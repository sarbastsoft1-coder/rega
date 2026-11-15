import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'mapbox_tiles.dart';

/// Reverse / forward geocoding via Mapbox Geocoding API (mirnatv33 token).
class MapboxGeocoding {
  /// Human-readable place name for [point], or null on failure.
  static Future<String?> reversePlaceName(
    LatLng point, {
    Duration timeout = const Duration(seconds: 6),
    String language = 'ku',
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
        // Prefer the first comma segment (local name) over the full address.
        final parts = placeName.split(',');
        return parts.first.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
