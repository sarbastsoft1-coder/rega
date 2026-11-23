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
        // Production web: same-origin /api via nginx reverse proxy (no :8001, no CORS).
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

  static bool isDesktop(BuildContext context) => sizeOf(context).width >= RegaBreakpoints.desktop;

  static double pagePadding(BuildContext context) {
    final w = sizeOf(context).width;
    if (w < 360) return 10;
    if (w < RegaBreakpoints.phone) return 14;
    if (w < RegaBreakpoints.tablet) return 20;
    return 28;
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
