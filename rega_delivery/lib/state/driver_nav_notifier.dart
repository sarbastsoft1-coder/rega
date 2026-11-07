import 'package:flutter/foundation.dart';

/// Driver tabs: 0 map, 1 jobs, 2 earnings, 3 profile
class DriverNavNotifier extends ChangeNotifier {
  static const tabPaths = <String>['/map', '/jobs', '/earnings', '/profile'];

  int _tabIndex = 0;

  int get tabIndex => _tabIndex;

  static int indexForPath(String path) {
    final i = tabPaths.indexWhere((p) => path == p || path.startsWith('$p/'));
    return i < 0 ? 0 : i;
  }

  static String pathForIndex(int index) {
    if (index < 0 || index >= tabPaths.length) return tabPaths.first;
    return tabPaths[index];
  }

  void setTabIndex(int index) {
    final next = index.clamp(0, tabPaths.length - 1);
    if (_tabIndex == next) return;
    _tabIndex = next;
    notifyListeners();
  }
}
