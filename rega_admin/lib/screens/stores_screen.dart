import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class StoresScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const StoresScreen({super.key, required this.api, required this.lang});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final _searchCtrl = TextEditingController();
  int? _selectedCategoryId;
  bool _loading = true;
  String? _error;
  List<dynamic> _stores = [];
  List<dynamic> _categories = [];
  List<dynamic> _neighborhoods = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getStores(search: _searchCtrl.text.trim(), categoryId: _selectedCategoryId),
        widget.api.getCategories(),
        widget.api.getNeighborhoods(),
      ]);
      if (mounted) {
        setState(() {
          _stores = results[0];
          _categories = results[1];
          _neighborhoods = results[2];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  void _showStoreFormDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameKuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final nameEnCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: existing?['address_ku']?.toString() ?? '');
    final commCtrl = TextEditingController(text: (existing?['commission_rate'] ?? 12).toString());
    final feeCtrl = TextEditingController(text: (existing?['base_delivery_fee'] ?? 1500).toString());
    final badgeCtrl = TextEditingController(text: existing?['discount_badge']?.toString() ?? '');
    final coverCtrl = TextEditingController(text: existing?['cover_url']?.toString() ?? '');
    final ownerNameCtrl = TextEditingController(text: existing?['owner']?['name']?.toString() ?? '');
    final ownerPassCtrl = TextEditingController();

    int? catId = existing?['category_id'] as int? ??
        (_categories.isNotEmpty ? (_categories.first as Map<String, dynamic>)['id'] as int : null);
    int? zoneId = existing?['neighborhood_id'] as int? ??
        (_neighborhoods.isNotEmpty ? (_neighborhoods.first as Map<String, dynamic>)['id'] as int : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'دەستکاریکردنی فرۆشگا' : 'تۆمارکردنی فرۆشگا و هەژماری فرۆشیار'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameKuCtrl,
                    decoration: const InputDecoration(labelText: 'ناوی فرۆشگا (کوردی) *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameEnCtrl,
                    decoration: const InputDecoration(labelText: 'ناوی فرۆشگا (English)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: catId,
                          decoration: const InputDecoration(labelText: 'بەشی سەرەکی *'),
                          items: _categories.map((c) {
                            final m = c as Map<String, dynamic>;
                            return DropdownMenuItem<int>(
                              value: m['id'] as int,
                              child: Text(m['name_ku']?.toString() ?? ''),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(() => catId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: zoneId,
                          decoration: const InputDecoration(labelText: 'گەڕەکی کەلار'),
                          items: _neighborhoods.map((z) {
                            final m = z as Map<String, dynamic>;
                            return DropdownMenuItem<int>(
                              value: m['id'] as int,
                              child: Text(m['name_ku']?.toString() ?? ''),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(() => zoneId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'ژمارەی مۆبایلی فرۆشگا / چوونەژوورەوە *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: commCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'ڕێژەی کۆمیسیۆنی ڕێگا (%)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'کرێی گەیاندنی بنەڕەت (د.ع)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: badgeCtrl,
                          decoration: const InputDecoration(labelText: 'باجی داشکاندن (نمونە: %20 OFF)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'ناونیشانی تەواو لە کەلار *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: coverCtrl,
                    decoration: const InputDecoration(labelText: 'بەستەری وێنەی فرۆشگا (Cover Image URL)'),
                  ),
                  const Divider(height: 24),
                  if (!isEdit) ...[
                    TextField(
                      controller: ownerNameCtrl,
                      decoration: const InputDecoration(labelText: 'ناوی خاوەنی فرۆشگا'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: ownerPassCtrl,
                    decoration: InputDecoration(
                      labelText: isEdit
                          ? 'وشەی نهێنی نوێ بۆ ئەپی فرۆشیار (ئارەزوومەندانە)'
                          : 'وشەی نهێنی چوونەژوورەوەی ئەپی فرۆشیار (بنەڕەت: password123)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
            ElevatedButton(
              onPressed: () async {
                if (nameKuCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || catId == null) {
                  _showSnack('تکایە خانە سەرەکییەکان پڕبکەرەوە', error: true);
                  return;
                }
                final payload = <String, dynamic>{
                  'name_ku': nameKuCtrl.text.trim(),
                  'name_en': nameEnCtrl.text.trim().isEmpty ? nameKuCtrl.text.trim() : nameEnCtrl.text.trim(),
                  'category_id': catId,
                  'neighborhood_id': zoneId,
                  'phone': phoneCtrl.text.trim(),
                  'address_ku': addressCtrl.text.trim().isEmpty ? 'کەلار' : addressCtrl.text.trim(),
                  'commission_rate': double.tryParse(commCtrl.text) ?? 12.0,
                  'base_delivery_fee': int.tryParse(feeCtrl.text) ?? 1500,
                  'discount_badge': badgeCtrl.text.trim().isEmpty ? null : badgeCtrl.text.trim(),
                  if (coverCtrl.text.trim().isNotEmpty) 'cover_url': coverCtrl.text.trim(),
                  if (!isEdit && ownerNameCtrl.text.trim().isNotEmpty) 'owner_name': ownerNameCtrl.text.trim(),
                  if (ownerPassCtrl.text.trim().isNotEmpty) 'owner_password': ownerPassCtrl.text.trim(),
                };
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await widget.api.updateStore(existing['id'] as int, payload);
                    _showSnack('فرۆشگا نوێکرایەوە');
                  } else {
                    await widget.api.createStore(payload);
                    _showSnack('فرۆشگا و هەژماری فرۆشیار بە سەرکەوتوویی دروستکران');
                  }
                  _load();
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: Text(AppStrings.tr('save', widget.lang)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
          child: SectionHeader(
            title: AppStrings.tr('nav_stores', widget.lang),
            subtitle: 'تۆمارکردنی فرۆشگا (Admin-Provisioned)، دیاریکردنی ڕێژەی کۆمیسیۆن و پەسەندکردن',
            trailing: ElevatedButton.icon(
              onPressed: () => _showStoreFormDialog(),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: const Text('تۆمارکردنی فرۆشگای نوێ'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'گەڕان بە ناوی فرۆشگا یان ژمارە...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
                  ),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'فلتەری بەش'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('هەموو بەشەکان')),
                    ..._categories.map((c) {
                      final m = c as Map<String, dynamic>;
                      return DropdownMenuItem<int?>(
                        value: m['id'] as int,
                        child: Text(m['name_ku']?.toString() ?? ''),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedCategoryId = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 430,
                          mainAxisExtent: 285,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _stores.length,
                        itemBuilder: (_, idx) {
                          final s = _stores[idx] as Map<String, dynamic>;
                          final cat = s['category'] as Map<String, dynamic>?;
                          final zone = s['neighborhood'] as Map<String, dynamic>?;
                          final online = s['is_online'] == true;
                          final approved = s['is_approved'] == true;
                          final badge = s['discount_badge']?.toString();

                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 92,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    image: s['cover_url'] != null
                                        ? DecorationImage(
                                            image: NetworkImage(s['cover_url'].toString()),
                                            fit: BoxFit.cover,
                                            colorFilter: ColorFilter.mode(
                                              Colors.black.withValues(alpha: 0.35),
                                              BlendMode.darken,
                                            ),
                                          )
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: RegaColors.gold,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'کۆمیسیۆن ${s['commission_rate']}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (badge != null && badge.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: RegaColors.crimson,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            badge,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    s['name_ku']?.toString() ?? '',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                                  ),
                                                ),
                                                Text(
                                                  '⭐ ${s['rating'] ?? 4.8}',
                                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${cat?['name_ku'] ?? ''} • ${zone?['name_ku'] ?? ''} • 📞 ${s['phone'] ?? ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'فرۆش: ${formatIqd(s['gross_sales'] as num?, lang: widget.lang)}  |  باڵانس: ${formatIqd(s['wallet_balance'] as num?, lang: widget.lang)}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: RegaColors.emeraldDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                FilterChip(
                                                  selected: online,
                                                  selectedColor: RegaColors.emerald.withValues(alpha: 0.2),
                                                  label: Text(online ? 'ئۆنلاین' : 'داخراو', style: const TextStyle(fontSize: 11)),
                                                  onSelected: (_) async {
                                                    await widget.api.toggleStoreField(s['id'] as int, 'is_online');
                                                    _load();
                                                  },
                                                ),
                                                const SizedBox(width: 6),
                                                FilterChip(
                                                  selected: approved,
                                                  selectedColor: RegaColors.gold.withValues(alpha: 0.3),
                                                  label: Text(approved ? 'پەسەندکراو' : 'پەسەندبکە', style: const TextStyle(fontSize: 11)),
                                                  onSelected: (_) async {
                                                    await widget.api.toggleStoreField(s['id'] as int, 'is_approved');
                                                    _load();
                                                  },
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              tooltip: 'دەستکاریکردن',
                                              onPressed: () => _showStoreFormDialog(existing: s),
                                              icon: const Icon(Icons.edit_note_rounded),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

