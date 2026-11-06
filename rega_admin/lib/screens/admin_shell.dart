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
  int _selectedIndex = 0; // سەرەکی (Executive Dashboard) selected by default to match screenshot
  int _pendingOrdersBadge = 0;
  int _onlineStoresBadge = 0;
  int _customersBadge = 0;
  int _onlineDriversBadge = 0;
  int _openTicketsBadge = 0;

  @override
  void initState() {
    super.initState();
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final surfaceColor = widget.isDark ? RegaColors.darkSurface : Colors.white;
    final hideTopOperationalBar = isDesktop && (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 3 || _selectedIndex == 4);

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
                    padding: const EdgeInsets.symmetric(horizontal: 18),
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
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                        // Language switcher
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'ku', label: Text('کوردی', style: TextStyle(fontSize: 11.5))),
                            ButtonSegment(value: 'ar', label: Text('عربي', style: TextStyle(fontSize: 11.5))),
                            ButtonSegment(value: 'en', label: Text('EN', style: TextStyle(fontSize: 11.5))),
                          ],
                          selected: {widget.lang},
                          onSelectionChanged: (v) => widget.onLangChanged(v.first),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'گۆڕینی دۆخی تاریک / ڕووناک',
                          onPressed: () => widget.onThemeChanged(!widget.isDark),
                          icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                        ),
                        IconButton(
                          tooltip: AppStrings.tr('refresh', widget.lang),
                          onPressed: () {
                            _refreshBadges();
                            setState(() {});
                          },
                          icon: const Icon(Icons.sync_rounded),
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
