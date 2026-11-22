class MapPlace {
  final String id;
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final String categoryKu;
  final String categoryAr;
  final String categoryEn;
  final double latitude;
  final double longitude;
  final String? addressDetailsKu;
  final String? addressDetailsAr;
  final String? addressDetailsEn;
  final String iconKey; // 'hospital', 'school', 'market', 'restaurant', 'park', 'general'
  final double? rating;
  final String? openHours;

  const MapPlace({
    required this.id,
    required this.nameKu,
    required this.nameAr,
    required this.nameEn,
    required this.categoryKu,
    required this.categoryAr,
    required this.categoryEn,
    required this.latitude,
    required this.longitude,
    this.addressDetailsKu,
    this.addressDetailsAr,
    this.addressDetailsEn,
    this.iconKey = 'general',
    this.rating,
    this.openHours,
  });

  String localizedName(String langCode) {
    if (langCode == 'ar' || langCode == 'العربية') return nameAr;
    if (langCode == 'en' || langCode == 'English') return nameEn;
    return nameKu;
  }

  String localizedCategory(String langCode) {
    if (langCode == 'ar' || langCode == 'العربية') return categoryAr;
    if (langCode == 'en' || langCode == 'English') return categoryEn;
    return categoryKu;
  }

  String? localizedAddress(String langCode) {
    if (langCode == 'ar' || langCode == 'العربية') return addressDetailsAr ?? addressDetailsKu;
    if (langCode == 'en' || langCode == 'English') return addressDetailsEn ?? addressDetailsKu;
    return addressDetailsKu;
  }
}

/// Standard curated landmarks & points of interest in Kalar (کەلار), Iraq
class KalarLandmarks {
  static const double kalarCenterLat = 34.6313;
  static const double kalarCenterLng = 45.3177;

  static const List<MapPlace> curatedPlaces = [
    // Hospitals & Health
    MapPlace(
      id: 'hosp_kalar_general',
      nameKu: 'نەخۆشخانەی گشتی کەلار (شەهید مەلا ڕەحیم)',
      nameAr: 'مستشفى كلار العام',
      nameEn: 'Kalar General Hospital',
      categoryKu: 'نەخۆشخانە',
      categoryAr: 'مستشفى',
      categoryEn: 'Hospital',
      latitude: 34.6288,
      longitude: 45.3195,
      addressDetailsKu: 'شەقامی سەرەکی گەرمیان، کەلار',
      addressDetailsAr: 'الشارع الرئيسي، كلار',
      addressDetailsEn: 'Main Highway, Kalar',
      iconKey: 'hospital',
      rating: 4.6,
      openHours: '24/7',
    ),
    MapPlace(
      id: 'hosp_kalar_emergency',
      nameKu: 'نەخۆشخانەی فریاکەوتنی کەلار',
      nameAr: 'مستشفى طوارئ كلار',
      nameEn: 'Kalar Emergency Hospital',
      categoryKu: 'نەخۆشخانە',
      categoryAr: 'مستشفى',
      categoryEn: 'Hospital',
      latitude: 34.6340,
      longitude: 45.3210,
      addressDetailsKu: 'نزیک قایمقامیەتی کەلار',
      addressDetailsAr: 'قرب قائممقامية كلار',
      addressDetailsEn: 'Near Kalar District Directorate',
      iconKey: 'hospital',
      rating: 4.5,
      openHours: '24/7',
    ),

    // Universities & Schools
    MapPlace(
      id: 'edu_garmian_univ',
      nameKu: 'زانکۆی گەرمیان - کامپەسی کەلار',
      nameAr: 'جامعة كرميان - كلار',
      nameEn: 'University of Garmian - Kalar Campus',
      categoryKu: 'قوتابخانە و زانکۆ',
      categoryAr: 'مدرسة وجامعة',
      categoryEn: 'University & School',
      latitude: 34.6420,
      longitude: 45.3090,
      addressDetailsKu: 'گەڕەکی زانکۆ، کەلار',
      addressDetailsAr: 'حي الجامعة، كلار',
      addressDetailsEn: 'Zanko Quarter, Kalar',
      iconKey: 'school',
      rating: 4.8,
      openHours: '08:00 - 15:00',
    ),
    MapPlace(
      id: 'edu_polytechnic',
      nameKu: 'پەیمانگای تەکنیکی کەلار',
      nameAr: 'المعهد التقني كلار',
      nameEn: 'Kalar Technical Institute',
      categoryKu: 'قوتابخانە و زانکۆ',
      categoryAr: 'مدرسة وجامعة',
      categoryEn: 'University & School',
      latitude: 34.6385,
      longitude: 45.3125,
      addressDetailsKu: 'شەقامی پەیمانگا، کەلار',
      addressDetailsAr: 'شارع المعهد، كلار',
      addressDetailsEn: 'Institute St, Kalar',
      iconKey: 'school',
      rating: 4.7,
      openHours: '08:00 - 14:30',
    ),

    // Markets & Bazaars
    MapPlace(
      id: 'market_central_bazaar',
      nameKu: 'بازاڕی گەورەی کەلار (ناوبازاڕ)',
      nameAr: 'سوق كلار المركزي',
      nameEn: 'Kalar Grand Central Bazaar',
      categoryKu: 'بازاڕ',
      categoryAr: 'سوق',
      categoryEn: 'Market',
      latitude: 34.6313,
      longitude: 45.3177,
      addressDetailsKu: 'ناوەندی بازاڕی کەلار، نزیک فلکەی ئاڵا',
      addressDetailsAr: 'وسط كلار، قرب فلكة العلم',
      addressDetailsEn: 'Downtown Kalar, Flag Circle',
      iconKey: 'market',
      rating: 4.9,
      openHours: '08:00 - 23:00',
    ),
    MapPlace(
      id: 'market_city_center',
      nameKu: 'سیتی مۆڵ کەلار',
      nameAr: 'سيتي مول كلار',
      nameEn: 'Kalar City Mall',
      categoryKu: 'بازاڕ',
      categoryAr: 'سوق',
      categoryEn: 'Market',
      latitude: 34.6335,
      longitude: 45.3225,
      addressDetailsKu: 'شەقامی سەرەکی، کەلار',
      addressDetailsAr: 'الشارع العام، كلار',
      addressDetailsEn: 'Main Road, Kalar',
      iconKey: 'market',
      rating: 4.7,
      openHours: '09:00 - 00:00',
    ),

    // Parks & Public Areas
    MapPlace(
      id: 'park_shar_kalar',
      nameKu: 'پارکی شار (باخچەی گشتی کەلار)',
      nameAr: 'حديقة المدينة العامة كلار',
      nameEn: 'Kalar Central City Park',
      categoryKu: 'باخچە و سەوزایی',
      categoryAr: 'حدائق ومتنزهات',
      categoryEn: 'Parks & Recreation',
      latitude: 34.6295,
      longitude: 45.3150,
      addressDetailsKu: 'گەڕەکی سیروان، نزیک ناوبازاڕ',
      addressDetailsAr: 'حي سيروان، قرب السوق',
      addressDetailsEn: 'Sirwan Quarter, Kalar',
      iconKey: 'park',
      rating: 4.8,
      openHours: '24/7',
    ),
    MapPlace(
      id: 'park_sherwana_castle',
      nameKu: 'قەڵای شێروانە و سەیرانگای دەوروبەری',
      nameAr: 'قلعة شيروانة والحدائق المحيطة',
      nameEn: 'Sherwana Castle & Historic Grounds',
      categoryKu: 'باخچە و سەوزایی',
      categoryAr: 'حدائق ومتنزهات',
      categoryEn: 'Parks & Recreation',
      latitude: 34.6240,
      longitude: 45.3280,
      addressDetailsKu: 'باشووری ڕۆژهەڵاتی کەلار، سەر تەپۆڵکەی شێروانە',
      addressDetailsAr: 'جنوب شرق كلار، تلة شيروانة',
      addressDetailsEn: 'Southeast Kalar, Sherwana Hill',
      iconKey: 'park',
      rating: 5.0,
      openHours: '08:00 - 22:00',
    ),

    // Roads & Major Transportation Intersections
    MapPlace(
      id: 'road_kalar_sulaymaniyah',
      nameKu: 'ڕێگای کەلار - دەربەندیخان - سلێمانی',
      nameAr: 'طريق كلار - دربنديخان - السليمانية',
      nameEn: 'Kalar - Sulaymaniyah Highway',
      categoryKu: 'ڕێگاکان',
      categoryAr: 'طرق ومحاور',
      categoryEn: 'Roads & Highways',
      latitude: 34.6490,
      longitude: 45.3050,
      addressDetailsKu: 'دەروازەی باکووری کەلار',
      addressDetailsAr: 'مدخل كلار الشمالي',
      addressDetailsEn: 'North Gate, Kalar',
      iconKey: 'general',
      rating: 4.6,
      openHours: '24/7',
    ),
    MapPlace(
      id: 'road_kalar_baghdad',
      nameKu: 'ڕێگای کەلار - خانەقین - بەغداد',
      nameAr: 'طريق كلار - خانقين - بغداد',
      nameEn: 'Kalar - Khanaqin - Baghdad Highway',
      categoryKu: 'ڕێگاکان',
      categoryAr: 'طرق ومحاور',
      categoryEn: 'Roads & Highways',
      latitude: 34.6150,
      longitude: 45.3350,
      addressDetailsKu: 'دەروازەی باشووری کەلار',
      addressDetailsAr: 'مدخل كلار الجنوبي',
      addressDetailsEn: 'South Gate, Kalar',
      iconKey: 'general',
      rating: 4.5,
      openHours: '24/7',
    ),
  ];
}
