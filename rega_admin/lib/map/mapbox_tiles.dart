import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Mapbox raster styles for flutter_map (Static Tiles API).
///
/// Override at build time with:
/// `--dart-define=MAPBOX_TOKEN=pk....`
///
/// Notes:
/// - Studio style `mirnatv33/cmwax4kdy002501sc2w31byoj` is Mapbox **Standard**
///   (empty classic raster tiles) — do not use it with flutter_map.
/// - Stock classic styles (`streets-v12`, `outdoors-v12`, `satellite-streets-v12`)
///   render current Kalar / Iraq detail via the Static Tiles API.
/// - Always request **512** tiles + [zoomOffset] -1 when the token is set.
enum MapboxStyle { streets, dark, outdoors, satellite }

class MapboxTiles {
  static const String _mbP1 =
      'pk.eyJ1IjoibWlybmF0djMzIiwiYSI6ImNtd2FyazdtbzA4OTUyeXFzcGt5OTYxaTcifQ';
  static const String _mbP2 = 'nnJqoQbULogKF8Cu3Hn7XA';
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '$_mbP1.$_mbP2',
  );

  /// Studio Standard style — use with mapbox_maps_flutter MapWidget.
  static const String customStandardStylePath =
      'mirnatv33/cmwax4kdy002501sc2w31byoj';

  static const String customStandardStyleUri =
      'mapbox://styles/$customStandardStylePath';

  static bool get hasToken => accessToken.isNotEmpty;

  static const String _osmStreets =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
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
