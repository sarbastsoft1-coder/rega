import 'package:flutter/material.dart';
import '../core/api/api_client.dart'; // ApiClient + ApiException

class AdminAppNotifier extends ChangeNotifier {
  final ApiClient api;
  String lang;
  bool isDark;
  bool checkingSession;
  Map<String, dynamic>? currentUser;

  AdminAppNotifier({
    required this.api,
    this.lang = 'ku',
    this.isDark = false,
    this.checkingSession = true,
    this.currentUser,
  });

  bool get isLoggedIn => currentUser != null;
  ThemeMode get themeMode => isDark ? ThemeMode.dark : ThemeMode.light;
  TextDirection get textDirection =>
      lang == 'en' ? TextDirection.ltr : TextDirection.rtl;

  Future<void> restoreSession() async {
    // Prefer persisted Sanctum token → /auth/me. Only clear token on auth failure.
    if (api.isAuthenticated) {
      try {
        currentUser = await api.me();
        checkingSession = false;
        notifyListeners();
        return;
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          await api.setToken(null);
          currentUser = null;
        } else {
          // Network / server error: keep token so a refresh can restore without re-login.
          currentUser = null;
        }
      } catch (_) {
        // Keep token on unexpected errors (e.g. offline).
        currentUser = null;
      }
    } else {
      currentUser = null;
    }

    checkingSession = false;
    notifyListeners();
  }

  void setLang(String value) {
    if (lang == value) return;
    lang = value;
    ApiClient.saveLang(value);
    notifyListeners();
  }

  void setDark(bool value) {
    if (isDark == value) return;
    isDark = value;
    ApiClient.saveDarkMode(value);
    notifyListeners();
  }

  void setUser(Map<String, dynamic>? user) {
    currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    currentUser = null;
    notifyListeners();
  }
}

class AdminNavNotifier extends ChangeNotifier {
  static const tabPaths = <String>[
    '/dashboard',
    '/order-intake',
    '/orders',
    '/drivers',
    '/customers',
    '/stores',
    '/vendor-items',
    '/finance',
    '/staff',
    '/support',
  ];

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;

  static int indexForPath(String path) {
    final i = tabPaths.indexWhere((p) => path == p || path.startsWith('$p/'));
    return i < 0 ? 0 : i;
  }

  static String pathForIndex(int index) {
    if (index < 0 || index >= tabPaths.length) return tabPaths.first;
    return tabPaths[index];
  }

  void setTabIndex(int index) {
    final next = index.clamp(0, tabPaths.length - 1);
    if (_tabIndex == next) return;
    _tabIndex = next;
    notifyListeners();
  }
}
