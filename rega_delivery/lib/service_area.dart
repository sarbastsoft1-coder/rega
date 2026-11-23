import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'rega_colors.dart';
import 'rega_i18n.dart';
import 'rega_mobile.dart';

/// Kalar service-area gate: device GPS must fall within center + radius (km).
class ServiceAreaConfig {
  static const double defaultCenterLat = 34.6295;
  static const double defaultCenterLng = 45.3159;
  static const int defaultRadiusKm = 10;
  static const String defaultAreaName = 'کەلار';

  final double centerLat;
  final double centerLng;
  final int radiusKm;
  final String areaName;

  const ServiceAreaConfig({
    this.centerLat = defaultCenterLat,
    this.centerLng = defaultCenterLng,
    this.radiusKm = defaultRadiusKm,
    this.areaName = defaultAreaName,
  });

  factory ServiceAreaConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ServiceAreaConfig();
    final kmRaw = map['service_radius_km'];
    var km = kmRaw is num
        ? kmRaw.toInt()
        : int.tryParse(kmRaw?.toString() ?? '') ?? defaultRadiusKm;
    if (![5, 10, 15, 20].contains(km)) km = defaultRadiusKm;

    final latRaw = map['service_center_lat'];
    final lngRaw = map['service_center_lng'];
    final lat = latRaw is num
        ? latRaw.toDouble()
        : double.tryParse(latRaw?.toString() ?? '') ?? defaultCenterLat;
    final lng = lngRaw is num
        ? lngRaw.toDouble()
        : double.tryParse(lngRaw?.toString() ?? '') ?? defaultCenterLng;
    final name = map['service_area_name']?.toString().trim();
    return ServiceAreaConfig(
      centerLat: lat,
      centerLng: lng,
      radiusKm: km,
      areaName: (name == null || name.isEmpty) ? defaultAreaName : name,
    );
  }

  double distanceMeters(double lat, double lng) =>
      Geolocator.distanceBetween(centerLat, centerLng, lat, lng);

  bool contains(double lat, double lng) =>
      distanceMeters(lat, lng) <= radiusKm * 1000.0;
}

enum ServiceAreaCheckStatus {
  inside,
  outside,
  locationUnavailable,
  permissionDenied,
  skipped,
}

class ServiceAreaCheckResult {
  final ServiceAreaCheckStatus status;
  final Position? position;

  const ServiceAreaCheckResult(this.status, {this.position});

  bool get isOutside => status == ServiceAreaCheckStatus.outside;
  bool get blocksApp => status == ServiceAreaCheckStatus.outside;
}

class ServiceAreaGate {
  ServiceAreaGate._();

  static ServiceAreaConfig config = const ServiceAreaConfig();

  static void applyFromMap(Map<String, dynamic>? map) {
    config = ServiceAreaConfig.fromMap(map);
  }

  static Future<ServiceAreaCheckResult> check({
    bool requestPermission = false,
  }) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (kIsWeb) {
          return const ServiceAreaCheckResult(ServiceAreaCheckStatus.skipped);
        }
        return const ServiceAreaCheckResult(
          ServiceAreaCheckStatus.locationUnavailable,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kIsWeb) {
          return const ServiceAreaCheckResult(ServiceAreaCheckStatus.skipped);
        }
        return const ServiceAreaCheckResult(
          ServiceAreaCheckStatus.permissionDenied,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (config.contains(pos.latitude, pos.longitude)) {
        return ServiceAreaCheckResult(
          ServiceAreaCheckStatus.inside,
          position: pos,
        );
      }
      return ServiceAreaCheckResult(
        ServiceAreaCheckStatus.outside,
        position: pos,
      );
    } catch (_) {
      if (kIsWeb) {
        return const ServiceAreaCheckResult(ServiceAreaCheckStatus.skipped);
      }
      return const ServiceAreaCheckResult(
        ServiceAreaCheckStatus.locationUnavailable,
      );
    }
  }
}

class ServiceAreaBlockedScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final String? areaName;
  final int? radiusKm;

  const ServiceAreaBlockedScreen({
    super.key,
    required this.onRetry,
    this.areaName,
    this.radiusKm,
  });

  @override
  Widget build(BuildContext context) {
    final name = areaName ?? ServiceAreaGate.config.areaName;
    final km = radiusKm ?? ServiceAreaGate.config.radiusKm;
    return Scaffold(
      backgroundColor: RC.bg(Colors.white),
      body: RegaResponsive.constrain(
        alignment: Alignment.center,
        maxWidth: 520,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_disabled_rounded,
                size: 80,
                color: RC.fg(const Color(0xFFDC2626)),
              ),
              const SizedBox(height: 24),
              Text(
                tx('تۆ لەدەرەوەی ناوچەی کارکردنیت'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                tx(
                  'ئەپی REGA تەنها لە ناوچەی کارکردن کار دەکات. تکایە کاتێک لە ناو ناوچەکەیت دووبارە هەوڵبدەرەوە.',
                ),
                style: TextStyle(fontSize: 14, color: RC.fg(Colors.grey)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${tx('ناوچەی کارکردن')}: $name · $km ${tx('کم')}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: RC.fg(const Color(0xFF334155)),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(const Color(0xFFFAC800)),
                    foregroundColor: RC.fg(Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tx('دووبارە هەوڵبدەرەوە'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
