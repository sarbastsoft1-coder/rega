import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'products_screen.dart';
import 'stores_screen.dart';

class VendorPartScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final VoidCallback? onDataChanged;

  const VendorPartScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onDataChanged,
  });

  @override
  State<VendorPartScreen> createState() => _VendorPartScreenState();
}

class _VendorPartScreenState extends State<VendorPartScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _autoRefreshTimer;

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _kpis = {};
  List<dynamic> _stores = [];
  List<dynamic> _kitchenOrders = [];
  List<dynamic> _vendorPayouts = [];
  int? _selectedStoreFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.api.getEcosystemHubs(),
        widget.api.getPayouts(recipientType: 'vendor'),
      ]);
      final hubs = results[0] as Map<String, dynamic>;
      final vp = hubs['vendor_part'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _kpis = vp['kpis'] as Map<String, dynamic>? ?? {};
        _stores = vp['stores'] as List<dynamic>? ?? [];
        _kitchenOrders = vp['kitchen_orders'] as List<dynamic>? ?? [];
        _vendorPayouts = results[1] as List<dynamic>;
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e.toString());
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
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

  Future<void> _updateVendorOrderStatus(int orderId, String nextStatus) async {
    try {
      await widget.api.updateOrderStatus(orderId, nextStatus);
      _showSnack('بارودۆخی داواکاری لە چێشتخانە نوێکرایەوە ✅');
      widget.onDataChanged?.call();
      _load(silent: true);
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _showHandoverPinDialog(Map<String, dynamic> order) {
    final pinCtrl = TextEditingController(text: order['handover_pin']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('پشتڕاستکردنەوەی کۆدی شۆفێر — ${order['order_number']}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'کاتێک شۆفێر دەگاتە فرۆشگا، کۆدی ٤ ژمارەیی ڕادەستکردن (Handover PIN) دڵنیا دەکرێتەوە:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 10),
                decoration: const InputDecoration(labelText: 'کۆدی ٤ ژمارەیی شۆفێر (PIN)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.length != 4) return;
              Navigator.pop(ctx);
              try {
                await widget.api.verifyHandoverPin(order['id'] as int, pin);
                _showSnack('داواکارییەکە بە سەرکەوتوویی ڕادەستی شۆفێر کرا ✅');
                widget.onDataChanged?.call();
                _load(silent: true);
              } catch (e) {
                _showSnack(e.toString(), error: true);
              }
            },
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: const Text('ڕادەستکردن بە شۆفێر'),
          ),
        ],
      ),
    );
  }

  void _showVendorPayoutDialog(Map<String, dynamic> store) {
    final netProfit = (store['net_profit'] as num?)?.toInt() ?? 0;
    final amountCtrl = TextEditingController(text: netProfit > 0 ? '$netProfit' : '25000');
    final noteCtrl = TextEditingController(text: 'پاکتاوی داهاتی فرۆشگای ${store['name_ku']}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تۆمارکردنی حەواڵەی فرۆشیار — ${store['name_ku']}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'بڕی پارەی خەرجکراو (د.ع) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'تێبینی پاکتاوکردن'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('پاشگەزبوونەوە')),
          ElevatedButton.icon(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              Navigator.pop(ctx);
              try {
                await widget.api.createPayout({
                  'recipient_type': 'vendor',
                  'store_id': store['id'],
                  'user_id': store['owner']?['id'],
                  'amount': amount,
                  'payment_method': 'cash',
                  'status': 'completed',
                  'notes': noteCtrl.text.trim(),
                });
                _showSnack('پاکتاوی دارایی فرۆشیار لە داتابەیس تۆمارکرا ✅');
                _load(silent: true);
              } catch (e) {
                _showSnack(e.toString(), error: true);
              }
            },
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: const Text('خەرجکردن و تۆمارکردن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Top Vendor Hub Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEA580C), Color(0xFFD97706)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: RegaColors.orange.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بەشی فرۆشیاران و چێشتخانەکان (REGA Vendor Hub)',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'بەستراوەتەوە بە ئەپی فرۆشیاران (rega_froshyar) و PostgreSQL بە شێوەی ڕاستەوخۆ',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _load(),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: Text('هاوکاتکردن (${_kpis['online_stores'] ?? 0}/${_kpis['total_stores'] ?? 0} ئۆنلاین)'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                indicatorWeight: 3.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'پوختە و داهات'),
                  Tab(
                    icon: const Icon(Icons.soup_kitchen_rounded, size: 18),
                    text: 'چێشتخانەی زیندوو (${_kpis['active_kitchen_orders'] ?? 0})',
                  ),
                  const Tab(icon: Icon(Icons.store_mall_directory_rounded, size: 18), text: 'فرۆشگا و هەژمارەکان'),
                  const Tab(icon: Icon(Icons.restaurant_menu_rounded, size: 18), text: 'مێنۆ و بەرهەمەکان'),
                  const Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'حەواڵە و پاکتاو'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(isDark),
                        _buildKitchenQueueTab(isDark),
                        StoresScreen(api: widget.api, lang: widget.lang),
                        ProductsScreen(api: widget.api, lang: widget.lang),
                        _buildVendorPayoutsTab(),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      children: [
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 2.35,
          children: [
            StatKpiCard(
              title: 'فرۆشگا چالاک و ئۆنلاینەکان',
              value: '${_kpis['online_stores'] ?? 0} / ${_kpis['total_stores'] ?? 0}',
              subtitle: '${_kpis['pending_approval_stores'] ?? 0} چاوەڕوانی پەسەندکردن',
              icon: Icons.storefront_rounded,
              accentColor: RegaColors.orange,
            ),
            StatKpiCard(
              title: 'کۆی کاڵاکانی مێنۆ',
              value: '${_kpis['total_products'] ?? 0}',
              subtitle: '${_kpis['unavailable_products'] ?? 0} نابەردەست',
              icon: Icons.fastfood_rounded,
              accentColor: RegaColors.blue,
            ),
            StatKpiCard(
              title: 'داواکاری چالاک لە چێشتخانە',
              value: '${_kpis['active_kitchen_orders'] ?? 0}',
              subtitle: 'ڕاستەوخۆ',
              icon: Icons.soup_kitchen_rounded,
              accentColor: RegaColors.purple,
            ),
            StatKpiCard(
              title: 'کۆی فرۆشی فرۆشگاکان',
              value: formatIqd(_kpis['gross_vendor_sales'] as num?, lang: widget.lang),
              subtitle: 'پێش کۆمیسیۆن',
              icon: Icons.point_of_sale_rounded,
              accentColor: RegaColors.emerald,
            ),
            StatKpiCard(
              title: 'قازانجی کۆمیسیۆنی ڕێگا',
              value: formatIqd(_kpis['platform_commission'] as num?, lang: widget.lang),
              subtitle: 'پشکی پلاتفۆرم',
              icon: Icons.percent_rounded,
              accentColor: RegaColors.goldDark,
            ),
            StatKpiCard(
              title: 'صافی شایستەی فرۆشیاران',
              value: formatIqd(_kpis['vendor_net_profit'] as num?, lang: widget.lang),
              subtitle: 'خەرجکراو: ${formatIqd(_kpis['vendor_payouts_paid'] as num?, lang: widget.lang)}',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: RegaColors.emeraldDark,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'لیستی فرۆشگاکان، هەژماری فرۆشیار و داهاتی ڕاستەوخۆ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                ..._stores.map((raw) {
                  final s = raw as Map<String, dynamic>;
                  final owner = s['owner'] as Map<String, dynamic>?;
                  final isOnline = s['is_online'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundColor: isOnline
                                  ? RegaColors.emerald.withValues(alpha: 0.16)
                                  : Colors.grey.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.store_rounded,
                                color: isOnline ? RegaColors.emeraldDark : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s['name_ku'] ?? ''} • (${s['commission_rate'] ?? 12}%)',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                                Text(
                                  '👤 خاوەن: ${owner?['name'] ?? '-'}  |  📱 چوونەژوورەوە: ${owner?['phone'] ?? s['phone'] ?? '-'}  |  🍱 ${s['products_count'] ?? 0} بەرهەم',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'صافی: ${formatIqd(s['net_profit'] as num?, lang: widget.lang)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark),
                                ),
                                Text(
                                  'کۆمیسیۆن: ${formatIqd(s['total_commission'] as num?, lang: widget.lang)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showVendorPayoutDialog(s),
                              icon: const Icon(Icons.payments_outlined, size: 16),
                              label: const Text('پاکتاوکردن'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKitchenQueueTab(bool isDark) {
    final filtered = _selectedStoreFilter == null
        ? _kitchenOrders
        : _kitchenOrders.where((o) => (o as Map<String, dynamic>)['store_id'] == _selectedStoreFilter).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedStoreFilter,
                  decoration: const InputDecoration(labelText: 'فلتەرکردن بەپێی فرۆشگا'),
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
                  onChanged: (v) => setState(() => _selectedStoreFilter = v),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, idx) {
              final o = filtered[idx] as Map<String, dynamic>;
              final status = o['status']?.toString() ?? 'pending';
              final items = o['items'] as List<dynamic>? ?? [];
              final itemsSummary = items
                  .map((it) => '${(it as Map<String, dynamic>)['quantity']}x ${it['product_name']}')
                  .join(' ، ');

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${o['order_number']}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              const SizedBox(width: 10),
                              StatusBadge(status: status, lang: widget.lang),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: RegaColors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '🔑 کۆدی شۆفێر (PIN): ${o['handover_pin'] ?? '----'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: RegaColors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            formatIqd(o['total_amount'] as num?, lang: widget.lang),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: RegaColors.emeraldDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🏪 ${o['store']?['name_ku'] ?? '-'}  •  👤 کڕیار: ${o['customer_name'] ?? '-'} (${o['customer_phone'] ?? '-'})  •  🛵 شۆفێر: ${o['driver']?['name'] ?? 'دیاری نەکراوە'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 6),
                      Text('🍲 پێکهاتەکان: $itemsSummary', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status == 'pending')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RegaColors.blue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _updateVendorOrderStatus(o['id'] as int, 'preparing'),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                              label: const Text('قبوڵکردن و ئامادەکردن'),
                            ),
                          if (status == 'pending' || status == 'preparing')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _updateVendorOrderStatus(o['id'] as int, 'ready'),
                              icon: const Icon(Icons.done_all_rounded, size: 17),
                              label: const Text('ئامادەیە بۆ شۆفێر'),
                            ),
                          if (status == 'ready' || status == 'preparing')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RegaColors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _showHandoverPinDialog(o),
                              icon: const Icon(Icons.pin_rounded, size: 17),
                              label: const Text('ڕادەستکردن بە شۆفێر (PIN)'),
                            ),
                          if (status == 'pending')
                            OutlinedButton.icon(
                              onPressed: () => _updateVendorOrderStatus(o['id'] as int, 'rejected'),
                              icon: const Icon(Icons.close_rounded, size: 17, color: RegaColors.crimson),
                              label: const Text('ڕەتکردنەوە', style: TextStyle(color: RegaColors.crimson)),
                            ),
                        ],
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

  Widget _buildVendorPayoutsTab() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      itemCount: _vendorPayouts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final p = _vendorPayouts[idx] as Map<String, dynamic>;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: RegaColors.orange.withValues(alpha: 0.14),
              child: const Icon(Icons.receipt_long_rounded, color: RegaColors.orange),
            ),
            title: Text(
              '${p['reference_number'] ?? ''}  •  🏪 ${p['store']?['name_ku'] ?? p['user']?['name'] ?? 'فرۆشیار'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${p['notes'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatIqd(p['amount'] as num?, lang: widget.lang),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark),
                ),
                const SizedBox(width: 10),
                StatusBadge(status: p['status']?.toString() ?? 'completed', lang: widget.lang),
              ],
            ),
          ),
        );
      },
    );
  }
}
