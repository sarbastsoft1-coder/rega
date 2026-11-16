import 'package:flutter/widgets.dart';

/// Shared layout breakpoints for the admin console (web + tablet + phone).
class AdminBreakpoints {
  AdminBreakpoints._();

  /// Phone / compact — drawer nav, stacked columns.
  static const double phone = 600;

  /// Tablet / narrow desktop — drawer or compact chrome.
  static const double tablet = 900;

  /// Wide desktop — fixed sidebar + multi-column charts.
  static const double desktop = 1100;

  /// Typical laptop (1280–1440). Below this the sidebar starts collapsed (icon rail).
  static const double laptop = 1280;

  /// Large laptop / external monitor — wider sidebar, roomier padding.
  static const double wide = 1600;

  /// Pages stop stretching past this width on 1920px+ / ultrawide monitors.
  static const double contentMaxWidth = 1760;

  /// Sidebar sizes: icon rail, normal laptop, large monitor.
  static const double sidebarRail = 76;
  static const double sidebarNormal = 225;
  static const double sidebarWide = 256;

  static bool isLaptopOrWider(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= laptop;

  /// KPI cards: 2 columns between these widths; 4 columns above [kpiFourCol].
  static const double kpiTwoCol = 560;
  static const double kpiFourCol = 960;

  /// Chart pairs / map+activity side-by-side.
  static const double chartsSideBySide = 900;

  /// Finance: Top Sellers + Order Status can sit in a 2-col row.
  static const double chartsTwoCol = 700;

  /// Header actions stay on one row with title.
  static const double headerInline = 760;
  static const double headerCompact = 650;

  /// Horizontal page padding that works from ~320px phones up to desktop.
  static double pagePadH(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < phone) return 12;
    if (w < tablet) return 16;
    if (w < wide) return 24;
    return 32;
  }

  /// Dialog / sheet content width clamped to the viewport.
  static double dialogWidth(BuildContext context, {double max = 560}) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.92).clamp(280.0, max);
  }

  /// Prefer nearly full-screen dialogs on phone; capped fraction on larger screens.
  static double dialogMaxHeight(BuildContext context, {double fraction = 0.92}) {
    final h = MediaQuery.sizeOf(context).height;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return ((h - inset) * fraction).clamp(280.0, h);
  }

  /// Horizontal inset for Dialog / AlertDialog so phone edges aren't clipped.
  static EdgeInsets dialogInset(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < phone) return const EdgeInsets.symmetric(horizontal: 10, vertical: 12);
    if (w < tablet) return const EdgeInsets.symmetric(horizontal: 16, vertical: 20);
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
  }
}
