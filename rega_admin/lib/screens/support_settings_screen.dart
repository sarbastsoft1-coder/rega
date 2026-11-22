import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../core/services/excel_backup_service.dart';
import '../widgets/admin_top_header.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
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

class _SupportSettingsScreenState extends State<SupportSettingsScreen> {
  int _selectedSubTab = 0; // 0: گشتی, 1: هەژمار, 2: ئاگادارکردنەوە, 3: پارەدان, 4: ئاسایش

  List<Map<String, dynamic>> _adminStaff = [];
  bool _loadingStaff = false;
  bool _exportingExcel = false;
  bool _loadingBackups = false;
  String? _downloadingBackupFile;
  List<Map<String, dynamic>> _storedBackups = [];

  // Text Controllers
  final _searchCtrl = TextEditingController();
  final _platformNameCtrl = TextEditingController(text: 'REGA');
  final _phoneCtrl = TextEditingController(text: '0750 000 0000');
  final _whatsappCtrl = TextEditingController(text: '+9647700001122');
  final _telegramCtrl = TextEditingController(text: '+9647700001122');
  final _telegramUserCtrl = TextEditingController(text: 'rega_support');
  final _emailCtrl = TextEditingController(text: 'info@rega.krd');
  final _hoursCtrl = TextEditingController(text: '23:00 - 9:00');
  final _deliveryFeeCtrl = TextEditingController(text: '2500');
  final _commissionCtrl = TextEditingController(text: '10');

  // Additional Payment & Finance Controllers
  final _driverShareCtrl = TextEditingController(text: '80');
  final _minOrderCtrl = TextEditingController(text: '5000');
  final _maxCodCtrl = TextEditingController(text: '150000');
  final _driverMinPayoutCtrl = TextEditingController(text: '10000');
  final _vendorMinPayoutCtrl = TextEditingController(text: '25000');

  // Payment Gateways States
  final bool _enableCod = true;
  String _payoutSchedule = 'هەفتانە';
  String _primaryCurrency = 'دیناری عێراقی';

  // Security States
  bool _twoFactorAuth = false;
  bool _autoLogoutIdle = true;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Notification States
  bool _notifyNewCustomer = true;
  bool _notifySystemAlert = true;
  bool _notifySms = false;
  bool _notifySound = true;

  // Dropdown States
  String _selectedCity = 'هەولێر';
  String _selectedDistance = '١٠ کیلۆمەتر';
  String _selectedRole = 'بەڕێوەبەر';

  // Toggle Switches matching screenshot
  bool _acceptOrders = true;
  bool _notifyNewOrder = true;
  bool _notifyDeliveryStatus = true;
  bool _notifyNewVendor = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAdminStaff();
    _loadStoredBackups();
  }

  Future<void> _loadStoredBackups() async {
    setState(() => _loadingBackups = true);
    try {
      final list = await ExcelBackupService(widget.api).listStoredBackups();
      if (!mounted) return;
      setState(() => _storedBackups = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _storedBackups = []);
    } finally {
      if (mounted) setState(() => _loadingBackups = false);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final data = await widget.api.getSettings();
      if (!mounted) return;
      setState(() {
        if (data.containsKey('default_delivery_fee')) {
          _deliveryFeeCtrl.text = data['default_delivery_fee'].toString();
        }
        if (data.containsKey('default_commission_rate')) {
          _commissionCtrl.text = data['default_commission_rate'].toString();
        }
        if (data.containsKey('working_hours')) {
          _hoursCtrl.text = data['working_hours'].toString();
        }
        if (data.containsKey('support_phone')) {
          _phoneCtrl.text = IraqPhoneFormatter.format(data['support_phone'].toString());
        }
        if (data.containsKey('whatsapp_number')) {
          _whatsappCtrl.text = IraqPhoneFormatter.format(data['whatsapp_number'].toString());
        }
        if (data.containsKey('telegram_number')) {
          _telegramCtrl.text = IraqPhoneFormatter.format(data['telegram_number'].toString());
        }
        if (data.containsKey('telegram_username')) {
          _telegramUserCtrl.text = data['telegram_username'].toString();
        }
        if (data.containsKey('platform_name')) {
          _platformNameCtrl.text = data['platform_name'].toString();
        }
      });
    } catch (_) {}
  }

  Future<void> _loadAdminStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final list = await widget.api.getAdminStaff();
      if (!mounted) return;
      setState(() {
        _adminStaff = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingStaff = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  void _showCreateAdminDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final passwordCtrl = TextEditingController();
    bool isActive = existing?['is_active'] != false;
    bool saving = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            tx(isEdit ? 'دەستکاریکردنی هەژماری ئەدمین' : 'دروستکردنی هەژماری ئەدمین'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 520),
            ),
            child: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: tx('ناو *'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: tx('مۆبایل *'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: tx('ئیمەیڵ *'),
                        hintText: tx('admin@example.com'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: txn(isEdit ? 'وشەی نهێنی نوێ (ئارەزوومەندانە)' : 'وشەی نهێنی *'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                          icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: tx('ڕۆڵ'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        tx('ئەدمین'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      title: Text(tx('چالاک'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(tx('پاشگەزبوونەوە')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFEA580C)),
                foregroundColor: RC.fg(Colors.white),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pass = passwordCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        _showSnack('ناو و مۆبایل پێویستن', error: true);
                        return;
                      }
                      if (email.isEmpty || !email.contains('@')) {
                        _showSnack('ئیمەیڵ پێویستە بۆ چوونە ژوورەوە', error: true);
                        return;
                      }
                      if (!isEdit && pass.isEmpty) {
                        _showSnack('وشەی نهێنی پێویستە', error: true);
                        return;
                      }
                      if (!isEdit && pass.length < 6) {
                        _showSnack('وشەی نهێنی لانیکەم ٦ پیت بێت', error: true);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final payload = <String, dynamic>{
                          'name': name,
                          'phone': phone,
                          'email': email,
                          'role': 'admin',
                          'is_active': isActive,
                          if (pass.isNotEmpty) 'password': pass,
                        };
                        if (isEdit) {
                          await widget.api.updateAdminStaff(existing['id'] as int, payload);
                        } else {
                          await widget.api.createAdminStaff(payload);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadAdminStaff();
                        _showSnack(
                          isEdit
                              ? 'هەژماری ئەدمین نوێکرایەوە ✅'
                              : 'هەژماری ئەدمین دروستکرا — دەتوانیت بە ئیمەیڵ و وشەی نهێنی بچیتە ژوورەوە ✅',
                        );
                      } catch (e) {
                        setDialogState(() => saving = false);
                        _showSnack(e.toString(), error: true);
                      }
                    },
              child: Text(tx(isEdit ? 'پاشەکەوتکردن' : 'دروستکردن')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDeliveryAndPlatformSettings(String msg) async {
    try {
      await widget.api.updateSettings({
        'default_delivery_fee': int.tryParse(_deliveryFeeCtrl.text.trim()) ?? 2500,
        'default_commission_rate': double.tryParse(_commissionCtrl.text.trim()) ?? 10.0,
        'working_hours': _hoursCtrl.text.trim(),
        'support_phone': _phoneCtrl.text.trim(),
        'whatsapp_number': _whatsappCtrl.text.trim(),
        'telegram_number': _telegramCtrl.text.trim(),
        'telegram_username': _telegramUserCtrl.text.trim().replaceAll('@', ''),
        'platform_name': _platformNameCtrl.text.trim(),
      });
      _showSaveFeedback('$msg و لە سێرڤەر پاشەکەوت کران ✅');
      widget.onChanged?.call();
    } catch (e) {
      _showSaveFeedback('$msg (لۆکاڵ)');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _platformNameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _telegramCtrl.dispose();
    _telegramUserCtrl.dispose();
    _emailCtrl.dispose();
    _hoursCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _commissionCtrl.dispose();
    _driverShareCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxCodCtrl.dispose();
    _driverMinPayoutCtrl.dispose();
    _vendorMinPayoutCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  double get _cardPad => AdminBreakpoints.cardPadding(context);
  Color get _cardColor => AdminSurfaces.of(context).card;
  Color get _borderColor => AdminSurfaces.of(context).border;
  Color get _mutedFill => AdminSurfaces.of(context).mutedFill;

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(message)),
        backgroundColor: error ? RC.bg(Color(0xFFDC2626)) : RC.bg(Color(0xFF16A34A)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSaveFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: RC.fg(Colors.white), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tx(message),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: RC.bg(Color(0xFFEA580C)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AdminBreakpoints.pagePadH(context), vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Area (Matching Screenshot)
              _buildTopHeader(),
              const SizedBox(height: 16),

              // 2. Sub-navigation Tabs: گشتی | هەژمار | ئاگادارکردنەوە | پارەدان | ئاسایش
              _buildSubTabsRow(),
              const SizedBox(height: 20),

              // 3. Active Subtab Content (Smoothly changes when clicking any tab)
              _buildActiveSubTabContent(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadExcelBackup() async {
    if (_exportingExcel) return;
    setState(() => _exportingExcel = true);
    try {
      final name = await ExcelBackupService(widget.api).downloadFullBackup();
      if (!mounted) return;
      _showSaveFeedback('${AppStrings.tr('excel_backup_done', widget.lang)}: $name');
      await _loadStoredBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('${AppStrings.tr('excel_backup_failed', widget.lang)}: $e')),
          backgroundColor: RC.bg(Color(0xFFDC2626)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<void> _downloadStoredBackup(String fileName) async {
    if (_downloadingBackupFile != null) return;
    setState(() => _downloadingBackupFile = fileName);
    try {
      final name = await ExcelBackupService(widget.api).downloadStoredBackup(fileName);
      if (!mounted) return;
      _showSaveFeedback('${AppStrings.tr('excel_backup_done', widget.lang)}: $name');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('${AppStrings.tr('excel_backup_failed', widget.lang)}: $e')),
          backgroundColor: RC.bg(Color(0xFFDC2626)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingBackupFile = null);
    }
  }

  Widget _buildExcelBackupCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFFFEDD5))),
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
              final narrow = constraints.maxWidth < AdminBreakpoints.phone;
              final textCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.tr('excel_backup_title', widget.lang),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.tr('excel_backup_subtitle', widget.lang),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: RC.fg(Color(0xFF64748B)),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              final button = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFEA580C)),
                  foregroundColor: RC.fg(Colors.white),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _exportingExcel ? null : _downloadExcelBackup,
                icon: _exportingExcel
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: RC.bg(Colors.white)),
                      )
                    : const Icon(Icons.table_view_rounded, size: 18),
                label: Text(
                  tx(_exportingExcel
                      ? AppStrings.tr('excel_backup_working', widget.lang)
                      : AppStrings.tr('excel_backup_button', widget.lang)),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    textCol,
                    const SizedBox(height: 14),
                    button,
                  ],
                );
              }
              return Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFFFEDD5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.backup_table_rounded, color: RC.fg(Color(0xFFEA580C)), size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: textCol),
                  const SizedBox(width: 16),
                  button,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: RC.bg(Color(0xFFFFEDD5))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr('excel_backup_auto_title', widget.lang),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.tr('excel_backup_auto_hint', widget.lang),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: RC.fg(Color(0xFF64748B)),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _loadingBackups ? null : _loadStoredBackups,
                icon: _loadingBackups
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(AppStrings.tr('excel_backup_refresh', widget.lang)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.tr('excel_backup_recent', widget.lang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: RC.fg(Color(0xFF9A3412)),
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingBackups && _storedBackups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_storedBackups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppStrings.tr('excel_backup_empty', widget.lang),
                style: TextStyle(
                  fontSize: 12.5,
                  color: RC.fg(Color(0xFF94A3B8)),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ..._storedBackups.take(12).map((item) {
              final file = item['file']?.toString() ?? '';
              final type = item['type']?.toString() ?? '';
              final size = int.tryParse(item['size']?.toString() ?? '') ?? 0;
              final modified = ExcelBackupService.formatModified(item['modified_at']?.toString());
              final busy = _downloadingBackupFile == file;
              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFEA580C)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tx(type.toUpperCase()),
                  style: TextStyle(
                    color: RC.fg(Colors.white),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              final fileInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx(file),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    tx('$modified · ${ExcelBackupService.formatBytes(size)}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: RC.fg(Color(0xFF64748B)),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              final dlBtn = TextButton(
                onPressed: busy || file.isEmpty ? null : () => _downloadStoredBackup(file),
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.tr('excel_backup_download_file', widget.lang)),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LayoutBuilder(
                  builder: (context, rowC) {
                    final compact = rowC.maxWidth < 460;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFFFF7ED)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: RC.bg(Color(0xFFFFEDD5))),
                      ),
                      child: compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    badge,
                                    const SizedBox(width: 10),
                                    Expanded(child: fileInfo),
                                  ],
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: dlBtn,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                badge,
                                const SizedBox(width: 10),
                                Expanded(child: fileInfo),
                                dlBtn,
                              ],
                            ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot)
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx('ڕێکخستنەکان'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: RC.fg(Color(0xFF111827)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tx('بەڕێوەبردنی هەژمار و خزمەتگوزارییەکانی REGA'),
              style: TextStyle(
                fontSize: 12.5,
                color: RC.fg(Color(0xFF6B7280)),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _searchCtrl,
          hintText: tx('...گەڕان لە ناو سیستەمدا'),
          onGoToSettings: () => setState(() => _selectedSubTab = 1),
        );

        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topActions,
              const SizedBox(height: 12),
              title,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              topActions,
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              Flexible(child: topActions),
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. SUB-NAVIGATION TABS (Matching Screenshot)
  // ============================================================================
  Widget _buildSubTabsRow() {
    final isPhone = MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;
    final tabs = [
      {'name': 'گشتی', 'icon': Icons.tune_rounded},
      {'name': 'هەژمار', 'icon': Icons.person_outline_rounded},
      {'name': 'ئاگادارکردنەوە', 'icon': Icons.notifications_none_rounded},
      {'name': 'پارەدان', 'icon': Icons.payments_outlined},
      {'name': 'ئاسایش', 'icon': Icons.shield_outlined},
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: RC.bg(Color(0xFFE2E8F0)), width: 1.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(tabs.length, (idx) {
            final isSelected = _selectedSubTab == idx;
            final tab = tabs[idx];
            return InkWell(
              onTap: () => setState(() => _selectedSubTab = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: isPhone ? 14 : 22, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? RC.bg(Color(0xFFEA580C)) : Colors.transparent,
                      width: 2.8,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 17,
                      color: isSelected ? RC.fg(Color(0xFFEA580C)) : RC.bg(Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tx(tab['name'] as String),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ============================================================================
  // 3. DYNAMIC CONTENT SWITCHER
  // ============================================================================
  Widget _buildActiveSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return Column(
          children: [
            _buildExcelBackupCard(),
            const SizedBox(height: 20),
            _buildTopCardsRow(),
            const SizedBox(height: 20),
            _buildBottomCardsRow(),
          ],
        );
      case 1:
        return _buildAccountTab();
      case 2:
        return _buildNotificationsTab();
      case 3:
        return _buildPaymentsTab();
      case 4:
        return _buildSecurityTab();
      default:
        return _buildPaymentsTab();
    }
  }

  // ----------------------------------------------------------------------------
  // TAB 1: هەژمار (Account)
  // ----------------------------------------------------------------------------
  Widget _buildAccountTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final top = constraints.maxWidth >= AdminBreakpoints.tablet
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildCompanyInfoCard()),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildAdminProfileCard()),
                ],
              )
            : Column(
                children: [
                  _buildCompanyInfoCard(),
                  const SizedBox(height: 20),
                  _buildAdminProfileCard(),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            top,
            const SizedBox(height: 20),
            _buildAdminStaffCard(),
          ],
        );
      },
    );
  }

  Widget _buildAdminStaffCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tx('هەژمارەکانی ئەدمین'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: RC.fg(Color(0xFF111827)),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadAdminStaff,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(tx('نوێکردنەوە')),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RC.bg(Color(0xFFEA580C)),
                      foregroundColor: RC.fg(Colors.white),
                    ),
                    onPressed: () => _showCreateAdminDialog(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(tx('دروستکردنی ئەدمین')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tx('دەتوانیت هەژماری ئەدمین دروست بکەیت — چوونە ژوورەوە بە ئیمەیڵ و وشەی نهێنی.'),
            style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF64748B)), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (_loadingStaff)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: RC.bg(Color(0xFFEA580C)))),
            )
          else if (_adminStaff.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tx('هیچ هەژماری ئەدمین نەدۆزرایەوە'), textAlign: TextAlign.center),
            )
          else
            ..._adminStaff.map((staff) {
              final id = staff['id'] as int;
              final active = staff['is_active'] != false;
              final statusPill = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? RC.bg(Color(0xFFDCFCE7)) : RC.bg(Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tx(active ? 'چالاک' : 'ناچالاک'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFDC2626)),
                  ),
                ),
              );
              final editBtn = IconButton(
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: tx('دەستکاری'),
                onPressed: () => _showCreateAdminDialog(existing: staff),
                icon: Icon(Icons.edit_rounded, size: 19, color: RC.fg(Color(0xFF334155))),
              );
              final toggleBtn = IconButton(
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: txn(active ? 'ناچالاککردن' : 'چالاککردن'),
                onPressed: () async {
                  try {
                    await widget.api.toggleAdminStaffActive(id);
                    await _loadAdminStaff();
                    _showSnack('دۆخی هەژمار نوێکرایەوە');
                  } catch (e) {
                    _showSnack(e.toString(), error: true);
                  }
                },
                icon: Icon(
                  active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: active ? RC.fg(Color(0xFF16A34A)) : RC.bg(Color(0xFF94A3B8)),
                  size: 28,
                ),
              );
              final deleteBtn = IconButton(
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: tx('سڕینەوە'),
                onPressed: () async {
                  final name = staff['name']?.toString() ?? '';
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      insetPadding: AdminBreakpoints.dialogInset(dCtx),
                      contentPadding: AdminBreakpoints.dialogContentPadding(dCtx),
                      actionsOverflowButtonSpacing: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: Text(
                        tx('سڕینەوەی ئەدمین؟'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      content: Text(tx('دڵنیایت دەتەوێت «$name» بسڕیتەوە؟')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(tx('پاشگەزبوونەوە'))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(Color(0xFFDC2626)),
                            foregroundColor: RC.fg(Colors.white),
                          ),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: Text(tx('سڕینەوە')),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await widget.api.deleteAdminStaff(id);
                    await _loadAdminStaff();
                    _showSnack('هەژماری ئەدمین سڕایەوە ✅');
                  } catch (e) {
                    _showSnack(e.toString(), error: true);
                  }
                },
                icon: Icon(Icons.delete_forever_rounded, size: 20, color: RC.fg(Color(0xFFDC2626))),
              );

              return LayoutBuilder(
                builder: (context, staffC) {
                  final compact = staffC.maxWidth < 620;
                  final infoRow = Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: RC.bg(Color(0xFFFFEDD5)),
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: active ? RC.fg(Color(0xFFEA580C)) : RC.bg(Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx(staff['name']?.toString() ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                            ),
                            Text(
                              tx('${staff['phone'] ?? ''} • ئەدمین'
                              '${staff['email'] != null ? ' • ${staff['email']}' : ''}'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: RC.fg(Color(0xFF64748B)), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      statusPill,
                    ],
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _mutedFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              infoRow,
                              const SizedBox(height: 6),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Wrap(
                                  spacing: 4,
                                  children: [editBtn, toggleBtn, deleteBtn],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: infoRow),
                              const SizedBox(width: 4),
                              editBtn,
                              toggleBtn,
                              deleteBtn,
                            ],
                          ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminProfileCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('هەژماری بەڕێوەبەر'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFF7ED)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_rounded, color: RC.fg(Color(0xFFEA580C)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFFFFF7ED)),
                    shape: BoxShape.circle,
                    border: Border.all(color: RC.bg(Color(0xFFFFEDD5)), width: 2),
                  ),
                  child: Center(
                    child: Icon(Icons.admin_panel_settings_rounded, color: RC.fg(Color(0xFFEA580C)), size: 36),
                  ),
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFF16A34A)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: RC.fg(Colors.white), size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              tx('سەرپەرشتیاری گشتی سیستەم'),
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF0F172A))),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              tx('admin@rega.krd • ناوەندی ئۆپەرەیشن'),
              style: TextStyle(fontSize: 11.5, color: RC.fg(Color(0xFF64748B)), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: RC.bg(Color(0xFFF1F5F9))),
          const SizedBox(height: 14),
          _buildInfoRow('دەسەڵات:', 'بەڕێوەبەری سەرەکی (Superadmin)'),
          const SizedBox(height: 10),
          _buildInfoRow('ناوەند:', 'ناوەندی ئۆپەرەیشنی کەلار • گەرمیان'),
          const SizedBox(height: 10),
          _buildInfoRow('دۆخ:', 'چالاک (Online)'),
          const SizedBox(height: 10),
          _buildInfoRow('دواهەمین چوونەژوورەوە:', 'ئەمڕۆ • 09:20'),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------------
  // TAB 2: ئاگادارکردنەوە (Notifications)
  // ----------------------------------------------------------------------------
  Widget _buildNotificationsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AdminBreakpoints.tablet;
        return Column(
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildNotificationsSettingsCard()),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: _buildNotificationChannelsCard()),
                ],
              )
            else ...[
              _buildNotificationsSettingsCard(),
              const SizedBox(height: 20),
              _buildNotificationChannelsCard(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNotificationChannelsCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('کەناڵەکانی ناردنی ئاگاداری'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFF7ED)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.ring_volume_rounded, color: RC.fg(Color(0xFFEA580C)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildGatewayRow(
            title: tx('دەنگی ئاگادارکردنەوە لە وێبدا'),
            subtitle: tx('لێدانی زەنگ لە کاتی هاتنی داواکاریی نوێ'),
            icon: Icons.volume_up_rounded,
            value: _notifySound,
            onChanged: (v) => setState(() => _notifySound = v),
          ),
          Divider(height: 16, color: RC.bg(Color(0xFFF1F5F9))),
          _buildGatewayRow(
            title: tx('ئاگاداری کڕیارە نوێیەکان'),
            subtitle: tx('ئاگادارکردنەوە لە کاتی دروستکردنی هەژماری نوێ'),
            icon: Icons.person_add_rounded,
            value: _notifyNewCustomer,
            onChanged: (v) => setState(() => _notifyNewCustomer = v),
          ),
          Divider(height: 16, color: RC.bg(Color(0xFFF1F5F9))),
          _buildGatewayRow(
            title: tx('ئاگاداری نامەی کورت (SMS)'),
            subtitle: tx('ناردنی SMS بۆ داواکارییە هەستیارەکان'),
            icon: Icons.sms_outlined,
            value: _notifySms,
            onChanged: (v) => setState(() => _notifySms = v),
          ),
          Divider(height: 16, color: RC.bg(Color(0xFFF1F5F9))),
          _buildGatewayRow(
            title: tx('ئاگاداری کێشەی سیستەم'),
            subtitle: tx('ئاگاداری ڕاستەوخۆ لە کاتی لەکارکەوتن یان پەستانی بەرز'),
            icon: Icons.warning_amber_rounded,
            value: _notifySystemAlert,
            onChanged: (v) => setState(() => _notifySystemAlert = v),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showSaveFeedback('ڕێکخستنەکانی کەناڵەکانی ئاگادارکردنەوە پاشەکەوت کران'),
            child: Text(tx('پاشەکەوتکردن'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------------
  // TAB 3: پارەدان (Payments & Fees) - The Tab User Clicked!
  // ----------------------------------------------------------------------------
  Widget _buildPaymentsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AdminBreakpoints.tablet;
        final stackBanner = constraints.maxWidth < 640;

        final bannerIcon = Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: RC.bg(Color(0xFFEA580C)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.payments_rounded, color: RC.fg(Colors.white), size: 26),
        );
        final bannerTextCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx('ڕێکخستنەکانی پارەدان و دەروازە داراییەکان'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: RC.fg(Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tx('دیاریکردنی کرێی گەیاندن، کۆمیسیۆنی فرۆشیاران، شێوازەکانی پارەدان و کاتی خولی پارەدان'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: RC.fg(Color(0xFF64748B)),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
        final bannerSaveBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: RC.bg(Color(0xFFEA580C)),
            foregroundColor: RC.fg(Colors.white),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی پارەدان نوێکرانەوە'),
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(
            tx('پاشەکەوتکردن'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Highlights Banner
            Container(
              padding: EdgeInsets.all(_cardPad),
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFFFF7ED)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RC.bg(Color(0xFFFFEDD5))),
              ),
              child: stackBanner
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bannerIcon,
                            const SizedBox(width: 12),
                            Expanded(child: bannerTextCol),
                          ],
                        ),
                        const SizedBox(height: 12),
                        bannerSaveBtn,
                      ],
                    )
                  : Row(
                      children: [
                        bannerIcon,
                        const SizedBox(width: 16),
                        Expanded(child: bannerTextCol),
                        const SizedBox(width: 12),
                        bannerSaveBtn,
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // Main Two-column Grid
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildPaymentFeesCard()),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: _buildPaymentGatewaysCard()),
                ],
              )
            else ...[
              _buildPaymentFeesCard(),
              const SizedBox(height: 20),
              _buildPaymentGatewaysCard(),
            ],
            const SizedBox(height: 20),

            // Payouts & Currencies Card
            _buildPayoutAndCurrencyCard(),
          ],
        );
      },
    );
  }

  Widget _buildPaymentGatewaysCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('شێوازەکانی پارەدان و دەروازەکان'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFF7ED)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance_rounded, color: RC.fg(Color(0xFFEA580C)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildGatewayRow(
            title: tx('کاش لە کاتی گەیاندن (COD)'),
            subtitle: tx('تەنها شێوازی پارەدان چالاکە — پارە بە کاش لە کاتی ڕادەستکردن'),
            icon: Icons.money_rounded,
            value: _enableCod,
            onChanged: null,
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutAndCurrencyCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('دراوی سیستەم و خشتەی وەرگرتن (Payouts & Currency)'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.currency_exchange_rounded, color: RC.fg(Color(0xFF334155)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1040
                  ? 4
                  : (constraints.maxWidth >= 560 ? 2 : 1);
              final fieldW = AdminBreakpoints.cardWidth(constraints.maxWidth, cols, 16);
              Widget field(Widget child) => SizedBox(width: fieldW, child: child);
              final saveBtn = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFEA580C)),
                  foregroundColor: RC.fg(Colors.white),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی دارایی و دراو نوێکرانەوە'),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(tx('پاشەکەوتکردنی ڕێکخستنەکانی خشتەی پارەدان'), style: const TextStyle(fontWeight: FontWeight.w900)),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      field(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx('دراوی سەرەکی'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569)))),
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(minHeight: 40),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _mutedFill,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _primaryCurrency,
                                  isExpanded: true,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'دیناری عێراقی',
                                      child: Text(tx('دیناری عێراقی'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    DropdownMenuItem(
                                      value: 'دۆلاری ئەمریکی',
                                      child: Text(tx('دۆلاری ئەمریکی'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _primaryCurrency = v ?? 'دیناری عێراقی'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      field(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx('خولی پارەدان بە فرۆشیاران'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569)))),
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(minHeight: 40),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _mutedFill,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _payoutSchedule,
                                  isExpanded: true,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'هەفتانە',
                                      child: Text(AppStrings.tr('payout_weekly', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ڕۆژانە',
                                      child: Text(tx(widget.lang == 'en' ? 'Daily' : (widget.lang == 'ar' ? 'يومي' : 'ڕۆژانە')), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    DropdownMenuItem(
                                      value: 'مانگانە',
                                      child: Text(AppStrings.tr('payout_monthly', widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _payoutSchedule = v ?? 'هەفتانە'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      field(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx('کەمترین باڵانس بۆ کێشانەوەی شۆفێران'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569)))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _driverMinPayoutCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: tx('دینار'),
                                filled: true,
                                fillColor: _mutedFill,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      field(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx('کەمترین باڵانس بۆ کێشانەوەی فرۆشیاران'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569)))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _vendorMinPayoutCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: tx('دینار'),
                                filled: true,
                                fillColor: _mutedFill,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (constraints.maxWidth < 560)
                    saveBtn
                  else
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: saveBtn,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------------
  // TAB 4: ئاسایش (Security)
  // ----------------------------------------------------------------------------
  Widget _buildSecurityTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AdminBreakpoints.tablet;
        return Column(
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildSecurityRolesCard()),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: _buildSecurityPasswordCard()),
                ],
              )
            else ...[
              _buildSecurityRolesCard(),
              const SizedBox(height: 20),
              _buildSecurityPasswordCard(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSecurityPasswordCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('ئاسایشی وشەی نهێنی و هەژمار'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFF7ED)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lock_outline_rounded, color: RC.fg(Color(0xFFEA580C)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildGatewayRow(
            title: tx('سەلماندنی دوو قۆناغی (2FA)'),
            subtitle: tx('پاراستنی هەژماری ئەدمین لە ڕێگەی کۆدی کاتی'),
            icon: Icons.phonelink_lock_rounded,
            value: _twoFactorAuth,
            onChanged: (v) => setState(() => _twoFactorAuth = v),
          ),
          Divider(height: 16, color: RC.bg(Color(0xFFF1F5F9))),
          _buildGatewayRow(
            title: tx('چوونەدەرەوەی خۆکار کاتی بێدەنگی'),
            subtitle: tx('چوونەدەرەوە لەدوای ١٥ خولەک بێچالاکی'),
            icon: Icons.timer_outlined,
            value: _autoLogoutIdle,
            onChanged: (v) => setState(() => _autoLogoutIdle = v),
          ),
          Divider(height: 20, color: RC.bg(Color(0xFFF1F5F9))),
          Text(tx('گۆڕینی وشەی نهێنی ئەدمین'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF1E293B)))),
          const SizedBox(height: 10),
          _buildPasswordInput(label: tx('وشەی نهێنی ئێستا'), controller: _currentPassCtrl),
          const SizedBox(height: 8),
          _buildPasswordInput(label: tx('وشەی نهێنی نوێ'), controller: _newPassCtrl),
          const SizedBox(height: 8),
          _buildPasswordInput(label: tx('دووبارەکردنەوەی وشەی نهێنی'), controller: _confirmPassCtrl),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _currentPassCtrl.clear();
              _newPassCtrl.clear();
              _confirmPassCtrl.clear();
              _showSaveFeedback('ڕێکخستنەکانی ئاسایش بە سەرکەوتوویی نوێکرانەوە');
            },
            child: Text(tx('پاشەکەوتکردنی ئاسایش'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordInput({required String label, required TextEditingController controller}) {
    bool obscure = true;
    return StatefulBuilder(
      builder: (ctx, setFieldState) => TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: txn(label),
          hintStyle: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8))),
          filled: true,
          fillColor: _mutedFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: IconButton(
            onPressed: () => setFieldState(() => obscure = !obscure),
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: RC.fg(Color(0xFF94A3B8)),
            ),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
        ),
      ),
    );
  }

  Widget _buildGatewayRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value ? RC.bg(Color(0xFFFFF7ED)) : RC.bg(Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: value ? RC.fg(Color(0xFFEA580C)) : RC.bg(Color(0xFF94A3B8)), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: value ? RC.bg(Color(0xFF0F172A)) : RC.bg(Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx(subtitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeThumbColor: RC.bg(Color(0xFFEA580C)),
            activeTrackColor: RC.bg(Color(0xFFFFEDD5)),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            tx(label),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF64748B))),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            tx(value),
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF0F172A))),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 4. TOP ROW OF CARDS: زانیاریی دامەزراوە (Right) & ڕێکخستنی دلیڤەری (Left)
  // ============================================================================
  Widget _buildTopCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AdminBreakpoints.tablet) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1 (Right): زانیاریی دامەزراوە (Company Info - flex 3)
              Expanded(flex: 3, child: _buildCompanyInfoCard()),
              const SizedBox(width: 20),

              // Card 2 (Left): ڕێکخستنی دلیڤەری (Delivery Settings - flex 2)
              Expanded(flex: 2, child: _buildDeliverySettingsCard()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildCompanyInfoCard(),
              const SizedBox(height: 20),
              _buildDeliverySettingsCard(),
            ],
          );
        }
      },
    );
  }

  // Card 1: زانیاریی دامەزراوە
  Widget _buildCompanyInfoCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          // Header with Office/Apartment Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('زانیاریی دامەزراوە'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.apartment_rounded, color: RC.fg(Color(0xFF334155)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Field 1: ناوی پلاتفۆرم
          _buildSettingsInputField(label: tx('ناوی پلاتفۆرم'), controller: _platformNameCtrl),
          const SizedBox(height: 14),

          // Field 2: ژمارەی پەیوەندی (Call)
          _buildSettingsInputField(label: tx('تەلەفۆن (Contact)'), controller: _phoneCtrl, isPhone: true),
          const SizedBox(height: 14),

          // WhatsApp / Telegram shown to blocked users
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RC.bg(Color(0xFFFEF3C7)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RC.bg(Color(0xFFF59E0B)).withValues(alpha: 0.35)),
            ),
            child: Text(
              tx('ئەم ژمارانە پیشان دەدرێن بۆ کڕیار / شۆفێر / فرۆشیار کاتێک هەژمارەکەیان مسدود دەکەیت، و هەروەها لە دیالۆگی تۆمارکردنی فرۆشگای نوێ لە ئەپی فرۆشیار (WhatsApp / Telegram / تەلەفۆن).'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.4, color: RC.fg(Color(0xFF92400E))),
            ),
          ),
          _buildSettingsInputField(label: 'WhatsApp', controller: _whatsappCtrl, isPhone: true),
          const SizedBox(height: 14),
          _buildSettingsInputField(label: tx('Telegram ژمارە'), controller: _telegramCtrl, isPhone: true),
          const SizedBox(height: 14),
          _buildSettingsInputField(label: tx('Telegram یوزەرنەیم'), controller: _telegramUserCtrl),
          const SizedBox(height: 14),

          // Field 3: ئیمەیڵ
          _buildSettingsInputField(label: tx('ئیمەیڵ'), controller: _emailCtrl),
          const SizedBox(height: 14),

          // Field 4: شار Dropdown
          _buildLabeledField(
            label: 'شار',
            field: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                  items: [
                    DropdownMenuItem(value: 'هەولێر', child: Text(tx('هەولێر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'سلێمانی', child: Text(tx('سلێمانی'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'دهۆک', child: Text(tx('دهۆک'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'کەلار', child: Text(tx('کەلار'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _selectedCity = v ?? 'هەولێر'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Save Button: پاشەکەوتکردن (includes WhatsApp / Telegram contact numbers)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _saveDeliveryAndPlatformSettings('ژمارەکانی پەیوەندی (تەلەفۆن / WhatsApp / Telegram)'),
            child: Text(tx('پاشەکەوتکردن'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // Card 2: ڕێکخستنی دلیڤەری
  Widget _buildDeliverySettingsCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          // Header with Delivery Truck Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('ڕێکخستنی دلیڤەری'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_shipping_rounded, color: RC.fg(Color(0xFF16A34A)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Field 1: مەودای گەیاندن
          _buildLabeledField(
            label: 'مەودای گەیاندن',
            field: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDistance,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                  items: [
                    DropdownMenuItem(value: '٥ کیلۆمەتر', child: Text(tx('٥ کیلۆمەتر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: '١٠ کیلۆمەتر', child: Text(tx('١٠ کیلۆمەتر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: '١٥ کیلۆمەتر', child: Text(tx('١٥ کیلۆمەتر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: '٢٠ کیلۆمەتر', child: Text(tx('٢٠ کیلۆمەتر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _selectedDistance = v ?? '١٠ کیلۆمەتر'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Field 2: کاتی کارکردن with Clock Icon
          _buildLabeledField(
            label: 'کاتی کارکردن',
            field: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hoursCtrl,
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time_rounded, size: 16, color: RC.fg(Color(0xFF64748B))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Row 3: وەرگرتنی داواکاری چالاکە (Switch)
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('وەرگرتنی داواکاری چالاکە'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _acceptOrders,
                activeThumbColor: RC.bg(Color(0xFFEA580C)),
                activeTrackColor: RC.bg(Color(0xFFFFEDD5)),
                onChanged: (v) => setState(() => _acceptOrders = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی دلیڤەری پاشەکەوت کران'),
            child: Text(tx('پاشەکەوتکردنی ڕێکخستنی دلیڤەری'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 4. BOTTOM ROW OF CARDS: ئاسایش (Right), پارەدان (Middle), ئاگادارکردنەوەکان (Left)
  // ============================================================================
  Widget _buildBottomCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1180) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 3 (Right): ئاسایش و دەسەڵات (flex 3)
              Expanded(flex: 3, child: _buildSecurityRolesCard()),
              const SizedBox(width: 16),

              // Card 4 (Middle): پارەدان و کرێ (flex 3)
              Expanded(flex: 3, child: _buildPaymentFeesCard()),
              const SizedBox(width: 16),

              // Card 5 (Left): ئاگادارکردنەوەکان (flex 3)
              Expanded(flex: 3, child: _buildNotificationsSettingsCard()),
            ],
          );
        }
        if (constraints.maxWidth >= 740) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSecurityRolesCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPaymentFeesCard()),
                ],
              ),
              const SizedBox(height: 16),
              _buildNotificationsSettingsCard(),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSecurityRolesCard(),
            const SizedBox(height: 16),
            _buildPaymentFeesCard(),
            const SizedBox(height: 16),
            _buildNotificationsSettingsCard(),
          ],
        );
      },
    );
  }

  // Card 3: ئاسایش و دەسەڵات (Security & Roles)
  Widget _buildSecurityRolesCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          // Header with Shield Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('ئاسایش و دەسەڵات'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shield_outlined, color: RC.fg(Color(0xFF16A34A)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Field 1: ڕۆڵەکانی کارگێڕی
          _buildLabeledField(
            label: 'ڕۆڵەکانی کارگێڕی',
            field: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
                  items: [
                    DropdownMenuItem(value: 'بەڕێوەبەر', child: Text(tx('بەڕێوەبەر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'کارمەندی پشتگیری', child: Text(tx('کارمەندی پشتگیری'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'چاودێر', child: Text(tx('چاودێر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v ?? 'بەڕێوەبەر'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Field 2: دۆخی هەژمار
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('دۆخی هەژمار'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569))),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: RC.fg(Color(0xFF16A34A))),
                    const SizedBox(width: 6),
                    Text(
                      tx('چالاکە'),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF16A34A))),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Footer info text
          Text(
            tx('هەموو تایبەتمەندییەکان دەستکەوتوون.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // Card 4: پارەدان و کرێ (Payment & Fees)
  Widget _buildPaymentFeesCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          // Header with Credit Card Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('پارەدان و کرێ'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.credit_card_rounded, color: RC.fg(Color(0xFF334155)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 1: کرێی دلیڤەری: دینار 2500
          _buildLabeledField(
            label: 'کرێی دلیڤەری',
            field: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: TextField(
                        controller: _deliveryFeeCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF1E293B))),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8F9FA)),
                      border: BorderDirectional(start: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
                    ),
                    child: Text(
                      tx('دینار'),
                      style: TextStyle(fontSize: 11.5, color: RC.fg(Color(0xFF64748B)), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Row 2: کۆمیسیۆنی فرۆشیار: % 10
          _buildLabeledField(
            label: 'کۆمیسیۆنی فرۆشیار',
            field: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: TextField(
                        controller: _commissionCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF1E293B))),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8F9FA)),
                      border: BorderDirectional(start: BorderSide(color: RC.bg(Color(0xFFE2E8F0)))),
                    ),
                    child: Text(
                      tx('%'),
                      style: TextStyle(fontSize: 13, color: RC.fg(Color(0xFF64748B)), fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Save Button: پاشەکەوتکردن
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی پارەدان و کرێ نوێکرانەوە'),
            child: Text(tx('پاشەکەوتکردن'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // Card 5: ئاگادارکردنەوەکان (Notifications Settings)
  Widget _buildNotificationsSettingsCard() {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
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
          // Header with Notification Bell Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('ئاگادارکردنەوەکان'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.notifications_active_rounded, color: RC.fg(Color(0xFF16A34A)), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Switch 1: داواکاریی نوێ
          _buildToggleRow(
            label: tx('داواکاریی نوێ'),
            value: _notifyNewOrder,
            onChanged: (v) => setState(() => _notifyNewOrder = v),
          ),
          const SizedBox(height: 8),

          // Switch 2: گۆڕانی دۆخی دلیڤەری
          _buildToggleRow(
            label: tx('گۆڕانی دۆخی دلیڤەری'),
            value: _notifyDeliveryStatus,
            onChanged: (v) => setState(() => _notifyDeliveryStatus = v),
          ),
          const SizedBox(height: 8),

          // Switch 3: تۆمارکردنی فرۆشیاری نوێ
          _buildToggleRow(
            label: tx('تۆمارکردنی فرۆشیاری نوێ'),
            value: _notifyNewVendor,
            onChanged: (v) => setState(() => _notifyNewVendor = v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            tx(label),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          activeThumbColor: RC.bg(Color(0xFFEA580C)),
          activeTrackColor: RC.bg(Color(0xFFFFEDD5)),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget field,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tx(label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569))),
              ),
              const SizedBox(height: 6),
              field,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                tx(label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF475569))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: field),
          ],
        );
      },
    );
  }

  Widget _buildSettingsInputField({
    required String label,
    required TextEditingController controller,
    bool isPhone = false,
  }) {
    return _buildLabeledField(
      label: label,
      field: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Directionality(
          // Phone must be LTR + left-aligned or digits look reversed (e.g. 0000 000 0750).
          textDirection: isPhone ? TextDirection.ltr : (widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl),
          child: TextField(
            controller: controller,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            textAlign: isPhone ? TextAlign.left : TextAlign.start,
            inputFormatters: isPhone
                ? <TextInputFormatter>[IraqPhoneFormatter()]
                : const <TextInputFormatter>[],
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF334155))),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: txn(isPhone ? '0750 000 0000' : null),
              hintStyle: TextStyle(fontSize: 12.5, color: RC.fg(Color(0xFF94A3B8))),
            ),
          ),
        ),
      ),
    );
  }
}
