import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum CaptainRouteStage {
  assigned,
  arrivingPickup,
  arrivedPickup,
  pickedUp,
  onTheWay,
  arrivedCustomer,
  delivered,
}

class CaptainLiveMapWidget extends StatefulWidget {
  final String orderNumber;
  final CaptainRouteStage stage;
  final String merchantName;
  final String merchantAddress;
  final String customerName;
  final String customerAddress;
  final String deliveryPin;
  final double storeLat;
  final double storeLng;
  final double customerLat;
  final double customerLng;
  final bool isOnline;
  final String apiBaseUrl;
  final ValueChanged<CaptainRouteStage> onStageAutoReached;
  final VoidCallback onArrivedPromptPin;
  final void Function(Map<String, dynamic> syncedOrder)? onNewBackendOrderFound;

  const CaptainLiveMapWidget({
    super.key,
    required this.orderNumber,
    required this.stage,
    required this.merchantName,
    required this.merchantAddress,
    required this.customerName,
    required this.customerAddress,
    required this.deliveryPin,
    this.storeLat = 34.6836,
    this.storeLng = 45.3189,
    this.customerLat = 34.6912,
    this.customerLng = 45.3264,
    this.isOnline = true,
    this.apiBaseUrl = 'http://127.0.0.1:8001/api/v1',
    required this.onStageAutoReached,
    required this.onArrivedPromptPin,
    this.onNewBackendOrderFound,
  });

  @override
  State<CaptainLiveMapWidget> createState() => _CaptainLiveMapWidgetState();
}

class _CaptainLiveMapWidgetState extends State<CaptainLiveMapWidget>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  late AnimationController _pulseController;
  late AnimationController _glideController;

  Timer? _secondTicker;
  StreamSubscription<Position>? _gpsSub;

  // Map appearance & camera controls
  int _mapStyleIndex = 0; // 0: Voyager HD, 1: Dark Night Radar, 2: OSM Kalar
  bool _followCaptain = true;
  bool _autoDriveSimulation = true;
  bool _mapReady = false;
  bool _backendSynced = false;
  bool _promptedPinOnce = false;

  // Coordinates & Street Polyline
  late LatLng _dispatchOrigin;
  late LatLng _storePoint;
  late LatLng _customerPoint;

  List<LatLng> _legToStore = [];
  List<LatLng> _legToCustomer = [];

  LatLng _prevDriverPos = const LatLng(34.6798, 45.3145);
  LatLng _targetDriverPos = const LatLng(34.6798, 45.3145);
  LatLng _displayDriverPos = const LatLng(34.6798, 45.3145);

  double _headingDeg = 44.0;
  double _speedKmh = 32.0;
  int _etaSeconds = 120;
  int _remainingMeters = 1350;
  int _elapsedSeconds = 0;

  double _leg1Progress = 0.0; // 0.0 -> 1.0 (Captain -> Store)
  double _leg2Progress = 0.0; // 0.0 -> 1.0 (Store -> Customer)

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..addListener(_onGlideFrame);

    _initCoordinatesAndRoutes();
    _syncStageAnchors(widget.stage, jumpImmediately: true);
    _startRealGpsIfAvailable();
    _startOneSecondEngine();
  }

  @override
  void didUpdateWidget(covariant CaptainLiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderNumber != widget.orderNumber ||
        oldWidget.storeLat != widget.storeLat ||
        oldWidget.customerLat != widget.customerLat) {
      _promptedPinOnce = false;
      _initCoordinatesAndRoutes();
      _syncStageAnchors(widget.stage, jumpImmediately: true);
    } else if (oldWidget.stage != widget.stage) {
      _syncStageAnchors(widget.stage, jumpImmediately: false);
    }
  }

  @override
  void dispose() {
    _secondTicker?.cancel();
    _gpsSub?.cancel();
    _pulseController.dispose();
    _glideController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _initCoordinatesAndRoutes() {
    _storePoint = LatLng(widget.storeLat, widget.storeLng);
    _customerPoint = LatLng(widget.customerLat, widget.customerLng);
    _dispatchOrigin = LatLng(widget.storeLat - 0.0038, widget.storeLng - 0.0044);

    _legToStore = _buildRealisticKalarRoad(_dispatchOrigin, _storePoint, steps: 28);
    _legToCustomer = _buildRealisticKalarRoad(_storePoint, _customerPoint, steps: 46);

    _fetchOsrmStreetRoutes();
  }

  List<LatLng> _buildRealisticKalarRoad(LatLng start, LatLng end, {int steps = 32}) {
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    // Realistic Kalar avenue bends (60m ring road -> Sirwan avenue -> neighborhood street)
    final p1 = LatLng(start.latitude + dLat * 0.28 + 0.00045, start.longitude + dLng * 0.18 - 0.00025);
    final p2 = LatLng(start.latitude + dLat * 0.58 - 0.00020, start.longitude + dLng * 0.54 + 0.00042);
    final p3 = LatLng(start.latitude + dLat * 0.84 + 0.00025, start.longitude + dLng * 0.82 - 0.00018);

    final control = [start, p1, p2, p3, end];
    final dense = <LatLng>[];
    final perSeg = math.max(4, steps ~/ (control.length - 1));
    for (var i = 0; i < control.length - 1; i++) {
      final a = control[i];
      final b = control[i + 1];
      for (var s = 0; s < perSeg; s++) {
        final t = s / perSeg;
        dense.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    dense.add(end);
    return dense;
  }

  Future<void> _fetchOsrmStreetRoutes() async {
    try {
      final leg1Url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_dispatchOrigin.longitude},${_dispatchOrigin.latitude};'
        '${_storePoint.longitude},${_storePoint.latitude}'
        '?overview=full&geometries=geojson',
      );
      final leg2Url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_storePoint.longitude},${_storePoint.latitude};'
        '${_customerPoint.longitude},${_customerPoint.latitude}'
        '?overview=full&geometries=geojson',
      );

      final responses = await Future.wait([
        http.get(leg1Url).timeout(const Duration(seconds: 4)),
        http.get(leg2Url).timeout(const Duration(seconds: 4)),
      ]);

      if (!mounted) return;

      final parsed1 = _parseOsrmCoords(responses[0]);
      final parsed2 = _parseOsrmCoords(responses[1]);

      setState(() {
        if (parsed1.length >= 4) _legToStore = _densifyPolyline(parsed1, minPoints: 30);
        if (parsed2.length >= 4) _legToCustomer = _densifyPolyline(parsed2, minPoints: 50);
      });
    } catch (_) {
      // Fallback Kalar street route is already active
    }
  }

  List<LatLng> _parseOsrmCoords(http.Response res) {
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return [];
    final geom = (routes.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List<dynamic>?;
    if (coords == null) return [];
    return coords.map((c) {
      final pair = c as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
  }

  List<LatLng> _densifyPolyline(List<LatLng> pts, {int minPoints = 40}) {
    if (pts.length >= minPoints || pts.length < 2) return pts;
    final out = <LatLng>[];
    final mult = (minPoints / pts.length).ceil().clamp(2, 8);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      for (var k = 0; k < mult; k++) {
        final t = k / mult;
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    out.add(pts.last);
    return out;
  }

  void _syncStageAnchors(CaptainRouteStage stage, {required bool jumpImmediately}) {
    LatLng nextTarget = _displayDriverPos;
    switch (stage) {
      case CaptainRouteStage.assigned:
        _leg1Progress = 0.0;
        _leg2Progress = 0.0;
        nextTarget = _legToStore.isNotEmpty ? _legToStore.first : _dispatchOrigin;
        break;
      case CaptainRouteStage.arrivingPickup:
        if (_leg1Progress < 0.05) _leg1Progress = 0.08;
        nextTarget = _pointAlong(_legToStore, _leg1Progress);
        break;
      case CaptainRouteStage.arrivedPickup:
      case CaptainRouteStage.pickedUp:
        _leg1Progress = 1.0;
        _leg2Progress = 0.0;
        nextTarget = _storePoint;
        _speedKmh = 0.0;
        break;
      case CaptainRouteStage.onTheWay:
        _leg1Progress = 1.0;
        if (_leg2Progress < 0.03) _leg2Progress = 0.04;
        nextTarget = _pointAlong(_legToCustomer, _leg2Progress);
        break;
      case CaptainRouteStage.arrivedCustomer:
      case CaptainRouteStage.delivered:
        _leg1Progress = 1.0;
        _leg2Progress = 1.0;
        nextTarget = _customerPoint;
        _speedKmh = 0.0;
        _etaSeconds = 0;
        _remainingMeters = 0;
        break;
    }

    if (jumpImmediately) {
      _prevDriverPos = nextTarget;
      _targetDriverPos = nextTarget;
      _displayDriverPos = nextTarget;
    } else {
      _animateDriverTo(nextTarget);
    }
    _recomputeMetrics();
  }

  Future<void> _startRealGpsIfAvailable() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) return; // Don't block UI with popup unless tapped
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        _gpsSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
          ),
        ).listen((pos) {
          // Only override Kalar coordinates if device is actually near Kalar!
          final inKalarBounds = pos.latitude > 34.55 &&
              pos.latitude < 34.80 &&
              pos.longitude > 45.20 &&
              pos.longitude < 45.48;
          if (inKalarBounds && !_autoDriveSimulation && mounted) {
            _speedKmh = math.max(0, pos.speed * 3.6);
            _animateDriverTo(LatLng(pos.latitude, pos.longitude));
            _recomputeMetrics();
          }
        });
      }
    } catch (_) {}
  }

  void _startOneSecondEngine() {
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.isOnline) return;
      _elapsedSeconds += 1;

      if (_autoDriveSimulation && widget.stage != CaptainRouteStage.delivered) {
        _stepSimulationOneSecond();
      } else {
        _recomputeMetrics();
      }

      _pushOneSecondTelemetryToBackend();
    });
  }

  void _stepSimulationOneSecond() {
    switch (widget.stage) {
      case CaptainRouteStage.assigned:
        // Auto-begin driving toward restaurant after 2 seconds
        if (_elapsedSeconds >= 2) {
          widget.onStageAutoReached(CaptainRouteStage.arrivingPickup);
        }
        break;

      case CaptainRouteStage.arrivingPickup:
        _leg1Progress = (_leg1Progress + 0.045).clamp(0.0, 1.0); // ~22s to store
        final nextPos = _pointAlong(_legToStore, _leg1Progress);
        _speedKmh = 28.0 + ((_elapsedSeconds % 5) * 1.4);
        _animateDriverTo(nextPos);
        if (_leg1Progress >= 1.0) {
          _speedKmh = 0.0;
          widget.onStageAutoReached(CaptainRouteStage.arrivedPickup);
        }
        break;

      case CaptainRouteStage.arrivedPickup:
        _speedKmh = 0.0;
        break;

      case CaptainRouteStage.pickedUp:
        // Smoothly transition into road navigation after pickup
        widget.onStageAutoReached(CaptainRouteStage.onTheWay);
        break;

      case CaptainRouteStage.onTheWay:
        _leg2Progress = (_leg2Progress + 0.022).clamp(0.0, 1.0); // ~45s real street drive
        final nextPos = _pointAlong(_legToCustomer, _leg2Progress);
        _speedKmh = 31.0 + ((_elapsedSeconds % 6) * 1.3);
        _animateDriverTo(nextPos);
        if (_leg2Progress >= 1.0) {
          _speedKmh = 0.0;
          widget.onStageAutoReached(CaptainRouteStage.arrivedCustomer);
          if (!_promptedPinOnce) {
            _promptedPinOnce = true;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && widget.stage == CaptainRouteStage.arrivedCustomer) {
                widget.onArrivedPromptPin();
              }
            });
          }
        }
        break;

      case CaptainRouteStage.arrivedCustomer:
      case CaptainRouteStage.delivered:
        _speedKmh = 0.0;
        break;
    }

    _recomputeMetrics();
  }

  void _animateDriverTo(LatLng next) {
    final movedMeters = _haversineMeters(_displayDriverPos, next);
    if (movedMeters > 0.4) {
      _headingDeg = _bearingDegrees(_displayDriverPos, next);
    }
    _prevDriverPos = _displayDriverPos;
    _targetDriverPos = next;
    _glideController.forward(from: 0.0);

    if (_followCaptain && _mapReady) {
      try {
        final curZoom = _mapController.camera.zoom;
        final safeZoom = (curZoom.isNaN || curZoom < 11.5) ? 15.6 : curZoom;
        _mapController.move(next, safeZoom);
      } catch (_) {}
    }
  }

  void _onGlideFrame() {
    if (!mounted) return;
    final t = Curves.linear.transform(_glideController.value);
    setState(() {
      _displayDriverPos = LatLng(
        _prevDriverPos.latitude + (_targetDriverPos.latitude - _prevDriverPos.latitude) * t,
        _prevDriverPos.longitude + (_targetDriverPos.longitude - _prevDriverPos.longitude) * t,
      );
    });
  }

  void _recomputeMetrics() {
    if (!mounted) return;
    if (widget.stage == CaptainRouteStage.delivered ||
        widget.stage == CaptainRouteStage.arrivedCustomer) {
      setState(() {
        _remainingMeters = 0;
        _etaSeconds = 0;
      });
      return;
    }

    double meters = 0;
    if (widget.stage == CaptainRouteStage.assigned ||
        widget.stage == CaptainRouteStage.arrivingPickup) {
      meters = _remainingPolylineMeters(_legToStore, _leg1Progress) +
          _remainingPolylineMeters(_legToCustomer, 0.0);
    } else if (widget.stage == CaptainRouteStage.arrivedPickup ||
        widget.stage == CaptainRouteStage.pickedUp) {
      meters = _remainingPolylineMeters(_legToCustomer, 0.0);
    } else {
      meters = _remainingPolylineMeters(_legToCustomer, _leg2Progress);
    }

    // Average Kalar urban scooter speed ~9.5 m/s (~34 km/h)
    final secs = (meters / 9.5).ceil();

    setState(() {
      _remainingMeters = meters.round();
      _etaSeconds = math.max(0, secs);
    });
  }

  Future<void> _pushOneSecondTelemetryToBackend() async {
    final cleanRef = widget.orderNumber.replaceAll('#', '').trim();
    if (cleanRef.isEmpty) return;

    final statusPair = _mapStageToBackendStrings(widget.stage);
    final totalPermille = widget.stage == CaptainRouteStage.delivered
        ? 1000
        : ((_leg1Progress * 350) + (_leg2Progress * 650)).round().clamp(0, 999);

    try {
      final res = await http
          .post(
            Uri.parse('${widget.apiBaseUrl}/live-telemetry/$cleanRef'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'driver_lat': _displayDriverPos.latitude,
              'driver_lng': _displayDriverPos.longitude,
              'driver_heading': double.parse(_headingDeg.toStringAsFixed(1)),
              'driver_speed_kmh': double.parse(_speedKmh.toStringAsFixed(1)),
              'eta_seconds': _etaSeconds,
              'distance_remaining_meters': _remainingMeters,
              'progress_permille': totalPermille,
              'status': statusPair.$1,
              'driver_status': statusPair.$2,
            }),
          )
          .timeout(const Duration(milliseconds: 900));

      if (mounted && res.statusCode >= 200 && res.statusCode < 300 && !_backendSynced) {
        setState(() => _backendSynced = true);
      }
    } catch (_) {
      if (mounted && _backendSynced) {
        setState(() => _backendSynced = false);
      }
    }
  }

  Future<void> syncLatestCustomerOrderFromServer() async {
    try {
      final res = await http
          .get(
            Uri.parse('${widget.apiBaseUrl}/live-telemetry/latest-active'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null && widget.onNewBackendOrderFound != null) {
          widget.onNewBackendOrderFound!(data);
        }
      }
    } catch (_) {}
  }

  (String, String) _mapStageToBackendStrings(CaptainRouteStage stage) {
    switch (stage) {
      case CaptainRouteStage.assigned:
        return ('preparing', 'driver_assigned');
      case CaptainRouteStage.arrivingPickup:
        return ('preparing', 'driver_arriving_pickup');
      case CaptainRouteStage.arrivedPickup:
        return ('ready', 'arrived_pickup');
      case CaptainRouteStage.pickedUp:
        return ('picked_up', 'picked_up');
      case CaptainRouteStage.onTheWay:
        return ('on_the_way', 'on_the_way');
      case CaptainRouteStage.arrivedCustomer:
        return ('arrived_customer', 'arrived_customer');
      case CaptainRouteStage.delivered:
        return ('delivered', 'delivered');
    }
  }

  LatLng _pointAlong(List<LatLng> pts, double progress) {
    if (pts.isEmpty) return _storePoint;
    if (pts.length == 1) return pts.first;
    final p = progress.clamp(0.0, 1.0);
    final exact = p * (pts.length - 1);
    final idx = exact.floor().clamp(0, pts.length - 2);
    final frac = exact - idx;
    final a = pts[idx];
    final b = pts[idx + 1];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * frac,
      a.longitude + (b.longitude - a.longitude) * frac,
    );
  }

  List<LatLng> _remainingSubPolyline(List<LatLng> pts, double progress, LatLng currentPos) {
    if (pts.length < 2 || progress >= 1.0) return [];
    final exact = progress.clamp(0.0, 1.0) * (pts.length - 1);
    final nextIdx = exact.ceil().clamp(1, pts.length - 1);
    return [currentPos, ...pts.sublist(nextIdx)];
  }

  List<LatLng> _traveledSubPolyline(List<LatLng> pts, double progress, LatLng currentPos) {
    if (pts.length < 2 || progress <= 0.0) return [];
    final exact = progress.clamp(0.0, 1.0) * (pts.length - 1);
    final lastIdx = exact.floor().clamp(0, pts.length - 1);
    return [...pts.sublist(0, lastIdx + 1), currentPos];
  }

  double _remainingPolylineMeters(List<LatLng> pts, double progress) {
    if (pts.length < 2 || progress >= 1.0) return 0;
    final sub = _remainingSubPolyline(pts, progress, _pointAlong(pts, progress));
    double sum = 0;
    for (var i = 0; i < sub.length - 1; i++) {
      sum += _haversineMeters(sub[i], sub[i + 1]);
    }
    return sum;
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _bearingDegrees(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  void _safeFitBounds(List<LatLng> points, {double maxZoom = 16.2, double minZoom = 11.5}) {
    if (!_mapReady || points.isEmpty) return;
    try {
      final valid = points.where((p) => !p.latitude.isNaN && !p.longitude.isNaN).toList();
      if (valid.isEmpty) return;
      if (valid.length == 1) {
        _mapController.move(valid.first, 15.6);
        return;
      }
      final bounds = LatLngBounds.fromPoints(valid);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          maxZoom: maxZoom,
          minZoom: minZoom,
        ),
      );
    } catch (_) {
      try {
        _mapController.move(_displayDriverPos, 15.6);
      } catch (_) {}
    }
  }

  void _fitFullRoute({bool keepFollowing = false}) {
    if (!_mapReady) return;
    _followCaptain = keepFollowing;
    _safeFitBounds([
      _displayDriverPos,
      _storePoint,
      _customerPoint,
    ]);
    setState(() {});
  }

  String _formatCountdown(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} کم';
    }
    return '$meters مەتر';
  }

  String get _tileUrl {
    switch (_mapStyleIndex) {
      case 1:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
      case 2:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      default:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
    }
  }

  String _navigationHeadline() {
    switch (widget.stage) {
      case CaptainRouteStage.assigned:
      case CaptainRouteStage.arrivingPickup:
        return 'بەرەو ${widget.merchantName}';
      case CaptainRouteStage.arrivedPickup:
        return 'لە بەردەم چێشتخانەیت — داواکاری وەربگرە';
      case CaptainRouteStage.pickedUp:
      case CaptainRouteStage.onTheWay:
        return 'بەرەو ماڵی ${widget.customerName}';
      case CaptainRouteStage.arrivedCustomer:
        return 'گەیشتیت! کۆدی ٤ ژمارەیی لە کڕیار وەربگرە';
      case CaptainRouteStage.delivered:
        return 'گەیاندن تەواوبوو بە سەرکەوتوویی!';
    }
  }

  IconData _navigationIcon() {
    switch (widget.stage) {
      case CaptainRouteStage.assigned:
      case CaptainRouteStage.arrivingPickup:
        return Icons.storefront_rounded;
      case CaptainRouteStage.arrivedPickup:
        return Icons.inventory_2_rounded;
      case CaptainRouteStage.pickedUp:
      case CaptainRouteStage.onTheWay:
        return Icons.navigation_rounded;
      case CaptainRouteStage.arrivedCustomer:
        return Icons.pin_rounded;
      case CaptainRouteStage.delivered:
        return Icons.verified_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToStore = widget.stage == CaptainRouteStage.assigned ||
        widget.stage == CaptainRouteStage.arrivingPickup;

    final polylines = <Polyline>[];

    // Traveled trail
    if (isToStore) {
      final traveled1 = _traveledSubPolyline(_legToStore, _leg1Progress, _displayDriverPos);
      final remain1 = _remainingSubPolyline(_legToStore, _leg1Progress, _displayDriverPos);
      if (traveled1.length >= 2) {
        polylines.add(Polyline(
          points: traveled1,
          strokeWidth: 5,
          color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
        ));
      }
      if (remain1.length >= 2) {
        polylines.add(Polyline(
          points: remain1,
          strokeWidth: 7,
          color: const Color(0xFFF59E0B),
          borderStrokeWidth: 2.5,
          borderColor: const Color(0xFF78350F),
        ));
      }
      if (_legToCustomer.length >= 2) {
        polylines.add(Polyline(
          points: _legToCustomer,
          strokeWidth: 5,
          pattern: StrokePattern.dashed(segments: const [14, 10]),
          color: const Color(0xFF16A34A).withValues(alpha: 0.7),
        ));
      }
    } else {
      if (_legToStore.length >= 2) {
        polylines.add(Polyline(
          points: _legToStore,
          strokeWidth: 4,
          color: const Color(0xFF94A3B8).withValues(alpha: 0.45),
        ));
      }
      final traveled2 = _traveledSubPolyline(_legToCustomer, _leg2Progress, _displayDriverPos);
      final remain2 = _remainingSubPolyline(_legToCustomer, _leg2Progress, _displayDriverPos);
      if (traveled2.length >= 2) {
        polylines.add(Polyline(
          points: traveled2,
          strokeWidth: 5,
          color: const Color(0xFF22C55E).withValues(alpha: 0.40),
        ));
      }
      if (remain2.length >= 2) {
        polylines.add(Polyline(
          points: remain2,
          strokeWidth: 7.5,
          color: const Color(0xFF00E676),
          borderStrokeWidth: 2.5,
          borderColor: const Color(0xFF065F46),
        ));
      }
    }

    return Stack(
      children: [
        // 1. Real Interactive Street Map of Kalar
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _displayDriverPos,
            initialZoom: 15.6,
            minZoom: 11.5,
            maxZoom: 18.5,
            backgroundColor: _mapStyleIndex == 1
                ? const Color(0xFF0F172A)
                : const Color(0xFFE2E8F0),
            onMapReady: () {
              _mapReady = true;
              _mapController.move(_displayDriverPos, 15.6);
              _followCaptain = true;
              Future.delayed(const Duration(milliseconds: 350), () {
                if (mounted && _mapReady) {
                  _safeFitBounds([
                    _displayDriverPos,
                    _storePoint,
                    _customerPoint,
                  ]);
                }
              });
            },
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followCaptain) {
                setState(() => _followCaptain = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl,
              fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: _mapStyleIndex == 2 ? const [] : const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'iq.rega.delivery',
              tileProvider: NetworkTileProvider(),
            ),
            PolylineLayer(polylines: polylines),
            MarkerLayer(
              markers: [
                // Store Marker (Pickup)
                Marker(
                  point: _storePoint,
                  width: 120,
                  height: 76,
                  alignment: Alignment.topCenter,
                  child: _MapPinBadge(
                    icon: Icons.storefront_rounded,
                    color: const Color(0xFFEA580C),
                    label: widget.merchantName,
                    isHighlighted: isToStore,
                  ),
                ),

                // Customer Marker (Dropoff)
                Marker(
                  point: _customerPoint,
                  width: 120,
                  height: 76,
                  alignment: Alignment.topCenter,
                  child: _MapPinBadge(
                    icon: Icons.home_rounded,
                    color: const Color(0xFF0284C7),
                    label: widget.customerName,
                    isHighlighted: !isToStore,
                  ),
                ),

                // Live 60fps Captain Motorcycle Marker with Sonar Pulse & Heading
                Marker(
                  point: _displayDriverPos,
                  width: 96,
                  height: 96,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final p = _pulseController.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 38 + (p * 44),
                            height: 38 + (p * 44),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00E676).withValues(alpha: (1 - p) * 0.38),
                            ),
                          ),
                          Transform.rotate(
                            angle: (_headingDeg * math.pi / 180.0),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F172A), width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Color(0xFF0F172A),
                                size: 24,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_speedKmh.toStringAsFixed(0)} km/h',
                                style: const TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),

        // 2. Top Turn-by-Turn Second-by-Second Navigation HUD
        Positioned(
          top: 12,
          left: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _navigationIcon(),
                        color: const Color(0xFF00E676),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _backendSynced
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFFFAC800),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _backendSynced
                                    ? 'GPS LIVE • چرکە بە چرکە هاوکاتە'
                                    : 'GPS LIVE • نەخشەی زیندووی کەلار',
                                style: const TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _navigationHeadline(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live Exact MM:SS Second-by-Second Countdown Box
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatCountdown(_etaSeconds),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              _formatDistance(_remainingMeters),
                              style: const TextStyle(
                                color: Color(0xFF064E3B),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 3. Floating Map Controls (Follow, Fit Route, Style, Auto-Drive, Sync Customer Order)
        Positioned(
          top: 96,
          right: 14,
          child: Column(
            children: [
              _MapHudButton(
                icon: _followCaptain ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                active: _followCaptain,
                tooltip: 'شوێنکەوتنی شۆفێر',
                onTap: () {
                  setState(() => _followCaptain = true);
                  if (_mapReady) {
                    _mapController.move(_displayDriverPos, 16.2);
                  }
                },
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: Icons.route_rounded,
                active: false,
                tooltip: 'پیشاندانی تەواوی ڕێڕەو',
                onTap: _fitFullRoute,
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: _mapStyleIndex == 1 ? Icons.dark_mode_rounded : Icons.layers_rounded,
                active: _mapStyleIndex > 0,
                tooltip: 'گۆڕینی شێوازی نەخشە',
                onTap: () => setState(() => _mapStyleIndex = (_mapStyleIndex + 1) % 3),
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: _autoDriveSimulation ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                active: _autoDriveSimulation,
                tooltip: 'لێخوڕینی زیندوو چرکە بە چرکە',
                onTap: () => setState(() => _autoDriveSimulation = !_autoDriveSimulation),
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: Icons.cloud_sync_rounded,
                active: _backendSynced,
                tooltip: 'هاوکاتکردنی نوێترین داواکاری کڕیار',
                onTap: syncLatestCustomerOrderFromServer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPinBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isHighlighted;

  const _MapPinBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: isHighlighted ? 38 : 32,
          height: isHighlighted ? 38 : 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: isHighlighted ? 12 : 6,
                spreadRadius: isHighlighted ? 2 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: isHighlighted ? 20 : 17),
        ),
      ],
    );
  }
}

class _MapHudButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _MapHudButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 21,
              color: active ? const Color(0xFF00E676) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}
