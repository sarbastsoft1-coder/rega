import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/customer_l10n.dart';

class LocaleNotifier extends ChangeNotifier {
  String _langCode = 'ku';
  bool _isDark = false;

  String get langCode => _langCode;
  bool get isDark => _isDark;
  String get displayName => CustomerL10n.displayName(_langCode);
  TextDirection get textDirection => CustomerL10n.directionFor(_langCode);
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('rega_saved_language_code');
      if (saved != null && saved.isNotEmpty) {
        _langCode = CustomerL10n.normalizeLang(saved);
      }
      _isDark = prefs.getBool('rega_saved_dark_mode') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLanguage(String lang) async {
    final code = CustomerL10n.normalizeLang(lang);
    if (code == _langCode) return;
    _langCode = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rega_saved_language_code', code);
      await prefs.setString('rega_saved_language_name', CustomerL10n.displayName(code));
    } catch (_) {}
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rega_saved_dark_mode', value);
    } catch (_) {}
  }
}
