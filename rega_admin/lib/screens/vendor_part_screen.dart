import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    final activeKitchenCount = (_kpis['active_kitchen_orders'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        // Top Vendor Hub Brand Header (Froshyar Style)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEA580C).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Wrap(
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'REGA FROSHYAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_kpis['online_stores'] ?? 0} ئۆنلاین',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'بەشی بەڕێوەبردنی فرۆشیاران و چێشتخانەکان — هاوکات لەگەڵ rega_froshyar',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _load(),
                icon: const Icon(Icons.sync_rounded, size: 17),
                label: const Text('هاوکاتکردنی داتا', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
        ),

        // Modern Froshyar Dock Navigation Bar
        _buildFroshyarNavBar(isDark: isDark, activeKitchenCount: activeKitchenCount),

        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildKitchenQueueTab(isDark),
                        ProductsScreen(api: widget.api, lang: widget.lang),
                        _buildOverviewTab(isDark),
                        StoresScreen(api: widget.api, lang: widget.lang),
                        _buildVendorPayoutsTab(),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildFroshyarNavBar({required bool isDark, required int activeKitchenCount}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFroshyarNavItem(
              index: 0,
              activeIcon: Icons.local_mall_rounded,
              inactiveIcon: Icons.local_mall_outlined,
              label: 'داواکارییەکان',
              subtitle: 'چێشتخانەی زیندوو',
              badgeCount: activeKitchenCount,
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildFroshyarNavItem(
              index: 1,
              activeIcon: Icons.restaurant_menu_rounded,
              inactiveIcon: Icons.restaurant_menu_outlined,
              label: 'مێنۆ و بەرهەم',
              subtitle: '${_kpis['total_products'] ?? 0} کاڵا',
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildFroshyarNavItem(
              index: 2,
              activeIcon: Icons.auto_graph_rounded,
              inactiveIcon: Icons.auto_graph_outlined,
              label: 'داهاتی فرۆشیار',
              subtitle: 'پوختە و ئامار',
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildFroshyarNavItem(
              index: 3,
              activeIcon: Icons.tune_rounded,
              inactiveIcon: Icons.tune_outlined,
              label: 'فرۆشگاکان و هەژمار',
              subtitle: '${_kpis['total_stores'] ?? 0} فرۆشگا',
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildFroshyarNavItem(
              index: 4,
              activeIcon: Icons.account_balance_wallet_rounded,
              inactiveIcon: Icons.account_balance_wallet_outlined,
              label: 'حەواڵە و پاکتاو',
              subtitle: 'باڵانسی فرۆشیاران',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFroshyarNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    String? subtitle,
    int badgeCount = 0,
    required bool isDark,
  }) {
    final bool isSelected = _tabController.index == index;
    const activeColor = Color(0xFFEA580C);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _tabController.animateTo(index);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFFEA580C).withValues(alpha: 0.2) : const Color(0xFFFFF7ED))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFEA580C).withValues(alpha: 0.35) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    isSelected ? activeIcon : inactiveIcon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33EF4444), blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: isSelected ? activeColor : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  child: Text(label),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected ? activeColor.withValues(alpha: 0.8) : inactiveColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'لیستی فرۆشگاکان، هەژماری فرۆشیار و داهاتی ڕاستەوخۆ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RegaColors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _tabController.animateTo(3),
                      icon: const Icon(Icons.add_business_rounded, size: 17),
                      label: const Text('زیادکردنی فرۆشگا'),
                    ),
                  ],
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
                              onPressed: () => _tabController.animateTo(3),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('دەستکاریکردن'),
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
                          if (status == 'ready' || status == 'preparing') ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RegaColors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _showHandoverPinDialog(o),
                              icon: const Icon(Icons.pin_rounded, size: 17),
                              label: const Text('ڕادەستکردن بە شۆفێر (PIN)'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _updateVendorOrderStatus(o['id'] as int, 'picked_up'),
                              icon: const Icon(Icons.check_rounded, size: 17),
                              label: const Text('ڕادەستکردنی دەستبەجێ'),
                            ),
                          ],
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
