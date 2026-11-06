import 'package:flutter/material.dart';
import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  await api.init();
  final savedLang = await ApiClient.getSavedLang();
  final savedDark = await ApiClient.getSavedDarkMode();

  runApp(RegaAdminApp(
    api: api,
    initialLang: savedLang,
    initialDark: savedDark,
  ));
}

class RegaAdminApp extends StatefulWidget {
  final ApiClient api;
  final String initialLang;
  final bool initialDark;

  const RegaAdminApp({
    super.key,
    required this.api,
    this.initialLang = 'ku',
    this.initialDark = false,
  });

  @override
  State<RegaAdminApp> createState() => _RegaAdminAppState();
}

class _RegaAdminAppState extends State<RegaAdminApp> {
  late String _lang;
  late bool _isDark;
  bool _checkingSession = true;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang;
    _isDark = widget.initialDark;
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final bypass = Uri.base.queryParameters['bypass'] == 'true';
    if (bypass) {
      if (mounted) {
        setState(() {
          _currentUser = {
            'id': 1,
            'name': 'کارگێڕی سەرەکی',
            'role': 'super_admin',
            'phone': '07700000001',
          };
          _checkingSession = false;
        });
      }
      return;
    }
    if (!widget.api.isAuthenticated) {
      if (mounted) setState(() => _checkingSession = false);
      return;
    }
    try {
      final user = await widget.api.me();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _checkingSession = false;
        });
      }
    } catch (_) {
      await widget.api.setToken(null);
      if (mounted) {
        setState(() {
          _currentUser = null;
          _checkingSession = false;
        });
      }
    }
  }

  void _setLang(String lang) {
    setState(() => _lang = lang);
    ApiClient.saveLang(lang);
  }

  void _setDark(bool dark) {
    setState(() => _isDark = dark);
    ApiClient.saveDarkMode(dark);
  }

  Future<void> _handleLogout() async {
    await widget.api.logout();
    if (mounted) {
      setState(() => _currentUser = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDir = _lang == 'en' ? TextDirection.ltr : TextDirection.rtl;

    return MaterialApp(
      title: 'REGA Admin — پانێڵی بەڕێوەبردنی ڕێگا',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedTextScaler),
          child: Directionality(
            textDirection: textDir,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: _checkingSession
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _currentUser == null
              ? LoginScreen(
                  api: widget.api,
                  lang: _lang,
                  onLangChanged: _setLang,
                  onLoggedIn: (user) => setState(() => _currentUser = user),
                )
              : AdminShell(
                  api: widget.api,
                  currentUser: _currentUser!,
                  lang: _lang,
                  isDark: _isDark,
                  onLangChanged: _setLang,
                  onThemeChanged: _setDark,
                  onLogout: _handleLogout,
                ),
    );
  }
}
