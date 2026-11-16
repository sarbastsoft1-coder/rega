import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/admin_top_header.dart';
import '../widgets/common_widgets.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
/// Main operational desk for receiving / handling live orders.
class OrderIntakeScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final VoidCallback? onChanged;

  const OrderIntakeScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onChanged,
  });

  @override
  State<OrderIntakeScreen> createState() => _OrderIntakeScreenState();
}

class _OrderIntakeScreenState extends State<OrderIntakeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _timer;

  bool _loading = true;
  String _filter = 'incoming'; // incoming | preparing | ready | all_active
  List<Map<String, dynamic>> _orders = [];
  List<dynamic> _drivers = [];
  List<dynamic> _stores = [];
  List<dynamic> _products = [];
  List<dynamic> _neighborhoods = [];
  List<dynamic> _customers = [];

  int _newCount = 0;
  int _preparingCount = 0;
  int _readyCount = 0;
  int _activeCount = 0;
  int? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _orders.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final needCatalog = _stores.isEmpty || _products.isEmpty || _neighborhoods.isEmpty || _customers.isEmpty;
      final ordersFut = widget.api.getOrders(
        status: 'all',
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      final driversFut = widget.api.getDrivers(isVerified: true);

      late final Map<String, dynamic> ordersRes;
      late final List<dynamic> drivers;
      if (needCatalog) {
        final results = await Future.wait([
          ordersFut,
          driversFut,
          widget.api.getStores(),
          widget.api.getProducts(),
          widget.api.getNeighborhoods(),
          widget.api.getCustomers(),
        ]);
        ordersRes = results[0] as Map<String, dynamic>;
        drivers = results[1] as List<dynamic>;
        _stores = results[2] as List<dynamic>;
        _products = results[3] as List<dynamic>;
        _neighborhoods = results[4] as List<dynamic>;
        _customers = results[5] as List<dynamic>;
      } else {
        final results = await Future.wait([ordersFut, driversFut]);
        ordersRes = results[0] as Map<String, dynamic>;
        drivers = results[1] as List<dynamic>;
      }

      final raw = ordersRes['data'] as List<dynamic>? ?? [];
      final mapped = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final newC = mapped.where((o) => _isIncoming(o['status']?.toString())).length;
      final prepC = mapped.where((o) => o['status']?.toString() == 'preparing').length;
      final readyC = mapped.where((o) => o['status']?.toString() == 'ready').length;
      final activeC = mapped.where((o) {
        final s = o['status']?.toString() ?? '';
        return !_isDone(s);
      }).length;

      if (!mounted) return;
      setState(() {
        _orders = mapped;
        _drivers = drivers;
        _newCount = newC;
        _preparingCount = prepC;
        _readyCount = readyC;
        _activeCount = activeC;
        _loading = false;
      });
    } catch (e) {
      debugPrint('OrderIntake _load: $e');
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  bool _isIncoming(String? status) =>
      status == 'pending' || status == 'accepted' || status == null || status == '';

  bool _isDone(String status) =>
      status == 'delivered' || status == 'completed' || status == 'cancelled' || status == 'rejected';

  List<Map<String, dynamic>> get _visibleOrders {
    return _orders.where((o) {
      final status = o['status']?.toString() ?? 'pending';
      if (_isDone(status)) return false;
      switch (_filter) {
        case 'incoming':
          return _isIncoming(status);
        case 'preparing':
          return status == 'preparing';
        case 'ready':
          return status == 'ready' ||
              status == 'picked_up' ||
              status == 'on_the_way' ||
              status == 'arrived_customer' ||
              status == 'driver_assigned';
        case 'all_active':
          return true;
        default:
          return true;
      }
    }).toList();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(msg)),
        backgroundColor: error ? RC.bg(Color(0xFFDC2626)) : RC.bg(Color(0xFF16A34A)),
      ),
    );
  }

  Future<void> _setStatus(Map<String, dynamic> order, String status, {String? reason}) async {
    final id = order['id'] as int?;
    if (id == null) return;
    try {
      await widget.api.updateOrderStatus(id, status, reason: reason);
      _snack('داواکاری ${order['order_number']} → $status');
      widget.onChanged?.call();
      await _load(silent: true);
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  String _fmtDistance(dynamic meters) {
    final m = (meters as num?)?.toDouble();
    if (m == null) return 'بێ GPS';
    if (m < 1000) return '${m.round()} م';
    return '${(m / 1000).toStringAsFixed(1)} کم';
  }

  List<Map<String, dynamic>> get _sortedDrivers {
    final list = _drivers.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    list.sort((a, b) {
      final ao = a['is_online'] == true ? 0 : 1;
      final bo = b['is_online'] == true ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      final ad = (a['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final bd = (b['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      if (ad != bd) return ad.compareTo(bd);
      final at = (a['today_orders'] as num?)?.toInt() ?? 0;
      final bt = (b['today_orders'] as num?)?.toInt() ?? 0;
      if (at != bt) return at.compareTo(bt);
      final an = (a['user'] as Map?)?['name']?.toString() ?? '';
      final bn = (b['user'] as Map?)?['name']?.toString() ?? '';
      return an.compareTo(bn);
    });
    return list;
  }

  Future<void> _showDriversBottomSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminSurfaces.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        return SizedBox(
          height: (h * 0.62).clamp(320.0, h * 0.85),
          child: _buildDriversPanel(compact: false),
        );
      },
    );
  }

  Future<void> _refreshDriversForOrder(Map<String, dynamic>? order) async {
    try {
      final storeId = (order?['store_id'] as num?)?.toInt() ??
          ((order?['store'] as Map?)?['id'] as num?)?.toInt();
      final orderId = (order?['id'] as num?)?.toInt();
      final drivers = await widget.api.getDrivers(
        isVerified: true,
        storeId: storeId,
        orderId: orderId,
      );
      if (!mounted) return;
      setState(() => _drivers = drivers);
    } catch (_) {}
  }

  Map<String, dynamic>? get _selectedOrder {
    if (_selectedOrderId == null) return null;
    for (final o in _orders) {
      if (o['id'] == _selectedOrderId) return o;
    }
    return null;
  }

  Future<void> _assignDriverToOrder(Map<String, dynamic> order, Map<String, dynamic> driverProfile) async {
    final orderId = order['id'] as int?;
    final user = driverProfile['user'] as Map<String, dynamic>? ?? {};
    final driverUserId = user['id'] as int?;
    if (orderId == null || driverUserId == null) return;
    try {
      await widget.api.assignDriver(orderId, driverUserId);
      _snack('ماتۆرسوار (${user['name'] ?? ''}) بۆ ${order['order_number']} دیاریکرا ✅');
      widget.onChanged?.call();
      _load(silent: true);
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _assignDriver(Map<String, dynamic> order) async {
    final orderId = order['id'] as int?;
    if (orderId == null) return;
    setState(() => _selectedOrderId = orderId);
    await _refreshDriversForOrder(order);

    final drivers = _sortedDrivers;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tx('دیاریکردنی ماتۆرسوار بۆ ${order['order_number']}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width * 0.92).clamp(280.0, 480.0),
          height: (MediaQuery.sizeOf(context).height * 0.55).clamp(320.0, 440.0),
          child: drivers.isEmpty
              ? Center(child: Text(tx('هیچ ماتۆرسوارێک تۆمار نەکراوە')))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tx('${drivers.where((d) => d['is_online'] == true).length} ئۆنلاین / ${drivers.length} — نزیکترین بۆ فرۆشگا یەکەمە'),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Colors.grey.shade700)),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: drivers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final dp = drivers[idx];
                          final u = dp['user'] as Map<String, dynamic>? ?? {};
                          final online = dp['is_online'] == true;
                          final today = (dp['today_deliveries'] as num?)?.toInt() ?? 0;
                          final todayAssigned = (dp['today_orders'] as num?)?.toInt() ?? 0;
                          final nearBadge = idx == 0 && dp['distance_meters'] != null ? ' · نزیکترین' : '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: online ? RC.bg(Color(0xFFDCFCE7)) : RC.bg(Color(0xFFF1F5F9)),
                              child: Icon(
                                Icons.two_wheeler_rounded,
                                color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey),
                              ),
                            ),
                            title: Text(
                              tx('${u['name'] ?? ''} (${dp['driver_code'] ?? ''})$nearBadge'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              tx('${online ? '🟢 ئۆنلاین' : '⚫ ئۆفلاین'} • ${_fmtDistance(dp['distance_meters'])}\n'
                              'ئەمڕۆ: $today گەیاندن · $todayAssigned داواکاری'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: online ? RC.bg(Color(0xFF16A34A)) : RC.bg(Colors.grey.shade600),
                              ),
                            ),
                            isThreeLine: true,
                            trailing: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(Color(0xFF16A34A)),
                                  foregroundColor: RC.fg(Colors.white),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _assignDriverToOrder(order, dp);
                                },
                                child: Text(tx(online ? 'پێدان' : 'دیاریکردن')),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('داخستن'))),
        ],
      ),
    );
  }

  void _showCreateOrderDialog() {
    if (_stores.isEmpty) {
      _snack('هیچ فرۆشگایەک بەردەست نییە', error: true);
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController(text: tx('کەلار - گەڕەکی شەهیدان'));
    final notesCtrl = TextEditingController();

    int selectedStoreId = (_stores.first as Map<String, dynamic>)['id'] as int;
    int? selectedZoneId = _neighborhoods.isNotEmpty
        ? (_neighborhoods.first as Map<String, dynamic>)['id'] as int
        : null;
    int? selectedCustomerId = _customers.isNotEmpty
        ? (_customers.first as Map<String, dynamic>)['id'] as int
        : null;
    final Map<int, int> cartQty = {};
    String paymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final storeProducts = _products
              .where((p) => (p as Map<String, dynamic>)['store_id'] == selectedStoreId)
              .toList();

          final dialogW = AdminBreakpoints.dialogWidth(ctx, max: 560);
          final stackFields = dialogW < 520;
          Widget pair(Widget a, Widget b) {
            if (stackFields) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [a, const SizedBox(height: 10), b],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
            );
          }

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(tx('وەرگرتنی داواکاری نوێ (طلب)'), style: TextStyle(fontWeight: FontWeight.w900)),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogW,
                maxHeight: AdminBreakpoints.dialogMaxHeight(ctx),
              ),
              child: SizedBox(
              width: dialogW,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_customers.isNotEmpty)
                      DropdownButtonFormField<int?>(
                        initialValue: selectedCustomerId,
                        decoration: InputDecoration(labelText: tx('کڕیاری تۆمارکراو (ئارەزوومەندانە)')),
                        items: [
                          DropdownMenuItem<int?>(value: null, child: Text(tx('کڕیاری نوێ / تەلەفۆن'))),
                          ..._customers.take(40).map((c) {
                            final m = c as Map<String, dynamic>;
                            return DropdownMenuItem<int?>(
                              value: m['id'] as int,
                              child: Text(tx('${m['name']} (${m['phone']})')),
                            );
                          }),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            selectedCustomerId = v;
                            if (v != null) {
                              Map<String, dynamic>? found;
                              for (final c in _customers) {
                                final m = c as Map<String, dynamic>;
                                if (m['id'] == v) {
                                  found = m;
                                  break;
                                }
                              }
                              nameCtrl.text = found?['name']?.toString() ?? '';
                              phoneCtrl.text = IraqPhoneFormatter.format(found?['phone']?.toString() ?? '');
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 10),
                    pair(
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(labelText: tx('ناوی کڕیار *')),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          inputFormatters: <TextInputFormatter>[IraqPhoneFormatter()],
                          decoration: InputDecoration(
                            labelText: tx('مۆبایل *'),
                            hintText: txn(IraqPhoneFormatter.hint),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    pair(
                      DropdownButtonFormField<int>(
                        initialValue: selectedStoreId,
                        decoration: InputDecoration(labelText: tx('فرۆشگا *')),
                        items: _stores.map((s) {
                          final m = s as Map<String, dynamic>;
                          return DropdownMenuItem(value: m['id'] as int, child: Text(tx(m['name_ku']?.toString() ?? '')));
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() {
                            selectedStoreId = v;
                            cartQty.clear();
                          });
                        },
                      ),
                      DropdownButtonFormField<int?>(
                        initialValue: selectedZoneId,
                        decoration: InputDecoration(labelText: tx('گەڕەک')),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: addrCtrl,
                      decoration: InputDecoration(labelText: tx('ناونیشانی گەیاندن *')),
                    ),
                    const SizedBox(height: 12),
                    Text(tx('بەرهەمەکان'), style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    if (storeProducts.isEmpty)
                      Text(tx('ئەم فرۆشگایە بەرهەمی نییە'))
                    else
                      ...storeProducts.take(20).map((raw) {
                        final p = raw as Map<String, dynamic>;
                        final pid = p['id'] as int;
                        final qty = cartQty[pid] ?? 0;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            tx('${p['name_ku']} — ${formatIqd(p['discount_price'] ?? p['price'], lang: widget.lang)}'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: qty > 0
                                    ? () => setDialogState(() {
                                          if (qty <= 1) {
                                            cartQty.remove(pid);
                                          } else {
                                            cartQty[pid] = qty - 1;
                                          }
                                        })
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                              ),
                              Text(tx('$qty'), style: const TextStyle(fontWeight: FontWeight.w900)),
                              IconButton(
                                onPressed: () => setDialogState(() => cartQty[pid] = qty + 1),
                                icon: Icon(Icons.add_circle, color: RC.fg(Color(0xFFEA580C)), size: 20),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: InputDecoration(labelText: tx('پارەدان')),
                      child: Text(
                        tx('کاش (COD)'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: RC.fg(Colors.grey.shade800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(labelText: tx('تێبینی')),
                    ),
                  ],
                ),
              ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('پاشگەزبوونەوە'))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFEA580C)),
                  foregroundColor: RC.fg(Colors.white),
                ),
                onPressed: () async {
                  if (phoneCtrl.text.trim().isEmpty && selectedCustomerId == null) {
                    _snack('ژمارەی مۆبایل پێویستە', error: true);
                    return;
                  }
                  if (cartQty.isEmpty) {
                    _snack('لانیکەم یەک بەرهەم هەڵبژێرە', error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final created = await widget.api.createAdminOrder({
                      'customer_id': selectedCustomerId,
                      'customer_name': nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                      'customer_phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      'store_id': selectedStoreId,
                      'neighborhood_id': selectedZoneId,
                      'delivery_address': addrCtrl.text.trim(),
                      'payment_method': paymentMethod,
                      'customer_notes': notesCtrl.text.trim(),
                      'items': cartQty.entries
                          .map((e) => {'product_id': e.key, 'quantity': e.value})
                          .toList(),
                    });
                    _snack('طلب تۆمارکرا: ${created['order_number']} ✅');
                    widget.onChanged?.call();
                    _load(silent: true);
                  } catch (e) {
                    _snack(e.toString(), error: true);
                  }
                },
                icon: const Icon(Icons.call_received_rounded, size: 18),
                label: Text(tx('تۆمارکردنی طلب')),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
      case 'accepted':
        return RC.bg(Color(0xFFD97706));
      case 'preparing':
        return RC.bg(Color(0xFF2563EB));
      case 'ready':
        return RC.bg(Color(0xFF7C3AED));
      case 'picked_up':
      case 'on_the_way':
      case 'arrived_customer':
        return RC.bg(Color(0xFFEA580C));
      default:
        return RC.bg(Colors.grey);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
      case 'accepted':
        return 'طلبی نوێ — چاوەڕوانی وەرگرتن';
      case 'preparing':
        return 'قبوڵکرا — لە ئامادەکردن';
      case 'ready':
        return 'ئامادەیە بۆ ماتۆرسوار';
      case 'picked_up':
        return 'هەڵگیرا لە فرۆشگا';
      case 'on_the_way':
        return 'لە ڕێگای گەیاندن';
      case 'arrived_customer':
        return 'گەیشتە کڕیار';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleOrders;
    final topActions = AdminTopBarRow(
      searchCtrl: _searchCtrl,
      hintText: tx('گەڕان بە ژمارەی طلب، کڕیار، فرۆشگا...'),
      onSearchChanged: (_) => _load(silent: true),
      onGoToOrders: () {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 12 : 20,
            16,
            MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 12 : 20,
            12,
          ),
          color: RC.bg(Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFFEA580C)).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.headset_mic_rounded, color: RC.fg(Color(0xFFEA580C)), size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx('وەرگرتنی داواکاری (طلب)'),
                              style: TextStyle(
                                fontSize: constraints.maxWidth < AdminBreakpoints.phone ? 18 : 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              tx('شاشەی سەرەکی بۆ وەرگرتن، قبوڵکردن و ناردنی داواکاری بۆ ماتۆرسوار'),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AdminSurfaces.of(context).textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < AdminBreakpoints.headerCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
                        const SizedBox(height: 10),
                        title,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 8),
                      topActions,
                    ],
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
                      backgroundColor: RC.bg(Color(0xFFEA580C)),
                      foregroundColor: RC.fg(Colors.white),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _showCreateOrderDialog,
                    icon: const Icon(Icons.add_ic_call_rounded),
                    label: Text(tx('تۆمارکردنی طلبی نوێ'), style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _load(),
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(tx('نوێکردنەوە')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < AdminBreakpoints.phone;
                  final chips = [
                    _kpiChip(AppStrings.tr('kpi_new_orders', widget.lang), _newCount, RC.bg(Color(0xFFD97706)), 'incoming'),
                    _kpiChip(AppStrings.tr('kpi_preparing', widget.lang), _preparingCount, RC.bg(Color(0xFF2563EB)), 'preparing'),
                    _kpiChip(AppStrings.tr('kpi_delivery', widget.lang), _readyCount, RC.bg(Color(0xFF7C3AED)), 'ready'),
                    _kpiChip(AppStrings.tr('filter_all', widget.lang), _activeCount, RC.bg(Color(0xFF0F172A)), 'all_active'),
                  ];
                  if (narrow) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips
                          .map((w) => SizedBox(width: (c.maxWidth - 8) / 2, child: w))
                          .toList(),
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < chips.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: chips[i]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final ordersPane = visible.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 72, color: RC.fg(Colors.grey.shade400)),
                                const SizedBox(height: 12),
                                Text(
                                  tx(_filter == 'incoming'
                                      ? 'هیچ طلبێکی نوێ لە چاوەڕوانیدا نییە'
                                      : 'هیچ داواکارییەک لەم بەشەدا نییە'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RC.bg(Color(0xFFEA580C)),
                                    foregroundColor: RC.fg(Colors.white),
                                  ),
                                  onPressed: _showCreateOrderDialog,
                                  icon: const Icon(Icons.add_ic_call_rounded),
                                  label: Text(tx('تۆمارکردنی یەکەم طلب')),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: RC.bg(Color(0xFFEA580C)),
                            onRefresh: () => _load(),
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 10 : 16,
                                12,
                                MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 10 : 16,
                                24,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (_, idx) => _buildOrderCard(visible[idx]),
                            ),
                          );

                    if (!wide) {
                      final phone = constraints.maxWidth < AdminBreakpoints.phone;
                      if (phone) {
                        return Column(
                          children: [
                            if (_selectedOrderId != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _showDriversBottomSheet,
                                    icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                                    label: Text(tx('ماتۆرسوارەکان بۆ طلبی هەڵبژێردراو'), style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ),
                            Expanded(child: ordersPane),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          SizedBox(
                            height: 210,
                            child: _buildDriversPanel(compact: true),
                          ),
                          const Divider(height: 1),
                          Expanded(child: ordersPane),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: ordersPane),
                        Container(width: 1, color: RC.bg(Color(0xFFE2E8F0))),
                        SizedBox(width: 340, child: _buildDriversPanel()),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDriversPanel({bool compact = false}) {
    final drivers = _sortedDrivers;
    final onlineCount = drivers.where((d) => d['is_online'] == true).length;
    final selected = _selectedOrder;

    return Container(
      color: RC.bg(Colors.white),
      padding: EdgeInsets.fromLTRB(14, compact ? 10 : 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.two_wheeler_rounded, color: RC.fg(Color(0xFF16A34A)), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tx('ماتۆرسوارەکان'),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tx('$onlineCount ئۆنلاین'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF166534))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tx(selected == null
                ? 'سەرەتا طلبێک هەڵبژێرە، پاشان ماتۆرسوار دەست لێدە'
                : 'طلبی هەڵبژێردراو: ${selected['order_number']} — نزیکترین بۆ فرۆشگا سەرەوەیە'),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected == null ? RC.bg(Colors.grey.shade600) : RC.bg(Color(0xFFEA580C)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: drivers.isEmpty
                ? Center(
                    child: Text(
                      tx('هیچ ماتۆرسوارێک نییە'),
                      style: TextStyle(fontWeight: FontWeight.w700, color: RC.fg(Colors.grey.shade500)),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: compact ? Axis.horizontal : Axis.vertical,
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => SizedBox(width: compact ? 10 : 0, height: compact ? 0 : 8),
                    itemBuilder: (_, idx) {
                      final dp = drivers[idx];
                      final u = dp['user'] as Map<String, dynamic>? ?? {};
                      final online = dp['is_online'] == true;
                      final name = u['name']?.toString() ?? '—';
                      final code = dp['driver_code']?.toString() ?? '';

                      final today = (dp['today_deliveries'] as num?)?.toInt() ?? 0;
                      final dist = _fmtDistance(dp['distance_meters']);

                      if (compact) {
                        final phone = MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _onDriverPanelTap(dp),
                          child: Container(
                            width: phone ? 132 : 158,
                            padding: EdgeInsets.all(phone ? 8 : 10),
                            decoration: BoxDecoration(
                              color: online ? RC.bg(Color(0xFFF0FDF4)) : RC.bg(Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: online ? RC.bg(Color(0xFF86EFAC)) : RC.bg(Color(0xFFE2E8F0))),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.two_wheeler_rounded, color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey), size: phone ? 18 : 20),
                                const Spacer(),
                                Text(tx(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: phone ? 12 : 13)),
                                Text(
                                  tx(online ? 'ئۆنلاین · $dist' : 'ئۆفلاین · $dist'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: phone ? 10 : 10.5, fontWeight: FontWeight.w700, color: online ? RC.bg(Color(0xFF16A34A)) : RC.bg(Colors.grey)),
                                ),
                                Text(tx('ئەمڕۆ: $today'), style: TextStyle(fontSize: phone ? 10 : 10.5, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFFEA580C)))),
                              ],
                            ),
                          ),
                        );
                      }

                      return Material(
                        color: online ? RC.bg(Color(0xFFF0FDF4)) : RC.bg(Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _onDriverPanelTap(dp),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: online ? RC.bg(Color(0xFF86EFAC)) : RC.bg(Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: online ? RC.bg(Color(0xFFDCFCE7)) : RC.bg(Color(0xFFE2E8F0)),
                                  child: Icon(Icons.two_wheeler_rounded, size: 18, color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tx('$name${code.isEmpty ? '' : ' ($code)'}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                      Text(
                                        tx('${online ? '🟢 ئۆنلاین' : '⚫ ئۆفلاین'} • $dist • ئەمڕۆ $today گەیاندن'),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: online ? RC.bg(Color(0xFF166534)) : RC.bg(Colors.grey.shade600)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_left_rounded, color: RC.fg(Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDriverPanelTap(Map<String, dynamic> driverProfile) async {
    final order = _selectedOrder;
    if (order == null) {
      _snack('سەرەتا طلبێک هەڵبژێرە (کرتە لەسەر کارت یان دوگمەی ماتۆرسوار)', error: true);
      return;
    }
    await _assignDriverToOrder(order, driverProfile);
  }

  Widget _kpiChip(String label, int count, Color color, String filterKey) {
    final selected = _filter == filterKey;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _filter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : RC.bg(Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : RC.bg(Color(0xFFE2E8F0)), width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Text(
              tx('$count'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, height: 1),
            ),
            const SizedBox(height: 4),
            Text(
              tx(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? color : RC.fg(Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final store = order['store'] as Map<String, dynamic>?;
    final driver = order['driver'] as Map<String, dynamic>?;
    final customer = order['customer'] as Map<String, dynamic>?;
    final items = order['items'] as List<dynamic>? ?? [];
    final color = _statusColor(status);
    final incoming = _isIncoming(status);
    final orderId = order['id'] as int?;
    final selected = orderId != null && orderId == _selectedOrderId;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        if (orderId == null) return;
        setState(() => _selectedOrderId = orderId);
        await _refreshDriversForOrder(order);
        if (!mounted) return;
        if (MediaQuery.sizeOf(context).width < AdminBreakpoints.phone) {
          await _showDriversBottomSheet();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AdminSurfaces.of(context).card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? RC.bg(Color(0xFF16A34A))
                : (incoming ? RC.bg(Color(0xFFF59E0B)) : RC.bg(Color(0xFFE2E8F0))),
            width: selected || incoming ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: RC.bg(Colors.black).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tx(order['order_number']?.toString() ?? 'RA-?'),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: RC.fg(Color(0xFFEA580C))),
                  ),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFDCFCE7)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(tx('هەڵبژێردراو'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF166534)))),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tx(_statusLabel(status)),
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                tx('کڕیار: ${customer?['name'] ?? order['customer_name'] ?? '—'}  •  ${IraqPhoneFormatter.display((customer?['phone'] ?? order['customer_phone'] ?? '').toString())}'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Text(
                tx('فرۆشگا: ${store?['name_ku'] ?? '—'}'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: RC.fg(Colors.grey.shade800)),
              ),
              const SizedBox(height: 4),
              Text(
                tx('ناونیشان: ${order['delivery_address'] ?? '—'}'),
                style: TextStyle(fontSize: 12.5, color: RC.fg(Colors.grey.shade700)),
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _assignDriver(order),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: driver == null ? RC.bg(Color(0xFFFEF2F2)) : RC.bg(Color(0xFFF0FDF4)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: driver == null ? RC.bg(Color(0xFFFECACA)) : RC.bg(Color(0xFFBBF7D0))),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.two_wheeler_rounded,
                        size: 18,
                        color: driver == null ? RC.fg(Color(0xFFDC2626)) : RC.bg(Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx('ماتۆرسوار: ${driver?['name'] ?? 'دیاری نەکراوە — کرتە بکە بۆ هەڵبژاردن'}'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: driver == null ? RC.bg(Color(0xFFDC2626)) : RC.bg(Color(0xFF166534)),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: driver == null ? RC.fg(Color(0xFFDC2626)) : RC.bg(Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: items.take(5).map((raw) {
                    final it = raw as Map<String, dynamic>;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminSurfaces.of(context).chipFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tx('${it['product_name'] ?? 'بەرهەم'} × ${it['quantity'] ?? 1}'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tx(formatIqd(order['total_amount'] as num?, lang: widget.lang)),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: RC.fg(Color(0xFFB45309))),
                  ),
                  if (incoming) ...[
                    TextButton(
                      onPressed: () => _setStatus(order, 'rejected', reason: 'ڕەتکرایەوە لە وەرگرتنی طلب'),
                      child: Text(tx('ڕەتکردنەوە'), style: TextStyle(color: RC.fg(Color(0xFFDC2626)), fontWeight: FontWeight.w800)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFF16A34A)),
                        foregroundColor: RC.fg(Colors.white),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _setStatus(order, 'preparing'),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(tx('قبوڵکردن'), style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _assignDriver(order),
                      icon: const Icon(Icons.two_wheeler_rounded, size: 17),
                      label: Text(
                        tx(driver == null ? 'ناردنی ماتۆرسوار' : 'گۆڕینی شۆفێر'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ] else if (status == 'preparing') ...[
                    OutlinedButton.icon(
                      onPressed: () => _assignDriver(order),
                      icon: const Icon(Icons.two_wheeler_rounded, size: 17),
                      label: Text(
                        tx(driver == null ? 'ناردنی ماتۆرسوار' : 'گۆڕینی شۆفێر'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFF16A34A)),
                        foregroundColor: RC.fg(Colors.white),
                      ),
                      onPressed: () => _setStatus(order, 'ready'),
                      child: Text(tx('ئامادەیە'), style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ] else if (status == 'ready') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFF16A34A)),
                        foregroundColor: RC.fg(Colors.white),
                      ),
                      onPressed: () => _assignDriver(order),
                      icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                      label: Text(
                        tx(driver == null ? 'ناردنی ماتۆرسوار' : 'گۆڕینی شۆفێر'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () => _assignDriver(order),
                      icon: const Icon(Icons.two_wheeler_rounded, size: 17),
                      label: Text(tx('شۆفێر'), style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFF059669)),
                        foregroundColor: RC.fg(Colors.white),
                      ),
                      onPressed: () => _setStatus(order, 'delivered'),
                      child: Text(tx('تەواوکردن'), style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
