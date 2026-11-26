part of 'main.dart';

/// Categories-first Menu & Products flow (T.B/10–T.B/19).
class ProductsMenuScreen extends StatefulWidget {
  final List<Product> products;
  final List<String> categories;
  final Map<String, String> categoryImages;
  final Function(String) onToggle;
  final Function(String) onDelete;
  final Function(Product) onAdd;
  final Function(Product) onEdit;
  final void Function(String name, {String? imageUrl}) onAddCategory;
  final Function(String)? onDeleteCategory;
  final Future<void> Function(String oldName, String newName, {String? imageUrl})? onUpdateCategory;

  const ProductsMenuScreen({
    super.key,
    required this.products,
    required this.categories,
    required this.categoryImages,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
    required this.onEdit,
    required this.onAddCategory,
    this.onDeleteCategory,
    this.onUpdateCategory,
  });

  @override
  State<ProductsMenuScreen> createState() => _ProductsMenuScreenState();
}

class _ProductsMenuScreenState extends State<ProductsMenuScreen> {
  static const _orange = Color(0xFFFF6418);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFE55B5B);

  String? _openedCategory;
  bool _addingCategory = false;
  String? _editingCategory;

  final _catNameCtrl = TextEditingController();
  String? _draftImageUrl;
  Uint8List? _draftPreviewBytes;
  bool _imageBusy = false;

  @override
  void dispose() {
    _catNameCtrl.dispose();
    super.dispose();
  }

  String? _imageFor(String cat) {
    final u = widget.categoryImages[cat];
    if (u == null || u.isEmpty) return null;
    return VendorApiService.instance.resolveMediaUrl(u);
  }

  void _startAddCategory() {
    setState(() {
      _addingCategory = true;
      _editingCategory = null;
      _catNameCtrl.clear();
      _draftImageUrl = null;
      _draftPreviewBytes = null;
      _imageBusy = false;
    });
  }

  void _startEditCategory(String cat) {
    setState(() {
      _addingCategory = false;
      _editingCategory = cat;
      _catNameCtrl.text = cat;
      _draftImageUrl = widget.categoryImages[cat];
      _draftPreviewBytes = null;
      _imageBusy = false;
    });
  }

  void _cancelDraft() {
    setState(() {
      _addingCategory = false;
      _editingCategory = null;
      _catNameCtrl.clear();
      _draftImageUrl = null;
      _draftPreviewBytes = null;
      _imageBusy = false;
    });
  }

  Future<void> _saveDraft() async {
    final name = _catNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('...ناوی بەش بنووسە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(_red),
        ),
      );
      return;
    }
    if (_editingCategory != null) {
      final old = _editingCategory!;
      await widget.onUpdateCategory?.call(old, name, imageUrl: _draftImageUrl);
      if (!mounted) return;
      setState(() {
        if (_openedCategory == old) _openedCategory = name;
        _cancelDraft();
      });
      return;
    }
    widget.onAddCategory(name, imageUrl: _draftImageUrl);
    _cancelDraft();
  }

  Future<void> _pickCategoryImage() async {
    final source = await _showImageSourceSheet();
    if (source == null || !mounted) return;
    setState(() => _imageBusy = true);
    try {
      final picked = await pickVendorImage(fromCamera: source == ImageSource.camera);
      if (picked == null || !mounted) {
        if (mounted) setState(() => _imageBusy = false);
        return;
      }
      final compressed = await ImageCompressService.compressForUpload(
        name: picked.name.isNotEmpty ? picked.name : 'category.jpg',
        bytes: picked.bytes,
      );
      final up = await VendorApiService.instance.uploadMedia(compressed.bytes, compressed.name);
      final url = up['url']?.toString();
      if (url == null || url.isEmpty) throw Exception(t('بارکردنی وێنە سەرکەوتوو نەبوو'));
      if (!mounted) return;
      setState(() {
        _draftImageUrl = url;
        _draftPreviewBytes = compressed.bytes;
        _imageBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _imageBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx(e.toString()), textAlign: TextAlign.center), backgroundColor: RC.bg(_red)),
      );
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: RC.bg(const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        t('هەڵبژاردنی وێنە'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: RC.fg(const Color(0xFF0F172A)),
                          fontFamily: kAppFontFamily,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 26, color: RC.fg(_red)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sourceRow(
                  icon: Icons.camera_alt_rounded,
                  label: t('کامێرا'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const SizedBox(height: 10),
                _sourceRow(
                  icon: Icons.photo_library_rounded,
                  label: t('گەلەری'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RC.bg(_red),
                      foregroundColor: RC.fg(Colors.white),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      t('پاشگەزبوونەوە'),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: kAppFontFamily),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceRow({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0)), width: 1.3),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, color: RC.fg(const Color(0xFF334155)), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: RC.fg(const Color(0xFF0F172A)),
                    fontFamily: kAppFontFamily,
                  ),
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: RC.fg(const Color(0xFF94A3B8)), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(String cat) {
    const deleteRed = Color(0xFFDC2626);
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final compactH = RegaResponsive.isCompactHeight(ctx);
        final pad = RegaResponsive.scale(ctx, 20).clamp(14.0, 22.0);
        final titleSize = RegaResponsive.scale(ctx, 18).clamp(15.0, 18.0);
        final bodySize = RegaResponsive.scale(ctx, 14).clamp(12.5, 14.0);
        final btnH = RegaResponsive.scale(ctx, compactH ? 42 : 46).clamp(40.0, 48.0);
        final radius = RegaResponsive.scale(ctx, 22).clamp(16.0, 24.0);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: RC.bg(Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            insetPadding: RegaResponsive.dialogInset(ctx, cap: 400, vertical: compactH ? 12 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(ctx, cap: 400),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, pad + 2, pad, pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('سڕینەوەی بەش'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: RC.fg(deleteRed),
                        fontWeight: FontWeight.w900,
                        fontSize: titleSize,
                        height: 1.35,
                        fontFamily: kAppFontFamily,
                      ),
                    ),
                    SizedBox(height: RegaResponsive.scale(ctx, 12).clamp(8.0, 12.0)),
                    Text(
                      tx('دڵنیایت لە سڕینەوەی "$cat"؟'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: RC.fg(const Color(0xFF64748B)),
                        fontWeight: FontWeight.w600,
                        fontSize: bodySize,
                        height: 1.55,
                        fontFamily: kAppFontFamily,
                      ),
                    ),
                    SizedBox(height: RegaResponsive.scale(ctx, 18).clamp(12.0, 18.0)),
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: btnH,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RC.bg(const Color(0xFFE8EAF0)),
                                foregroundColor: RC.fg(const Color(0xFF0F172A)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                t('پاشگەزبوونەوە'),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: RegaResponsive.scale(ctx, 14).clamp(12.0, 14.0),
                                  height: 1.1,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: btnH,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RC.bg(deleteRed),
                                foregroundColor: RC.fg(Colors.white),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                t('سڕینەوە'),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: RegaResponsive.scale(ctx, 15).clamp(13.0, 15.0),
                                  height: 1.1,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((ok) {
      if (ok == true) {
        widget.onDeleteCategory?.call(cat);
        if (_openedCategory == cat) setState(() => _openedCategory = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final padH = RegaResponsive.pagePadding(context);
    if (_openedCategory != null) {
      return _buildCategoryDetail(padH, _openedCategory!);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 14, padH, 10),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        t('بەشەکانی مێنۆ'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: RC.fg(const Color(0xFF0F172A)),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          fontFamily: kAppFontFamily,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _orangeActionButton(
                      label: '+ ${t('زیادکردنی بەش')}',
                      onTap: _startAddCategory,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.categories.isEmpty && !_addingCategory
                    ? Center(
                        child: Text(
                          t('هیچ بەشێک زیاد نەکراوە'),
                          style: TextStyle(
                            color: RC.fg(const Color(0xFFCBD5E1)),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final crossCount = w >= 900
                              ? 4
                              : w >= 640
                                  ? 3
                                  : w >= 380
                                      ? 2
                                      : 1;
                          final cats = widget.categories
                              .where((c) => c != _editingCategory)
                              .toList();
                          final showDraft = _addingCategory || _editingCategory != null;

                          final itemCount = cats.length + (showDraft ? 1 : 0);

                          return CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(padH, 4, padH, 20),
                                sliver: SliverGrid(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossCount,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.78,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (showDraft && index == 0) {
                                        return _buildCategoryDraftCard();
                                      }
                                      final catIndex = showDraft ? index - 1 : index;
                                      return _buildCategoryCard(cats[catIndex]);
                                    },
                                    childCount: itemCount,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orangeActionButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: RC.bg(_orange),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: RC.fg(Colors.white),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              fontFamily: kAppFontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDraftCard() {
    final hasImage = _draftPreviewBytes != null || (_draftImageUrl != null && _draftImageUrl!.isNotEmpty);
    return Material(
      color: RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RC.bg(_orange), width: 1.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                color: RC.bg(const Color(0xFFF8FAFC)),
                child: InkWell(
                  onTap: _imageBusy ? null : _pickCategoryImage,
                  child: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_draftPreviewBytes != null)
                              Image.memory(
                                _draftPreviewBytes!,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              )
                            else
                              Image.network(
                                VendorApiService.instance.resolveMediaUrl(_draftImageUrl!),
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                color: Colors.black.withValues(alpha: 0.55),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  t('گۆڕینی وێنە'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: RC.fg(Colors.white),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    fontFamily: kAppFontFamily,
                                  ),
                                ),
                              ),
                            ),
                            if (_imageBusy)
                              const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_imageBusy)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: _orange, strokeWidth: 2),
                              )
                            else ...[
                              Icon(Icons.image_outlined, size: 36, color: RC.fg(_orange)),
                              const SizedBox(height: 6),
                              Text(
                                t('هەڵبژاردنی وێنە'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: RC.fg(_green),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _catNameCtrl,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: kAppFontFamily,
                      color: RC.fg(const Color(0xFF0F172A)),
                    ),
                    decoration: InputDecoration(
                      hintText: t('...ناوی بەش بنووسە'),
                      hintStyle: TextStyle(
                        color: RC.fg(const Color(0xFF94A3B8)),
                        fontFamily: kAppFontFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: RC.bg(Colors.white),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: RC.bg(_orange), width: 1.4),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: RC.bg(_orange), width: 1.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _saveDraft,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RC.bg(_green),
                              foregroundColor: RC.fg(Colors.white),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              t('پاشەکەوتکردن'),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                height: 1.1,
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Material(
                          color: RC.bg(_red),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _cancelDraft,
                            borderRadius: BorderRadius.circular(10),
                            child: Icon(Icons.close_rounded, color: RC.fg(Colors.white), size: 18),
                          ),
                        ),
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
  }

  Widget _buildCategoryCard(String cat) {
    final img = _imageFor(cat);
    return Material(
      color: RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => setState(() => _openedCategory = cat),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (img != null && img.isNotEmpty)
                      Image.network(
                        img,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => Container(
                          color: RC.bg(const Color(0xFFFFF7ED)),
                          child: Icon(Icons.restaurant_menu_rounded, color: RC.fg(_orange), size: 44),
                        ),
                      )
                    else
                      Container(
                        color: RC.bg(const Color(0xFFFFF7ED)),
                        child: Icon(Icons.restaurant_menu_rounded, color: RC.fg(_orange), size: 44),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Row(
                        children: [
                          _miniIconBtn(
                            color: _red,
                            icon: Icons.delete_outline_rounded,
                            onTap: () => _confirmDeleteCategory(cat),
                          ),
                          const SizedBox(width: 6),
                          _miniIconBtn(
                            color: _green,
                            icon: Icons.edit_rounded,
                            onTap: () => _startEditCategory(cat),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: RC.bg(Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        cat.trim() == 'بەرهەمە سەرەکییەکان' ? t('بەرهەمەکان') : tx(cat),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: RC.fg(const Color(0xFF0F172A)),
                          fontFamily: kAppFontFamily,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded, color: RC.fg(const Color(0xFF94A3B8)), size: 22),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniIconBtn({required Color color, required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: RC.bg(color),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: RC.fg(Colors.white), size: 19),
        ),
      ),
    );
  }

  Widget _buildCategoryDetail(double padH, String cat) {
    final products = widget.products.where((p) => p.category.trim() == cat.trim()).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 12, padH, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 420;
                    final backBtn = Material(
                      color: RC.bg(const Color(0xFFFFF7ED)),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _openedCategory = null),
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: RC.fg(_orange),
                            size: 20,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ),
                    );
                    final titleLabel = cat.trim() == 'بەرهەمە سەرەکییەکان'
                        ? t('بەرهەمەکان')
                        : tx(cat);
                    final title = Text(
                      titleLabel,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: narrow ? 14 : 15.5,
                        color: RC.fg(const Color(0xFF0F172A)),
                        fontFamily: kAppFontFamily,
                      ),
                    );
                    final addBtn = _orangeActionButton(
                      label: '+ ${t('زیادکردنی بەرهەم')}',
                      onTap: () => _openProductForm(category: cat),
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              backBtn,
                              const SizedBox(width: 12),
                              Expanded(child: title),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: addBtn,
                          ),
                        ],
                      );
                    }

                    return Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        backBtn,
                        const SizedBox(width: 12),
                        Expanded(child: title),
                        const SizedBox(width: 12),
                        addBtn,
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Text(
                          t('هیچ بابەتێک لەم بەشەدا نییە'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: RC.fg(const Color(0xFFCBD5E1)),
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final useGrid = w >= 720;
                          final crossCount = w >= 980
                              ? 3
                              : w >= 720
                                  ? 2
                                  : 1;
                          if (!useGrid) {
                            return ListView.builder(
                              padding: EdgeInsets.fromLTRB(padH, 4, padH, 20),
                              itemCount: products.length,
                              itemBuilder: (_, i) => _buildProductRow(products[i]),
                            );
                          }
                          return GridView.builder(
                            padding: EdgeInsets.fromLTRB(padH, 4, padH, 20),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 184,
                            ),
                            itemCount: products.length,
                            itemBuilder: (_, i) => _buildProductRow(products[i]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(Product product) {
    final resolved = VendorApiService.instance.resolveMediaUrl(product.imageUrl);
    late final ImageProvider provider;
    if (!kIsWeb && product.imagePath != null && product.imagePath!.isNotEmpty) {
      final f = File(product.imagePath!);
      if (f.existsSync()) {
        provider = FileImage(f);
      } else if (resolved.isNotEmpty) {
        provider = NetworkImage(resolved);
      } else {
        provider = NetworkImage(getProductImageUrl(product.name));
      }
    } else if (resolved.isNotEmpty) {
      provider = NetworkImage(resolved);
    } else {
      provider = NetworkImage(getProductImageUrl(product.name));
    }

    final hasDiscount =
        product.discountPrice != null && product.discountPrice! > 0 && product.discountPrice! < product.price;
    final display = hasDiscount ? product.discountPrice!.toInt() : product.price.toInt();

    return Material(
      color: RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openProductForm(category: product.category, existing: product),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.bg(const Color(0xFF0F172A)), width: 1.15),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => showFullScreenImageDialog(context, imageProvider: provider, title: product.name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: provider,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 84,
                      height: 84,
                      color: RC.bg(const Color(0xFFFFF7ED)),
                      child: Icon(Icons.fastfood_rounded, color: RC.fg(_orange)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tx(product.name),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: RC.fg(const Color(0xFF0F172A)),
                        fontFamily: kAppFontFamily,
                      ),
                    ),
                    if ((product.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tx(product.description!),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: RC.fg(const Color(0xFF64748B)),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          fontFamily: kAppFontFamily,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  tx('${formatAmountOnly(display)} ${t('دینار')}'),
                                  style: TextStyle(
                                    color: RC.fg(_green),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    fontFamily: kAppFontFamily,
                                  ),
                                ),
                                if (hasDiscount) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    formatAmountOnly(product.price.toInt()),
                                    style: TextStyle(
                                      color: RC.fg(const Color(0xFF94A3B8)),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: RC.fg(_red),
                                      fontFamily: kAppFontFamily,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t('دەستکاری'),
                              style: TextStyle(
                                color: RC.fg(_green),
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _featureLineRe = RegExp(r'^[•\-\*]\s*(.+?)(?:\s*\(\+(\d+)\))?\s*$');

  List<({String name, int extraPrice})> _parseFeatures(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final idx = raw.indexOf('تایبەتمەندییەکان:');
    if (idx < 0) return [];
    final out = <({String name, int extraPrice})>[];
    for (final line in raw.substring(idx).split('\n').skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final m = _featureLineRe.firstMatch(trimmed);
      if (m == null) break;
      final name = (m.group(1) ?? '').trim();
      if (name.isEmpty) continue;
      final extra = int.tryParse(m.group(2) ?? '') ?? 0;
      out.add((name: name, extraPrice: extra < 0 ? 0 : extra));
    }
    return out;
  }

  String _stripFeaturesBlock(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final idx = raw.indexOf('تایبەتمەندییەکان:');
    if (idx < 0) return raw.trim();
    return raw.substring(0, idx).trim();
  }

  String? _composeDescription(String base, List<({String name, int extraPrice})> features) {
    final clean = base.trim();
    if (features.isEmpty) return clean.isEmpty ? null : clean;
    final buf = StringBuffer();
    if (clean.isNotEmpty) {
      buf.writeln(clean);
      buf.writeln();
    }
    buf.writeln('تایبەتمەندییەکان:');
    for (final f in features) {
      if (f.extraPrice > 0) {
        buf.writeln('• ${f.name} (+${f.extraPrice})');
      } else {
        buf.writeln('• ${f.name}');
      }
    }
    return buf.toString().trim();
  }

  Future<({String name, int extraPrice})?> _promptAddFeature(BuildContext parentCtx) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final result = await showDialog<({String name, int extraPrice})>(
      context: parentCtx,
      builder: (dlgCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              t('زیادکردنی تایبەتمەندی'),
              style: TextStyle(fontWeight: FontWeight.w900, fontFamily: kAppFontFamily),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: t('ناوی تایبەتمەندی'),
                    filled: true,
                    fillColor: RC.bg(const Color(0xFFF1F5F9)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(fontFamily: kAppFontFamily),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: t('نرخی زیادە (ئارەزوومەندانە)'),
                    hintText: t('بە دینار — ئارەزوومەندانە'),
                    hintStyle: TextStyle(
                      color: RC.fg(const Color(0xFF94A3B8)),
                      fontWeight: FontWeight.w600,
                      fontFamily: kAppFontFamily,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: RC.bg(const Color(0xFFF1F5F9)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(fontFamily: kAppFontFamily),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(t('پاشگەزبوونەوە'), style: TextStyle(fontFamily: kAppFontFamily)),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final extra = int.tryParse(priceCtrl.text.trim()) ?? 0;
                  Navigator.pop(dlgCtx, (name: name, extraPrice: extra < 0 ? 0 : extra));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(_green),
                  foregroundColor: RC.fg(Colors.white),
                ),
                child: Text(t('زیادکردن'), style: TextStyle(fontFamily: kAppFontFamily, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
    nameCtrl.dispose();
    priceCtrl.dispose();
    return result;
  }

  Future<void> _openProductForm({required String category, Product? existing}) async {
    final isEdit = existing != null;
    final parsedFeatures = _parseFeatures(existing?.description);
    final nameKu = TextEditingController(text: existing?.name ?? '');
    final nameAr = TextEditingController();
    final desc = TextEditingController(text: _stripFeaturesBlock(existing?.description));
    final price = TextEditingController(
      text: (existing != null && existing.price > 0) ? existing.price.toInt().toString() : '',
    );
    final cost = TextEditingController(
      text: (existing != null && existing.costPrice > 0) ? existing.costPrice.toInt().toString() : '',
    );
    final discount = TextEditingController(
      text: (existing?.discountPrice != null && existing!.discountPrice! > 0)
          ? existing.discountPrice!.toInt().toString()
          : '',
    );
    final prep = TextEditingController();
    final delivery = TextEditingController();
    String? imageUrl = existing?.imageUrl;
    Uint8List? previewBytes;
    var imageBusy = false;
    final features = List<({String name, int extraPrice})>.from(parsedFeatures);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            Future<void> pickImage() async {
              final source = await _showImageSourceSheet();
              if (source == null) return;
              setSheet(() => imageBusy = true);
              try {
                final picked = await pickVendorImage(fromCamera: source == ImageSource.camera);
                if (picked == null) {
                  setSheet(() => imageBusy = false);
                  return;
                }
                final compressed = await ImageCompressService.compressForUpload(
                  name: picked.name.isNotEmpty ? picked.name : 'product.jpg',
                  bytes: picked.bytes,
                );
                final up = await VendorApiService.instance.uploadMedia(compressed.bytes, compressed.name);
                final url = up['url']?.toString();
                if (url == null || url.isEmpty) throw Exception(t('بارکردنی وێنە سەرکەوتوو نەبوو'));
                setSheet(() {
                  imageUrl = url;
                  previewBytes = compressed.bytes;
                  imageBusy = false;
                });
              } catch (e) {
                setSheet(() => imageBusy = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tx(e.toString())), backgroundColor: RC.bg(_red)),
                  );
                }
              }
            }

            InputDecoration fieldDeco({String? hint}) => InputDecoration(
                  filled: true,
                  fillColor: RC.bg(const Color(0xFFF1F5F9)),
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: RC.fg(const Color(0xFF94A3B8)),
                    fontWeight: FontWeight.w600,
                    fontFamily: kAppFontFamily,
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                );

            Widget labeledField(
              String label,
              TextEditingController c, {
              int maxLines = 1,
              TextInputType? type,
              String? hint,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: RC.fg(const Color(0xFF0F172A)),
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: c,
                    maxLines: maxLines,
                    keyboardType: type,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontWeight: FontWeight.w700, fontFamily: kAppFontFamily),
                    decoration: fieldDeco(hint: hint),
                  ),
                ],
              );
            }

            final bottom = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            final hasImage = previewBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetCtx).height * 0.92,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    child: Text(
                                      isEdit ? t('دەستکاری بابەت') : t('زیادکردنی بەرهەم'),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        fontFamily: kAppFontFamily,
                                        color: RC.fg(const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: RC.bg(const Color(0xFFFEE2E2)),
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      onTap: () => Navigator.pop(sheetCtx),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: RC.bg(_red), width: 1.4),
                                        ),
                                        child: Text(
                                          t('داخستن'),
                                          style: TextStyle(
                                            color: RC.fg(_red),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            fontFamily: kAppFontFamily,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t('وێنە'),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: RC.fg(const Color(0xFF0F172A)),
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Material(
                                color: RC.bg(const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: imageBusy ? null : pickImage,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: SizedBox(
                                            width: 72,
                                            height: 72,
                                            child: previewBytes != null
                                                ? Image.memory(previewBytes!, fit: BoxFit.cover)
                                                : (imageUrl != null && imageUrl!.isNotEmpty)
                                                    ? Image.network(
                                                        VendorApiService.instance.resolveMediaUrl(imageUrl),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => Container(
                                                          color: Colors.white,
                                                          child: Icon(Icons.image_outlined, color: RC.fg(_orange)),
                                                        ),
                                                      )
                                                    : Container(
                                                        color: Colors.white,
                                                        child: Icon(Icons.image_outlined, color: RC.fg(_orange)),
                                                      ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            hasImage ? t('گۆڕینی وێنە') : t('هەڵبژاردنی وێنە'),
                                            textAlign: TextAlign.right,
                                            textDirection: TextDirection.rtl,
                                            style: TextStyle(
                                              color: RC.fg(_green),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              fontFamily: kAppFontFamily,
                                            ),
                                          ),
                                        ),
                                        if (imageBusy)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              labeledField(t('ناوی بابەت بە کوردی'), nameKu),
                              const SizedBox(height: 10),
                              labeledField(t('ناوی بابەت بە عەرەبی'), nameAr),
                              const SizedBox(height: 10),
                              labeledField(t('وەسف'), desc, maxLines: 2, hint: t('وەسف بنووسە (ئارەزوومەندانە)')),
                              const SizedBox(height: 10),
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    child: labeledField(
                                      t('نرخی فرۆشتن'),
                                      price,
                                      type: TextInputType.number,
                                      hint: t('بە دینار'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: labeledField(
                                      t('نرخی کڕین (تێچوو)'),
                                      cost,
                                      type: TextInputType.number,
                                      hint: t('تێچووی دروستکردن'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    child: labeledField(
                                      t('داشکان'),
                                      discount,
                                      type: TextInputType.number,
                                      hint: t('بە دینار — ئارەزوومەندانە'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: labeledField(
                                      t('کاتی پێچوون (خولەک)'),
                                      prep,
                                      type: TextInputType.number,
                                      hint: t('بە خولەک'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              labeledField(
                                t('نرخی گەیاندن'),
                                delivery,
                                type: TextInputType.number,
                                hint: t('بە دینار — ئارەزوومەندانە'),
                              ),
                              const SizedBox(height: 12),
                              if (features.isNotEmpty) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    t('تایبەتمەندییەکان'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: RC.fg(const Color(0xFF0F172A)),
                                      fontFamily: kAppFontFamily,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...features.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final f = entry.value;
                                  final priceLabel = f.extraPrice > 0 ? ' (+${f.extraPrice})' : '';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: RC.bg(const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                                    ),
                                    child: Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${f.name}$priceLabel',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontFamily: kAppFontFamily,
                                              color: RC.fg(const Color(0xFF334155)),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: t('سڕینەوە'),
                                          onPressed: () => setSheet(() => features.removeAt(i)),
                                          icon: Icon(Icons.close_rounded, color: RC.fg(_red), size: 20),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final added = await _promptAddFeature(sheetCtx);
                                    if (added == null) return;
                                    setSheet(() => features.add(added));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RC.bg(const Color(0xFFF1F5F9)),
                                    foregroundColor: RC.fg(const Color(0xFF334155)),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    t('+ زیادکردنی تایبەتمەندی'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontFamily: kAppFontFamily,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            flex: isEdit ? 3 : 1,
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  final n = nameKu.text.trim();
                                  final p = double.tryParse(price.text.trim()) ?? 0;
                                  final c = double.tryParse(cost.text.trim()) ?? 0;
                                  final d = double.tryParse(discount.text.trim()) ?? 0;
                                  if (n.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(t('ناوی بابەت بە کوردی'), textAlign: TextAlign.center),
                                        backgroundColor: RC.bg(_red),
                                      ),
                                    );
                                    return;
                                  }
                                  if (p <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(t('نرخی فرۆشتن'), textAlign: TextAlign.center),
                                        backgroundColor: RC.bg(_red),
                                      ),
                                    );
                                    return;
                                  }
                                  if (c > 0 && c >= p) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          t('نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت'),
                                          textAlign: TextAlign.center,
                                        ),
                                        backgroundColor: RC.bg(_red),
                                      ),
                                    );
                                    return;
                                  }
                                  final product = Product(
                                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                    name: n,
                                    category: category,
                                    price: p,
                                    costPrice: c > 0 ? c : (existing?.costPrice ?? 0),
                                    discountPrice: d > 0 && d < p ? d : null,
                                    description: _composeDescription(desc.text, features),
                                    imageUrl: imageUrl,
                                    isAvailable: existing?.isAvailable ?? true,
                                    imagePath: existing?.imagePath,
                                  );
                                  if (isEdit) {
                                    widget.onEdit(product);
                                  } else {
                                    widget.onAdd(product);
                                  }
                                  Navigator.pop(sheetCtx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(_green),
                                  foregroundColor: RC.fg(Colors.white),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  t('پاشەکەوتکردن'),
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: kAppFontFamily),
                                ),
                              ),
                            ),
                          ),
                          if (isEdit) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  widget.onDelete(existing.id);
                                  Navigator.pop(sheetCtx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(_red),
                                  foregroundColor: RC.fg(Colors.white),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  t('سڕینەوە'),
                                  style: TextStyle(fontWeight: FontWeight.w900, fontFamily: kAppFontFamily),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameKu.dispose();
    nameAr.dispose();
    desc.dispose();
    price.dispose();
    cost.dispose();
    discount.dispose();
    prep.dispose();
    delivery.dispose();
  }
}
