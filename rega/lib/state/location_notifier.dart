import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/mapbox_geocoding.dart';
import '../models/customer_models.dart';

/// Delivery pin + display name. Never defaults to a hardcoded neighborhood.
class LocationNotifier extends ChangeNotifier {
  static const _kLat = 'rega_delivery_lat';
  static const _kLng = 'rega_delivery_lng';
  static const _kNote = 'rega_delivery_note';
  static const _kPlaceName = 'rega_delivery_place_name';
  static const _kZoneId = 'rega_delivery_zone_id';
  static const _kZoneName = 'rega_delivery_zone_name';
  static const _kZoneFee = 'rega_delivery_zone_fee';
  static const _kZoneLat = 'rega_delivery_zone_lat';
  static const _kZoneLng = 'rega_delivery_zone_lng';

  Neighborhood? _neighborhood;
  double? _pinnedLat;
  double? _pinnedLng;
  String? _placeNote;
  /// Reverse-geocoded or otherwise resolved place label (not a Flutter const).
  String? _resolvedPlaceName;
  bool _loaded = false;

  Neighborhood? get neighborhood => _neighborhood;
  double? get pinnedLat => _pinnedLat;
  double? get pinnedLng => _pinnedLng;
  String? get placeNote => _placeNote;
  String? get resolvedPlaceName => _resolvedPlaceName;
  bool get hasPin => _pinnedLat != null && _pinnedLng != null;
  bool get hasChosenPlace =>
      hasPin ||
      (_placeNote != null && _placeNote!.isNotEmpty) ||
      (_resolvedPlaceName != null && _resolvedPlaceName!.isNotEmpty);

  /// Home bar / chips: note → resolved geocode/zone name → null (caller shows hint).
  String? get displayPlaceLabel {
    final note = _placeNote?.trim();
    if (note != null && note.isNotEmpty) return note;
    final resolved = _resolvedPlaceName?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final zone = _neighborhood?.name.trim();
    if (zone != null && zone.isNotEmpty) return zone;
    if (hasPin) {
      return MapboxGeocoding.coordinatesLabel(
        LatLng(_pinnedLat!, _pinnedLng!),
      );
    }
    return null;
  }

  int get deliveryFeeOrZero => _neighborhood?.deliveryFee ?? 0;

  Future<void> loadPersisted() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _pinnedLat = prefs.getDouble(_kLat);
      _pinnedLng = prefs.getDouble(_kLng);
      _placeNote = prefs.getString(_kNote);
      _resolvedPlaceName = prefs.getString(_kPlaceName);
      final zoneId = prefs.getString(_kZoneId);
      final zoneName = prefs.getString(_kZoneName);
      if (zoneId != null &&
          zoneId.isNotEmpty &&
          zoneName != null &&
          zoneName.isNotEmpty) {
        _neighborhood = Neighborhood(
          id: zoneId,
          name: zoneName,
          nameEn: zoneName,
          deliveryFee: prefs.getInt(_kZoneFee) ?? 0,
          lat: prefs.getDouble(_kZoneLat),
          lng: prefs.getDouble(_kZoneLng),
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pinnedLat != null) {
        await prefs.setDouble(_kLat, _pinnedLat!);
      } else {
        await prefs.remove(_kLat);
      }
      if (_pinnedLng != null) {
        await prefs.setDouble(_kLng, _pinnedLng!);
      } else {
        await prefs.remove(_kLng);
      }
      if (_placeNote != null && _placeNote!.isNotEmpty) {
        await prefs.setString(_kNote, _placeNote!);
      } else {
        await prefs.remove(_kNote);
      }
      if (_resolvedPlaceName != null && _resolvedPlaceName!.isNotEmpty) {
        await prefs.setString(_kPlaceName, _resolvedPlaceName!);
      } else {
        await prefs.remove(_kPlaceName);
      }
      final n = _neighborhood;
      if (n != null) {
        await prefs.setString(_kZoneId, n.id);
        await prefs.setString(_kZoneName, n.name);
        await prefs.setInt(_kZoneFee, n.deliveryFee);
        if (n.lat != null) await prefs.setDouble(_kZoneLat, n.lat!);
        if (n.lng != null) await prefs.setDouble(_kZoneLng, n.lng!);
      } else {
        await prefs.remove(_kZoneId);
        await prefs.remove(_kZoneName);
        await prefs.remove(_kZoneFee);
        await prefs.remove(_kZoneLat);
        await prefs.remove(_kZoneLng);
      }
    } catch (_) {}
  }

  void setNeighborhood(Neighborhood? n) {
    _neighborhood = n;
    _persist();
    notifyListeners();
  }

  void setResolvedPlaceName(String? name) {
    final t = name?.trim();
    _resolvedPlaceName = (t == null || t.isEmpty) ? null : t;
    _persist();
    notifyListeners();
  }

  void setPin({
    required double lat,
    required double lng,
    Neighborhood? neighborhood,
    bool clearNeighborhood = false,
    String? placeNote,
    bool clearPlaceNote = false,
    String? resolvedPlaceName,
    bool clearResolvedPlaceName = false,
  }) {
    _pinnedLat = lat;
    _pinnedLng = lng;
    if (clearNeighborhood) {
      _neighborhood = null;
    } else if (neighborhood != null) {
      _neighborhood = neighborhood;
    }
    if (clearPlaceNote) {
      _placeNote = null;
    } else if (placeNote != null) {
      _placeNote = placeNote.trim().isEmpty ? null : placeNote.trim();
    }
    if (clearResolvedPlaceName) {
      _resolvedPlaceName = null;
    } else if (resolvedPlaceName != null) {
      final t = resolvedPlaceName.trim();
      _resolvedPlaceName = t.isEmpty ? null : t;
    }
    _persist();
    notifyListeners();
  }

  /// Partial update so legacy code can assign lat then lng separately.
  void updateCoords({double? lat, double? lng}) {
    if (lat != null) _pinnedLat = lat;
    if (lng != null) _pinnedLng = lng;
    _persist();
    notifyListeners();
  }

  void setPlaceNote(String? note) {
    _placeNote = (note == null || note.trim().isEmpty) ? null : note.trim();
    _persist();
    notifyListeners();
  }

  void clearPin() {
    _pinnedLat = null;
    _pinnedLng = null;
    _placeNote = null;
    _resolvedPlaceName = null;
    _neighborhood = null;
    _persist();
    notifyListeners();
  }

  /// Remap saved zone id onto freshly loaded backend neighborhoods (fees/names).
  void rebindNeighborhoodFromCatalog(List<Neighborhood> zones) {
    if (_neighborhood == null || zones.isEmpty) return;
    final current = _neighborhood!;
    Neighborhood? match;
    for (final z in zones) {
      if (z.id == current.id || z.name == current.name) {
        match = z;
        break;
      }
    }
    if (match != null) {
      _neighborhood = match;
      _persist();
      notifyListeners();
    }
  }
}
