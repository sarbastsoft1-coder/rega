<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderStatusLog;
use App\Models\PlatformSetting;
use App\Models\SupportTicket;
use App\Services\OrderSettlementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
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

    public function profile(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->resolveDriverProfile($request),
        ]);
    }

    public function updateStatus(Request $request): JsonResponse
    {
        $profile = $this->resolveDriverProfile($request);
        $validated = $request->validate([
            'is_online' => ['required', 'boolean'],
        ]);

        $goingOnline = (bool) $validated['is_online'];

        if (! $goingOnline && $profile->is_online && $profile->online_since) {
            $minutes = max(0, $profile->online_since->diffInMinutes(now()));
            $hoursAdded = round($minutes / 60, 2);
            $profile->update([
                'is_online' => false,
                'online_hours_total' => (float) $profile->online_hours_total + $hoursAdded,
                'online_since' => null,
            ]);
        } elseif ($goingOnline) {
            $profile->update([
                'is_online' => true,
                'online_since' => $profile->online_since ?? now(),
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => $profile->fresh(['user', 'documents']),
        ]);
    }

    public function updateLocation(Request $request): JsonResponse
    {
        $profile = $this->resolveDriverProfile($request);
        $validated = $request->validate([
            'lat' => ['required', 'numeric'],
            'lng' => ['required', 'numeric'],
        ]);

        $profile->update([
            'current_lat' => $validated['lat'],
            'current_lng' => $validated['lng'],
        ]);

        return response()->json(['success' => true]);
    }

    public function activeOrder(Request $request): JsonResponse
    {
        $order = Order::query()
            ->where('driver_id', $request->user()->id)
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->with(['items', 'store:id,name_ku,phone,address_ku,lat,lng', 'customer:id,name,phone'])
            ->latest()
            ->first();

        if ($order) {
            // Driver sees handover_pin (to give to vendor), NOT delivery_pin (customer holds delivery_pin)
            $order->makeHidden(['delivery_pin']);
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

        $orders = $query->get()->makeHidden(['delivery_pin']);

        return response()->json([
            'success' => true,
            'data' => $orders,
        ]);
    }

    public function advanceOrderStatus(Request $request, Order $order): JsonResponse
    {
        if ($order->driver_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'driver_status' => ['required', 'string', 'in:driver_arriving_pickup,arrived_pickup,picked_up,on_the_way,arrived_customer'],
        ]);

        $nextDriverStatus = $validated['driver_status'];
        $oldStatus = $order->driver_status;

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
            'from_status' => $oldStatus,
            'to_status' => $nextDriverStatus,
            'actor_id' => $request->user()->id,
            'actor_role' => 'driver',
            'note' => "شۆفێر بارودۆخی گۆڕی بۆ {$nextDriverStatus}",
        ]);

        return response()->json([
            'success' => true,
            'data' => $order->fresh(['items', 'store:id,name_ku,phone,address_ku,lat,lng'])->makeHidden(['delivery_pin']),
        ]);
    }

    public function verifyDeliveryPin(Request $request, Order $order): JsonResponse
    {
        if ($order->driver_id !== $request->user()->id) {
            abort(403);
        }

        $validated = $request->validate([
            'pin' => ['required', 'string', 'size:4'],
        ]);

        if ($validated['pin'] !== $order->delivery_pin) {
            return response()->json([
                'success' => false,
                'message' => 'کۆدی پاراستنی کڕیار هەڵەیە! تکایە دووبارە دڵنیابەرەوە.',
            ], 422);
        }

        $settled = $this->settlementService->markDelivered(
            $order,
            $request->user(),
            'بە کۆدی پاراستنی ٤ ژمارەیی کڕیار گەیاندن تەواوکرا'
        );

        return response()->json([
            'success' => true,
            'message' => 'گەیاندن بە سەرکەوتوویی تەواوکرا و کرێ خرایە سەر باڵانسەکەت.',
            'data' => $settled,
        ]);
    }

    public function claimWaitingBonus(Request $request, Order $order): JsonResponse
    {
        if ($order->driver_id !== $request->user()->id) {
            abort(403);
        }

        $threshold = (int) PlatformSetting::getValue('waiting_bonus_threshold_minutes', 15);
        $bonusAmount = (int) PlatformSetting::getValue('waiting_bonus_amount', 1000);

        $waitedMinutes = $order->arrived_pickup_at
            ? (int) $order->arrived_pickup_at->diffInMinutes($order->picked_up_at ?? now())
            : (int) $request->integer('waited_minutes', 0);

        if ($waitedMinutes < $threshold) {
            return response()->json([
                'success' => false,
                'message' => "کاتی چاوەڕوانی ({$waitedMinutes} خولەک) کەمترە لە {$threshold} خولەک.",
            ], 422);
        }

        $order->update([
            'waiting_bonus' => $bonusAmount,
            'driver_total_earning' => (int) $order->delivery_fee + (int) $order->driver_tip + $bonusAmount,
        ]);

        return response()->json([
            'success' => true,
            'message' => "پاداشتی چاوەڕوانی ({$bonusAmount} د.ع) بۆت هەژمارکرا.",
            'data' => $order->fresh(),
        ]);
    }

    public function requestCancellation(Request $request, Order $order): JsonResponse
    {
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

