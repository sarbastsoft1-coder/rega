import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

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
  void dispose() {
    _searchCtrl.dispose();
    _platformNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _hoursCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _commissionCtrl.dispose();
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
        backgroundColor: const Color(0xFF113E2E),
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

              // 3. Top Row of Cards: زانیاریی دامەزراوە (Right) & ڕێکخستنی دلیڤەری (Left)
              _buildTopCardsRow(),
              const SizedBox(height: 20),

              // 4. Bottom Row of Cards: ئاسایش و دەسەڵات (Right), پارەدان و کرێ (Middle), ئاگادارکردنەوەکان (Left)
              _buildBottomCardsRow(),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Right side in RTL (First child): Title and Subtitle
        Column(
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
        ),

        // Left side in RTL (Second child): Search bar, Bell with 3, Profile
        Row(
          children: [
            // Search box: '...گەڕان لە ناو سیستەمدا'
            Container(
              width: 260,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: '...گەڕان لە ناو سیستەمدا',
                        hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Notification Bell with Badge '3'
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569), size: 24),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEA580C),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // User Avatar with Name "کارگێری سەرەکی" / "بەڕێوەبەر"
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 22),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'کارگێری سەرەکی',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'بەڕێوەبەر',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // 2. SUB-NAVIGATION TABS (Matching Screenshot)
  // ============================================================================
  Widget _buildSubTabsRow() {
    final tabs = ['گشتی', 'هەژمار', 'ئاگادارکردنەوە', 'پارەدان', 'ئاسایش'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedSubTab == idx;
          return InkWell(
            onTap: () => setState(() => _selectedSubTab = idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                tabs[idx],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================================
  // 3. TOP ROW OF CARDS: زانیاریی دامەزراوە (Right) & ڕێکخستنی دلیڤەری (Left)
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
              backgroundColor: const Color(0xFF16503B),
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
              backgroundColor: const Color(0xFF16503B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showSaveFeedback('ڕێکخستنەکانی پارەدان و کرێ نوێکرانەوە'),
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
