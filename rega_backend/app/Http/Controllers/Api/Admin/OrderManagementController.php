<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\LiveTelemetrySession;
use App\Models\Order;
use App\Models\OrderStatusLog;
use App\Models\User;
use App\Services\OrderSettlementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OrderManagementController extends Controller
{
    public function __construct(private readonly OrderSettlementService $settlementService) {}

    public function index(Request $request): JsonResponse
    {
        $query = Order::query()
            ->with([
                'store:id,name_ku,name_en,phone,address_ku,logo_url',
                'customer:id,name,phone',
                'driver:id,name,phone',
                'driver.driverProfile:id,user_id,driver_code,motor_type,plate_number',
                'neighborhood:id,name_ku,name_en,delivery_fee',
                'items',
            ]);

        if ($request->filled('status') && $request->string('status') !== 'all') {
            $status = (string) $request->string('status');
            if ($status === 'active') {
                $query->whereNotIn('status', ['delivered', 'cancelled', 'rejected']);
            } elseif ($status === 'in_transit') {
                $query->whereIn('status', ['picked_up', 'on_the_way', 'arrived_customer']);
            } else {
                $query->where('status', $status);
            }
        }

        if ($request->filled('store_id')) {
            $query->where('store_id', $request->integer('store_id'));
        }

        if ($request->filled('driver_id')) {
            $query->where('driver_id', $request->integer('driver_id'));
        }

        if ($request->filled('neighborhood_id')) {
            $query->where('neighborhood_id', $request->integer('neighborhood_id'));
        }

        if ($request->filled('search')) {
            $s = trim((string) $request->string('search'));
            $query->where(function ($q) use ($s) {
                $q->where('order_number', 'ILIKE', "%{$s}%")
                    ->orWhere('customer_name', 'ILIKE', "%{$s}%")
                    ->orWhere('customer_phone', 'ILIKE', "%{$s}%")
                    ->orWhereHas('store', fn ($sq) => $sq->where('name_ku', 'ILIKE', "%{$s}%")->orWhere('name_en', 'ILIKE', "%{$s}%"));
            });
        }

        $orders = $query->latest()->paginate($request->integer('per_page', 25));

        $counts = [
            'all' => Order::count(),
            'active' => Order::whereNotIn('status', ['delivered', 'cancelled', 'rejected'])->count(),
            'pending' => Order::where('status', 'pending')->count(),
            'preparing' => Order::where('status', 'preparing')->count(),
            'ready' => Order::where('status', 'ready')->count(),
            'in_transit' => Order::whereIn('status', ['picked_up', 'on_the_way', 'arrived_customer'])->count(),
            'delivered' => Order::where('status', 'delivered')->count(),
            'cancelled' => Order::whereIn('status', ['cancelled', 'rejected'])->count(),
        ];

        return response()->json([
            'success' => true,
            'counts' => $counts,
            'data' => $orders->items(),
            'meta' => [
                'current_page' => $orders->currentPage(),
                'last_page' => $orders->lastPage(),
                'per_page' => $orders->perPage(),
                'total' => $orders->total(),
            ],
        ]);
    }

    public function show(Order $order): JsonResponse
    {
        $order->load([
            'store.category',
            'store.neighborhood',
            'customer',
            'driver.driverProfile',
            'neighborhood',
            'coupon',
            'items.product',
            'statusLogs.actor:id,name,role',
        ]);

        return response()->json([
            'success' => true,
            'data' => $order,
        ]);
    }

    public function assignDriver(Request $request, Order $order): JsonResponse
    {
        $validated = $request->validate([
            'driver_id' => ['required', 'exists:users,id'],
        ]);

        /** @var User $driver */
        $driver = User::with('driverProfile')->findOrFail($validated['driver_id']);

        if (! $driver->isDriver() || ! $driver->driverProfile) {
            return response()->json([
                'success' => false,
                'message' => 'ئەم بەکارهێنەرە شۆفێر نییە.',
            ], 422);
        }

        DB::transaction(function () use ($order, $driver, $request) {
            $oldDriverStatus = $order->driver_status;

            $order->update([
                'driver_id' => $driver->id,
                'driver_status' => in_array($order->driver_status, ['picked_up', 'on_the_way', 'arrived_customer', 'delivered'], true)
                    ? $order->driver_status
                    : 'driver_assigned',
                'driver_assigned_at' => now(),
            ]);

            OrderStatusLog::create([
                'order_id' => $order->id,
                'from_status' => $oldDriverStatus,
                'to_status' => 'driver_assigned',
                'actor_id' => $request->user()->id,
                'actor_role' => $request->user()->role,
                'note' => "شۆفێر دیاریکرا: {$driver->name} ({$driver->driverProfile->driver_code})",
            ]);

            AppNotification::create([
                'user_id' => $driver->id,
                'target_audience' => 'specific_user',
                'title_ku' => "داواکاری نوێی {$order->order_number} گەیشت",
                'title_en' => "New Order {$order->order_number} Assigned",
                'body_ku' => "داواکارییەک لە {$order->store?->name_ku} بۆت دیاریکرا.",
                'tag' => 'گەیاندن',
                'type' => 'order',
            ]);
        });

        return response()->json([
            'success' => true,
            'message' => 'شۆفێر بە سەرکەوتوویی بۆ داواکارییەکە دیاریکرا.',
            'data' => $order->fresh(['store', 'customer', 'driver.driverProfile', 'items', 'statusLogs.actor']),
        ]);
    }

    public function updateStatus(Request $request, Order $order): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:pending,preparing,ready,picked_up,on_the_way,arrived_customer,delivered,cancelled,rejected'],
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $newStatus = $validated['status'];

        if ($newStatus === 'delivered') {
            $settled = $this->settlementService->markDelivered(
                $order,
                $request->user(),
                $validated['reason'] ?? 'لەلایەن ئەدمینەوە کرایە گەیەندراو'
            );

            return response()->json([
                'success' => true,
                'message' => 'بارودۆخی داواکاری نوێکرایەوە بۆ گەیەندراو و حسابەکان یەکلاکرانەوە.',
                'data' => $settled,
            ]);
        }

        $oldStatus = $order->status;

        $updates = ['status' => $newStatus];
        match ($newStatus) {
            'pending' => $updates += ['vendor_status' => 'pending', 'driver_status' => $order->driver_id ? 'driver_assigned' : 'unassigned'],
            'preparing' => $updates += ['vendor_status' => 'preparing', 'accepted_at' => $order->accepted_at ?? now()],
            'ready' => $updates += ['vendor_status' => 'ready', 'ready_at' => $order->ready_at ?? now()],
            'picked_up' => $updates += ['vendor_status' => 'completed', 'driver_status' => 'picked_up', 'picked_up_at' => $order->picked_up_at ?? now()],
            'on_the_way' => $updates += ['vendor_status' => 'completed', 'driver_status' => 'on_the_way'],
            'arrived_customer' => $updates += ['driver_status' => 'arrived_customer', 'arrived_customer_at' => now()],
            'cancelled' => $updates += [
                'cancelled_at' => now(),
                'cancelled_by' => 'admin',
                'cancellation_reason' => $validated['reason'] ?? 'هەڵوەشێندرایەوە لەلایەن بەڕێوەبەرایەتی',
            ],
            'rejected' => $updates += [
                'vendor_status' => 'rejected',
                'cancelled_at' => now(),
                'cancelled_by' => 'admin',
                'cancellation_reason' => $validated['reason'] ?? 'ڕەتکرایەوە',
            ],
            default => null,
        };

        $order->update($updates);
        $order->refresh();

        OrderStatusLog::create([
            'order_id' => $order->id,
            'from_status' => $oldStatus,
            'to_status' => $newStatus,
            'actor_id' => $request->user()->id,
            'actor_role' => $request->user()->role,
            'note' => $validated['reason'] ?? "بارودۆخ گۆڕدرا بۆ {$newStatus}",
        ]);

        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->update([
                'status' => $newStatus,
                'driver_status' => $order->driver_status,
            ]);

        return response()->json([
            'success' => true,
            'message' => 'بارودۆخی داواکاری بە سەرکەوتوویی نوێکرایەوە.',
            'data' => $order->fresh(['store', 'customer', 'driver.driverProfile', 'items', 'statusLogs.actor']),
        ]);
    }

    public function addWaitingBonus(Request $request, Order $order): JsonResponse
    {
        $validated = $request->validate([
            'waiting_bonus' => ['required', 'integer', 'min:0', 'max:50000'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $bonus = (int) $validated['waiting_bonus'];
        $newDriverEarning = (int) $order->delivery_fee + (int) $order->driver_tip + $bonus;

        $order->update([
            'waiting_bonus' => $bonus,
            'driver_total_earning' => $newDriverEarning,
        ]);

        OrderStatusLog::create([
            'order_id' => $order->id,
            'from_status' => $order->status,
            'to_status' => $order->status,
            'actor_id' => $request->user()->id,
            'actor_role' => $request->user()->role,
            'note' => $validated['note'] ?? "پاداشتی چاوەڕوانی شۆفێر زیادکرا: {$bonus} د.ع",
        ]);

        return response()->json([
            'success' => true,
            'message' => 'پاداشتی چاوەڕوانی بۆ شۆفێر تۆمارکرا.',
            'data' => $order->fresh(['driver.driverProfile', 'statusLogs.actor']),
        ]);
    }

    public function update(Request $request, Order $order): JsonResponse
    {
        $validated = $request->validate([
            'customer_name' => ['sometimes', 'string', 'max:120'],
            'customer_phone' => ['sometimes', 'string', 'max:30'],
            'delivery_address' => ['sometimes', 'string', 'max:255'],
            'customer_notes' => ['nullable', 'string', 'max:500'],
            'delivery_fee' => ['nullable', 'integer', 'min:0'],
            'payment_method' => ['nullable', 'string', 'in:cash,fib,fastpay,wallet'],
            'payment_status' => ['nullable', 'string', 'in:pending,paid,refunded'],
            'status' => ['nullable', 'string'],
        ]);

        if (isset($validated['delivery_fee'])) {
            $diff = (int) $validated['delivery_fee'] - (int) $order->delivery_fee;
            $validated['total_amount'] = (int) $order->total_amount + $diff;
            $validated['driver_total_earning'] = (int) $validated['delivery_fee'] + (int) $order->driver_tip + (int) $order->waiting_bonus;
        }

        $order->update($validated);

        if (! empty($validated['status']) && $validated['status'] !== $order->getOriginal('status')) {
            OrderStatusLog::create([
                'order_id' => $order->id,
                'from_status' => $order->getOriginal('status'),
                'to_status' => $validated['status'],
                'actor_id' => $request->user()->id,
                'actor_role' => $request->user()->role,
                'note' => 'دەستکاریکردنی داواکاری لەلایەن ئەدمین',
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'زانیاری داواکاری نوێکرایەوە.',
            'data' => $order->fresh(['store', 'customer', 'driver.driverProfile', 'items']),
        ]);
    }

    public function destroy(Order $order): JsonResponse
    {
        DB::transaction(function () use ($order) {
            $order->items()->delete();
            $order->statusLogs()->delete();
            LiveTelemetrySession::where('order_id', $order->id)->delete();
            $order->delete();
        });

        return response()->json([
            'success' => true,
            'message' => 'داواکاری بە سەرکەوتوویی سڕایەوە.',
        ]);
    }
}

