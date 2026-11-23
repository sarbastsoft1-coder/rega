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
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null || !mounted) return;
    setState(() => _imageBusy = true);
    try {
      final raw = await file.readAsBytes();
      final compressed = await ImageCompressService.compressForUpload(
        name: file.name.isNotEmpty ? file.name : 'category.jpg',
        bytes: Uint8List.fromList(raw),
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
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: RC.bg(const Color(0xFFFEE2E2)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: RC.fg(_red)),
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
                  label: t('گالەری'),
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
      color: RC.bg(const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, color: RC.fg(const Color(0xFF334155)), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: RC.fg(const Color(0xFF0F172A)),
                    fontFamily: kAppFontFamily,
                  ),
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: RC.fg(const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(String cat) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(t('سڕینەوەی بەش'), style: TextStyle(fontFamily: kAppFontFamily)),
          content: Text(tx('دڵنیایت لە سڕینەوەی "$cat"؟'), style: TextStyle(fontFamily: kAppFontFamily)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('پاشگەزبوونەوە'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('سڕینەوە'), style: TextStyle(color: RC.fg(_red))),
            ),
          ],
        ),
      ),
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
                      label: t('زیادکردنی بەش'),
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
                    : ListView(
                        padding: EdgeInsets.fromLTRB(padH, 4, padH, 20),
                        children: [
                          if (_addingCategory || _editingCategory != null) ...[
                            _buildCategoryDraftCard(),
                            const SizedBox(height: 14),
                          ],
                          ...widget.categories.map((cat) {
                            if (_editingCategory == cat) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildCategoryCard(cat),
                            );
                          }),
                        ],
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: RC.fg(Colors.white), size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: RC.fg(Colors.white),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  fontFamily: kAppFontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDraftCard() {
    final hasImage = _draftPreviewBytes != null || (_draftImageUrl != null && _draftImageUrl!.isNotEmpty);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: Material(
                  color: RC.bg(const Color(0xFFF8FAFC)),
                  child: InkWell(
                    onTap: _imageBusy ? null : _pickCategoryImage,
                    child: hasImage
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_draftPreviewBytes != null)
                                Image.memory(_draftPreviewBytes!, fit: BoxFit.cover)
                              else
                                Image.network(
                                  VendorApiService.instance.resolveMediaUrl(_draftImageUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black.withValues(alpha: 0.55),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    t('گۆڕینی وێنە'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: RC.fg(Colors.white),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      fontFamily: kAppFontFamily,
                                    ),
                                  ),
                                ),
                              ),
                              if (_imageBusy)
                                const Center(child: CircularProgressIndicator(color: Colors.white)),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_imageBusy)
                                const CircularProgressIndicator(color: _orange)
                              else ...[
                                Icon(Icons.image_outlined, size: 42, color: RC.fg(_orange)),
                                const SizedBox(height: 8),
                                Text(
                                  t('هەڵبژاردنی وێنە'),
                                  style: TextStyle(
                                    color: RC.fg(_green),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _catNameCtrl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        fontFamily: kAppFontFamily,
                        color: RC.fg(const Color(0xFF0F172A)),
                      ),
                      decoration: InputDecoration(
                        hintText: t('...ناوی بەش بنووسە'),
                        hintStyle: TextStyle(
                          color: RC.fg(const Color(0xFF94A3B8)),
                          fontFamily: kAppFontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: RC.bg(_orange), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: RC.bg(_orange), width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _saveDraft,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RC.bg(_green),
                                foregroundColor: RC.fg(Colors.white),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                t('پاشەکەوتکردن'),
                                style: TextStyle(fontWeight: FontWeight.w900, fontFamily: kAppFontFamily),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Material(
                            color: RC.bg(_red),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _cancelDraft,
                              borderRadius: BorderRadius.circular(12),
                              child: Icon(Icons.close_rounded, color: RC.fg(Colors.white)),
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

  Widget _buildCategoryCard(String cat) {
    final img = _imageFor(cat);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Material(
          color: RC.bg(Colors.white),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
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
                  AspectRatio(
                    aspectRatio: 1.15,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (img != null && img.isNotEmpty)
                          Image.network(
                            img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: RC.bg(const Color(0xFFFFF7ED)),
                              child: Icon(Icons.restaurant_menu_rounded, color: RC.fg(_orange), size: 48),
                            ),
                          )
                        else
                          Container(
                            color: RC.bg(const Color(0xFFFFF7ED)),
                            child: Icon(Icons.restaurant_menu_rounded, color: RC.fg(_orange), size: 48),
                          ),
                        Positioned(
                          top: 10,
                          left: 10,
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
                                icon: Icons.edit_square,
                                onTap: () => _startEditCategory(cat),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Text(
                            tx(cat),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: RC.fg(const Color(0xFF0F172A)),
                              fontFamily: kAppFontFamily,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded, color: RC.fg(const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
          width: 34,
          height: 34,
          child: Icon(icon, color: RC.fg(Colors.white), size: 18),
        ),
      ),
    );
  }

  Widget _buildCategoryDetail(double padH, String cat) {
    final products = widget.products.where((p) => p.category.trim() == cat.trim()).toList();
    final img = _imageFor(cat);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 12, padH, 10),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Material(
                      color: RC.bg(const Color(0xFFFFF7ED)),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _openedCategory = null),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.arrow_forward_rounded, color: RC.fg(_orange), size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (img != null && img.isNotEmpty)
                      ClipOval(
                        child: Image.network(img, width: 40, height: 40, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 40)),
                      )
                    else
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: RC.bg(const Color(0xFFFFF7ED)),
                        child: Icon(Icons.restaurant_menu_rounded, color: RC.fg(_orange), size: 20),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tx(cat),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: RC.fg(const Color(0xFF0F172A)),
                          fontFamily: kAppFontFamily,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _orangeActionButton(
                      label: t('زیادکردنی بەرهەم'),
                      onTap: () => _openProductForm(category: cat),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Text(
                          t('هیچ بابەتێک لەم بەشەدا نییە'),
                          style: TextStyle(
                            color: RC.fg(const Color(0xFFCBD5E1)),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(padH, 4, padH, 20),
                        itemCount: products.length,
                        itemBuilder: (_, i) => _buildProductRow(products[i]),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(const Color(0xFF0F172A)), width: 1.1),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showFullScreenImageDialog(context, imageProvider: provider, title: product.name),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(image: provider, width: 78, height: 78, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 78,
                  height: 78,
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
                const SizedBox(height: 8),
                Row(
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
                    const Spacer(),
                    InkWell(
                      onTap: () => _openProductForm(category: product.category, existing: product),
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductForm({required String category, Product? existing}) async {
    final isEdit = existing != null;
    final nameKu = TextEditingController(text: existing?.name ?? '');
    final nameAr = TextEditingController();
    final desc = TextEditingController(text: existing?.description ?? '');
    final price = TextEditingController(text: (existing?.price.toInt() ?? 0).toString());
    final discount = TextEditingController(
      text: (existing?.discountPrice?.toInt() ?? 0).toString(),
    );
    final prep = TextEditingController(text: '0');
    final delivery = TextEditingController(text: '0');
    String? imageUrl = existing?.imageUrl;
    Uint8List? previewBytes;
    var imageBusy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            Future<void> pickImage() async {
              final source = await _showImageSourceSheet();
              if (source == null) return;
              final picker = ImagePicker();
              final file = await picker.pickImage(source: source);
              if (file == null) return;
              setSheet(() => imageBusy = true);
              try {
                final raw = await file.readAsBytes();
                final compressed = await ImageCompressService.compressForUpload(
                  name: file.name.isNotEmpty ? file.name : 'product.jpg',
                  bytes: Uint8List.fromList(raw),
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

            InputDecoration fieldDeco() => InputDecoration(
                  filled: true,
                  fillColor: RC.bg(const Color(0xFFF1F5F9)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                );

            Widget labeledField(String label, TextEditingController c, {int maxLines = 1, TextInputType? type}) {
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
                    style: TextStyle(fontWeight: FontWeight.w700, fontFamily: kAppFontFamily),
                    decoration: fieldDeco(),
                  ),
                ],
              );
            }

            final bottom = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
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
                          TextButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: Text(
                              t('داخستن'),
                              style: TextStyle(
                                color: RC.fg(_red),
                                fontWeight: FontWeight.w900,
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                    width: 64,
                                    height: 64,
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
                                    (imageUrl != null && imageUrl!.isNotEmpty) ? t('گۆڕینی وێنە') : t('هەڵبژاردنی وێنە'),
                                    textAlign: TextAlign.left,
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
                      labeledField(t('وەسف'), desc, maxLines: 2),
                      const SizedBox(height: 10),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(child: labeledField(t('نرخ'), price, type: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: labeledField(t('داشکان'), discount, type: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: labeledField(t('کاتی پێچوون (خولەک)'), prep, type: TextInputType.number),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: labeledField(t('نرخی گەیاندن'), delivery, type: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isEdit)
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            backgroundColor: RC.bg(const Color(0xFFF1F5F9)),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            t('زیادکردنی تایبەتمەندی +'),
                            style: TextStyle(
                              color: RC.fg(const Color(0xFF334155)),
                              fontWeight: FontWeight.w800,
                              fontFamily: kAppFontFamily,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            flex: isEdit ? 3 : 1,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  final n = nameKu.text.trim();
                                  final p = double.tryParse(price.text.trim()) ?? 0;
                                  final d = double.tryParse(discount.text.trim()) ?? 0;
                                  if (n.isEmpty || p <= 0) return;
                                  final product = Product(
                                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                    name: n,
                                    category: category,
                                    price: p,
                                    costPrice: existing?.costPrice ??
                                        (p > 1 ? (p - 1).clamp(0, p - 1).toDouble() : 0),
                                    discountPrice: d > 0 && d < p ? d : null,
                                    description: desc.text.trim().isEmpty ? null : desc.text.trim(),
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
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 50,
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
    discount.dispose();
    prep.dispose();
    delivery.dispose();
  }
}
