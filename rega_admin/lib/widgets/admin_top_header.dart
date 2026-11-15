import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../state/admin_app_notifier.dart';
import '../state/admin_domain_notifiers.dart';

/// Top header actions row containing:
/// 1. Interactive Search Bar (Global Spotlight Search)
/// 2. Admin Profile Dropdown (Profile, Language, Dark Mode, Logout)
/// 3. Notifications Bell (Live Alerts & Navigation)
///
/// Language + theme live in the sticky AdminShell chrome (always visible).
class AdminTopBarRow extends StatelessWidget {
  final TextEditingController? searchCtrl;
  final String hintText;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onGoToOrders;
  final VoidCallback? onGoToStores;
  final VoidCallback? onGoToDrivers;
  final VoidCallback? onGoToSettings;

  const AdminTopBarRow({
    super.key,
    this.searchCtrl,
    this.hintText = '',
    this.onSearchChanged,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onGoToOrders,
    this.onGoToStores,
    this.onGoToDrivers,
    this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final compactSearch = screenW < AdminBreakpoints.phone;
    final gap = compactSearch ? 4.0 : 10.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AdminGlobalSearchBar(
          controller: searchCtrl,
          hintText: hintText.isEmpty ? AppStrings.tr('search_system', context.watch<AdminAppNotifier>().lang) : hintText,
          onChanged: onSearchChanged,
          compact: compactSearch,
        ),
        SizedBox(width: gap),
        AdminProfileDropdown(onGoToSettings: onGoToSettings, compact: compactSearch),
        SizedBox(width: compactSearch ? 2 : 8),
        AdminNotificationsBell(
          onGoToOrders: onGoToOrders,
          onGoToStores: onGoToStores,
          onGoToDrivers: onGoToDrivers,
          onGoToSettings: onGoToSettings,
        ),
      ],
    );
  }
}

/// Visible language control — cycles / picks ku · ar · en (persists via [AdminAppNotifier]).
class AdminLocaleToggle extends StatelessWidget {
  const AdminLocaleToggle({super.key});

  static const _order = ['ku', 'ar', 'en'];

  String _label(String code, String lang) {
    switch (code) {
      case 'ar':
        return AppStrings.tr('lang_ar', lang);
      case 'en':
        return AppStrings.tr('lang_en', lang);
      default:
        return AppStrings.tr('lang_ku', lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AdminAppNotifier>();
    final surfaces = AdminSurfaces.of(context);
    final lang = app.lang;

    return PopupMenuButton<String>(
      tooltip: AppStrings.tr('language', lang),
      initialValue: lang,
      onSelected: app.setLang,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => _order
          .map(
            (code) => PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Icon(
                    lang == code ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 18,
                    color: lang == code ? RegaColors.orange : surfaces.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _label(code, lang),
                    style: TextStyle(
                      fontWeight: lang == code ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: surfaces.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 16, color: surfaces.textSecondary),
            const SizedBox(width: 6),
            Text(
              lang.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: surfaces.textPrimary,
                letterSpacing: 0.4,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: surfaces.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Visible light / dark theme control (persists via [AdminAppNotifier.setDark]).
class AdminThemeToggle extends StatelessWidget {
  const AdminThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AdminAppNotifier>();
    final surfaces = AdminSurfaces.of(context);
    final lang = app.lang;
    final isDark = app.isDark;

    return Tooltip(
      message: isDark ? AppStrings.tr('theme_light', lang) : AppStrings.tr('theme_dark', lang),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => app.setDark(!isDark),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: surfaces.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: surfaces.border),
            ),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
              size: 18,
              color: surfaces.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. GLOBAL SEARCH BAR & SPOTLIGHT MODAL
// ============================================================================
class AdminGlobalSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool compact;

  const AdminGlobalSearchBar({
    super.key,
    this.controller,
    this.hintText = '',
    this.onChanged,
    this.compact = false,
  });

  @override
  State<AdminGlobalSearchBar> createState() => _AdminGlobalSearchBarState();
}

class _AdminGlobalSearchBarState extends State<AdminGlobalSearchBar> {
  late final TextEditingController _ctrl;
  bool _isSelfCtrl = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = TextEditingController();
      _isSelfCtrl = true;
    }
  }

  @override
  void dispose() {
    if (_isSelfCtrl) _ctrl.dispose();
    super.dispose();
  }

  void _openSpotlightSearch(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _SpotlightSearchDialog(initialQuery: _ctrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminSurfaces.of(context);
    if (widget.compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSpotlightSearch(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.border),
            ),
            child: Icon(Icons.search_rounded, size: 18, color: s.textSecondary),
          ),
        ),
      );
    }
    final screenW = MediaQuery.sizeOf(context).width;
    final barW = screenW < AdminBreakpoints.phone
        ? (screenW * 0.42).clamp(120.0, 180.0)
        : 220.0;
    return Container(
      width: barW,
      constraints: BoxConstraints(
        minWidth: screenW < AdminBreakpoints.phone ? 110 : 140,
        maxWidth: screenW < AdminBreakpoints.phone ? 180 : 260,
      ),
      height: 38,
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.border),
        boxShadow: [
          BoxShadow(
            color: s.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          InkWell(
            onTap: () => _openSpotlightSearch(context),
            child: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              onSubmitted: (_) => _openSpotlightSearch(context),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            InkWell(
              onTap: () {
                _ctrl.clear();
                widget.onChanged?.call('');
                setState(() {});
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotlightSearchDialog extends StatefulWidget {
  final String initialQuery;

  const _SpotlightSearchDialog({required this.initialQuery});

  @override
  State<_SpotlightSearchDialog> createState() => _SpotlightSearchDialogState();
}

class _SpotlightSearchDialogState extends State<_SpotlightSearchDialog> {
  late final TextEditingController _queryCtrl;
  final List<Map<String, dynamic>> _allEntries = [
    {'title': 'ڕێکخستنەکانی پارەدان', 'sub': 'کرێی گەیاندن، کۆمیسیۆن و دەروازەکان', 'type': 'setting', 'path': '/support', 'icon': Icons.payments_rounded},
    {'title': 'ڕاپۆرتە داراییەکان', 'sub': 'داهات، فرۆش و تێچووی سیستەم', 'type': 'finance', 'path': '/finance', 'icon': Icons.insert_chart_rounded},
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: widget.initialQuery);
    _loadLiveEntities();
  }

  Future<void> _loadLiveEntities() async {
    final api = context.read<AdminAppNotifier>().api;
    try {
      final results = await Future.wait([
        api.getOrders(),
        api.getStores(),
        api.getDrivers(),
        api.getCustomers(),
        api.getProducts(),
      ]);

      final ordersRes = results[0] as Map<String, dynamic>? ?? {};
      final ordersList = ordersRes['data'] as List<dynamic>? ?? [];
      final storesList = results[1] as List<dynamic>? ?? [];
      final driversList = results[2] as List<dynamic>? ?? [];
      final customersList = results[3] as List<dynamic>? ?? [];
      final productsList = results[4] as List<dynamic>? ?? [];

      final List<Map<String, dynamic>> live = [];

      for (final o in ordersList.take(20)) {
        final m = o as Map<String, dynamic>;
        final store = m['store'] as Map<String, dynamic>?;
        final num = m['order_number']?.toString() ?? '#RA-${m['id']}';
        final storeName = store?['name_ku']?.toString() ?? store?['name_en']?.toString() ?? 'فرۆشگا';
        final amt = m['total_amount']?.toString() ?? '0';
        live.add({
          'title': 'داواکاری $num',
          'sub': '$storeName • $amt د.ع',
          'type': 'order',
          'path': '/order-intake',
          'icon': Icons.headset_mic_rounded,
        });
      }

      for (final s in storesList) {
        final m = s as Map<String, dynamic>;
        final name = m['name_ku']?.toString() ?? m['name_en']?.toString() ?? 'فرۆشگا';
        final cat = m['category'] as Map<String, dynamic>?;
        final cuisine = cat?['name_ku']?.toString() ?? 'خواردن';
        live.add({
          'title': name,
          'sub': '$cuisine • کەلار',
          'type': 'store',
          'path': '/stores',
          'icon': Icons.storefront_rounded,
        });
      }

      for (final p in productsList.take(40)) {
        final m = p as Map<String, dynamic>;
        final name = m['name_ku']?.toString() ?? m['name_en']?.toString() ?? 'بەرهەم';
        final store = m['store'] as Map<String, dynamic>?;
        final storeName = store?['name_ku']?.toString() ?? '';
        final price = m['price']?.toString() ?? '0';
        live.add({
          'title': name,
          'sub': '$storeName • $price د.ع',
          'type': 'product',
          'path': '/vendor-items',
          'icon': Icons.restaurant_menu_rounded,
        });
      }

      for (final d in driversList) {
        final m = d as Map<String, dynamic>;
        final u = m['user'] as Map<String, dynamic>? ?? {};
        final name = u['name']?.toString() ?? 'شۆفێر';
        final phone = u['phone']?.toString() ?? '';
        live.add({
          'title': name,
          'sub': 'ماتۆرسوار • $phone',
          'type': 'driver',
          'path': '/drivers',
          'icon': Icons.two_wheeler_rounded,
        });
      }

      for (final c in customersList) {
        final m = c as Map<String, dynamic>;
        final name = m['name']?.toString() ?? 'کڕیار';
        final phone = m['phone']?.toString() ?? '';
        live.add({
          'title': name,
          'sub': 'کڕیار • $phone',
          'type': 'customer',
          'path': '/customers',
          'icon': Icons.person_rounded,
        });
      }

      live.add({'title': 'ڕێکخستنەکانی پارەدان', 'sub': 'کرێی گەیاندن، کۆمیسیۆن و دەروازەکان', 'type': 'setting', 'path': '/support', 'icon': Icons.payments_rounded});
      live.add({'title': 'ڕاپۆرتە داراییەکان', 'sub': 'داهات، فرۆش و تێچووی سیستەم', 'type': 'finance', 'path': '/finance', 'icon': Icons.insert_chart_rounded});

      if (mounted) {
        setState(() {
          _allEntries.clear();
          _allEntries.addAll(live);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = AdminSurfaces.of(context);
    final lang = context.watch<AdminAppNotifier>().lang;
    final query = _queryCtrl.text.trim().toLowerCase();
    final results = query.isEmpty
        ? _allEntries
        : _allEntries.where((e) {
            final t = (e['title'] as String).toLowerCase();
            final s = (e['sub'] as String).toLowerCase();
            return t.contains(query) || s.contains(query);
          }).toList();

    return Dialog(
      backgroundColor: surfaces.dialog,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 12 : 20,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: surfaces.border),
      ),
      child: Container(
        width: AdminBreakpoints.dialogWidth(context, max: 520),
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Field
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: surfaces.mutedFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFFEA580C), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: AppStrings.tr('search_system', lang),
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_queryCtrl.text.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _queryCtrl.clear()),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AdminSurfaces.of(context).hairline),
            const SizedBox(height: 10),

            // Results List
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 8),
                          Text(AppStrings.tr('no_results', lang), style: TextStyle(color: AdminSurfaces.of(context).textSecondary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: AdminSurfaces.of(context).hairline),
                      itemBuilder: (context, idx) {
                        final item = results[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item['icon'] as IconData, color: const Color(0xFFEA580C), size: 20),
                          ),
                          title: Text(
                            item['title'] as String,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          subtitle: Text(
                            item['sub'] as String,
                            style: TextStyle(fontSize: 11.5, color: AdminSurfaces.of(context).textSecondary, fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                          onTap: () {
                            Navigator.pop(context);
                            final path = item['path'] as String;
                            final tabIndex = AdminNavNotifier.indexForPath(path);
                            context.read<AdminNavNotifier>().setTabIndex(tabIndex);
                            context.go(path);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. INTERACTIVE USER PROFILE DROPDOWN MENU
// ============================================================================
class AdminProfileDropdown extends StatelessWidget {
  final VoidCallback? onGoToSettings;
  final bool compact;

  const AdminProfileDropdown({
    super.key,
    this.onGoToSettings,
    this.compact = false,
  });

  void _showProfileDialog(BuildContext context) {
    final app = context.read<AdminAppNotifier>();
    final lang = app.lang;
    final surfaces = AdminSurfaces.of(context);
    final user = app.currentUser;
    final userName = user?['name']?.toString() ?? AppStrings.tr('nav_staff', lang);
    final userEmail = user?['email']?.toString() ?? '';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: surfaces.dialog,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 12 : 20,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: surfaces.border),
        ),
        child: Container(
          width: AdminBreakpoints.dialogWidth(context, max: 380),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: surfaces.isDark ? const Color(0xFF3B2112) : const Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFEA580C), size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: surfaces.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail.isEmpty ? AppStrings.tr('nav_staff', lang) : userEmail,
                          style: TextStyle(fontSize: 11.5, color: surfaces.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: surfaces.successSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      AppStrings.statusLabel('verified', lang),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: surfaces.isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: surfaces.hairline),
              const SizedBox(height: 10),
              _buildMenuActionTile(
                context: context,
                icon: Icons.settings_outlined,
                title: AppStrings.tr('nav_support', lang),
                subtitle: AppStrings.tr('dashboard_subtitle', lang),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AdminNavNotifier>().setTabIndex(AdminNavNotifier.indexForPath('/support'));
                  context.go('/support');
                },
              ),
              _buildMenuActionTile(
                context: context,
                icon: Icons.language_rounded,
                title: AppStrings.tr('language', lang),
                subtitle: AppStrings.tr(
                  lang == 'ku' ? 'lang_ku' : (lang == 'ar' ? 'lang_ar' : 'lang_en'),
                  lang,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLanguageDialog(context);
                },
              ),
              _buildMenuActionTile(
                context: context,
                icon: app.isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                title: app.isDark ? AppStrings.tr('theme_light', lang) : AppStrings.tr('theme_dark', lang),
                subtitle: AppStrings.tr('theme_switch_sub', lang),
                onTap: () {
                  app.setDark(!app.isDark);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: surfaces.hairline),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await app.logout();
                  if (context.mounted) context.go('/login');
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.tr('logout', lang),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final app = context.read<AdminAppNotifier>();
    final surfaces = AdminSurfaces.of(context);
    final lang = app.lang;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaces.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(AppStrings.tr('lang_pick', lang), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                lang == 'ku' ? Icons.check_circle_rounded : Icons.language_rounded,
                color: lang == 'ku' ? const Color(0xFFEA580C) : surfaces.textSecondary,
              ),
              title: Text(AppStrings.tr('lang_ku', lang), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                app.setLang('ku');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                lang == 'ar' ? Icons.check_circle_rounded : Icons.language_rounded,
                color: lang == 'ar' ? const Color(0xFFEA580C) : surfaces.textSecondary,
              ),
              title: Text(AppStrings.tr('lang_ar', lang), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                app.setLang('ar');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                lang == 'en' ? Icons.check_circle_rounded : Icons.language_rounded,
                color: lang == 'en' ? const Color(0xFFEA580C) : surfaces.textSecondary,
              ),
              title: Text(AppStrings.tr('lang_en', lang), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                app.setLang('en');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final surfaces = AdminSurfaces.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: surfaces.mutedFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: surfaces.border),
              ),
              child: Icon(icon, color: surfaces.textPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: surfaces.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: surfaces.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: surfaces.textTertiary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = AdminSurfaces.of(context);
    final app = context.watch<AdminAppNotifier>();
    final name = app.currentUser?['name']?.toString() ?? AppStrings.tr('nav_staff', app.lang);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showProfileDialog(context),
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFFEA580C).withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surfaces.chipFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, color: surfaces.textSecondary, size: 22),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: surfaces.textPrimary,
                        ),
                      ),
                      Text(
                        AppStrings.tr('nav_staff', app.lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: surfaces.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: surfaces.textSecondary, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. INTERACTIVE NOTIFICATIONS BELL WITH MODAL POPUP
// ============================================================================
class AdminNotificationsBell extends StatefulWidget {
  final VoidCallback? onGoToOrders;
  final VoidCallback? onGoToStores;
  final VoidCallback? onGoToDrivers;
  final VoidCallback? onGoToSettings;

  const AdminNotificationsBell({
    super.key,
    this.onGoToOrders,
    this.onGoToStores,
    this.onGoToDrivers,
    this.onGoToSettings,
  });

  @override
  State<AdminNotificationsBell> createState() => _AdminNotificationsBellState();
}

class _AdminNotificationsBellState extends State<AdminNotificationsBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminInboxNotifier>().load(silent: true);
    });
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'storefront':
        return Icons.storefront_rounded;
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'support':
        return Icons.support_agent_rounded;
      case 'receipt':
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _colorFor(String? hex, {Color fallback = const Color(0xFFEA580C)}) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  void _navigateForItem(BuildContext context, Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    final route = item['route']?.toString();
    final tab = (item['tab_index'] as num?)?.toInt();

    switch (type) {
      case 'pending_orders':
        if (widget.onGoToOrders != null) {
          widget.onGoToOrders!();
          return;
        }
        break;
      case 'pending_stores':
        if (widget.onGoToStores != null) {
          widget.onGoToStores!();
          return;
        }
        break;
      case 'pending_drivers':
        if (widget.onGoToDrivers != null) {
          widget.onGoToDrivers!();
          return;
        }
        break;
      case 'open_tickets':
        if (widget.onGoToSettings != null) {
          widget.onGoToSettings!();
          return;
        }
        break;
    }

    if (tab != null) {
      context.read<AdminNavNotifier>().setTabIndex(tab);
    }
    if (route != null && route.isNotEmpty) {
      context.go(route);
    }
  }

  Future<void> _showNotificationsModal(BuildContext context) async {
    final inbox = context.read<AdminInboxNotifier>();
    await inbox.load(silent: true);

    if (!context.mounted) return;
    final surfaces = AdminSurfaces.of(context);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Consumer<AdminInboxNotifier>(
        builder: (ctx, inboxState, _) {
          final lang = ctx.watch<AdminAppNotifier>().lang;
          final unread = inboxState.unreadCount;
          final items = inboxState.items;

          return Dialog(
            backgroundColor: surfaces.dialog,
            surfaceTintColor: Colors.transparent,
            elevation: 16,
            insetPadding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < AdminBreakpoints.phone ? 12 : 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: surfaces.border),
            ),
            child: Container(
              width: AdminBreakpoints.dialogWidth(context, max: 420),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFFEA580C),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('notifications', lang),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AdminSurfaces.of(context).textPrimary,
                                ),
                              ),
                              Text(
                                unread > 0
                                    ? AppStrings.trParams('unread_waiting', lang, {'n': '$unread'})
                                    : AppStrings.tr('all_read', lang),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AdminSurfaces.of(context).textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (unread > 0)
                        TextButton(
                          onPressed: () async {
                            try {
                              await inboxState.markAllRead();
                            } catch (_) {}
                          },
                          child: Text(AppStrings.tr('mark_all_read', lang),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: AdminSurfaces.of(context).hairline),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          AppStrings.tr('no_notifications', lang),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AdminSurfaces.of(context).textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 8, color: AdminSurfaces.of(context).hairline),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final isUnread = item['is_read'] != true;
                          final timeLabel =
                              item['time_label']?.toString() ?? '';
                          return _buildNotificationItem(
                            icon: _iconFor(item['icon']?.toString()),
                            iconColor: _colorFor(item['color']?.toString()),
                            title: item['title_ku']?.toString() ?? '',
                            subtitle: item['body_ku']?.toString() ?? '',
                            time: timeLabel,
                            isUnread: isUnread,
                            onTap: () async {
                              final key = item['id']?.toString();
                              if (key != null && isUnread) {
                                try {
                                  await inboxState.markRead(key);
                                } catch (_) {}
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (!context.mounted) return;
                              _navigateForItem(context, item);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: AdminSurfaces.of(context).hairline),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEA580C),
                      side: const BorderSide(color: Color(0xFFFFEDD5)),
                      backgroundColor: const Color(0xFFFFF7ED),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (widget.onGoToSettings != null) {
                        widget.onGoToSettings!();
                      } else {
                        context.read<AdminNavNotifier>().setTabIndex(AdminNavNotifier.indexForPath('/support'));
                        context.go('/support');
                      }
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: Text(AppStrings.tr('notification_settings', lang),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isUnread ? FontWeight.w900 : FontWeight.w700,
                            color: AdminSurfaces.of(context).textPrimary,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEA580C),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AdminSurfaces.of(context).textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: AdminSurfaces.of(context).textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AdminInboxNotifier>().unreadCount;
    final badge = unread > 99 ? '99+' : '$unread';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showNotificationsModal(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: AdminSurfaces.of(context).textSecondary,
                size: 24,
              ),
              if (unread > 0)
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
                    child: Center(
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: AdminSurfaces.of(context).card,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
