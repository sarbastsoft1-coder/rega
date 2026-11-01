import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final ValueChanged<int> onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.api,
    required this.lang,
    required this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _days = 7;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.getDashboard(days: _days);
      if (mounted) {
        setState(() => _data = res);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data.isEmpty) {
      return ErrorRetryView(message: _error!, onRetry: _load);
    }

    final kpis = _data['kpis'] as Map<String, dynamic>? ?? {};
    final chart = _data['revenue_chart'] as List<dynamic>? ?? [];
    final statusBreakdown = _data['status_breakdown'] as Map<String, dynamic>? ?? {};
    final categorySales = _data['category_sales'] as List<dynamic>? ?? [];
    final topStores = _data['top_stores'] as List<dynamic>? ?? [];
    final topDrivers = _data['top_drivers'] as List<dynamic>? ?? [];
    final recentOrders = _data['recent_orders'] as List<dynamic>? ?? [];
    final radar = _data['fleet_radar'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionHeader(
            title: AppStrings.tr('nav_dashboard', widget.lang),
            subtitle: 'ئامار و داتای زیندووی پلاتفۆرمی REGA لەسەر داتابەیسی PostgreSQL',
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('٧ ڕۆژ')),
                ButtonSegment(value: 14, label: Text('١٤ ڕۆژ')),
                ButtonSegment(value: 30, label: Text('٣٠ ڕۆژ')),
              ],
              selected: {_days},
              onSelectionChanged: (val) {
                setState(() => _days = val.first);
                _load();
              },
            ),
          ),
          const SizedBox(height: 18),

          // 3 Core Ecosystem Parts (Vendor • Customer • Delivery)
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final cards = [
                _buildEcosystemPortalCard(
                  title: '١. بەشی فرۆشیاران (Vendor Part)',
                  subtitle: '${kpis['online_stores'] ?? 0}/${kpis['total_stores'] ?? 0} فرۆشگای ئۆنلاین • مێنۆ، چێشتخانە و کۆمیسیۆن',
                  badge: 'LIVE • rega_froshyar',
                  icon: Icons.storefront_rounded,
                  gradient: const [Color(0xFFEA580C), Color(0xFFD97706)],
                  onTap: () => widget.onNavigateTab(1),
                ),
                _buildEcosystemPortalCard(
                  title: '٢. بەشی کڕیاران (Customer Part)',
                  subtitle: '${kpis['total_customers'] ?? 0} کڕیار • داواکاری ڕاستەوخۆ، کۆپۆن، گەڕەکەکان و کۆدی کڕیار',
                  badge: 'LIVE • rega',
                  icon: Icons.shopping_bag_rounded,
                  gradient: const [Color(0xFF1E293B), Color(0xFF0F172A)],
                  accentText: RegaColors.gold,
                  onTap: () => widget.onNavigateTab(2),
                ),
                _buildEcosystemPortalCard(
                  title: '٣. بەشی گەیاندن (Delivery Part)',
                  subtitle: '${kpis['online_drivers'] ?? 0}/${kpis['total_drivers'] ?? 0} شۆفێری ئۆنلاین • نەخشەی ١ چرکەیی، KYC و کاشی COD',
                  badge: 'LIVE • rega_delivery',
                  icon: Icons.two_wheeler_rounded,
                  gradient: const [Color(0xFF059669), Color(0xFF047857)],
                  onTap: () => widget.onNavigateTab(3),
                ),
              ];
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[2]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 10),
                  cards[1],
                  const SizedBox(height: 10),
                  cards[2],
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 8 Executive KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1200
                  ? 4
                  : (constraints.maxWidth >= 700 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: cols == 1 ? 2.6 : 1.75,
                children: [
                  StatKpiCard(
                    title: AppStrings.tr('kpi_total_gmv', widget.lang),
                    value: formatIqd(kpis['total_gmv'] as num?, lang: widget.lang),
                    subtitle: 'ئەمڕۆ: ${formatIqd(kpis['today_gmv'] as num?, lang: widget.lang)}',
                    icon: Icons.payments_rounded,
                    accentColor: RegaColors.emeraldDark,
                    onTap: () => widget.onNavigateTab(11),
                  ),
                  StatKpiCard(
                    title: AppStrings.tr('kpi_commission', widget.lang),
                    value: formatIqd(kpis['platform_commission_earned'] as num?, lang: widget.lang),
                    subtitle: 'ئەمڕۆ: ${formatIqd(kpis['today_commission'] as num?, lang: widget.lang)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: RegaColors.goldDark,
                    onTap: () => widget.onNavigateTab(11),
                  ),
                  StatKpiCard(
                    title: AppStrings.tr('kpi_active_orders', widget.lang),
                    value: '${kpis['active_orders_count'] ?? 0}',
                    subtitle: '${kpis['pending_orders_count'] ?? 0} چاوەڕوانی قبوڵکردن',
                    icon: Icons.shopping_bag_rounded,
                    accentColor: RegaColors.orange,
                    onTap: () => widget.onNavigateTab(4),
                  ),
                  StatKpiCard(
                    title: AppStrings.tr('kpi_online_stores', widget.lang),
                    value: '${kpis['online_stores'] ?? 0} / ${kpis['total_stores'] ?? 0}',
                    subtitle: '${kpis['pending_stores'] ?? 0} چاوەڕوانی پەسەندکردن',
                    icon: Icons.storefront_rounded,
                    accentColor: RegaColors.blue,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  StatKpiCard(
                    title: AppStrings.tr('kpi_online_drivers', widget.lang),
                    value: '${kpis['online_drivers'] ?? 0} / ${kpis['total_drivers'] ?? 0}',
                    subtitle: '${kpis['pending_kyc_drivers'] ?? 0} چاوەڕوانی KYC',
                    icon: Icons.two_wheeler_rounded,
                    accentColor: RegaColors.emerald,
                    onTap: () => widget.onNavigateTab(3),
                  ),
                  StatKpiCard(
                    title: AppStrings.tr('kpi_cod_cash', widget.lang),
                    value: formatIqd(kpis['total_cod_cash_held'] as num?, lang: widget.lang),
                    subtitle: 'ئامادە بۆ پاکتاوکردن',
                    icon: Icons.request_quote_rounded,
                    accentColor: RegaColors.purple,
                    onTap: () => widget.onNavigateTab(3),
                  ),
                  StatKpiCard(
                    title: AppStrings.tr('kpi_customers', widget.lang),
                    value: formatNumber(kpis['total_customers'] as num?),
                    subtitle: 'کۆی داواکاری: ${kpis['total_orders'] ?? 0}',
                    icon: Icons.groups_rounded,
                    accentColor: const Color(0xFF0284C7),
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  StatKpiCard(
                    title: AppStrings.tr('kpi_open_tickets', widget.lang),
                    value: '${kpis['open_tickets_count'] ?? 0}',
                    subtitle: 'گەیەندراو: ${kpis['delivered_orders'] ?? 0}',
                    icon: Icons.support_agent_rounded,
                    accentColor: RegaColors.crimson,
                    onTap: () => widget.onNavigateTab(12),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Charts Row: Revenue & Commission Bar Chart + Status Donut Chart
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final revenueCard = _buildRevenueChartCard(chart);
              final statusCard = _buildStatusDonutCard(statusBreakdown);

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: revenueCard),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: statusCard),
                  ],
                );
              }
              return Column(
                children: [
                  revenueCard,
                  const SizedBox(height: 18),
                  statusCard,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Live Kalar Fleet & Store Radar + Category Sales Share
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final radarCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'نەخشەی ڕاداری زیندووی شاری کەلار',
                        subtitle: 'شوێنی فرۆشگا کراوەکان و شۆفێرە ئۆنلاینەکان لەم ساتەدا',
                      ),
                      const SizedBox(height: 14),
                      KalarFleetRadarMap(
                        stores: radar['stores'] as List<dynamic>? ?? [],
                        drivers: radar['drivers'] as List<dynamic>? ?? [],
                      ),
                    ],
                  ),
                ),
              );

              final catCard = _buildCategorySalesCard(categorySales);

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: radarCard),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: catCard),
                  ],
                );
              }
              return Column(
                children: [
                  radarCard,
                  const SizedBox(height: 18),
                  catCard,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Top Stores & Top Drivers
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final storesWidget = _buildTopStoresCard(topStores);
              final driversWidget = _buildTopDriversCard(topDrivers);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: storesWidget),
                    const SizedBox(width: 18),
                    Expanded(child: driversWidget),
                  ],
                );
              }
              return Column(
                children: [
                  storesWidget,
                  const SizedBox(height: 18),
                  driversWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Recent Live Orders Table
          _buildRecentOrdersCard(recentOrders),
        ],
      ),
    );
  }

  Widget _buildRevenueChartCard(List<dynamic> chart) {
    double maxY = 10000;
    for (final item in chart) {
      final gmv = ((item as Map<String, dynamic>)['gmv'] as num?)?.toDouble() ?? 0;
      if (gmv > maxY) maxY = gmv;
    }
    maxY = maxY * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'هێڵکاری فرۆش (GMV) و قازانجی کۆمیسیۆن',
              subtitle: 'بەراوردی ڕۆژانەی کۆی فرۆش و پشکی ١٢٪ی پلاتفۆرم بە دیناری عێراقی',
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 250,
              child: chart.isEmpty
                  ? const Center(child: Text('داتا بەردەست نییە'))
                  : BarChart(
                      BarChartData(
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: math.max(1, maxY / 4),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (val, _) {
                                if (val == 0) return const SizedBox.shrink();
                                return Text(
                                  '${(val / 1000).round()}k',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (val, _) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= chart.length) return const SizedBox.shrink();
                                if (chart.length > 14 && idx % 3 != 0) return const SizedBox.shrink();
                                final label = (chart[idx] as Map<String, dynamic>)['label']?.toString() ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(label, style: const TextStyle(fontSize: 10.5)),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(chart.length, (i) {
                          final row = chart[i] as Map<String, dynamic>;
                          final gmv = (row['gmv'] as num?)?.toDouble() ?? 0;
                          final comm = (row['commission'] as num?)?.toDouble() ?? 0;
                          return BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: gmv,
                                color: RegaColors.emerald,
                                width: chart.length > 14 ? 7 : 12,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                              BarChartRodData(
                                toY: comm,
                                color: RegaColors.gold,
                                width: chart.length > 14 ? 7 : 12,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.square_rounded, size: 12, color: RegaColors.emerald),
                SizedBox(width: 6),
                Text('کۆی فرۆش (GMV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                SizedBox(width: 20),
                Icon(Icons.square_rounded, size: 12, color: RegaColors.gold),
                SizedBox(width: 6),
                Text('کۆمیسیۆنی ڕێگا', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDonutCard(Map<String, dynamic> statusBreakdown) {
    final entries = statusBreakdown.entries.where((e) => ((e.value as num?) ?? 0) > 0).toList();
    final total = entries.fold<int>(0, (sum, e) => sum + ((e.value as num?)?.toInt() ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'دابەشبوونی بارودۆخی داواکارییەکان',
              subtitle: 'ڕێژەی سەرجەم قۆناغەکان',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 195,
              child: entries.isEmpty
                  ? const Center(child: Text('هیچ داواکارییەک نییە'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 42,
                        sections: entries.map((e) {
                          final val = (e.value as num).toDouble();
                          final pct = total > 0 ? ((val / total) * 100).round() : 0;
                          return PieChartSectionData(
                            value: val,
                            color: StatusBadge.colorFor(e.key),
                            radius: 44,
                            title: '$pct%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: StatusBadge.colorFor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${AppStrings.statusLabel(e.key, widget.lang)} (${e.value})',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySalesCard(List<dynamic> categories) {
    double maxRev = 1;
    for (final c in categories) {
      final rev = ((c as Map<String, dynamic>)['revenue'] as num?)?.toDouble() ?? 0;
      if (rev > maxRev) maxRev = rev;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'فرۆش بەپێی بەشەکانی بازاڕ',
              subtitle: 'پڕفرۆشترین کەرتەکان لە کەلار',
            ),
            const SizedBox(height: 16),
            ...categories.take(7).map((raw) {
              final c = raw as Map<String, dynamic>;
              final rev = (c['revenue'] as num?)?.toDouble() ?? 0;
              final ratio = (rev / maxRev).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c['name_ku']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        Text(
                          formatIqd(rev, lang: widget.lang),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: RegaColors.emeraldDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: RegaColors.goldDark,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStoresCard(List<dynamic> stores) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'پڕفرۆشترین فرۆشگاکان',
              trailing: TextButton(
                onPressed: () => widget.onNavigateTab(1),
                child: const Text('بینینی هەمووی'),
              ),
            ),
            const SizedBox(height: 12),
            ...stores.map((raw) {
              final s = raw as Map<String, dynamic>;
              final online = s['is_online'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: RegaColors.gold.withValues(alpha: 0.2),
                  child: const Icon(Icons.storefront_rounded, color: RegaColors.goldDark),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s['name_ku']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online ? RegaColors.emerald : Colors.grey,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${s['category_name'] ?? ''} • ${s['delivered_orders_count'] ?? 0} داواکاری • کۆمیسیۆن: ${formatIqd(s['platform_commission'] as num?, lang: widget.lang)}',
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: Text(
                  formatIqd(s['gross_sales'] as num?, lang: widget.lang),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark, fontSize: 13),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDriversCard(List<dynamic> drivers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'چالاکترین شۆفێرەکان',
              trailing: TextButton(
                onPressed: () => widget.onNavigateTab(3),
                child: const Text('بینینی هەمووی'),
              ),
            ),
            const SizedBox(height: 12),
            ...drivers.map((raw) {
              final d = raw as Map<String, dynamic>;
              final online = d['is_online'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: (online ? RegaColors.emerald : Colors.grey).withValues(alpha: 0.16),
                  child: Icon(
                    Icons.two_wheeler_rounded,
                    color: online ? RegaColors.emeraldDark : Colors.grey,
                  ),
                ),
                title: Text(
                  '${d['name'] ?? ''} (${d['driver_code'] ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                subtitle: Text(
                  '${d['motor_type'] ?? ''} • ⭐ ${d['rating'] ?? 5.0} • کاشی لای شۆفێر: ${formatIqd(d['cash_collected_hand'] as num?, lang: widget.lang)}',
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: RegaColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${d['total_deliveries'] ?? 0} گەیاندن',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: RegaColors.emeraldDark),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrdersCard(List<dynamic> recentOrders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'نوێترین داواکارییەکان',
              subtitle: 'دوایین ١٠ داواکاری تۆمارکراو لە سیستەمدا',
              trailing: ElevatedButton.icon(
                onPressed: () => widget.onNavigateTab(4),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('بەڕێوەبردنی داواکارییەکان'),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                columns: const [
                  DataColumn(label: Text('ژمارەی داواکاری', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('فرۆشگا', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('کڕیار', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('شۆفێر', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('کۆی گشتی', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('کۆمیسیۆن', style: TextStyle(fontWeight: FontWeight.w800))),
                  DataColumn(label: Text('بارودۆخ', style: TextStyle(fontWeight: FontWeight.w800))),
                ],
                rows: recentOrders.map((raw) {
                  final o = raw as Map<String, dynamic>;
                  final store = o['store'] as Map<String, dynamic>?;
                  final driver = o['driver'] as Map<String, dynamic>?;
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        o['order_number']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      )),
                      DataCell(Text(store?['name_ku']?.toString() ?? '-')),
                      DataCell(Text('${o['customer_name'] ?? ''} (${o['customer_phone'] ?? ''})')),
                      DataCell(Text(driver?['name']?.toString() ?? 'دیاری نەکراوە')),
                      DataCell(Text(
                        formatIqd(o['total_amount'] as num?, lang: widget.lang),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      )),
                      DataCell(Text(
                        formatIqd(o['commission_amount'] as num?, lang: widget.lang),
                        style: const TextStyle(color: RegaColors.emeraldDark, fontWeight: FontWeight.w700),
                      )),
                      DataCell(StatusBadge(status: o['status']?.toString() ?? 'pending', lang: widget.lang)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEcosystemPortalCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required List<Color> gradient,
    Color accentText = Colors.white,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            border: accentText == RegaColors.gold
                ? Border.all(color: RegaColors.gold.withValues(alpha: 0.5), width: 1.3)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentText == RegaColors.gold
                          ? RegaColors.gold
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      color: accentText == RegaColors.gold ? const Color(0xFF0F172A) : Colors.white,
                      size: 22,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(color: accentText, fontSize: 10.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(color: accentText, fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
