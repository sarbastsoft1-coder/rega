<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AccountingRefundTransaction;
use App\Models\AdminProfitSettingsHistory;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\PlatformSetting;
use App\Models\Store;
use App\Services\OrderProfitService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AccountingController extends Controller
{
    public function __construct(private OrderProfitService $profitService) {}

    public function dashboard(Request $request): JsonResponse
    {
        [$from, $to] = $this->resolveDateRange($request);

        $base = Order::query()
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to));

        $totalOrders = (clone $base)->count();
        $completedOrders = (clone $base)->where('status', 'delivered')->count();
        $cancelledOrders = (clone $base)->whereIn('status', ['cancelled', 'rejected'])->count();

        $realized = (clone $base)->where('status', 'delivered')->where('is_profit_realized', true);

        $totalSales = (int) (clone $realized)->sum('subtotal');
        $totalCosts = (int) (clone $realized)->sum('total_product_cost');
        $totalGross = (int) (clone $realized)->sum('total_gross_profit');
        $adminProfit = (int) (clone $realized)->sum('admin_profit_amount');
        $sellerProfit = (int) (clone $realized)->sum('seller_profit_amount');
        $refundedSales = (int) AccountingRefundTransaction::query()
            ->whereHas('order', function ($q) use ($from, $to) {
                $q->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                    ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to));
            })
            ->sum('refunded_sales');

        $series = Order::query()
            ->where('status', 'delivered')
            ->where('is_profit_realized', true)
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to))
            ->selectRaw("DATE(created_at) as day")
            ->selectRaw('COALESCE(SUM(subtotal),0) as revenue')
            ->selectRaw('COALESCE(SUM(admin_profit_amount),0) as admin_profit')
            ->selectRaw('COALESCE(SUM(seller_profit_amount),0) as seller_profit')
            ->selectRaw('COALESCE(SUM(total_gross_profit),0) as gross_profit')
            ->groupBy('day')
            ->orderBy('day')
            ->get();

        $byShop = Store::query()
            ->withSum(['orders as sales' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'subtotal')
            ->withSum(['orders as admin_earnings' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'admin_profit_amount')
            ->withSum(['orders as seller_earnings' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'seller_profit_amount')
            ->withSum(['orders as gross_profit' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'total_gross_profit')
            ->orderByDesc('admin_earnings')
            ->limit(15)
            ->get(['id', 'name_ku', 'name_en']);

        $topProducts = OrderItem::query()
            ->selectRaw('product_id, product_name')
            ->selectRaw('SUM(quantity) as qty_sold')
            ->selectRaw('SUM(line_total) as sales')
            ->selectRaw('SUM(line_cost) as costs')
            ->selectRaw('SUM(line_gross_profit) as gross_profit')
            ->selectRaw('SUM(admin_share) as admin_share')
            ->selectRaw('SUM(seller_share) as seller_share')
            ->whereHas('order', function ($q) use ($from, $to) {
                $q->where('status', 'delivered')
                    ->where('is_profit_realized', true)
                    ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                    ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to));
            })
            ->groupBy('product_id', 'product_name')
            ->orderByDesc('gross_profit')
            ->limit(15)
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'commission_percentage' => $this->profitService->globalCommissionPercentage(),
                'stats' => [
                    'total_orders' => $totalOrders,
                    'completed_orders' => $completedOrders,
                    'cancelled_orders' => $cancelledOrders,
                    'total_sales_revenue' => $totalSales,
                    'total_product_costs' => $totalCosts,
                    'total_gross_profit' => $totalGross,
                    'total_admin_profit' => $adminProfit,
                    'total_seller_profit' => $sellerProfit,
                    'total_refunded_sales' => $refundedSales,
                    'net_admin_profit' => max(0, $adminProfit),
                ],
                'series' => $series,
                'profit_by_shop' => $byShop,
                'top_products' => $topProducts,
            ],
        ]);
    }

    public function shopIndex(Request $request): JsonResponse
    {
        [$from, $to] = $this->resolveDateRange($request);

        $stores = Store::query()
            ->when($request->filled('q'), function ($q) use ($request) {
                $term = '%'.trim((string) $request->string('q')).'%';
                $q->where(function ($qq) use ($term) {
                    $qq->where('name_ku', 'ILIKE', $term)->orWhere('name_en', 'ILIKE', $term);
                });
            })
            ->withCount(['orders as total_orders' => fn ($q) => $q
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))])
            ->withCount(['orders as completed_orders' => fn ($q) => $q->where('status', 'delivered')
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))])
            ->withSum(['orders as total_sales' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'subtotal')
            ->withSum(['orders as total_costs' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'total_product_cost')
            ->withSum(['orders as gross_profit' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'total_gross_profit')
            ->withSum(['orders as admin_earnings' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'admin_profit_amount')
            ->withSum(['orders as seller_earnings' => fn ($q) => $q->where('status', 'delivered')->where('is_profit_realized', true)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to))], 'seller_profit_amount')
            ->orderByDesc('admin_earnings')
            ->paginate(min(100, max(10, (int) $request->integer('per_page', 30))));

        return response()->json([
            'success' => true,
            'data' => $stores->items(),
            'meta' => [
                'current_page' => $stores->currentPage(),
                'last_page' => $stores->lastPage(),
                'total' => $stores->total(),
                'commission_percentage' => $this->profitService->globalCommissionPercentage(),
            ],
        ]);
    }

    public function shopShow(Request $request, Store $store): JsonResponse
    {
        [$from, $to] = $this->resolveDateRange($request);

        $ordersQ = $store->orders()
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to));

        $realizedQ = (clone $ordersQ)->where('status', 'delivered')->where('is_profit_realized', true);

        $refunds = AccountingRefundTransaction::query()
            ->whereHas('order', fn ($q) => $q->where('store_id', $store->id)
                ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to)))
            ->sum('refunded_sales');

        $orderHistory = (clone $ordersQ)
            ->with(['items:id,order_id,product_name,quantity,unit_price,unit_cost,line_total,line_cost,line_gross_profit,commission_rate,admin_share,seller_share'])
            ->latest()
            ->limit(100)
            ->get([
                'id', 'order_number', 'status', 'created_at', 'subtotal', 'total_product_cost',
                'total_gross_profit', 'profit_commission_rate', 'admin_profit_amount',
                'seller_profit_amount', 'refunded_amount', 'is_profit_realized', 'total_amount',
            ]);

        $productBreakdown = OrderItem::query()
            ->selectRaw('product_id, product_name')
            ->selectRaw('SUM(quantity) as qty_sold')
            ->selectRaw('SUM(line_total) as sales')
            ->selectRaw('SUM(line_cost) as costs')
            ->selectRaw('SUM(line_gross_profit) as gross_profit')
            ->selectRaw('SUM(admin_share) as admin_share')
            ->selectRaw('SUM(seller_share) as seller_share')
            ->whereHas('order', function ($q) use ($store, $from, $to) {
                $q->where('store_id', $store->id)
                    ->where('status', 'delivered')
                    ->where('is_profit_realized', true)
                    ->when($from, fn ($qq) => $qq->where('created_at', '>=', $from))
                    ->when($to, fn ($qq) => $qq->where('created_at', '<=', $to));
            })
            ->groupBy('product_id', 'product_name')
            ->orderByDesc('gross_profit')
            ->get();

        // Day-by-day: what this seller owes admin from product profit.
        $dailyBreakdown = Order::query()
            ->where('store_id', $store->id)
            ->where('status', 'delivered')
            ->where('is_profit_realized', true)
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to))
            ->selectRaw('DATE(created_at) as day')
            ->selectRaw('COUNT(*) as orders_count')
            ->selectRaw('COALESCE(SUM(subtotal),0) as sales')
            ->selectRaw('COALESCE(SUM(total_product_cost),0) as costs')
            ->selectRaw('COALESCE(SUM(total_gross_profit),0) as gross_profit')
            ->selectRaw('COALESCE(SUM(admin_profit_amount),0) as admin_owed')
            ->selectRaw('COALESCE(SUM(seller_profit_amount),0) as seller_share')
            ->groupBy('day')
            ->orderByDesc('day')
            ->limit(62)
            ->get();

        $todayFrom = now()->startOfDay();
        $todayTo = now()->endOfDay();
        $todayQ = $store->orders()
            ->where('status', 'delivered')
            ->where('is_profit_realized', true)
            ->whereBetween('created_at', [$todayFrom, $todayTo]);

        $commissionPct = $this->profitService->globalCommissionPercentage();
        $adminEarnings = (int) (clone $realizedQ)->sum('admin_profit_amount');
        $grossProfit = (int) (clone $realizedQ)->sum('total_gross_profit');
        $todayAdminOwed = (int) (clone $todayQ)->sum('admin_profit_amount');
        $todayGross = (int) (clone $todayQ)->sum('total_gross_profit');
        $todaySales = (int) (clone $todayQ)->sum('subtotal');

        return response()->json([
            'success' => true,
            'data' => [
                'shop' => [
                    'id' => $store->id,
                    'name_ku' => $store->name_ku,
                    'name_en' => $store->name_en,
                ],
                'summary' => [
                    'total_orders' => (clone $ordersQ)->count(),
                    'completed_orders' => (clone $ordersQ)->where('status', 'delivered')->count(),
                    'total_sales' => (int) (clone $realizedQ)->sum('subtotal'),
                    'total_product_costs' => (int) (clone $realizedQ)->sum('total_product_cost'),
                    'gross_profit' => $grossProfit,
                    'admin_commission_percentage' => $commissionPct,
                    'admin_earnings' => $adminEarnings,
                    'admin_owed' => $adminEarnings,
                    'seller_earnings' => (int) (clone $realizedQ)->sum('seller_profit_amount'),
                    'refunds' => (int) $refunds,
                    'net_profit' => $adminEarnings,
                    'today_sales' => $todaySales,
                    'today_gross_profit' => $todayGross,
                    'today_admin_owed' => $todayAdminOwed,
                    'formula_note' => 'admin_owed = gross_profit × commission% / 100 (not from full sales)',
                ],
                'daily_breakdown' => $dailyBreakdown,
                'orders' => $orderHistory,
                'product_breakdown' => $productBreakdown,
            ],
        ]);
    }

    public function ordersIndex(Request $request): JsonResponse
    {
        [$from, $to] = $this->resolveDateRange($request);

        $query = Order::query()
            ->with(['store:id,name_ku,name_en'])
            ->when($request->filled('store_id'), fn ($q) => $q->where('store_id', (int) $request->integer('store_id')))
            ->when($request->filled('status') && $request->string('status') !== 'all', fn ($q) => $q->where('status', (string) $request->string('status')))
            ->when($request->filled('order_id'), function ($q) use ($request) {
                $term = trim((string) $request->string('order_id'));
                $q->where(function ($qq) use ($term) {
                    if (is_numeric($term)) {
                        $qq->where('id', (int) $term);
                    }
                    $qq->orWhere('order_number', 'ILIKE', "%{$term}%");
                });
            })
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to))
            ->when($request->filled('min_profit'), fn ($q) => $q->where('total_gross_profit', '>=', (int) $request->integer('min_profit')))
            ->when($request->filled('max_profit'), fn ($q) => $q->where('total_gross_profit', '<=', (int) $request->integer('max_profit')))
            ->latest();

        $page = $query->paginate(min(100, max(10, (int) $request->integer('per_page', 40))));

        $rows = collect($page->items())->map(function (Order $o) {
            return [
                'id' => $o->id,
                'order_number' => $o->order_number,
                'shop_name' => $o->store?->name_ku,
                'store_id' => $o->store_id,
                'order_date' => $o->created_at?->toIso8601String(),
                'order_status' => $o->status,
                'total_sales' => (int) $o->subtotal,
                'product_costs' => (int) $o->total_product_cost,
                'gross_profit' => (int) $o->total_gross_profit,
                'admin_commission' => (float) ($o->profit_commission_rate ?? $o->commission_rate),
                'admin_earnings' => (int) $o->admin_profit_amount,
                'seller_earnings' => (int) $o->seller_profit_amount,
                'refunded_amount' => (int) $o->refunded_amount,
                'is_profit_realized' => (bool) $o->is_profit_realized,
                'total_amount' => (int) $o->total_amount,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $rows,
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function orderShow(Order $order): JsonResponse
    {
        $order->load([
            'store:id,name_ku,name_en',
            'items',
            'refundTransactions.processor:id,name',
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'order' => [
                    'id' => $order->id,
                    'order_number' => $order->order_number,
                    'shop_name' => $order->store?->name_ku,
                    'store_id' => $order->store_id,
                    'order_date' => $order->created_at?->toIso8601String(),
                    'order_status' => $order->status,
                    'total_sales' => (int) $order->subtotal,
                    'product_costs' => (int) $order->total_product_cost,
                    'gross_profit' => (int) $order->total_gross_profit,
                    'admin_commission' => (float) ($order->profit_commission_rate ?? $order->commission_rate),
                    'admin_earnings' => (int) $order->admin_profit_amount,
                    'seller_earnings' => (int) $order->seller_profit_amount,
                    'refunded_amount' => (int) $order->refunded_amount,
                    'is_profit_realized' => (bool) $order->is_profit_realized,
                    'total_amount' => (int) $order->total_amount,
                ],
                'items' => $order->items->map(fn ($i) => [
                    'id' => $i->id,
                    'product_id' => $i->product_id,
                    'shop_id' => $order->store_id,
                    'product_name' => $i->product_name,
                    'quantity' => (int) $i->quantity,
                    'cost_price' => (int) $i->unit_cost,
                    'selling_price' => (int) $i->unit_price,
                    'line_cost' => (int) $i->line_cost,
                    'line_sales' => (int) $i->line_total,
                    'gross_profit' => (int) $i->line_gross_profit,
                    'commission_percentage' => (float) $i->commission_rate,
                    'admin_share' => (int) $i->admin_share,
                    'seller_share' => (int) $i->seller_share,
                ]),
                'refunds' => $order->refundTransactions,
            ],
        ]);
    }

    public function profitSettings(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'commission_percentage' => $this->profitService->globalCommissionPercentage(),
                'history' => AdminProfitSettingsHistory::query()
                    ->with('changer:id,name')
                    ->latest()
                    ->limit(50)
                    ->get(),
            ],
        ]);
    }

    public function updateProfitSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'commission_percentage' => ['required', 'numeric', 'min:0', 'max:100'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $pct = round((float) $validated['commission_percentage'], 2);

        DB::transaction(function () use ($pct, $validated, $request) {
            PlatformSetting::setValue(
                OrderProfitService::SETTINGS_KEY,
                $pct,
                'finance',
                'Global admin share % of product gross profit (selling - cost)'
            );

            AdminProfitSettingsHistory::create([
                'commission_percentage' => $pct,
                'changed_by' => $request->user()->id,
                'note' => $validated['note'] ?? 'Updated global profit commission',
            ]);
        });

        return $this->profitSettings();
    }

    public function reports(Request $request): JsonResponse
    {
        [$from, $to] = $this->resolveDateRange($request);
        $period = (string) $request->string('period', 'custom');

        if (! $from && ! $to) {
            [$from, $to] = match ($period) {
                'daily', 'day' => [now()->startOfDay(), now()->endOfDay()],
                'weekly', 'week' => [now()->startOfWeek(), now()->endOfWeek()],
                'monthly', 'month' => [now()->startOfMonth(), now()->endOfMonth()],
                'yearly', 'year' => [now()->startOfYear(), now()->endOfYear()],
                default => [now()->subDays(30)->startOfDay(), now()->endOfDay()],
            };
        }

        $realized = Order::query()
            ->where('status', 'delivered')
            ->where('is_profit_realized', true)
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to));

        $allInRange = Order::query()
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to));

        return response()->json([
            'success' => true,
            'data' => [
                'period' => $period,
                'from' => $from?->toIso8601String(),
                'to' => $to?->toIso8601String(),
                'total_revenue' => (int) (clone $realized)->sum('subtotal'),
                'total_costs' => (int) (clone $realized)->sum('total_product_cost'),
                'gross_profit' => (int) (clone $realized)->sum('total_gross_profit'),
                'admin_earnings' => (int) (clone $realized)->sum('admin_profit_amount'),
                'seller_earnings' => (int) (clone $realized)->sum('seller_profit_amount'),
                'total_orders' => (clone $allInRange)->count(),
                'completed_orders' => (clone $allInRange)->where('status', 'delivered')->count(),
            ],
        ]);
    }

    public function exportReport(Request $request): StreamedResponse
    {
        [$from, $to] = $this->resolveDateRange($request);

        $orders = Order::query()
            ->with('store:id,name_ku')
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to))
            ->orderBy('id')
            ->get();

        $filename = 'accounting_report_'.now()->format('Ymd_His').'.csv';

        return response()->streamDownload(function () use ($orders) {
            $out = fopen('php://output', 'w');
            fprintf($out, chr(0xEF).chr(0xBB).chr(0xBF));
            fputcsv($out, [
                'Order ID', 'Order Number', 'Shop', 'Status', 'Date',
                'Sales', 'Costs', 'Gross Profit', 'Commission %',
                'Admin Share', 'Seller Share', 'Refunded', 'Realized',
            ]);
            foreach ($orders as $o) {
                fputcsv($out, [
                    $o->id,
                    $o->order_number,
                    $o->store?->name_ku,
                    $o->status,
                    optional($o->created_at)->toDateTimeString(),
                    (int) $o->subtotal,
                    (int) $o->total_product_cost,
                    (int) $o->total_gross_profit,
                    (float) ($o->profit_commission_rate ?? $o->commission_rate),
                    (int) $o->admin_profit_amount,
                    (int) $o->seller_profit_amount,
                    (int) $o->refunded_amount,
                    $o->is_profit_realized ? 1 : 0,
                ]);
            }
            fclose($out);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function transactions(Request $request): JsonResponse
    {
        [$from, $to] = $this->resolveDateRange($request);

        $refunds = AccountingRefundTransaction::query()
            ->with(['order:id,order_number,store_id', 'order.store:id,name_ku', 'processor:id,name'])
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('created_at', '<=', $to))
            ->latest()
            ->paginate(min(100, max(10, (int) $request->integer('per_page', 40))));

        return response()->json([
            'success' => true,
            'data' => $refunds->items(),
            'meta' => [
                'current_page' => $refunds->currentPage(),
                'last_page' => $refunds->lastPage(),
                'total' => $refunds->total(),
            ],
        ]);
    }

    public function refundOrder(Request $request, Order $order): JsonResponse
    {
        $validated = $request->validate([
            'order_item_id' => ['nullable', 'exists:order_items,id'],
            'quantity' => ['nullable', 'integer', 'min:1'],
            'full' => ['nullable', 'boolean'],
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $result = $this->profitService->processRefund(
            $order,
            $request->user(),
            $validated['order_item_id'] ?? null,
            $validated['quantity'] ?? null,
            (bool) ($validated['full'] ?? false),
            $validated['reason'] ?? null,
        );

        return response()->json([
            'success' => true,
            'message' => 'گەڕاندنەوە تۆمارکرا.',
            'data' => $result,
        ]);
    }

    /**
     * @return array{0: \Carbon\Carbon|null, 1: \Carbon\Carbon|null}
     */
    private function resolveDateRange(Request $request): array
    {
        $from = $request->filled('from') ? \Carbon\Carbon::parse((string) $request->string('from'))->startOfDay() : null;
        $to = $request->filled('to') ? \Carbon\Carbon::parse((string) $request->string('to'))->endOfDay() : null;

        $period = (string) $request->string('period', '');
        if ((! $from || ! $to) && $period !== '') {
            [$from, $to] = match ($period) {
                'daily', 'day', 'today' => [now()->startOfDay(), now()->endOfDay()],
                'weekly', 'week' => [now()->startOfWeek(), now()->endOfWeek()],
                'monthly', 'month' => [now()->startOfMonth(), now()->endOfMonth()],
                'yearly', 'year' => [now()->startOfYear(), now()->endOfYear()],
                default => [$from, $to],
            };
        }

        return [$from, $to];
    }
}
