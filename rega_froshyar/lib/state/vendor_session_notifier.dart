import 'package:flutter/foundation.dart';

class VendorSessionNotifier extends ChangeNotifier {
  bool _loggedIn = false;
  String? _phone;
  String? _password;

  bool get isLoggedIn => _loggedIn;
  String? get phone => _phone;
  String? get password => _password;

  void login({String? phone, String? password}) {
    _loggedIn = true;
    _phone = phone;
    _password = password;
    notifyListeners();
  }

  void logout() {
    _loggedIn = false;
    _phone = null;
    _password = null;
    notifyListeners();
  }

  void applyBypass() {
    _loggedIn = true;
    notifyListeners();
  }
}
