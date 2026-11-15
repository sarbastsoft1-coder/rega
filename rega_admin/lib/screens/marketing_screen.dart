import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

enum MarketingMode { all, notifications }

class MarketingScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final MarketingMode mode;
  final int initialTab;

  const MarketingScreen({
    super.key,
    required this.api,
    required this.lang,
    this.mode = MarketingMode.all,
    this.initialTab = 0,
  });

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  bool _loading = true;
  String? _error;
  List<dynamic> _coupons = [];
  List<dynamic> _banners = [];
  List<dynamic> _notifications = [];

  bool get _notificationsOnly => widget.mode == MarketingMode.notifications;

  @override
  void initState() {
    super.initState();
    if (!_notificationsOnly) {
      _tabCtrl = TabController(
        length: 3,
        vsync: this,
        initialIndex: widget.initialTab.clamp(0, 2),
      );
    }
    _load();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_notificationsOnly) {
        final notifs = await widget.api.getNotifications();
        if (mounted) setState(() => _notifications = notifs);
      } else {
        final results = await Future.wait([
          widget.api.getCoupons(),
          widget.api.getBanners(),
          widget.api.getNotifications(),
        ]);
        if (mounted) {
          setState(() {
            _coupons = results[0];
            _banners = results[1];
            _notifications = results[2];
          });
        }
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

  void _showCouponDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final codeCtrl = TextEditingController(text: existing?['code']?.toString() ?? '');
    final titleCtrl = TextEditingController(text: existing?['title_ku']?.toString() ?? '');
    final valCtrl = TextEditingController(text: (existing?['discount_value'] ?? 2000).toString());
    final minCtrl = TextEditingController(text: (existing?['min_order_amount'] ?? 10000).toString());
    String type = existing?['discount_type']?.toString() ?? 'fixed';
    bool isActive = existing?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          title: Text(isEdit ? 'دەستکاریکردنی کۆدی داشکاندن' : 'دروستکردنی کۆدی داشکاندنی نوێ (Coupon)'),
          content: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'کۆد (نمونە: KALAR50) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'ناونیشانی ئۆفەر (کوردی) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'جۆری داشکاندن'),
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('بڕی جێگیر بە دینار (Fixed IQD)')),
                    DropdownMenuItem(value: 'percentage', child: Text('ڕێژەی سەدی (%)')),
                    DropdownMenuItem(value: 'free_delivery', child: Text('گەیاندنی بێبەرامبەر (Free Delivery)')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'fixed'),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack = constraints.maxWidth < AdminBreakpoints.phone;
                    final discountField = TextField(
                      controller: valCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'بڕی داشکاندن'),
                    );
                    final minOrderField = TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'کەمترین بڕی داواکاری (د.ع)'),
                    );
                    if (stack) {
                      return Column(
                        children: [
                          discountField,
                          const SizedBox(height: 12),
                          minOrderField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: discountField),
                        const SizedBox(width: 12),
                        Expanded(child: minOrderField),
                      ],
                    );
                  },
                ),
                if (isEdit) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    title: const Text('چالاکە'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final payload = {
                    'code': codeCtrl.text.trim(),
                    'title_ku': titleCtrl.text.trim(),
                    'discount_type': type,
                    'discount_value': int.tryParse(valCtrl.text) ?? 0,
                    'min_order_amount': int.tryParse(minCtrl.text) ?? 0,
                    'is_active': isActive,
                  };
                  if (isEdit) {
                    await widget.api.updateCoupon(existing['id'] as int, payload);
                    _showSnack('کۆدی داشکاندن نوێکرایەوە ✅');
                  } else {
                    await widget.api.createCoupon(payload);
                    _showSnack('کۆدی داشکاندن دروستکرا ✅');
                  }
                  _load();
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: Text(AppStrings.tr('save', widget.lang)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBannerDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?['title_ku']?.toString() ?? '');
    final subCtrl = TextEditingController(text: existing?['subtitle_ku']?.toString() ?? '');
    final badgeCtrl = TextEditingController(text: existing?['badge_text']?.toString() ?? 'تایبەت');
    final imgCtrl = TextEditingController(
      text: existing?['image_url']?.toString() ??
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1000&q=80',
    );
    bool isActive = existing?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          title: Text(isEdit ? 'دەستکاریکردنی بانەری ڕێکلام' : 'زیادکردنی بانەری نوێ بۆ ئەپی کڕیار'),
          content: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'سەردێڕی بانەر *')),
                  const SizedBox(height: 12),
                  TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'ژێرنووس')),
                  const SizedBox(height: 12),
                  TextField(controller: badgeCtrl, decoration: const InputDecoration(labelText: 'تاگی سەر بانەر')),
                  const SizedBox(height: 12),
                  TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: 'بەستەری وێنە (Image URL) *')),
                  if (isEdit) ...[
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      title: const Text('چالاکە'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || imgCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final payload = {
                    'title_ku': titleCtrl.text.trim(),
                    'subtitle_ku': subCtrl.text.trim(),
                    'badge_text': badgeCtrl.text.trim(),
                    'image_url': imgCtrl.text.trim(),
                    'is_active': isActive,
                  };
                  if (isEdit) {
                    await widget.api.updateBanner(existing['id'] as int, payload);
                    _showSnack('بانەری ڕێکلام نوێکرایەوە ✅');
                  } else {
                    await widget.api.createBanner(payload);
                    _showSnack('بانەری نوێ زیادکرا ✅');
                  }
                  _load();
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: Text(AppStrings.tr('save', widget.lang)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBroadcastDialog() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final badgeCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    String audience = 'customers'; // customers | selected
    String notifType = 'discount'; // discount | general | other
    bool saving = false;
    bool loadingCustomers = true;
    List<Map<String, dynamic>> customers = [];
    final Set<int> selectedIds = {};

    try {
      final raw = await widget.api.getCustomers(isActive: true);
      customers = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      customers = [];
    }
    loadingCustomers = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = searchCtrl.text.trim().toLowerCase();
          final filtered = customers.where((c) {
            if (q.isEmpty) return true;
            final name = c['name']?.toString().toLowerCase() ?? '';
            final phone = c['phone']?.toString().toLowerCase() ?? '';
            return name.contains(q) || phone.contains(q);
          }).toList();

          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            title: const Text('ناردنی ئاگاداری بۆ کڕیاران'),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ئەم نامەیە جیاوازە لە زەنگی ناوخۆیی ئەدمین — ڕاستەوخۆ دەچێتە سندوقی ئاگاداری ئەپی کڕیار (داشکاندن / پرۆمۆشن / نامەی تایبەت).',
                      style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(labelText: 'ئامانجی وەرگر'),
                      items: const [
                        DropdownMenuItem(value: 'customers', child: Text('هەموو کڕیاران')),
                        DropdownMenuItem(value: 'selected', child: Text('کڕیاری هەڵبژێردراو')),
                      ],
                      onChanged: (v) => setDialogState(() => audience = v ?? 'customers'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: notifType,
                      decoration: const InputDecoration(labelText: 'جۆری ئاگاداری'),
                      items: const [
                        DropdownMenuItem(value: 'discount', child: Text('داشکاندن / پرۆمۆشن')),
                        DropdownMenuItem(value: 'general', child: Text('گشتی')),
                        DropdownMenuItem(value: 'other', child: Text('ئەویتر / تایبەت')),
                      ],
                      onChanged: (v) => setDialogState(() => notifType = v ?? 'discount'),
                    ),
                    if (audience == 'selected') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'گەڕان بە ناو یان مۆبایل',
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loadingCustomers
                            ? 'بارکردنی کڕیاران...'
                            : '${selectedIds.length} کڕیار هەڵبژێردرا · ${filtered.length} نیشان دراو',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: loadingCustomers
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : filtered.isEmpty
                                ? const Center(child: Text('هیچ کڕیارێک نەدۆزرایەوە'))
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (_, i) {
                                      final c = filtered[i];
                                      final id = (c['id'] as num?)?.toInt();
                                      if (id == null) return const SizedBox.shrink();
                                      final checked = selectedIds.contains(id);
                                      return CheckboxListTile(
                                        dense: true,
                                        value: checked,
                                        title: Text(
                                          c['name']?.toString() ?? '—',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                        subtitle: Text(c['phone']?.toString() ?? ''),
                                        onChanged: (v) {
                                          setDialogState(() {
                                            if (v == true) {
                                              selectedIds.add(id);
                                            } else {
                                              selectedIds.remove(id);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'سەردێڕ *',
                        hintText: 'نموونە: داشکاندنی %30 ئەمڕۆ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ناوەڕۆک / نامە *',
                        hintText: 'هەر نامەیەک کە دەتەوێت بۆ کڕیار بنێریت...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: badgeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'باجی داشکاندن (ئارەزوومەندانە)',
                        hintText: 'نموونە: %30 OFF یان 5,000 د.ع',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(AppStrings.tr('cancel', widget.lang)),
              ),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
                          _showSnack('سەردێڕ و ناوەڕۆک پێویستن', error: true);
                          return;
                        }
                        if (audience == 'selected' && selectedIds.isEmpty) {
                          _showSnack('تکایە لانیکەم یەک کڕیار هەڵبژێرە', error: true);
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await widget.api.sendNotification({
                            'target_audience': audience,
                            'title_ku': titleCtrl.text.trim(),
                            'body_ku': bodyCtrl.text.trim(),
                            'type': notifType,
                            if (audience == 'selected') 'user_ids': selectedIds.toList(),
                            if (badgeCtrl.text.trim().isNotEmpty) 'discount_badge': badgeCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack('ئاگاداری نێردرا — لە سندوقی ئەپی کڕیار دەردەکەوێت');
                          _load();
                        } catch (e) {
                          setDialogState(() => saving = false);
                          _showSnack(e.toString(), error: true);
                        }
                      },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('ناردن بۆ کڕیاران'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationsPanel() {
    final customerNotifs = _notifications.where((raw) {
      final n = raw as Map<String, dynamic>;
      final aud = n['target_audience']?.toString() ?? '';
      final type = n['type']?.toString() ?? '';
      if (type == 'order') return false;
      if (aud == 'customers' || aud == 'all') return true;
      // Selected-customer campaigns (fan-out) — ignore operational specific_user rows.
      if (aud == 'specific_user') {
        return n['campaign_id'] != null || type == 'general';
      }
      return false;
    }).toList();

    final pad = AdminBreakpoints.pagePadH(context);
    return ListView(
      padding: EdgeInsets.all(pad),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RegaColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RegaColors.gold.withValues(alpha: 0.35)),
          ),
          child: const Text(
            'ناردنی ئاگاداری (Outbound) — داشکاندن، پرۆمۆشن یان نامەی تایبەت بۆ کڕیاران. جیاوازە لە زەنگی چاوەڕوانی ناوخۆیی ئەدمین.',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ElevatedButton.icon(
            onPressed: _showBroadcastDialog,
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: const Text('ناردنی ئاگاداری نوێ'),
          ),
        ),
        const SizedBox(height: 14),
        if (customerNotifs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'هیچ ئاگادارییەک نەنێردراوە — یەکەم ئاگاداری بنێرە',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
              ),
            ),
          )
        else
          ...customerNotifs.map((raw) {
            final n = raw as Map<String, dynamic>;
            final aud = n['target_audience']?.toString() ?? 'customers';
            final recipients = (n['recipient_count'] as num?)?.toInt() ?? 1;
            final audienceLabel = aud == 'specific_user'
                ? 'کڕیاری هەڵبژێردراو ($recipients)'
                : aud == 'all'
                    ? 'هەموو بەکارهێنەران'
                    : 'هەموو کڕیاران ($recipients)';
            final id = (n['id'] as num?)?.toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.campaign_rounded, color: RegaColors.goldDark),
                  ),
                  title: Text(
                    n['title_ku']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${n['tag'] ?? 'ئاگاداری'}  •  $audienceLabel\n'
                    '${n['body_ku'] ?? ''}'
                    '${n['discount_badge'] != null ? '  •  ${n['discount_badge']}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: id == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                          onPressed: () async {
                            await widget.api.deleteNotification(id);
                            _load();
                          },
                        ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: SectionHeader(
            title: _notificationsOnly ? 'ئاگاداری بۆ ئەپی کڕیار' : AppStrings.tr('nav_marketing', widget.lang),
            subtitle: _notificationsOnly
                ? 'ناردنی داشکاندن و ئاگاداری — دەردەکەوێت لە نۆتیفیکەیشنی ئەپی کڕیار'
                : 'بەڕێوەبردنی کۆدەکانی داشکاندن، بانەرەکانی ئەپ و ناردنی نامەی گشتی',
          ),
        ),
        if (!_notificationsOnly && _tabCtrl != null)
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '🎟️ کۆدەکانی داشکاندن (${_coupons.length})'),
              Tab(text: '🖼️ بانەرەکان (${_banners.length})'),
              Tab(text: '🔔 ئاگادارکردنەوەکان (${_notifications.length})'),
            ],
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : _notificationsOnly
                      ? _buildNotificationsPanel()
                      : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // Coupons
                        ListView(
                          padding: EdgeInsets.all(AdminBreakpoints.pagePadH(context)),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ElevatedButton.icon(
                                onPressed: () => _showCouponDialog(),
                                icon: const Icon(Icons.local_offer_rounded, size: 18),
                                label: const Text('دروستکردنی کۆدی نوێ'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._coupons.map((raw) {
                              final c = raw as Map<String, dynamic>;
                              final active = c['is_active'] == true;
                              final phone = MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;
                              final actions = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: RegaColors.blue, size: 20),
                                    tooltip: 'دەستکاریکردن',
                                    onPressed: () => _showCouponDialog(existing: c),
                                  ),
                                  Switch(
                                    value: active,
                                    onChanged: (v) async {
                                      await widget.api.updateCoupon(c['id'] as int, {'is_active': v});
                                      _load();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                    onPressed: () async {
                                      await widget.api.deleteCoupon(c['id'] as int);
                                      _load();
                                    },
                                  ),
                                ],
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: phone
                                      ? Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: RegaColors.gold,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      c['code']?.toString() ?? '',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      c['title_ku']?.toString() ?? '',
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'بەکارهاتووە: ${c['used_count'] ?? 0} جار  •  کەمترین داواکاری: ${formatIqd(c['min_order_amount'] as num?, lang: widget.lang)}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                              Align(alignment: AlignmentDirectional.centerEnd, child: actions),
                                            ],
                                          ),
                                        )
                                      : ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: RegaColors.gold,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              c['code']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            c['title_ku']?.toString() ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                          subtitle: Text(
                                            'بەکارهاتووە: ${c['used_count'] ?? 0} جار  •  کەمترین داواکاری: ${formatIqd(c['min_order_amount'] as num?, lang: widget.lang)}',
                                          ),
                                          trailing: actions,
                                        ),
                                ),
                              );
                            }),
                          ],
                        ),

                        // Banners
                        ListView(
                          padding: EdgeInsets.all(AdminBreakpoints.pagePadH(context)),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ElevatedButton.icon(
                                onPressed: () => _showBannerDialog(),
                                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                label: const Text('زیادکردنی بانەر'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._banners.map((raw) {
                              final b = raw as Map<String, dynamic>;
                              final active = b['is_active'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 72,
                                        height: 48,
                                        child: Image.network(
                                          b['image_url']?.toString() ?? '',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(Icons.image_rounded),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      b['title_ku']?.toString() ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: Text(b['subtitle_ku']?.toString() ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: RegaColors.blue, size: 20),
                                          tooltip: 'دەستکاریکردن',
                                          onPressed: () => _showBannerDialog(existing: b),
                                        ),
                                        Switch(
                                          value: active,
                                          onChanged: (v) async {
                                            await widget.api.updateBanner(b['id'] as int, {'is_active': v});
                                            _load();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                          onPressed: () async {
                                            await widget.api.deleteBanner(b['id'] as int);
                                            _load();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                        // Notifications
                        _buildNotificationsPanel(),
                      ],
                    ),
        ),
      ],
    );
  }
}

