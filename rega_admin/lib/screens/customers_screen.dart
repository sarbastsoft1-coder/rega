import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CustomersScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const CustomersScreen({super.key, required this.api, required this.lang});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<dynamic> _customers = [];

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
      final res = await widget.api.getCustomers(search: _searchCtrl.text.trim());
      if (mounted) setState(() => _customers = res);
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

  void _showCustomerFormDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final passCtrl = TextEditingController(text: isEdit ? '' : 'password123');
    bool isActive = existing?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'دەستکاریکردنی کڕیار' : 'زیادکردنی کڕیاری نوێ'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'ناوی تەواو *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'ژمارەی مۆبایل *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'ئیمەیڵ (ئارەزوومەندانە)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEdit ? 'وشەی نهێنی نوێ (ئەگەر دەتەوێت بیگۆڕیت)' : 'وشەی نهێنی *',
                    ),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      title: const Text('هەژماری چالاکە'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.tr('cancel', widget.lang)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  _showSnack('تکایە ناو و مۆبایل پڕبکەرەوە', error: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final payload = <String, dynamic>{
                    'name': name,
                    'phone': phone,
                    'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  };
                  if (passCtrl.text.trim().isNotEmpty) {
                    payload['password'] = passCtrl.text.trim();
                  }
                  if (isEdit) {
                    payload['is_active'] = isActive;
                    await widget.api.updateCustomer(existing['id'] as int, payload);
                    _showSnack('زانیاری کڕیار بە سەرکەوتوویی نوێکرایەوە ✅');
                  } else {
                    await widget.api.createCustomer(payload);
                    _showSnack('کڕیاری نوێ زیادکرا ✅');
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

  Future<void> _showCustomerDetailsDialog(Map<String, dynamic> c) async {
    try {
      final detail = await widget.api.getCustomerDetails(c['id'] as int);
      if (!mounted) return;
      final addresses = detail['addresses'] as List<dynamic>? ?? [];
      final orders = detail['customer_orders'] as List<dynamic>? ?? [];

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('پڕۆفایلی کڕیار — ${detail['name'] ?? ''}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📞 مۆبایل: ${detail['phone'] ?? '-'}'),
                  Text('✉️ ئیمەیڵ: ${detail['email'] ?? '-'}'),
                  const Divider(height: 20),
                  const Text('📍 ناونیشانە تۆمارکراوەکان لە کەلار:', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (addresses.isEmpty)
                    const Text('هیچ ناونیشانێک تۆمار نەکراوە')
                  else
                    ...addresses.map((a) {
                      final m = a as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• [${m['label'] ?? 'ماڵەوە'}] ${m['address_line'] ?? ''} (${m['neighborhood']?['name_ku'] ?? ''})'),
                      );
                    }),
                  const Divider(height: 20),
                  Text('🛍️ داواکارییەکان (${orders.length}):', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (orders.isEmpty)
                    const Text('هیچ داواکارییەک نییە')
                  else
                    ...orders.map((o) {
                      final m = o as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${m['order_number']} • 🏪 ${m['store']?['name_ku'] ?? '-'}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        trailing: Text(formatIqd(m['total_amount'] as num?, lang: widget.lang),
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
          ],
        ),
      );
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _confirmDeleteCustomer(Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سڕینەوەی کڕیار — ${c['name']}'),
        content: const Text('ئایا دڵنیایت لە سڕینەوە یان ڕاگرتنی ئەم کڕیارە؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteCustomer(c['id'] as int);
                _showSnack('کڕیارەکە بە سەرکەوتوویی سڕایەوە یان ڕاگیرا ✅');
                _load();
              } catch (e) {
                _showSnack(e.toString(), error: true);
              }
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
          child: SectionHeader(
            title: AppStrings.tr('nav_customers', widget.lang),
            subtitle: 'بەڕێوەبردن، دەستکاریکردن و زیادکردنی کڕیارانی ئەپی REGA، ناونیشان و خەرجی کڕیار',
            trailing: ElevatedButton.icon(
              onPressed: () => _showCustomerFormDialog(),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('زیادکردنی کڕیار'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 320,
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'گەڕان بە ناوی کڕیار یان مۆبایل...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                      itemCount: _customers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) {
                        final c = _customers[idx] as Map<String, dynamic>;
                        final addresses = c['addresses'] as List<dynamic>? ?? [];
                        final firstAddr = addresses.isNotEmpty
                            ? (addresses.first as Map<String, dynamic>)['address_line']?.toString()
                            : 'بێ ناونیشان';
                        final active = c['is_active'] == true;

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: RegaColors.gold.withValues(alpha: 0.2),
                              child: Text(
                                (c['name']?.toString() ?? 'U').characters.first,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                            ),
                            title: Text(
                              '${c['name'] ?? ''}  •  📞 ${c['phone'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text('📍 $firstAddr  •  🛍️ ${c['customer_orders_count'] ?? 0} داواکاری'),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  formatIqd(c['total_spent'] as num?, lang: widget.lang),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: RegaColors.emeraldDark,
                                    fontSize: 14,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  tooltip: 'بینینی زانیاری',
                                  onPressed: () => _showCustomerDetailsDialog(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18, color: RegaColors.blue),
                                  tooltip: 'دەستکاریکردنی کڕیار',
                                  onPressed: () => _showCustomerFormDialog(existing: c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: RegaColors.crimson),
                                  tooltip: 'سڕینەوە',
                                  onPressed: () => _confirmDeleteCustomer(c),
                                ),
                                FilterChip(
                                  selected: active,
                                  selectedColor: RegaColors.emerald.withValues(alpha: 0.2),
                                  label: Text(active ? 'چالاک' : 'ڕاگیراو'),
                                  onSelected: (_) async {
                                    await widget.api.toggleCustomerActive(c['id'] as int);
                                    _load();
                                  },
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
