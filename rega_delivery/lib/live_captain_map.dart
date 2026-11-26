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
  final double? profileLat;
  final double? profileLng;
  final bool isOnline;
  final bool hasActiveOrder;
  final bool isOrderCardExpanded;
  final String locale;
  final String Function(String key)? translate;
  final String apiBaseUrl;
  final ValueChanged<CaptainRouteStage> onStageAutoReached;
  final VoidCallback onArrivedPromptPin;
  final Future<void> Function()? onRefreshData;
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
    this.profileLat,
    this.profileLng,
    this.isOnline = true,
    this.hasActiveOrder = true,
    this.isOrderCardExpanded = false,
    this.locale = 'ku',
    this.translate,
    String? apiBaseUrl,
    required this.onStageAutoReached,
    required this.onArrivedPromptPin,
    this.onRefreshData,
    this.onNewBackendOrderFound,
  }) : apiBaseUrl = apiBaseUrl ?? RegaApiHost.apiV1;

  @override
  State<CaptainLiveMapWidget> createState() => _CaptainLiveMapWidgetState();
}

class _CaptainLiveMapWidgetState extends State<CaptainLiveMapWidget>
    with TickerProviderStateMixin {
  final GlobalKey<RegaStandardMapState> _regaMapKey = GlobalKey();

  late AnimationController _pulseController;
  late AnimationController _glideController;

  Timer? _secondTicker;
  StreamSubscription<Position>? _gpsSub;
  Timer? _gpsPollTimer;
  Timer? _gpsRetryTimer;

  bool _followCaptain = true;
  bool _usingRealGps = false;
  bool _gpsBusy = false;
  bool _refreshBusy = false;
  bool _mapReady = false;
  bool _backendSynced = false;
  bool _isSatellite = false;
  DateTime? _lastFleetLocationPush;
  DateTime? _lastGpsFixAt;

  // Downtown Kalar center (ناو بازاڕی کەلار)
  static const LatLng _kalarOverview = LatLng(34.6295, 45.3159);

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

  double _leg1Progress = 0.0;
  double _leg2Progress = 0.0;

  LatLng get _effectiveFallbackDriverPos {
    final pLat = widget.profileLat;
    final pLng = widget.profileLng;
    if (pLat != null &&
        pLng != null &&
        pLat.abs() > 1 &&
        pLng.abs() > 1) {
      return LatLng(pLat, pLng);
    }
    return _kalarOverview;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(_onGlideFrame);

    _displayDriverPos = _effectiveFallbackDriverPos;
    _prevDriverPos = _displayDriverPos;
    _targetDriverPos = _displayDriverPos;

    _initCoordinatesAndRoutes();
    if (widget.hasActiveOrder) {
      _syncStageAnchors(widget.stage, jumpImmediately: true);
    }
    _startRealGpsIfAvailable();
    _gpsRetryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _usingRealGps || _gpsBusy) return;
      _startRealGpsIfAvailable(requestPermission: false);
    });
    _startOneSecondEngine();
  }

  @override
  void didUpdateWidget(covariant CaptainLiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_usingRealGps &&
        (oldWidget.profileLat != widget.profileLat ||
            oldWidget.profileLng != widget.profileLng)) {
      _displayDriverPos = _effectiveFallbackDriverPos;
      _prevDriverPos = _displayDriverPos;
      _targetDriverPos = _displayDriverPos;
    }
    if (oldWidget.hasActiveOrder != widget.hasActiveOrder ||
        oldWidget.orderNumber != widget.orderNumber ||
        oldWidget.storeLat != widget.storeLat ||
        oldWidget.storeLng != widget.storeLng ||
        oldWidget.customerLat != widget.customerLat ||
        oldWidget.customerLng != widget.customerLng) {
      _initCoordinatesAndRoutes();
      if (widget.hasActiveOrder) {
        _syncStageAnchors(widget.stage, jumpImmediately: true);
        if (_mapReady) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted && widget.hasActiveOrder) {
              _fitFullRoute(keepFollowing: false);
            }
          });
        }
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
    super.dispose();
  }

  Future<void> _moveMap(LatLng at, {double? zoom}) async {
    if (!_mapReady) return;
    final currentZ = _regaMapKey.currentState?.currentZoom ?? 15.5;
    final z = zoom ?? (currentZ < 11.5 ? 15.5 : currentZ);
    await _regaMapKey.currentState?.moveTo(at, zoom: z);
  }

  void _onFlutterMapReady() {
    _mapReady = true;
    if (widget.hasActiveOrder) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted && widget.hasActiveOrder) {
          _fitFullRoute(keepFollowing: false);
        }
      });
    } else {
      final center = _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;
      final zoom = _usingRealGps ? 15.6 : 14.4;
      unawaited(_moveMap(center, zoom: zoom));
    }
  }

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
    _dispatchOrigin =
        _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;

    if (!widget.hasActiveOrder) {
      _legToStore = [];
      _legToCustomer = [];
      _leg1Progress = 0.0;
      _leg2Progress = 0.0;
      _etaSeconds = 0;
      _remainingMeters = 0;
      return;
    }

    _legToStore = [_dispatchOrigin, _storePoint];
    _legToCustomer = [_storePoint, _customerPoint];
    _recomputeMetrics();
    _fetchMapboxStreetRoutes();
  }

  Future<void> _fetchMapboxStreetRoutes() async {
    if (!widget.hasActiveOrder) return;
    try {
      final origin =
          _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;
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
      _recomputeMetrics();
    } catch (_) {}
  }

  void _syncStageAnchors(
    CaptainRouteStage stage, {
    required bool jumpImmediately,
  }) {
    switch (stage) {
      case CaptainRouteStage.assigned:
        _leg1Progress = 0.0;
        _leg2Progress = 0.0;
        break;
      case CaptainRouteStage.arrivingPickup:
        if (_usingRealGps) {
          _leg1Progress =
              _nearestProgressOnPolyline(_legToStore, _displayDriverPos);
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
          _leg2Progress =
              _nearestProgressOnPolyline(_legToCustomer, _displayDriverPos);
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
    _recomputeMetrics();
  }

  Future<void> _startRealGpsIfAvailable({bool requestPermission = true}) async {
    if (_gpsBusy) return;
    _gpsBusy = true;
    if (mounted) setState(() {});
    try {
      if (kIsWeb) {
        // On Web, directly invoke requestPermission/checkPermission safely
        try {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied && requestPermission) {
            perm = await Geolocator.requestPermission();
          }
          if (perm == LocationPermission.denied ||
              perm == LocationPermission.deniedForever) {
            if (_mapReady) {
              await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
            }
            return;
          }
        } catch (_) {}

        // Multi-tier acquisition on Web: first try high accuracy, fallback to balanced
        Position? webPos;
        try {
          webPos = await Geolocator.getCurrentPosition(
            locationSettings: WebSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: const Duration(seconds: 12),
            ),
          );
        } catch (_) {
          try {
            webPos = await Geolocator.getCurrentPosition(
              locationSettings: WebSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 10),
              ),
            );
          } catch (_) {
            try {
              webPos = await Geolocator.getLastKnownPosition();
            } catch (_) {}
          }
        }

        if (webPos != null && mounted) {
          _applyPhoneGpsPosition(webPos, snapImmediately: true);
        } else if (_mapReady) {
          await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
        }

        await _gpsSub?.cancel();
        _gpsSub = Geolocator.getPositionStream(
          locationSettings: WebSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
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
        if (mounted) {
          setState(() => _followCaptain = true);
          if (_mapReady) {
            await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
          }
        }
        return;
      }

      // Native platform (Android / iOS)
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (_mapReady) {
          await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
        }
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && requestPermission) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (_mapReady) {
          await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
        }
        return;
      }

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
          } else if (_mapReady) {
            await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
          }
        } catch (_) {
          if (_mapReady) {
            await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
          }
        }
      }

      await _gpsSub?.cancel();
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: _freshLocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
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

      if (mounted) {
        setState(() => _followCaptain = true);
        if (_mapReady) {
          await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
        }
      }
    } catch (_) {
      _ensureGpsPollingFallback();
      if (_mapReady) {
        await _moveMap(_usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos, zoom: 15.6);
      }
    } finally {
      _gpsBusy = false;
      if (mounted) setState(() {});
    }
  }

  void _ensureGpsPollingFallback() {
    if (_gpsPollTimer != null) return;
    final interval =
        kIsWeb ? const Duration(seconds: 3) : const Duration(seconds: 5);
    _gpsPollTimer = Timer.periodic(interval, (_) async {
      if (!mounted) return;
      if (!kIsWeb &&
          _lastGpsFixAt != null &&
          DateTime.now().difference(_lastGpsFixAt!).inSeconds < 5) {
        return;
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _freshLocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 6),
          ),
        );
        if (mounted) _applyPhoneGpsPosition(pos);
      } catch (_) {}
    });
  }

  void _applyPhoneGpsPosition(Position pos, {bool snapImmediately = false}) {
    final next = LatLng(pos.latitude, pos.longitude);
    final hadFix = _usingRealGps;
    _usingRealGps = true;
    _lastGpsFixAt = DateTime.now();
    final speed = pos.speed.isFinite ? math.max(0.0, pos.speed * 3.6) : 0.0;
    _speedKmh = speed;
    if (pos.heading.isFinite && pos.heading >= 0) {
      _headingDeg = pos.heading;
    }

    if (!hadFix || snapImmediately) {
      _glideController.stop();
      _prevDriverPos = next;
      _targetDriverPos = next;
      _displayDriverPos = next;
      if (_mapReady && _followCaptain) {
        unawaited(_moveMap(next, zoom: 15.6));
      }
      if (mounted) setState(() {});
    } else {
      _animateDriverTo(next);
    }

    _updateProgressFromPhoneGps(next);
    _recomputeMetrics();
    _pushFleetLocationIfNeeded(
      force: !hadFix,
      lat: next.latitude,
      lng: next.longitude,
    );
    if (!hadFix && widget.hasActiveOrder) {
      _dispatchOrigin = next;
      _fetchMapboxStreetRoutes();
    }
  }

  Future<void> _pushFleetLocationIfNeeded({
    bool force = false,
    double? lat,
    double? lng,
  }) async {
    if (!widget.isOnline) return;
    final pos = _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;
    final now = DateTime.now();
    if (!force &&
        _lastFleetLocationPush != null &&
        now.difference(_lastFleetLocationPush!).inSeconds < 3) {
      return;
    }
    _lastFleetLocationPush = now;
    await DriverApiService.instance.updateLocation(
      lat ?? pos.latitude,
      lng ?? pos.longitude,
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
      _recomputeMetrics();
      if (widget.hasActiveOrder) {
        _pushOneSecondTelemetryToBackend();
      }
      if (_elapsedSeconds % 4 == 0) {
        _pushFleetLocationIfNeeded();
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
  }

  void _onGlideFrame() {
    if (!mounted) return;
    final t = Curves.easeOut.transform(_glideController.value);
    setState(() {
      _displayDriverPos = LatLng(
        _prevDriverPos.latitude +
            (_targetDriverPos.latitude - _prevDriverPos.latitude) * t,
        _prevDriverPos.longitude +
            (_targetDriverPos.longitude - _prevDriverPos.longitude) * t,
      );
    });
  }

  void _recomputeMetrics() {
    if (!mounted) return;
    if (!widget.hasActiveOrder ||
        widget.stage == CaptainRouteStage.delivered ||
        widget.stage == CaptainRouteStage.arrivedCustomer) {
      if (_remainingMeters != 0 || _etaSeconds != 0) {
        setState(() {
          _remainingMeters = 0;
          _etaSeconds = 0;
        });
      }
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

    final secs = (meters / 9.5).ceil();
    final nextMeters = meters.round();
    final nextSecs = math.max(0, secs);
    if (nextMeters != _remainingMeters || nextSecs != _etaSeconds) {
      setState(() {
        _remainingMeters = nextMeters;
        _etaSeconds = nextSecs;
      });
    }
  }

  Future<void> _pushOneSecondTelemetryToBackend() async {
    final cleanRef = widget.orderNumber.replaceAll('#', '').trim();
    if (cleanRef.isEmpty) return;

    final driverPos =
        _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;
    final statusPair = _mapStageToBackendStrings(widget.stage);
    final totalPermille = widget.stage == CaptainRouteStage.delivered
        ? 1000
        : ((_leg1Progress * 350) + (_leg2Progress * 650))
            .round()
            .clamp(0, 999);

    try {
      final res = await http
          .post(
            Uri.parse('${widget.apiBaseUrl}/live-telemetry/$cleanRef'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'driver_lat': driverPos.latitude,
              'driver_lng': driverPos.longitude,
              'driver_heading': double.parse(_headingDeg.toStringAsFixed(1)),
              'driver_speed_kmh': double.parse(_speedKmh.toStringAsFixed(1)),
              'eta_seconds': _etaSeconds,
              'distance_remaining_meters': _remainingMeters,
              'progress_permille': totalPermille,
              'status': statusPair.$1,
              'driver_status': statusPair.$2,
            }),
          )
          .timeout(const Duration(milliseconds: 1100));

      if (mounted &&
          res.statusCode >= 200 &&
          res.statusCode < 300 &&
          !_backendSynced) {
        setState(() => _backendSynced = true);
      }
    } catch (_) {
      if (mounted && _backendSynced) {
        setState(() => _backendSynced = false);
      }
    }
  }

  Future<void> syncLatestCustomerOrderFromServer() async {
    if (_refreshBusy) return;
    setState(() => _refreshBusy = true);
    try {
      // Strictly refresh only orders assigned to this driver by Admin.
      if (widget.onRefreshData != null) {
        await widget.onRefreshData!();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _refreshBusy = false);
    }
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

  List<LatLng> _remainingSubPolyline(
      List<LatLng> pts, double progress, LatLng currentPos) {
    if (pts.length < 2 || progress >= 1.0) return [];
    final exact = progress.clamp(0.0, 1.0) * (pts.length - 1);
    final nextIdx = exact.ceil().clamp(1, pts.length - 1);
    return [currentPos, ...pts.sublist(nextIdx)];
  }

  List<LatLng> _traveledSubPolyline(
      List<LatLng> pts, double progress, LatLng currentPos) {
    if (pts.length < 2 || progress <= 0.0) return [];
    final exact = progress.clamp(0.0, 1.0) * (pts.length - 1);
    final lastIdx = exact.floor().clamp(0, pts.length - 1);
    return [...pts.sublist(0, lastIdx + 1), currentPos];
  }

  double _remainingPolylineMeters(List<LatLng> pts, double progress) {
    if (pts.length < 2 || progress >= 1.0) return 0;
    final sub =
        _remainingSubPolyline(pts, progress, _pointAlong(pts, progress));
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
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
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

  void _fitFullRoute({bool keepFollowing = false}) {
    if (!_mapReady) return;
    _followCaptain = keepFollowing;
    final driverPos =
        _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;
    if (widget.hasActiveOrder) {
      _regaMapKey.currentState?.fitPoints(
        [driverPos, _storePoint, _customerPoint],
        padding: EdgeInsets.fromLTRB(
          42,
          128,
          42,
          widget.isOrderCardExpanded ? 310 : 190,
        ),
      );
    } else {
      _moveMap(driverPos, zoom: 15.2);
    }
    setState(() {});
  }

  List<Polyline> _buildFlutterMapPolylines() {
    if (!widget.hasActiveOrder) return const [];

    final lines = <Polyline>[];
    final isToStore = widget.stage == CaptainRouteStage.assigned ||
        widget.stage == CaptainRouteStage.arrivingPickup;
    final driverPos =
        _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;

    if (isToStore) {
      final traveled1 =
          _traveledSubPolyline(_legToStore, _leg1Progress, driverPos);
      final remain1 =
          _remainingSubPolyline(_legToStore, _leg1Progress, driverPos);
      if (traveled1.length >= 2) {
        lines.add(
          Polyline(
            points: traveled1,
            color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
            strokeWidth: 4.5,
          ),
        );
      }
      if (remain1.length >= 2) {
        lines.add(
          Polyline(
            points: remain1,
            color: const Color(0xFFF59E0B),
            strokeWidth: 6.5,
            borderColor: const Color(0xFF78350F),
            borderStrokeWidth: 2.0,
          ),
        );
      } else if (_legToStore.length >= 2) {
        lines.add(
          Polyline(
            points: _legToStore,
            color: const Color(0xFFF59E0B),
            strokeWidth: 6.0,
            borderColor: const Color(0xFF78350F),
            borderStrokeWidth: 1.8,
          ),
        );
      }
      if (_legToCustomer.length >= 2) {
        lines.add(
          Polyline(
            points: _legToCustomer,
            color: const Color(0xFF16A34A).withValues(alpha: 0.82),
            strokeWidth: 5.0,
            borderColor: const Color(0xFF064E3B).withValues(alpha: 0.5),
            borderStrokeWidth: 1.5,
          ),
        );
      }
    } else {
      if (_legToStore.length >= 2) {
        lines.add(
          Polyline(
            points: _legToStore,
            color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
            strokeWidth: 4.0,
          ),
        );
      }
      final traveled2 =
          _traveledSubPolyline(_legToCustomer, _leg2Progress, driverPos);
      final remain2 =
          _remainingSubPolyline(_legToCustomer, _leg2Progress, driverPos);
      if (traveled2.length >= 2) {
        lines.add(
          Polyline(
            points: traveled2,
            color: const Color(0xFF22C55E).withValues(alpha: 0.75),
            strokeWidth: 5.0,
          ),
        );
      }
      if (remain2.length >= 2) {
        lines.add(
          Polyline(
            points: remain2,
            color: const Color(0xFF00E676),
            strokeWidth: 7.0,
            borderColor: const Color(0xFF065F46),
            borderStrokeWidth: 2.2,
          ),
        );
      } else if (_legToCustomer.length >= 2) {
        lines.add(
          Polyline(
            points: _legToCustomer,
            color: const Color(0xFF00E676),
            strokeWidth: 6.5,
            borderColor: const Color(0xFF065F46),
            borderStrokeWidth: 2.0,
          ),
        );
      }
    }
    return lines;
  }

  List<Marker> _buildFlutterMapMarkers() {
    final markers = <Marker>[];
    final driverPos =
        _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;

    if (widget.hasActiveOrder) {
      // 1. Vendor / Store Pin
      markers.add(
        Marker(
          point: _storePoint,
          width: 116,
          height: 76,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _moveMap(_storePoint, zoom: 16.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: const Color(0xFFEA580C), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    tx(widget.merchantName.isEmpty
                        ? 'فرۆشگا'
                        : widget.merchantName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 2. Customer Pin
      markers.add(
        Marker(
          point: _customerPoint,
          width: 116,
          height: 76,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _moveMap(_customerPoint, zoom: 16.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: const Color(0xFF0284C7), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    tx(widget.customerName.isEmpty
                        ? 'کڕیار'
                        : widget.customerName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Captain / Driver Live Marker (always shown so captain sees their pin)
    markers.add(
      Marker(
        point: driverPos,
        width: 96,
        height: 96,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final p = _pulseController.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38 + (p * 42),
                  height: 38 + (p * 42),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E676)
                        .withValues(alpha: (1.0 - p) * 0.35),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F172A),
                          width: 2.8,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.two_wheeler_rounded,
                        color: Color(0xFF0F172A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tx(_usingRealGps
                            ? '${_speedKmh.toStringAsFixed(0)} km/h'
                            : 'کاپتن'),
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );

    return markers;
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
    final phone = RegaResponsive.isPhone(context);
    final padH = RegaResponsive.pagePadding(context);

    final mapCenter =
        _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos;
    final mapZoom = _usingRealGps ? 15.6 : 14.4;

    const gold = Color(0xFFFAC800);
    const brandGreen = Color(0xFF00B34B);

    // Dynamic bottom offset so map controls sit cleanly above bottom card
    final double controlsBottom = hasOrder
        ? (widget.isOrderCardExpanded ? (phone ? 295.0 : 310.0) : 84.0)
        : (phone ? 112.0 : 120.0);

    return Stack(
      children: [
        Positioned.fill(
          child: RegaStandardMap(
            key: _regaMapKey,
            center: mapCenter,
            zoom: mapZoom,
            showLayersFab: false,
            showCustomerControls: false,
            onMapReady: _onFlutterMapReady,
            onUserGesture: (_) {
              if (_followCaptain) {
                setState(() => _followCaptain = false);
              }
            },
            onStyleChanged: (id) {
              if (mounted) {
                setState(() => _isSatellite = id == RegaMapStyleId.satellite);
              }
            },
            polylines: _buildFlutterMapPolylines(),
            markers: _buildFlutterMapMarkers(),
          ),
        ),

        // Top Responsive Map Control Bar (Never overlaps!)
        Positioned(
          top: 10,
          left: padH,
          right: padH,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    // Left group: Satellite toggle + Refresh/Sync + Route Fit
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CaptainModeChip(
                              label: _isSatellite ? 'نەخشە' : 'سەتەلایت',
                              icon: _isSatellite
                                  ? Icons.map_rounded
                                  : Icons.satellite_alt_rounded,
                              active: _isSatellite,
                              activeColor: gold,
                              compact: phone,
                              onTap: () =>
                                  _regaMapKey.currentState?.toggleSatellite(),
                            ),
                            const SizedBox(width: 6),
                            _CaptainIconChip(
                              icon: Icons.sync_rounded,
                              busy: _refreshBusy,
                              tooltip: tx(_mt('sync_order')),
                              onTap: syncLatestCustomerOrderFromServer,
                            ),
                            if (hasOrder) ...[
                              const SizedBox(width: 6),
                              _CaptainModeChip(
                                label: 'ڕێگا',
                                icon: Icons.route_rounded,
                                active: false,
                                activeColor: brandGreen,
                                compact: phone,
                                onTap: () =>
                                    _fitFullRoute(keepFollowing: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right: My Location button with live GPS status indicator
                    _CaptainModeChip(
                      label: 'شوێنەکەم',
                      icon: _usingRealGps
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      active: true,
                      activeColor: gold,
                      busy: _gpsBusy,
                      compact: phone,
                      dotColor: _usingRealGps
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                      onTap: () async {
                        setState(() => _followCaptain = true);
                        await _startRealGpsIfAvailable(requestPermission: true);
                        if (_mapReady) {
                          await _moveMap(
                            _usingRealGps ? _displayDriverPos : _effectiveFallbackDriverPos,
                            zoom: 15.6,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Live Order Navigation HUD (shown right below top chips when order is active)
        if (hasOrder)
          Positioned(
            top: 56,
            left: padH,
            right: padH,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 620),
                ),
                child: Material(
                  color: RC.bg(Colors.white).withValues(alpha: 0.96),
                  elevation: 6,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: phone ? 10 : 14,
                      vertical: phone ? 8 : 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: phone ? 36 : 40,
                          height: phone ? 36 : 40,
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _navigationIcon(),
                            color: RC.fg(const Color(0xFF0F172A)),
                            size: phone ? 20 : 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tx(_navigationHeadline()),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: RC.fg(const Color(0xFF0F172A)),
                                  fontSize: phone ? 12.5 : 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _usingRealGps
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      tx(_usingRealGps
                                          ? _mt('gps_live_sync')
                                          : _mt('gps_live_kalar')),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _usingRealGps
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFD97706),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Quick jump to Store / Customer pins
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 30, minHeight: 30),
                          tooltip: tx(widget.merchantName),
                          icon: const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFFEA580C),
                            size: 19,
                          ),
                          onPressed: () {
                            setState(() => _followCaptain = false);
                            _moveMap(_storePoint, zoom: 16.4);
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 30, minHeight: 30),
                          tooltip: tx(widget.customerName),
                          icon: const Icon(
                            Icons.home_rounded,
                            color: Color(0xFF0284C7),
                            size: 19,
                          ),
                          onPressed: () {
                            setState(() => _followCaptain = false);
                            _moveMap(_customerPoint, zoom: 16.4);
                          },
                        ),
                        const SizedBox(width: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: phone ? 84 : 120,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: phone ? 8 : 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: gold,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tx(_formatCountdown(_etaSeconds)),
                                      style: TextStyle(
                                        color: const Color(0xFF0F172A),
                                        fontSize: phone ? 13 : 14.5,
                                        fontWeight: FontWeight.w900,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Floating Zoom & Map Style Controls (Right Rail — dynamically positioned above bottom card)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          right: padH,
          bottom: controlsBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapHudButton(
                icon: Icons.add_rounded,
                active: false,
                tooltip: '+',
                onTap: () => _regaMapKey.currentState?.zoomBy(1),
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: Icons.remove_rounded,
                active: false,
                tooltip: '−',
                onTap: () => _regaMapKey.currentState?.zoomBy(-1),
              ),
              const SizedBox(height: 8),
              _MapHudButton(
                icon: Icons.layers_rounded,
                active: _isSatellite,
                tooltip: tx(_mt('map_style')),
                onTap: () => _regaMapKey.currentState?.cycleStyle(),
              ),
            ],
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
  final bool compact;
  final Color? dotColor;

  const _CaptainModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.busy = false,
    this.compact = false,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? activeColor : RC.bg(Colors.white),
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 14,
            vertical: compact ? 8 : 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F172A),
                  ),
                )
              else
                Icon(
                  icon,
                  size: compact ? 15.5 : 17,
                  color: active
                      ? const Color(0xFF0F172A)
                      : RC.fg(const Color(0xFF0F172A)),
                ),
              const SizedBox(width: 5),
              Text(
                tx(label),
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w900,
                  color: active
                      ? const Color(0xFF0F172A)
                      : RC.fg(const Color(0xFF0F172A)),
                ),
              ),
              if (dotColor != null) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptainIconChip extends StatelessWidget {
  final IconData icon;
  final bool busy;
  final String tooltip;
  final VoidCallback onTap;

  const _CaptainIconChip({
    required this.icon,
    required this.busy,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: RC.bg(Colors.white),
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: busy ? null : onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF16A34A),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 18,
                      color: RC.fg(const Color(0xFF0F172A)),
                    ),
            ),
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
        color: active ? const Color(0xFF0F172A) : Colors.white,
        shape: const CircleBorder(),
        elevation: 5,
        shadowColor: Colors.black38,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: active
                  ? const Color(0xFF00E676)
                  : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}
