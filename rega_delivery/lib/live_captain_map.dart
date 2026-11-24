import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'driver_api_service.dart';
import 'map/mapbox_directions.dart';
import 'map/rega_map_styles.dart';
import 'map/rega_standard_map.dart';
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
  final GlobalKey<RegaStandardMapState> _regaMapKey = GlobalKey();
  mb.MapboxMap? _mbMap;
  mb.PolylineAnnotationManager? _polyMgr;
  mb.PolylineAnnotationManager? _polyDashMgr;
  mb.PointAnnotationManager? _pointMgr;
  mb.PointAnnotation? _driverPointAnno;
  StreamSubscription<mb.MapContentGestureContext>? _panGestureSub;
  bool _suppressFollowDisable = false;

  late AnimationController _pulseController;
  late AnimationController _glideController;

  Timer? _secondTicker;
  StreamSubscription<Position>? _gpsSub;
  Timer? _gpsPollTimer;

  // Map appearance & camera controls
  bool _followCaptain = true;
  /// True only after a real phone GPS fix — never invent a fake place.
  bool _usingRealGps = false;
  bool _gpsBusy = false;
  bool _mapReady = false;
  bool _backendSynced = false;
  bool _promptedPinOnce = false;
  bool _isSatellite = false;
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
      unawaited(_syncPointAnnotations());
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
    _panGestureSub?.cancel();
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

  Future<double> _cameraZoom() async {
    final map = _mbMap;
    if (map == null) return 15.6;
    try {
      final z = (await map.getCameraState()).zoom;
      return (z.isNaN || z < 11.5) ? 15.6 : z;
    } catch (_) {
      return 15.6;
    }
  }

  Future<void> _moveMap(LatLng at, {double? zoom}) async {
    if (!_mapReady) return;
    _suppressFollowDisable = true;
    try {
      final z = zoom ?? await _cameraZoom();
      final safeZoom = z < 11.5 ? 15.6 : z;
      await _regaMapKey.currentState?.moveTo(at, zoom: safeZoom);
    } finally {
      _suppressFollowDisable = false;
    }
  }

  Future<void> _onMbMapCreated(mb.MapboxMap map) async {
    _mbMap = map;
    _mapReady = true;
    if (!kIsWeb) {
      try {
        final annotations = map.annotations;
        _polyMgr = await annotations.createPolylineAnnotationManager();
        _polyDashMgr =
            await annotations.createPolylineAnnotationManager(id: 'dash');
        await _polyDashMgr?.setLineDasharray([1.4, 1.0]);
        _pointMgr = await annotations.createPointAnnotationManager();
      } catch (_) {}
    }
    try {
      _panGestureSub = map.gestures.pan.gestureEvents.listen((_) {
        if (!_mapReady || _suppressFollowDisable) return;
        if (_followCaptain) setState(() => _followCaptain = false);
      });
    } catch (_) {}

    final center = _usingRealGps ? _displayDriverPos : _kalarOverview;
    final zoom = _usingRealGps ? 15.6 : 13.8;
    await _moveMap(center, zoom: zoom);
    if (_usingRealGps) _followCaptain = true;
    await _syncRoutePolylines();
    await _syncPointAnnotations();
    if (!_usingRealGps && widget.hasActiveOrder) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _mapReady && widget.hasActiveOrder && !_usingRealGps) {
          _safeFitBounds([_storePoint, _customerPoint]);
        }
      });
    }
  }

  Future<void> _syncRoutePolylines() async {
    if (kIsWeb) return;
    final solid = _polyMgr;
    final dashed = _polyDashMgr;
    if (solid == null) return;
    try {
      await solid.deleteAll();
      await dashed?.deleteAll();
    } catch (_) {}

    final hasOrder = widget.hasActiveOrder;
    final isToStore = widget.stage == CaptainRouteStage.assigned ||
        widget.stage == CaptainRouteStage.arrivingPickup;
    final polylines = <({List<LatLng> pts, int color, double width, int? border, double borderW, bool dash})>[];

    if (hasOrder && _usingRealGps) {
      if (isToStore) {
        final traveled1 =
            _traveledSubPolyline(_legToStore, _leg1Progress, _displayDriverPos);
        final remain1 =
            _remainingSubPolyline(_legToStore, _leg1Progress, _displayDriverPos);
        if (traveled1.length >= 2) {
          polylines.add((
            pts: traveled1,
            color: _colorInt(const Color(0xFF94A3B8)),
            width: 5,
            border: null,
            borderW: 0,
            dash: false,
          ));
        }
        if (remain1.length >= 2) {
          polylines.add((
            pts: remain1,
            color: _colorInt(const Color(0xFFF59E0B)),
            width: 7,
            border: _colorInt(const Color(0xFF78350F)),
            borderW: 2.5,
            dash: false,
          ));
        }
        if (_legToCustomer.length >= 2) {
          polylines.add((
            pts: _legToCustomer,
            color: _colorInt(const Color(0xFF16A34A)),
            width: 5,
            border: null,
            borderW: 0,
            dash: true,
          ));
        }
      } else {
        if (_legToStore.length >= 2) {
          polylines.add((
            pts: _legToStore,
            color: _colorInt(const Color(0xFF94A3B8)),
            width: 4,
            border: null,
            borderW: 0,
            dash: false,
          ));
        }
        final traveled2 = _traveledSubPolyline(
            _legToCustomer, _leg2Progress, _displayDriverPos);
        final remain2 = _remainingSubPolyline(
            _legToCustomer, _leg2Progress, _displayDriverPos);
        if (traveled2.length >= 2) {
          polylines.add((
            pts: traveled2,
            color: _colorInt(const Color(0xFF22C55E)),
            width: 5,
            border: null,
            borderW: 0,
            dash: false,
          ));
        }
        if (remain2.length >= 2) {
          polylines.add((
            pts: remain2,
            color: _colorInt(const Color(0xFF00E676)),
            width: 7.5,
            border: _colorInt(const Color(0xFF065F46)),
            borderW: 2.5,
            dash: false,
          ));
        }
      }
    } else if (hasOrder && _legToStore.length >= 2) {
      polylines.add((
        pts: [_storePoint, _customerPoint],
        color: _colorInt(const Color(0xFF64748B)),
        width: 5,
        border: null,
        borderW: 0,
        dash: true,
      ));
    }

    for (final pl in polylines) {
      final mgr = pl.dash ? dashed : solid;
      if (mgr == null || pl.pts.length < 2) continue;
      try {
        await mgr.create(
          mb.PolylineAnnotationOptions(
            geometry: _mbLine(pl.pts),
            lineColor: pl.color,
            lineWidth: pl.width,
            lineOpacity: pl.dash ? 0.75 : (pl.color == _colorInt(const Color(0xFF94A3B8)) ? 0.65 : 1.0),
            lineBorderColor: pl.border,
            lineBorderWidth: pl.borderW,
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _syncPointAnnotations({bool driverOnly = false}) async {
    if (kIsWeb) return;
    final mgr = _pointMgr;
    if (mgr == null) return;

    if (!driverOnly) {
      try {
        await mgr.deleteAll();
        _driverPointAnno = null;
      } catch (_) {}

      if (widget.hasActiveOrder) {
        try {
          await mgr.create(
            mb.PointAnnotationOptions(
              geometry: _mbPoint(_storePoint),
              textField: widget.merchantName,
              textSize: 10,
              textHaloWidth: 1.2,
              textHaloColor: _colorInt(Colors.white),
              textColor: _colorInt(const Color(0xFF0F172A)),
              textOffset: [0, -1.8],
              iconColor: _colorInt(const Color(0xFFEA580C)),
              iconSize: 1.1,
            ),
          );
          await mgr.create(
            mb.PointAnnotationOptions(
              geometry: _mbPoint(_customerPoint),
              textField: widget.customerName,
              textSize: 10,
              textHaloWidth: 1.2,
              textHaloColor: _colorInt(Colors.white),
              textColor: _colorInt(const Color(0xFF0F172A)),
              textOffset: [0, -1.8],
              iconColor: _colorInt(const Color(0xFF0284C7)),
              iconSize: 1.1,
            ),
          );
        } catch (_) {}
      }
    }

    if (!_usingRealGps) return;

    try {
      final speedLabel = '${_speedKmh.toStringAsFixed(0)} km/h';
      if (_driverPointAnno == null) {
        _driverPointAnno = await mgr.create(
          mb.PointAnnotationOptions(
            geometry: _mbPoint(_displayDriverPos),
            textField: speedLabel,
            textSize: 9,
            textColor: _colorInt(const Color(0xFF00E676)),
            textHaloColor: _colorInt(const Color(0xFF0F172A)),
            textHaloWidth: 1.2,
            textOffset: [0, -2.2],
            iconRotate: _headingDeg,
            iconColor: _colorInt(const Color(0xFF00E676)),
            iconSize: 1.25,
          ),
        );
      } else {
        _driverPointAnno!
          ..geometry = _mbPoint(_displayDriverPos)
          ..iconRotate = _headingDeg
          ..textField = speedLabel;
        await mgr.update(_driverPointAnno!);
      }
    } catch (_) {}
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
      await _syncRoutePolylines();
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
      unawaited(_syncRoutePolylines());
      return;
    }
    _recomputeMetrics();
    unawaited(_syncRoutePolylines());
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

      // Fast first fix so «شوێنەکەم» jumps like the customer app (then stream refines).
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _freshLocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 10),
          ),
        );
        if (mounted) _applyPhoneGpsPosition(pos, snapImmediately: true);
      } catch (_) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null && mounted) {
            _applyPhoneGpsPosition(last, snapImmediately: true);
          }
        } catch (_) {}
      }

      await _gpsSub?.cancel();
      // Web watchPosition is unreliable; distanceFilter:0 + poll fallback below.
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: _freshLocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
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
            accuracy: LocationAccuracy.bestForNavigation,
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
      if (_mapReady) unawaited(_moveMap(next));
      if (mounted) setState(() {});
      unawaited(_syncPointAnnotations());
      unawaited(_syncRoutePolylines());
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
      unawaited(_moveMap(next));
    }
    unawaited(_syncPointAnnotations(driverOnly: true));
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
    unawaited(_syncPointAnnotations(driverOnly: true));
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

  Future<void> _safeFitBounds(List<LatLng> points, {double maxZoom = 16.2, double minZoom = 11.5}) async {
    if (!_mapReady || points.isEmpty || _mbMap == null) return;
    try {
      final valid = points.where((p) => !p.latitude.isNaN && !p.longitude.isNaN).toList();
      if (valid.isEmpty) return;
      if (valid.length == 1) {
        await _moveMap(valid.first, zoom: 15.6);
        return;
      }
      final camera = await _mbMap!.cameraForCoordinates(
        valid.map(_mbPoint).toList(),
        mb.MbxEdgeInsets(top: 36, left: 28, bottom: 36, right: 28),
        null,
        null,
      );
      var z = camera.zoom ?? 15.6;
      if (z > maxZoom) z = maxZoom;
      if (z < minZoom) z = minZoom;
      _suppressFollowDisable = true;
      await _mbMap!.setCamera(mb.CameraOptions(center: camera.center, zoom: z));
      _suppressFollowDisable = false;
    } catch (_) {
      await _moveMap(_displayDriverPos, zoom: 15.6);
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

    final mapCenter = _usingRealGps ? _displayDriverPos : _kalarOverview;
    final mapZoom = _usingRealGps ? 15.6 : 13.8;

    const gold = Color(0xFFFAC800);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = 88.0 + MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        RegaStandardMap(
          key: _regaMapKey,
          center: mapCenter,
          zoom: mapZoom,
          showLayersFab: false,
          onMapCreated: _onMbMapCreated,
          onStyleChanged: (id) {
            if (mounted) setState(() => _isSatellite = id == RegaMapStyleId.satellite);
          },
        ),

        // Customer-style top chips: سەتەلایت | شوێنەکەم
        Positioned(
          top: 12 + topPad * 0.1,
          left: 10,
          right: 10,
          child: SafeArea(
            bottom: false,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _CaptainModeChip(
                    label: 'سەتەلایت',
                    icon: Icons.satellite_alt_rounded,
                    active: _isSatellite,
                    activeColor: gold,
                    onTap: () => _regaMapKey.currentState?.toggleSatellite(),
                  ),
                  const SizedBox(width: 8),
                  if (hasOrder)
                    _CaptainModeChip(
                      label: 'ڕێگا',
                      icon: Icons.route_rounded,
                      active: false,
                      activeColor: const Color(0xFF22C55E),
                      onTap: _fitFullRoute,
                    ),
                  const Spacer(),
                  _CaptainModeChip(
                    label: 'شوێنەکەم',
                    icon: _gpsBusy
                        ? Icons.hourglass_top_rounded
                        : Icons.my_location_rounded,
                    active: true,
                    activeColor: gold,
                    busy: _gpsBusy,
                    onTap: _gpsBusy
                        ? () {}
                        : () async {
                            setState(() => _followCaptain = true);
                            await _startRealGpsIfAvailable(requestPermission: true);
                          },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Compact order HUD (only with active order) — lighter, customer-like card
        if (hasOrder)
          Positioned(
            top: 62 + topPad * 0.15,
            left: RegaResponsive.pagePadding(context),
            right: RegaResponsive.pagePadding(context),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 620),
                ),
                child: Material(
                  color: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_navigationIcon(), color: const Color(0xFF0F172A), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx(_navigationHeadline()),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tx(_backendSynced ? _mt('gps_live_sync') : _mt('gps_live_kalar')),
                                style: TextStyle(
                                  color: _backendSynced
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tx(_formatCountdown(_etaSeconds)),
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Text(
                                  tx(_formatDistance(_remainingMeters)),
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
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
                  ),
                ),
              ),
            ),
          ),

        // Zoom + / − — customer style (bottom right)
        Positioned(
          right: 14,
          bottom: bottomPad,
          child: Column(
            children: [
              _MapHudButton(
                icon: Icons.add_rounded,
                active: false,
                tooltip: '+',
                onTap: () => _regaMapKey.currentState?.zoomBy(1),
              ),
              const SizedBox(height: 10),
              _MapHudButton(
                icon: Icons.remove_rounded,
                active: false,
                tooltip: '−',
                onTap: () => _regaMapKey.currentState?.zoomBy(-1),
              ),
              const SizedBox(height: 10),
              _MapHudButton(
                icon: Icons.cloud_sync_rounded,
                active: _backendSynced,
                tooltip: tx(_mt('sync_order')),
                onTap: syncLatestCustomerOrderFromServer,
              ),
            ],
          ),
        ),

        // Soft tip when GPS not ready yet (not dark full banner)
        if (!_usingRealGps)
          Positioned(
            left: 14,
            bottom: bottomPad,
            child: Material(
              color: gold,
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _gpsBusy
                    ? null
                    : () => _startRealGpsIfAvailable(requestPermission: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_gpsBusy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F172A),
                          ),
                        )
                      else
                        const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        tx(_gpsBusy ? _mt('gps_locating') : 'شوێنەکەم'),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
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

class _CaptainModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final bool busy;

  const _CaptainModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
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
