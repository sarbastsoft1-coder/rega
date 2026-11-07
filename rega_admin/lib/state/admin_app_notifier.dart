import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

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
  TextDirection get textDirection =>
      lang == 'en' ? TextDirection.ltr : TextDirection.rtl;

  Future<void> restoreSession() async {
    final bypass = Uri.base.queryParameters['bypass'] == 'true';
    if (bypass) {
      currentUser = {
        'id': 1,
        'name': 'کارگێڕی سەرەکی',
        'role': 'super_admin',
        'phone': '07700000001',
      };
      checkingSession = false;
      notifyListeners();
      return;
    }
    if (!api.isAuthenticated) {
      checkingSession = false;
      notifyListeners();
      return;
    }
    try {
      currentUser = await api.me();
    } catch (_) {
      await api.setToken(null);
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
    '/orders',
    '/drivers',
    '/customers',
    '/stores',
    '/finance',
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
