import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Fresh GPS settings — best accuracy; on web `maximumAge: 0` blocks stale fixes.
LocationSettings regaFreshLocationSettings({
  LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
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

/// Pick the tighter fix (smaller accuracy radius = better).
Position regaBetterFix(Position a, Position b) {
  final aa = a.accuracy;
  final ba = b.accuracy;
  if (!aa.isFinite) return b;
  if (!ba.isFinite) return a;
  return aa <= ba ? a : b;
}

/// True when the fix is too coarse (typical IP / city-level geolocation).
bool regaIsCoarseFix(Position pos, {double maxMeters = 120}) {
  final a = pos.accuracy;
  if (!a.isFinite) return true;
  return a > maxMeters;
}

/// Ensure location service + permission. Returns false when unavailable.
Future<bool> regaEnsureLocationPermission({bool requestIfNeeded = true}) async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) return false;

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied && requestIfNeeded) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    return false;
  }
  return true;
}

/// Best live device position (2026).
///
/// [precise] — longer refine, never fall back to stale last-known (avoids
/// city-center / Citadel false pins from IP geolocation).
Future<Position?> regaResolveCurrentPosition({
  Duration timeLimit = const Duration(seconds: 18),
  Duration refineFor = const Duration(seconds: 4),
  bool requestPermission = true,
  bool precise = false,
  bool allowLastKnown = false,
}) async {
  if (!await regaEnsureLocationPermission(requestIfNeeded: requestPermission)) {
    return null;
  }

  final effectiveRefine = precise
      ? (refineFor < const Duration(seconds: 8)
          ? const Duration(seconds: 8)
          : refineFor)
      : refineFor;
  final effectiveLimit = precise && timeLimit < const Duration(seconds: 22)
      ? const Duration(seconds: 22)
      : timeLimit;

  Position? best;

  try {
    best = await Geolocator.getCurrentPosition(
      locationSettings: regaFreshLocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: effectiveLimit,
      ),
    );
  } catch (_) {
    try {
      best = await Geolocator.getCurrentPosition(
        locationSettings: regaFreshLocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 12),
        ),
      );
    } catch (_) {}
  }

  if (effectiveRefine > Duration.zero) {
    try {
      final settings = regaFreshLocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        timeLimit: effectiveRefine,
      );
      await for (final sample in Geolocator.getPositionStream(
        locationSettings: settings,
      ).timeout(
        effectiveRefine,
        onTimeout: (sink) => sink.close(),
      )) {
        best = best == null ? sample : regaBetterFix(best, sample);
        // Delivery-grade precision.
        if (best.accuracy.isFinite && best.accuracy <= 20) break;
      }
    } catch (_) {}
  }

  if (best != null) {
    var resolved = best;
    // Precise mode: tighten city-level / IP fixes so we don't land on Citadel.
    if (precise && regaIsCoarseFix(resolved, maxMeters: 250)) {
      try {
        final retry = await Geolocator.getCurrentPosition(
          locationSettings: regaFreshLocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 12),
          ),
        );
        resolved = regaBetterFix(resolved, retry);
      } catch (_) {}
    }
    return resolved;
  }

  if (!allowLastKnown || precise) return null;

  try {
    return await Geolocator.getLastKnownPosition();
  } catch (_) {
    return null;
  }
}

/// Zoom level that matches fix precision for map cameras.
double regaZoomForAccuracy(double accuracyMeters) {
  if (!accuracyMeters.isFinite) return 16.5;
  if (accuracyMeters <= 20) return 18.2;
  if (accuracyMeters <= 50) return 17.2;
  if (accuracyMeters <= 120) return 16.2;
  return 14.5;
}
