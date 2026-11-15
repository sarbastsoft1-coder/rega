<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\DriverProfile;
use App\Models\LiveTelemetrySession;
use App\Models\Order;
use App\Models\OrderStatusLog;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreCategory;
use App\Models\User;
use App\Services\DriverDispatchService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class VendorAppController extends Controller
{
    private function resolveStore(Request $request): Store
    {
        $store = $request->user()->resolveOwnedStore();
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

    /**
     * داشکاندنی گشتی بۆ هەموو بەرهەمەکانی دوکان (٪ لە 0 تا 100؛ 0 = لابردنی داشکاندن).
     */
    public function applyStoreDiscount(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        $validated = $request->validate([
            'percent' => ['required', 'integer', 'min:0', 'max:100'],
        ]);

        $percent = (int) $validated['percent'];
        if ($percent > 0 && $percent % 5 !== 0) {
            return response()->json([
                'success' => false,
                'message' => 'داشکاندن دەبێت بە ٥٪ زیاد بکرێت (٥، ١٠، ١٥، ...).',
            ], 422);
        }

        DB::transaction(function () use ($store, $percent) {
            $products = $store->products()->lockForUpdate()->get();
            foreach ($products as $product) {
                if ($percent <= 0) {
                    $product->update(['discount_price' => null]);
                    continue;
                }
                $newPrice = (int) round($product->price * (100 - $percent) / 100);
                $product->update([
                    'discount_price' => max(0, min($newPrice, $product->price - 1)),
                ]);
            }
            $store->refreshDiscountBadge();
        });

        return response()->json([
            'success' => true,
            'message' => $percent > 0
                ? "داشکاندنی {$percent}% بۆ هەموو بەرهەمەکانی دوکان جێبەجێ کرا."
                : 'داشکاندنی دوکان لابرا.',
            'data' => [
                'percent' => $percent,
                'discount_badge' => $store->fresh()->discount_badge,
                'products' => $store->products()->with('storeCategory:id,name_ku')->latest()->get()->each->makeVisible(['cost_price']),
            ],
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
            'name_ar' => ['nullable', 'string', 'max:100'],
            'name_en' => ['nullable', 'string', 'max:100'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'secondary_image_url' => ['nullable', 'string', 'max:500'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $cat = $store->storeCategories()->create([
            'name_ku' => $validated['name_ku'],
            'name_ar' => $validated['name_ar'] ?? $validated['name_ku'],
            'name_en' => $validated['name_en'] ?? null,
            'image_url' => $validated['image_url'] ?? null,
            'secondary_image_url' => $validated['secondary_image_url'] ?? null,
            'sort_order' => $validated['sort_order'] ?? ($store->storeCategories()->count() + 1),
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
        $products = $store->products()->with('storeCategory:id,name_ku')->latest()->get();
        $products->each->makeVisible(['cost_price']);

        return response()->json([
            'success' => true,
            'data' => $products,
        ]);
    }

    public function uploadMedia(Request $request): JsonResponse
    {
        $this->resolveStore($request);

        $request->validate([
            'file' => ['required', 'file', 'max:10240', 'mimes:jpg,jpeg,png,webp,gif,pdf'],
        ]);

        $path = $request->file('file')->store('uploads', 'public');

        return response()->json([
            'success' => true,
            'message' => 'فایل بە سەرکەوتوویی بارکرا.',
            'data' => [
                'path' => $path,
                'url' => \App\Support\PublicMedia::url($path),
            ],
        ], 201);
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
            'cost_price' => ['required', 'integer', 'min:0'],
            'discount_price' => ['nullable', 'integer', 'min:0'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_available' => ['nullable', 'boolean'],
        ]);

        if ((int) $validated['cost_price'] >= (int) $validated['price']) {
            return response()->json([
                'success' => false,
                'message' => 'نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت.',
            ], 422);
        }

        $product = $store->products()->create([
            ...$validated,
            'is_available' => $validated['is_available'] ?? true,
        ]);

        $store->refreshDiscountBadge();

        return response()->json([
            'success' => true,
            'data' => $product->makeVisible(['cost_price'])->load('storeCategory:id,name_ku'),
        ], 201);
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
            'cost_price' => ['sometimes', 'integer', 'min:0'],
            'discount_price' => ['nullable', 'integer', 'min:0'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_available' => ['nullable', 'boolean'],
        ]);

        $sell = (int) ($validated['price'] ?? $product->price);
        $cost = (int) ($validated['cost_price'] ?? $product->cost_price);
        if ($cost >= $sell) {
            return response()->json([
                'success' => false,
                'message' => 'نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت.',
            ], 422);
        }

        $product->update($validated);
        $store->refreshDiscountBadge();

        return response()->json([
            'success' => true,
            'data' => $product->fresh('storeCategory:id,name_ku')->makeVisible(['cost_price']),
        ]);
    }

    public function toggleProductAvailability(Request $request, Product $product): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($product->store_id !== $store->id) {
            abort(403);
        }

        $product->update(['is_available' => ! $product->is_available]);
        $store->refreshDiscountBadge();

        return response()->json(['success' => true, 'data' => $product]);
    }

    public function deleteProduct(Request $request, Product $product): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($product->store_id !== $store->id) {
            abort(403);
        }

        $product->delete();
        $store->refreshDiscountBadge();

        return response()->json(['success' => true]);
    }

    public function orders(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);

        $query = $store->orders()
            ->with(['items', 'customer:id,name,phone', 'driver:id,name,phone', 'driver.driverProfile'])
            ->latest();

        $filter = (string) $request->string('status', 'active');
        if ($filter === 'active') {
            $query->whereIn('vendor_status', ['pending', 'preparing', 'ready']);
        } elseif ($filter !== 'all') {
            $query->where('vendor_status', $filter);
        }

        $orders = $query->get()->makeHidden(['handover_pin', 'delivery_pin'])->map(function (Order $order) use ($store) {
            $profile = $order->driver?->driverProfile;
            $arr = $order->toArray();
            $arr['driver_lat'] = $order->driver_lat ?? $profile?->current_lat;
            $arr['driver_lng'] = $order->driver_lng ?? $profile?->current_lng;
            $arr['store_lat'] = $store->lat;
            $arr['store_lng'] = $store->lng;
            $arr['customer_lat'] = $order->delivery_lat;
            $arr['customer_lng'] = $order->delivery_lng;
            if (isset($arr['driver']) && is_array($arr['driver'])) {
                $arr['driver']['current_lat'] = $arr['driver_lat'];
                $arr['driver']['current_lng'] = $arr['driver_lng'];
                $arr['driver']['lat'] = $arr['driver_lat'];
                $arr['driver']['lng'] = $arr['driver_lng'];
            }

            return $arr;
        });

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

        if ($order->customer_id) {
            AppNotification::create([
                'user_id' => $order->customer_id,
                'target_audience' => 'specific_user',
                'title_ku' => "فرۆشگا داواکاری {$order->order_number} ی قبوڵکرد",
                'title_en' => "Store accepted order {$order->order_number}",
                'body_ku' => 'داواکارییەکەت لە ئامادەکردندایە. کاتێک نێردرا بۆ گەیاندن دەتوانیت شوێنی ماتۆرسوار ببینیت لەسەر نەخشە.',
                'tag' => 'گەیاندن',
                'type' => 'order',
            ]);
        }

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
            'is_profit_realized' => false,
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

    public function markReady(Request $request, Order $order): JsonResponse
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

        // Manual flow: do NOT auto-assign a driver. Admin/vendor assigns via button.
        $order = $order->fresh(['items', 'driver.driverProfile']);

        if ($order->customer_id) {
            AppNotification::create([
                'user_id' => $order->customer_id,
                'target_audience' => 'specific_user',
                'title_ku' => "داواکاری {$order->order_number} ئامادەیە",
                'title_en' => "Order {$order->order_number} is ready",
                'body_ku' => 'فرۆشگا داواکارییەکەی ئامادەکرد. چاوەڕوانی دیاریکردنی شۆفێر بکە.',
                'tag' => 'گەیاندن',
                'type' => 'order',
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'داواکاری ئامادەکرا. شۆفێر دەبێت بە دوگمە دیاری بکرێت (ئادمین / فرۆشگا).',
            'data' => $order->makeHidden(['handover_pin', 'delivery_pin']),
            'dispatch' => [
                'success' => false,
                'message' => 'خۆکار دیاریکردنی شۆفێر کوژێنرایەوە — تەنها بە دوگمە.',
                'distance_meters' => null,
            ],
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

    public function assignDriver(Request $request, Order $order): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($order->store_id !== $store->id) {
            abort(403);
        }

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

        DB::transaction(function () use ($order, $driver, $request, $store) {
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
                'actor_role' => 'vendor',
                'note' => "فرۆشیار شۆفێری دیاریکرد: {$driver->name} ({$driver->driverProfile->driver_code})",
            ]);

            AppNotification::create([
                'user_id' => $driver->id,
                'target_audience' => 'specific_user',
                'title_ku' => "داواکاری نوێی {$order->order_number} گەیشت",
                'title_en' => "New Order {$order->order_number} Assigned",
                'body_ku' => "داواکارییەک لە {$store->name_ku} بۆت دیاریکرا — شوێنی فرۆشگا لەسەر نەخشە دەرکەوتووە.",
                'tag' => 'گەیاندن',
                'type' => 'order',
            ]);

            // Push vendor GPS onto live telemetry so driver map shows the store pin.
            LiveTelemetrySession::updateOrCreate(
                ['order_ref' => $order->order_number],
                [
                    'order_id' => $order->id,
                    'status' => $order->status,
                    'driver_status' => 'driver_assigned',
                    'store_name' => $store->name_ku,
                    'store_address' => $store->address_ku,
                    'store_phone' => $store->phone,
                    'store_lat' => (float) ($store->lat ?? 34.6836),
                    'store_lng' => (float) ($store->lng ?? 45.3189),
                    'customer_name' => $order->customer_name,
                    'customer_address' => $order->delivery_address,
                    'customer_phone' => $order->customer_phone,
                    'customer_lat' => $order->delivery_lat,
                    'customer_lng' => $order->delivery_lng,
                    'driver_name' => $driver->name,
                    'driver_phone' => $driver->phone,
                    'vehicle_label' => $driver->driverProfile?->motor_type,
                    'driver_lat' => $driver->driverProfile?->current_lat,
                    'driver_lng' => $driver->driverProfile?->current_lng,
                ]
            );
        });

        return response()->json([
            'success' => true,
            'message' => 'ماتۆرسوار بە سەرکەوتوویی دیاریکرا.',
            'data' => $order->fresh(['items', 'store:id,name_ku,phone,address_ku,lat,lng', 'driver.driverProfile'])->makeHidden(['handover_pin', 'delivery_pin']),
        ]);
    }

    /** All verified drivers (online first, nearest to store) for vendor assign + map. */
    public function nearbyDrivers(
        Request $request,
        DriverDispatchService $dispatchService,
        \App\Services\DriverWorkloadService $workload,
    ): JsonResponse {
        $store = $this->resolveStore($request);
        $storeLat = (float) ($store->lat ?? 34.6836);
        $storeLng = (float) ($store->lng ?? 45.3189);

        $todayDelivered = $workload->todayDeliveredCounts();
        $todayAssigned = $workload->todayAssignedCounts();

        $drivers = DriverProfile::query()
            ->with('user:id,name,phone')
            ->where('is_verified', true)
            ->get()
            ->map(function (DriverProfile $d) use ($storeLat, $storeLng, $dispatchService, $todayDelivered, $todayAssigned) {
                $lat = $d->current_lat !== null ? (float) $d->current_lat : null;
                $lng = $d->current_lng !== null ? (float) $d->current_lng : null;
                $meters = ($lat !== null && $lng !== null)
                    ? $dispatchService->calculateHaversineDistanceMeters($storeLat, $storeLng, $lat, $lng)
                    : null;

                return [
                    'id' => $d->id,
                    'user_id' => $d->user_id,
                    'driver_code' => $d->driver_code,
                    'name' => $d->user?->name,
                    'phone' => $d->user?->phone,
                    'is_online' => (bool) $d->is_online,
                    'lat' => $lat,
                    'lng' => $lng,
                    'current_lat' => $lat,
                    'current_lng' => $lng,
                    'heading' => $d->heading,
                    'speed_kmh' => $d->speed_kmh,
                    'distance_meters' => $meters,
                    'today_deliveries' => (int) ($todayDelivered[$d->user_id] ?? 0),
                    'today_orders' => (int) ($todayAssigned[$d->user_id] ?? 0),
                    'total_deliveries' => (int) $d->total_deliveries,
                    'motor_type' => $d->motor_type,
                    'plate_number' => $d->plate_number,
                    'last_ping_at' => optional($d->last_ping_at)?->toIso8601String(),
                ];
            })
            ->sort(function ($a, $b) {
                $ao = ! empty($a['is_online']) ? 0 : 1;
                $bo = ! empty($b['is_online']) ? 0 : 1;
                if ($ao !== $bo) {
                    return $ao <=> $bo;
                }
                $ad = $a['distance_meters'] ?? PHP_INT_MAX;
                $bd = $b['distance_meters'] ?? PHP_INT_MAX;
                if ($ad != $bd) {
                    return $ad <=> $bd;
                }

                return ((int) ($a['today_orders'] ?? 0)) <=> ((int) ($b['today_orders'] ?? 0));
            })
            ->values();

        return response()->json([
            'success' => true,
            'data' => [
                'store' => [
                    'id' => $store->id,
                    'name' => $store->name_ku,
                    'lat' => $storeLat,
                    'lng' => $storeLng,
                ],
                'drivers' => $drivers,
                'online_count' => $drivers->where('is_online', true)->count(),
                'server_time' => now()->toIso8601String(),
            ],
        ]);
    }

    public function handoverToDriver(Request $request, Order $order): JsonResponse
    {
        $store = $this->resolveStore($request);
        if ($order->store_id !== $store->id) {
            abort(403);
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
            'note' => 'ڕادەستی شۆفێر کرا',
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
            ->where('is_profit_realized', true)
            ->where('created_at', '>=', $start);

        $totalSales = (int) (clone $delivered)->sum('subtotal');
        $totalCosts = (int) (clone $delivered)->sum('total_product_cost');
        $grossProfit = (int) (clone $delivered)->sum('total_gross_profit');
        $adminShare = (int) (clone $delivered)->sum('admin_profit_amount');
        $sellerShare = (int) (clone $delivered)->sum('seller_profit_amount');
        $commissionAmount = $adminShare;
        $netProfit = (int) (clone $delivered)->sum('vendor_net_amount');
        $ordersCount = (clone $delivered)->count();
        $avgTicket = $ordersCount > 0 ? (int) round($totalSales / $ordersCount) : 0;

        $topProducts = DB::table('order_items')
            ->join('orders', 'order_items.order_id', '=', 'orders.id')
            ->where('orders.store_id', $store->id)
            ->where('orders.status', 'delivered')
            ->where('orders.is_profit_realized', true)
            ->select(
                'order_items.product_id',
                'order_items.product_name',
                DB::raw('SUM(order_items.quantity) as sold_count'),
                DB::raw('SUM(order_items.line_total) as revenue'),
                DB::raw('SUM(order_items.line_cost) as costs'),
                DB::raw('SUM(order_items.seller_share) as seller_share')
            )
            ->groupBy('order_items.product_id', 'order_items.product_name')
            ->orderByDesc('revenue')
            ->limit(5)
            ->get();

        $daily = $store->orders()
            ->where('status', 'delivered')
            ->where('is_profit_realized', true)
            ->where('created_at', '>=', $start)
            ->selectRaw('DATE(created_at) as day')
            ->selectRaw('COUNT(*) as orders_count')
            ->selectRaw('COALESCE(SUM(subtotal),0) as sales')
            ->selectRaw('COALESCE(SUM(total_gross_profit),0) as gross_profit')
            ->selectRaw('COALESCE(SUM(admin_profit_amount),0) as admin_owed')
            ->selectRaw('COALESCE(SUM(seller_profit_amount),0) as seller_share')
            ->groupBy('day')
            ->orderByDesc('day')
            ->limit(31)
            ->get();

        $todayQ = $store->orders()
            ->where('status', 'delivered')
            ->where('is_profit_realized', true)
            ->whereDate('created_at', Carbon::today());

        $commissionRate = app(\App\Services\OrderProfitService::class)->globalCommissionPercentage();

        return response()->json([
            'success' => true,
            'data' => [
                'period' => $period,
                'commission_rate' => $commissionRate,
                'total_sales' => $totalSales,
                'total_product_costs' => $totalCosts,
                'gross_profit' => $grossProfit,
                'admin_share' => $adminShare,
                'admin_owed' => $adminShare,
                'seller_share' => $sellerShare,
                'commission_amount' => $commissionAmount,
                'net_profit' => $sellerShare,
                'vendor_net_amount' => $netProfit,
                'completed_orders_count' => $ordersCount,
                'avg_ticket' => $avgTicket,
                'wallet_balance' => (int) $store->wallet_balance,
                'today_sales' => (int) (clone $todayQ)->sum('subtotal'),
                'today_gross_profit' => (int) (clone $todayQ)->sum('total_gross_profit'),
                'today_admin_owed' => (int) (clone $todayQ)->sum('admin_profit_amount'),
                'today_seller_share' => (int) (clone $todayQ)->sum('seller_profit_amount'),
                'formula_note' => 'ئەدمین = قازانجی سەرەتایی × ڕێژە٪ — نموونە: قازانج ٢٬٠٠٠ × ١٠٪ = ٢٠٠ د.ع',
                'daily_breakdown' => $daily,
                'top_products' => $topProducts,
            ],
        ]);
    }
}

