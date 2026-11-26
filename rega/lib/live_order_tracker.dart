import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'map/mapbox_directions.dart';
import 'map/mapbox_tiles.dart';
import 'map/rega_map_styles.dart';
import 'services/rega_gps.dart';
import 'rega_mobile.dart';

import 'rega_i18n.dart';
import 'rega_colors.dart';

export 'services/rega_gps.dart'
    show
        regaFreshLocationSettings,
        regaResolveCurrentPosition,
        regaZoomForAccuracy,
        regaEnsureLocationPermission,
        regaBetterFix,
        regaIsCoarseFix;

/// Neighborhood centers — filled from backend zones; no frozen labels as UI source of truth.
class KalarGeoCatalog {
  /// Real downtown Kalar (ناو بازاڕی کەلار) — default map center when user has not pinned yet.
  static const LatLng kalarCenter = LatLng(34.6295, 45.3159);

  /// Runtime coords synced from admin/backend neighborhoods (id → LatLng).
  static final Map<String, LatLng> neighborhoodCoords = {};

  /// Max distance (meters) to associate a backend delivery fee zone around Kalar/Rizgari.
  static const double maxZoneMatchMeters = 4500;

  /// Strict distance (meters) to use a backend zone's name as the pin neighborhood label.
  static const double strictNeighborhoodLabelMeters = 900;

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
  /// True while reverse-geocode is in flight — shows a small spinner in the bubble.
  final bool pinLoading;
  final ValueChanged<LatLng> onLocationChanged;
  final bool allowIraqWide;
  /// When true (e.g. first open with no saved pin), jump to live GPS immediately.
  final bool autoLocateOnStart;
  /// When true, require a precise fix (no stale last-known / city-level IP pin).
  final bool forcePreciseGps;
  /// Parent sheet can call [locateMe] / [setStyle].
  final KalarPickerController? controller;
  /// Default Mapbox Standard (live 2026 cartography).
  final RegaMapStyleId initialStyle;
  /// When false, parent owns back/title chrome (map only shows layers + GPS FABs).
  final bool showTopChrome;
  /// Optional close (X) FAB — bottom-left, matching pick-location screenshot.
  final VoidCallback? onClose;
  /// Extra bottom inset so zoom/close FABs sit above the parent confirm button.
  final double bottomControlsInset;

  const KalarInteractivePickerMap({
    super.key,
    required this.initialPoint,
    required this.pinLabel,
    this.pinLoading = false,
    required this.onLocationChanged,
    this.allowIraqWide = true,
    this.autoLocateOnStart = false,
    this.forcePreciseGps = false,
    this.controller,
    this.initialStyle = RegaMapStyles.defaultPicker,
    this.showTopChrome = false,
    this.onClose,
    this.bottomControlsInset = 78,
  });

  @override
  State<KalarInteractivePickerMap> createState() => _KalarInteractivePickerMapState();
}

class _KalarInteractivePickerMapState extends State<KalarInteractivePickerMap> {
  /// flutter_map raster tiles — reliable on Flutter web (MapWidget/GL often grey).
  final MapController _mapCtrl = MapController();
  late LatLng _pinned;
  late RegaMapStyleId _styleId;
  bool _ready = false;
  bool _locating = false;
  bool _didAutoLocate = false;
  bool _applyingCamera = false;
  bool _panPickMode = true;
  /// Once the user pans, late GPS must not overwrite their chosen pin.
  bool _userMovedPin = false;
  int _gpsGeneration = 0;
  DateTime? _lastPanEmit;

  MapboxStyle get _rasterStyle => _styleId == RegaMapStyleId.satellite
      ? MapboxStyle.satellite
      : MapboxStyle.streets;

  double get _initialZoom => widget.allowIraqWide ? 16.2 : 15.4;

  @override
  void initState() {
    super.initState();
    _pinned = widget.initialPoint;
    _styleId = widget.initialStyle == RegaMapStyleId.satellite
        ? RegaMapStyleId.satellite
        : RegaMapStyleId.map;
    widget.controller?.locateMe = ({bool silent = false}) => _goToCurrentGps(silent: silent);
    widget.controller?.setStyle = _applyStyle;
    if (widget.autoLocateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoLocate) return;
        _didAutoLocate = true;
        // Never silent when hunting a real pin — user must know if GPS failed
        // (otherwise the map stays on city center / Citadel).
        _goToCurrentGps(silent: false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant KalarInteractivePickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.locateMe = null;
      oldWidget.controller?.setStyle = null;
      widget.controller?.locateMe = ({bool silent = false}) => _goToCurrentGps(silent: silent);
      widget.controller?.setStyle = _applyStyle;
    }
    if (oldWidget.initialPoint != widget.initialPoint) {
      final sameAsPinned =
          (widget.initialPoint.latitude - _pinned.latitude).abs() < 1e-7 &&
          (widget.initialPoint.longitude - _pinned.longitude).abs() < 1e-7;
      if (!sameAsPinned) {
        _pinned = widget.initialPoint;
        if (_ready) _moveCamera(_pinned);
      }
    }
    if (oldWidget.pinLabel != widget.pinLabel ||
        oldWidget.pinLoading != widget.pinLoading) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller?.locateMe = null;
    widget.controller?.setStyle = null;
    _mapCtrl.dispose();
    super.dispose();
  }

  void _moveCamera(LatLng pt, {double? zoom}) {
    _applyingCamera = true;
    try {
      final z = (zoom ?? (_ready ? _mapCtrl.camera.zoom : _initialZoom)).clamp(5.0, 20.0);
      _mapCtrl.move(pt, z);
    } catch (_) {
    } finally {
      // Hold long enough that MapEventMove/End from this move are ignored
      // (50ms was too short — GPS jump was treated as user pan and cancelled).
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        _applyingCamera = false;
      });
    }
  }

  void _setPin(LatLng pt, {double? zoom, bool moveCamera = true}) {
    setState(() => _pinned = pt);
    widget.onLocationChanged(pt);
    if (moveCamera) {
      if (_ready) {
        _moveCamera(pt, zoom: zoom);
      } else {
        // Map not ready yet — apply as soon as onMapReady fires.
        _pendingGpsTarget = pt;
        _pendingGpsZoom = zoom;
      }
    }
  }

  LatLng? _pendingGpsTarget;
  double? _pendingGpsZoom;

  void _emitCenterPin(LatLng center, {required bool fromGesture}) {
    if (widget.allowIraqWide &&
        !KalarGeoCatalog.isInsideIraq(center.latitude, center.longitude)) {
      return;
    }
    if (center.latitude == _pinned.latitude &&
        center.longitude == _pinned.longitude) {
      return;
    }
    if (fromGesture) {
      if (_applyingCamera || _locating) return;
      final now = DateTime.now();
      if (_lastPanEmit != null &&
          now.difference(_lastPanEmit!) < const Duration(milliseconds: 120)) {
        return;
      }
      _lastPanEmit = now;
      _userMovedPin = true;
      // Cancel any in-flight auto-GPS apply.
      _gpsGeneration++;
    }
    _setPin(center, moveCamera: false);
  }

  void _onMapEvent(MapEvent event) {
    if (!_ready) {
      _ready = true;
    }
    if (!_panPickMode || _applyingCamera || _locating) return;
    if (event is MapEventMove || event is MapEventMoveEnd) {
      _emitCenterPin(event.camera.center, fromGesture: true);
    }
  }

  Future<void> _applyStyle(RegaMapStyleId id) async {
    final next = id == RegaMapStyleId.satellite
        ? RegaMapStyleId.satellite
        : RegaMapStyleId.map;
    if (_styleId == next) return;
    setState(() => _styleId = next);
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
    final gen = ++_gpsGeneration;
    // Explicit «شوێنەکەم» / auto-GPS resets the user-moved guard.
    _userMovedPin = false;
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
          _toast(
            kIsWeb
                ? 'ڕێگە بدە بە Location (Precise) لە وێبگەڕەکەت'
                : 'ڕێگەپێدانی لۆکەیشن پێویستە بۆ دیاریکردنی شوێنەکەت',
          );
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

      // Fast first fix so the map jumps immediately (long precise refine was
      // leaving the button stuck on loading for 20s+).
      var pos = await regaResolveCurrentPosition(
        precise: false,
        allowLastKnown: true,
        refineFor: const Duration(seconds: 2),
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted || gen != _gpsGeneration) return;
      if (pos == null) {
        if (!silent) {
          _toast(
            kIsWeb
                ? 'GPS نەدۆزرایەوە. Precise Location چالاک بکە و دووبارە «شوێنەکەم» لێدە'
                : 'نەتوانرا شوێنەکەت بدۆزرێتەوە. دووبارە هەوڵبدەرەوە',
          );
        }
        return;
      }
      var pt = LatLng(pos.latitude, pos.longitude);
      if (widget.allowIraqWide &&
          !KalarGeoCatalog.isInsideIraq(pt.latitude, pt.longitude)) {
        if (!silent) {
          _toast('شوێنی GPS دەرەوەی عێراقە. تکایە شوێنێک لە ناو عێراق هەڵبژێرە');
        }
        return;
      }
      if (!mounted || gen != _gpsGeneration || _userMovedPin) return;

      // Wait briefly if tiles/controller not ready yet.
      for (var i = 0; i < 30 && mounted && !_ready; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted || gen != _gpsGeneration || _userMovedPin) return;

      _applyingCamera = true;
      _setPin(pt, zoom: regaZoomForAccuracy(pos.accuracy));
      if (_ready) {
        _moveCamera(pt, zoom: regaZoomForAccuracy(pos.accuracy));
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (gen == _gpsGeneration) _applyingCamera = false;

      if (!silent) {
        final acc = pos.accuracy;
        final meters = acc.isFinite ? acc.round() : null;
        final coarse = regaIsCoarseFix(pos, maxMeters: 120);
        if (coarse) {
          _toast(
            meters == null
                ? '⚠️ شوێن نزیکە بەڵام ورد نییە — Precise Location هەڵبکە یان نەخشە بجوڵێنە'
                : '⚠️ شوێن ورد نییە (±$meters م). Precise Location هەڵبکە یان پینەکە بجوڵێنە',
            bg: RC.bg(const Color(0xFFD97706)),
          );
        } else {
          _toast(
            meters == null
                ? '🎯 باشترین شوێنی GPS دیاریکرا'
                : '🎯 باشترین شوێنی GPS (±$meters م)',
            bg: RC.bg(const Color(0xFF059669)),
          );
        }
      }

      // Background refine — update pin if a tighter fix arrives.
      final first = pos;
      () async {
        final better = await regaResolveCurrentPosition(
          precise: true,
          allowLastKnown: false,
          refineFor: const Duration(seconds: 5),
          timeLimit: const Duration(seconds: 12),
        );
        if (!mounted || gen != _gpsGeneration || _userMovedPin || better == null) {
          return;
        }
        if (!regaIsCoarseFix(better, maxMeters: 120) &&
            (!first.accuracy.isFinite ||
                (better.accuracy.isFinite && better.accuracy < first.accuracy - 5))) {
          final next = LatLng(better.latitude, better.longitude);
          if (widget.allowIraqWide &&
              !KalarGeoCatalog.isInsideIraq(next.latitude, next.longitude)) {
            return;
          }
          _applyingCamera = true;
          _setPin(next, zoom: regaZoomForAccuracy(better.accuracy));
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (gen == _gpsGeneration) _applyingCamera = false;
        }
      }();
    } catch (_) {
      if (!silent) {
        _toast('هەڵەی GPS. تکایە دووبارە هەوڵبدەرەوە');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _zoomBy(double delta) {
    try {
      final cam = _mapCtrl.camera;
      final next = (cam.zoom + delta).clamp(5.0, 20.0);
      _applyingCamera = true;
      _mapCtrl.move(cam.center, next);
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        _applyingCamera = false;
      });
    } catch (_) {}
  }

  /// Center map marker — Flaticon GPS icon (assets/icons/gps_location.png).
  Widget _buildRegaPin({double size = 56}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/icons/gps_location.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.gps_fixed_rounded,
          size: size * 0.85,
          color: RC.fg(const Color(0xFFE11D48)),
        ),
      ),
    );
  }

  /// Center overlay — GPS icon sits on the map center point.
  Widget _buildCenterPinWithAccuracy() {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: _buildRegaPin(size: 56),
    );
  }

  Widget _zoomFab(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: const Color(0xFF0F172A), size: 24),
        ),
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
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
              Icon(
                icon,
                size: 17,
                color: const Color(0xFF0F172A),
              ),
              const SizedBox(width: 6),
              Text(
                tx(label),
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

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFAC800);
    const panGreen = Color(0xFF22C55E);
    final isSat = _styleId == RegaMapStyleId.satellite;
    final bottomPad = widget.bottomControlsInset + MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _pinned,
            initialZoom: _initialZoom,
            minZoom: 5,
            maxZoom: 20,
            backgroundColor: const Color(0xFFE8EEF4),
            onMapReady: () {
              _ready = true;
              // Prefer pending GPS target over city-center initial pin.
              final pending = _pendingGpsTarget;
              if (pending != null) {
                _pendingGpsTarget = null;
                final z = _pendingGpsZoom;
                _pendingGpsZoom = null;
                _moveCamera(pending, zoom: z ?? regaZoomForAccuracy(50));
                return;
              }
              // Don't yank back to city center while GPS is still resolving.
              if (_locating) return;
              _moveCamera(_pinned, zoom: _initialZoom);
            },
            onMapEvent: _onMapEvent,
          ),
          children: [
            MapboxTiles.layer(
              style: _rasterStyle,
              userAgentPackageName: 'tech.rega.customer',
              fallbackStyle: MapboxStyle.outdoors,
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('Mapbox'),
                TextSourceAttribution('OpenStreetMap'),
              ],
            ),
          ],
        ),
        // Center pin + accuracy circle (screenshot style).
        IgnorePointer(
          child: Align(
            alignment: const Alignment(0, -0.02),
            child: _buildCenterPinWithAccuracy(),
          ),
        ),
        // Top chips: سەتەلایت | جووڵاندن | شوێنەکەم
        Positioned(
          top: 12 + MediaQuery.of(context).padding.top * 0.15,
          left: 10,
          right: 10,
          child: SafeArea(
            bottom: false,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _modeChip(
                    label: 'سەتەلایت',
                    icon: Icons.satellite_alt_rounded,
                    active: isSat,
                    activeColor: gold,
                    onTap: () => _applyStyle(
                      isSat ? RegaMapStyleId.map : RegaMapStyleId.satellite,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _modeChip(
                    label: 'جووڵاندن',
                    icon: Icons.open_with_rounded,
                    active: _panPickMode,
                    activeColor: panGreen,
                    onTap: () => setState(() => _panPickMode = !_panPickMode),
                  ),
                  const Spacer(),
                  _modeChip(
                    label: 'شوێنەکەم',
                    icon: Icons.my_location_rounded,
                    active: true,
                    activeColor: gold,
                    onTap: _locating ? () {} : () => _goToCurrentGps(),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Close (X) — bottom left
        if (widget.onClose != null)
          Positioned(
            left: 14,
            bottom: bottomPad,
            child: _zoomFab(Icons.close_rounded, widget.onClose!),
          ),
        // Zoom + / − — bottom right
        Positioned(
          right: 14,
          bottom: bottomPad,
          child: Column(
            children: [
              _zoomFab(Icons.add_rounded, () => _zoomBy(1)),
              const SizedBox(height: 10),
              _zoomFab(Icons.remove_rounded, () => _zoomBy(-1)),
            ],
          ),
        ),
        if (_locating)
          const Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFFAC800),
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
  /// Vendor cover/logo shown as the store pin on the live map.
  final String? storeCoverUrl;
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
    this.storeCoverUrl,
    String? apiBaseUrl,
    this.onOrderStatusChanged,
  }) : apiBaseUrl = apiBaseUrl ?? RegaApiHost.apiV1;

  @override
  State<CustomerLiveOrderTrackerScreen> createState() =>
      _CustomerLiveOrderTrackerScreenState();
}

class _CustomerLiveOrderTrackerScreenState extends State<CustomerLiveOrderTrackerScreen>
    with TickerProviderStateMixin {
  /// Same flutter_map + Mapbox rasters stack as the pick-location map.
  final MapController _mapCtrl = MapController();

  late AnimationController _pulseController;
  late AnimationController _glideController;

  Timer? _oneSecondTimer;

  RegaMapStyleId _mapStyleId = RegaMapStyleId.map;
  bool _followDriver = true;
  bool _mapReady = false;
  bool _applyingCamera = false;
  /// Local fake movement — OFF by default; only via play button.
  bool _autoDriveSimulation = false;

  late String _status; // 'pending' | 'preparing' | 'picked_up' | 'on_the_way' | 'arrived_customer' | 'delivered'
  late String _driverName;
  late String _driverPhone;
  String _vehicleLabel = 'ماتۆڕسوار • KLR-402';

  late LatLng _storePos;
  late LatLng _customerPos;
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

  MapboxStyle get _rasterStyle => switch (_mapStyleId) {
        RegaMapStyleId.satellite => MapboxStyle.satellite,
        RegaMapStyleId.outdoors => MapboxStyle.outdoors,
        RegaMapStyleId.dark => MapboxStyle.dark,
        RegaMapStyleId.map => MapboxStyle.streets,
      };

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _driverName = widget.driverName;
    _driverPhone = widget.driverPhone;
    _storePos = widget.storeLocation;
    _customerPos = widget.customerLocation;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..addListener(_onGlideTick);

    _dispatchOrigin = LatLng(
      _storePos.latitude - 0.0036,
      _storePos.longitude - 0.0042,
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
    _mapCtrl.dispose();
    super.dispose();
  }

  void _buildInitialRoute() {
    // Temporary straight fallback until Mapbox Directions returns road geometry.
    final leg1 = [_dispatchOrigin, _storePos];
    final leg2 = [_storePos, _customerPos];
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
        store: _storePos,
        customer: _customerPos,
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
                  'store_lat': _storePos.latitude,
                  'store_lng': _storePos.longitude,
                  'customer_address': widget.customerAddress,
                  'customer_lat': _customerPos.latitude,
                  'customer_lng': _customerPos.longitude,
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
      final store = (data['store'] as Map<String, dynamic>?) ?? const {};
      final customer = (data['customer'] as Map<String, dynamic>?) ?? const {};
      // Mirror real-time 1-second coordinates from Captain App or Backend Telemetry Engine!
      final dLat = (driver['lat'] as num?)?.toDouble() ?? _displayDriverPos.latitude;
      final dLng = (driver['lng'] as num?)?.toDouble() ?? _displayDriverPos.longitude;
      final remoteStatus = (data['status'] ?? _status).toString();

      final sLat = (store['lat'] as num?)?.toDouble();
      final sLng = (store['lng'] as num?)?.toDouble();
      if (sLat != null && sLng != null) {
        _storePos = LatLng(sLat, sLng);
      }
      final cLat = (customer['lat'] as num?)?.toDouble();
      final cLng = (customer['lng'] as num?)?.toDouble();
      if (cLat != null && cLng != null) {
        _customerPos = LatLng(cLat, cLng);
      }

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
    _glideDriverTo(_customerPos);
    _updateStatus('delivered');
  }

  void _moveCamera(LatLng center, {double? zoom}) {
    if (!_mapReady) return;
    _applyingCamera = true;
    try {
      final z = (zoom ?? _mapCtrl.camera.zoom).clamp(5.0, 20.0);
      _mapCtrl.move(center, z);
    } catch (_) {
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        _applyingCamera = false;
      });
    }
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
      _moveCamera(next);
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
    if (_followDriver && _mapReady && !_applyingCamera) {
      _moveCamera(cur);
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

  void _onMapReady() {
    _mapReady = true;
    _followDriver = true;
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted && _mapReady) {
        _safeFitBounds([
          _displayDriverPos,
          _storePos,
          _customerPos,
        ]);
      }
    });
  }

  List<Polyline> _buildRoutePolylines() {
    final storeRatio = _fullRoute.length > 2
        ? (_storeSplitIndex / (_fullRoute.length - 1))
        : 0.35;
    final isHeadingToStore = _localProgress < storeRatio;
    final isDelivered = _status == 'delivered';
    final lines = <Polyline>[];

    void addLine(List<LatLng> pts, Color color, double width) {
      if (pts.length < 2) return;
      lines.add(
        Polyline(
          points: pts,
          color: color,
          strokeWidth: width,
          borderColor: Colors.white.withValues(alpha: 0.55),
          borderStrokeWidth: 1.5,
        ),
      );
    }

    if (isHeadingToStore) {
      final leg1Progress = (_localProgress / storeRatio).clamp(0.0, 1.0);
      addLine(
        _traveledSubPolyline(_leg1ToStore, leg1Progress, _displayDriverPos),
        const Color(0xFF94A3B8),
        4,
      );
      addLine(
        _remainingSubPolyline(_leg1ToStore, leg1Progress, _displayDriverPos),
        const Color(0xFFF59E0B),
        7,
      );
      addLine(_leg2ToCustomer, const Color(0xFF10B981), 4);
    } else {
      addLine(_leg1ToStore, const Color(0xFF94A3B8), 3.5);
      final leg2Progress =
          ((_localProgress - storeRatio) / (1.0 - storeRatio)).clamp(0.0, 1.0);
      addLine(
        _traveledSubPolyline(_leg2ToCustomer, leg2Progress, _displayDriverPos),
        const Color(0xFF86EFAC),
        4,
      );
      if (!isDelivered) {
        addLine(
          _remainingSubPolyline(_leg2ToCustomer, leg2Progress, _displayDriverPos),
          const Color(0xFF16A34A),
          7.5,
        );
      } else {
        addLine(_leg2ToCustomer, const Color(0xFF16A34A), 6);
      }
    }
    return lines;
  }

  void _safeFitBounds(List<LatLng> points, {double maxZoom = 16.2, double minZoom = 13.0}) {
    if (!_mapReady || points.isEmpty) return;
    final valid = points.where((p) => !p.latitude.isNaN && !p.longitude.isNaN).toList();
    if (valid.isEmpty) return;
    if (valid.length == 1) {
      _moveCamera(valid.first, zoom: 15.6);
      return;
    }
    try {
      _applyingCamera = true;
      _mapCtrl.fitCamera(
        CameraFit.coordinates(
          coordinates: valid,
          padding: const EdgeInsets.fromLTRB(52, 110, 52, 270),
          maxZoom: maxZoom,
          minZoom: minZoom,
        ),
      );
    } catch (_) {
      double minLat = valid.first.latitude, maxLat = valid.first.latitude;
      double minLng = valid.first.longitude, maxLng = valid.first.longitude;
      for (final p in valid) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
      final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      final span = math.max((maxLat - minLat).abs(), (maxLng - minLng).abs());
      final zoom = span < 0.002
          ? maxZoom
          : span < 0.01
              ? 15.4
              : span < 0.03
                  ? 14.2
                  : minZoom + 0.8;
      _moveCamera(center, zoom: zoom.clamp(minZoom, maxZoom));
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        _applyingCamera = false;
      });
    }
  }

  void _focusOnPickupRoute() {
    if (!_mapReady) return;
    _followDriver = false;
    _safeFitBounds([
      _displayDriverPos,
      _dispatchOrigin,
      _storePos,
    ]);
    setState(() {});
  }

  void _focusOnDeliveryRoute() {
    if (!_mapReady) return;
    _followDriver = false;
    _safeFitBounds([
      _storePos,
      _customerPos,
      if (_localProgress >= 0.35) _displayDriverPos,
    ]);
    setState(() {});
  }

  LatLng _pointAlong(List<LatLng> pts, double progress) {
    if (pts.isEmpty) return _storePos;
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
      _storePos,
      _customerPos,
    ]);
    setState(() {});
  }

  Widget _vendorLogoMarker() {
    final url = (widget.storeCoverUrl ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFFAC800), width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF0F172A),
                    size: 26,
                  ),
                )
              : const Icon(Icons.storefront_rounded, color: Color(0xFF0F172A), size: 26),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Text(
            tx('فرۆشگا'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _customerPinMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tx('کڕیار'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _driverLiveMarker() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 0.65 + (_pulseController.value * 0.35);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _headingDeg * math.pi / 180.0,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAC800),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
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
              ],
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tx('گەیاندن'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
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
        // Waiting for vendor accept — no step active yet.
        return -1;
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
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeLines = _buildRoutePolylines();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: RC.bg(Color(0xFFF1F5F9)),
        body: Stack(
          children: [
            // Same flutter_map + Mapbox rasters as pick-location, with live pins.
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: _displayDriverPos,
                  initialZoom: 15.4,
                  minZoom: 5,
                  maxZoom: 20,
                  backgroundColor: const Color(0xFFE8EEF4),
                  onMapReady: _onMapReady,
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && _followDriver) {
                      setState(() => _followDriver = false);
                    }
                  },
                ),
                children: [
                  MapboxTiles.layer(
                    style: _rasterStyle,
                    userAgentPackageName: 'tech.rega.customer',
                    fallbackStyle: MapboxStyle.outdoors,
                  ),
                  PolylineLayer(polylines: routeLines),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _storePos,
                        width: 72,
                        height: 84,
                        alignment: Alignment.bottomCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _vendorLogoMarker(),
                        ),
                      ),
                      Marker(
                        point: _customerPos,
                        width: 64,
                        height: 76,
                        alignment: Alignment.bottomCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _customerPinMarker(),
                        ),
                      ),
                      if (_status != 'delivered')
                        Marker(
                          point: _displayDriverPos,
                          width: 72,
                          height: 86,
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _driverLiveMarker(),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('Mapbox'),
                      TextSourceAttribution('OpenStreetMap'),
                    ],
                  ),
                ],
              ),
            ),

            // Top-start exit + map controls (visible on first paint; RTL-aware)
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
                          _moveCamera(_displayDriverPos, zoom: 16.0);
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
                      icon: _mapStyleId == RegaMapStyleId.satellite
                          ? Icons.satellite_alt_rounded
                          : Icons.layers_rounded,
                      active: _mapStyleId != RegaMapStyleId.map,
                      onTap: () {
                        final next = switch (_mapStyleId) {
                          RegaMapStyleId.map => RegaMapStyleId.satellite,
                          RegaMapStyleId.satellite => RegaMapStyleId.outdoors,
                          RegaMapStyleId.outdoors => RegaMapStyleId.dark,
                          RegaMapStyleId.dark => RegaMapStyleId.map,
                        };
                        setState(() => _mapStyleId = next);
                      },
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
    const stepLabels = ['قبوڵکرا', 'ئامادەیە', 'هەڵگیرا', 'لە ڕێگایە', 'ڕادەست کرا'];
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
            return Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    tx(stepLabels[i]),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                      color: i <= activeIdx ? RC.bg(Color(0xFF0F172A)) : RC.bg(Color(0xFF94A3B8)),
                    ),
                  ),
                ),
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

/// Mapbox-style Map | Satellite segmented control.
class _MapStyleSegment extends StatelessWidget {
  final bool satellite;
  final VoidCallback onMap;
  final VoidCallback onSatellite;

  const _MapStyleSegment({
    required this.satellite,
    required this.onMap,
    required this.onSatellite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segChip(
            label: tx('نەخشە'),
            icon: Icons.map_rounded,
            selected: !satellite,
            onTap: onMap,
          ),
          _segChip(
            label: tx('سەتەلایت'),
            icon: Icons.satellite_alt_rounded,
            selected: satellite,
            onTap: onSatellite,
          ),
        ],
      ),
    );
  }

  Widget _segChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFAC800) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.black : const Color(0xFF475569)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.black : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapGlassChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color foregroundOnActive;
  final VoidCallback onTap;

  const _MapGlassChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    this.foregroundOnActive = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? activeColor : Colors.white.withValues(alpha: 0.94);
    final fg = active ? foregroundOnActive : const Color(0xFF0F172A);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapRoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapRoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}

