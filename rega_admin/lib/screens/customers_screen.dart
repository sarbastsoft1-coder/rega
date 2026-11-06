import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

/// Representation of a customer item matching the exact design in the screenshot
class CustomerItem {
  final int id;
  final String name;
  final String tier;
  final String phone;
  final String city;
  final int totalOrders;
  final bool isActive;

  CustomerItem({
    required this.id,
    required this.name,
    this.tier = 'کڕیاری ستاندارد',
    required this.phone,
    required this.city,
    required this.totalOrders,
    required this.isActive,
  });

  CustomerItem copyWith({
    int? id,
    String? name,
    String? tier,
    String? phone,
    String? city,
    int? totalOrders,
    bool? isActive,
  }) {
    return CustomerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      totalOrders: totalOrders ?? this.totalOrders,
      isActive: isActive ?? this.isActive,
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
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _topSearchCtrl = TextEditingController();

  String _selectedCity = 'هەموو شارەکان';
  String _selectedStatus = 'هەموو دۆخەکان';
  int _currentPage = 1;

  // KPI Metrics (matching exact screenshot values)
  final String _totalCustomers = '٢٤,٨٥٠';
  final String _activeCustomers = '٨,٤٢٠';
  final String _newThisMonth = '١,٢٨٠';
  final String _returnRate = '٦٨٪';

  // Demo Customers matching the screenshot table exactly
  final List<CustomerItem> _demoCustomers = [
    CustomerItem(
      id: 1,
      name: 'ئارام محەمەد',
      tier: 'کڕیاری ستاندارد',
      phone: '٠٧٥٠ ١٢٣ ٤٥٦٧',
      city: 'هەولێر',
      totalOrders: 28,
      isActive: true,
    ),
    CustomerItem(
      id: 2,
      name: 'سارا عەلی',
      tier: 'کڕیاری ستاندارد',
      phone: '٠٧٧٠ ٢٣٤ ٥٦٧٨',
      city: 'سلێمانی',
      totalOrders: 12,
      isActive: true,
    ),
    CustomerItem(
      id: 3,
      name: 'هیوا کەریم',
      tier: 'کڕیاری ستاندارد',
      phone: '٠٧٥٠ ٩٨٧ ٦٥٤٣',
      city: 'دهۆک',
      totalOrders: 45,
      isActive: true,
    ),
    CustomerItem(
      id: 4,
      name: 'لەيلا ئیبراهیم',
      tier: 'کڕیاری ستاندارد',
      phone: '٠٧٥٠ ١١٢ ٢٢٣٣',
      city: 'هەولێر',
      totalOrders: 3,
      isActive: false,
    ),
    CustomerItem(
      id: 5,
      name: 'بەهرۆز قادر',
      tier: 'کڕیاری ستاندارد',
      phone: '٠٧٧٠ ٤٤٣ ٣٣٢٢',
      city: 'سلێمانی',
      totalOrders: 19,
      isActive: true,
    ),
  ];

  late List<CustomerItem> _customers;

  @override
  void initState() {
    super.initState();
    _customers = List.from(_demoCustomers);
    _loadFromBackend();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _topSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend() async {
    try {
      final res = await widget.api.getCustomers();
      if (res.isNotEmpty && mounted) {
        setState(() {
          _customers = res.map((m) {
            final map = m as Map<String, dynamic>;
            final addresses = map['addresses'] as List<dynamic>? ?? [];
            final city = addresses.isNotEmpty
                ? (addresses.first as Map<String, dynamic>)['city']?.toString() ?? 'کەلار'
                : 'کەلار';
            final orderCount = (map['orders_count'] as num?)?.toInt() ?? 10;
            return CustomerItem(
              id: (map['id'] as num?)?.toInt() ?? 0,
              name: map['name']?.toString() ?? 'کڕیار',
              tier: 'کڕیاری ستاندارد',
              phone: map['phone']?.toString() ?? '',
              city: city,
              totalOrders: orderCount,
              isActive: map['is_active'] == true,
            );
          }).toList();
        });
      }
    } catch (_) {
      // Fallback to demo customers seamlessly
    }
  }

  List<CustomerItem> get _filteredCustomers {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _customers.where((c) {
      if (query.isNotEmpty) {
        final matchName = c.name.toLowerCase().contains(query);
        final matchPhone = c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
        if (!matchName && !matchPhone) return false;
      }
      if (_selectedCity != 'هەموو شارەکان' && _selectedCity != 'هەموو دوارەکان') {
        if (c.city != _selectedCity) return false;
      }
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
                color: const Color(0xFFFF5722),
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
                    activeColor: const Color(0xFF16A34A),
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
                backgroundColor: const Color(0xFFFF5722),
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
                        tier: 'کڕیاری ستاندارد',
                        phone: phoneCtrl.text.trim(),
                        city: city,
                        totalOrders: 1,
                        isActive: isActive,
                      ),
                    );
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'کڕیار بە سەرکەوتوویی نوێکرایەوە' : 'کڕیاری نوێ زیادکرا'),
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                );
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
                  Text(c.tier, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
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
              _buildDetailRow(
                '🟢 دۆخ:',
                c.isActive ? 'چالاک (Active)' : 'ناچالاک (Inactive)',
                valueColor: c.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: valueColor ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(CustomerItem c) {
    setState(() => _customers.removeWhere((item) => item.id == c.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('کڕیار "${c.name}" سڕایەوە'),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  void _toggleStatus(CustomerItem c) {
    setState(() {
      final idx = _customers.indexWhere((item) => item.id == c.id);
      if (idx != -1) {
        _customers[idx] = c.copyWith(isActive: !c.isActive);
      }
    });
  }

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
              const SizedBox(height: 22),

              // 3. Actions & Filter Bar
              _buildFilterActionsBar(),
              const SizedBox(height: 14),

              // 4. Main Customers Table Card
              _buildCustomersTableCard(filtered),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot Header with Search, Bell, Profile)
  // ============================================================================
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side in RTL (User profile, Bell with red dot, Search pill)
        Row(
          children: [
            // User Avatar with Chevron
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF6B7280), size: 22),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280), size: 18),
              ],
            ),
            const SizedBox(width: 16),

            // Notification Bell with Red Dot Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF4B5563), size: 24),
                Positioned(
                  top: 0,
                  right: 0,
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

            // Top Search Input Pill
            Container(
              width: 220,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
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
            ),
          ],
        ),

        // Right side in RTL: Page Title & Subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
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
              'زانیاری و چالاکیی کڕیارەکان',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // 2. 4 TOP KPI METRIC SUMMARY CARDS
  // ============================================================================
  Widget _buildKPICardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 48) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: کۆی کڕیاران (Rightmost)
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'کۆی کڕیاران',
                value: _totalCustomers,
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 2: کڕیاری چالاک
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'کڕیاری چالاک',
                value: _activeCustomers,
                icon: Icons.person_rounded,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 3: نوێی ئەم مانگە
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'نوێی ئەم مانگە',
                value: _newThisMonth,
                icon: Icons.add_rounded,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
              ),
            ),
            // Card 4: ڕێژەی گەڕانەوە (Leftmost)
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'ڕێژەی گەڕانەوە',
                value: _returnRate,
                icon: Icons.sync_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
          // Top Row: Title + Circular Icon Badge
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
          const SizedBox(height: 6),
          // Value text
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
    );
  }

  // ============================================================================
  // 3. ACTIONS AND FILTER BAR (Above Table)
  // ============================================================================
  Widget _buildFilterActionsBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side in RTL: + زیادکردنی کڕیار Button & Dropdowns
        Row(
          children: [
            // + زیادکردنی کڕیار Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () => _showAddCustomerDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'زیادکردنی کڕیار +',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),

            // Filter Dropdown 2: هەموو دۆخەکان
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF6B7280)),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
                  items: const [
                    DropdownMenuItem(
                      value: 'هەموو دۆخەکان',
                      child: Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF6B7280)),
                          SizedBox(width: 6),
                          Text('هەموو دۆخەکان'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(value: 'چالاک', child: Text('چالاک')),
                    DropdownMenuItem(value: 'ناچالاک', child: Text('ناچالاک')),
                  ],
                  onChanged: (v) => setState(() => _selectedStatus = v ?? 'هەموو دۆخەکان'),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Filter Dropdown 1: هەموو شارەکان
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF6B7280)),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
                  items: const [
                    DropdownMenuItem(
                      value: 'هەموو شارەکان',
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6B7280)),
                          SizedBox(width: 6),
                          Text('هەموو شارەکان'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(value: 'هەولێر', child: Text('هەولێر')),
                    DropdownMenuItem(value: 'سلێمانی', child: Text('سلێمانی')),
                    DropdownMenuItem(value: 'دهۆک', child: Text('دهۆک')),
                    DropdownMenuItem(value: 'کەلار', child: Text('کەلار')),
                  ],
                  onChanged: (v) => setState(() => _selectedCity = v ?? 'هەموو شارەکان'),
                ),
              ),
            ),
          ],
        ),

        // Right side in RTL: Search input pill
        Container(
          width: 240,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '...گەڕان',
                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 4. MAIN CUSTOMERS TABLE CARD
  // ============================================================================
  Widget _buildCustomersTableCard(List<CustomerItem> customers) {
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
          // Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('کڕیار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('ژمارەی مۆبایل', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('شار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('کۆی داواکاری', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('دۆخ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Center(child: Text('کردار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280))))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Table Rows
          if (customers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('هیچ کڕیارێک نەدۆزرایەوە', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
              ),
            )
          else
            ...customers.map((c) => _buildCustomerRow(c)),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Table Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Right side in RTL: Showing count
                Text(
                  'نمایشکردنی ${customers.length} لە $_totalCustomers کڕیار',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
                // Left side in RTL: Pagination Buttons
                Row(
                  children: [
                    _buildPageChevron(Icons.chevron_right_rounded, () {}),
                    const SizedBox(width: 6),
                    _buildPageSquare('1', true),
                    const SizedBox(width: 4),
                    _buildPageSquare('2', false),
                    const SizedBox(width: 4),
                    _buildPageSquare('3', false),
                    const SizedBox(width: 6),
                    _buildPageChevron(Icons.chevron_left_rounded, () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(CustomerItem c) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          // 1. کڕیار: Avatar + Name + Subtitle
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF6B7280), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.tier,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. ژمارەی مۆبایل
          Expanded(
            flex: 2,
            child: Text(
              c.phone,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // 3. شار
          Expanded(
            flex: 2,
            child: Text(
              c.city,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // 4. کۆی داواکاری
          Expanded(
            flex: 2,
            child: Text(
              '${c.totalOrders}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),

          // 5. دۆخ (Status Pill)
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: c.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c.isActive ? 'چالاک' : 'ناچالاک',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: c.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),

          // 6. کردار (Actions: بینین + 3 Dots Menu)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _showCustomerDetailsDialog(c),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'بینین',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF9CA3AF)),
                  onSelected: (act) {
                    if (act == 'edit') {
                      _showAddCustomerDialog(existing: c);
                    } else if (act == 'toggle') {
                      _toggleStatus(c);
                    } else if (act == 'delete') {
                      _deleteCustomer(c);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 16, color: Color(0xFF475569)),
                          SizedBox(width: 8),
                          Text('دەستکاریکردن', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            c.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: c.isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.isActive ? 'ناچالاککردن' : 'چالاککردن',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('سڕینەوە', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSquare(String page, bool active) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFF5722) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          page,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildPageChevron(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
      ),
    );
  }
}
