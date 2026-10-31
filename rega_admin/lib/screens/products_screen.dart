import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProductsScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const ProductsScreen({super.key, required this.api, required this.lang});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
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

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
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
    final discountCtrl = TextEditingController(text: existing?['discount_price']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: existing?['image_url']?.toString() ?? '');

    int? storeId = existing?['store_id'] as int? ??
        _storeFilter ??
        (_stores.isNotEmpty ? (_stores.first as Map<String, dynamic>)['id'] as int : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'دەستکاریکردنی بەرهەم' : 'زیادکردنی بەرهەمی نوێ'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: storeId,
                    decoration: const InputDecoration(labelText: 'فرۆشگا *'),
                    items: _stores.map((s) {
                      final m = s as Map<String, dynamic>;
                      return DropdownMenuItem<int>(
                        value: m['id'] as int,
                        child: Text(m['name_ku']?.toString() ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => storeId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameKuCtrl,
                    decoration: const InputDecoration(labelText: 'ناوی بەرهەم (کوردی) *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameEnCtrl,
                    decoration: const InputDecoration(labelText: 'ناوی بەرهەم (English)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'نرخی ئاسایی (د.ع) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: discountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'نرخی داشکاندن (د.ع)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descKuCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'وەسفی بەرهەم (کوردی)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descArCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'وەسفی بەرهەم (عەرەبی)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imgCtrl,
                    decoration: const InputDecoration(labelText: 'بەستەری وێنەی بەرهەم (Image URL)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
            ElevatedButton(
              onPressed: () async {
                final price = int.tryParse(priceCtrl.text.trim());
                if (storeId == null || nameKuCtrl.text.trim().isEmpty || price == null) {
                  _showSnack('تکایە ناوی بەرهەم و نرخ بنووسە', error: true);
                  return;
                }
                final disc = int.tryParse(discountCtrl.text.trim());
                final payload = <String, dynamic>{
                  'store_id': storeId,
                  'name_ku': nameKuCtrl.text.trim(),
                  'name_en': nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
                  'description_ku': descKuCtrl.text.trim().isEmpty ? null : descKuCtrl.text.trim(),
                  'description_ar': descArCtrl.text.trim().isEmpty ? null : descArCtrl.text.trim(),
                  'price': price,
                  'discount_price': disc,
                  if (imgCtrl.text.trim().isNotEmpty) 'image_url': imgCtrl.text.trim(),
                };
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await widget.api.updateProduct(existing['id'] as int, payload);
                    _showSnack('بەرهەم نوێکرایەوە');
                  } else {
                    await widget.api.createProduct(payload);
                    _showSnack('بەرهەمی نوێ زیادکرا');
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
            title: AppStrings.tr('nav_products', widget.lang),
            subtitle: 'کۆنترۆڵکردنی تەواوی مێنۆ و کاڵاکانی فرۆشگاکان، نرخ و داشکاندنەکان',
            trailing: ElevatedButton.icon(
              onPressed: () => _showProductDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('زیادکردنی بەرهەمی نوێ'),
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
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'گەڕان بە ناوی خواردن یان کاڵا...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: _storeFilter,
                  decoration: const InputDecoration(labelText: 'فلتەری فرۆشگا'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('هەموو فرۆشگاکان')),
                    ..._stores.map((s) {
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
              FilterChip(
                selected: _onlyDiscounted,
                selectedColor: RegaColors.crimson.withValues(alpha: 0.15),
                label: const Text('تەنها داشکێنراوەکان 🔥'),
                onSelected: (v) {
                  setState(() => _onlyDiscounted = v);
                  _load();
                },
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
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 340,
                        mainAxisExtent: 265,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (_, idx) {
                        final p = _products[idx] as Map<String, dynamic>;
                        final store = p['store'] as Map<String, dynamic>?;
                        final price = (p['price'] as num?)?.toInt() ?? 0;
                        final disc = (p['discount_price'] as num?)?.toInt();
                        final hasDiscount = disc != null && disc > 0 && disc < price;
                        final avail = p['is_available'] == true;

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
                                    color: const Color(0xFF1E293B),
                                    child: p['image_url'] != null
                                        ? Image.network(
                                            p['image_url'].toString(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(Icons.fastfood_rounded, color: Colors.white54, size: 36),
                                          )
                                        : const Icon(Icons.fastfood_rounded, color: Colors.white54, size: 36),
                                  ),
                                  if (hasDiscount)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: RegaColors.crimson,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'داشکاندن',
                                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
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
                                            p['name_ku']?.toString() ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '🏪 ${store?['name_ku'] ?? ''} • فرۆشراو: ${p['sold_count'] ?? 0}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                formatIqd(hasDiscount ? disc : price, lang: widget.lang),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: RegaColors.emeraldDark,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              if (hasDiscount) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  formatIqd(price, lang: widget.lang),
                                                  style: const TextStyle(
                                                    decoration: TextDecoration.lineThrough,
                                                    color: RegaColors.crimson,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Switch(
                                                value: avail,
                                                onChanged: (_) async {
                                                  await widget.api.toggleProductAvailability(p['id'] as int);
                                                  _load();
                                                },
                                              ),
                                              Text(
                                                avail ? 'بەردەستە' : 'نەماوە',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: avail ? RegaColors.emeraldDark : RegaColors.crimson,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 19),
                                                onPressed: () => _showProductDialog(existing: p),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 19, color: RegaColors.crimson),
                                                onPressed: () async {
                                                  await widget.api.deleteProduct(p['id'] as int);
                                                  _showSnack('بەرهەم سڕایەوە');
                                                  _load();
                                                },
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
                    ),
        ),
      ],
    );
  }
}

