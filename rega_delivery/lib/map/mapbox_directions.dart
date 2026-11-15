import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'mapbox_tiles.dart';

/// Road-following routes via Mapbox Directions API.
class MapboxDirections {
  static Future<List<LatLng>> drivingRoute(
    LatLng from,
    LatLng to, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?geometries=geojson&overview=full&access_token=${MapboxTiles.accessToken}',
    );

    final res = await http.get(uri).timeout(timeout);
    if (res.statusCode != 200) return const [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != null && body['code'] != 'Ok') return const [];

    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return const [];

    final geom = (routes.first as Map<String, dynamic>)['geometry']
        as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) return const [];

    return coords.map((c) {
      final pair = c as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
  }

  static Future<(List<LatLng>, List<LatLng>)> twoLegRoute({
    required LatLng origin,
    required LatLng store,
    required LatLng customer,
  }) async {
    final legs = await Future.wait([
      drivingRoute(origin, store),
      drivingRoute(store, customer),
    ]);
    return (legs[0], legs[1]);
  }

  static List<LatLng> densify(List<LatLng> pts, {int minPoints = 40}) {
    if (pts.length >= minPoints || pts.length < 2) return pts;
    final out = <LatLng>[];
    final mult = (minPoints / pts.length).ceil().clamp(2, 8);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      for (var k = 0; k < mult; k++) {
        final t = k / mult;
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    out.add(pts.last);
    return out;
  }
}
