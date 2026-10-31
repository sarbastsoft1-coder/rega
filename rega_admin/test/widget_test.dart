import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rega_admin/core/api/api_client.dart';
import 'package:rega_admin/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('REGA Admin renders login console cleanly on compact and wide viewports', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient();
    await api.init();

    // 1. Compact / tablet viewport (800x600) — default Kurdish Sorani (RTL)
    await tester.pumpWidget(RegaAdminApp(api: api));
    await tester.pumpAndSettle();

    expect(find.text('پانێڵی بەڕێوەبردنی ڕێگا'), findsOneWidget);
    expect(find.text('چوونە ژوورەوە بۆ پانێڵ'), findsOneWidget);

    // Switch language to English (LTR)
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('REGA Admin Control'), findsOneWidget);
    expect(find.text('Sign In to Console'), findsOneWidget);

    // 2. Wide desktop viewport (1440x900) — verifies hero branding panel
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpAndSettle();
    expect(find.text('REGA CENTRAL'), findsOneWidget);
  });
}
