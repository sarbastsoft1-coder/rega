import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CatalogZonesScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const CatalogZonesScreen({super.key, required this.api, required this.lang});

  @override
  State<CatalogZonesScreen> createState() => _CatalogZonesScreenState();
}

class _CatalogZonesScreenState extends State<CatalogZonesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  List<dynamic> _zones = [];
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getNeighborhoods(),
        widget.api.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _zones = results[0];
          _categories = results[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showZoneDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final kuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final enCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final feeCtrl = TextEditingController(text: (existing?['delivery_fee'] ?? 1500).toString());
    final minCtrl = TextEditingController(text: (existing?['estimated_minutes'] ?? 25).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'دەستکاریکردنی گەڕەک' : 'زیادکردنی گەڕەکی نوێ لە کەلار'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: kuCtrl, decoration: const InputDecoration(labelText: 'ناوی گەڕەک (کوردی) *')),
              const SizedBox(height: 12),
              TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'ناوی گەڕەک (English)')),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'کرێی گەیاندن بە دینار (د.ع) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'کاتی خەمڵێنراوی گەیاندن (خولەک)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            onPressed: () async {
              if (kuCtrl.text.trim().isEmpty) return;
              final payload = {
                'name_ku': kuCtrl.text.trim(),
                'name_en': enCtrl.text.trim().isEmpty ? kuCtrl.text.trim() : enCtrl.text.trim(),
                'delivery_fee': int.tryParse(feeCtrl.text) ?? 1500,
                'estimated_minutes': int.tryParse(minCtrl.text) ?? 25,
              };
              Navigator.pop(ctx);
              if (isEdit) {
                await widget.api.updateNeighborhood(existing['id'] as int, payload);
              } else {
                await widget.api.createNeighborhood(payload);
              }
              _load();
            },
            child: Text(AppStrings.tr('save', widget.lang)),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final kuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final enCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: existing?['image_url']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'دەستکاریکردنی بەش' : 'زیادکردنی بەشی نوێی بازاڕ'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: kuCtrl, decoration: const InputDecoration(labelText: 'ناوی بەش (کوردی) *')),
              const SizedBox(height: 12),
              TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'ناوی بەش (English)')),
              const SizedBox(height: 12),
              TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: 'بەستەری وێنە (Image URL)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            onPressed: () async {
              if (kuCtrl.text.trim().isEmpty) return;
              final payload = {
                'name_ku': kuCtrl.text.trim(),
                'name_en': enCtrl.text.trim().isEmpty ? kuCtrl.text.trim() : enCtrl.text.trim(),
                if (imgCtrl.text.trim().isNotEmpty) 'image_url': imgCtrl.text.trim(),
              };
              Navigator.pop(ctx);
              if (isEdit) {
                await widget.api.updateCategory(existing['id'] as int, payload);
              } else {
                await widget.api.createCategory(payload);
              }
              _load();
            },
            child: Text(AppStrings.tr('save', widget.lang)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteZone(Map<String, dynamic> z) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سڕینەوەی گەڕەکی ${z['name_ku']}'),
        content: const Text('ئایا دڵنیایت لە سڕینەوەی ئەم گەڕەکە؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteNeighborhood(z['id'] as int);
                _load();
              } catch (_) {}
            },
            child: const Text('سڕینەوە'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سڕینەوەی بەشی ${c['name_ku']}'),
        content: const Text('ئایا دڵنیایت لە سڕینەوەی ئەم بەشە؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteCategory(c['id'] as int);
                _load();
              } catch (_) {}
            },
            child: const Text('سڕینەوە'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: SectionHeader(
            title: AppStrings.tr('nav_zones', widget.lang),
            subtitle: 'ڕێکخستنی گەڕەکەکانی کەلار و کرێی گەیاندن + بەشە سەرەکییەکانی ئەپی کڕیار',
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: '📍 گەڕەکەکانی کەلار (${_zones.length})'),
            Tab(text: '🗂️ بەشەکانی بازاڕ (${_categories.length})'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // Zones Tab
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ElevatedButton.icon(
                                onPressed: () => _showZoneDialog(),
                                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                                label: const Text('زیادکردنی گەڕەکی نوێ'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._zones.map((raw) {
                              final z = raw as Map<String, dynamic>;
                              final active = z['is_active'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: RegaColors.gold.withValues(alpha: 0.22),
                                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF0F172A)),
                                    ),
                                    title: Text(
                                      '${z['name_ku'] ?? ''} (${z['name_en'] ?? ''})',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: Text(
                                      '⏱️ ${z['estimated_minutes'] ?? 25} خولەک  •  🏪 ${z['stores_count'] ?? 0} فرۆشگا  •  📦 ${z['orders_count'] ?? 0} داواکاری',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: RegaColors.emerald.withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            formatIqd(z['delivery_fee'] as num?, lang: widget.lang),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: RegaColors.emeraldDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Switch(
                                          value: active,
                                          onChanged: (v) async {
                                            await widget.api.updateNeighborhood(z['id'] as int, {'is_active': v});
                                            _load();
                                          },
                                        ),
                                        IconButton(
                                          onPressed: () => _showZoneDialog(existing: z),
                                          icon: const Icon(Icons.edit_outlined, color: RegaColors.blue),
                                        ),
                                        IconButton(
                                          onPressed: () => _confirmDeleteZone(z),
                                          icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                        // Categories Tab
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ElevatedButton.icon(
                                onPressed: () => _showCategoryDialog(),
                                icon: const Icon(Icons.add_box_rounded, size: 18),
                                label: const Text('زیادکردنی بەشی نوێ'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._categories.map((raw) {
                              final c = raw as Map<String, dynamic>;
                              final active = c['is_active'] == true;
                              final featured = c['is_featured_home'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: c['image_url'] != null
                                            ? Image.network(
                                                c['image_url'].toString(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => const Icon(Icons.category_rounded),
                                              )
                                            : const Icon(Icons.category_rounded),
                                      ),
                                    ),
                                    title: Text(
                                      '${c['name_ku'] ?? ''} (${c['name_en'] ?? ''})',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: Text('🏪 ${c['stores_count'] ?? 0} فرۆشگا تۆمارکراوە'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FilterChip(
                                          selected: featured,
                                          selectedColor: RegaColors.gold.withValues(alpha: 0.3),
                                          label: const Text('لە سەرەکی دەرکەوێت'),
                                          onSelected: (v) async {
                                            await widget.api.updateCategory(c['id'] as int, {'is_featured_home': v});
                                            _load();
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Switch(
                                          value: active,
                                          onChanged: (v) async {
                                            await widget.api.updateCategory(c['id'] as int, {'is_active': v});
                                            _load();
                                          },
                                        ),
                                        IconButton(
                                          onPressed: () => _showCategoryDialog(existing: c),
                                          icon: const Icon(Icons.edit_outlined, color: RegaColors.blue),
                                        ),
                                        IconButton(
                                          onPressed: () => _confirmDeleteCategory(c),
                                          icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                        ),
                                      ],
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
      ],
    );
  }
}

