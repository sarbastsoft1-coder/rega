import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api/api_client.dart';

/// Representation of a courier matching the exact design in the screenshot
class CourierItem {
  final int id;
  final String name;
  final String phone;
  final String city;
  final String status; // 'active' (چالاک), 'on_the_way' (لە دلیڤەری), 'offline' (ناچالاک)
  final int todayOrders;
  final String avatarUrl;
  final String motorType;
  final String plateNumber;
  final LatLng location;
  final bool isVerified;
  final num cashCollected;
  final num walletBalance;

  CourierItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.status,
    required this.todayOrders,
    required this.avatarUrl,
    required this.motorType,
    required this.plateNumber,
    required this.location,
    this.isVerified = true,
    this.cashCollected = 0,
    this.walletBalance = 0,
  });

  CourierItem copyWith({
    int? id,
    String? name,
    String? phone,
    String? city,
    String? status,
    int? todayOrders,
    String? avatarUrl,
    String? motorType,
    String? plateNumber,
    LatLng? location,
    bool? isVerified,
    num? cashCollected,
    num? walletBalance,
  }) {
    return CourierItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      status: status ?? this.status,
      todayOrders: todayOrders ?? this.todayOrders,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      motorType: motorType ?? this.motorType,
      plateNumber: plateNumber ?? this.plateNumber,
      location: location ?? this.location,
      isVerified: isVerified ?? this.isVerified,
      cashCollected: cashCollected ?? this.cashCollected,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}

class DriversScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const DriversScreen({super.key, required this.api, required this.lang});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();

  int _currentPage = 1;
  String _selectedCity = 'هەموو شارەکان';
  String _selectedStatus = 'هەموو دۆخەکان';
  String _selectedDate = 'ئەمڕۆ';

  // KPI Metrics matching exact screenshot values
  final String _totalDriversKPI = '٢٤٨';
  final String _activeDriversKPI = '١٢٨';
  final String _inDeliveryKPI = '٣٤';
  final String _pendingApprovalKPI = '٩';

  // Demo Couriers matching the screenshot table exactly
  final List<CourierItem> _initialDemoCouriers = [
    CourierItem(
      id: 1,
      name: 'ئارام حوسێن',
      phone: '0750 123 4567',
      city: 'هەولێر',
      status: 'active',
      todayOrders: 12,
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      motorType: 'Honda CBR 150R',
      plateNumber: 'KLR-402',
      location: const LatLng(36.1911, 44.0091),
      isVerified: true,
      cashCollected: 45000,
      walletBalance: 18500,
    ),
    CourierItem(
      id: 2,
      name: 'سەرباز قادر',
      phone: '0750 234 5678',
      city: 'سلێمانی',
      status: 'on_the_way',
      todayOrders: 8,
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      motorType: 'Yamaha NMAX 155',
      plateNumber: 'KLR-819',
      location: const LatLng(36.1820, 44.0200),
      isVerified: true,
      cashCollected: 62000,
      walletBalance: 24000,
    ),
    CourierItem(
      id: 3,
      name: 'هێمن ئەحمەد',
      phone: '0750 345 6789',
      city: 'دهۆک',
      status: 'offline',
      todayOrders: 5,
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      motorType: 'Bajaj Pulsar 200',
      plateNumber: 'ERB-3104',
      location: const LatLng(36.1985, 43.9980),
      isVerified: true,
      cashCollected: 38000,
      walletBalance: 31000,
    ),
    CourierItem(
      id: 4,
      name: 'دانا مەحموود',
      phone: '0750 456 7890',
      city: 'هەولێر',
      status: 'active',
      todayOrders: 11,
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
      motorType: 'TVS HLX 150',
      plateNumber: 'KLR-552',
      location: const LatLng(36.2050, 44.0150),
      isVerified: true,
      cashCollected: 19000,
      walletBalance: 9500,
    ),
    CourierItem(
      id: 5,
      name: 'ڕێبین ساڵح',
      phone: '0750 567 8901',
      city: 'سلێمانی',
      status: 'on_the_way',
      todayOrders: 7,
      avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
      motorType: 'Suzuki Haojue 125',
      plateNumber: 'KLR-901',
      location: const LatLng(36.1750, 44.0010),
      isVerified: true,
      cashCollected: 51000,
      walletBalance: 16000,
    ),
  ];

  late List<CourierItem> _couriers;

  @override
  void initState() {
    super.initState();
    _couriers = List.from(_initialDemoCouriers);
    _loadFromBackend();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend() async {
    try {
      final backendList = await widget.api.getDrivers();
      if (!mounted) return;

      if (backendList.isNotEmpty) {
        final List<CourierItem> merged = [];

        for (final item in backendList) {
          final m = item as Map<String, dynamic>;
          final u = m['user'] as Map<String, dynamic>? ?? {};
          final isOnline = m['is_online'] == true;
          final isVerified = m['is_verified'] == true;

          merged.add(
            CourierItem(
              id: m['id'] as int? ?? (100 + merged.length),
              name: u['name']?.toString() ?? 'شۆفێری ڕێگا',
              phone: u['phone']?.toString() ?? '0750 000 0000',
              city: 'هەولێر',
              status: isOnline ? 'active' : 'offline',
              todayOrders: (m['total_deliveries'] as num?)?.toInt() ?? 5,
              avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
              motorType: m['motor_type']?.toString() ?? 'هۆندا',
              plateNumber: m['plate_number']?.toString() ?? 'KLR-100',
              location: LatLng(
                36.1911 + (math.Random().nextDouble() - 0.5) * 0.03,
                44.0091 + (math.Random().nextDouble() - 0.5) * 0.03,
              ),
              isVerified: isVerified,
              cashCollected: (m['cash_collected_hand'] as num?) ?? 0,
              walletBalance: (m['wallet_balance'] as num?) ?? 0,
            ),
          );
        }

        for (final d in _initialDemoCouriers) {
          if (!merged.any((x) => x.name == d.name)) {
            merged.add(d);
          }
        }

        setState(() {
          _couriers = merged;
        });
      }
    } catch (_) {}
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF113E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<CourierItem> get _filteredCouriers {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _couriers.where((c) {
      if (query.isNotEmpty) {
        final matchName = c.name.toLowerCase().contains(query);
        final matchPhone = c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
        final matchCity = c.city.toLowerCase().contains(query);
        if (!matchName && !matchPhone && !matchCity) return false;
      }
      if (_selectedCity != 'هەموو شارەکان' && c.city != _selectedCity) return false;
      if (_selectedStatus == 'چالاک' && c.status != 'active') return false;
      if (_selectedStatus == 'لە دلیڤەری' && c.status != 'on_the_way') return false;
      if (_selectedStatus == 'ناچالاک' && c.status != 'offline') return false;
      return true;
    }).toList();
  }

  void _showAddCourierDialog({CourierItem? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? 'هەولێر');
    String status = existing?.status ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF113E2E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF113E2E), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isEdit ? 'دەستکاریکردنی ماتۆرسوار' : 'زیادکردنی ماتۆرسواری نوێ',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'ناوی تەواوی ماتۆرسوار *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'ژمارەی مۆبایل *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: cityCtrl.text,
                    decoration: InputDecoration(
                      labelText: 'شار',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'هەولێر', child: Text('هەولێر')),
                      DropdownMenuItem(value: 'سلێمانی', child: Text('سلێمانی')),
                      DropdownMenuItem(value: 'دهۆک', child: Text('دهۆک')),
                      DropdownMenuItem(value: 'کەلار', child: Text('کەلار')),
                    ],
                    onChanged: (v) => setDialogState(() => cityCtrl.text = v ?? 'هەولێر'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: 'دۆخی ماتۆرسوار',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('چالاک')),
                      DropdownMenuItem(value: 'on_the_way', child: Text('لە دلیڤەری')),
                      DropdownMenuItem(value: 'offline', child: Text('ناچالاک')),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? 'active'),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF113E2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  if (isEdit) {
                    final idx = _couriers.indexWhere((c) => c.id == existing.id);
                    if (idx != -1) {
                      _couriers[idx] = existing.copyWith(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        city: cityCtrl.text,
                        status: status,
                      );
                    }
                  } else {
                    _couriers.insert(
                      0,
                      CourierItem(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        city: cityCtrl.text,
                        status: status,
                        todayOrders: 1,
                        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                        motorType: 'Honda CBR 150R',
                        plateNumber: 'KLR-999',
                        location: const LatLng(36.1911, 44.0091),
                      ),
                    );
                  }
                });
                _showSnack(isEdit ? 'ماتۆرسوار نوێکرایەوە' : 'ماتۆرسواری نوێ زیادکرا');
              },
              child: Text(isEdit ? 'پاشەکەوتکردن' : 'زیادکردن'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourierDetailsDialog(CourierItem courier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(courier.avatarUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(courier.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(courier.phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            _buildStatusBadge(courier.status),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('شار', courier.city),
              const Divider(height: 18),
              _buildDetailRow('داواکارییەکانی ئەمڕۆ', '${courier.todayOrders} داواکاری'),
              const Divider(height: 18),
              _buildDetailRow('جۆری ماتۆڕسکیل', courier.motorType),
              const Divider(height: 18),
              _buildDetailRow('تابلۆی هاتووچۆ', courier.plateNumber),
              const Divider(height: 18),
              _buildDetailRow('پارەی کاش (COD)', '${courier.cashCollected} د.ع'),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddCourierDialog(existing: courier);
            },
            child: const Text('دەستکاریکردن'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF113E2E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
      ],
    );
  }

  // ============================================================================
  // BUILD SCREEN
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Area (Title, Subtitle, Search, Bell, Profile)
              _buildTopHeader(),
              const SizedBox(height: 16),

              // 2. Action Button: + زیادکردنی ماتۆرسوار
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF113E2E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showAddCourierDialog(),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      'زیادکردنی ماتۆرسوار',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Row of 4 KPI Metric Cards (Right to Left)
              _buildKpiSummaryRow(),
              const SizedBox(height: 20),

              // 4. Main Two-Column Content: Left Column Table, Right Column Map
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left visually in RTL (Flex 62): Filter Bar & Couriers Table
                        Expanded(
                          flex: 62,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFilterBar(),
                              const SizedBox(height: 14),
                              _buildCouriersTableCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Right visually in RTL (Flex 38): Couriers Map Card
                        Expanded(
                          flex: 38,
                          child: _buildCouriersMapCard(),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildCouriersMapCard(),
                        const SizedBox(height: 20),
                        _buildFilterBar(),
                        const SizedBox(height: 14),
                        _buildCouriersTableCard(),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. Top Header Widget
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Text(
              'بەڕێوەبردنی ماتۆرسواران',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'چاوەدێری و بەڕێوەبردنی تیمی دلیڤەری',
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
            // User Avatar + Aryan Mohammed
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFE2E8F0),
                  backgroundImage: NetworkImage(
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'ئاریان محەمەد',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'بەڕێوەبەر',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
              ],
            ),
            const SizedBox(width: 14),

            // Notification Bell with Badge '3'
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569), size: 24),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEA580C),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        final searchBar = Container(
          width: isNarrow ? constraints.maxWidth : 260.0,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '...گەڕان بە ناوی ماتۆرسوار',
                    hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );

        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  profileAndBell,
                ],
              ),
              const SizedBox(height: 10),
              titleWidget,
              const SizedBox(height: 12),
              searchBar,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  profileAndBell,
                  Expanded(child: titleWidget),
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
                  const SizedBox(width: 16),
                  searchBar,
                ],
              ),
              titleWidget,
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. Top 4 Metric KPI Summary Cards (Matching Screenshot)
  // ============================================================================
  Widget _buildKpiSummaryRow() {
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
            // Card 1: کۆی ماتۆرسواران (Rightmost)
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'کۆی ماتۆرسواران',
                value: _totalDriversKPI,
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
              ),
            ),
            // Card 2: چالاک
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'چالاک',
                value: _activeDriversKPI,
                icon: Icons.circle,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 3: لە دلیڤەری
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'لە دلیڤەری',
                value: _inDeliveryKPI,
                icon: Icons.two_wheeler_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            // Card 4: چاوەڕوانی پەسەندکردن (Leftmost)
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'چاوەڕوانی پەسەندکردن',
                value: _pendingApprovalKPI,
                icon: Icons.access_time_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
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
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: icon == Icons.circle ? 16 : 22),
          ),
          // Value and Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
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
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Filter Bar (Calendar, City, Status)
  // ============================================================================
  Widget _buildFilterBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Date Dropdown: 'ئەمڕۆ'
        _buildDropdownPill(
          icon: Icons.calendar_today_outlined,
          value: _selectedDate,
          items: const ['ئەمڕۆ', 'دوێنێ', '٧ ڕۆژی ڕابردوو', 'ئەم مانگە'],
          onChanged: (v) => setState(() => _selectedDate = v ?? 'ئەمڕۆ'),
        ),

        // City Dropdown: 'هەموو شارەکان'
        _buildDropdownPill(
          icon: Icons.location_on_outlined,
          value: _selectedCity,
          items: const ['هەموو شارەکان', 'هەولێر', 'سلێمانی', 'دهۆک', 'کەلار'],
          onChanged: (v) => setState(() => _selectedCity = v ?? 'هەموو شارەکان'),
        ),

        // Status Dropdown: 'هەموو دۆخەکان'
        _buildDropdownPill(
          icon: Icons.filter_list_rounded,
          value: _selectedStatus,
          items: const ['هەموو دۆخەکان', 'چالاک', 'لە دلیڤەری', 'ناچالاک'],
          onChanged: (v) => setState(() => _selectedStatus = v ?? 'هەموو دۆخەکان'),
        ),
      ],
    );
  }

  Widget _buildDropdownPill({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================================
  // Right Card: شوێنی ماتۆرسواران (Couriers Live Map Card)
  // ============================================================================
  Widget _buildCouriersMapCard() {
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
          // Header: Location Pin + شوێنی ماتۆرسواران, Expand Icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF0F172A)),
                    SizedBox(width: 6),
                    Text(
                      'شوێنی ماتۆرسواران',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    _mapController.move(const LatLng(36.1911, 44.0091), 13.5);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.crop_free_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          // Interactive Map Canvas
          SizedBox(
            height: 380,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(36.1911, 44.0091),
                initialZoom: 13.5,
                minZoom: 10.0,
                maxZoom: 18.0,
                backgroundColor: Color(0xFFF1F5F9),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'iq.rega.admin',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    // Center label: هەولێر
                    Marker(
                      point: const LatLng(36.1911, 44.0091),
                      width: 70,
                      height: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            'هەولێر',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    ),

                    // Driver Motorbike Markers
                    ..._couriers.take(8).map((c) {
                      final isDelivery = c.status == 'on_the_way';
                      return Marker(
                        point: c.location,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDelivery ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.two_wheeler_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // Map Legend at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _LegendItem(color: Color(0xFF16A34A), text: 'چالاک (١٢٨)'),
                _LegendItem(color: Color(0xFFEA580C), text: 'لە دلیڤەری (٣٤)'),
                _LegendItem(color: Color(0xFF94A3B8), text: 'ناچالاک (٨٦)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Left Card: Couriers Table Card
  // ============================================================================
  Widget _buildCouriersTableCard() {
    final list = _filteredCouriers;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 680 ? 680.0 : constraints.maxWidth;
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Headers
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: const [
                            Expanded(flex: 3, child: Text('ماتۆرسوار', textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 3, child: Text('ژمارەی مۆبایل', textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('شار', textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('داواکارییەکانی ئەمڕۆ', textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('دۆخ', textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('کردار', textAlign: TextAlign.left, style: _headerStyle)),
                          ],
                        ),
                      ),

          // Table Rows
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('هیچ ماتۆرسوارێک بەردەست نییە', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final c = list[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // 1. Driver Name + Avatar
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(c.avatarUrl),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Phone
                      Expanded(
                        flex: 3,
                        child: Text(
                          c.phone,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),

                      // 3. City
                      Expanded(
                        flex: 2,
                        child: Text(
                          c.city,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),

                      // 4. Today Orders
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${c.todayOrders}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),

                      // 5. Status
                      Expanded(
                        flex: 2,
                        child: Center(child: _buildStatusBadge(c.status)),
                      ),

                      // 6. Action Buttons [✏️] [👁]
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // View details button
                            InkWell(
                              onTap: () => _showCourierDetailsDialog(c),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF475569)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Edit button
                            InkWell(
                              onTap: () => _showAddCourierDialog(existing: c),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
                    ],
                  ),
                ),
              ),

              // Pagination Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    // Right side: '5 لە 248 دانە نمایش دەکرێت'
                    const Text(
                      '5 لە 248 دانە نمایش دەکرێت',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    // Left side: < 3 2 [1] >
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPageNavBtn(icon: Icons.chevron_left_rounded, onTap: () {}),
                        const SizedBox(width: 4),
                        _buildPageNumberBtn(page: 1, active: _currentPage == 1),
                        const SizedBox(width: 4),
                        _buildPageNumberBtn(page: 2, active: _currentPage == 2),
                        const SizedBox(width: 4),
                        _buildPageNumberBtn(page: 3, active: _currentPage == 3),
                        const SizedBox(width: 4),
                        _buildPageNavBtn(icon: Icons.chevron_right_rounded, onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label;
    Color bg;
    Color text;

    switch (status) {
      case 'on_the_way':
        label = 'لە دلیڤەری';
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFEA580C);
        break;
      case 'offline':
        label = 'ناچالاک';
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        break;
      case 'active':
      default:
        label = 'چالاک';
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildPageNumberBtn({required int page, required bool active}) {
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF113E2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Color(0xFF64748B),
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
