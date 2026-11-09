import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../widgets/admin_top_header.dart';

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

  // Text Controllers
  final _searchCtrl = TextEditingController();
  final _platformNameCtrl = TextEditingController(text: 'REGA');
  final _phoneCtrl = TextEditingController(text: '0750 123 4567');
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
  bool _enableCod = true;
  bool _enableFastPay = true;
  bool _enableFib = true;
  bool _enableZainCash = true;
  bool _enableQiCard = false;
  String _payoutSchedule = 'هەفتانە (Weekly)';
  String _primaryCurrency = 'دیناری عێراقی (IQD)';

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
  }

  Future<void> _loadSettings() async {
    try {
      final res = await widget.api.getSettings();
      final data = res['data'] as Map<String, dynamic>? ?? {};
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
          _phoneCtrl.text = data['support_phone'].toString();
        }
        if (data.containsKey('platform_name')) {
          _platformNameCtrl.text = data['platform_name'].toString();
        }
      });
    } catch (_) {}
  }

  Future<void> _saveDeliveryAndPlatformSettings(String msg) async {
    try {
      await widget.api.updateSettings({
        'default_delivery_fee': int.tryParse(_deliveryFeeCtrl.text.trim()) ?? 2500,
        'default_commission_rate': double.tryParse(_commissionCtrl.text.trim()) ?? 10.0,
        'working_hours': _hoursCtrl.text.trim(),
        'support_phone': _phoneCtrl.text.trim(),
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

  void _showSaveFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: const Color(0xFFEA580C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

  // ============================================================================
  // 1. TOP HEADER (Matching Screenshot)
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'ڕێکخستنەکان',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'بەڕێوەبردنی هەژمار و خزمەتگوزارییەکانی REGA',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _searchCtrl,
          hintText: '...گەڕان لە ناو سیستەمدا',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: title),
                ],
              ),
              const SizedBox(height: 12),
              topActions,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              title,
              topActions,
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
    final tabs = [
      {'name': 'گشتی', 'icon': Icons.tune_rounded},
      {'name': 'هەژمار', 'icon': Icons.person_outline_rounded},
      {'name': 'ئاگادارکردنەوە', 'icon': Icons.notifications_none_rounded},
      {'name': 'پارەدان', 'icon': Icons.payments_outlined},
      {'name': 'ئاسایش', 'icon': Icons.shield_outlined},
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
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
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
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
                      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab['name'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
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
        if (constraints.maxWidth > 880) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildCompanyInfoCard()),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildAdminProfileCard()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildCompanyInfoCard(),
              const SizedBox(height: 20),
              _buildAdminProfileCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildAdminProfileCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'هەژماری بەڕێوەبەر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFFEA580C), size: 20),
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
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFEA580C), size: 36),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'سەرپەرشتیاری گشتی سیستەم',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 2),
          const Center(
            child: Text(
              'admin@rega.krd • ناوەندی ئۆپەرەیشن',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
        final isWide = constraints.maxWidth > 880;
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'کەناڵەکانی ناردنی ئاگاداری',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.ring_volume_rounded, color: Color(0xFFEA580C), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildGatewayRow(
            title: 'دەنگی ئاگادارکردنەوە لە وێبدا',
            subtitle: 'لێدانی زەنگ لە کاتی هاتنی داواکاریی نوێ',
            icon: Icons.volume_up_rounded,
            value: _notifySound,
            onChanged: (v) => setState(() => _notifySound = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildGatewayRow(
            title: 'ئاگاداری کڕیارە نوێیەکان',
            subtitle: 'ئاگادارکردنەوە لە کاتی دروستکردنی هەژماری نوێ',
            icon: Icons.person_add_rounded,
            value: _notifyNewCustomer,
            onChanged: (v) => setState(() => _notifyNewCustomer = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildGatewayRow(
            title: 'ئاگاداری نامەی کورت (SMS)',
            subtitle: 'ناردنی SMS بۆ داواکارییە هەستیارەکان',
            icon: Icons.sms_outlined,
            value: _notifySms,
            onChanged: (v) => setState(() => _notifySms = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildGatewayRow(
            title: 'ئاگاداری کێشەی سیستەم',
            subtitle: 'ئاگاداری ڕاستەوخۆ لە کاتی لەکارکەوتن یان پەستانی بەرز',
            icon: Icons.warning_amber_rounded,
            value: _notifySystemAlert,
            onChanged: (v) => setState(() => _notifySystemAlert = v),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showSaveFeedback('ڕێکخستنەکانی کەناڵەکانی ئاگادارکردنەوە پاشەکەوت کران'),
            child: const Text('پاشەکەوتکردن', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
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
        final isWide = constraints.maxWidth > 880;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Highlights Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'ڕێکخستنەکانی پارەدان و دەروازە داراییەکان',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'دیاریکردنی کرێی گەیاندن، کۆمیسیۆنی فرۆشیاران، شێوازەکانی پارەدان و کاتی خولی پارەدان',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی پارەدان نوێکرانەوە'),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text(
                      'پاشەکەوتکردن',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'شێوازەکانی پارەدان و دەروازەکان',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFFEA580C), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildGatewayRow(
            title: 'کاش لە کاتی گەیاندن (COD)',
            subtitle: 'پارەدانی ڕاستەوخۆ بە کاش لە کاتی ڕادەستکردنی داواکاری',
            icon: Icons.money_rounded,
            value: _enableCod,
            onChanged: (v) => setState(() => _enableCod = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          _buildGatewayRow(
            title: 'فاستپەی (FastPay)',
            subtitle: 'پارەدانی ئەلیکترۆنی لە ڕێگەی ئەپی فاستپەی',
            icon: Icons.flash_on_rounded,
            value: _enableFastPay,
            onChanged: (v) => setState(() => _enableFastPay = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          _buildGatewayRow(
            title: 'بانکی نێودەوڵەتی یەکەم (FIB)',
            subtitle: 'دەروازەی ڕاستەوخۆی پارەدانی ئەلیکترۆنی FIB',
            icon: Icons.account_balance_rounded,
            value: _enableFib,
            onChanged: (v) => setState(() => _enableFib = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          _buildGatewayRow(
            title: 'زەین کاش (ZainCash)',
            subtitle: 'پارەدانی ڕاستەوخۆ لە ڕێگەی جزدانی زەین کاش',
            icon: Icons.wallet_rounded,
            value: _enableZainCash,
            onChanged: (v) => setState(() => _enableZainCash = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          _buildGatewayRow(
            title: 'کی کارد (Qi Card)',
            subtitle: 'پارەدان لە ڕێگەی ماستەرکارد و کی کاردی عێراقی',
            icon: Icons.credit_card_rounded,
            value: _enableQiCard,
            onChanged: (v) => setState(() => _enableQiCard = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutAndCurrencyCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'دراوی سیستەم و خشتەی وەرگرتن (Payouts & Currency)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.currency_exchange_rounded, color: Color(0xFF334155), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('دراوی سەرەکی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _primaryCurrency,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'دیناری عێراقی (IQD)', child: Text('دیناری عێراقی (IQD)')),
                            DropdownMenuItem(value: 'دۆلاری ئەمریکی (USD)', child: Text('دۆلاری ئەمریکی (USD)')),
                          ],
                          onChanged: (v) => setState(() => _primaryCurrency = v ?? 'دیناری عێراقی (IQD)'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('خولی پارەدان بە فرۆشیاران', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _payoutSchedule,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'هەفتانە (Weekly)', child: Text('هەفتانە (Weekly)')),
                            DropdownMenuItem(value: 'ڕۆژانە (Daily)', child: Text('ڕۆژانە (Daily)')),
                            DropdownMenuItem(value: 'مانگانە (Monthly)', child: Text('مانگانە (Monthly)')),
                          ],
                          onChanged: (v) => setState(() => _payoutSchedule = v ?? 'هەفتانە (Weekly)'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('کەمترین باڵانس بۆ کێشانەوەی شۆفێران', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _driverMinPayoutCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: 'دینار',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('کەمترین باڵانس بۆ کێشانەوەی فرۆشیاران', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _vendorMinPayoutCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: 'دینار',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی دارایی و دراو نوێکرانەوە'),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('پاشەکەوتکردنی ڕێکخستنەکانی خشتەی پارەدان', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
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
        final isWide = constraints.maxWidth > 880;
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ئاسایشی وشەی نهێنی و هەژمار',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFEA580C), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildGatewayRow(
            title: 'سەلماندنی دوو قۆناغی (2FA)',
            subtitle: 'پاراستنی هەژماری ئەدمین لە ڕێگەی کۆدی کاتی',
            icon: Icons.phonelink_lock_rounded,
            value: _twoFactorAuth,
            onChanged: (v) => setState(() => _twoFactorAuth = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildGatewayRow(
            title: 'چوونەدەرەوەی خۆکار کاتی بێدەنگی',
            subtitle: 'چوونەدەرەوە لەدوای ١٥ خولەک بێچالاکی',
            icon: Icons.timer_outlined,
            value: _autoLogoutIdle,
            onChanged: (v) => setState(() => _autoLogoutIdle = v),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          const Text('گۆڕینی وشەی نهێنی ئەدمین', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          _buildPasswordInput(label: 'وشەی نهێنی ئێستا', controller: _currentPassCtrl),
          const SizedBox(height: 8),
          _buildPasswordInput(label: 'وشەی نهێنی نوێ', controller: _newPassCtrl),
          const SizedBox(height: 8),
          _buildPasswordInput(label: 'دووبارەکردنەوەی وشەی نهێنی', controller: _confirmPassCtrl),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
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
            child: const Text('پاشەکەوتکردنی ئاسایش', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordInput({required String label, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
    );
  }

  Widget _buildGatewayRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: value ? const Color(0xFFEA580C) : const Color(0xFF94A3B8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: value ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFEA580C),
            activeTrackColor: const Color(0xFFFFEDD5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      ],
    );
  }

  // ============================================================================
  // 4. TOP ROW OF CARDS: زانیاریی دامەزراوە (Right) & ڕێکخستنی دلیڤەری (Left)
  // ============================================================================
  Widget _buildTopCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 850) {
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'زانیاریی دامەزراوە',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.apartment_rounded, color: Color(0xFF334155), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Field 1: ناوی پلاتفۆرم
          _buildSettingsInputField(label: 'ناوی پلاتفۆرم', controller: _platformNameCtrl),
          const SizedBox(height: 14),

          // Field 2: ژمارەی پەیوەندی
          _buildSettingsInputField(label: 'ژمارەی پەیوەندی', controller: _phoneCtrl, isPhone: true),
          const SizedBox(height: 14),

          // Field 3: ئیمەیڵ
          _buildSettingsInputField(label: 'ئیمەیڵ', controller: _emailCtrl),
          const SizedBox(height: 14),

          // Field 4: شار Dropdown
          Row(
            children: [
              SizedBox(
                width: 110,
                child: const Text(
                  'شار',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCity,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      items: const [
                        DropdownMenuItem(value: 'هەولێر', child: Text('هەولێر')),
                        DropdownMenuItem(value: 'سلێمانی', child: Text('سلێمانی')),
                        DropdownMenuItem(value: 'دهۆک', child: Text('دهۆک')),
                        DropdownMenuItem(value: 'کەلار', child: Text('کەلار')),
                      ],
                      onChanged: (v) => setState(() => _selectedCity = v ?? 'هەولێر'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Save Button: پاشەکەوتکردن
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showSaveFeedback('زانیارییەکانی دامەزراوە پاشەکەوت کران'),
            child: const Text('پاشەکەوتکردن', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // Card 2: ڕێکخستنی دلیڤەری
  Widget _buildDeliverySettingsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ڕێکخستنی دلیڤەری',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF16A34A), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Field 1: مەودای گەیاندن
          Row(
            children: [
              SizedBox(
                width: 100,
                child: const Text(
                  'مەودای گەیاندن',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDistance,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      items: const [
                        DropdownMenuItem(value: '٥ کیلۆمەتر', child: Text('٥ کیلۆمەتر')),
                        DropdownMenuItem(value: '١٠ کیلۆمەتر', child: Text('١٠ کیلۆمەتر')),
                        DropdownMenuItem(value: '١٥ کیلۆمەتر', child: Text('١٥ کیلۆمەتر')),
                        DropdownMenuItem(value: '٢٠ کیلۆمەتر', child: Text('٢٠ کیلۆمەتر')),
                      ],
                      onChanged: (v) => setState(() => _selectedDistance = v ?? '١٠ کیلۆمەتر'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Field 2: کاتی کارکردن with Clock Icon
          Row(
            children: [
              SizedBox(
                width: 100,
                child: const Text(
                  'کاتی کارکردن',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hoursCtrl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: وەرگرتنی داواکاری چالاکە (Switch)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'وەرگرتنی داواکاری چالاکە',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              Switch(
                value: _acceptOrders,
                activeThumbColor: const Color(0xFFEA580C),
                activeTrackColor: const Color(0xFFFFEDD5),
                onChanged: (v) => setState(() => _acceptOrders = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی دلیڤەری پاشەکەوت کران'),
            child: const Text('پاشەکەوتکردنی ڕێکخستنی دلیڤەری', style: TextStyle(fontWeight: FontWeight.w800)),
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
        if (constraints.maxWidth > 950) {
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
        } else {
          return Column(
            children: [
              _buildSecurityRolesCard(),
              const SizedBox(height: 16),
              _buildPaymentFeesCard(),
              const SizedBox(height: 16),
              _buildNotificationsSettingsCard(),
            ],
          );
        }
      },
    );
  }

  // Card 3: ئاسایش و دەسەڵات (Security & Roles)
  Widget _buildSecurityRolesCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ئاسایش و دەسەڵات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Field 1: ڕۆڵەکانی کارگێڕی
          Row(
            children: [
              SizedBox(
                width: 100,
                child: const Text(
                  'ڕۆڵەکانی کارگێڕی',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      items: const [
                        DropdownMenuItem(value: 'بەڕێوەبەر', child: Text('بەڕێوەبەر')),
                        DropdownMenuItem(value: 'کارمەندی پشتگیری', child: Text('کارمەندی پشتگیری')),
                        DropdownMenuItem(value: 'چاودێر', child: Text('چاودێر')),
                      ],
                      onChanged: (v) => setState(() => _selectedRole = v ?? 'بەڕێوەبەر'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Field 2: دۆخی هەژمار
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'دۆخی هەژمار',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                    SizedBox(width: 6),
                    Text(
                      'چالاکە',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Footer info text
          const Text(
            'هەموو تایبەتمەندییەکان دەستکەوتوون.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // Card 4: پارەدان و کرێ (Payment & Fees)
  Widget _buildPaymentFeesCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'پارەدان و کرێ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.credit_card_rounded, color: Color(0xFF334155), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 1: کرێی دلیڤەری: دینار 2500
          Row(
            children: [
              SizedBox(
                width: 100,
                child: const Text(
                  'کرێی دلیڤەری',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            controller: _deliveryFeeCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: const Text(
                          'دینار',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: کۆمیسیۆنی فرۆشیار: % 10
          Row(
            children: [
              SizedBox(
                width: 100,
                child: const Text(
                  'کۆمیسیۆنی فرۆشیار',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            controller: _commissionCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: const Text(
                          '%',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Save Button: پاشەکەوتکردن
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _saveDeliveryAndPlatformSettings('ڕێکخستنەکانی پارەدان و کرێ نوێکرانەوە'),
            child: const Text('پاشەکەوتکردن', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // Card 5: ئاگادارکردنەوەکان (Notifications Settings)
  Widget _buildNotificationsSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ئاگادارکردنەوەکان',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF16A34A), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Switch 1: داواکاریی نوێ
          _buildToggleRow(
            label: 'داواکاریی نوێ',
            value: _notifyNewOrder,
            onChanged: (v) => setState(() => _notifyNewOrder = v),
          ),
          const SizedBox(height: 8),

          // Switch 2: گۆڕانی دۆخی دلیڤەری
          _buildToggleRow(
            label: 'گۆڕانی دۆخی دلیڤەری',
            value: _notifyDeliveryStatus,
            onChanged: (v) => setState(() => _notifyDeliveryStatus = v),
          ),
          const SizedBox(height: 8),

          // Switch 3: تۆمارکردنی فرۆشیاری نوێ
          _buildToggleRow(
            label: 'تۆمارکردنی فرۆشیاری نوێ',
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        Switch(
          value: value,
          activeThumbColor: const Color(0xFFEA580C),
          activeTrackColor: const Color(0xFFFFEDD5),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSettingsInputField({
    required String label,
    required TextEditingController controller,
    bool isPhone = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
        ),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Directionality(
              textDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
              child: TextField(
                controller: controller,
                textAlign: isPhone ? TextAlign.right : TextAlign.start,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
