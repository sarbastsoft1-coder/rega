import 'package:flutter/material.dart';
import '../core/api/api_client.dart'; // ApiClient + ApiException
import '../rega_i18n.dart';

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
  }) {
    // Keep tx() in sync from the first frame (saved lang may be en/ar).
    RegaI18n.setLang(lang);
  }

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
    final next = RegaI18n.normalize(value);
    if (lang == next) {
      // Still push into RegaI18n in case it drifted from AppStrings lang.
      RegaI18n.setLang(next);
      return;
    }
    lang = next;
    RegaI18n.setLang(next);
    ApiClient.saveLang(next);
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
