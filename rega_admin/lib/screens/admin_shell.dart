import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'catalog_zones_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'drivers_screen.dart';
import 'finance_screen.dart';
import 'marketing_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
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
  int _selectedIndex = 0;
  int _pendingOrdersBadge = 0;
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
          _openTicketsBadge = (kpis['open_tickets_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  List<_NavItemSpec> _buildNavItems() => [
        _NavItemSpec(Icons.dashboard_rounded, AppStrings.tr('nav_dashboard', widget.lang)),
        _NavItemSpec(Icons.receipt_long_rounded, AppStrings.tr('nav_orders', widget.lang), badge: _pendingOrdersBadge),
        _NavItemSpec(Icons.storefront_rounded, AppStrings.tr('nav_stores', widget.lang)),
        _NavItemSpec(Icons.fastfood_rounded, AppStrings.tr('nav_products', widget.lang)),
        _NavItemSpec(Icons.two_wheeler_rounded, AppStrings.tr('nav_drivers', widget.lang)),
        _NavItemSpec(Icons.groups_rounded, AppStrings.tr('nav_customers', widget.lang)),
        _NavItemSpec(Icons.map_rounded, AppStrings.tr('nav_zones', widget.lang)),
        _NavItemSpec(Icons.campaign_rounded, AppStrings.tr('nav_marketing', widget.lang)),
        _NavItemSpec(Icons.account_balance_wallet_rounded, AppStrings.tr('nav_finance', widget.lang)),
        _NavItemSpec(Icons.support_agent_rounded, AppStrings.tr('nav_support', widget.lang), badge: _openTicketsBadge),
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
        return StoresScreen(api: widget.api, lang: widget.lang);
      case 3:
        return ProductsScreen(api: widget.api, lang: widget.lang);
      case 4:
        return DriversScreen(api: widget.api, lang: widget.lang);
      case 5:
        return CustomersScreen(api: widget.api, lang: widget.lang);
      case 6:
        return CatalogZonesScreen(api: widget.api, lang: widget.lang);
      case 7:
        return MarketingScreen(api: widget.api, lang: widget.lang);
      case 8:
        return FinanceScreen(api: widget.api, lang: widget.lang);
      case 9:
        return SupportSettingsScreen(
          api: widget.api,
          lang: widget.lang,
          onChanged: _refreshBadges,
        );
      default:
        return DashboardScreen(
          api: widget.api,
          lang: widget.lang,
          onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
        );
    }
  }

  Widget _buildSidebar({required bool isDrawer}) {
    final items = _buildNavItems();
    return Container(
      width: 268,
      color: RegaColors.sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            // Brand Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      'assets/logo2.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (_, _, _) => const Icon(Icons.bolt_rounded, color: RegaColors.gold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REGA ADMIN',
                          style: TextStyle(
                            color: RegaColors.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'PostgreSQL • Kalar',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                itemCount: items.length,
                itemBuilder: (ctx, idx) {
                  final item = items[idx];
                  final active = _selectedIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: active ? RegaColors.gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() => _selectedIndex = idx);
                          if (isDrawer) Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: active ? const Color(0xFF0F172A) : Colors.white70,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                                    color: active ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                ),
                              ),
                              if (item.badge != null && item.badge! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: active ? const Color(0xFF0F172A) : RegaColors.crimson,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${item.badge}',
                                    style: TextStyle(
                                      color: active ? RegaColors.gold : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RegaColors.sidebarCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: RegaColors.gold,
                      child: Icon(Icons.shield_rounded, size: 18, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentUser['name']?.toString() ?? 'Admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                          ),
                          Text(
                            widget.currentUser['role']?.toString() ?? 'super_admin',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.tr('logout', widget.lang),
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout_rounded, color: RegaColors.crimson, size: 20),
                    ),
                  ],
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
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final surfaceColor = widget.isDark ? RegaColors.darkSurface : Colors.white;

    return Scaffold(
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(isDrawer: true)),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(isDrawer: false),
          Expanded(
            child: Column(
              children: [
                // Top Operational Bar
                Container(
                  height: 66,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
                      const SizedBox(width: 10),
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
  final int? badge;

  _NavItemSpec(this.icon, this.label, {this.badge});
}

