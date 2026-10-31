<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Banner;
use App\Models\Category;
use App\Models\Coupon;
use App\Models\CustomerAddress;
use App\Models\Neighborhood;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusLog;
use App\Models\PlatformSetting;
use App\Models\Product;
use App\Models\Store;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PublicAndCustomerController extends Controller
{
    public function bootstrap(): JsonResponse
    {
        $neighborhoods = Neighborhood::where('is_active', true)->orderBy('sort_order')->get();
        $categories = Category::where('is_active', true)->orderBy('sort_order')->get();
        $banners = Banner::where('is_active', true)->with(['store:id,name_ku,slug', 'category:id,name_ku,slug'])->orderBy('sort_order')->get();
        $featuredStores = Store::where('is_approved', true)
            ->with(['category:id,name_ku,name_en', 'neighborhood:id,name_ku'])
            ->orderByDesc('is_featured')
            ->orderByDesc('rating')
            ->limit(20)
            ->get();

        $settingsRows = PlatformSetting::whereIn('group', ['public', 'general', 'support'])->get();
        $publicSettings = [];
        foreach ($settingsRows as $row) {
            $val = $row->value;
            $publicSettings[$row->key] = (is_array($val) && array_key_exists('val', $val) && count($val) === 1) ? $val['val'] : $val;
        }

        return response()->json([
            'success' => true,
            'data' => [
                'neighborhoods' => $neighborhoods,
                'categories' => $categories,
                'banners' => $banners,
                'stores' => $featuredStores,
                'settings' => $publicSettings,
            ],
        ]);
    }

    public function stores(Request $request): JsonResponse
    {
        $query = Store::query()
            ->where('is_approved', true)
            ->with(['category:id,slug,name_ku,name_ar,name_en', 'neighborhood:id,name_ku,delivery_fee']);

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->integer('category_id'));
        }

        if ($request->filled('category')) {
            $catName = trim((string) $request->string('category'));
            $query->whereHas('category', fn ($q) => $q->where('name_ku', $catName)->orWhere('slug', $catName));
        }

        if ($request->boolean('has_discount')) {
            $query->whereNotNull('discount_badge')->where('discount_badge', '!=', '');
        }

        if ($request->filled('search')) {
            $s = trim((string) $request->string('search'));
            $query->where(fn ($q) => $q->where('name_ku', 'ILIKE', "%{$s}%")->orWhere('name_en', 'ILIKE', "%{$s}%"));
        }

        return response()->json([
            'success' => true,
            'data' => $query->orderByDesc('is_online')->orderByDesc('rating')->get(),
        ]);
    }

    public function storeDetails(Store $store): JsonResponse
    {
        $store->load([
            'category',
            'neighborhood',
            'storeCategories.products' => fn ($q) => $q->where('is_available', true),
            'products' => fn ($q) => $q->where('is_available', true)->with('storeCategory:id,name_ku'),
        ]);

        return response()->json([
            'success' => true,
            'data' => $store,
        ]);
    }

    public function search(Request $request): JsonResponse
    {
        $q = trim((string) $request->string('q', ''));
        if ($q === '') {
            return response()->json([
                'success' => true,
                'data' => [
                    'popular_keywords' => ['کەباب', 'شاوڕمە', 'پیتزا', 'قوزی', 'سوپەرمارکێت', 'میوە', 'شیرینی', 'برنج', 'دۆ', 'کۆسمەتیک'],
                    'categories' => Category::where('is_active', true)->orderBy('sort_order')->get(),
                    'stores' => [],
                    'products' => [],
                ],
            ]);
        }

        $categories = Category::where('is_active', true)
            ->where(fn ($c) => $c->where('name_ku', 'ILIKE', "%{$q}%")->orWhere('name_en', 'ILIKE', "%{$q}%"))
            ->get();

        $stores = Store::where('is_approved', true)
            ->with('category:id,name_ku')
            ->where(fn ($s) => $s->where('name_ku', 'ILIKE', "%{$q}%")->orWhere('name_en', 'ILIKE', "%{$q}%"))
            ->limit(20)
            ->get();

        $products = Product::where('is_available', true)
            ->with(['store:id,name_ku,is_online', 'storeCategory:id,name_ku'])
            ->where(fn ($p) => $p->where('name_ku', 'ILIKE', "%{$q}%")->orWhere('name_en', 'ILIKE', "%{$q}%"))
            ->limit(30)
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'categories' => $categories,
                'stores' => $stores,
                'products' => $products,
            ],
        ]);
    }

    public function validateCoupon(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => ['required', 'string'],
            'store_id' => ['nullable', 'integer'],
            'subtotal' => ['required', 'integer', 'min:0'],
            'delivery_fee' => ['nullable', 'integer', 'min:0'],
        ]);

        $coupon = Coupon::where('code', strtoupper(trim($validated['code'])))
            ->where('is_active', true)
            ->first();

        if (! $coupon) {
            return response()->json(['success' => false, 'message' => 'کۆدی داشکاندن بوونی نییە یان بەسەرچووە.'], 404);
        }

        if ($coupon->store_id !== null && isset($validated['store_id']) && (int) $coupon->store_id !== (int) $validated['store_id']) {
            return response()->json(['success' => false, 'message' => 'ئەم کۆدە تەنها بۆ فرۆشگایەکی دیاریکراوە.'], 422);
        }

        $discount = $coupon->calculateDiscount((int) $validated['subtotal'], (int) ($validated['delivery_fee'] ?? 1500));
        if ($discount <= 0) {
            return response()->json(['success' => false, 'message' => 'مەرجەکانی کۆدی داشکاندن جێبەجێ نەبوون.'], 422);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'coupon' => $coupon,
                'discount_amount' => $discount,
            ],
        ]);
    }

    public function placeOrder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'store_id' => ['required', 'exists:stores,id'],
            'neighborhood_id' => ['nullable', 'exists:neighborhoods,id'],
            'delivery_address' => ['required', 'string', 'max:255'],
            'delivery_lat' => ['nullable', 'numeric'],
            'delivery_lng' => ['nullable', 'numeric'],
            'payment_method' => ['nullable', 'string', 'in:cash,fib,fastpay,wallet'],
            'coupon_code' => ['nullable', 'string'],
            'driver_tip' => ['nullable', 'integer', 'min:0'],
            'customer_notes' => ['nullable', 'string', 'max:500'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.special_notes' => ['nullable', 'string', 'max:255'],
        ]);

        $user = $request->user();
        $store = Store::findOrFail($validated['store_id']);

        if (! $store->is_online || ! $store->is_approved) {
            return response()->json([
                'success' => false,
                'message' => 'فرۆشگاکە لە ئێستادا داخراوە.',
            ], 422);
        }

        $order = DB::transaction(function () use ($validated, $user, $store) {
            $neighborhood = isset($validated['neighborhood_id'])
                ? Neighborhood::find($validated['neighborhood_id'])
                : null;

            $deliveryFee = $neighborhood ? (int) $neighborhood->delivery_fee : (int) $store->base_delivery_fee;

            $subtotal = 0;
            $preparedItems = [];

            foreach ($validated['items'] as $entry) {
                $product = Product::where('store_id', $store->id)->findOrFail($entry['product_id']);
                $unitPrice = $product->effectivePrice();
                $qty = (int) $entry['quantity'];
                $lineTotal = $unitPrice * $qty;
                $subtotal += $lineTotal;

                $preparedItems[] = [
                    'product_id' => $product->id,
                    'product_name' => $product->name_ku,
                    'product_image' => $product->image_url,
                    'unit_price' => $unitPrice,
                    'quantity' => $qty,
                    'line_total' => $lineTotal,
                    'special_notes' => $entry['special_notes'] ?? null,
                ];
            }

            $coupon = null;
            $discountAmount = 0;
            if (! empty($validated['coupon_code'])) {
                $coupon = Coupon::where('code', strtoupper(trim($validated['coupon_code'])))
                    ->where('is_active', true)
                    ->first();
                if ($coupon && ($coupon->store_id === null || (int) $coupon->store_id === (int) $store->id)) {
                    $discountAmount = $coupon->calculateDiscount($subtotal, $deliveryFee);
                    if ($discountAmount > 0) {
                        $coupon->increment('used_count');
                    }
                }
            }

            $tip = (int) ($validated['driver_tip'] ?? 0);
            $totalAmount = max(0, $subtotal + $deliveryFee + $tip - $discountAmount);

            $commissionRate = (float) $store->commission_rate;
            $commissionAmount = (int) round($subtotal * ($commissionRate / 100));
            $vendorNetAmount = max(0, $subtotal - $commissionAmount);
            $driverTotalEarning = $deliveryFee + $tip;

            $nextSeq = 10000 + Order::count() + 1;
            $orderNumber = 'RA-' . $nextSeq;
            while (Order::where('order_number', $orderNumber)->exists()) {
                $orderNumber = 'RA-' . random_int(10001, 99999);
            }

            $handoverPin = (string) random_int(1000, 9999);
            $deliveryPin = (string) random_int(1000, 9999);

            $created = Order::create([
                'order_number' => $orderNumber,
                'customer_id' => $user->id,
                'store_id' => $store->id,
                'neighborhood_id' => $neighborhood?->id,
                'coupon_id' => $discountAmount > 0 ? $coupon?->id : null,
                'status' => 'pending',
                'vendor_status' => 'pending',
                'driver_status' => 'unassigned',
                'handover_pin' => $handoverPin,
                'delivery_pin' => $deliveryPin,
                'subtotal' => $subtotal,
                'discount_amount' => $discountAmount,
                'delivery_fee' => $deliveryFee,
                'driver_tip' => $tip,
                'waiting_bonus' => 0,
                'total_amount' => $totalAmount,
                'commission_rate' => $commissionRate,
                'commission_amount' => $commissionAmount,
                'vendor_net_amount' => $vendorNetAmount,
                'driver_total_earning' => $driverTotalEarning,
                'payment_method' => $validated['payment_method'] ?? 'cash',
                'payment_status' => 'pending',
                'customer_name' => $user->name,
                'customer_phone' => $user->phone,
                'delivery_address' => $validated['delivery_address'],
                'delivery_lat' => $validated['delivery_lat'] ?? $neighborhood?->center_lat ?? 34.6850,
                'delivery_lng' => $validated['delivery_lng'] ?? $neighborhood?->center_lng ?? 45.3200,
                'customer_notes' => $validated['customer_notes'] ?? null,
            ]);

            foreach ($preparedItems as $itemData) {
                OrderItem::create(['order_id' => $created->id, ...$itemData]);
            }

            OrderStatusLog::create([
                'order_id' => $created->id,
                'from_status' => null,
                'to_status' => 'pending',
                'actor_id' => $user->id,
                'actor_role' => 'customer',
                'note' => 'داواکاری نوێ لەلایەن کڕیارەوە نێردرا',
            ]);

            return $created->load(['items', 'store:id,name_ku,name_en,phone,lat,lng', 'neighborhood']);
        });

        return response()->json([
            'success' => true,
            'message' => 'داواکارییەکەت بە سەرکەوتوویی نێردرا.',
            'data' => $order,
        ], 201);
    }

    public function customerOrders(Request $request): JsonResponse
    {
        $orders = $request->user()
            ->customerOrders()
            ->with([
                'items',
                'store:id,name_ku,name_en,phone,cover_url,lat,lng',
                'driver:id,name,phone',
                'neighborhood:id,name_ku,name_en',
            ])
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => $orders,
        ]);
    }

    public function trackOrder(Request $request, Order $order): JsonResponse
    {
        if ($order->customer_id !== $request->user()->id && ! $request->user()->isAdmin()) {
            abort(403);
        }

        $order->load(['store:id,name_ku,phone,lat,lng', 'driver.driverProfile', 'items', 'statusLogs']);

        return response()->json([
            'success' => true,
            'data' => [
                'order' => $order,
                'tracking' => [
                    'store_lat' => $order->store?->lat ?? 34.6836,
                    'store_lng' => $order->store?->lng ?? 45.3189,
                    'customer_lat' => $order->delivery_lat ?? 34.6880,
                    'customer_lng' => $order->delivery_lng ?? 45.3230,
                    'driver_lat' => $order->driver?->driverProfile?->current_lat ?? 34.6855,
                    'driver_lng' => $order->driver?->driverProfile?->current_lng ?? 45.3210,
                    'driver_name' => $order->driver?->name,
                    'driver_phone' => $order->driver?->phone,
                    'eta_minutes' => 12,
                ],
            ],
        ]);
    }

    public function addresses(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $request->user()->addresses()->with('neighborhood')->get(),
        ]);
    }

    public function storeAddress(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'neighborhood_id' => ['nullable', 'exists:neighborhoods,id'],
            'label' => ['nullable', 'string', 'max:60'],
            'address_line' => ['required', 'string', 'max:255'],
            'landmark' => ['nullable', 'string', 'max:255'],
            'lat' => ['nullable', 'numeric'],
            'lng' => ['nullable', 'numeric'],
            'is_default' => ['nullable', 'boolean'],
        ]);

        if (! empty($validated['is_default'])) {
            $request->user()->addresses()->update(['is_default' => false]);
        }

        $address = $request->user()->addresses()->create([
            'neighborhood_id' => $validated['neighborhood_id'] ?? null,
            'label' => $validated['label'] ?? 'ماڵەوە',
            'address_line' => $validated['address_line'],
            'landmark' => $validated['landmark'] ?? null,
            'lat' => $validated['lat'] ?? 34.6840,
            'lng' => $validated['lng'] ?? 45.3200,
            'is_default' => $validated['is_default'] ?? false,
        ]);

        return response()->json([
            'success' => true,
            'data' => $address->load('neighborhood'),
        ], 201);
    }

    public function deleteAddress(Request $request, CustomerAddress $address): JsonResponse
    {
        if ($address->user_id !== $request->user()->id) {
            abort(403);
        }
        $address->delete();

        return response()->json(['success' => true]);
    }

    public function toggleFavorite(Request $request, Store $store): JsonResponse
    {
        $changes = $request->user()->favoriteStores()->toggle($store->id);

        return response()->json([
            'success' => true,
            'is_favorited' => ! empty($changes['attached']),
        ]);
    }

    public function notifications(Request $request): JsonResponse
    {
        $userId = $request->user()?->id;

        $list = AppNotification::query()
            ->with('store:id,name_ku,name_en,cover_url')
            ->where(function ($q) use ($userId) {
                $q->whereIn('target_audience', ['all', 'customers']);
                if ($userId) {
                    $q->orWhere('user_id', $userId);
                }
            })
            ->latest()
            ->limit(50)
            ->get();

        return response()->json([
            'success' => true,
            'data' => $list,
        ]);
    }
}

