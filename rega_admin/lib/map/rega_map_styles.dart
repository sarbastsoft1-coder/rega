import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'mapbox_tiles.dart';

/// Mapbox Standard family for every REGA fullscreen map.
enum RegaMapStyleId { map, satellite, outdoors, dark }

class RegaMapStyles {
  static const RegaMapStyleId defaultPicker = RegaMapStyleId.map;
  static const RegaMapStyleId defaultTracking = RegaMapStyleId.map;

  static String uri(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => MapboxTiles.customStandardStyleUri,
      RegaMapStyleId.satellite => MapboxStyles.STANDARD_SATELLITE,
      RegaMapStyleId.outdoors => MapboxStyles.STANDARD,
      RegaMapStyleId.dark => MapboxStyles.STANDARD,
    };
  }

  static String fallbackUri(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => MapboxStyles.STANDARD,
      RegaMapStyleId.satellite => MapboxStyles.STANDARD_SATELLITE,
      RegaMapStyleId.outdoors => MapboxStyles.STANDARD,
      RegaMapStyleId.dark => MapboxStyles.STANDARD,
    };
  }

  static Future<void> applyConfig(MapboxMap map, RegaMapStyleId id) async {
    if (id == RegaMapStyleId.satellite) return;
    final preset = switch (id) {
      RegaMapStyleId.dark => 'night',
      RegaMapStyleId.outdoors => 'day',
      RegaMapStyleId.map => 'day',
      RegaMapStyleId.satellite => 'day',
    };
    try {
      await map.style.setStyleImportConfigProperty('basemap', 'lightPreset', preset);
    } catch (_) {}
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
