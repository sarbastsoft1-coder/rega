import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../state/cart_notifier.dart';
import '../state/locale_notifier.dart';
import '../state/location_notifier.dart';
import '../state/navigation_notifier.dart';
import '../state/orders_notifier.dart';
import '../state/session_notifier.dart';

MultiProvider buildCustomerProviders({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleNotifier()..loadSaved()),
      ChangeNotifierProvider(create: (_) {
        final session = SessionNotifier();
        session.restoreSession();
        return session;
      }),
      ChangeNotifierProvider(create: (_) => CartNotifier()),
      ChangeNotifierProvider(create: (_) => LocationNotifier()..loadPersisted()),
      ChangeNotifierProvider(create: (_) => OrdersNotifier()),
      ChangeNotifierProvider(create: (_) => NavigationNotifier()),
    ],
    child: child,
  );
}
