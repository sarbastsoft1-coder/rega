import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
class AccountingScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const AccountingScreen({super.key, required this.api, required this.lang});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _period = 'month';
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _dash = {};
  List<dynamic> _shops = [];
  List<dynamic> _orders = [];
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _report = {};
  List<dynamic> _transactions = [];

  final _commissionCtrl = TextEditingController();
  final _orderSearchCtrl = TextEditingController();
  final _shopSearchCtrl = TextEditingController();
  String _orderStatus = 'all';
  int? _selectedShopId;
  /// null = global default rate; otherwise selected vendor store id
  int? _settingsStoreId;
  List<dynamic> _settingsStores = [];

  String get _lang => widget.lang;

  String _t(String key) => AppStrings.tr(key, _lang);

  String _tp(String key, Map<String, String> params) => AppStrings.trParams(key, _lang, params);

  String _localizedStoreName(Map<String, dynamic> m) {
    final lang = _lang == 'ckb' ? 'ku' : _lang;
    final ku = m['name_ku']?.toString().trim() ?? '';
    final ar = m['name_ar']?.toString().trim() ?? '';
    final en = m['name_en']?.toString().trim() ?? '';
    if (lang == 'en') {
      return en.isNotEmpty ? en : (ku.isNotEmpty ? ku : (ar.isNotEmpty ? ar : _t('acc_shop_fallback')));
    }
    if (lang == 'ar') {
      return ar.isNotEmpty ? ar : (ku.isNotEmpty ? ku : (en.isNotEmpty ? en : _t('acc_shop_fallback')));
    }
    return ku.isNotEmpty ? ku : (en.isNotEmpty ? en : (ar.isNotEmpty ? ar : _t('acc_shop_fallback')));
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _commissionCtrl.dispose();
    _orderSearchCtrl.dispose();
    _shopSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dash = await widget.api.getAccountingDashboard(period: _period);
      final shopsRes = await widget.api.getAccountingShops(
        period: _period,
        q: _shopSearchCtrl.text.trim().isEmpty ? null : _shopSearchCtrl.text.trim(),
      );
      final ordersRes = await widget.api.getAccountingOrders(
        status: _orderStatus,
        orderId: _orderSearchCtrl.text.trim().isEmpty ? null : _orderSearchCtrl.text.trim(),
        storeId: _selectedShopId?.toString(),
      );
      final settings = await widget.api.getProfitSettings();
      final report = await widget.api.getAccountingReports(period: _period);
      final txRes = await widget.api.getAccountingTransactions();

      if (!mounted) return;
      final settingsStores = settings['stores'] as List<dynamic>? ?? [];
      final selectedRate = _rateForSettingsStore(
        settingsStores,
        _settingsStoreId,
        fallback: settings['default_commission_percentage'] ??
            settings['commission_percentage'] ??
            dash['commission_percentage'] ??
            20,
      );
      setState(() {
        _dash = dash;
        _shops = shopsRes['data'] as List<dynamic>? ?? [];
        _orders = ordersRes['data'] as List<dynamic>? ?? [];
        _settings = settings;
        _settingsStores = settingsStores;
        _commissionCtrl.text = '$selectedRate';
        _report = report;
        _transactions = txRes['data'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = AdminSurfaces.of(context);
    final periods = <(String, String)>[
      ('today', _t('acc_period_today')),
      ('week', _t('acc_period_week')),
      ('month', _t('acc_period_month')),
      ('year', _t('acc_period_year')),
    ];

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AdminBreakpoints.pagePadH(context),
            16,
            AdminBreakpoints.pagePadH(context),
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('acc_title'),
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: surfaces.textPrimary,
                  ),
                ),
                Text(
                  _t('acc_subtitle'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 12 : 16,
            8,
            MediaQuery.sizeOf(context).width < 600 ? 12 : 16,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in periods)
                      ChoiceChip(
                        label: Text(p.$2),
                        selected: _period == p.$1,
                        onSelected: (_) {
                          setState(() => _period = p.$1);
                          _loadAll();
                        },
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: _t('refresh'),
              ),
            ],
          ),
        ),
        Material(
          color: surfaces.elevated,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            indicatorColor: RegaColors.orange,
            labelColor: RegaColors.orange,
            unselectedLabelColor: surfaces.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: _t('acc_tab_dashboard')),
              Tab(text: _t('acc_tab_shops')),
              Tab(text: _t('acc_tab_orders')),
              Tab(text: _t('acc_tab_settings')),
              Tab(text: _t('acc_tab_reports')),
              Tab(text: _t('acc_tab_transactions')),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tx(_error!), style: TextStyle(color: surfaces.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadAll, child: Text(_t('acc_retry'))),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildDashboard(),
                        _buildShops(),
                        _buildOrders(),
                        _buildSettings(),
                        _buildReports(),
                        _buildTransactions(),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    final stats = Map<String, dynamic>.from(_dash['stats'] as Map? ?? {});
    final series = (_dash['series'] as List?) ?? [];
    final byShop = (_dash['profit_by_shop'] as List?) ?? [];
    final topProducts = (_dash['top_products'] as List?) ?? [];
    final defaultPct = '${_dash['commission_percentage'] ?? 20}';

    final kpiCards = <Widget>[
      StatKpiCard(
        title: _t('acc_kpi_total_orders'),
        value: '${stats['total_orders'] ?? 0}',
        icon: Icons.receipt_long_rounded,
        accentColor: RegaColors.blue,
      ),
      StatKpiCard(
        title: _t('acc_kpi_completed'),
        value: '${stats['completed_orders'] ?? 0}',
        icon: Icons.check_circle_outline,
        accentColor: RegaColors.emerald,
      ),
      StatKpiCard(
        title: _t('acc_kpi_cancelled'),
        value: '${stats['cancelled_orders'] ?? 0}',
        icon: Icons.cancel_outlined,
        accentColor: RegaColors.crimson,
      ),
      StatKpiCard(
        title: _t('acc_kpi_total_sales'),
        value: formatIqd(stats['total_sales_revenue'] as num?, lang: _lang),
        icon: Icons.payments_outlined,
        accentColor: RegaColors.orange,
      ),
      StatKpiCard(
        title: _t('acc_kpi_total_costs'),
        value: formatIqd(stats['total_product_costs'] as num?, lang: _lang),
        icon: Icons.inventory_2_outlined,
        accentColor: RegaColors.purple,
      ),
      StatKpiCard(
        title: _t('acc_kpi_gross_profit'),
        value: formatIqd(stats['total_gross_profit'] as num?, lang: _lang),
        icon: Icons.trending_up_rounded,
        accentColor: RegaColors.emeraldDark,
      ),
      StatKpiCard(
        title: _t('acc_kpi_admin_profit'),
        value: formatIqd(stats['total_admin_profit'] as num?, lang: _lang),
        icon: Icons.account_balance_rounded,
        accentColor: RegaColors.forestGreen,
        subtitle: _tp('acc_default_rate', {'pct': defaultPct}),
      ),
      StatKpiCard(
        title: _t('acc_kpi_seller_profit'),
        value: formatIqd(stats['total_seller_profit'] as num?, lang: _lang),
        icon: Icons.storefront_outlined,
        accentColor: RegaColors.goldDark,
      ),
    ];

    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 16),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final phone = c.maxWidth < 600;
            final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 700 ? 2 : (phone ? 1 : 2));
            if (phone) {
              return Column(
                children: [
                  for (var i = 0; i < kpiCards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: kpiCards[i]),
                  ],
                ],
              );
            }
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 2 ? 1.65 : 1.55,
              children: kpiCards,
            );
          },
        ),
        const SizedBox(height: 20),
        Text(_t('acc_profit_by_shop'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...byShop.take(10).map((s) {
          final m = Map<String, dynamic>.from(s as Map);
          return ListTile(
            title: Text(_localizedStoreName(m)),
            subtitle: Text(_tp('acc_sales_label', {
              'amount': formatIqd(m['sales'] as num?, lang: _lang),
            })),
            trailing: Text(
              formatIqd(m['admin_earnings'] as num?, lang: _lang),
              style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.forestGreen),
            ),
            onTap: () async {
              final id = m['id'] as int?;
              if (id == null) return;
              final detail = await widget.api.getAccountingShop(id, period: _period);
              if (!mounted) return;
              _showShopDetail(detail);
            },
          );
        }),
        const SizedBox(height: 12),
        Text(_t('acc_top_products'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...topProducts.take(10).map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          return ListTile(
            dense: true,
            title: Text(tx(m['product_name']?.toString() ?? '—')),
            subtitle: Text(_tp('acc_qty_label', {'qty': '${m['qty_sold'] ?? 0}'})),
            trailing: Text(formatIqd(m['gross_profit'] as num?, lang: _lang)),
          );
        }),
        if (series.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(_t('acc_revenue_trend'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: series.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = Map<String, dynamic>.from(series[i] as Map);
                final rev = (m['revenue'] as num?)?.toInt() ?? 0;
                final maxRev = series
                    .map((e) => ((e as Map)['revenue'] as num?)?.toInt() ?? 0)
                    .fold<int>(1, (a, b) => a > b ? a : b);
                return Container(
                  width: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RegaColors.orangeSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RegaColors.orangeBorder),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: (rev / maxRev).clamp(0.05, 1),
                            child: Container(
                              width: 28,
                              decoration: BoxDecoration(
                                color: RegaColors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tx('${m['day']}'.split('T').first.split('-').last),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShops() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _shopSearchCtrl,
            decoration: InputDecoration(
              hintText: _t('acc_search_shop'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _loadAll, icon: const Icon(Icons.check)),
            ),
            onSubmitted: (_) => _loadAll(),
          ),
        ),
        Expanded(
          child: _shops.isEmpty
              ? Center(child: Text(_t('acc_no_shops')))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: _shops.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = Map<String, dynamic>.from(_shops[i] as Map);
                    return ListTile(
                      title: Text(_localizedStoreName(m), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        _tp('acc_shop_list_meta', {
                          'rate': '${m['commission_rate'] ?? '—'}',
                          'orders': '${m['total_orders'] ?? 0}',
                          'completed': '${m['completed_orders'] ?? 0}',
                          'sales': formatIqd(m['total_sales'] as num?, lang: _lang),
                          'profit': formatIqd(m['gross_profit'] as num?, lang: _lang),
                        }),
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatIqd(m['admin_earnings'] as num?, lang: _lang),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.forestGreen),
                          ),
                          Text(_t('acc_admin_owed'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                          Text(
                            formatIqd(m['seller_earnings'] as num?, lang: _lang),
                            style: const TextStyle(fontSize: 12, color: RegaColors.goldDark),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final id = m['id'] as int?;
                        if (id == null) return;
                        final detail = await widget.api.getAccountingShop(id, period: _period);
                        if (!mounted) return;
                        _showShopDetail(detail);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showShopDetail(Map<String, dynamic> detail) {
    final shop = Map<String, dynamic>.from(detail['shop'] as Map? ?? {});
    final summary = Map<String, dynamic>.from(detail['summary'] as Map? ?? {});
    final orders = (detail['orders'] as List?) ?? [];
    final products = (detail['product_breakdown'] as List?) ?? [];
    final daily = (detail['daily_breakdown'] as List?) ?? [];
    final pct = summary['admin_commission_percentage'] ?? 20;
    final todayOwed = (summary['today_admin_owed'] as num?)?.toInt() ?? 0;
    final todayGross = (summary['today_gross_profit'] as num?)?.toInt() ?? 0;
    final todaySales = (summary['today_sales'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(_localizedStoreName(shop), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_t('acc_shop_detail_hint'), style: TextStyle(color: RC.fg(Colors.grey.shade600), fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFECFDF5)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RC.bg(Color(0xFF86EFAC))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('acc_today_owed_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    formatIqd(todayOwed, lang: _lang),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF166534))),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tp('acc_today_sales_meta', {
                      'sales': formatIqd(todaySales, lang: _lang),
                      'profit': formatIqd(todayGross, lang: _lang),
                      'pct': '$pct',
                    }),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('acc_example_formula'),
                    style: TextStyle(fontSize: 11.5, color: RC.fg(Colors.grey.shade700), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip(_t('acc_chip_sales_period'), formatIqd(summary['total_sales'] as num?, lang: _lang)),
                _chip(_t('acc_chip_cost'), formatIqd(summary['total_product_costs'] as num?, lang: _lang)),
                _chip(_t('acc_chip_profit'), formatIqd(summary['gross_profit'] as num?, lang: _lang)),
                _chip(
                  _tp('acc_chip_admin_owed_pct', {'pct': '$pct'}),
                  formatIqd(summary['admin_earnings'] as num?, lang: _lang),
                ),
                _chip(_t('acc_chip_seller_share'), formatIqd(summary['seller_earnings'] as num?, lang: _lang)),
                _chip(_t('acc_chip_refunds'), formatIqd(summary['refunds'] as num?, lang: _lang)),
              ],
            ),
            const SizedBox(height: 18),
            Text(_t('acc_daily_owed_title'), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            if (daily.isEmpty)
              Text(_t('acc_no_completed_sales'), style: TextStyle(color: RC.fg(Colors.grey.shade600)))
            else
              ...daily.map((d) {
                final m = Map<String, dynamic>.from(d as Map);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${m['day']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    _tp('acc_daily_row_meta', {
                      'sales': formatIqd(m['sales'] as num?, lang: _lang),
                      'profit': formatIqd(m['gross_profit'] as num?, lang: _lang),
                      'orders': '${m['orders_count'] ?? 0}',
                    }),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatIqd(m['admin_owed'] as num?, lang: _lang),
                        style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF166534))),
                      ),
                      Text(_t('acc_for_admin'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(_t('acc_products'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ...products.map((p) {
              final m = Map<String, dynamic>.from(p as Map);
              return ListTile(
                dense: true,
                title: Text(tx(m['product_name']?.toString() ?? '')),
                subtitle: Text(_tp('acc_admin_share', {
                  'amount': formatIqd(m['admin_share'] as num?, lang: _lang),
                })),
                trailing: Text(formatIqd(m['gross_profit'] as num?, lang: _lang)),
              );
            }),
            const SizedBox(height: 8),
            Text(_t('acc_order_history'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ...orders.map((o) {
              final m = Map<String, dynamic>.from(o as Map);
              final status = AppStrings.statusLabel('${m['status'] ?? ''}', _lang);
              return ListTile(
                dense: true,
                title: Text(m['order_number']?.toString() ?? '#${m['id']}'),
                subtitle: Text('$status · ${m['created_at']}'),
                trailing: Text(formatIqd(m['admin_profit_amount'] as num?, lang: _lang)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: RegaColors.orangeSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RegaColors.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: RegaColors.lightMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildOrders() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _orderSearchCtrl,
                  decoration: InputDecoration(hintText: _t('acc_order_search_hint'), isDense: true),
                  onSubmitted: (_) => _loadAll(),
                ),
              ),
              DropdownButton<String>(
                value: _orderStatus,
                items: [
                  DropdownMenuItem(value: 'all', child: Text(_t('acc_status_all'))),
                  DropdownMenuItem(value: 'delivered', child: Text(AppStrings.statusLabel('delivered', _lang))),
                  DropdownMenuItem(value: 'cancelled', child: Text(AppStrings.statusLabel('cancelled', _lang))),
                  DropdownMenuItem(value: 'pending', child: Text(AppStrings.statusLabel('pending', _lang))),
                ],
                onChanged: (v) {
                  setState(() => _orderStatus = v ?? 'all');
                  _loadAll();
                },
              ),
              ElevatedButton(onPressed: _loadAll, child: Text(_t('acc_filter'))),
            ],
          ),
        ),
        Expanded(
          child: _orders.isEmpty
              ? Center(child: Text(_t('acc_no_orders')))
              : ListView.separated(
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = Map<String, dynamic>.from(_orders[i] as Map);
                    final status = AppStrings.statusLabel('${m['order_status'] ?? ''}', _lang);
                    return ListTile(
                      title: Text(tx('${m['order_number']} · ${m['shop_name'] ?? ''}')),
                      subtitle: Text(
                        _tp('acc_order_row_meta', {
                          'status': status,
                          'sales': formatIqd(m['total_sales'] as num?, lang: _lang),
                          'profit': formatIqd(m['gross_profit'] as num?, lang: _lang),
                          'pct': '${m['admin_commission'] ?? ''}',
                        }),
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        formatIqd(m['admin_earnings'] as num?, lang: _lang),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.forestGreen),
                      ),
                      onTap: () async {
                        final id = m['id'] as int?;
                        if (id == null) return;
                        final detail = await widget.api.getAccountingOrder(id);
                        if (!mounted) return;
                        _showOrderDetail(detail);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showOrderDetail(Map<String, dynamic> detail) {
    final order = Map<String, dynamic>.from(detail['order'] as Map? ?? {});
    final items = (detail['items'] as List?) ?? [];
    final status = AppStrings.statusLabel('${order['order_status'] ?? ''}', _lang);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(order['order_number']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${tx(order['shop_name']?.toString() ?? '')} · $status'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(_t('acc_chip_sales'), formatIqd(order['total_sales'] as num?, lang: _lang)),
                _chip(_t('acc_chip_cost'), formatIqd(order['product_costs'] as num?, lang: _lang)),
                _chip(_t('acc_chip_profit'), formatIqd(order['gross_profit'] as num?, lang: _lang)),
                _chip(_t('acc_chip_admin'), formatIqd(order['admin_earnings'] as num?, lang: _lang)),
                _chip(_t('acc_chip_seller'), formatIqd(order['seller_earnings'] as num?, lang: _lang)),
              ],
            ),
            const SizedBox(height: 16),
            Text(_t('acc_items_snapshot'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ...items.map((it) {
              final m = Map<String, dynamic>.from(it as Map);
              return ListTile(
                title: Text(tx('${m['product_name']} × ${m['quantity']}')),
                subtitle: Text(
                  _tp('acc_item_row_meta', {
                    'cost': formatIqd(m['cost_price'] as num?, lang: _lang),
                    'sell': formatIqd(m['selling_price'] as num?, lang: _lang),
                    'pct': '${m['commission_percentage'] ?? ''}',
                  }),
                ),
                trailing: Text(formatIqd(m['admin_share'] as num?, lang: _lang)),
              );
            }),
            const SizedBox(height: 12),
            if (order['order_status'] == 'delivered')
              ElevatedButton.icon(
                onPressed: () async {
                  final id = order['id'] as int?;
                  if (id == null) return;
                  await widget.api.refundAccountingOrder(id, full: true, reason: _t('acc_full_refund'));
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                },
                icon: const Icon(Icons.undo_rounded),
                label: Text(_t('acc_full_refund')),
                style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson, foregroundColor: RC.fg(Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  num _rateForSettingsStore(List<dynamic> stores, int? storeId, {required Object? fallback}) {
    if (storeId != null) {
      for (final raw in stores) {
        final m = Map<String, dynamic>.from(raw as Map);
        if (m['id'] == storeId) {
          return (m['commission_rate'] as num?) ?? (fallback as num? ?? 20);
        }
      }
    }
    return (fallback as num?) ?? 20;
  }

  void _selectSettingsStore(int? storeId) {
    final rate = _rateForSettingsStore(
      _settingsStores,
      storeId,
      fallback: _settings['default_commission_percentage'] ?? _settings['commission_percentage'] ?? 20,
    );
    setState(() {
      _settingsStoreId = storeId;
      _commissionCtrl.text = '$rate';
    });
  }

  Widget _buildSettings() {
    final history = (_settings['history'] as List?) ?? [];
    final pct = double.tryParse(_commissionCtrl.text.trim()) ?? 20;
    const exampleProfit = 2000;
    final exampleAdmin = (exampleProfit * pct / 100).round();
    final exampleSeller = exampleProfit - exampleAdmin;
    final globalPct = '${_settings['default_commission_percentage'] ?? _settings['commission_percentage'] ?? 20}';
    final selectedStoreName = () {
      if (_settingsStoreId == null) return null;
      for (final raw in _settingsStores) {
        final m = Map<String, dynamic>.from(raw as Map);
        if (m['id'] == _settingsStoreId) return _localizedStoreName(m);
      }
      return null;
    }();
    final vendorLabel = selectedStoreName ?? _t('acc_vendor_fallback');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_t('acc_settings_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(_t('acc_settings_help'), style: const TextStyle(color: RegaColors.lightMuted)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          key: ValueKey('commission-store-${_settingsStoreId ?? 'global'}'),
          initialValue: _settingsStoreId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _t('acc_vendor_store'),
            helperText: _t('acc_vendor_helper'),
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(_tp('acc_global_rate_option', {'pct': globalPct})),
            ),
            ..._settingsStores.map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              final id = m['id'] as int?;
              final name = _localizedStoreName(m);
              final rate = m['commission_rate'] ?? 20;
              return DropdownMenuItem<int?>(
                value: id,
                child: Text('$name — $rate%'),
              );
            }),
          ],
          onChanged: _selectSettingsStore,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commissionCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _settingsStoreId == null
                ? _t('acc_global_rate_label')
                : _tp('acc_vendor_rate_label', {'name': vendorLabel}),
            helperText: _t('acc_rate_helper'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RegaColors.orangeSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: RegaColors.orangeBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _settingsStoreId == null
                    ? _t('acc_example_global')
                    : _tp('acc_example_vendor', {'name': vendorLabel}),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _tp('acc_example_gross', {'amount': formatIqd(exampleProfit, lang: _lang)}),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _tp('acc_example_rate', {
                  'pct': pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1),
                }),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _tp('acc_example_admin_gets', {'amount': formatIqd(exampleAdmin, lang: _lang)}),
                style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF166534)), fontSize: 15),
              ),
              Text(
                _tp('acc_example_seller_keeps', {'amount': formatIqd(exampleSeller, lang: _lang)}),
                style: TextStyle(fontWeight: FontWeight.w800, color: RC.fg(Color(0xFFB45309))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final value = double.tryParse(_commissionCtrl.text.trim());
            if (value == null || value < 0 || value > 100) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_t('acc_rate_invalid')), backgroundColor: RegaColors.crimson),
              );
              return;
            }
            final note = _settingsStoreId == null ? _t('acc_note_global') : _t('acc_note_vendor');
            await widget.api.updateProfitSettings(
              value,
              storeId: _settingsStoreId,
              note: note,
            );
            await _loadAll();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _settingsStoreId == null
                      ? _t('acc_saved_global')
                      : _tp('acc_saved_vendor', {'name': vendorLabel}),
                ),
                backgroundColor: RegaColors.emerald,
              ),
            );
          },
          child: Text(_t('save')),
        ),
        const SizedBox(height: 24),
        Text(_t('acc_history_title'), style: const TextStyle(fontWeight: FontWeight.w900)),
        ...history.map((h) {
          final m = Map<String, dynamic>.from(h as Map);
          final changer = m['changer'] is Map ? (m['changer'] as Map)['name'] : null;
          final storeMap = m['store'] is Map ? Map<String, dynamic>.from(m['store'] as Map) : null;
          final scope = storeMap != null ? _localizedStoreName(storeMap) : _t('acc_global_scope');
          final note = (m['note']?.toString() ?? '').trim();
          final noteDisplay = _localizeHistoryNote(note);
          return ListTile(
            dense: true,
            title: Text('${m['commission_percentage']}% — $scope'),
            subtitle: Text('$noteDisplay · ${changer ?? _t('acc_system')} · ${m['created_at'] ?? ''}'),
          );
        }),
      ],
    );
  }

  /// Map known system notes so history stays in the active UI language.
  String _localizeHistoryNote(String note) {
    if (note.isEmpty) return '';
    final lower = note.toLowerCase();
    if (lower.contains('global') ||
        note.contains('ڕێژەی گشتی') ||
        note.contains('النسبة العامة') ||
        note.contains('Initial global')) {
      return _t('acc_note_global');
    }
    if (lower.contains('store') ||
        lower.contains('vendor') ||
        note.contains('دوکان') ||
        note.contains('المتجر') ||
        note.contains('کۆمیسیۆن')) {
      return _t('acc_note_vendor');
    }
    // Avoid mixing languages: hide opaque foreign notes in the UI chrome.
    final lang = _lang == 'ckb' ? 'ku' : _lang;
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(note);
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(note);
    if (lang == 'en' && hasArabic) return _t('acc_note_global');
    if (lang != 'en' && hasLatin && !hasArabic) {
      if (lower.contains('updated') || lower.contains('initial')) {
        return lower.contains('store') || lower.contains('vendor')
            ? _t('acc_note_vendor')
            : _t('acc_note_global');
      }
    }
    return note;
  }

  Widget _buildReports() {
    final periodLabel = switch (_report['period'] ?? _period) {
      'today' || 'day' || 'daily' => _t('acc_period_today'),
      'week' || 'weekly' => _t('acc_period_week'),
      'month' || 'monthly' => _t('acc_period_month'),
      'year' || 'yearly' => _t('acc_period_year'),
      final other => '$other',
    };
    final reportCards = <Widget>[
      StatKpiCard(
        title: _t('acc_kpi_revenue'),
        value: formatIqd(_report['total_revenue'] as num?, lang: _lang),
        icon: Icons.payments,
        accentColor: RegaColors.orange,
      ),
      StatKpiCard(
        title: _t('acc_chip_cost'),
        value: formatIqd(_report['total_costs'] as num?, lang: _lang),
        icon: Icons.inventory,
        accentColor: RegaColors.purple,
      ),
      StatKpiCard(
        title: _t('acc_kpi_gross_profit'),
        value: formatIqd(_report['gross_profit'] as num?, lang: _lang),
        icon: Icons.trending_up,
        accentColor: RegaColors.emerald,
      ),
      StatKpiCard(
        title: _t('acc_kpi_admin_profit'),
        value: formatIqd(_report['admin_earnings'] as num?, lang: _lang),
        icon: Icons.account_balance,
        accentColor: RegaColors.forestGreen,
      ),
      StatKpiCard(
        title: _t('acc_kpi_seller_profit'),
        value: formatIqd(_report['seller_earnings'] as num?, lang: _lang),
        icon: Icons.store,
        accentColor: RegaColors.goldDark,
      ),
      StatKpiCard(
        title: _t('acc_kpi_orders_short'),
        value: '${_report['total_orders'] ?? 0}',
        icon: Icons.receipt,
        accentColor: RegaColors.blue,
      ),
    ];
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 16),
      children: [
        Text(_tp('acc_report_title', {'period': periodLabel}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 600) {
              return Column(
                children: [
                  for (var i = 0; i < reportCards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: reportCards[i]),
                  ],
                ],
              );
            }
            final cols = c.maxWidth > 900 ? 3 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: reportCards,
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          _tp('acc_report_range', {
            'from': '${_report['from'] ?? '—'}',
            'to': '${_report['to'] ?? '—'}',
          }),
          style: const TextStyle(color: RegaColors.lightMuted),
        ),
        const SizedBox(height: 8),
        Text(_t('acc_csv_export_hint'), style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return Center(child: Text(_t('acc_no_refund_tx')));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = Map<String, dynamic>.from(_transactions[i] as Map);
        final order = m['order'] is Map ? Map<String, dynamic>.from(m['order'] as Map) : <String, dynamic>{};
        final title = order['order_number']?.toString() ??
            _tp('acc_order_number_fallback', {'id': '${m['order_id'] ?? ''}'});
        return ListTile(
          title: Text(title),
          subtitle: Text(
            _tp('acc_refund_row_meta', {
              'sales': formatIqd(m['refunded_sales'] as num?, lang: _lang),
              'admin': formatIqd(m['refunded_admin_share'] as num?, lang: _lang),
              'reason': '${m['reason'] ?? ''}',
              'date': '${m['created_at'] ?? ''}',
            }),
          ),
          isThreeLine: true,
          leading: const Icon(Icons.undo_rounded, color: RegaColors.crimson),
        );
      },
    );
  }
}
