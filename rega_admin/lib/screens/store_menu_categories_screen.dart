import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/services/media_pick_service.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bulk_delete_bar.dart';
import '../widgets/common_widgets.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
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
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  bool _bulkBusy = false;

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
      // Same home parts as customer app / Add Vendor (active + featured_home).
      final rawCats = results[2] as List<dynamic>;
      final active = rawCats
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((c) => c['is_active'] != false && c['is_active'] != 0)
          .toList();
      final featured = active
          .where((c) => c['is_featured_home'] == true || c['is_featured_home'] == 1)
          .toList();
      final homeCats = (featured.isNotEmpty ? featured : active)
        ..sort((a, b) =>
            ((a['sort_order'] as num?)?.toInt() ?? 0)
                .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
      setState(() {
        _rows = results[0];
        _stores = results[1];
        _homeCategories = homeCats;
        _selectedIds.removeWhere(
          (id) => !_rows.any((r) => (r as Map)['id'] == id),
        );
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
        content: Text(tx(msg)),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  Future<({String name, Uint8List bytes})?> _pickCompressedImage() {
    return MediaPickService.pickImageForUpload();
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

  List<int> get _rowIds => _rows.map((r) => (r as Map)['id']).whereType<int>().toList();

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllRows() {
    setState(() => _selectedIds
      ..clear()
      ..addAll(_rowIds));
  }

  void _toggleRowSelected(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDeleteRows({required bool deleteAll}) async {
    final ids = deleteAll ? _rowIds : _selectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await BulkDeleteActions.confirm(
      context: context,
      lang: widget.lang,
      count: ids.length,
      deleteAll: deleteAll,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    final result = await BulkDeleteActions.run(
      ids: ids,
      deleteOne: widget.api.deleteStoreCategory,
    );
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectionMode = false;
      _selectedIds.clear();
    });
    _showSnack(
      BulkDeleteActions.resultMessage(widget.lang, result),
      error: result.failed > 0 && result.ok == 0,
    );
    await _load();
  }

  void _confirmDelete(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        title: Text(
          tx('سڕینەوەی ${row['name_ku']}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 420),
            maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 260),
          ),
          child: SingleChildScrollView(
            child: Text(
              tx('ئایا دڵنیایت؟ ${(row['products_count'] ?? 0)} بەرهەم لەم بەشەدا هەیە.'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.tr('cancel', widget.lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.crimson,
              foregroundColor: Colors.white,
            ),
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
                Text(tx(label), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
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
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: saving ? null : onPick,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(
                    tx('هەڵبژاردنی وێنە (+compress)'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: tx('یان بەستەری وێنە'),
                    hintText: tx('https://...'),
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
            actionsOverflowButtonSpacing: 8,
            title: Text(
              tx(isEdit ? 'دەستکاری بەشی مێنیو / چیپ' : 'زیادکردنی بەشی مێنیو (چیپ)'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 520),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 580),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tx('ئەم بەشانە لە ڕووکاری فرۆشگا (چیپ بار) و گریدی بابەتەکان دەردەکەون. '
                        'وێنەی سەرەکی بۆ کارتی گەورە، وێنەی دووەم (sec) بۆ ئایکۆنی چیپ.'),
                        style: TextStyle(fontSize: 12, color: RC.fg(Colors.black54)),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: homeCategoryId,
                        decoration: InputDecoration(
                          labelText: tx('بەشی سەرەکی ئەپ (فلتەر / هەڵبژاردن)'),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              tx('هەموو بەشەکان'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._homeCategories.map((c) {
                            final m = c as Map<String, dynamic>;
                            return DropdownMenuItem<int?>(
                              value: m['id'] as int,
                              child: Text(
                                tx(m['name_ku']?.toString() ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                        isExpanded: true,
                        initialValue: storeId,
                        decoration: InputDecoration(
                          labelText: tx('فرۆشگا *'),
                        ),
                        items: storeChoices.map((s) {
                          final m = s as Map<String, dynamic>;
                          return DropdownMenuItem<int?>(
                            value: m['id'] as int,
                            child: Text(
                              tx(m['name_ku']?.toString() ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: isEdit
                            ? (v) => setDialogState(() => storeId = v)
                            : (v) => setDialogState(() => storeId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: kuCtrl,
                        decoration: InputDecoration(
                          labelText: tx('ناوی بەش / چیپ (کوردی) *'),
                          hintText: tx('نموونە: گریل و کەباب'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: arCtrl,
                        decoration: InputDecoration(labelText: tx('ناو (عەرەبی)')),
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
                        decoration: InputDecoration(labelText: tx('ڕیزبەندی')),
                      ),
                      const SizedBox(height: 16),
                      imageBox(
                        label: tx('وێنەی سەرەکی (کارتی بابەت)'),
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
                        label: tx('وێنەی دووەم / Sec image (ئایکۆنی چیپ)'),
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
                    ? SizedBox(
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
      color: RC.bg(Color(0xFFF1F5F9)),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: Text(
        tx(label),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: RC.fg(Colors.black45), fontWeight: FontWeight.w700),
      ),
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
                color: RC.bg(Color(0xFFE2E8F0)),
                child: Icon(Icons.image_outlined, size: 20, color: RC.fg(Colors.black38)),
              )
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: RC.bg(Color(0xFFE2E8F0)),
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = AdminBreakpoints.pagePadH(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final narrow = w < AdminBreakpoints.phone;
        final compactCard = w < 580;
        final availW = (w - pad * 2) > 200 ? (w - pad * 2) : 200.0;
        final filterW = narrow ? availW : (availW < 220.0 ? availW : 220.0);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tx('ڕووکاری فرۆشگا — بەشەکانی مێنیو / چیپ (${_rows.length})'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: narrow ? 15 : 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    BulkDeleteBar(
                      lang: widget.lang,
                      selectionMode: _selectionMode,
                      selectedCount: _selectedIds.length,
                      totalCount: _rows.length,
                      busy: _bulkBusy,
                      onToggleSelectionMode: _toggleSelectionMode,
                      onSelectAll: _selectAllRows,
                      onClearSelection: _clearSelection,
                      onDeleteSelected: () => _bulkDeleteRows(deleteAll: false),
                      onDeleteAll: () => _bulkDeleteRows(deleteAll: true),
                      extraActions: [
                        ElevatedButton.icon(
                          onPressed: _bulkBusy ? null : () => _showDialog(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(tx('زیادکردنی بەش / چیپ')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
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
                        decoration: InputDecoration(
                          hintText: tx('گەڕان…'),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: filterW,
                      child: DropdownButtonFormField<int?>(
                        initialValue: _homeCategoryFilter,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: tx('بەشی سەرەکی ئەپ')),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(tx('هەموو'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          ..._homeCategories.map((c) {
                            final m = c as Map<String, dynamic>;
                            return DropdownMenuItem<int?>(
                              value: m['id'] as int,
                              child: Text(
                                tx(m['name_ku']?.toString() ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                        isExpanded: true,
                        decoration: InputDecoration(labelText: tx('فرۆشگا')),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(tx('هەموو فرۆشگاکان'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          ..._storesForHomeCategory(_homeCategoryFilter).map((s) {
                            final m = s as Map<String, dynamic>;
                            return DropdownMenuItem<int?>(
                              value: m['id'] as int,
                              child: Text(
                                tx(m['name_ku']?.toString() ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(pad),
                    child: ErrorRetryView(message: _error!, onRetry: _load),
                  ),
                ),
              )
            else if (_rows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Text(
                      tx('هیچ بەشێکی مێنیو نییە — یەکەم چیپ زیاد بکە'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, color: RC.fg(Colors.black54)),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                sliver: SliverList.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final row = Map<String, dynamic>.from(_rows[index] as Map);
                    final rowId = row['id'] as int?;
                    final selected = rowId != null && _selectedIds.contains(rowId);
                    final store = row['store'] as Map<String, dynamic>?;
                    final homeCat = store?['category'] as Map<String, dynamic>?;

                    final thumbsAndInfo = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectionMode && rowId != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: BulkSelectBadge(
                              selected: selected,
                              onChanged: (_) => _toggleRowSelected(rowId),
                            ),
                          ),
                        _thumb(row['image_url']?.toString()),
                        const SizedBox(width: 8),
                        _thumb(row['secondary_image_url']?.toString()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx(row['name_ku']?.toString() ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tx([
                                  if (homeCat?['name_ku'] != null)
                                    'بەش: ${homeCat!['name_ku']}',
                                  if (store?['name_ku'] != null)
                                    'فرۆشگا: ${store!['name_ku']}',
                                  '${row['products_count'] ?? 0} بەرهەم',
                                  '#${row['sort_order'] ?? index + 1}',
                                ].join(' • ')),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: RC.fg(Color(0xFF64748B)),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    label: Text(tx('سەرەکی'), style: const TextStyle(fontSize: 10)),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: row['image_url'] != null
                                        ? RegaColors.gold.withValues(alpha: 0.25)
                                        : RC.bg(Color(0xFFF1F5F9)),
                                  ),
                                  Chip(
                                    label: Text(tx('Sec'), style: const TextStyle(fontSize: 10)),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: row['secondary_image_url'] != null
                                        ? RC.bg(Color(0xFFFFEDD5))
                                        : RC.bg(Color(0xFFF1F5F9)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final actionButtons = Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: tx('بەرەو سەرەوە'),
                          onPressed: index == 0 ? null : () => _moveRow(index, -1),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                        ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: tx('بەرەو خوارەوە'),
                          onPressed: index >= _rows.length - 1
                              ? null
                              : () => _moveRow(index, 1),
                          icon: const Icon(Icons.arrow_downward_rounded, size: 19),
                        ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showDialog(existing: row),
                          icon: const Icon(Icons.edit_outlined, size: 19, color: RegaColors.blue),
                        ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmDelete(row),
                          icon: const Icon(Icons.delete_outline, size: 19, color: RegaColors.crimson),
                        ),
                      ],
                    );

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: selected
                            ? const BorderSide(color: RegaColors.orange, width: 2)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: _selectionMode && rowId != null
                            ? () => _toggleRowSelected(rowId)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: compactCard
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  thumbsAndInfo,
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: actionButtons,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: thumbsAndInfo),
                                  const SizedBox(width: 8),
                                  actionButtons,
                                ],
                              ),
                      ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
