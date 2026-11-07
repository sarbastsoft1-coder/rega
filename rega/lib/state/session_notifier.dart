import 'package:flutter/foundation.dart';
import '../models/customer_models.dart';

class SessionNotifier extends ChangeNotifier {
  UserProfile? _user;
  bool _isLoginMode = false;

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoginMode => _isLoginMode;

  void setLoginMode(bool value) {
    if (_isLoginMode == value) return;
    _isLoginMode = value;
    notifyListeners();
  }

  void signIn(UserProfile profile) {
    _user = profile;
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _user = profile;
    notifyListeners();
  }

  void signOut() {
    _user = null;
    notifyListeners();
  }
}
