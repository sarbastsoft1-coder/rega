<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\DriverProfile;
use App\Models\LiveTelemetrySession;
use App\Models\Order;
use App\Models\OrderStatusLog;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class DriverDispatchService
{
    /** Drivers must have pinged within this window to be auto-assigned. */
    public const PING_FRESHNESS_MINUTES = 15;

    /**
     * Find nearest online, verified, freshly-pinged driver with real GPS and assign.
     * Fail closed when none are eligible — never fall back to offline/unverified/any.
     *
     * @return array{success: bool, message: string, driver: User|null, distance_meters: int|null}
     */
    /**
     * @param  list<int>  $excludeDriverIds
     * @return array{success: bool, message: string, driver: User|null, distance_meters: int|null}
     */
    public function autoAssignNearestDriver(Order $order, ?User $actor = null, array $excludeDriverIds = []): array
    {
        return DB::transaction(function () use ($order, $actor, $excludeDriverIds) {
            /** @var Order $lockedOrder */
            $lockedOrder = Order::query()
                ->with(['store', 'customer', 'driver.driverProfile'])
                ->lockForUpdate()
                ->findOrFail($order->id);

            if ($lockedOrder->driver_id && $lockedOrder->driver) {
                return [
                    'success' => true,
                    'message' => "شۆفێر پێشتر دیاریکراوە: {$lockedOrder->driver->name}",
                    'driver' => $lockedOrder->driver,
                    'distance_meters' => null,
                ];
            }

            $storeLat = $lockedOrder->store?->lat;
            $storeLng = $lockedOrder->store?->lng;
            if ($storeLat === null || $storeLng === null) {
                return [
                    'success' => false,
                    'message' => 'ناونیشانی فرۆشگا (GPS) دیارینەکراوە — ناتوانرێت شۆفێر دیاری بکرێت.',
                    'driver' => null,
                    'distance_meters' => null,
                ];
            }
            $storeLat = (float) $storeLat;
            $storeLng = (float) $storeLng;

            $excludeDriverIds = array_values(array_unique(array_map('intval', $excludeDriverIds)));

            $drivers = DriverProfile::query()
                ->where('is_online', true)
                ->where('is_verified', true)
                ->whereNotNull('current_lat')
                ->whereNotNull('current_lng')
                ->where('last_ping_at', '>=', now()->subMinutes(self::PING_FRESHNESS_MINUTES))
                ->when($excludeDriverIds !== [], fn ($q) => $q->whereNotIn('user_id', $excludeDriverIds))
                ->with('user')
                ->get()
                ->filter(fn (DriverProfile $profile) => $profile->user !== null);

            if ($drivers->isEmpty()) {
                return [
                    'success' => false,
                    'message' => 'هیچ شۆفێرێکی ئۆنلاین/پشتڕاستکراو بە GPSی نوێ بەردەست نییە.',
                    'driver' => null,
                    'distance_meters' => null,
                ];
            }

            $sortedDrivers = $drivers->map(function (DriverProfile $profile) use ($storeLat, $storeLng) {
                $dLat = (float) $profile->current_lat;
                $dLng = (float) $profile->current_lng;
                $meters = $this->calculateHaversineDistanceMeters($storeLat, $storeLng, $dLat, $dLng);

                return [
                    'profile' => $profile,
                    'user' => $profile->user,
                    'distance_meters' => $meters,
                ];
            })->sortBy('distance_meters')->values();

            $nearest = $sortedDrivers->first();
            /** @var DriverProfile $chosenProfile */
            $chosenProfile = $nearest['profile'];
            /** @var User $chosenUser */
            $chosenUser = $nearest['user'];
            $distanceMeters = (int) $nearest['distance_meters'];

            $oldDriverStatus = $lockedOrder->driver_status;
            $driverLat = (float) $chosenProfile->current_lat;
            $driverLng = (float) $chosenProfile->current_lng;

            $lockedOrder->update([
                'driver_id' => $chosenUser->id,
                'driver_status' => 'driver_assigned',
                'driver_assigned_at' => now(),
                'driver_lat' => $driverLat,
                'driver_lng' => $driverLng,
            ]);

            $actorRole = $actor?->role ?? 'vendor';
            $actorId = $actor?->id ?? $lockedOrder->store?->user_id;

            OrderStatusLog::create([
                'order_id' => $lockedOrder->id,
                'from_status' => $oldDriverStatus,
                'to_status' => 'driver_assigned',
                'actor_id' => $actorId,
                'actor_role' => $actorRole,
                'note' => "شۆفێری نزیکترین دیاریکرا: {$chosenUser->name} ({$chosenProfile->driver_code}) - دووری: {$distanceMeters} مەتر",
            ]);

            AppNotification::createAndPush([
                'user_id' => $chosenUser->id,
                'target_audience' => 'specific_user',
                'title_ku' => "داواکاری نوێی {$lockedOrder->order_number} گەیشت",
                'title_en' => "New Order {$lockedOrder->order_number} Assigned",
                'body_ku' => "داواکارییەک لە {$lockedOrder->store?->name_ku} بە ئۆتۆماتیکی بۆت نێردرا.",
                'tag' => 'گەیاندن',
                'type' => 'order',
            ], [
                'order_number' => (string) $lockedOrder->order_number,
                'order_id' => (string) $lockedOrder->id,
            ]);

            $customerLat = (float) ($lockedOrder->delivery_lat ?? $storeLat);
            $customerLng = (float) ($lockedOrder->delivery_lng ?? $storeLng);

            LiveTelemetrySession::updateOrCreate(
                ['order_ref' => $lockedOrder->order_number],
                [
                    'order_id' => $lockedOrder->id,
                    'status' => $lockedOrder->status,
                    'driver_status' => 'driver_assigned',
                    'store_name' => $lockedOrder->store?->name_ku ?? 'فرۆشگا',
                    'store_address' => $lockedOrder->store?->address_ku ?? '',
                    'store_phone' => $lockedOrder->store?->phone ?? '',
                    'store_lat' => $storeLat,
                    'store_lng' => $storeLng,
                    'customer_name' => $lockedOrder->customer_name ?? $lockedOrder->customer?->name ?? 'کڕیار',
                    'customer_address' => $lockedOrder->delivery_address ?? '',
                    'customer_phone' => $lockedOrder->customer_phone ?? $lockedOrder->customer?->phone ?? '',
                    'customer_lat' => $customerLat,
                    'customer_lng' => $customerLng,
                    'driver_name' => $chosenUser->name,
                    'driver_phone' => $chosenUser->phone,
                    'vehicle_label' => $chosenProfile->plate_number ?? $chosenProfile->motor_type ?? 'ماتۆڕسوار',
                    'driver_lat' => $driverLat,
                    'driver_lng' => $driverLng,
                    'driver_heading' => (float) ($chosenProfile->heading ?? 0),
                    'driver_speed_kmh' => (float) ($chosenProfile->speed_kmh ?? 0),
                    'eta_seconds' => max(60, (int) round(($distanceMeters / 250) * 60)),
                    'distance_remaining_meters' => $distanceMeters,
                    'delivery_pin' => $lockedOrder->delivery_pin,
                    'handover_pin' => $lockedOrder->handover_pin,
                    'total_amount' => $lockedOrder->total_amount,
                    'delivery_fee' => $lockedOrder->delivery_fee,
                    'driver_tip' => $lockedOrder->driver_tip,
                    'route_polyline' => [
                        [$driverLat, $driverLng],
                        [$storeLat, $storeLng],
                        [$customerLat, $customerLng],
                    ],
                ]
            );

            return [
                'success' => true,
                'message' => "نزیکترین شۆفێر ({$chosenUser->name}) بە دووری {$distanceMeters} مەتر بە سەرکەوتوویی دیاریکرا و داواکارییەکەی بۆ نێردرا.",
                'driver' => $chosenUser->load('driverProfile'),
                'distance_meters' => $distanceMeters,
            ];
        });
    }

    /**
     * Driver self-claim of a ready, unassigned order (marketplace accept).
     *
     * @return array{success: bool, message: string, order: Order|null, distance_meters: int|null}
     */
    public function claimOrderForDriver(Order $order, User $driver): array
    {
        return DB::transaction(function () use ($order, $driver) {
            /** @var Order $lockedOrder */
            $lockedOrder = Order::query()
                ->with(['store', 'customer', 'driver.driverProfile'])
                ->lockForUpdate()
                ->findOrFail($order->id);

            if ($lockedOrder->driver_id) {
                if ((int) $lockedOrder->driver_id === (int) $driver->id) {
                    return [
                        'success' => true,
                        'message' => 'ئەم داواکارییە پێشتر بۆت دیاریکراوە.',
                        'order' => $lockedOrder,
                        'distance_meters' => null,
                    ];
                }

                return [
                    'success' => false,
                    'message' => 'ئەم داواکارییە پێشتر لەلایەن شۆفێرێکی ترەوە وەرگیراوە.',
                    'order' => null,
                    'distance_meters' => null,
                ];
            }

            $isReady = $lockedOrder->status === 'ready' || $lockedOrder->vendor_status === 'ready';
            if (! $isReady || in_array($lockedOrder->status, ['delivered', 'cancelled', 'rejected'], true)) {
                return [
                    'success' => false,
                    'message' => 'ئەم داواکارییە ئامادە نییە بۆ قبوڵکردن.',
                    'order' => null,
                    'distance_meters' => null,
                ];
            }

            /** @var DriverProfile|null $profile */
            $profile = $driver->driverProfile;
            if (! $profile) {
                return [
                    'success' => false,
                    'message' => 'پڕۆفایلی شۆفێر نەدۆزرایەوە.',
                    'order' => null,
                    'distance_meters' => null,
                ];
            }

            $storeLat = $lockedOrder->store?->lat;
            $storeLng = $lockedOrder->store?->lng;
            $driverLat = $profile->current_lat !== null ? (float) $profile->current_lat : (float) ($storeLat ?? 0);
            $driverLng = $profile->current_lng !== null ? (float) $profile->current_lng : (float) ($storeLng ?? 0);
            $distanceMeters = null;
            if ($storeLat !== null && $storeLng !== null && $profile->current_lat !== null && $profile->current_lng !== null) {
                $distanceMeters = $this->calculateHaversineDistanceMeters(
                    (float) $storeLat,
                    (float) $storeLng,
                    $driverLat,
                    $driverLng
                );
            }

            $oldDriverStatus = $lockedOrder->driver_status;
            $lockedOrder->update([
                'driver_id' => $driver->id,
                'driver_status' => 'driver_assigned',
                'driver_assigned_at' => now(),
                'driver_lat' => $driverLat ?: null,
                'driver_lng' => $driverLng ?: null,
            ]);

            OrderStatusLog::create([
                'order_id' => $lockedOrder->id,
                'from_status' => $oldDriverStatus,
                'to_status' => 'driver_assigned',
                'actor_id' => $driver->id,
                'actor_role' => 'driver',
                'note' => "شۆفێر داواکاری قبوڵکرد: {$driver->name}",
            ]);

            AppNotification::createAndPush([
                'user_id' => $driver->id,
                'target_audience' => 'specific_user',
                'title_ku' => "داواکاری {$lockedOrder->order_number} قبوڵکرا",
                'title_en' => "Order {$lockedOrder->order_number} accepted",
                'body_ku' => "داواکارییەک لە {$lockedOrder->store?->name_ku} قبوڵت کرد — بەڕێکەوە بەرەو فرۆشگا.",
                'tag' => 'گەیاندن',
                'type' => 'order',
            ], [
                'order_number' => (string) $lockedOrder->order_number,
                'order_id' => (string) $lockedOrder->id,
            ]);

            $customerLat = (float) ($lockedOrder->delivery_lat ?? $storeLat ?? $driverLat);
            $customerLng = (float) ($lockedOrder->delivery_lng ?? $storeLng ?? $driverLng);

            LiveTelemetrySession::updateOrCreate(
                ['order_ref' => $lockedOrder->order_number],
                [
                    'order_id' => $lockedOrder->id,
                    'status' => $lockedOrder->status,
                    'driver_status' => 'driver_assigned',
                    'store_name' => $lockedOrder->store?->name_ku ?? 'فرۆشگا',
                    'store_address' => $lockedOrder->store?->address_ku ?? '',
                    'store_phone' => $lockedOrder->store?->phone ?? '',
                    'store_lat' => $storeLat,
                    'store_lng' => $storeLng,
                    'customer_name' => $lockedOrder->customer_name ?? $lockedOrder->customer?->name ?? 'کڕیار',
                    'customer_address' => $lockedOrder->delivery_address ?? '',
                    'customer_phone' => $lockedOrder->customer_phone ?? $lockedOrder->customer?->phone ?? '',
                    'customer_lat' => $customerLat,
                    'customer_lng' => $customerLng,
                    'driver_name' => $driver->name,
                    'driver_phone' => $driver->phone,
                    'vehicle_label' => $profile->plate_number ?? $profile->motor_type ?? 'ماتۆڕسوار',
                    'driver_lat' => $driverLat ?: null,
                    'driver_lng' => $driverLng ?: null,
                    'driver_heading' => (float) ($profile->heading ?? 0),
                    'driver_speed_kmh' => (float) ($profile->speed_kmh ?? 0),
                    'eta_seconds' => $distanceMeters !== null ? max(60, (int) round(($distanceMeters / 250) * 60)) : 600,
                    'distance_remaining_meters' => $distanceMeters,
                    'delivery_pin' => $lockedOrder->delivery_pin,
                    'handover_pin' => $lockedOrder->handover_pin,
                    'total_amount' => $lockedOrder->total_amount,
                    'delivery_fee' => $lockedOrder->delivery_fee,
                    'driver_tip' => $lockedOrder->driver_tip,
                    'route_polyline' => ($storeLat !== null && $storeLng !== null)
                        ? [
                            [$driverLat ?: (float) $storeLat, $driverLng ?: (float) $storeLng],
                            [(float) $storeLat, (float) $storeLng],
                            [$customerLat, $customerLng],
                        ]
                        : [],
                ]
            );

            return [
                'success' => true,
                'message' => 'داواکاری بە سەرکەوتوویی قبوڵکرا.',
                'order' => $lockedOrder->fresh([
                    'items',
                    'store:id,name_ku,phone,address_ku,lat,lng,logo_url',
                    'customer:id,name,phone',
                ]),
                'distance_meters' => $distanceMeters,
            ];
        });
    }

    /**
     * Driver declined / timed out before starting the trip.
     * Releases the assignment (if any) and tries the next nearest driver.
     *
     * @return array{success: bool, message: string, reassigned: bool, driver: User|null}
     */
    public function declineOfferAndReassign(Order $order, User $driver, string $reason, bool $timedOut = false): array
    {
        return DB::transaction(function () use ($order, $driver, $reason, $timedOut) {
            /** @var Order $lockedOrder */
            $lockedOrder = Order::query()
                ->with(['store', 'customer', 'driver.driverProfile'])
                ->lockForUpdate()
                ->findOrFail($order->id);

            $notePrefix = $timedOut
                ? 'تایمەوتی ٣٠ چرکە — شۆفێر وەری نەگرت'
                : 'شۆفێر ڕەتیکردەوە';

            // Marketplace skip: order still unassigned — log only so others can claim.
            if ($lockedOrder->driver_id === null) {
                OrderStatusLog::create([
                    'order_id' => $lockedOrder->id,
                    'from_status' => $lockedOrder->driver_status,
                    'to_status' => $lockedOrder->driver_status ?: 'unassigned',
                    'actor_id' => $driver->id,
                    'actor_role' => 'driver',
                    'note' => "{$notePrefix}: {$reason}",
                ]);

                return [
                    'success' => true,
                    'message' => 'داواکاری بۆ شۆفێرانی تر بەردەست ماوەتەوە.',
                    'reassigned' => false,
                    'driver' => null,
                ];
            }

            if ((int) $lockedOrder->driver_id !== (int) $driver->id) {
                return [
                    'success' => false,
                    'message' => 'ئەم داواکارییە بۆ تۆ نییە.',
                    'reassigned' => false,
                    'driver' => null,
                ];
            }

            $currentStatus = (string) ($lockedOrder->driver_status ?? 'driver_assigned');
            if (! in_array($currentStatus, ['', 'unassigned', 'driver_assigned'], true)) {
                return [
                    'success' => false,
                    'message' => 'دوای دەستپێکردنی گەیاندن ناتوانیت ڕەتی بکەیتەوە — داوای هەڵوەشاندنەوە بکە.',
                    'reassigned' => false,
                    'driver' => null,
                ];
            }

            $oldStatus = $lockedOrder->driver_status;
            $lockedOrder->update([
                'driver_id' => null,
                'driver_status' => 'unassigned',
                'driver_assigned_at' => null,
                'driver_lat' => null,
                'driver_lng' => null,
            ]);

            OrderStatusLog::create([
                'order_id' => $lockedOrder->id,
                'from_status' => $oldStatus,
                'to_status' => 'unassigned',
                'actor_id' => $driver->id,
                'actor_role' => 'driver',
                'note' => "{$notePrefix}: {$reason}",
            ]);

            LiveTelemetrySession::query()
                ->where('order_id', $lockedOrder->id)
                ->orWhere('order_ref', $lockedOrder->order_number)
                ->orWhere('order_ref', strtoupper(ltrim((string) $lockedOrder->order_number, '#')))
                ->update([
                    'driver_status' => 'unassigned',
                    'driver_name' => null,
                    'driver_phone' => null,
                    'driver_lat' => null,
                    'driver_lng' => null,
                ]);

            // Nested transaction shares the outer lock connection in Laravel.
            $assign = $this->autoAssignNearestDriver(
                $lockedOrder->fresh() ?? $lockedOrder,
                $driver,
                [(int) $driver->id]
            );

            return [
                'success' => true,
                'message' => $assign['success']
                    ? "داواکاری درا بە شۆفێرێکی تر: {$assign['driver']?->name}"
                    : 'داواکاری ئازادکرا — شۆفێری تر نەدۆزرایەوە، لە پووڵی بەردەست دەمێنێتەوە.',
                'reassigned' => (bool) $assign['success'],
                'driver' => $assign['driver'],
            ];
        });
    }

    /**
     * Compute Haversine distance in meters between two lat/lng coordinates.
     */
    public function calculateHaversineDistanceMeters(float $lat1, float $lon1, float $lat2, float $lon2): int
    {
        $earthRadius = 6371000;

        $latDelta = deg2rad($lat2 - $lat1);
        $lonDelta = deg2rad($lon2 - $lon1);

        $a = sin($latDelta / 2) * sin($latDelta / 2) +
            cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
            sin($lonDelta / 2) * sin($lonDelta / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return (int) round($earthRadius * $c);
    }
}
