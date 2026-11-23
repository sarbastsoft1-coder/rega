import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'rega_colors.dart';
import 'rega_i18n.dart';
import 'rega_mobile.dart';

/// One GPS circle for a work city (کەلار، هەولێر، …).
class ServiceAreaCircle {
  static const double defaultCenterLat = 34.6295;
  static const double defaultCenterLng = 45.3159;
  static const int defaultRadiusKm = 10;
  static const String defaultAreaName = 'کەلار';

  final int? id;
  final String code;
  final double centerLat;
  final double centerLng;
  final int radiusKm;
  final String areaName;
  final String? nameEn;
  final String? nameAr;

  const ServiceAreaCircle({
    this.id,
    this.code = 'kalar',
    this.centerLat = defaultCenterLat,
    this.centerLng = defaultCenterLng,
    this.radiusKm = defaultRadiusKm,
    this.areaName = defaultAreaName,
    this.nameEn,
    this.nameAr,
  });

  factory ServiceAreaCircle.fromCityMap(Map<String, dynamic> map) {
    final kmRaw = map['radius_km'] ?? map['service_radius_km'];
    var km = kmRaw is num
        ? kmRaw.toInt()
        : int.tryParse(kmRaw?.toString() ?? '') ?? defaultRadiusKm;
    if (![5, 10, 15, 20].contains(km)) km = defaultRadiusKm;

    final latRaw = map['center_lat'] ?? map['service_center_lat'];
    final lngRaw = map['center_lng'] ?? map['service_center_lng'];
    final lat = latRaw is num
        ? latRaw.toDouble()
        : double.tryParse(latRaw?.toString() ?? '') ?? defaultCenterLat;
    final lng = lngRaw is num
        ? lngRaw.toDouble()
        : double.tryParse(lngRaw?.toString() ?? '') ?? defaultCenterLng;
    final name = (map['name_ku'] ?? map['service_area_name'] ?? map['name'])
        ?.toString()
        .trim();
    return ServiceAreaCircle(
      id: (map['id'] as num?)?.toInt(),
      code: map['code']?.toString() ?? 'city',
      centerLat: lat,
      centerLng: lng,
      radiusKm: km,
      areaName: (name == null || name.isEmpty) ? defaultAreaName : name,
      nameEn: map['name_en']?.toString(),
      nameAr: map['name_ar']?.toString(),
    );
  }

  double distanceMeters(double lat, double lng) =>
      Geolocator.distanceBetween(centerLat, centerLng, lat, lng);

  bool contains(double lat, double lng) =>
      distanceMeters(lat, lng) <= radiusKm * 1000.0;
}

/// Multi-circle service area: inside if GPS is in **any** active city.
class ServiceAreaConfig {
  final List<ServiceAreaCircle> cities;

  const ServiceAreaConfig({
    this.cities = const [
      ServiceAreaCircle(),
    ],
  });

  factory ServiceAreaConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ServiceAreaConfig();

    final rawCities = map['service_cities'];
    if (rawCities is List && rawCities.isNotEmpty) {
      final parsed = <ServiceAreaCircle>[];
      for (final item in rawCities) {
        if (item is Map<String, dynamic>) {
          parsed.add(ServiceAreaCircle.fromCityMap(item));
        } else if (item is Map) {
          parsed.add(ServiceAreaCircle.fromCityMap(Map<String, dynamic>.from(item)));
        }
      }
      if (parsed.isNotEmpty) return ServiceAreaConfig(cities: parsed);
    }

    // Legacy single-circle keys from platform_settings / support contacts.
    return ServiceAreaConfig(
      cities: [ServiceAreaCircle.fromCityMap(map)],
    );
  }

  ServiceAreaCircle get primary =>
      cities.isNotEmpty ? cities.first : const ServiceAreaCircle();

  double get centerLat => primary.centerLat;
  double get centerLng => primary.centerLng;
  int get radiusKm => primary.radiusKm;
  String get areaName =>
      cities.map((c) => c.areaName).where((n) => n.isNotEmpty).join(' · ');

  bool contains(double lat, double lng) =>
      cities.any((c) => c.contains(lat, lng));

  ServiceAreaCircle? cityContaining(double lat, double lng) {
    for (final c in cities) {
      if (c.contains(lat, lng)) return c;
    }
    return null;
  }

  ServiceAreaCircle? byId(int? id) {
    if (id == null) return null;
    for (final c in cities) {
      if (c.id == id) return c;
    }
    return null;
  }
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

  /// Merge top-level bootstrap `service_cities` with optional settings map.
  static void applyFromBootstrap(Map<String, dynamic>? boot) {
    if (boot == null) return;
    final merged = <String, dynamic>{};
    final settings = boot['settings'];
    if (settings is Map<String, dynamic>) {
      merged.addAll(settings);
    } else if (settings is Map) {
      merged.addAll(Map<String, dynamic>.from(settings));
    }
    if (boot['service_cities'] != null) {
      merged['service_cities'] = boot['service_cities'];
    }
    // Also accept service_cities already on the support-contacts payload.
    applyFromMap(merged.isEmpty ? boot : merged);
  }

  /// Check current GPS against [config] (any city circle).
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
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                maximumAge: Duration.zero,
                timeLimit: const Duration(seconds: 15),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                timeLimit: Duration(seconds: 15),
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

/// Full-screen block when the device is outside all configured service cities.
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
