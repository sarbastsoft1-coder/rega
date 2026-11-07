import 'package:flutter/foundation.dart';

/// Vendor bottom tabs: 0 settings, 1 revenue, 2 products, 3 orders
class VendorNavNotifier extends ChangeNotifier {
  static const tabPaths = <String>[
    '/settings',
    '/revenue',
    '/products',
    '/orders',
  ];

  int _tabIndex = 3;

  int get tabIndex => _tabIndex;

  static int indexForPath(String path) {
    final i = tabPaths.indexWhere((p) => path == p || path.startsWith('$p/'));
    return i < 0 ? 3 : i;
  }

  static String pathForIndex(int index) {
    if (index < 0 || index >= tabPaths.length) return tabPaths.last;
    return tabPaths[index];
  }

  void setTabIndex(int index) {
    final next = index.clamp(0, tabPaths.length - 1);
    if (_tabIndex == next) return;
    _tabIndex = next;
    notifyListeners();
  }
}
