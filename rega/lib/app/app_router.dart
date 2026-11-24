import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../live_order_tracker.dart';
import '../models/customer_models.dart';
import '../onboarding/onboarding_notifier.dart';
import '../onboarding/splash_onboarding.dart';
import '../state/navigation_notifier.dart';
import '../state/orders_notifier.dart';
import '../state/session_notifier.dart';
import '../screens/kalar_map_screen.dart';

import '../rega_i18n.dart';
typedef CustomerShellBuilder = Widget Function(
  BuildContext context,
  int tabIndex,
  String? openStoreId,
);

typedef CustomerLoginBuilder = Widget Function(BuildContext context);

final GlobalKey<NavigatorState> customerRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'customerRoot');

GoRouter createCustomerRouter({
  required CustomerShellBuilder shellBuilder,
  required CustomerLoginBuilder loginBuilder,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    navigatorKey: customerRootNavigatorKey,
    initialLocation: '/onboarding',
    refreshListenable: refreshListenable,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final session = context.read<SessionNotifier>();
      final onboarding = context.read<OnboardingNotifier>();
      final path = state.uri.path;
      final onLogin = path == '/login';
      final onOnboarding = path == '/onboarding';

      if (!onboarding.ready || session.isRestoring) return null;

      // First launch: splash → language → location before login/home.
      if (!onboarding.done && !onOnboarding) return '/onboarding';
      if (onboarding.done && onOnboarding) {
        return session.isLoggedIn ? '/home' : '/login';
      }

      if (!session.isLoggedIn && !onLogin && !onOnboarding) return '/login';
      if (session.isLoggedIn && onLogin) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
        return NavigationNotifier.pathForIndex(tab ?? 0);
      }

      final tab = state.uri.queryParameters['tab'];
      if (tab != null && session.isLoggedIn) {
        final idx = int.tryParse(tab);
        if (idx != null && idx >= 0 && idx <= 4) {
          final target = NavigationNotifier.pathForIndex(idx);
          if (path != target) return target;
        }
      }
      if (path == '/' || path.isEmpty) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const SplashOnboardingFlow(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => loginBuilder(context),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final path = state.uri.path;
          final storeMatch = RegExp(r'^/store/([^/]+)').firstMatch(path);
          final openStoreId = storeMatch?.group(1);
          final tabIndex = openStoreId != null
              ? 0
              : NavigationNotifier.indexForPath(path);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<NavigationNotifier>().setTabIndex(tabIndex);
          });
          return shellBuilder(context, tabIndex, openStoreId);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/offers',
            name: 'offers',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/cart',
            name: 'cart',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/orders',
            name: 'orders',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/store/:id',
            name: 'store',
            builder: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      GoRoute(
        path: '/track/:orderId',
        name: 'track',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          final extra = state.extra;
          OrderItem? order;
          if (extra is OrderItem) {
            order = extra;
          } else {
            try {
              order = context.read<OrdersNotifier>().orders.firstWhere((o) => o.id == orderId);
            } catch (_) {
              order = null;
            }
          }
          if (order == null) {
            return Scaffold(
              appBar: AppBar(title: Text(tx('REGA'))),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tx('داواکاری نەدۆزرایەوە')),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.go('/orders'),
                      child: Text(tx('گەڕانەوە بۆ داواکارییەکان')),
                    ),
                  ],
                ),
              ),
            );
          }
          final o = order;
          return CustomerLiveOrderTrackerScreen(
            orderCode: o.id,
            storeName: o.storeName,
            customerAddress: o.address,
            driverName: o.driverName,
            driverPhone: o.driverPhone,
            deliveryPin: o.deliveryPin,
            totalAmount: o.totalAmount,
            initialStatus: o.status,
            storeLocation: LatLng(o.storeLat, o.storeLng),
            customerLocation: LatLng(o.customerLat, o.customerLng),
            storeCoverUrl: o.storeCoverUrl,
            onOrderStatusChanged: (nextStatus) {
              o.status = nextStatus;
              context.read<OrdersNotifier>().notify();
            },
          );
        },
      ),
      GoRoute(
        path: '/map',
        name: 'map',
        builder: (context, state) {
          final lang = state.uri.queryParameters['lang'] ?? 'Kurdish';
          return KalarMapScreen(
            language: lang,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          );
        },
      ),
    ],
  );
}
