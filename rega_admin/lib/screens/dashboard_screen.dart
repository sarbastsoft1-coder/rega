import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api/api_client.dart';

/// Representation of a dashboard recent order
class RecentOrderEntry {
  final String orderCode;
  final String customerName;
  final String storeName;
  final String courierName;
  final String courierAvatar;
  final String status; // 'on_the_way' | 'completed' | 'pending'
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

  String _selectedDays = '٧ ڕۆژی ڕابردوو';
  String _selectedOrderFilter = 'هەموو';

  // KPI Metrics matching screenshot exactly
  final String _todayOrders = '١,٢٨٤';
  final String _activeCouriers = '١٢٨';
  final String _totalCustomers = '٢٤,٨٥٠';
  final String _totalStores = '٣٤٢';

  // Demo Stacked Chart Data (Completed, Pending, OnTheWay) out of 400
  final List<({String date, double completed, double pending, double onTheWay})> _chartData = [
    (date: '١٠/٢٨', completed: 110, pending: 45, onTheWay: 65), // total 220
    (date: '١٠/٢٩', completed: 140, pending: 50, onTheWay: 90), // total 280
    (date: '١٠/٣٠', completed: 110, pending: 45, onTheWay: 65), // total 220
    (date: '١٠/٣١', completed: 155, pending: 50, onTheWay: 75), // total 280
    (date: '١١/٠١', completed: 185, pending: 65, onTheWay: 80), // total 330
    (date: '١١/٠٢', completed: 215, pending: 65, onTheWay: 70), // total 350
    (date: '١١/٠٣', completed: 165, pending: 55, onTheWay: 65), // total 285
  ];

  // 5 Active Couriers on the Map
  final List<LatLng> _courierPositions = const [
    LatLng(35.5620, 45.4280),
    LatLng(35.5560, 45.4410),
    LatLng(35.5490, 45.4190),
    LatLng(35.5680, 45.4490),
    LatLng(35.5420, 45.4350),
  ];
  final LatLng _centerLocus = const LatLng(35.5550, 45.4330);

  // Exact 5 initial rows from screenshot
  final List<RecentOrderEntry> _recentOrders = [
    RecentOrderEntry(
      orderCode: '#DK-78421',
      customerName: 'هیوا محەمەد',
      storeName: 'ڕێستورانتی ئامۆ',
      courierName: 'سەرباز عەلی',
      courierAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=80&q=80',
      status: 'on_the_way',
      time: '١٤:٢٥',
    ),
    RecentOrderEntry(
      orderCode: '#DK-78420',
      customerName: 'سارا عوسمان',
      storeName: 'مارکێتی ڕۆژ',
      courierName: 'ئارام حسێن',
      courierAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&q=80',
      status: 'completed',
      time: '١٣:١٠',
    ),
    RecentOrderEntry(
      orderCode: '#DK-78419',
      customerName: 'ئاوات نامیق',
      storeName: 'کافێی لاف',
      courierName: 'دڵشاد قادر',
      courierAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80&q=80',
      status: 'pending',
      time: '١٢:٤٠',
    ),
    RecentOrderEntry(
      orderCode: '#DK-78418',
      customerName: 'زەینەب ئەحمەد',
      storeName: 'فاست فوود شاز',
      courierName: 'هێمن خالید',
      courierAvatar: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=80&q=80',
      status: 'completed',
      time: '١١:٢٥',
    ),
    RecentOrderEntry(
      orderCode: '#DK-78417',
      customerName: 'محەمەد عارف',
      storeName: 'دەرمانخانەی سەلام',
      courierName: 'کاروان ئیسماعیل',
      courierAvatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=80&q=80',
      status: 'on_the_way',
      time: '١٠:٥٠',
    ),
  ];

  @override
  void dispose() {
    _topSearchCtrl.dispose();
    super.dispose();
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
              // 1. Top Executive Header Area (Matching Screenshot)
              _buildTopHeader(),
              const SizedBox(height: 20),

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
        final isNarrow = constraints.maxWidth < 760;

        final title = Column(
          crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: const [
            Text(
              'داشبۆردی بەڕێوەبەرایەتی',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'بەڕێوەبردنی یەکگرتووی خزمەتگوزاریی دلیڤەری',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final profileAndBell = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Avatar + Name (ئادەم محەمەد) + Role (بەڕێوەبەر) + Chevron
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&q=80',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 36,
                      height: 36,
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF6B7280), size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'ئادەم محەمەد',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      'بەڕێوەبەر',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280), size: 18),
              ],
            ),
            const SizedBox(width: 14),

            // Notification Bell with Badge 5
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF4B5563), size: 24),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: const Text(
                      '5',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        final searchBar = Container(
          width: isNarrow ? constraints.maxWidth : 220.0,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _topSearchCtrl,
                  decoration: const InputDecoration(
                    hintText: '...گەڕان',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  profileAndBell,
                  Expanded(child: title),
                ],
              ),
              const SizedBox(height: 12),
              searchBar,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  profileAndBell,
                  const SizedBox(width: 18),
                  searchBar,
                ],
              ),
              title,
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
        final double cardWidth;
        if (width >= 960) {
          cardWidth = (width - 48) / 4;
        } else if (width >= 560) {
          cardWidth = (width - 16) / 2;
        } else {
          cardWidth = width;
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: داواکاریی ئەمڕۆ (Rightmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'داواکاریی ئەمڕۆ',
                value: _todayOrders,
                trend: '↗ +12% لە دوێنێ دوێ',
                icon: Icons.receipt_long_rounded,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
              ),
            ),
            // Card 2: ماتۆرسوارانی چالاک
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'ماتۆرسوارانی چالاک',
                value: _activeCouriers,
                trend: '↗ +8% لە دوێنێ دوێ',
                icon: Icons.two_wheeler_rounded,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 3: کڕیاران
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'کڕیاران',
                value: _totalCustomers,
                trend: '↗ +5% لە دوێنێ دوێ',
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            // Card 4: فرۆشیاران (Leftmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'فرۆشیاران',
                value: _totalStores,
                trend: '↗ +3% لە دوێنێ دوێ',
                icon: Icons.storefront_rounded,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B5563),
                ),
              ),
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                trend,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. MIDDLE CARDS: Chart Card (Left) & Live Map Card (Right)
  // ============================================================================
  Widget _buildMiddleCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final halfWidth = (constraints.maxWidth - 16) / 2;

        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Card in RTL (Chart Card)
                  SizedBox(
                    width: halfWidth,
                    height: 340,
                    child: _buildChartCard(),
                  ),
                  const SizedBox(width: 16),
                  // Right Card in RTL (Map Card)
                  SizedBox(
                    width: halfWidth,
                    height: 340,
                    child: _buildMapCard(),
                  ),
                ],
              )
            : Column(
                children: [
                  SizedBox(height: 340, child: _buildMapCard()),
                  const SizedBox(height: 16),
                  SizedBox(height: 340, child: _buildChartCard()),
                ],
              );
      },
    );
  }

  // --- Right Card: شوێنی دلیڤەرییەکان (Live Map) ---
  Widget _buildMapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'شوێنی دلیڤەرییەکان',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
                      SizedBox(width: 5),
                      Text(
                        '٥ ماتۆرسوار لەسەر کارن',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

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
                      initialZoom: 13.5,
                      minZoom: 10.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'iq.rega.admin',
                      ),
                      // Center radar pulse zone
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _centerLocus,
                            radius: 38,
                            useRadiusInMeter: false,
                            color: const Color(0xFFFF5722).withValues(alpha: 0.15),
                            borderColor: const Color(0xFFFF5722),
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
                            width: 80,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 22, color: Color(0xFFFF5722)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                  ),
                                  child: const Text('هەولێر', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900)),
                                ),
                              ],
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
                                  color: const Color(0xFF113E2E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                ),
                                child: const Icon(Icons.two_wheeler_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Map Zoom Controls (+, -)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
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
                            onTap: () => _mapController.move(_centerLocus, 13.5),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title & Legend & Days Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title & Legend (Right in RTL)
              Row(
                children: [
                  const Text(
                    'چالاکیی داواکارییەکان',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Legend
                  _buildLegendDot(const Color(0xFF166534), 'تەواوبوو'),
                  const SizedBox(width: 10),
                  _buildLegendDot(const Color(0xFFEA580C), 'چاوەڕوان'),
                  const SizedBox(width: 10),
                  _buildLegendDot(const Color(0xFFCBD5E1), 'لە ڕێگادایە'),
                ],
              ),

              // Dropdown (Left in RTL)
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDays,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
                    items: const [
                      DropdownMenuItem(value: '٧ ڕۆژی ڕابردوو', child: Text('٧ ڕۆژی ڕابردوو')),
                      DropdownMenuItem(value: '١٤ ڕۆژی ڕابردوو', child: Text('١٤ ڕۆژی ڕابردوو')),
                      DropdownMenuItem(value: '٣٠ ڕۆژی ڕابردوو', child: Text('٣٠ ڕۆژی ڕابردوو')),
                    ],
                    onChanged: (v) => setState(() => _selectedDays = v ?? '٧ ڕۆژی ڕابردوو'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Custom Stacked Bar Chart with Gridlines
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-Axis labels (0, 100, 200, 300, 400)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('400', style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
                    Text('300', style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
                    Text('200', style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
                    Text('100', style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
                    Text('0', style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(width: 10),

                // Stacked Bars Area with Horizontal Dashed Gridlines
                Expanded(
                  child: Stack(
                    children: [
                      // Gridlines
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            5,
                            (index) => Container(
                              height: 1,
                              color: const Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                      ),
                      // 7 Vertical Stacked Columns
                      Positioned.fill(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _chartData.map((d) {
                            return _buildStackedBarColumn(d);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
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
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildStackedBarColumn(({String date, double completed, double pending, double onTheWay}) d) {
    const double maxScale = 400.0;
    const double chartMaxHeight = 175.0;

    final hCompleted = (d.completed / maxScale) * chartMaxHeight;
    final hPending = (d.pending / maxScale) * chartMaxHeight;
    final hOnTheWay = (d.onTheWay / maxScale) * chartMaxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Stacked Bar Container
        Container(
          width: 26,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Segment: لە ڕێگادایە (Grey)
              Container(
                height: hOnTheWay,
                color: const Color(0xFFCBD5E1),
              ),
              // Middle Segment: چاوەڕوان (Orange)
              Container(
                height: hPending,
                color: const Color(0xFFEA580C),
              ),
              // Bottom Segment: تەواوبوو (Green)
              Container(
                height: hCompleted,
                color: const Color(0xFF166534),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Date Label below bar
        Text(
          d.date,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 4. BOTTOM CARD: داواکارییە نوێترینەکان (LATEST ORDERS TABLE)
  // ============================================================================
  Widget _buildLatestOrdersCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title & Filter Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                // Filter Tabs on Left in RTL
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildFilterPill('فرۆشیار'),
                    _buildFilterPill('کڕیار'),
                    _buildFilterPill('ماتۆرسوار'),
                    _buildFilterPill('هەموو'),
                  ],
                ),

                // Title on Right in RTL
                const Text(
                  'داواکارییە نوێترینەکان',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth > 720 ? constraints.maxWidth : 720.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: const [
                            Expanded(flex: 2, child: Text('داواکاری', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6B7280)))),
                            Expanded(flex: 2, child: Text('کڕیار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6B7280)))),
                            Expanded(flex: 2, child: Text('فرۆشیار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6B7280)))),
                            Expanded(flex: 2, child: Text('ماتۆرسوار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6B7280)))),
                            Expanded(flex: 2, child: Text('دۆخ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6B7280)))),
                            Expanded(flex: 1, child: Text('کات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6B7280)))),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Table Rows
                      ..._recentOrders.map((o) => _buildOrderRow(o)),
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

  Widget _buildFilterPill(String label) {
    final active = _selectedOrderFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedOrderFilter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF113E2E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderRow(RecentOrderEntry o) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // 1. داواکاری (#DK-78421 >)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  o.orderCode,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left_rounded, size: 16, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),

          // 2. کڕیار
          Expanded(
            flex: 2,
            child: Text(
              o.customerName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // 3. فرۆشیار
          Expanded(
            flex: 2,
            child: Text(
              o.storeName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
          ),

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
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    o.courierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                  _statusLabel(o.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _statusFg(o.status),
                  ),
                ),
              ),
            ),
          ),

          // 6. کات
          Expanded(
            flex: 1,
            child: Text(
              o.time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFDCFCE7);
      case 'on_the_way':
        return const Color(0xFFFFEDD5);
      case 'pending':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF16A34A);
      case 'on_the_way':
        return const Color(0xFFEA580C);
      case 'pending':
      default:
        return const Color(0xFFD97706);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'تەواوبوو';
      case 'on_the_way':
        return 'لە ڕێگادایە';
      case 'pending':
      default:
        return 'چاوەڕوان';
    }
  }
}
