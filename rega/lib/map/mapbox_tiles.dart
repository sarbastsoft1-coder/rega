import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Mapbox raster styles for flutter_map (Static Tiles API).
///
/// Pass token at build time:
/// `--dart-define=MAPBOX_TOKEN=pk....`
///
/// Without a token, falls back to Carto / Esri so maps still load.
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

  static const String _cartoVoyager =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const String _cartoDark =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
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
        MapboxStyle.satellite => _esriSatellite,
        MapboxStyle.dark => _cartoDark,
        MapboxStyle.outdoors => _cartoVoyager,
        MapboxStyle.streets => _cartoVoyager,
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
