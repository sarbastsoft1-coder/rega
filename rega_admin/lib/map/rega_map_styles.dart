import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'mapbox_tiles.dart';

/// Mapbox Standard + companion styles for REGA fullscreen maps.
enum RegaMapStyleId { map, satellite, outdoors, dark }

class RegaMapStyles {
  static const RegaMapStyleId defaultPicker = RegaMapStyleId.satellite;
  static const RegaMapStyleId defaultTracking = RegaMapStyleId.map;

  static String uri(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => MapboxTiles.customStandardStyleUri,
      RegaMapStyleId.satellite => MapboxStyles.STANDARD_SATELLITE,
      RegaMapStyleId.outdoors => MapboxStyles.OUTDOORS,
      RegaMapStyleId.dark => MapboxStyles.DARK,
    };
  }

  static String fallbackUri(RegaMapStyleId id) {
    return switch (id) {
      RegaMapStyleId.map => MapboxStyles.STANDARD,
      RegaMapStyleId.satellite => MapboxStyles.STANDARD_SATELLITE,
      RegaMapStyleId.outdoors => MapboxStyles.OUTDOORS,
      RegaMapStyleId.dark => MapboxStyles.DARK,
    };
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

/// Lets the parent sheet call locate / style without a GlobalKey.
class KalarPickerController {
  Future<void> Function({bool silent})? locateMe;
  Future<void> Function(RegaMapStyleId id)? setStyle;
}
