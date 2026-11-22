import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/services/media_pick_service.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
enum CatalogZonesMode { both, zones, categories }

class CatalogZonesScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final CatalogZonesMode mode;
  final int initialTab;

  const CatalogZonesScreen({
    super.key,
    required this.api,
    required this.lang,
    this.mode = CatalogZonesMode.both,
    this.initialTab = 0,
  });

  @override
  State<CatalogZonesScreen> createState() => _CatalogZonesScreenState();
}

class _CatalogZonesScreenState extends State<CatalogZonesScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  bool _loading = true;
  String? _error;
  List<dynamic> _zones = [];
  List<dynamic> _categories = [];

  bool get _showZones =>
      widget.mode == CatalogZonesMode.both || widget.mode == CatalogZonesMode.zones;

  bool get _showCategories =>
      widget.mode == CatalogZonesMode.both || widget.mode == CatalogZonesMode.categories;

  bool get _hasTabs => _showZones && _showCategories;

  @override
  void initState() {
    super.initState();
    if (_hasTabs) {
      _tabCtrl = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialTab.clamp(0, 1),
      );
    }
    _load();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = <Future>[];
      if (_showZones) futures.add(widget.api.getNeighborhoods());
      if (_showCategories) futures.add(widget.api.getCategories());
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        var i = 0;
        if (_showZones) _zones = results[i++] as List<dynamic>;
        if (_showCategories) _categories = results[i++] as List<dynamic>;
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

  void _showZoneDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final kuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final enCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final feeCtrl = TextEditingController(text: (existing?['delivery_fee'] ?? 1500).toString());
    final minCtrl = TextEditingController(text: (existing?['estimated_minutes'] ?? 25).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        title: Text(
          tx(isEdit ? 'دەستکاریکردنی گەڕەک' : 'زیادکردنی گەڕەکی نوێ لە کەلار'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: AdminBreakpoints.dialogWidth(ctx, max: 420),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 480),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: kuCtrl, decoration: InputDecoration(labelText: tx('ناوی گەڕەک (کوردی) *'))),
                  const SizedBox(height: 12),
                  TextField(controller: enCtrl, decoration: InputDecoration(labelText: AppStrings.tr('name_en_field', widget.lang))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tx('نرخی گەیاندنی ماتۆرسوار (د.ع) *')),
                  ),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (ctx2, setChipState) {
                      const presets = [1000, 1500, 2000, 2500, 3000];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presets.map((p) {
                          final selected = feeCtrl.text.trim() == p.toString();
                          return ChoiceChip(
                            label: Text(tx('$p')),
                            selected: selected,
                            onSelected: (_) {
                              feeCtrl.text = p.toString();
                              setChipState(() {});
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tx('کاتی خەمڵێنراوی گەیاندن (خولەک)')),
                  ),
                ],
              ),
            ),
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

  Future<({String name, Uint8List bytes})?> _pickCategoryImage() async {
    final picked = await MediaPickService.pickImageForUpload();
    if (picked == null) return null;
    if (picked.bytes.isEmpty) {
      throw Exception('نەتوانرا وێنە بخوێنرێتەوە. تکایە دووبارە هەوڵ بدەوە.');
    }
    return picked;
  }

  Future<void> _moveCategory(int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _categories.length) return;
    final list = List<Map<String, dynamic>>.from(
      _categories.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final item = list.removeAt(index);
    list.insert(newIndex, item);
    final orderedIds = list.map((c) => c['id'] as int).toList();
    try {
      final updated = await widget.api.reorderCategories(orderedIds);
      if (!mounted) return;
      setState(() => _categories = updated);
      _showSnack('ڕیزبەندی بەشەکان نوێکرایەوە');
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _showCategoryDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final kuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final arCtrl = TextEditingController(text: existing?['name_ar']?.toString() ?? '');
    final enCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: existing?['image_url']?.toString() ?? '');
    final secImgCtrl = TextEditingController(text: existing?['secondary_image_url']?.toString() ?? '');
    final orderCtrl = TextEditingController(
      text: (existing?['sort_order'] ?? (_categories.length + 1)).toString(),
    );
    bool featured = existing == null ? true : existing['is_featured_home'] == true;
    bool active = existing == null ? true : existing['is_active'] == true;
    ({String name, Uint8List bytes})? pendingImage;
    ({String name, Uint8List bytes})? pendingSecImage;
    var pickingPrimary = false;
    var uploadingPrimary = false;
    var pickingSecondary = false;
    var uploadingSecondary = false;
    String? primaryUploadError;
    String? secondaryUploadError;
    var primaryUploadOk = false;
    var secondaryUploadOk = false;
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickCompressAndUpload({required bool secondary}) async {
            final busyPrimary = pickingPrimary || uploadingPrimary;
            final busySecondary = pickingSecondary || uploadingSecondary;
            if (saving || busyPrimary || busySecondary) return;
            setDialogState(() {
              if (secondary) {
                pickingSecondary = true;
                secondaryUploadError = null;
                secondaryUploadOk = false;
              } else {
                pickingPrimary = true;
                primaryUploadError = null;
                primaryUploadOk = false;
              }
            });
            try {
              final picked = await _pickCategoryImage();
              if (picked == null || !ctx.mounted) {
                setDialogState(() {
                  if (secondary) {
                    pickingSecondary = false;
                  } else {
                    pickingPrimary = false;
                  }
                });
                return;
              }
              setDialogState(() {
                if (secondary) {
                  pendingSecImage = picked;
                  pickingSecondary = false;
                  uploadingSecondary = true;
                } else {
                  pendingImage = picked;
                  pickingPrimary = false;
                  uploadingPrimary = true;
                }
              });
              final up = await widget.api.uploadMedia(picked.bytes, picked.name);
              final url = up['url']?.toString();
              if (url == null || url.isEmpty) {
                throw Exception(AppStrings.tr('item_image_upload_failed', widget.lang));
              }
              if (!ctx.mounted) return;
              if (secondary) {
                secImgCtrl.text = url;
              } else {
                imgCtrl.text = url;
              }
              setDialogState(() {
                if (secondary) {
                  uploadingSecondary = false;
                  secondaryUploadOk = true;
                  secondaryUploadError = null;
                } else {
                  uploadingPrimary = false;
                  primaryUploadOk = true;
                  primaryUploadError = null;
                }
              });
            } catch (e) {
              if (!ctx.mounted) return;
              setDialogState(() {
                if (secondary) {
                  pickingSecondary = false;
                  uploadingSecondary = false;
                  secondaryUploadOk = false;
                  secondaryUploadError = e.toString();
                } else {
                  pickingPrimary = false;
                  uploadingPrimary = false;
                  primaryUploadOk = false;
                  primaryUploadError = e.toString();
                }
              });
              _showSnack(
                '${AppStrings.tr('item_image_upload_failed', widget.lang)}: $e',
                error: true,
              );
            }
          }

          Widget imageUploadBlock({
            required String title,
            required TextEditingController ctrl,
            required ({String name, Uint8List bytes})? pending,
            required bool picking,
            required bool uploading,
            required bool uploadOk,
            required String? uploadError,
            required bool secondary,
            required String urlLabel,
          }) {
            final previewUrl = ctrl.text.trim();
            final resolved =
                previewUrl.isEmpty ? '' : widget.api.resolveMediaUrl(previewUrl);
            final busy = picking || uploading;
            final hasPreview = pending != null || resolved.isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tx(title), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (saving || busy) ? null : () => pickCompressAndUpload(secondary: secondary),
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: uploadError != null
                              ? RegaColors.crimson
                              : (uploadOk || hasPreview)
                                  ? RegaColors.orange
                                  : RC.bg(Color(0xFFE2E8F0)),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: AspectRatio(
                          aspectRatio: 1.35,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (pending != null)
                                Image.memory(
                                  pending.bytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _imagePlaceholder(),
                                )
                              else if (resolved.isNotEmpty)
                                Image.network(
                                  resolved,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _imagePlaceholder(),
                                )
                              else
                                _imagePlaceholder(),
                              if (!hasPreview)
                                Container(
                                  color: RC.bg(Color(0xAA0F172A)),
                                  padding: const EdgeInsets.all(12),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_rounded,
                                        color: RC.fg(Colors.white),
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppStrings.tr('item_image_tap_hint', widget.lang),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: RC.fg(Colors.white),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (busy)
                                Container(
                                  color: RC.bg(Color(0x880F172A)),
                                  padding: const EdgeInsets.all(12),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: RC.bg(Colors.white)),
                                      const SizedBox(height: 10),
                                      Text(
                                        tx(picking
                                            ? AppStrings.tr('item_image_compressing', widget.lang)
                                            : AppStrings.tr('item_image_uploading', widget.lang)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: RC.fg(Colors.white),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (saving || busy) ? null : () => pickCompressAndUpload(secondary: secondary),
                    style: FilledButton.styleFrom(
                      backgroundColor: RegaColors.orange,
                      foregroundColor: RC.fg(Colors.white),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    icon: busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: RC.bg(Colors.white)),
                          )
                        : Icon(
                            hasPreview ? Icons.sync_rounded : Icons.cloud_upload_rounded,
                            size: 18,
                          ),
                    label: Text(
                      tx(busy
                          ? (picking
                              ? AppStrings.tr('item_image_compressing', widget.lang)
                              : AppStrings.tr('item_image_uploading', widget.lang))
                          : (hasPreview
                              ? AppStrings.tr('item_image_change', widget.lang)
                              : AppStrings.tr('item_image_pick', widget.lang))),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (uploadOk) ...[
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.tr('item_image_upload_ok', widget.lang),
                    style: const TextStyle(
                      color: RegaColors.emeraldDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (uploadError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    tx(uploadError),
                    style: const TextStyle(
                      color: RegaColors.crimson,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Theme(
                  data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      tx(urlLabel),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    children: [
                      TextField(
                        controller: ctrl,
                        enabled: !saving && !busy,
                        onChanged: (_) => setDialogState(() {
                          if (secondary) {
                            secondaryUploadOk = false;
                          } else {
                            primaryUploadOk = false;
                          }
                        }),
                        decoration: InputDecoration(
                          hintText: tx('https://...'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final imageBusy = pickingPrimary ||
              uploadingPrimary ||
              pickingSecondary ||
              uploadingSecondary;

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
            actionsOverflowButtonSpacing: 8,
            title: Text(
              tx(isEdit ? 'دەستکاریکردنی بەشی سەرەکی' : 'زیادکردنی بەشی نوێ بۆ ئەپی کڕیار'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 460),
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
                        tx('وێنەی سەرەکی بۆ گریدی سەرەکی؛ وێنەی دووەم (sec) بۆ چیپ/ئایکۆن.'),
                        style: TextStyle(fontSize: 12, color: RC.fg(Colors.black54)),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: kuCtrl,
                        enabled: !saving,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('section_name_ku', widget.lang),
                          hintText: AppStrings.tr('section_name_ku_hint', widget.lang),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: arCtrl,
                        enabled: !saving,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('section_name_ar', widget.lang),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: enCtrl,
                        enabled: !saving,
                        decoration: InputDecoration(labelText: AppStrings.tr('name_en_field', widget.lang)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: orderCtrl,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tx('ڕیزبەندی (sort_order)'),
                          hintText: tx('1 = یەکەم خانە لە گرید'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      imageUploadBlock(
                        title: tx('وێنەی سەرەکی (گرید)'),
                        ctrl: imgCtrl,
                        pending: pendingImage,
                        picking: pickingPrimary,
                        uploading: uploadingPrimary,
                        uploadOk: primaryUploadOk,
                        uploadError: primaryUploadError,
                        secondary: false,
                        urlLabel: 'یان بەستەری وێنەی سەرەکی',
                      ),
                      const SizedBox(height: 16),
                      imageUploadBlock(
                        title: tx('وێنەی دووەم / Sec image (چیپ)'),
                        ctrl: secImgCtrl,
                        pending: pendingSecImage,
                        picking: pickingSecondary,
                        uploading: uploadingSecondary,
                        uploadOk: secondaryUploadOk,
                        uploadError: secondaryUploadError,
                        secondary: true,
                        urlLabel: 'یان بەستەری وێنەی دووەم (secondary_image_url)',
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          tx('لە شاشەی سەرەکی ئەپی کڕیار دەرکەوێت'),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        value: featured,
                        activeThumbColor: RegaColors.goldDark,
                        onChanged: saving ? null : (v) => setDialogState(() => featured = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tx('بەش چالاکە'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        value: active,
                        onChanged: saving ? null : (v) => setDialogState(() => active = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: (saving || imageBusy) ? null : () => Navigator.pop(ctx),
                child: Text(AppStrings.tr('cancel', widget.lang)),
              ),
              ElevatedButton(
                onPressed: (saving || imageBusy)
                    ? null
                    : () async {
                        if (kuCtrl.text.trim().isEmpty) {
                          _showSnack('تکایە ناوی بەش بنووسە', error: true);
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          final imageUrl =
                              imgCtrl.text.trim().isEmpty ? null : imgCtrl.text.trim();
                          final secUrl =
                              secImgCtrl.text.trim().isEmpty ? null : secImgCtrl.text.trim();
                          // Upload already happened on pick (same as products_screen).
                          final payload = <String, dynamic>{
                            'name_ku': kuCtrl.text.trim(),
                            'name_en': enCtrl.text.trim().isEmpty ? kuCtrl.text.trim() : enCtrl.text.trim(),
                            'name_ar': arCtrl.text.trim().isEmpty ? kuCtrl.text.trim() : arCtrl.text.trim(),
                            'is_featured_home': featured,
                            'is_active': active,
                            'sort_order': int.tryParse(orderCtrl.text.trim()) ?? (_categories.length + 1),
                            if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
                            if (secUrl != null && secUrl.isNotEmpty) 'secondary_image_url': secUrl,
                          };
                          if (isEdit) {
                            await widget.api.updateCategory(existing['id'] as int, payload);
                          } else {
                            await widget.api.createCategory(payload);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack(
                            isEdit
                                ? 'بەش نوێکرایەوە ✅'
                                : 'بەشی نوێ زیادکرا و لە ئەپی کڕیار دەردەکەوێت ✅',
                          );
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: RC.bg(Colors.white)),
                      )
                    : Text(AppStrings.tr('save', widget.lang)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: RC.bg(Color(0xFFF1F5F9)),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 36, color: RC.fg(Colors.black38)),
          const SizedBox(height: 6),
          Text(
            tx('وێنەی بەش'),
            textAlign: TextAlign.center,
            style: TextStyle(color: RC.fg(Colors.black45), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteZone(Map<String, dynamic> z) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        title: Text(
          tx('سڕینەوەی گەڕەکی ${z['name_ku']}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 420),
            maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 280),
          ),
          child: SingleChildScrollView(
            child: Text(tx('ئایا دڵنیایت لە سڕینەوەی ئەم گەڕەکە؟')),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson, foregroundColor: RC.fg(Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteNeighborhood(z['id'] as int);
                _load();
              } catch (_) {}
            },
            child: Text(tx('سڕینەوە')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Map<String, dynamic> c) {
    final storesCount = (c['stores_count'] as num?)?.toInt() ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        title: Text(
          tx('سڕینەوەی بەشی ${c['name_ku']}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 420),
            maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 280),
          ),
          child: SingleChildScrollView(
            child: Text(
              tx(storesCount > 0
                  ? 'ئەم بەشە $storesCount فرۆشگای لەسەرە — ناتوانرێت بسڕدرێتەوە هەتا فرۆشگاکان بگۆڕدرێن. دەتوانیت چالاکی بکەیتەوە یان لە سەرەکی لاببەیت.'
                  : 'ئایا دڵنیایت لە سڕینەوەی ئەم بەشە؟ لە گریدی سەرەکی ئەپی کڕیار دەسڕێتەوە.'),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          if (storesCount == 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson, foregroundColor: RC.fg(Colors.white)),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.api.deleteCategory(c['id'] as int);
                  _load();
                  _showSnack('بەش سڕایەوە');
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: Text(tx('سڕینەوە')),
            )
          else
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.api.updateCategory(c['id'] as int, {
                    'is_active': false,
                    'is_featured_home': false,
                  });
                  _load();
                  _showSnack('بەش ناچالاک کرا و لە سەرەکی لابرا');
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: Text(tx('ناچالاککردن')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = switch (widget.mode) {
      CatalogZonesMode.categories => 'بەشەکانی سەرەکی ئەپی کڕیار',
      CatalogZonesMode.zones => 'گەڕەکەکانی کەلار',
      CatalogZonesMode.both => AppStrings.tr('nav_zones', widget.lang),
    };
    final headerSubtitle = switch (widget.mode) {
      CatalogZonesMode.categories => 'ناو و وێنەی بەش زیاد بکە — ڕاستەوخۆ لە شاشەی سەرەکی ئەپی کڕیار دەردەکەوێت',
      CatalogZonesMode.zones => 'ڕێکخستنی گەڕەکەکانی کەلار و کرێی گەیاندن',
      CatalogZonesMode.both => 'ڕێکخستنی گەڕەکەکانی کەلار و کرێی گەیاندن + بەشە سەرەکییەکانی ئەپی کڕیار',
    };

    final padH = AdminBreakpoints.pagePadH(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padH, padH < 16 ? 10 : 18, padH, 6),
          child: SectionHeader(
            title: headerTitle,
            subtitle: headerSubtitle,
          ),
        ),
        if (_hasTabs && _tabCtrl != null)
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: tx('📍 گەڕەکەکانی کەلار (${_zones.length})')),
              Tab(text: tx('🗂️ بەشەکانی بازاڕ (${_categories.length})')),
            ],
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : _hasTabs && _tabCtrl != null
                      ? TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _buildZonesList(),
                            _buildCategoriesList(),
                          ],
                        )
                      : _showCategories
                          ? _buildCategoriesList()
                          : _buildZonesList(),
        ),
      ],
    );
  }

  Widget _buildZonesList() {
    final pad = AdminBreakpoints.pagePadH(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        return ListView(
          padding: EdgeInsets.all(pad),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ElevatedButton.icon(
                onPressed: () => _showZoneDialog(),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: Text(tx('زیادکردنی گەڕەکی نوێ')),
              ),
            ),
            const SizedBox(height: 14),
            ..._zones.map((raw) {
              final z = raw as Map<String, dynamic>;
              final active = z['is_active'] == true;
              final feeChip = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: RegaColors.emerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tx(formatIqd(z['delivery_fee'] as num?, lang: widget.lang)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: RegaColors.emeraldDark,
                  ),
                ),
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: active,
                    onChanged: (v) async {
                      await widget.api.updateNeighborhood(z['id'] as int, {'is_active': v});
                      _load();
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _showZoneDialog(existing: z),
                    icon: const Icon(Icons.edit_outlined, color: RegaColors.blue),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _confirmDeleteZone(z),
                    icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                  ),
                ],
              );
              if (narrow) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: RegaColors.gold.withValues(alpha: 0.22),
                                child: Icon(Icons.location_on_rounded, color: RC.fg(Color(0xFF0F172A))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx('${z['name_ku'] ?? ''} (${z['name_en'] ?? ''})'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tx('⏱️ ${z['estimated_minutes'] ?? 25} خولەک  •  🏪 ${z['stores_count'] ?? 0} فرۆشگا  •  📦 ${z['orders_count'] ?? 0} داواکاری'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade700)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              feeChip,
                            ],
                          ),
                          const SizedBox(height: 6),
                          Align(alignment: AlignmentDirectional.centerEnd, child: actions),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: RegaColors.gold.withValues(alpha: 0.22),
                      child: Icon(Icons.location_on_rounded, color: RC.fg(Color(0xFF0F172A))),
                    ),
                    title: Text(
                      tx('${z['name_ku'] ?? ''} (${z['name_en'] ?? ''})'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      tx('⏱️ ${z['estimated_minutes'] ?? 25} خولەک  •  🏪 ${z['stores_count'] ?? 0} فرۆشگا  •  📦 ${z['orders_count'] ?? 0} داواکاری'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        feeChip,
                        const SizedBox(width: 8),
                        actions,
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildCategoriesList() {
    final pad = AdminBreakpoints.pagePadH(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gridW = (w - pad * 2).clamp(240.0, w);
        final narrowBanner = gridW < AdminBreakpoints.phone;
        final cols = gridW < 720 ? 1 : (gridW < 1320 ? 2 : 3);
        final cardWidth = cols == 1 ? gridW : AdminBreakpoints.cardWidth(gridW, cols, 14);

        return ListView(
          padding: EdgeInsets.all(pad),
          children: [
            if (narrowBanner) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RegaColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RegaColors.gold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  tx('هەر بەشێک کە زیاد دەکەیت (ناو + وێنە) لە گریدی سەرەکی ئەپی کڕیار دەردەکەوێت، وەک خواردنگە و مارکێت.'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCategoryDialog(),
                  icon: const Icon(Icons.add_box_rounded, size: 18),
                  label: Text(tx('زیادکردنی بەشی نوێ')),
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RegaColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: RegaColors.gold.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        tx('هەر بەشێک کە زیاد دەکەیت (ناو + وێنە) لە گریدی سەرەکی ئەپی کڕیار دەردەکەوێت، وەک خواردنگە و مارکێت.'),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    icon: const Icon(Icons.add_box_rounded, size: 18),
                    label: Text(tx('زیادکردنی بەشی نوێ')),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (_categories.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    tx('هیچ بەشێک نییە — یەکەم بەش زیاد بکە بۆ ئەپی کڕیار'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: RC.fg(Colors.black54)),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var index = 0; index < _categories.length; index++)
                    Builder(
                      builder: (_) {
                        final c = _categories[index] as Map<String, dynamic>;
                        final active = c['is_active'] == true;
                        final featured = c['is_featured_home'] == true;
                        return SizedBox(
                          width: cardWidth,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 140,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      c['image_url'] != null
                                          ? Image.network(
                                              c['image_url'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                color: RC.bg(Color(0xFFE2E8F0)),
                                                child: const Icon(Icons.category_rounded, size: 40),
                                              ),
                                            )
                                          : Container(
                                              color: RC.bg(Color(0xFFE2E8F0)),
                                              child: const Icon(Icons.category_rounded, size: 40),
                                            ),
                                      PositionedDirectional(
                                        top: 8,
                                        start: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: RC.bg(Colors.black).withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            tx('#${c['sort_order'] ?? (index + 1)}'),
                                            style: TextStyle(
                                              color: RC.fg(Colors.white),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (c['secondary_image_url'] != null &&
                                          c['secondary_image_url'].toString().isNotEmpty)
                                        PositionedDirectional(
                                          top: 8,
                                          end: 8,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(
                                              c['secondary_image_url'].toString(),
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          color: RC.bg(Color(0xFFFAC800)),
                                          child: Text(
                                            tx(c['name_ku']?.toString() ?? ''),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: RC.fg(Colors.black),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: tx('بەرەو سەرەوە'),
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: index == 0 ? null : () => _moveCategory(index, -1),
                                            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                                          ),
                                          IconButton(
                                            tooltip: tx('بەرەو خوارەوە'),
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: index >= _categories.length - 1
                                                ? null
                                                : () => _moveCategory(index, 1),
                                            icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            tx('🏪 ${c['stores_count'] ?? 0} فرۆشگا'),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FilterChip(
                                            selected: featured,
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            selectedColor: RegaColors.gold.withValues(alpha: 0.3),
                                            label: Text(tx('سەرەکی'), style: const TextStyle(fontSize: 11)),
                                            onSelected: (v) async {
                                              await widget.api.updateCategory(
                                                c['id'] as int,
                                                {'is_featured_home': v},
                                              );
                                              _load();
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          Switch(
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            value: active,
                                            onChanged: (v) async {
                                              await widget.api.updateCategory(c['id'] as int, {'is_active': v});
                                              _load();
                                            },
                                          ),
                                          IconButton(
                                            tooltip: tx('دەستکاری'),
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: () => _showCategoryDialog(existing: c),
                                            icon: const Icon(Icons.edit_outlined, size: 20, color: RegaColors.blue),
                                          ),
                                          IconButton(
                                            tooltip: tx('سڕینەوە'),
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: () => _confirmDeleteCategory(c),
                                            icon: const Icon(Icons.delete_outline, size: 20, color: RegaColors.crimson),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
