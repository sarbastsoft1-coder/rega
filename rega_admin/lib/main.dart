import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app/app_router.dart';
import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'state/admin_app_notifier.dart';

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: nav),
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

    return MaterialApp.router(
      title: 'REGA Admin — پانێڵی بەڕێوەبردنی ڕێگا',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: app.isDark ? ThemeMode.dark : ThemeMode.light,
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
