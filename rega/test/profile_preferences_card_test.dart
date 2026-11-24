import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rega_app/l10n/customer_l10n.dart';
import 'package:rega_app/widgets/profile_preferences_card.dart';

Widget _wrap({
  required Widget child,
  required String langCode,
  required bool isDark,
  double width = 390,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    home: Directionality(
      textDirection: CustomerL10n.directionFor(langCode),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Center(
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Kurdish RTL layout anchors title beside translate icon and expands cleanly',
    (tester) async {
      String selectedLang = 'کوردی';
      bool dark = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _wrap(
              langCode: CustomerL10n.normalizeLang(selectedLang),
              isDark: dark,
              child: ProfilePreferencesCard(
                currentLanguage: selectedLang,
                isDark: dark,
                onLanguageSelected: (lang) =>
                    setState(() => selectedLang = lang),
                onDarkModeChanged: (v) => setState(() => dark = v),
              ),
            );
          },
        ),
      );

      // Collapsed by default: tray is hidden, Appearance row is always visible.
      expect(
        find.byKey(const ValueKey('preferences_language_tray')),
        findsNothing,
      );
      expect(find.text('زمانەکان'), findsOneWidget);
      expect(find.text('ڕووکار'), findsOneWidget);
      expect(find.text('دۆخی ڕووناک'), findsOneWidget);

      // Verify RTL alignment: title is right next to the translate icon on the
      // right side, NOT pushed over to the left edge.
      final iconRect = tester.getRect(find.byIcon(Icons.translate_rounded));
      final titleRect = tester.getRect(find.text('زمانەکان'));
      expect(iconRect.center.dx, greaterThan(titleRect.center.dx));
      expect(iconRect.left - titleRect.right, lessThan(40));

      // Expand language picker tray.
      await tester.tap(
        find.byKey(const ValueKey('preferences_language_header')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('preferences_language_tray')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('preferences_lang_ku')), findsOneWidget);
      expect(find.byKey(const ValueKey('preferences_lang_ar')), findsOneWidget);
      expect(find.byKey(const ValueKey('preferences_lang_en')), findsOneWidget);

      // Select English -> updates language & switches to LTR copy.
      await tester.tap(find.byKey(const ValueKey('preferences_lang_en')));
      await tester.pumpAndSettle();

      expect(selectedLang, 'English');
      expect(find.text('Languages'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Light mode'), findsOneWidget);

      // Select Arabic -> updates to Arabic copy.
      await tester.tap(find.byKey(const ValueKey('preferences_lang_ar')));
      await tester.pumpAndSettle();

      expect(selectedLang, 'العربية');
      expect(find.text('اللغات'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
    },
  );

  testWidgets('Theme segmented toggle switches between Light and Dark mode', (
    tester,
  ) async {
    bool dark = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _wrap(
            langCode: 'ku',
            isDark: dark,
            child: ProfilePreferencesCard(
              currentLanguage: 'کوردی',
              isDark: dark,
              initiallyExpanded: true,
              onLanguageSelected: (_) {},
              onDarkModeChanged: (v) => setState(() => dark = v),
            ),
          );
        },
      ),
    );

    expect(find.text('دۆخی ڕووناک'), findsOneWidget);

    // Tap dark segment button.
    await tester.tap(find.byKey(const ValueKey('preferences_theme_dark')));
    await tester.pumpAndSettle();

    expect(dark, isTrue);
    expect(find.text('دۆخی تاریک'), findsOneWidget);

    // Tap light segment button.
    await tester.tap(find.byKey(const ValueKey('preferences_theme_light')));
    await tester.pumpAndSettle();

    expect(dark, isFalse);
    expect(find.text('دۆخی ڕووناک'), findsOneWidget);

    // Tapping the Appearance row itself toggles dark mode.
    await tester.tap(find.byKey(const ValueKey('preferences_theme_row')));
    await tester.pumpAndSettle();
    expect(dark, isTrue);
  });

  testWidgets('Renders without overflow on narrow 320px screen in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        langCode: 'en',
        isDark: true,
        width: 320,
        child: ProfilePreferencesCard(
          currentLanguage: 'English',
          isDark: true,
          initiallyExpanded: true,
          onLanguageSelected: (_) {},
          onDarkModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Languages'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
  });
}
