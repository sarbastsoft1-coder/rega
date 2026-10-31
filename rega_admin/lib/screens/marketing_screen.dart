import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MarketingScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const MarketingScreen({super.key, required this.api, required this.lang});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  List<dynamic> _coupons = [];
  List<dynamic> _banners = [];
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
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

  void _showAddCouponDialog() {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final valCtrl = TextEditingController(text: '2000');
    final minCtrl = TextEditingController(text: '10000');
    String type = 'fixed';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('دروستکردنی کۆدی داشکاندنی نوێ (Coupon)'),
          content: SizedBox(
            width: 440,
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'بڕی داشکاندن'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'کەمترین بڕی داواکاری (د.ع)'),
                      ),
                    ),
                  ],
                ),
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
                  await widget.api.createCoupon({
                    'code': codeCtrl.text.trim(),
                    'title_ku': titleCtrl.text.trim(),
                    'discount_type': type,
                    'discount_value': int.tryParse(valCtrl.text) ?? 0,
                    'min_order_amount': int.tryParse(minCtrl.text) ?? 0,
                  });
                  _showSnack('کۆدی داشکاندن دروستکرا');
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

  void _showAddBannerDialog() {
    final titleCtrl = TextEditingController();
    final subCtrl = TextEditingController();
    final badgeCtrl = TextEditingController(text: 'تایبەت');
    final imgCtrl = TextEditingController(
      text: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1000&q=80',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زیادکردنی بانەری ڕێکلام بۆ ئەپی کڕیار'),
        content: SizedBox(
          width: 440,
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || imgCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await widget.api.createBanner({
                'title_ku': titleCtrl.text.trim(),
                'subtitle_ku': subCtrl.text.trim(),
                'badge_text': badgeCtrl.text.trim(),
                'image_url': imgCtrl.text.trim(),
              });
              _showSnack('بانەری نوێ زیادکرا');
              _load();
            },
            child: Text(AppStrings.tr('save', widget.lang)),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('ناردنی ئاگادارکردنەوەی گشتی (Broadcast)'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: const InputDecoration(labelText: 'ئاراستەکراو بۆ'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('هەموو بەکارهێنەران (All Apps)')),
                    DropdownMenuItem(value: 'customers', child: Text('تەنها کڕیاران (Customer App)')),
                    DropdownMenuItem(value: 'vendors', child: Text('تەنها فرۆشیاران (Vendor App)')),
                    DropdownMenuItem(value: 'drivers', child: Text('تەنها شۆفێران (Driver App)')),
                  ],
                  onChanged: (v) => setDialogState(() => audience = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'سەردێڕی نامە *')),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'ناوەڕۆکی ئاگادارکردنەوە *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
            ElevatedButton.icon(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await widget.api.sendNotification({
                  'target_audience': audience,
                  'title_ku': titleCtrl.text.trim(),
                  'body_ku': bodyCtrl.text.trim(),
                });
                _showSnack('ئاگادارکردنەوە نێردرا 🔔');
                _load();
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('ناردنی ڕاستەوخۆ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: SectionHeader(
            title: AppStrings.tr('nav_marketing', widget.lang),
            subtitle: 'بەڕێوەبردنی کۆدەکانی داشکاندن، بانەرەکانی ئەپ و ناردنی نامەی گشتی',
          ),
        ),
        TabBar(
          controller: _tabCtrl,
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
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // Coupons
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ElevatedButton.icon(
                                onPressed: _showAddCouponDialog,
                                icon: const Icon(Icons.local_offer_rounded, size: 18),
                                label: const Text('دروستکردنی کۆدی نوێ'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._coupons.map((raw) {
                              final c = raw as Map<String, dynamic>;
                              final active = c['is_active'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: ListTile(
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
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                        // Banners
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ElevatedButton.icon(
                                onPressed: _showAddBannerDialog,
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
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ElevatedButton.icon(
                                onPressed: _showBroadcastDialog,
                                icon: const Icon(Icons.campaign_rounded, size: 18),
                                label: const Text('ناردنی ئاگادارکردنەوەی نوێ'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._notifications.map((raw) {
                              final n = raw as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFFEF3C7),
                                      child: Icon(Icons.notifications_active_rounded, color: RegaColors.goldDark),
                                    ),
                                    title: Text(
                                      '[${n['target_audience']}] ${n['title_ku'] ?? ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: Text(n['body_ku']?.toString() ?? ''),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                      onPressed: () async {
                                        await widget.api.deleteNotification(n['id'] as int);
                                        _load();
                                      },
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

