import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../state/driver_nav_notifier.dart';
import '../state/driver_session_notifier.dart';

MultiProvider buildDriverProviders({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DriverSessionNotifier()),
      ChangeNotifierProvider(create: (_) => DriverNavNotifier()),
    ],
    child: child,
  );
}
