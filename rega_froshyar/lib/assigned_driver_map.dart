import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'map/mapbox_tiles.dart';
import 'rega_mobile.dart';

/// Compact live map: store + customer + assigned driver GPS for one order.
/// Never invents fake places — markers only appear when real coords exist.
class AssignedDriverMap extends StatefulWidget {
  final String orderNumber;
  final double? storeLat;
  final double? storeLng;
  final double? customerLat;
  final double? customerLng;
  final double? initialDriverLat;
  final double? initialDriverLng;
  final String? driverName;
  final double height;

  const AssignedDriverMap({
    super.key,
    required this.orderNumber,
    this.storeLat,
    this.storeLng,
    this.customerLat,
    this.customerLng,
    this.initialDriverLat,
    this.initialDriverLng,
    this.driverName,
    this.height = 180,
  });

  @override
  State<AssignedDriverMap> createState() => _AssignedDriverMapState();
}

class _AssignedDriverMapState extends State<AssignedDriverMap> {
  final MapController _map = MapController();
  Timer? _poll;
  double? _driverLat;
  double? _driverLng;
  String _status = '';
  bool _live = false;
  bool _mapReady = false;

  /// Downtown کەلار overview only (no fake driver/store pin).
  static const LatLng _kalarOverview = LatLng(34.6295, 45.3159);

  @override
  void initState() {
    super.initState();
    _driverLat = widget.initialDriverLat;
    _driverLng = widget.initialDriverLng;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
    _fetch();
  }

  @override
  void didUpdateWidget(covariant AssignedDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderNumber != widget.orderNumber) {
      _driverLat = widget.initialDriverLat;
      _driverLng = widget.initialDriverLng;
      _fetch();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _map.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final ref = widget.orderNumber.replaceAll('#', '').trim();
    if (ref.isEmpty) return;
    try {
      final res = await http
          .get(
            Uri.parse('${RegaApiHost.apiV1}/live-telemetry/$ref'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
      if (!mounted || res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return;
      final driver = (data['driver'] as Map<String, dynamic>?) ?? const {};
      final lat = (driver['lat'] as num?)?.toDouble();
      final lng = (driver['lng'] as num?)?.toDouble();
      setState(() {
        if (lat != null && lng != null) {
          _driverLat = lat;
          _driverLng = lng;
          if (_mapReady) {
            try {
              _map.move(LatLng(lat, lng), _map.camera.zoom);
            } catch (_) {}
          }
        }
        _status = (data['status'] ?? data['driver_status'] ?? '').toString();
        _live = driver['is_live_captain'] == true;
      });
    } catch (_) {}
  }

  bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && lat.abs() > 0.01 && lng.abs() > 0.01;

  @override
  Widget build(BuildContext context) {
    final hasStore = _valid(widget.storeLat, widget.storeLng);
    final hasCustomer = _valid(widget.customerLat, widget.customerLng);
    final hasDriver = _valid(_driverLat, _driverLng);

    final store = hasStore ? LatLng(widget.storeLat!, widget.storeLng!) : null;
    final customer =
        hasCustomer ? LatLng(widget.customerLat!, widget.customerLng!) : null;
    final driver = hasDriver ? LatLng(_driverLat!, _driverLng!) : null;

    final points = <LatLng>[
      if (store != null) store,
      if (customer != null) customer,
      if (driver != null) driver,
    ];
    final center = points.isNotEmpty ? points.first : _kalarOverview;

    final markers = <Marker>[
      if (store != null)
        Marker(
          point: store,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
          ),
        ),
      if (customer != null)
        Marker(
          point: customer,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
          ),
        ),
      if (driver != null)
        Marker(
          point: driver,
          width: 96,
          height: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _live ? const Color(0xFF064E3B) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.driverName?.isNotEmpty == true ? widget.driverName! : 'شۆفێر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
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
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: widget.height,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: points.length > 1 ? 13.5 : 14.0,
                onMapReady: () {
                  _mapReady = true;
                  if (points.length >= 2) {
                    try {
                      _map.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(points),
                          padding: const EdgeInsets.all(28),
                          maxZoom: 16,
                        ),
                      );
                    } catch (_) {}
                  }
                },
              ),
              children: [
                MapboxTiles.layer(
                  style: MapboxStyle.streets,
                  userAgentPackageName: 'iq.rega.vendor.order',
                ),
                if (store != null && driver != null && customer != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [store, driver, customer],
                        strokeWidth: 3.5,
                        color: const Color(0xFF16A34A),
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _live
              ? 'شوێنی شۆفێر زیندووە ${_status.isNotEmpty ? "• $_status" : ""}'
              : (hasDriver
                  ? 'دوایین شوێنی شۆفێر ${_status.isNotEmpty ? "• $_status" : ""}'
                  : 'چاوەڕوانی GPSی ڕاستەقینەی شۆفێر...'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _live ? const Color(0xFF166534) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
