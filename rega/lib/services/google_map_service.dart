import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapConfig {
  /// Default center coordinates for Kalar (کەلار), Garmian, Kurdistan Region, Iraq
  static const double kalarCenterLat = 34.6313;
  static const double kalarCenterLng = 45.3177;
  static const double defaultZoom = 16.0;

  static const CameraPosition kalarInitialCamera = CameraPosition(
    target: LatLng(kalarCenterLat, kalarCenterLng),
    zoom: defaultZoom,
    tilt: 0,
    bearing: 0,
  );

  /// Standard bounds for Kalar metropolitan area
  static final LatLngBounds kalarBounds = LatLngBounds(
    southwest: const LatLng(34.5800, 45.2600),
    northeast: const LatLng(34.6900, 45.3800),
  );
}

class GoogleMapService {
  GoogleMapController? _controller;

  GoogleMapController? get controller => _controller;

  void setController(GoogleMapController controller) {
    _controller = controller;
  }

  /// Smoothly animate camera to any coordinates in Kalar
  Future<void> animateToLocation(LatLng target, {double zoom = 16.5, double bearing = 0.0}) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      await ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom,
            bearing: bearing,
            tilt: 15.0,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GoogleMapService] animateToLocation failed: $e');
      }
    }
  }

  /// Reset camera orientation to North (compass click)
  Future<void> resetBearingToNorth() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      final currentZoom = await ctrl.getZoomLevel();
      final visibleRegion = await ctrl.getVisibleRegion();
      final centerLat = (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2;
      final centerLng = (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2;
      await ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: currentZoom,
            bearing: 0.0,
            tilt: 0.0,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GoogleMapService] resetBearingToNorth failed: $e');
      }
    }
  }

  /// Zoom in smoothly
  Future<void> zoomIn() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await ctrl.animateCamera(CameraUpdate.zoomIn());
  }

  /// Zoom out smoothly
  Future<void> zoomOut() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await ctrl.animateCamera(CameraUpdate.zoomOut());
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
