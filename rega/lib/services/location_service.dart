import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'rega_gps.dart';

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
  /// Acquire the best device GPS fix (shared 2026 resolver).
  static Future<LocationResult> getCurrentLocation({bool requestIfNeeded = true}) async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return const LocationResult(
          status: LocationStatus.serviceDisabled,
          errorMessage: 'خزمەتگوزاری شوێن (GPS) ناچالاکە',
        );
      }

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

      final position = await regaResolveCurrentPosition(
        requestPermission: false,
        precise: true,
        allowLastKnown: false,
        refineFor: const Duration(seconds: 8),
      );
      if (position == null) {
        return const LocationResult(
          status: LocationStatus.error,
          errorMessage: 'نەتوانرا شوێن بدۆزرێتەوە',
        );
      }

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

  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
