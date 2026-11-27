<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\DriverProfile;
use App\Models\LiveTelemetrySession;
use App\Models\Order;
use App\Models\OrderStatusLog;
use App\Models\PlatformSetting;
use App\Models\SupportTicket;
use App\Services\DriverDispatchService;
use App\Services\OrderSettlementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DriverAppController extends Controller
{
    public function __construct(private readonly OrderSettlementService $settlementService) {}

    private function resolveDriverProfile(Request $request): DriverProfile
    {
        $profile = $request->user()->driverProfile()->with(['user', 'documents'])->first();
        if (! $profile) {
            abort(404, 'پڕۆفایلی شۆفێر نەدۆزرایەوە.');
        }
        return $profile;
    }

    /** Real GPS with a recent ping — not a map overview / stale seed coord. */
    private function isLocationTrusted(?DriverProfile $profile): bool
    {
        if ($profile === null) {
            return false;
        }
        if ($profile->current_lat === null || $profile->current_lng === null || $profile->last_ping_at === null) {
            return false;
        }

        return $profile->last_ping_at->gte(now()->subMinutes(15));
    }

    public function profile(Request $request): JsonResponse
    {
        $profile = $this->resolveDriverProfile($request);

        $trusted = $this->isLocationTrusted($profile);

        return response()->json([
            'success' => true,
            'data' => $profile,
            'location_trusted' => $trusted,
            'dispatch_eligible' => (bool) $profile->is_verified && (bool) $profile->is_online && $trusted,
        ]);
    }

    public function updateStatus(Request $request): JsonResponse
    {
        $profile = $this->resolveDriverProfile($request);
        $validated = $request->validate([
            'is_online' => ['required', 'boolean'],
            'lat' => ['nullable', 'numeric'],
            'lng' => ['nullable', 'numeric'],
        ]);

        $goingOnline = (bool) $validated['is_online'];
        $user = $request->user();

        if ($goingOnline && $user && $user->is_active === false) {
            return response()->json([
                'success' => false,
                'message' => 'هەژمارەکەت ناچالاک کراوە — ناتوانیت ئۆنلاین بیت.',
            ], 403);
        }

        if (! $goingOnline && $profile->is_online && $profile->online_since) {
            $minutes = max(0, $profile->online_since->diffInMinutes(now()));
            $hoursAdded = round($minutes / 60, 2);
            $profile->update([
                'is_online' => false,
                'online_hours_total' => (float) $profile->online_hours_total + $hoursAdded,
                'online_since' => null,
            ]);
        } elseif ($goingOnline) {
            $updates = [
                'is_online' => true,
                'online_since' => $profile->online_since ?? now(),
            ];
            // Never invent city-default coords — dispatch requires real GPS + last_ping_at.
            if (isset($validated['lat'], $validated['lng'])) {
                $updates['current_lat'] = $validated['lat'];
                $updates['current_lng'] = $validated['lng'];
                $updates['last_ping_at'] = now();
            }
            $profile->update($updates);
        }

        $fresh = $profile->fresh(['user', 'documents']);
        $trusted = $this->isLocationTrusted($fresh);

        return response()->json([
            'success' => true,
            'data' => $fresh,
            'location_trusted' => $trusted,
            'dispatch_eligible' => (bool) $fresh->is_verified && (bool) $fresh->is_online && $trusted,
            'warning' => ($goingOnline && ! $fresh->is_verified)
                ? 'ئۆنلاین بوویت، بەڵام هەژمارەکەت پشتڕاست نەکراوەتەوە — قبوڵکردنی داواکاری داخراوە هەتا پشتڕاست بکرێیت.'
                : (($goingOnline && ! $trusted)
                    ? 'ئۆنلاین بوویت، بەڵام GPS نوێ نییە — شوێن بنێرە بۆ وەرگرتنی داواکاری.'
                    : null),
        ]);
    }

    public function updateLocation(Request $request): JsonResponse
    {
        $profile = $this->resolveDriverProfile($request);
        $validated = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
            'heading' => ['nullable', 'numeric'],
            'speed_kmh' => ['nullable', 'numeric'],
        ]);

        $updates = [
            'current_lat' => $validated['lat'],
            'current_lng' => $validated['lng'],
            'last_ping_at' => now(),
        ];
        if (array_key_exists('heading', $validated) && $validated['heading'] !== null) {
            $updates['heading'] = $validated['heading'];
        }
        if (array_key_exists('speed_kmh', $validated) && $validated['speed_kmh'] !== null) {
            $updates['speed_kmh'] = $validated['speed_kmh'];
        }

        $profile->update($updates);
        $profile->refresh();

        // Mirror onto active order + live telemetry so seller/customer maps move live.
        $activeOrder = Order::query()
            ->where('driver_id', $request->user()->id)
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->latest()
            ->first();

        if ($activeOrder) {
            $orderUpdates = [
                'driver_lat' => $validated['lat'],
                'driver_lng' => $validated['lng'],
                'last_telemetry_at' => now(),
            ];
            if (isset($validated['heading'])) {
                $orderUpdates['driver_heading'] = $validated['heading'];
            }
            if (isset($validated['speed_kmh'])) {
                $orderUpdates['driver_speed_kmh'] = $validated['speed_kmh'];
            }
            $activeOrder->update($orderUpdates);

            $orderRef = strtoupper(ltrim((string) ($activeOrder->order_number ?? ''), '#'));
            $session = LiveTelemetrySession::query()
                ->where(function ($q) use ($activeOrder, $orderRef) {
                    $q->where('order_id', $activeOrder->id);
                    if ($orderRef !== '') {
                        $q->orWhere('order_ref', $orderRef);
                    }
                })
                ->latest('updated_at')
                ->first();
            if ($session) {
                $session->update([
                    'driver_lat' => $validated['lat'],
                    'driver_lng' => $validated['lng'],
                    'driver_heading' => $validated['heading'] ?? $session->driver_heading,
                    'driver_speed_kmh' => $validated['speed_kmh'] ?? $session->driver_speed_kmh,
                    'driver_pinged_at' => now(),
                    'driver_name' => $session->driver_name ?: $request->user()->name,
                    'driver_phone' => $session->driver_phone ?: $request->user()->phone,
                    'status' => $activeOrder->status ?: $session->status,
                    'driver_status' => $activeOrder->driver_status ?: $session->driver_status,
                ]);
            }
        }

        return response()->json([
            'success' => true,
            'data' => [
                'lat' => (float) $profile->current_lat,
                'lng' => (float) $profile->current_lng,
                'is_online' => (bool) $profile->is_online,
            ],
            'location_trusted' => $this->isLocationTrusted($profile),
        ]);
    }

    public function activeOrder(Request $request): JsonResponse
    {
        $order = Order::query()
            ->where('driver_id', $request->user()->id)
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->with(['items', 'store:id,name_ku,phone,address_ku,lat,lng,logo_url', 'customer:id,name,phone'])
            ->latest()
            ->first();

        // delivery_pin / handover_pin are secrets — driver submits them, must not receive them.
        if ($order) {
            $order->makeHidden(['delivery_pin', 'handover_pin']);
        }

        return response()->json([
            'success' => true,
            'data' => $order,
        ]);
    }

    public function ordersHistory(Request $request): JsonResponse
    {
        $query = Order::query()
            ->where('driver_id', $request->user()->id)
            ->with(['items', 'store:id,name_ku,address_ku', 'customer:id,name'])
            ->latest();

        $status = (string) $request->string('status', 'all');
        if ($status === 'delivered') {
            $query->where('status', 'delivered');
        } elseif ($status === 'cancelled') {
            $query->whereIn('status', ['cancelled', 'rejected']);
        }

        $orders = $query->get()->makeHidden(['delivery_pin', 'handover_pin']);

        return response()->json([
            'success' => true,
            'data' => $orders,
        ]);
    }

    /** Ready, unassigned orders drivers can accept (marketplace pool). */
    public function availableOrders(Request $request): JsonResponse
    {
        $orders = Order::query()
            ->whereNull('driver_id')
            ->where(function ($q) {
                $q->where('status', 'ready')->orWhere('vendor_status', 'ready');
            })
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected', 'pending'])
            ->with(['items', 'store:id,name_ku,phone,address_ku,lat,lng,logo_url', 'customer:id,name,phone'])
            ->latest('ready_at')
            ->latest('id')
            ->limit(50)
            ->get()
            ->makeHidden(['delivery_pin', 'handover_pin']);

        return response()->json([
            'success' => true,
            'data' => $orders,
        ]);
    }

    public function claimOrder(Request $request, Order $order, DriverDispatchService $dispatchService): JsonResponse
    {
        $profile = $this->resolveDriverProfile($request);

        if (! $profile->is_online) {
            return response()->json([
                'success' => false,
                'message' => 'بۆ قبوڵکردنی داواکاری دەبێت ئۆنلاین بیت.',
            ], 422);
        }

        if (! $profile->is_verified) {
            return response()->json([
                'success' => false,
                'message' => 'هەژمارەکەت پشتڕاست نەکراوەتەوە — پەیوەندی بە ئادمینەوە بکە.',
            ], 422);
        }

        // One active job at a time.
        $busy = Order::query()
            ->where('driver_id', $request->user()->id)
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->exists();
        if ($busy) {
            return response()->json([
                'success' => false,
                'message' => 'داواکارییەکی چالاکت هەیە — سەرەتا ئەوە تەواو بکە.',
            ], 422);
        }

        $result = $dispatchService->claimOrderForDriver($order, $request->user());

        if (! $result['success']) {
            return response()->json([
                'success' => false,
                'message' => $result['message'],
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => $result['message'],
            'data' => $result['order']?->makeHidden(['delivery_pin', 'handover_pin']),
            'distance_meters' => $result['distance_meters'],
        ]);
    }

    /**
     * Driver declined or timed out the 30s accept window.
     * Assigned orders are released and offered to the next driver; pool orders stay available.
     */
    public function declineOrderOffer(Request $request, Order $order, DriverDispatchService $dispatchService): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
            'timed_out' => ['sometimes', 'boolean'],
        ]);

        $result = $dispatchService->declineOfferAndReassign(
            $order,
            $request->user(),
            $validated['reason'],
            (bool) ($validated['timed_out'] ?? false),
        );

        if (! $result['success']) {
            return response()->json([
                'success' => false,
                'message' => $result['message'],
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => $result['message'],
            'reassigned' => $result['reassigned'],
            'next_driver' => $result['driver']?->only(['id', 'name', 'phone']),
        ]);
    }

    /**
     * Allowed driver_status edges. Completion is PIN-only (verify-delivery).
     *
     * @var array<string, list<string>>
     */
    private const DRIVER_STATUS_TRANSITIONS = [
        '' => ['driver_arriving_pickup'],
        'unassigned' => ['driver_arriving_pickup'],
        'driver_assigned' => ['driver_arriving_pickup'],
        'driver_arriving_pickup' => ['arrived_pickup'],
        'arrived_pickup' => ['picked_up'],
        'picked_up' => ['on_the_way'],
        'on_the_way' => ['arrived_customer'],
        'arrived_customer' => [],
    ];

    public function advanceOrderStatus(Request $request, Order $order): JsonResponse
    {
        if ($order->driver_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'driver_status' => ['required', 'string', 'in:driver_arriving_pickup,arrived_pickup,picked_up,on_the_way,arrived_customer'],
        ]);

        $nextDriverStatus = $validated['driver_status'];
        $oldStatus = (string) ($order->driver_status ?? '');

        // Idempotent replay of the same status under flaky networks.
        if ($oldStatus === $nextDriverStatus) {
            return response()->json([
                'success' => true,
                'data' => $order->fresh([
                    'items',
                    'store:id,name_ku,phone,address_ku,lat,lng,logo_url',
                    'customer:id,name,phone',
                ])?->makeHidden(['delivery_pin', 'handover_pin']),
            ]);
        }

        $allowed = self::DRIVER_STATUS_TRANSITIONS[$oldStatus] ?? null;
        if ($allowed === null || ! in_array($nextDriverStatus, $allowed, true)) {
            return response()->json([
                'success' => false,
                'message' => "گواستنەوەی بارودۆخ لە «{$oldStatus}» بۆ «{$nextDriverStatus}» ڕێگەپێدراو نییە.",
                'data' => [
                    'current' => $oldStatus,
                    'requested' => $nextDriverStatus,
                    'allowed' => $allowed ?? [],
                ],
            ], 422);
        }

        $updates = ['driver_status' => $nextDriverStatus];

        match ($nextDriverStatus) {
            'arrived_pickup' => $updates['arrived_pickup_at'] = $order->arrived_pickup_at ?? now(),
            'picked_up' => $updates += [
                'status' => 'picked_up',
                'vendor_status' => 'completed',
                'picked_up_at' => $order->picked_up_at ?? now(),
            ],
            'on_the_way' => $updates['status'] = 'on_the_way',
            'arrived_customer' => $updates += [
                'status' => 'arrived_customer',
                'arrived_customer_at' => now(),
            ],
            default => null,
        };

        $order->update($updates);

        OrderStatusLog::create([
            'order_id' => $order->id,
            'from_status' => $oldStatus !== '' ? $oldStatus : null,
            'to_status' => $nextDriverStatus,
            'actor_id' => $request->user()->id,
            'actor_role' => 'driver',
            'note' => "شۆفێر بارودۆخی گۆڕی بۆ {$nextDriverStatus}",
        ]);

        $cleanRef = strtoupper(ltrim((string) $order->order_number, '#'));
        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->orWhere('order_ref', $cleanRef)
            ->update([
                'status' => $order->status,
                'driver_status' => $nextDriverStatus,
                'driver_name' => $request->user()->name,
                'driver_phone' => $request->user()->phone,
            ]);

        if ($order->customer_id && in_array($nextDriverStatus, ['picked_up', 'on_the_way', 'arrived_customer'], true)) {
            $msgKu = match ($nextDriverStatus) {
                'picked_up' => 'شۆفێر داواکارییەکەتی لە فرۆشگا وەرگرت و بەڕێدەکەوێت بۆ لات.',
                'on_the_way' => 'شۆفێر ئێستا لە ڕێگایە بەرەو ناونیشانەکەت — لەسەر نەخشە شوێنی ببینە.',
                'arrived_customer' => 'شۆفێر گەیشتە بەردەم ناونیشانەکەت!',
                default => '',
            };
            if ($msgKu !== '') {
                AppNotification::createAndPush([
                    'user_id' => $order->customer_id,
                    'target_audience' => 'specific_user',
                    'title_ku' => "نوێکاری گەیاندنی {$order->order_number}",
                    'title_en' => "Delivery update for {$order->order_number}",
                    'body_ku' => $msgKu,
                    'tag' => 'گەیاندن',
                    'type' => 'order',
                    'store_id' => $order->store_id,
                ]);
            }
        }

        return response()->json([
            'success' => true,
            'data' => $order->fresh([
                'items',
                'store:id,name_ku,phone,address_ku,lat,lng,logo_url',
                'customer:id,name,phone',
            ])?->makeHidden(['delivery_pin', 'handover_pin']),
        ]);
    }

    public function verifyDeliveryPin(Request $request, Order $order): JsonResponse
    {
        if ($order->driver_id !== $request->user()->id) {
            abort(403);
        }

        // PIN is optional — driver app may complete without customer code.
        $validated = $request->validate([
            'delivery_pin' => ['nullable', 'string', 'size:4'],
        ]);

        $pin = trim((string) ($validated['delivery_pin'] ?? ''));
        if ($pin !== '') {
            $expected = (string) ($order->delivery_pin ?? '');
            if ($expected === '' || ! hash_equals($expected, $pin)) {
                return response()->json([
                    'success' => false,
                    'message' => 'PIN ی گەیاندن هەڵەیە. تکایە کۆدی ٤ ژمارەیی لە کڕیار وەربگرە.',
                ], 422);
            }
        }

        $settled = $this->settlementService->markDelivered(
            $order,
            $request->user(),
            'گەیاندن تەواوکرا'
        );

        $cleanRef = strtoupper(ltrim((string) $order->order_number, '#'));
        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->orWhere('order_ref', $cleanRef)
            ->update([
                'status' => 'delivered',
                'driver_status' => 'delivered',
                'eta_seconds' => 0,
                'distance_remaining_meters' => 0,
                'progress_permille' => 1000,
            ]);

        return response()->json([
            'success' => true,
            'message' => 'گەیاندن بە سەرکەوتوویی تەواوکرا و کرێ خرایە سەر باڵانسەکەت.',
            'data' => $settled->makeHidden(['delivery_pin', 'handover_pin']),
        ]);
    }

    public function claimWaitingBonus(Request $request, Order $order): JsonResponse
    {
        if ($order->driver_id !== $request->user()->id) {
            abort(403);
        }

        $threshold = (int) PlatformSetting::getValue('waiting_bonus_threshold_minutes', 15);
        $bonusAmount = (int) PlatformSetting::getValue('waiting_bonus_amount', 1000);

        return DB::transaction(function () use ($request, $order, $threshold, $bonusAmount) {
            /** @var Order $locked */
            $locked = Order::query()->lockForUpdate()->findOrFail($order->id);

            if ($locked->driver_id !== $request->user()->id) {
                abort(403);
            }

            if ((int) $locked->waiting_bonus > 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'پاداشتی چاوەڕوانی پێشتر هەژمارکراوە.',
                    'data' => $locked->makeHidden(['delivery_pin', 'handover_pin']),
                ], 422);
            }

            if ($locked->arrived_pickup_at === null) {
                return response()->json([
                    'success' => false,
                    'message' => 'پێویستە سەرەتا گەیشتن بە فرۆشگا تۆمار بکرێت پێش داواکردنی پاداشت.',
                ], 422);
            }

            // Server timestamps only — client waited_minutes is ignored.
            $waitedMinutes = (int) $locked->arrived_pickup_at
                ->diffInMinutes($locked->picked_up_at ?? now());

            if ($waitedMinutes < $threshold) {
                return response()->json([
                    'success' => false,
                    'message' => "کاتی چاوەڕوانی ({$waitedMinutes} خولەک) کەمترە لە {$threshold} خولەک.",
                ], 422);
            }

            $locked->update([
                'waiting_bonus' => $bonusAmount,
                'driver_total_earning' => (int) $locked->delivery_fee + (int) $locked->driver_tip + $bonusAmount,
            ]);

            return response()->json([
                'success' => true,
                'message' => "پاداشتی چاوەڕوانی ({$bonusAmount} د.ع) بۆت هەژمارکرا.",
                'data' => $locked->fresh()?->makeHidden(['delivery_pin', 'handover_pin']),
            ]);
        });
    }

    public function requestCancellation(Request $request, Order $order): JsonResponse
    {
        if ($order->driver_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $ticket = SupportTicket::create([
            'ticket_number' => 'TKT-' . strtoupper(Str::random(6)),
            'user_id' => $request->user()->id,
            'order_id' => $order->id,
            'category' => 'unreachable_customer',
            'priority' => 'urgent',
            'subject' => "داواکاری هەڵوەشاندنەوە بۆ {$order->order_number}",
            'description' => $validated['reason'],
            'status' => 'open',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'داواکاری هەڵوەشاندنەوە نێردرا بۆ بەشی چاودێری REGA.',
            'data' => $ticket,
        ], 201);
    }

    public function earnings(Request $request): JsonResponse
    {
        $profile = $this->resolveDriverProfile($request);
        $period = (string) $request->string('period', 'today');

        $start = match ($period) {
            'week' => Carbon::now()->subDays(6)->startOfDay(),
            'month' => Carbon::now()->subDays(29)->startOfDay(),
            default => Carbon::today(),
        };

        $delivered = Order::query()
            ->where('driver_id', $request->user()->id)
            ->where('status', 'delivered')
            ->where('delivered_at', '>=', $start);

        $totalEarnings = (int) (clone $delivered)->sum('driver_total_earning');
        $totalDeliveries = (clone $delivered)->count();
        $avgPerDelivery = $totalDeliveries > 0 ? (int) round($totalEarnings / $totalDeliveries) : 0;
        $bonus = (int) (clone $delivered)->sum('waiting_bonus');
        $tips = (int) (clone $delivered)->sum('driver_tip');
        $history = (clone $delivered)->latest('delivered_at')->limit(30)->get();

        return response()->json([
            'success' => true,
            'data' => [
                'period' => $period,
                'total_earnings' => $totalEarnings,
                'total_deliveries' => $totalDeliveries,
                'avg_per_delivery' => $avgPerDelivery,
                'bonus' => $bonus,
                'customer_tips' => $tips,
                'online_hours' => (float) $profile->online_hours_total,
                'wallet_balance' => (int) $profile->wallet_balance,
                'cash_collected_hand' => (int) $profile->cash_collected_hand,
                'history' => $history,
            ],
        ]);
    }
}

