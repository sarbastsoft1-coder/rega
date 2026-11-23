import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'map/rega_standard_map.dart';
import 'rega_mobile.dart';

import 'rega_i18n.dart';
import 'rega_colors.dart';

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
  final GlobalKey<RegaStandardMapState> _regaMapKey = GlobalKey();
  mb.MapboxMap? _mbMap;
  mb.PolylineAnnotationManager? _polyMgr;
  mb.PointAnnotationManager? _pointMgr;
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
    super.dispose();
  }

  mb.Point _mbPoint(LatLng p) =>
      mb.Point(coordinates: mb.Position(p.longitude, p.latitude));

  mb.LineString _mbLine(List<LatLng> pts) => mb.LineString(
        coordinates: pts
            .map((p) => mb.Position(p.longitude, p.latitude))
            .toList(),
      );

  int _colorInt(Color c) => RC.bg(c).toARGB32();

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _mbMap = map;
    _mapReady = true;
    if (!kIsWeb) {
      try {
        _polyMgr = await map.annotations.createPolylineAnnotationManager();
        _pointMgr = await map.annotations.createPointAnnotationManager();
      } catch (_) {}
    }
    await _syncOverlays();
    await _fitIfNeeded();
  }

  Future<void> _syncOverlays() async {
    if (kIsWeb) return;
    final pts = _pointMgr;
    final lines = _polyMgr;
    if (pts == null) return;

    try {
      await pts.deleteAll();
      await lines?.deleteAll();
    } catch (_) {}

    final hasStore = _valid(widget.storeLat, widget.storeLng);
    final hasCustomer = _valid(widget.customerLat, widget.customerLng);
    final hasDriver = _valid(_driverLat, _driverLng);

    if (hasStore) {
      try {
        await pts.create(
          mb.PointAnnotationOptions(
            geometry: _mbPoint(LatLng(widget.storeLat!, widget.storeLng!)),
            iconColor: _colorInt(const Color(0xFFEA580C)),
            iconSize: 1.0,
          ),
        );
      } catch (_) {}
    }
    if (hasCustomer) {
      try {
        await pts.create(
          mb.PointAnnotationOptions(
            geometry: _mbPoint(LatLng(widget.customerLat!, widget.customerLng!)),
            iconColor: _colorInt(const Color(0xFF2563EB)),
            iconSize: 1.0,
          ),
        );
      } catch (_) {}
    }
    if (hasDriver) {
      try {
        await pts.create(
          mb.PointAnnotationOptions(
            geometry: _mbPoint(LatLng(_driverLat!, _driverLng!)),
            textField: tx(widget.driverName?.isNotEmpty == true ? widget.driverName! : 'شۆفێر'),
            textSize: 9,
            textColor: _colorInt(Colors.white),
            textHaloColor: _colorInt(const Color(0xFF064E3B)),
            textHaloWidth: 1,
            textOffset: [0, -1.5],
            iconColor: _colorInt(const Color(0xFF16A34A)),
            iconSize: 1.1,
          ),
        );
      } catch (_) {}
    }

    if (lines != null &&
        hasStore &&
        hasCustomer &&
        hasDriver) {
      try {
        await lines.create(
          mb.PolylineAnnotationOptions(
            geometry: _mbLine([
              LatLng(widget.storeLat!, widget.storeLng!),
              LatLng(_driverLat!, _driverLng!),
              LatLng(widget.customerLat!, widget.customerLng!),
            ]),
            lineColor: _colorInt(const Color(0xFF16A34A)),
            lineWidth: 3.5,
          ),
        );
      } catch (_) {}
    }
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
    final map = _mbMap;
    if (map == null || points.length < 2) return;
    try {
      final camera = await map.cameraForCoordinates(
        points.map(_mbPoint).toList(),
        mb.MbxEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
        null,
        null,
      );
      await map.setCamera(camera);
    } catch (_) {}
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
        }
        _status = (data['status'] ?? data['driver_status'] ?? '').toString();
        _live = driver['is_live_captain'] == true;
      });
      await _syncOverlays();
      if (_mapReady && lat != null && lng != null) {
        try {
          await _regaMapKey.currentState?.moveTo(LatLng(lat, lng));
        } catch (_) {}
      }
    } catch (_) {}
  }

  bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && lat.abs() > 0.01 && lng.abs() > 0.01;

  @override
  Widget build(BuildContext context) {
    final hasStore = _valid(widget.storeLat, widget.storeLng);
    final hasCustomer = _valid(widget.customerLat, widget.customerLng);
    final hasDriver = _valid(_driverLat, _driverLng);

    final points = <LatLng>[
      if (hasStore) LatLng(widget.storeLat!, widget.storeLng!),
      if (hasCustomer) LatLng(widget.customerLat!, widget.customerLng!),
      if (hasDriver) LatLng(_driverLat!, _driverLng!),
    ];
    final center = points.isNotEmpty ? points.first : _kalarOverview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: widget.height,
            child: RegaStandardMap(
              key: _regaMapKey,
              center: center,
              zoom: points.length > 1 ? 13.5 : 14.0,
              showLayersFab: false,
              onMapCreated: _onMapCreated,
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
            color: _live ? RC.bg(Color(0xFF166534)) : RC.bg(Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}