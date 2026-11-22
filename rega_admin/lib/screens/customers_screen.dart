import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../widgets/admin_top_header.dart';
import '../widgets/common_widgets.dart';
import '../core/theme/app_theme.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
import '../widgets/send_customer_notification_dialog.dart';
/// Representation of a customer item matching the exact design in the screenshot
class CustomerItem {
  final int id;
  final String name;
  final String phone;
  final String city;
  final int totalOrders;
  final String registerDate;
  final bool isActive;
  final bool isFemale;

  CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.totalOrders,
    required this.registerDate,
    required this.isActive,
    this.isFemale = false,
  });

  CustomerItem copyWith({
    int? id,
    String? name,
    String? phone,
    String? city,
    int? totalOrders,
    String? registerDate,
    bool? isActive,
    bool? isFemale,
  }) {
    return CustomerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      totalOrders: totalOrders ?? this.totalOrders,
      registerDate: registerDate ?? this.registerDate,
      isActive: isActive ?? this.isActive,
      isFemale: isFemale ?? this.isFemale,
    );
  }
}

class CustomersScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const CustomersScreen({
    super.key,
    required this.api,
    required this.lang,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _topSearchCtrl = TextEditingController();
  Timer? _refreshTimer;

  /// Stable filter keys (not localized) so EN/AR/KU switches don't break filters.
  String _selectedCity = 'all'; // 'all' | DB city (KU)
  String _selectedStatus = 'all'; // all | active | inactive
  String _selectedPeriod = 'this_month'; // this_month | last_month | this_year
  int _currentPage = 1;

  // Live KPI Metrics from PostgreSQL database (formatted in build via lang)
  int _totalCustomers = 0;
  int _activeCustomers = 0;
  int _newThisMonth = 0;
  int _todayOrders = 0;

  /// Last 6 months new-customer series from `/admin/dashboard`
  List<Map<String, dynamic>> _newCustomersChart = [];
  int _newCustomersYMax = 4;

  String get _lang => widget.lang;

  String _d(dynamic input) => AppStrings.digits(input, _lang);

  static int _niceCeiling(int value) {
    if (value <= 0) return 4;
    if (value <= 4) return 4;
    final step = value <= 20
        ? 5
        : value <= 100
            ? 10
            : value <= 500
                ? 50
                : value <= 2000
                    ? 100
                    : 500;
    return ((value / step).ceil() * step);
  }

  List<CustomerItem> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadFromBackend(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _topSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend({bool silent = false}) async {
    if (!silent && _customers.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await widget.api.getCustomers();

      // Live new-customers monthly series + KPIs from dashboard analytics
      List<Map<String, dynamic>> chartSeries = _newCustomersChart;
      int newThisMonthCount = -1;
      int todayOrdersKpi = -1;
      try {
        final dash = await widget.api.getDashboard(days: 30);
        final rawChart = dash['new_customers_chart'] as List<dynamic>? ?? [];
        chartSeries = rawChart.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final kpis = dash['kpis'] as Map<String, dynamic>? ?? {};
        newThisMonthCount = (kpis['new_customers_this_month'] as num?)?.toInt() ??
            (chartSeries.isNotEmpty ? ((chartSeries.last['count'] as num?)?.toInt() ?? 0) : 0);
        todayOrdersKpi = (kpis['today_orders'] as num?)?.toInt() ?? -1;
      } catch (_) {}

      if (!mounted) return;

      final mapped = res.map((m) {
        final map = m as Map<String, dynamic>;
        final addresses = map['addresses'] as List<dynamic>? ?? [];
        final rawCity = map['city']?.toString();
        final addrCity = addresses.isNotEmpty
            ? (addresses.first as Map<String, dynamic>)['city']?.toString()
            : null;
        final city = AppStrings.cityDbValue(
          (rawCity != null && rawCity.trim().isNotEmpty)
              ? rawCity
              : (addrCity != null && addrCity.trim().isNotEmpty)
                  ? addrCity
                  : 'کەلار',
        );
        final orderCount = (map['orders_count'] as num?)?.toInt() ??
            (map['customer_orders_count'] as num?)?.toInt() ??
            0;
        final createdAt = map['created_at']?.toString() ?? '2026-11-09';
        return CustomerItem(
          id: (map['id'] as num?)?.toInt() ?? 0,
          name: map['name']?.toString() ?? AppStrings.tr('customer_fallback', _lang),
          phone: map['phone']?.toString() ?? '0750 000 ****',
          city: city,
          totalOrders: orderCount,
          registerDate: createdAt.split('T').first,
          isActive: map['is_active'] != false,
        );
      }).toList();

      final totalCount = mapped.length;
      final activeCount = mapped.where((c) => c.isActive).length;
      final totalOrders = mapped.fold<int>(0, (sum, c) => sum + c.totalOrders);
      final counts = chartSeries.map((e) => (e['count'] as num?)?.toInt() ?? 0).toList();
      final yMax = _niceCeiling(counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b));

      setState(() {
        _customers = mapped;
        _totalCustomers = totalCount;
        _activeCustomers = activeCount;
        _newThisMonth = newThisMonthCount >= 0 ? newThisMonthCount : 0;
        _todayOrders = todayOrdersKpi >= 0 ? todayOrdersKpi : totalOrders;
        _newCustomersChart = chartSeries;
        _newCustomersYMax = yMax;
        _isLoading = false;
      });
    } catch (_) {
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

  List<CustomerItem> get _filteredCustomers {
    final query = _topSearchCtrl.text.trim().toLowerCase();
    return _customers.where((c) {
      if (query.isNotEmpty) {
        final matchName = c.name.toLowerCase().contains(query);
        final matchPhone = c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
        final matchCity = c.city.toLowerCase().contains(query);
        if (!matchName && !matchPhone && !matchCity) return false;
      }
      if (_selectedCity != 'all' && c.city != _selectedCity) return false;
      if (_selectedStatus == 'active' && !c.isActive) return false;
      if (_selectedStatus == 'inactive' && c.isActive) return false;
      return true;
    }).toList();
  }

  void _showAddCustomerDialog({CustomerItem? existing}) {
    final isEdit = existing != null;
    final lang = _lang;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final rawCity = AppStrings.cityDbValue(existing?.city ?? 'کەلار');
    String city = AppStrings.knownCitiesKu.contains(rawCity) ? rawCity : 'کەلار';
    bool isActive = existing?.isActive ?? true;
    bool saving = false;
    String? formError;

    void dialogSnack(BuildContext dialogCtx, String msg, {bool error = false}) {
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        SnackBar(
          content: Text(tx(msg)),
          backgroundColor: error ? RC.bg(Color(0xFFDC2626)) : RC.bg(Color(0xFF16A34A)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return ScaffoldMessenger(
            child: Builder(
              builder: (messengerCtx) {
                // Prefer in-dialog messenger so errors are visible above the modal.
                void showDialogError(String msg) => dialogSnack(messengerCtx, msg, error: true);

                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: AlertDialog(
                  insetPadding: AdminBreakpoints.dialogInset(ctx),
                  contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
                  actionsOverflowButtonSpacing: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: Row(
                    children: [
                      Icon(
                        isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                        color: RC.fg(Color(0xFF113E2E)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx(isEdit
                              ? AppStrings.tr('edit_customer', lang)
                              : AppStrings.tr('add_customer_new', lang)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: AdminBreakpoints.dialogWidth(ctx, max: 440),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 540),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (formError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFFFEE2E2)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: RC.bg(Color(0xFFFECACA))),
                                ),
                                child: Text(
                                  tx(formError!),
                                  style: TextStyle(
                                    color: RC.fg(Color(0xFFB91C1C)),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: nameCtrl,
                              enabled: !saving,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('customer_name_label', lang),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: phoneCtrl,
                              enabled: !saving,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              inputFormatters: <TextInputFormatter>[IraqPhoneFormatter()],
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('mobile_label', lang),
                                hintText: tx('0750 000 0000'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: emailCtrl,
                              enabled: !saving,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('email_optional', lang),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: passwordCtrl,
                              enabled: !saving,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr(
                                  isEdit ? 'password_new_optional' : 'password_required_label',
                                  lang,
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: city,
                              items: [
                                for (final c in AppStrings.knownCitiesKu)
                                  DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      tx(AppStrings.cityLabel(c, lang)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (v) => setDialogState(() => city = v ?? 'کەلار'),
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('city', lang),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: !isActive,
                              activeTrackColor: RC.bg(Color(0xFFFECACA)),
                              activeThumbColor: RC.bg(Color(0xFFDC2626)),
                              onChanged: saving
                                  ? null
                                  : (v) => setDialogState(() => isActive = !v),
                              title: Text(
                                AppStrings.tr('block_account', lang),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                tx(isActive
                                    ? AppStrings.tr('account_active', lang)
                                    : AppStrings.tr('account_blocked_hint', lang)),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  actions: [
                    if (isEdit)
                      TextButton(
                        onPressed: saving
                            ? null
                            : () async {
                                // Re-bind snack helper for nested confirm flow.
                                final confirmed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (confirmCtx) => AlertDialog(
                                    insetPadding: AdminBreakpoints.dialogInset(confirmCtx),
                                    contentPadding: AdminBreakpoints.dialogContentPadding(confirmCtx),
                                    actionsOverflowButtonSpacing: 8,
                                    title: Text(
                                      AppStrings.tr('confirm_delete_customer_title', lang),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    content: SingleChildScrollView(
                                      child: Text(AppStrings.tr('confirm_delete_customer_body', lang)),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(confirmCtx, false),
                                        child: Text(AppStrings.tr('cancel', lang)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(confirmCtx, true),
                                        child: Text(
                                          AppStrings.tr('delete', lang),
                                          style: TextStyle(
                                            color: RC.fg(Color(0xFFDC2626)),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !ctx.mounted) return;
                                setDialogState(() {
                                  saving = true;
                                  formError = null;
                                });
                                var deleted = false;
                                try {
                                  await widget.api.deleteCustomer(existing.id);
                                  deleted = true;
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _showSnack(AppStrings.tr('customer_deleted', lang));
                                  try {
                                    await _loadFromBackend();
                                  } catch (_) {}
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  setDialogState(() => formError = e.toString());
                                  showDialogError(e.toString());
                                } finally {
                                  if (!deleted && ctx.mounted) {
                                    setDialogState(() => saving = false);
                                  }
                                }
                              },
                        child: Text(
                          AppStrings.tr('delete', lang),
                          style: TextStyle(color: RC.fg(Color(0xFFDC2626))),
                        ),
                      ),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: Text(
                        AppStrings.tr('cancel', lang),
                        style: TextStyle(color: RC.fg(Colors.grey)),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFF16A34A)),
                        foregroundColor: RC.fg(Colors.white),
                        disabledBackgroundColor: RC.bg(Color(0xFF16A34A)).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final phoneRaw = phoneCtrl.text.trim();
                              final phone = IraqPhoneFormatter.digitsOnly(phoneRaw);
                              final email = emailCtrl.text.trim();
                              final password = passwordCtrl.text.trim();

                              if (name.isEmpty || phoneRaw.isEmpty) {
                                final msg = AppStrings.tr('customer_name_phone_required', lang);
                                setDialogState(() => formError = msg);
                                showDialogError(msg);
                                return;
                              }
                              if (!IraqPhoneFormatter.isValidIraqMobile(phoneRaw)) {
                                final msg = AppStrings.tr('customer_phone_invalid', lang);
                                setDialogState(() => formError = msg);
                                showDialogError(msg);
                                return;
                              }
                              if (isEdit && existing.id <= 0) {
                                final msg = AppStrings.tr('customer_invalid_id', lang);
                                setDialogState(() => formError = msg);
                                showDialogError(msg);
                                return;
                              }
                              if (!isEdit && password.isEmpty) {
                                final msg = AppStrings.tr('customer_password_required', lang);
                                setDialogState(() => formError = msg);
                                showDialogError(msg);
                                return;
                              }
                              if ((!isEdit || password.isNotEmpty) && password.length < 6) {
                                final msg = AppStrings.tr('customer_password_min', lang);
                                setDialogState(() => formError = msg);
                                showDialogError(msg);
                                return;
                              }

                              setDialogState(() {
                                saving = true;
                                formError = null;
                              });
                              var succeeded = false;
                              try {
                                final payload = <String, dynamic>{
                                  'name': name,
                                  'phone': phone,
                                  'city': city,
                                  'is_active': isActive,
                                  if (email.isNotEmpty) 'email': email,
                                  if (password.isNotEmpty) 'password': password,
                                };
                                if (isEdit) {
                                  await widget.api.updateCustomer(existing.id, payload);
                                } else {
                                  await widget.api.createCustomer(payload);
                                }
                                succeeded = true;
                                if (ctx.mounted) Navigator.pop(ctx);
                                _showSnack(
                                  AppStrings.tr(isEdit ? 'customer_updated' : 'customer_created', lang),
                                );
                                // Reload after close so a slow list fetch never holds the spinner.
                                try {
                                  await _loadFromBackend();
                                } catch (_) {}
                              } catch (e) {
                                if (!ctx.mounted) return;
                                final msg = e.toString();
                                setDialogState(() => formError = msg);
                                showDialogError(msg);
                              } finally {
                                // Always clear spinner on error; on success dialog is already closed.
                                if (!succeeded && ctx.mounted) {
                                  setDialogState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: RC.bg(Colors.white)),
                            )
                          : Text(AppStrings.tr(isEdit ? 'save' : 'add', lang)),
                    ),
                  ],
                ),
                );
              },
            ),
          );
        },
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      passwordCtrl.dispose();
    });
  }

  void _showCustomerDetailsDialog(CustomerItem c) {
    final lang = _lang;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: RC.bg(Color(0xFFE5E7EB)),
              child: Icon(Icons.person_rounded, color: RC.fg(Color(0xFF6B7280))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx(c.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Text(
                    tx(AppStrings.cityLabel(c.city, lang)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF9CA3AF))),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(c.isActive),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 420),
            maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 520),
          ),
          child: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('📱 ${AppStrings.tr('phone', lang)}:', c.phone, ltrValue: true),
                  _buildDetailRow('🏙️ ${AppStrings.tr('city', lang)}:', AppStrings.cityLabel(c.city, lang)),
                  _buildDetailRow(
                    '🛍️ ${AppStrings.tr('total_orders_label', lang)}:',
                    '${_d(c.totalOrders)} ${AppStrings.tr('orders_count_suffix', lang)}',
                  ),
                  _buildDetailRow('📅 ${AppStrings.tr('col_register_date', lang)}:', c.registerDate, ltrValue: true),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await showSendCustomerNotificationDialog(
                context,
                api: widget.api,
                lang: lang,
                preselectedIds: {c.id},
                preselectedLabel: '${c.name} ${c.phone}'.trim(),
              );
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tx('ئاگاداری نێردرا — لە سندوقی ئەپی کڕیار دەردەکەوێت')),
                    backgroundColor: RegaColors.emeraldDark,
                  ),
                );
              }
            },
            child: Text(tx('ناردنی ئاگاداری')),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddCustomerDialog(existing: c);
            },
            child: Text(AppStrings.tr('edit', lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFF113E2E)),
              foregroundColor: RC.fg(Colors.white),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.tr('close', lang)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool ltrValue = false}) {
    return ResponsiveDetailRow(
      label: label,
      value: value,
      ltrValue: ltrValue,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: RC.fg(Color(0xFF4B5563))),
      valueStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: RC.fg(Color(0xFF111827))),
    );
  }

  // ============================================================================
  // BUILD SCREEN
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCustomers;

    final padH = AdminBreakpoints.pagePadH(context);
    return Directionality(
      textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Area (Matching Screenshot)
              _buildTopHeader(),
              const SizedBox(height: 20),

              // 2. 4 Top KPI Metric Cards (Matching Screenshot)
              _buildKPICardsRow(),
              const SizedBox(height: 20),

              // 3. Middle Section: Chart on Left, Filter Bar on Right
              _buildMiddleSection(),
              const SizedBox(height: 16),

              // 4. Main Customers Table Card (Matching Screenshot)
              _buildCustomersTableCard(filtered),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot: Title & Button on Right, Profile on Left)
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 980;
        final titleSize = constraints.maxWidth < 400 ? 18.0 : 22.0;

        final titleAndButton = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('customers_title', _lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: AdminSurfaces.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.tr('customers_subtitle', _lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AdminSurfaces.of(context).textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RC.fg(const Color(0xFF113E2E)),
                    side: BorderSide(color: RC.fg(const Color(0xFF113E2E))),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final ok = await showSendCustomerNotificationDialog(
                      context,
                      api: widget.api,
                      lang: _lang,
                    );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tx('ئاگاداری نێردرا — لە سندوقی ئەپی کڕیار دەردەکەوێت')),
                          backgroundColor: RegaColors.emeraldDark,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_active_rounded, size: 18),
                  label: Text(
                    tx('ناردنی ئاگاداری'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFF113E2E)),
                    foregroundColor: RC.fg(Colors.white),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddCustomerDialog(),
                  icon: Icon(Icons.add, size: 18, color: RC.fg(Colors.white)),
                  label: Text(
                    AppStrings.tr('add_customer', _lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _topSearchCtrl,
          hintText: AppStrings.tr('search_customer', _lang),
          onSearchChanged: (_) => setState(() {}),
        );

        if (constraints.maxWidth < AdminBreakpoints.headerCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topActions,
              const SizedBox(height: 12),
              titleAndButton,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleAndButton,
              const SizedBox(height: 12),
              topActions,
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleAndButton),
              const SizedBox(width: 12),
              Flexible(child: topActions),
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. 4 TOP KPI METRIC SUMMARY CARDS (Matching Screenshot Right to Left)
  // ============================================================================
  Widget _buildKPICardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= AdminBreakpoints.kpiFourCol
            ? 4
            : (width >= AdminBreakpoints.kpiTwoCol ? 2 : 1);
        final cardWidth = AdminBreakpoints.cardWidth(width, cols, 16);
        final lang = _lang;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_total_customers', lang),
                value: _d(_totalCustomers),
                icon: Icons.person_rounded,
                iconBg: RC.bg(Color(0xFFFFEDD5)),
                iconColor: RC.fg(Color(0xFFEA580C)),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_active_customers', lang),
                value: _d(_activeCustomers),
                icon: Icons.groups_rounded,
                iconBg: RC.bg(Color(0xFFEFF6FF)),
                iconColor: RC.fg(Color(0xFF2563EB)),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_new_this_month', lang),
                value: _d(_newThisMonth),
                icon: Icons.person_add_rounded,
                iconBg: RC.bg(Color(0xFFDCFCE7)),
                iconColor: RC.fg(Color(0xFF16A34A)),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKPICard(
                title: AppStrings.tr('kpi_today_orders', lang),
                value: _d(_todayOrders),
                icon: Icons.shopping_cart_outlined,
                iconBg: RC.bg(Color(0xFFFFEDD5)),
                iconColor: RC.fg(Color(0xFFEA580C)),
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
        children: [
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Value & Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tx(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminSurfaces.of(context).textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tx(value),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AdminSurfaces.of(context).textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. MIDDLE SECTION: Filters on Right, Chart on Left (in RTL)
  // ============================================================================
  Widget _buildMiddleSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AdminBreakpoints.chartsSideBySide;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 48,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _buildFilterBar(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 52,
                child: _buildNewCustomersChartCard(),
              ),
            ],
          );
        }
        // Narrow: New Customers chart stacks below filters
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterBar(),
            const SizedBox(height: 14),
            _buildNewCustomersChartCard(),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final lang = _lang;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _buildDropdownPill(
          icon: Icons.calendar_today_outlined,
          value: _selectedPeriod,
          items: [
            ('this_month', AppStrings.tr('this_month', lang)),
            ('last_month', AppStrings.tr('last_month', lang)),
            ('this_year', AppStrings.tr('this_year', lang)),
          ],
          onChanged: (v) => setState(() => _selectedPeriod = v ?? 'this_month'),
        ),
        _buildDropdownPill(
          icon: Icons.person_outline_rounded,
          value: _selectedStatus,
          items: [
            ('all', AppStrings.tr('customer_status_filter', lang)),
            ('active', AppStrings.tr('active', lang)),
            ('inactive', AppStrings.tr('inactive', lang)),
          ],
          onChanged: (v) => setState(() => _selectedStatus = v ?? 'all'),
        ),
        _buildDropdownPill(
          icon: Icons.location_on_outlined,
          value: _selectedCity,
          items: [
            ('all', AppStrings.tr('all_cities', lang)),
            for (final c in AppStrings.knownCitiesKu) (c, AppStrings.cityLabel(c, lang)),
          ],
          onChanged: (v) => setState(() => _selectedCity = v ?? 'all'),
        ),
      ],
    );
  }

  Widget _buildDropdownPill({
    required IconData icon,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminSurfaces.of(context).textPrimary,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item.$1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: RC.fg(Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      tx(item.$2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
  // New Customers Curved Area Line Chart (live last-6-months series)
  // ============================================================================
  Widget _buildNewCustomersChartCard() {
    final counts = _newCustomersChart
        .map((e) => (e['count'] as num?)?.toInt() ?? 0)
        .toList();
    final labels = _newCustomersChart
        .map((e) {
          final m = (e['month'] as num?)?.toInt();
          if (m != null) return AppStrings.monthLabel(m, _lang);
          return e['label_ku']?.toString() ?? '';
        })
        .toList();
    final yMax = _newCustomersYMax;
    final yTicks = List<int>.generate(5, (i) => ((yMax * (4 - i)) / 4).round());

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr('new_customers_chart', _lang),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AdminSurfaces.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 110, maxHeight: 130),
              child: SizedBox(
                height: 112,
                child: Row(
                  children: [
                    // Y-axis labels — fixed width so values never push canvas unevenly
                    SizedBox(
                      width: 34,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: yTicks
                            .map(
                              (v) => Text(
                                tx(v >= 1000
                                    ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
                                    : '$v'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: AdminSurfaces.of(context).textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: counts.isEmpty
                          ? Center(
                              child: Text(
                                tx('...'),
                                style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8))),
                              ),
                            )
                          : CustomPaint(
                              painter: _CustomersChartPainter(
                                values: counts,
                                yMax: yMax,
                                gridColor: AdminSurfaces.of(context).hairline,
                              ),
                              size: Size.infinite,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // X-axis Month Labels — actual last 6 calendar months (ku)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: (labels.isEmpty
                        ? const ['—', '—', '—', '—', '—', '—']
                        : labels)
                    .map(
                      (label) => Flexible(
                        child: Text(
                          tx(label),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AdminSurfaces.of(context).textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerMobileCard(CustomerItem c) {
    final surfaces = AdminSurfaces.of(context);
    final lang = _lang;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surfaces.chipFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  c.isFemale ? Icons.face_3_rounded : Icons.person_rounded,
                  size: 18,
                  color: surfaces.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx(c.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(c.isActive),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  tx(c.phone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              Text(
                tx(AppStrings.cityLabel(c.city, lang)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surfaces.textSecondary),
              ),
              Text(
                tx('${_d(c.totalOrders)} ${AppStrings.tr('orders_count_suffix', lang)}'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: RC.fg(Color(0xFFEA580C))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () async {
                  final ok = await showSendCustomerNotificationDialog(
                    context,
                    api: widget.api,
                    lang: _lang,
                    preselectedIds: {c.id},
                    preselectedLabel: '${c.name} ${c.phone}'.trim(),
                  );
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tx('ئاگاداری نێردرا — لە سندوقی ئەپی کڕیار دەردەکەوێت')),
                        backgroundColor: RegaColors.emeraldDark,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Tooltip(
                  message: tx('ناردنی ئاگاداری'),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.notifications_active_outlined, size: 17, color: RC.fg(const Color(0xFF2563EB))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showCustomerDetailsDialog(c),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.visibility_outlined, size: 17, color: RC.fg(Color(0xFF475569))),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showAddCustomerDialog(existing: c),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.edit_outlined, size: 17, color: RC.fg(Color(0xFF475569))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 4. MAIN CUSTOMERS TABLE CARD (Matching Screenshot)
  // ============================================================================
  Widget _buildCustomersTableCard(List<CustomerItem> list) {
    // Show top 5 records for page 1
    final pagedList = list.take(5).toList();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 40, color: RC.fg(Color(0xFFCBD5E1))),
                              const SizedBox(height: 10),
                              Text(
                                AppStrings.tr('no_customers', _lang),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF94A3B8))),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...pagedList.map(_buildCustomerMobileCard),
                  ],
                );
              }
              final tableWidth = constraints.maxWidth > 940 ? constraints.maxWidth : 940.0;
              return Scrollbar(
                child: SingleChildScrollView(
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
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            border: Border(bottom: BorderSide(color: AdminSurfaces.of(context).hairline)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(AppStrings.tr('col_customer', _lang), textAlign: TextAlign.start, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: Text(AppStrings.tr('col_mobile', _lang), textAlign: TextAlign.start, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(AppStrings.tr('city', _lang), textAlign: TextAlign.start, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(AppStrings.tr('col_total_orders', _lang), textAlign: TextAlign.center, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: Text(AppStrings.tr('col_register_date', _lang), textAlign: TextAlign.center, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(AppStrings.tr('col_status', _lang), textAlign: TextAlign.center, style: _headerStyle)),
                              const SizedBox(width: 8),
                              SizedBox(width: 112, child: Text(AppStrings.tr('col_action', _lang), textAlign: TextAlign.end, style: _headerStyle)),
                            ],
                          ),
                        ),

                        // Table Rows
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 40, color: RC.fg(Color(0xFFCBD5E1))),
                                  const SizedBox(height: 10),
                                  Text(
                                    AppStrings.tr('no_customers', _lang),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF94A3B8))),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pagedList.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: AdminSurfaces.of(context).hairline),
                            itemBuilder: (context, index) {
                              final c = pagedList[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    // 1. Customer Name + Avatar
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: AdminSurfaces.of(context).chipFill,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              c.isFemale ? Icons.face_3_rounded : Icons.person_rounded,
                                              size: 16,
                                              color: AdminSurfaces.of(context).textTertiary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              tx(c.name),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5,
                                                color: RC.fg(Color(0xFF1E293B)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 2. Phone
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            tx(c.phone),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AdminSurfaces.of(context).textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 3. City
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        tx(AppStrings.cityLabel(c.city, _lang)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AdminSurfaces.of(context).textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 4. Total Orders
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        tx('${c.totalOrders}'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AdminSurfaces.of(context).textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 5. Register Date
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        tx(c.registerDate),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AdminSurfaces.of(context).textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 6. Status
                                    Expanded(
                                      flex: 2,
                                      child: Center(child: _buildStatusBadge(c.isActive)),
                                    ),
                                    const SizedBox(width: 8),

                                    // 7. Actions [🔔] [👁] [✏️]
                                    SizedBox(
                                      width: 112,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // Send Notification Button
                                          InkWell(
                                            onTap: () async {
                                              final ok = await showSendCustomerNotificationDialog(
                                                context,
                                                api: widget.api,
                                                lang: _lang,
                                                preselectedIds: {c.id},
                                                preselectedLabel: '${c.name} ${c.phone}'.trim(),
                                              );
                                              if (ok && context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(tx('ئاگاداری نێردرا — لە سندوقی ئەپی کڕیار دەردەکەوێت')),
                                                    backgroundColor: RegaColors.emeraldDark,
                                                  ),
                                                );
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Tooltip(
                                              message: tx('ناردنی ئاگاداری'),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AdminSurfaces.of(context).chipFill,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(Icons.notifications_active_outlined, size: 16, color: RC.fg(const Color(0xFF2563EB))),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // View Details Eye Button
                                          InkWell(
                                            onTap: () => _showCustomerDetailsDialog(c),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AdminSurfaces.of(context).chipFill,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(Icons.visibility_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Edit Button
                                          InkWell(
                                            onTap: () => _showAddCustomerDialog(existing: c),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AdminSurfaces.of(context).chipFill,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(Icons.edit_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
                                            ),
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
              );
            },
          ),

          // Pagination Footer
          Container(
            width: double.infinity,
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
                  AppStrings.trParams('showing_of', _lang, {'shown': _d(pagedList.length), 'total': _d(list.length), 'unit': AppStrings.tr('nav_customers', _lang)}),
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
                      _buildPageNavBtn(
                        icon: isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                        onTap: () {},
                      ),
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
                      _buildPageNavBtn(
                        icon: isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? RC.bg(Color(0xFFDCFCE7)) : RC.bg(Color(0xFFFEE2E2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        tx(isActive ? AppStrings.tr('active', _lang) : AppStrings.tr('inactive', _lang)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: isActive ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFDC2626)),
        ),
      ),
    );
  }

  Widget _buildPageNumberBtn({required int page, required bool active}) {
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? RC.bg(Color(0xFF113E2E)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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

/// Custom painter for the New Customers curved area line chart (live values)
class _CustomersChartPainter extends CustomPainter {
  final List<int> values;
  final int yMax;
  final Color gridColor;

  _CustomersChartPainter({
    required this.values,
    required this.yMax,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty || yMax <= 0) return;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * (i / (values.length - 1));
      final ratio = (values[i] / yMax).clamp(0.0, 1.0);
      final y = size.height * (1.0 - ratio);
      points.add(Offset(x, y));
    }

    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final areaPath = Path.from(linePath);
    areaPath.lineTo(size.width, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        RC.bg(Color(0xFF0D9488)).withValues(alpha: 0.35),
        RC.bg(Color(0xFF0D9488)).withValues(alpha: 0.02),
      ],
    );

    final areaPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = RC.bg(Color(0xFF0D9488))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = RC.bg(Color(0xFF0D9488));
    final dotWhite = Paint()..color = RC.bg(Colors.white);

    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 2.0, dotWhite);
    }
  }

  @override
  bool shouldRepaint(covariant _CustomersChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.yMax != yMax ||
        oldDelegate.gridColor != gridColor;
  }
}
