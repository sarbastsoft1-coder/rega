import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api/api_client.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../map/rega_standard_map.dart';
import '../rega_i18n.dart';
import '../rega_colors.dart';

class AdminLiveRadarDialog extends StatefulWidget {
  final ApiClient api;

  const AdminLiveRadarDialog({super.key, required this.api});

  @override
  State<AdminLiveRadarDialog> createState() => _AdminLiveRadarDialogState();
}

class _AdminLiveRadarDialogState extends State<AdminLiveRadarDialog> {
  final GlobalKey<RegaStandardMapState> _regaMapKey = GlobalKey();
  static const LatLng _radarCenter = LatLng(34.6295, 45.3159);
  Timer? _pollTimer;

  List<dynamic> _drivers = [];
  List<dynamic> _sessions = [];
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchRadar();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchRadar());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRadar() async {
    try {
      final data = await widget.api.getLiveRadar();
      if (!mounted) return;
      setState(() {
        _tickCount += 1;
        _drivers = data['drivers'] as List<dynamic>? ?? [];
        _sessions = data['live_sessions'] as List<dynamic>? ?? [];
      });
    } catch (_) {}
  }

  Marker _buildPin({
    required LatLng point,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 112,
      height: 70,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tx(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  (List<Polyline>, List<Marker>) _buildRadarLayers() {
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    for (final raw in _sessions) {
      final s = raw as Map<String, dynamic>;
      final store = (s['store'] as Map<String, dynamic>?) ?? const {};
      final cust = (s['customer'] as Map<String, dynamic>?) ?? const {};
      final drv = (s['driver'] as Map<String, dynamic>?) ?? const {};

      final sPt = LatLng(
        (store['lat'] as num?)?.toDouble() ??
            (s['store_lat'] as num?)?.toDouble() ??
            34.6295,
        (store['lng'] as num?)?.toDouble() ??
            (s['store_lng'] as num?)?.toDouble() ??
            45.3159,
      );
      final cPt = LatLng(
        (cust['lat'] as num?)?.toDouble() ??
            (s['customer_lat'] as num?)?.toDouble() ??
            34.6345,
        (cust['lng'] as num?)?.toDouble() ??
            (s['customer_lng'] as num?)?.toDouble() ??
            45.3220,
      );
      final dPt = LatLng(
        (drv['lat'] as num?)?.toDouble() ??
            (s['driver_lat'] as num?)?.toDouble() ??
            34.6315,
        (drv['lng'] as num?)?.toDouble() ??
            (s['driver_lng'] as num?)?.toDouble() ??
            45.3185,
      );
      final etaSecs = (s['eta_seconds'] as num?)?.toInt() ?? 0;
      final ref = (s['order_ref'] ?? '').toString();

      polylines.add(
        Polyline(
          points: [sPt, dPt, cPt],
          color: const Color(0xFF16A34A),
          strokeWidth: 4.5,
          borderColor: const Color(0xFF064E3B),
          borderStrokeWidth: 1.5,
        ),
      );

      markers.add(
        _buildPin(
          point: sPt,
          icon: Icons.storefront_rounded,
          color: const Color(0xFFEA580C),
          label: (store['name'] ?? s['store_name'] ?? 'فرۆشگا').toString(),
        ),
      );
      markers.add(
        _buildPin(
          point: cPt,
          icon: Icons.home_rounded,
          color: const Color(0xFF0284C7),
          label: (cust['name'] ?? s['customer_name'] ?? 'کڕیار').toString(),
        ),
      );
      markers.add(
        _buildPin(
          point: dPt,
          icon: Icons.two_wheeler_rounded,
          color: const Color(0xFF16A34A),
          label: '#$ref • ${etaSecs}s',
        ),
      );
    }

    for (final raw in _drivers) {
      final d = raw as Map<String, dynamic>;
      if (d['is_online'] != true) continue;
      final lat = (d['current_lat'] as num?)?.toDouble() ??
          (d['lat'] as num?)?.toDouble();
      final lng = (d['current_lng'] as num?)?.toDouble() ??
          (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final user = (d['user'] as Map<String, dynamic>?) ?? const {};
      final label =
          (user['name'] ?? d['name'] ?? d['driver_code'] ?? 'کاپتن').toString();

      markers.add(
        _buildPin(
          point: LatLng(lat, lng),
          icon: Icons.two_wheeler_rounded,
          color: const Color(0xFF00B34B),
          label: label,
        ),
      );
    }

    return (polylines, markers);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;
    final isPhone = screenW < AdminBreakpoints.phone;
    final dialogW =
        isPhone ? screenW - 16 : AdminBreakpoints.dialogWidth(context, max: 1120);
    final dialogH = isPhone
        ? screenH * 0.96
        : AdminBreakpoints.dialogMaxHeight(context, fraction: 0.90);
    final mapZoom = isPhone ? 13.8 : 14.5;
    final (polylines, markers) = _buildRadarLayers();

    return Dialog(
      insetPadding: isPhone
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
          : AdminBreakpoints.dialogInset(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 16 : 26),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Stack(
          children: [
            RegaStandardMap(
              key: _regaMapKey,
              center: _radarCenter,
              zoom: mapZoom,
              showCustomerControls: true,
              topControlsOffset: isPhone ? 76 : 86,
              bottomControlsOffset: 18,
              polylines: polylines,
              markers: markers,
            ),
            Positioned(
              top: isPhone ? 10 : 14,
              left: isPhone ? 10 : 14,
              right: isPhone ? 10 : 14,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 12 : 18,
                  vertical: isPhone ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: RC.bg(const Color(0xFF0F172A)).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(isPhone ? 14 : 18),
                  border: Border.all(
                    color: RegaColors.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      color: RegaColors.emerald,
                      size: isPhone ? 22 : 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx(isPhone
                                ? 'ڕاداری زیندووی کەلار'
                                : 'ڕاداری زیندووی شاری کەلار • نوێکردنەوەی چرکە بە چرکە (1s Live GPS)'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: RC.fg(Colors.white),
                              fontWeight: FontWeight.w900,
                              fontSize: isPhone ? 13 : 15,
                            ),
                          ),
                          Text(
                            tx('ئۆنلاین: ${_drivers.where((d) => (d as Map)['is_online'] == true).length} • گەشت: ${_sessions.length} • ${_tickCount}s'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: RC.fg(const Color(0xFF94A3B8)),
                              fontSize: isPhone ? 11 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: RC.fg(Colors.white),
                        size: isPhone ? 20 : 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
