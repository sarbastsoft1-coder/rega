import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/services/image_compress_service.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Admin CRUD for in-store menu category chips (ڕووکاری فرۆشگا):
/// select home category + store, primary image + secondary (chip) image.
class StoreMenuCategoriesScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const StoreMenuCategoriesScreen({
    super.key,
    required this.api,
    required this.lang,
  });

  @override
  State<StoreMenuCategoriesScreen> createState() => _StoreMenuCategoriesScreenState();
}

class _StoreMenuCategoriesScreenState extends State<StoreMenuCategoriesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _rows = [];
  List<dynamic> _stores = [];
  List<dynamic> _homeCategories = [];
  int? _storeFilter;
  int? _homeCategoryFilter;
  final _searchCtrl = TextEditingController();

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
        widget.api.getStoreCategories(
          storeId: _storeFilter,
          categoryId: _homeCategoryFilter,
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        ),
        widget.api.getStores(),
        widget.api.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0];
        _stores = results[1];
        _homeCategories = results[2];
      });
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

  Future<({String name, Uint8List bytes})?> _pickCompressedImage() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return null;
    final f = files.first;
    final raw = await f.readAsBytes();
    if (raw.isEmpty) return null;
    return ImageCompressService.compressForUpload(name: f.name, bytes: raw);
  }

  List<dynamic> _storesForHomeCategory(int? homeCategoryId) {
    if (homeCategoryId == null) return _stores;
    return _stores.where((s) {
      final m = s as Map<String, dynamic>;
      return m['category_id'] == homeCategoryId ||
          (m['category'] is Map && (m['category'] as Map)['id'] == homeCategoryId);
    }).toList();
  }

  Future<void> _moveRow(int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _rows.length) return;
    final list = List<Map<String, dynamic>>.from(
      _rows.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final item = list.removeAt(index);
    list.insert(newIndex, item);
    final orderedIds = list.map((c) => c['id'] as int).toList();
    try {
      await widget.api.reorderStoreCategories(orderedIds);
      if (!mounted) return;
      setState(() => _rows = list);
      _showSnack('ڕیزبەندی بەشەکان نوێکرایەوە');
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _confirmDelete(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سڕینەوەی ${row['name_ku']}'),
        content: Text(
          'ئایا دڵنیایت؟ ${(row['products_count'] ?? 0)} بەرهەم لەم بەشەدا هەیە.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.tr('cancel', widget.lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteStoreCategory(row['id'] as int);
                _showSnack('بەشی مێنیو سڕایەوە');
                _load();
              } catch (e) {
                _showSnack(e.toString(), error: true);
              }
            },
            child: Text(AppStrings.tr('delete', widget.lang)),
          ),
        ],
      ),
    );
  }

  void _showDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final kuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final arCtrl = TextEditingController(text: existing?['name_ar']?.toString() ?? '');
    final enCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: existing?['image_url']?.toString() ?? '');
    final secImgCtrl = TextEditingController(text: existing?['secondary_image_url']?.toString() ?? '');
    final orderCtrl = TextEditingController(
      text: (existing?['sort_order'] ?? (_rows.length + 1)).toString(),
    );

    final existingStore = existing?['store'] as Map<String, dynamic>?;
    int? homeCategoryId = existingStore?['category_id'] as int? ??
        (existingStore?['category'] is Map
            ? (existingStore!['category'] as Map)['id'] as int?
            : null) ??
        _homeCategoryFilter;
    int? storeId = existing?['store_id'] as int? ??
        existingStore?['id'] as int? ??
        _storeFilter;

    ({String name, Uint8List bytes})? pendingPrimary;
    ({String name, Uint8List bytes})? pendingSecondary;
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final storeChoices = _storesForHomeCategory(homeCategoryId);
          if (storeId != null &&
              storeChoices.every((s) => (s as Map)['id'] != storeId)) {
            storeId = storeChoices.isNotEmpty
                ? (storeChoices.first as Map)['id'] as int
                : null;
          }

          Widget imageBox({
            required String label,
            required TextEditingController ctrl,
            required ({String name, Uint8List bytes})? pending,
            required VoidCallback onPick,
          }) {
            final preview = ctrl.text.trim();
            final resolved =
                preview.isEmpty ? '' : widget.api.resolveMediaUrl(preview);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.6,
                    child: pending != null
                        ? Image.memory(pending.bytes, fit: BoxFit.cover)
                        : resolved.isNotEmpty
                            ? Image.network(
                                resolved,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _placeholder(label),
                              )
                            : _placeholder(label),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: saving ? null : onPick,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('هەڵبژاردنی وێنە (+compress)'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'یان بەستەری وێنە',
                    hintText: 'https://...',
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            title: Text(isEdit ? 'دەستکاری بەشی مێنیو / چیپ' : 'زیادکردنی بەشی مێنیو (چیپ)'),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ئەم بەشانە لە ڕووکاری فرۆشگا (چیپ بار) و گریدی بابەتەکان دەردەکەون. '
                      'وێنەی سەرەکی بۆ کارتی گەورە، وێنەی دووەم (sec) بۆ ئایکۆنی چیپ.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      initialValue: homeCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'بەشی سەرەکی ئەپ (فلتەر / هەڵبژاردن)',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('هەموو بەشەکان'),
                        ),
                        ..._homeCategories.map((c) {
                          final m = c as Map<String, dynamic>;
                          return DropdownMenuItem<int?>(
                            value: m['id'] as int,
                            child: Text(m['name_ku']?.toString() ?? ''),
                          );
                        }),
                      ],
                      onChanged: (v) => setDialogState(() {
                        homeCategoryId = v;
                        final choices = _storesForHomeCategory(v);
                        if (storeId == null ||
                            choices.every((s) => (s as Map)['id'] != storeId)) {
                          storeId = choices.isNotEmpty
                              ? (choices.first as Map)['id'] as int
                              : null;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: storeId,
                      decoration: const InputDecoration(
                        labelText: 'فرۆشگا *',
                      ),
                      items: storeChoices.map((s) {
                        final m = s as Map<String, dynamic>;
                        return DropdownMenuItem<int?>(
                          value: m['id'] as int,
                          child: Text(m['name_ku']?.toString() ?? ''),
                        );
                      }).toList(),
                      onChanged: isEdit
                          ? (v) => setDialogState(() => storeId = v)
                          : (v) => setDialogState(() => storeId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kuCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ناوی بەش / چیپ (کوردی) *',
                        hintText: 'نموونە: گریل و کەباب',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: arCtrl,
                      decoration: const InputDecoration(labelText: 'ناو (عەرەبی)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: enCtrl,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('name_en_field', widget.lang),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ڕیزبەندی'),
                    ),
                    const SizedBox(height: 16),
                    imageBox(
                      label: 'وێنەی سەرەکی (کارتی بابەت)',
                      ctrl: imgCtrl,
                      pending: pendingPrimary,
                      onPick: () async {
                        final picked = await _pickCompressedImage();
                        if (picked == null) return;
                        setDialogState(() => pendingPrimary = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    imageBox(
                      label: 'وێنەی دووەم / Sec image (ئایکۆنی چیپ)',
                      ctrl: secImgCtrl,
                      pending: pendingSecondary,
                      onPick: () async {
                        final picked = await _pickCompressedImage();
                        if (picked == null) return;
                        setDialogState(() => pendingSecondary = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(AppStrings.tr('cancel', widget.lang)),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (kuCtrl.text.trim().isEmpty) {
                          _showSnack('ناوی بەش پێویستە', error: true);
                          return;
                        }
                        if (storeId == null) {
                          _showSnack('تکایە فرۆشگا هەڵبژێرە', error: true);
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          String? imageUrl =
                              imgCtrl.text.trim().isEmpty ? null : imgCtrl.text.trim();
                          String? secUrl = secImgCtrl.text.trim().isEmpty
                              ? null
                              : secImgCtrl.text.trim();
                          if (pendingPrimary != null) {
                            final up = await widget.api
                                .uploadMedia(pendingPrimary!.bytes, pendingPrimary!.name);
                            imageUrl = up['url']?.toString() ?? imageUrl;
                          }
                          if (pendingSecondary != null) {
                            final up = await widget.api.uploadMedia(
                              pendingSecondary!.bytes,
                              pendingSecondary!.name,
                            );
                            secUrl = up['url']?.toString() ?? secUrl;
                          }
                          final payload = <String, dynamic>{
                            'name_ku': kuCtrl.text.trim(),
                            'name_ar': arCtrl.text.trim().isEmpty
                                ? kuCtrl.text.trim()
                                : arCtrl.text.trim(),
                            'name_en': enCtrl.text.trim().isEmpty
                                ? kuCtrl.text.trim()
                                : enCtrl.text.trim(),
                            'sort_order':
                                int.tryParse(orderCtrl.text.trim()) ?? (_rows.length + 1),
                            if (imageUrl != null) 'image_url': imageUrl,
                            if (secUrl != null) 'secondary_image_url': secUrl,
                          };
                          if (isEdit) {
                            if (storeId != existing['store_id']) {
                              payload['store_id'] = storeId;
                            }
                            await widget.api
                                .updateStoreCategory(existing['id'] as int, payload);
                          } else {
                            await widget.api.addStoreCategory(storeId!, payload);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack(isEdit ? 'بەش نوێکرایەوە ✅' : 'بەشی مێنیو زیادکرا ✅');
                          _load();
                        } catch (e) {
                          setDialogState(() => saving = false);
                          _showSnack(e.toString(), error: true);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(AppStrings.tr('save', widget.lang)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _placeholder(String label) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
    );
  }

  Widget _thumb(String? url) {
    final resolved = url == null || url.isEmpty ? '' : widget.api.resolveMediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: resolved.isEmpty
            ? Container(
                color: const Color(0xFFE2E8F0),
                child: const Icon(Icons.image_outlined, size: 20, color: Colors.black38),
              )
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFE2E8F0),
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = AdminBreakpoints.pagePadH(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;
    final filterW = narrow ? double.infinity : 220.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ڕووکاری فرۆشگا — بەشەکانی مێنیو / چیپ (${_rows.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _showDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('زیادکردنی بەش / چیپ'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ڕووکاری فرۆشگا — بەشەکانی مێنیو / چیپ (${_rows.length})',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('زیادکردنی بەش / چیپ'),
                    ),
                  ],
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: filterW,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(),
                  decoration: const InputDecoration(
                    hintText: 'گەڕان…',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                ),
              ),
              SizedBox(
                width: filterW,
                child: DropdownButtonFormField<int?>(
                  initialValue: _homeCategoryFilter,
                  decoration: const InputDecoration(labelText: 'بەشی سەرەکی ئەپ'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('هەموو')),
                    ..._homeCategories.map((c) {
                      final m = c as Map<String, dynamic>;
                      return DropdownMenuItem<int?>(
                        value: m['id'] as int,
                        child: Text(m['name_ku']?.toString() ?? ''),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _homeCategoryFilter = v;
                      _storeFilter = null;
                    });
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: filterW,
                child: DropdownButtonFormField<int?>(
                  initialValue: _storeFilter,
                  decoration: const InputDecoration(labelText: 'فرۆشگا'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('هەموو فرۆشگاکان')),
                    ..._storesForHomeCategory(_homeCategoryFilter).map((s) {
                      final m = s as Map<String, dynamic>;
                      return DropdownMenuItem<int?>(
                        value: m['id'] as int,
                        child: Text(m['name_ku']?.toString() ?? ''),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _storeFilter = v);
                    _load();
                  },
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : _rows.isEmpty
                      ? const Center(
                          child: Text(
                            'هیچ بەشێکی مێنیو نییە — یەکەم چیپ زیاد بکە',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final row = Map<String, dynamic>.from(_rows[index] as Map);
                            final store = row['store'] as Map<String, dynamic>?;
                            final homeCat = store?['category'] as Map<String, dynamic>?;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    _thumb(row['image_url']?.toString()),
                                    const SizedBox(width: 8),
                                    _thumb(row['secondary_image_url']?.toString()),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row['name_ku']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (homeCat?['name_ku'] != null)
                                                'بەش: ${homeCat!['name_ku']}',
                                              if (store?['name_ku'] != null)
                                                'فرۆشگا: ${store!['name_ku']}',
                                              '${row['products_count'] ?? 0} بەرهەم',
                                              '#${row['sort_order'] ?? index + 1}',
                                            ].join(' • '),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              Chip(
                                                label: const Text('سەرەکی', style: TextStyle(fontSize: 10)),
                                                visualDensity: VisualDensity.compact,
                                                backgroundColor: row['image_url'] != null
                                                    ? RegaColors.gold.withValues(alpha: 0.25)
                                                    : const Color(0xFFF1F5F9),
                                              ),
                                              Chip(
                                                label: const Text('Sec', style: TextStyle(fontSize: 10)),
                                                visualDensity: VisualDensity.compact,
                                                backgroundColor: row['secondary_image_url'] != null
                                                    ? const Color(0xFFFFEDD5)
                                                    : const Color(0xFFF1F5F9),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'بەرەو سەرەوە',
                                      onPressed: index == 0 ? null : () => _moveRow(index, -1),
                                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                                    ),
                                    IconButton(
                                      tooltip: 'بەرەو خوارەوە',
                                      onPressed: index >= _rows.length - 1
                                          ? null
                                          : () => _moveRow(index, 1),
                                      icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                    ),
                                    IconButton(
                                      onPressed: () => _showDialog(existing: row),
                                      icon: const Icon(Icons.edit_outlined, color: RegaColors.blue),
                                    ),
                                    IconButton(
                                      onPressed: () => _confirmDelete(row),
                                      icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
