import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/admin_app_notifier.dart';

/// Top header actions row containing:
/// 1. Interactive Search Bar (Global Spotlight Search)
/// 2. Admin Profile Dropdown (Profile, Language, Dark Mode, Logout)
/// 3. Notifications Bell (Live Alerts & Navigation)
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
    this.hintText = '...گەڕان لە ناو سیستەمدا',
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Search Bar
        AdminGlobalSearchBar(
          controller: searchCtrl,
          hintText: hintText,
          onChanged: onSearchChanged,
        ),
        const SizedBox(width: 14),

        // 2. Profile Dropdown Menu
        AdminProfileDropdown(
          onGoToSettings: onGoToSettings,
        ),
        const SizedBox(width: 12),

        // 3. Notifications Bell with Badge
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

// ============================================================================
// 1. GLOBAL SEARCH BAR & SPOTLIGHT MODAL
// ============================================================================
class AdminGlobalSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const AdminGlobalSearchBar({
    super.key,
    this.controller,
    this.hintText = '...گەڕان لە ناو سیستەمدا',
    this.onChanged,
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
    return Container(
      width: 250,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
      ]);

      final ordersRes = results[0] as Map<String, dynamic>? ?? {};
      final ordersList = ordersRes['data'] as List<dynamic>? ?? [];
      final storesList = results[1] as List<dynamic>? ?? [];
      final driversList = results[2] as List<dynamic>? ?? [];
      final customersList = results[3] as List<dynamic>? ?? [];

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
          'path': '/orders',
          'icon': Icons.receipt_long_rounded,
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
    final query = _queryCtrl.text.trim().toLowerCase();
    final results = query.isEmpty
        ? _allEntries
        : _allEntries.where((e) {
            final t = (e['title'] as String).toLowerCase();
            final s = (e['sub'] as String).toLowerCase();
            return t.contains(query) || s.contains(query);
          }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Container(
        width: 520,
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
                color: const Color(0xFFF8FAFC),
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
                      decoration: const InputDecoration(
                        hintText: 'گەڕان بە ناوی داواکاری، فرۆشگا، شۆفێر یان کڕیار...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
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
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Results List
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.search_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 8),
                          Text('هیچ ئەنجامێک نەدۆزرایەوە', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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

  const AdminProfileDropdown({
    super.key,
    this.onGoToSettings,
  });

  void _showProfileDialog(BuildContext context) {
    final app = context.read<AdminAppNotifier>();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Card Header
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
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
                      children: const [
                        Text(
                          'کارگێڕی سەرەکی',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'admin@rega.krd • سەرپەرشتیار',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'چالاک',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Action 1: Settings
              _buildMenuActionTile(
                icon: Icons.settings_outlined,
                title: 'ڕێکخستنە گشتییەکان',
                subtitle: 'بەڕێوەبردنی پلاتفۆرم و سیستەم',
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AdminNavNotifier>().setTabIndex(6);
                  context.go('/support');
                },
              ),

              // Action 2: Payments
              _buildMenuActionTile(
                icon: Icons.payments_outlined,
                title: 'ڕێکخستنەکانی پارەدان',
                subtitle: 'کۆمیسیۆن، کرێ و دەروازە داراییەکان',
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AdminNavNotifier>().setTabIndex(6);
                  context.go('/support');
                },
              ),

              // Action 3: Language
              _buildMenuActionTile(
                icon: Icons.language_rounded,
                title: 'گۆڕینی زمان',
                subtitle: app.lang == 'ku' ? 'کوردی (Kurdish)' : (app.lang == 'ar' ? 'العربية' : 'English'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLanguageDialog(context);
                },
              ),

              // Action 4: Dark Mode
              _buildMenuActionTile(
                icon: app.isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                title: app.isDark ? 'دۆخی ڕووناک (Light Mode)' : 'دۆخی تاریک (Dark Mode)',
                subtitle: 'گۆڕینی ڕووکاری پانێڵ',
                onTap: () {
                  app.setDark(!app.isDark);
                  Navigator.pop(ctx);
                },
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Action 5: Logout
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
                    children: const [
                      Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                      SizedBox(width: 12),
                      Text(
                        'چوونە دەرەوە لە هەژمار',
                        style: TextStyle(
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('هەڵبژاردنی زمان', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_rounded, color: Color(0xFFEA580C)),
              title: const Text('کوردی (سۆرانی)', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                app.setLang('ku');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: Color(0xFF64748B)),
              title: const Text('العربية', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                app.setLang('ar');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: Color(0xFF64748B)),
              title: const Text('English', style: TextStyle(fontWeight: FontWeight.w800)),
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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, color: const Color(0xFF334155), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showProfileDialog(context),
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFFEA580C).withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                    'کارگێڕی سەرەکی',
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
  int _unreadCount = 0;
  int _pendingOrders = 0;
  int _pendingStores = 0;
  int _pendingDrivers = 0;
  int _openTickets = 0;

  @override
  void initState() {
    super.initState();
    _loadLiveNotifications();
  }

  Future<void> _loadLiveNotifications() async {
    try {
      final api = context.read<AdminAppNotifier>().api;
      final dash = await api.getDashboard(days: 7);
      final kpis = dash['kpis'] as Map<String, dynamic>? ?? {};
      final po = (kpis['pending_orders_count'] as num?)?.toInt() ?? 0;
      final ps = (kpis['pending_stores'] as num?)?.toInt() ?? 0;
      final pd = (kpis['pending_kyc_drivers'] as num?)?.toInt() ?? 0;
      final ot = (kpis['open_tickets_count'] as num?)?.toInt() ?? 0;
      final total = po + ps + pd + ot;
      if (mounted) {
        setState(() {
          _pendingOrders = po;
          _pendingStores = ps;
          _pendingDrivers = pd;
          _openTickets = ot;
          _unreadCount = total;
        });
      }
    } catch (_) {}
  }

  void _showNotificationsModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 16,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
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
                          child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFEA580C), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ئاگادارکردنەوەکان',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              _unreadCount > 0 ? '$_unreadCount ئاگاداری نوێ لە چاوەڕوانیدایە' : 'هەموو ئاگادارییەکان خوێندراونەتەوە',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_unreadCount > 0)
                      TextButton(
                        onPressed: () {
                          setDialogState(() => _unreadCount = 0);
                          setState(() => _unreadCount = 0);
                        },
                        child: const Text(
                          'هەمووی بە خوێندراو دابنێ',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEA580C)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                if (_unreadCount == 0 && _pendingOrders == 0 && _pendingStores == 0 && _pendingDrivers == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'هیچ ئاگادارییەکی لە چاوەڕوانیدا نییە',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else ...[
                  // Notification Item 1: Pending Orders
                  _buildNotificationItem(
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFFEA580C),
                    title: 'داواکاری لە چاوەڕوانیدایە',
                    subtitle: _pendingOrders > 0 ? '$_pendingOrders داواکاری نوێ چاوەڕوانی وەڵامە' : 'داواکارییەکان لە کاتی خۆیاندا بەڕێوەدەچن',
                    time: 'ڕاستەوخۆ لە داتابەیس',
                    isUnread: _unreadCount > 0 && _pendingOrders > 0,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (widget.onGoToOrders != null) {
                        widget.onGoToOrders!();
                      } else {
                        context.read<AdminNavNotifier>().setTabIndex(1);
                        context.go('/orders');
                      }
                    },
                  ),
                  const Divider(height: 8, color: Color(0xFFF1F5F9)),

                  // Notification Item 2: Pending Stores
                  _buildNotificationItem(
                    icon: Icons.storefront_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'فرۆشیاری نوێ لە چاوەڕوانیدایە',
                    subtitle: _pendingStores > 0 ? '$_pendingStores فرۆشگا چاوەڕوانی پەسەندکردنی کارگێڕییە' : 'هەموو فرۆشگاکان چالاککراون',
                    time: 'ڕاستەوخۆ لە داتابەیس',
                    isUnread: _unreadCount > 0 && _pendingStores > 0,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (widget.onGoToStores != null) {
                        widget.onGoToStores!();
                      } else {
                        context.read<AdminNavNotifier>().setTabIndex(4);
                        context.go('/stores');
                      }
                    },
                  ),
                  const Divider(height: 8, color: Color(0xFFF1F5F9)),

                  // Notification Item 3: Pending KYC Drivers
                  _buildNotificationItem(
                    icon: Icons.two_wheeler_rounded,
                    iconColor: const Color(0xFF16A34A),
                    title: 'ماتۆرسوار لە چاوەڕوانیدایە',
                    subtitle: _pendingDrivers > 0 ? '$_pendingDrivers ماتۆرسوار چاوەڕوانی پەسەندکردنی بەڵگەنامەن' : 'هەموو ماتۆرسوارەکان پشتڕاستکراونەتەوە',
                    time: 'ڕاستەوخۆ لە داتابەیس',
                    isUnread: _unreadCount > 0 && _pendingDrivers > 0,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (widget.onGoToDrivers != null) {
                        widget.onGoToDrivers!();
                      } else {
                        context.read<AdminNavNotifier>().setTabIndex(2);
                        context.go('/drivers');
                      }
                    },
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Footer Action
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    side: const BorderSide(color: Color(0xFFFFEDD5)),
                    backgroundColor: const Color(0xFFFFF7ED),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (widget.onGoToSettings != null) {
                      widget.onGoToSettings!();
                    } else {
                      context.read<AdminNavNotifier>().setTabIndex(6);
                      context.go('/support');
                    }
                  },
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text(
                    'ڕێکخستنەکانی ئاگادارکردنەوە',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                          color: const Color(0xFF0F172A),
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
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
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
              const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569), size: 24),
              if (_unreadCount > 0)
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
                        '$_unreadCount',
                        style: const TextStyle(
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
        ),
      ),
    );
  }
}
