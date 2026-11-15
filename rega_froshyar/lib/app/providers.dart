import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../state/vendor_nav_notifier.dart';
import '../state/vendor_session_notifier.dart';

MultiProvider buildVendorProviders({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) {
        final session = VendorSessionNotifier();
        session.restoreSession();
        return session;
      }),
      ChangeNotifierProvider(create: (_) => VendorNavNotifier()),
    ],
    child: child,
  );
}
