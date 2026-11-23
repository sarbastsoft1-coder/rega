import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../core/api/api_client.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../map/rega_map_annotation_helpers.dart';
import '../map/rega_map_styles.dart';
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
  mb.PointAnnotationManager? _pointMgr;
  mb.CircleAnnotationManager? _circleMgr;
  mb.PolylineAnnotationManager? _polylineMgr;
  static const LatLng _radarCenter = LatLng(34.6295, 45.3159);
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
      _syncRadarMapAnnotations();
    } catch (_) {}
  }

  Future<void> _onRadarMapCreated(mb.MapboxMap map) async {
    final ann = map.annotations;
    _pointMgr = await ann.createPointAnnotationManager();
    _circleMgr = await ann.createCircleAnnotationManager();
    _polylineMgr = await ann.createPolylineAnnotationManager();
    await _syncRadarMapAnnotations();
  }

  Future<void> _syncRadarMapAnnotations() async {
    final points = _pointMgr;
    final circles = _circleMgr;
    final lines = _polylineMgr;
    if (points == null || circles == null || lines == null) return;
    await regaClearAnnotationLayers(points: points, circles: circles, polylines: lines);

    final pointOpts = <mb.PointAnnotationOptions>[];
    final circleOpts = <mb.CircleAnnotationOptions>[];
    final lineOpts = <mb.PolylineAnnotationOptions>[];

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

      lineOpts.add(
        mb.PolylineAnnotationOptions(
          geometry: regaMapLine([sPt, dPt, cPt]),
          lineColor: regaArgb(RegaColors.emerald),
          lineWidth: 4.5,
        ),
      );

      circleOpts.add(
        mb.CircleAnnotationOptions(
          geometry: regaMapPoint(sPt),
          circleRadius: 9,
          circleColor: regaArgb(RC.bg(const Color(0xFFEA580C))),
          circleStrokeColor: regaArgb(RC.bg(Colors.white)),
          circleStrokeWidth: 2,
        ),
      );
      circleOpts.add(
        mb.CircleAnnotationOptions(
          geometry: regaMapPoint(cPt),
          circleRadius: 9,
          circleColor: regaArgb(RegaColors.blue),
          circleStrokeColor: regaArgb(RC.bg(Colors.white)),
          circleStrokeWidth: 2,
        ),
      );
      pointOpts.add(
        mb.PointAnnotationOptions(
          geometry: regaMapPoint(dPt),
          textField: '#$ref • ${etaSecs}s',
          textSize: 9.5,
          textColor: regaArgb(RegaColors.gold),
          textHaloColor: regaArgb(RC.bg(Colors.black87)),
          textHaloWidth: 1,
          textOffset: [0, -2.0],
        ),
      );
      circleOpts.add(
        mb.CircleAnnotationOptions(
          geometry: regaMapPoint(dPt),
          circleRadius: 11,
          circleColor: regaArgb(RegaColors.gold),
          circleStrokeColor: regaArgb(RC.bg(Colors.black)),
          circleStrokeWidth: 2,
        ),
      );
      pointOpts.add(
        mb.PointAnnotationOptions(
          geometry: regaMapPoint(dPt),
          iconRotate: heading,
          textField: '›',
          textSize: 16,
          textColor: regaArgb(RC.fg(Colors.black)),
        ),
      );
    }

    for (final raw in _drivers) {
      final d = raw as Map<String, dynamic>;
      if (d['is_online'] != true) continue;
      final lat = (d['current_lat'] as num?)?.toDouble();
      final lng = (d['current_lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final user = (d['user'] as Map<String, dynamic>?) ?? const {};
      final label = (user['name'] ?? d['driver_code'] ?? 'Captain').toString();

      pointOpts.add(
        mb.PointAnnotationOptions(
          geometry: regaMapPoint(LatLng(lat, lng)),
          textField: label,
          textSize: 9,
          textColor: regaArgb(RC.fg(Colors.white)),
          textHaloColor: regaArgb(RC.bg(const Color(0xFF064E3B))),
          textHaloWidth: 1,
          textOffset: [0, -2.2],
        ),
      );
      circleOpts.add(
        mb.CircleAnnotationOptions(
          geometry: regaMapPoint(LatLng(lat, lng)),
          circleRadius: 9,
          circleColor: regaArgb(RegaColors.emerald),
          circleStrokeColor: regaArgb(RC.bg(Colors.white)),
          circleStrokeWidth: 2,
        ),
      );
    }

    if (lineOpts.isNotEmpty) await lines.createMulti(lineOpts);
    if (circleOpts.isNotEmpty) await circles.createMulti(circleOpts);
    if (pointOpts.isNotEmpty) await points.createMulti(pointOpts);
  }

  Future<void> _toggleRadarMapStyle() async {
    setState(() => _darkMap = !_darkMap);
    await _regaMapKey.currentState?.applyStyle(_darkMap ? RegaMapStyleId.dark : RegaMapStyleId.map);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;
    final isPhone = screenW < AdminBreakpoints.phone;
    final dialogW = isPhone ? screenW - 16 : AdminBreakpoints.dialogWidth(context, max: 1120);
    final dialogH = isPhone ? screenH * 0.96 : AdminBreakpoints.dialogMaxHeight(context, fraction: 0.90);
    final mapZoom = isPhone ? 13.8 : 14.5;

    return Dialog(
      insetPadding: isPhone
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
          : AdminBreakpoints.dialogInset(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isPhone ? 16 : 26)),
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
              showLayersFab: true,
              initialStyle: _darkMap ? RegaMapStyleId.dark : RegaMapStyleId.map,
              onMapCreated: _onRadarMapCreated,
            ),
            Positioned(
              top: isPhone ? 10 : 16,
              left: isPhone ? 10 : 16,
              right: isPhone ? 10 : 16,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 12 : 18,
                  vertical: isPhone ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: RC.bg(const Color(0xFF0F172A)).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(isPhone ? 14 : 18),
                  border: Border.all(color: RegaColors.gold.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radar_rounded, color: RegaColors.emerald, size: isPhone ? 22 : 26),
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
                            style: TextStyle(color: RC.fg(const Color(0xFF94A3B8)), fontSize: isPhone ? 11 : 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _toggleRadarMapStyle,
                      tooltip: tx('گۆڕینی شێوازی نەخشە'),
                      icon: Icon(
                        _darkMap ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: RegaColors.gold,
                        size: isPhone ? 20 : 24,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: RC.fg(Colors.white), size: isPhone ? 20 : 24),
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