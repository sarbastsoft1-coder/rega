import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/services/excel_backup_service.dart';
import '../core/theme/admin_breakpoints.dart';
import '../widgets/admin_top_header.dart';
import '../core/theme/app_theme.dart';

class FinanceScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const FinanceScreen({super.key, required this.api, required this.lang});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Timer? _refreshTimer;
  String _selectedCity = 'all';
  String _selectedPeriod = 'this_month';

  // Live KPI Metrics from PostgreSQL database
  String _totalOrders = '٠';
  String _totalRevenue = '٠ د.ع';
  String _completionRate = '٠٪';
  String _avgDeliveryTime = '— خولەک';
  List<Map<String, dynamic>> _topDrivers = [];
  List<Map<String, dynamic>> _topStores = [];
  List<Map<String, dynamic>> _ordersRevenueMonthly = [];
  int _rawTotalOrders = 0;
  int _deliveredCount = 0;
  int _activeCount = 0;
  int _cancelledCount = 0;
  int _deliveredPct = 0;
  int _activePct = 0;
  int _cancelledPct = 0;
  int _topStoresMax = 1;

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
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  static String _formatInt(int n) {
    return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  static int _niceCeiling(int value) {
    if (value <= 0) return 1;
    final mag = math.pow(10, (math.log(value) / math.ln10).floor()).toInt();
    final step = mag < 1 ? 1 : mag;
    return ((value / step).ceil() * step).clamp(step, 1 << 30);
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      // ApiClient.getDashboard already unwraps `data`
      final data = await widget.api.getDashboard(days: 30);
      final kpis = data['kpis'] as Map<String, dynamic>? ?? {};

      final totalOrders = (kpis['total_orders'] as num?)?.toInt() ?? 0;
      final delivered = (kpis['delivered_orders'] as num?)?.toInt() ?? 0;
      final activeOrders = (kpis['active_orders_count'] as num?)?.toInt() ?? 0;
      final cancelledOrders = (kpis['cancelled_orders'] as num?)?.toInt() ?? 0;
      final gmv = (kpis['total_gmv'] as num?)?.toInt() ?? 0;
      final rate = (kpis['completion_rate'] as num?)?.toInt() ??
          (totalOrders > 0 ? ((delivered / totalOrders) * 100).round() : 0);
      final avgMins = (kpis['avg_delivery_minutes'] as num?)?.toInt() ?? 0;

      var drivers = (data['top_drivers'] as List<dynamic>? ?? [])
          .map((d) => Map<String, dynamic>.from(d as Map))
          .toList();

      if (drivers.isEmpty) {
        try {
          final resDrivers = await widget.api.getDrivers();
          if (resDrivers.isNotEmpty) {
            drivers = resDrivers.map((d) => Map<String, dynamic>.from(d as Map)).toList();
          }
        } catch (_) {}
      }

      // Prefer dashboard top_stores (sorted by real delivered orders / revenue)
      var stores = (data['top_stores'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      if (stores.isEmpty) {
        try {
          final resStores = await widget.api.getStores();
          stores = resStores.map((s) => Map<String, dynamic>.from(s as Map)).toList();
          stores.sort((a, b) {
            final ao = (a['delivered_orders_count'] as num?)?.toInt() ??
                (a['orders_count'] as num?)?.toInt() ??
                0;
            final bo = (b['delivered_orders_count'] as num?)?.toInt() ??
                (b['orders_count'] as num?)?.toInt() ??
                0;
            return bo.compareTo(ao);
          });
        } catch (_) {}
      }

      final monthly = (data['orders_revenue_monthly'] as List<dynamic>? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();

      final delPct = totalOrders > 0 ? ((delivered / totalOrders) * 100).round() : 0;
      final actPct = totalOrders > 0 ? ((activeOrders / totalOrders) * 100).round() : 0;
      final canPct = totalOrders > 0 ? ((cancelledOrders / totalOrders) * 100).round() : 0;

      final storeValues = stores.take(3).map((s) {
        return (s['gross_sales'] as num?)?.toInt() ??
            (s['delivered_orders_count'] as num?)?.toInt() ??
            (s['orders_count'] as num?)?.toInt() ??
            0;
      }).toList();
      final maxStore = storeValues.isEmpty ? 1 : storeValues.reduce(math.max);

      if (!mounted) return;
      setState(() {
        _rawTotalOrders = totalOrders;
        _deliveredCount = delivered;
        _activeCount = activeOrders;
        _cancelledCount = cancelledOrders;
        _deliveredPct = delPct;
        _activePct = actPct;
        _cancelledPct = canPct;
        _totalOrders = _toDigits(totalOrders);
        _totalRevenue = '${_toDigits(_formatInt(gmv))} د.ع';
        _completionRate = '${_toDigits(rate)}٪';
        _avgDeliveryTime = avgMins > 0
            ? '${_toDigits(avgMins)} خولەک'
            : '— خولەک';
        if (drivers.isNotEmpty) {
          _topDrivers = drivers;
        }
        _topStores = stores;
        _topStoresMax = _niceCeiling(maxStore);
        _ordersRevenueMonthly = monthly;
      });
    } catch (_) {}
  }

  bool _exporting = false;

  Future<void> _exportReport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final name = await ExcelBackupService(widget.api).downloadFullBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${AppStrings.tr('excel_backup_done', widget.lang)}: $name',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF113E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('excel_backup_failed', widget.lang)}: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padH = AdminBreakpoints.pagePadH(context);
    return Directionality(
      textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Area (Matching Screenshot)
              _buildTopHeader(),
              const SizedBox(height: 20),

              // 2. 4 Top KPI Metric Cards (Matching Screenshot)
              _buildKPICardsRow(),
              const SizedBox(height: 20),

              // 3. Middle Section: 3 Charts Row (Horizontal Bars, Donut, Dual Axis Line)
              _buildMiddleChartsRow(),
              const SizedBox(height: 20),

              // 4. Bottom Table Card: Driver Performance (Matching Screenshot)
              _buildDriverPerformanceCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot)
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        final titleAndButton = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('finance_title', widget.lang),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AdminSurfaces.of(context).textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.tr('finance_subtitle', widget.lang),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AdminSurfaces.of(context).textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _exportReport,
              icon: const Icon(Icons.file_download_outlined, size: 18, color: Colors.white),
              label: Text(
                AppStrings.tr('export_report', widget.lang),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );

        final topActions = const AdminTopBarRow();

        final filters = Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _buildHeaderDropdownPill(
              icon: Icons.calendar_today_outlined,
              value: _selectedPeriod,
              items: const ['this_month', 'last_month', 'this_year'],
              labels: [
                AppStrings.tr('this_month', widget.lang),
                AppStrings.tr('last_month', widget.lang),
                AppStrings.tr('this_year', widget.lang),
              ],
              onChanged: (v) => setState(() => _selectedPeriod = v ?? 'this_month'),
            ),
            _buildHeaderDropdownPill(
              icon: Icons.location_on_outlined,
              value: _selectedCity,
              items: ['all', ...AppStrings.knownCitiesKu],
              labels: [
                AppStrings.tr('all_cities', widget.lang),
                for (final c in AppStrings.knownCitiesKu) AppStrings.cityLabel(c, widget.lang),
              ],
              onChanged: (v) => setState(() => _selectedCity = v ?? 'all'),
            ),
          ],
        );

        if (constraints.maxWidth < AdminBreakpoints.headerCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
              const SizedBox(height: 12),
              titleAndButton,
              const SizedBox(height: 12),
              filters,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleAndButton,
              const SizedBox(height: 12),
              Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
              const SizedBox(height: 12),
              filters,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleAndButton),
                  const SizedBox(width: 12),
                  topActions,
                ],
              ),
              const SizedBox(height: 12),
              filters,
            ],
          );
        }
      },
    );
  }

  Widget _buildHeaderDropdownPill({
    required IconData icon,
    required String value,
    required List<String> items,
    List<String>? labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminSurfaces.of(context).textPrimary,
              ),
              items: [
                for (var i = 0; i < items.length; i++)
                  DropdownMenuItem<String>(
                    value: items[i],
                    child: Text(labels != null && i < labels.length ? labels[i] : items[i]),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. 4 TOP KPI METRIC CARDS (Matching Screenshot)
  // ============================================================================
  Widget _buildKPICardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double cardWidth;
        if (width >= AdminBreakpoints.kpiFourCol) {
          cardWidth = (width - 48) / 4;
        } else if (width >= AdminBreakpoints.kpiTwoCol) {
          cardWidth = (width - 16) / 2;
        } else {
          cardWidth = width;
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: کۆی داواکارییەکان (Live from DB)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_total_orders', widget.lang),
                value: _totalOrders,
                icon: Icons.inventory_2_outlined,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
              ),
            ),
            // Card 2: داهاتی گشتی (Live from DB)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_total_revenue', widget.lang),
                value: _totalRevenue,
                icon: Icons.monetization_on_outlined,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
              ),
            ),
            // Card 3: ڕێژەی تەواوکردن (Live from DB)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_completion_rate', widget.lang),
                value: _completionRate,
                icon: Icons.check_circle_outline_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 4: کاتی گەیاندنی ناوەند (Live from DB)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_avg_delivery', widget.lang),
                value: _avgDeliveryTime,
                icon: Icons.access_time_rounded,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
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
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Value & Title on the right in RTL
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminSurfaces.of(context).textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AdminSurfaces.of(context).textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          // Icon Box on the left in RTL
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. MIDDLE SECTION: 3 CHARTS ROW (Horizontal Bars, Donut, Dual Axis Line)
  // ============================================================================
  Widget _buildMiddleChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        // Desktop: Top Sellers | Order Status | Trends side-by-side
        if (w >= AdminBreakpoints.desktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: _buildTopVendorsCard()),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _buildOrderStatusDonutCard()),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: _buildTrendsLineChartCard()),
            ],
          );
        }

        // Tablet: Top Sellers + Order Status in a row, Trends full-width below
        if (w >= AdminBreakpoints.chartsTwoCol) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildTopVendorsCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _buildOrderStatusDonutCard()),
                ],
              ),
              const SizedBox(height: 16),
              _buildTrendsLineChartCard(),
            ],
          );
        }

        // Phone: stack all charts (wrappers only — chart painters unchanged)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopVendorsCard(),
            const SizedBox(height: 16),
            _buildOrderStatusDonutCard(),
            const SizedBox(height: 16),
            _buildTrendsLineChartCard(),
          ],
        );
      },
    );
  }

  // Card 1: باشترین فرۆشیاران (Top Vendors Horizontal Bar Chart)
  Widget _buildTopVendorsCard() {
    return Container(
      height: 270,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr('top_vendors', widget.lang),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AdminSurfaces.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _topStores.isEmpty
                ? Center(
                    child: Text(AppStrings.tr('loading_from_server', widget.lang), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _topStores.take(3).map((s) {
                      final name = s['name_ku']?.toString() ?? s['name_en']?.toString() ?? 'فرۆشگا';
                      // Prefer revenue (gross_sales); fall back to delivered order count
                      final value = (s['gross_sales'] as num?)?.toInt() ??
                          (s['delivered_orders_count'] as num?)?.toInt() ??
                          (s['orders_count'] as num?)?.toInt() ??
                          0;
                      return _buildVendorBarRow(name, value, _topStoresMax);
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          // X-axis scale labels — scaled to live max
          Padding(
            padding: const EdgeInsets.only(right: 90),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(fontSize: 10.5, color: AdminSurfaces.of(context).textTertiary, fontWeight: FontWeight.w600)),
                Text(_formatInt((_topStoresMax / 3).round()), style: TextStyle(fontSize: 10.5, color: AdminSurfaces.of(context).textTertiary, fontWeight: FontWeight.w600)),
                Text(_formatInt(((_topStoresMax * 2) / 3).round()), style: TextStyle(fontSize: 10.5, color: AdminSurfaces.of(context).textTertiary, fontWeight: FontWeight.w600)),
                Text(_formatInt(_topStoresMax), style: TextStyle(fontSize: 10.5, color: AdminSurfaces.of(context).textTertiary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorBarRow(String name, int value, int max) {
    final ratio = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminSurfaces.of(context).textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 22,
                decoration: BoxDecoration(
                  color: AdminSurfaces.of(context).chipFill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: ratio,
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16503B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            _toDigits(_formatInt(value)),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  // Card 2: دۆخی داواکارییەکان (Donut Chart)
  Widget _buildOrderStatusDonutCard() {
    return Container(
      height: 270,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr('order_status_chart', widget.lang),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AdminSurfaces.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: _DonutChartPainter(
                        slices: [
                          if (_rawTotalOrders <= 0)
                            const _Slice(1.0, Color(0xFFE2E8F0))
                          else ...[
                            _Slice(
                              (_deliveredCount / _rawTotalOrders).clamp(0.0, 1.0),
                              const Color(0xFF16503B),
                            ),
                            _Slice(
                              (_activeCount / _rawTotalOrders).clamp(0.0, 1.0),
                              const Color(0xFFEA580C),
                            ),
                            _Slice(
                              (_cancelledCount / _rawTotalOrders).clamp(0.0, 1.0),
                              const Color(0xFFCBD5E1),
                            ),
                          ],
                        ],
                        strokeWidth: 16,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _totalOrders,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AdminSurfaces.of(context).textPrimary,
                          ),
                        ),
                        Text(
                          'داواکاری',
                          style: TextStyle(
                            fontSize: 10,
                            color: AdminSurfaces.of(context).textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _completionRate,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend — live percentages from DB status counts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDonutLegendItem(const Color(0xFF16503B), AppStrings.tr('legend_delivered', widget.lang), '${_toDigits(_deliveredPct)}٪'),
              _buildDonutLegendItem(const Color(0xFFEA580C), AppStrings.tr('legend_on_way', widget.lang), '${_toDigits(_activePct)}٪'),
              _buildDonutLegendItem(const Color(0xFFCBD5E1), AppStrings.tr('legend_cancelled', widget.lang), '${_toDigits(_cancelledPct)}٪'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendItem(Color color, String label, String pct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 3),
        Text(
          pct,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  // Card 3: ڕەوتی داواکاری و داهات (Orders & Revenue Dual-Axis Chart)
  Widget _buildTrendsLineChartCard() {
    return Container(
      height: 270,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.tr('orders_revenue_trend', widget.lang),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AdminSurfaces.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _ordersRevenueMonthly.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.tr('loading_from_server', widget.lang),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                : CustomPaint(
                    painter: _DualAxisLineChartPainter(
                      series: _ordersRevenueMonthly,
                      lang: widget.lang,
                      gridColor: AdminSurfaces.of(context).hairline,
                      labelColor: AdminSurfaces.of(context).textSecondary,
                      mutedColor: AdminSurfaces.of(context).textTertiary,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          // Legend below chart matching screenshot
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF16503B)),
                  SizedBox(width: 6),
                  Text(AppStrings.tr('orders_axis', widget.lang), style: TextStyle(fontSize: 11, color: AdminSurfaces.of(context).textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFFEA580C)),
                  SizedBox(width: 6),
                  Text(AppStrings.tr('revenue_axis', widget.lang), style: TextStyle(fontSize: 11, color: AdminSurfaces.of(context).textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 4. BOTTOM TABLE CARD: DRIVER PERFORMANCE (Matching Screenshot)
  // ============================================================================
  Widget _buildDriverPerformanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Text(
              AppStrings.tr('courier_performance', widget.lang),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AdminSurfaces.of(context).textPrimary,
              ),
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < AdminBreakpoints.phone) {
                if (_topDrivers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    child: Center(
                      child: Text(
                        AppStrings.tr('no_courier_data', widget.lang),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  );
                }
                return Column(
                  children: _topDrivers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    final name = (d['name'] ?? d['full_name'] ?? 'ماتۆرسوار').toString();
                    final completedRaw = (d['completed_deliveries'] as num?)?.toInt() ??
                        (d['total_deliveries'] as num?)?.toInt() ??
                        (d['total_orders'] as num?)?.toInt() ??
                        0;
                    final avgMins = (d['avg_delivery_minutes'] as num?)?.toInt() ?? 0;
                    final ratingVal = d['rating'] != null ? d['rating'].toString() : '0';
                    final star = (double.tryParse(ratingVal) ?? 0).round().clamp(0, 5);
                    return Column(
                      children: [
                        _buildDriverMobileCard(
                          rank: _toDigits(i + 1),
                          name: name,
                          completedOrders: _toDigits(completedRaw),
                          avgTime: avgMins > 0 ? '${_toDigits(avgMins)} خولەک' : '— خولەک',
                          rating: ratingVal,
                          starCount: star,
                        ),
                        if (i < _topDrivers.length - 1) Divider(height: 1, color: AdminSurfaces.of(context).hairline),
                      ],
                    );
                  }).toList(),
                );
              }
              final tableWidth = constraints.maxWidth > 580 ? constraints.maxWidth : 580.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AdminSurfaces.of(context).mutedFill,
                          border: Border(
                            top: BorderSide(color: AdminSurfaces.of(context).hairline),
                            bottom: BorderSide(color: AdminSurfaces.of(context).hairline),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Text(AppStrings.tr('col_courier', widget.lang), textAlign: TextAlign.right, style: _tableHeaderStyle)),
                            Expanded(flex: 3, child: Text(AppStrings.tr('col_completed_orders', widget.lang), textAlign: TextAlign.center, style: _tableHeaderStyle)),
                            Expanded(flex: 3, child: Text(AppStrings.tr('col_avg_time', widget.lang), textAlign: TextAlign.center, style: _tableHeaderStyle)),
                            Expanded(flex: 3, child: Text(AppStrings.tr('col_rating', widget.lang), textAlign: TextAlign.left, style: _tableHeaderStyle)),
                          ],
                        ),
                      ),

                      if (_topDrivers.isNotEmpty)
                        ..._topDrivers.asMap().entries.map((entry) {
                          final i = entry.key;
                          final d = entry.value;
                          final name = (d['name'] ?? d['full_name'] ?? 'ماتۆرسوار').toString();
                          final completedRaw = (d['completed_deliveries'] as num?)?.toInt() ??
                              (d['total_deliveries'] as num?)?.toInt() ??
                              (d['total_orders'] as num?)?.toInt() ??
                              0;
                          final avgMins = (d['avg_delivery_minutes'] as num?)?.toInt() ?? 0;
                          final ratingVal = d['rating'] != null ? d['rating'].toString() : '0';
                          final star = (double.tryParse(ratingVal) ?? 0).round().clamp(0, 5);
                          return Column(
                            children: [
                              _buildDriverRow(
                                rank: _toDigits(i + 1),
                                name: name,
                                completedOrders: _toDigits(completedRaw),
                                avgTime: avgMins > 0
                                    ? '${_toDigits(avgMins)} خولەک'
                                    : '— خولەک',
                                rating: ratingVal,
                                starCount: star,
                              ),
                              if (i < _topDrivers.length - 1)
                                Divider(height: 1, color: AdminSurfaces.of(context).hairline),
                            ],
                          );
                        })
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text(
                              AppStrings.tr('no_courier_data', widget.lang),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  TextStyle get _tableHeaderStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AdminSurfaces.of(context).textSecondary,
  );

  Widget _buildDriverMobileCard({
    required String rank,
    required String name,
    required String completedOrders,
    required String avgTime,
    required String rating,
    required int starCount,
  }) {
    final surfaces = AdminSurfaces.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(rank, style: TextStyle(fontSize: 12, color: surfaces.textTertiary, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < starCount ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 14,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('تەواو: $completedOrders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: surfaces.textPrimary)),
              Text('کات: $avgTime', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surfaces.textSecondary)),
              Text('هەڵسەنگاندن: $rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surfaces.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRow({
    required String rank,
    required String name,
    required String completedOrders,
    required String avgTime,
    required String rating,
    required int starCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // 1. Driver Rank, Avatar and Name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    rank,
                    style: TextStyle(fontSize: 12, color: AdminSurfaces.of(context).textTertiary, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AdminSurfaces.of(context).chipFill,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // 2. Completed Orders
          Expanded(
            flex: 3,
            child: Text(
              completedOrders,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AdminSurfaces.of(context).textPrimary,
              ),
            ),
          ),

          // 3. Average Time
          Expanded(
            flex: 3,
            child: Text(
              avgTime,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminSurfaces.of(context).textSecondary,
              ),
            ),
          ),

          // 4. Rating with Gold Stars
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final isFilled = i < starCount;
                    return Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  rating,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AdminSurfaces.of(context).textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER: DONUT CHART
// ============================================================================
class _Slice {
  final double ratio;
  final Color color;
  const _Slice(this.ratio, this.color);
}

class _DonutChartPainter extends CustomPainter {
  final List<_Slice> slices;
  final double strokeWidth;

  _DonutChartPainter({required this.slices, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = slice.ratio * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (oldDelegate.slices.length != slices.length) return true;
    for (int i = 0; i < slices.length; i++) {
      if (oldDelegate.slices[i].ratio != slices[i].ratio ||
          oldDelegate.slices[i].color != slices[i].color) {
        return true;
      }
    }
    return oldDelegate.strokeWidth != strokeWidth;
  }
}

// ============================================================================
// CUSTOM PAINTER: DUAL-AXIS LINE CHART (live monthly series)
// ============================================================================
class _DualAxisLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> series;
  final String lang;
  final Color gridColor;
  final Color labelColor;
  final Color mutedColor;

  _DualAxisLineChartPainter({
    required this.series,
    required this.lang,
    required this.gridColor,
    required this.labelColor,
    required this.mutedColor,
  });

  static String _fmt(int n) {
    if (n >= 1000000) {
      final m = n / 1000000;
      return m == m.roundToDouble() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return n.toString();
  }

  static int _niceMax(int value) {
    if (value <= 0) return 1;
    final mag = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final step = mag < 1 ? 1.0 : mag;
    return ((value / step).ceil() * step).toInt().clamp(1, 1 << 30);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 42.0;
    const rightPadding = 48.0;
    const topPadding = 24.0;
    const bottomPadding = 25.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0 || series.isEmpty) return;

    final orders = series.map((e) => (e['orders_count'] as num?)?.toInt() ?? 0).toList();
    final gmvs = series.map((e) => (e['gmv'] as num?)?.toInt() ?? 0).toList();
    final labels = series.map((e) {
      final m = (e['month'] as num?)?.toInt();
      if (m != null) return AppStrings.monthLabel(m, lang);
      return e['label_ku']?.toString() ?? '';
    }).toList();

    final maxOrders = _niceMax(orders.fold<int>(0, math.max));
    final maxGmv = _niceMax(gmvs.fold<int>(0, math.max));

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: AppStrings.tr('orders_axis', lang),
      style: TextStyle(fontSize: 9.5, color: labelColor, fontWeight: FontWeight.w700),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(leftPadding - 4, topPadding - 18));

    textPainter.text = TextSpan(
      text: AppStrings.tr('revenue_axis', lang),
      style: TextStyle(fontSize: 9.5, color: Color(0xFFEA580C), fontWeight: FontWeight.w700),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(leftPadding + chartWidth - textPainter.width + 4, topPadding - 18));

    for (int i = 0; i < 5; i++) {
      final y = topPadding + chartHeight - (i * chartHeight / 4);
      canvas.drawLine(Offset(leftPadding, y), Offset(leftPadding + chartWidth, y), gridPaint);

      final leftVal = ((maxOrders * i) / 4).round();
      textPainter.text = TextSpan(
        text: _fmt(leftVal),
        style: TextStyle(fontSize: 9.5, color: mutedColor, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2));

      final rightVal = ((maxGmv * i) / 4).round();
      textPainter.text = TextSpan(
        text: _fmt(rightVal),
        style: const TextStyle(fontSize: 9, color: Color(0xFFEA580C), fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding + chartWidth + 6, y - textPainter.height / 2));
    }

    final count = series.length;
    final xCoords = <double>[];
    for (int i = 0; i < count; i++) {
      final x = count == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + (i * chartWidth / (count - 1));
      xCoords.add(x);

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(fontSize: 9.5, color: labelColor, fontWeight: FontWeight.w700),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - bottomPadding + 6));
    }

    final greenPoints = <Offset>[];
    final orangePoints = <Offset>[];
    for (int i = 0; i < count; i++) {
      final gy = topPadding + chartHeight - ((orders[i] / maxOrders) * chartHeight);
      final oy = topPadding + chartHeight - ((gmvs[i] / maxGmv) * chartHeight);
      greenPoints.add(Offset(xCoords[i], gy));
      orangePoints.add(Offset(xCoords[i], oy));
    }

    void drawSeries(List<Offset> points, Color color) {
      if (points.isEmpty) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final dot = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
      for (final pt in points) {
        canvas.drawCircle(pt, 4.0, dot);
      }
    }

    drawSeries(greenPoints, const Color(0xFF16503B));
    drawSeries(orangePoints, const Color(0xFFEA580C));
  }

  @override
  bool shouldRepaint(covariant _DualAxisLineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.mutedColor != mutedColor;
  }
}
