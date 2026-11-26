import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rega_admin/core/api/api_client.dart';
import 'package:rega_admin/main.dart';
import 'package:rega_admin/state/admin_app_notifier.dart';
import 'package:rega_admin/state/admin_domain_notifiers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('REGA Admin renders login console cleanly on compact and wide viewports', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient();
    await api.init();
    final appState = AdminAppNotifier(api: api, lang: 'ku', isDark: false, checkingSession: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider(create: (_) => AdminNavNotifier()),
          ChangeNotifierProvider(create: (_) => DashboardNotifier(api)),
          ChangeNotifierProvider(create: (_) => AdminInboxNotifier(api)),
          ChangeNotifierProvider(create: (_) => OrdersNotifier(api)),
          ChangeNotifierProvider(create: (_) => DriversNotifier(api)),
          ChangeNotifierProvider(create: (_) => CustomersNotifier(api)),
          ChangeNotifierProvider(create: (_) => StoresNotifier(api)),
        ],
        child: RegaAdminApp(appState: appState),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('پانێڵی بەڕێوەبردنی ڕێگا'), findsOneWidget);
    expect(find.text('چوونە ژوورەوە بۆ پانێڵ'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('REGA Admin Control'), findsOneWidget);
    expect(find.text('Sign In to Console'), findsOneWidget);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpAndSettle();
    expect(find.text('REGA'), findsWidgets);
  });
}
