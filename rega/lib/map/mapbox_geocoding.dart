import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'mapbox_tiles.dart';

/// A known local Kurdish neighborhood, district, residential complex (سیتی / کۆمەڵگا),
/// or landmark with real-world coordinates and optional bounding box.
class KurdishLocalPlace {
  final String id;
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final LatLng center;
  final double radiusMeters;
  final double? minLat;
  final double? maxLat;
  final double? minLng;
  final double? maxLng;
  final bool isCompound;
  final List<String> aliases;

  const KurdishLocalPlace({
    required this.id,
    required this.nameKu,
    required this.nameAr,
    required this.nameEn,
    required this.center,
    this.radiusMeters = 650,
    this.minLat,
    this.maxLat,
    this.minLng,
    this.maxLng,
    this.isCompound = false,
    this.aliases = const [],
  });

  bool containsBbox(LatLng pt) {
    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return false;
    }
    return pt.latitude >= minLat! &&
        pt.latitude <= maxLat! &&
        pt.longitude >= minLng! &&
        pt.longitude <= maxLng!;
  }
}

/// Forward search / autocomplete suggestion for the location picker.
class GeocodedPlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng point;
  final String? neighborhoodName;
  final bool isLocalCurated;

  const GeocodedPlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
    this.neighborhoodName,
    this.isLocalCurated = false,
  });
}

/// Reverse & forward geocoding tailored for Kurdish neighborhoods and residential
/// complexes (Kalar, Rizgari, Garmian, and Kurdistan / Iraq).
///
/// Resolution priority:
/// 1. Exact GPS coordinates (`lat`, `lng`) are always preserved by the caller.
/// 2. Curated local Kurdish neighborhood & residential compound geofences.
/// 3. OpenStreetMap Nominatim (`accept-language=ckb,ku,ar,en`, `namedetails=1`,
///    `addressdetails=1`) on both Web and Native.
/// 4. Mapbox Geocoding v5 (`country=iq`, `language=ar,en` with Kurdish normalizer).
/// 5. Graceful Kurdish fallback for new housing complexes / unmapped satellite areas.
class MapboxGeocoding {
  /// Real Kalar city center (ناو بازاڕی کەلار).
  static const LatLng kalarCenter = LatLng(34.6295, 45.3159);

  /// Curated list of Kalar, Rizgari & Garmian neighborhoods, residential complexes,
  /// and major landmarks with real satellite-verified coordinates.
  static const List<KurdishLocalPlace> localPlaces = [
    KurdishLocalPlace(
      id: 'n9',
      nameKu: 'ناو بازاڕی کەلار',
      nameAr: 'سوق كلار المركزي',
      nameEn: 'Kalar Downtown Bazaar',
      center: LatLng(34.6295, 45.3159),
      radiusMeters: 600,
      minLat: 34.6255,
      maxLat: 34.6330,
      minLng: 45.3115,
      maxLng: 45.3200,
      aliases: ['ناو بازاڕ', 'بازاڕی کەلار', 'سەنتەری کەلار', 'downtown', 'bazaar'],
    ),
    KurdishLocalPlace(
      id: 'n3',
      nameKu: 'گەڕەکی شەهیدان',
      nameAr: 'حي الشهداء',
      nameEn: 'Shahidan',
      center: LatLng(34.6345, 45.3185),
      radiusMeters: 680,
      minLat: 34.6315,
      maxLat: 34.6380,
      minLng: 45.3140,
      maxLng: 45.3225,
      aliases: ['شەهیدان', 'شهيدان', 'الشهداء', 'al-shuhada', 'shuhada', 'shahidan'],
    ),
    KurdishLocalPlace(
      id: 'n8',
      nameKu: 'گەڕەکی فەرمانبەران',
      nameAr: 'حي الموظفين',
      nameEn: 'Farmanbaran',
      center: LatLng(34.6372, 45.3242),
      radiusMeters: 700,
      minLat: 34.6335,
      maxLat: 34.6410,
      minLng: 45.3200,
      maxLng: 45.3285,
      aliases: ['فەرمانبەران', 'موظفين', 'الموظفين', 'farmanbaran', 'muwazafin'],
    ),
    KurdishLocalPlace(
      id: 'mamostayan',
      nameKu: 'گەڕەکی مامۆستایان',
      nameAr: 'حي المعلمين',
      nameEn: 'Mamostayan',
      center: LatLng(34.6322, 45.3265),
      radiusMeters: 680,
      minLat: 34.6285,
      maxLat: 34.6358,
      minLng: 45.3220,
      maxLng: 45.3310,
      aliases: ['مامۆستایان', 'معلمين', 'المعلمين', 'mamostayan', 'muallimin'],
    ),
    KurdishLocalPlace(
      id: 'n2',
      nameKu: 'گەڕەکی زانکۆ',
      nameAr: 'حي الجامعة',
      nameEn: 'Zanko',
      center: LatLng(34.6485, 45.3295),
      radiusMeters: 780,
      minLat: 34.6440,
      maxLat: 34.6535,
      minLng: 45.3240,
      maxLng: 45.3355,
      aliases: ['زانکۆ', 'زانکۆی گەرمیان', 'الجامعة', 'zanko', 'garmian university'],
    ),
    KurdishLocalPlace(
      id: 'bardasur',
      nameKu: 'گەڕەکی بەردەسوور',
      nameAr: 'حي بردسور',
      nameEn: 'Bardasur',
      center: LatLng(34.6445, 45.3270),
      radiusMeters: 750,
      minLat: 34.6400,
      maxLat: 34.6485,
      minLng: 45.3220,
      maxLng: 45.3325,
      aliases: ['بەردەسوور', 'بەردەسور', 'بردسور', 'bardasur', 'barda sur'],
    ),
    KurdishLocalPlace(
      id: 'n4',
      nameKu: 'گەڕەکی سیروان',
      nameAr: 'حي سيروان',
      nameEn: 'Sirwan',
      center: LatLng(34.6242, 45.3235),
      radiusMeters: 680,
      minLat: 34.6200,
      maxLat: 34.6280,
      minLng: 45.3190,
      maxLng: 45.3285,
      aliases: ['سیروان', 'سيروان', 'sirwan'],
    ),
    KurdishLocalPlace(
      id: 'n5',
      nameKu: 'گەڕەکی شۆڕش',
      nameAr: 'حي شورش',
      nameEn: 'Shorish',
      center: LatLng(34.6312, 45.3088),
      radiusMeters: 650,
      minLat: 34.6275,
      maxLat: 34.6350,
      minLng: 45.3040,
      maxLng: 45.3130,
      aliases: ['شۆڕش', 'شورش', 'shorish', 'shorsh'],
    ),
    KurdishLocalPlace(
      id: 'n6',
      nameKu: 'گەڕەکی بێساری',
      nameAr: 'حي بيساري',
      nameEn: 'Besari',
      center: LatLng(34.6410, 45.3208),
      radiusMeters: 680,
      minLat: 34.6375,
      maxLat: 34.6448,
      minLng: 45.3165,
      maxLng: 45.3250,
      aliases: ['بێساری', 'بيساري', 'besari', 'beysari'],
    ),
    KurdishLocalPlace(
      id: 'n7',
      nameKu: 'گەڕەکی کاکەییان',
      nameAr: 'حي كاكائيان',
      nameEn: 'Kakeyan',
      center: LatLng(34.6265, 45.3122),
      radiusMeters: 620,
      minLat: 34.6230,
      maxLat: 34.6298,
      minLng: 45.3080,
      maxLng: 45.3160,
      aliases: ['کاکەییان', 'کاکەییەکان', 'كاكائيان', 'kakeyan', 'kakaiyan'],
    ),
    KurdishLocalPlace(
      id: 'goran',
      nameKu: 'گەڕەکی گۆران',
      nameAr: 'حي كوران',
      nameEn: 'Goran',
      center: LatLng(34.6382, 45.3140),
      radiusMeters: 650,
      minLat: 34.6345,
      maxLat: 34.6420,
      minLng: 45.3095,
      maxLng: 45.3180,
      aliases: ['گۆران', 'كوران', 'goran'],
    ),
    KurdishLocalPlace(
      id: 'azadi',
      nameKu: 'گەڕەکی ئازادی',
      nameAr: 'حي آزادي',
      nameEn: 'Azadi',
      center: LatLng(34.6282, 45.3212),
      radiusMeters: 620,
      minLat: 34.6250,
      maxLat: 34.6315,
      minLng: 45.3175,
      maxLng: 45.3250,
      aliases: ['ئازادی', 'آزادي', 'الحرية', 'azadi'],
    ),
    KurdishLocalPlace(
      id: 'raparin',
      nameKu: 'گەڕەکی ڕاپەڕین',
      nameAr: 'حي رابرين',
      nameEn: 'Raparin',
      center: LatLng(34.6352, 45.3105),
      radiusMeters: 620,
      minLat: 34.6320,
      maxLat: 34.6385,
      minLng: 45.3060,
      maxLng: 45.3145,
      aliases: ['ڕاپەڕین', 'راپەڕین', 'رابرين', 'raparin'],
    ),
    KurdishLocalPlace(
      id: 'sarbakhoyi',
      nameKu: 'گەڕەکی سەربەخۆیی',
      nameAr: 'حي الاستقلال',
      nameEn: 'Sarbakhoyi',
      center: LatLng(34.6230, 45.3160),
      radiusMeters: 600,
      minLat: 34.6198,
      maxLat: 34.6260,
      minLng: 45.3120,
      maxLng: 45.3198,
      aliases: ['سەربەخۆیی', 'الاستقلال', 'sarbakhoyi'],
    ),
    KurdishLocalPlace(
      id: 'hamrin',
      nameKu: 'گەڕەکی حەمرین',
      nameAr: 'حي حمرين',
      nameEn: 'Hamrin',
      center: LatLng(34.6215, 45.3198),
      radiusMeters: 600,
      aliases: ['حەمرین', 'حمرين', 'hamrin'],
    ),
    KurdishLocalPlace(
      id: 'ashti',
      nameKu: 'گەڕەکی ئاشتی',
      nameAr: 'حي آشتي',
      nameEn: 'Ashti',
      center: LatLng(34.6395, 45.3172),
      radiusMeters: 600,
      aliases: ['ئاشتی', 'آشتي', 'ashti'],
    ),
    KurdishLocalPlace(
      id: 'nawroz',
      nameKu: 'گەڕەکی نەورۆز',
      nameAr: 'حي نوروز',
      nameEn: 'Nawroz',
      center: LatLng(34.6330, 45.3055),
      radiusMeters: 600,
      aliases: ['نەورۆز', 'نوروز', 'nawroz', 'newroz'],
    ),
    KurdishLocalPlace(
      id: 'sarkawtin',
      nameKu: 'گەڕەکی سەرکەوتن',
      nameAr: 'حي سركوتن',
      nameEn: 'Sarkawtin',
      center: LatLng(34.6368, 45.3072),
      radiusMeters: 600,
      aliases: ['سەرکەوتن', 'سركوتن', 'sarkawtin'],
    ),
    KurdishLocalPlace(
      id: 'garmian_qtr',
      nameKu: 'گەڕەکی گەرمیان',
      nameAr: 'حي كرميان',
      nameEn: 'Garmian Quarter',
      center: LatLng(34.6305, 45.3292),
      radiusMeters: 620,
      aliases: ['گەڕەکی گەرمیان', 'حي كرميان'],
    ),
    KurdishLocalPlace(
      id: 'sherwana_castle',
      nameKu: 'قەڵای شێروانە',
      nameAr: 'قلعة شيروانة',
      nameEn: 'Sherwana Castle',
      center: LatLng(34.6205, 45.3085),
      radiusMeters: 550,
      aliases: ['شێروانە', 'قەڵای شێروانە', 'پارکی شێروانە', 'sherwana', 'shirwana'],
    ),
    // Residential complexes & modern compounds (سیتی و کۆمەڵگاکانی نیشتەجێبوون)
    KurdishLocalPlace(
      id: 'lana_city',
      nameKu: 'لانه سیتی (کەلار)',
      nameAr: 'لانة سيتي',
      nameEn: 'Lana City',
      center: LatLng(34.6425, 45.3115),
      radiusMeters: 650,
      isCompound: true,
      aliases: ['لانه سیتی', 'لانە سیتی', 'lana city'],
    ),
    KurdishLocalPlace(
      id: 'garmian_city',
      nameKu: 'گەرمیان سیتی',
      nameAr: 'كرميان سيتي',
      nameEn: 'Garmian City',
      center: LatLng(34.6460, 45.3190),
      radiusMeters: 650,
      isCompound: true,
      aliases: ['گەرمیان سیتی', 'garmian city'],
    ),
    KurdishLocalPlace(
      id: 'qala_city',
      nameKu: 'قەڵا سیتی',
      nameAr: 'قلعة سيتي',
      nameEn: 'Qala City',
      center: LatLng(34.6185, 45.3135),
      radiusMeters: 650,
      isCompound: true,
      aliases: ['قەڵا سیتی', 'qala city'],
    ),
    KurdishLocalPlace(
      id: 'sherwana_city',
      nameKu: 'شێروانە سیتی',
      nameAr: 'شيروانة سيتي',
      nameEn: 'Sherwana City',
      center: LatLng(34.6175, 45.3055),
      radiusMeters: 650,
      isCompound: true,
      aliases: ['شێروانە سیتی', 'sherwana city'],
    ),
    KurdishLocalPlace(
      id: 'bahashti_kalar',
      nameKu: 'کۆمەڵگای بەهەشتی کەلار',
      nameAr: 'مجمع بهشتي كلار',
      nameEn: 'Bahashti Kalar',
      center: LatLng(34.6510, 45.3230),
      radiusMeters: 700,
      isCompound: true,
      aliases: ['بەهەشتی کەلار', 'بهشتي كلار', 'bahashti kalar'],
    ),
    KurdishLocalPlace(
      id: 'gulan_city',
      nameKu: 'گوڵان سیتی',
      nameAr: 'كولان سيتي',
      nameEn: 'Gulan City',
      center: LatLng(34.6400, 45.3315),
      radiusMeters: 650,
      isCompound: true,
      aliases: ['گوڵان سیتی', 'gulan city'],
    ),
    KurdishLocalPlace(
      id: 'kalar_new_town',
      nameKu: 'کەلاری نوێ',
      nameAr: 'كلار الجديدة',
      nameEn: 'New Kalar',
      center: LatLng(34.6470, 45.3145),
      radiusMeters: 750,
      isCompound: true,
      aliases: ['کەلاری نوێ', 'كلار الجديدة', 'new kalar'],
    ),
    // Rizgari subdistrict (شارۆچکەی ڕزگاری / سمود)
    KurdishLocalPlace(
      id: 'n1',
      nameKu: 'شارۆچکەی ڕزگاری',
      nameAr: 'ناحية رزكاري',
      nameEn: 'Rzgari',
      center: LatLng(34.6250, 45.2760),
      radiusMeters: 1800,
      minLat: 34.6120,
      maxLat: 34.6380,
      minLng: 45.2580,
      maxLng: 45.2920,
      aliases: ['ڕزگاری', 'رزگاری', 'شارۆچکەی رزگاری', 'سمود', 'الصمود', 'رزكاري', 'rzgari', 'rizgari'],
    ),
  ];

  /// Short GPS label — always changes when the user moves the map pin.
  static String coordinatesLabel(LatLng point, {int decimals = 5}) {
    return '${point.latitude.toStringAsFixed(decimals)}, '
        '${point.longitude.toStringAsFixed(decimals)}';
  }

  /// Haversine distance in meters between two coordinates.
  static double distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(_degToRad(a.latitude)) *
            math.cos(_degToRad(b.latitude)) *
            sinLng *
            sinLng;
    return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// True if [lat], [lng] are the legacy shifted Kalar seed coordinates
  /// (around 34.67..34.71 north near Sayyid Khalil) or missing.
  static bool isLegacyShiftedKalarCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return true;
    // All old seeded zones in DatabaseSeeder were at lat 34.6710..34.7010, lng 45.2950..45.3360
    return lat >= 34.668 && lat <= 34.710 && lng >= 45.285 && lng <= 45.345;
  }

  /// Resolves real-world Kalar coordinates for a backend neighborhood by code or name,
  /// correcting legacy shifted coordinates (`34.67..34.70` -> `34.62..34.65`).
  static LatLng? resolveKnownCoordForName(
    String nameKu, {
    String? nameEn,
    String? code,
    double? rawLat,
    double? rawLng,
  }) {
    final normCode = code?.trim().toLowerCase() ?? '';
    final normKu = _normalizeSearchKey(nameKu);
    final normEn = _normalizeSearchKey(nameEn ?? '');

    for (final p in localPlaces) {
      if (normCode.isNotEmpty && p.id.toLowerCase() == normCode) {
        return p.center;
      }
      final pKu = _normalizeSearchKey(p.nameKu);
      final pEn = _normalizeSearchKey(p.nameEn);
      if (normKu.isNotEmpty && (pKu == normKu || pKu.contains(normKu) || normKu.contains(pKu))) {
        return p.center;
      }
      if (normEn.isNotEmpty && (pEn == normEn || pEn.contains(normEn))) {
        return p.center;
      }
      for (final alias in p.aliases) {
        final a = _normalizeSearchKey(alias);
        if (a.isNotEmpty && (normKu == a || normEn == a || normKu.contains(a))) {
          return p.center;
        }
      }
    }

    if (rawLat != null && rawLng != null && !isLegacyShiftedKalarCoord(rawLat, rawLng)) {
      return LatLng(rawLat, rawLng);
    }
    return null;
  }

  /// Matches [point] against curated Kurdish neighborhoods and residential complexes.
  /// Prioritizes bounding-box containment, then nearest center within [maxMeters].
  static KurdishLocalPlace? matchLocalPlace(
    LatLng point, {
    double? maxMeters,
  }) {
    KurdishLocalPlace? bestBbox;
    double bestBboxDist = double.infinity;

    KurdishLocalPlace? bestRadius;
    double bestRadiusDist = double.infinity;

    for (final place in localPlaces) {
      final dist = distanceMeters(point, place.center);
      if (place.containsBbox(point) && dist < bestBboxDist) {
        bestBboxDist = dist;
        bestBbox = place;
      }
      final limit = maxMeters ?? place.radiusMeters;
      if (dist <= limit && dist < bestRadiusDist) {
        bestRadiusDist = dist;
        bestRadius = place;
      }
    }
    return bestBbox ?? bestRadius;
  }

  /// Nearest curated place within [maxMeters], even if outside strict neighborhood radius
  /// (used for "نزیک گەڕەکی ..." fallback in new residential expansions).
  static ({KurdishLocalPlace place, double distanceMeters})? nearestLocalPlace(
    LatLng point, {
    double maxMeters = 1600,
  }) {
    KurdishLocalPlace? nearest;
    double minDist = double.infinity;
    for (final place in localPlaces) {
      final d = distanceMeters(point, place.center);
      if (d < minDist) {
        minDist = d;
        nearest = place;
      }
    }
    if (nearest == null || minDist > maxMeters) return null;
    return (place: nearest, distanceMeters: minDist);
  }

  static bool isInsideKalarUrbanArea(LatLng pt) {
    return pt.latitude >= 34.600 &&
        pt.latitude <= 34.662 &&
        pt.longitude >= 45.293 &&
        pt.longitude <= 45.350;
  }

  static bool isInsideRizgariArea(LatLng pt) {
    return pt.latitude >= 34.608 &&
        pt.latitude <= 34.645 &&
        pt.longitude >= 45.250 &&
        pt.longitude <= 45.293;
  }

  /// Human-readable Kurdish place name for [point].
  /// Combines curated local Kurdish neighborhood/compound boundaries with
  /// OpenStreetMap Nominatim (`ckb,ku,ar,en`) and Mapbox Geocoding (`iq`),
  /// falling back gracefully for new housing complexes.
  static Future<String?> reversePlaceName(
    LatLng point, {
    Duration timeout = const Duration(seconds: 6),
    String language = 'ckb,ku,ar,en',
  }) async {
    // 1. Check curated local Kurdish neighborhood / compound geofence first.
    final localMatch = matchLocalPlace(point);

    // 2. Query OSM Nominatim (works on both Web and Native when headers are CORS-safe)
    //    to see if there is a specific Kurdish street, mosque, school, park, or neighborhood.
    String? osmLabel;
    osmLabel = await _reverseNominatim(
      point,
      timeout: timeout,
      acceptLanguage: language,
    );

    // 3. Query Mapbox if token is configured and OSM didn't yield a rich label.
    String? mapboxLabel;
    if (MapboxTiles.accessToken.isNotEmpty) {
      mapboxLabel = await _reverseMapbox(
        point,
        timeout: timeout,
      );
    }

    final remoteBest = _pickBestRemoteLabel(osmLabel, mapboxLabel);

    // 4. Combine local Kurdish neighborhood match with any specific remote POI/street.
    if (localMatch != null) {
      if (remoteBest != null &&
          remoteBest.isNotEmpty &&
          !_isGenericCityOrDistrict(remoteBest) &&
          !_isSamePlaceName(localMatch.nameKu, remoteBest)) {
        return '${localMatch.nameKu} · $remoteBest';
      }
      return localMatch.nameKu;
    }

    // 5. No exact local polygon match: if remote returned a specific non-generic Kurdish label, use it.
    if (remoteBest != null &&
        remoteBest.isNotEmpty &&
        !_isGenericCityOrDistrict(remoteBest)) {
      if (isInsideKalarUrbanArea(point) && !remoteBest.contains('کەلار')) {
        return 'کەلار · $remoteBest';
      }
      if (isInsideRizgariArea(point) && !remoteBest.contains('ڕزگاری')) {
        return 'ڕزگاری · $remoteBest';
      }
      return remoteBest;
    }

    // 6. Graceful fallback for new housing complexes / unmapped satellite areas in Kalar & Rizgari
    //    where Mapbox/OSM has no official street or neighborhood name.
    if (isInsideRizgariArea(point)) {
      return 'شارۆچکەی ڕزگاری · ناوچەی نیشتەجێبوون';
    }
    if (isInsideKalarUrbanArea(point)) {
      final near = nearestLocalPlace(point, maxMeters: 1350);
      if (near != null) {
        return 'کەلار · نزیک ${near.place.nameKu}';
      }
      return 'کەلار · گەڕەک / کۆمەڵگای نوێ';
    }

    // 7. Outside Kalar/Rizgari: return normalized remote city/town or clean GPS fallback.
    if (remoteBest != null && remoteBest.isNotEmpty) {
      return remoteBest;
    }
    return null;
  }

  /// Forward search / autocomplete for Kurdish neighborhoods, residential complexes,
  /// landmarks, and streets across Kalar, Garmian, and Iraq.
  static Future<List<GeocodedPlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // Return top curated local neighborhoods & compounds when search is empty.
      return localPlaces
          .map(
            (p) => GeocodedPlaceSuggestion(
              title: p.nameKu,
              subtitle: p.isCompound ? 'کۆمەڵگای نیشتەجێبوون · کەلار' : 'گەڕەک · کەلار / گەرمیان',
              point: p.center,
              neighborhoodName: p.nameKu,
              isLocalCurated: true,
            ),
          )
          .toList();
    }

    final normQ = _normalizeSearchKey(trimmed);
    final results = <GeocodedPlaceSuggestion>[];
    final seenTitles = <String>{};

    // 1. Instant local match against curated Kurdish neighborhoods & residential complexes.
    for (final p in localPlaces) {
      final matchKu = _normalizeSearchKey(p.nameKu).contains(normQ);
      final matchAr = _normalizeSearchKey(p.nameAr).contains(normQ);
      final matchEn = _normalizeSearchKey(p.nameEn).contains(normQ);
      final matchAlias = p.aliases.any((a) => _normalizeSearchKey(a).contains(normQ));
      if (matchKu || matchAr || matchEn || matchAlias) {
        seenTitles.add(p.nameKu);
        results.add(
          GeocodedPlaceSuggestion(
            title: p.nameKu,
            subtitle: p.isCompound ? 'کۆمەڵگای نیشتەجێبوون · کەلار' : 'گەڕەک · کەلار / گەرمیان',
            point: p.center,
            neighborhoodName: p.nameKu,
            isLocalCurated: true,
          ),
        );
      }
    }

    // 2. Remote search via OSM Nominatim bounded to Iraq with Kurdish language priority.
    try {
      final focus = proximity ?? kalarCenter;
      final viewbox = '${focus.longitude - 0.35},${focus.latitude + 0.35},'
          '${focus.longitude + 0.35},${focus.latitude - 0.35}';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(trimmed)}'
        '&format=jsonv2'
        '&addressdetails=1'
        '&namedetails=1'
        '&countrycodes=iq'
        '&viewbox=$viewbox'
        '&accept-language=ckb,ku,ar,en'
        '&limit=6',
      );
      final res = await http
          .get(
            uri,
            headers: kIsWeb
                ? const {'Accept': 'application/json'}
                : const {
                    'Accept': 'application/json',
                    'User-Agent': 'rega-customer/1.0 (kurdish delivery map picker)',
                  },
          )
          .timeout(timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          for (final item in list) {
            if (item is! Map<String, dynamic>) continue;
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null) continue;
            final pt = LatLng(lat, lon);
            final local = matchLocalPlace(pt);
            final rawName = _extractNominatimLabel(item) ?? item['name']?.toString() ?? '';
            final cleanTitle = normalizePlaceLabel(rawName) ?? local?.nameKu ?? rawName.trim();
            if (cleanTitle.isEmpty || seenTitles.contains(cleanTitle)) continue;
            seenTitles.add(cleanTitle);
            results.add(
              GeocodedPlaceSuggestion(
                title: cleanTitle,
                subtitle: local != null ? local.nameKu : coordinatesLabel(pt, decimals: 4),
                point: pt,
                neighborhoodName: local?.nameKu,
              ),
            );
          }
        }
      }
    } catch (_) {}

    return results;
  }

  static String? _pickBestRemoteLabel(String? osm, String? mapbox) {
    final cleanOsm = normalizePlaceLabel(osm);
    final cleanMapbox = normalizePlaceLabel(mapbox);

    if (cleanOsm != null && cleanOsm.isNotEmpty) {
      // Prefer Kurdish/Arabic script over Latin transliteration.
      if (_containsKurdishOrArabicScript(cleanOsm) && !_isGenericCityOrDistrict(cleanOsm)) {
        return cleanOsm;
      }
    }
    if (cleanMapbox != null && cleanMapbox.isNotEmpty) {
      if (_containsKurdishOrArabicScript(cleanMapbox) && !_isGenericCityOrDistrict(cleanMapbox)) {
        return cleanMapbox;
      }
    }
    if (cleanOsm != null && cleanOsm.isNotEmpty && !_isGenericCityOrDistrict(cleanOsm)) {
      return cleanOsm;
    }
    if (cleanMapbox != null && cleanMapbox.isNotEmpty && !_isGenericCityOrDistrict(cleanMapbox)) {
      return cleanMapbox;
    }
    return cleanOsm ?? cleanMapbox;
  }

  static bool _containsKurdishOrArabicScript(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  static bool _isSamePlaceName(String a, String b) {
    final na = _normalizeSearchKey(a);
    final nb = _normalizeSearchKey(b);
    if (na.isEmpty || nb.isEmpty) return false;
    return na == nb || na.contains(nb) || nb.contains(na);
  }

  static bool _isGenericCityOrDistrict(String label) {
    final norm = _normalizeSearchKey(label);
    const generics = {
      'کەلار',
      'قەزای کەلار',
      'كلار',
      'قضاء كلار',
      'kalar',
      'kelar',
      'qada kalar',
      'kalar district',
      'سلێمانی',
      'پارێزگای سلێمانی',
      'sulaymaniyah',
      'sulaymaniyah governorate',
      'گەرمیان',
      'ئیدارەی گەرمیان',
      'garmian',
      'عێراق',
      'العراق',
      'iraq',
      'هەرێمی کوردستان',
      'kurdistan',
      'kurdistan region',
      'سەید خەلیل',
      'سید خلیل',
      'sayyid khalil',
    };
    return generics.contains(norm);
  }

  static String _normalizeSearchKey(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('گەڕەکی ', '')
        .replaceAll('گەرەکی ', '')
        .replaceAll('شارۆچکەی ', '')
        .replaceAll('کۆمەڵگای ', '')
        .replaceAll('حي ', '')
        .replaceAll('ناحية ', '')
        .replaceAll('قضاء ', '')
        .replaceAll('محافظة ', '')
        .replaceAll('ڕ', 'ر')
        .replaceAll('ڵ', 'ل')
        .replaceAll('ۆ', 'و')
        .replaceAll('ێ', 'ی')
        .replaceAll('ە', 'ه')
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ی')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'[\s\-_]+'), ' ')
        .trim();
  }

  /// Normalizes raw Mapbox/OSM place strings into clean Kurdish names,
  /// filtering out awkward transliterations, bare highway numbers, and administrative noise.
  static String? normalizePlaceLabel(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (looksLikeCoordinates(text)) return null;
    if (_isNumberOnly(text)) return null;

    // Reject unnamed road / highway number placeholders.
    final lower = text.toLowerCase();
    if (lower == 'unnamed road' ||
        lower == 'unclassified' ||
        lower == 'residential' ||
        RegExp(r'^(highway|route|road|st|street)\s*\d+$', caseSensitive: false).hasMatch(text) ||
        RegExp(r'^\d{4,6}$').hasMatch(text)) {
      return null;
    }

    // Match against our curated local places & aliases first.
    final key = _normalizeSearchKey(text);
    for (final p in localPlaces) {
      if (_normalizeSearchKey(p.nameKu) == key ||
          _normalizeSearchKey(p.nameAr) == key ||
          _normalizeSearchKey(p.nameEn) == key) {
        return p.nameKu;
      }
      for (final alias in p.aliases) {
        if (_normalizeSearchKey(alias) == key) {
          return p.nameKu;
        }
      }
    }

    // Known city / district / landmark transliteration replacements.
    const dictionary = <String, String>{
      'kalar': 'کەلار',
      'kelar': 'کەلار',
      'qalar': 'کەلار',
      'qada kalar': 'کەلار',
      'kalar district': 'کەلار',
      'كلار': 'کەلار',
      'قضاء كلار': 'کەلار',
      'rizgari': 'شارۆچکەی ڕزگاری',
      'rzgari': 'شارۆچکەی ڕزگاری',
      'rizgary': 'شارۆچکەی ڕزگاری',
      'ناحية رزكاري': 'شارۆچکەی ڕزگاری',
      'رزكاري': 'شارۆچکەی ڕزگاری',
      'الصمود': 'شارۆچکەی ڕزگاری',
      'sulaymaniyah': 'سلێمانی',
      'sulaimani': 'سلێمانی',
      'slemani': 'سلێمانی',
      ' السليمانية': 'سلێمانی',
      'السليمانية': 'سلێمانی',
      'erbil': 'هەولێر',
      'arbil': 'هەولێر',
      'hawler': 'هەولێر',
      'أربيل': 'هەولێر',
      'اربيل': 'هەولێر',
      'duhok': 'دهۆک',
      'dahuk': 'دهۆک',
      'دهوك': 'دهۆک',
      'halabja': 'هەڵەبجە',
      'حلبجة': 'هەڵەبجە',
      'kirkuk': 'کەرکووک',
      'كركوك': 'کەرکووک',
      'kifri': 'کفری',
      'كفري': 'کفری',
      'darbandikhan': 'دەربەندیخان',
      'دربندخان': 'دەربەندیخان',
      'chamchamal': 'چەمچەماڵ',
      'جمجمال': 'چەمچەماڵ',
      'khanaqin': 'خانەقین',
      'خانقين': 'خانەقین',
      'pebaz': 'پێباز',
      'bawanoor': 'باوەنور',
      'bawanur': 'باوەنور',
      'sayyid khalil': 'سەید خەلیل',
      'سید خلیل': 'سەید خەلیل',
    };

    if (dictionary.containsKey(lower)) {
      return dictionary[lower];
    }

    // Replace common Arabic prefixes with Kurdish equivalents when script is Arabic/Kurdish.
    if (_containsKurdishOrArabicScript(text)) {
      text = text
          .replaceFirst(RegExp(r'^حي\s+'), 'گەڕەکی ')
          .replaceFirst(RegExp(r'^محلة\s+'), 'گەڕەکی ')
          .replaceFirst(RegExp(r'^ناحية\s+'), 'شارۆچکەی ')
          .replaceFirst(RegExp(r'^شارع\s+'), 'شەقامی ')
          .replaceFirst(RegExp(r'^مجمع\s+'), 'کۆمەڵگای ')
          .replaceFirst(RegExp(r'^جامع\s+'), 'مزگەوتی ')
          .replaceFirst(RegExp(r'^مسجد\s+'), 'مزگەوتی ')
          .replaceFirst(RegExp(r'^مدرسة\s+'), 'قوتابخانەی ')
          .replaceFirst(RegExp(r'^مستشفى\s+'), 'نەخۆشخانەی ');
      return text.trim();
    }

    // If it's a purely Latin string that wasn't in our dictionary (awkward transliteration),
    // discard it if it looks like an administrative or road code.
    if (RegExp(r'^[A-Za-z0-9\s\-_,\.]+$').hasMatch(text)) {
      if (lower.contains('governorate') ||
          lower.contains('district') ||
          lower.contains('subdistrict') ||
          lower.contains('province') ||
          lower.contains('iraq')) {
        return null;
      }
    }

    return text;
  }

  static int _typeRank(List<dynamic>? placeType) {
    if (placeType == null || placeType.isEmpty) return 50;
    final t = placeType.map((e) => e.toString()).toSet();
    // Prioritize neighborhood & locality over random distant POIs or unnamed road addresses.
    if (t.contains('neighborhood')) return 0;
    if (t.contains('locality')) return 1;
    if (t.contains('poi')) return 2;
    if (t.contains('address')) return 3;
    if (t.contains('place')) return 4;
    return 40;
  }

  static bool _isNumberOnly(String? text) =>
      text != null && text.isNotEmpty && RegExp(r'^\d+\w*$').hasMatch(text.trim());

  static String? _labelFromFeature(Map<String, dynamic> feature, LatLng point) {
    // Prefer Kurdish / Arabic localized text fields if present on the feature.
    final text = (feature['text_ckb'] ??
            feature['text_ku'] ??
            feature['text_ar'] ??
            feature['text'])
        ?.toString()
        .trim();
    final placeName = (feature['place_name_ckb'] ??
            feature['place_name_ku'] ??
            feature['place_name_ar'] ??
            feature['place_name'])
        ?.toString()
        .trim();
    final placeType = feature['place_type'] as List<dynamic>?;
    final rank = _typeRank(placeType);

    if (rank == 3) {
      if (text != null && text.isNotEmpty && !_isNumberOnly(text)) {
        final norm = normalizePlaceLabel(text);
        if (norm != null) return norm;
      }
      if (placeName != null && placeName.isNotEmpty) {
        final first = placeName.split(',').first.trim();
        final norm = normalizePlaceLabel(first);
        if (norm != null) return norm;
      }
    }

    if (text != null && text.isNotEmpty && !_isNumberOnly(text)) {
      final norm = normalizePlaceLabel(text);
      if (norm != null) return norm;
    }
    if (placeName != null && placeName.isNotEmpty) {
      final first = placeName.split(',').first.trim();
      return normalizePlaceLabel(first);
    }
    return null;
  }

  /// True when [label] is (or ends with) raw GPS coords like "36.0500, 44.0400".
  static bool looksLikeCoordinates(String? label) {
    if (label == null) return false;
    final t = label.trim();
    if (RegExp(r'^-?\d+\.\d+\s*,\s*-?\d+\.\d+$').hasMatch(t)) return true;
    if (RegExp(r'·\s*-?\d+\.\d+\s*,\s*-?\d+\.\d+$').hasMatch(t)) return true;
    return false;
  }

  static Future<String?> _reverseMapbox(
    LatLng point, {
    required Duration timeout,
  }) async {
    // Mapbox Geocoding v5 supports ISO 639-1 codes like 'ar,en' (passing 'ckb' or 'ku'
    // to Mapbox v5 can return HTTP 422). We pass country=iq & language=ar,en and then
    // normalize to Kurdish.
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      '${point.longitude},${point.latitude}.json'
      '?types=neighborhood,locality,poi,address,place'
      '&country=iq'
      '&limit=5'
      '&language=ar,en'
      '&access_token=${MapboxTiles.accessToken}',
    );

    try {
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final features = body['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final sorted = features.whereType<Map<String, dynamic>>().toList()
        ..sort(
          (a, b) => _typeRank(a['place_type'] as List<dynamic>?)
              .compareTo(_typeRank(b['place_type'] as List<dynamic>?)),
        );

      for (final f in sorted) {
        final candidate = _labelFromFeature(f, point);
        if (candidate != null &&
            candidate.isNotEmpty &&
            !_isGenericCityOrDistrict(candidate)) {
          return candidate;
        }
      }
      return _labelFromFeature(sorted.first, point);
    } catch (_) {
      return null;
    }
  }

  static String? _extractNominatimLabel(Map<String, dynamic> body) {
    final namedetails = body['namedetails'];
    if (namedetails is Map<String, dynamic>) {
      for (final key in const ['name:ckb', 'name:ku', 'official_name:ckb', 'official_name:ku']) {
        final v = namedetails[key]?.toString().trim();
        if (v != null && v.isNotEmpty) {
          final norm = normalizePlaceLabel(v);
          if (norm != null && norm.isNotEmpty) return norm;
        }
      }
    }

    final address = body['address'];
    String? neighborhoodPart;
    String? poiOrRoadPart;
    if (address is Map<String, dynamic>) {
      for (final k in const [
        'neighbourhood',
        'quarter',
        'suburb',
        'residential',
        'city_district',
        'hamlet',
      ]) {
        final raw = address[k]?.toString().trim();
        final norm = normalizePlaceLabel(raw);
        if (norm != null && norm.isNotEmpty && !_isGenericCityOrDistrict(norm)) {
          neighborhoodPart = norm;
          break;
        }
      }

      for (final k in const [
        'amenity',
        'building',
        'shop',
        'leisure',
        'tourism',
        'historic',
        'road',
        'pedestrian',
      ]) {
        final raw = address[k]?.toString().trim();
        final norm = normalizePlaceLabel(raw);
        if (norm != null &&
            norm.isNotEmpty &&
            !_isGenericCityOrDistrict(norm) &&
            norm != neighborhoodPart) {
          poiOrRoadPart = norm;
          break;
        }
      }
    }

    if (neighborhoodPart != null && poiOrRoadPart != null) {
      return '$neighborhoodPart · $poiOrRoadPart';
    }
    if (neighborhoodPart != null) return neighborhoodPart;

    if (namedetails is Map<String, dynamic>) {
      for (final key in const ['name', 'name:ar']) {
        final v = namedetails[key]?.toString().trim();
        final norm = normalizePlaceLabel(v);
        if (norm != null && norm.isNotEmpty && !_isGenericCityOrDistrict(norm)) {
          return norm;
        }
      }
    }

    if (poiOrRoadPart != null) return poiOrRoadPart;

    final name = normalizePlaceLabel(body['name']?.toString());
    if (name != null && name.isNotEmpty && !_isGenericCityOrDistrict(name)) {
      return name;
    }

    final display = body['display_name']?.toString().trim();
    if (display != null && display.isNotEmpty) {
      for (final part in display.split(',')) {
        final norm = normalizePlaceLabel(part.trim());
        if (norm != null && norm.isNotEmpty && !_isGenericCityOrDistrict(norm)) {
          return norm;
        }
      }
    }
    return null;
  }

  static Future<String?> _reverseNominatim(
    LatLng point, {
    required Duration timeout,
    String acceptLanguage = 'ckb,ku,ar,en',
  }) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${point.latitude}&lon=${point.longitude}'
      '&format=jsonv2'
      '&addressdetails=1'
      '&namedetails=1'
      '&accept-language=$acceptLanguage'
      '&zoom=18',
    );
    try {
      // On Web, sending a custom User-Agent header triggers a browser CORS preflight error.
      // Browsers automatically send their own User-Agent header when omitted.
      final res = await http
          .get(
            uri,
            headers: kIsWeb
                ? const {'Accept': 'application/json'}
                : const {
                    'Accept': 'application/json',
                    'User-Agent': 'rega-customer/1.0 (kurdish delivery map picker)',
                  },
          )
          .timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return _extractNominatimLabel(body);
    } catch (_) {
      return null;
    }
  }
}
