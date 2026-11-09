import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api/api_client.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'drivers_screen.dart';
import 'orders_screen.dart';

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
        content: Text(msg),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  void _showAssignDriverDialog(Map<String, dynamic> order) {
    if (_drivers.isEmpty) {
      _showSnack('هیچ شۆفێرێک بەردەست نییە', error: true);
      return;
    }
    int selectedUserId = ((_drivers.first as Map<String, dynamic>)['user_id'] as int);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('ناردنی شۆفێر بۆ داواکاری ${order['order_number']}'),
          content: SizedBox(
            width: 420,
            child: DropdownButtonFormField<int>(
              initialValue: selectedUserId,
              decoration: const InputDecoration(labelText: 'هەڵبژاردنی شۆفێری ماتۆڕسکیل'),
              items: _drivers.map((d) {
                final m = d as Map<String, dynamic>;
                final online = m['is_online'] == true ? '🟢 ئۆنلاین' : '⚪ ئۆفلاین';
                return DropdownMenuItem<int>(
                  value: m['user_id'] as int,
                  child: Text('${m['user']?['name'] ?? ''} (${m['driver_code']}) — $online'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => selectedUserId = v);
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.api.assignDriver(order['id'] as int, selectedUserId);
                  _showSnack('شۆفێر بە سەرکەوتوویی دیاریکرا ✅');
                  widget.onDataChanged?.call();
                  _load(silent: true);
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              icon: const Icon(Icons.two_wheeler_rounded, size: 18),
              label: const Text('دیاریکردنی شۆفێر'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyDeliveryPinDialog(Map<String, dynamic> order) {
    final pinCtrl = TextEditingController(text: order['delivery_pin']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('پشتڕاستکردنەوەی کۆدی کڕیار — ${order['order_number']}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('کۆدی ٤ ژمارەیی وەرگرتنی کڕیار (Delivery PIN) بۆ تەواوکردنی گەیاندن:'),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 10),
                decoration: const InputDecoration(labelText: 'کۆدی ٤ ژمارەیی کڕیار (PIN)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.emeraldDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.length != 4) return;
              Navigator.pop(ctx);
              try {
                await widget.api.verifyDeliveryPin(order['id'] as int, pin);
                _showSnack('گەیاندن تەواوکرا و حسابەکان لە PostgreSQL یەکلاکرانەوە ✅');
                widget.onDataChanged?.call();
                _load(silent: true);
              } catch (e) {
                _showSnack(e.toString(), error: true);
              }
            },
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: const Text('تەواوکردنی گەیاندن'),
          ),
        ],
      ),
    );
  }

  void _showSettleDriverCodDialog(Map<String, dynamic> driverProfile) {
    final cashHeld = (driverProfile['cash_collected_hand'] as num?)?.toInt() ?? 0;
    final amountCtrl = TextEditingController(text: cashHeld > 0 ? '$cashHeld' : '10000');
    final noteCtrl = TextEditingController(
      text: 'وەرگرتنەوەی پارەی کاشی کۆکراوە (COD) لە شۆفێر ${driverProfile['user']?['name'] ?? ''}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('پاکتاوکردنی کاشی شۆفێر — ${driverProfile['user']?['name'] ?? ''}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'بڕی کاشی وەرگیراوە لە شۆفێر (د.ع) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'تێبینی ژمێریاری'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
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
            label: const Text('وەرگرتن و تۆمارکردن'),
          ),
        ],
      ),
    );
  }

  void _showEditDeliveryOrderDialog(Map<String, dynamic> order) {
    final nameCtrl = TextEditingController(text: order['customer_name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: order['customer_phone']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: order['delivery_address']?.toString() ?? '');
    final feeCtrl = TextEditingController(text: (order['delivery_fee'] ?? 2500).toString());
    final pinCtrl = TextEditingController(text: order['delivery_pin']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: order['customer_notes']?.toString() ?? '');
    String status = order['status']?.toString() ?? 'pending';

    int? selectedDriverUserId = (order['driver'] != null && order['driver']['id'] != null)
        ? (order['driver']['id'] as int)
        : null;

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
                    Text('دەستکاریکردنی بەشی گەیاندن — ${order['order_number']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const Text('گۆڕینی شۆفێر، ناونیشان، تێچووی گەیاندن و باری داواکاری', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('١. شۆفێری دیاریکراو و باری گەیاندن', style: TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedDriverUserId,
                    decoration: InputDecoration(
                      labelText: 'شۆفێری ماتۆڕسکیل',
                      prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('❌ بەبێ شۆفێر (دیاری نەکراوە)'),
                      ),
                      ..._drivers.map((d) {
                        final m = d as Map<String, dynamic>;
                        final online = m['is_online'] == true ? '🟢 ئۆنلاین' : '⚪ ئۆفلاین';
                        return DropdownMenuItem<int?>(
                          value: m['user_id'] as int?,
                          child: Text('${m['user']?['name'] ?? ''} (${m['driver_code']}) — $online'),
                        );
                      }),
                    ],
                    onChanged: (v) => setDialogState(() => selectedDriverUserId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: 'دۆخی گەیاندن (Status)',
                      prefixIcon: const Icon(Icons.timeline_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('⏳ لە چاوەڕوانیدا (Pending)')),
                      DropdownMenuItem(value: 'accepted', child: Text('✅ قبولکراو (Accepted)')),
                      DropdownMenuItem(value: 'preparing', child: Text('🍳 لە ئامادەکردندایە (Preparing)')),
                      DropdownMenuItem(value: 'ready', child: Text('📦 ئامادەیە بۆ وەرگرتن (Ready)')),
                      DropdownMenuItem(value: 'picked_up', child: Text('🛵 کاڵا لەلای شۆفێرە (Picked up)')),
                      DropdownMenuItem(value: 'on_the_way', child: Text('🚀 لە ڕێگادایە بۆ کڕیار (On the way)')),
                      DropdownMenuItem(value: 'arrived_customer', child: Text('📍 گەیشتە بەردەم کڕیار (Arrived)')),
                      DropdownMenuItem(value: 'delivered', child: Text('🎉 تەواوبوو و گەیەندرا (Delivered)')),
                      DropdownMenuItem(value: 'cancelled', child: Text('❌ هەڵوەشاوەتەوە (Cancelled)')),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? 'pending'),
                  ),
                  const SizedBox(height: 18),
                  const Text('٢. زانیاری کڕیار و ناونیشانی گەیاندن', style: TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'ناوی کڕیار',
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: InputDecoration(
                            labelText: 'ژمارەی مۆبایلی کڕیار',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'ناونیشانی تەواوی گەیاندن (گەڕەک / کۆڵان / شوێن)',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('٣. تێچووی دلیڤەری و کۆدی PIN', style: TextStyle(fontWeight: FontWeight.w900, color: RegaColors.emeraldDark)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'نرخی گەیاندن (د.ع)',
                            prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pinCtrl,
                          maxLength: 4,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'کۆدی پشتڕاستکردنەوە (PIN)',
                            prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'تێبینی و ڕێنمایی تایبەت بۆ شۆفێر',
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RegaColors.emeraldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
              child: const Text('پاشەکەوتکردنی هەموو گۆڕانکارییەکان'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickDeliverySettingsDialog() async {
    int fee = 2500;
    String hours = '09:00 - 23:00';
    String phone = '0750 123 4567';
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
            const Text('ڕێکخستنی بنەڕەتی گەیاندن (Global Delivery Settings)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'تێچووی بنەڕەتی گەیاندن بۆ هەموو داواکارییەکان (د.ع) *',
                  prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: hoursCtrl,
                decoration: InputDecoration(
                  labelText: 'کاتژمێری کارکردنی گەیاندن (نموونە: 09:00 - 23:00)',
                  prefixIcon: const Icon(Icons.access_time_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: hotlineCtrl,
                decoration: InputDecoration(
                  labelText: 'هێڵی گەرمی پەیوەندی شۆفێران (Driver Hotline)',
                  prefixIcon: const Icon(Icons.phone_in_talk_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'ژمارەی مۆبایلی پاڵپشتی ناوەند',
                  prefixIcon: const Icon(Icons.headset_mic_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('پاشگەزبوونەوە')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.emeraldDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            child: const Text('پاشەکەوتکردنی ڕێکخستنەکان'),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Delivery Hub Header Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: RegaColors.emerald.withValues(alpha: 0.25),
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
                        child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بەشی گەیاندن و شۆفێران (REGA Delivery & Fleet Hub)',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'بەستراوەتەوە بە ئەپی شۆفێران (rega_delivery) • ڕاداری چرکە بە چرکەی کەلار، ناردن، KYC و باڵانسی کاش',
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
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF047857),
                        ),
                        onPressed: () => _showQuickDeliverySettingsDialog(),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('ڕێکخستنی نرخی گەیاندن'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF047857),
                        ),
                        onPressed: () => _tabController.animateTo(1),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('زیادکردنی شۆفێر'),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          _load();
                          _fetchLiveRadarTick();
                        },
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: Text('LIVE 1s • تیک #$_radarTicks (${_kpis['online_drivers'] ?? 0} شۆفێری ئۆنلاین)'),
                      ),
                    ],
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
                  Tab(
                    icon: const Icon(Icons.map_rounded, size: 18),
                    text: 'نەخشەی ١ چرکەیی و ناردن (${_dispatchQueue.length})',
                  ),
                  const Tab(icon: Icon(Icons.badge_rounded, size: 18), text: 'شۆفێران و بەڵگەنامەی KYC'),
                  const Tab(icon: Icon(Icons.local_shipping_rounded, size: 18), text: 'هەموو گەیاندنەکان'),
                  const Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'باڵانسی کاش (COD) و حەواڵە'),
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
  }

  Widget _buildLiveMapAndDispatchTab() {
    final isWide = MediaQuery.of(context).size.width > 1050;
    final tileUrl = _darkMap
        ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

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
          child: const CircleAvatar(
            backgroundColor: RegaColors.orange,
            child: Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
          ),
        ),
      );
      markers.add(
        Marker(
          point: LatLng(cLat, cLng),
          width: 40,
          height: 40,
          child: const CircleAvatar(
            backgroundColor: RegaColors.blue,
            child: Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
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
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RegaColors.gold),
                ),
                child: Text(
                  '${m['order_ref']} • ${_fmtMmSs(eta)}',
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
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
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
      final lat = (dm['lat'] as num?)?.toDouble() ?? 34.6845;
      final lng = (dm['lng'] as num?)?.toDouble() ?? 45.3195;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 32,
          height: 32,
          child: Tooltip(
            message: '${dm['name'] ?? ''} (${dm['code'] ?? ''})',
            child: Container(
              decoration: BoxDecoration(
                color: RegaColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F172A), width: 2),
              ),
              child: const Icon(Icons.navigation_rounded, size: 15, color: Color(0xFF0F172A)),
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
              initialCenter: LatLng(34.6865, 45.3215),
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'iq.rega.admin.delivery'),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() => _darkMap = !_darkMap),
              icon: Icon(_darkMap ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 16),
              label: Text(_darkMap ? 'ڕۆژ' : 'شەو'),
            ),
          ),
        ],
      ),
    );

    final queuePanel = Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ڕیزی ناردن و گەیاندن (${_dispatchQueue.length})',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                Text(
                  'بێ شۆفێر: ${_kpis['unassigned_ready_orders'] ?? 0}',
                  style: const TextStyle(color: RegaColors.orange, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _dispatchQueue.isEmpty
                ? const Center(child: Text('هیچ گەیاندنێکی چالاک لەم چرکەیەدا نییە'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
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
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.22)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${o['order_number']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                StatusBadge(status: status, lang: widget.lang),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('🏪 ${o['store']?['name_ku'] ?? '-'}  →  👤 ${o['customer_name'] ?? '-'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text(
                              '🛵 شۆفێر: ${o['driver']?['name'] ?? 'دیاری نەکراوە'}  |  🔐 PIN کڕیار: ${o['delivery_pin'] ?? '----'}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                                  label: const Text('دەستکاریکردنی هەموو بەشەکانی گەیاندن'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showAssignDriverDialog(o),
                                  icon: const Icon(Icons.two_wheeler_rounded, size: 15),
                                  label: Text(hasDriver ? 'گۆڕینی شۆفێر' : 'ناردنی شۆفێر'),
                                ),
                                if (hasDriver && (status == 'preparing' || status == 'ready'))
                                  OutlinedButton(
                                    onPressed: () async {
                                      await widget.api.updateOrderStatus(o['id'] as int, 'picked_up');
                                      _load(silent: true);
                                    },
                                    child: const Text('کاڵا هەڵگیرا (Picked up)'),
                                  ),
                                if (hasDriver && status != 'on_the_way' && status != 'arrived_customer' && status != 'delivered')
                                  OutlinedButton(
                                    onPressed: () async {
                                      await widget.api.updateOrderStatus(o['id'] as int, 'on_the_way');
                                      _load(silent: true);
                                    },
                                    child: const Text('بەڕێکەوت بۆ کڕیار'),
                                  ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RegaColors.emeraldDark,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _showVerifyDeliveryPinDialog(o),
                                  icon: const Icon(Icons.pin_rounded, size: 15),
                                  label: const Text('تەواوکردن بە PIN'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
      child: isWide
          ? Row(
              children: [
                Expanded(flex: 6, child: mapCard),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: queuePanel),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 5, child: mapCard),
                const SizedBox(height: 12),
                Expanded(flex: 5, child: queuePanel),
              ],
            ),
    );
  }

  Widget _buildDriverCodAndEarningsTab() {
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
              title: 'شۆفێرانی ئۆنلاین',
              value: '${_kpis['online_drivers'] ?? 0} / ${_kpis['total_drivers'] ?? 0}',
              subtitle: '${_kpis['verified_drivers'] ?? 0} پشتڕاستکراو',
              icon: Icons.two_wheeler_rounded,
              accentColor: RegaColors.emeraldDark,
            ),
            StatKpiCard(
              title: 'بەڵگەنامەی چاوەڕوانکراو (KYC)',
              value: '${_kpis['pending_kyc_docs'] ?? 0}',
              subtitle: 'پشکنینی پێویستە',
              icon: Icons.fact_check_rounded,
              accentColor: RegaColors.orange,
            ),
            StatKpiCard(
              title: 'گەیاندنە تەواوکراوەکان',
              value: '${_kpis['completed_deliveries'] ?? 0}',
              subtitle: 'لە ڕێگادا: ${_kpis['in_transit_orders'] ?? 0}',
              icon: Icons.check_circle_rounded,
              accentColor: RegaColors.blue,
            ),
            StatKpiCard(
              title: 'کۆی کرێ و داهاتی شۆفێران',
              value: formatIqd(_kpis['total_driver_earnings'] as num?, lang: widget.lang),
              subtitle: 'پاداشت: ${formatIqd(_kpis['total_waiting_bonus'] as num?, lang: widget.lang)}',
              icon: Icons.savings_rounded,
              accentColor: RegaColors.purple,
            ),
            StatKpiCard(
              title: 'پارەی کاشی لای شۆفێران (COD)',
              value: formatIqd(_kpis['total_cod_cash_held'] as num?, lang: widget.lang),
              subtitle: 'ئامادە بۆ وەرگرتنەوە',
              icon: Icons.payments_rounded,
              accentColor: RegaColors.crimson,
            ),
            StatKpiCard(
              title: 'کۆی پاکتاوی شۆفێران',
              value: formatIqd(_kpis['driver_settlements_paid'] as num?, lang: widget.lang),
              subtitle: 'یەکلاکراوە',
              icon: Icons.verified_rounded,
              accentColor: RegaColors.goldDark,
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
                  'باڵانسی کاشی کۆکراوە (COD) و جزدان بۆ هەر شۆفێرێک',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                ..._drivers.map((raw) {
                  final dp = raw as Map<String, dynamic>;
                  final u = dp['user'] as Map<String, dynamic>?;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    leading: CircleAvatar(
                      backgroundColor: dp['is_online'] == true
                          ? RegaColors.emerald.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.two_wheeler_rounded,
                        color: dp['is_online'] == true ? RegaColors.emeraldDark : Colors.grey,
                      ),
                    ),
                    title: Text(
                      '${u?['name'] ?? ''} (${dp['driver_code'] ?? ''})  •  📞 ${u?['phone'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '🏍️ ${dp['motor_type'] ?? ''} (${dp['plate_number'] ?? ''})  •  📦 ${dp['total_deliveries'] ?? 0} گەیاندن  •  جزدان: ${formatIqd(dp['wallet_balance'] as num?, lang: widget.lang)}',
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
                              'کاشی COD: ${formatIqd(dp['cash_collected_hand'] as num?, lang: widget.lang)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.crimson),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showSettleDriverCodDialog(dp),
                          icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                          label: const Text('پاکتاوی COD'),
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
}

