import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-launch splash/onboarding gate for the customer app.
class OnboardingNotifier extends ChangeNotifier {
  static const prefsKey = 'rega_onboarding_done';

  bool _ready = false;
  bool _done = false;

  bool get ready => _ready;
  bool get done => _done;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _done = prefs.getBool(prefsKey) == true;
    } catch (_) {
      _done = false;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> complete() async {
    _done = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, true);
    } catch (_) {}
  }
}
