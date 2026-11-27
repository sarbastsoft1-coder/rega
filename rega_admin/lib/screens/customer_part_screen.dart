import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../state/admin_app_notifier.dart';
import '../widgets/common_widgets.dart';
import 'customers_screen.dart';
import 'direct_requests_screen.dart';
import 'live_radar_dialog.dart';
import '../widgets/send_customer_notification_dialog.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';

class CustomerPartScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final VoidCallback? onDataChanged;

  /// پوختە و کڕیاران
  static const int overviewTabIndex = 0;
  /// داواکاری کڕیاران
  static const int customerOrdersTabIndex = 1;
  /// داواکاری ڕاستەوخۆ
  static const int directRequestsTabIndex = 2;
  /// بەڕێوەبردنی کڕیاران
  static const int customersManageTabIndex = 3;

  const CustomerPartScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onDataChanged,
  });

  @override
  State<CustomerPartScreen> createState() => _CustomerPartScreenState();
}

class _CustomerPartScreenState extends State<CustomerPartScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _autoRefreshTimer;
  AdminNavNotifier? _nav;

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _kpis = {};
  List<dynamic> _vipCustomers = [];
  List<dynamic> _recentOrders = [];
  List<dynamic> _stores = [];
  List<dynamic> _products = [];
  List<dynamic> _neighborhoods = [];

  static const int _tabCount = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _load();
    _autoRefreshTimer =
        Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<AdminNavNotifier>();
    if (!identical(_nav, nav)) {
      _nav?.removeListener(_openPendingSubTab);
      _nav = nav;
      _nav!.addListener(_openPendingSubTab);
    }
    _openPendingSubTab();
  }

  void _openPendingSubTab() {
    final sub = _nav?.takeCustomersSubTab();
    if (sub == null) return;
    final target = sub.clamp(0, _tabCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index == target) return;
      _tabController.animateTo(target);
    });
  }

  @override
  void dispose() {
    _nav?.removeListener(_openPendingSubTab);
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

  void _goToServiceCities() {
    final idx = AdminNavNotifier.indexForPath('/service-cities');
    context.read<AdminNavNotifier>().setTabIndex(idx);
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
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          actionsOverflowButtonSpacing: 8,
          title: Text(
            tx('پڕۆفایلی کڕیار — ${detail['name'] ?? ''}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 560),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    AdminBreakpoints.dialogContentMaxHeight(ctx, max: 540),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ResponsiveDetailRow(
                      label: 'مۆبایل',
                      value: '${detail['phone'] ?? '-'}',
                      ltrValue: true,
                    ),
                    const SizedBox(height: 6),
                    ResponsiveDetailRow(
                      label: 'ئیمەیڵ',
                      value: '${detail['email'] ?? '-'}',
                      ltrValue: true,
                    ),
                    const Divider(height: 24),
                    Text(tx('📍 ناونیشانە تۆمارکراوەکان لە کەلار:'),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (addresses.isEmpty)
                      Text(tx('هیچ ناونیشانێک تۆمار نەکراوە'))
                    else
                      ...addresses.map((a) {
                        final m = a as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(tx(
                              '• [${m['label'] ?? 'ماڵەوە'}] ${m['address_line'] ?? ''} (${m['neighborhood']?['name_ku'] ?? ''})')),
                        );
                      }),
                    const Divider(height: 24),
                    Text(tx('🛍️ دوایین داواکارییەکان (${orders.length}):'),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    ...orders.map((o) {
                      final m = o as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: RC.bg(Colors.grey).withValues(alpha: 0.22)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              tx('${m['order_number']}  •  🏪 ${m['store']?['name_ku'] ?? '-'}'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tx('📍 ${m['delivery_address'] ?? ''}'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: RC.fg(Colors.grey.shade600)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  tx(formatIqd(m['total_amount'] as num?,
                                      lang: widget.lang)),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: RegaColors.emeraldDark),
                                ),
                                StatusBadge(
                                    status: m['status']?.toString() ?? 'pending',
                                    lang: widget.lang),
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
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final id = (detail['id'] as num?)?.toInt();
                if (id == null) return;
                Navigator.pop(ctx);
                final ok = await showSendCustomerNotificationDialog(
                  context,
                  api: widget.api,
                  lang: widget.lang,
                  preselectedIds: {id},
                  preselectedLabel:
                      '${detail['name'] ?? ''} ${detail['phone'] ?? ''}'.trim(),
                );
                if (ok) {
                  _showSnack(
                      'ئاگاداری نێردرا — لە سندوقی ئەپی کڕیار دەردەکەوێت');
                }
              },
              child: Text(tx('ناردنی ئاگاداری')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(const Color(0xFFDC2626)),
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(tx('داخستن'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
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

    final addrCtrl = TextEditingController(
        text: tx('کەلار - گەڕەکی شەهیدان، نزیک قوتابخانەی کەلار'));
    final couponCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    const paymentMethod = 'cash';
    final Map<int, int> cartQty = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final storeProducts = _products
              .where((p) =>
                  (p as Map<String, dynamic>)['store_id'] == selectedStoreId)
              .toList();

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
            actionsOverflowButtonSpacing: 8,
            title: Text(
              tx('تۆمارکردنی داواکاری ڕاستەوخۆ بۆ کڕیار (Live PostgreSQL Order)'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 580),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      AdminBreakpoints.dialogContentMaxHeight(ctx, max: 560),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: selectedCustomerId,
                        decoration:
                            InputDecoration(labelText: tx('هەڵبژاردنی کڕیار *')),
                        items: _vipCustomers.map((c) {
                          final m = c as Map<String, dynamic>;
                          return DropdownMenuItem<int?>(
                            value: m['id'] as int,
                            child: Text(
                              tx('${m['name']} (${m['phone']})'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedCustomerId = v),
                      ),
                      const SizedBox(height: 12),
                      ResponsiveFormRow(
                        breakpoint: 460,
                        first: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: selectedStoreId,
                          decoration: InputDecoration(
                              labelText: tx('فرۆشگا / چێشتخانە *')),
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
                          onChanged: (v) {
                            if (v == null) return;
                            setDialogState(() {
                              selectedStoreId = v;
                              cartQty.clear();
                            });
                          },
                        ),
                        second: DropdownButtonFormField<int?>(
                          isExpanded: true,
                          initialValue: selectedZoneId,
                          decoration:
                              InputDecoration(labelText: tx('گەڕەکی کەلار')),
                          items: _neighborhoods.map((z) {
                            final m = z as Map<String, dynamic>;
                            return DropdownMenuItem<int?>(
                              value: m['id'] as int,
                              child: Text(
                                tx('${m['name_ku']} (${m['delivery_fee']} د.ع)'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedZoneId = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addrCtrl,
                        decoration: InputDecoration(
                            labelText: tx('ناونیشانی تەواوی گەیاندن *')),
                      ),
                      const SizedBox(height: 14),
                      Text(tx('🍱 هەڵبژاردنی بەرهەمەکان:'),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (storeProducts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child:
                              Text(tx('ئەم فرۆشگایە هیچ بەرهەمێکی تێدا نییە')),
                        )
                      else
                        ...storeProducts.map((raw) {
                          final p = raw as Map<String, dynamic>;
                          final pid = p['id'] as int;
                          final qty = cartQty[pid] ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: RC
                                      .bg(Colors.grey)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tx('${p['name_ku']} — ${formatIqd(p['discount_price'] ?? p['price'], lang: widget.lang)}'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 34, minHeight: 34),
                                  onPressed: qty > 0
                                      ? () => setDialogState(() {
                                            if (qty == 1) {
                                              cartQty.remove(pid);
                                            } else {
                                              cartQty[pid] = qty - 1;
                                            }
                                          })
                                      : null,
                                  icon: const Icon(
                                      Icons.remove_circle_outline_rounded),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(tx('$qty'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 34, minHeight: 34),
                                  onPressed: () => setDialogState(
                                      () => cartQty[pid] = qty + 1),
                                  icon: const Icon(Icons.add_circle_rounded,
                                      color: RegaColors.emeraldDark),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 12),
                      ResponsiveFormRow(
                        breakpoint: 460,
                        first: InputDecorator(
                          decoration:
                              InputDecoration(labelText: tx('شێوازی پارەدان')),
                          child: Text(
                            tx('کاش لە کاتی وەرگرتن (COD)'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: RC.fg(Colors.grey.shade800),
                            ),
                          ),
                        ),
                        second: TextField(
                          controller: couponCtrl,
                          decoration: InputDecoration(
                              labelText: tx('کۆپۆنی داشکاندن (نمونە: REGA25)')),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        decoration:
                            InputDecoration(labelText: tx('تێبینی کڕیار')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tx('پاشگەزبوونەوە'))),
              ElevatedButton.icon(
                onPressed: () async {
                  if (cartQty.isEmpty) {
                    _showSnack('تکایە لانیکەم یەک بەرهەم هەڵبژێرە',
                        error: true);
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
                      'coupon_code': couponCtrl.text.trim().isEmpty
                          ? null
                          : couponCtrl.text.trim(),
                      'customer_notes': notesCtrl.text.trim(),
                      'items': cartQty.entries
                          .map((e) =>
                              {'product_id': e.key, 'quantity': e.value})
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
                label: Text(tx('تۆمارکردن و ناردن بۆ چێشتخانە'),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = AdminSurfaces.of(context);
    final padH = AdminBreakpoints.pagePadH(context);
    final isPhone =
        MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padH, isPhone ? 10 : 16, padH, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx('کڕیاران'),
                      style: TextStyle(
                        fontSize: isPhone ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx('بەڕێوەبردنی کڕیار، داواکاری و داواکاری ڕاستەوخۆ'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: surfaces.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isPhone)
                FilledButton.tonalIcon(
                  onPressed: _showCreateCustomerOrderDialog,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(tx('داواکاری نوێ')),
                ),
              IconButton(
                tooltip: tx('نوێکردنەوە'),
                onPressed: () => _load(),
                icon: const Icon(Icons.sync_rounded),
              ),
            ],
          ),
        ),
        if (isPhone)
          Padding(
            padding: EdgeInsets.fromLTRB(padH, 8, padH, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: _showCreateCustomerOrderDialog,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: Text(tx('داواکاری نوێ')),
              ),
            ),
          ),
        Material(
          color: surfaces.elevated,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: RegaColors.orange,
            indicatorWeight: 3,
            labelColor: RegaColors.orange,
            unselectedLabelColor: surfaces.textSecondary,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            dividerColor: surfaces.border,
            tabs: [
              Tab(text: tx('پوختە')),
              Tab(
                text: tx(
                    'داواکاری کڕیاران (${_kpis['total_customer_orders'] ?? 0})'),
              ),
              Tab(text: tx('داواکاری ڕاستەوخۆ')),
              Tab(text: tx('بەڕێوەبردنی کڕیاران')),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVipOverviewTab(),
                        _buildCustomerOrdersTab(),
                        DirectRequestsScreen(
                          api: widget.api,
                          lang: widget.lang,
                          onChanged: widget.onDataChanged,
                        ),
                        CustomersScreen(
                            api: widget.api, lang: widget.lang),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildVipOverviewTab() {
    final padH = AdminBreakpoints.pagePadH(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(padH, 8, padH, 28),
      children: [
        LayoutBuilder(
          builder: (context, kpiConstraints) {
            final w = kpiConstraints.maxWidth;
            final cols = w < 560 ? 1 : (w < 980 ? 2 : 3);
            final isPhone = w < AdminBreakpoints.phone;
            final kpis = <Widget>[
              StatKpiCard(
                title: tx('کۆی کڕیارانی تۆمارکراو'),
                value: '${_kpis['total_customers'] ?? 0}',
                subtitle: tx('${_kpis['active_customers'] ?? 0} چالاک'),
                icon: Icons.groups_rounded,
                accentColor: RegaColors.goldDark,
              ),
              StatKpiCard(
                title: tx('ناونیشانە تۆمارکراوەکان'),
                value: '${_kpis['saved_addresses_count'] ?? 0}',
                subtitle: tx('تۆمارکراو لە GPS'),
                icon: Icons.pin_drop_rounded,
                accentColor: RegaColors.blue,
              ),
              StatKpiCard(
                title: tx('کۆی خەرجی کڕیاران (GMV)'),
                value: formatIqd(_kpis['total_customer_gmv'] as num?,
                    lang: widget.lang),
                subtitle:
                    tx('${_kpis['total_customer_orders'] ?? 0} داواکاری'),
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
            ];
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kpis.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: isPhone ? 84 : 162,
              ),
              itemBuilder: (_, idx) => kpis[idx],
            );
          },
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: RegaColors.gold,
                foregroundColor: RC.fg(const Color(0xFF0F172A)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _goToServiceCities,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: Text(tx('شارەکانی کار (لە مێنو)')),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: RC.fg(const Color(0xFF0F172A)),
                side: const BorderSide(color: RegaColors.gold),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _goToServiceCities,
              icon: const Icon(Icons.location_city_rounded, size: 18),
              label: Text(tx('گەڕەکەکان / ناوچەکان')),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, cardConstraints) {
            final isPhone = cardConstraints.maxWidth < AdminBreakpoints.phone;
            final compactItem = cardConstraints.maxWidth < 760;
            return Card(
              child: Padding(
                padding: EdgeInsets.all(isPhone ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tx('پڕخەرجترین کڕیاران و ناونیشانەکانیان'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RegaColors.gold,
                            foregroundColor: RC.fg(const Color(0xFF0F172A)),
                          ),
                          onPressed: () => _tabController.animateTo(
                              CustomerPartScreen.customersManageTabIndex),
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
                          ? (addrs.first as Map<String, dynamic>)['address_line']
                              ?.toString()
                          : 'بێ ناونیشان';
                      final avatar = CircleAvatar(
                        backgroundColor:
                            RegaColors.gold.withValues(alpha: 0.25),
                        child: Text(
                          tx((c['name']?.toString() ?? 'C').characters.first),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: RC.fg(const Color(0xFF0F172A))),
                        ),
                      );
                      final titleText =
                          tx('${c['name'] ?? ''}  •  📞 ${c['phone'] ?? ''}');
                      final subText = tx(
                          '📍 $addrLine  •  🛍️ ${c['customer_orders_count'] ?? 0} داواکاری');
                      final spentText = tx(formatIqd(c['total_spent'] as num?,
                          lang: widget.lang));

                      if (compactItem) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    RC.bg(Colors.grey).withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  avatar,
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          titleText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          subText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  RC.fg(Colors.grey.shade600)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    spentText,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: RegaColors.emeraldDark),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _tabController.animateTo(
                                                CustomerPartScreen
                                                    .customersManageTabIndex),
                                        icon: const Icon(Icons.edit_rounded,
                                            size: 16),
                                        label: Text(tx('دەستکاری')),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showCustomerDetailsDialog(c),
                                        icon: const Icon(
                                            Icons.visibility_rounded,
                                            size: 16),
                                        label: Text(tx('وردەکاری')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 6),
                        leading: avatar,
                        title: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          subText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              spentText,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: RegaColors.emeraldDark),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _tabController.animateTo(
                                  CustomerPartScreen.customersManageTabIndex),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: Text(tx('دەستکاری')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showCustomerDetailsDialog(c),
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 16),
                              label: Text(tx('وردەکاری')),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomerOrdersTab() {
    final padH = AdminBreakpoints.pagePadH(context);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(padH, 10, padH, 24),
      itemCount: _recentOrders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final o = _recentOrders[idx] as Map<String, dynamic>;
        final status = o['status']?.toString() ?? 'pending';
        return Card(
          child: Padding(
            padding: EdgeInsets.all(AdminBreakpoints.cardPadding(context)),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tx('${o['order_number']}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        StatusBadge(status: status, lang: widget.lang),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tx('👤 کڕیار: ${o['customer_name'] ?? '-'} (${IraqPhoneFormatter.display((o['customer_phone'] ?? '').toString())})  •  🏪 ${o['store']?['name_ku'] ?? '-'}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      tx('📍 ناونیشان: ${o['delivery_address'] ?? '-'}'),
                      style: TextStyle(
                          fontSize: 12, color: RC.fg(Colors.grey.shade600)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tx(formatIqd(o['total_amount'] as num?,
                          lang: widget.lang)),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: RegaColors.emeraldDark),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) =>
                              AdminLiveRadarDialog(api: widget.api),
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
