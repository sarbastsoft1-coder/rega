import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/services/media_pick_service.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bulk_delete_bar.dart';
import '../widgets/common_widgets.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
import '../widgets/send_customer_notification_dialog.dart';
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
  bool _selectionMode = false;
  final Set<int> _couponSelectedIds = {};
  final Set<int> _bannerSelectedIds = {};
  final Set<int> _notificationSelectedIds = {};
  bool _bulkBusy = false;

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
      _tabCtrl!.addListener(() {
        if (_tabCtrl!.indexIsChanging) return;
        setState(() {
          _selectionMode = false;
          _couponSelectedIds.clear();
          _bannerSelectedIds.clear();
          _notificationSelectedIds.clear();
        });
      });
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
        if (mounted) {
          setState(() {
            _notifications = notifs;
            _notificationSelectedIds.removeWhere(
              (id) => !_notifications.any((n) => (n as Map)['id'] == id),
            );
          });
        }
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
            _couponSelectedIds.removeWhere(
              (id) => !_coupons.any((c) => (c as Map)['id'] == id),
            );
            _bannerSelectedIds.removeWhere(
              (id) => !_banners.any((b) => (b as Map)['id'] == id),
            );
            _notificationSelectedIds.removeWhere(
              (id) => !_notifications.any((n) => (n as Map)['id'] == id),
            );
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
        content: Text(tx(msg)),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  int get _marketingTab =>
      _notificationsOnly ? 2 : (_tabCtrl?.index ?? 0);

  Set<int> get _activeSelectedIds => switch (_marketingTab) {
        0 => _couponSelectedIds,
        1 => _bannerSelectedIds,
        _ => _notificationSelectedIds,
      };

  List<int> get _couponIds => _coupons.map((c) => (c as Map)['id']).whereType<int>().toList();
  List<int> get _bannerIds => _banners.map((b) => (b as Map)['id']).whereType<int>().toList();
  List<int> get _notificationIds =>
      _notifications.map((n) => (n as Map)['id']).whereType<int>().toList();

  List<int> get _activeListIds => switch (_marketingTab) {
        0 => _couponIds,
        1 => _bannerIds,
        _ => _notificationIds,
      };

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _couponSelectedIds.clear();
        _bannerSelectedIds.clear();
        _notificationSelectedIds.clear();
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _couponSelectedIds.clear();
      _bannerSelectedIds.clear();
      _notificationSelectedIds.clear();
    });
  }

  void _selectAllActive() {
    setState(() {
      switch (_marketingTab) {
        case 0:
          _couponSelectedIds
            ..clear()
            ..addAll(_couponIds);
        case 1:
          _bannerSelectedIds
            ..clear()
            ..addAll(_bannerIds);
        default:
          _notificationSelectedIds
            ..clear()
            ..addAll(_notificationIds);
      }
    });
  }

  void _toggleItemSelected(int id) {
    setState(() {
      final set = switch (_marketingTab) {
        0 => _couponSelectedIds,
        1 => _bannerSelectedIds,
        _ => _notificationSelectedIds,
      };
      if (set.contains(id)) {
        set.remove(id);
      } else {
        set.add(id);
      }
    });
  }

  Future<void> _bulkDeleteCoupons({required bool deleteAll}) async {
    final ids = deleteAll ? _couponIds : _couponSelectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await BulkDeleteActions.confirm(
      context: context,
      lang: widget.lang,
      count: ids.length,
      deleteAll: deleteAll,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    final result = await BulkDeleteActions.run(
      ids: ids,
      deleteOne: widget.api.deleteCoupon,
    );
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectionMode = false;
      _couponSelectedIds.clear();
    });
    _showSnack(
      BulkDeleteActions.resultMessage(widget.lang, result),
      error: result.failed > 0 && result.ok == 0,
    );
    await _load();
  }

  Future<void> _bulkDeleteBanners({required bool deleteAll}) async {
    final ids = deleteAll ? _bannerIds : _bannerSelectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await BulkDeleteActions.confirm(
      context: context,
      lang: widget.lang,
      count: ids.length,
      deleteAll: deleteAll,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    final result = await BulkDeleteActions.run(
      ids: ids,
      deleteOne: widget.api.deleteBanner,
    );
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectionMode = false;
      _bannerSelectedIds.clear();
    });
    _showSnack(
      BulkDeleteActions.resultMessage(widget.lang, result),
      error: result.failed > 0 && result.ok == 0,
    );
    await _load();
  }

  Future<void> _bulkDeleteNotifications({required bool deleteAll}) async {
    final ids = deleteAll ? _notificationIds : _notificationSelectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await BulkDeleteActions.confirm(
      context: context,
      lang: widget.lang,
      count: ids.length,
      deleteAll: deleteAll,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    final result = await BulkDeleteActions.run(
      ids: ids,
      deleteOne: widget.api.deleteNotification,
    );
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectionMode = false;
      _notificationSelectedIds.clear();
    });
    _showSnack(
      BulkDeleteActions.resultMessage(widget.lang, result),
      error: result.failed > 0 && result.ok == 0,
    );
    await _load();
  }

  void _runBulkDeleteSelected() {
    switch (_marketingTab) {
      case 0:
        _bulkDeleteCoupons(deleteAll: false);
      case 1:
        _bulkDeleteBanners(deleteAll: false);
      default:
        _bulkDeleteNotifications(deleteAll: false);
    }
  }

  void _runBulkDeleteAll() {
    switch (_marketingTab) {
      case 0:
        _bulkDeleteCoupons(deleteAll: true);
      case 1:
        _bulkDeleteBanners(deleteAll: true);
      default:
        _bulkDeleteNotifications(deleteAll: true);
    }
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
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          actionsOverflowButtonSpacing: 8,
          title: Text(
            tx(isEdit ? 'دەستکاریکردنی کۆدی داشکاندن' : 'دروستکردنی کۆدی داشکاندنی نوێ (Coupon)'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 480),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 500),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: InputDecoration(labelText: tx('کۆد (نمونە: KALAR50) *')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(labelText: tx('ناونیشانی ئۆفەر (کوردی) *')),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: type,
                      decoration: InputDecoration(labelText: tx('جۆری داشکاندن')),
                      items: [
                        DropdownMenuItem(value: 'fixed', child: Text(tx('بڕی جێگیر بە دینار (Fixed IQD)'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'percentage', child: Text(tx('ڕێژەی سەدی (%)'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'free_delivery', child: Text(tx('گەیاندنی بێبەرامبەر (Free Delivery)'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setDialogState(() => type = v ?? 'fixed'),
                    ),
                    const SizedBox(height: 12),
                    ResponsiveFormRow(
                      breakpoint: 360,
                      first: TextField(
                        controller: valCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: tx('بڕی داشکاندن')),
                      ),
                      second: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: tx('کەمترین بڕی داواکاری (د.ع)')),
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                        title: Text(tx('چالاکە')),
                      ),
                    ],
                  ],
                ),
              ),
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
    final badgeCtrl = TextEditingController(text: existing?['badge_text']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: existing?['image_url']?.toString() ?? '');
    bool isActive = existing?['is_active'] ?? true;
    bool uploadingImage = false;
    bool showUrlField = (existing?['image_url']?.toString() ?? '').trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final previewUrl = widget.api.resolveMediaUrl(imgCtrl.text.trim());
          return AlertDialog(
            insetPadding: AdminBreakpoints.dialogInset(ctx),
            contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
            actionsOverflowButtonSpacing: 8,
            title: Text(
              tx(isEdit ? 'دەستکاریکردنی بانەری ڕێکلام' : 'زیادکردنی بانەری نوێ بۆ ئەپی کڕیار'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 480),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 560),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tx('ئەم وێنەیە لە سەرەکی ئەپی کڕیار وەک ڕیکلام (بانەر) دەردەکەوێت — وێنە بار بکە.'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: RC.fg(Colors.grey.shade700),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 7,
                          child: previewUrl.isEmpty
                              ? Container(
                                  color: RC.bg(const Color(0xFFF1F5F9)),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image_outlined, size: 36, color: RC.fg(Colors.grey)),
                                      const SizedBox(height: 6),
                                      Text(
                                        tx('پیشاندانی وێنەی ڕیکلام'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: RC.fg(Colors.grey.shade600),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Image.network(
                                  previewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: RC.bg(const Color(0xFFF1F5F9)),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.broken_image_outlined, color: RC.fg(Colors.grey)),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: uploadingImage
                            ? null
                            : () async {
                                final picked = await MediaPickService.pickImageForUpload();
                                if (picked == null) return;
                                setDialogState(() => uploadingImage = true);
                                try {
                                  final up = await widget.api.uploadMedia(picked.bytes, picked.name);
                                  final url = up['url']?.toString();
                                  if (url != null && url.isNotEmpty) {
                                    setDialogState(() {
                                      imgCtrl.text = url;
                                      showUrlField = true;
                                    });
                                    _showSnack(tx('وێنە بە سەرکەوتوویی بارکرا'));
                                  } else {
                                    _showSnack(AppStrings.tr('item_image_upload_failed', widget.lang), error: true);
                                  }
                                } catch (e) {
                                  _showSnack(e.toString(), error: true);
                                } finally {
                                  setDialogState(() => uploadingImage = false);
                                }
                              },
                        icon: uploadingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 20),
                        label: Text(
                          tx(uploadingImage
                              ? AppStrings.tr('item_image_uploading', widget.lang)
                              : 'هەڵبژاردن و بارکردنی وێنەی ڕیکلام'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setDialogState(() => showUrlField = !showUrlField),
                        child: Text(
                          tx(showUrlField ? 'شاردنەوەی بەستەری وێنە' : 'یان بەستەری وێنە دابنێ (URL)'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      if (showUrlField) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: imgCtrl,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: tx('بەستەری وێنە (Image URL)'),
                            hintText: tx('دوای بارکردن خۆکار پڕدەبێتەوە'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: tx('سەردێڕ (ئارەزوومەندانە)'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subCtrl,
                        decoration: InputDecoration(labelText: tx('ژێرنووس (ئارەزوومەندانە)')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: badgeCtrl,
                        decoration: InputDecoration(labelText: tx('تاگی سەر بانەر (ئارەزوومەندانە)')),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          onChanged: (v) => setDialogState(() => isActive = v),
                          title: Text(tx('چالاکە — لە سەرەکی ئەپ پیشان بدرێت')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppStrings.tr('cancel', widget.lang)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (imgCtrl.text.trim().isEmpty) {
                    _showSnack(tx('تکایە وێنەی ڕیکلام بار بکە'), error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final payload = {
                      'title_ku': titleCtrl.text.trim(),
                      'subtitle_ku': subCtrl.text.trim(),
                      'badge_text': badgeCtrl.text.trim().isEmpty ? null : badgeCtrl.text.trim(),
                      'image_url': imgCtrl.text.trim(),
                      'target_type': 'none',
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
          );
        },
      ),
    );
  }

  Future<void> _showBroadcastDialog() async {
    final ok = await showSendCustomerNotificationDialog(
      context,
      api: widget.api,
      lang: widget.lang,
    );
    if (ok) {
      _showSnack('ئاگاداری نێردرا — لە سندوقی ئەپی کڕیار دەردەکەوێت');
      _load();
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < AdminBreakpoints.phone;
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
              child: Text(
                tx('ناردنی ئاگاداری (Outbound) — داشکاندن، پرۆمۆشن یان نامەی تایبەت بۆ کڕیاران. جیاوازە لە زەنگی چاوەڕوانی ناوخۆیی ئەدمین.'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ElevatedButton.icon(
                onPressed: _showBroadcastDialog,
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: Text(tx('ناردنی ئاگاداری نوێ')),
              ),
            ),
            const SizedBox(height: 14),
            if (customerNotifs.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    tx('هیچ ئاگادارییەک نەنێردراوە — یەکەم ئاگاداری بنێرە'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: RC.fg(Colors.black54)),
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
                final avatar = CircleAvatar(
                  backgroundColor: RC.bg(Color(0xFFFEF3C7)),
                  child: Icon(Icons.campaign_rounded, color: RegaColors.goldDark),
                );
                final titleText = tx(n['title_ku']?.toString() ?? '');
                final subText = tx('${n['tag'] ?? 'ئاگاداری'}  •  $audienceLabel\n'
                    '${n['body_ku'] ?? ''}'
                    '${n['discount_badge'] != null ? '  •  ${n['discount_badge']}' : ''}');

                if (narrow) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                      const SizedBox(height: 4),
                                      Text(
                                        subText,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: AdminSurfaces.of(context).textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (id != null) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                  onPressed: () async {
                                    await widget.api.deleteNotification(id);
                                    _load();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }

                  final selected =
                      id != null && _notificationSelectedIds.contains(id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: selected
                            ? const BorderSide(color: RegaColors.orange, width: 2)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: _selectionMode && id != null
                            ? () => _toggleItemSelected(id)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectionMode && id != null)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 6),
                                child: BulkSelectBadge(
                                  selected: selected,
                                  onChanged: (_) => _toggleItemSelected(id),
                                ),
                              ),
                            avatar,
                          ],
                        ),
                        title: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          subText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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
                    ),
                  );
              }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = AdminBreakpoints.pagePadH(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad < 16 ? 10 : 18, pad, 6),
          child: SectionHeader(
            title: _notificationsOnly ? 'ئاگاداری بۆ ئەپی کڕیار' : AppStrings.tr('nav_marketing', widget.lang),
            subtitle: _notificationsOnly
                ? 'ناردنی داشکاندن و ئاگاداری — دەردەکەوێت لە نۆتیفیکەیشنی ئەپی کڕیار'
                : 'بەڕێوەبردنی کۆدەکانی داشکاندن، بانەرەکانی ئەپ و ناردنی نامەی گشتی',
            trailing: BulkDeleteBar(
              lang: widget.lang,
              selectionMode: _selectionMode,
              selectedCount: _activeSelectedIds.length,
              totalCount: _activeListIds.length,
              busy: _bulkBusy,
              onToggleSelectionMode: _toggleSelectionMode,
              onSelectAll: _selectAllActive,
              onClearSelection: _clearSelection,
              onDeleteSelected: _runBulkDeleteSelected,
              onDeleteAll: _runBulkDeleteAll,
            ),
          ),
        ),
        if (!_notificationsOnly && _tabCtrl != null)
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: tx('🎟️ کۆدەکانی داشکاندن (${_coupons.length})')),
              Tab(text: tx('🖼️ بانەرەکان (${_banners.length})')),
              Tab(text: tx('🔔 ئاگادارکردنەوەکان (${_notifications.length})')),
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compactCoupon = constraints.maxWidth < 700;
                            return ListView(
                              padding: EdgeInsets.all(AdminBreakpoints.pagePadH(context)),
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showCouponDialog(),
                                    icon: const Icon(Icons.local_offer_rounded, size: 18),
                                    label: Text(tx('دروستکردنی کۆدی نوێ')),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ..._coupons.map((raw) {
                                  final c = raw as Map<String, dynamic>;
                                  final itemId = (c['id'] as num?)?.toInt();
                                  final selected = itemId != null && _couponSelectedIds.contains(itemId);
                                  final active = c['is_active'] == true;
                                  final actions = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.edit_rounded, color: RegaColors.blue, size: 20),
                                        tooltip: tx('دەستکاریکردن'),
                                        onPressed: () => _showCouponDialog(existing: c),
                                      ),
                                      Switch(
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        value: active,
                                        onChanged: (v) async {
                                          await widget.api.updateCoupon(c['id'] as int, {'is_active': v});
                                          _load();
                                        },
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                        onPressed: () async {
                                          await widget.api.deleteCoupon(c['id'] as int);
                                          _load();
                                        },
                                      ),
                                    ],
                                  );
                                  final codeBadge = Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: RegaColors.gold,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 140),
                                      child: Text(
                                        tx(c['code']?.toString() ?? ''),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: RC.fg(Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ),
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: selected
                                            ? const BorderSide(color: RegaColors.orange, width: 2)
                                            : BorderSide.none,
                                      ),
                                      child: InkWell(
                                        onTap: _selectionMode && itemId != null
                                            ? () => _toggleItemSelected(itemId)
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        child: compactCoupon
                                          ? Padding(
                                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      if (_selectionMode && itemId != null)
                                                        Padding(
                                                          padding: const EdgeInsetsDirectional.only(end: 8),
                                                          child: BulkSelectBadge(
                                                            selected: selected,
                                                            onChanged: (_) => _toggleItemSelected(itemId),
                                                          ),
                                                        ),
                                                      codeBadge,
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          tx(c['title_ku']?.toString() ?? ''),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    tx('بەکارهاتووە: ${c['used_count'] ?? 0} جار  •  کەمترین داواکاری: ${formatIqd(c['min_order_amount'] as num?, lang: widget.lang)}'),
                                                    style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade700)),
                                                  ),
                                                  Align(alignment: AlignmentDirectional.centerEnd, child: actions),
                                                ],
                                              ),
                                            )
                                          : ListTile(
                                              leading: codeBadge,
                                              title: Text(
                                                tx(c['title_ku']?.toString() ?? ''),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w800),
                                              ),
                                              subtitle: Text(
                                                tx('بەکارهاتووە: ${c['used_count'] ?? 0} جار  •  کەمترین داواکاری: ${formatIqd(c['min_order_amount'] as num?, lang: widget.lang)}'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              trailing: actions,
                                            ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),

                        // Banners / home reklaming
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compactBanner = constraints.maxWidth < 680;
                            return ListView(
                              padding: EdgeInsets.all(AdminBreakpoints.pagePadH(context)),
                              children: [
                                Card(
                                  color: RC.bg(const Color(0xFFFFFBEB)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Icon(Icons.campaign_rounded, color: RC.fg(const Color(0xFFB45309))),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            tx('وێنەی ڕیکلام بۆ سەرەکی ئەپی کڕیار بار بکە — دوای پاشەکەوتکردن لە بانەری سەرەوە دەردەکەوێت.'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: RC.fg(const Color(0xFF78350F)),
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showBannerDialog(),
                                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                    label: Text(tx('زیادکردنی وێنەی ڕیکلام')),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ..._banners.map((raw) {
                                  final b = raw as Map<String, dynamic>;
                                  final itemId = (b['id'] as num?)?.toInt();
                                  final selected = itemId != null && _bannerSelectedIds.contains(itemId);
                                  final active = b['is_active'] == true;
                                  final thumb = widget.api.resolveMediaUrl(b['image_url']?.toString());
                                  final titleStr = b['title_ku']?.toString() ?? '';
                                  final subStr = b['subtitle_ku']?.toString() ?? '';
                                  final bannerActions = <Widget>[
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.edit_rounded, color: RegaColors.blue, size: 20),
                                      tooltip: tx('دەستکاریکردن'),
                                      onPressed: () => _showBannerDialog(existing: b),
                                    ),
                                    Switch(
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      value: active,
                                      onChanged: (v) async {
                                        await widget.api.updateBanner(b['id'] as int, {'is_active': v});
                                        _load();
                                      },
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                      onPressed: () async {
                                        await widget.api.deleteBanner(b['id'] as int);
                                        _load();
                                      },
                                    ),
                                  ];

                                  if (compactBanner) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            AspectRatio(
                                              aspectRatio: 16 / 7,
                                              child: Image.network(
                                                thumb,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => Container(
                                                  color: AdminSurfaces.of(context).chipFill,
                                                  alignment: Alignment.center,
                                                  child: const Icon(Icons.image_rounded, size: 32),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (titleStr.trim().isNotEmpty)
                                                    Text(
                                                      tx(titleStr),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                                    ),
                                                  if (subStr.trim().isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      tx(subStr),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AdminSurfaces.of(context).textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: bannerActions,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: selected
                                            ? const BorderSide(color: RegaColors.orange, width: 2)
                                            : BorderSide.none,
                                      ),
                                      child: InkWell(
                                        onTap: _selectionMode && itemId != null
                                            ? () => _toggleItemSelected(itemId)
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        child: ListTile(
                                          leading: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_selectionMode && itemId != null)
                                                Padding(
                                                  padding: const EdgeInsetsDirectional.only(end: 6),
                                                  child: BulkSelectBadge(
                                                    selected: selected,
                                                    onChanged: (_) => _toggleItemSelected(itemId),
                                                  ),
                                                ),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: SizedBox(
                                                  width: 72,
                                                  height: 48,
                                                  child: Image.network(
                                                    thumb,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => const Icon(Icons.image_rounded),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          title: Text(
                                            tx(titleStr),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                          subtitle: Text(
                                            tx(subStr),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: bannerActions,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
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

