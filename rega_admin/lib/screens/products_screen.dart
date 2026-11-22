import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/services/media_pick_service.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'store_menu_categories_screen.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
class ProductsScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const ProductsScreen({super.key, required this.api, required this.lang});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  int? _storeFilter;
  bool _onlyDiscounted = false;
  bool _loading = true;
  String? _error;
  List<dynamic> _products = [];
  List<dynamic> _stores = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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
        widget.api.getProducts(
          storeId: _storeFilter,
          search: _searchCtrl.text.trim(),
          hasDiscount: _onlyDiscounted ? true : null,
        ),
        widget.api.getStores(),
      ]);
      if (mounted) {
        setState(() {
          _products = results[0];
          _stores = results[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<dynamic>> _loadMenuCategories(int storeId) async {
    try {
      final res = await widget.api.getStoreDetails(storeId);
      final data = res['data'] as Map<String, dynamic>? ?? res;
      return data['store_categories'] as List<dynamic>? ?? [];
    } catch (_) {
      return [];
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

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        title: Text(
          AppStrings.tr('delete', widget.lang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 420),
            maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 260),
          ),
          child: SingleChildScrollView(
            child: Text(AppStrings.tr('confirm_delete_item', widget.lang)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.tr('cancel', widget.lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.tr('delete', widget.lang)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteProduct(product['id'] as int);
      _showSnack(AppStrings.tr('vendor_item_deleted', widget.lang));
      _load();
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  Future<({String name, Uint8List bytes})?> _pickAndCompressProductImage() {
    return MediaPickService.pickImageForUpload();
  }

  Widget _productImagePlaceholder() {
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
            AppStrings.tr('item_image_placeholder', widget.lang),
            textAlign: TextAlign.center,
            style: TextStyle(color: RC.fg(Colors.black45), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _showProductDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameKuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final nameEnCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final descKuCtrl = TextEditingController(text: existing?['description_ku']?.toString() ?? '');
    final descArCtrl = TextEditingController(text: existing?['description_ar']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: (existing?['price'] ?? '').toString());
    final costCtrl = TextEditingController(text: (existing?['cost_price'] ?? '').toString());
    final discountCtrl = TextEditingController(text: existing?['discount_price']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: existing?['image_url']?.toString() ?? '');

    int? storeId = existing?['store_id'] as int? ??
        _storeFilter ??
        (_stores.isNotEmpty ? (_stores.first as Map<String, dynamic>)['id'] as int : null);
    int? categoryId = existing?['store_category_id'] as int?;
    bool isAvailable = existing?['is_available'] != false;
    List<dynamic> menuCategories = [];
    var catsLoading = false;
    var catsFetchStarted = false;
    ({String name, Uint8List bytes})? pendingImage;
    var pickingImage = false;
    var uploadingImage = false;
    String? imageUploadError;
    var imageUploadOk = false;
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> loadCats(int? id) async {
            if (id == null) {
              setDialogState(() {
                menuCategories = [];
                categoryId = null;
                catsLoading = false;
              });
              return;
            }
            setDialogState(() => catsLoading = true);
            final cats = await _loadMenuCategories(id);
            if (!ctx.mounted) return;
            setDialogState(() {
              menuCategories = cats;
              final stillValid = cats.any((c) => (c as Map)['id'] == categoryId);
              if (!stillValid) categoryId = null;
              catsLoading = false;
            });
          }

          Future<void> pickCompressAndUpload() async {
            if (saving || pickingImage || uploadingImage) return;
            setDialogState(() {
              pickingImage = true;
              imageUploadError = null;
              imageUploadOk = false;
            });
            try {
              final picked = await _pickAndCompressProductImage();
              if (picked == null || !ctx.mounted) return;
              setDialogState(() {
                pendingImage = picked;
                pickingImage = false;
                uploadingImage = true;
              });
              final up = await widget.api.uploadMedia(picked.bytes, picked.name);
              final url = up['url']?.toString();
              if (url == null || url.isEmpty) {
                throw Exception(AppStrings.tr('item_image_upload_failed', widget.lang));
              }
              if (!ctx.mounted) return;
              imgCtrl.text = url;
              setDialogState(() {
                uploadingImage = false;
                imageUploadOk = true;
                imageUploadError = null;
              });
            } catch (e) {
              if (!ctx.mounted) return;
              final friendly = AppStrings.tr('item_image_upload_failed', widget.lang);
              setDialogState(() {
                pickingImage = false;
                uploadingImage = false;
                imageUploadOk = false;
                imageUploadError = friendly;
              });
              _showSnack(
                friendly,
                error: true,
              );
            }
          }

          if (!catsFetchStarted && storeId != null) {
            catsFetchStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) loadCats(storeId);
            });
          }

          final previewUrl = imgCtrl.text.trim();
          final resolvedPreview =
              previewUrl.isEmpty ? '' : widget.api.resolveMediaUrl(previewUrl);
          final busyImage = pickingImage || uploadingImage;
          final hasPreview = pendingImage != null || resolvedPreview.isNotEmpty;

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
            actionsOverflowButtonSpacing: 8,
            title: Text(
              tx(isEdit
                  ? AppStrings.tr('edit_vendor_item', widget.lang)
                  : AppStrings.tr('add_vendor_item', widget.lang)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 500),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 580),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: storeId,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('vendor_store_required', widget.lang),
                        ),
                        items: _stores.map((s) {
                          final m = s as Map<String, dynamic>;
                          return DropdownMenuItem<int>(
                            value: m['id'] as int,
                            child: Text(
                              tx(m['name_ku']?.toString() ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (v) {
                                setDialogState(() {
                                  storeId = v;
                                  categoryId = null;
                                });
                                loadCats(v);
                              },
                      ),
                      const SizedBox(height: 12),
                      if (catsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        )
                      else if (menuCategories.isNotEmpty)
                        DropdownButtonFormField<int?>(
                          isExpanded: true,
                          key: ValueKey('menu-cat-$storeId-${menuCategories.length}'),
                          initialValue: categoryId,
                          decoration: InputDecoration(
                            labelText: AppStrings.tr('menu_category', widget.lang),
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                AppStrings.tr('no_menu_category', widget.lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ...menuCategories.map((c) {
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
                          onChanged: saving ? null : (v) => setDialogState(() => categoryId = v),
                        ),
                      if (menuCategories.isNotEmpty) const SizedBox(height: 12),
                      TextField(
                        controller: nameKuCtrl,
                        enabled: !saving,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('item_name_ku', widget.lang),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameEnCtrl,
                        enabled: !saving,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('name_en_field', widget.lang),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ResponsiveFormRow(
                        breakpoint: 380,
                        first: TextField(
                          controller: costCtrl,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tx('نرخی کڕین / Cost (IQD) *'),
                          ),
                        ),
                        second: TextField(
                          controller: priceCtrl,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: AppStrings.tr('item_price', widget.lang),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: discountCtrl,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('item_discount_price', widget.lang),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descKuCtrl,
                        enabled: !saving,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('item_desc_ku', widget.lang),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descArCtrl,
                        enabled: !saving,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('item_desc_ar', widget.lang),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppStrings.tr('item_image_placeholder', widget.lang),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: (saving || busyImage) ? null : pickCompressAndUpload,
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: imageUploadError != null
                                    ? RegaColors.crimson
                                    : (imageUploadOk || hasPreview)
                                        ? RegaColors.orange
                                        : RC.bg(Color(0xFFE2E8F0)),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: AspectRatio(
                                  aspectRatio: 1.35,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (pendingImage != null)
                                        Image.memory(
                                          pendingImage!.bytes,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => _productImagePlaceholder(),
                                        )
                                      else if (resolvedPreview.isNotEmpty)
                                        Image.network(
                                          resolvedPreview,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => _productImagePlaceholder(),
                                        )
                                      else
                                        _productImagePlaceholder(),
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
                                      if (busyImage)
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
                                                tx(pickingImage
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
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (saving || busyImage) ? null : pickCompressAndUpload,
                          style: FilledButton.styleFrom(
                            backgroundColor: RegaColors.orange,
                            foregroundColor: RC.fg(Colors.white),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          icon: busyImage
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: RC.bg(Colors.white),
                                  ),
                                )
                              : Icon(
                                  hasPreview
                                      ? Icons.sync_rounded
                                      : Icons.cloud_upload_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            tx(busyImage
                                ? (pickingImage
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
                      if (imageUploadOk) ...[
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
                      if (imageUploadError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          tx(imageUploadError!),
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
                            AppStrings.tr('item_image_or_url', widget.lang),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          children: [
                            TextField(
                              controller: imgCtrl,
                              enabled: !saving && !busyImage,
                              onChanged: (_) => setDialogState(() {
                                imageUploadOk = false;
                              }),
                              decoration: InputDecoration(
                                hintText: tx('https://...'),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          tx(isAvailable
                              ? AppStrings.tr('item_available', widget.lang)
                              : AppStrings.tr('item_unavailable', widget.lang)),
                        ),
                        value: isAvailable,
                        onChanged: saving ? null : (v) => setDialogState(() => isAvailable = v),
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
                        final price = int.tryParse(priceCtrl.text.trim());
                        final cost = int.tryParse(costCtrl.text.trim());
                        if (storeId == null || nameKuCtrl.text.trim().isEmpty || price == null || cost == null) {
                          _showSnack(AppStrings.tr('vendor_item_validation', widget.lang), error: true);
                          return;
                        }
                        if (cost < 0 || cost >= price) {
                          _showSnack('نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت', error: true);
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          String? imageUrl =
                              imgCtrl.text.trim().isEmpty ? null : imgCtrl.text.trim();
                          // Fallback: if a local image was picked but not yet uploaded
                          if (pendingImage != null && (imageUrl == null || imageUrl.isEmpty)) {
                            final up = await widget.api.uploadMedia(
                              pendingImage!.bytes,
                              pendingImage!.name,
                            );
                            imageUrl = up['url']?.toString();
                            if (imageUrl == null || imageUrl.isEmpty) {
                              throw Exception(
                                AppStrings.tr('item_image_upload_failed', widget.lang),
                              );
                            }
                            imgCtrl.text = imageUrl;
                          }
                          final disc = int.tryParse(discountCtrl.text.trim());
                          final payload = <String, dynamic>{
                            'store_id': storeId,
                            'store_category_id': categoryId,
                            'name_ku': nameKuCtrl.text.trim(),
                            'name_en': nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
                            'description_ku':
                                descKuCtrl.text.trim().isEmpty ? null : descKuCtrl.text.trim(),
                            'description_ar':
                                descArCtrl.text.trim().isEmpty ? null : descArCtrl.text.trim(),
                            'price': price,
                            'cost_price': cost,
                            'discount_price': disc,
                            'is_available': isAvailable,
                            if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
                          };
                          if (isEdit) {
                            await widget.api.updateProduct(existing['id'] as int, payload);
                            _showSnack(AppStrings.tr('vendor_item_saved', widget.lang));
                          } else {
                            await widget.api.createProduct(payload);
                            _showSnack(AppStrings.tr('vendor_item_created', widget.lang));
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
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

  Widget _buildItemsTab() {
    final padH = AdminBreakpoints.pagePadH(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentW = (constraints.maxWidth - padH * 2).clamp(220.0, constraints.maxWidth);
        final phone = contentW < AdminBreakpoints.phone;
        final fieldWidth = phone ? contentW : 260.0;
        final storeFieldWidth = phone ? contentW : 220.0;
        final cols = contentW < 540
            ? 1
            : (contentW < 900 ? 2 : (contentW < 1280 ? 3 : 4));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(padH, 16, padH, 14),
                    child: SectionHeader(
                      title: AppStrings.tr('nav_vendor_items', widget.lang),
                      subtitle: AppStrings.tr('vendor_items_subtitle', widget.lang),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _showProductDialog(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(AppStrings.tr('add_vendor_item', widget.lang)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: (_) => _load(),
                            decoration: InputDecoration(
                              hintText: AppStrings.tr('search_vendor_items', widget.lang),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                onPressed: _load,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: storeFieldWidth,
                          child: DropdownButtonFormField<int?>(
                            isExpanded: true,
                            initialValue: _storeFilter,
                            decoration: InputDecoration(
                              labelText: AppStrings.tr('filter_by_vendor', widget.lang),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  AppStrings.tr('all_vendors', widget.lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ..._stores.map((s) {
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
                        FilterChip(
                          selected: _onlyDiscounted,
                          selectedColor: RegaColors.crimson.withValues(alpha: 0.15),
                          label: Text(AppStrings.tr('only_discounted', widget.lang)),
                          onSelected: (v) {
                            setState(() => _onlyDiscounted = v);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorRetryView(message: _error!, onRetry: _load),
                ),
              )
            else if (_products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppStrings.tr('no_results', widget.lang),
                      style: TextStyle(
                        color: RC.fg(Color(0xFF64748B)),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padH, 6, padH, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisExtent: 284,
                    crossAxisSpacing: cols == 1 ? 10 : 14,
                    mainAxisSpacing: cols == 1 ? 10 : 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, idx) {
                      final p = _products[idx] as Map<String, dynamic>;
                      final store = p['store'] as Map<String, dynamic>?;
                      final menuCat = p['store_category'] as Map<String, dynamic>?;
                      final price = (p['price'] as num?)?.toInt() ?? 0;
                      final disc = (p['discount_price'] as num?)?.toInt();
                      final hasDiscount = disc != null && disc > 0 && disc < price;
                      final avail = p['is_available'] == true;
                      final imageUrl = widget.api.resolveMediaUrl(p['image_url']?.toString());

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 105,
                                  width: double.infinity,
                                  color: RC.bg(Color(0xFF1E293B)),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.fastfood_rounded,
                                            color: RC.fg(Colors.white54),
                                            size: 36,
                                          ),
                                        )
                                      : Icon(
                                          Icons.fastfood_rounded,
                                          color: RC.fg(Colors.white54),
                                          size: 36,
                                        ),
                                ),
                                if (hasDiscount)
                                  PositionedDirectional(
                                    top: 8,
                                    end: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: RegaColors.crimson,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        AppStrings.tr('only_discounted', widget.lang),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: RC.fg(Colors.white),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx(p['name_ku']?.toString() ?? ''),
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
                                            store?['name_ku']?.toString() ?? '',
                                            if (menuCat?['name_ku'] != null)
                                              menuCat!['name_ku'].toString(),
                                          ].where((s) => s.isNotEmpty).join(' • ')),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: RC.fg(Color(0xFF64748B)),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              tx(formatIqd(
                                                hasDiscount ? disc : price,
                                                lang: widget.lang,
                                              )),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: RegaColors.emeraldDark,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            if (hasDiscount)
                                              Text(
                                                tx(formatIqd(price, lang: widget.lang)),
                                                style: const TextStyle(
                                                  decoration: TextDecoration.lineThrough,
                                                  color: RegaColors.crimson,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Switch(
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                value: avail,
                                                onChanged: (_) async {
                                                  try {
                                                    await widget.api
                                                        .toggleProductAvailability(p['id'] as int);
                                                    _load();
                                                  } catch (e) {
                                                    _showSnack(e.toString(), error: true);
                                                  }
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  tx(avail
                                                      ? AppStrings.tr('item_available', widget.lang)
                                                      : AppStrings.tr(
                                                          'item_unavailable',
                                                          widget.lang,
                                                        )),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: avail
                                                        ? RegaColors.emeraldDark
                                                        : RegaColors.crimson,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                              icon: const Icon(Icons.edit_outlined, size: 19),
                                              onPressed: () =>
                                                  _showProductDialog(existing: p),
                                            ),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 19,
                                                color: RegaColors.crimson,
                                              ),
                                              onPressed: () => _confirmDelete(p),
                                            ),
                                          ],
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
                    childCount: _products.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AdminBreakpoints.pagePadH(context), 12, AdminBreakpoints.pagePadH(context), 0),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: RegaColors.orange,
            unselectedLabelColor: RC.fg(Color(0xFF64748B)),
            indicatorColor: RegaColors.orange,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            tabs: [
              Tab(text: tx('بەرهەمەکان (Vendor Items)')),
              Tab(text: tx('ڕووکاری فرۆشگا / چیپەکان')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildItemsTab(),
              StoreMenuCategoriesScreen(api: widget.api, lang: widget.lang),
            ],
          ),
        ),
      ],
    );
  }
}
