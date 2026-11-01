<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LiveTelemetrySession;
use App\Models\Order;
use App\Models\OrderStatusLog;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreCategory;
use App\Services\DriverDispatchService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class VendorAppController extends Controller
{
    private function resolveStore(Request $request): Store
    {
        $store = $request->user()->ownedStore()->with(['category', 'neighborhood'])->first();
        if (! $store) {
            abort(404, 'هیچ فرۆشگایەک بەم هەژمارەوە نەبەستراوەتەوە.');
        }
        return $store;
    }

    public function storeProfile(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request)->load('storeCategories');

        return response()->json([
            'success' => true,
            'data' => $store,
        ]);
    }

    public function updateStore(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        $validated = $request->validate([
            'name_ku' => ['sometimes', 'string', 'max:150'],
            'phone' => ['sometimes', 'string', 'max:30'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'cover_url' => ['nullable', 'string', 'max:500'],
            'open_time' => ['sometimes', 'string', 'max:20'],
            'close_time' => ['sometimes', 'string', 'max:20'],
        ]);

        $store->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'ڕێکخستنەکانی فرۆشگا پاشەکەوتکران.',
            'data' => $store->fresh(),
        ]);
    }

    public function updateOnlineStatus(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        $validated = $request->validate([
            'is_online' => ['required', 'boolean'],
        ]);

        $store->update(['is_online' => $validated['is_online']]);

        return response()->json([
            'success' => true,
            'message' => $store->is_online ? 'فرۆشگا ئێستا ئۆنلاینە.' : 'فرۆشگا ئۆفلاین کرا.',
            'data' => $store,
        ]);
    }

    public function categories(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        return response()->json([
            'success' => true,
            'data' => $store->storeCategories()->withCount('products')->get(),
        ]);
    }

    public function addCategory(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        $validated = $request->validate([
            'name_ku' => ['required', 'string', 'max:100'],
        ]);

        $cat = $store->storeCategories()->create([
            'name_ku' => $validated['name_ku'],
            'sort_order' => $store->storeCategories()->count() + 1,
        ]);

        return response()->json(['success' => true, 'data' => $cat], 201);
    }

    public function deleteCategory(Request $request, StoreCategory $storeCategory): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($storeCategory->store_id !== $store->id) {
            abort(403);
        }
        $storeCategory->delete();

        return response()->json(['success' => true]);
    }

    public function products(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        return response()->json([
            'success' => true,
            'data' => $store->products()->with('storeCategory:id,name_ku')->latest()->get(),
        ]);
    }

    public function addProduct(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        $validated = $request->validate([
            'store_category_id' => ['nullable', 'exists:store_categories,id'],
            'name_ku' => ['required', 'string', 'max:150'],
            'description_ku' => ['nullable', 'string'],
            'description_ar' => ['nullable', 'string'],
            'price' => ['required', 'integer', 'min:0'],
            'discount_price' => ['nullable', 'integer', 'min:0'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_available' => ['nullable', 'boolean'],
        ]);

        $product = $store->products()->create([
            ...$validated,
            'is_available' => $validated['is_available'] ?? true,
        ]);

        return response()->json(['success' => true, 'data' => $product->load('storeCategory:id,name_ku')], 201);
    }

    public function updateProduct(Request $request, Product $product): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($product->store_id !== $store->id) {
            abort(403);
        }

        $validated = $request->validate([
            'store_category_id' => ['nullable', 'exists:store_categories,id'],
            'name_ku' => ['sometimes', 'string', 'max:150'],
            'description_ku' => ['nullable', 'string'],
            'description_ar' => ['nullable', 'string'],
            'price' => ['sometimes', 'integer', 'min:0'],
            'discount_price' => ['nullable', 'integer', 'min:0'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_available' => ['nullable', 'boolean'],
        ]);

        $product->update($validated);

        return response()->json(['success' => true, 'data' => $product->fresh('storeCategory:id,name_ku')]);
    }

    public function toggleProductAvailability(Request $request, Product $product): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($product->store_id !== $store->id) {
            abort(403);
        }

        $product->update(['is_available' => ! $product->is_available]);

        return response()->json(['success' => true, 'data' => $product]);
    }

    public function deleteProduct(Request $request, Product $product): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($product->store_id !== $store->id) {
            abort(403);
        }

        $product->delete();

        return response()->json(['success' => true]);
    }

    public function orders(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        $query = $store->orders()
            ->with(['items', 'customer:id,name,phone', 'driver:id,name,phone'])
            ->latest();

        $filter = (string) $request->string('status', 'active');
        if ($filter === 'active') {
            $query->whereIn('vendor_status', ['pending', 'preparing', 'ready']);
        } elseif ($filter !== 'all') {
            $query->where('vendor_status', $filter);
        }

        // Security: hide plain handover_pin on vendor payload so vendor verifies driver's PIN
        $orders = $query->get()->makeHidden(['handover_pin', 'delivery_pin']);

        return response()->json([
            'success' => true,
            'data' => $orders,
        ]);
    }

    public function acceptOrder(Request $request, Order $order): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($order->store_id !== $store->id) {
            abort(403);
        }

        $old = $order->status;
        $order->update([
            'status' => 'preparing',
            'vendor_status' => 'preparing',
            'accepted_at' => now(),
        ]);

        OrderStatusLog::create([
            'order_id' => $order->id,
            'from_status' => $old,
            'to_status' => 'preparing',
            'actor_id' => $request->user()->id,
            'actor_role' => 'vendor',
            'note' => 'فرۆشیار داواکارییەکەی قبوڵکرد و دەستی بە ئامادەکردن کرد',
        ]);

        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->update(['status' => 'preparing']);

        return response()->json(['success' => true, 'data' => $order->fresh('items')->makeHidden(['handover_pin', 'delivery_pin'])]);
    }

    public function rejectOrder(Request $request, Order $order): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($order->store_id !== $store->id) {
            abort(403);
        }

        $reason = $request->input('reason', 'لەلایەن فرۆشگاوە ڕەتکرایەوە');
        $old = $order->status;

        $order->update([
            'status' => 'rejected',
            'vendor_status' => 'rejected',
            'cancelled_by' => 'vendor',
            'cancellation_reason' => $reason,
            'cancelled_at' => now(),
        ]);

        OrderStatusLog::create([
            'order_id' => $order->id,
            'from_status' => $old,
            'to_status' => 'rejected',
            'actor_id' => $request->user()->id,
            'actor_role' => 'vendor',
            'note' => $reason,
        ]);

        return response()->json(['success' => true, 'data' => $order]);
    }

    public function markReady(Request $request, Order $order, DriverDispatchService $dispatchService): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($order->store_id !== $store->id) {
            abort(403);
        }

        $old = $order->status;
        $order->update([
            'status' => 'ready',
            'vendor_status' => 'ready',
            'ready_at' => now(),
        ]);

        OrderStatusLog::create([
            'order_id' => $order->id,
            'from_status' => $old,
            'to_status' => 'ready',
            'actor_id' => $request->user()->id,
            'actor_role' => 'vendor',
            'note' => 'داواکاری ئامادەیە بۆ وەرگرتن لەلایەن شۆفێرەوە',
        ]);

        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->update(['status' => 'ready']);

        // Auto-assign nearest driver if order does not already have a driver
        $dispatchResult = null;
        if (! $order->driver_id) {
            $dispatchResult = $dispatchService->autoAssignNearestDriver($order, $request->user());
        }

        return response()->json([
            'success' => true,
            'message' => $dispatchResult['message'] ?? 'داواکاری ئامادەکرا و نێردرا بۆ شۆفێر.',
            'dispatch' => $dispatchResult,
            'data' => $order->fresh(['items', 'driver.driverProfile'])->makeHidden(['handover_pin', 'delivery_pin']),
        ]);
    }

    public function dispatchNearestDriver(Request $request, Order $order, DriverDispatchService $dispatchService): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($order->store_id !== $store->id) {
            abort(403);
        }

        $result = $dispatchService->autoAssignNearestDriver($order, $request->user());

        return response()->json([
            'success' => $result['success'],
            'message' => $result['message'],
            'data' => [
                'order' => $order->fresh(['items', 'driver.driverProfile'])->makeHidden(['handover_pin', 'delivery_pin']),
                'driver' => $result['driver'],
                'distance_meters' => $result['distance_meters'],
            ],
        ], $result['success'] ? 200 : 422);
    }

    public function handoverToDriver(Request $request, Order $order): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($order->store_id !== $store->id) {
            abort(403);
        }

        $validated = $request->validate([
            'pin' => ['required', 'string', 'size:4'],
        ]);

        if ($validated['pin'] !== $order->handover_pin) {
            return response()->json([
                'success' => false,
                'message' => 'کۆدی شۆفێر (PIN) هەڵەیە! تکایە دڵنیابەرەوە.',
            ], 422);
        }

        $old = $order->status;
        $order->update([
            'status' => 'picked_up',
            'vendor_status' => 'completed',
            'driver_status' => 'picked_up',
            'picked_up_at' => now(),
        ]);

        OrderStatusLog::create([
            'order_id' => $order->id,
            'from_status' => $old,
            'to_status' => 'picked_up',
            'actor_id' => $request->user()->id,
            'actor_role' => 'vendor',
            'note' => 'بە کۆدی پاراستن ڕادەستی شۆفێر کرا',
        ]);

        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->update([
                'status' => 'picked_up',
                'driver_status' => 'picked_up',
            ]);

        return response()->json([
            'success' => true,
            'message' => 'داواکاری بە سەرکەوتوویی ڕادەستی شۆفێر کرا.',
            'data' => $order->fresh('items')->makeHidden(['handover_pin', 'delivery_pin']),
        ]);
    }

    public function revenueAnalytics(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);
        $period = (string) $request->string('period', 'today');

        $start = match ($period) {
            'week' => Carbon::now()->subDays(6)->startOfDay(),
            'month' => Carbon::now()->subDays(29)->startOfDay(),
            default => Carbon::today(),
        };

        $delivered = $store->orders()
            ->where('status', 'delivered')
            ->where('created_at', '>=', $start);

        $totalSales = (int) (clone $delivered)->sum('subtotal');
        $commissionAmount = (int) (clone $delivered)->sum('commission_amount');
        $netProfit = (int) (clone $delivered)->sum('vendor_net_amount');
        $ordersCount = (clone $delivered)->count();
        $avgTicket = $ordersCount > 0 ? (int) round($totalSales / $ordersCount) : 0;

        $topProducts = DB::table('order_items')
            ->join('orders', 'order_items.order_id', '=', 'orders.id')
            ->where('orders.store_id', $store->id)
            ->where('orders.status', 'delivered')
            ->select(
                'order_items.product_id',
                'order_items.product_name',
                DB::raw('SUM(order_items.quantity) as sold_count'),
                DB::raw('SUM(order_items.line_total) as revenue')
            )
            ->groupBy('order_items.product_id', 'order_items.product_name')
            ->orderByDesc('revenue')
            ->limit(5)
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'period' => $period,
                'commission_rate' => (float) $store->commission_rate,
                'total_sales' => $totalSales,
                'commission_amount' => $commissionAmount,
                'net_profit' => $netProfit,
                'completed_orders_count' => $ordersCount,
                'avg_ticket' => $avgTicket,
                'wallet_balance' => (int) $store->wallet_balance,
                'top_products' => $topProducts,
            ],
        ]);
    }
}

