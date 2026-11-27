import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../driver_api_service.dart';

class DriverSessionNotifier extends ChangeNotifier {
  bool _loggedIn = false;
  String _locale = 'ku';
  bool _isDark = false;
  String _driverPhone = '';
  bool _restoring = true;
  static const _localePrefKey = 'rega_delivery_lang';
  static const _darkPrefKey = 'rega_delivery_dark_mode';
  static const _phonePrefKey = 'rega_delivery_phone';
  static const _loggedInPrefKey = 'rega_delivery_logged_in';

  bool get isLoggedIn => _loggedIn;
  bool get isRestoring => _restoring;
  String get locale => _locale;
  bool get isDark => _isDark;
  String get driverPhone => _driverPhone;
  TextDirection get textDirection =>
      _locale == 'en' ? TextDirection.ltr : TextDirection.rtl;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadSavedPrefs() async {
    _restoring = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_localePrefKey);
      if (saved != null && saved.isNotEmpty) {
        final code = saved == 'ckb' ? 'ku' : saved;
        if (code == 'ku' || code == 'ar' || code == 'en') {
          _locale = code;
        }
      }
      _isDark = prefs.getBool(_darkPrefKey) ?? false;
      _driverPhone = prefs.getString(_phonePrefKey) ?? '';

      await DriverApiService.instance.initToken();
      // Sanctum token alone restores the session (first install has neither).
      if (DriverApiService.instance.hasToken) {
        _loggedIn = true;
        await prefs.setBool(_loggedInPrefKey, true);
      } else {
        _loggedIn = false;
        await prefs.setBool(_loggedInPrefKey, false);
      }
    } catch (_) {
      _loggedIn = false;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> loadSavedLocale() => loadSavedPrefs();

  /// Alias used by splash / router coordination.
  Future<void> restoreSession() => loadSavedPrefs();

  Future<void> setLocale(String lang) async {
    final code = lang == 'ckb' ? 'ku' : lang;
    if (_locale == code) return;
    _locale = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localePrefKey, code);
    } catch (_) {}
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkPrefKey, value);
    } catch (_) {}
  }

  void toggleDark() => setDark(!_isDark);

  Future<void> login({String? phone}) async {
    _loggedIn = true;
    if (phone != null && phone.isNotEmpty) _driverPhone = phone;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInPrefKey, true);
      if (_driverPhone.isNotEmpty) {
        await prefs.setString(_phonePrefKey, _driverPhone);
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    _loggedIn = false;
    notifyListeners();
    try {
      await DriverApiService.instance.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInPrefKey, false);
    } catch (_) {}
  }

  /// Local session clear after 401 (token already wiped by DriverApiService).
  Future<void> markSessionExpired() async {
    if (!_loggedIn && !DriverApiService.instance.hasToken) {
      notifyListeners();
      return;
    }
    _loggedIn = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInPrefKey, false);
    } catch (_) {}
  }
}
