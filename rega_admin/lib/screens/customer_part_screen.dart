import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'catalog_zones_screen.dart';
import 'customers_screen.dart';
import 'live_radar_dialog.dart';
import 'marketing_screen.dart';

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
        content: Text(msg),
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
          title: Text('پڕۆفایلی کڕیار — ${detail['name'] ?? ''}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📞 مۆبایل: ${detail['phone'] ?? '-'}  |  ✉️ ئیمەیڵ: ${detail['email'] ?? '-'}'),
                  const Divider(height: 24),
                  const Text('📍 ناونیشانە تۆمارکراوەکان لە کەلار:', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (addresses.isEmpty)
                    const Text('هیچ ناونیشانێک تۆمار نەکراوە')
                  else
                    ...addresses.map((a) {
                      final m = a as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• [${m['label'] ?? 'ماڵەوە'}] ${m['address_line'] ?? ''} (${m['neighborhood']?['name_ku'] ?? ''})'),
                      );
                    }),
                  const Divider(height: 24),
                  Text('🛍️ دوایین داواکارییەکان (${orders.length}):', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...orders.map((o) {
                    final m = o as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${m['order_number']}  •  🏪 ${m['store']?['name_ku'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('📍 ${m['delivery_address'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatIqd(m['total_amount'] as num?, lang: widget.lang), style: const TextStyle(fontWeight: FontWeight.w900)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
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

    final addrCtrl = TextEditingController(text: 'کەلار - گەڕەکی شەهیدان، نزیک قوتابخانەی کەلار');
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
            title: const Text('تۆمارکردنی داواکاری ڕاستەوخۆ بۆ کڕیار (Live PostgreSQL Order)'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'هەڵبژاردنی کڕیار *'),
                      items: _vipCustomers.map((c) {
                        final m = c as Map<String, dynamic>;
                        return DropdownMenuItem<int?>(
                          value: m['id'] as int,
                          child: Text('${m['name']} (${m['phone']})'),
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
                            decoration: const InputDecoration(labelText: 'فرۆشگا / چێشتخانە *'),
                            items: _stores.map((s) {
                              final m = s as Map<String, dynamic>;
                              return DropdownMenuItem<int>(
                                value: m['id'] as int,
                                child: Text(m['name_ku']?.toString() ?? ''),
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
                            decoration: const InputDecoration(labelText: 'گەڕەکی کەلار'),
                            items: _neighborhoods.map((z) {
                              final m = z as Map<String, dynamic>;
                              return DropdownMenuItem<int?>(
                                value: m['id'] as int,
                                child: Text('${m['name_ku']} (${m['delivery_fee']} د.ع)'),
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
                      decoration: const InputDecoration(labelText: 'ناونیشانی تەواوی گەیاندن *'),
                    ),
                    const SizedBox(height: 14),
                    const Text('🍱 هەڵبژاردنی بەرهەمەکان:', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (storeProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('ئەم فرۆشگایە هیچ بەرهەمێکی تێدا نییە'),
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
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${p['name_ku']} — ${formatIqd(p['discount_price'] ?? p['price'], lang: widget.lang)}',
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
                              Text('$qty', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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
                          child: DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(labelText: 'شێوازی پارەدان'),
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('کاش لە کاتی وەرگرتن (COD)')),
                              DropdownMenuItem(value: 'fib', child: Text('FIB Bank')),
                              DropdownMenuItem(value: 'fastpay', child: Text('FastPay')),
                            ],
                            onChanged: (v) => setDialogState(() => paymentMethod = v ?? 'cash'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: couponCtrl,
                            decoration: const InputDecoration(labelText: 'کۆپۆنی داشکاندن (نمونە: REGA25)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'تێبینی کڕیار'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('پاشگەزبوونەوە')),
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
                      'داواکاری ${created['order_number']} تۆمارکرا! کۆدی کڕیار: ${created['delivery_pin']} ✅',
                    );
                    widget.onDataChanged?.call();
                    _load(silent: true);
                  } catch (e) {
                    _showSnack(e.toString(), error: true);
                  }
                },
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('تۆمارکردن و ناردن بۆ چێشتخانە'),
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
          margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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
                        child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF0F172A), size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بەشی کڕیاران و مارکێتپڵەیس (REGA Customer Hub)',
                            style: TextStyle(color: RegaColors.gold, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'بەستراوەتەوە بە ئەپی کڕیاران (rega) • هەژمارەکان، داواکاری، کۆپۆن، گەڕەکەکانی کەلار و نەخشەی زیندوو',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
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
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                        onPressed: _showCreateCustomerOrderDialog,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: const Text('داواکاری نوێ بۆ کڕیار'),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _load(),
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('نوێکردنەوە'),
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
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(icon: Icon(Icons.workspace_premium_rounded, size: 18), text: 'پوختە و کڕیارانی VIP'),
                  Tab(
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    text: 'داواکاری کڕیاران و PIN (${_kpis['total_customer_orders'] ?? 0})',
                  ),
                  const Tab(icon: Icon(Icons.groups_rounded, size: 18), text: 'بەڕێوەبردنی کڕیاران'),
                  const Tab(icon: Icon(Icons.location_city_rounded, size: 18), text: 'گەڕەکەکان و بەشەکان'),
                  const Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: 'کۆپۆن و ڕیکلامەکان'),
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
                        CatalogZonesScreen(api: widget.api, lang: widget.lang),
                        MarketingScreen(api: widget.api, lang: widget.lang),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildVipOverviewTab(bool isDark) {
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
              title: 'کۆی کڕیارانی تۆمارکراو',
              value: '${_kpis['total_customers'] ?? 0}',
              subtitle: '${_kpis['active_customers'] ?? 0} چالاک',
              icon: Icons.groups_rounded,
              accentColor: RegaColors.goldDark,
            ),
            StatKpiCard(
              title: 'ناونیشانەکانی کەلار',
              value: '${_kpis['saved_addresses_count'] ?? 0}',
              subtitle: 'تۆمارکراو لە GPS',
              icon: Icons.pin_drop_rounded,
              accentColor: RegaColors.blue,
            ),
            StatKpiCard(
              title: 'کۆی خەرجی کڕیاران (GMV)',
              value: formatIqd(_kpis['total_customer_gmv'] as num?, lang: widget.lang),
              subtitle: '${_kpis['total_customer_orders'] ?? 0} داواکاری',
              icon: Icons.shopping_bag_rounded,
              accentColor: RegaColors.emeraldDark,
            ),
            StatKpiCard(
              title: 'کۆپۆنە چالاکەکان',
              value: '${_kpis['active_coupons_count'] ?? 0}',
              subtitle: 'ئامادە بۆ کڕیار',
              icon: Icons.discount_rounded,
              accentColor: RegaColors.purple,
            ),
            StatKpiCard(
              title: 'بانەر و ڕیکلامی سەرەکی',
              value: '${_kpis['active_banners_count'] ?? 0}',
              subtitle: 'لە شاشەی سەرەکی ئەپ',
              icon: Icons.burst_mode_rounded,
              accentColor: RegaColors.orange,
            ),
            StatKpiCard(
              title: 'هەژماری ڕاگیراو',
              value: '${_kpis['suspended_customers'] ?? 0}',
              subtitle: 'بلۆککراو',
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
                const Text(
                  'پڕخەرجترین کڕیاران (VIP Customers) و ناونیشانەکانیان',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
                        (c['name']?.toString() ?? 'C').characters.first,
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ),
                    title: Text(
                      '${c['name'] ?? ''}  •  📞 ${c['phone'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('📍 $addrLine  •  🛍️ ${c['customer_orders_count'] ?? 0} داواکاری'),
                    trailing: Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatIqd(c['total_spent'] as num?, lang: widget.lang),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showCustomerDetailsDialog(c),
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('وردەکاری'),
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
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
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
                        Text('${o['order_number']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
                            '🔐 کۆدی وەرگرتنی کڕیار (Delivery PIN): ${o['delivery_pin'] ?? '----'}',
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
                      '👤 کڕیار: ${o['customer_name'] ?? '-'} (${o['customer_phone'] ?? '-'})  •  🏪 ${o['store']?['name_ku'] ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('📍 ناونیشان: ${o['delivery_address'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatIqd(o['total_amount'] as num?, lang: widget.lang),
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
                      label: const Text('نەخشەی ١ چرکەیی'),
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
