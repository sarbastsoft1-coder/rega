import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map/mapbox_tiles.dart';
import 'vendor_api_service.dart';

/// Live GPS of online delivery captains for the seller app.
/// Store + driver pins only from real API coords (no fake place fallback).
class OnlineDriversMapPage extends StatefulWidget {
  const OnlineDriversMapPage({super.key});

  @override
  State<OnlineDriversMapPage> createState() => _OnlineDriversMapPageState();
}

class _OnlineDriversMapPageState extends State<OnlineDriversMapPage> {
  final MapController _mapController = MapController();
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
    _mapController.dispose();
    super.dispose();
  }

  bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && lat.abs() > 0.01 && lng.abs() > 0.01;

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

    if (_mapReady) {
      _fitMap();
    }
  }

  void _fitMap() {
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
    if (points.isEmpty) {
      try {
        _mapController.move(_kalarOverview, 13.2);
      } catch (_) {}
      return;
    }
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 14.5);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(36),
            maxZoom: 16,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final storeLat = (_store?['lat'] as num?)?.toDouble();
    final storeLng = (_store?['lng'] as num?)?.toDouble();
    final hasStore = _valid(storeLat, storeLng);
    final storePt = hasStore ? LatLng(storeLat!, storeLng!) : null;

    final markers = <Marker>[
      if (storePt != null)
        Marker(
          point: storePt,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
          ),
        ),
      ..._drivers.map((d) {
        final lat = (d['lat'] as num?)?.toDouble() ?? (d['current_lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble() ?? (d['current_lng'] as num?)?.toDouble();
        if (!_valid(lat, lng)) return null;
        final name = (d['name'] ?? d['driver_code'] ?? 'Captain').toString();
        final meters = (d['distance_meters'] as num?)?.toInt();
        return Marker(
          point: LatLng(lat!, lng!),
          width: 110,
          height: 58,
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
                  meters != null ? '$name • ${meters}m' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 15),
              ),
            ],
          ),
        );
      }).whereType<Marker>(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
        title: Text(
          'شۆفێرە ئۆنلاینەکان ($_onlineCount)',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'نوێکردنەوە',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: storePt ?? _kalarOverview,
              initialZoom: 13.8,
              onMapReady: () {
                _mapReady = true;
                _fitMap();
              },
            ),
            children: [
              MapboxTiles.layer(
                style: MapboxStyle.streets,
                userAgentPackageName: 'iq.rega.vendor',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          if (_loading)
            const Positioned(
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
                        Text('نوێکردنەوەی GPS...', style: TextStyle(fontWeight: FontWeight.w700)),
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
                color: const Color(0xFFFEF3C7),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    hasStore
                        ? 'هیچ شۆفێرێکی ئۆنلاین لەسەر نەخشە نییە. کاتێک شۆفێر Online + GPS دەکاتەوە، لێرە دەردەکەوێت.'
                        : 'شوێنی فرۆشگا لە سێرڤەر نییە — شۆفێرەکان دوای Online + GPS دەردەکەون (بێ شوێنی ساختە).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4, color: Color(0xFF92400E)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
