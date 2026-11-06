import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'drivers_screen.dart';
import 'finance_screen.dart';
import 'orders_screen.dart';
import 'stores_screen.dart';
import 'support_settings_screen.dart';

class AdminShell extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic> currentUser;
  final String lang;
  final bool isDark;
  final ValueChanged<String> onLangChanged;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLogout;

  const AdminShell({
    super.key,
    required this.api,
    required this.currentUser,
    required this.lang,
    required this.isDark,
    required this.onLangChanged,
    required this.onThemeChanged,
    required this.onLogout,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0; // سەرەکی (Executive Dashboard) selected by default
  int _pendingOrdersBadge = 0;
  int _onlineStoresBadge = 0;
  int _customersBadge = 0;
  int _onlineDriversBadge = 0;
  int _openTicketsBadge = 0;

  @override
  void initState() {
    super.initState();
    final tabParam = Uri.base.queryParameters['tab'];
    if (tabParam != null) {
      final idx = int.tryParse(tabParam);
      if (idx != null && idx >= 0 && idx <= 6) {
        _selectedIndex = idx;
      }
    }
    _refreshBadges();
  }

  Future<void> _refreshBadges() async {
    try {
      final dash = await widget.api.getDashboard(days: 7);
      final kpis = dash['kpis'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _pendingOrdersBadge = (kpis['active_orders_count'] as num?)?.toInt() ?? 0;
          _onlineStoresBadge = (kpis['online_stores'] as num?)?.toInt() ?? 0;
          _customersBadge = (kpis['total_customers'] as num?)?.toInt() ?? 0;
          _onlineDriversBadge = (kpis['online_drivers'] as num?)?.toInt() ?? 0;
          _openTicketsBadge = (kpis['open_tickets_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  List<_NavItemSpec> _buildNavItems() => [
        _NavItemSpec(Icons.home_outlined, AppStrings.tr('nav_dashboard', widget.lang)),
        _NavItemSpec(Icons.receipt_long_outlined, AppStrings.tr('nav_orders', widget.lang)),
        _NavItemSpec(Icons.two_wheeler_outlined, AppStrings.tr('nav_drivers', widget.lang)),
        _NavItemSpec(Icons.people_outline_rounded, AppStrings.tr('nav_customers', widget.lang)),
        _NavItemSpec(Icons.storefront_outlined, AppStrings.tr('nav_stores', widget.lang)),
        _NavItemSpec(Icons.insert_chart_outlined_rounded, AppStrings.tr('nav_finance', widget.lang)),
        _NavItemSpec(Icons.settings_outlined, AppStrings.tr('nav_support', widget.lang)),
      ];

  Widget _buildActiveScreen() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          api: widget.api,
          lang: widget.lang,
          onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
        );
      case 1:
        return OrdersScreen(
          api: widget.api,
          lang: widget.lang,
          onOrderChanged: _refreshBadges,
        );
      case 2:
        return DriversScreen(api: widget.api, lang: widget.lang);
      case 3:
        return CustomersScreen(api: widget.api, lang: widget.lang);
      case 4:
        return StoresScreen(api: widget.api, lang: widget.lang);
      case 5:
        return FinanceScreen(api: widget.api, lang: widget.lang);
      case 6:
        return SupportSettingsScreen(
          api: widget.api,
          lang: widget.lang,
          onChanged: _refreshBadges,
        );
      default:
        return CustomersScreen(api: widget.api, lang: widget.lang);
    }
  }

  Widget _buildSidebar({required bool isDrawer}) {
    final items = _buildNavItems();
    return Container(
      width: 225,
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
                            color: Color(0xFF113E2E),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'REGA',
                    style: TextStyle(
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: items.length,
                itemBuilder: (ctx, idx) {
                  final item = items[idx];
                  final active = _selectedIndex == idx;
                  final isOrdersActive = active && idx == 1;
                  final isCustomerActive = active && idx == 3;

                  Color itemBg = Colors.transparent;
                  if (active) {
                    itemBg = isOrdersActive
                        ? const Color(0xFFEA580C)
                        : RegaColors.forestGreenActive;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: itemBg,
                        borderRadius: BorderRadius.circular(10),
                        border: isCustomerActive
                            ? const Border(
                                right: BorderSide(
                                  color: Color(0xFFFF5722),
                                  width: 3.5,
                                ),
                              )
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() => _selectedIndex = idx);
                            if (isDrawer) Navigator.pop(ctx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 21,
                                  color: isCustomerActive ? const Color(0xFFFF5722) : Colors.white,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                      color: isCustomerActive ? const Color(0xFFFF5722) : Colors.white,
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Material(
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
                      children: const [
                        Icon(Icons.logout_rounded, size: 21, color: Colors.white70),
                        SizedBox(width: 14),
                        Text(
                          'چوونە دەرەوە',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final surfaceColor = widget.isDark ? RegaColors.darkSurface : Colors.white;
    final hideTopOperationalBar = isDesktop;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(isDrawer: true)),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(isDrawer: false),
          Expanded(
            child: Column(
              children: [
                if (!hideTopOperationalBar)
                  Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border(
                        bottom: BorderSide(
                          color: widget.isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!isDesktop)
                          Builder(
                            builder: (ctx) => IconButton(
                              icon: const Icon(Icons.menu_rounded),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            AppStrings.tr('kalar_hub', widget.lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        // Language switcher (Adaptive: SegmentedButton on tablet, Popup on mobile)
                        if (screenWidth >= 600)
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'ku', label: Text('کوردی', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'ar', label: Text('عربي', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'en', label: Text('EN', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {widget.lang},
                            onSelectionChanged: (v) => widget.onLangChanged(v.first),
                          )
                        else
                          PopupMenuButton<String>(
                            tooltip: 'زمان / Language',
                            initialValue: widget.lang,
                            onSelected: widget.onLangChanged,
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'ku', child: Text('کوردی')),
                              PopupMenuItem(value: 'ar', child: Text('عربي')),
                              PopupMenuItem(value: 'en', child: Text('English')),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: widget.isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language_rounded, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.lang.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'گۆڕینی دۆخی تاریک / ڕووناک',
                          onPressed: () => widget.onThemeChanged(!widget.isDark),
                          icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                        ),
                        IconButton(
                          tooltip: AppStrings.tr('refresh', widget.lang),
                          onPressed: () {
                            _refreshBadges();
                            setState(() {});
                          },
                          icon: const Icon(Icons.sync_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildActiveScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemSpec {
  final IconData icon;
  final String label;

  _NavItemSpec(this.icon, this.label);
}
