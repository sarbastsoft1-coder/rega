import 'package:flutter/foundation.dart';
import '../models/customer_models.dart';

class LocationNotifier extends ChangeNotifier {
  Neighborhood _neighborhood = kalarNeighborhoods[1];
  double? _pinnedLat;
  double? _pinnedLng;
  String? _placeNote;

  Neighborhood get neighborhood => _neighborhood;
  double? get pinnedLat => _pinnedLat;
  double? get pinnedLng => _pinnedLng;
  String? get placeNote => _placeNote;
  bool get hasPin => _pinnedLat != null && _pinnedLng != null;

  void setNeighborhood(Neighborhood n) {
    _neighborhood = n;
    notifyListeners();
  }

  void setPin({
    required double lat,
    required double lng,
    Neighborhood? neighborhood,
    String? placeNote,
    bool clearPlaceNote = false,
  }) {
    _pinnedLat = lat;
    _pinnedLng = lng;
    if (neighborhood != null) _neighborhood = neighborhood;
    if (clearPlaceNote) {
      _placeNote = null;
    } else if (placeNote != null) {
      _placeNote = placeNote;
    }
    notifyListeners();
  }

  /// Partial update so legacy code can assign lat then lng separately.
  void updateCoords({double? lat, double? lng}) {
    if (lat != null) _pinnedLat = lat;
    if (lng != null) _pinnedLng = lng;
    notifyListeners();
  }

  void setPlaceNote(String? note) {
    _placeNote = (note == null || note.trim().isEmpty) ? null : note.trim();
    notifyListeners();
  }

  void clearPin() {
    _pinnedLat = null;
    _pinnedLng = null;
    _placeNote = null;
    notifyListeners();
  }
}
