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
use App\Models\SupportTicket;
use App\Models\User;
use App\Support\PublicMedia;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PublicAndCustomerController extends Controller
{
    public function bootstrap(): JsonResponse
    {
        $neighborhoods = Neighborhood::where('is_active', true)->orderBy('sort_order')->get();
        // Home grid uses is_featured_home; sort_order controls tile order in admin.
        $categories = $this->homeCategoriesQuery()->get();
        $banners = Banner::where('is_active', true)->with(['store:id,name_ku,slug', 'category:id,name_ku,name_ar,name_en,slug'])->orderBy('sort_order')->get();
        // Load all approved stores so every home tile (سوپەرمارکێت، خواردنگە، فست فوود…)
        // can show its vendors — products inherit the store's category_id.
        $featuredStores = Store::where('is_approved', true)
            ->with(['category:id,name_ku,name_ar,name_en', 'neighborhood:id,name_ku'])
            ->orderByDesc('is_featured')
            ->orderByDesc('rating')
            ->limit(200)
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

    /**
     * Public list of active marketplace categories for the customer home grid.
     * Query: featured_home=1 (default) returns only is_featured_home tiles.
     */
    public function categories(Request $request): JsonResponse
    {
        $featuredOnly = $request->boolean('featured_home', true);
        $query = Category::where('is_active', true);

        if ($featuredOnly) {
            $query->where('is_featured_home', true);
        }

        $categories = $query
            ->when(! $featuredOnly, fn ($q) => $q->orderByDesc('is_featured_home'))
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $categories,
        ]);
    }

    private function homeCategoriesQuery()
    {
        return Category::query()
            ->where('is_active', true)
            ->orderByDesc('is_featured_home')
            ->orderBy('sort_order')
            ->orderBy('id');
    }

    /**
     * Public support contacts for vendor/customer apps (no auth).
     * Sourced from PlatformSetting group=support — editable in admin Support settings.
     */
    public function supportContacts(): JsonResponse
    {
        $keys = [
            'support_phone',
            'whatsapp_number',
            'telegram_number',
            'telegram_username',
            'support_email',
            'driver_hotline',
        ];

        $out = [];
        foreach ($keys as $key) {
            $out[$key] = PlatformSetting::getValue($key);
        }

        $out['support_phone'] = $out['support_phone'] ?? '0770 000 1122';
        $out['whatsapp_number'] = $out['whatsapp_number'] ?? '+9647700001122';
        $out['telegram_number'] = $out['telegram_number'] ?? ($out['support_phone'] ?? '0770 000 1122');
        $out['telegram_username'] = ltrim((string) ($out['telegram_username'] ?? 'rega_support'), '@');

        return response()->json([
            'success' => true,
            'data' => $out,
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
            'products' => fn ($q) => $q->where('is_available', true)->with(
                'storeCategory:id,name_ku,name_ar,name_en,image_url,secondary_image_url,sort_order'
            ),
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
            ->with('category:id,name_ku,name_ar,name_en')
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
            'payment_method' => ['nullable', 'string', 'in:cash'],
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

            $deliveryFee = ((int) $store->base_delivery_fee === 0)
                ? 0
                : ($neighborhood ? (int) $neighborhood->delivery_fee : (int) $store->base_delivery_fee);

            $profitService = app(\App\Services\OrderProfitService::class);
            $commissionRate = $profitService->commissionForStore($store);
            $preparedItems = [];

            foreach ($validated['items'] as $entry) {
                $product = Product::where('store_id', $store->id)->findOrFail($entry['product_id']);
                $snap = $profitService->buildLineSnapshot($product, (int) $entry['quantity'], $commissionRate);
                $preparedItems[] = [
                    ...$snap['item'],
                    'special_notes' => $entry['special_notes'] ?? null,
                ];
            }

            $finance = $profitService->aggregateOrderFinancials($preparedItems, $commissionRate);
            $subtotal = (int) $finance['subtotal'];

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

            $commissionAmount = (int) $finance['admin_profit_amount'];
            $vendorNetAmount = (int) $finance['vendor_net_amount'];
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
                'total_product_cost' => (int) $finance['total_product_cost'],
                'total_gross_profit' => (int) $finance['total_gross_profit'],
                'discount_amount' => $discountAmount,
                'delivery_fee' => $deliveryFee,
                'driver_tip' => $tip,
                'waiting_bonus' => 0,
                'total_amount' => $totalAmount,
                'commission_rate' => $commissionRate,
                'profit_commission_rate' => (float) $finance['profit_commission_rate'],
                'commission_amount' => $commissionAmount,
                'admin_profit_amount' => (int) $finance['admin_profit_amount'],
                'seller_profit_amount' => (int) $finance['seller_profit_amount'],
                'refunded_amount' => 0,
                'is_profit_realized' => false,
                'vendor_net_amount' => $vendorNetAmount,
                'driver_total_earning' => $driverTotalEarning,
                'payment_method' => 'cash',
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
                    'driver_name' => 'لە چاوەڕوانی شۆفێر',
                    'driver_phone' => '0770 000 0000',
                    'vehicle_label' => 'دیاری نەکراوە',
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
            'payment_method' => ['nullable', 'string', 'in:cash'],
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
                : (((int) $store->base_delivery_fee === 0)
                    ? 0
                    : ($neighborhood ? (int) $neighborhood->delivery_fee : (int) $store->base_delivery_fee));

            $profitService = app(\App\Services\OrderProfitService::class);
            $commissionRate = $profitService->commissionForStore($store);
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
                if ($product) {
                    $snap = $profitService->buildLineSnapshot($product, $qty, $commissionRate);
                    $preparedItems[] = [
                        ...$snap['item'],
                        'special_notes' => $entry['special_notes'] ?? null,
                    ];
                } else {
                    $unitPrice = max(0, (int) ($entry['unit_price'] ?? 2500));
                    $unitCost = 0;
                    $lineTotal = $unitPrice * $qty;
                    $lineGross = $unitPrice * $qty;
                    $adminShare = (int) round($lineGross * ($commissionRate / 100));
                    $preparedItems[] = [
                        'product_id' => null,
                        'product_name' => (string) ($entry['product_name'] ?? 'بەرهەم'),
                        'product_image' => $entry['product_image'] ?? null,
                        'unit_price' => $unitPrice,
                        'unit_cost' => $unitCost,
                        'quantity' => $qty,
                        'line_total' => $lineTotal,
                        'line_cost' => 0,
                        'unit_gross_profit' => $unitPrice,
                        'line_gross_profit' => $lineGross,
                        'commission_rate' => $commissionRate,
                        'admin_share' => $adminShare,
                        'seller_share' => max(0, $lineGross - $adminShare),
                        'special_notes' => $entry['special_notes'] ?? null,
                    ];
                }
            }

            $finance = $profitService->aggregateOrderFinancials($preparedItems, $commissionRate);
            $subtotal = (int) $finance['subtotal'];

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
            $commissionAmount = (int) $finance['admin_profit_amount'];
            $vendorNetAmount = (int) $finance['vendor_net_amount'];
            $driverTotalEarning = $deliveryFee + $tip;

            $nextSeq = 10000 + Order::count() + 1;
            $orderNumber = 'RA-' . $nextSeq;
            while (Order::where('order_number', $orderNumber)->exists()) {
                $orderNumber = 'RA-' . random_int(10001, 99999);
            }

            $handoverPin = (string) random_int(1000, 9999);
            $deliveryPin = (string) random_int(1000, 9999);

            $paymentMethod = 'cash';

            $sLat = (float) ($store->lat ?? 34.6836);
            $sLng = (float) ($store->lng ?? 45.3189);
            $cLat = (float) ($validated['delivery_lat'] ?? $neighborhood?->center_lat ?? 34.6912);
            $cLng = (float) ($validated['delivery_lng'] ?? $neighborhood?->center_lng ?? 45.3264);

            $created = Order::create([
                'order_number' => $orderNumber,
                'customer_id' => $authUser->id,
                'store_id' => $store->id,
                'driver_id' => null,
                'neighborhood_id' => $neighborhood?->id,
                'coupon_id' => $discountAmount > 0 ? $coupon?->id : null,
                'status' => 'pending',
                'vendor_status' => 'pending',
                'driver_status' => 'unassigned',
                'driver_assigned_at' => null,
                'handover_pin' => $handoverPin,
                'delivery_pin' => $deliveryPin,
                'subtotal' => $subtotal,
                'total_product_cost' => (int) $finance['total_product_cost'],
                'total_gross_profit' => (int) $finance['total_gross_profit'],
                'discount_amount' => $discountAmount,
                'delivery_fee' => $deliveryFee,
                'driver_tip' => $tip,
                'waiting_bonus' => 0,
                'total_amount' => $totalAmount,
                'commission_rate' => $commissionRate,
                'profit_commission_rate' => (float) $finance['profit_commission_rate'],
                'commission_amount' => $commissionAmount,
                'admin_profit_amount' => (int) $finance['admin_profit_amount'],
                'seller_profit_amount' => (int) $finance['seller_profit_amount'],
                'refunded_amount' => 0,
                'is_profit_realized' => false,
                'vendor_net_amount' => $vendorNetAmount,
                'driver_total_earning' => $driverTotalEarning,
                'payment_method' => $paymentMethod,
                'payment_status' => 'pending',
                'customer_name' => $validated['customer_name'] ?? $authUser->name,
                'customer_phone' => $validated['customer_phone'] ?? $authUser->phone,
                'delivery_address' => $validated['delivery_address'],
                'delivery_lat' => $cLat,
                'delivery_lng' => $cLng,
                'driver_lat' => $sLat - 0.0035,
                'driver_lng' => $sLng - 0.0040,
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
                    'driver_name' => 'لە چاوەڕوانی شۆفێر',
                    'driver_phone' => '0770 000 0000',
                    'vehicle_label' => 'دیاری نەکراوە',
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

        $directQuery = SupportTicket::query()
            ->where('category', 'direct_request')
            ->latest();

        if ($authUser) {
            $query->where('customer_id', $authUser->id);
            $directQuery->where('user_id', $authUser->id);
        } elseif ($phone !== '') {
            $query->where('customer_phone', 'ILIKE', "%{$phone}%");
            $directQuery->where('description', 'ILIKE', "%{$phone}%");
        } else {
            $query->limit(15);
            $directQuery->limit(10);
        }

        $orders = $query->limit(30)->get();
        $tickets = $directQuery->limit(20)->get()->map(fn ($t) => $this->formatSupportTicketAsOrder($t));

        $merged = collect($orders->toArray())
            ->concat($tickets)
            ->sortByDesc(fn ($item) => $item['created_at'] ?? '')
            ->values()
            ->take(30);

        return response()->json([
            'success' => true,
            'data' => $merged,
        ]);
    }

    public function customerOrders(Request $request): JsonResponse
    {
        $user = $request->user();
        $orders = $user
            ->customerOrders()
            ->with([
                'items',
                'store:id,name_ku,name_en,phone,cover_url,lat,lng',
                'driver:id,name,phone',
                'neighborhood:id,name_ku,name_en',
            ])
            ->latest()
            ->get();

        $tickets = SupportTicket::query()
            ->where('user_id', $user->id)
            ->where('category', 'direct_request')
            ->latest()
            ->limit(20)
            ->get()
            ->map(fn ($t) => $this->formatSupportTicketAsOrder($t));

        $merged = collect($orders->toArray())
            ->concat($tickets)
            ->sortByDesc(fn ($item) => $item['created_at'] ?? '')
            ->values()
            ->take(30);

        return response()->json([
            'success' => true,
            'data' => $merged,
        ]);
    }

    public function publicDeleteCustomerOrder(Request $request, string $id): JsonResponse
    {
        return $this->performDeleteOrder($request, $id);
    }

    public function deleteCustomerOrder(Request $request, string $id): JsonResponse
    {
        return $this->performDeleteOrder($request, $id);
    }

    protected function performDeleteOrder(Request $request, string $id): JsonResponse
    {
        $user = $request->user('sanctum') ?? $request->user();

        // 1. Check if it's a Direct Request Support Ticket (starts with DR- or is ticket number)
        $ticket = null;
        if (str_starts_with(strtoupper($id), 'DR-')) {
            $ticket = SupportTicket::where('ticket_number', strtoupper($id))->first();
        } elseif (is_numeric($id)) {
            $ticket = SupportTicket::where('id', (int) $id)->where('category', 'direct_request')->first();
        }

        if ($ticket) {
            if ($user && $ticket->user_id && $ticket->user_id !== $user->id && ! $user->isAdmin()) {
                return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
            }
            $ticket->delete();

            return response()->json([
                'success' => true,
                'message' => 'داواکاری ڕاستەوخۆ بە سەرکەوتوویی سڕایەوە.',
            ]);
        }

        // 2. Otherwise look up in Order table
        $orderQuery = Order::query();
        if (is_numeric($id)) {
            $orderQuery->where(function ($q) use ($id) {
                $q->where('id', (int) $id)->orWhere('order_number', $id);
            });
        } else {
            $orderQuery->where('order_number', $id);
        }

        $order = $orderQuery->first();
        if (! $order) {
            return response()->json(['success' => false, 'message' => 'داواکاری نەدۆزرایەوە.'], 404);
        }

        if ($user && $order->customer_id && $order->customer_id !== $user->id && ! $user->isAdmin()) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

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

    protected function formatSupportTicketAsOrder(SupportTicket $t): array
    {
        $desc = (string) $t->description;
        $address = '';
        $notes = '';
        $phone = '';
        $image = null;
        foreach (explode("\n", $desc) as $line) {
            $line = trim($line);
            if (str_starts_with($line, 'ناونیشان: ')) {
                $address = trim(substr($line, strlen('ناونیشان: ')));
            } elseif (str_starts_with($line, 'مۆبایل: ')) {
                $phone = trim(substr($line, strlen('مۆبایل: ')));
            } elseif (str_starts_with($line, 'تێبینی: ')) {
                $notes = trim(substr($line, strlen('تێبینی: ')));
            } elseif (str_starts_with($line, 'وێنە: ')) {
                $image = trim(substr($line, strlen('وێنە: ')));
            }
        }

        $statusMap = [
            'open' => 'pending',
            'in_progress' => 'preparing',
            'resolved' => 'delivered',
            'closed' => 'delivered',
        ];
        $status = $statusMap[$t->status] ?? $t->status;

        return [
            'id' => $t->id,
            'order_number' => $t->ticket_number,
            'is_direct_request' => true,
            'ticket_id' => $t->id,
            'direct_subject' => $t->subject,
            'direct_notes' => $notes ?: $t->subject,
            'direct_image' => $image,
            'customer_phone' => $phone,
            'delivery_address' => $address ?: 'کەلار',
            'total_amount' => 0,
            'status' => $status,
            'created_at' => $t->created_at?->toISOString() ?? now()->toISOString(),
            'store' => [
                'id' => null,
                'name_ku' => '⚡ داواکاری ڕاستەوخۆ',
                'name_en' => 'Direct Request',
                'phone' => $phone,
                'cover_url' => $image ?: null,
                'lat' => 34.6836,
                'lng' => 45.3189,
            ],
            'driver' => null,
            'items' => [
                [
                    'id' => $t->id,
                    'product_id' => 0,
                    'product_name' => $t->subject,
                    'quantity' => 1,
                    'unit_price' => 0,
                    'total_price' => 0,
                    'special_notes' => $notes,
                    'product_image' => $image ?: null,
                ],
            ],
        ];
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

        // Broadcast rows: user_id NULL + audience all/customers.
        // Personal / fan-out rows: only the owning customer (or authenticated user).
        $list = AppNotification::query()
            ->with('store:id,name_ku,name_en,cover_url')
            ->where(function ($q) use ($userId) {
                $q->where(function ($broadcast) {
                    $broadcast->whereNull('user_id')
                        ->whereIn('target_audience', ['all', 'customers']);
                });
                if ($userId) {
                    $q->orWhere('user_id', $userId);
                }
            })
            ->latest()
            ->limit(80)
            ->get();

        if ($userId) {
            // Prefer personal fan-out rows over the campaign's broadcast companion (avoid duplicates).
            $personalCampaignIds = $list
                ->where('user_id', $userId)
                ->whereNotNull('campaign_id')
                ->pluck('campaign_id')
                ->flip();

            $list = $list
                ->reject(function (AppNotification $n) use ($personalCampaignIds) {
                    return $n->user_id === null
                        && $n->campaign_id
                        && $personalCampaignIds->has($n->campaign_id);
                })
                ->values();

            $broadcastIds = $list->whereNull('user_id')->pluck('id');
            $readBroadcastIds = $broadcastIds->isEmpty()
                ? collect()
                : DB::table('app_notification_reads')
                    ->where('user_id', $userId)
                    ->whereIn('app_notification_id', $broadcastIds)
                    ->pluck('app_notification_id')
                    ->flip();

            $list->transform(function (AppNotification $n) use ($readBroadcastIds) {
                if ($n->user_id === null) {
                    $n->is_read = $readBroadcastIds->has($n->id);
                }

                return $n;
            });
        }

        return response()->json([
            'success' => true,
            'data' => $list->take(50)->values(),
        ]);
    }

    public function markNotificationsRead(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 401);
        }

        $validated = $request->validate([
            'ids' => ['nullable', 'array', 'max:100'],
            'ids.*' => ['integer'],
            'all' => ['nullable', 'boolean'],
        ]);

        $visibleQuery = AppNotification::query()->where(function ($q) use ($user) {
            $q->where('user_id', $user->id)
                ->orWhere(function ($broadcast) {
                    $broadcast->whereNull('user_id')
                        ->whereIn('target_audience', ['all', 'customers']);
                });
        });

        if (! empty($validated['all'])) {
            $targets = (clone $visibleQuery)->get(['id', 'user_id']);
        } elseif (! empty($validated['ids'])) {
            $targets = (clone $visibleQuery)->whereIn('id', $validated['ids'])->get(['id', 'user_id']);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'ids یان all پێویستە.',
            ], 422);
        }

        $personalIds = $targets->where('user_id', $user->id)->pluck('id');
        $broadcastIds = $targets->whereNull('user_id')->pluck('id');

        $updated = 0;
        if ($personalIds->isNotEmpty()) {
            $updated += AppNotification::query()
                ->where('user_id', $user->id)
                ->whereIn('id', $personalIds)
                ->where('is_read', false)
                ->update(['is_read' => true]);
        }

        if ($broadcastIds->isNotEmpty()) {
            $now = now();
            foreach ($broadcastIds as $nid) {
                $inserted = DB::table('app_notification_reads')->insertOrIgnore([
                    'app_notification_id' => $nid,
                    'user_id' => $user->id,
                    'read_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                $updated += (int) $inserted;
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'ئاگادارییەکان وەک خوێندراوە نیشانکران.',
            'updated' => $updated,
        ]);
    }

    /** Customer uploads an image for داواکاری ڕاستەوخۆ. */
    public function uploadDirectRequestMedia(Request $request): JsonResponse
    {
        $request->validate([
            'file' => ['required', 'file', 'max:10240', 'mimes:jpg,jpeg,png,webp,gif'],
        ]);

        $path = $request->file('file')->store('uploads/direct-requests', 'public');

        return response()->json([
            'success' => true,
            'message' => 'وێنە بە سەرکەوتوویی بارکرا.',
            'data' => [
                'path' => $path,
                'url' => PublicMedia::url($path),
            ],
        ], 201);
    }

    /** Customer submits داواکاری ڕاستەوخۆ (stored as a support ticket). */
    public function submitDirectRequest(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 401);
        }

        $validated = $request->validate([
            'subject' => ['required', 'string', 'max:200'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'address' => ['required', 'string', 'max:500'],
            'phone' => ['required', 'string', 'max:20'],
            'image_url' => ['nullable', 'string', 'max:500'],
        ]);

        $phone = preg_replace('/\s+/', '', $validated['phone']) ?? '';
        $imageUrl = null;
        if (! empty($validated['image_url'])) {
            $relative = PublicMedia::relativePathFromUrl($validated['image_url']);
            $imageUrl = $relative
                ? PublicMedia::url($relative)
                : (string) $validated['image_url'];
        }

        $lines = [
            'ناونیشان: '.$validated['address'],
            'مۆبایل: '.$phone,
        ];
        if (! empty($validated['notes'])) {
            $lines[] = 'تێبینی: '.$validated['notes'];
        }
        if ($imageUrl) {
            $lines[] = 'وێنە: '.$imageUrl;
        }

        $ticket = SupportTicket::create([
            'ticket_number' => 'DR-'.strtoupper(Str::random(6)),
            'user_id' => $user->id,
            'subject' => $validated['subject'],
            'description' => implode("\n", $lines),
            'category' => 'direct_request',
            'priority' => 'high',
            'status' => 'open',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'داواکارییەکەت بە سەرکەوتوویی نێردرا.',
            'data' => [
                'id' => $ticket->id,
                'ticket_number' => $ticket->ticket_number,
            ],
        ], 201);
    }
}

