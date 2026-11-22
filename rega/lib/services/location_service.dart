import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationStatus {
  idle,
  checking,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  located,
  error,
}

class LocationResult {
  final LocationStatus status;
  final Position? position;
  final String? errorMessage;

  const LocationResult({
    required this.status,
    this.position,
    this.errorMessage,
  });

  bool get isSuccess => status == LocationStatus.located && position != null;
}

class KalarLocationService {
  /// Acquire current device GPS coordinates with proper permission & service checks.
  /// Never spams permission dialogs.
  static Future<LocationResult> getCurrentLocation({bool requestIfNeeded = true}) async {
    try {
      // 1. Check if GPS service is enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return const LocationResult(
          status: LocationStatus.serviceDisabled,
          errorMessage: 'خزمەتگوزاری شوێن (GPS) ناچالاکە',
        );
      }

      // 2. Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        if (!requestIfNeeded) {
          return const LocationResult(
            status: LocationStatus.permissionDenied,
            errorMessage: 'مۆڵەتی دیاریکردنی شوێن نەدراوە',
          );
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationStatus.permissionDenied,
            errorMessage: 'مۆڵەتی دیاریکردنی شوێن ڕەتکرایەوە',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationStatus.permissionDeniedForever,
          errorMessage: 'مۆڵەتی شوێن بە تەواوی بلۆک کراوە لە ڕێکخستنەکان',
        );
      }

      // 3. Obtain location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      return LocationResult(
        status: LocationStatus.located,
        position: position,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[KalarLocationService] Exception acquiring location: $e');
      }
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Open system app settings when permission is permanently denied
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open system location settings when GPS toggle is off
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
