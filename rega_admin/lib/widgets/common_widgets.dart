import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  if (subtitle != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
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
        return const Color(0xFF0D9488);
      case 'picked_up':
        return RegaColors.purple;
      case 'on_the_way':
      case 'arrived_customer':
        return const Color(0xFF0284C7);
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
        return const Color(0xFF64748B);
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
        AppStrings.statusLabel(status, lang),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('دووبارە هەوڵبدەرەوە'),
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
        color: const Color(0xFF0F172A),
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
                    const Positioned(
                      top: 14,
                      right: 16,
                      child: _RadarLegendPill(),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          '📍 کەلار • ڕووباری سیروان • قەڵای شێروانە',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
                          message: '${s['name_ku'] ?? ''} (${online ? 'ئۆنلاین' : 'داخراو'})',
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: online ? RegaColors.gold : const Color(0xFF475569),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: (online ? RegaColors.gold : Colors.black).withValues(alpha: 0.45),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 15,
                              color: online ? const Color(0xFF0F172A) : Colors.white70,
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
                          ? const Color(0xFF64748B)
                          : (busy ? const Color(0xFF38BDF8) : RegaColors.emerald);

                      return Positioned(
                        left: pos.dx - 18,
                        top: pos.dy - 18,
                        child: Tooltip(
                          message:
                              '🏍️ ${d['name'] ?? ''} (${d['driver_code'] ?? ''}) • ${busy ? 'لە گەیاندندایە' : (online ? 'ئامادەیە' : 'ئۆفلاین')}',
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
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.two_wheeler_rounded,
                                    size: 14,
                                    color: Colors.white,
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
  const _RadarLegendPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: RegaColors.gold),
          SizedBox(width: 4),
          Text('فرۆشگا', style: TextStyle(color: Colors.white, fontSize: 10.5)),
          SizedBox(width: 10),
          Icon(Icons.circle, size: 9, color: RegaColors.emerald),
          SizedBox(width: 4),
          Text('شۆفێری ئامادە', style: TextStyle(color: Colors.white, fontSize: 10.5)),
          SizedBox(width: 10),
          Icon(Icons.circle, size: 9, color: Color(0xFF38BDF8)),
          SizedBox(width: 4),
          Text('لە گەیاندن', style: TextStyle(color: Colors.white, fontSize: 10.5)),
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
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Sirwan River curve along eastern/southern edge
    final riverPaint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final river = Path()
      ..moveTo(size.width * 0.88, 0)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.55, size.width * 0.94, size.height);
    canvas.drawPath(river, riverPaint);

    // Kalar arterial ring roads
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
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

