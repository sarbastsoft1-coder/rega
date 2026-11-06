import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

/// Representation of a vendor item matching the exact design in the screenshot
class VendorItem {
  final int id;
  final String name;
  final String cuisine;
  final String city;
  final int todayOrders;
  final String status; // 'active' (چالاک) | 'under_review' (پێداچوونەوە)
  final String imageUrl;

  VendorItem({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.city,
    required this.todayOrders,
    required this.status,
    required this.imageUrl,
  });

  VendorItem copyWith({
    int? id,
    String? name,
    String? cuisine,
    String? city,
    int? todayOrders,
    String? status,
    String? imageUrl,
  }) {
    return VendorItem(
      id: id ?? this.id,
      name: name ?? this.name,
      cuisine: cuisine ?? this.cuisine,
      city: city ?? this.city,
      todayOrders: todayOrders ?? this.todayOrders,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class StoresScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const StoresScreen({
    super.key,
    required this.api,
    required this.lang,
  });

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final TextEditingController _topSearchCtrl = TextEditingController();

  // Top KPI metrics matching exact screenshot values
  final String _registeredVendors = '٣٤٢';
  final String _activeVendors = '٢٨٦';
  final String _pendingApproval = '١٢';
  final String _todayOrders = '١,٧٦٠';

  // Demo Vendors matching the screenshot table exactly
  final List<VendorItem> _demoVendors = [
    VendorItem(
      id: 1,
      name: 'چێشتخانەی ئارام',
      cuisine: 'خواردنی کوردی',
      city: 'هەولێر',
      todayOrders: 240,
      status: 'active',
      imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=120&q=80',
    ),
    VendorItem(
      id: 2,
      name: 'کافێی ڕۆژ',
      cuisine: 'کافێ',
      city: 'سلێمانی',
      todayOrders: 187,
      status: 'active',
      imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=120&q=80',
    ),
    VendorItem(
      id: 3,
      name: 'پیتزای شار',
      cuisine: 'پیتزا',
      city: 'هەولێر',
      todayOrders: 320,
      status: 'active',
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=120&q=80',
    ),
    VendorItem(
      id: 4,
      name: 'چێشتخانەی دەڤەر',
      cuisine: 'خواردنی کوردی',
      city: 'سلێمانی',
      todayOrders: 98,
      status: 'under_review',
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=120&q=80',
    ),
    VendorItem(
      id: 5,
      name: 'سەندوچی بەختیار',
      cuisine: 'سەندویچ',
      city: 'هەولێر',
      todayOrders: 155,
      status: 'active',
      imageUrl: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=120&q=80',
    ),
  ];

  late List<VendorItem> _vendors;

  @override
  void initState() {
    super.initState();
    _vendors = List.from(_demoVendors);
    _loadFromBackend();
  }

  @override
  void dispose() {
    _topSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend() async {
    try {
      final res = await widget.api.getStores();
      if (res.isNotEmpty && mounted) {
        setState(() {
          _vendors = res.map((m) {
            final map = m as Map<String, dynamic>;
            final name = map['name_ku']?.toString() ?? map['name_en']?.toString() ?? 'فرۆشگا';
            final cat = map['category'] as Map<String, dynamic>?;
            final cuisine = cat?['name_ku']?.toString() ?? 'خواردنی خێرا';
            final zone = map['neighborhood'] as Map<String, dynamic>?;
            final city = zone?['city']?.toString() ?? 'کەلار';
            final isApproved = map['is_approved'] == true;
            return VendorItem(
              id: (map['id'] as num?)?.toInt() ?? 0,
              name: name,
              cuisine: cuisine,
              city: city,
              todayOrders: (map['active_orders_count'] as num?)?.toInt() ?? 45,
              status: isApproved ? 'active' : 'under_review',
              imageUrl: map['cover_url']?.toString() ?? '',
            );
          }).toList();
        });
      }
    } catch (_) {
      // Fallback gracefully to demo vendors
    }
  }

  List<VendorItem> get _filteredVendors {
    final query = _topSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _vendors;
    return _vendors.where((v) {
      return v.name.toLowerCase().contains(query) ||
          v.cuisine.toLowerCase().contains(query) ||
          v.city.toLowerCase().contains(query);
    }).toList();
  }

  void _showAddVendorDialog({VendorItem? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String cuisine = existing?.cuisine ?? 'خواردنی کوردی';
    String city = existing?.city ?? 'هەولێر';
    String status = existing?.status ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_rounded : Icons.add_business_rounded,
                color: const Color(0xFFFF5722),
              ),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'دەستکاریکردنی فرۆشیار' : 'زیادکردنی فرۆشیاری نوێ',
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
                      labelText: 'ناوی فرۆشیار (چێشتخانە/کافێ) *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: cuisine,
                    items: const [
                      DropdownMenuItem(value: 'خواردنی کوردی', child: Text('خواردنی کوردی')),
                      DropdownMenuItem(value: 'کافێ', child: Text('کافێ')),
                      DropdownMenuItem(value: 'پیتزا', child: Text('پیتزا')),
                      DropdownMenuItem(value: 'سەندویچ', child: Text('سەندویچ')),
                      DropdownMenuItem(value: 'شیرینی', child: Text('شیرینی')),
                    ],
                    onChanged: (v) => setDialogState(() => cuisine = v ?? 'خواردنی کوردی'),
                    decoration: InputDecoration(
                      labelText: 'جۆری خواردن',
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
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('چالاک (Active)')),
                      DropdownMenuItem(value: 'under_review', child: Text('پێداچوونەوە (Under Review)')),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? 'active'),
                    decoration: InputDecoration(
                      labelText: 'دۆخی فرۆشیار',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
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
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  if (isEdit) {
                    final idx = _vendors.indexWhere((v) => v.id == existing.id);
                    if (idx != -1) {
                      _vendors[idx] = existing.copyWith(
                        name: nameCtrl.text.trim(),
                        cuisine: cuisine,
                        city: city,
                        status: status,
                      );
                    }
                  } else {
                    _vendors.insert(
                      0,
                      VendorItem(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: nameCtrl.text.trim(),
                        cuisine: cuisine,
                        city: city,
                        todayOrders: 10,
                        status: status,
                        imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=120&q=80',
                      ),
                    );
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'فرۆشیار بە سەرکەوتوویی نوێکرایەوە' : 'فرۆشیاری نوێ زیادکرا'),
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

  void _showVendorDetailsDialog(VendorItem v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                v.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF6B7280)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(v.cuisine, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
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
              _buildDetailRow('🏙️ شار:', v.city),
              _buildDetailRow('🍽️ جۆری خواردن:', v.cuisine),
              _buildDetailRow('🛍️ داواکارییەکانی ئەمڕۆ:', '${v.todayOrders} داواکاری'),
              _buildDetailRow(
                '🟢 دۆخ:',
                v.status == 'active' ? 'چالاک (Active)' : 'پێداچوونەوە (Under Review)',
                valueColor: v.status == 'active' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
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

  void _deleteVendor(VendorItem v) {
    setState(() => _vendors.removeWhere((item) => item.id == v.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('فرۆشیار "${v.name}" سڕایەوە'),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  void _toggleStatus(VendorItem v) {
    setState(() {
      final idx = _vendors.indexWhere((item) => item.id == v.id);
      if (idx != -1) {
        final nextStatus = v.status == 'active' ? 'under_review' : 'active';
        _vendors[idx] = v.copyWith(status: nextStatus);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVendors;

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
              const SizedBox(height: 24),

              // 3. Action and Table Title Bar
              _buildActionAndTitleBar(),
              const SizedBox(height: 12),

              // 4. Main Vendors Table Card
              _buildVendorsTableCard(filtered),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot Header with Search, Bell Badge 5, Profile)
  // ============================================================================
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side in RTL (User Profile with Name, Bell Badge 5, Search Input)
        Row(
          children: [
            // User Avatar + Name + Dropdown Chevron
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
                const SizedBox(width: 8),
                const Text(
                  'ئارین محەمەد',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280), size: 18),
              ],
            ),
            const SizedBox(width: 18),

            // Notification Bell with Badge "5"
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
            const SizedBox(width: 18),

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
                      onChanged: (_) => setState(() {}),
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
              'بەڕێوەبردنی فرۆشیاران',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'چالاکی و داواکاریین چێشتخانەکان',
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
            // Card 1: فرۆشیاری تۆمارکراو (Rightmost)
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'فرۆشیاری تۆمارکراو',
                value: _registeredVendors,
                icon: Icons.people_alt_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            // Card 2: چالاک
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'چالاک',
                value: _activeVendors,
                icon: Icons.check_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 3: چاوەڕوانی پەسەندکردن
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'چاوەڕوانی پەسەندکردن',
                value: _pendingApproval,
                icon: Icons.access_time_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
              ),
            ),
            // Card 4: داواکاریی ئەمڕۆ (Leftmost)
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'داواکاریی ئەمڕۆ',
                value: _todayOrders,
                icon: Icons.shopping_cart_rounded,
                iconBg: const Color(0xFFFEE2E2),
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
  // 3. ACTION AND TABLE TITLE BAR
  // ============================================================================
  Widget _buildActionAndTitleBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left in RTL: + زیادکردنی فرۆشیار Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5722),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: () => _showAddVendorDialog(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'زیادکردنی فرۆشیار +',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),

        // Right in RTL: لیستی فرۆشیاران Title
        const Text(
          'لیستی فرۆشیاران',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 4. MAIN VENDORS TABLE CARD
  // ============================================================================
  Widget _buildVendorsTableCard(List<VendorItem> vendors) {
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
                Expanded(flex: 3, child: Text('ناوی فرۆشیار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('جۆری خواردن', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('شار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('داواکاریی ئەمڕۆ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('دۆخ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)))),
                Expanded(flex: 3, child: Center(child: Text('کردار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280))))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Table Rows
          if (vendors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('هیچ فرۆشیارێک نەدۆزرایەوە', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
              ),
            )
          else
            ...vendors.map((v) => _buildVendorRow(v)),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Table Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Right side in RTL: Showing count
                Text(
                  'نمایشی ١ بۆ ${vendors.length} لە $_registeredVendors فرۆشیار',
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

  Widget _buildVendorRow(VendorItem v) {
    final isActive = v.status == 'active';

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          // 1. ناوی فرۆشیار: Thumbnail Photo + Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    v.imageUrl,
                    width: 46,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 46,
                      height: 38,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF94A3B8), size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    v.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. جۆری خواردن
          Expanded(
            flex: 2,
            child: Text(
              v.cuisine,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // 3. شار
          Expanded(
            flex: 2,
            child: Text(
              v.city,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // 4. داواکاریی ئەمڕۆ
          Expanded(
            flex: 2,
            child: Text(
              '${v.todayOrders}',
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
                  color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'چالاک' : 'پێداچوونەوە',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ),
          ),

          // 6. کردار (Actions: دەستکاری + بینین + ...)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // دەستکاری Action Button
                InkWell(
                  onTap: () => _showAddVendorDialog(existing: v),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                        SizedBox(width: 4),
                        Text(
                          'دەستکاری',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // بینین Action Button
                InkWell(
                  onTap: () => _showVendorDetailsDialog(v),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'بینین',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // ... More Options Action Button
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.more_horiz_rounded, size: 16, color: Color(0xFF334155)),
                  ),
                  onSelected: (act) {
                    if (act == 'toggle') {
                      _toggleStatus(v);
                    } else if (act == 'delete') {
                      _deleteVendor(v);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                            size: 16,
                            color: isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? 'گۆڕین بۆ پێداچوونەوە' : 'پەسەندکردن و چالاککردن',
                            style: const TextStyle(fontSize: 12.5),
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
                          Text('سڕینەوەی فرۆشیار', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
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
