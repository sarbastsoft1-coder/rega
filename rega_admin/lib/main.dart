import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app/app_router.dart';
import 'core/api/api_client.dart';
import 'core/localization/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'state/admin_app_notifier.dart';
import 'state/admin_domain_notifiers.dart';

import 'rega_i18n.dart';
import 'rega_colors.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  await api.init();
  final savedLang = await ApiClient.getSavedLang();
  final savedDark = await ApiClient.getSavedDarkMode();

  final appState = AdminAppNotifier(
    api: api,
    lang: savedLang,
    isDark: savedDark,
  );
  final nav = AdminNavNotifier();
  final dashboard = DashboardNotifier(api);
  final inbox = AdminInboxNotifier(api);
  final orders = OrdersNotifier(api);
  final drivers = DriversNotifier(api);
  final customers = CustomersNotifier(api);
  final stores = StoresNotifier(api);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: nav),
        ChangeNotifierProvider.value(value: dashboard),
        ChangeNotifierProvider.value(value: inbox),
        ChangeNotifierProvider.value(value: orders),
        ChangeNotifierProvider.value(value: drivers),
        ChangeNotifierProvider.value(value: customers),
        ChangeNotifierProvider.value(value: stores),
      ],
      child: RegaAdminApp(appState: appState),
    ),
  );
}

class RegaAdminApp extends StatefulWidget {
  final AdminAppNotifier appState;

  const RegaAdminApp({super.key, required this.appState});

  @override
  State<RegaAdminApp> createState() => _RegaAdminAppState();
}

class _RegaAdminAppState extends State<RegaAdminApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAdminRouter(refreshListenable: widget.appState);
    widget.appState.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AdminAppNotifier>();
    // Drives tx(): every on-screen string follows the selected language.
    RegaI18n.setLang(app.lang);
    RC.setDark(app.themeMode == ThemeMode.dark);

    return MaterialApp.router(
      title: AppStrings.tr('app_title', app.lang),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: app.themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedTextScaler),
          child: Directionality(
            textDirection: app.textDirection,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
