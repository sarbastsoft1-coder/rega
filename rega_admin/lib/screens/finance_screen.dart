import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

class FinanceScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const FinanceScreen({super.key, required this.api, required this.lang});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _selectedCity = 'هەموو شارەکان';
  String _selectedPeriod = 'ئەم مانگە';

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'ڕاپۆرتی کارایی و داهات هەناردەکرا بە سەرکەوتوویی',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF113E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Right side in RTL (First child): Title, Subtitle, and Export Button
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ڕاپۆرت و شیکاری',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'پوختەی کارایی و داهاتی خزمەتگوزاری دلیڤەری',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            // Export Button: هەناردەکردنی ڕاپۆرت
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
              label: const Text(
                'هەناردەکردنی ڕاپۆرت',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),

        // Left side in RTL (Second child): Date Dropdown, City Dropdown, Bell, Profile
        Row(
          children: [
            // Date Filter: ئەم مانگە
            _buildHeaderDropdownPill(
              icon: Icons.calendar_today_outlined,
              value: _selectedPeriod,
              items: const ['ئەم مانگە', 'مانگی پێشوو', 'ئەمساڵ'],
              onChanged: (v) => setState(() => _selectedPeriod = v ?? 'ئەم مانگە'),
            ),
            const SizedBox(width: 12),

            // City Filter: هەموو شارەکان
            _buildHeaderDropdownPill(
              icon: Icons.location_on_outlined,
              value: _selectedCity,
              items: const ['هەموو شارەکان', 'هەولێر', 'سلێمانی', 'دهۆک', 'کەلار'],
              onChanged: (v) => setState(() => _selectedCity = v ?? 'هەموو شارەکان'),
            ),
            const SizedBox(width: 16),

            // Notification Bell with Red Badge '1'
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569), size: 24),
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // User Avatar with Name "هێوا عەلی" / "بەڕێوەبەر"
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 22),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'هێوا عەلی',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'بەڕێوەبەر',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderDropdownPill({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
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
        final cardWidth = (constraints.maxWidth - 48) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: کۆی داواکارییەکان: ٣٨,٤٢٠ (Rightmost)
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'کۆی داواکارییەکان',
                value: '٣٨,٤٢٠',
                icon: Icons.inventory_2_outlined,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
              ),
            ),
            // Card 2: داهاتی گشتی: ١٢٨,٥٠٠,٠٠٠ د.ع
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'داهاتی گشتی',
                value: '١٢٨,٥٠٠,٠٠٠ د.ع',
                icon: Icons.monetization_on_outlined,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
              ),
            ),
            // Card 3: ڕێژەی تەواوکردن: ٩٦٪
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'ڕێژەی تەواوکردن',
                value: '٩٦٪',
                icon: Icons.check_circle_outline_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 4: کاتی گەیاندنی ناوەند: ٣٢ خولەک (Leftmost)
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'کاتی گەیاندنی ناوەند',
                value: '٣٢ خولەک',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
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
        if (constraints.maxWidth > 950) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1 (Right): باشترین فرۆشیاران (flex 4)
              Expanded(flex: 4, child: _buildTopVendorsCard()),
              const SizedBox(width: 16),

              // Card 2 (Middle): دۆخی داواکارییەکان (flex 3)
              Expanded(flex: 3, child: _buildOrderStatusDonutCard()),
              const SizedBox(width: 16),

              // Card 3 (Left): ڕەوتی داواکاری و داهات (flex 5)
              Expanded(flex: 5, child: _buildTrendsLineChartCard()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildTopVendorsCard(),
              const SizedBox(height: 16),
              _buildOrderStatusDonutCard(),
              const SizedBox(height: 16),
              _buildTrendsLineChartCard(),
            ],
          );
        }
      },
    );
  }

  // Card 1: باشترین فرۆشیاران (Top Vendors Horizontal Bar Chart)
  Widget _buildTopVendorsCard() {
    return Container(
      height: 270,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          const Text(
            'باشترین فرۆشیاران',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildVendorBarRow('کبابی هەولێر', 4280, 6000),
                _buildVendorBarRow('پیتزای ڕووناک', 3120, 6000),
                _buildVendorBarRow('بەرگەر لاند', 2650, 6000),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // X-axis scale labels: 0, 2,000, 4,000, 6,000
          Padding(
            padding: const EdgeInsets.only(right: 90),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('0', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                Text('2,000', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                Text('4,000', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                Text('6,000', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
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
                  color: const Color(0xFFF1F5F9),
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
          width: 44,
          child: Text(
            value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          const Text(
            'دۆخی داواکارییەکان',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
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
                        slices: const [
                          _Slice(0.96, Color(0xFF16503B)), // تەواوبوو 96%
                          _Slice(0.03, Color(0xFFEA580C)), // لە ڕێگادایە 3%
                          _Slice(0.01, Color(0xFFCBD5E1)), // هەڵوەشایەوە 1%
                        ],
                        strokeWidth: 16,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          '٣٨,٤٢٠',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'داواکاری',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '96%',
                          style: TextStyle(
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
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDonutLegendItem(const Color(0xFF16503B), 'تەواوبوو', '٩٦٪'),
              _buildDonutLegendItem(const Color(0xFFEA580C), 'لە ڕێگادایە', '٣٪'),
              _buildDonutLegendItem(const Color(0xFFCBD5E1), 'هەڵوەشایەوە', '١٪'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          const Text(
            'ڕەوتی داواکاری و داهات',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _DualAxisLineChartPainter(),
            ),
          ),
          const SizedBox(height: 6),
          // Legend below chart matching screenshot
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.circle, size: 8, color: Color(0xFF16503B)),
              SizedBox(width: 6),
              Text('ژمارەی داواکارییەکان', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              SizedBox(width: 20),
              Icon(Icons.circle, size: 8, color: Color(0xFFEA580C)),
              SizedBox(width: 6),
              Text('داهات (ع.د)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
            child: const Text(
              'کارایی ماتۆرسواران',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('ماتۆرسوار', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text('داواکاریی تەواوکراو', textAlign: TextAlign.center, style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text('کاتی ناوەند', textAlign: TextAlign.center, style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text('هەڵسەنگاندن', textAlign: TextAlign.left, style: _tableHeaderStyle)),
              ],
            ),
          ),

          // 3 Screenshot Driver Rows
          _buildDriverRow(
            rank: '١',
            name: 'ئارام محەمەد',
            completedOrders: '1,245',
            avgTime: '٢٨ خولەک',
            rating: '4.9',
            starCount: 5,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildDriverRow(
            rank: '٢',
            name: 'سامان قادر',
            completedOrders: '980',
            avgTime: '٣١ خولەک',
            rating: '4.7',
            starCount: 4,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildDriverRow(
            rank: '٣',
            name: 'دانا ڕەشید',
            completedOrders: '860',
            avgTime: '٣٦ خولەک',
            rating: '4.6',
            starCount: 4,
          ),
        ],
      ),
    );
  }

  static const TextStyle _tableHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
  );

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
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
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
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          // 3. Average Time
          Expanded(
            flex: 3,
            child: Text(
              avgTime,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
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
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
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
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => false;
}

// ============================================================================
// CUSTOM PAINTER: DUAL-AXIS LINE CHART
// ============================================================================
class _DualAxisLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 55.0;
    const rightPadding = 65.0;
    const topPadding = 24.0;
    const bottomPadding = 25.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // Draw horizontal grid lines & Y labels
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final leftYLabels = ['0', '5,000', '10,000', '15,000', '20,000'];
    final rightYLabels = ['0', '20,000,000', '40,000,000', '60,000,000', '80,000,000'];

    // Axis titles
    textPainter.text = const TextSpan(
      text: 'داواکارییەکان',
      style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(leftPadding - textPainter.width + 6, topPadding - 18));

    textPainter.text = const TextSpan(
      text: 'داهات (ع.د)',
      style: TextStyle(fontSize: 9.5, color: Color(0xFFEA580C), fontWeight: FontWeight.w700),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(leftPadding + chartWidth - 10, topPadding - 18));

    for (int i = 0; i < 5; i++) {
      final y = topPadding + chartHeight - (i * chartHeight / 4);

      // Grid line
      canvas.drawLine(Offset(leftPadding, y), Offset(leftPadding + chartWidth, y), gridPaint);

      // Left Y Label (داواکارییەکان)
      textPainter.text = TextSpan(
        text: leftYLabels[i],
        style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2));

      // Right Y Label (داهات)
      textPainter.text = TextSpan(
        text: rightYLabels[i],
        style: const TextStyle(fontSize: 9, color: Color(0xFFEA580C), fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding + chartWidth + 6, y - textPainter.height / 2));
    }

    // X month labels: ئایار, حوزەیران, تەمموز, ئاب
    final months = ['ئایار', 'حوزەیران', 'تەمموز', 'ئاب'];
    final xCoords = <double>[];
    for (int i = 0; i < months.length; i++) {
      final x = leftPadding + (i * chartWidth / (months.length - 1));
      xCoords.add(x);

      textPainter.text = TextSpan(
        text: months[i],
        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - bottomPadding + 6));
    }

    // Green line (Orders): 7,500, 11,200, 15,100, 19,300 (out of 20,000 max)
    final greenRatios = [7500 / 20000, 11200 / 20000, 15100 / 20000, 19300 / 20000];
    final greenPoints = <Offset>[];
    for (int i = 0; i < months.length; i++) {
      final y = topPadding + chartHeight - (greenRatios[i] * chartHeight);
      greenPoints.add(Offset(xCoords[i], y));
    }

    // Orange line (Revenue): 18M, 36M, 52M, 70M (out of 80M max)
    final orangeRatios = [18.0 / 80.0, 36.0 / 80.0, 52.0 / 80.0, 70.0 / 80.0];
    final orangePoints = <Offset>[];
    for (int i = 0; i < months.length; i++) {
      final y = topPadding + chartHeight - (orangeRatios[i] * chartHeight);
      orangePoints.add(Offset(xCoords[i], y));
    }

    // Draw green line
    final greenPaint = Paint()
      ..color = const Color(0xFF16503B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final greenDotPaint = Paint()
      ..color = const Color(0xFF16503B)
      ..style = PaintingStyle.fill;

    final greenPath = Path();
    for (int i = 0; i < greenPoints.length; i++) {
      if (i == 0) {
        greenPath.moveTo(greenPoints[i].dx, greenPoints[i].dy);
      } else {
        greenPath.lineTo(greenPoints[i].dx, greenPoints[i].dy);
      }
    }
    canvas.drawPath(greenPath, greenPaint);
    for (final pt in greenPoints) {
      canvas.drawCircle(pt, 4.5, greenDotPaint);
    }

    // Draw orange line
    final orangePaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final orangeDotPaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.fill;

    final orangePath = Path();
    for (int i = 0; i < orangePoints.length; i++) {
      if (i == 0) {
        orangePath.moveTo(orangePoints[i].dx, orangePoints[i].dy);
      } else {
        orangePath.lineTo(orangePoints[i].dx, orangePoints[i].dy);
      }
    }
    canvas.drawPath(orangePath, orangePaint);
    for (final pt in orangePoints) {
      canvas.drawCircle(pt, 4.5, orangeDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DualAxisLineChartPainter oldDelegate) => false;
}
