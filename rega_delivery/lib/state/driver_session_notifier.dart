import 'package:flutter/material.dart';

class DriverSessionNotifier extends ChangeNotifier {
  bool _loggedIn = true; // default true for existing QA shortcut
  String _locale = 'ku';
  String _driverPhone = '07501234567';

  bool get isLoggedIn => _loggedIn;
  String get locale => _locale;
  String get driverPhone => _driverPhone;
  TextDirection get textDirection =>
      _locale == 'en' ? TextDirection.ltr : TextDirection.rtl;

  void setLocale(String lang) {
    if (_locale == lang) return;
    _locale = lang;
    notifyListeners();
  }

  void login({String? phone}) {
    _loggedIn = true;
    if (phone != null && phone.isNotEmpty) _driverPhone = phone;
    notifyListeners();
  }

  void logout() {
    _loggedIn = false;
    notifyListeners();
  }
}
