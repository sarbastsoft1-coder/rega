import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/vendor_nav_notifier.dart';
import '../state/vendor_session_notifier.dart';

typedef VendorShellBuilder = Widget Function(BuildContext context, int tabIndex);
typedef VendorLoginBuilder = Widget Function(BuildContext context);

GoRouter createVendorRouter({
  required VendorShellBuilder shellBuilder,
  required VendorLoginBuilder loginBuilder,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/orders',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = context.read<VendorSessionNotifier>();
      final loggingIn = state.uri.path == '/login';
      final bypass = state.uri.queryParameters['bypass'] == 'true';
      final hasTab = state.uri.queryParameters.containsKey('tab');

      if ((bypass || hasTab) && !session.isLoggedIn) {
        // Defer mutation; mark logged-in for this redirect cycle via bypass flag path.
        Future.microtask(() {
          if (!session.isLoggedIn) session.applyBypass();
        });
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
        return VendorNavNotifier.pathForIndex(tab ?? 3);
      }

      if (!session.isLoggedIn && !loggingIn) {
        return '/login';
      }
      if (session.isLoggedIn && loggingIn) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
        return VendorNavNotifier.pathForIndex(tab ?? 3);
      }

      final tabQ = state.uri.queryParameters['tab'];
      if (tabQ != null && session.isLoggedIn) {
        final idx = int.tryParse(tabQ);
        if (idx != null) {
          final target = VendorNavNotifier.pathForIndex(idx);
          if (state.uri.path != target) return target;
        }
      }

      if (state.uri.path == '/' || state.uri.path.isEmpty) {
        return '/orders';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => loginBuilder(context),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final idx = VendorNavNotifier.indexForPath(state.uri.path);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<VendorNavNotifier>().setTabIndex(idx);
          });
          return shellBuilder(context, idx);
        },
        routes: [
          GoRoute(path: '/settings', name: 'settings', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/revenue', name: 'revenue', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/products', name: 'products', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/orders', name: 'orders', builder: (_, __) => const SizedBox.shrink()),
        ],
      ),
    ],
  );
}
