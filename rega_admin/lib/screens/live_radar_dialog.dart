import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api/api_client.dart';
import '../core/theme/app_theme.dart';

class AdminLiveRadarDialog extends StatefulWidget {
  final ApiClient api;

  const AdminLiveRadarDialog({super.key, required this.api});

  @override
  State<AdminLiveRadarDialog> createState() => _AdminLiveRadarDialogState();
}

class _AdminLiveRadarDialogState extends State<AdminLiveRadarDialog> {
  final MapController _mapController = MapController();
  Timer? _pollTimer;

  bool _darkMap = true;
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
    _mapController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    // Active Live Telemetry Sessions (Store -> Driver -> Customer)
    for (final raw in _sessions) {
      final s = raw as Map<String, dynamic>;
      final store = (s['store'] as Map<String, dynamic>?) ?? const {};
      final cust = (s['customer'] as Map<String, dynamic>?) ?? const {};
      final drv = (s['driver'] as Map<String, dynamic>?) ?? const {};

      final sPt = LatLng(
        (store['lat'] as num?)?.toDouble() ?? 34.6836,
        (store['lng'] as num?)?.toDouble() ?? 45.3189,
      );
      final cPt = LatLng(
        (cust['lat'] as num?)?.toDouble() ?? 34.6912,
        (cust['lng'] as num?)?.toDouble() ?? 45.3264,
      );
      final dPt = LatLng(
        (drv['lat'] as num?)?.toDouble() ?? 34.6860,
        (drv['lng'] as num?)?.toDouble() ?? 45.3215,
      );
      final heading = (drv['heading'] as num?)?.toDouble() ?? 45.0;
      final etaSecs = (s['eta_seconds'] as num?)?.toInt() ?? 0;
      final ref = (s['order_ref'] ?? '').toString();

      polylines.add(
        Polyline(
          points: [sPt, dPt, cPt],
          strokeWidth: 4.5,
          color: RegaColors.emerald,
        ),
      );

      markers.add(
        Marker(
          point: sPt,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 17),
          ),
        ),
      );

      markers.add(
        Marker(
          point: cPt,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: RegaColors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 17),
          ),
        ),
      );

      markers.add(
        Marker(
          point: dPt,
          width: 112,
          height: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RegaColors.gold),
                ),
                child: Text(
                  '#$ref • ${etaSecs}s',
                  style: const TextStyle(
                    color: RegaColors.gold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Transform.rotate(
                angle: heading * math.pi / 180.0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: RegaColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.two_wheeler_rounded, color: Colors.black, size: 18),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Online Fleet Drivers
    for (final raw in _drivers) {
      final d = raw as Map<String, dynamic>;
      if (d['is_online'] != true) continue;
      final lat = (d['current_lat'] as num?)?.toDouble();
      final lng = (d['current_lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final user = (d['user'] as Map<String, dynamic>?) ?? const {};

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 96,
          height: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (user['name'] ?? d['driver_code'] ?? 'Captain').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: RegaColors.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 15),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1120,
        height: 680,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(34.6855, 45.3210),
                initialZoom: 14.5,
                minZoom: 11.5,
                maxZoom: 18.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: _darkMap
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'iq.rega.admin',
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: RegaColors.gold.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: RegaColors.emerald, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ڕاداری زیندووی شاری کەلار • نوێکردنەوەی چرکە بە چرکە (1s Live GPS)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'شۆفێرە ئۆنلاینەکان: ${_drivers.where((d) => (d as Map)['is_online'] == true).length} • گەشتە زیندووەکان: ${_sessions.length} • ژمارەی نوێبوونەوە: ${_tickCount}s',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _darkMap = !_darkMap),
                      tooltip: 'گۆڕینی شێوازی نەخشە',
                      icon: Icon(
                        _darkMap ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: RegaColors.gold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
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

