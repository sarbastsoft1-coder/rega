<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Store;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function overview(Request $request): JsonResponse
    {
        $days = max(7, min(30, (int) $request->integer('days', 7)));
        $todayStart = Carbon::today();

        $deliveredQuery = Order::query()->where('status', 'delivered');
        $todayDeliveredQuery = Order::query()
            ->where('status', 'delivered')
            ->where('created_at', '>=', $todayStart);

        $totalGmv = (int) (clone $deliveredQuery)->sum('total_amount');
        $platformCommission = (int) (clone $deliveredQuery)->sum('commission_amount');
        $todayGmv = (int) (clone $todayDeliveredQuery)->sum('total_amount');
        $todayCommission = (int) (clone $todayDeliveredQuery)->sum('commission_amount');

        $totalOrders = Order::count();
        $todayOrders = Order::where('created_at', '>=', $todayStart)->count();
        $deliveredOrders = (clone $deliveredQuery)->count();
        $cancelledOrders = Order::whereIn('status', ['cancelled', 'rejected'])->count();
        $activeOrdersCount = Order::whereNotIn('status', ['delivered', 'cancelled', 'rejected'])->count();
        $pendingOrdersCount = Order::where('status', 'pending')->count();

        $totalStores = Store::count();
        $onlineStores = Store::where('is_online', true)->where('is_approved', true)->count();
        $pendingStores = Store::where('is_approved', false)->count();

        $totalDrivers = DriverProfile::count();
        $onlineDrivers = DriverProfile::where('is_online', true)->count();
        $pendingKycDrivers = DriverProfile::where('is_verified', false)->count();
        $totalCodCashHeld = (int) DriverProfile::sum('cash_collected_hand');

        $totalCustomers = User::where('role', 'customer')->count();
        $openTicketsCount = SupportTicket::whereIn('status', ['open', 'in_progress'])->count();
        $completionRate = $totalOrders > 0
            ? (int) round(($deliveredOrders / $totalOrders) * 100)
            : 0;

        // Avg delivery minutes — ignore unrealistic outliers (> 6h) that skew the KPI
        $avgDeliveryMinutes = (int) round(
            (float) Order::query()
                ->where('status', 'delivered')
                ->whereNotNull('delivered_at')
                ->whereNotNull('created_at')
                ->whereRaw('EXTRACT(EPOCH FROM (delivered_at - created_at)) / 60.0 BETWEEN 1 AND 360')
                ->selectRaw('AVG(EXTRACT(EPOCH FROM (delivered_at - created_at)) / 60.0) as avg_mins')
                ->value('avg_mins') ?? 0
        );

        // Daily revenue & commission chart over last N days (PostgreSQL DATE grouping)
        $startDate = Carbon::today()->subDays($days - 1);
        $dailyRows = Order::query()
            ->selectRaw('DATE(created_at) as bucket_date')
            ->selectRaw("SUM(CASE WHEN status = 'delivered' THEN total_amount ELSE 0 END) as gmv")
            ->selectRaw("SUM(CASE WHEN status = 'delivered' THEN commission_amount ELSE 0 END) as commission")
            ->selectRaw("SUM(CASE WHEN status = 'delivered' THEN delivery_fee ELSE 0 END) as delivery_fees")
            ->selectRaw('COUNT(*) as orders_count')
            ->selectRaw("SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as delivered_count")
            ->selectRaw("SUM(CASE WHEN status = 'on_the_way' THEN 1 ELSE 0 END) as on_the_way_count")
            ->selectRaw("SUM(CASE WHEN status NOT IN ('delivered', 'cancelled', 'rejected', 'on_the_way') THEN 1 ELSE 0 END) as pending_count")
            ->selectRaw("SUM(CASE WHEN status IN ('cancelled', 'rejected') THEN 1 ELSE 0 END) as cancelled_count")
            ->selectRaw("SUM(CASE WHEN status NOT IN ('delivered', 'cancelled', 'rejected') THEN 1 ELSE 0 END) as active_count")
            ->where('created_at', '>=', $startDate)
            ->groupByRaw('DATE(created_at)')
            ->orderByRaw('DATE(created_at) ASC')
            ->get()
            ->keyBy('bucket_date');

        $revenueChart = [];
        for ($i = 0; $i < $days; $i++) {
            $d = $startDate->copy()->addDays($i);
            $dateKey = $d->toDateString();
            $row = $dailyRows->get($dateKey);
            $revenueChart[] = [
                'date' => $dateKey,
                'label' => $d->format('m/d'),
                'day_name' => $d->format('D'),
                'gmv' => (int) ($row->gmv ?? 0),
                'commission' => (int) ($row->commission ?? 0),
                'delivery_fees' => (int) ($row->delivery_fees ?? 0),
                'orders_count' => (int) ($row->orders_count ?? 0),
                'delivered_count' => (int) ($row->delivered_count ?? 0),
                'on_the_way_count' => (int) ($row->on_the_way_count ?? 0),
                'pending_count' => (int) ($row->pending_count ?? 0),
                'cancelled_count' => (int) ($row->cancelled_count ?? 0),
                'active_count' => (int) ($row->active_count ?? 0),
            ];
        }

        // Status breakdown
        $statusCounts = Order::query()
            ->select('status', DB::raw('COUNT(*) as total'))
            ->groupBy('status')
            ->pluck('total', 'status')
            ->map(fn ($v) => (int) $v)
            ->all();

        // Category sales share
        $categorySales = Category::query()
            ->leftJoin('stores', 'categories.id', '=', 'stores.category_id')
            ->leftJoin('orders', function ($join) {
                $join->on('stores.id', '=', 'orders.store_id')
                    ->where('orders.status', '=', 'delivered');
            })
            ->select(
                'categories.id',
                'categories.name_ku',
                'categories.name_ar',
                'categories.name_en',
                'categories.icon_name',
                DB::raw('COALESCE(SUM(orders.total_amount), 0) as revenue'),
                DB::raw('COUNT(orders.id) as orders_count')
            )
            ->groupBy('categories.id', 'categories.name_ku', 'categories.name_ar', 'categories.name_en', 'categories.icon_name')
            ->orderByDesc('revenue')
            ->get()
            ->map(fn ($c) => [
                'id' => $c->id,
                'name_ku' => $c->name_ku,
                'name_ar' => $c->name_ar,
                'name_en' => $c->name_en,
                'icon_name' => $c->icon_name,
                'revenue' => (int) $c->revenue,
                'orders_count' => (int) $c->orders_count,
            ]);

        // Top performing stores (by delivered order count, then revenue)
        $topStores = Store::query()
            ->with('category:id,name_ku,name_en')
            ->withCount(['orders as orders_count'])
            ->withCount(['orders as delivered_orders_count' => fn ($q) => $q->where('status', 'delivered')])
            ->withSum(['orders as gross_sales' => fn ($q) => $q->where('status', 'delivered')], 'total_amount')
            ->withSum(['orders as platform_commission' => fn ($q) => $q->where('status', 'delivered')], 'commission_amount')
            ->orderByDesc('delivered_orders_count')
            ->orderByDesc('gross_sales')
            ->limit(6)
            ->get()
            ->map(fn (Store $s) => [
                'id' => $s->id,
                'name_ku' => $s->name_ku,
                'name_en' => $s->name_en,
                'category_name' => $s->category?->name_ku,
                'rating' => (float) $s->rating,
                'is_online' => (bool) $s->is_online,
                'commission_rate' => (float) $s->commission_rate,
                'orders_count' => (int) ($s->orders_count ?? 0),
                'delivered_orders_count' => (int) ($s->delivered_orders_count ?? 0),
                'gross_sales' => (int) ($s->gross_sales ?? 0),
                'platform_commission' => (int) ($s->platform_commission ?? 0),
                'cover_url' => $s->cover_url,
            ]);

        // Last 6 calendar months: new customers (role=customer) by created_at
        $kuMonths = [
            1 => 'کانوونی دووەم',
            2 => 'شوبات',
            3 => 'ئازار',
            4 => 'نیسان',
            5 => 'ئایار',
            6 => 'حوزەیران',
            7 => 'تەمموز',
            8 => 'ئاب',
            9 => 'ئەیلول',
            10 => 'تشرینی یەکەم',
            11 => 'تشرینی دووەم',
            12 => 'کانوونی یەکەم',
        ];

        $monthStart = Carbon::today()->startOfMonth()->subMonths(5);
        $customerMonthRows = User::query()
            ->where('role', 'customer')
            ->where('created_at', '>=', $monthStart)
            ->selectRaw("to_char(created_at, 'YYYY-MM') as ym")
            ->selectRaw('COUNT(*) as total')
            ->groupByRaw("to_char(created_at, 'YYYY-MM')")
            ->orderByRaw("to_char(created_at, 'YYYY-MM') ASC")
            ->pluck('total', 'ym');

        $newCustomersChart = [];
        for ($i = 0; $i < 6; $i++) {
            $m = $monthStart->copy()->addMonths($i);
            $ym = $m->format('Y-m');
            $newCustomersChart[] = [
                'year' => (int) $m->year,
                'month' => (int) $m->month,
                'ym' => $ym,
                'label_ku' => $kuMonths[(int) $m->month] ?? $m->format('M'),
                'count' => (int) ($customerMonthRows[$ym] ?? 0),
            ];
        }

        // Last 6 calendar months: orders count + GMV for dual-axis trends
        $orderMonthRows = Order::query()
            ->where('created_at', '>=', $monthStart)
            ->selectRaw("to_char(created_at, 'YYYY-MM') as ym")
            ->selectRaw('COUNT(*) as orders_count')
            ->selectRaw("SUM(CASE WHEN status = 'delivered' THEN total_amount ELSE 0 END) as gmv")
            ->groupByRaw("to_char(created_at, 'YYYY-MM')")
            ->orderByRaw("to_char(created_at, 'YYYY-MM') ASC")
            ->get()
            ->keyBy('ym');

        $ordersRevenueMonthly = [];
        for ($i = 0; $i < 6; $i++) {
            $m = $monthStart->copy()->addMonths($i);
            $ym = $m->format('Y-m');
            $row = $orderMonthRows->get($ym);
            $ordersRevenueMonthly[] = [
                'year' => (int) $m->year,
                'month' => (int) $m->month,
                'ym' => $ym,
                'label_ku' => $kuMonths[(int) $m->month] ?? $m->format('M'),
                'orders_count' => (int) ($row->orders_count ?? 0),
                'gmv' => (int) ($row->gmv ?? 0),
            ];
        }

        // Per-driver average delivery minutes (delivered orders only, exclude >6h outliers)
        $driverAvgMinutes = Order::query()
            ->where('status', 'delivered')
            ->whereNotNull('delivered_at')
            ->whereNotNull('driver_id')
            ->whereRaw('EXTRACT(EPOCH FROM (delivered_at - created_at)) / 60.0 BETWEEN 1 AND 360')
            ->selectRaw('driver_id')
            ->selectRaw('AVG(EXTRACT(EPOCH FROM (delivered_at - created_at)) / 60.0) as avg_mins')
            ->groupBy('driver_id')
            ->pluck('avg_mins', 'driver_id');

        // Top drivers
        $topDrivers = DriverProfile::query()
            ->with('user:id,name,phone,avatar_url')
            ->orderByDesc('total_deliveries')
            ->limit(6)
            ->get()
            ->map(fn (DriverProfile $dp) => [
                'id' => $dp->id,
                'user_id' => $dp->user_id,
                'name' => $dp->user?->name,
                'phone' => $dp->user?->phone,
                'driver_code' => $dp->driver_code,
                'motor_type' => $dp->motor_type,
                'is_online' => $dp->is_online,
                'is_verified' => $dp->is_verified,
                'rating' => (float) $dp->rating,
                'total_deliveries' => (int) $dp->total_deliveries,
                'completed_deliveries' => (int) $dp->total_deliveries,
                'avg_delivery_minutes' => (int) round((float) ($driverAvgMinutes[$dp->user_id] ?? 0)),
                'wallet_balance' => (int) $dp->wallet_balance,
                'cash_collected_hand' => (int) $dp->cash_collected_hand,
            ]);

        $newThisMonth = User::query()
            ->where('role', 'customer')
            ->where('created_at', '>=', Carbon::today()->startOfMonth())
            ->count();

        // Recent orders
        $recentOrders = Order::query()
            ->with([
                'store:id,name_ku,name_en,phone',
                'customer:id,name,phone',
                'driver:id,name,phone',
                'driver.driverProfile:id,user_id,driver_code',
                'neighborhood:id,name_ku,name_en',
            ])
            ->withCount('items')
            ->latest()
            ->limit(10)
            ->get();

        // Live Kalar Fleet & Store Radar
        $activeDriverIds = Order::query()
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->whereNotNull('driver_id')
            ->pluck('driver_id')
            ->unique()
            ->all();

        $radarStores = Store::query()
            ->select('id', 'name_ku', 'name_en', 'lat', 'lng', 'is_online', 'is_approved')
            ->get();

        $radarDrivers = DriverProfile::query()
            ->with('user:id,name,phone')
            ->get()
            ->map(fn (DriverProfile $dp) => [
                'id' => $dp->id,
                'user_id' => $dp->user_id,
                'driver_code' => $dp->driver_code,
                'name' => $dp->user?->name,
                'phone' => $dp->user?->phone,
                'lat' => $dp->current_lat ?? 34.6850,
                'lng' => $dp->current_lng ?? 45.3200,
                'is_online' => $dp->is_online,
                'has_active_order' => in_array($dp->user_id, $activeDriverIds, true),
            ]);

        return response()->json([
            'success' => true,
            'data' => [
                'kpis' => [
                    'total_gmv' => $totalGmv,
                    'today_gmv' => $todayGmv,
                    'platform_commission_earned' => $platformCommission,
                    'today_commission' => $todayCommission,
                    'total_orders' => $totalOrders,
                    'today_orders' => $todayOrders,
                    'delivered_orders' => $deliveredOrders,
                    'cancelled_orders' => $cancelledOrders,
                    'active_orders_count' => $activeOrdersCount,
                    'pending_orders_count' => $pendingOrdersCount,
                    'completion_rate' => $completionRate,
                    'avg_delivery_minutes' => $avgDeliveryMinutes,
                    'total_stores' => $totalStores,
                    'online_stores' => $onlineStores,
                    'pending_stores' => $pendingStores,
                    'total_drivers' => $totalDrivers,
                    'online_drivers' => $onlineDrivers,
                    'pending_kyc_drivers' => $pendingKycDrivers,
                    'total_cod_cash_held' => $totalCodCashHeld,
                    'total_customers' => $totalCustomers,
                    'new_customers_this_month' => $newThisMonth,
                    'open_tickets_count' => $openTicketsCount,
                ],
                'revenue_chart' => $revenueChart,
                'orders_revenue_monthly' => $ordersRevenueMonthly,
                'monthly_trends' => array_values(array_slice($ordersRevenueMonthly, -4)),
                'new_customers_chart' => $newCustomersChart,
                'status_breakdown' => $statusCounts,
                'category_sales' => $categorySales,
                'top_stores' => $topStores,
                'top_drivers' => $topDrivers,
                'recent_orders' => $recentOrders,
                'fleet_radar' => [
                    'stores' => $radarStores,
                    'drivers' => $radarDrivers,
                ],
            ],
        ]);
    }
}

