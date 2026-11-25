import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Mapbox Standard family for every REGA fullscreen map.
enum RegaMapStyleId { map, satellite, outdoors, dark }

class RegaMapStyles {
  static const RegaMapStyleId defaultPicker = RegaMapStyleId.map;
  static const RegaMapStyleId defaultTracking = RegaMapStyleId.map;

  /// Match customer app: classic streets / satellite-streets (not Studio Standard).
  static String uri(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => MapboxStyles.MAPBOX_STREETS,
      RegaMapStyleId.satellite => MapboxStyles.SATELLITE_STREETS,
      RegaMapStyleId.outdoors => MapboxStyles.OUTDOORS,
      RegaMapStyleId.dark => MapboxStyles.DARK,
    };
  }

  static String fallbackUri(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => MapboxStyles.MAPBOX_STREETS,
      RegaMapStyleId.satellite => MapboxStyles.SATELLITE_STREETS,
      RegaMapStyleId.outdoors => MapboxStyles.OUTDOORS,
      RegaMapStyleId.dark => MapboxStyles.DARK,
    };
  }

  static Future<void> applyConfig(MapboxMap map, RegaMapStyleId id) async {
    // Classic styles — no Standard basemap lightPreset needed.
  }

  static String labelKu(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => 'نەخشە',
      RegaMapStyleId.satellite => 'مانگەدەری',
      RegaMapStyleId.outdoors => 'دەرەوە',
      RegaMapStyleId.dark => 'تاریک',
    };
  }

  static String labelEn(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => 'Map',
      RegaMapStyleId.satellite => 'Satellite',
      RegaMapStyleId.outdoors => 'Outdoors',
      RegaMapStyleId.dark => 'Dark',
    };
  }

  static const List<RegaMapStyleId> all = [
    RegaMapStyleId.map,
    RegaMapStyleId.satellite,
    RegaMapStyleId.outdoors,
    RegaMapStyleId.dark,
  ];
}

class KalarPickerController {
  Future<void> Function({bool silent})? locateMe;
  Future<void> Function(RegaMapStyleId id)? setStyle;
}
