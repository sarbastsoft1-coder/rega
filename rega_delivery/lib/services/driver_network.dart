import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks device connectivity for offline banner + mutation drain.
class DriverNetwork extends ChangeNotifier {
  DriverNetwork._();
  static final DriverNetwork instance = DriverNetwork._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  bool _started = false;

  bool get isOnline => _online;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final current = await _connectivity.checkConnectivity();
      _apply(current);
    } catch (_) {
      _online = true;
    }
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next == _online) return;
    _online = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    super.dispose();
  }
}
