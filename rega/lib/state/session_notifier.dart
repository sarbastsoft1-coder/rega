import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../blocked_account.dart';
import '../customer_api_service.dart';
import '../models/customer_models.dart';

class SessionNotifier extends ChangeNotifier {
  UserProfile? _user;
  bool _isLoginMode = true; // default: login tab first
  bool _restoring = true;
  AccountBlockedException? _pendingBlocked;

  static const _profilePrefKey = 'user_profile';
  static const _loggedInPrefKey = 'rega_customer_logged_in';

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoginMode => _isLoginMode;
  bool get isRestoring => _restoring;
  AccountBlockedException? get pendingBlocked => _pendingBlocked;

  void clearPendingBlocked() {
    if (_pendingBlocked == null) return;
    _pendingBlocked = null;
    notifyListeners();
  }

  void setLoginMode(bool value) {
    if (_isLoginMode == value) return;
    _isLoginMode = value;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    _restoring = true;
    notifyListeners();
    try {
      await CustomerApiService.instance.initToken();
      final prefs = await SharedPreferences.getInstance();
      final wantSession = prefs.getBool(_loggedInPrefKey) == true;
      final hasToken = CustomerApiService.instance.hasToken;

      // No prior login on this device → stay on login.
      if (!hasToken && !wantSession) {
        _user = null;
        return;
      }

      // Token missing but flag set (corrupt / cleared) → force login.
      if (!hasToken) {
        await prefs.setBool(_loggedInPrefKey, false);
        await prefs.remove(_profilePrefKey);
        _user = null;
        return;
      }

      // Always validate Sanctum token. Cached profile alone must not keep a dead session
      // (that caused /customer/notifications → 401 → empty inbox).
      try {
        final me = await CustomerApiService.instance.fetchMe();
        if (me != null) {
          final phone = (me['phone'] ?? '').toString().trim();
          if (phone.isNotEmpty) {
            _user = UserProfile(
              name: (me['name'] ?? phone).toString(),
              phone: phone,
              email: (me['email'] ?? '').toString(),
              address: (me['address'] ?? me['default_address'] ?? '').toString(),
            );
            await _persistProfile(_user!);
            await prefs.setBool(_loggedInPrefKey, true);
            return;
          }
        }
      } on AccountBlockedException catch (e) {
        // Admin blocked this customer — force logout and let UI show WhatsApp help dialog.
        _pendingBlocked = e;
        await CustomerApiService.instance.clearToken();
        await prefs.setBool(_loggedInPrefKey, false);
        await prefs.remove(_profilePrefKey);
        _user = null;
        return;
      }

      // Token invalid / expired → clear and require login.
      await CustomerApiService.instance.clearToken();
      await prefs.setBool(_loggedInPrefKey, false);
      await prefs.remove(_profilePrefKey);
      _user = null;
    } catch (_) {
      _user = null;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> signIn(UserProfile profile) async {
    _user = profile;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await _persistProfile(profile);
      await prefs.setBool(_loggedInPrefKey, true);
    } catch (_) {}
  }

  Future<void> updateProfile(UserProfile profile) async {
    _user = profile;
    notifyListeners();
    try {
      await _persistProfile(profile);
    } catch (_) {}
  }

  Future<void> _persistProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilePrefKey,
      jsonEncode({
        'name': profile.name,
        'phone': profile.phone,
        'email': profile.email,
        'address': profile.address,
      }),
    );
  }

  Future<void> signOut() async {
    _user = null;
    await CustomerApiService.instance.clearToken();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profilePrefKey);
      await prefs.setBool(_loggedInPrefKey, false);
    } catch (_) {}
    notifyListeners();
  }
}
