import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../map/mapbox_tiles.dart';
import '../widgets/common_widgets.dart';
import 'drivers_screen.dart';
import 'orders_screen.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
class DeliveryPartScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final VoidCallback? onDataChanged;

  const DeliveryPartScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onDataChanged,
  });

  @override
  State<DeliveryPartScreen> createState() => _DeliveryPartScreenState();
}

class _DeliveryPartScreenState extends State<DeliveryPartScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MapController _mapController = MapController();
  Timer? _radarOneSecondTimer;
  Timer? _hubRefreshTimer;

  bool _loading = true;
  String? _error;
  bool _darkMap = true;
  int _radarTicks = 0;

  Map<String, dynamic> _kpis = {};
  List<dynamic> _drivers = [];
  List<dynamic> _dispatchQueue = [];
  List<dynamic> _radarDrivers = [];
  List<dynamic> _radarSessions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
    _fetchLiveRadarTick();
    _radarOneSecondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tabController.index == 0) {
        _fetchLiveRadarTick();
      }
    });
    _hubRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _radarOneSecondTimer?.cancel();
    _hubRefreshTimer?.cancel();
    _mapController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveRadarTick() async {
    try {
      final radar = await widget.api.getLiveRadar();
      if (!mounted) return;
      setState(() {
        _radarTicks += 1;
        _radarDrivers = radar['drivers'] as List<dynamic>? ?? [];
        _radarSessions = radar['live_sessions'] as List<dynamic>? ?? [];
      });
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final hubs = await widget.api.getEcosystemHubs();
      final dp = hubs['delivery_part'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _kpis = dp['kpis'] as Map<String, dynamic>? ?? {};
        _drivers = dp['drivers'] as List<dynamic>? ?? [];
        _dispatchQueue = dp['dispatch_queue'] as List<dynamic>? ?? [];
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

  void _showAssignDriverDialog(Map<String, dynamic> order) {
    if (_drivers.isEmpty) {
      _showSnack('هیچ شۆفێرێک بەردەست نییە', error: true);
      return;
    }
    final drivers = _drivers.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) {
        final ao = a['is_online'] == true ? 0 : 1;
        final bo = b['is_online'] == true ? 0 : 1;
        return ao.compareTo(bo);
      });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tx('دیاریکردنی ماتۆرسوار بۆ ${order['order_number']}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: SizedBox(
          width: AdminBreakpoints.dialogWidth(ctx, max: 460),
          height: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 420),
          child: ListView.separated(
            itemCount: drivers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) {
              final dp = drivers[idx];
              final u = dp['user'] as Map<String, dynamic>? ?? {};
              final online = dp['is_online'] == true;
              final userId = (u['id'] as num?)?.toInt() ?? (dp['user_id'] as num?)?.toInt();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.two_wheeler_rounded, color: online ? RegaColors.emeraldDark : RC.bg(Colors.grey)),
                title: Text(
                  tx('${u['name'] ?? dp['name'] ?? ''} (${dp['driver_code'] ?? ''})'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  tx('${online ? '🟢 ئۆنلاین' : '⚫ ئۆفلاین'} • ${u['phone'] ?? dp['phone'] ?? ''}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RegaColors.emeraldDark,
                    foregroundColor: RC.fg(Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: userId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await widget.api.assignDriver(order['id'] as int, userId);
                            _showSnack('ماتۆرسوار دیاریکرا ✅');
                            widget.onDataChanged?.call();
                            _load(silent: true);
                          } catch (e) {
                            _showSnack(e.toString(), error: true);
                          }
                        },
                  child: Text(tx(online ? 'پێدان' : 'دیاریکردن')),
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

  Future<void> _completeDelivery(Map<String, dynamic> order) async {
    try {
      await widget.api.verifyDeliveryPin(order['id'] as int);
      _showSnack('گەیاندن تەواوکرا و حسابەکان لە PostgreSQL یەکلاکرانەوە ✅');
      widget.onDataChanged?.call();
      _load(silent: true);
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _showSettleDriverCodDialog(Map<String, dynamic> driverProfile) {
    final cashHeld = (driverProfile['cash_collected_hand'] as num?)?.toInt() ?? 0;
    final amountCtrl = TextEditingController(text: cashHeld > 0 ? '$cashHeld' : '10000');
    final noteCtrl = TextEditingController(
      text: tx('وەرگرتنەوەی پارەی کاشی کۆکراوە (COD) لە شۆفێر ${driverProfile['user']?['name'] ?? ''}'),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        title: Text(
          tx('پاکتاوکردنی کاشی شۆفێر — ${driverProfile['user']?['name'] ?? ''}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: AdminBreakpoints.dialogWidth(ctx, max: 420),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 420),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tx('بڕی کاشی وەرگیراوە لە شۆفێر (د.ع) *')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: tx('تێبینی ژمێریاری')),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('داخستن'))),
          ElevatedButton.icon(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              Navigator.pop(ctx);
              try {
                await widget.api.createPayout({
                  'recipient_type': 'driver_cod_settlement',
                  'user_id': driverProfile['user_id'],
                  'amount': amount,
                  'payment_method': 'cash',
                  'status': 'completed',
                  'notes': noteCtrl.text.trim(),
                });
                _showSnack('پاکتاوی کاشی شۆفێر (COD) بە سەرکەوتوویی تۆمارکرا ✅');
                _load(silent: true);
              } catch (e) {
                _showSnack(e.toString(), error: true);
              }
            },
            icon: const Icon(Icons.task_alt_rounded, size: 18),
            label: Text(tx('وەرگرتن و تۆمارکردن')),
          ),
        ],
      ),
    );
  }

  void _showEditDeliveryOrderDialog(Map<String, dynamic> order) {
    final nameCtrl = TextEditingController(text: order['customer_name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(
      text: IraqPhoneFormatter.format(order['customer_phone']?.toString() ?? ''),
    );
    final addressCtrl = TextEditingController(text: order['delivery_address']?.toString() ?? '');
    final feeCtrl = TextEditingController(text: (order['delivery_fee'] ?? 2500).toString());
    final notesCtrl = TextEditingController(text: order['customer_notes']?.toString() ?? '');
    String status = order['status']?.toString() ?? 'pending';

    int? selectedDriverUserId = (order['driver'] != null && order['driver']['id'] != null)
        ? (order['driver']['id'] as int)
        : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RegaColors.emeraldDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: RegaColors.emeraldDark, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx('دەستکاریکردنی بەشی گەیاندن — ${order['order_number']}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      tx('گۆڕینی شۆفێر، ناونیشان، تێچووی گەیاندن و باری داواکاری'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 520),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 540),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx('١. شۆفێری دیاریکراو و باری گەیاندن'), style: TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: selectedDriverUserId,
                      decoration: InputDecoration(
                        labelText: tx('شۆفێری ماتۆڕسکیل'),
                        prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            tx('❌ بەبێ شۆفێر (دیاری نەکراوە)'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ..._drivers.map((d) {
                          final m = d as Map<String, dynamic>;
                          final online = m['is_online'] == true ? '🟢 ئۆنلاین' : '⚪ ئۆفلاین';
                          return DropdownMenuItem<int?>(
                            value: m['user_id'] as int?,
                            child: Text(
                              tx('${m['user']?['name'] ?? ''} (${m['driver_code']}) — $online'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) => setDialogState(() => selectedDriverUserId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
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
                            child: Text(
                              tx(AppStrings.statusLabel(s == 'accepted' ? 'approved' : s, widget.lang)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setDialogState(() => status = v ?? 'pending'),
                    ),
                    const SizedBox(height: 18),
                    Text(tx('٢. زانیاری کڕیار و ناونیشانی گەیاندن'), style: TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark)),
                    const SizedBox(height: 10),
                    ResponsiveFormRow(
                      breakpoint: 460,
                      first: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: tx('ناوی کڕیار'),
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      second: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        inputFormatters: <TextInputFormatter>[IraqPhoneFormatter()],
                        decoration: InputDecoration(
                          labelText: tx('ژمارەی مۆبایلی کڕیار'),
                          hintText: txn(IraqPhoneFormatter.hint),
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: tx('ناونیشانی تەواوی گەیاندن (گەڕەک / کۆڵان / شوێن)'),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(tx('٣. تێچووی دلیڤەری'), style: TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: feeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tx('نرخی گەیاندن (د.ع)'),
                        prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: tx('تێبینی و ڕێنمایی تایبەت بۆ شۆفێر'),
                        prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tx('پاشگەزبوونەوە'), style: TextStyle(color: RC.fg(Colors.grey))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RegaColors.emeraldDark,
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final orderId = order['id'] as int;
                try {
                  // 1. If driver changed or selected
                  if (selectedDriverUserId != null &&
                      (order['driver'] == null || order['driver']['id'] != selectedDriverUserId)) {
                    await widget.api.assignDriver(orderId, selectedDriverUserId!);
                  }

                  // 2. Update order delivery details
                  final parsedFee = int.tryParse(feeCtrl.text.trim()) ?? (order['delivery_fee'] as int? ?? 2500);
                  await widget.api.updateOrder(orderId, {
                    'customer_name': nameCtrl.text.trim(),
                    'customer_phone': phoneCtrl.text.trim(),
                    'delivery_address': addressCtrl.text.trim(),
                    'delivery_fee': parsedFee,
                    'status': status,
                    'customer_notes': notesCtrl.text.trim(),
                  });

                  _showSnack('هەموو بەشەکانی گەیاندنی داواکاری ${order['order_number']} بە سەرکەوتوویی نوێکرانەوە ✅');
                  widget.onDataChanged?.call();
                  _load(silent: true);
                } catch (e) {
                  _showSnack('هەڵە لە نوێکردنەوە: $e', error: true);
                }
              },
              child: Text(tx('پاشەکەوتکردنی هەموو گۆڕانکارییەکان')),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickDeliverySettingsDialog() async {
    int fee = 2500;
    String hours = '09:00 - 23:00';
    String phone = '0750 000 0000';
    String hotline = '0750 999 8877';

    try {
      final s = await widget.api.getSettings();
      final data = s['data'] as Map<String, dynamic>? ?? {};
      if (data.containsKey('default_delivery_fee')) {
        fee = int.tryParse(data['default_delivery_fee'].toString()) ?? 2500;
      }
      if (data.containsKey('working_hours')) {
        hours = data['working_hours'].toString();
      }
      if (data.containsKey('support_phone')) {
        phone = data['support_phone'].toString();
      }
      if (data.containsKey('driver_hotline')) {
        hotline = data['driver_hotline'].toString();
      }
    } catch (_) {}

    final feeCtrl = TextEditingController(text: fee.toString());
    final hoursCtrl = TextEditingController(text: hours);
    final phoneCtrl = TextEditingController(text: phone);
    final hotlineCtrl = TextEditingController(text: hotline);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RegaColors.emeraldDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune_rounded, color: RegaColors.emeraldDark, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tx('ڕێکخستنی بنەڕەتی گەیاندن (Global Delivery Settings)'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: AdminBreakpoints.dialogWidth(ctx, max: 440),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 500),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tx('نرخی گەیاندنی ماتۆرسوار (د.ع) *'),
                      prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StatefulBuilder(
                    builder: (ctx2, setChipState) {
                      const presets = [1000, 1500, 2000, 2500, 3000];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presets.map((p) {
                          final selected = feeCtrl.text.trim() == p.toString();
                          return ChoiceChip(
                            label: Text(tx('$p د.ع')),
                            selected: selected,
                            onSelected: (_) {
                              feeCtrl.text = p.toString();
                              setChipState(() {});
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: hoursCtrl,
                    decoration: InputDecoration(
                      labelText: tx('کاتژمێری کارکردنی گەیاندن (نموونە: 09:00 - 23:00)'),
                      prefixIcon: const Icon(Icons.access_time_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: hotlineCtrl,
                    decoration: InputDecoration(
                      labelText: tx('هێڵی گەرمی پەیوەندی شۆفێران (Driver Hotline)'),
                      prefixIcon: const Icon(Icons.phone_in_talk_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: tx('ژمارەی مۆبایلی پاڵپشتی ناوەند'),
                      prefixIcon: const Icon(Icons.headset_mic_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('پاشگەزبوونەوە'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.emeraldDark,
              foregroundColor: RC.fg(Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.updateSettings({
                  'default_delivery_fee': int.tryParse(feeCtrl.text.trim()) ?? 2500,
                  'working_hours': hoursCtrl.text.trim(),
                  'driver_hotline': hotlineCtrl.text.trim(),
                  'support_phone': phoneCtrl.text.trim(),
                });
                _showSnack('ڕێکخستنەکانی گەیاندن بە سەرکەوتوویی نوێکرانەوە ✅');
                _load(silent: true);
              } catch (e) {
                _showSnack('هەڵە لە پاشەکەوتکردن: $e', error: true);
              }
            },
            child: Text(tx('پاشەکەوتکردنی ڕێکخستنەکان'), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _fmtMmSs(int sec) {
    final s = sec < 0 ? 0 : sec;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Widget _buildHubTab(IconData icon, String label, bool compact) {
    if (compact) {
      return Tab(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      );
    }
    return Tab(icon: Icon(icon, size: 18), text: label);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = MediaQuery.sizeOf(context).height;
        final padH = AdminBreakpoints.pagePadH(context);
        final isPhone = w < AdminBreakpoints.phone;
        final isShort = h < 640;
        final isCompactBanner = isPhone || isShort;
        final stackHeader = w < 860;
        final btnPadding = isPhone
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : null;

        final titleRow = Row(
          children: [
            Container(
              padding: EdgeInsets.all(isPhone ? 8 : 10),
              decoration: BoxDecoration(
                color: RC.bg(Colors.white).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.two_wheeler_rounded, color: RC.fg(Colors.white), size: isPhone ? 22 : 26),
            ),
            SizedBox(width: isPhone ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx('بەشی گەیاندن و شۆفێران (REGA Delivery & Fleet Hub)'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RC.fg(Colors.white),
                      fontSize: isPhone ? 15.5 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (!isCompactBanner)
                    Text(
                      tx('بەستراوەتەوە بە ئەپی شۆفێران (rega_delivery) • ڕاداری چرکە بە چرکەی کەلار، ناردن، KYC و باڵانسی کاش'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: RC.fg(Colors.white70), fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        );

        final actionsWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Colors.white),
                foregroundColor: RC.fg(Color(0xFF047857)),
                padding: btnPadding,
              ),
              onPressed: () => _showQuickDeliverySettingsDialog(),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                tx('ڕێکخستنی نرخی گەیاندن'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Colors.white),
                foregroundColor: RC.fg(Color(0xFF047857)),
                padding: btnPadding,
              ),
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(
                tx('زیادکردنی شۆفێر'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: RC.bg(Colors.white).withValues(alpha: 0.2),
                foregroundColor: RC.fg(Colors.white),
                padding: btnPadding,
              ),
              onPressed: () {
                _load();
                _fetchLiveRadarTick();
              },
              icon: const Icon(Icons.radar_rounded, size: 18),
              label: Text(
                tx(isPhone
                    ? 'LIVE #$_radarTicks (${_kpis['online_drivers'] ?? 0})'
                    : 'LIVE 1s • تیک #$_radarTicks (${_kpis['online_drivers'] ?? 0} شۆفێری ئۆنلاین)'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

        return Column(
          children: [
            // Delivery Hub Header Banner
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(padH, isCompactBanner ? 8 : 18, padH, 0),
              padding: isCompactBanner
                  ? const EdgeInsets.fromLTRB(12, 10, 12, 6)
                  : const EdgeInsets.fromLTRB(22, 18, 22, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [RC.bg(Color(0xFF059669)), RC.bg(Color(0xFF047857))],
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                ),
                borderRadius: BorderRadius.circular(isCompactBanner ? 16 : 22),
                boxShadow: [
                  BoxShadow(
                    color: RegaColors.emerald.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stackHeader) ...[
                    titleRow,
                    SizedBox(height: isCompactBanner ? 8 : 12),
                    actionsWrap,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: titleRow),
                        const SizedBox(width: 12),
                        Flexible(child: actionsWrap),
                      ],
                    ),
                  SizedBox(height: isCompactBanner ? 8 : 14),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: RC.bg(Colors.white),
                    indicatorWeight: 3.5,
                    labelColor: RC.fg(Colors.white),
                    unselectedLabelColor: RC.fg(Colors.white70),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: [
                      _buildHubTab(Icons.map_rounded, tx('نەخشەی ١ چرکەیی و ناردن (${_dispatchQueue.length})'), isCompactBanner),
                      _buildHubTab(Icons.badge_rounded, tx('شۆفێران و بەڵگەنامەی KYC'), isCompactBanner),
                      _buildHubTab(Icons.local_shipping_rounded, tx('هەموو گەیاندنەکان'), isCompactBanner),
                      _buildHubTab(Icons.account_balance_wallet_rounded, tx('باڵانسی کاش (COD) و حەواڵە'), isCompactBanner),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompactBanner ? 6 : 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ErrorRetryView(message: _error!, onRetry: _load)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLiveMapAndDispatchTab(),
                            DriversScreen(api: widget.api, lang: widget.lang),
                            OrdersScreen(
                              api: widget.api,
                              lang: widget.lang,
                              onOrderChanged: () {
                                widget.onDataChanged?.call();
                                _load(silent: true);
                              },
                            ),
                            _buildDriverCodAndEarningsTab(),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveMapAndDispatchTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980 && constraints.maxHeight >= 520;
        final padH = AdminBreakpoints.pagePadH(context);
        final mapStyle = _darkMap ? MapboxStyle.dark : MapboxStyle.streets;

        final polylines = <Polyline>[];
        final markers = <Marker>[];

        for (final s in _radarSessions) {
          final m = s as Map<String, dynamic>;
          final rawPoly = m['route_polyline'] as List<dynamic>? ?? [];
          final pts = <LatLng>[];
          for (final p in rawPoly) {
            if (p is List && p.length >= 2) {
              pts.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
            }
          }
          if (pts.length >= 2) {
            polylines.add(Polyline(points: pts, strokeWidth: 4.5, color: RegaColors.emerald));
          }

          final sLat = (m['store_lat'] as num?)?.toDouble() ?? 34.6836;
          final sLng = (m['store_lng'] as num?)?.toDouble() ?? 45.3189;
          final cLat = (m['customer_lat'] as num?)?.toDouble() ?? 34.6912;
          final cLng = (m['customer_lng'] as num?)?.toDouble() ?? 45.3264;
          final dLat = (m['driver_lat'] as num?)?.toDouble() ?? 34.6850;
          final dLng = (m['driver_lng'] as num?)?.toDouble() ?? 45.3210;
          final heading = (m['driver_heading'] as num?)?.toDouble() ?? 45.0;
          final eta = (m['eta_seconds'] as num?)?.toInt() ?? 0;

          markers.add(
            Marker(
              point: LatLng(sLat, sLng),
              width: 40,
              height: 40,
              child: CircleAvatar(
                backgroundColor: RegaColors.orange,
                child: Icon(Icons.storefront_rounded, color: RC.fg(Colors.white), size: 18),
              ),
            ),
          );
          markers.add(
            Marker(
              point: LatLng(cLat, cLng),
              width: 40,
              height: 40,
              child: CircleAvatar(
                backgroundColor: RegaColors.blue,
                child: Icon(Icons.person_pin_circle_rounded, color: RC.fg(Colors.white), size: 20),
              ),
            ),
          );
          markers.add(
            Marker(
              point: LatLng(dLat, dLng),
              width: 115,
              height: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFF0F172A)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: RegaColors.gold),
                    ),
                    child: Text(
                      tx('${m['order_ref']} • ${_fmtMmSs(eta)}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RegaColors.gold, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Transform.rotate(
                    angle: (heading - 90) * math.pi / 180.0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: RegaColors.emerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: RC.bg(Colors.white), width: 2),
                      ),
                      child: Icon(Icons.two_wheeler_rounded, color: RC.fg(Colors.white), size: 18),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        for (final d in _radarDrivers) {
          final dm = d as Map<String, dynamic>;
          if (dm['is_online'] != true) continue;
          final lat = (dm['current_lat'] as num?)?.toDouble() ?? (dm['lat'] as num?)?.toDouble();
          final lng = (dm['current_lng'] as num?)?.toDouble() ?? (dm['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final label = (dm['name'] ?? dm['user']?['name'] ?? dm['code'] ?? dm['driver_code'] ?? 'Captain').toString();
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 36,
              height: 36,
              child: Tooltip(
                message: label,
                child: Container(
                  decoration: BoxDecoration(
                    color: RegaColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: RC.bg(Color(0xFF0F172A)), width: 2),
                  ),
                  child: Icon(Icons.navigation_rounded, size: 15, color: RC.fg(Color(0xFF0F172A))),
                ),
              ),
            ),
          );
        }

        final mapCard = Card(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(34.6295, 45.3159),
                  initialZoom: 14.5,
                ),
                children: [
                  MapboxTiles.layer(
                    key: ValueKey(_darkMap),
                    style: mapStyle,
                    userAgentPackageName: 'iq.rega.admin.delivery',
                  ),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
              PositionedDirectional(
                top: 12,
                start: 12,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _darkMap = !_darkMap),
                  icon: Icon(_darkMap ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 16),
                  label: Text(tx(_darkMap ? 'ڕۆژ' : 'شەو')),
                ),
              ),
            ],
          ),
        );

        final queueList = _dispatchQueue.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    tx('هیچ گەیاندنێکی چالاک لەم چرکەیەدا نییە'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                shrinkWrap: !isWide,
                physics: isWide ? null : const NeverScrollableScrollPhysics(),
                itemCount: _dispatchQueue.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, idx) {
                  final o = _dispatchQueue[idx] as Map<String, dynamic>;
                  final status = o['status']?.toString() ?? 'pending';
                  final hasDriver = o['driver'] != null;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RC.bg(Colors.grey).withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tx('${o['order_number']}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: status, lang: widget.lang),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tx('🏪 ${o['store']?['name_ku'] ?? '-'}  →  👤 ${o['customer_name'] ?? '-'}'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          tx('🛵 شۆفێر: ${o['driver']?['name'] ?? 'دیاری نەکراوە'}'),
                          style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade600)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: RegaColors.emeraldDark,
                                side: const BorderSide(color: RegaColors.emeraldDark, width: 1.2),
                              ),
                              onPressed: () => _showEditDeliveryOrderDialog(o),
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: Text(
                                tx('دەستکاریکردنی هەموو بەشەکانی گەیاندن'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showAssignDriverDialog(o),
                              icon: const Icon(Icons.two_wheeler_rounded, size: 15),
                              label: Text(tx(hasDriver ? 'گۆڕینی شۆفێر' : 'ناردنی شۆفێر')),
                            ),
                            if (hasDriver && (status == 'preparing' || status == 'ready'))
                              OutlinedButton(
                                onPressed: () async {
                                  await widget.api.updateOrderStatus(o['id'] as int, 'picked_up');
                                  _load(silent: true);
                                },
                                child: Text(tx('کاڵا هەڵگیرا (Picked up)')),
                              ),
                            if (hasDriver && status != 'on_the_way' && status != 'arrived_customer' && status != 'delivered')
                              OutlinedButton(
                                onPressed: () async {
                                  await widget.api.updateOrderStatus(o['id'] as int, 'on_the_way');
                                  _load(silent: true);
                                },
                                child: Text(tx('بەڕێکەوت بۆ کڕیار')),
                              ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RegaColors.emeraldDark,
                                foregroundColor: RC.fg(Colors.white),
                              ),
                              onPressed: () => _completeDelivery(o),
                              icon: const Icon(Icons.check_circle_rounded, size: 15),
                              label: Text(tx('تەواوکردنی گەیاندن')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );

        final queuePanel = Card(
          child: Column(
            mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx('ڕیزی ناردن و گەیاندن (${_dispatchQueue.length})'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tx('بێ شۆفێر: ${_kpis['unassigned_ready_orders'] ?? 0}'),
                      style: const TextStyle(color: RegaColors.orange, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (isWide)
                Expanded(child: queueList)
              else
                queueList,
            ],
          ),
        );

        if (isWide) {
          return Padding(
            padding: EdgeInsets.fromLTRB(padH, 6, padH, 20),
            child: Row(
              children: [
                Expanded(flex: 6, child: mapCard),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: queuePanel),
              ],
            ),
          );
        }

        final mobileMapH = math.min(320.0, math.max(220.0, MediaQuery.sizeOf(context).height * 0.36));
        return ListView(
          padding: EdgeInsets.fromLTRB(padH, 6, padH, 24),
          children: [
            SizedBox(height: mobileMapH, child: mapCard),
            const SizedBox(height: 12),
            queuePanel,
          ],
        );
      },
    );
  }

  Widget _buildDriverCodAndEarningsTab() {
    final padH = AdminBreakpoints.pagePadH(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(padH, 8, padH, 28),
      children: [
        LayoutBuilder(
          builder: (context, kpiConstraints) {
            final w = kpiConstraints.maxWidth;
            final cols = w < 560 ? 1 : (w < 960 ? 2 : 3);
            final isPhone = w < AdminBreakpoints.phone;
            final kpis = <Widget>[
              StatKpiCard(
                title: tx('شۆفێرانی ئۆنلاین'),
                value: '${_kpis['online_drivers'] ?? 0} / ${_kpis['total_drivers'] ?? 0}',
                subtitle: tx('${_kpis['verified_drivers'] ?? 0} پشتڕاستکراو'),
                icon: Icons.two_wheeler_rounded,
                accentColor: RegaColors.emeraldDark,
              ),
              StatKpiCard(
                title: tx('بەڵگەنامەی چاوەڕوانکراو (KYC)'),
                value: '${_kpis['pending_kyc_docs'] ?? 0}',
                subtitle: tx('پشکنینی پێویستە'),
                icon: Icons.fact_check_rounded,
                accentColor: RegaColors.orange,
              ),
              StatKpiCard(
                title: tx('گەیاندنە تەواوکراوەکان'),
                value: '${_kpis['completed_deliveries'] ?? 0}',
                subtitle: tx('لە ڕێگادا: ${_kpis['in_transit_orders'] ?? 0}'),
                icon: Icons.check_circle_rounded,
                accentColor: RegaColors.blue,
              ),
              StatKpiCard(
                title: tx('کۆی کرێ و داهاتی شۆفێران'),
                value: formatIqd(_kpis['total_driver_earnings'] as num?, lang: widget.lang),
                subtitle: tx('پاداشت: ${formatIqd(_kpis['total_waiting_bonus'] as num?, lang: widget.lang)}'),
                icon: Icons.savings_rounded,
                accentColor: RegaColors.purple,
              ),
              StatKpiCard(
                title: tx('پارەی کاشی لای شۆفێران (COD)'),
                value: formatIqd(_kpis['total_cod_cash_held'] as num?, lang: widget.lang),
                subtitle: tx('ئامادە بۆ وەرگرتنەوە'),
                icon: Icons.payments_rounded,
                accentColor: RegaColors.crimson,
              ),
              StatKpiCard(
                title: tx('کۆی پاکتاوی شۆفێران'),
                value: formatIqd(_kpis['driver_settlements_paid'] as num?, lang: widget.lang),
                subtitle: tx('یەکلاکراوە'),
                icon: Icons.verified_rounded,
                accentColor: RegaColors.goldDark,
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
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, cardConstraints) {
            final isPhone = cardConstraints.maxWidth < AdminBreakpoints.phone;
            final compact = cardConstraints.maxWidth < 720;
            return Card(
              child: Padding(
                padding: EdgeInsets.all(isPhone ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx('باڵانسی کاشی کۆکراوە (COD) و جزدان بۆ هەر شۆفێرێک'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    ..._drivers.map((raw) {
                      final dp = raw as Map<String, dynamic>;
                      final u = dp['user'] as Map<String, dynamic>?;
                      final isOnline = dp['is_online'] == true;
                      final avatar = CircleAvatar(
                        backgroundColor: isOnline
                            ? RegaColors.emerald.withValues(alpha: 0.2)
                            : RC.bg(Colors.grey).withValues(alpha: 0.2),
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          color: isOnline ? RegaColors.emeraldDark : RC.bg(Colors.grey),
                        ),
                      );
                      final titleText = tx('${u?['name'] ?? ''} (${dp['driver_code'] ?? ''})  •  📞 ${u?['phone'] ?? ''}');
                      final subtitleText = tx('🏍️ ${dp['motor_type'] ?? ''} (${dp['plate_number'] ?? ''})  •  📦 ${dp['total_deliveries'] ?? 0} گەیاندن  •  جزدان: ${formatIqd(dp['wallet_balance'] as num?, lang: widget.lang)}');
                      final codText = tx('کاشی COD: ${formatIqd(dp['cash_collected_hand'] as num?, lang: widget.lang)}');

                      if (compact) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: RC.bg(Colors.grey).withValues(alpha: 0.2)),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          titleText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          subtitleText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade600)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    codText,
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.crimson),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showSettleDriverCodDialog(dp),
                                    icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                                    label: Text(tx('پاکتاوی COD')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        leading: avatar,
                        title: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          subtitleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  codText,
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.crimson),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showSettleDriverCodDialog(dp),
                              icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                              label: Text(tx('پاکتاوی COD')),
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
}

