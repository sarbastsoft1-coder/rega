import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'map/mapbox_directions.dart';
import 'map/mapbox_tiles.dart';
import 'rega_mobile.dart';

import 'rega_i18n.dart';
import 'rega_colors.dart';

/// Fresh GPS settings — on web force `maximumAge: 0` so browsers cannot
/// hand back a cached/stale fix (hardcoded Kalar-center lookalike bug).
LocationSettings regaFreshLocationSettings({
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

/// Resolve a live device position. Returns null when GPS/permission unavailable.
Future<Position?> regaResolveCurrentPosition({
  Duration timeLimit = const Duration(seconds: 20),
}) async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) return null;

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    return null;
  }

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: regaFreshLocationSettings(timeLimit: timeLimit),
    );
  } catch (_) {
    // Prefer a recent last-known fix over failing completely.
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

/// Neighborhood centers — filled from backend zones; no frozen labels as UI source of truth.
class KalarGeoCatalog {
  /// Downtown Kalar — default map center when user has not pinned yet.
  static const LatLng kalarCenter = LatLng(34.6836, 45.3189);

  /// Runtime coords synced from admin/backend neighborhoods (id → LatLng).
  static final Map<String, LatLng> neighborhoodCoords = {};

  /// Max distance (meters) to treat a pin as inside a delivery zone.
  static const double maxZoneMatchMeters = 12000;

  /// Rough Iraq bounds for map picking (user can pin park/home anywhere).
  static const LatLng iraqCenter = LatLng(33.3152, 44.3661); // Baghdad
  static const double iraqMinLat = 29.0;
  static const double iraqMaxLat = 37.5;
  static const double iraqMinLng = 38.5;
  static const double iraqMaxLng = 49.0;

  static void syncFromZones(Iterable<({String id, double? lat, double? lng})> zones) {
    for (final z in zones) {
      final lat = z.lat;
      final lng = z.lng;
      if (lat == null || lng == null) continue;
      neighborhoodCoords[z.id] = LatLng(lat, lng);
    }
  }

  static LatLng forNeighborhoodId(String id) {
    return neighborhoodCoords[id] ?? kalarCenter;
  }

  static bool isInsideIraq(double lat, double lng) {
    return lat >= iraqMinLat &&
        lat <= iraqMaxLat &&
        lng >= iraqMinLng &&
        lng <= iraqMaxLng;
  }
}

/// Interactive map to pick delivery place anywhere in Iraq
/// (current GPS OR a future place like a park the user will go to later).
class KalarInteractivePickerMap extends StatefulWidget {
  final LatLng initialPoint;
  /// Live pin label — place note / reverse-geocode / backend zone (never a frozen default).
  final String pinLabel;
  final ValueChanged<LatLng> onLocationChanged;
  final bool allowIraqWide;
  /// When true (e.g. first open with no saved pin), jump to live GPS immediately.
  final bool autoLocateOnStart;

  const KalarInteractivePickerMap({
    super.key,
    required this.initialPoint,
    required this.pinLabel,
    required this.onLocationChanged,
    this.allowIraqWide = true,
    this.autoLocateOnStart = false,
  });

  @override
  State<KalarInteractivePickerMap> createState() => _KalarInteractivePickerMapState();
}

class _KalarInteractivePickerMapState extends State<KalarInteractivePickerMap> {
  final MapController _controller = MapController();
  late LatLng _pinned;
  /// Same cycle as driver + live tracker: 0 streets, 1 satellite, 2 outdoors.
  int _mapStyleIndex = 1;
  bool _ready = false;
  bool _locating = false;
  bool _didAutoLocate = false;
  /// When true, map pans under a fixed center pin (جوڵاندن).
  bool _panPickMode = true;

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

  @override
  void initState() {
    super.initState();
    _pinned = widget.initialPoint;
    if (widget.autoLocateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoLocate) return;
        _didAutoLocate = true;
        _goToCurrentGps(silent: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant KalarInteractivePickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPoint != widget.initialPoint) {
      _pinned = widget.initialPoint;
      if (_ready) {
        _controller.move(_pinned, 15.8);
      }
    }
    if (oldWidget.pinLabel != widget.pinLabel) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPin(LatLng pt, {double? zoom}) {
    setState(() => _pinned = pt);
    widget.onLocationChanged(pt);
    if (_ready) {
      try {
        _controller.move(pt, zoom ?? _controller.camera.zoom);
      } catch (_) {}
    }
  }

  void _toast(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(tx(msg)),
        backgroundColor: bg ?? RC.bg(const Color(0xFFDC2626)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _goToCurrentGps({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent) {
          _toast('تکایە GPS / Location مۆبایلەکەت هەڵبکە');
          if (!kIsWeb) {
            try {
              await Geolocator.openLocationSettings();
            } catch (_) {}
          }
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        if (!silent) {
          _toast('ڕێگەپێدانی لۆکەیشن پێویستە بۆ دیاریکردنی شوێنەکەت');
        }
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        if (!silent) {
          _toast('لە ڕێکخستنی مۆبایل ڕێگەپێدانی لۆکەیشن چالاک بکە');
          if (!kIsWeb) {
            try {
              await Geolocator.openAppSettings();
            } catch (_) {}
          }
        }
        return;
      }

      final pos = await regaResolveCurrentPosition();
      if (pos == null) {
        if (!silent) {
          _toast('نەتوانرا شوێنەکەت بدۆزرێتەوە. دووبارە هەوڵبدەرەوە');
        }
        return;
      }
      final pt = LatLng(pos.latitude, pos.longitude);
      if (widget.allowIraqWide &&
          !KalarGeoCatalog.isInsideIraq(pt.latitude, pt.longitude)) {
        if (!silent) {
          _toast('شوێنی GPS دەرەوەی عێراقە. تکایە شوێنێک لە ناو عێراق هەڵبژێرە');
        }
        return;
      }
      _setPin(pt, zoom: 16.2);
      if (!silent) {
        _toast(
          '🎯 شوێنەکەت دیاریکرا',
          bg: RC.bg(const Color(0xFF059669)),
        );
      }
    } catch (_) {
      if (!silent) {
        _toast('هەڵەی GPS. تکایە دووبارە هەوڵبدەرەوە');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Center delivery pin: classic location teardrop + live label bubble.
  /// Drawn with CustomPaint (not Material Icons) so web icon-fonts cannot
  /// fall back to a home glyph after tree-shaking.
  Widget _buildRedPin({double size = 34}) {
    final pinW = size * 1.15;
    final pinH = size * 1.45;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: RC.bg(const Color(0xFFDC2626)), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: RC.bg(Colors.black26),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            tx(widget.pinLabel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RC.fg(const Color(0xFF0F172A)),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: pinW,
          height: pinH,
          child: CustomPaint(
            painter: _LocationPinPainter(
              fill: RC.bg(const Color(0xFFDC2626)),
              stroke: RC.bg(Colors.white),
              hole: RC.bg(Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final minZ = widget.allowIraqWide ? 5.2 : 12.0;
    final satelliteLike = _mapStyleIndex == 1;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _pinned,
            initialZoom: widget.allowIraqWide ? 16.0 : 15.4,
            minZoom: minZ,
            maxZoom: 18.5,
            backgroundColor: satelliteLike
                ? RC.bg(Color(0xFF0F172A))
                : RC.bg(Color(0xFFF1F5F9)),
            onMapReady: () {
              _ready = true;
              if (_panPickMode) {
                try {
                  _controller.move(_pinned, widget.allowIraqWide ? 16.0 : 15.4);
                } catch (_) {}
              }
            },
            onPositionChanged: (position, hasGesture) {
              if (_panPickMode && !hasGesture) {
                final center = position.center;
                if (widget.allowIraqWide &&
                    !KalarGeoCatalog.isInsideIraq(center.latitude, center.longitude)) {
                  return;
                }
                if (center.latitude != _pinned.latitude || center.longitude != _pinned.longitude) {
                  _setPin(center);
                }
              }
            },
            onTap: _panPickMode
                ? null
                : (_, latLng) {
                    if (widget.allowIraqWide &&
                        !KalarGeoCatalog.isInsideIraq(latLng.latitude, latLng.longitude)) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text(tx('تکایە شوێنێک لە ناو عێراق هەڵبژێرە')),
                          backgroundColor: RC.bg(Color(0xFFDC2626)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    _setPin(latLng);
                  },
          ),
          children: [
            MapboxTiles.layer(
              key: ValueKey(_mapStyleIndex),
              style: _mapboxStyle,
              userAgentPackageName: 'iq.rega.customer',
            ),
            if (!_panPickMode)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pinned,
                    width: 140,
                    height: 88,
                    alignment: Alignment.topCenter,
                    child: _buildRedPin(),
                  ),
                ],
              ),
          ],
        ),
        if (_panPickMode)
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0, -0.08),
              child: _buildRedPin(size: 36),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  _TrackerMapBtn(
                    icon: _mapStyleIndex == 1
                        ? Icons.satellite_alt_rounded
                        : Icons.layers_rounded,
                    active: _mapStyleIndex != 0,
                    onTap: () => setState(() => _mapStyleIndex = (_mapStyleIndex + 1) % 3),
                  ),
                  const Spacer(),
                  _PickerMapPill(
                    label: tx('جوڵاندن'),
                    icon: Icons.open_with_rounded,
                    active: _panPickMode,
                    onTap: () {
                      setState(() => _panPickMode = !_panPickMode);
                      if (_panPickMode && _ready) {
                        try {
                          _controller.move(_pinned, _controller.camera.zoom);
                        } catch (_) {}
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _PickerMapPill(
                    label: tx('شوێنەکەم'),
                    icon: _locating ? Icons.hourglass_top_rounded : Icons.my_location_rounded,
                    active: _locating,
                    onTap: _locating ? () {} : () => _goToCurrentGps(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-Screen Second-by-Second Live Order Tracking Map ("Sec by Sec Until Get Order")
class CustomerLiveOrderTrackerScreen extends StatefulWidget {
  final String orderCode;
  final String storeName;
  final String customerAddress;
  final String driverName;
  final String driverPhone;
  final String deliveryPin;
  final int totalAmount;
  final String initialStatus;
  final LatLng storeLocation;
  final LatLng customerLocation;
  final String apiBaseUrl;
  final ValueChanged<String>? onOrderStatusChanged;

  CustomerLiveOrderTrackerScreen({
    super.key,
    required this.orderCode,
    required this.storeName,
    required this.customerAddress,
    required this.driverName,
    required this.driverPhone,
    required this.deliveryPin,
    required this.totalAmount,
    required this.initialStatus,
    this.storeLocation = const LatLng(34.6836, 45.3189),
    this.customerLocation = const LatLng(34.6912, 45.3264),
    String? apiBaseUrl,
    this.onOrderStatusChanged,
  }) : apiBaseUrl = apiBaseUrl ?? RegaApiHost.apiV1;

  @override
  State<CustomerLiveOrderTrackerScreen> createState() =>
      _CustomerLiveOrderTrackerScreenState();
}

class _CustomerLiveOrderTrackerScreenState extends State<CustomerLiveOrderTrackerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  late AnimationController _pulseController;
  late AnimationController _glideController;

  Timer? _oneSecondTimer;

  int _mapStyleIndex = 0; // 0: Mapbox Streets, 1: Satellite, 2: Outdoors
  bool _followDriver = true;
  bool _mapReady = false;
  /// Local fake movement — OFF by default; only via play button.
  bool _autoDriveSimulation = false;

  late String _status; // 'pending' | 'preparing' | 'picked_up' | 'on_the_way' | 'arrived_customer' | 'delivered'
  late String _driverName;
  late String _driverPhone;
  String _vehicleLabel = 'ماتۆڕسوار • KLR-402';

  late LatLng _dispatchOrigin;
  List<LatLng> _leg1ToStore = [];
  List<LatLng> _leg2ToCustomer = [];
  List<LatLng> _fullRoute = [];
  int _storeSplitIndex = 12;

  LatLng _prevDriverPos = const LatLng(34.6798, 45.3145);
  LatLng _targetDriverPos = const LatLng(34.6798, 45.3145);
  LatLng _displayDriverPos = const LatLng(34.6798, 45.3145);

  double _headingDeg = 45.0;
  double _speedKmh = 31.0;
  int _etaSeconds = 95;
  int _remainingMeters = 1280;
  int _secondsSinceOpen = 0;
  double _localProgress = 0.08; // 0.0 -> 1.0 along _fullRoute

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _driverName = widget.driverName;
    _driverPhone = widget.driverPhone;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..addListener(_onGlideTick);

    _dispatchOrigin = LatLng(
      widget.storeLocation.latitude - 0.0036,
      widget.storeLocation.longitude - 0.0042,
    );

    _buildInitialRoute();
    _registerAndSyncBackend();
    _startSecondBySecondLoop();
  }

  @override
  void dispose() {
    _oneSecondTimer?.cancel();
    _pulseController.dispose();
    _glideController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _buildInitialRoute() {
    // Temporary straight fallback until Mapbox Directions returns road geometry.
    final leg1 = [_dispatchOrigin, widget.storeLocation];
    final leg2 = [widget.storeLocation, widget.customerLocation];
    _leg1ToStore = leg1;
    _leg2ToCustomer = leg2;
    _storeSplitIndex = leg1.length - 1;
    _fullRoute = [...leg1, ...leg2.skip(1)];

    if (_status == 'delivered') {
      _localProgress = 1.0;
      _etaSeconds = 0;
      _remainingMeters = 0;
      _speedKmh = 0;
    } else if (_status == 'on_the_way') {
      _localProgress = (_storeSplitIndex / (_fullRoute.length - 1)) + 0.05;
    } else if (_status == 'picked_up' || _status == 'at_store') {
      _localProgress = (_storeSplitIndex / (_fullRoute.length - 1));
    } else {
      // Driver starting journey heading to store to pick up order
      _localProgress = 0.02;
    }

    final startPos = _pointAlong(_fullRoute, _localProgress);
    _prevDriverPos = startPos;
    _targetDriverPos = startPos;
    _displayDriverPos = startPos;
    _recomputeLocalMetrics();

    _fetchMapboxStreetRoute();
  }

  Future<void> _fetchMapboxStreetRoute() async {
    try {
      final (raw1, raw2) = await MapboxDirections.twoLegRoute(
        origin: _dispatchOrigin,
        store: widget.storeLocation,
        customer: widget.customerLocation,
      );
      if (!mounted) return;
      final leg1 = MapboxDirections.densify(raw1, minPoints: 24);
      final leg2 = MapboxDirections.densify(raw2, minPoints: 52);
      if (leg1.length >= 2 && leg2.length >= 2) {
        setState(() {
          _leg1ToStore = leg1;
          _leg2ToCustomer = leg2;
          _storeSplitIndex = leg1.length - 1;
          _fullRoute = [...leg1, ...leg2.skip(1)];
          _recomputeLocalMetrics();
        });
      }
    } catch (_) {}
  }

  Future<void> _registerAndSyncBackend() async {
    final cleanRef = widget.orderCode.replaceAll('#', '').trim();
    if (cleanRef.isEmpty) return;
    try {
      // Check if session already exists; if not, register customer's order coordinates & PIN
      final check = await http
          .get(
            Uri.parse('${widget.apiBaseUrl}/live-telemetry/$cleanRef'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 1200));

      if (check.statusCode == 200) {
        // Also push customer's exact coordinates if newly placed
        if (_secondsSinceOpen <= 1 && _status != 'delivered') {
          await http
              .post(
                Uri.parse('${widget.apiBaseUrl}/live-telemetry/register'),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'order_ref': cleanRef,
                  'store_name': widget.storeName,
                  'store_lat': widget.storeLocation.latitude,
                  'store_lng': widget.storeLocation.longitude,
                  'customer_address': widget.customerAddress,
                  'customer_lat': widget.customerLocation.latitude,
                  'customer_lng': widget.customerLocation.longitude,
                  'delivery_pin': widget.deliveryPin,
                  'total_amount': widget.totalAmount,
                }),
              )
              .timeout(const Duration(milliseconds: 1200));
        }
      }
    } catch (_) {}
  }

  void _startSecondBySecondLoop() {
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      _secondsSinceOpen += 1;

      if (_status == 'delivered') return;

      final synced = await _pollBackendOneSecond();
      // Fake local movement only when user presses play (never auto).
      if (!synced &&
          _autoDriveSimulation &&
          _status != 'pending' &&
          _status != 'preparing') {
        _stepLocalOneSecond();
      }
    });
  }

  Future<bool> _pollBackendOneSecond() async {
    final cleanRef = widget.orderCode.replaceAll('#', '').trim();
    if (cleanRef.isEmpty) return false;

    try {
      final res = await http
          .get(
            Uri.parse('${widget.apiBaseUrl}/live-telemetry/$cleanRef'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 850));

      if (!mounted || res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return false;

      final driver = (data['driver'] as Map<String, dynamic>?) ?? const {};
      // Mirror real-time 1-second coordinates from Captain App or Backend Telemetry Engine!
      final dLat = (driver['lat'] as num?)?.toDouble() ?? _displayDriverPos.latitude;
      final dLng = (driver['lng'] as num?)?.toDouble() ?? _displayDriverPos.longitude;
      final remoteStatus = (data['status'] ?? _status).toString();

      _driverName = (driver['name'] ?? _driverName).toString();
      _driverPhone = (driver['phone'] ?? _driverPhone).toString();
      _vehicleLabel = (driver['vehicle_label'] ?? _vehicleLabel).toString();
      _speedKmh = (driver['speed_kmh'] as num?)?.toDouble() ?? _speedKmh;
      _etaSeconds = (data['eta_seconds'] as num?)?.toInt() ?? _etaSeconds;
      _remainingMeters = (data['distance_remaining_meters'] as num?)?.toInt() ?? _remainingMeters;
      _localProgress = ((data['progress_permille'] as num?)?.toDouble() ?? 500.0) / 1000.0;

      final pLeg = data['route_pickup'] as List<dynamic>?;
      final dLeg = data['route_delivery'] as List<dynamic>?;
      if (pLeg != null && pLeg.length >= 2 && dLeg != null && dLeg.length >= 2) {
        final pPts = pLeg.map((e) => LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble())).toList();
        final dPts = dLeg.map((e) => LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble())).toList();
        if (_leg1ToStore.isEmpty || _leg2ToCustomer.isEmpty) {
          _leg1ToStore = pPts;
          _leg2ToCustomer = dPts;
          _storeSplitIndex = pPts.length - 1;
          _fullRoute = [...pPts, ...dPts.skip(1)];
        }
      }

      if (remoteStatus != _status) {
        _updateStatus(remoteStatus);
      }
      _glideDriverTo(LatLng(dLat, dLng), headingOverride: (driver['heading'] as num?)?.toDouble());
      return true;
    } catch (_) {
      return false;
    }
  }

  void _stepLocalOneSecond() {
    if (_status == 'delivered' || !_autoDriveSimulation) return;

    // Manual play-button movement along Mapbox road polyline
    _localProgress = (_localProgress + 0.015).clamp(0.0, 1.0);
    final nextPos = _pointAlong(_fullRoute, _localProgress);
    _speedKmh = 29.0 + ((_secondsSinceOpen % 4) * 1.5);
    _glideDriverTo(nextPos);
    _recomputeLocalMetrics();
  }

  void _updateStatus(String next) {
    if (_status == next) return;
    setState(() {
      _status = next;
    });
    if (widget.onOrderStatusChanged != null) {
      widget.onOrderStatusChanged!(next);
    }
  }

  Future<void> _confirmOrderReceivedByCustomer() async {
    final cleanRef = widget.orderCode.replaceAll('#', '').trim();
    try {
      await http
          .post(
            Uri.parse('${widget.apiBaseUrl}/live-telemetry/$cleanRef/verify-pin'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    _localProgress = 1.0;
    _etaSeconds = 0;
    _remainingMeters = 0;
    _speedKmh = 0.0;
    _glideDriverTo(widget.customerLocation);
    _updateStatus('delivered');
  }

  void _glideDriverTo(LatLng next, {double? headingOverride}) {
    final dist = _haversineMeters(_displayDriverPos, next);
    if (headingOverride != null) {
      _headingDeg = headingOverride;
    } else if (dist > 0.3) {
      _headingDeg = _bearingDegrees(_displayDriverPos, next);
    }

    _prevDriverPos = _displayDriverPos;
    _targetDriverPos = next;
    _glideController.forward(from: 0.0);

    if (_followDriver && _mapReady) {
      try {
        final curZoom = _mapController.camera.zoom;
        final safeZoom = (curZoom.isNaN || curZoom < 12.0) ? 15.6 : curZoom;
        _mapController.move(next, safeZoom);
      } catch (_) {}
    }
  }

  void _onGlideTick() {
    if (!mounted) return;
    final t = Curves.easeInOut.transform(_glideController.value);
    final cur = LatLng(
      _prevDriverPos.latitude + (_targetDriverPos.latitude - _prevDriverPos.latitude) * t,
      _prevDriverPos.longitude + (_targetDriverPos.longitude - _prevDriverPos.longitude) * t,
    );
    setState(() {
      _displayDriverPos = cur;
    });
    if (_followDriver && _mapReady) {
      try {
        final curZoom = _mapController.camera.zoom;
        final safeZoom = (curZoom.isNaN || curZoom < 12.0) ? 15.6 : curZoom;
        _mapController.move(cur, safeZoom);
      } catch (_) {}
    }
  }

  void _recomputeLocalMetrics() {
    if (_status == 'delivered' || _status == 'arrived_customer' || _localProgress >= 1.0) {
      _remainingMeters = 0;
      _etaSeconds = 0;
      return;
    }

    final storeRatio = _fullRoute.length > 2
        ? (_storeSplitIndex / (_fullRoute.length - 1))
        : 0.35;

    final isHeadingToStore = _localProgress < storeRatio;

    if (isHeadingToStore && _leg1ToStore.isNotEmpty) {
      // Metric is distance & ETA to the store!
      final leg1Progress = (_localProgress / storeRatio).clamp(0.0, 1.0);
      final rem1 = _remainingSubPolyline(_leg1ToStore, leg1Progress, _displayDriverPos);
      double meters = 0;
      for (var i = 0; i < rem1.length - 1; i++) {
        meters += _haversineMeters(rem1[i], rem1[i + 1]);
      }
      _remainingMeters = meters.round();
      _etaSeconds = math.max(1, (meters / 8.8).round());
    } else {
      // Metric is distance & ETA to the customer door!
      final leg2Progress = ((_localProgress - storeRatio) / (1.0 - storeRatio)).clamp(0.0, 1.0);
      final rem2 = _remainingSubPolyline(_leg2ToCustomer, leg2Progress, _displayDriverPos);
      double meters = 0;
      for (var i = 0; i < rem2.length - 1; i++) {
        meters += _haversineMeters(rem2[i], rem2[i + 1]);
      }
      _remainingMeters = meters.round();
      _etaSeconds = math.max(1, (meters / 9.6).round());
    }
  }

  List<LatLng> _remainingSubPolyline(List<LatLng> pts, double progress, LatLng current) {
    if (pts.length < 2 || progress >= 1.0) return [];
    final nextIdx = (progress.clamp(0.0, 1.0) * (pts.length - 1)).ceil().clamp(1, pts.length - 1);
    return [current, ...pts.sublist(nextIdx)];
  }

  List<LatLng> _traveledSubPolyline(List<LatLng> pts, double progress, LatLng current) {
    if (pts.length < 2 || progress <= 0.0) return [];
    final prevIdx = (progress.clamp(0.0, 1.0) * (pts.length - 1)).floor().clamp(0, pts.length - 1);
    return [...pts.sublist(0, prevIdx + 1), current];
  }

  void _safeFitBounds(List<LatLng> points, {double maxZoom = 16.2, double minZoom = 12.0}) {
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

  void _focusOnPickupRoute() {
    if (!_mapReady) return;
    _followDriver = false;
    _safeFitBounds([
      _displayDriverPos,
      _dispatchOrigin,
      widget.storeLocation,
    ]);
    setState(() {});
  }

  void _focusOnDeliveryRoute() {
    if (!_mapReady) return;
    _followDriver = false;
    _safeFitBounds([
      widget.storeLocation,
      widget.customerLocation,
      if (_localProgress >= 0.35) _displayDriverPos,
    ]);
    setState(() {});
  }

  LatLng _pointAlong(List<LatLng> pts, double progress) {
    if (pts.isEmpty) return widget.storeLocation;
    if (pts.length == 1) return pts.first;
    final p = progress.clamp(0.0, 1.0);
    final exact = p * (pts.length - 1);
    final idx = exact.floor().clamp(0, pts.length - 2);
    final frac = exact - idx;
    return LatLng(
      pts[idx].latitude + (pts[idx + 1].latitude - pts[idx].latitude) * frac,
      pts[idx].longitude + (pts[idx + 1].longitude - pts[idx].longitude) * frac,
    );
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

  void _fitAllMarkers({bool keepFollowing = false}) {
    if (!_mapReady) return;
    _followDriver = keepFollowing;
    _safeFitBounds([
      _displayDriverPos,
      widget.storeLocation,
      widget.customerLocation,
    ]);
    setState(() {});
  }

  void _exitLiveTracker() {
    if (!mounted) return;
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  String _formatMoney(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  int get _activeStepIndex {
    switch (_status) {
      case 'pending':
      case 'accepted':
        return 0;
      case 'heading_to_store':
      case 'driver_assigned':
      case 'arriving_pickup':
      case 'preparing':
      case 'ready':
        return 1;
      case 'picked_up':
      case 'at_store':
      case 'arrived_pickup':
        return 2;
      case 'on_the_way':
      case 'arrived_customer':
        return 3;
      case 'delivered':
      case 'completed':
        return 4;
      default:
        return 1;
    }
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

  @override
  Widget build(BuildContext context) {
    final storeRatio = _fullRoute.length > 2
        ? (_storeSplitIndex / (_fullRoute.length - 1))
        : 0.35;
    final isHeadingToStore = _localProgress < storeRatio;
    final isDelivered = _status == 'delivered';

    final polylines = <Polyline>[];

    if (isHeadingToStore) {
      // 1. Way to Get Order (Driver -> Store) Active!
      final leg1Progress = (_localProgress / storeRatio).clamp(0.0, 1.0);
      final traveled1 = _traveledSubPolyline(_leg1ToStore, leg1Progress, _displayDriverPos);
      final remain1 = _remainingSubPolyline(_leg1ToStore, leg1Progress, _displayDriverPos);

      // Traveled trail
      if (traveled1.length >= 2) {
        polylines.add(
          Polyline(
            points: traveled1,
            strokeWidth: 5,
            color: RC.bg(Color(0xFF94A3B8)).withValues(alpha: 0.60),
          ),
        );
      }
      // Glowing Amber Active Pickup Line
      if (remain1.length >= 2) {
        polylines.add(
          Polyline(
            points: remain1,
            strokeWidth: 8,
            color: RC.bg(Color(0xFFF59E0B)),
            borderStrokeWidth: 2.5,
            borderColor: RC.bg(Color(0xFF78350F)),
          ),
        );
      }
      // Dashed Emerald Future Delivery Line (Store -> Customer)
      if (_leg2ToCustomer.length >= 2) {
        polylines.add(
          Polyline(
            points: _leg2ToCustomer,
            strokeWidth: 5.5,
            pattern: StrokePattern.dashed(segments: const [14, 10]),
            color: RC.bg(Color(0xFF10B981)).withValues(alpha: 0.75),
          ),
        );
      }
    } else {
      // 2. Leg 1 is Completed (Historical trail to store)
      if (_leg1ToStore.length >= 2) {
        polylines.add(
          Polyline(
            points: _leg1ToStore,
            strokeWidth: 4,
            color: RC.bg(Color(0xFF94A3B8)).withValues(alpha: 0.45),
          ),
        );
      }

      // Leg 2 Active Delivery Line (Store -> Customer)
      final leg2Progress = ((_localProgress - storeRatio) / (1.0 - storeRatio)).clamp(0.0, 1.0);
      final traveled2 = _traveledSubPolyline(_leg2ToCustomer, leg2Progress, _displayDriverPos);
      final remain2 = _remainingSubPolyline(_leg2ToCustomer, leg2Progress, _displayDriverPos);

      if (traveled2.length >= 2) {
        polylines.add(
          Polyline(
            points: traveled2,
            strokeWidth: 5,
            color: RC.bg(Color(0xFF86EFAC)).withValues(alpha: 0.55),
          ),
        );
      }
      if (remain2.length >= 2 && !isDelivered) {
        polylines.add(
          Polyline(
            points: remain2,
            strokeWidth: 8.5,
            color: RC.bg(Color(0xFF16A34A)),
            borderStrokeWidth: 2.5,
            borderColor: RC.bg(Color(0xFF064E3B)),
          ),
        );
      }
      if (isDelivered && _leg2ToCustomer.length >= 2) {
        polylines.add(
          Polyline(
            points: _leg2ToCustomer,
            strokeWidth: 7,
            color: RC.bg(Color(0xFF16A34A)),
          ),
        );
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: RC.bg(Color(0xFFF1F5F9)),
        body: Stack(
          children: [
            // 1. Real Interactive Kalar Street Map
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _displayDriverPos,
                  initialZoom: 15.6,
                  minZoom: 11.0,
                  maxZoom: 18.5,
                  backgroundColor: RC.bg(Color(0xFFF1F5F9)),
                  onMapReady: () {
                    _mapReady = true;
                    try {
                      _mapController.move(_displayDriverPos, 15.6);
                    } catch (_) {}
                    _followDriver = true;
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (mounted && _mapReady) {
                        _safeFitBounds([
                          _displayDriverPos,
                          widget.storeLocation,
                          widget.customerLocation,
                        ]);
                      }
                    });
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && _followDriver) {
                      setState(() => _followDriver = false);
                    }
                  },
                ),
                children: [
                  MapboxTiles.layer(
                    style: _mapboxStyle,
                    userAgentPackageName: 'iq.rega.customer',
                  ),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(
                    markers: [
                      // Store Pin (Pickup)
                      Marker(
                        point: widget.storeLocation,
                        width: 140,
                        height: 94,
                        alignment: Alignment.topCenter,
                        child: _CustomerMapPin(
                          icon: Icons.storefront_rounded,
                          color: RC.bg(Color(0xFFEA580C)),
                          label: widget.storeName,
                          subtitle: tx("١. وەرگرتن لە فرۆشگا"),
                          badge: isHeadingToStore ? "شۆفێر بەڕێوەیە 🛵" : "داواکاری وەرگیرا ✅",
                          badgeColor: isHeadingToStore ? RC.bg(Color(0xFFD97706)) : RC.bg(Color(0xFF16A34A)),
                          isHighlighted: isHeadingToStore,
                        ),
                      ),

                      // Customer delivery pin
                      Marker(
                        point: widget.customerLocation,
                        width: 140,
                        height: 94,
                        alignment: Alignment.topCenter,
                        child: _CustomerMapPin(
                          icon: Icons.location_on_rounded,
                          color: RC.bg(Color(0xFFDC2626)),
                          label: tx("شوێنی تۆ 📍"),
                          subtitle: tx("٢. شوێنی گەیاندن"),
                          badge: isDelivered
                              ? "گەیشت 🎉"
                              : (!isHeadingToStore ? "شۆفێر بەرەو تۆ دێت 🚀" : "چاوەڕوانی وەرگرتن"),
                          badgeColor: !isHeadingToStore ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFF64748B)),
                          isHighlighted: !isHeadingToStore && !isDelivered,
                        ),
                      ),

                      // Gliding 60fps Driver Motorcycle Marker with Live Heading & Tooltip
                      if (_status != 'delivered')
                        Marker(
                          point: _displayDriverPos,
                          width: 170,
                          height: 110,
                          alignment: Alignment.center,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final p = _pulseController.value;
                              return Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // Radar Pulse Ring
                                  Container(
                                    width: 36 + (p * 46),
                                    height: 36 + (p * 46),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (isHeadingToStore
                                              ? RC.bg(Color(0xFFF59E0B))
                                              : RC.bg(Color(0xFF10B981)))
                                          .withValues(alpha: (1 - p) * 0.45),
                                    ),
                                  ),
                                  // Floating Stage Tooltip above motorcycle
                                  Positioned(
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: RC.bg(Color(0xFF0F172A)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isHeadingToStore
                                              ? RC.bg(Color(0xFFFAC800))
                                              : RC.bg(Color(0xFF00E676)),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(color: RC.bg(Colors.black45), blurRadius: 6, offset: Offset(0, 2)),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isHeadingToStore
                                                ? Icons.shopping_bag_rounded
                                                : Icons.two_wheeler_rounded,
                                            size: 11,
                                            color: isHeadingToStore
                                                ? RC.fg(Color(0xFFFAC800))
                                                : RC.bg(Color(0xFF00E676)),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            tx(isHeadingToStore
                                                ? "بەرەو فرۆشگا بۆ وەرگرتن 🛍️"
                                                : (_status == 'arrived_customer'
                                                    ? "گەیشتە بەردەم ماڵت 🔔"
                                                    : "بە خواردنەکەوە بەرەو تۆ دێت 🚀")),
                                            style: TextStyle(
                                              color: RC.fg(Colors.white),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Rotating Biker Icon
                                  Transform.rotate(
                                    angle: _headingDeg * math.pi / 180.0,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isHeadingToStore
                                            ? RC.bg(Color(0xFFFAC800))
                                            : RC.bg(Color(0xFF00E676)),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: RC.bg(Color(0xFF0F172A)),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: RC.bg(Colors.black38),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.two_wheeler_rounded,
                                        color: RC.fg(Color(0xFF0F172A)),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  // Speed Tag
                                  Positioned(
                                    bottom: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: RC.bg(Color(0xFF0F172A)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tx('${_speedKmh.toStringAsFixed(0)} کم/ک'),
                                        style: TextStyle(
                                          color: isHeadingToStore
                                              ? RC.bg(Color(0xFFFAC800))
                                              : RC.bg(Color(0xFF00E676)),
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
            ),

            // 2. Top-start exit + map controls (visible on first paint; RTL-aware)
            Positioned.directional(
              textDirection: Directionality.of(context),
              top: 0,
              start: 0,
              child: SafeArea(
                bottom: false,
                minimum: kIsWeb ? const EdgeInsets.only(top: 8) : EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LiveTrackerExitButton(onPressed: _exitLiveTracker),
                      const SizedBox(height: 8),
                      _TrackerMapBtn(
                      icon: _followDriver
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      active: _followDriver,
                      onTap: () {
                        setState(() => _followDriver = true);
                        if (_mapReady) {
                          _mapController.move(_displayDriverPos, 16.0);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _TrackerMapBtn(
                      icon: Icons.route_rounded,
                      active: false,
                      onTap: () => _fitAllMarkers(keepFollowing: false),
                    ),
                    const SizedBox(height: 8),
                    _TrackerMapBtn(
                      icon: Icons.storefront_rounded,
                      active: false,
                      onTap: _focusOnPickupRoute,
                    ),
                    const SizedBox(height: 8),
                    _TrackerMapBtn(
                      icon: Icons.location_on_rounded,
                      active: false,
                      onTap: _focusOnDeliveryRoute,
                    ),
                    const SizedBox(height: 8),
                    _TrackerMapBtn(
                      icon: _mapStyleIndex == 1
                          ? Icons.dark_mode_rounded
                          : Icons.layers_rounded,
                      active: _mapStyleIndex > 0,
                      onTap: () => setState(() => _mapStyleIndex = (_mapStyleIndex + 1) % 3),
                    ),
                    const SizedBox(height: 8),
                    _TrackerMapBtn(
                      icon: _autoDriveSimulation
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      active: _autoDriveSimulation,
                      onTap: () => setState(
                        () => _autoDriveSimulation = !_autoDriveSimulation,
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Bottom Live Order & Captain & 4-Digit Security PIN Sheet
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.white),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: RC.bg(Colors.black26),
                            blurRadius: 28,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      child: _status == 'delivered'
                          ? _buildDeliveredCelebrationCard()
                          : _buildActiveLiveBottomPanel(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLiveBottomPanel() {
    const stepLabels = ['وەرگیرا', 'ئامادەیە', 'هەڵگیرا', 'لە ڕێگایە', 'ڕادەست کرا'];
    final activeIdx = _activeStepIndex;
    final isArrivedAtDoor = _status == 'arrived_customer';
    final screenH = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenH < 620 ? screenH * 0.44 : 360),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 5-Stage Live Stepper
        Row(
          children: List.generate(stepLabels.length, (i) {
            final done = i <= activeIdx;
            final isLast = i == stepLabels.length - 1;
            return Expanded(
              flex: isLast ? 0 : 1,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: i == activeIdx ? 20 : 14,
                    height: i == activeIdx ? 20 : 14,
                    decoration: BoxDecoration(
                      color: done ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                      boxShadow: i == activeIdx
                          ? [
                              BoxShadow(
                                color: RC.bg(Color(0xFF16A34A)).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: done
                        ? Icon(Icons.check, size: 11, color: RC.fg(Colors.white))
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i < activeIdx
                            ? RC.bg(Color(0xFF16A34A))
                            : RC.bg(Color(0xFFE2E8F0)),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(stepLabels.length, (i) {
            final active = i == activeIdx;
            return Text(
              tx(stepLabels[i]),
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: i <= activeIdx ? RC.bg(Color(0xFF0F172A)) : RC.bg(Color(0xFF94A3B8)),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isArrivedAtDoor ? RC.bg(Color(0xFFECFDF5)) : RC.bg(Color(0xFFFFFBEB)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isArrivedAtDoor ? RC.bg(Color(0xFF10B981)) : RC.bg(Color(0xFFFCD34D)),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx(isArrivedAtDoor
                    ? '🔔 شۆفێر لە بەردەم دەرگایە!'
                    : 'داواکارییەکەت'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: isArrivedAtDoor
                      ? RC.bg(Color(0xFF065F46))
                      : RC.bg(Color(0xFF92400E)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tx('${_formatMoney(widget.totalAmount)} د.ع'),
                style: TextStyle(fontSize: 10.5, color: RC.fg(Color(0xFF64748B))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Driver Info + Action Row
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFFEF3C7)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.two_wheeler_rounded,
                color: RC.fg(Color(0xFFB45309)),
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx(_driverName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: RC.fg(Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    tx(_driverPhone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: RC.fg(Color(0xFF64748B)),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isArrivedAtDoor)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFF16A34A)),
                  foregroundColor: RC.fg(Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _confirmOrderReceivedByCustomer,
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: Text(
                  tx('وەرمگرت ✅'),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ],
    ),
  ),
);
  }

  Widget _buildDeliveredCelebrationCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: RC.bg(Color(0xFFDCFCE7)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: RC.fg(Color(0xFF16A34A)),
            size: 40,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tx('داواکارییەکەت بە سەلامەتی گەیشت! 🎉'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: RC.fg(Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tx('سوپاس بۆ بەکارهێنانی ڕێگا (REGA) • کۆی گشتی: ${_formatMoney(widget.totalAmount)} د.ع'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF64748B))),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFFAC800)),
              foregroundColor: RC.fg(Colors.black),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _exitLiveTracker,
            child: Text(
              tx('گەڕانەوە بۆ داواکارییەکان'),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerMapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool isHighlighted;

  const _CustomerMapPin({
    required this.icon,
    required this.color,
    required this.label,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted ? color : color.withValues(alpha: 0.6),
              width: isHighlighted ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted ? color.withValues(alpha: 0.35) : RC.bg(Colors.black26),
                blurRadius: isHighlighted ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tx(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: RC.fg(Color(0xFF0F172A)),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  tx(subtitle!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: isHighlighted ? color : RC.fg(Color(0xFF64748B)),
                  ),
                ),
              ],
              if (badge != null) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tx(badge!),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: badgeColor ?? color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: RC.bg(Colors.white), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: RC.fg(Colors.white), size: 18),
        ),
      ],
    );
  }
}

/// Always-visible back/exit — high contrast on satellite & street tiles (incl. web).
class _LiveTrackerExitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LiveTrackerExitButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tx('گەڕانەوە'),
      child: Material(
        color: RC.bg(const Color(0xFF0F172A)),
        elevation: 6,
        shadowColor: RC.bg(Colors.black45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 26,
              color: RC.fg(Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackerMapBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TrackerMapBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
            size: 20,
            color: active ? RC.fg(Color(0xFFFAC800)) : RC.bg(Color(0xFF0F172A)),
          ),
        ),
      ),
    );
  }
}

class _PickerMapPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _PickerMapPill({
    required this.label,
    required this.icon,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RC.bg(Color(0xFF0F172A)) : RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: RC.bg(Colors.black26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? RC.fg(Color(0xFFFAC800)) : RC.bg(Color(0xFF0F172A)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: active ? RC.fg(Color(0xFFFAC800)) : RC.bg(Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Classic map location pin (teardrop) — independent of Material Icons fonts.
class _LocationPinPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final Color hole;

  const _LocationPinPainter({
    required this.fill,
    required this.stroke,
    required this.hole,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final headR = w * 0.42;
    final headCy = headR + 1.5;

    final path = ui.Path()
      ..moveTo(cx, h - 1)
      ..quadraticBezierTo(cx - headR * 0.15, h * 0.62, cx - headR, headCy)
      ..arcToPoint(
        Offset(cx + headR, headCy),
        radius: Radius.circular(headR),
        clockwise: true,
      )
      ..quadraticBezierTo(cx + headR * 0.15, h * 0.62, cx, h - 1)
      ..close();

    canvas.drawShadow(path, const Color(0x99000000), 4, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      Offset(cx, headCy),
      headR * 0.34,
      Paint()
        ..color = hole
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _LocationPinPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.hole != hole;
  }
}
