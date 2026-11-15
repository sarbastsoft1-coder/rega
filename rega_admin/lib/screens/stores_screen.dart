import 'dart:async';
import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import 'package:flutter/services.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../widgets/admin_top_header.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';

/// Representation of a vendor item matching the exact design in the screenshot
class VendorItem {
  final int id;
  final int categoryId;
  final String name;
  final String subtitle;
  final String cuisine;
  final String city;
  final String address;
  final String phone;
  final int todayOrders;
  final String status; // 'active' (چالاک) | 'under_review' (پێداچوونەوە)
  final String imageUrl;
  final int deliveryFee;
  final double rating;
  final double lat;
  final double lng;

  VendorItem({
    required this.id,
    this.categoryId = 0,
    required this.name,
    this.subtitle = '',
    required this.cuisine,
    required this.city,
    this.address = '',
    required this.phone,
    required this.todayOrders,
    required this.status,
    required this.imageUrl,
    this.deliveryFee = 1500,
    this.rating = 9.6,
    this.lat = 34.6836,
    this.lng = 45.3189,
  });

  VendorItem copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? subtitle,
    String? cuisine,
    String? city,
    String? address,
    String? phone,
    int? todayOrders,
    String? status,
    String? imageUrl,
    int? deliveryFee,
    double? rating,
    double? lat,
    double? lng,
  }) {
    return VendorItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      cuisine: cuisine ?? this.cuisine,
      city: city ?? this.city,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      todayOrders: todayOrders ?? this.todayOrders,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      rating: rating ?? this.rating,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
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

  String _selectedCuisine = 'all';
  String _selectedCity = 'all';
  String _selectedStatus = 'all';
  int _currentPage = 1;

  // Live Top KPI metrics from PostgreSQL database
  String _registeredVendors = '٠';
  String _activeVendors = '٠';
  String _pendingApproval = '٠';
  String _todayOrders = '٠';

  List<VendorItem> _vendors = [];
  /// Marketplace home categories from admin (مارکێت، کافێ، …) — used when adding/filtering vendors.
  List<Map<String, dynamic>> _homeCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadFromBackend(silent: true));
  }

  List<String> get _cuisineFilterOptions {
    final names = _homeCategories
        .map((c) => c['name_ku']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    if (names.isEmpty) {
      // Fallback until categories load / if catalog is empty
      return [
        'all',
        ..._vendors.map((v) => v.cuisine).where((c) => c.trim().isNotEmpty).toSet(),
      ];
    }
    return ['all', ...names];
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _topSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend({bool silent = false}) async {
    if (!silent && _vendors.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        widget.api.getStores(),
        widget.api.getCategories(),
      ]);
      if (!mounted) return;
      final res = results[0] as List<dynamic>;
      final cats = (results[1] as List<dynamic>)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((c) => c['is_active'] != false)
          .toList()
        ..sort((a, b) =>
            ((a['sort_order'] as num?)?.toInt() ?? 0)
                .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));

      final mapped = res.map((m) {
        final map = m as Map<String, dynamic>;
        final name = map['name_ku']?.toString() ?? map['name_en']?.toString() ?? 'فرۆشگا';
        final cat = map['category'] as Map<String, dynamic>?;
        final cuisine = cat?['name_ku']?.toString() ?? 'خواردنی خێرا';
        final catId = (map['category_id'] as num?)?.toInt() ??
            (cat?['id'] as num?)?.toInt() ??
            0;
        final zone = map['neighborhood'] as Map<String, dynamic>?;
        final city = zone?['city']?.toString() ?? 'کەلار';
        final isApproved = map['is_approved'] == true;
        final activeOrders = (map['active_orders_count'] as num?)?.toInt() ?? 0;
        final rawRating = (map['rating'] as num?)?.toDouble() ?? 9.6;
        return VendorItem(
          id: (map['id'] as num?)?.toInt() ?? 0,
          categoryId: catId,
          name: name,
          subtitle: map['name_en']?.toString() ?? '',
          cuisine: cuisine,
          city: city,
          address: map['address_ku']?.toString() ?? city,
          phone: map['phone']?.toString() ?? '0750 000 0000',
          todayOrders: activeOrders,
          status: isApproved ? 'active' : 'under_review',
          imageUrl: map['cover_url']?.toString() ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=120&q=80',
          deliveryFee: (map['base_delivery_fee'] as num?)?.toInt() ?? 1500,
          rating: rawRating <= 5.01 ? rawRating * 2 : rawRating,
          lat: (map['lat'] as num?)?.toDouble() ?? 34.6836,
          lng: (map['lng'] as num?)?.toDouble() ?? 45.3189,
        );
      }).toList();

      final totalCount = mapped.length;
      final activeCount = mapped.where((v) => v.status == 'active').length;
      final pendingCount = mapped.where((v) => v.status == 'under_review').length;
      final totalActiveOrders = mapped.fold<int>(0, (sum, v) => sum + v.todayOrders);

      setState(() {
        _vendors = mapped;
        _homeCategories = cats;
        _registeredVendors = _toKurdishDigits(totalCount);
        _activeVendors = _toKurdishDigits(activeCount);
        _pendingApproval = _toKurdishDigits(pendingCount);
        _todayOrders = _toKurdishDigits(totalActiveOrders);
        _isLoading = false;
        // Drop stale filter if category was renamed/removed
        if (_selectedCuisine != 'all' &&
            !_cuisineFilterOptions.contains(_selectedCuisine)) {
          _selectedCuisine = 'all';
        }
      });
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
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
      if (_selectedCuisine != 'all' && v.cuisine != _selectedCuisine) return false;
      if (_selectedCity != 'all' && v.city != _selectedCity) return false;
      if (_selectedStatus == 'active' && v.status != 'active') return false;
      if (_selectedStatus == 'under_review' && v.status != 'under_review') return false;
      return true;
    }).toList();
  }

  void _showAddVendorDialog({VendorItem? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final passwordCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: (existing?.deliveryFee ?? 1500).toString());
    final ratingCtrl = TextEditingController(text: (existing?.rating ?? 9.6).toStringAsFixed(1));
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final latCtrl = TextEditingController(text: (existing?.lat ?? 34.6836).toStringAsFixed(6));
    final lngCtrl = TextEditingController(text: (existing?.lng ?? 45.3189).toStringAsFixed(6));
    const defaultCity = 'کەلار';
    String status = existing?.status ?? 'active';
    String imageUrl = existing?.imageUrl ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=160&q=80';
    bool isSaving = false;
    // Dynamic home category (مارکێت / کافێ / …) — users see this vendor under that tile.
    int? selectedCategoryId = existing?.categoryId != null && existing!.categoryId > 0
        ? existing.categoryId
        : (_homeCategories.isNotEmpty
            ? (_homeCategories.first['id'] as num?)?.toInt()
            : null);
    const feePresets = [1000, 1500, 2000, 2500, 3000];
    const locationPresets = <Map<String, dynamic>>[
      {'name': 'ناو بازاڕی کەلار', 'lat': 34.6836, 'lng': 45.3189},
      {'name': 'گەڕەکی شەهیدان', 'lat': 34.6912, 'lng': 45.3264},
      {'name': 'گەڕەکی مامۆستایان', 'lat': 34.6750, 'lng': 45.3100},
      {'name': 'گەڕەکی سەربەخۆیی', 'lat': 34.6980, 'lng': 45.3050},
    ];

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
        builder: (ctx, setDialogState) {
          final mq = MediaQuery.of(ctx);
          final screenW = mq.size.width;
          final screenH = mq.size.height;
          final isNarrow = screenW < AdminBreakpoints.phone;
          final isCompact = screenW < 420;
          final dialogW = AdminBreakpoints.dialogWidth(ctx, max: 560);
          final padH = isCompact ? 14.0 : (isNarrow ? 18.0 : 24.0);
          final padV = isCompact ? 14.0 : 20.0;
          final maxDialogH = (screenH - mq.viewInsets.bottom - 32).clamp(320.0, screenH * 0.92);

          Widget statusChip({
            required bool selected,
            required Color activeBg,
            required Color activeBorder,
            required Color activeDot,
            required Color activeText,
            required String label,
            required VoidCallback onTap,
          }) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? activeBg : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? activeBorder : const Color(0xFFE2E8F0),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected ? activeDot : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCompact ? 11.5 : 12.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? activeText : const Color(0xFF64748B),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final feeBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'نرخی گەیاندنی ماتۆرسوار (د.ع)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              _buildDialogInput(
                controller: feeCtrl,
                label: '',
                hint: '1500',
                icon: Icons.two_wheeler_rounded,
                numeric: true,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: feePresets.map((fee) {
                  final selected = feeCtrl.text.trim() == fee.toString();
                  return FilterChip(
                    selected: selected,
                    label: Text('$fee'),
                    selectedColor: const Color(0xFFFFEDD5),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => setDialogState(() => feeCtrl.text = fee.toString()),
                  );
                }).toList(),
              ),
            ],
          );

          final ratingBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ڕێژەی ئەستێرە لە ١٠',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              _buildDialogInput(
                controller: ratingCtrl,
                label: '',
                hint: '9.6',
                icon: Icons.star_rounded,
                numeric: true,
              ),
              const SizedBox(height: 6),
              Text(
                'نموونە: 8.5 یان 9.8 لە ١٠',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ],
          );

          final cancelBtn = OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              backgroundColor: const Color(0xFFF8FAFC),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20, vertical: 13),
              minimumSize: Size(isNarrow ? double.infinity : 0, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('پاشگەزبوونەوە', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          );

          final saveBtn = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 24, vertical: 13),
              minimumSize: Size(isNarrow ? double.infinity : 0, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(isEdit ? Icons.save_rounded : Icons.add_business_rounded, size: 18),
            label: Text(
              isEdit ? 'پاشەکەوتکردن' : AppStrings.tr('add_vendor', widget.lang),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            onPressed: isSaving ? null : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          final password = passwordCtrl.text.trim();
                          if (!isEdit && password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('وشەی نهێنی پێویستە بۆ هەژماری فرۆشیار (لانیکەم ٦ پیت)'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }
                          if (password.isNotEmpty && password.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.tr('customer_password_min', widget.lang)),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }

                          if (selectedCategoryId == null || selectedCategoryId! <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تکایە جۆری فرۆشیار هەڵبژێرە (مارکێت، کافێ، …)'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          final phone = phoneCtrl.text.trim();
                          final subtitle = subtitleCtrl.text.trim();

                          final deliveryFee = int.tryParse(feeCtrl.text.trim()) ?? 1500;
                          final ratingVal = (double.tryParse(ratingCtrl.text.trim()) ?? 9.6).clamp(0, 10).toDouble();
                          final city = (existing?.city.trim().isNotEmpty == true)
                              ? existing!.city
                              : defaultCity;
                          final address = addressCtrl.text.trim().isNotEmpty
                              ? addressCtrl.text.trim()
                              : city;
                          final lat = double.tryParse(latCtrl.text.trim()) ?? 34.6836;
                          final lng = double.tryParse(lngCtrl.text.trim()) ?? 45.3189;
                          if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Latitude / Longitude نادروستە'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }

                          try {
                            final storePayload = <String, dynamic>{
                              'name_ku': name,
                              if (subtitle.isNotEmpty) 'name_en': subtitle,
                              'category_id': selectedCategoryId,
                              'phone': phone.isNotEmpty ? phone : '0750 000 0000',
                              'address_ku': address,
                              'address_ar': address,
                              'lat': lat,
                              'lng': lng,
                              'is_approved': status == 'active',
                              'is_online': status == 'active',
                              'cover_url': imageUrl,
                              'base_delivery_fee': deliveryFee,
                              'rating': ratingVal,
                              'owner_name': name,
                              'owner_phone': phone.isNotEmpty ? phone : '0750 000 0000',
                              'owner_is_active': status == 'active',
                              if (password.isNotEmpty) 'owner_password': password,
                            };

                            if (isEdit) {
                              await widget.api.updateStore(existing.id, storePayload);
                            } else {
                              await widget.api.createStore({
                                ...storePayload,
                                'owner_password': password,
                              });
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            await _loadFromBackend();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit
                                      ? 'فرۆشیار لە داتابەیس نوێکرایەوە ✅'
                                      : 'فرۆشیاری نوێ زیادکرا ✅'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            }
                            return;
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                            return;
                          }
            },
          );

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 16,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 16,
              vertical: isCompact ? 12 : 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogW,
                maxHeight: maxDialogH,
              ),
              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: mq.viewInsets.bottom > 0 ? 12 : 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: isCompact ? 40 : 48,
                            height: isCompact ? 40 : 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFEDD5)),
                            ),
                            child: Icon(
                              isEdit ? Icons.edit_note_rounded : Icons.storefront_rounded,
                              color: const Color(0xFFEA580C),
                              size: isCompact ? 22 : 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'دەستکاریکردنی فرۆشیار' : 'زیادکردنی فرۆشیاری نوێ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: isCompact ? 15.5 : 17.5,
                                    color: AdminSurfaces.of(context).textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isEdit
                                      ? 'دەستکاری زانیارییەکانی ئەم فرۆشگایە بکە لە داتابەیسدا'
                                      : 'زانیارییە سەرەکییەکانی فرۆشگا و چێشتخانە تۆمار بکە',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isCompact ? 11 : 12,
                                    color: AdminSurfaces.of(context).textSecondary,
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
                              decoration: BoxDecoration(
                                color: AdminSurfaces.of(context).chipFill,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 12 : 16),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      SizedBox(height: isCompact ? 12 : 16),

                              // Cover image + presets
                              if (isCompact) ...[
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      imageUrl,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: const Icon(Icons.storefront_rounded, color: Color(0xFFEA580C)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'وێنەی ڕووکەشی فرۆشگا',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: imagePresets.map((preset) {
                                    final isSelected = imageUrl == preset['url'];
                                    return InkWell(
                                      onTap: () => setDialogState(() => imageUrl = preset['url']!),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    );
                                  }).toList(),
                                ),
                              ] else
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
                                        errorBuilder: (_, _, _) => Container(
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
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: imagePresets.map((preset) {
                                              final isSelected = imageUrl == preset['url'];
                                              return InkWell(
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
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 14),

                              // Marketplace category
                              const Text(
                                'جۆری فرۆشیار (بەشی ئەپ) *',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'کڕیار ئەم فرۆشیارە لەم بەشەدا دەبینێت (مارکێت، کافێ، …)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              if (_homeCategories.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: const Text(
                                    'هیچ بەشێک نەدۆزرایەوە. سەرەتا لە کاتالۆگ / جۆرەکان بەشێک زیاد بکە.',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _homeCategories.map((cat) {
                                    final id = (cat['id'] as num?)?.toInt();
                                    final name = cat['name_ku']?.toString() ?? '';
                                    final selected = id != null && selectedCategoryId == id;
                                    return FilterChip(
                                      selected: selected,
                                      label: Text(name),
                                      selectedColor: const Color(0xFFFFEDD5),
                                      checkmarkColor: const Color(0xFFEA580C),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      labelStyle: TextStyle(
                                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                        color: selected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                      side: BorderSide(
                                        color: selected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                                        width: selected ? 1.5 : 1,
                                      ),
                                      onSelected: id == null
                                          ? null
                                          : (_) => setDialogState(() => selectedCategoryId = id),
                                    );
                                  }).toList(),
                                ),

                              const SizedBox(height: 14),
                              _buildDialogInput(
                                controller: nameCtrl,
                                label: 'ناوی فرۆشیار (چێشتخانە / کافێ / مارکێت) *',
                                hint: 'بۆ نموونە: چێشتخانەی ئارام، کافێ ڕۆژ، مارکێتی کەلار',
                                icon: Icons.storefront_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogInput(
                                controller: subtitleCtrl,
                                label: 'پێناسەی کورت (وەک: خواردنی کوردی و گریل)',
                                hint: 'پێناسەیەکی کورت لەسەر فرۆشگاکە',
                                icon: Icons.subtitles_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogInput(
                                controller: phoneCtrl,
                                label: 'ژمارەی مۆبایل *',
                                hint: '0750 000 0000',
                                icon: Icons.phone_outlined,
                                isPhone: true,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogInput(
                                controller: passwordCtrl,
                                label: isEdit
                                    ? AppStrings.tr('password_new_optional', widget.lang)
                                    : '${AppStrings.tr('password_label', widget.lang)} *',
                                hint: isEdit ? '••••••••' : 'لانیکەم ٦ پیت',
                                icon: Icons.lock_outline_rounded,
                                obscureText: true,
                              ),
                              const SizedBox(height: 12),

                              const Text(
                                'شوێنی فرۆشگا (نەخشە) *',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 6),
                              _buildDialogInput(
                                controller: addressCtrl,
                                label: '',
                                hint: 'ناونیشانی فرۆشگا — نموونە: ناو بازاڕی کەلار',
                                icon: Icons.place_rounded,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: locationPresets.map((p) {
                                  final selected = latCtrl.text.trim() == (p['lat'] as double).toStringAsFixed(6) &&
                                      lngCtrl.text.trim() == (p['lng'] as double).toStringAsFixed(6);
                                  return FilterChip(
                                    selected: selected,
                                    label: Text(p['name'] as String, style: const TextStyle(fontSize: 11.5)),
                                    selectedColor: const Color(0xFFFFEDD5),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    onSelected: (_) => setDialogState(() {
                                      addressCtrl.text = p['name'] as String;
                                      latCtrl.text = (p['lat'] as double).toStringAsFixed(6);
                                      lngCtrl.text = (p['lng'] as double).toStringAsFixed(6);
                                    }),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              if (isCompact) ...[
                                _buildDialogInput(
                                  controller: latCtrl,
                                  label: 'Latitude',
                                  hint: '34.683600',
                                  icon: Icons.my_location_rounded,
                                  numeric: true,
                                ),
                                const SizedBox(height: 10),
                                _buildDialogInput(
                                  controller: lngCtrl,
                                  label: 'Longitude',
                                  hint: '45.318900',
                                  icon: Icons.explore_rounded,
                                  numeric: true,
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDialogInput(
                                        controller: latCtrl,
                                        label: 'Latitude',
                                        hint: '34.683600',
                                        icon: Icons.my_location_rounded,
                                        numeric: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDialogInput(
                                        controller: lngCtrl,
                                        label: 'Longitude',
                                        hint: '45.318900',
                                        icon: Icons.explore_rounded,
                                        numeric: true,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 6),
                              Text(
                                'کاتێک فرۆشیار ماتۆرسوار دیاری دەکات، ئەم شوێنە لەسەر نەخشەی ماتۆرسوار دەردەکەوێت.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),

                              // Fee + rating: stack on phone, side-by-side on wider
                              if (isNarrow) ...[
                                feeBlock,
                                const SizedBox(height: 14),
                                ratingBlock,
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: feeBlock),
                                    const SizedBox(width: 12),
                                    Expanded(child: ratingBlock),
                                  ],
                                ),

                              const SizedBox(height: 14),
                              const Text(
                                'دۆخی فرۆشیار',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 6),
                              if (isCompact) ...[
                                statusChip(
                                  selected: status == 'active',
                                  activeBg: const Color(0xFFDCFCE7),
                                  activeBorder: const Color(0xFF16A34A),
                                  activeDot: const Color(0xFF16A34A),
                                  activeText: const Color(0xFF15803D),
                                  label: 'چالاک (Active)',
                                  onTap: () => setDialogState(() => status = 'active'),
                                ),
                                const SizedBox(height: 8),
                                statusChip(
                                  selected: status == 'under_review',
                                  activeBg: const Color(0xFFFEF3C7),
                                  activeBorder: const Color(0xFFD97706),
                                  activeDot: const Color(0xFFD97706),
                                  activeText: const Color(0xFFB45309),
                                  label: 'مسدود / Blocked',
                                  onTap: () => setDialogState(() => status = 'under_review'),
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: statusChip(
                                        selected: status == 'active',
                                        activeBg: const Color(0xFFDCFCE7),
                                        activeBorder: const Color(0xFF16A34A),
                                        activeDot: const Color(0xFF16A34A),
                                        activeText: const Color(0xFF15803D),
                                        label: 'چالاک (Active / Unblocked)',
                                        onTap: () => setDialogState(() => status = 'active'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: statusChip(
                                        selected: status == 'under_review',
                                        activeBg: const Color(0xFFFEF3C7),
                                        activeBorder: const Color(0xFFD97706),
                                        activeDot: const Color(0xFFD97706),
                                        activeText: const Color(0xFFB45309),
                                        label: 'مسدود / Blocked',
                                        onTap: () => setDialogState(() => status = 'under_review'),
                                      ),
                                    ),
                                  ],
                                ),

                      SizedBox(height: isCompact ? 12 : 16),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      SizedBox(height: isCompact ? 12 : 14),

                      // Footer actions
                      if (isNarrow) ...[
                        saveBtn,
                        const SizedBox(height: 8),
                        cancelBtn,
                      ] else
                        Row(
                          children: [
                            Expanded(child: cancelBtn),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: saveBtn),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPhone = false,
    bool numeric = false,
    bool obscureText = false,
  }) {
    final ltr = isPhone || numeric;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
        ],
        Directionality(
          textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: isPhone
                ? TextInputType.phone
                : (numeric
                    ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                    : TextInputType.text),
            textAlign: ltr ? TextAlign.left : TextAlign.right,
            inputFormatters: isPhone
                ? [IraqPhoneFormatter()]
                : (numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))] : null),
            decoration: InputDecoration(
              hintText: isPhone ? '0750 000 0000' : hint,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              isDense: true,
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
        child: Builder(
          builder: (ctx2) {
            final w = MediaQuery.sizeOf(ctx2).width;
            final isNarrow = w < AdminBreakpoints.phone;
            final pad = isNarrow ? 16.0 : 24.0;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AdminBreakpoints.dialogWidth(ctx2, max: 480),
                maxHeight: MediaQuery.sizeOf(ctx2).height * 0.9,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                v.subtitle.isNotEmpty ? v.subtitle : v.cuisine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: AdminSurfaces.of(context).textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(v.status),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('جۆر:', v.cuisine),
                          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('شار:', v.city),
                          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('ناونیشان:', v.address.isNotEmpty ? v.address : v.city),
                          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('GPS:', '${v.lat.toStringAsFixed(5)}, ${v.lng.toStringAsFixed(5)}'),
                          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('مۆبایل:', v.phone),
                          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('داواکاریی ئەمڕۆ:', '${_toKurdishDigits(v.todayOrders)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isNarrow) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('دەستکاریکردن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddVendorDialog(existing: v);
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('داخستن', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
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
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF111827)),
            ),
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
      textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AdminBreakpoints.pagePadH(context), vertical: 16),
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
        final w = constraints.maxWidth;
        final isCompact = w < AdminBreakpoints.headerCompact;
        final isNarrow = w < AdminBreakpoints.headerInline;
        final titleSize = w < 400 ? 18.0 : 22.0;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr('stores_title', widget.lang),
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                color: AdminSurfaces.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.tr('stores_subtitle', widget.lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: w < 400 ? 11.5 : 12.5,
                color: AdminSurfaces.of(context).textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final addBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEA580C),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: Size(isCompact ? double.infinity : 0, 44),
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            shadowColor: const Color(0xFFEA580C).withValues(alpha: 0.3),
          ),
          onPressed: () => _showAddVendorDialog(),
          icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
          label: Text(
            AppStrings.tr('add_vendor', widget.lang),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
          ),
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _topSearchCtrl,
          hintText: AppStrings.tr('search_vendor', widget.lang),
          onSearchChanged: (_) => setState(() {}),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topActions,
              const SizedBox(height: 12),
              titleBlock,
              const SizedBox(height: 12),
              addBtn,
            ],
          );
        }
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  addBtn,
                ],
              ),
              const SizedBox(height: 12),
              topActions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(child: titleBlock),
                  const SizedBox(width: 14),
                  addBtn,
                ],
              ),
            ),
            const SizedBox(width: 16),
            topActions,
          ],
        );
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
        final gap = width < 400 ? 10.0 : 16.0;
        final double cardWidth;
        if (width >= AdminBreakpoints.kpiFourCol) {
          cardWidth = (width - gap * 3) / 4;
        } else if (width >= AdminBreakpoints.kpiTwoCol) {
          cardWidth = (width - gap) / 2;
        } else {
          cardWidth = width;
        }
        Widget card({
          required String title,
          required String value,
          required IconData icon,
          required Color iconBg,
          required Color iconColor,
        }) {
          return SizedBox(
            width: cardWidth,
            child: _buildKPICard(
              title: title,
              value: value,
              icon: icon,
              iconBg: iconBg,
              iconColor: iconColor,
              compact: width < 400,
            ),
          );
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            card(
              title: AppStrings.tr('kpi_total_vendors', widget.lang),
              value: _registeredVendors,
              icon: Icons.groups_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF16A34A),
            ),
            card(
              title: AppStrings.tr('kpi_active_vendors', widget.lang),
              value: _activeVendors,
              icon: Icons.person_outline_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF16A34A),
            ),
            card(
              title: AppStrings.tr('kpi_pending_approval', widget.lang),
              value: _pendingApproval,
              icon: Icons.access_time_rounded,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
            ),
            card(
              title: AppStrings.tr('kpi_today_orders', widget.lang),
              value: _todayOrders,
              icon: Icons.description_outlined,
              iconBg: const Color(0xFFFFEDD5),
              iconColor: const Color(0xFFEA580C),
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
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminSurfaces.of(context).textSecondary,
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w900,
                    color: AdminSurfaces.of(context).textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: compact ? 40 : 44,
            height: compact ? 40 : 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: compact ? 20 : 22),
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
        final w = constraints.maxWidth;
        final gap = 12.0;
        // Phone: 1 col · tablet: 2 col · desktop: 3 col
        final cols = w < 480 ? 1 : (w < 800 ? 2 : 3);
        final itemWidth = cols == 1
            ? w
            : ((w - gap * (cols - 1)) / cols).clamp(140.0, w);

        Widget filterField({
          required String label,
          required Widget child,
        }) {
          return SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                child,
              ],
            ),
          );
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            filterField(
              label: AppStrings.tr('cuisine_type', widget.lang),
              child: _buildDropdownPill(
                value: _cuisineFilterOptions.contains(_selectedCuisine)
                    ? _selectedCuisine
                    : 'all',
                items: _cuisineFilterOptions,
                labels: [
                  for (final c in _cuisineFilterOptions)
                    c == 'all' ? AppStrings.tr('all_types', widget.lang) : c,
                ],
                onChanged: (v) => setState(() => _selectedCuisine = v ?? 'all'),
              ),
            ),
            filterField(
              label: AppStrings.tr('city', widget.lang),
              child: _buildDropdownPill(
                value: _selectedCity,
                items: ['all', ...AppStrings.knownCitiesKu],
                labels: [
                  AppStrings.tr('all_cities', widget.lang),
                  for (final c in AppStrings.knownCitiesKu) AppStrings.cityLabel(c, widget.lang),
                ],
                onChanged: (v) => setState(() => _selectedCity = v ?? 'all'),
              ),
            ),
            filterField(
              label: AppStrings.tr('status', widget.lang),
              child: _buildDropdownPill(
                value: _selectedStatus,
                items: const ['all', 'active', 'under_review'],
                labels: [
                  AppStrings.tr('all_statuses', widget.lang),
                  AppStrings.tr('active', widget.lang),
                  AppStrings.statusLabel('under_review', widget.lang),
                ],
                onChanged: (v) => setState(() => _selectedStatus = v ?? 'all'),
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
    List<String>? labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: TextStyle(
            fontSize: 12.5,
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

  Widget _buildVendorMobileCard(VendorItem v) {
    final surfaces = AdminSurfaces.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  v.imageUrl,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 42,
                    height: 42,
                    color: surfaces.chipFill,
                    child: const Icon(Icons.storefront_rounded, size: 22, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    if (v.subtitle.isNotEmpty)
                      Text(v.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: surfaces.textTertiary)),
                    const SizedBox(height: 4),
                    Text(
                      '${v.cuisine} • ${v.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: surfaces.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(v.status, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(v.phone, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              Text(
                'ئەمڕۆ: ${_toKurdishDigits(v.todayOrders)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFEA580C)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _showVendorDetailsDialog(v),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showAddVendorDialog(existing: v),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 4. MAIN VENDORS TABLE CARD (Matching Screenshot)
  // ============================================================================
  Widget _buildVendorsTableCard(List<VendorItem> list) {
    // Show top 5 records for page 1
    final pagedList = list.take(5).toList();

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
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Cards on phone + small tablet; table from ~720px up.
              final useCards = constraints.maxWidth < 720;
              if (useCards) {
                return Column(
                  children: [
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.storefront_outlined, size: 40, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 10),
                              Text(
                                'هیچ فرۆشگایەک لە سیستەمدا نییە',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...pagedList.map(_buildVendorMobileCard),
                  ],
                );
              }
              final tableWidth = constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Headers
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: AdminSurfaces.of(context).mutedFill,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          border: Border(bottom: BorderSide(color: AdminSurfaces.of(context).hairline)),
                        ),
                        child: Row(
                          children: [
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
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.storefront_outlined, size: 40, color: Color(0xFFCBD5E1)),
                                SizedBox(height: 10),
                                Text(
                                  'هیچ فرۆشگایەک لە سیستەمدا نییە',
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
                        separatorBuilder: (_, _) => Divider(height: 1, color: AdminSurfaces.of(context).hairline),
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
                                              color: AdminSurfaces.of(context).chipFill,
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
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: AdminSurfaces.of(context).textTertiary,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AdminSurfaces.of(context).textPrimary,
                                    ),
                                  ),
                                ),

                                // 3. City
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    v.city,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AdminSurfaces.of(context).textPrimary,
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AdminSurfaces.of(context).textPrimary,
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
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AdminSurfaces.of(context).textPrimary,
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
                                            color: AdminSurfaces.of(context).chipFill,
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
                                            color: AdminSurfaces.of(context).chipFill,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final narrowFooter = constraints.maxWidth < 480;
              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: narrowFooter ? 12 : 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AdminSurfaces.of(context).hairline)),
                ),
                child: Wrap(
                  alignment: narrowFooter ? WrapAlignment.center : WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Text(
                      'نمایشکردنی ${_toKurdishDigits(pagedList.length)} لە ${_toKurdishDigits(list.length)} دانە',
                      textAlign: narrowFooter ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminSurfaces.of(context).textSecondary,
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool compact = false}) {
    final isActive = status == 'active';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isActive ? 'چالاک' : (compact ? 'پێداچوونەوە' : 'پێداچوونەوە'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11.5,
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

  TextStyle get _headerStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AdminSurfaces.of(context).textSecondary,
  );
}
