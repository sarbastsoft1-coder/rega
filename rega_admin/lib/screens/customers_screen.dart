import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../widgets/admin_top_header.dart';

/// Representation of a customer item matching the exact design in the screenshot
class CustomerItem {
  final int id;
  final String name;
  final String phone;
  final String city;
  final int totalOrders;
  final String registerDate;
  final bool isActive;
  final bool isFemale;

  CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.totalOrders,
    required this.registerDate,
    required this.isActive,
    this.isFemale = false,
  });

  CustomerItem copyWith({
    int? id,
    String? name,
    String? phone,
    String? city,
    int? totalOrders,
    String? registerDate,
    bool? isActive,
    bool? isFemale,
  }) {
    return CustomerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      totalOrders: totalOrders ?? this.totalOrders,
      registerDate: registerDate ?? this.registerDate,
      isActive: isActive ?? this.isActive,
      isFemale: isFemale ?? this.isFemale,
    );
  }
}

class CustomersScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const CustomersScreen({
    super.key,
    required this.api,
    required this.lang,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _topSearchCtrl = TextEditingController();
  Timer? _refreshTimer;

  String _selectedCity = 'هەموو شارەکان';
  String _selectedStatus = 'دۆخی کڕیار';
  String _selectedPeriod = 'ئەم مانگە';
  int _currentPage = 1;

  // Live KPI Metrics from PostgreSQL database
  String _totalCustomers = '٠';
  String _activeCustomers = '٠';
  String _newThisMonth = '٠';
  String _todayOrders = '٠';

  static String _toDigits(dynamic input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ku = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String s = input.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], ku[i]);
    }
    return s;
  }

  List<CustomerItem> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadFromBackend(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _topSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend({bool silent = false}) async {
    if (!silent && _customers.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await widget.api.getCustomers();
      if (!mounted) return;

      final mapped = res.map((m) {
        final map = m as Map<String, dynamic>;
        final addresses = map['addresses'] as List<dynamic>? ?? [];
        final city = addresses.isNotEmpty
            ? (addresses.first as Map<String, dynamic>)['city']?.toString() ?? 'کەلار'
            : 'کەلار';
        final orderCount = (map['orders_count'] as num?)?.toInt() ?? 0;
        final createdAt = map['created_at']?.toString() ?? '2026-11-09';
        return CustomerItem(
          id: map['id'] as int? ?? 1,
          name: map['name']?.toString() ?? 'کڕیار',
          phone: map['phone']?.toString() ?? '0750 000 ****',
          city: city,
          totalOrders: orderCount,
          registerDate: createdAt.split('T').first,
          isActive: map['is_active'] != false,
        );
      }).toList();

      final totalCount = mapped.length;
      final activeCount = mapped.where((c) => c.isActive).length;
      final totalOrders = mapped.fold<int>(0, (sum, c) => sum + c.totalOrders);

      setState(() {
        _customers = mapped;
        _totalCustomers = _toDigits(totalCount);
        _activeCustomers = _toDigits(activeCount);
        _newThisMonth = _toDigits(totalCount);
        _todayOrders = _toDigits(totalOrders);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      ),
    );
  }

  List<CustomerItem> get _filteredCustomers {
    final query = _topSearchCtrl.text.trim().toLowerCase();
    return _customers.where((c) {
      if (query.isNotEmpty) {
        final matchName = c.name.toLowerCase().contains(query);
        final matchPhone = c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
        final matchCity = c.city.toLowerCase().contains(query);
        if (!matchName && !matchPhone && !matchCity) return false;
      }
      if (_selectedCity != 'هەموو شارەکان' && c.city != _selectedCity) return false;
      if (_selectedStatus == 'چالاک' && !c.isActive) return false;
      if (_selectedStatus == 'ناچالاک' && c.isActive) return false;
      return true;
    }).toList();
  }

  void _showAddCustomerDialog({CustomerItem? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String city = existing?.city ?? 'هەولێر';
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                color: const Color(0xFF113E2E),
              ),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'دەستکاریکردنی کڕیار' : 'زیادکردنی کڕیاری نوێ',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                      labelText: 'ناوی کڕیار *',
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
                    initialValue: city,
                    items: const [
                      DropdownMenuItem(value: 'هەولێر', child: Text('هەولێر')),
                      DropdownMenuItem(value: 'سلێمانی', child: Text('سلێمانی')),
                      DropdownMenuItem(value: 'دهۆک', child: Text('دهۆک')),
                      DropdownMenuItem(value: 'کەلار', child: Text('کەلار')),
                    ],
                    onChanged: (v) => setDialogState(() => city = v ?? 'هەولێر'),
                    decoration: InputDecoration(
                      labelText: 'شار',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: isActive,
                    activeTrackColor: const Color(0xFF86EFAC),
                    activeThumbColor: const Color(0xFF16A34A),
                    onChanged: (v) => setDialogState(() => isActive = v),
                    title: const Text('دۆخی کڕیار (چالاک)', style: TextStyle(fontWeight: FontWeight.w700)),
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
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  if (isEdit) {
                    final idx = _customers.indexWhere((c) => c.id == existing.id);
                    if (idx != -1) {
                      _customers[idx] = existing.copyWith(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        city: city,
                        isActive: isActive,
                      );
                    }
                  } else {
                    _customers.insert(
                      0,
                      CustomerItem(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        city: city,
                        totalOrders: 1,
                        registerDate: '2024-06-15',
                        isActive: isActive,
                      ),
                    );
                  }
                });
                _showSnack(isEdit ? 'کڕیار نوێکرایەوە' : 'کڕیاری نوێ زیادکرا');
              },
              child: Text(isEdit ? 'پاشەکەوتکردن' : 'زیادکردن'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetailsDialog(CustomerItem c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE5E7EB),
              child: Icon(Icons.person_rounded, color: Color(0xFF6B7280)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(c.city, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            _buildStatusBadge(c.isActive),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('📱 مۆبایل:', c.phone),
              _buildDetailRow('🏙️ شار:', c.city),
              _buildDetailRow('🛍️ کۆی داواکارییەکان:', '${c.totalOrders} داواکاری'),
              _buildDetailRow('📅 بەرواری تۆمارکردن:', c.registerDate),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddCustomerDialog(existing: c);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BUILD SCREEN
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCustomers;

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

              // 3. Middle Section: Chart on Left, Filter Bar on Right
              _buildMiddleSection(),
              const SizedBox(height: 16),

              // 4. Main Customers Table Card (Matching Screenshot)
              _buildCustomersTableCard(filtered),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot: Title & Button on Right, Profile on Left)
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;

        final titleAndButton = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'بەڕێوەبردنی کڕیاران',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'زانیاری و چالاکیی کڕیارەکانی خزمەتگوزاری دلیڤەری',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF113E2E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showAddCustomerDialog(),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'زیادکردنی کڕیار',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _topSearchCtrl,
          hintText: '...گەڕان بە ناوی کڕیار',
          onSearchChanged: (_) => setState(() {}),
        );

        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topActions,
              const SizedBox(height: 12),
              titleAndButton,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleAndButton),
                ],
              ),
              const SizedBox(height: 12),
              topActions,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              titleAndButton,
              topActions,
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. 4 TOP KPI METRIC SUMMARY CARDS (Matching Screenshot Right to Left)
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
            // Card 1: کۆی کڕیاران (Rightmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'کۆی کڕیاران',
                value: _totalCustomers,
                icon: Icons.person_rounded,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
              ),
            ),
            // Card 2: کڕیاری چالاک
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'کڕیاری چالاک',
                value: _activeCustomers,
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            // Card 3: نوێی ئەم مانگە
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'نوێی ئەم مانگە',
                value: _newThisMonth,
                icon: Icons.person_add_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 4: داواکاریی ئەمڕۆ (Leftmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: 'داواکاریی ئەمڕۆ',
                value: _todayOrders,
                icon: Icons.shopping_cart_outlined,
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
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          // Value & Title
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
  // 3. MIDDLE SECTION: Filters on Right, Chart on Left (in RTL)
  // ============================================================================
  Widget _buildMiddleSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Right side in RTL (child 0): Filter Dropdowns near sidebar
              Expanded(
                flex: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildFilterBar(),
                ),
              ),
              const SizedBox(width: 20),
              // Left side in RTL (child 1): Curved Area Chart Card
              Expanded(
                flex: 52,
                child: _buildNewCustomersChartCard(),
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterBar(),
              const SizedBox(height: 14),
              _buildNewCustomersChartCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        // Period: ئەم مانگە
        _buildDropdownPill(
          icon: Icons.calendar_today_outlined,
          value: _selectedPeriod,
          items: const ['ئەم مانگە', 'مانگی ڕابردوو', 'ئەمساڵ'],
          onChanged: (v) => setState(() => _selectedPeriod = v ?? 'ئەم مانگە'),
        ),

        // Status: دۆخی کڕیار
        _buildDropdownPill(
          icon: Icons.person_outline_rounded,
          value: _selectedStatus,
          items: const ['دۆخی کڕیار', 'چالاک', 'ناچالاک'],
          onChanged: (v) => setState(() => _selectedStatus = v ?? 'دۆخی کڕیار'),
        ),

        // City: هەموو شارەکان
        _buildDropdownPill(
          icon: Icons.location_on_outlined,
          value: _selectedCity,
          items: const ['هەموو شارەکان', 'هەولێر', 'سلێمانی', 'دهۆک', 'کەلار'],
          onChanged: (v) => setState(() => _selectedCity = v ?? 'هەموو شارەکان'),
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
  // New Customers Curved Area Line Chart
  // ============================================================================
  Widget _buildNewCustomersChartCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'کڕیارانی نوێ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 110,
              child: Row(
                children: [
                  // Y-axis labels
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('2,000', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                      Text('1,500', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                      Text('1,000', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                      Text('500', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                      Text('0', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Area Chart Canvas
                  Expanded(
                    child: CustomPaint(
                      painter: _CustomersChartPainter(),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // X-axis Month Labels (LTR: کانوونی دووەم to حوزەیران)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('کانوونی دووەم', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  Text('شوبات', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  Text('ئازار', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  Text('نیسان', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  Text('ئایار', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  Text('حوزەیران', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 4. MAIN CUSTOMERS TABLE CARD (Matching Screenshot)
  // ============================================================================
  Widget _buildCustomersTableCard(List<CustomerItem> list) {
    // Show top 5 records for page 1
    final pagedList = list.take(5).toList();

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
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth > 780 ? constraints.maxWidth : 780.0;
              return SingleChildScrollView(
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
                            Expanded(flex: 3, child: Text('کڕیار', textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 3, child: Text('ژمارەی مۆبایل', textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('شار', textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('کۆی داواکاری', textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 3, child: Text('بەرواری تۆمارکردن', textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('دۆخ', textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text('کردار', textAlign: TextAlign.left, style: _headerStyle)),
                          ],
                        ),
                      ),

                      // Table Rows
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFFCBD5E1)),
                                SizedBox(height: 10),
                                Text(
                                  'هیچ کڕیارێک لە سیستەمدا نییە',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pagedList.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final c = pagedList[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                // 1. Customer Name + Avatar
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          c.isFemale ? Icons.face_3_rounded : Icons.person_rounded,
                                          size: 16,
                                          color: const Color(0xFF94A3B8),
                                        ),
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

                                // 4. Total Orders
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${c.totalOrders}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),

                                // 5. Register Date
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    c.registerDate,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),

                                // 6. Status
                                Expanded(
                                  flex: 2,
                                  child: Center(child: _buildStatusBadge(c.isActive)),
                                ),

                                // 7. Actions [✏️] [👁]
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // View Details Eye Button
                                      InkWell(
                                        onTap: () => _showCustomerDetailsDialog(c),
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
                                      // Edit Button
                                      InkWell(
                                        onTap: () => _showAddCustomerDialog(existing: c),
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
              );
            },
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
                Text(
                  'نمایش ${_toDigits(pagedList.length)} لە ${_toDigits(list.length)} کڕیار',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),

                // Left side: < 5 4 3 2 [1] >
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
                    _buildPageNumberBtn(page: 4, active: _currentPage == 4),
                    const SizedBox(width: 4),
                    _buildPageNumberBtn(page: 5, active: _currentPage == 5),
                    const SizedBox(width: 4),
                    _buildPageNavBtn(icon: Icons.chevron_right_rounded, onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isActive ? 'چالاک' : 'ناچالاک',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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

/// Custom painter for the New Customers curved area line chart
class _CustomersChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Grid horizontal lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Normalized points for months (Jan to June):
    // 350, 700, 1000, 1000, 1400, 1750 (out of 2000 max)
    final values = [0.18, 0.35, 0.50, 0.50, 0.70, 0.88];
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height * (1.0 - values[i]);
      points.add(Offset(x, y));
    }

    // Path for line and filled area
    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final areaPath = Path.from(linePath);
    areaPath.lineTo(size.width, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    // Area Gradient Fill (Teal/Emerald)
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF0D9488).withValues(alpha: 0.35),
        const Color(0xFF0D9488).withValues(alpha: 0.02),
      ],
    );

    final areaPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);

    // Line Stroke
    final linePaint = Paint()
      ..color = const Color(0xFF0D9488)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // Draw dots at points
    final dotPaint = Paint()..color = const Color(0xFF0D9488);
    final dotWhite = Paint()..color = Colors.white;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 2.0, dotWhite);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
