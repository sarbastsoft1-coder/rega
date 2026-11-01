<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Banner;
use App\Models\Category;
use App\Models\Coupon;
use App\Models\CustomerAddress;
use App\Models\DriverProfile;
use App\Models\LiveTelemetrySession;
use App\Models\Neighborhood;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusLog;
use App\Models\PlatformSetting;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
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

            $sLat = (float) ($store->lat ?? 34.6836);
            $sLng = (float) ($store->lng ?? 45.3189);
            $cLat = (float) ($created->delivery_lat ?? 34.6912);
            $cLng = (float) ($created->delivery_lng ?? 45.3264);

            LiveTelemetrySession::updateOrCreate(
                ['order_ref' => $created->order_number],
                [
                    'order_id' => $created->id,
                    'status' => 'pending',
                    'driver_status' => 'unassigned',
                    'store_name' => $store->name_ku,
                    'store_address' => $store->address_ku,
                    'store_phone' => $store->phone,
                    'store_lat' => $sLat,
                    'store_lng' => $sLng,
                    'customer_name' => $created->customer_name,
                    'customer_address' => $created->delivery_address,
                    'customer_phone' => $created->customer_phone,
                    'customer_lat' => $cLat,
                    'customer_lng' => $cLng,
                    'driver_name' => 'کاروان محەمەد',
                    'driver_phone' => '07702001001',
                    'vehicle_label' => 'KLR-402',
                    'driver_lat' => $sLat - 0.0035,
                    'driver_lng' => $sLng - 0.0040,
                    'driver_heading' => 45.0,
                    'driver_speed_kmh' => 28.0,
                    'eta_seconds' => 170,
                    'distance_remaining_meters' => 1480,
                    'progress_permille' => 0,
                    'delivery_pin' => $created->delivery_pin,
                    'handover_pin' => $created->handover_pin,
                    'total_amount' => $created->total_amount,
                    'delivery_fee' => $created->delivery_fee,
                    'driver_tip' => $created->driver_tip,
                    'items_json' => $preparedItems,
                    'route_polyline' => [
                        [$sLat - 0.0035, $sLng - 0.0040],
                        [$sLat, $sLng],
                        [$cLat, $cLng],
                    ],
                ]
            );

            return $created->load(['items', 'store:id,name_ku,name_en,phone,lat,lng', 'neighborhood']);
        });

        return response()->json([
            'success' => true,
            'message' => 'داواکارییەکەت بە سەرکەوتوویی نێردرا.',
            'data' => $order,
        ], 201);
    }

    /**
     * Seamless order creation from Customer App (`rega`), supporting both Sanctum-authenticated
     * and phone/guest checkout, resolving stores & products by ID or name.
     */
    public function publicPlaceOrder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'store_id' => ['nullable', 'integer'],
            'store_name' => ['nullable', 'string', 'max:150'],
            'neighborhood_id' => ['nullable', 'integer'],
            'neighborhood_name' => ['nullable', 'string', 'max:120'],
            'customer_name' => ['nullable', 'string', 'max:120'],
            'customer_phone' => ['nullable', 'string', 'max:30'],
            'delivery_address' => ['required', 'string', 'max:255'],
            'delivery_lat' => ['nullable', 'numeric'],
            'delivery_lng' => ['nullable', 'numeric'],
            'delivery_fee' => ['nullable', 'integer', 'min:0'],
            'payment_method' => ['nullable', 'string'],
            'coupon_code' => ['nullable', 'string'],
            'driver_tip' => ['nullable', 'integer', 'min:0'],
            'customer_notes' => ['nullable', 'string', 'max:500'],
            'items' => ['required', 'array', 'min:1'],
        ]);

        $authUser = $request->user('sanctum');
        if (! $authUser) {
            $phone = preg_replace('/\s+/', '', $validated['customer_phone'] ?? '07703001001');
            if ($phone === '') {
                $phone = '07703001001';
            }
            $authUser = User::firstOrCreate(
                ['phone' => $phone],
                [
                    'name' => $validated['customer_name'] ?? 'سەربەست عەلی',
                    'password' => 'password123',
                    'role' => 'customer',
                    'language' => 'ku',
                    'is_active' => true,
                ]
            );
        }

        $store = null;
        if (! empty($validated['store_id'])) {
            $store = Store::find($validated['store_id']);
        }
        if (! $store && ! empty($validated['store_name'])) {
            $sn = trim($validated['store_name']);
            $store = Store::where('name_ku', 'ILIKE', "%{$sn}%")
                ->orWhere('name_en', 'ILIKE', "%{$sn}%")
                ->first();
        }
        if (! $store) {
            $store = Store::where('is_approved', true)->orderByDesc('is_online')->firstOrFail();
        }

        $order = DB::transaction(function () use ($validated, $authUser, $store) {
            $neighborhood = null;
            if (! empty($validated['neighborhood_id'])) {
                $neighborhood = Neighborhood::find($validated['neighborhood_id']);
            } elseif (! empty($validated['neighborhood_name'])) {
                $nn = trim($validated['neighborhood_name']);
                $neighborhood = Neighborhood::where('name_ku', 'ILIKE', "%{$nn}%")
                    ->orWhere('name_en', 'ILIKE', "%{$nn}%")
                    ->first();
            }

            $deliveryFee = isset($validated['delivery_fee'])
                ? (int) $validated['delivery_fee']
                : ($neighborhood ? (int) $neighborhood->delivery_fee : (int) $store->base_delivery_fee);

            $subtotal = 0;
            $preparedItems = [];

            foreach ($validated['items'] as $entry) {
                $product = null;
                if (! empty($entry['product_id']) && is_numeric($entry['product_id'])) {
                    $product = Product::find((int) $entry['product_id']);
                }
                if (! $product && ! empty($entry['product_name'])) {
                    $pn = trim((string) $entry['product_name']);
                    $product = Product::where('store_id', $store->id)
                        ->where('name_ku', 'ILIKE', "%{$pn}%")
                        ->first();
                }

                $qty = max(1, (int) ($entry['quantity'] ?? 1));
                $unitPrice = $product ? $product->effectivePrice() : max(0, (int) ($entry['unit_price'] ?? 2500));
                $lineTotal = $unitPrice * $qty;
                $subtotal += $lineTotal;

                $preparedItems[] = [
                    'product_id' => $product?->id,
                    'product_name' => $product?->name_ku ?? (string) ($entry['product_name'] ?? 'بەرهەم'),
                    'product_image' => $product?->image_url ?? ($entry['product_image'] ?? null),
                    'unit_price' => $unitPrice,
                    'quantity' => $qty,
                    'line_total' => $lineTotal,
                    'special_notes' => $entry['special_notes'] ?? null,
                ];
            }

            $discountAmount = 0;
            $coupon = null;
            if (! empty($validated['coupon_code'])) {
                $coupon = Coupon::where('code', strtoupper(trim($validated['coupon_code'])))
                    ->where('is_active', true)
                    ->first();
                if ($coupon) {
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

            $rawPayMethod = $validated['payment_method'] ?? 'cash';
            $paymentMethod = in_array($rawPayMethod, ['cash', 'fib', 'fastpay', 'wallet'], true)
                ? $rawPayMethod
                : 'cash';

            $sLat = (float) ($store->lat ?? 34.6836);
            $sLng = (float) ($store->lng ?? 45.3189);
            $cLat = (float) ($validated['delivery_lat'] ?? $neighborhood?->center_lat ?? 34.6912);
            $cLng = (float) ($validated['delivery_lng'] ?? $neighborhood?->center_lng ?? 45.3264);

            $onlineDriver = DriverProfile::with('user')->where('is_online', true)->first();

            $created = Order::create([
                'order_number' => $orderNumber,
                'customer_id' => $authUser->id,
                'store_id' => $store->id,
                'driver_id' => $onlineDriver?->user_id,
                'neighborhood_id' => $neighborhood?->id,
                'coupon_id' => $discountAmount > 0 ? $coupon?->id : null,
                'status' => 'pending',
                'vendor_status' => 'pending',
                'driver_status' => $onlineDriver ? 'driver_assigned' : 'unassigned',
                'driver_assigned_at' => $onlineDriver ? now() : null,
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
                'payment_method' => $paymentMethod,
                'payment_status' => 'pending',
                'customer_name' => $validated['customer_name'] ?? $authUser->name,
                'customer_phone' => $validated['customer_phone'] ?? $authUser->phone,
                'delivery_address' => $validated['delivery_address'],
                'delivery_lat' => $cLat,
                'delivery_lng' => $cLng,
                'driver_lat' => (float) ($onlineDriver?->current_lat ?? ($sLat - 0.0035)),
                'driver_lng' => (float) ($onlineDriver?->current_lng ?? ($sLng - 0.0040)),
                'eta_seconds' => 175,
                'distance_remaining_meters' => 1500,
                'customer_notes' => $validated['customer_notes'] ?? null,
            ]);

            foreach ($preparedItems as $itemData) {
                OrderItem::create(['order_id' => $created->id, ...$itemData]);
            }

            OrderStatusLog::create([
                'order_id' => $created->id,
                'from_status' => null,
                'to_status' => 'pending',
                'actor_id' => $authUser->id,
                'actor_role' => 'customer',
                'note' => 'داواکاری نوێ لە ئەپی کڕیاران (REGA) تۆمارکرا',
            ]);

            LiveTelemetrySession::updateOrCreate(
                ['order_ref' => $orderNumber],
                [
                    'order_id' => $created->id,
                    'status' => 'pending',
                    'driver_status' => $onlineDriver ? 'driver_assigned' : 'unassigned',
                    'store_name' => $store->name_ku,
                    'store_address' => $store->address_ku,
                    'store_phone' => $store->phone,
                    'store_lat' => $sLat,
                    'store_lng' => $sLng,
                    'customer_name' => $created->customer_name,
                    'customer_address' => $created->delivery_address,
                    'customer_phone' => $created->customer_phone,
                    'customer_lat' => $cLat,
                    'customer_lng' => $cLng,
                    'driver_name' => $onlineDriver?->user?->name ?? 'کاروان محەمەد',
                    'driver_phone' => $onlineDriver?->user?->phone ?? '07702001001',
                    'vehicle_label' => $onlineDriver?->plate_number ?? 'KLR-402',
                    'driver_lat' => (float) ($onlineDriver?->current_lat ?? ($sLat - 0.0035)),
                    'driver_lng' => (float) ($onlineDriver?->current_lng ?? ($sLng - 0.0040)),
                    'driver_heading' => 45.0,
                    'driver_speed_kmh' => 28.0,
                    'eta_seconds' => 175,
                    'distance_remaining_meters' => 1500,
                    'progress_permille' => 0,
                    'delivery_pin' => $deliveryPin,
                    'handover_pin' => $handoverPin,
                    'total_amount' => $totalAmount,
                    'delivery_fee' => $deliveryFee,
                    'driver_tip' => $tip,
                    'items_json' => $preparedItems,
                    'route_polyline' => [
                        [(float) ($onlineDriver?->current_lat ?? ($sLat - 0.0035)), (float) ($onlineDriver?->current_lng ?? ($sLng - 0.0040))],
                        [$sLat, $sLng],
                        [$cLat, $cLng],
                    ],
                ]
            );

            return $created->load(['items', 'store:id,name_ku,name_en,phone,lat,lng', 'driver:id,name,phone', 'neighborhood']);
        });

        return response()->json([
            'success' => true,
            'message' => 'داواکارییەکەت بە سەرکەوتوویی لە سێرڤەر تۆمارکرا.',
            'data' => $order,
        ], 201);
    }

    public function publicCustomerOrders(Request $request): JsonResponse
    {
        $authUser = $request->user('sanctum');
        $phone = preg_replace('/\s+/', '', (string) $request->string('phone', ''));

        $query = Order::query()
            ->with([
                'items',
                'store:id,name_ku,name_en,phone,cover_url,lat,lng',
                'driver:id,name,phone',
                'neighborhood:id,name_ku,name_en',
            ])
            ->latest();

        if ($authUser) {
            $query->where('customer_id', $authUser->id);
        } elseif ($phone !== '') {
            $query->where('customer_phone', 'ILIKE', "%{$phone}%");
        } else {
            $query->limit(15);
        }

        return response()->json([
            'success' => true,
            'data' => $query->limit(30)->get(),
        ]);
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

