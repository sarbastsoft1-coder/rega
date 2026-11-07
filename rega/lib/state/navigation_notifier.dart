import 'package:flutter/foundation.dart';

/// Bottom-tab index synced with go_router paths.
class NavigationNotifier extends ChangeNotifier {
  static const tabPaths = <String>[
    '/home',
    '/offers',
    '/cart',
    '/orders',
    '/profile',
  ];

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
