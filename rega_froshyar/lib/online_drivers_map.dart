import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map/rega_standard_map.dart';
import 'vendor_api_service.dart';
import 'rega_i18n.dart';
import 'rega_colors.dart';

/// Customer-style live GPS map of online delivery captains for the Seller/Vendor app.
class OnlineDriversMapPage extends StatefulWidget {
  const OnlineDriversMapPage({super.key});

  @override
  State<OnlineDriversMapPage> createState() => _OnlineDriversMapPageState();
}

class _OnlineDriversMapPageState extends State<OnlineDriversMapPage> {
  final GlobalKey<RegaStandardMapState> _regaMapKey = GlobalKey();
  Timer? _poll;
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic>? _store;
  int _onlineCount = 0;
  bool _loading = true;
  bool _mapReady = false;
  bool _didInitialFit = false;

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

  bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && lat.abs() > 0.01 && lng.abs() > 0.01;

  void _onMapReady() {
    _mapReady = true;
    _fitMap();
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
            final lat = (d['lat'] as num?)?.toDouble() ??
                (d['current_lat'] as num?)?.toDouble();
            final lng = (d['lng'] as num?)?.toDouble() ??
                (d['current_lng'] as num?)?.toDouble();
            return _valid(lat, lng);
          })
          .toList();
      _onlineCount = (data['online_count'] as num?)?.toInt() ??
          _drivers.where((d) => d['is_online'] == true).length;
    });

    if (_mapReady && (!_didInitialFit || !silent)) {
      _didInitialFit = true;
      await _fitMap();
    }
  }

  Future<void> _fitMap() async {
    if (!_mapReady) return;
    final points = <LatLng>[];
    final storeLat = (_store?['lat'] as num?)?.toDouble();
    final storeLng = (_store?['lng'] as num?)?.toDouble();
    if (_valid(storeLat, storeLng)) {
      points.add(LatLng(storeLat!, storeLng!));
    }
    for (final d in _drivers) {
      final lat = (d['lat'] as num?)?.toDouble() ??
          (d['current_lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble() ??
          (d['current_lng'] as num?)?.toDouble();
      if (_valid(lat, lng)) points.add(LatLng(lat!, lng!));
    }
    if (points.isEmpty) {
      await _regaMapKey.currentState?.moveTo(_kalarOverview, zoom: 13.8);
      return;
    }
    await _regaMapKey.currentState?.fitPoints(
      points,
      padding: const EdgeInsets.fromLTRB(44, 80, 44, 110),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final storeLat = (_store?['lat'] as num?)?.toDouble();
    final storeLng = (_store?['lng'] as num?)?.toDouble();
    if (_valid(storeLat, storeLng)) {
      markers.add(
        Marker(
          point: LatLng(storeLat!, storeLng!),
          width: 110,
          height: 72,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tx((_store?['name'] ?? 'فرۆشگا').toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    for (final d in _drivers) {
      final lat = (d['lat'] as num?)?.toDouble() ??
          (d['current_lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble() ??
          (d['current_lng'] as num?)?.toDouble();
      if (!_valid(lat, lng)) continue;
      final isOnline = d['is_online'] == true;
      final name = (d['name'] ?? d['driver_code'] ?? 'کاپتن').toString();
      final meters = (d['distance_meters'] as num?)?.toInt();
      final label = meters != null ? '$name • ${meters}m' : name;

      markers.add(
        Marker(
          point: LatLng(lat!, lng!),
          width: 120,
          height: 74,
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
                  style: TextStyle(
                    color: isOnline ? const Color(0xFF00E676) : Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF00E676)
                      : const Color(0xFF64748B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F172A), width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Icon(
                  Icons.two_wheeler_rounded,
                  color: isOnline ? const Color(0xFF0F172A) : Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final storeLat = (_store?['lat'] as num?)?.toDouble();
    final storeLng = (_store?['lng'] as num?)?.toDouble();
    final hasStore = _valid(storeLat, storeLng);
    final storePt = hasStore ? LatLng(storeLat!, storeLng!) : null;

    return Scaffold(
      backgroundColor: RC.bg(const Color(0xFFF8FAFC)),
      appBar: AppBar(
        backgroundColor: RC.bg(const Color(0xFFEA580C)),
        foregroundColor: RC.fg(Colors.white),
        title: Text(
          tx('شۆفێرە ئۆنلاینەکان ($_onlineCount)'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: tx('پیشاندانی هەموو'),
            onPressed: _fitMap,
            icon: const Icon(Icons.route_rounded),
          ),
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
            zoom: 14.2,
            showCustomerControls: true,
            onMapReady: _onMapReady,
            markers: _buildMarkers(),
          ),
          if (_loading)
            Positioned(
              top: 64,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tx('نوێکردنەوەی GPS...'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                color: RC.bg(const Color(0xFFFEF3C7)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    tx(hasStore
                        ? 'هیچ شۆفێرێکی ئۆنلاین لەسەر نەخشە نییە. کاتێک شۆفێر Online + GPS دەکاتەوە، لێرە دەردەکەوێت.'
                        : 'شوێنی فرۆشگا لە سێرڤەر نییە — شۆفێرەکان دوای Online + GPS دەردەکەون.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: RC.fg(const Color(0xFF92400E)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
