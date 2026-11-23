import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/admin_shell.dart';
import '../screens/login_screen.dart';
import '../state/admin_app_notifier.dart';

GoRouter createAdminRouter({required Listenable refreshListenable}) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final app = context.read<AdminAppNotifier>();
      final onLogin = state.uri.path == '/login';

      if (app.checkingSession) return null;

      if (!app.isLoggedIn && !onLogin) return '/login';
      if (app.isLoggedIn && onLogin) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
        return AdminNavNotifier.pathForIndex(tab ?? 0);
      }

      final tabQ = state.uri.queryParameters['tab'];
      if (tabQ != null && app.isLoggedIn) {
        final idx = int.tryParse(tabQ);
        if (idx != null) {
          final target = AdminNavNotifier.pathForIndex(idx);
          if (state.uri.path != target) return target;
        }
      }

      if (state.uri.path == '/' || state.uri.path.isEmpty) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          final app = context.watch<AdminAppNotifier>();
          return LoginScreen(
            api: app.api,
            lang: app.lang,
            onLangChanged: app.setLang,
            onLoggedIn: (user) {
              app.setUser(user);
              context.go('/dashboard');
            },
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final app = context.watch<AdminAppNotifier>();
          final idx = AdminNavNotifier.indexForPath(state.uri.path);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<AdminNavNotifier>().setTabIndex(idx);
          });
          if (app.checkingSession) {
            // No splash: blank while session restores.
            return const Scaffold(body: SizedBox.shrink());
          }
          if (app.currentUser == null) {
            return const SizedBox.shrink();
          }
          return AdminShell(
            api: app.api,
            currentUser: app.currentUser!,
            lang: app.lang,
            isDark: app.isDark,
            onLangChanged: app.setLang,
            onThemeChanged: app.setDark,
            onLogout: () async {
              await app.logout();
              if (context.mounted) context.go('/login');
            },
            initialIndex: idx,
            onTabChanged: (i) {
              context.read<AdminNavNotifier>().setTabIndex(i);
              context.go(AdminNavNotifier.pathForIndex(i));
            },
          );
        },
        routes: [
          GoRoute(path: '/dashboard', name: 'dashboard', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/order-intake', name: 'order-intake', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/orders', name: 'orders', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/drivers', name: 'drivers', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/customers', name: 'customers', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/service-cities', name: 'service-cities', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/stores', name: 'stores', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/vendor-items', name: 'vendor-items', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/finance', name: 'finance', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/staff', name: 'staff', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/support', name: 'support', builder: (_, __) => const SizedBox.shrink()),
        ],
      ),
    ],
  );
}
