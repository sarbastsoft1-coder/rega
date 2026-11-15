import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Mapbox raster styles for flutter_map.
///
/// Set token with `--dart-define=MAPBOX_TOKEN=pk....` or edit [accessToken]
/// defaultValue below (needed for `flutter build web` via serve_all.py).
///
/// IMPORTANT: Studio style `mirnatv33/cmwax4kdy002501sc2w31byoj` is a
/// **Mapbox Standard** style (`imports: mapbox://styles/mapbox/standard`,
/// zero classic layers). The classic raster tile API
/// `/styles/v1/{user}/{id}/tiles/...` returns empty transparent PNGs for it,
/// which shows up as a solid grey map in flutter_map. Use stock raster styles
/// below until a classic (non-Standard) Studio style is published.
enum MapboxStyle { streets, dark, outdoors, satellite }

class MapboxTiles {
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  /// Documented Studio style — NOT usable with flutter_map raster tiles.
  static const String customStandardStylePath =
      'mirnatv33/cmwax4kdy002501sc2w31byoj';

  static String url(MapboxStyle style) {
    if (accessToken.isEmpty) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
    final id = switch (style) {
      MapboxStyle.streets => 'streets-v12',
      MapboxStyle.dark => 'dark-v11',
      MapboxStyle.outdoors => 'outdoors-v12',
      MapboxStyle.satellite => 'satellite-streets-v12',
    };
    return 'https://api.mapbox.com/styles/v1/mapbox/$id/tiles/256/{z}/{x}/{y}@2x'
        '?access_token=$accessToken';
  }

  static TileLayer layer({
    required MapboxStyle style,
    required String userAgentPackageName,
    Key? key,
    MapboxStyle fallbackStyle = MapboxStyle.streets,
    TileProvider? tileProvider,
  }) {
    return TileLayer(
      key: key ?? ValueKey(style),
      urlTemplate: url(style),
      fallbackUrl: url(fallbackStyle),
      userAgentPackageName: userAgentPackageName,
      maxZoom: 22,
      // Same provider on web/mobile so every REGA map loads identical Mapbox tiles.
      tileProvider: tileProvider ?? NetworkTileProvider(),
    );
  }
}
