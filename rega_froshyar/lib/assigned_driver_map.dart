import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'map/rega_standard_map.dart';
import 'rega_mobile.dart';
import 'rega_i18n.dart';
import 'rega_colors.dart';

/// Customer-style live map in Vendor app: Store + Customer + Assigned Driver GPS for one order.
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
    this.height = 220,
  });

  @override
  State<AssignedDriverMap> createState() => _AssignedDriverMapState();
}

class _AssignedDriverMapState extends State<AssignedDriverMap> {
  final GlobalKey<RegaStandardMapState> _regaMapKey = GlobalKey();
  Timer? _poll;
  double? _driverLat;
  double? _driverLng;
  String _status = '';
  bool _live = false;
  bool _mapReady = false;

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
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    _fitIfNeeded();
  }

  Future<void> _fitIfNeeded() async {
    final points = <LatLng>[];
    if (_valid(widget.storeLat, widget.storeLng)) {
      points.add(LatLng(widget.storeLat!, widget.storeLng!));
    }
    if (_valid(widget.customerLat, widget.customerLng)) {
      points.add(LatLng(widget.customerLat!, widget.customerLng!));
    }
    if (_valid(_driverLat, _driverLng)) {
      points.add(LatLng(_driverLat!, _driverLng!));
    }
    if (!_mapReady || points.isEmpty) return;
    await _regaMapKey.currentState?.fitPoints(
      points,
      padding: const EdgeInsets.fromLTRB(32, 54, 32, 32),
    );
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
      final lat = (driver['lat'] as num?)?.toDouble() ??
          (data['driver_lat'] as num?)?.toDouble();
      final lng = (driver['lng'] as num?)?.toDouble() ??
          (data['driver_lng'] as num?)?.toDouble();
      setState(() {
        if (lat != null && lng != null) {
          _driverLat = lat;
          _driverLng = lng;
        }
        _status = (data['status'] ?? data['driver_status'] ?? '').toString();
        _live = driver['is_live_captain'] == true || (lat != null && lng != null);
      });
    } catch (_) {}
  }

  bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && lat.abs() > 0.01 && lng.abs() > 0.01;

  Marker _pinMarker({
    required LatLng point,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 96,
      height: 66,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  @override
  Widget build(BuildContext context) {
    final hasStore = _valid(widget.storeLat, widget.storeLng);
    final hasCustomer = _valid(widget.customerLat, widget.customerLng);
    final hasDriver = _valid(_driverLat, _driverLng);

    final storePt = hasStore ? LatLng(widget.storeLat!, widget.storeLng!) : null;
    final customerPt =
        hasCustomer ? LatLng(widget.customerLat!, widget.customerLng!) : null;
    final driverPt = hasDriver ? LatLng(_driverLat!, _driverLng!) : null;

    final markers = <Marker>[
      if (storePt != null)
        _pinMarker(
          point: storePt,
          icon: Icons.storefront_rounded,
          color: const Color(0xFFEA580C),
          label: 'فرۆشگا',
        ),
      if (customerPt != null)
        _pinMarker(
          point: customerPt,
          icon: Icons.home_rounded,
          color: const Color(0xFF0284C7),
          label: 'کڕیار',
        ),
      if (driverPt != null)
        _pinMarker(
          point: driverPt,
          icon: Icons.two_wheeler_rounded,
          color: const Color(0xFF16A34A),
          label: widget.driverName?.isNotEmpty == true
              ? widget.driverName!
              : 'گەیاندن',
        ),
    ];

    final polylines = <Polyline>[
      if (storePt != null && driverPt != null && customerPt != null)
        Polyline(
          points: [storePt, driverPt, customerPt],
          color: const Color(0xFF16A34A),
          strokeWidth: 4.5,
          borderColor: const Color(0xFF064E3B),
          borderStrokeWidth: 1.5,
        )
      else if (storePt != null && customerPt != null)
        Polyline(
          points: [storePt, customerPt],
          color: const Color(0xFFF59E0B),
          strokeWidth: 4.0,
        ),
    ];

    final center = driverPt ?? storePt ?? customerPt ?? _kalarOverview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.height,
            child: RegaStandardMap(
              key: _regaMapKey,
              center: center,
              zoom: 14.5,
              showCustomerControls: true,
              topControlsOffset: 8,
              bottomControlsOffset: 10,
              onMapReady: _onMapReady,
              polylines: polylines,
              markers: markers,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tx(_live
              ? 'شوێنی شۆفێر زیندووە ${_status.isNotEmpty ? "• $_status" : ""}'
              : (hasDriver
                  ? 'دوایین شوێنی شۆفێر ${_status.isNotEmpty ? "• $_status" : ""}'
                  : 'چاوەڕوانی GPSی ڕاستەقینەی شۆفێر...')),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _live
                ? RC.bg(const Color(0xFF166534))
                : RC.bg(const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}
