import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/driver_nav_notifier.dart';
import '../state/driver_session_notifier.dart';

typedef DriverShellBuilder = Widget Function(BuildContext context, int tabIndex);
typedef DriverAuthBuilder = Widget Function(BuildContext context);

GoRouter createDriverRouter({
  required DriverShellBuilder shellBuilder,
  required DriverAuthBuilder authBuilder,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = context.read<DriverSessionNotifier>();
      final path = state.uri.path;
      final onAuth = path == '/login';
      final forceLogout = state.uri.queryParameters['logout'] == 'true';

      if (session.isRestoring) return null;

      if (forceLogout && session.isLoggedIn) {
        // Clear token + logged_in so next open stays on login.
        session.logout();
        return '/login';
      }

      if (!session.isLoggedIn && !onAuth) return '/login';
      if (session.isLoggedIn && onAuth) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
        return DriverNavNotifier.pathForIndex(tab ?? 0);
      }

      final tabQ = state.uri.queryParameters['tab'];
      if (tabQ != null && session.isLoggedIn) {
        final idx = int.tryParse(tabQ);
        if (idx != null) {
          final target = DriverNavNotifier.pathForIndex(idx);
          if (path != target) return target;
        }
      }

      if (path == '/' || path.isEmpty) return '/map';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => authBuilder(context),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final idx = DriverNavNotifier.indexForPath(state.uri.path);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<DriverNavNotifier>().setTabIndex(idx);
          });
          return shellBuilder(context, idx);
        },
        routes: [
          GoRoute(path: '/map', name: 'map', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/jobs', name: 'jobs', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/earnings', name: 'earnings', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/profile', name: 'profile', builder: (_, __) => const SizedBox.shrink()),
        ],
      ),
    ],
  );
}
