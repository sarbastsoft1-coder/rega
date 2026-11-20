import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Mapbox raster styles for flutter_map (Static Tiles API).
///
/// Pass token at build time:
/// `--dart-define=MAPBOX_TOKEN=pk....`
///
/// Without a token, falls back to OSM (streets) / Esri (satellite) so maps still load.
/// Carto was removed — their free basemaps now require an API key watermark.
enum MapboxStyle { streets, dark, outdoors, satellite }

class MapboxTiles {
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  /// Documented Studio Standard style — not usable with flutter_map rasters.
  static const String customStandardStylePath =
      'mirnatv33/cmwax4kdy002501sc2w31byoj';

  static bool get hasToken => accessToken.isNotEmpty;

  /// Free OSM raster tiles (no API key). Keep a proper User-Agent via TileLayer.
  static const String _osmStreets =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  /// Unchanged satellite fallback — do not edit.
  static const String _esriSatellite =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static String _stylePath(MapboxStyle style) {
    return switch (style) {
      MapboxStyle.streets => 'mapbox/streets-v12',
      MapboxStyle.dark => 'mapbox/outdoors-v12',
      MapboxStyle.outdoors => 'mapbox/outdoors-v12',
      MapboxStyle.satellite => 'mapbox/satellite-streets-v12',
    };
  }

  static String url(MapboxStyle style) {
    if (!hasToken) {
      return switch (style) {
        // Satellite stays on Esri — never touch this path.
        MapboxStyle.satellite => _esriSatellite,
        MapboxStyle.dark => _osmStreets,
        MapboxStyle.outdoors => _osmStreets,
        MapboxStyle.streets => _osmStreets,
      };
    }
    final path = _stylePath(style);
    return 'https://api.mapbox.com/styles/v1/$path/tiles/512/{z}/{x}/{y}@2x'
        '?access_token=$accessToken';
  }

  static TileLayer layer({
    required MapboxStyle style,
    required String userAgentPackageName,
    Key? key,
    MapboxStyle fallbackStyle = MapboxStyle.outdoors,
    TileProvider? tileProvider,
  }) {
    final useMapboxSizing = hasToken;
    return TileLayer(
      key: key ?? ValueKey('${style}_$hasToken'),
      urlTemplate: url(style),
      fallbackUrl: url(fallbackStyle),
      userAgentPackageName: userAgentPackageName,
      tileDimension: useMapboxSizing ? 512 : 256,
      zoomOffset: useMapboxSizing ? -1 : 0,
      maxZoom: 22,
      maxNativeZoom: 22,
      tileProvider: tileProvider ?? NetworkTileProvider(),
    );
  }
}
