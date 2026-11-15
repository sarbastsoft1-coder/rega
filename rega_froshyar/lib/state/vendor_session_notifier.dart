import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../vendor_api_service.dart';

class VendorSessionNotifier extends ChangeNotifier {
  bool _loggedIn = false;
  String? _phone;
  String? _password;
  bool _restoring = true;
  static const _phonePrefKey = 'rega_vendor_phone';
  static const _loggedInPrefKey = 'rega_vendor_logged_in';

  bool get isLoggedIn => _loggedIn;
  bool get isRestoring => _restoring;
  String? get phone => _phone;
  String? get password => _password;

  Future<void> restoreSession() async {
    _restoring = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _phone = prefs.getString(_phonePrefKey);
      await VendorApiService.instance.ensureAuthenticated();

      // Sanctum token alone is enough — covers older installs without logged_in flag.
      if (VendorApiService.instance.isAuthenticated) {
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

  Future<void> login({String? phone, String? password}) async {
    _loggedIn = true;
    _phone = phone;
    _password = password;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInPrefKey, true);
      if (phone != null && phone.trim().isNotEmpty) {
        await prefs.setString(_phonePrefKey, phone.trim());
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    _loggedIn = false;
    _phone = null;
    _password = null;
    notifyListeners();
    try {
      await VendorApiService.instance.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInPrefKey, false);
    } catch (_) {}
  }
}
