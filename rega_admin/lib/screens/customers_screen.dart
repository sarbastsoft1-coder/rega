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

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'password123');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زیادکردنی کڕیاری نوێ'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ناوی تەواو *')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'ژمارەی مۆبایل *')),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'وشەی نهێنی')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await widget.api.createCustomer({
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'password': passCtrl.text.trim(),
              });
              _load();
            },
            child: Text(AppStrings.tr('save', widget.lang)),
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
            subtitle: 'بەڕێوەبردنی کڕیارانی ئەپی REGA، ناونیشانەکان و کۆی خەرجی هەر کڕیارێک',
            trailing: ElevatedButton.icon(
              onPressed: _showAddCustomerDialog,
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatIqd(c['total_spent'] as num?, lang: widget.lang),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: RegaColors.emeraldDark,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 14),
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

