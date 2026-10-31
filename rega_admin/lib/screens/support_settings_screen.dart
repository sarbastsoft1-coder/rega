import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SupportSettingsScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final VoidCallback? onChanged;

  const SupportSettingsScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onChanged,
  });

  @override
  State<SupportSettingsScreen> createState() => _SupportSettingsScreenState();
}

class _SupportSettingsScreenState extends State<SupportSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  List<dynamic> _tickets = [];

  final _platformNameCtrl = TextEditingController();
  final _commRateCtrl = TextEditingController();
  final _delFeeCtrl = TextEditingController();
  final _waitMinCtrl = TextEditingController();
  final _waitBonusCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();
  final _driverHotlineCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  bool _enforceAntiVpn = true;
  bool _maintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _platformNameCtrl.dispose();
    _commRateCtrl.dispose();
    _delFeeCtrl.dispose();
    _waitMinCtrl.dispose();
    _waitBonusCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _driverHotlineCtrl.dispose();
    _whatsappCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getTickets(),
        widget.api.getSettings(),
      ]);
      final settings = results[1] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _tickets = results[0] as List<dynamic>;
          _platformNameCtrl.text = (settings['platform_name'] ?? 'REGA - ڕێگا').toString();
          _commRateCtrl.text = (settings['default_commission_rate'] ?? 12).toString();
          _delFeeCtrl.text = (settings['default_delivery_fee'] ?? 1500).toString();
          _waitMinCtrl.text = (settings['waiting_bonus_threshold_minutes'] ?? 15).toString();
          _waitBonusCtrl.text = (settings['waiting_bonus_amount'] ?? 1000).toString();
          _supportPhoneCtrl.text = (settings['support_phone'] ?? '0770 000 1122').toString();
          _driverHotlineCtrl.text = (settings['driver_hotline'] ?? '0750 000 9372').toString();
          _whatsappCtrl.text = (settings['whatsapp_number'] ?? '+9647700001122').toString();
          _hoursCtrl.text = (settings['working_hours'] ?? '09:00 AM - 01:00 AM').toString();
          _enforceAntiVpn = settings['enforce_anti_vpn'] == true;
          _maintenanceMode = settings['maintenance_mode'] == true;
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

  void _showReplyTicketDialog(Map<String, dynamic> ticket) {
    final replyCtrl = TextEditingController(text: ticket['admin_reply']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('وەڵامدانەوەی ${ticket['ticket_number']}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ticket['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(ticket['description']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: replyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وەڵامی بەڕێوەبەرایەتی REGA *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.api.updateTicket(ticket['id'] as int, {
                'status': 'resolved',
                'admin_reply': replyCtrl.text.trim(),
              });
              _showSnack('تیکتەکە چارەسەرکرا ✅');
              widget.onChanged?.call();
              _load();
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('ناردنی وەڵام و چارەسەرکردن'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      await widget.api.updateSettings({
        'platform_name': _platformNameCtrl.text.trim(),
        'default_commission_rate': int.tryParse(_commRateCtrl.text) ?? 12,
        'default_delivery_fee': int.tryParse(_delFeeCtrl.text) ?? 1500,
        'waiting_bonus_threshold_minutes': int.tryParse(_waitMinCtrl.text) ?? 15,
        'waiting_bonus_amount': int.tryParse(_waitBonusCtrl.text) ?? 1000,
        'support_phone': _supportPhoneCtrl.text.trim(),
        'driver_hotline': _driverHotlineCtrl.text.trim(),
        'whatsapp_number': _whatsappCtrl.text.trim(),
        'working_hours': _hoursCtrl.text.trim(),
        'enforce_anti_vpn': _enforceAntiVpn,
        'maintenance_mode': _maintenanceMode,
      });
      _showSnack('ڕێکخستنەکانی سیستەم لە داتابەیسی PostgreSQL پاشەکەوتکران ✅');
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: SectionHeader(
            title: AppStrings.tr('nav_support', widget.lang),
            subtitle: 'چارەسەرکردنی سکاڵای بەپەلەی شۆفێران و کڕیاران + ڕێکخستنی گشتی سیستەمی REGA',
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: '🎧 سکاڵا و تیکتەکان (${_tickets.length})'),
            const Tab(text: '⚙️ ڕێکخستنە گشتییەکانی سیستەم'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // Tickets
                        ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, idx) {
                            final t = _tickets[idx] as Map<String, dynamic>;
                            final u = t['user'] as Map<String, dynamic>?;
                            final ord = t['order'] as Map<String, dynamic>?;
                            final priority = t['priority']?.toString() ?? 'medium';

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              t['ticket_number']?.toString() ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                            ),
                                            const SizedBox(width: 8),
                                            StatusBadge(status: priority, lang: widget.lang),
                                            const SizedBox(width: 8),
                                            StatusBadge(status: t['status']?.toString() ?? 'open', lang: widget.lang),
                                          ],
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _showReplyTicketDialog(t),
                                          child: const Text('وەڵامدانەوە / چارەسەر'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(t['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(t['description']?.toString() ?? '', style: const TextStyle(color: Color(0xFF475569))),
                                    const SizedBox(height: 6),
                                    Text(
                                      '👤 ${u?['name'] ?? ''} (${u?['phone'] ?? ''})  ${ord != null ? '•  📦 داواکاری: ${ord['order_number']}' : ''}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                    if (t['admin_reply'] != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: RegaColors.emerald.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '✅ وەڵامی ئەدمین: ${t['admin_reply']}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RegaColors.emeraldDark),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Settings
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ڕێکخستنی دارایی، پەیوەندی و ئاسایشی پلاتفۆرم (PostgreSQL JSONB)',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        SizedBox(
                                          width: 300,
                                          child: TextField(
                                            controller: _platformNameCtrl,
                                            decoration: const InputDecoration(labelText: 'ناوی فەرمی پلاتفۆرم'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 220,
                                          child: TextField(
                                            controller: _commRateCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: 'ڕێژەی کۆمیسیۆنی بنەڕەت (%)'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 220,
                                          child: TextField(
                                            controller: _delFeeCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: 'کرێی گەیاندنی بنەڕەت (د.ع)'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 240,
                                          child: TextField(
                                            controller: _waitMinCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: 'کاتی چاوەڕوانی بۆ پاداشت (خولەک)'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 240,
                                          child: TextField(
                                            controller: _waitBonusCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: 'بڕی پاداشتی چاوەڕوانی شۆفێر (د.ع)'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 240,
                                          child: TextField(
                                            controller: _driverHotlineCtrl,
                                            decoration: const InputDecoration(labelText: 'هێڵی گەرمی سەرپەرشتیاری شۆفێران'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 240,
                                          child: TextField(
                                            controller: _supportPhoneCtrl,
                                            decoration: const InputDecoration(labelText: 'ژمارەی سەنتەری خزمەتگوزاری کڕیاران'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 240,
                                          child: TextField(
                                            controller: _whatsappCtrl,
                                            decoration: const InputDecoration(labelText: 'ژمارەی واتسئەپ (WhatsApp)'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 260,
                                          child: TextField(
                                            controller: _hoursCtrl,
                                            decoration: const InputDecoration(labelText: 'کاتی کارکردنی ڕۆژانە'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 30),
                                    SwitchListTile(
                                      value: _enforceAntiVpn,
                                      onChanged: (v) => setState(() => _enforceAntiVpn = v),
                                      title: const Text(
                                        'چالاککردنی سیستەمی دژە VPN لە ئەپی کڕیار (Anti-VPN Guard)',
                                        style: TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    SwitchListTile(
                                      value: _maintenanceMode,
                                      onChanged: (v) => setState(() => _maintenanceMode = v),
                                      title: const Text(
                                        'دۆخی چاکسازی گشتی (Maintenance Mode)',
                                        style: TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: ElevatedButton.icon(
                                        onPressed: _saveSettings,
                                        icon: const Icon(Icons.save_rounded),
                                        label: const Text('پاشەکەوتکردنی گۆڕانکارییەکان'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

