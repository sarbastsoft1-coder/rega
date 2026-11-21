import 'dart:async';
import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/services/media_pick_service.dart';
import '../state/admin_app_notifier.dart';
import '../widgets/admin_top_header.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
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

  // Live Top KPI metrics from PostgreSQL database (raw; digits formatted at display time)
  int _registeredVendors = 0;
  int _activeVendors = 0;
  int _pendingApproval = 0;
  int _todayOrders = 0;

  List<VendorItem> _vendors = [];
  /// Marketplace home categories from admin (مارکێت، کافێ، …) — used when adding/filtering vendors.
  List<Map<String, dynamic>> _homeCategories = [];
  bool _isLoading = true;

  String get _lang => widget.lang;
  String _t(String key) => AppStrings.tr(key, _lang);
  String _d(dynamic input) => AppStrings.digits(input, _lang);

  String _categoryLabel(Map<String, dynamic> cat) =>
      AppStrings.localizedName(cat, _lang, fallbackKey: 'cuisine_fallback');

  String _cuisineLabelForKey(String cuisineKey) {
    for (final cat in _homeCategories) {
      final ku = cat['name_ku']?.toString() ?? '';
      if (ku == cuisineKey) return _categoryLabel(cat);
    }
    return cuisineKey;
  }

  String _vendorCuisineLabel(VendorItem v) {
    if (v.categoryId > 0) {
      for (final cat in _homeCategories) {
        if ((cat['id'] as num?)?.toInt() == v.categoryId) {
          return _categoryLabel(cat);
        }
      }
    }
    return _cuisineLabelForKey(v.cuisine);
  }

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

  static bool _flagOn(dynamic v) => v == true || v == 1 || v == '1';
  static bool _flagOff(dynamic v) => v == false || v == 0 || v == '0';

  /// Same tiles as customer home: active + featured_home (fallback = all active).
  List<Map<String, dynamic>> _parseHomeCategories(List<dynamic> raw) {
    final active = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => !_flagOff(c['is_active']))
        .toList();
    final featured = active.where((c) => _flagOn(c['is_featured_home'])).toList();
    final source = featured.isNotEmpty ? featured : active;
    source.sort((a, b) =>
        ((a['sort_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
    return source;
  }

  Future<List<Map<String, dynamic>>> _fetchHomeCategories() async {
    final raw = await widget.api.getCategories();
    return _parseHomeCategories(raw);
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
      final cats = _parseHomeCategories(results[1] as List<dynamic>);

      final mapped = res.map((m) {
        final map = m as Map<String, dynamic>;
        final name = map['name_ku']?.toString() ??
            map['name_en']?.toString() ??
            AppStrings.tr('store_fallback', widget.lang);
        final cat = map['category'] as Map<String, dynamic>?;
        // Stable filter key (KU); display label is resolved via [_vendorCuisineLabel].
        final cuisine = cat?['name_ku']?.toString() ??
            cat?['name_en']?.toString() ??
            AppStrings.tr('cuisine_fallback', widget.lang);
        final catId = (map['category_id'] as num?)?.toInt() ??
            (cat?['id'] as num?)?.toInt() ??
            0;
        final zone = map['neighborhood'] as Map<String, dynamic>?;
        final city = zone?['city']?.toString() ?? AppStrings.cityDbValue('city_kalar');
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
        _registeredVendors = totalCount;
        _activeVendors = activeCount;
        _pendingApproval = pendingCount;
        _todayOrders = totalActiveOrders;
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

  Future<void> _showAddVendorDialog({VendorItem? existing}) async {
    // Always re-fetch home parts so newly added customer-home tiles appear here.
    List<Map<String, dynamic>> dialogCategories = List<Map<String, dynamic>>.from(_homeCategories);
    try {
      final fresh = await _fetchHomeCategories();
      if (!mounted) return;
      dialogCategories = fresh;
      setState(() => _homeCategories = fresh);
    } catch (_) {
      // Keep last known list if refresh fails.
    }

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
    final defaultCity = AppStrings.cityDbValue('city_kalar');
    String status = existing?.status ?? 'active';
    String imageUrl = existing?.imageUrl ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=160&q=80';
    bool isSaving = false;
    bool uploadingCover = false;
    // Dynamic home category (مارکێت / کافێ / …) — users see this vendor under that tile.
    int? selectedCategoryId = existing?.categoryId != null && existing!.categoryId > 0
        ? existing.categoryId
        : (dialogCategories.isNotEmpty
            ? (dialogCategories.first['id'] as num?)?.toInt()
            : null);
    // If editing a store whose category is missing from the home list, keep a chip for it.
    final initialCatId = selectedCategoryId;
    if (initialCatId != null &&
        initialCatId > 0 &&
        dialogCategories.every((c) => (c['id'] as num?)?.toInt() != initialCatId)) {
      dialogCategories = [
        ...dialogCategories,
        {
          'id': initialCatId,
          'name_ku': existing?.cuisine ?? _t('cuisine_fallback'),
          'image_url': existing?.imageUrl,
          'is_active': true,
          'is_featured_home': true,
        },
      ];
    }
    if (existing == null && initialCatId != null && initialCatId > 0) {
      for (final cat in dialogCategories) {
        if ((cat['id'] as num?)?.toInt() == initialCatId) {
          final cover = cat['image_url']?.toString().trim();
          if (cover != null && cover.isNotEmpty) {
            imageUrl = cover;
          }
          break;
        }
      }
    }
    const feePresets = [0, 1000, 1500, 2000, 2500, 3000];
    final locationPresets = <Map<String, dynamic>>[
      {'nameKey': 'loc_kalar_bazaar', 'lat': 34.6836, 'lng': 45.3189},
      {'nameKey': 'loc_shahidan', 'lat': 34.6912, 'lng': 45.3264},
      {'nameKey': 'loc_mamostayan', 'lat': 34.6750, 'lng': 45.3100},
      {'nameKey': 'loc_serbexoyi', 'lat': 34.6980, 'lng': 45.3050},
    ];

    // Same names/images as customer home tiles. Selecting a chip sets cover + category_id.
    List<Map<String, dynamic>> buildImagePresets(List<Map<String, dynamic>> cats) {
      if (cats.isEmpty) {
        return <Map<String, dynamic>>[
          {'name': _t('cat_restaurant'), 'url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=160&q=80', 'category_id': null},
          {'name': _t('cat_supermarket'), 'url': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=160&q=80', 'category_id': null},
          {'name': _t('cat_fast_food'), 'url': 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=160&q=80', 'category_id': null},
          {'name': _t('cat_produce'), 'url': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=160&q=80', 'category_id': null},
          {'name': _t('cat_cafe'), 'url': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=160&q=80', 'category_id': null},
          {'name': _t('cat_dairy_sweets'), 'url': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=160&q=80', 'category_id': null},
        ];
      }
      return cats.map((cat) {
        final name = _categoryLabel(cat);
        final img = cat['image_url']?.toString().trim();
        final id = (cat['id'] as num?)?.toInt();
        return {
          'name': name,
          'url': (img != null && img.isNotEmpty)
              ? img
              : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=160&q=80',
          'category_id': id,
        };
      }).where((p) => (p['name'] as String).isNotEmpty).toList();
    }

    final imagePresets = buildImagePresets(dialogCategories);

    showDialog(
      context: context,
      barrierColor: RC.bg(Colors.black).withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final mq = MediaQuery.of(ctx);
          final screenH = mq.size.height;
          // Breakpoints from dialog content width — not full window (avoids side-by-side overflow).
          final dialogW = AdminBreakpoints.dialogWidth(ctx, max: 560);
          final isCompact = dialogW < 420;
          final stackFields = dialogW < 520;
          final padH = isCompact ? 14.0 : (stackFields ? 16.0 : 22.0);
          final padV = isCompact ? 14.0 : 18.0;
          final maxDialogH = (screenH - mq.viewInsets.bottom - 32).clamp(320.0, screenH * 0.92);
          // Live language from Provider — never freeze Kurdish if user switched to EN.
          final lang = ctx.watch<AdminAppNotifier>().lang;
          final latLabel = AppStrings.tr('lat_label', lang);
          final lngLabel = AppStrings.tr('lng_label', lang);
          final activeLabel = AppStrings.tr('vendor_status_active', lang);
          final blockedLabel = AppStrings.statusLabel('under_review', lang);
          final feeTitle =
              '${AppStrings.tr('delivery_fee_label', lang)} (${AppStrings.tr('iqd', lang)})';
          final ratingTitle = AppStrings.tr('rating_out_of_10', lang);

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
                  color: selected ? activeBg : RC.bg(Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? activeBorder : RC.bg(Color(0xFFE2E8F0)),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected ? activeDot : RC.bg(Color(0xFF94A3B8)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx(label),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCompact ? 11.5 : 12.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? activeText : RC.bg(Color(0xFF64748B)),
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
              Text(
                feeTitle,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
              ),
              const SizedBox(height: 6),
              _buildDialogInput(
                controller: feeCtrl,
                label: '',
                hint: '1500',
                icon: Icons.two_wheeler_rounded,
                numeric: true,
                lang: lang,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: feePresets.map((fee) {
                  final selected = feeCtrl.text.trim() == fee.toString();
                  final chipText = fee == 0 ? '0 (${_t('خۆڕایی')})' : '$fee';
                  return FilterChip(
                    selected: selected,
                    label: Text(
                      chipText,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: fee == 0 && selected ? RC.fg(const Color(0xFF059669)) : null,
                      ),
                    ),
                    selectedColor: fee == 0 ? RC.bg(const Color(0xFFDCFCE7)) : RC.bg(const Color(0xFFFFEDD5)),
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
              Text(
                ratingTitle,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
              ),
              const SizedBox(height: 6),
              _buildDialogInput(
                controller: ratingCtrl,
                label: '',
                hint: '9.6',
                icon: Icons.star_rounded,
                numeric: true,
                lang: lang,
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.tr('rating_example', lang),
                style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade600), fontWeight: FontWeight.w600),
              ),
            ],
          );

          final cancelBtn = OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: RC.fg(Color(0xFF64748B)),
              backgroundColor: RC.bg(Color(0xFFF8FAFC)),
              side: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20, vertical: 13),
              minimumSize: Size(stackFields ? double.infinity : 0, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.tr('cancel', lang),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          );

          final saveBtn = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 24, vertical: 13),
              minimumSize: Size(stackFields ? double.infinity : 0, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(isEdit ? Icons.save_rounded : Icons.add_business_rounded, size: 18),
            label: Text(
              isEdit ? AppStrings.tr('save', lang) : AppStrings.tr('add_vendor', lang),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            onPressed: isSaving ? null : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          final password = passwordCtrl.text.trim();
                          if (!isEdit && password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.tr('vendor_password_required', lang)),
                                backgroundColor: RC.bg(Color(0xFFDC2626)),
                              ),
                            );
                            return;
                          }
                          if (password.isNotEmpty && password.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.tr('customer_password_min', lang)),
                                backgroundColor: RC.bg(Color(0xFFDC2626)),
                              ),
                            );
                            return;
                          }

                          if (selectedCategoryId == null || selectedCategoryId! <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.tr('vendor_category_required', lang)),
                                backgroundColor: RC.bg(Color(0xFFDC2626)),
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
                              SnackBar(
                                content: Text(AppStrings.tr('coords_invalid', lang)),
                                backgroundColor: RC.bg(Color(0xFFDC2626)),
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
                                  content: Text(tx(isEdit
                                      ? AppStrings.tr('vendor_updated', lang)
                                      : AppStrings.tr('vendor_created', lang))),
                                  backgroundColor: RC.bg(Color(0xFF16A34A)),
                                ),
                              );
                            }
                            return;
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tx(e.toString())),
                                  backgroundColor: RC.bg(Color(0xFFDC2626)),
                                ),
                              );
                            }
                            return;
                          }
            },
          );

          return Directionality(
            textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
            child: Dialog(
            backgroundColor: RC.bg(Colors.white),
            surfaceTintColor: Colors.transparent,
            elevation: 16,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 16,
              vertical: isCompact ? 12 : 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
              side: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
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
                              color: RC.bg(Color(0xFFFFF7ED)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: RC.bg(Color(0xFFFFEDD5))),
                            ),
                            child: Icon(
                              isEdit ? Icons.edit_note_rounded : Icons.storefront_rounded,
                              color: RC.fg(Color(0xFFEA580C)),
                              size: isCompact ? 22 : 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.tr(
                                    isEdit ? 'edit_vendor' : 'add_vendor_new',
                                    lang,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: isCompact ? 15.5 : 17.5,
                                    color: AdminSurfaces.of(context).textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppStrings.tr(
                                    isEdit ? 'edit_vendor_hint' : 'add_vendor_hint',
                                    lang,
                                  ),
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
                              child: Icon(Icons.close_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 12 : 16),
                      Divider(height: 1, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
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
                                          color: RC.bg(Color(0xFFF8FAFC)),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                                        ),
                                        child: Icon(Icons.storefront_rounded, color: RC.fg(Color(0xFFEA580C))),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  AppStrings.tr('vendor_cover_image', lang),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569))),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: imagePresets.map((preset) {
                                    final presetUrl = preset['url']?.toString() ?? '';
                                    final presetId = (preset['category_id'] as num?)?.toInt();
                                    final isSelected = (presetId != null && selectedCategoryId == presetId) ||
                                        (presetId == null && imageUrl == presetUrl);
                                    return InkWell(
                                      onTap: () => setDialogState(() {
                                        imageUrl = presetUrl;
                                        if (presetId != null) selectedCategoryId = presetId;
                                      }),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? RC.bg(Color(0xFFFFF7ED)) : RC.bg(Color(0xFFF8FAFC)),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFE2E8F0)),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          tx(preset['name']?.toString() ?? ''),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFF64748B)),
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
                                            color: RC.bg(Color(0xFFF8FAFC)),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                                          ),
                                          child: Icon(Icons.storefront_rounded, color: RC.fg(Color(0xFFEA580C))),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppStrings.tr('vendor_cover_image', lang),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569))),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: imagePresets.map((preset) {
                                              final presetUrl = preset['url']?.toString() ?? '';
                                              final presetId = (preset['category_id'] as num?)?.toInt();
                                              final isSelected = (presetId != null && selectedCategoryId == presetId) ||
                                                  (presetId == null && imageUrl == presetUrl);
                                              return InkWell(
                                                onTap: () => setDialogState(() {
                                                  imageUrl = presetUrl;
                                                  if (presetId != null) selectedCategoryId = presetId;
                                                }),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? RC.bg(Color(0xFFFFF7ED)) : RC.bg(Color(0xFFF8FAFC)),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFE2E8F0)),
                                                      width: isSelected ? 1.5 : 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    tx(preset['name']?.toString() ?? ''),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                      color: isSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFF64748B)),
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
                              const SizedBox(height: 10),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: OutlinedButton.icon(
                                  onPressed: (isSaving || uploadingCover)
                                      ? null
                                      : () async {
                                          final picked = await MediaPickService.pickImageForUpload();
                                          if (picked == null) return;
                                          setDialogState(() => uploadingCover = true);
                                          try {
                                            final up = await widget.api.uploadMedia(picked.bytes, picked.name);
                                            final url = up['url']?.toString();
                                            if (url != null && url.isNotEmpty) {
                                              setDialogState(() => imageUrl = url);
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(tx(AppStrings.tr('item_image_upload_failed', lang))), backgroundColor: RegaColors.crimson),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(tx(e.toString())), backgroundColor: RegaColors.crimson),
                                              );
                                            }
                                          } finally {
                                            setDialogState(() => uploadingCover = false);
                                          }
                                        },
                                  icon: uploadingCover
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.upload_rounded, size: 18),
                                  label: Text(
                                    tx(uploadingCover
                                        ? AppStrings.tr('item_image_uploading', lang)
                                        : AppStrings.tr('item_image_pick', lang)),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Marketplace category — same names as customer home
                              Text(
                                AppStrings.tr('vendor_type_app', lang),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.tr('vendor_type_hint', lang),
                                style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade600), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              if (dialogCategories.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: RC.bg(Color(0xFFFEF3C7)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: RC.bg(Color(0xFFF59E0B))),
                                  ),
                                  child: Text(
                                    AppStrings.tr('no_categories_vendor', lang),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF92400E))),
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: dialogCategories.map((cat) {
                                    final id = (cat['id'] as num?)?.toInt();
                                    final name = _categoryLabel(cat);
                                    final selected = id != null && selectedCategoryId == id;
                                    return FilterChip(
                                      selected: selected,
                                      label: Text(tx(name)),
                                      selectedColor: RC.bg(Color(0xFFFFEDD5)),
                                      checkmarkColor: RC.bg(Color(0xFFEA580C)),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      labelStyle: TextStyle(
                                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                        color: selected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFF64748B)),
                                        fontSize: 12,
                                      ),
                                      side: BorderSide(
                                        color: selected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFE2E8F0)),
                                        width: selected ? 1.5 : 1,
                                      ),
                                      onSelected: id == null
                                          ? null
                                          : (_) => setDialogState(() {
                                                selectedCategoryId = id;
                                                final cover = cat['image_url']?.toString().trim();
                                                if (cover != null && cover.isNotEmpty) {
                                                  imageUrl = cover;
                                                }
                                              }),
                                    );
                                  }).toList(),
                                ),

                              const SizedBox(height: 14),
                              _buildDialogInput(
                                controller: nameCtrl,
                                label: AppStrings.tr('vendor_name_label', lang),
                                hint: AppStrings.tr('vendor_name_hint', lang),
                                icon: Icons.storefront_outlined,
                                lang: lang,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogInput(
                                controller: subtitleCtrl,
                                label: AppStrings.tr('vendor_short_desc', lang),
                                hint: AppStrings.tr('vendor_short_desc_hint', lang),
                                icon: Icons.subtitles_outlined,
                                lang: lang,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogInput(
                                controller: phoneCtrl,
                                label: AppStrings.tr('mobile_label', lang),
                                hint: '0750 000 0000',
                                icon: Icons.phone_outlined,
                                isPhone: true,
                                lang: lang,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogInput(
                                controller: passwordCtrl,
                                label: isEdit
                                    ? AppStrings.tr('password_new_optional', lang)
                                    : '${AppStrings.tr('password_label', lang)} *',
                                hint: isEdit ? '••••••••' : AppStrings.tr('password_min_hint', lang),
                                icon: Icons.lock_outline_rounded,
                                obscureText: true,
                                lang: lang,
                              ),
                              const SizedBox(height: 12),

                              Text(
                                AppStrings.tr('vendor_location_map', lang),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                              ),
                              const SizedBox(height: 6),
                              _buildDialogInput(
                                controller: addressCtrl,
                                label: '',
                                hint: AppStrings.tr('vendor_address_hint', lang),
                                icon: Icons.place_rounded,
                                lang: lang,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: locationPresets.map((p) {
                                  final locName = AppStrings.tr(p['nameKey'] as String, lang);
                                  final selected = latCtrl.text.trim() == (p['lat'] as double).toStringAsFixed(6) &&
                                      lngCtrl.text.trim() == (p['lng'] as double).toStringAsFixed(6);
                                  return FilterChip(
                                    selected: selected,
                                    label: Text(locName, style: const TextStyle(fontSize: 11.5)),
                                    selectedColor: RC.bg(Color(0xFFFFEDD5)),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    onSelected: (_) => setDialogState(() {
                                      addressCtrl.text = locName;
                                      latCtrl.text = (p['lat'] as double).toStringAsFixed(6);
                                      lngCtrl.text = (p['lng'] as double).toStringAsFixed(6);
                                    }),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              if (stackFields) ...[
                                _buildDialogInput(
                                  controller: latCtrl,
                                  label: latLabel,
                                  hint: '34.683600',
                                  icon: Icons.my_location_rounded,
                                  numeric: true,
                                  lang: lang,
                                ),
                                const SizedBox(height: 10),
                                _buildDialogInput(
                                  controller: lngCtrl,
                                  label: lngLabel,
                                  hint: '45.318900',
                                  icon: Icons.explore_rounded,
                                  numeric: true,
                                  lang: lang,
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDialogInput(
                                        controller: latCtrl,
                                        label: latLabel,
                                        hint: '34.683600',
                                        icon: Icons.my_location_rounded,
                                        numeric: true,
                                        lang: lang,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDialogInput(
                                        controller: lngCtrl,
                                        label: lngLabel,
                                        hint: '45.318900',
                                        icon: Icons.explore_rounded,
                                        numeric: true,
                                        lang: lang,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 6),
                              Text(
                                AppStrings.tr('vendor_map_hint', lang),
                                style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade600), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),

                              // Fee + rating: always stack inside narrow dialogs
                              if (stackFields) ...[
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
                              Text(
                                AppStrings.tr('vendor_status_label', lang),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                              ),
                              const SizedBox(height: 6),
                              // Always stack status — long bilingual labels overflow side-by-side.
                              statusChip(
                                selected: status == 'active',
                                activeBg: RC.bg(Color(0xFFDCFCE7)),
                                activeBorder: RC.bg(Color(0xFF16A34A)),
                                activeDot: RC.bg(Color(0xFF16A34A)),
                                activeText: RC.bg(Color(0xFF15803D)),
                                label: activeLabel,
                                onTap: () => setDialogState(() => status = 'active'),
                              ),
                              const SizedBox(height: 8),
                              statusChip(
                                selected: status == 'under_review',
                                activeBg: RC.bg(Color(0xFFFEF3C7)),
                                activeBorder: RC.bg(Color(0xFFD97706)),
                                activeDot: RC.bg(Color(0xFFD97706)),
                                activeText: RC.bg(Color(0xFFB45309)),
                                label: blockedLabel,
                                onTap: () => setDialogState(() => status = 'under_review'),
                              ),

                      SizedBox(height: isCompact ? 12 : 16),
                      Divider(height: 1, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
                      SizedBox(height: isCompact ? 12 : 14),

                      // Footer actions
                      if (stackFields) ...[
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
    String? lang,
  }) {
    final uiLang = lang ?? widget.lang;
    final forceLtr = isPhone || numeric || uiLang == 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            // Labels are already translated via AppStrings.tr — do not re-tx into Kurdish.
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
          ),
          const SizedBox(height: 6),
        ],
        Directionality(
          textDirection: forceLtr ? TextDirection.ltr : TextDirection.rtl,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: isPhone
                ? TextInputType.phone
                : (numeric
                    ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                    : TextInputType.text),
            textAlign: forceLtr ? TextAlign.left : TextAlign.right,
            inputFormatters: isPhone
                ? [IraqPhoneFormatter()]
                : (numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))] : null),
            decoration: InputDecoration(
              hintText: isPhone ? '0750 000 0000' : hint,
              hintStyle: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8))),
              prefixIcon: Icon(icon, size: 20, color: RC.fg(Color(0xFF94A3B8))),
              filled: true,
              fillColor: RC.bg(Color(0xFFF8FAFC)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: RC.bg(Color(0xFFEA580C)), width: 1.8),
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
      barrierColor: RC.bg(Colors.black).withValues(alpha: 0.5),
      builder: (ctx) => Directionality(
        textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: Dialog(
        backgroundColor: RC.bg(Colors.white),
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
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
                                color: RC.bg(Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                              ),
                              child: Icon(Icons.storefront_rounded, color: RC.fg(Color(0xFFEA580C))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx(v.name),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: RC.fg(Color(0xFF0F172A))),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tx(v.subtitle.isNotEmpty ? v.subtitle : v.cuisine),
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
                    Divider(height: 1, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(_t('type_label'), _vendorCuisineLabel(v)),
                          Divider(height: 16, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
                          _buildDetailRow('${_t('city')}:', AppStrings.cityLabel(v.city, _lang)),
                          Divider(height: 16, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
                          _buildDetailRow(_t('address_label'), v.address.isNotEmpty ? v.address : AppStrings.cityLabel(v.city, _lang)),
                          Divider(height: 16, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
                          _buildDetailRow('GPS:', '${v.lat.toStringAsFixed(5)}, ${v.lng.toStringAsFixed(5)}'),
                          Divider(height: 16, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
                          _buildDetailRow('${_t('phone')}:', v.phone),
                          Divider(height: 16, thickness: 1, color: RC.bg(Color(0xFFF1F5F9))),
                          _buildDetailRow('${_t('kpi_today_orders')}:', _d(v.todayOrders)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isNarrow) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(Color(0xFFEA580C)),
                          foregroundColor: RC.fg(Colors.white),
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(_t('edit'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddVendorDialog(existing: v);
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RC.fg(Color(0xFF64748B)),
                          backgroundColor: RC.bg(Color(0xFFF8FAFC)),
                          side: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(_t('close'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: RC.fg(Color(0xFF64748B)),
                                backgroundColor: RC.bg(Color(0xFFF8FAFC)),
                                side: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(_t('close'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RC.bg(Color(0xFFEA580C)),
                                foregroundColor: RC.fg(Colors.white),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(_t('edit'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
            child: Text(tx(label), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: RC.fg(Color(0xFF4B5563)))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              tx(value),
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: RC.fg(Color(0xFF111827))),
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
            backgroundColor: RC.bg(Color(0xFFEA580C)),
            foregroundColor: RC.fg(Colors.white),
            elevation: 0,
            minimumSize: Size(isCompact ? double.infinity : 0, 44),
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            shadowColor: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.3),
          ),
          onPressed: () => _showAddVendorDialog(),
          icon: Icon(Icons.add_rounded, size: 20, color: RC.fg(Colors.white)),
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
  // 2. 4 TOP KPI METRIC SUMMARY CARDS — 2×2 on phone, 4 across on desktop
  // ============================================================================
  Widget _buildKPICardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scroll views can report infinite maxWidth — fall back to viewport.
        final pad = AdminBreakpoints.pagePadH(context);
        final screenW = MediaQuery.sizeOf(context).width;
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : (screenW - pad * 2).clamp(280.0, screenW);

        final gap = width < 400 ? 8.0 : 12.0;
        final cols = width >= AdminBreakpoints.kpiFourCol ? 4 : 2;
        final cardW = (width - gap * (cols - 1)) / cols;
        final compact = cols == 2;

        Widget cell({
          required String title,
          required String value,
          required IconData icon,
          required Color iconBg,
          required Color iconColor,
        }) {
          return SizedBox(
            width: cardW,
            child: _buildKPICard(
              title: title,
              value: value,
              icon: icon,
              iconBg: iconBg,
              iconColor: iconColor,
              compact: compact,
            ),
          );
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            cell(
              title: AppStrings.tr('kpi_total_vendors', widget.lang),
              value: _d(_registeredVendors),
              icon: Icons.groups_rounded,
              iconBg: RC.bg(Color(0xFFDCFCE7)),
              iconColor: RC.fg(Color(0xFF16A34A)),
            ),
            cell(
              title: AppStrings.tr('kpi_active_vendors', widget.lang),
              value: _d(_activeVendors),
              icon: Icons.person_outline_rounded,
              iconBg: RC.bg(Color(0xFFDCFCE7)),
              iconColor: RC.fg(Color(0xFF16A34A)),
            ),
            cell(
              title: AppStrings.tr('kpi_pending_approval', widget.lang),
              value: _d(_pendingApproval),
              icon: Icons.access_time_rounded,
              iconBg: RC.bg(Color(0xFFFEF3C7)),
              iconColor: RC.fg(Color(0xFFD97706)),
            ),
            cell(
              title: AppStrings.tr('kpi_today_orders', widget.lang),
              value: _d(_todayOrders),
              icon: Icons.description_outlined,
              iconBg: RC.bg(Color(0xFFFFEDD5)),
              iconColor: RC.fg(Color(0xFFEA580C)),
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
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tx(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: AdminSurfaces.of(context).textSecondary,
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),
                Text(
                  tx(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 18 : 26,
                    fontWeight: FontWeight.w900,
                    color: AdminSurfaces.of(context).textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: compact ? 32 : 44,
            height: compact ? 32 : 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: compact ? 16 : 22),
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
                  tx(label),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF64748B))),
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
                    c == 'all' ? AppStrings.tr('all_types', widget.lang) : _cuisineLabelForKey(c),
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
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AdminSurfaces.of(context).textPrimary,
          ),
          items: [
            for (var i = 0; i < items.length; i++)
              DropdownMenuItem<String>(
                value: items[i],
                child: Text(tx(labels != null && i < labels.length ? labels[i] : items[i])),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
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
                    child: Icon(Icons.storefront_rounded, size: 22, color: RC.fg(Color(0xFF94A3B8))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx(v.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    if (v.subtitle.isNotEmpty)
                      Text(tx(v.subtitle), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: surfaces.textTertiary)),
                    const SizedBox(height: 4),
                    Text(
                      tx('${_vendorCuisineLabel(v)} • ${AppStrings.cityLabel(v.city, _lang)}'),
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
                child: Text(tx(v.phone), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              Text(
                tx('${_t('today_prefix')} ${_d(v.todayOrders)}'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: RC.fg(Color(0xFFEA580C))),
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
                      child: Icon(Icons.visibility_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showAddVendorDialog(existing: v),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.edit_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
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
            color: RC.bg(Colors.black).withValues(alpha: 0.02),
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
                            children: [
                              Icon(Icons.storefront_outlined, size: 40, color: RC.fg(Color(0xFFCBD5E1))),
                              const SizedBox(height: 10),
                              Text(
                                _t('no_vendors'),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF94A3B8))),
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
              final alignStart = widget.lang == 'en' ? TextAlign.left : TextAlign.right;
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
                            Expanded(flex: 3, child: Text(_t('col_vendor'), textAlign: alignStart, style: _headerStyle)),
                            Expanded(flex: 3, child: Text(_t('cuisine_type'), textAlign: alignStart, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(_t('city'), textAlign: alignStart, style: _headerStyle)),
                            Expanded(flex: 3, child: Text(_t('col_mobile'), textAlign: alignStart, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(_t('kpi_today_orders'), textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(_t('status'), textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(_t('col_action'), textAlign: widget.lang == 'en' ? TextAlign.right : TextAlign.left, style: _headerStyle)),
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
                              children: [
                                Icon(Icons.storefront_outlined, size: 40, color: RC.fg(Color(0xFFCBD5E1))),
                                const SizedBox(height: 10),
                                Text(
                                  _t('no_vendors'),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF94A3B8))),
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
                                            child: Icon(Icons.storefront_rounded, size: 20, color: RC.fg(Color(0xFF94A3B8))),
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
                                              tx(v.name),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: RC.fg(Color(0xFF1E293B)),
                                              ),
                                            ),
                                            if (v.subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                tx(v.subtitle),
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
                                    tx(_vendorCuisineLabel(v)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: alignStart,
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
                                    tx(AppStrings.cityLabel(v.city, _lang)),
                                    textAlign: alignStart,
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
                                    alignment: widget.lang == 'en' ? Alignment.centerLeft : Alignment.centerRight,
                                    child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        tx(v.phone),
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
                                    tx(_d(v.todayOrders)),
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
                                          child: Icon(Icons.visibility_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
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
                                          child: Icon(Icons.edit_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
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
                      AppStrings.trParams('showing_of', _lang, {
                        'shown': _d(pagedList.length),
                        'total': _d(list.length),
                        'unit': _t('nav_stores'),
                      }),
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
        color: isActive ? RC.bg(Color(0xFFDCFCE7)) : RC.bg(Color(0xFFFEF3C7)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        tx(AppStrings.statusLabel(status, _lang)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11.5,
          fontWeight: FontWeight.w800,
          color: isActive ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFD97706)),
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
          color: active ? RC.bg(Color(0xFFEA580C)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            tx('$page'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? RC.bg(Colors.white) : RC.bg(Color(0xFF64748B)),
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
          child: Icon(icon, size: 18, color: RC.fg(Color(0xFF94A3B8))),
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
