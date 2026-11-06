import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

/// Representation of a vendor item matching the exact design in the screenshot
class VendorItem {
  final int id;
  final String name;
  final String subtitle;
  final String cuisine;
  final String city;
  final String phone;
  final int todayOrders;
  final String status; // 'active' (چالاک) | 'under_review' (پێداچوونەوە)
  final String imageUrl;

  VendorItem({
    required this.id,
    required this.name,
    this.subtitle = '',
    required this.cuisine,
    required this.city,
    required this.phone,
    required this.todayOrders,
    required this.status,
    required this.imageUrl,
  });

  VendorItem copyWith({
    int? id,
    String? name,
    String? subtitle,
    String? cuisine,
    String? city,
    String? phone,
    int? todayOrders,
    String? status,
    String? imageUrl,
  }) {
    return VendorItem(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      cuisine: cuisine ?? this.cuisine,
      city: city ?? this.city,
      phone: phone ?? this.phone,
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

  String _selectedCuisine = 'هەموو جۆرەکان';
  String _selectedCity = 'هەموو شارەکان';
  String _selectedStatus = 'هەموو دۆخەکان';
  int _currentPage = 1;

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
      subtitle: 'چێشت و گریل',
      cuisine: 'خواردنی کوردی',
      city: 'هەولێر',
      phone: '0750 123 4567',
      todayOrders: 248,
      status: 'active',
      imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=120&q=80',
    ),
    VendorItem(
      id: 2,
      name: 'کافێی ڕۆژ',
      subtitle: 'کافێ و ساندویچ',
      cuisine: 'کافێی خواردنی خێرا',
      city: 'سلێمانی',
      phone: '0770 234 5678',
      todayOrders: 93,
      status: 'under_review',
      imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=120&q=80',
    ),
    VendorItem(
      id: 3,
      name: 'پیتزای شار',
      subtitle: 'پیتزا و پاستا',
      cuisine: 'پیتزا و خۆراکی خێرا',
      city: 'هەولێر',
      phone: '0750 987 6543',
      todayOrders: 317,
      status: 'active',
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=120&q=80',
    ),
    VendorItem(
      id: 4,
      name: 'خواردنی کوردی',
      subtitle: 'چێشتە کوردییەکان',
      cuisine: 'خواردنی کوردی',
      city: 'سلێمانی',
      phone: '0770 111 2233',
      todayOrders: 126,
      status: 'active',
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=120&q=80',
    ),
    VendorItem(
      id: 5,
      name: 'شیرینی هەولێر',
      subtitle: 'کێک و شیرینی',
      cuisine: 'شیرینی و خۆراکی شیرین',
      city: 'هەولێر',
      phone: '0750 444 7788',
      todayOrders: 76,
      status: 'under_review',
      imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=120&q=80',
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
        final mapped = res.map((m) {
          final map = m as Map<String, dynamic>;
          final name = map['name_ku']?.toString() ?? map['name_en']?.toString() ?? 'فرۆشگا';
          final cat = map['category'] as Map<String, dynamic>?;
          final cuisine = cat?['name_ku']?.toString() ?? 'خواردنی خێرا';
          final zone = map['neighborhood'] as Map<String, dynamic>?;
          final city = zone?['city']?.toString() ?? 'هەولێر';
          final isApproved = map['is_approved'] == true;
          return VendorItem(
            id: (map['id'] as num?)?.toInt() ?? 0,
            name: name,
            subtitle: 'خزمەتگوزاری خواردن',
            cuisine: cuisine,
            city: city,
            phone: map['phone']?.toString() ?? '0750 000 0000',
            todayOrders: (map['active_orders_count'] as num?)?.toInt() ?? 45,
            status: isApproved ? 'active' : 'under_review',
            imageUrl: map['cover_url']?.toString() ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=120&q=80',
          );
        }).toList();

        setState(() {
          _vendors = [..._demoVendors, ...mapped.where((x) => !_demoVendors.any((d) => d.name == x.name))];
        });
      }
    } catch (_) {}
  }

  List<VendorItem> get _filteredVendors {
    final query = _topSearchCtrl.text.trim().toLowerCase();
    return _vendors.where((v) {
      if (query.isNotEmpty) {
        final matchName = v.name.toLowerCase().contains(query);
        final matchCuisine = v.cuisine.toLowerCase().contains(query);
        final matchCity = v.city.toLowerCase().contains(query);
        final matchPhone = v.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
        if (!matchName && !matchCuisine && !matchCity && !matchPhone) return false;
      }
      if (_selectedCuisine != 'هەموو جۆرەکان' && v.cuisine != _selectedCuisine) return false;
      if (_selectedCity != 'هەموو شارەکان' && v.city != _selectedCity) return false;
      if (_selectedStatus == 'چالاک' && v.status != 'active') return false;
      if (_selectedStatus == 'پێداچوونەوە' && v.status != 'under_review') return false;
      return true;
    }).toList();
  }

  void _showAddVendorDialog({VendorItem? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
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
                color: const Color(0xFF113E2E),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitleCtrl,
                    decoration: InputDecoration(
                      labelText: 'پێناسەی کورت (وەک: چێشت و گریل)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'ژمارەی مۆبایل *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cuisine,
                    items: const [
                      DropdownMenuItem(value: 'خواردنی کوردی', child: Text('خواردنی کوردی')),
                      DropdownMenuItem(value: 'کافێی خواردنی خێرا', child: Text('کافێی خواردنی خێرا')),
                      DropdownMenuItem(value: 'پیتزا و خۆراکی خێرا', child: Text('پیتزا و خۆراکی خێرا')),
                      DropdownMenuItem(value: 'شیرینی و خۆراکی شیرین', child: Text('شیرینی و خۆراکی شیرین')),
                    ],
                    onChanged: (v) => setDialogState(() => cuisine = v ?? 'خواردنی کوردی'),
                    decoration: InputDecoration(
                      labelText: 'جۆری خواردن',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                    final idx = _vendors.indexWhere((v) => v.id == existing.id);
                    if (idx != -1) {
                      _vendors[idx] = existing.copyWith(
                        name: nameCtrl.text.trim(),
                        subtitle: subtitleCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
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
                        subtitle: subtitleCtrl.text.trim(),
                        cuisine: cuisine,
                        city: city,
                        phone: phoneCtrl.text.trim(),
                        todayOrders: 10,
                        status: status,
                        imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=120&q=80',
                      ),
                    );
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'فرۆشیار نوێکرایەوە' : 'فرۆشیاری نوێ زیادکرا'),
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
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.storefront_rounded, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(v.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            _buildStatusBadge(v.status),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('🍔 جۆری خواردن:', v.cuisine),
              _buildDetailRow('🏙️ شار:', v.city),
              _buildDetailRow('📱 ژمارەی مۆبایل:', v.phone),
              _buildDetailRow('📦 داواکارییەکانی ئەمڕۆ:', '${v.todayOrders} داواکاری'),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddVendorDialog(existing: v);
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
              const SizedBox(height: 20),

              // 3. Filter Bar (Matching Screenshot with 3 dropdown columns)
              _buildFilterBar(),
              const SizedBox(height: 16),

              // 4. Main Vendors Table Card (Matching Screenshot)
              _buildVendorsTableCard(filtered),
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
        // Right side in RTL (First child): Title, Subtitle, and Add Vendor Button
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  'چاوەدێری و بەڕێوەبردنی فرۆشیار و چێشتخانەکان',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            // Add Vendor Button: + زیادکردنی فرۆشیار
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF113E2E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showAddVendorDialog(),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'زیادکردنی فرۆشیار',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),

        // Left side in RTL (Second child): Search pill, Bell with 3, Profile (ئەدمین)
        Row(
          children: [
            // Search pill: '...گەڕان بە ناوی فرۆشیار'
            Container(
              width: 260,
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
                      controller: _topSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '...گەڕان بە ناوی فرۆشیار',
                        hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

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
            const SizedBox(width: 16),

            // User Avatar with Name "ئەدمین"
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
                const Text(
                  'ئەدمین',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
              ],
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
            // Card 1: کۆی فرۆشیاران (Rightmost)
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'کۆی فرۆشیاران',
                value: _registeredVendors,
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
              ),
            ),
            // Card 2: فرۆشیاری چالاک
            SizedBox(
              width: cardWidth.clamp(210.0, 450.0),
              child: _buildKPICard(
                title: 'فرۆشیاری چالاک',
                value: _activeVendors,
                icon: Icons.person_outline_rounded,
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
                icon: Icons.description_outlined,
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
          // Value & Title (on the right in RTL)
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
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          // Icon Box (on the left in RTL)
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
  // 3. FILTER BAR (Matching Screenshot with 3 dropdown columns)
  // ============================================================================
  Widget _buildFilterBar() {
    return Row(
      children: [
        // 1. Food Type: جۆری خواردن -> هەموو جۆرەکان
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'جۆری خواردن',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              _buildDropdownPill(
                value: _selectedCuisine,
                items: const [
                  'هەموو جۆرەکان',
                  'خواردنی کوردی',
                  'کافێی خواردنی خێرا',
                  'پیتزا و خۆراکی خێرا',
                  'شیرینی و خۆراکی شیرین',
                ],
                onChanged: (v) => setState(() => _selectedCuisine = v ?? 'هەموو جۆرەکان'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // 2. City: شار -> هەموو شارەکان
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'شار',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              _buildDropdownPill(
                value: _selectedCity,
                items: const ['هەموو شارەکان', 'هەولێر', 'سلێمانی', 'دهۆک', 'کەلار'],
                onChanged: (v) => setState(() => _selectedCity = v ?? 'هەموو شارەکان'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // 3. Status: دۆخ -> هەموو دۆخەکان
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'دۆخ',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              _buildDropdownPill(
                value: _selectedStatus,
                items: const ['هەموو دۆخەکان', 'چالاک', 'پێداچوونەوە'],
                onChanged: (v) => setState(() => _selectedStatus = v ?? 'هەموو دۆخەکان'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownPill({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(
            fontSize: 12.5,
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
    );
  }

  static String _toKurdishDigits(dynamic input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String s = input.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(western[i], eastern[i]);
    }
    return s;
  }

  // ============================================================================
  // 4. MAIN VENDORS TABLE CARD (Matching Screenshot)
  // ============================================================================
  Widget _buildVendorsTableCard(List<VendorItem> list) {
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
                Expanded(flex: 3, child: Text('فرۆشیار', textAlign: TextAlign.right, style: _headerStyle)),
                Expanded(flex: 3, child: Text('جۆری خواردن', textAlign: TextAlign.right, style: _headerStyle)),
                Expanded(flex: 2, child: Text('شار', textAlign: TextAlign.right, style: _headerStyle)),
                Expanded(flex: 3, child: Text('ژمارەی مۆبایل', textAlign: TextAlign.right, style: _headerStyle)),
                Expanded(flex: 2, child: Text('داواکاریی ئەمڕۆ', textAlign: TextAlign.center, style: _headerStyle)),
                Expanded(flex: 2, child: Text('دۆخ', textAlign: TextAlign.center, style: _headerStyle)),
                Expanded(flex: 2, child: Text('کردار', textAlign: TextAlign.left, style: _headerStyle)),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedList.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final v = pagedList[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // 1. Vendor Name, Subtitle, and Thumbnail
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              v.imageUrl,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  v.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                if (v.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    v.subtitle,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Food Type
                    Expanded(
                      flex: 3,
                      child: Text(
                        v.cuisine,
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
                        v.city,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),

                    // 4. Phone
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            v.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 5. Today Orders
                    Expanded(
                      flex: 2,
                      child: Text(
                        _toKurdishDigits(v.todayOrders),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),

                    // 6. Status
                    Expanded(
                      flex: 2,
                      child: Center(child: _buildStatusBadge(v.status)),
                    ),

                    // 7. Actions [✏️] [👁]
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // View Details Eye Button
                          InkWell(
                            onTap: () => _showVendorDetailsDialog(v),
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
                            onTap: () => _showAddVendorDialog(existing: v),
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

          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Right side: 'نمایشکردنی 1 تا 5 لە 342 دانە'
                const Text(
                  'نمایشکردنی 1 تا 5 لە 342 دانە',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),

                // Left side: < 5 4 3 2 [1] >
                Row(
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

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isActive ? 'چالاک' : 'پێداچوونەوە',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: isActive ? const Color(0xFF16A34A) : const Color(0xFFD97706),
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
