import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'driver_api_service.dart';
import 'map/mapbox_directions.dart';
import 'map/mapbox_tiles.dart';
import 'rega_mobile.dart';

import 'rega_i18n.dart';
import 'rega_colors.dart';
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
  /// When false (no assigned order), map shows only the driver — no route lines or stop pins.
  final bool hasActiveOrder;
  final String locale;
  final String Function(String key)? translate;
  final String apiBaseUrl;
  final ValueChanged<CaptainRouteStage> onStageAutoReached;
  final VoidCallback onArrivedPromptPin;
  final void Function(Map<String, dynamic> syncedOrder)? onNewBackendOrderFound;

  CaptainLiveMapWidget({
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
    this.hasActiveOrder = true,
    this.locale = 'ku',
    this.translate,
    String? apiBaseUrl,
    required this.onStageAutoReached,
    required this.onArrivedPromptPin,
    this.onNewBackendOrderFound,
  }) : apiBaseUrl = apiBaseUrl ?? RegaApiHost.apiV1;

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
  Timer? _gpsPollTimer;

  // Map appearance & camera controls
  int _mapStyleIndex = 0; // 0: Mapbox Streets, 1: Satellite, 2: Outdoors
  bool _followCaptain = true;
  /// True only after a real phone GPS fix — never invent a fake place.
  bool _usingRealGps = false;
  bool _gpsBusy = false;
  bool _mapReady = false;
  bool _backendSynced = false;
  bool _promptedPinOnce = false;
  DateTime? _lastFleetLocationPush;
  DateTime? _lastGpsFixAt;
  Timer? _gpsRetryTimer;

  // Overview only (no driver pin) until real GPS arrives — downtown کەلار.
  static const LatLng _kalarOverview = LatLng(34.6295, 45.3159);

  // Coordinates & Street Polyline
  late LatLng _dispatchOrigin;
  late LatLng _storePoint;
  late LatLng _customerPoint;

  List<LatLng> _legToStore = [];
  List<LatLng> _legToCustomer = [];

  LatLng _prevDriverPos = _kalarOverview;
  LatLng _targetDriverPos = _kalarOverview;
  LatLng _displayDriverPos = _kalarOverview;

  double _headingDeg = 0.0;
  double _speedKmh = 0.0;
  int _etaSeconds = 0;
  int _remainingMeters = 0;
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
    if (widget.hasActiveOrder) {
      _syncStageAnchors(widget.stage, jumpImmediately: true);
    }
    _startRealGpsIfAvailable();
    _gpsRetryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _usingRealGps || _gpsBusy) return;
      _startRealGpsIfAvailable(requestPermission: true);
    });
    _startOneSecondEngine();
  }

  @override
  void didUpdateWidget(covariant CaptainLiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasActiveOrder != widget.hasActiveOrder ||
        oldWidget.orderNumber != widget.orderNumber ||
        oldWidget.storeLat != widget.storeLat ||
        oldWidget.customerLat != widget.customerLat) {
      _promptedPinOnce = false;
      _initCoordinatesAndRoutes();
      if (widget.hasActiveOrder) {
        _syncStageAnchors(widget.stage, jumpImmediately: true);
      }
    } else if (widget.hasActiveOrder && oldWidget.stage != widget.stage) {
      _syncStageAnchors(widget.stage, jumpImmediately: false);
    }
    if (!oldWidget.isOnline && widget.isOnline) {
      _startRealGpsIfAvailable(requestPermission: true);
      _pushFleetLocationIfNeeded(force: true);
    }
  }

  @override
  void dispose() {
    _secondTicker?.cancel();
    _gpsRetryTimer?.cancel();
    _gpsPollTimer?.cancel();
    _gpsSub?.cancel();
    _pulseController.dispose();
    _glideController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Fresh GPS settings — on web force `maximumAge: 0` so browsers cannot
  /// hand back a cached/stale fix (the Karkuk St / field pin bug).
  LocationSettings _freshLocationSettings({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
    Duration? timeLimit,
  }) {
    if (kIsWeb) {
      return WebSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        maximumAge: Duration.zero,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );
  }

  void _initCoordinatesAndRoutes() {
    _storePoint = LatLng(widget.storeLat, widget.storeLng);
    _customerPoint = LatLng(widget.customerLat, widget.customerLng);
    // Route start = real phone GPS when available (never a fabricated offset).
    _dispatchOrigin = _usingRealGps ? _displayDriverPos : _storePoint;

    if (!widget.hasActiveOrder) {
      // Idle map: no route geometry at all.
      _legToStore = [];
      _legToCustomer = [];
      _leg1Progress = 0.0;
      _leg2Progress = 0.0;
      _etaSeconds = 0;
      _remainingMeters = 0;
      return;
    }

    // Temporary straight fallback until Mapbox Directions returns road geometry.
    _legToStore = [_dispatchOrigin, _storePoint];
    _legToCustomer = [_storePoint, _customerPoint];

    _fetchMapboxStreetRoutes();
  }

  Future<void> _fetchMapboxStreetRoutes() async {
    if (!widget.hasActiveOrder) return;
    try {
      final origin = _usingRealGps ? _displayDriverPos : _storePoint;
      final (leg1, leg2) = await MapboxDirections.twoLegRoute(
        origin: origin,
        store: _storePoint,
        customer: _customerPoint,
      );
      if (!mounted || !widget.hasActiveOrder) return;
      setState(() {
        if (leg1.length >= 2) {
          _legToStore = MapboxDirections.densify(leg1, minPoints: 30);
        }
        if (leg2.length >= 2) {
          _legToCustomer = MapboxDirections.densify(leg2, minPoints: 50);
        }
      });
    } catch (_) {
      // Keep temporary fallback line if Directions is unreachable.
    }
  }

  void _syncStageAnchors(CaptainRouteStage stage, {required bool jumpImmediately}) {
    // Progress / ETA only — never teleport the pin to a fake place.
    switch (stage) {
      case CaptainRouteStage.assigned:
        _leg1Progress = 0.0;
        _leg2Progress = 0.0;
        break;
      case CaptainRouteStage.arrivingPickup:
        if (_usingRealGps) {
          _leg1Progress = _nearestProgressOnPolyline(_legToStore, _displayDriverPos);
        }
        break;
      case CaptainRouteStage.arrivedPickup:
      case CaptainRouteStage.pickedUp:
        _leg1Progress = 1.0;
        _leg2Progress = 0.0;
        if (!_usingRealGps) _speedKmh = 0.0;
        break;
      case CaptainRouteStage.onTheWay:
        _leg1Progress = 1.0;
        if (_usingRealGps) {
          _leg2Progress = _nearestProgressOnPolyline(_legToCustomer, _displayDriverPos);
        }
        break;
      case CaptainRouteStage.arrivedCustomer:
      case CaptainRouteStage.delivered:
        _leg1Progress = 1.0;
        _leg2Progress = 1.0;
        if (!_usingRealGps) _speedKmh = 0.0;
        _etaSeconds = 0;
        _remainingMeters = 0;
        break;
    }

    // Without real GPS we keep the overview center — do not invent a driver place.
    if (!_usingRealGps) {
      _recomputeMetrics();
      return;
    }
    _recomputeMetrics();
  }

  Future<void> _startRealGpsIfAvailable({bool requestPermission = true}) async {
    if (_gpsBusy) return;
    _gpsBusy = true;
    if (mounted) setState(() {});
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && requestPermission) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      // Fresh fix only — never promote getLastKnownPosition to the driver pin
      // (stale/cached coords were shown as live near Karkuk St at 0 km/h).
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _freshLocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          ),
        );
        if (mounted) _applyPhoneGpsPosition(pos, snapImmediately: true);
      } catch (_) {
        // Overview only until a real current fix arrives — no fabricated pin.
      }

      await _gpsSub?.cancel();
      // Web watchPosition is unreliable; distanceFilter:0 + poll fallback below.
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: _freshLocationSettings(
          accuracy: kIsWeb
              ? LocationAccuracy.high
              : LocationAccuracy.bestForNavigation,
          distanceFilter: kIsWeb ? 0 : 2,
        ),
      ).listen(
        (pos) {
          if (!mounted) return;
          _applyPhoneGpsPosition(pos);
        },
        onError: (_) {
          _ensureGpsPollingFallback();
        },
        cancelOnError: false,
      );

      _ensureGpsPollingFallback();

      if (mounted && _usingRealGps) {
        setState(() => _followCaptain = true);
      }
    } catch (_) {
      // Stay without a driver pin until a real fix arrives.
      _ensureGpsPollingFallback();
    } finally {
      _gpsBusy = false;
      if (mounted) setState(() {});
    }
  }

  /// Poll getCurrentPosition when the web/native stream stalls or never fires.
  void _ensureGpsPollingFallback() {
    if (_gpsPollTimer != null) return;
    final interval = kIsWeb ? const Duration(seconds: 2) : const Duration(seconds: 4);
    _gpsPollTimer = Timer.periodic(interval, (_) async {
      if (!mounted) return;
      // Native: skip poll while the stream is healthy.
      if (!kIsWeb &&
          _lastGpsFixAt != null &&
          DateTime.now().difference(_lastGpsFixAt!).inSeconds < 5) {
        return;
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _freshLocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          ),
        );
        if (mounted) _applyPhoneGpsPosition(pos);
      } catch (_) {}
    });
  }

  /// Move captain pin + camera whenever the delivery phone place changes.
  void _applyPhoneGpsPosition(Position pos, {bool snapImmediately = false}) {
    final next = LatLng(pos.latitude, pos.longitude);
    final hadFix = _usingRealGps;
    _usingRealGps = true;
    _lastGpsFixAt = DateTime.now();
    _followCaptain = true;
    final speed = pos.speed.isFinite ? math.max(0.0, pos.speed * 3.6) : 0.0;
    _speedKmh = speed;
    if (pos.heading.isFinite && pos.heading >= 0) {
      _headingDeg = pos.heading;
    }

    // First fix: snap — never glide from the Kalar overview toward the phone.
    if (!hadFix || snapImmediately) {
      _glideController.stop();
      _prevDriverPos = next;
      _targetDriverPos = next;
      _displayDriverPos = next;
      if (_mapReady) {
        try {
          final curZoom = _mapController.camera.zoom;
          final safeZoom = (curZoom.isNaN || curZoom < 11.5) ? 15.6 : curZoom;
          _mapController.move(next, safeZoom);
        } catch (_) {}
      }
      if (mounted) setState(() {});
    } else {
      _animateDriverTo(next);
    }

    _updateProgressFromPhoneGps(next);
    _recomputeMetrics();
    // Push the real fix coords (not mid-animation display).
    _pushFleetLocationIfNeeded(
      force: !hadFix,
      lat: next.latitude,
      lng: next.longitude,
    );
    // Rebuild road route from the real phone place once we get the first fix.
    if (!hadFix && widget.hasActiveOrder) {
      _dispatchOrigin = next;
      _fetchMapboxStreetRoutes();
    }
  }

  /// Publish GPS to backend so admin + seller maps see this online driver.
  Future<void> _pushFleetLocationIfNeeded({
    bool force = false,
    double? lat,
    double? lng,
  }) async {
    if (!widget.isOnline || !_usingRealGps) return;
    final now = DateTime.now();
    if (!force &&
        _lastFleetLocationPush != null &&
        now.difference(_lastFleetLocationPush!).inSeconds < 3) {
      return;
    }
    _lastFleetLocationPush = now;
    await DriverApiService.instance.updateLocation(
      lat ?? _displayDriverPos.latitude,
      lng ?? _displayDriverPos.longitude,
      heading: _headingDeg,
      speedKmh: _speedKmh,
    );
  }

  double _nearestProgressOnPolyline(List<LatLng> pts, LatLng here) {
    if (pts.length < 2) return 0;
    var bestDist = double.infinity;
    var bestProgress = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final d = _haversineMeters(here, pts[i]);
      if (d < bestDist) {
        bestDist = d;
        bestProgress = i / (pts.length - 1);
      }
    }
    return bestProgress.clamp(0.0, 1.0);
  }

  void _updateProgressFromPhoneGps(LatLng here) {
    if (widget.stage == CaptainRouteStage.assigned ||
        widget.stage == CaptainRouteStage.arrivingPickup) {
      _leg1Progress = _nearestProgressOnPolyline(_legToStore, here);
    } else if (widget.stage == CaptainRouteStage.onTheWay ||
        widget.stage == CaptainRouteStage.arrivedCustomer) {
      _leg1Progress = 1.0;
      _leg2Progress = _nearestProgressOnPolyline(_legToCustomer, here);
    }
  }

  void _startOneSecondEngine() {
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.isOnline) return;
      _elapsedSeconds += 1;
      if (_usingRealGps) {
        _recomputeMetrics();
        if (widget.hasActiveOrder) {
          _pushOneSecondTelemetryToBackend();
        }
        // Keep fleet GPS alive for admin/seller maps (real phone only).
        if (_elapsedSeconds % 3 == 0) {
          _pushFleetLocationIfNeeded(
            lat: _targetDriverPos.latitude,
            lng: _targetDriverPos.longitude,
          );
        }
      }
    });
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
    if (!widget.hasActiveOrder ||
        widget.stage == CaptainRouteStage.delivered ||
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
    if (!_usingRealGps) return;
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
    if (!_mapReady || !widget.hasActiveOrder) return;
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
      return '${(meters / 1000).toStringAsFixed(2)} ${_mt('km_unit')}';
    }
    return '$meters ${_mt('m_unit')}';
  }

  MapboxStyle get _mapboxStyle {
    switch (_mapStyleIndex) {
      case 1:
        return MapboxStyle.satellite;
      case 2:
        return MapboxStyle.outdoors;
      default:
        return MapboxStyle.streets;
    }
  }

  String _mt(String key) => widget.translate?.call(key) ?? key;

  String _navigationHeadline() {
    switch (widget.stage) {
      case CaptainRouteStage.assigned:
      case CaptainRouteStage.arrivingPickup:
        return _mt('nav_to_merchant').replaceAll('{name}', widget.merchantName);
      case CaptainRouteStage.arrivedPickup:
        return _mt('nav_at_store');
      case CaptainRouteStage.pickedUp:
      case CaptainRouteStage.onTheWay:
        return _mt('nav_to_customer').replaceAll('{name}', widget.customerName);
      case CaptainRouteStage.arrivedCustomer:
        return _mt('nav_ask_pin');
      case CaptainRouteStage.delivered:
        return _mt('nav_done');
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
    final hasOrder = widget.hasActiveOrder;
    final isToStore = widget.stage == CaptainRouteStage.assigned ||
        widget.stage == CaptainRouteStage.arrivingPickup;

    final polylines = <Polyline>[];

    // Route lines only while an order is assigned + we have a real phone place.
    if (hasOrder && _usingRealGps) {
      if (isToStore) {
        final traveled1 = _traveledSubPolyline(_legToStore, _leg1Progress, _displayDriverPos);
        final remain1 = _remainingSubPolyline(_legToStore, _leg1Progress, _displayDriverPos);
        if (traveled1.length >= 2) {
          polylines.add(Polyline(
            points: traveled1,
            strokeWidth: 5,
            color: RC.bg(Color(0xFF94A3B8)).withValues(alpha: 0.65),
          ));
        }
        if (remain1.length >= 2) {
          polylines.add(Polyline(
            points: remain1,
            strokeWidth: 7,
            color: RC.bg(Color(0xFFF59E0B)),
            borderStrokeWidth: 2.5,
            borderColor: RC.bg(Color(0xFF78350F)),
          ));
        }
        if (_legToCustomer.length >= 2) {
          polylines.add(Polyline(
            points: _legToCustomer,
            strokeWidth: 5,
            pattern: StrokePattern.dashed(segments: const [14, 10]),
            color: RC.bg(Color(0xFF16A34A)).withValues(alpha: 0.7),
          ));
        }
      } else {
        if (_legToStore.length >= 2) {
          polylines.add(Polyline(
            points: _legToStore,
            strokeWidth: 4,
            color: RC.bg(Color(0xFF94A3B8)).withValues(alpha: 0.45),
          ));
        }
        final traveled2 = _traveledSubPolyline(_legToCustomer, _leg2Progress, _displayDriverPos);
        final remain2 = _remainingSubPolyline(_legToCustomer, _leg2Progress, _displayDriverPos);
        if (traveled2.length >= 2) {
          polylines.add(Polyline(
            points: traveled2,
            strokeWidth: 5,
            color: RC.bg(Color(0xFF22C55E)).withValues(alpha: 0.40),
          ));
        }
        if (remain2.length >= 2) {
          polylines.add(Polyline(
            points: remain2,
            strokeWidth: 7.5,
            color: RC.bg(Color(0xFF00E676)),
            borderStrokeWidth: 2.5,
            borderColor: RC.bg(Color(0xFF065F46)),
          ));
        }
      }
    } else if (hasOrder && _legToStore.length >= 2) {
      // Order assigned but waiting GPS: show static store→customer preview only.
      polylines.add(Polyline(
        points: [_storePoint, _customerPoint],
        strokeWidth: 5,
        pattern: StrokePattern.dashed(segments: const [14, 10]),
        color: RC.bg(Color(0xFF64748B)).withValues(alpha: 0.75),
      ));
    }

    final markers = <Marker>[
      if (hasOrder) ...[
        // Store Marker (Pickup)
        Marker(
          point: _storePoint,
          width: 120,
          height: 76,
          alignment: Alignment.topCenter,
          child: _MapPinBadge(
            icon: Icons.storefront_rounded,
            color: RC.bg(Color(0xFFEA580C)),
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
            color: RC.bg(Color(0xFF0284C7)),
            label: widget.customerName,
            isHighlighted: !isToStore,
          ),
        ),
      ],
      // Live captain marker — only with real phone GPS (no fake pin).
      if (_usingRealGps)
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
                      color: RC.bg(Color(0xFF00E676)).withValues(alpha: (1 - p) * 0.38),
                    ),
                  ),
                  Transform.rotate(
                    angle: (_headingDeg * math.pi / 180.0),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFF00E676)),
                        shape: BoxShape.circle,
                        border: Border.all(color: RC.bg(Color(0xFF0F172A)), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: RC.bg(Colors.black26),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.navigation_rounded,
                        color: RC.fg(Color(0xFF0F172A)),
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFF0F172A)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tx('${_speedKmh.toStringAsFixed(0)} km/h'),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF00E676)),
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
    ];

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
                ? RC.bg(Color(0xFF0F172A))
                : RC.bg(Color(0xFFE2E8F0)),
            onMapReady: () {
              _mapReady = true;
              // Overview until a real fix — do not treat Kalar overview as the driver.
              final center = _usingRealGps ? _displayDriverPos : _kalarOverview;
              _mapController.move(center, _usingRealGps ? 15.6 : 13.8);
              if (_usingRealGps) {
                _followCaptain = true;
              } else if (hasOrder) {
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (mounted && _mapReady && widget.hasActiveOrder && !_usingRealGps) {
                    _safeFitBounds([_storePoint, _customerPoint]);
                  }
                });
              }
            },
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followCaptain) {
                setState(() => _followCaptain = false);
              }
            },
          ),
          children: [
            MapboxTiles.layer(
              style: _mapboxStyle,
              userAgentPackageName: 'iq.rega.delivery',
              tileProvider: NetworkTileProvider(),
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),

        // 2. Top Turn-by-Turn Second-by-Second Navigation HUD (only with active order)
        if (hasOrder)
        Positioned(
          top: 12,
          left: RegaResponsive.pagePadding(context),
          right: RegaResponsive.pagePadding(context),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 620),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFF0F172A)).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: RC.bg(Color(0xFF00E676)).withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: RC.bg(Colors.black26),
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
                        color: RC.bg(Color(0xFF00E676)).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _navigationIcon(),
                        color: RC.fg(Color(0xFF00E676)),
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
                                      ? RC.bg(Color(0xFF00E676))
                                      : RC.bg(Color(0xFFFAC800)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                tx(_backendSynced
                                    ? _mt('gps_live_sync')
                                    : _mt('gps_live_kalar')),
                                style: TextStyle(
                                  color: RC.fg(Color(0xFF00E676)),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx(_navigationHeadline()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: RC.fg(Colors.white),
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
                          color: RC.bg(Color(0xFF00E676)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tx(_formatCountdown(_etaSeconds)),
                              style: TextStyle(
                                color: RC.fg(Color(0xFF0F172A)),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              tx(_formatDistance(_remainingMeters)),
                              style: TextStyle(
                                color: RC.fg(Color(0xFF064E3B)),
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
                tooltip: tx(_mt('follow_driver')),
                onTap: () {
                  setState(() => _followCaptain = true);
                  if (_mapReady) {
                    _mapController.move(_displayDriverPos, 16.2);
                  }
                },
              ),
              if (hasOrder) ...[
                const SizedBox(height: 8),
                _MapHudButton(
                  icon: Icons.route_rounded,
                  active: false,
                  tooltip: tx(_mt('show_full_route')),
                  onTap: _fitFullRoute,
                ),
              ],
              const SizedBox(height: 8),
              _MapHudButton(
                icon: _mapStyleIndex == 1 ? Icons.dark_mode_rounded : Icons.layers_rounded,
                active: _mapStyleIndex > 0,
                tooltip: tx(_mt('map_style')),
                onTap: () => setState(() => _mapStyleIndex = (_mapStyleIndex + 1) % 3),
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: _usingRealGps
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                active: _usingRealGps,
                tooltip: tx(_mt('phone_gps')),
                onTap: () async {
                  setState(() => _followCaptain = true);
                  await _startRealGpsIfAvailable(requestPermission: true);
                },
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: Icons.cloud_sync_rounded,
                active: _backendSynced,
                tooltip: tx(_mt('sync_order')),
                onTap: syncLatestCustomerOrderFromServer,
              ),
            ],
          ),
        ),

        // Waiting for real phone GPS — never show a fake driver place.
        if (!_usingRealGps)
          Positioned(
            top: 14,
            left: 14,
            right: 70,
            child: Material(
              color: RC.bg(Color(0xFF0F172A)).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _startRealGpsIfAvailable(requestPermission: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      if (_gpsBusy)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: RC.bg(Color(0xFFFAC800)),
                          ),
                        )
                      else
                        Icon(Icons.gps_fixed_rounded, color: RC.fg(Color(0xFFFAC800)), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tx(_gpsBusy
                              ? _mt('gps_locating')
                              : _mt('gps_allow_phone')),
                          style: TextStyle(
                            color: RC.fg(Colors.white),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
            boxShadow: [
              BoxShadow(color: RC.bg(Colors.black26), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            tx(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: RC.fg(Color(0xFF0F172A)),
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
            border: Border.all(color: RC.bg(Colors.white), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: isHighlighted ? 12 : 6,
                spreadRadius: isHighlighted ? 2 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: RC.fg(Colors.white), size: isHighlighted ? 20 : 17),
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
        color: active ? RC.bg(Color(0xFF0F172A)) : RC.bg(Colors.white),
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
              color: active ? RC.fg(Color(0xFF00E676)) : RC.bg(Color(0xFF0F172A)),
            ),
          ),
        ),
      ),
    );
  }
}
