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
    /**
     * Find nearest online and available driver to store location and assign order.
     *
     * @param Order $order
     * @param User|null $actor
     * @return array{success: bool, message: string, driver: User|null, distance_meters: int|null}
     */
    public function autoAssignNearestDriver(Order $order, ?User $actor = null): array
    {
        return DB::transaction(function () use ($order, $actor) {
            /** @var Order $lockedOrder */
            $lockedOrder = Order::query()
                ->with(['store', 'customer', 'driver.driverProfile'])
                ->lockForUpdate()
                ->findOrFail($order->id);

            // If order already has an active assigned driver
            if ($lockedOrder->driver_id && $lockedOrder->driver) {
                return [
                    'success' => true,
                    'message' => "شۆفێر پێشتر دیاریکراوە: {$lockedOrder->driver->name}",
                    'driver' => $lockedOrder->driver,
                    'distance_meters' => null,
                ];
            }

            $storeLat = (float) ($lockedOrder->store?->lat ?? 34.6836);
            $storeLng = (float) ($lockedOrder->store?->lng ?? 45.3189);

            // Fetch online drivers
            $drivers = DriverProfile::query()
                ->where('is_online', true)
                ->with('user')
                ->get();

            if ($drivers->isEmpty()) {
                // Fallback: search all registered verified drivers
                $drivers = DriverProfile::query()
                    ->where('is_verified', true)
                    ->with('user')
                    ->get();
            }

            if ($drivers->isEmpty()) {
                // Ultimate fallback: any driver profile
                $drivers = DriverProfile::query()->with('user')->get();
            }

            if ($drivers->isEmpty()) {
                return [
                    'success' => false,
                    'message' => 'هیچ شۆفێرێک لە سیستەمدا بەردەست نییە بۆ وەرگرتنی داواکاری.',
                    'driver' => null,
                    'distance_meters' => null,
                ];
            }

            // Calculate distance for each driver and sort to find nearest
            $sortedDrivers = $drivers->map(function (DriverProfile $profile) use ($storeLat, $storeLng) {
                $dLat = (float) ($profile->current_lat ?? 34.6836);
                $dLng = (float) ($profile->current_lng ?? 45.3189);
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

            // Assign driver to order
            $lockedOrder->update([
                'driver_id' => $chosenUser->id,
                'driver_status' => 'driver_assigned',
                'driver_assigned_at' => now(),
                'driver_lat' => (float) ($chosenProfile->current_lat ?? $storeLat),
                'driver_lng' => (float) ($chosenProfile->current_lng ?? $storeLng),
            ]);

            // Add status log
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

            // Create notification for driver
            AppNotification::create([
                'user_id' => $chosenUser->id,
                'target_audience' => 'specific_user',
                'title_ku' => "داواکاری نوێی {$lockedOrder->order_number} گەیشت",
                'title_en' => "New Order {$lockedOrder->order_number} Assigned",
                'body_ku' => "داواکارییەک لە {$lockedOrder->store?->name_ku} بە ئۆتۆماتیکی بۆت نێردرا.",
                'tag' => 'گەیاندن',
                'type' => 'order',
            ]);

            // Sync with LiveTelemetrySession
            $driverLat = (float) ($chosenProfile->current_lat ?? $storeLat);
            $driverLng = (float) ($chosenProfile->current_lng ?? $storeLng);
            $customerLat = (float) ($lockedOrder->delivery_lat ?? 34.6912);
            $customerLng = (float) ($lockedOrder->delivery_lng ?? 45.3264);

            LiveTelemetrySession::updateOrCreate(
                ['order_ref' => $lockedOrder->order_number],
                [
                    'order_id' => $lockedOrder->id,
                    'status' => $lockedOrder->status,
                    'driver_status' => 'driver_assigned',
                    'store_name' => $lockedOrder->store?->name_ku ?? 'فرۆشگا',
                    'store_address' => $lockedOrder->store?->address_ku ?? 'کەلار',
                    'store_phone' => $lockedOrder->store?->phone ?? '',
                    'store_lat' => $storeLat,
                    'store_lng' => $storeLng,
                    'customer_name' => $lockedOrder->customer_name ?? $lockedOrder->customer?->name ?? 'کڕیار',
                    'customer_address' => $lockedOrder->delivery_address ?? 'کەلار',
                    'customer_phone' => $lockedOrder->customer_phone ?? $lockedOrder->customer?->phone ?? '',
                    'customer_lat' => $customerLat,
                    'customer_lng' => $customerLng,
                    'driver_name' => $chosenUser->name,
                    'driver_phone' => $chosenUser->phone,
                    'vehicle_label' => $chosenProfile->plate_number ?? $chosenProfile->motor_type ?? 'ماتۆڕسوار',
                    'driver_lat' => $driverLat,
                    'driver_lng' => $driverLng,
                    'driver_heading' => (float) ($chosenProfile->heading ?? 45.0),
                    'driver_speed_kmh' => (float) ($chosenProfile->speed_kmh ?? 25.0),
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
     * Compute Haversine distance in meters between two lat/lng coordinates.
     */
    public function calculateHaversineDistanceMeters(float $lat1, float $lon1, float $lat2, float $lon2): int
    {
        $earthRadius = 6371000; // in meters

        $latDelta = deg2rad($lat2 - $lat1);
        $lonDelta = deg2rad($lon2 - $lon1);

        $a = sin($latDelta / 2) * sin($latDelta / 2) +
            cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
            sin($lonDelta / 2) * sin($lonDelta / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return (int) round($earthRadius * $c);
    }
}

