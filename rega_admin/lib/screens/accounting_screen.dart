import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

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
      final shopsRes = await widget.api.getAccountingShops(period: _period, q: _shopSearchCtrl.text.trim().isEmpty ? null : _shopSearchCtrl.text.trim());
      final ordersRes = await widget.api.getAccountingOrders(
        status: _orderStatus,
        orderId: _orderSearchCtrl.text.trim().isEmpty ? null : _orderSearchCtrl.text.trim(),
        storeId: _selectedShopId?.toString(),
      );
      final settings = await widget.api.getProfitSettings();
      final report = await widget.api.getAccountingReports(period: _period);
      final txRes = await widget.api.getAccountingTransactions();

      if (!mounted) return;
      setState(() {
        _dash = dash;
        _shops = shopsRes['data'] as List<dynamic>? ?? [];
        _orders = ordersRes['data'] as List<dynamic>? ?? [];
        _settings = settings;
        _commissionCtrl.text = '${settings['commission_percentage'] ?? dash['commission_percentage'] ?? 20}';
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
                  'ژمێریاری و قازانج',
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: surfaces.textPrimary,
                  ),
                ),
                Text(
                  'Accounting & Profit Management',
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
                    for (final p in const [
                      ('today', 'ڕۆژانە'),
                      ('week', 'هەفتانە'),
                      ('month', 'مانگانە'),
                      ('year', 'ساڵانە'),
                    ])
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
                tooltip: 'نوێکردنەوە',
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
            tabs: const [
              Tab(text: 'داشبۆرد'),
              Tab(text: 'قازانجی دوکان'),
              Tab(text: 'ژمێریاری داواکاری'),
              Tab(text: 'ڕێکخستنی قازانج'),
              Tab(text: 'ڕاپۆرتەکان'),
              Tab(text: 'مامەڵەکان'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: surfaces.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadAll, child: const Text('دووبارە هەوڵبدە')),
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

    final kpiCards = <Widget>[
      StatKpiCard(
        title: 'کۆی داواکاری',
        value: '${stats['total_orders'] ?? 0}',
        icon: Icons.receipt_long_rounded,
        accentColor: RegaColors.blue,
      ),
      StatKpiCard(
        title: 'تەواوکراو',
        value: '${stats['completed_orders'] ?? 0}',
        icon: Icons.check_circle_outline,
        accentColor: RegaColors.emerald,
      ),
      StatKpiCard(
        title: 'هەڵوەشاوە',
        value: '${stats['cancelled_orders'] ?? 0}',
        icon: Icons.cancel_outlined,
        accentColor: RegaColors.crimson,
      ),
      StatKpiCard(
        title: 'کۆی فرۆش',
        value: formatIqd(stats['total_sales_revenue'] as num?, lang: widget.lang),
        icon: Icons.payments_outlined,
        accentColor: RegaColors.orange,
      ),
      StatKpiCard(
        title: 'کۆی تێچوو',
        value: formatIqd(stats['total_product_costs'] as num?, lang: widget.lang),
        icon: Icons.inventory_2_outlined,
        accentColor: RegaColors.purple,
      ),
      StatKpiCard(
        title: 'قازانجی گشتی',
        value: formatIqd(stats['total_gross_profit'] as num?, lang: widget.lang),
        icon: Icons.trending_up_rounded,
        accentColor: RegaColors.emeraldDark,
      ),
      StatKpiCard(
        title: 'قازانجی ئەدمین',
        value: formatIqd(stats['total_admin_profit'] as num?, lang: widget.lang),
        icon: Icons.account_balance_rounded,
        accentColor: RegaColors.forestGreen,
        subtitle: '${_dash['commission_percentage'] ?? 20}%',
      ),
      StatKpiCard(
        title: 'قازانجی فرۆشیار',
        value: formatIqd(stats['total_seller_profit'] as num?, lang: widget.lang),
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
        Text('قازانج بەپێی دوکان', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...byShop.take(10).map((s) {
          final m = Map<String, dynamic>.from(s as Map);
          return ListTile(
            title: Text(m['name_ku']?.toString() ?? '—'),
            subtitle: Text('فرۆش: ${formatIqd(m['sales'] as num?, lang: widget.lang)}'),
            trailing: Text(
              formatIqd(m['admin_earnings'] as num?, lang: widget.lang),
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
        Text('بەرهەمە قازانجدارەکان', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...topProducts.take(10).map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          return ListTile(
            dense: true,
            title: Text(m['product_name']?.toString() ?? '—'),
            subtitle: Text('دانە: ${m['qty_sold'] ?? 0}'),
            trailing: Text(formatIqd(m['gross_profit'] as num?, lang: widget.lang)),
          );
        }),
        if (series.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('ڕێڕەوی داهات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
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
                      Text('${m['day']}'.split('T').first.split('-').last, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
              hintText: 'گەڕان بە ناوی دوکان…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _loadAll, icon: const Icon(Icons.check)),
            ),
            onSubmitted: (_) => _loadAll(),
          ),
        ),
        Expanded(
          child: _shops.isEmpty
              ? const Center(child: Text('هیچ دوکانێک نەدۆزرایەوە'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: _shops.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = Map<String, dynamic>.from(_shops[i] as Map);
                    return ListTile(
                      title: Text(m['name_ku']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        'داواکاری: ${m['total_orders'] ?? 0} · تەواوکراو: ${m['completed_orders'] ?? 0}\n'
                        'فرۆش: ${formatIqd(m['total_sales'] as num?, lang: widget.lang)} · قازانج: ${formatIqd(m['gross_profit'] as num?, lang: widget.lang)}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatIqd(m['admin_earnings'] as num?, lang: widget.lang),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.forestGreen)),
                          const Text('قەرزی ئەدمین', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                          Text(formatIqd(m['seller_earnings'] as num?, lang: widget.lang),
                              style: const TextStyle(fontSize: 12, color: RegaColors.goldDark)),
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
            Text(shop['name_ku']?.toString() ?? 'دوکان', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('هەڵبژێردراو — قەرزی ئەدمین بەپێی قازانج', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ئەمڕۆ پێویستە بدرێت بە ئەدمین', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    formatIqd(todayOwed, lang: widget.lang),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'فرۆشی ئەمڕۆ: ${formatIqd(todaySales, lang: widget.lang)} · قازانج: ${formatIqd(todayGross, lang: widget.lang)} · ڕێژە: $pct%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'نموونە: قازانج ٢٬٠٠٠ × ١٠٪ = ٢٠٠ د.ع بۆ ئەدمین (لەسەر قازانج، نەک فرۆش)',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip('فرۆش (ماوە)', formatIqd(summary['total_sales'] as num?, lang: widget.lang)),
                _chip('تێچوو', formatIqd(summary['total_product_costs'] as num?, lang: widget.lang)),
                _chip('قازانج', formatIqd(summary['gross_profit'] as num?, lang: widget.lang)),
                _chip('قەرزی ئەدمین $pct%', formatIqd(summary['admin_earnings'] as num?, lang: widget.lang)),
                _chip('بەشی فرۆشیار', formatIqd(summary['seller_earnings'] as num?, lang: widget.lang)),
                _chip('گەڕاندنەوە', formatIqd(summary['refunds'] as num?, lang: widget.lang)),
              ],
            ),
            const SizedBox(height: 18),
            const Text('ڕۆژانە — چەند دەبێت بدرێت بە ئەدمین', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            if (daily.isEmpty)
              Text('هیچ فرۆشێکی تەواوکراو لەم ماوەیەدا نییە', style: TextStyle(color: Colors.grey.shade600))
            else
              ...daily.map((d) {
                final m = Map<String, dynamic>.from(d as Map);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${m['day']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    'فرۆش ${formatIqd(m['sales'] as num?, lang: widget.lang)} · قازانج ${formatIqd(m['gross_profit'] as num?, lang: widget.lang)} · ${m['orders_count'] ?? 0} داواکاری',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatIqd(m['admin_owed'] as num?, lang: widget.lang),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                      ),
                      const Text('بۆ ئەدمین', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            const Text('بەرهەمەکان', style: TextStyle(fontWeight: FontWeight.w900)),
            ...products.map((p) {
              final m = Map<String, dynamic>.from(p as Map);
              return ListTile(
                dense: true,
                title: Text(m['product_name']?.toString() ?? ''),
                subtitle: Text('بەشی ئەدمین: ${formatIqd(m['admin_share'] as num?, lang: widget.lang)}'),
                trailing: Text(formatIqd(m['gross_profit'] as num?, lang: widget.lang)),
              );
            }),
            const SizedBox(height: 8),
            const Text('مێژووی داواکاری', style: TextStyle(fontWeight: FontWeight.w900)),
            ...orders.map((o) {
              final m = Map<String, dynamic>.from(o as Map);
              return ListTile(
                dense: true,
                title: Text(m['order_number']?.toString() ?? '#${m['id']}'),
                subtitle: Text('${m['status']} · ${m['created_at']}'),
                trailing: Text(formatIqd(m['admin_profit_amount'] as num?, lang: widget.lang)),
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
                  decoration: const InputDecoration(hintText: 'Order ID / Number', isDense: true),
                  onSubmitted: (_) => _loadAll(),
                ),
              ),
              DropdownButton<String>(
                value: _orderStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('هەموو')),
                  DropdownMenuItem(value: 'delivered', child: Text('گەیەندراو')),
                  DropdownMenuItem(value: 'cancelled', child: Text('هەڵوەشاوە')),
                  DropdownMenuItem(value: 'pending', child: Text('چاوەڕوان')),
                ],
                onChanged: (v) {
                  setState(() => _orderStatus = v ?? 'all');
                  _loadAll();
                },
              ),
              ElevatedButton(onPressed: _loadAll, child: const Text('فلتەر')),
            ],
          ),
        ),
        Expanded(
          child: _orders.isEmpty
              ? const Center(child: Text('هیچ داواکارییەک نەدۆزرایەوە'))
              : ListView.separated(
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = Map<String, dynamic>.from(_orders[i] as Map);
                    return ListTile(
                      title: Text('${m['order_number']} · ${m['shop_name'] ?? ''}'),
                      subtitle: Text(
                        '${m['order_status']} · فرۆش ${formatIqd(m['total_sales'] as num?, lang: widget.lang)} · '
                        'قازانج ${formatIqd(m['gross_profit'] as num?, lang: widget.lang)} · '
                        'کۆمیسیۆن ${m['admin_commission']}%',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        formatIqd(m['admin_earnings'] as num?, lang: widget.lang),
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
            Text('${order['shop_name']} · ${order['order_status']}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('فرۆش', formatIqd(order['total_sales'] as num?, lang: widget.lang)),
                _chip('تێچوو', formatIqd(order['product_costs'] as num?, lang: widget.lang)),
                _chip('قازانج', formatIqd(order['gross_profit'] as num?, lang: widget.lang)),
                _chip('ئەدمین', formatIqd(order['admin_earnings'] as num?, lang: widget.lang)),
                _chip('فرۆشیار', formatIqd(order['seller_earnings'] as num?, lang: widget.lang)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('بەرهەمەکان (snapshot)', style: TextStyle(fontWeight: FontWeight.w900)),
            ...items.map((it) {
              final m = Map<String, dynamic>.from(it as Map);
              return ListTile(
                title: Text('${m['product_name']} × ${m['quantity']}'),
                subtitle: Text(
                  'کڕین ${formatIqd(m['cost_price'] as num?, lang: widget.lang)} · '
                  'فرۆش ${formatIqd(m['selling_price'] as num?, lang: widget.lang)} · '
                  'کۆمیسیۆن ${m['commission_percentage']}%',
                ),
                trailing: Text(formatIqd(m['admin_share'] as num?, lang: widget.lang)),
              );
            }),
            const SizedBox(height: 12),
            if (order['order_status'] == 'delivered')
              ElevatedButton.icon(
                onPressed: () async {
                  final id = order['id'] as int?;
                  if (id == null) return;
                  await widget.api.refundAccountingOrder(id, full: true, reason: 'Admin full refund');
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('گەڕاندنەوەی تەواو'),
                style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson, foregroundColor: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    final history = (_settings['history'] as List?) ?? [];
    final pct = double.tryParse(_commissionCtrl.text.trim()) ?? 20;
    // Example matching: profit 2000 × 10% = 200 admin
    const exampleProfit = 2000;
    final exampleAdmin = (exampleProfit * pct / 100).round();
    final exampleSeller = exampleProfit - exampleAdmin;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ڕێکخستنی قازانج و کۆمیسیۆن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text(
          'یەک ڕێژەی جیهانی بۆ هەموو دوکان و بەرهەمەکان. کۆمیسیۆن لەسەر قازانجی سەرەتایی (فرۆش − تێچوو) حیساب دەکرێت، نەک لەسەر نرخی فرۆشتن.',
          style: TextStyle(color: RegaColors.lightMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commissionCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'ڕێژەی کۆمیسیۆنی ئەدمین (%)',
            helperText: '٠ تا ١٠٠ — تەنها بۆ داواکارییە نوێیەکان جێبەجێ دەبێت',
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
              const Text('نموونەی حیسابکردن (بۆ هەر دوکانێک / ڕۆژ)', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('قازانجی سەرەتایی: ${formatIqd(exampleProfit, lang: widget.lang)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('ڕێژەی ئەدمین: ${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '→ ئەدمین وەردەگرێت: ${formatIqd(exampleAdmin, lang: widget.lang)}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF166534), fontSize: 15),
              ),
              Text(
                '→ فرۆشیار دەمێنێتەوە: ${formatIqd(exampleSeller, lang: widget.lang)}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
              ),
              const SizedBox(height: 6),
              Text(
                'بۆ بینینی قەرزی ڕاستەقینەی هەر فرۆشیارێک بڕۆ بۆ تاب «قازانجی دوکان» و دوکان هەڵبژێرە.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
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
                const SnackBar(content: Text('ڕێژە دەبێت لە نێوان ٠ و ١٠٠ بێت'), backgroundColor: RegaColors.crimson),
              );
              return;
            }
            await widget.api.updateProfitSettings(value, note: 'Updated from admin accounting UI');
            await _loadAll();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ڕێکخستن پاشەکەوت کرا'), backgroundColor: RegaColors.emerald),
            );
          },
          child: const Text('پاشەکەوتکردن'),
        ),
        const SizedBox(height: 24),
        const Text('مێژووی گۆڕانکاری', style: TextStyle(fontWeight: FontWeight.w900)),
        ...history.map((h) {
          final m = Map<String, dynamic>.from(h as Map);
          final changer = m['changer'] is Map ? (m['changer'] as Map)['name'] : null;
          return ListTile(
            dense: true,
            title: Text('${m['commission_percentage']}%'),
            subtitle: Text('${m['note'] ?? ''} · ${changer ?? 'سیستەم'} · ${m['created_at'] ?? ''}'),
          );
        }),
      ],
    );
  }

  Widget _buildReports() {
    final reportCards = <Widget>[
      StatKpiCard(title: 'داهات', value: formatIqd(_report['total_revenue'] as num?, lang: widget.lang), icon: Icons.payments, accentColor: RegaColors.orange),
      StatKpiCard(title: 'تێچوو', value: formatIqd(_report['total_costs'] as num?, lang: widget.lang), icon: Icons.inventory, accentColor: RegaColors.purple),
      StatKpiCard(title: 'قازانجی گشتی', value: formatIqd(_report['gross_profit'] as num?, lang: widget.lang), icon: Icons.trending_up, accentColor: RegaColors.emerald),
      StatKpiCard(title: 'قازانجی ئەدمین', value: formatIqd(_report['admin_earnings'] as num?, lang: widget.lang), icon: Icons.account_balance, accentColor: RegaColors.forestGreen),
      StatKpiCard(title: 'قازانجی فرۆشیار', value: formatIqd(_report['seller_earnings'] as num?, lang: widget.lang), icon: Icons.store, accentColor: RegaColors.goldDark),
      StatKpiCard(title: 'داواکاری', value: '${_report['total_orders'] ?? 0}', icon: Icons.receipt, accentColor: RegaColors.blue),
    ];
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 16),
      children: [
        Text('ڕاپۆرت (${_report['period'] ?? _period})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
        Text('لە ${_report['from'] ?? '—'} تا ${_report['to'] ?? '—'}', style: const TextStyle(color: RegaColors.lightMuted)),
        const SizedBox(height: 8),
        const Text('CSV لە ڕێگەی /admin/accounting/reports/export هەناردە دەکرێت.', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('هیچ مامەڵەی گەڕاندنەوەیەک نییە'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = Map<String, dynamic>.from(_transactions[i] as Map);
        final order = m['order'] is Map ? Map<String, dynamic>.from(m['order'] as Map) : <String, dynamic>{};
        return ListTile(
          title: Text(order['order_number']?.toString() ?? 'Order #${m['order_id']}'),
          subtitle: Text(
            'فرۆش −${formatIqd(m['refunded_sales'] as num?, lang: widget.lang)} · '
            'ئەدمین −${formatIqd(m['refunded_admin_share'] as num?, lang: widget.lang)}\n'
            '${m['reason'] ?? ''} · ${m['created_at'] ?? ''}',
          ),
          isThreeLine: true,
          leading: const Icon(Icons.undo_rounded, color: RegaColors.crimson),
        );
      },
    );
  }
}
