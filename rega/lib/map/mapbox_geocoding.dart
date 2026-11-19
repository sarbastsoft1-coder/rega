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

  static Future<String?> _reverseMapbox(
    LatLng point, {
    required Duration timeout,
    required String language,
  }) async {
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      '${point.longitude},${point.latitude}.json'
      '?types=address,poi,neighborhood,locality,place'
      '&limit=1'
      '&language=$language'
      '&access_token=${MapboxTiles.accessToken}',
    );

    try {
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final features = body['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;
      final first = features.first as Map<String, dynamic>;
      final text = first['text']?.toString().trim();
      final placeName = first['place_name']?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
      if (placeName != null && placeName.isNotEmpty) {
        final parts = placeName.split(',');
        return parts.first.trim();
      }
      return null;
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
