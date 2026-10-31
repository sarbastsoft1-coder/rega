import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'live_radar_dialog.dart';

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
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<dynamic> _orders = [];
  Map<String, dynamic> _counts = {};
  List<dynamic> _drivers = [];

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
        widget.api.getOrders(status: _statusFilter, search: _searchCtrl.text.trim()),
        widget.api.getDrivers(isVerified: true),
      ]);
      final ordersRes = results[0] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _orders = ordersRes['data'] as List<dynamic>? ?? [];
          _counts = ordersRes['counts'] as Map<String, dynamic>? ?? {};
          _drivers = results[1] as List<dynamic>;
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

  Future<void> _showAssignDriverDialog(Map<String, dynamic> order) async {
    final orderId = order['id'] as int;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('دیاریکردنی شۆفێر بۆ ${order['order_number']}'),
        content: SizedBox(
          width: 440,
          child: _drivers.isEmpty
              ? const Text('هیچ شۆفێرێکی پشتڕاستکراو بەردەست نییە.')
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
                        backgroundColor: (online ? RegaColors.emerald : Colors.grey).withValues(alpha: 0.16),
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          color: online ? RegaColors.emeraldDark : Colors.grey,
                        ),
                      ),
                      title: Text(
                        '${u['name'] ?? ''} (${dp['driver_code'] ?? ''})',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('${dp['motor_type'] ?? ''} • ${u['phone'] ?? ''}'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await widget.api.assignDriver(orderId, u['id'] as int);
                            _showSnack('شۆفێر بە سەرکەوتوویی دیاریکرا');
                            widget.onOrderChanged?.call();
                            _load();
                          } catch (e) {
                            _showSnack(e.toString(), error: true);
                          }
                        },
                        child: Text(online ? 'دیاریکردن (ئۆنلاین)' : 'دیاریکردن'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
        ],
      ),
    );
  }

  Future<void> _showOrderDetailsModal(int orderId) async {
    try {
      final detail = await widget.api.getOrderDetails(orderId);
      if (!mounted) return;

      final items = detail['items'] as List<dynamic>? ?? [];
      final logs = detail['status_logs'] as List<dynamic>? ?? [];
      final store = detail['store'] as Map<String, dynamic>?;
      final driver = detail['driver'] as Map<String, dynamic>?;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('وردەکاری داواکاری ${detail['order_number']}'),
              StatusBadge(status: detail['status']?.toString() ?? 'pending', lang: widget.lang),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dual Security PIN Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        Text(
                          '🔑 کۆدی ڕادەستکردنی فرۆشگا بە شۆفێر (Handover PIN): ${detail['handover_pin'] ?? '----'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B21A8),
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          '🛡️ کۆدی وەرگرتنی کڕیار (Delivery PIN): ${detail['delivery_pin'] ?? '----'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: RegaColors.emeraldDark,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Parties Info
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _InfoMiniBox(
                        title: 'فرۆشگا',
                        line1: store?['name_ku']?.toString() ?? '-',
                        line2: store?['phone']?.toString() ?? '',
                      ),
                      _InfoMiniBox(
                        title: 'کڕیار و ناونیشان',
                        line1: '${detail['customer_name'] ?? ''} (${detail['customer_phone'] ?? ''})',
                        line2: detail['delivery_address']?.toString() ?? '',
                      ),
                      _InfoMiniBox(
                        title: 'شۆفێر',
                        line1: driver?['name']?.toString() ?? 'دیاری نەکراوە',
                        line2: driver?['phone']?.toString() ?? 'گرتە لە دیاریکردنی شۆفێر بکە',
                      ),
                    ],
                  ),
                  if (detail['customer_notes'] != null && detail['customer_notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '📝 تێبینی کڕیار: ${detail['customer_notes']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Items Table
                  const Text('کاڵاکانی داواکاری:', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...items.map((raw) {
                    final it = raw as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${it['quantity']} × ${it['product_name']}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            formatIqd(it['line_total'] as num?, lang: widget.lang),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),

                  // Financial Split Summary
                  _FinanceRow('کۆی نرخی کاڵاکان (Subtotal)', formatIqd(detail['subtotal'] as num?, lang: widget.lang)),
                  _FinanceRow('داشکاندن (Discount)', '- ${formatIqd(detail['discount_amount'] as num?, lang: widget.lang)}'),
                  _FinanceRow('کرێی گەیاندن (Delivery Fee)', formatIqd(detail['delivery_fee'] as num?, lang: widget.lang)),
                  _FinanceRow('بەخشیش + پاداشتی چاوەڕوانی شۆفێر', formatIqd(((detail['driver_tip'] as num? ?? 0) + (detail['waiting_bonus'] as num? ?? 0)), lang: widget.lang)),
                  _FinanceRow(
                    'کۆمیسیۆنی ڕێگا (${detail['commission_rate']}%)',
                    formatIqd(detail['commission_amount'] as num?, lang: widget.lang),
                    highlight: RegaColors.goldDark,
                  ),
                  _FinanceRow(
                    'صافی فرۆشیار (Vendor Net)',
                    formatIqd(detail['vendor_net_amount'] as num?, lang: widget.lang),
                    highlight: RegaColors.blue,
                  ),
                  _FinanceRow(
                    'کۆی گشتی حساب (Grand Total)',
                    formatIqd(detail['total_amount'] as num?, lang: widget.lang),
                    highlight: RegaColors.emeraldDark,
                    bold: true,
                  ),
                  const SizedBox(height: 18),

                  // Quick Status Control Buttons
                  const Text('گۆڕینی ڕاستەوخۆی بارودۆخ (Admin Override):', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final st in ['preparing', 'ready', 'picked_up', 'on_the_way', 'delivered', 'cancelled'])
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await widget.api.updateOrderStatus(orderId, st);
                              _showSnack('بارودۆخ گۆڕدرا بۆ ${AppStrings.statusLabel(st, widget.lang)}');
                              widget.onOrderChanged?.call();
                              _load();
                            } catch (e) {
                              _showSnack(e.toString(), error: true);
                            }
                          },
                          child: Text(AppStrings.statusLabel(st, widget.lang), style: const TextStyle(fontSize: 12)),
                        ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await widget.api.addWaitingBonus(orderId, 1000);
                            _showSnack('پاداشتی چاوەڕوانی (+١,٠٠٠ د.ع) زیادکرا بۆ شۆفێر');
                            _load();
                          } catch (e) {
                            _showSnack(e.toString(), error: true);
                          }
                        },
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('+١,٠٠٠ د.ع پاداشتی چاوەڕوانی'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Timeline Logs
                  if (logs.isNotEmpty) ...[
                    const Text('مێژووی جووڵەی داواکاری (Audit Trail):', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    ...logs.map((raw) {
                      final l = raw as Map<String, dynamic>;
                      final actor = l['actor'] as Map<String, dynamic>?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• [${l['to_status']}] ${l['note'] ?? ''} — (${actor?['name'] ?? l['actor_role'] ?? 'سیستەم'})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      );
                    }),
                  ],
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

  @override
  Widget build(BuildContext context) {
    final filterTabs = [
      ('all', 'هەمووی', _counts['all']),
      ('active', 'چالاک', _counts['active']),
      ('pending', 'چاوەڕوان', _counts['pending']),
      ('preparing', 'لە ئامادەکردن', _counts['preparing']),
      ('ready', 'ئامادەیە', _counts['ready']),
      ('in_transit', 'لە ڕێگا', _counts['in_transit']),
      ('delivered', 'گەیەندراو', _counts['delivered']),
      ('cancelled', 'هەڵوەشاوە', _counts['cancelled']),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: AppStrings.tr('nav_orders', widget.lang),
                subtitle: 'چاودێریکردنی زیندووی داواکارییەکان، دیاریکردنی شۆفێر و کۆدەکانی پاراستن',
                trailing: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RegaColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AdminLiveRadarDialog(api: widget.api),
                        );
                      },
                      icon: const Icon(Icons.radar_rounded, size: 18),
                      label: const Text('ڕاداری زیندووی شۆفێران (1s Map)', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchCtrl,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                          hintText: 'گەڕان بە کۆدی داواکاری یان کڕیار...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            onPressed: _load,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filterTabs.map((t) {
                    final selected = _statusFilter == t.$1;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        selected: selected,
                        selectedColor: RegaColors.gold,
                        label: Text(
                          '${t.$2} (${t.$3 ?? 0})',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: selected ? const Color(0xFF0F172A) : null,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _statusFilter = t.$1);
                          _load();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : _orders.isEmpty
                      ? const Center(child: Text('هیچ داواکارییەک لەم بەشەدا نییە.'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: _orders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, idx) {
                              final o = _orders[idx] as Map<String, dynamic>;
                              final store = o['store'] as Map<String, dynamic>?;
                              final driver = o['driver'] as Map<String, dynamic>?;
                              final zone = o['neighborhood'] as Map<String, dynamic>?;
                              final items = o['items'] as List<dynamic>? ?? [];

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 12,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                o['order_number']?.toString() ?? '',
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                              ),
                                              const SizedBox(width: 10),
                                              StatusBadge(status: o['status']?.toString() ?? 'pending', lang: widget.lang),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '🏪 ${store?['name_ku'] ?? '-'}  •  👤 ${o['customer_name'] ?? ''} (${o['customer_phone'] ?? ''})',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '📍 ${zone?['name_ku'] ?? ''} — ${o['delivery_address'] ?? ''}  •  📦 ${items.length} جۆر کاڵا',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                formatIqd(o['total_amount'] as num?, lang: widget.lang),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: RegaColors.emeraldDark,
                                                ),
                                              ),
                                              Text(
                                                'کۆمیسیۆن: ${formatIqd(o['commission_amount'] as num?, lang: widget.lang)}',
                                                style: const TextStyle(fontSize: 11.5, color: RegaColors.goldDark, fontWeight: FontWeight.w700),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 14),
                                          OutlinedButton.icon(
                                            onPressed: () => _showAssignDriverDialog(o),
                                            icon: const Icon(Icons.two_wheeler_rounded, size: 17),
                                            label: Text(
                                              driver != null ? driver['name'].toString() : 'دیاریکردنی شۆفێر',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => _showOrderDetailsModal(o['id'] as int),
                                            child: const Text('وردەکاری و کۆنترۆڵ'),
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
        ),
      ],
    );
  }
}

class _InfoMiniBox extends StatelessWidget {
  final String title;
  final String line1;
  final String line2;

  const _InfoMiniBox({required this.title, required this.line1, required this.line2});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(line1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(line2, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;
  final bool bold;

  const _FinanceRow(this.label, this.value, {this.highlight, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 14.5 : 12.5,
              fontWeight: FontWeight.w900,
              color: highlight,
            ),
          ),
        ],
      ),
    );
  }
}

