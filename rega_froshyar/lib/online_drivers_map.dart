import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'map/rega_standard_map.dart';
import 'vendor_api_service.dart';

import 'rega_i18n.dart';
import 'rega_colors.dart';

/// Live GPS of online delivery captains for the seller app.
/// Store + driver pins only from real API coords (no fake place fallback).
class OnlineDriversMapPage extends StatefulWidget {
  const OnlineDriversMapPage({super.key});

  @override
  State<OnlineDriversMapPage> createState() => _OnlineDriversMapPageState();
}

class _OnlineDriversMapPageState extends State<OnlineDriversMapPage> {
  final GlobalKey<RegaStandardMapState> _regaMapKey = GlobalKey();
  mb.MapboxMap? _mbMap;
  mb.PointAnnotationManager? _pointMgr;
  Timer? _poll;
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic>? _store;
  int _onlineCount = 0;
  bool _loading = true;
  bool _mapReady = false;

  static const LatLng _kalarOverview = LatLng(34.6295, 45.3159);

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  mb.Point _mbPoint(LatLng p) =>
      mb.Point(coordinates: mb.Position(p.longitude, p.latitude));

  int _colorInt(Color c) => RC.bg(c).toARGB32();

  bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && lat.abs() > 0.01 && lng.abs() > 0.01;

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _mbMap = map;
    _mapReady = true;
    if (!kIsWeb) {
      try {
        _pointMgr = await map.annotations.createPointAnnotationManager();
      } catch (_) {}
    }
    await _syncPointAnnotations();
    if (_mapReady) await _fitMap();
  }

  Future<void> _syncPointAnnotations() async {
    if (kIsWeb || _pointMgr == null) return;
    try {
      await _pointMgr!.deleteAll();
    } catch (_) {}

    final storeLat = (_store?['lat'] as num?)?.toDouble();
    final storeLng = (_store?['lng'] as num?)?.toDouble();
    if (_valid(storeLat, storeLng)) {
      try {
        await _pointMgr!.create(
          mb.PointAnnotationOptions(
            geometry: _mbPoint(LatLng(storeLat!, storeLng!)),
            textField: tx('فرۆشگا'),
            textSize: 10,
            textHaloWidth: 1,
            textHaloColor: _colorInt(Colors.white),
            iconColor: _colorInt(const Color(0xFFEA580C)),
            iconSize: 1.2,
          ),
        );
      } catch (_) {}
    }

    for (final d in _drivers) {
      final lat = (d['lat'] as num?)?.toDouble() ?? (d['current_lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble() ?? (d['current_lng'] as num?)?.toDouble();
      if (!_valid(lat, lng)) continue;
      final name = (d['name'] ?? d['driver_code'] ?? 'Captain').toString();
      final meters = (d['distance_meters'] as num?)?.toInt();
      final label = meters != null ? '$name • ${meters}m' : name;
      try {
        await _pointMgr!.create(
          mb.PointAnnotationOptions(
            geometry: _mbPoint(LatLng(lat!, lng!)),
            textField: tx(label),
            textSize: 9,
            textColor: _colorInt(Colors.white),
            textHaloColor: _colorInt(const Color(0xFF064E3B)),
            textHaloWidth: 1.2,
            textOffset: [0, -1.6],
            iconColor: _colorInt(const Color(0xFF16A34A)),
            iconSize: 1.1,
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final data = await VendorApiService.instance.fetchNearbyDrivers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) return;
      _store = data['store'] as Map<String, dynamic>?;
      _drivers = (data['drivers'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((d) {
            final lat = (d['lat'] as num?)?.toDouble() ?? (d['current_lat'] as num?)?.toDouble();
            final lng = (d['lng'] as num?)?.toDouble() ?? (d['current_lng'] as num?)?.toDouble();
            return _valid(lat, lng);
          })
          .toList();
      _onlineCount = (data['online_count'] as num?)?.toInt() ?? _drivers.length;
    });

    await _syncPointAnnotations();
    if (_mapReady) await _fitMap();
  }

  Future<void> _fitMap() async {
    final points = <LatLng>[];
    final storeLat = (_store?['lat'] as num?)?.toDouble();
    final storeLng = (_store?['lng'] as num?)?.toDouble();
    if (_valid(storeLat, storeLng)) {
      points.add(LatLng(storeLat!, storeLng!));
    }
    for (final d in _drivers) {
      final lat = (d['lat'] as num?)?.toDouble() ?? (d['current_lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble() ?? (d['current_lng'] as num?)?.toDouble();
      if (_valid(lat, lng)) points.add(LatLng(lat!, lng!));
    }
    final map = _mbMap;
    if (map == null) return;
    try {
      if (points.isEmpty) {
        await _regaMapKey.currentState?.moveTo(_kalarOverview, zoom: 13.2);
        return;
      }
      if (points.length == 1) {
        await _regaMapKey.currentState?.moveTo(points.first, zoom: 14.5);
        return;
      }
      final camera = await map.cameraForCoordinates(
        points.map(_mbPoint).toList(),
        mb.MbxEdgeInsets(top: 36, left: 36, bottom: 36, right: 36),
        null,
        null,
      );
      await map.setCamera(camera);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final storeLat = (_store?['lat'] as num?)?.toDouble();
    final storeLng = (_store?['lng'] as num?)?.toDouble();
    final hasStore = _valid(storeLat, storeLng);
    final storePt = hasStore ? LatLng(storeLat!, storeLng!) : null;

    return Scaffold(
      backgroundColor: RC.bg(Color(0xFFF8FAFC)),
      appBar: AppBar(
        backgroundColor: RC.bg(Color(0xFFEA580C)),
        foregroundColor: RC.fg(Colors.white),
        title: Text(
          tx('شۆفێرە ئۆنلاینەکان ($_onlineCount)'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: tx('نوێکردنەوە'),
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          RegaStandardMap(
            key: _regaMapKey,
            center: storePt ?? _kalarOverview,
            zoom: 13.8,
            showLayersFab: true,
            onMapCreated: _onMapCreated,
          ),
          if (_loading)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text(tx('نوێکردنەوەی GPS...'), style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_loading && _drivers.isEmpty)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Card(
                color: RC.bg(Color(0xFFFEF3C7)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    tx(hasStore
                        ? 'هیچ شۆفێرێکی ئۆنلاین لەسەر نەخشە نییە. کاتێک شۆفێر Online + GPS دەکاتەوە، لێرە دەردەکەوێت.'
                        : 'شوێنی فرۆشگا لە سێرڤەر نییە — شۆفێرەکان دوای Online + GPS دەردەکەون (بێ شوێنی ساختە).'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.4, color: RC.fg(Color(0xFF92400E))),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}