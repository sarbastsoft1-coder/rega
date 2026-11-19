import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'mapbox_tiles.dart';

/// Reverse geocoding (Mapbox when token present, else OSM Nominatim on native).
class MapboxGeocoding {
  /// Short GPS label — always changes when the user moves the map pin.
  static String coordinatesLabel(LatLng point, {int decimals = 4}) {
    return '${point.latitude.toStringAsFixed(decimals)}, '
        '${point.longitude.toStringAsFixed(decimals)}';
  }

  /// Human-readable place name for [point], or null on failure.
  /// Prefers street / POI / neighborhood over the coarse city name so the
  /// pin bubble stays dynamic while the user pans.
  static Future<String?> reversePlaceName(
    LatLng point, {
    Duration timeout = const Duration(seconds: 6),
    String language = 'ku',
  }) async {
    if (MapboxTiles.accessToken.isNotEmpty) {
      final fromMapbox = await _reverseMapbox(point, timeout: timeout, language: language);
      if (fromMapbox != null && fromMapbox.isNotEmpty) return fromMapbox;
    }
    // Nominatim blocks most browser CORS calls — native/mobile only.
    if (!kIsWeb) {
      final fromOsm = await _reverseNominatim(point, timeout: timeout);
      if (fromOsm != null && fromOsm.isNotEmpty) return fromOsm;
    }
    return null;
  }

  static int _typeRank(List<dynamic>? placeType) {
    if (placeType == null || placeType.isEmpty) return 50;
    final t = placeType.map((e) => e.toString()).toSet();
    if (t.contains('address')) return 0;
    if (t.contains('poi')) return 1;
    if (t.contains('neighborhood')) return 2;
    if (t.contains('locality')) return 3;
    if (t.contains('place')) return 4;
    return 40;
  }

  static bool _isNumberOnly(String? text) =>
      text != null && text.isNotEmpty && RegExp(r'^\d+\w*$').hasMatch(text);

  static String? _labelFromFeature(Map<String, dynamic> feature, LatLng point) {
    final text = feature['text']?.toString().trim();
    final placeName = feature['place_name']?.toString().trim();
    final placeType = feature['place_type'] as List<dynamic>?;
    final rank = _typeRank(placeType);

    // Address: prefer "number street" from place_name first segment.
    if (rank == 0) {
      if (placeName != null && placeName.isNotEmpty) {
        final first = placeName.split(',').first.trim();
        if (first.isNotEmpty) return first;
      }
      if (text != null && text.isNotEmpty && !_isNumberOnly(text)) return text;
      // Bare house number alone is not useful — skip to next feature preference.
    }

    // POI / neighborhood / city — place name only (never raw GPS coords).
    if (text != null && text.isNotEmpty && !_isNumberOnly(text)) return text;
    if (placeName != null && placeName.isNotEmpty) {
      return placeName.split(',').first.trim();
    }
    return null;
  }

  /// True when [label] is (or ends with) raw GPS coords like "36.0500, 44.0400".
  static bool looksLikeCoordinates(String? label) {
    if (label == null) return false;
    final t = label.trim();
    if (RegExp(r'^-?\d+\.\d+\s*,\s*-?\d+\.\d+$').hasMatch(t)) return true;
    // Also catch "City · 36.0500, 44.0400"
    if (RegExp(r'·\s*-?\d+\.\d+\s*,\s*-?\d+\.\d+$').hasMatch(t)) return true;
    return false;
  }

  static Future<String?> _reverseMapbox(
    LatLng point, {
    required Duration timeout,
    required String language,
  }) async {
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      '${point.longitude},${point.latitude}.json'
      '?types=address,poi,neighborhood,locality,place'
      '&limit=5'
      '&language=$language'
      '&access_token=${MapboxTiles.accessToken}',
    );

    try {
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final features = body['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      Map<String, dynamic>? best;
      var bestRank = 999;
      for (final raw in features) {
        if (raw is! Map<String, dynamic>) continue;
        final rank = _typeRank(raw['place_type'] as List<dynamic>?);
        if (rank < bestRank) {
          bestRank = rank;
          best = raw;
        }
      }
      best ??= features.first as Map<String, dynamic>;
      return _labelFromFeature(best, point);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _reverseNominatim(LatLng point, {required Duration timeout}) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${point.latitude}&lon=${point.longitude}'
      '&format=json&accept-language=ku,ar,en&zoom=18',
    );
    try {
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'rega-customer/1.0 (delivery map picker)'},
      ).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final name = body['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final display = body['display_name']?.toString().trim();
      if (display != null && display.isNotEmpty) {
        return display.split(',').first.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
