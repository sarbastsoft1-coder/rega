import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RegaApiHost {
  static const int apiPort = 8001;
  static const String _fromDefine = String.fromEnvironment('REGA_API_HOST', defaultValue: '');

  static String get origin {
    if (_fromDefine.trim().isNotEmpty) {
      return _fromDefine.trim().replaceAll(RegExp(r'/+$'), '');
    }
    final override = Uri.base.queryParameters['api'];
    if (override != null && override.trim().isNotEmpty) {
      return override.trim().replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        // Production web: same-origin /api via nginx reverse proxy.
        final origin = Uri.base.origin;
        if (origin.isNotEmpty) return origin.replaceAll(RegExp(r'/+$'), '');
      }
      final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
      return '$scheme://127.0.0.1:$apiPort';
    }
    return 'http://127.0.0.1:$apiPort';
  }

  static String get apiV1 => '$origin/api/v1';
}

class RegaBreakpoints {
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1100;
}

class RegaResponsive {
  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isPhone(BuildContext context) => sizeOf(context).width < RegaBreakpoints.phone;

  static bool isTablet(BuildContext context) {
    final w = sizeOf(context).width;
    return w >= RegaBreakpoints.phone && w < RegaBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) => sizeOf(context).width >= RegaBreakpoints.desktop;

  static double pagePadding(BuildContext context) {
    final w = sizeOf(context).width;
    if (w < 360) return 10;
    if (w < RegaBreakpoints.phone) return 14;
    if (w < RegaBreakpoints.tablet) return 20;
    return 28;
  }

  static double dialogMaxWidth(BuildContext context, {double cap = 640}) {
    final w = sizeOf(context).width;
    return math.min(w * 0.92, cap);
  }

  static EdgeInsets dialogInset(BuildContext context, {double cap = 640, double vertical = 24}) {
    final maxW = dialogMaxWidth(context, cap: cap);
    final horizontal = math.max(12.0, (sizeOf(context).width - maxW) / 2);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static double scale(BuildContext context, double base) {
    final w = sizeOf(context).width;
    if (w < 340) return base * 0.86;
    if (w < 380) return base * 0.92;
    if (w > 1100) return base * 1.04;
    return base;
  }

  static int gridCount(BuildContext context, {int phone = 2, int tablet = 3, int desktop = 4}) {
    final w = sizeOf(context).width;
    if (w < RegaBreakpoints.phone) return phone;
    if (w < RegaBreakpoints.desktop) return tablet;
    return desktop;
  }

  static int gridCountForWidth(double w, {int phone = 2, int tablet = 3, int desktop = 4}) {
    if (w < RegaBreakpoints.phone) return phone;
    if (w < RegaBreakpoints.desktop) return tablet;
    return desktop;
  }

  // ── Tablet / iPad layout helpers ───────────────────────────────────────
  /// Forms (login, register, profile edit) — keeps fields readable on iPad.
  static const double formMaxWidth = 560;

  /// Lists & detail pages (cart, orders, settings) on tablets.
  static const double readingMaxWidth = 820;

  /// Catalog / dashboard grids on large tablets & desktop browsers.
  static const double wideMaxWidth = 1080;

  static bool isLandscape(BuildContext context) {
    final s = sizeOf(context);
    return s.width > s.height;
  }

  /// Phone in landscape (short height) — use compact headers / 2-pane layouts.
  static bool isCompactHeight(BuildContext context) => sizeOf(context).height < 500;

  /// True for iPad / Android tablets (shortest side >= 600, any orientation).
  static bool isTabletDevice(BuildContext context) => sizeOf(context).shortestSide >= RegaBreakpoints.phone;

  /// Centers [child] and caps its width so phone layouts do not stretch
  /// edge-to-edge on tablets. Child still fills the width on phones.
  static Widget constrain({
    required Widget child,
    double maxWidth = readingMaxWidth,
    AlignmentGeometry alignment = Alignment.topCenter,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  static Widget appBuilder(BuildContext context, Widget? child, {TextDirection? direction}) {
    final mq = MediaQuery.of(context);
    final clamped = mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15);
    Widget content = MediaQuery(
      data: mq.copyWith(textScaler: clamped),
      child: child ?? const SizedBox.shrink(),
    );
    if (direction != null) {
      content = Directionality(textDirection: direction, child: content);
    }
    return content;
  }
}
