import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';

/// Stacks two form fields vertically below [breakpoint], otherwise side-by-side.
class ResponsiveFormRow extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double breakpoint;
  final double spacing;

  const ResponsiveFormRow({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 460,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: spacing),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

/// Key/value detail row that wraps gracefully without overflowing narrow dialogs.
class ResponsiveDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ltrValue;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const ResponsiveDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.ltrValue = false,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final surfaces = AdminSurfaces.of(context);
    final valueWidget = Text(
      tx(value),
      textAlign: TextAlign.end,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: valueStyle ??
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: surfaces.textPrimary,
          ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            tx(label),
            style: labelStyle ??
                TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: surfaces.textSecondary,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: ltrValue
              ? Directionality(textDirection: TextDirection.ltr, child: valueWidget)
              : valueWidget,
        ),
      ],
    );
  }
}

class StatKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const StatKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaces = AdminSurfaces.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 260 ||
            (constraints.hasBoundedHeight && constraints.maxHeight < 135) ||
            MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;

        final iconBox = Container(
          padding: EdgeInsets.all(narrow ? 9 : 10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: narrow ? 20 : 22),
        );

        final subtitleChip = subtitle == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tx(subtitle!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              );

        // Phone / short cell: compact horizontal row so cards never overflow vertically.
        if (narrow) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tx(title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: surfaces.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              tx(value),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: surfaces.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (subtitleChip != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: subtitleChip,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      iconBox,
                      if (subtitleChip != null) ...[
                        const SizedBox(width: 6),
                        Flexible(child: subtitleChip),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      tx(value),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: surfaces.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: surfaces.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final String lang;

  const StatusBadge({super.key, required this.status, this.lang = 'ku'});

  static Color colorFor(String status) {
    switch (status) {
      case 'pending':
        return RegaColors.orange;
      case 'preparing':
      case 'in_progress':
        return RegaColors.blue;
      case 'ready':
      case 'approved':
        return RC.bg(Color(0xFF0D9488));
      case 'picked_up':
        return RegaColors.purple;
      case 'on_the_way':
      case 'arrived_customer':
        return RC.bg(Color(0xFF0284C7));
      case 'delivered':
      case 'verified':
      case 'completed':
      case 'resolved':
        return RegaColors.emeraldDark;
      case 'cancelled':
      case 'rejected':
      case 'urgent':
        return RegaColors.crimson;
      default:
        return RC.bg(Color(0xFF64748B));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        tx(AppStrings.statusLabel(status, lang)),
        style: TextStyle(
          color: c,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final surfaces = AdminSurfaces.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < AdminBreakpoints.phone;
        final titleCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx(title),
              style: TextStyle(
                fontSize: narrow ? 16 : 18,
                fontWeight: FontWeight.w900,
                color: surfaces.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                tx(subtitle!),
                style: TextStyle(
                  fontSize: 12,
                  color: surfaces.textSecondary,
                ),
              ),
            ],
          ],
        );
        if (trailing == null) return titleCol;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleCol,
              const SizedBox(height: 10),
              trailing!,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titleCol),
            const SizedBox(width: 12),
            trailing!,
          ],
        );
      },
    );
  }
}

class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: RegaColors.crimson.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 42, color: RegaColors.crimson),
            ),
            const SizedBox(height: 16),
            Text(
              tx(message),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tx('دووبارە هەوڵبدەرەوە')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Live Kalar Fleet & Store Radar Map
class KalarFleetRadarMap extends StatefulWidget {
  final List<dynamic> stores;
  final List<dynamic> drivers;

  const KalarFleetRadarMap({
    super.key,
    required this.stores,
    required this.drivers,
  });

  @override
  State<KalarFleetRadarMap> createState() => _KalarFleetRadarMapState();
}

class _KalarFleetRadarMapState extends State<KalarFleetRadarMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Offset _latLngToPos(double lat, double lng, Size size) {
    // Kalar bounding box: lat [34.668..34.705], lng [45.292..45.340]
    const minLat = 34.668;
    const maxLat = 34.705;
    const minLng = 45.292;
    const maxLng = 45.340;

    final nx = ((lng - minLng) / (maxLng - minLng)).clamp(0.08, 0.92);
    final ny = (1.0 - (lat - minLat) / (maxLat - minLat)).clamp(0.10, 0.90);
    return Offset(nx * size.width, ny * size.height);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 310,
        color: RC.bg(Color(0xFF0F172A)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return Stack(
                  children: [
                    CustomPaint(
                      size: size,
                      painter: _KalarRadarGridPainter(pulse: _pulseCtrl.value),
                    ),
                    // Landmark labels
                    PositionedDirectional(
                      top: 14,
                      end: 16,
                      child: _RadarLegendPill(
                        maxWidth: math.max(120.0, size.width - 28),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 14,
                      start: 14,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(120.0, size.width - 28),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.black).withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: RC.bg(Colors.white12)),
                          ),
                          child: Text(
                            tx('📍 کەلار • ڕووباری سیروان • قەڵای شێروانە'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: RC.fg(Colors.white70), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    // Store pins
                    ...widget.stores.map((raw) {
                      final s = raw as Map<String, dynamic>;
                      final lat = (s['lat'] as num?)?.toDouble() ?? 34.6836;
                      final lng = (s['lng'] as num?)?.toDouble() ?? 45.3189;
                      final online = s['is_online'] == true;
                      final pos = _latLngToPos(lat, lng, size);
                      return Positioned(
                        left: pos.dx - 14,
                        top: pos.dy - 14,
                        child: Tooltip(
                          message: tx('${s['name_ku'] ?? ''} (${online ? 'ئۆنلاین' : 'داخراو'})'),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: online ? RegaColors.gold : RC.bg(Color(0xFF475569)),
                              shape: BoxShape.circle,
                              border: Border.all(color: RC.bg(Colors.white), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: (online ? RegaColors.gold : RC.bg(Colors.black)).withValues(alpha: 0.45),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 15,
                              color: online ? RC.fg(Color(0xFF0F172A)) : RC.bg(Colors.white70),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Driver pins
                    ...widget.drivers.map((raw) {
                      final d = raw as Map<String, dynamic>;
                      final lat = (d['lat'] as num?)?.toDouble() ?? 34.6850;
                      final lng = (d['lng'] as num?)?.toDouble() ?? 45.3200;
                      final online = d['is_online'] == true;
                      final busy = d['has_active_order'] == true;
                      final pos = _latLngToPos(lat, lng, size);
                      final pinColor = !online
                          ? RC.bg(Color(0xFF64748B))
                          : (busy ? RC.bg(Color(0xFF38BDF8)) : RegaColors.emerald);

                      return Positioned(
                        left: pos.dx - 18,
                        top: pos.dy - 18,
                        child: Tooltip(
                          message:
                              tx('🏍️ ${d['name'] ?? ''} (${d['driver_code'] ?? ''}) • ${busy ? 'لە گەیاندندایە' : (online ? 'ئامادەیە' : 'ئۆفلاین')}'),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (online)
                                  Container(
                                    width: 18 + (18 * _pulseCtrl.value),
                                    height: 18 + (18 * _pulseCtrl.value),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: pinColor.withValues(alpha: (1 - _pulseCtrl.value) * 0.4),
                                    ),
                                  ),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: pinColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: RC.bg(Colors.white), width: 2),
                                  ),
                                  child: Icon(
                                    Icons.two_wheeler_rounded,
                                    size: 14,
                                    color: RC.fg(Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RadarLegendPill extends StatelessWidget {
  final double? maxWidth;

  const _RadarLegendPill({this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final effMax = maxWidth ?? MediaQuery.sizeOf(context).width * 0.72;
    final narrow = effMax < 440 || MediaQuery.sizeOf(context).width < AdminBreakpoints.phone;
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 4),
          Text(tx(label), style: TextStyle(color: RC.fg(Colors.white), fontSize: narrow ? 9.5 : 10.5)),
        ],
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: effMax),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: RC.bg(Colors.black).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: RC.bg(Colors.white12)),
      ),
      child: Wrap(
        spacing: narrow ? 8 : 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          item(RegaColors.gold, 'فرۆشگا'),
          item(RegaColors.emerald, narrow ? 'شۆفێر' : 'شۆفێری ئامادە'),
          item(RC.bg(Color(0xFF38BDF8)), 'لە گەیاندن'),
        ],
      ),
    );
  }
}

class _KalarRadarGridPainter extends CustomPainter {
  final double pulse;
  _KalarRadarGridPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = RC.bg(Color(0xFF1E293B))
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Sirwan River curve along eastern/southern edge
    final riverPaint = Paint()
      ..color = RC.bg(Color(0xFF0EA5E9)).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final river = Path()
      ..moveTo(size.width * 0.88, 0)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.55, size.width * 0.94, size.height);
    canvas.drawPath(river, riverPaint);

    // Kalar arterial ring roads
    final roadPaint = Paint()
      ..color = RC.bg(Colors.white).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.52), math.min(size.width, size.height) * 0.28, roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.52), Offset(size.width, size.height * 0.48), roadPaint);
    canvas.drawLine(Offset(size.width * 0.50, 0), Offset(size.width * 0.54, size.height), roadPaint);

    // Subtle radar sweep circle
    final radarPaint = Paint()
      ..color = RegaColors.emerald.withValues(alpha: (1 - pulse) * 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.52),
      (math.min(size.width, size.height) * 0.45) * pulse,
      radarPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KalarRadarGridPainter oldDelegate) => oldDelegate.pulse != pulse;
}

