import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../driver_api_service.dart';
import '../state/driver_nav_notifier.dart';
import '../state/driver_session_notifier.dart';

MultiProvider buildDriverProviders({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) {
        final session = DriverSessionNotifier();
        DriverApiService.instance.onUnauthorized = () {
          session.markSessionExpired();
        };
        session.loadSavedPrefs();
        return session;
      }),
      ChangeNotifierProvider(create: (_) => DriverNavNotifier()),
    ],
    child: child,
  );
}
