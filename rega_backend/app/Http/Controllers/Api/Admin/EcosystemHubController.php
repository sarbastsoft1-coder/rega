<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Banner;
use App\Models\Coupon;
use App\Models\CustomerAddress;
use App\Models\DriverDocument;
use App\Models\DriverProfile;
use App\Models\LiveTelemetrySession;
use App\Models\Neighborhood;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusLog;
use App\Models\Payout;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use App\Services\OrderSettlementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EcosystemHubController extends Controller
{
    public function __construct(private readonly OrderSettlementService $settlementService) {}

    /**
     * Unified real-time snapshot for the 3 Admin Ecosystem Parts:
     * 1) Vendor Part (`vendor_part`)
     * 2) Customer Part (`customer_part`)
     * 3) Delivery Part (`delivery_part`)
     */
    public function overview(): JsonResponse
    {
        $deliveredOrders = Order::where('status', 'delivered');

        // ---------------- 1. VENDOR PART ----------------
        $totalStores = Store::count();
        $onlineStores = Store::where('is_online', true)->where('is_approved', true)->count();
        $pendingApprovalStores = Store::where('is_approved', false)->count();
        $totalProducts = Product::count();
        $unavailableProducts = Product::where('is_available', false)->count();
        $activeKitchenOrders = Order::whereIn('vendor_status', ['pending', 'preparing', 'ready'])
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->count();

        $grossVendorSales = (int) (clone $deliveredOrders)->sum('subtotal');
        $platformCommission = (int) (clone $deliveredOrders)->sum('commission_amount');
        $vendorNetProfit = (int) (clone $deliveredOrders)->sum('vendor_net_amount');
        $vendorPayoutsPaid = (int) Payout::where('recipient_type', 'vendor')
            ->where('status', 'completed')
            ->sum('amount');

        $vendorStores = Store::query()
            ->with([
                'owner:id,name,phone,email,is_active',
                'category:id,name_ku,name_en',
                'neighborhood:id,name_ku,delivery_fee',
            ])
            ->withCount(['products', 'orders'])
            ->withSum(['orders as gross_sales' => fn ($q) => $q->where('status', 'delivered')], 'subtotal')
            ->withSum(['orders as total_commission' => fn ($q) => $q->where('status', 'delivered')], 'commission_amount')
            ->withSum(['orders as net_profit' => fn ($q) => $q->where('status', 'delivered')], 'vendor_net_amount')
            ->orderByDesc('is_online')
            ->orderByDesc('gross_sales')
            ->get();

        $kitchenOrders = Order::query()
            ->with([
                'store:id,name_ku,name_en,phone,address_ku',
                'customer:id,name,phone',
                'driver:id,name,phone',
                'driver.driverProfile:id,user_id,driver_code,plate_number',
                'items',
            ])
            ->latest()
            ->limit(30)
            ->get();

        // ---------------- 2. CUSTOMER PART ----------------
        $totalCustomers = User::where('role', 'customer')->count();
        $activeCustomers = User::where('role', 'customer')->where('is_active', true)->count();
        $suspendedCustomers = max(0, $totalCustomers - $activeCustomers);
        $savedAddressesCount = CustomerAddress::count();
        $activeCouponsCount = Coupon::where('is_active', true)->count();
        $activeBannersCount = Banner::where('is_active', true)->count();
        $totalCustomerOrders = Order::count();
        $totalCustomerGmv = (int) (clone $deliveredOrders)->sum('total_amount');

        $vipCustomers = User::query()
            ->where('role', 'customer')
            ->with(['addresses.neighborhood'])
            ->withCount('customerOrders')
            ->withSum(['customerOrders as total_spent' => fn ($q) => $q->where('status', 'delivered')], 'total_amount')
            ->orderByRaw('COALESCE((SELECT SUM(total_amount) FROM orders WHERE orders.customer_id = users.id AND orders.status = \'delivered\'), 0) DESC')
            ->limit(25)
            ->get();

        $recentCustomerOrders = Order::query()
            ->with([
                'store:id,name_ku,name_en,phone,lat,lng',
                'customer:id,name,phone',
                'driver:id,name,phone',
                'neighborhood:id,name_ku,delivery_fee',
                'items',
            ])
            ->latest()
            ->limit(30)
            ->get();

        // ---------------- 3. DELIVERY PART ----------------
        $totalDrivers = DriverProfile::count();
        $onlineDrivers = DriverProfile::where('is_online', true)->count();
        $verifiedDrivers = DriverProfile::where('is_verified', true)->count();
        $pendingKycDocs = DriverDocument::where('status', 'pending')->count();
        $unassignedReadyOrders = Order::whereNull('driver_id')
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->count();
        $inTransitOrders = Order::whereIn('status', ['picked_up', 'on_the_way', 'arrived_customer'])->count();
        $completedDeliveries = (clone $deliveredOrders)->count();
        $totalDriverEarnings = (int) (clone $deliveredOrders)->sum('driver_total_earning');
        $totalWaitingBonus = (int) (clone $deliveredOrders)->sum('waiting_bonus');
        $totalCodCashHeld = (int) DriverProfile::sum('cash_collected_hand');
        $driverSettlementsPaid = (int) Payout::whereIn('recipient_type', ['driver', 'driver_cod_settlement'])
            ->where('status', 'completed')
            ->sum('amount');

        $drivers = DriverProfile::query()
            ->with(['user:id,name,phone,email,is_active', 'documents'])
            ->orderByDesc('is_online')
            ->orderByDesc('total_deliveries')
            ->get();

        $dispatchQueue = Order::query()
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->with([
                'store:id,name_ku,name_en,phone,address_ku,lat,lng',
                'customer:id,name,phone',
                'driver:id,name,phone',
                'driver.driverProfile:id,user_id,driver_code,motor_type,plate_number,current_lat,current_lng,speed_kmh',
                'neighborhood:id,name_ku,delivery_fee',
                'items',
            ])
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'vendor_part' => [
                    'kpis' => [
                        'total_stores' => $totalStores,
                        'online_stores' => $onlineStores,
                        'pending_approval_stores' => $pendingApprovalStores,
                        'total_products' => $totalProducts,
                        'unavailable_products' => $unavailableProducts,
                        'active_kitchen_orders' => $activeKitchenOrders,
                        'gross_vendor_sales' => $grossVendorSales,
                        'platform_commission' => $platformCommission,
                        'vendor_net_profit' => $vendorNetProfit,
                        'vendor_payouts_paid' => $vendorPayoutsPaid,
                    ],
                    'stores' => $vendorStores,
                    'kitchen_orders' => $kitchenOrders,
                ],
                'customer_part' => [
                    'kpis' => [
                        'total_customers' => $totalCustomers,
                        'active_customers' => $activeCustomers,
                        'suspended_customers' => $suspendedCustomers,
                        'saved_addresses_count' => $savedAddressesCount,
                        'active_coupons_count' => $activeCouponsCount,
                        'active_banners_count' => $activeBannersCount,
                        'total_customer_orders' => $totalCustomerOrders,
                        'total_customer_gmv' => $totalCustomerGmv,
                    ],
                    'vip_customers' => $vipCustomers,
                    'recent_orders' => $recentCustomerOrders,
                ],
                'delivery_part' => [
                    'kpis' => [
                        'total_drivers' => $totalDrivers,
                        'online_drivers' => $onlineDrivers,
                        'verified_drivers' => $verifiedDrivers,
                        'pending_kyc_docs' => $pendingKycDocs,
                        'unassigned_ready_orders' => $unassignedReadyOrders,
                        'in_transit_orders' => $inTransitOrders,
                        'completed_deliveries' => $completedDeliveries,
                        'total_driver_earnings' => $totalDriverEarnings,
                        'total_waiting_bonus' => $totalWaitingBonus,
                        'total_cod_cash_held' => $totalCodCashHeld,
                        'driver_settlements_paid' => $driverSettlementsPaid,
                    ],
                    'drivers' => $drivers,
                    'dispatch_queue' => $dispatchQueue,
                ],
            ],
        ]);
    }

    /**
     * Admin creates a real live order for any customer directly into PostgreSQL + LiveTelemetrySession.
     */
    public function createOrder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'customer_id' => ['nullable', 'exists:users,id'],
            'customer_name' => ['nullable', 'string', 'max:120'],
            'customer_phone' => ['nullable', 'string', 'max:30'],
            'store_id' => ['required', 'exists:stores,id'],
            'driver_id' => ['nullable', 'exists:users,id'],
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
        ]);

        $store = Store::findOrFail($validated['store_id']);

        $customer = null;
        if (! empty($validated['customer_id'])) {
            $customer = User::find($validated['customer_id']);
        } elseif (! empty($validated['customer_phone'])) {
            $cleanPhone = preg_replace('/\s+/', '', $validated['customer_phone']);
            $customer = User::firstOrCreate(
                ['phone' => $cleanPhone],
                [
                    'name' => $validated['customer_name'] ?? 'کڕیاری نوێ',
                    'password' => 'password123',
                    'role' => 'customer',
                    'language' => 'ku',
                    'is_active' => true,
                ]
            );
        } else {
            $customer = User::where('role', 'customer')->first();
        }

        $order = DB::transaction(function () use ($validated, $store, $customer, $request) {
            $neighborhood = isset($validated['neighborhood_id'])
                ? Neighborhood::find($validated['neighborhood_id'])
                : null;

            $deliveryFee = $neighborhood ? (int) $neighborhood->delivery_fee : (int) $store->base_delivery_fee;

            $subtotal = 0;
            $preparedItems = [];

            foreach ($validated['items'] as $entry) {
                $product = Product::findOrFail($entry['product_id']);
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

            $driverId = $validated['driver_id'] ?? null;
            $driverUser = $driverId ? User::with('driverProfile')->find($driverId) : null;

            $cLat = (float) ($validated['delivery_lat'] ?? $neighborhood?->center_lat ?? 34.6912);
            $cLng = (float) ($validated['delivery_lng'] ?? $neighborhood?->center_lng ?? 45.3264);
            $sLat = (float) ($store->lat ?? 34.6836);
            $sLng = (float) ($store->lng ?? 45.3189);
            $dLat = (float) ($driverUser?->driverProfile?->current_lat ?? ($sLat - 0.0035));
            $dLng = (float) ($driverUser?->driverProfile?->current_lng ?? ($sLng - 0.0040));

            $created = Order::create([
                'order_number' => $orderNumber,
                'customer_id' => $customer?->id,
                'store_id' => $store->id,
                'driver_id' => $driverUser?->id,
                'neighborhood_id' => $neighborhood?->id,
                'coupon_id' => $discountAmount > 0 ? $coupon?->id : null,
                'status' => 'pending',
                'vendor_status' => 'pending',
                'driver_status' => $driverUser ? 'driver_assigned' : 'unassigned',
                'driver_assigned_at' => $driverUser ? now() : null,
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
                'customer_name' => $validated['customer_name'] ?? $customer?->name ?? 'کڕیار',
                'customer_phone' => $validated['customer_phone'] ?? $customer?->phone ?? '07700000000',
                'delivery_address' => $validated['delivery_address'],
                'delivery_lat' => $cLat,
                'delivery_lng' => $cLng,
                'driver_lat' => $dLat,
                'driver_lng' => $dLng,
                'eta_seconds' => 180,
                'distance_remaining_meters' => 1550,
                'customer_notes' => $validated['customer_notes'] ?? null,
            ]);

            foreach ($preparedItems as $itemData) {
                OrderItem::create(['order_id' => $created->id, ...$itemData]);
            }

            OrderStatusLog::create([
                'order_id' => $created->id,
                'from_status' => null,
                'to_status' => 'pending',
                'actor_id' => $request->user()->id,
                'actor_role' => $request->user()->role,
                'note' => 'داواکاری نوێ لە پانێڵی بەڕێوەبردن تۆمارکرا',
            ]);

            LiveTelemetrySession::updateOrCreate(
                ['order_ref' => $orderNumber],
                [
                    'order_id' => $created->id,
                    'status' => 'pending',
                    'driver_status' => $driverUser ? 'driver_assigned' : 'unassigned',
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
                    'driver_name' => $driverUser?->name ?? 'کاروان محەمەد',
                    'driver_phone' => $driverUser?->phone ?? '07702001001',
                    'vehicle_label' => $driverUser?->driverProfile?->plate_number ?? 'KLR-402',
                    'driver_lat' => $dLat,
                    'driver_lng' => $dLng,
                    'driver_heading' => 45.0,
                    'driver_speed_kmh' => 28.0,
                    'eta_seconds' => 180,
                    'distance_remaining_meters' => 1550,
                    'progress_permille' => 0,
                    'delivery_pin' => $deliveryPin,
                    'handover_pin' => $handoverPin,
                    'total_amount' => $totalAmount,
                    'delivery_fee' => $deliveryFee,
                    'driver_tip' => $tip,
                    'items_json' => $preparedItems,
                    'route_polyline' => [
                        [$dLat, $dLng],
                        [$sLat, $sLng],
                        [$cLat, $cLng],
                    ],
                ]
            );

            return $created->load(['items', 'store', 'customer', 'driver.driverProfile', 'neighborhood']);
        });

        return response()->json([
            'success' => true,
            'message' => "داواکاری {$order->order_number} بە سەرکەوتوویی تۆمارکرا.",
            'data' => $order,
        ], 201);
    }

    /**
     * Verify Store -> Driver 4-digit Handover PIN (`handover_pin`).
     */
    public function verifyHandoverPin(Request $request, Order $order): JsonResponse
    {
        $validated = $request->validate([
            'pin' => ['required', 'string', 'size:4'],
        ]);

        if ($validated['pin'] !== $order->handover_pin) {
            return response()->json([
                'success' => false,
                'message' => 'کۆدی ڕادەستکردنی شۆفێر (Handover PIN) هەڵەیە!',
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
            'actor_role' => $request->user()->role,
            'note' => 'بە کۆدی ڕادەستکردنی شۆفێر (Handover PIN) داواکارییەکە ڕادەستی شۆفێر کرا',
        ]);

        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->update([
                'status' => 'picked_up',
                'driver_status' => 'picked_up',
            ]);

        return response()->json([
            'success' => true,
            'message' => 'کۆدی شۆفێر پشتڕاستکرایەوە و داواکارییەکە ڕادەستی شۆفێر کرا ✅',
            'data' => $order->fresh(['items', 'store', 'customer', 'driver.driverProfile']),
        ]);
    }

    /**
     * Verify Driver -> Customer 4-digit Delivery PIN (`delivery_pin`) and settle financials.
     */
    public function verifyDeliveryPin(Request $request, Order $order): JsonResponse
    {
        $validated = $request->validate([
            'pin' => ['required', 'string', 'size:4'],
        ]);

        if ($validated['pin'] !== $order->delivery_pin) {
            return response()->json([
                'success' => false,
                'message' => 'کۆدی وەرگرتنی کڕیار (Delivery PIN) هەڵەیە!',
            ], 422);
        }

        $settled = $this->settlementService->markDelivered(
            $order,
            $request->user(),
            'بە کۆدی ٤ ژمارەیی کڕیار گەیاندن تەواوکرا و حسابەکان یەکلاکرانەوە'
        );

        LiveTelemetrySession::where('order_id', $order->id)
            ->orWhere('order_ref', $order->order_number)
            ->update([
                'status' => 'delivered',
                'driver_status' => 'delivered',
                'eta_seconds' => 0,
                'distance_remaining_meters' => 0,
                'progress_permille' => 1000,
            ]);

        return response()->json([
            'success' => true,
            'message' => 'گەیاندن بە کۆدی کڕیار پشتڕاستکرایەوە و حسابەکان یەکلاکرانەوە ✅',
            'data' => $settled,
        ]);
    }
}

