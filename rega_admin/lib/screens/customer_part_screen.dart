import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'catalog_zones_screen.dart';
import 'customers_screen.dart';
import 'live_radar_dialog.dart';
import 'marketing_screen.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
class CustomerPartScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final VoidCallback? onDataChanged;

  const CustomerPartScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onDataChanged,
  });

  @override
  State<CustomerPartScreen> createState() => _CustomerPartScreenState();
}

class _CustomerPartScreenState extends State<CustomerPartScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _autoRefreshTimer;

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _kpis = {};
  List<dynamic> _vipCustomers = [];
  List<dynamic> _recentOrders = [];
  List<dynamic> _stores = [];
  List<dynamic> _products = [];
  List<dynamic> _neighborhoods = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
        widget.api.getStores(),
        widget.api.getProducts(),
        widget.api.getNeighborhoods(),
      ]);
      final hubs = results[0] as Map<String, dynamic>;
      final cp = hubs['customer_part'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _kpis = cp['kpis'] as Map<String, dynamic>? ?? {};
        _vipCustomers = cp['vip_customers'] as List<dynamic>? ?? [];
        _recentOrders = cp['recent_orders'] as List<dynamic>? ?? [];
        _stores = results[1] as List<dynamic>;
        _products = results[2] as List<dynamic>;
        _neighborhoods = results[3] as List<dynamic>;
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
        content: Text(tx(msg)),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  Future<void> _showCustomerDetailsDialog(Map<String, dynamic> customer) async {
    try {
      final detail = await widget.api.getCustomerDetails(customer['id'] as int);
      if (!mounted) return;
      final addresses = detail['addresses'] as List<dynamic>? ?? [];
      final orders = detail['customer_orders'] as List<dynamic>? ?? [];

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tx('پڕۆفایلی کڕیار — ${detail['name'] ?? ''}')),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width * 0.92).clamp(280.0, 560.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tx('📞 مۆبایل: ${detail['phone'] ?? '-'}  |  ✉️ ئیمەیڵ: ${detail['email'] ?? '-'}')),
                  const Divider(height: 24),
                  Text(tx('📍 ناونیشانە تۆمارکراوەکان لە کەلار:'), style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (addresses.isEmpty)
                    Text(tx('هیچ ناونیشانێک تۆمار نەکراوە'))
                  else
                    ...addresses.map((a) {
                      final m = a as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(tx('• [${m['label'] ?? 'ماڵەوە'}] ${m['address_line'] ?? ''} (${m['neighborhood']?['name_ku'] ?? ''})')),
                      );
                    }),
                  const Divider(height: 24),
                  Text(tx('🛍️ دوایین داواکارییەکان (${orders.length}):'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...orders.map((o) {
                    final m = o as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(tx('${m['order_number']}  •  🏪 ${m['store']?['name_ku'] ?? '-'}'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(tx('📍 ${m['delivery_address'] ?? ''}')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tx(formatIqd(m['total_amount'] as num?, lang: widget.lang)), style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(width: 8),
                          StatusBadge(status: m['status']?.toString() ?? 'pending', lang: widget.lang),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('داخستن'))),
          ],
        ),
      );
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _showCreateCustomerOrderDialog() {
    if (_stores.isEmpty) {
      _showSnack('هیچ فرۆشگایەک بەردەست نییە', error: true);
      return;
    }

    int? selectedCustomerId = _vipCustomers.isNotEmpty
        ? (_vipCustomers.first as Map<String, dynamic>)['id'] as int
        : null;
    int selectedStoreId = (_stores.first as Map<String, dynamic>)['id'] as int;
    int? selectedZoneId = _neighborhoods.isNotEmpty
        ? (_neighborhoods.first as Map<String, dynamic>)['id'] as int
        : null;

    final addrCtrl = TextEditingController(text: tx('کەلار - گەڕەکی شەهیدان، نزیک قوتابخانەی کەلار'));
    final couponCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = 'cash';
    final Map<int, int> cartQty = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final storeProducts = _products
              .where((p) => (p as Map<String, dynamic>)['store_id'] == selectedStoreId)
              .toList();

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            title: Text(tx('تۆمارکردنی داواکاری ڕاستەوخۆ بۆ کڕیار (Live PostgreSQL Order)')),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 580),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: selectedCustomerId,
                      decoration: InputDecoration(labelText: tx('هەڵبژاردنی کڕیار *')),
                      items: _vipCustomers.map((c) {
                        final m = c as Map<String, dynamic>;
                        return DropdownMenuItem<int?>(
                          value: m['id'] as int,
                          child: Text(tx('${m['name']} (${m['phone']})')),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedCustomerId = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedStoreId,
                            decoration: InputDecoration(labelText: tx('فرۆشگا / چێشتخانە *')),
                            items: _stores.map((s) {
                              final m = s as Map<String, dynamic>;
                              return DropdownMenuItem<int>(
                                value: m['id'] as int,
                                child: Text(tx(m['name_ku']?.toString() ?? '')),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setDialogState(() {
                                selectedStoreId = v;
                                cartQty.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: selectedZoneId,
                            decoration: InputDecoration(labelText: tx('گەڕەکی کەلار')),
                            items: _neighborhoods.map((z) {
                              final m = z as Map<String, dynamic>;
                              return DropdownMenuItem<int?>(
                                value: m['id'] as int,
                                child: Text(tx('${m['name_ku']} (${m['delivery_fee']} د.ع)')),
                              );
                            }).toList(),
                            onChanged: (v) => setDialogState(() => selectedZoneId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addrCtrl,
                      decoration: InputDecoration(labelText: tx('ناونیشانی تەواوی گەیاندن *')),
                    ),
                    const SizedBox(height: 14),
                    Text(tx('🍱 هەڵبژاردنی بەرهەمەکان:'), style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (storeProducts.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(tx('ئەم فرۆشگایە هیچ بەرهەمێکی تێدا نییە')),
                      )
                    else
                      ...storeProducts.map((raw) {
                        final p = raw as Map<String, dynamic>;
                        final pid = p['id'] as int;
                        final qty = cartQty[pid] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: RC.bg(Colors.grey).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tx('${p['name_ku']} — ${formatIqd(p['discount_price'] ?? p['price'], lang: widget.lang)}'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                onPressed: qty > 0
                                    ? () => setDialogState(() {
                                          if (qty == 1) {
                                            cartQty.remove(pid);
                                          } else {
                                            cartQty[pid] = qty - 1;
                                          }
                                        })
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline_rounded),
                              ),
                              Text(tx('$qty'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              IconButton(
                                onPressed: () => setDialogState(() => cartQty[pid] = qty + 1),
                                icon: const Icon(Icons.add_circle_rounded, color: RegaColors.emeraldDark),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: tx('شێوازی پارەدان')),
                            child: Text(
                              tx('کاش لە کاتی وەرگرتن (COD)'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: RC.fg(Colors.grey.shade800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: couponCtrl,
                            decoration: InputDecoration(labelText: tx('کۆپۆنی داشکاندن (نمونە: REGA25)')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(labelText: tx('تێبینی کڕیار')),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('پاشگەزبوونەوە'))),
              ElevatedButton.icon(
                onPressed: () async {
                  if (cartQty.isEmpty) {
                    _showSnack('تکایە لانیکەم یەک بەرهەم هەڵبژێرە', error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final created = await widget.api.createAdminOrder({
                      'customer_id': selectedCustomerId,
                      'store_id': selectedStoreId,
                      'neighborhood_id': selectedZoneId,
                      'delivery_address': addrCtrl.text.trim(),
                      'payment_method': paymentMethod,
                      'coupon_code': couponCtrl.text.trim().isEmpty ? null : couponCtrl.text.trim(),
                      'customer_notes': notesCtrl.text.trim(),
                      'items': cartQty.entries
                          .map((e) => {'product_id': e.key, 'quantity': e.value})
                          .toList(),
                    });
                    _showSnack(
                      'داواکاری ${created['order_number']} تۆمارکرا ✅',
                    );
                    widget.onDataChanged?.call();
                    _load(silent: true);
                  } catch (e) {
                    _showSnack(e.toString(), error: true);
                  }
                },
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(tx('تۆمارکردن و ناردن بۆ چێشتخانە')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Customer Hub Header Banner
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(AdminBreakpoints.pagePadH(context), 18, AdminBreakpoints.pagePadH(context), 0),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [RC.bg(Color(0xFF1E293B)), RC.bg(Color(0xFF0F172A))],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: RegaColors.gold.withValues(alpha: 0.5), width: 1.4),
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
                          color: RegaColors.gold,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.shopping_bag_rounded, color: RC.fg(Color(0xFF0F172A)), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx('بەشی کڕیاران و مارکێتپڵەیس (REGA Customer Hub)'),
                            style: TextStyle(color: RegaColors.gold, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            tx('بەستراوەتەوە بە ئەپی کڕیاران (rega) • بەشەکانی سەرەکی، هەژمار، داواکاری، کۆپۆن و گەڕەکەکان'),
                            style: TextStyle(color: RC.fg(Colors.white70), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RegaColors.gold,
                          foregroundColor: RC.fg(Color(0xFF0F172A)),
                        ),
                        onPressed: _showCreateCustomerOrderDialog,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: Text(tx('داواکاری نوێ بۆ کڕیار')),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: RC.bg(Colors.white).withValues(alpha: 0.12),
                          foregroundColor: RC.fg(Colors.white),
                        ),
                        onPressed: () => _load(),
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: Text(tx('نوێکردنەوە')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: RegaColors.gold,
                indicatorWeight: 3.5,
                labelColor: RegaColors.gold,
                unselectedLabelColor: RC.fg(Colors.white70),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(icon: Icon(Icons.workspace_premium_rounded, size: 18), text: tx('پوختە و کڕیاران')),
                  Tab(
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    text: tx('داواکاری کڕیاران (${_kpis['total_customer_orders'] ?? 0})'),
                  ),
                  Tab(icon: Icon(Icons.groups_rounded, size: 18), text: tx('بەڕێوەبردنی کڕیاران')),
                  Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: tx('بەشەکانی سەرەکی ئەپ')),
                  Tab(icon: Icon(Icons.notifications_active_rounded, size: 18), text: tx('ئاگاداری بۆ کڕیار')),
                  Tab(icon: Icon(Icons.location_city_rounded, size: 18), text: tx('گەڕەکەکانی کەلار')),
                  Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: tx('کۆپۆن و ڕیکلامەکان')),
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
                        _buildVipOverviewTab(isDark),
                        _buildCustomerOrdersTab(),
                        CustomersScreen(api: widget.api, lang: widget.lang),
                        CatalogZonesScreen(
                          api: widget.api,
                          lang: widget.lang,
                          mode: CatalogZonesMode.categories,
                        ),
                        MarketingScreen(
                          api: widget.api,
                          lang: widget.lang,
                          mode: MarketingMode.notifications,
                        ),
                        CatalogZonesScreen(
                          api: widget.api,
                          lang: widget.lang,
                          mode: CatalogZonesMode.zones,
                        ),
                        MarketingScreen(api: widget.api, lang: widget.lang),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildVipOverviewTab(bool isDark) {
    return ListView(
      padding: EdgeInsets.fromLTRB(AdminBreakpoints.pagePadH(context), 8, AdminBreakpoints.pagePadH(context), 28),
      children: [
        GridView.count(
          crossAxisCount: () {
            final w = MediaQuery.sizeOf(context).width;
            if (w < AdminBreakpoints.phone) return 1;
            if (w > 1200) return 3;
            return 2;
          }(),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 2.8 : 2.35,
          children: [
            StatKpiCard(
              title: tx('کۆی کڕیارانی تۆمارکراو'),
              value: '${_kpis['total_customers'] ?? 0}',
              subtitle: tx('${_kpis['active_customers'] ?? 0} چالاک'),
              icon: Icons.groups_rounded,
              accentColor: RegaColors.goldDark,
            ),
            StatKpiCard(
              title: tx('ناونیشانەکانی کەلار'),
              value: '${_kpis['saved_addresses_count'] ?? 0}',
              subtitle: tx('تۆمارکراو لە GPS'),
              icon: Icons.pin_drop_rounded,
              accentColor: RegaColors.blue,
            ),
            StatKpiCard(
              title: tx('کۆی خەرجی کڕیاران (GMV)'),
              value: formatIqd(_kpis['total_customer_gmv'] as num?, lang: widget.lang),
              subtitle: tx('${_kpis['total_customer_orders'] ?? 0} داواکاری'),
              icon: Icons.shopping_bag_rounded,
              accentColor: RegaColors.emeraldDark,
            ),
            StatKpiCard(
              title: tx('کۆپۆنە چالاکەکان'),
              value: '${_kpis['active_coupons_count'] ?? 0}',
              subtitle: tx('ئامادە بۆ کڕیار'),
              icon: Icons.discount_rounded,
              accentColor: RegaColors.purple,
            ),
            StatKpiCard(
              title: tx('بانەر و ڕیکلامی سەرەکی'),
              value: '${_kpis['active_banners_count'] ?? 0}',
              subtitle: tx('لە شاشەی سەرەکی ئەپ'),
              icon: Icons.burst_mode_rounded,
              accentColor: RegaColors.orange,
            ),
            StatKpiCard(
              title: tx('هەژماری ڕاگیراو'),
              value: '${_kpis['suspended_customers'] ?? 0}',
              subtitle: tx('بلۆککراو'),
              icon: Icons.block_rounded,
              accentColor: RegaColors.crimson,
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
                    Text(
                      tx('پڕخەرجترین کڕیاران و ناونیشانەکانیان'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RegaColors.gold,
                        foregroundColor: RC.fg(Color(0xFF0F172A)),
                      ),
                      onPressed: () => _tabController.animateTo(2),
                      icon: const Icon(Icons.person_add_rounded, size: 17),
                      label: Text(tx('زیادکردنی کڕیار')),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._vipCustomers.map((raw) {
                  final c = raw as Map<String, dynamic>;
                  final addrs = c['addresses'] as List<dynamic>? ?? [];
                  final addrLine = addrs.isNotEmpty
                      ? (addrs.first as Map<String, dynamic>)['address_line']?.toString()
                      : 'بێ ناونیشان';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    leading: CircleAvatar(
                      backgroundColor: RegaColors.gold.withValues(alpha: 0.25),
                      child: Text(
                        tx((c['name']?.toString() ?? 'C').characters.first),
                        style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF0F172A))),
                      ),
                    ),
                    title: Text(
                      tx('${c['name'] ?? ''}  •  📞 ${c['phone'] ?? ''}'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(tx('📍 $addrLine  •  🛍️ ${c['customer_orders_count'] ?? 0} داواکاری')),
                    trailing: Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tx(formatIqd(c['total_spent'] as num?, lang: widget.lang)),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _tabController.animateTo(2),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(tx('دەستکاری')),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showCustomerDetailsDialog(c),
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: Text(tx('وردەکاری')),
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

  Widget _buildCustomerOrdersTab() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(AdminBreakpoints.pagePadH(context), 10, AdminBreakpoints.pagePadH(context), 24),
      itemCount: _recentOrders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final o = _recentOrders[idx] as Map<String, dynamic>;
        final status = o['status']?.toString() ?? 'pending';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tx('${o['order_number']}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(width: 10),
                        StatusBadge(status: status, lang: widget.lang),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: RegaColors.emerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tx('📍 ناونیشان: ${o['delivery_address'] ?? '-'}'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: RegaColors.emeraldDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tx('👤 کڕیار: ${o['customer_name'] ?? '-'} (${IraqPhoneFormatter.display((o['customer_phone'] ?? '').toString())})  •  🏪 ${o['store']?['name_ku'] ?? '-'}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(tx('📍 ناونیشان: ${o['delivery_address'] ?? '-'}'), style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade600))),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tx(formatIqd(o['total_amount'] as num?, lang: widget.lang)),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: RegaColors.emeraldDark),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AdminLiveRadarDialog(api: widget.api),
                        );
                      },
                      icon: const Icon(Icons.radar_rounded, size: 17),
                      label: Text(tx('نەخشەی ١ چرکەیی')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
