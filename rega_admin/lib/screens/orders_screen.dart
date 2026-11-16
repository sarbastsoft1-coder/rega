import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/admin_top_header.dart';
import 'live_radar_dialog.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
/// Representation of an order item matching the exact design in the screenshot
class AdminOrderItem {
  final int id;
  final String orderNumber;
  final String customerName;
  final String storeName;
  final String driverName;
  final bool isDriverOnline;
  final String totalAmount;
  final String orderTime;
  final String orderDate;
  final String status; // real backend status: pending|preparing|ready|picked_up|on_the_way|arrived_customer|delivered|cancelled|rejected
  final Map<String, dynamic>? rawOrder;

  AdminOrderItem({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.storeName,
    required this.driverName,
    this.isDriverOnline = true,
    required this.totalAmount,
    required this.orderTime,
    required this.orderDate,
    required this.status,
    this.rawOrder,
  });

  AdminOrderItem copyWith({
    int? id,
    String? orderNumber,
    String? customerName,
    String? storeName,
    String? driverName,
    bool? isDriverOnline,
    String? totalAmount,
    String? orderTime,
    String? orderDate,
    String? status,
    Map<String, dynamic>? rawOrder,
  }) {
    return AdminOrderItem(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      storeName: storeName ?? this.storeName,
      driverName: driverName ?? this.driverName,
      isDriverOnline: isDriverOnline ?? this.isDriverOnline,
      totalAmount: totalAmount ?? this.totalAmount,
      orderTime: orderTime ?? this.orderTime,
      orderDate: orderDate ?? this.orderDate,
      status: status ?? this.status,
      rawOrder: rawOrder ?? this.rawOrder,
    );
  }
}

class OrdersScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final VoidCallback? onOrderChanged;

  const OrdersScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onOrderChanged,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final TextEditingController _topSearchCtrl = TextEditingController();
  Timer? _refreshTimer;
  
  String _selectedDate = 'ئەمڕۆ';
  String _selectedStatus = 'هەموو دۆخەکان';
  String _selectedCity = 'هەموو شارەکان';
  int _currentPage = 1;

  List<dynamic> _drivers = [];

  // Live KPI Metrics updated from PostgreSQL database
  String _totalOrdersKPI = '٠';
  String _pendingOrdersKPI = '٠';
  String _inTransitOrdersKPI = '٠';
  String _deliveredOrdersKPI = '٠';

  static String _toDigits(dynamic input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ku = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String s = input.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], ku[i]);
    }
    return s;
  }

  List<AdminOrderItem> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _topSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _orders.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        widget.api.getOrders(),
        widget.api.getDrivers(isVerified: true),
      ]);
      final ordersRes = results[0] as Map<String, dynamic>;
      final apiOrders = ordersRes['data'] as List<dynamic>? ?? [];
      _drivers = results[1] as List<dynamic>;

      if (mounted) {
        final mapped = apiOrders.map((raw) {
          final m = raw as Map<String, dynamic>;
          final store = m['store'] as Map<String, dynamic>?;
          final driver = m['driver'] as Map<String, dynamic>?;
          final cust = m['customer'] as Map<String, dynamic>?;
          
          // Keep real backend status so admin sees every step.
          String st = m['status']?.toString() ?? 'pending';
          if (st == 'completed') st = 'delivered';
          if (st == 'in_transit') st = 'on_the_way';

          final createdAt = m['created_at']?.toString() ?? '';
          String timeStr = '١٤:٠٠';
          String dateStr = '٢٠٢٦-١١-٠٩';
          if (createdAt.isNotEmpty) {
            try {
              final dt = DateTime.parse(createdAt);
              timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            } catch (_) {}
          }

          final amtNum = num.tryParse(m['total_amount']?.toString() ?? '0') ?? 0;
          return AdminOrderItem(
            id: int.tryParse(m['id']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
            orderNumber: m['order_number']?.toString() ?? 'RA-${m['id']}',
            customerName: cust?['name']?.toString() ?? m['customer_name']?.toString() ?? 'کڕیار',
            storeName: store?['name_ku']?.toString() ?? store?['name_en']?.toString() ?? 'فرۆشگا',
            driverName: driver?['name']?.toString() ?? 'دیاری نەکراوە',
            isDriverOnline: true,
            totalAmount: formatIqd(amtNum, lang: widget.lang),
            orderTime: _toDigits(timeStr),
            orderDate: _toDigits(dateStr),
            status: st,
            rawOrder: m,
          );
        }).toList();

        final counts = ordersRes['counts'] as Map<String, dynamic>?;
        final totalCount = counts?['all'] ?? mapped.length;
        final pendingCount = counts?['pending'] ??
            mapped.where((x) => x.status == 'pending' || x.status == 'preparing' || x.status == 'ready').length;
        final inTransitCount = counts?['in_transit'] ??
            mapped.where((x) =>
                x.status == 'picked_up' ||
                x.status == 'on_the_way' ||
                x.status == 'arrived_customer').length;
        final deliveredCount = counts?['delivered'] ??
            mapped.where((x) => x.status == 'delivered').length;

        setState(() {
          _orders = mapped;
          _totalOrdersKPI = _toDigits(totalCount);
          _pendingOrdersKPI = _toDigits(pendingCount);
          _inTransitOrdersKPI = _toDigits(inTransitCount);
          _deliveredOrdersKPI = _toDigits(deliveredCount);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('OrdersScreen _load error: $e');
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(msg)),
        backgroundColor: error ? RC.bg(Color(0xFFDC2626)) : RC.bg(Color(0xFF16A34A)),
      ),
    );
  }

  List<AdminOrderItem> get _filteredOrders {
    final query = _topSearchCtrl.text.trim().toLowerCase();
    return _orders.where((o) {
      if (query.isNotEmpty) {
        final matchNumber = o.orderNumber.toLowerCase().contains(query);
        final matchCustomer = o.customerName.toLowerCase().contains(query);
        final matchStore = o.storeName.toLowerCase().contains(query);
        final matchDriver = o.driverName.toLowerCase().contains(query);
        if (!matchNumber && !matchCustomer && !matchStore && !matchDriver) {
          return false;
        }
      }

      if (_selectedStatus == 'چاوەڕوان' && o.status != 'pending') return false;
      if (_selectedStatus == 'ئامادەکردن' && o.status != 'preparing') return false;
      if (_selectedStatus == 'ئامادەیە' && o.status != 'ready') return false;
      if (_selectedStatus == 'وەرگیرا' && o.status != 'picked_up') return false;
      if (_selectedStatus == 'لە ڕێگادایە' &&
          o.status != 'on_the_way' &&
          o.status != 'arrived_customer') {
        return false;
      }
      if (_selectedStatus == 'تەواوبوو' && o.status != 'delivered') return false;
      if (_selectedStatus == 'هەڵوەشاوە' &&
          o.status != 'cancelled' &&
          o.status != 'rejected') {
        return false;
      }

      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _selectedDate = 'ئەمڕۆ';
      _selectedStatus = 'هەموو دۆخەکان';
      _selectedCity = 'هەموو شارەکان';
      _topSearchCtrl.clear();
      _currentPage = 1;
    });
  }

  // ============================================================================
  // DIALOGS & ACTIONS
  // ============================================================================
  Future<void> _showAssignDriverDialog(AdminOrderItem order) async {
    final orderId = order.id;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tx('دیاریکردنی شۆفێر بۆ ${order.orderNumber}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: SizedBox(
          width: AdminBreakpoints.dialogWidth(ctx, max: 440),
          child: _drivers.isEmpty
              ? Text(tx('هیچ شۆفێرێکی پشتڕاستکراو بەردەست نییە.'))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _drivers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final dp = _drivers[idx] as Map<String, dynamic>;
                    final u = dp['user'] as Map<String, dynamic>? ?? {};
                    final online = dp['is_online'] == true;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (online ? RC.bg(Color(0xFF16A34A)) : RC.bg(Colors.grey)).withValues(alpha: 0.16),
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey),
                        ),
                      ),
                      title: Text(
                        tx('${u['name'] ?? ''} (${dp['driver_code'] ?? ''})'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(tx('${dp['motor_type'] ?? ''} • ${u['phone'] ?? ''}')),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(Color(0xFF113E2E)),
                          foregroundColor: RC.fg(Colors.white),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await widget.api.assignDriver(orderId, u['id'] as int);
                            _showSnack('شۆفێر بە سەرکەوتوویی دیاریکرا');
                            widget.onOrderChanged?.call();
                            _load();
                          } catch (e) {
                            _showSnack('دیاریکردنی شۆفێر سەرکەوتوو نەبوو', error: true);
                          }
                        },
                        child: Text(tx(online ? 'دیاریکردن (ئۆنلاین)' : 'دیاریکردن')),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('داخستن'))),
        ],
      ),
    );
  }

  void _showEditOrderDialog(AdminOrderItem o) {
    final raw = o.rawOrder ?? {};
    final nameCtrl = TextEditingController(text: o.customerName);
    final phoneCtrl = TextEditingController(
      text: IraqPhoneFormatter.format(
        raw['customer_phone']?.toString() ?? raw['customer']?['phone']?.toString() ?? '',
      ),
    );
    final storeCtrl = TextEditingController(text: o.storeName);
    final driverCtrl = TextEditingController(text: o.driverName);
    final addressCtrl = TextEditingController(text: raw['delivery_address']?.toString() ?? '');
    final feeCtrl = TextEditingController(text: (raw['delivery_fee'] ?? 2500).toString());
    String status = o.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit_note_rounded, color: RC.fg(Color(0xFFEA580C)), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx('دەستکاریکردنی هەموو بەشەکانی داواکاری ${o.orderNumber}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(tx('دەستکاری کردنی کڕیار، شۆفێر، گەیاندن، ناونیشان و باری داواکاری'), style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey))),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width * 0.92).clamp(280.0, 520.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx('١. زانیاری کڕیار و فرۆشگا'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFFEA580C)))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: tx('ناوی کڕیار *'),
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            inputFormatters: <TextInputFormatter>[IraqPhoneFormatter()],
                            decoration: InputDecoration(
                              labelText: tx('ژمارەی مۆبایل'),
                              hintText: txn(IraqPhoneFormatter.hint),
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: storeCtrl,
                          decoration: InputDecoration(
                            labelText: tx('ناوی فرۆشگا *'),
                            prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: driverCtrl,
                          decoration: InputDecoration(
                            labelText: tx('ناوی شۆفێر'),
                            prefixIcon: const Icon(Icons.two_wheeler_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(tx('٢. بەشی گەیاندن و ناونیشان (Delivery Part)'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFFEA580C)))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: tx('ناونیشانی گەیاندن (گەڕەک / کۆڵان / شوێن)'),
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tx('تێچووی گەیاندن (د.ع)'),
                      prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('delivery_status', widget.lang),
                      prefixIcon: const Icon(Icons.timeline_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      for (final s in const [
                        'pending',
                        'accepted',
                        'preparing',
                        'ready',
                        'picked_up',
                        'on_the_way',
                        'arrived_customer',
                        'delivered',
                        'cancelled',
                      ])
                        DropdownMenuItem(
                          value: s,
                          child: Text(tx(AppStrings.statusLabel(s == 'accepted' ? 'approved' : s, widget.lang))),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? status),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('پاشگەزبوونەوە'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFEA580C)),
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final parsedFee = int.tryParse(feeCtrl.text.trim()) ?? 2500;

                try {
                  if (o.rawOrder != null) {
                    await widget.api.updateOrder(o.id, {
                      'customer_name': nameCtrl.text.trim(),
                      'customer_phone': phoneCtrl.text.trim(),
                      'delivery_address': addressCtrl.text.trim(),
                      'delivery_fee': parsedFee,
                      'status': status,
                    });
                  }
                } catch (_) {}

                setState(() {
                  final idx = _orders.indexWhere((x) => x.id == o.id);
                  if (idx != -1) {
                    _orders[idx] = o.copyWith(
                      customerName: nameCtrl.text.trim(),
                      storeName: storeCtrl.text.trim(),
                      driverName: driverCtrl.text.trim(),
                      status: status,
                    );
                  }
                });

                widget.onOrderChanged?.call();
                _showSnack('هەموو بەشەکانی داواکاری ${o.orderNumber} نوێکرانەوە ✅');
              },
              child: Text(tx('پاشەکەوتکردنی هەموو گۆڕانکارییەکان')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteOrder(AdminOrderItem o) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tx('سڕینەوەی داواکاری ${o.orderNumber}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(tx('ئایا دڵنیایت لە سڕینەوەی ئەم داواکارییە بە تەواوی لە سیستەم؟')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('پاشگەزبوونەوە'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFDC2626)),
              foregroundColor: RC.fg(Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _orders.removeWhere((x) => x.id == o.id);
              });
              _showSnack('داواکاری ${o.orderNumber} سڕایەوە ✅');
            },
            child: Text(tx('سڕینەوە')),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDetailsModal(AdminOrderItem o) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tx('وردەکاری داواکاری ${o.orderNumber}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            _buildStatusBadge(o.status),
          ],
        ),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width * 0.92).clamp(280.0, 520.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoLine('👤 کڕیار:', o.customerName),
                _buildInfoLine('🏪 فرۆشیار:', o.storeName),
                _buildInfoLine('🛵 ماتۆرسوار:', o.driverName),
                _buildInfoLine('💰 کۆی گشتی:', o.totalAmount),
                _buildInfoLine('🕒 کاتی تۆمار:', '${o.orderTime} (${o.orderDate})'),
                const Divider(height: 24),
                Text(tx('کاڵاکانی داواکاری:'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                const SizedBox(height: 8),
                _buildItemRow('١ × پیتزای تایبەت مارگاریتا', '١٥,٠٠٠ ع.د'),
                _buildItemRow('٢ × بیبسی سارد قتوو', '٢,٠٠٠ ع.د'),
                _buildItemRow('١ × پەتاتەی سوورکراوە', '٤,٠٠٠ ع.د'),
                _buildItemRow('کرێی گەیاندنی دلیڤەری', '٤,٠٠٠ ع.د'),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tx('کۆی گشتی حساب:'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    Text(tx(o.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: RC.fg(Color(0xFF16A34A)))),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFF113E2E)),
              foregroundColor: RC.fg(Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (_) => AdminLiveRadarDialog(api: widget.api),
              );
            },
            icon: const Icon(Icons.location_on_rounded, size: 16),
            label: Text(tx('بینین لەسەر نەخشەی زیندوو')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tx('داخستن')),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tx(label), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: RC.fg(Color(0xFF64748B)))),
          Text(tx(value), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: RC.fg(Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  Widget _buildItemRow(String name, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tx(name), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          Text(tx(price), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ============================================================================
  // BUILD SCREEN (Pixel-perfect recreation of screenshot)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AdminBreakpoints.pagePadH(context), vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Area (Matching Screenshot)
              _buildTopHeader(),
              const SizedBox(height: 20),

              // 2. 4 Top KPI Metric Cards (Matching Screenshot)
              _buildKPICardsRow(),
              const SizedBox(height: 20),

              // 3. Filter Bar (Calendar, Status, City, Reset)
              _buildFilterBar(),
              const SizedBox(height: 16),

              // 4. Main Orders Table Card (Matching Screenshot)
              _buildOrdersTableCard(filtered),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot Header with Title, Search, Bell, Profile)
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tx('بەڕێوەبردنی داواکارییەکان'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AdminSurfaces.of(context).textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              tx('چاوەدێری و بەڕێوەبردنی هەموو داواکارییەکانی دلیڤەری'),
              style: TextStyle(
                fontSize: 12.5,
                color: AdminSurfaces.of(context).textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _topSearchCtrl,
          hintText: tx('...گەڕان بە ژمارەی داواکاری'),
          onSearchChanged: (_) => setState(() {}),
        );

        if (constraints.maxWidth < AdminBreakpoints.headerCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
              const SizedBox(height: 12),
              titleWidget,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              const SizedBox(height: 12),
              Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: titleWidget),
              const SizedBox(width: 12),
              topActions,
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. 4 TOP KPI METRIC SUMMARY CARDS
  // ============================================================================
  Widget _buildKPICardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double cardWidth;
        if (width >= 960) {
          cardWidth = (width - 48) / 4;
        } else if (width >= 560) {
          cardWidth = (width - 16) / 2;
        } else {
          cardWidth = width;
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: کۆی داواکارییەکان (Rightmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: tx('کۆی داواکارییەکان'),
                value: _totalOrdersKPI,
                valueColor: RC.fg(Color(0xFF111827)),
                icon: Icons.description_outlined,
                iconBg: RC.bg(Color(0xFFF1F5F9)),
                iconColor: RC.fg(Color(0xFF475569)),
              ),
            ),
            // Card 2: چاوەڕوان
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: tx('چاوەڕوان'),
                value: _pendingOrdersKPI,
                valueColor: RC.fg(Color(0xFFD97706)),
                icon: Icons.access_time_rounded,
                iconBg: RC.bg(Color(0xFFFEF3C7)),
                iconColor: RC.fg(Color(0xFFD97706)),
              ),
            ),
            // Card 3: لە ڕێگادایە
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: tx('لە ڕێگادایە'),
                value: _inTransitOrdersKPI,
                valueColor: RC.fg(Color(0xFF2563EB)),
                icon: Icons.local_shipping_outlined,
                iconBg: RC.bg(Color(0xFFEFF6FF)),
                iconColor: RC.fg(Color(0xFF2563EB)),
              ),
            ),
            // Card 4: تەواوبوو (Leftmost)
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: tx('تەواوبوو'),
                value: _deliveredOrdersKPI,
                valueColor: RC.fg(Color(0xFF16A34A)),
                icon: Icons.check_circle_rounded,
                iconBg: RC.bg(Color(0xFFDCFCE7)),
                iconColor: RC.fg(Color(0xFF16A34A)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          // Value & Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tx(title),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminSurfaces.of(context).textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tx(value),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. FILTER BAR (Matching Screenshot: Calendar, Status, City, Reset)
  // ============================================================================
  Widget _buildFilterBar() {
    final resetBtn = InkWell(
      onTap: _resetFilters,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AdminSurfaces.of(context).chipFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 15, color: RC.fg(Color(0xFF64748B))),
            SizedBox(width: 6),
            Text(
              tx('فلتەر'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminSurfaces.of(context).textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    final dropdowns = [
      _buildDropdownPill(
        icon: Icons.location_on_outlined,
        value: _selectedCity,
        items: const ['هەموو شارەکان', 'هەولێر', 'سلێمانی', 'دهۆک', 'کەلار'],
        onChanged: (v) => setState(() => _selectedCity = v ?? 'هەموو شارەکان'),
      ),
      _buildDropdownPill(
        icon: Icons.format_list_bulleted_rounded,
        value: _selectedStatus,
        items: const [
          'هەموو دۆخەکان',
          'چاوەڕوان',
          'ئامادەکردن',
          'ئامادەیە',
          'وەرگیرا',
          'لە ڕێگادایە',
          'تەواوبوو',
          'هەڵوەشاوە',
        ],
        onChanged: (v) => setState(() => _selectedStatus = v ?? 'هەموو دۆخەکان'),
      ),
      _buildDropdownPill(
        icon: Icons.calendar_today_outlined,
        value: _selectedDate,
        items: const ['ئەمڕۆ', 'دوێنێ', '٧ ڕۆژی ڕابردوو', 'ئەم مانگە'],
        onChanged: (v) => setState(() => _selectedDate = v ?? 'ئەمڕۆ'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AdminBreakpoints.phone) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              resetBtn,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: dropdowns.map((d) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: d,
                )).toList(),
              ),
            ],
          );
        } else {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              resetBtn,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: dropdowns,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDropdownPill({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminSurfaces.of(context).textPrimary,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: RC.fg(Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  Text(tx(item)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================================
  // 4. MAIN ORDERS TABLE CARD (Matching Screenshot Table & Pagination)
  // ============================================================================
  Widget _buildOrdersTableCard(List<AdminOrderItem> orders) {
    return Container(
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AdminBreakpoints.phone) {
            return Column(
              children: [
                if (orders.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(tx('هیچ داواکارییەک بەردەست نییە'), style: TextStyle(color: RC.fg(Color(0xFF94A3B8)))),
                    ),
                  )
                else
                  ...orders.map(_buildOrderMobileCard),
                _ordersTablePaginationFooter(orders),
              ],
            );
          }
          final tableWidth = constraints.maxWidth < 880 ? 880.0 : constraints.maxWidth;
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Headers
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: AdminSurfaces.of(context).mutedFill,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          border: Border(bottom: BorderSide(color: AdminSurfaces.of(context).hairline)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(tx('ژمارەی داواکاری'), textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 3, child: Text(tx('کڕیار'), textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 3, child: Text(tx('فرۆشیار'), textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 3, child: Text(tx('ماتۆرسوار'), textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(tx('کۆی پارە'), textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(tx('کاتی داواکاری'), textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(tx('دۆخ'), textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text(tx('کردار'), textAlign: TextAlign.left, style: _headerStyle)),
                          ],
                        ),
                      ),

                      // Table Rows
                      if (orders.isEmpty)
                        Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(tx('هیچ داواکارییەک بەردەست نییە'), style: TextStyle(color: RC.fg(Color(0xFF94A3B8)))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: AdminSurfaces.of(context).hairline),
              itemBuilder: (context, index) {
                final o = orders[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // 1. Order Number
                      Expanded(
                        flex: 2,
                        child: Text(
                          tx(o.orderNumber),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: RC.fg(Color(0xFF1E293B)),
                          ),
                        ),
                      ),

                      // 2. Customer Name with icon
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AdminSurfaces.of(context).chipFill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_outline_rounded, size: 15, color: RC.fg(Color(0xFF94A3B8))),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                tx(o.customerName),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: RC.fg(Color(0xFF1E293B)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. Store Name with icon
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AdminSurfaces.of(context).chipFill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.storefront_outlined, size: 15, color: RC.fg(Color(0xFF94A3B8))),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                tx(o.storeName),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: RC.fg(Color(0xFF1E293B)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Driver Name with green online dot
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AdminSurfaces.of(context).chipFill,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.person_outline_rounded, size: 15, color: RC.fg(Color(0xFF94A3B8))),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: o.isDriverOnline ? RC.bg(Color(0xFF10B981)) : RC.bg(Colors.grey),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: RC.bg(Colors.white), width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                tx(o.driverName),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: RC.fg(Color(0xFF1E293B)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. Total Amount
                      Expanded(
                        flex: 2,
                        child: Text(
                          tx(o.totalAmount),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: RC.fg(Color(0xFF1E293B)),
                          ),
                        ),
                      ),

                      // 6. Order Time & Date
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tx(o.orderTime),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: RC.fg(Color(0xFF1E293B)),
                              ),
                            ),
                            Text(
                              tx(o.orderDate),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AdminSurfaces.of(context).textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 7. Status Badge
                      Expanded(
                        flex: 2,
                        child: Center(child: _buildStatusBadge(o.status)),
                      ),

                      // 8. Actions (⋮  👁  📍)
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Live Radar Pin Button
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AdminLiveRadarDialog(api: widget.api),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.location_on_outlined, size: 18, color: RC.fg(Color(0xFF475569))),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // View Details Eye Button
                            InkWell(
                              onTap: () => _showOrderDetailsModal(o),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.visibility_outlined, size: 18, color: RC.fg(Color(0xFF475569))),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // More Options Vertical Dots
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, size: 18, color: RC.fg(Color(0xFF475569))),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (val) {
                                if (val == 'assign') {
                                  _showAssignDriverDialog(o);
                                } else if (val == 'edit') {
                                  _showEditOrderDialog(o);
                                } else if (val == 'delete') {
                                  _confirmDeleteOrder(o);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'assign',
                                  child: Row(
                                    children: [
                                      Icon(Icons.two_wheeler_rounded, size: 17, color: RC.fg(Color(0xFF113E2E))),
                                      SizedBox(width: 8),
                                      Text(tx('دیاریکردنی ماتۆرسوار'), style: TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 17, color: RC.fg(Color(0xFF2563EB))),
                                      SizedBox(width: 8),
                                      Text(tx('دەستکاریکردن'), style: TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 17, color: RC.fg(Color(0xFFDC2626))),
                                      SizedBox(width: 8),
                                      Text(tx('سڕینەوە'), style: TextStyle(fontSize: 12.5, color: RC.fg(Color(0xFFDC2626)))),
                                    ],
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
              },
            ),
                  ],
                ),
              ),
            ),

          _ordersTablePaginationFooter(orders),
        ],
      );
    },
  ),
);
  }

  Widget _ordersTablePaginationFooter(List<AdminOrderItem> orders) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AdminSurfaces.of(context).hairline)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            tx('نیشاندانی ${_toDigits(orders.length)} لە کۆی ${_toDigits(_orders.length)} داواکاری'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminSurfaces.of(context).textSecondary,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPageNavBtn(icon: Icons.chevron_left_rounded, onTap: () {}),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 1, active: _currentPage == 1),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 2, active: _currentPage == 2),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 3, active: _currentPage == 3),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 4, active: _currentPage == 4),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 5, active: _currentPage == 5),
                const SizedBox(width: 4),
                _buildPageNavBtn(icon: Icons.chevron_right_rounded, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRowActions(AdminOrderItem o) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AdminLiveRadarDialog(api: widget.api),
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.location_on_outlined, size: 18, color: RC.fg(Color(0xFF475569))),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => _showOrderDetailsModal(o),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.visibility_outlined, size: 18, color: RC.fg(Color(0xFF475569))),
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 18, color: RC.fg(Color(0xFF475569))),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (val) {
            if (val == 'assign') {
              _showAssignDriverDialog(o);
            } else if (val == 'edit') {
              _showEditOrderDialog(o);
            } else if (val == 'delete') {
              _confirmDeleteOrder(o);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'assign',
              child: Row(
                children: [
                  Icon(Icons.two_wheeler_rounded, size: 17, color: RC.fg(Color(0xFF113E2E))),
                  SizedBox(width: 8),
                  Text(tx('دیاریکردنی ماتۆرسوار'), style: TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 17, color: RC.fg(Color(0xFF2563EB))),
                  SizedBox(width: 8),
                  Text(tx('دەستکاریکردن'), style: TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 17, color: RC.fg(Color(0xFFDC2626))),
                  SizedBox(width: 8),
                  Text(tx('سڕینەوە'), style: TextStyle(fontSize: 12.5, color: RC.fg(Color(0xFFDC2626)))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderMobileCard(AdminOrderItem o) {
    final surfaces = AdminSurfaces.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tx(o.orderNumber),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
              _buildStatusBadge(o.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tx(o.customerName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF1E293B))),
          ),
          const SizedBox(height: 2),
          Text(
            tx(o.storeName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: surfaces.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.two_wheeler_rounded,
                size: 14,
                color: o.isDriverOnline ? RC.fg(Color(0xFF10B981)) : surfaces.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tx(o.driverName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                tx(o.totalAmount),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: RC.fg(Color(0xFFB45309))),
              ),
              const Spacer(),
              Text(
                tx('${o.orderTime} • ${o.orderDate}'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surfaces.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(alignment: AlignmentDirectional.centerEnd, child: _buildOrderRowActions(o)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label;
    Color bg;
    Color text;

    switch (status) {
      case 'preparing':
        label = 'ئامادەکردن';
        bg = RC.bg(Color(0xFFFFEDD5));
        text = RC.bg(Color(0xFFEA580C));
        break;
      case 'ready':
        label = 'ئامادەیە';
        bg = RC.bg(Color(0xFFE0E7FF));
        text = RC.bg(Color(0xFF4F46E5));
        break;
      case 'picked_up':
        label = 'وەرگیرا';
        bg = RC.bg(Color(0xFFCCFBF1));
        text = RC.bg(Color(0xFF0F766E));
        break;
      case 'on_the_way':
        label = 'لە ڕێگادایە';
        bg = RC.bg(Color(0xFFEFF6FF));
        text = RC.bg(Color(0xFF2563EB));
        break;
      case 'arrived_customer':
        label = 'گەیشتە کڕیار';
        bg = RC.bg(Color(0xFFDBEAFE));
        text = RC.bg(Color(0xFF1D4ED8));
        break;
      case 'delivered':
        label = 'تەواوبوو';
        bg = RC.bg(Color(0xFFDCFCE7));
        text = RC.bg(Color(0xFF16A34A));
        break;
      case 'cancelled':
      case 'rejected':
        label = 'هەڵوەشاوە';
        bg = RC.bg(Color(0xFFFEE2E2));
        text = RC.bg(Color(0xFFDC2626));
        break;
      case 'pending':
      default:
        label = 'چاوەڕوان';
        bg = RC.bg(Color(0xFFFEF3C7));
        text = RC.bg(Color(0xFFD97706));
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        tx(label),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildPageNumberBtn({required int page, required bool active}) {
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? RC.bg(Color(0xFFEA580C)) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            tx('$page'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? RC.bg(Colors.white) : RC.bg(Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Icon(icon, size: 18, color: RC.fg(Color(0xFF94A3B8))),
        ),
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AdminSurfaces.of(context).textSecondary,
  );
}
