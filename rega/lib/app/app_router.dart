import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../live_order_tracker.dart';
import '../models/customer_models.dart';
import '../state/navigation_notifier.dart';
import '../state/orders_notifier.dart';

typedef CustomerShellBuilder = Widget Function(
  BuildContext context,
  int tabIndex,
  String? openStoreId,
);

final GlobalKey<NavigatorState> customerRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'customerRoot');

GoRouter createCustomerRouter({
  required CustomerShellBuilder shellBuilder,
}) {
  return GoRouter(
    navigatorKey: customerRootNavigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final tab = state.uri.queryParameters['tab'];
      if (tab != null) {
        final idx = int.tryParse(tab);
        if (idx != null && idx >= 0 && idx <= 4) {
          final target = NavigationNotifier.pathForIndex(idx);
          if (state.uri.path != target) return target;
        }
      }
      if (state.uri.path == '/' || state.uri.path.isEmpty) return '/home';
      return null;
    },
    routes: [
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
          // Shell keeps this element alive across tab path changes.
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
              appBar: AppBar(title: const Text('REGA')),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('داواکاری نەدۆزرایەوە'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.go('/orders'),
                      child: const Text('گەڕانەوە بۆ داواکارییەکان'),
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
            onOrderStatusChanged: (nextStatus) {
              o.status = nextStatus;
              context.read<OrdersNotifier>().notify();
            },
          );
        },
      ),
    ],
  );
}
