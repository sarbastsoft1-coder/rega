import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'mapbox_tiles.dart';
import 'rega_map_styles.dart';

/// Unified Customer-style Mapbox raster map host (`FlutterMap` + `MapboxTiles`)
/// used across REGA Customer, Delivery, Vendor, and Admin (Web + Android + iOS).
class RegaStandardMap extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final RegaMapStyleId initialStyle;
  final VoidCallback? onMapReady;
  final ValueChanged<bool>? onUserGesture;
  final bool showLayersFab;
  final bool showCustomerControls;
  final double topControlsOffset;
  final double bottomControlsOffset;
  final ValueChanged<RegaMapStyleId>? onStyleChanged;
  final ValueChanged<LatLng>? onMyLocationFound;
  final List<Polyline> polylines;
  final List<Marker> markers;
  final List<CircleMarker> circles;

  const RegaStandardMap({
    super.key,
    required this.center,
    this.zoom = 14.5,
    this.initialStyle = RegaMapStyles.defaultTracking,
    this.onMapReady,
    this.onUserGesture,
    this.showLayersFab = false,
    this.showCustomerControls = true,
    this.topControlsOffset = 12,
    this.bottomControlsOffset = 16,
    this.onStyleChanged,
    this.onMyLocationFound,
    this.polylines = const [],
    this.markers = const [],
    this.circles = const [],
  });

  @override
  State<RegaStandardMap> createState() => RegaStandardMapState();
}

class RegaStandardMapState extends State<RegaStandardMap> {
  final MapController _mapController = MapController();
  late RegaMapStyleId _styleId;
  bool _ready = false;
  bool _locating = false;
  double _currentZoom = 14.5;
  LatLng _currentCenter = const LatLng(34.6295, 45.3159);
  LatLng? _myGpsPos;

  @override
  void initState() {
    super.initState();
    _styleId = widget.initialStyle == RegaMapStyleId.satellite
        ? RegaMapStyleId.satellite
        : RegaMapStyleId.map;
    _currentZoom = widget.zoom;
    _currentCenter = widget.center;
  }

  RegaMapStyleId get styleId => _styleId;
  double get currentZoom => _currentZoom;
  LatLng get currentCenter => _currentCenter;

  MapboxStyle _toRasterStyle(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.satellite => MapboxStyle.satellite,
      RegaMapStyleId.outdoors => MapboxStyle.outdoors,
      RegaMapStyleId.dark => MapboxStyle.streets,
      RegaMapStyleId.map => MapboxStyle.streets,
    };
  }

  Future<void> moveTo(LatLng center, {double? zoom}) async {
    if (!_ready) return;
    try {
      final z = (zoom ?? _currentZoom).clamp(5.0, 20.0);
      _mapController.move(center, z);
      _currentCenter = center;
      _currentZoom = z;
    } catch (_) {}
  }

  Future<void> fitPoints(
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.fromLTRB(44, 90, 44, 120),
    double maxZoom = 16.5,
    double minZoom = 11.5,
  }) async {
    if (!_ready || points.isEmpty) return;
    final valid = points
        .where((p) => !p.latitude.isNaN && !p.longitude.isNaN)
        .toList();
    if (valid.isEmpty) return;
    if (valid.length == 1) {
      await moveTo(valid.first, zoom: 15.2);
      return;
    }
    try {
      var minLat = valid.first.latitude;
      var maxLat = valid.first.latitude;
      var minLng = valid.first.longitude;
      var maxLng = valid.first.longitude;
      for (final p in valid) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      if ((maxLat - minLat).abs() < 0.0002 && (maxLng - minLng).abs() < 0.0002) {
        await moveTo(valid.first, zoom: 15.2);
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
          padding: padding,
          maxZoom: maxZoom,
          minZoom: minZoom,
        ),
      );
    } catch (_) {
      await moveTo(valid.first, zoom: 14.8);
    }
  }

  Future<void> applyStyle(RegaMapStyleId id) async {
    if (_styleId == id) return;
    setState(() => _styleId = id);
    widget.onStyleChanged?.call(id);
  }

  Future<void> toggleSatellite() async {
    await applyStyle(
      _styleId == RegaMapStyleId.satellite
          ? RegaMapStyleId.map
          : RegaMapStyleId.satellite,
    );
  }

  Future<void> cycleStyle() async {
    await toggleSatellite();
  }

  Future<void> zoomBy(double delta) async {
    if (!_ready) return;
    try {
      final next = (_currentZoom + delta).clamp(5.0, 20.0);
      _mapController.move(_currentCenter, next);
      _currentZoom = next;
    } catch (_) {}
  }

  Future<void> goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (widget.markers.length > 1) {
        await fitPoints(widget.markers.map((m) => m.point).toList());
      } else {
        await moveTo(widget.center, zoom: widget.zoom);
      }
      widget.onMyLocationFound?.call(widget.center);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _customerChip({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return Material(
      color: active ? activeColor : Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F172A),
                  ),
                )
              else
                Icon(icon, size: 17, color: const Color(0xFF0F172A)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerZoomFab(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF0F172A), size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFAC800);
    final isSat = _styleId == RegaMapStyleId.satellite;
    final rasterStyle = _toRasterStyle(_styleId);
    final allMarkers = <Marker>[
      ...widget.markers,
      if (_myGpsPos != null)
        Marker(
          point: _myGpsPos!,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
          ),
        ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            minZoom: 5,
            maxZoom: 20,
            backgroundColor: const Color(0xFFE8EEF4),
            onMapReady: () {
              _ready = true;
              _currentCenter = widget.center;
              _currentZoom = widget.zoom;
              widget.onMapReady?.call();
            },
            onPositionChanged: (camera, hasGesture) {
              _currentCenter = camera.center;
              _currentZoom = camera.zoom;
              if (hasGesture) {
                widget.onUserGesture?.call(true);
              }
            },
          ),
          children: [
            MapboxTiles.layer(
              style: rasterStyle,
              userAgentPackageName: 'tech.rega.admin',
              fallbackStyle: MapboxStyle.outdoors,
            ),
            if (widget.circles.isNotEmpty)
              CircleLayer(circles: widget.circles),
            if (widget.polylines.isNotEmpty)
              PolylineLayer(polylines: widget.polylines),
            if (allMarkers.isNotEmpty)
              MarkerLayer(markers: allMarkers),
            RichAttributionWidget(
              attributions: const [
                TextSourceAttribution('Mapbox'),
                TextSourceAttribution('OpenStreetMap'),
              ],
            ),
          ],
        ),
        if (widget.showCustomerControls) ...[
          Positioned(
            top: widget.topControlsOffset,
            left: 10,
            right: 10,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _customerChip(
                    label: 'سەتەلایت',
                    icon: Icons.satellite_alt_rounded,
                    active: isSat,
                    activeColor: gold,
                    onTap: toggleSatellite,
                  ),
                  const Spacer(),
                  _customerChip(
                    label: 'شوێنەکەم',
                    icon: Icons.my_location_rounded,
                    active: true,
                    activeColor: gold,
                    busy: _locating,
                    onTap: goToMyLocation,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: widget.bottomControlsOffset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _customerZoomFab(Icons.add_rounded, () => zoomBy(1)),
                const SizedBox(height: 10),
                _customerZoomFab(Icons.remove_rounded, () => zoomBy(-1)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
