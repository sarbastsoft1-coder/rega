import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../map/mapbox_tiles.dart';
import '../widgets/admin_top_header.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
/// Representation of a dashboard recent order
class RecentOrderEntry {
  final String orderCode;
  final String customerName;
  final String storeName;
  final String courierName;
  final String courierAvatar;
  final String status; // 'on_the_way' | 'completed' | 'delivered' | 'pending' | 'preparing'
  final String time;

  RecentOrderEntry({
    required this.orderCode,
    required this.customerName,
    required this.storeName,
    required this.courierName,
    required this.courierAvatar,
    required this.status,
    required this.time,
  });
}

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
  final TextEditingController _topSearchCtrl = TextEditingController();
  final MapController _mapController = MapController();
  Timer? _refreshTimer;
  bool _isLoading = true;

  String _selectedDays = 'days_7';
  String _selectedOrderFilter = 'filter_all';

  // Live KPI Metrics updated directly from PostgreSQL database
  String _todayOrders = '٠';
  String _activeCouriers = '٠';
  String _totalCustomers = '٠';
  String _totalStores = '٠';

  // Live Stacked Chart Data (Completed, Pending, OnTheWay) from PostgreSQL
  List<({String date, double completed, double pending, double onTheWay})> _chartData = [];

  // Active Couriers on the Map (Kalar / Kurdistan coordinates) from Fleet Radar
  List<LatLng> _courierPositions = [];
  // Real Kalar city center (Mapbox geocode) — old 34.6865 was north near سید خلیل
  final LatLng _centerLocus = const LatLng(34.6295, 45.3159);

  // Live Recent Orders from real backend
  List<RecentOrderEntry> _recentOrders = [];

  static String _toDigits(dynamic input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ku = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String s = input.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], ku[i]);
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadDashboardData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _topSearchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await widget.api.getDashboard(days: 7);
      final data = res['data'] as Map<String, dynamic>? ?? res;
      final kpis = data['kpis'] as Map<String, dynamic>? ?? {};

      // 1. Real KPIs from PostgreSQL database
      final todayCount = (kpis['today_orders'] as num?)?.toInt() ?? 0;
      final totalOrdersCount = (kpis['total_orders'] as num?)?.toInt() ?? 0;
      final onlineDriversCount = (kpis['online_drivers'] as num?)?.toInt() ?? (kpis['total_drivers'] as num?)?.toInt() ?? 0;
      final totalCustomersCount = (kpis['total_customers'] as num?)?.toInt() ?? 0;
      final totalStoresCount = (kpis['total_stores'] as num?)?.toInt() ?? (kpis['online_stores'] as num?)?.toInt() ?? 0;

      // 2. Real daily order-status chart (zeros when empty — no demo padding)
      final revChart = data['revenue_chart'] as List<dynamic>? ?? [];
      final List<({String date, double completed, double pending, double onTheWay})> mappedChart = [];
      if (revChart.isNotEmpty) {
        for (final item in revChart) {
          final m = item as Map<String, dynamic>;
          final label = _toDigits(m['label']?.toString() ?? '');
          final completed = (m['delivered_count'] as num?)?.toDouble() ?? 0.0;
          final pending = (m['pending_count'] as num?)?.toDouble() ??
              (m['active_count'] as num?)?.toDouble() ??
              0.0;
          final onTheWay = (m['on_the_way_count'] as num?)?.toDouble() ?? 0.0;
          mappedChart.add((date: label, completed: completed, pending: pending, onTheWay: onTheWay));
        }
      }

      // 3. Real Recent Orders from Customer / Vendor / Delivery apps
      final rawOrders = data['recent_orders'] as List<dynamic>? ?? [];
      final List<RecentOrderEntry> mappedOrders = [];
      for (final ro in rawOrders) {
        final m = ro as Map<String, dynamic>;
        final cust = m['customer'] as Map<String, dynamic>? ?? {};
        final store = m['store'] as Map<String, dynamic>? ?? {};
        final driver = m['driver'] as Map<String, dynamic>? ?? {};
        final orderNum = m['order_number']?.toString() ?? '#RA-${m['id']}';
        final custName = cust['name']?.toString() ?? m['customer_name']?.toString() ?? AppStrings.tr('customer_fallback', widget.lang);
        final storeName = store['name_ku']?.toString() ?? store['name_en']?.toString() ?? AppStrings.tr('store_fallback', widget.lang);
        final driverName = driver['name']?.toString() ?? AppStrings.tr('waiting_driver', widget.lang);
        final st = m['status']?.toString() ?? 'pending';
        final createdAt = m['created_at']?.toString() ?? '';
        String timeStr = 'ئێستا';
        if (createdAt.isNotEmpty) {
          try {
            final dt = DateTime.parse(createdAt);
            timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        mappedOrders.add(
          RecentOrderEntry(
            orderCode: orderNum,
            customerName: custName,
            storeName: storeName,
            courierName: driverName,
            courierAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=80&q=80',
            status: st,
            time: _toDigits(timeStr),
          ),
        );
      }

      // 4. Real Driver Positions from Fleet Radar
      final rawRadarDrivers = data['radar_drivers'] as List<dynamic>? ?? [];
      final List<LatLng> mappedPositions = [];
      for (final rd in rawRadarDrivers) {
        final m = rd as Map<String, dynamic>;
        final lat = (m['lat'] as num?)?.toDouble();
        final lng = (m['lng'] as num?)?.toDouble();
        if (lat != null && lng != null && lat != 0.0) {
          mappedPositions.add(LatLng(lat, lng));
        }
      }

      if (!mounted) return;
      setState(() {
        final displayOrders = todayCount > 0 ? todayCount : (totalOrdersCount > 0 ? totalOrdersCount : 0);
        _todayOrders = _toDigits(displayOrders);
        _activeCouriers = _toDigits(onlineDriversCount > 0 ? onlineDriversCount : 0);
        _totalCustomers = _toDigits(totalCustomersCount > 0 ? totalCustomersCount : 0);
        _totalStores = _toDigits(totalStoresCount > 0 ? totalStoresCount : 0);
        if (mappedChart.isNotEmpty) _chartData = mappedChart;
        if (mappedOrders.isNotEmpty) _recentOrders = mappedOrders;
        if (mappedPositions.isNotEmpty) _courierPositions = mappedPositions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padH = AdminBreakpoints.pagePadH(context);

    return Directionality(
      textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Executive Header Area (Matching Screenshot)
              _buildTopHeader(),
              if (_isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: LinearProgressIndicator(minHeight: 2, color: RC.bg(Color(0xFF113E2E)), backgroundColor: Colors.transparent),
                ),
              const SizedBox(height: 16),

              // 2. 4 Top KPI Metric Cards with Trends
              _buildKPICardsRow(),
              const SizedBox(height: 20),

              // 3. Middle Two-Column Grid: Left (Stacked Orders Chart) & Right (Live Couriers Map)
              _buildMiddleCardsRow(),
              const SizedBox(height: 20),

              // 4. Bottom Card: Latest Orders Table with Filter Tabs
              _buildLatestOrdersCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot Header with Profile, Bell Badge 5, Search)
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 820;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr('dashboard_title', widget.lang),
              style: TextStyle(
                fontSize: constraints.maxWidth < AdminBreakpoints.phone ? 18 : 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.tr('dashboard_subtitle', widget.lang),
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? RC.bg(Color(0xFF94A3B8))
                    : RC.bg(Color(0xFF6B7280)),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _topSearchCtrl,
          hintText: AppStrings.tr('dashboard_search_hint', widget.lang),
          onSearchChanged: (_) => setState(() {}),
        );

        if (constraints.maxWidth < AdminBreakpoints.headerCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
              const SizedBox(height: 12),
              title,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              Flexible(child: topActions),
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. 4 TOP KPI METRIC SUMMARY CARDS WITH TRENDS
  // ============================================================================
  Widget _buildKPICardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = width < AdminBreakpoints.phone ? 10.0 : 16.0;
        final int cols = width >= AdminBreakpoints.kpiFourCol
            ? 4
            : (width >= AdminBreakpoints.kpiTwoCol ? 2 : 1);
        final double cardWidth = AdminBreakpoints.cardWidth(width, cols, gap);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            // Card 1: داواکاریی ئەمڕۆ (Rightmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('dashboard_kpi_system_orders', widget.lang),
                value: _todayOrders,
                trend: AppStrings.tr('dashboard_kpi_system_orders_trend', widget.lang),
                icon: Icons.receipt_long_rounded,
                iconBg: RC.bg(Color(0xFFFFEDD5)),
                iconColor: RC.fg(Color(0xFFEA580C)),
                onTap: () => widget.onNavigateTab(1), // وەرگرتنی طلب
              ),
            ),
            // Card 2: ماتۆرسوارانی چالاک
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('dashboard_kpi_active_couriers', widget.lang),
                value: _activeCouriers,
                trend: AppStrings.tr('dashboard_kpi_active_couriers_trend', widget.lang),
                icon: Icons.two_wheeler_rounded,
                iconBg: RC.bg(Color(0xFFE8F5E9)),
                iconColor: RC.fg(Color(0xFF16A34A)),
                onTap: () => widget.onNavigateTab(3),
              ),
            ),
            // Card 3: کڕیاران
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('dashboard_kpi_customers_title', widget.lang),
                value: _totalCustomers,
                trend: AppStrings.tr('dashboard_kpi_customers_trend', widget.lang),
                icon: Icons.groups_rounded,
                iconBg: RC.bg(Color(0xFFE0F2FE)),
                iconColor: RC.fg(Color(0xFF0284C7)),
                onTap: () => widget.onNavigateTab(4),
              ),
            ),
            // Card 4: فرۆشیاران (Leftmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('dashboard_kpi_vendors_stores', widget.lang),
                value: _totalStores,
                trend: AppStrings.tr('dashboard_kpi_vendors_trend', widget.lang),
                icon: Icons.storefront_rounded,
                iconBg: RC.bg(Color(0xFFF3E8FF)),
                iconColor: RC.fg(Color(0xFF9333EA)),
                onTap: () => widget.onNavigateTab(5),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? RC.bg(Color(0xFF1F2937)) : RC.bg(Color(0xFFF1F5F9))),
          boxShadow: [
            BoxShadow(
              color: isDark ? RC.bg(Colors.black26) : RC.bg(Color(0x06000000)),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tx(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? RC.bg(Color(0xFF94A3B8)) : RC.bg(Color(0xFF4B5563)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              tx(value),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  tx(trend),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: RC.fg(Color(0xFF16A34A)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // ============================================================================
  // 3. MIDDLE CARDS: Chart Card (Left) & Live Map Card (Right)
  // ============================================================================
  Widget _buildMiddleCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AdminBreakpoints.chartsSideBySide;
        final phone = constraints.maxWidth < AdminBreakpoints.phone;
        final chartH = phone ? 280.0 : (constraints.maxWidth < AdminBreakpoints.tablet ? 320.0 : 340.0);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SizedBox(height: chartH, child: _buildChartCard())),
              const SizedBox(width: 16),
              Expanded(child: SizedBox(height: chartH, child: _buildMapCard())),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: phone ? 260.0 : chartH, child: _buildMapCard()),
            const SizedBox(height: 16),
            SizedBox(height: chartH, child: _buildChartCard()),
          ],
        );
      },
    );
  }

  // --- Right Card: شوێنی دلیڤەرییەکان (Live Map) ---
  Widget _buildMapCard() {
    final surfaces = AdminSurfaces.of(context);
    return Container(
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.hairline),
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.tr('dashboard_delivery_map', widget.lang),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: surfaces.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: surfaces.successSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: RC.fg(Color(0xFF16A34A))),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          AppStrings.tr('dashboard_delivery_riders_on_duty', widget.lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: RC.fg(Color(0xFF16A34A)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AdminSurfaces.of(context).hairline),

          // Interactive Map Area
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _centerLocus,
                      initialZoom: 14.2,
                      minZoom: 10.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      MapboxTiles.layer(
                        style: MapboxStyle.streets,
                        userAgentPackageName: 'iq.rega.admin',
                      ),
                      // Center radar pulse zone
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _centerLocus,
                            radius: 38,
                            useRadiusInMeter: false,
                            color: RC.bg(Color(0xFFFF5722)).withValues(alpha: 0.15),
                            borderColor: RC.bg(Color(0xFFFF5722)),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                      // Couriers and Central Location Pin
                      MarkerLayer(
                        markers: [
                          // Central Pin
                          Marker(
                            point: _centerLocus,
                            width: 84,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded, size: 22, color: RC.fg(Color(0xFFFF5722))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AdminSurfaces.of(context).card,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                                      boxShadow: [BoxShadow(color: RC.bg(Colors.black26), blurRadius: 4)],
                                    ),
                                    child: Text(
                                      tx('کەلار'),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        // Explicit dark ink: Marker subtree can inherit light
                                        // DefaultTextStyle (e.g. dark theme) → white-on-white.
                                        color: AdminSurfaces.of(context).textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 5 Motorcycle Couriers
                          ..._courierPositions.map(
                            (pos) => Marker(
                              point: pos,
                              width: 32,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFF113E2E)),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: RC.bg(Colors.white), width: 2),
                                  boxShadow: [BoxShadow(color: RC.bg(Colors.black26), blurRadius: 6)],
                                ),
                                child: Icon(Icons.two_wheeler_rounded, size: 16, color: RC.fg(Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Map Zoom Controls (+, -)
                  PositionedDirectional(
                    start: 12,
                    bottom: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AdminSurfaces.of(context).card,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: RC.bg(Colors.black12), blurRadius: 6)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _mapController.move(_centerLocus, _mapController.camera.zoom + 1),
                            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 18)),
                          ),
                          const Divider(height: 1),
                          InkWell(
                            onTap: () => _mapController.move(_centerLocus, _mapController.camera.zoom - 1),
                            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 18)),
                          ),
                          const Divider(height: 1),
                          InkWell(
                            onTap: () => _mapController.move(_centerLocus, 14.2),
                            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.my_location_rounded, size: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Left Card: چالاکیی داواکارییەکان (Stacked Bar Chart) ---
  Widget _buildChartCard() {
    final surfaces = AdminSurfaces.of(context);
    final days7 = AppStrings.tr('days_7', widget.lang);
    final days14 = AppStrings.tr('days_14', widget.lang);
    final days30 = AppStrings.tr('days_30', widget.lang);
    final dayKey = (_selectedDays == 'days_14' || _selectedDays == days14)
        ? 'days_14'
        : (_selectedDays == 'days_30' || _selectedDays == days30)
            ? 'days_30'
            : 'days_7';
    final dayValue = AppStrings.tr(dayKey, widget.lang);
    double maxScale = 400.0;
    for (final d in _chartData) {
      final tot = d.completed + d.pending + d.onTheWay;
      if (tot > maxScale) maxScale = tot;
    }
    maxScale = ((maxScale / 100).ceil() * 100).toDouble();
    if (maxScale < 400.0) maxScale = 400.0;

    return LayoutBuilder(
      builder: (context, cardC) {
        final narrow = cardC.maxWidth < 460 ||
            MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;
        return Container(
          decoration: BoxDecoration(
            color: surfaces.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surfaces.hairline),
            boxShadow: [
              BoxShadow(
                color: surfaces.shadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 12 : 20,
            vertical: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Title & Legend & Days Dropdown
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Text(
                        AppStrings.tr('dashboard_order_activity', widget.lang),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: surfaces.textPrimary,
                        ),
                      ),
                      _buildLegendDot(RC.bg(Color(0xFF166534)), AppStrings.tr('chart_legend_delivered', widget.lang)),
                      _buildLegendDot(RC.bg(Color(0xFFEA580C)), AppStrings.tr('chart_legend_pending', widget.lang)),
                      _buildLegendDot(RC.bg(Color(0xFFCBD5E1)), AppStrings.tr('chart_legend_on_the_way', widget.lang)),
                    ],
                  ),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surfaces.border),
                      color: surfaces.mutedFill,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dayValue,
                        isDense: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: surfaces.textSecondary),
                        dropdownColor: surfaces.card,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surfaces.textSecondary),
                        items: [
                          DropdownMenuItem(value: days7, child: Text(tx(days7))),
                          DropdownMenuItem(value: days14, child: Text(tx(days14))),
                          DropdownMenuItem(value: days30, child: Text(tx(days30))),
                        ],
                        onChanged: (v) {
                          if (v == days14) {
                            setState(() => _selectedDays = 'days_14');
                          } else if (v == days30) {
                            setState(() => _selectedDays = 'days_30');
                          } else {
                            setState(() => _selectedDays = 'days_7');
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Custom Stacked Bar Chart with Gridlines
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Y-Axis labels
                    Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tx('${maxScale.round()}'), style: TextStyle(fontSize: 10.5, color: RC.fg(Color(0xFF9CA3AF)), fontWeight: FontWeight.w700)),
                          Text(tx('${(maxScale * 0.75).round()}'), style: TextStyle(fontSize: 10.5, color: RC.fg(Color(0xFF9CA3AF)), fontWeight: FontWeight.w700)),
                          Text(tx('${(maxScale * 0.5).round()}'), style: TextStyle(fontSize: 10.5, color: RC.fg(Color(0xFF9CA3AF)), fontWeight: FontWeight.w700)),
                          Text(tx('${(maxScale * 0.25).round()}'), style: TextStyle(fontSize: 10.5, color: RC.fg(Color(0xFF9CA3AF)), fontWeight: FontWeight.w700)),
                          Text(tx('0'), style: TextStyle(fontSize: 10.5, color: RC.fg(Color(0xFF9CA3AF)), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Stacked Bars Area with Horizontal Dashed Gridlines
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, chartC) {
                          final availH = math.max(40.0, chartC.maxHeight - 28.0);
                          final minSlotW = narrow ? 36.0 : 48.0;
                          final needsScroll = _chartData.length * minSlotW > chartC.maxWidth;

                          return Stack(
                            children: [
                              // Gridlines
                              Positioned.fill(
                                bottom: 22,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    5,
                                    (index) => Container(
                                      height: 1,
                                      color: AdminSurfaces.of(context).chipFill,
                                    ),
                                  ),
                                ),
                              ),
                              // Vertical Stacked Columns
                              if (_chartData.isEmpty)
                                Positioned.fill(
                                  child: Center(
                                    child: Text(
                                      tx('زانیارییە داراییەکان لە سێرڤەرەوە باردەکرێن...'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: AdminSurfaces.of(context).textTertiary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                )
                              else if (needsScroll)
                                Positioned.fill(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: _chartData.length * minSlotW,
                                      height: chartC.maxHeight,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: _chartData
                                            .map((d) => SizedBox(
                                                  width: minSlotW,
                                                  child: _buildStackedBarColumn(
                                                    d,
                                                    availH: availH,
                                                    maxScale: maxScale,
                                                    narrow: narrow,
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned.fill(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: _chartData
                                        .map((d) => Expanded(
                                              child: _buildStackedBarColumn(
                                                d,
                                                availH: availH,
                                                maxScale: maxScale,
                                                narrow: narrow,
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    final surfaces = AdminSurfaces.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          tx(label),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surfaces.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStackedBarColumn(
    ({String date, double completed, double pending, double onTheWay}) d, {
    required double availH,
    required double maxScale,
    required bool narrow,
  }) {
    final barW = narrow ? 18.0 : 26.0;

    final hCompleted = (d.completed / maxScale) * availH;
    final hPending = (d.pending / maxScale) * availH;
    final hOnTheWay = (d.onTheWay / maxScale) * availH;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: barW,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: hOnTheWay, color: RC.bg(Color(0xFFCBD5E1))),
              Container(height: hPending, color: RC.bg(Color(0xFFEA580C))),
              Container(height: hCompleted, color: RC.bg(Color(0xFF166534))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tx(d.date),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: narrow ? 9 : 10,
            fontWeight: FontWeight.w700,
            color: AdminSurfaces.of(context).textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 4. BOTTOM CARD: داواکارییە نوێترینەکان (LATEST ORDERS TABLE)
  // ============================================================================
  Widget _buildLatestOrdersCard() {
    final surfaces = AdminSurfaces.of(context);
    TextStyle headerStyle() => TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: surfaces.textSecondary,
        );
    return Container(
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.hairline),
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title & Filter Pills
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 12 : 20,
              vertical: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.tr('dashboard_recent_orders', widget.lang),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill('filter_all'),
                      const SizedBox(width: 6),
                      _buildFilterPill('col_vendor'),
                      const SizedBox(width: 6),
                      _buildFilterPill('col_customer'),
                      const SizedBox(width: 6),
                      _buildFilterPill('col_courier'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: surfaces.hairline),

          LayoutBuilder(
            builder: (context, constraints) {
              if (_recentOrders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 36, color: RC.fg(Color(0xFFCBD5E1))),
                        SizedBox(height: 8),
                        Text(
                          tx('هیچ داواکارییەکی نوێ نییە'),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF94A3B8))),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Phones: stacked cards (no horizontal table scroll).
              if (constraints.maxWidth < AdminBreakpoints.phone) {
                return Column(
                  children: _recentOrders.map(_buildOrderMobileCard).toList(),
                );
              }

              final tableWidth = constraints.maxWidth > 720 ? constraints.maxWidth : 720.0;
              return Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(AppStrings.tr('col_order', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: headerStyle())),
                              const SizedBox(width: 6),
                              Expanded(flex: 2, child: Text(AppStrings.tr('col_customer', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: headerStyle())),
                              const SizedBox(width: 6),
                              Expanded(flex: 2, child: Text(AppStrings.tr('col_vendor', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: headerStyle())),
                              const SizedBox(width: 6),
                              Expanded(flex: 2, child: Text(AppStrings.tr('col_courier', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: headerStyle())),
                              const SizedBox(width: 6),
                              Expanded(flex: 2, child: Text(AppStrings.tr('col_status', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: headerStyle())),
                              const SizedBox(width: 6),
                              Expanded(flex: 1, child: Text(AppStrings.tr('col_time', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: headerStyle())),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: surfaces.hairline),
                        ..._recentOrders.map((o) => _buildOrderRow(o)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String key) {
    final surfaces = AdminSurfaces.of(context);
    final active = _selectedOrderFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedOrderFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? RC.bg(Color(0xFF113E2E)) : surfaces.chipFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          AppStrings.tr(key, widget.lang),
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            color: active ? RC.bg(Colors.white) : surfaces.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderMobileCard(RecentOrderEntry o) {
    final surfaces = AdminSurfaces.of(context);
    return InkWell(
      onTap: () => widget.onNavigateTab(1),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: surfaces.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tx(o.orderCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: _statusBg(o.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tx(_statusLabel(o.status)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _statusFg(o.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tx(o.customerName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: surfaces.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              tx(o.storeName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: surfaces.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.two_wheeler_rounded, size: 14, color: surfaces.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tx(o.courierName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surfaces.textPrimary),
                  ),
                ),
                Text(
                  tx(o.time),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: surfaces.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(RecentOrderEntry o) {
    final surfaces = AdminSurfaces.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      onTap: () => widget.onNavigateTab(1),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: surfaces.hairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
          // 1. داواکاری (#DK-78421 >)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    tx(o.orderCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  size: 16,
                  color: surfaces.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // 2. کڕیار
          Expanded(
            flex: 2,
            child: Text(
              tx(o.customerName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: surfaces.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 3. فرۆشیار
          Expanded(
            flex: 2,
            child: Text(
              tx(o.storeName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: surfaces.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 4. ماتۆرسوار (Avatar + Name)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    o.courierAvatar,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 24,
                      height: 24,
                      color: surfaces.chipFill,
                      child: Icon(Icons.two_wheeler_rounded, size: 14, color: surfaces.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tx(o.courierName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // 5. دۆخ (Status Pill)
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _statusBg(o.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tx(_statusLabel(o.status)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _statusFg(o.status),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 6. کات
          Expanded(
            flex: 1,
            child: Text(
              tx(o.time),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminSurfaces.of(context).textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Color _statusFg(String status) {
    switch (status) {
      case 'delivered':
      case 'completed':
        return RC.bg(Color(0xFF16A34A));
      case 'on_the_way':
      case 'arrived_customer':
      case 'picked_up':
        return RC.bg(Color(0xFFEA580C));
      case 'preparing':
      case 'ready':
        return RC.bg(Color(0xFF4338CA));
      case 'cancelled':
      case 'rejected':
        return RC.bg(Color(0xFFDC2626));
      case 'pending':
      default:
        return RC.bg(Color(0xFFD97706));
    }
  }

  String _statusLabel(String status) {
    if (status == 'completed') return AppStrings.statusLabel('delivered', widget.lang);
    return AppStrings.statusLabel(status, widget.lang);
  }

  Color _statusBg(String status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 'delivered':
      case 'completed':
        return dark ? RC.bg(Color(0xFF14532D)) : RC.bg(Color(0xFFDCFCE7));
      case 'on_the_way':
      case 'arrived_customer':
      case 'picked_up':
        return dark ? RC.bg(Color(0xFF3B2112)) : RC.bg(Color(0xFFFFEDD5));
      case 'preparing':
      case 'ready':
        return dark ? RC.bg(Color(0xFF1E1B4B)) : RC.bg(Color(0xFFE0E7FF));
      case 'cancelled':
      case 'rejected':
        return dark ? RC.bg(Color(0xFF3F1D1D)) : RC.bg(Color(0xFFFEE2E2));
      case 'pending':
      default:
        return dark ? RC.bg(Color(0xFF422006)) : RC.bg(Color(0xFFFEF3C7));
    }
  }
}
