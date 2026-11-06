import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Real Kalar neighborhood center coordinates
class KalarGeoCatalog {
  static const Map<String, LatLng> neighborhoodCoords = {
    'n1': LatLng(34.6695, 45.2950), // شارۆچکەی رزگاری
    'n2': LatLng(34.7010, 45.3315), // گەڕەکی زانکۆ
    'n3': LatLng(34.6912, 45.3264), // گەڕەکی شەهیدان
    'n4': LatLng(34.6785, 45.3320), // گەڕەکی سیروان
    'n5': LatLng(34.6895, 45.3140), // گەڕەکی شۆڕش
    'n6': LatLng(34.6960, 45.3195), // گەڕەکی بێساری
    'n7': LatLng(34.6815, 45.3095), // گەڕەکی کاکەییان
    'n8': LatLng(34.6872, 45.3238), // گەڕەکی فەرمانبەران
    'n9': LatLng(34.6836, 45.3189), // ناو بازاڕی کەلار
  };

  static LatLng forNeighborhoodId(String id) {
    return neighborhoodCoords[id] ?? const LatLng(34.6912, 45.3264);
  }
}

/// Interactive real Kalar street map for picking exact customer delivery pin
class KalarInteractivePickerMap extends StatefulWidget {
  final LatLng initialPoint;
  final String selectedNeighborhoodName;
  final ValueChanged<LatLng> onLocationChanged;

  const KalarInteractivePickerMap({
    super.key,
    required this.initialPoint,
    required this.selectedNeighborhoodName,
    required this.onLocationChanged,
  });

  @override
  State<KalarInteractivePickerMap> createState() => _KalarInteractivePickerMapState();
}

class _KalarInteractivePickerMapState extends State<KalarInteractivePickerMap> {
  final MapController _controller = MapController();
  late LatLng _pinned;
  bool _darkStyle = false;
  bool _ready = false;

  static const _landmarks = <(String, LatLng)>[
    ('🏰 قەڵای شێروانە', LatLng(34.6698, 45.3222)),
    ('🎓 زانکۆی گەرمیان', LatLng(34.7032, 45.3338)),
    ('🏪 ناو بازاڕی کەلار', LatLng(34.6836, 45.3189)),
    ('🌊 ڕووباری سیروان', LatLng(34.6725, 45.3355)),
  ];

  @override
  void initState() {
    super.initState();
    _pinned = widget.initialPoint;
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _pinned,
            initialZoom: 15.4,
            minZoom: 12.0,
            maxZoom: 18.5,
            onMapReady: () => _ready = true,
            onTap: (_, latLng) {
              setState(() => _pinned = latLng);
              widget.onLocationChanged(latLng);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _darkStyle
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'iq.rega.customer',
            ),
            MarkerLayer(
              markers: [
                ..._landmarks.map(
                  (lm) => Marker(
                    point: lm.$2,
                    width: 118,
                    height: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFAC800), width: 0.8),
                      ),
                      child: Center(
                        child: Text(
                          lm.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Marker(
                  point: _pinned,
                  width: 145,
                  height: 78,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFAC800), width: 1.4),
                        ),
                        child: Text(
                          '📍 ${widget.selectedNeighborhoodName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFAC800),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(Icons.location_on_rounded, size: 42, color: Color(0xFFEF4444)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _darkStyle = !_darkStyle),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  _darkStyle ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'GPS: ${_pinned.latitude.toStringAsFixed(4)}, ${_pinned.longitude.toStringAsFixed(4)}',
              style: const TextStyle(
                color: Color(0xFFFAC800),
                fontSize: 10,
                fontWeight: FontWeight.w800,
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

  const CustomerLiveOrderTrackerScreen({
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
    this.apiBaseUrl = 'http://127.0.0.1:8001/api/v1',
    this.onOrderStatusChanged,
  });

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

  int _mapStyleIndex = 0; // 0: Voyager, 1: Dark, 2: OSM
  bool _followDriver = true;
  bool _mapReady = false;
  bool _serverLiveConnected = false;
  bool _liveCaptainConnected = false;

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
    final leg1 = _generateKalarStreetPath(_dispatchOrigin, widget.storeLocation, steps: 20);
    final leg2 = _generateKalarStreetPath(widget.storeLocation, widget.customerLocation, steps: 44);
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

    _fetchRealOsrmRoute();
  }

  List<LatLng> _generateKalarStreetPath(LatLng a, LatLng b, {int steps = 28}) {
    final dLat = b.latitude - a.latitude;
    final dLng = b.longitude - a.longitude;
    final w1 = LatLng(a.latitude + dLat * 0.30 + 0.00042, a.longitude + dLng * 0.20 - 0.00028);
    final w2 = LatLng(a.latitude + dLat * 0.62 - 0.00024, a.longitude + dLng * 0.56 + 0.00038);
    final w3 = LatLng(a.latitude + dLat * 0.85 + 0.00020, a.longitude + dLng * 0.84 - 0.00016);
    final anchors = [a, w1, w2, w3, b];

    final out = <LatLng>[];
    final perSeg = math.max(4, steps ~/ (anchors.length - 1));
    for (var i = 0; i < anchors.length - 1; i++) {
      final p0 = anchors[i];
      final p1 = anchors[i + 1];
      for (var k = 0; k < perSeg; k++) {
        final t = k / perSeg;
        out.add(LatLng(
          p0.latitude + (p1.latitude - p0.latitude) * t,
          p0.longitude + (p1.longitude - p0.longitude) * t,
        ));
      }
    }
    out.add(b);
    return out;
  }

  Future<void> _fetchRealOsrmRoute() async {
    try {
      final url1 = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_dispatchOrigin.longitude},${_dispatchOrigin.latitude};'
        '${widget.storeLocation.longitude},${widget.storeLocation.latitude}'
        '?overview=full&geometries=geojson',
      );
      final url2 = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${widget.storeLocation.longitude},${widget.storeLocation.latitude};'
        '${widget.customerLocation.longitude},${widget.customerLocation.latitude}'
        '?overview=full&geometries=geojson',
      );

      final res = await Future.wait([
        http.get(url1).timeout(const Duration(seconds: 4)),
        http.get(url2).timeout(const Duration(seconds: 4)),
      ]);

      if (!mounted) return;
      final leg1 = _parseOsrm(res[0], minPoints: 24);
      final leg2 = _parseOsrm(res[1], minPoints: 52);
      if (leg1.length >= 4 && leg2.length >= 4) {
        setState(() {
          _leg1ToStore = leg1;
          _leg2ToCustomer = leg2;
          _storeSplitIndex = leg1.length - 1;
          _fullRoute = [...leg1, ...leg2.skip(1)];
        });
      }
    } catch (_) {}
  }

  List<LatLng> _parseOsrm(http.Response res, {int minPoints = 32}) {
    if (res.statusCode != 200) return [];
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return [];
    final geom = (routes.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) return [];
    final raw = coords.map((e) {
      final pair = e as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
    if (raw.length >= minPoints) return raw;
    final dense = <LatLng>[];
    final mult = (minPoints / raw.length).ceil().clamp(2, 8);
    for (var i = 0; i < raw.length - 1; i++) {
      for (var k = 0; k < mult; k++) {
        final t = k / mult;
        dense.add(LatLng(
          raw[i].latitude + (raw[i + 1].latitude - raw[i].latitude) * t,
          raw[i].longitude + (raw[i + 1].longitude - raw[i].longitude) * t,
        ));
      }
    }
    dense.add(raw.last);
    return dense;
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
      if (!synced) {
        // Seamless local 1-second street progression so user ALWAYS sees sec-by-sec movement!
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
            Uri.parse('${widget.apiBaseUrl}/live-telemetry/$cleanRef?auto_progress=1'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 850));

      if (!mounted || res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return false;

      final driver = (data['driver'] as Map<String, dynamic>?) ?? const {};
      final isLiveCaptain = driver['is_live_captain'] == true;

      _serverLiveConnected = true;
      _liveCaptainConnected = isLiveCaptain;

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
      _serverLiveConnected = false;
      _liveCaptainConnected = false;
      return false;
    }
  }

  void _stepLocalOneSecond() {
    if (_status == 'delivered') return;

    final storeRatio = _fullRoute.length > 2
        ? (_storeSplitIndex / (_fullRoute.length - 1))
        : 0.32;

    if (_status == 'arrived_customer') {
      // Wait briefly at the customer's door so customer sees the PIN prompt, or auto-complete after 12s
      _speedKmh = 0;
      _etaSeconds = 0;
      _remainingMeters = 0;
      setState(() {});
      return;
    }

    // Advance along real Kalar street polyline every 1.0 second (~65s full visual trip)
    _localProgress = (_localProgress + 0.0155).clamp(0.0, 1.0);
    final nextPos = _pointAlong(_fullRoute, _localProgress);

    if (_localProgress < storeRatio - 0.02) {
      if (_status != 'heading_to_store') _updateStatus('heading_to_store');
      _speedKmh = 29.0 + ((_secondsSinceOpen % 4) * 1.5);
    } else if (_localProgress < storeRatio + 0.03) {
      if (_status != 'picked_up') _updateStatus('picked_up');
      _speedKmh = 14.0;
    } else if (_localProgress < 0.995) {
      if (_status != 'on_the_way') _updateStatus('on_the_way');
      _speedKmh = 33.0 + ((_secondsSinceOpen % 5) * 1.2);
    } else {
      _localProgress = 1.0;
      _speedKmh = 0.0;
      _updateStatus('arrived_customer');
    }

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
            body: jsonEncode({'pin': widget.deliveryPin}),
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

  String _formatCountdown(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatMeters(int m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} کم';
    return '$m مەتر';
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

  String get _statusHeadline {
    switch (_status) {
      case 'pending':
        return 'داواکارییەکەت نێردرا بۆ فرۆشگا...';
      case 'heading_to_store':
      case 'driver_assigned':
      case 'arriving_pickup':
        return 'شۆفێر بەڕێکەوت بەرەو فرۆشگا بۆ وەرگرتن 🛵';
      case 'preparing':
        return 'ئامادە دەکرێت و شۆفێر بەرەو فرۆشگایە 🛵';
      case 'picked_up':
      case 'at_store':
      case 'arrived_pickup':
        return 'شۆفێر داواکارییەکەتی لە فرۆشگا وەرگرت! 🛍️';
      case 'on_the_way':
        return 'شۆفێر لە ڕێگایە بۆ لات (چرکە بە چرکە) 🚀';
      case 'arrived_customer':
        return 'شۆفێر گەیشتە بەردەم ماڵەکەت! 🔔';
      case 'delivered':
      case 'completed':
        return 'داواکارییەکەت گەیشت! نۆشی گیانت بێت 🎉';
      default:
        return 'شۆفێر لە ڕێگایە بۆ لات 🛵';
    }
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
            color: const Color(0xFF94A3B8).withValues(alpha: 0.60),
          ),
        );
      }
      // Glowing Amber Active Pickup Line
      if (remain1.length >= 2) {
        polylines.add(
          Polyline(
            points: remain1,
            strokeWidth: 8,
            color: const Color(0xFFF59E0B),
            borderStrokeWidth: 2.5,
            borderColor: const Color(0xFF78350F),
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
            color: const Color(0xFF10B981).withValues(alpha: 0.75),
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
            color: const Color(0xFF94A3B8).withValues(alpha: 0.45),
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
            color: const Color(0xFF86EFAC).withValues(alpha: 0.55),
          ),
        );
      }
      if (remain2.length >= 2 && !isDelivered) {
        polylines.add(
          Polyline(
            points: remain2,
            strokeWidth: 8.5,
            color: const Color(0xFF16A34A),
            borderStrokeWidth: 2.5,
            borderColor: const Color(0xFF064E3B),
          ),
        );
      }
      if (isDelivered && _leg2ToCustomer.length >= 2) {
        polylines.add(
          Polyline(
            points: _leg2ToCustomer,
            strokeWidth: 7,
            color: const Color(0xFF16A34A),
          ),
        );
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
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
                  backgroundColor: const Color(0xFFF1F5F9),
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
                  TileLayer(
                    urlTemplate: _tileUrl,
                    fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: _mapStyleIndex == 2 ? const [] : const ["a", "b", "c", "d"],
                    userAgentPackageName: "iq.rega.customer",
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
                          color: const Color(0xFFEA580C),
                          label: widget.storeName,
                          subtitle: "١. وەرگرتن لە فرۆشگا",
                          badge: isHeadingToStore ? "شۆفێر بەڕێوەیە 🛵" : "داواکاری وەرگیرا ✅",
                          badgeColor: isHeadingToStore ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          isHighlighted: isHeadingToStore,
                        ),
                      ),

                      // Customer Home Pin (Delivery)
                      Marker(
                        point: widget.customerLocation,
                        width: 140,
                        height: 94,
                        alignment: Alignment.topCenter,
                        child: _CustomerMapPin(
                          icon: Icons.home_rounded,
                          color: const Color(0xFFDC2626),
                          label: "شوێنی تۆ 📍",
                          subtitle: "٢. شوێنی گەیاندن",
                          badge: isDelivered
                              ? "گەیشت 🎉"
                              : (!isHeadingToStore ? "شۆفێر بەرەو تۆ دێت 🚀" : "چاوەڕوانی وەرگرتن"),
                          badgeColor: !isHeadingToStore ? const Color(0xFF16A34A) : const Color(0xFF64748B),
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
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF10B981))
                                          .withValues(alpha: (1 - p) * 0.45),
                                    ),
                                  ),
                                  // Floating Stage Tooltip above motorcycle
                                  Positioned(
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isHeadingToStore
                                              ? const Color(0xFFFAC800)
                                              : const Color(0xFF00E676),
                                          width: 1.2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
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
                                                ? const Color(0xFFFAC800)
                                                : const Color(0xFF00E676),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isHeadingToStore
                                                ? "بەرەو فرۆشگا بۆ وەرگرتن 🛍️"
                                                : (_status == 'arrived_customer'
                                                    ? "گەیشتە بەردەم ماڵت 🔔"
                                                    : "بە خواردنەکەوە بەرەو تۆ دێت 🚀"),
                                            style: const TextStyle(
                                              color: Colors.white,
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
                                            ? const Color(0xFFFAC800)
                                            : const Color(0xFF00E676),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF0F172A),
                                          width: 3,
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
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_speedKmh.toStringAsFixed(0)} کم/ک',
                                        style: TextStyle(
                                          color: isHeadingToStore
                                              ? const Color(0xFFFAC800)
                                              : const Color(0xFF00E676),
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

            // 2. Top Live Second-by-Second Header Bar & Two-Stage Journey Navigator
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFFAC800).withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
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
                                            color: _status == 'delivered'
                                                ? const Color(0xFF22C55E)
                                                : const Color(0xFF00E676),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _liveCaptainConnected
                                                ? "LIVE GPS • ڕاستەوخۆ لە مۆبایلی شۆفێرەوە"
                                                : (_serverLiveConnected
                                                    ? "LIVE 1s • نوێکردنەوەی چرکە بە چرکە"
                                                    : "LIVE 1s • شوێنپێهەڵگرتنی زیندوو"),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF00E676),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _statusHeadline,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Exact MM:SS Second-by-Second Countdown Pill
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _status == 'delivered'
                                        ? const Color(0xFF22C55E)
                                        : (isHeadingToStore ? const Color(0xFFF59E0B) : const Color(0xFFFAC800)),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _status == 'delivered'
                                            ? 'DONE'
                                            : _formatCountdown(_etaSeconds),
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Text(
                                        _status == 'delivered'
                                            ? 'گەیشت'
                                            : (isHeadingToStore
                                                ? '${_formatMeters(_remainingMeters)} بۆ فرۆشگا'
                                                : '${_formatMeters(_remainingMeters)} بۆ ماڵت'),
                                        style: const TextStyle(
                                          color: Color(0xFF1E293B),
                                          fontSize: 8.5,
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
                        const SizedBox(height: 6),
                        // Visual Two-Stage Journey Header (Pickup from store -> Delivery to you)
                        _buildJourneyPhaseBar(isHeadingToStore, isDelivered),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Map Controls (Follow Driver, Fit Full, Focus Pickup, Focus Delivery, Map Style)
            Positioned(
              top: 135,
              left: 14,
              child: SafeArea(
                child: Column(
                  children: [
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
                      icon: Icons.home_rounded,
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
                  ],
                ),
              ),
            ),

            // 4. Bottom Live Order & Captain & 4-Digit Security PIN Sheet
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
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

  Widget _buildJourneyPhaseBar(bool isHeadingToStore, bool isDelivered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Pickup Phase (Driver -> Store)
          Expanded(
            child: InkWell(
              onTap: _focusOnPickupRoute,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isHeadingToStore
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHeadingToStore
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981).withValues(alpha: 0.5),
                    width: isHeadingToStore ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isHeadingToStore ? Icons.two_wheeler_rounded : Icons.check_circle_rounded,
                      size: 16,
                      color: isHeadingToStore ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '١. وەرگرتن',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: isHeadingToStore ? const Color(0xFFFAC800) : Colors.white,
                                ),
                              ),
                              if (isHeadingToStore) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            isHeadingToStore ? 'ڕێگای زەرد بۆ فرۆشگا' : 'لە فرۆشگا وەرگیرا ✓',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: isHeadingToStore
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF86EFAC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Icon(Icons.arrow_back_rounded, color: Colors.white30, size: 16),
          ),
          // 2. Delivery Phase (Store -> Customer)
          Expanded(
            child: InkWell(
              onTap: _focusOnDeliveryRoute,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: !isHeadingToStore && !isDelivered
                      ? const Color(0xFF10B981).withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !isHeadingToStore && !isDelivered
                        ? const Color(0xFF10B981)
                        : Colors.white12,
                    width: !isHeadingToStore && !isDelivered ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDelivered
                          ? Icons.verified_rounded
                          : (!isHeadingToStore ? Icons.local_shipping_rounded : Icons.home_rounded),
                      size: 16,
                      color: !isHeadingToStore ? const Color(0xFF10B981) : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '٢. گەیاندن بۆ تۆ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: !isHeadingToStore ? const Color(0xFF34D399) : Colors.white70,
                                ),
                              ),
                              if (!isHeadingToStore && !isDelivered) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            isDelivered
                                ? 'گەیشت 🎉'
                                : (!isHeadingToStore
                                    ? 'ڕێگای سەوز بۆ ماڵت'
                                    : 'ڕێگای داهاتوو (پچڕپچڕ)'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: !isHeadingToStore
                                  ? const Color(0xFFA7F3D0)
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLiveBottomPanel() {
    const stepLabels = ['وەرگیرا', 'ئامادەیە', 'هەڵگیرا', 'لە ڕێگایە', 'ڕادەست کرا'];
    final activeIdx = _activeStepIndex;
    final isArrivedAtDoor = _status == 'arrived_customer';

    return Column(
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
                      color: done ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                      boxShadow: i == activeIdx
                          ? [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i < activeIdx
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE2E8F0),
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
              stepLabels[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: i <= activeIdx ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),

        // Security Delivery PIN Box (Customer gives to Driver at Door)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isArrivedAtDoor ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isArrivedAtDoor ? const Color(0xFF10B981) : const Color(0xFFFCD34D),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArrivedAtDoor
                          ? '🔔 شۆفێر لە بەردەم دەرگایە! ئەم کۆدەی بدەرێ:'
                          : '🔐 کۆدی وەرگرتنی داواکاری (تەنها بۆ شۆفێر):',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isArrivedAtDoor
                            ? const Color(0xFF065F46)
                            : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'داواکاری ${widget.orderCode} • ${_formatMoney(widget.totalAmount)} د.ع',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.deliveryPin.padRight(4, '0').substring(0, 4).split('').map((d) {
                    return Container(
                      width: 28,
                      height: 34,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            color: Color(0xFFFAC800),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: Color(0xFFB45309),
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _driverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '$_vehicleLabel • $_driverPhone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isArrivedAtDoor)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _confirmOrderReceivedByCustomer,
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text(
                  'وەرمگرت ✅',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_speedKmh.toStringAsFixed(0)} کم/ک',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const Text(
                      'خێرایی شۆفێر',
                      style: TextStyle(fontSize: 9, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliveredCelebrationCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 40,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'داواکارییەکەت بە سەلامەتی گەیشت! 🎉',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'سوپاس بۆ بەکارهێنانی ڕێگا (REGA) • کۆی گشتی: ${_formatMoney(widget.totalAmount)} د.ع',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFAC800),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'گەڕانەوە بۆ داواکارییەکان',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted ? color : color.withValues(alpha: 0.6),
              width: isHighlighted ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted ? color.withValues(alpha: 0.35) : Colors.black26,
                blurRadius: isHighlighted ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: isHighlighted ? color : const Color(0xFF64748B),
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
                    badge!,
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
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ],
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
            size: 20,
            color: active ? const Color(0xFFFAC800) : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
