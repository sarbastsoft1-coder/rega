import 'dart:async';
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
  Timer? _refreshTimer;

  String _selectedCuisine = 'هەموو جۆرەکان';
  String _selectedCity = 'هەموو شارەکان';
  String _selectedStatus = 'هەموو دۆخەکان';
  int _currentPage = 1;

  // Live Top KPI metrics from PostgreSQL database
  String _registeredVendors = '٠';
  String _activeVendors = '٠';
  String _pendingApproval = '٠';
  String _todayOrders = '٠';

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) => _loadFromBackend(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _topSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend({bool silent = false}) async {
    try {
      final res = await widget.api.getStores();
      if (res.isNotEmpty && mounted) {
        final mapped = res.map((m) {
          final map = m as Map<String, dynamic>;
          final name = map['name_ku']?.toString() ?? map['name_en']?.toString() ?? 'فرۆشگا';
          final cat = map['category'] as Map<String, dynamic>?;
          final cuisine = cat?['name_ku']?.toString() ?? 'خواردنی خێرا';
          final zone = map['neighborhood'] as Map<String, dynamic>?;
          final city = zone?['city']?.toString() ?? 'کەلار';
          final isApproved = map['is_approved'] == true;
          final activeOrders = (map['active_orders_count'] as num?)?.toInt() ?? 0;
          return VendorItem(
            id: (map['id'] as num?)?.toInt() ?? 0,
            name: name,
            subtitle: 'خزمەتگوزاری چێشتخانە و فرۆشگا',
            cuisine: cuisine,
            city: city,
            phone: map['phone']?.toString() ?? '0750 000 0000',
            todayOrders: activeOrders,
            status: isApproved ? 'active' : 'under_review',
            imageUrl: map['cover_url']?.toString() ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=120&q=80',
          );
        }).toList();

        final totalCount = mapped.length;
        final activeCount = mapped.where((v) => v.status == 'active').length;
        final pendingCount = mapped.where((v) => v.status == 'under_review').length;
        final totalActiveOrders = mapped.fold<int>(0, (sum, v) => sum + v.todayOrders);

        setState(() {
          _vendors = mapped;
          _registeredVendors = _toKurdishDigits(totalCount);
          _activeVendors = _toKurdishDigits(activeCount);
          _pendingApproval = _toKurdishDigits(pendingCount);
          _todayOrders = _toKurdishDigits(totalActiveOrders > 0 ? totalActiveOrders : totalCount);
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
    String imageUrl = existing?.imageUrl ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=160&q=80';
    bool isSaving = false;

    final imagePresets = [
      {'name': 'خواردنی کوردی', 'url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=160&q=80'},
      {'name': 'گریل و کەباب', 'url': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=160&q=80'},
      {'name': 'پیتزا و فاست فود', 'url': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=160&q=80'},
      {'name': 'کافێ و خواردنەوە', 'url': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=160&q=80'},
      {'name': 'شیرینی و کێک', 'url': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=160&q=80'},
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 16,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header ---
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_note_rounded : Icons.storefront_rounded,
                          color: const Color(0xFFEA580C),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'دەستکاریکردنی فرۆشیار' : 'زیادکردنی فرۆشیاری نوێ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17.5,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isEdit
                                  ? 'دەستکاری زانیارییەکانی ئەم فرۆشگایە بکە لە داتابەیسدا'
                                  : 'زانیارییە سەرەکییەکانی فرۆشگا و چێشتخانە تۆمار بکە',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 18),

                  // Image Preview & Preset Selector
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFFEA580C)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'وێنەی ڕووکەشی فرۆشگا',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: imagePresets.map((preset) {
                                  final isSelected = imageUrl == preset['url'];
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: InkWell(
                                      onTap: () => setDialogState(() => imageUrl = preset['url']!),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          preset['name']!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 1. Store Name
                  _buildDialogInput(
                    controller: nameCtrl,
                    label: 'ناوی فرۆشیار (چێشتخانە / کافێ) *',
                    hint: 'بۆ نموونە: چێشتخانەی ئارام، کافێ ڕۆژ',
                    icon: Icons.storefront_outlined,
                  ),

                  const SizedBox(height: 14),

                  // 2. Subtitle / Description
                  _buildDialogInput(
                    controller: subtitleCtrl,
                    label: 'پێناسەی کورت (وەک: خواردنی کوردی و گریل)',
                    hint: 'پێناسەیەکی کورت لەسەر فرۆشگاکە',
                    icon: Icons.subtitles_outlined,
                  ),

                  const SizedBox(height: 14),

                  // 3. Phone Number
                  _buildDialogInput(
                    controller: phoneCtrl,
                    label: 'ژمارەی مۆبایل *',
                    hint: '0750 123 4567',
                    icon: Icons.phone_outlined,
                    isPhone: true,
                  ),

                  const SizedBox(height: 14),

                  // 4. Cuisine & City Row
                  Row(
                    children: [
                      // Cuisine
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'جۆری خواردن',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: cuisine,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  items: const [
                                    DropdownMenuItem(value: 'خواردنی کوردی', child: Text('خواردنی کوردی')),
                                    DropdownMenuItem(value: 'کافێی خواردنی خێرا', child: Text('کافێی خواردنی خێرا')),
                                    DropdownMenuItem(value: 'پیتزا و خۆراکی خێرا', child: Text('پیتزا و خۆراکی خێرا')),
                                    DropdownMenuItem(value: 'شیرینی و خۆراکی شیرین', child: Text('شیرینی و خۆراکی شیرین')),
                                  ],
                                  onChanged: (v) => setDialogState(() => cuisine = v ?? 'خواردنی کوردی'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // City
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'شار',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: city,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  items: const [
                                    DropdownMenuItem(value: 'هەولێر', child: Text('هەولێر')),
                                    DropdownMenuItem(value: 'سلێمانی', child: Text('سلێمانی')),
                                    DropdownMenuItem(value: 'دهۆک', child: Text('دهۆک')),
                                    DropdownMenuItem(value: 'کەلار', child: Text('کەلار')),
                                    DropdownMenuItem(value: 'کەرکووک', child: Text('کەرکووک')),
                                  ],
                                  onChanged: (v) => setDialogState(() => city = v ?? 'هەولێر'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 5. Store Status Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'دۆخی فرۆشیار',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => status = 'active'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: status == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: status == 'active' ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                    width: status == 'active' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: status == 'active' ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'چالاک (Active)',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: status == 'active' ? FontWeight.w800 : FontWeight.w600,
                                        color: status == 'active' ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => status = 'under_review'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: status == 'under_review' ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: status == 'under_review' ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
                                    width: status == 'under_review' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: status == 'under_review' ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'چاوەڕوانی پەسەندکردن',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: status == 'under_review' ? FontWeight.w800 : FontWeight.w600,
                                        color: status == 'under_review' ? const Color(0xFFB45309) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 18),

                  // --- Action Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('پاشگەزبوونەوە', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(isEdit ? Icons.save_rounded : Icons.add_business_rounded, size: 18),
                        label: Text(
                          isEdit ? 'پاشەکەوتکردن' : 'زیادکردنی فرۆشیار',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        onPressed: isSaving ? null : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          setDialogState(() => isSaving = true);

                          final phone = phoneCtrl.text.trim();
                          final subtitle = subtitleCtrl.text.trim();

                          // Persist via API
                          try {
                            if (isEdit) {
                              await widget.api.updateStore(existing.id, {
                                'name_ku': name,
                                'phone': phone.isNotEmpty ? phone : '0750 000 0000',
                                'address_ku': city,
                                'is_approved': status == 'active',
                                'is_online': status == 'active',
                                'cover_url': imageUrl,
                              });
                            } else {
                              await widget.api.createStore({
                                'name_ku': name,
                                'phone': phone.isNotEmpty ? phone : '0750 000 0000',
                                'address_ku': city,
                                'category_id': 1,
                                'is_approved': status == 'active',
                                'is_online': status == 'active',
                                'cover_url': imageUrl,
                              });
                            }
                          } catch (_) {}

                          if (mounted) {
                            setState(() {
                              if (isEdit) {
                                final idx = _vendors.indexWhere((v) => v.id == existing.id);
                                if (idx != -1) {
                                  _vendors[idx] = existing.copyWith(
                                    name: name,
                                    subtitle: subtitle,
                                    phone: phone,
                                    cuisine: cuisine,
                                    city: city,
                                    status: status,
                                    imageUrl: imageUrl,
                                  );
                                }
                              } else {
                                _vendors.insert(
                                  0,
                                  VendorItem(
                                    id: DateTime.now().millisecondsSinceEpoch,
                                    name: name,
                                    subtitle: subtitle.isNotEmpty ? subtitle : 'خزمەتگوزاری چێشتخانە و فرۆشگا',
                                    cuisine: cuisine,
                                    city: city,
                                    phone: phone.isNotEmpty ? phone : '0750 000 0000',
                                    todayOrders: 0,
                                    status: status,
                                    imageUrl: imageUrl,
                                  ),
                                );
                              }
                            });
                          }

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          _loadFromBackend(silent: true);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? 'فرۆشیار نوێکرایەوە' : 'فرۆشیاری نوێ بە سەرکەوتوویی زیادکرا'),
                                backgroundColor: const Color(0xFFEA580C),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
          child: TextField(
            controller: controller,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            textAlign: isPhone ? TextAlign.left : TextAlign.right,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showVendorDetailsDialog(VendorItem v) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      v.imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFFEA580C)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          v.subtitle.isNotEmpty ? v.subtitle : v.cuisine,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(v.status),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('🍔 جۆری خواردن:', v.cuisine),
                    const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('🏙️ شار:', v.city),
                    const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('📱 ژمارەی مۆبایل:', v.phone),
                    const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('📦 داواکارییەکانی ئەمڕۆ:', '${_toKurdishDigits(v.todayOrders)} داواکاری'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('داخستن', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('دەستکاریکردن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddVendorDialog(existing: v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                shadowColor: const Color(0xFFEA580C).withValues(alpha: 0.3),
              ),
              onPressed: () => _showAddVendorDialog(),
              icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              label: const Text(
                'زیادکردنی فرۆشیار',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );

        final profileAndBell = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
            const SizedBox(width: 14),
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
              titleAndButton,
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
                  Expanded(child: titleAndButton),
                  const SizedBox(width: 12),
                  profileAndBell,
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
              titleAndButton,
              Row(
                children: [
                  profileAndBell,
                  const SizedBox(width: 16),
                  searchBar,
                ],
              ),
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. 4 TOP KPI METRIC SUMMARY CARDS
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
            // Card 1: کۆی فرۆشیاران (Rightmost)
            SizedBox(
              width: cardWidth,
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
              width: cardWidth,
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
              width: cardWidth,
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
              width: cardWidth,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;
        final itemWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 28) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // 1. Food Type: جۆری خواردن -> هەموو جۆرەکان
            SizedBox(
              width: isNarrow && constraints.maxWidth < 420 ? constraints.maxWidth : itemWidth.clamp(160.0, 360.0),
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

            // 2. City: شار -> هەموو شارەکان
            SizedBox(
              width: isNarrow && constraints.maxWidth < 420 ? constraints.maxWidth : itemWidth.clamp(160.0, 360.0),
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

            // 3. Status: دۆخ -> هەموو دۆخەکان
            SizedBox(
              width: isNarrow && constraints.maxWidth < 420 ? constraints.maxWidth : itemWidth.clamp(160.0, 360.0),
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
      },
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
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth > 840 ? constraints.maxWidth : 840.0;
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
          color: active ? const Color(0xFFEA580C) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
