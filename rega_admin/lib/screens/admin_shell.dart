import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../state/admin_app_notifier.dart';
import '../state/admin_domain_notifiers.dart';
import '../widgets/admin_top_header.dart';
import 'customer_part_screen.dart';
import 'dashboard_screen.dart';
import 'drivers_screen.dart';
import 'accounting_screen.dart';
import 'order_intake_screen.dart';
import 'orders_screen.dart';
import 'service_areas_part_screen.dart';
import 'stores_screen.dart';
import 'products_screen.dart';
import 'admin_staff_screen.dart';
import 'support_settings_screen.dart';

import '../rega_i18n.dart';

class AdminShell extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic> currentUser;
  final String lang;
  final bool isDark;
  final ValueChanged<String> onLangChanged;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLogout;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;

  const AdminShell({
    super.key,
    required this.api,
    required this.currentUser,
    required this.lang,
    required this.isDark,
    required this.onLangChanged,
    required this.onThemeChanged,
    required this.onLogout,
    this.initialIndex = 0,
    this.onTabChanged,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late int _selectedIndex;
  int _pendingOrdersBadge = 0;
  int _onlineStoresBadge = 0;
  int _customersBadge = 0;
  int _onlineDriversBadge = 0;
  int _openTicketsBadge = 0;
  /// Bumped on manual refresh so the active screen remounts and reloads live API data.
  int _dataRefreshKey = 0;
  bool _refreshing = false;

  /// User's explicit sidebar choice on laptop/desktop. `null` = automatic
  /// (icon rail below [AdminBreakpoints.laptop], full sidebar above it).
  bool? _sidebarCollapsedPref;

  bool _isSidebarCollapsed(double screenWidth) =>
      _sidebarCollapsedPref ?? screenWidth < AdminBreakpoints.laptop;

  @override
  void initState() {
    super.initState();
    final maxTab = AdminNavNotifier.tabPaths.length - 1;
    _selectedIndex = widget.initialIndex.clamp(0, maxTab);
    final tabParam = Uri.base.queryParameters['tab'];
    if (tabParam != null) {
      final idx = int.tryParse(tabParam);
      if (idx != null && idx >= 0 && idx <= maxTab) {
        _selectedIndex = idx;
      }
    }
    _refreshBadges();
  }

  @override
  void didUpdateWidget(covariant AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex &&
        _selectedIndex != widget.initialIndex) {
      setState(() => _selectedIndex = widget.initialIndex.clamp(0, AdminNavNotifier.tabPaths.length - 1));
    }
  }

  void _selectTab(int idx) {
    setState(() => _selectedIndex = idx);
    widget.onTabChanged?.call(idx);
  }

  Future<void> _refreshBadges() async {
    try {
      final dash = context.read<DashboardNotifier>();
      final inbox = context.read<AdminInboxNotifier>();
      await Future.wait([
        dash.load(days: 7, silent: true),
        inbox.load(silent: true),
      ]);
      if (mounted) {
        setState(() {
          _pendingOrdersBadge = dash.pendingOrders;
          _onlineStoresBadge = dash.onlineStores;
          _customersBadge = dash.totalCustomers;
          _onlineDriversBadge = dash.onlineDrivers;
          _openTicketsBadge = dash.openTickets;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshAllLiveData() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        _refreshBadges(),
        context.read<OrdersNotifier>().load(silent: true),
        context.read<DriversNotifier>().load(silent: true),
        context.read<CustomersNotifier>().load(silent: true),
        context.read<StoresNotifier>().load(silent: true),
        context.read<AdminInboxNotifier>().load(silent: true),
      ]);
      if (!mounted) return;
      setState(() => _dataRefreshKey++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('refresh', widget.lang)),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<_NavItemSpec> _buildNavItems() => [
        _NavItemSpec(Icons.home_outlined, AppStrings.tr('nav_dashboard', widget.lang)),
        _NavItemSpec(Icons.headset_mic_outlined, AppStrings.tr('nav_order_intake', widget.lang)),
        _NavItemSpec(Icons.receipt_long_outlined, AppStrings.tr('nav_orders', widget.lang)),
        _NavItemSpec(Icons.two_wheeler_outlined, AppStrings.tr('nav_drivers', widget.lang)),
        _NavItemSpec(Icons.people_outline_rounded, AppStrings.tr('nav_customers', widget.lang)),
        _NavItemSpec(Icons.map_rounded, AppStrings.tr('nav_service_cities', widget.lang)),
        _NavItemSpec(Icons.storefront_outlined, AppStrings.tr('nav_stores', widget.lang)),
        _NavItemSpec(Icons.restaurant_menu_outlined, AppStrings.tr('nav_vendor_items', widget.lang)),
        _NavItemSpec(Icons.insert_chart_outlined_rounded, AppStrings.tr('nav_finance', widget.lang)),
        _NavItemSpec(Icons.admin_panel_settings_outlined, AppStrings.tr('nav_staff', widget.lang)),
        _NavItemSpec(Icons.settings_outlined, AppStrings.tr('nav_support', widget.lang)),
      ];

  Widget _buildActiveScreen() {
    final key = ValueKey('admin-tab-$_selectedIndex-$_dataRefreshKey');
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          key: key,
          api: widget.api,
          lang: widget.lang,
          onNavigateTab: _selectTab,
        );
      case 1:
        return OrderIntakeScreen(
          key: key,
          api: widget.api,
          lang: widget.lang,
          onChanged: _refreshBadges,
        );
      case 2:
        return OrdersScreen(
          key: key,
          api: widget.api,
          lang: widget.lang,
          onOrderChanged: _refreshBadges,
        );
      case 3:
        return DriversScreen(key: key, api: widget.api, lang: widget.lang);
      case 4:
        return CustomerPartScreen(
          key: key,
          api: widget.api,
          lang: widget.lang,
          onDataChanged: _refreshBadges,
        );
      case 5:
        return ServiceAreasPartScreen(
          key: key,
          api: widget.api,
          lang: widget.lang,
        );
      case 6:
        return StoresScreen(key: key, api: widget.api, lang: widget.lang);
      case 7:
        return ProductsScreen(key: key, api: widget.api, lang: widget.lang);
      case 8:
        return AccountingScreen(key: key, api: widget.api, lang: widget.lang);
      case 9:
        return AdminStaffScreen(key: key, api: widget.api, lang: widget.lang);
      case 10:
        return SupportSettingsScreen(
          key: key,
          api: widget.api,
          lang: widget.lang,
          onChanged: _refreshBadges,
        );
      default:
        return OrderIntakeScreen(
          key: key,
          api: widget.api,
          lang: widget.lang,
          onChanged: _refreshBadges,
        );
    }
  }

  Widget _buildSidebar({required bool isDrawer, bool collapsed = false}) {
    final items = _buildNavItems();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final rail = collapsed && !isDrawer;
    final double width = rail
        ? AdminBreakpoints.sidebarRail
        : (!isDrawer && screenWidth >= AdminBreakpoints.wide
            ? AdminBreakpoints.sidebarWide
            : AdminBreakpoints.sidebarNormal);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      color: RegaColors.sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            // Prominent REGA Pin Logo matching screenshot
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 42,
                        color: Color(0xFFFF5722),
                      ),
                      Positioned(
                        top: 9,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: RegaColors.sidebarBg,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!rail) const SizedBox(height: 6),
                  if (!rail)
                  Text(
                    tx('REGA'),
                    style: const TextStyle(
                      // Sidebar is always dark forest green — keep light text in both themes.
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: rail ? 10 : 14, vertical: 8),
                itemCount: items.length,
                itemBuilder: (ctx, idx) {
                  final item = items[idx];
                  final active = _selectedIndex == idx;

                  final Color itemBg = active ? RegaColors.orange : Colors.transparent;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: itemBg,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: RegaColors.orange.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            _selectTab(idx);
                            if (isDrawer) Navigator.pop(ctx);
                          },
                          child: rail
                              ? Tooltip(
                                  message: item.label,
                                  preferBelow: false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Icon(
                                        item.icon,
                                        size: 22,
                                        // Do not use RC.bg(white) here — in dark mode it maps to a
                                        // dark slate and vanishes on the forest-green sidebar.
                                        color: active
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.78),
                                      ),
                                    ),
                                  ),
                                )
                              : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 21,
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.78),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                                      color: active
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.88),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(rail ? 10 : 16, 8, rail ? 10 : 16, 20),
              child: rail
                  ? Tooltip(
                      message: AppStrings.tr('logout', widget.lang),
                      child: IconButton(
                        onPressed: widget.onLogout,
                        icon: Icon(
                          Icons.logout_rounded,
                          size: 21,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    )
                  : Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    widget.onLogout();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 21,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            AppStrings.tr('logout', widget.lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Phone / iPad portrait use drawer; wide tablets & desktop keep fixed sidebar.
    final isDesktop = screenWidth >= AdminBreakpoints.tablet;
    final sidebarCollapsed = _isSidebarCollapsed(screenWidth);
    final surfaces = AdminSurfaces.of(context);
    final surfaceColor = surfaces.elevated;

    final isPhone = screenWidth < AdminBreakpoints.phone;
    final isTightPhone = screenWidth < 380;

    return Scaffold(
      backgroundColor: surfaces.canvas,
      drawer: isDesktop
          ? null
          : Drawer(
              width: math.min(280.0, screenWidth * 0.84),
              child: _buildSidebar(isDrawer: true),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop)
              _buildSidebar(isDrawer: false, collapsed: sidebarCollapsed),
            Expanded(
              child: Column(
                children: [
                  // Sticky chrome: always visible language + theme + refresh on all sizes.
                  Container(
                    height: isPhone ? 48 : 58,
                    padding: EdgeInsets.symmetric(
                      horizontal: isPhone ? 4 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border(
                        bottom: BorderSide(color: surfaces.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isDesktop)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            tooltip: AppStrings.tr(
                              sidebarCollapsed ? 'expand_menu' : 'collapse_menu',
                              widget.lang,
                            ),
                            icon: Icon(
                              sidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
                            ),
                            onPressed: () => setState(
                              () => _sidebarCollapsedPref = !sidebarCollapsed,
                            ),
                          ),
                        if (!isDesktop)
                          Builder(
                            builder: (ctx) => IconButton(
                              visualDensity: isPhone
                                  ? VisualDensity.compact
                                  : VisualDensity.standard,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: isTightPhone ? 36 : 40,
                                minHeight: 40,
                              ),
                              icon: const Icon(Icons.menu_rounded),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            AppStrings.tr('kalar_hub', widget.lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isPhone ? 11 : 13,
                              color: surfaces.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const AdminLocaleToggle(),
                        const SizedBox(width: 4),
                        const AdminThemeToggle(),
                        IconButton(
                          visualDensity: isPhone
                              ? VisualDensity.compact
                              : VisualDensity.standard,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: isTightPhone ? 36 : 40,
                            minHeight: 40,
                          ),
                          tooltip: AppStrings.tr('refresh', widget.lang),
                          onPressed: _refreshing ? null : _refreshAllLiveData,
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  // Cap page width on 1920px+ monitors so tables/forms stay readable.
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AdminBreakpoints.contentMaxWidth,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildActiveScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemSpec {
  final IconData icon;
  final String label;

  _NavItemSpec(this.icon, this.label);
}
