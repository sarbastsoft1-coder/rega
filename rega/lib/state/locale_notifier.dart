import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/customer_l10n.dart';

class LocaleNotifier extends ChangeNotifier {
  String _langCode = 'ku';

  String get langCode => _langCode;
  String get displayName => CustomerL10n.displayName(_langCode);
  TextDirection get textDirection => CustomerL10n.directionFor(_langCode);

  Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('rega_saved_language_code');
      if (saved != null && saved.isNotEmpty) {
        _langCode = CustomerL10n.normalizeLang(saved);
        notifyListeners();
      }
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
}
