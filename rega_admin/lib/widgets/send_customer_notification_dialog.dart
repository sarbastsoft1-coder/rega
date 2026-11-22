import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../rega_colors.dart';
import '../rega_i18n.dart';

/// Shared admin dialog: create/send an in-app notification to customers.
///
/// [preselectedIds] forces audience = selected and pre-checks those customers.
Future<bool> showSendCustomerNotificationDialog(
  BuildContext context, {
  required ApiClient api,
  required String lang,
  Set<int>? preselectedIds,
  String? preselectedLabel,
}) async {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  final badgeCtrl = TextEditingController();
  final searchCtrl = TextEditingController();

  final forcedSelected = preselectedIds != null && preselectedIds.isNotEmpty;
  String audience = forcedSelected ? 'selected' : 'customers';
  String notifType = 'discount';
  bool saving = false;
  bool loadingCustomers = true;
  List<Map<String, dynamic>> customers = [];
  final Set<int> selectedIds = {...?preselectedIds};

  try {
    final raw = await api.getCustomers(isActive: true);
    customers = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (_) {
    customers = [];
  }
  loadingCustomers = false;

  if (!context.mounted) return false;

  final sent = await showDialog<bool>(
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
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          actionsOverflowButtonSpacing: 8,
          title: Text(tx('ناردنی ئاگاداری بۆ کڕیاران')),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 520),
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 560),
            ),
            child: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tx(
                        forcedSelected && (preselectedLabel?.trim().isNotEmpty ?? false)
                            ? 'ئاگاداری تایبەت بۆ: $preselectedLabel'
                            : 'ئەم نامەیە جیاوازە لە زەنگی ناوخۆیی ئەدمین — ڕاستەوخۆ دەچێتە سندوقی ئاگاداری ئەپی کڕیار (داشکاندن / پرۆمۆشن / نامەی تایبەت).',
                      ),
                      style: TextStyle(fontSize: 12, color: RC.fg(Colors.black54), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    if (!forcedSelected) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: audience,
                        decoration: InputDecoration(labelText: tx('ئامانجی وەرگر')),
                        items: [
                          DropdownMenuItem(
                            value: 'customers',
                            child: Text(tx('هەموو کڕیاران'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'selected',
                            child: Text(tx('کڕیاری هەڵبژێردراو'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: (v) => setDialogState(() => audience = v ?? 'customers'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: notifType,
                      decoration: InputDecoration(labelText: tx('جۆری ئاگاداری')),
                      items: [
                        DropdownMenuItem(
                          value: 'discount',
                          child: Text(tx('داشکاندن / پرۆمۆشن'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'general',
                          child: Text(tx('گشتی'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(tx('ئەویتر / تایبەت'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => notifType = v ?? 'discount'),
                    ),
                    if (audience == 'selected') ...[
                      const SizedBox(height: 12),
                      if (!forcedSelected) ...[
                        TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            labelText: tx('گەڕان بە ناو یان مۆبایل'),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        tx(
                          loadingCustomers
                              ? 'بارکردنی کڕیاران...'
                              : '${selectedIds.length} کڕیار هەڵبژێردرا · ${filtered.length} نیشان دراو',
                        ),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Colors.black54)),
                      ),
                      if (!forcedSelected) ...[
                        const SizedBox(height: 6),
                        Container(
                          height: math.min(180.0, AdminBreakpoints.dialogMaxHeight(ctx, fraction: 0.28)),
                          decoration: BoxDecoration(
                            border: Border.all(color: RC.bg(Colors.black12)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: loadingCustomers
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : filtered.isEmpty
                                  ? Center(child: Text(tx('هیچ کڕیارێک نەدۆزرایەوە')))
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
                                            tx(c['name']?.toString() ?? '—'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                          subtitle: Text(
                                            tx(c['phone']?.toString() ?? ''),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: tx('سەردێڕ *'),
                        hintText: tx('نموونە: داشکاندنی %30 ئەمڕۆ'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: tx('ناوەڕۆک / نامە *'),
                        hintText: tx('هەر نامەیەک کە دەتەوێت بۆ کڕیار بنێریت...'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: badgeCtrl,
                      decoration: InputDecoration(
                        labelText: tx('باجی داشکاندن (ئارەزوومەندانە)'),
                        hintText: tx('نموونە: %30 OFF یان 5,000 د.ع'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: Text(AppStrings.tr('cancel', lang)),
            ),
            ElevatedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tx('سەردێڕ و ناوەڕۆک پێویستن')),
                            backgroundColor: RegaColors.crimson,
                          ),
                        );
                        return;
                      }
                      if (audience == 'selected' && selectedIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tx('تکایە لانیکەم یەک کڕیار هەڵبژێرە')),
                            backgroundColor: RegaColors.crimson,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await api.sendNotification({
                          'target_audience': audience,
                          'title_ku': titleCtrl.text.trim(),
                          'body_ku': bodyCtrl.text.trim(),
                          'type': notifType,
                          if (audience == 'selected') 'user_ids': selectedIds.toList(),
                          if (badgeCtrl.text.trim().isNotEmpty) 'discount_badge': badgeCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tx(e.toString())), backgroundColor: RegaColors.crimson),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(tx('ناردن بۆ کڕیاران')),
            ),
          ],
        );
      },
    ),
  );

  titleCtrl.dispose();
  bodyCtrl.dispose();
  badgeCtrl.dispose();
  searchCtrl.dispose();
  return sent == true;
}
