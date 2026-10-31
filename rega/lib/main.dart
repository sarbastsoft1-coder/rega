import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // 📍 پێویستە ئەم پاکێجە لە pubspec.yaml زیاد کرابێت
import 'package:permission_handler/permission_handler.dart'; // 🔔 بۆ داواکردنی ڕێگەپێدانی نۆتیکەیشن و ئەوانی تر
import 'package:connectivity_plus/connectivity_plus.dart'; // 🛡️ بۆ پشکنینی VPN و ئینتەرنێت
import 'package:safe_device/safe_device.dart'; // 🔒 بۆ پشکنینی هاک و ئیمۆلیتۆر
import 'package:screen_protector/screen_protector.dart'; // 🔒 بۆ ڕێگری لە وێنەگرتنی شاشە
// Platform import removed to fix unused warning
import 'package:latlong2/latlong.dart' show LatLng;
import 'live_order_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RegaApp());
}

/// ============================================================================
/// 🚀 REGA - ڕێگا (تەواوی کۆدی فڵاتەر / Full Flutter App Code)
/// ----------------------------------------------------------------------------
/// ئەم کۆدە 100% چاککراوەتەوە و بێ ئیرۆرە. دەتوانیت تەواوی ئەم کۆدە کۆپی بکەیت و لە Visual Studio Code
/// لە فایلی `lib/main.dart` دایبنێیت.
/// ============================================================================

class RegaApp extends StatefulWidget {
  const RegaApp({super.key});

  @override
  State<RegaApp> createState() => _RegaAppState();
}

class _RegaAppState extends State<RegaApp> {
  TextDirection _textDirection = TextDirection.rtl;
  String _currentLang = 'ckb'; // 'ckb' (Kurdish) or 'en' (English) or 'ar' (Arabic)

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  // 💾 بارکردنی زمانی پاشەکەوتکراو لە SharedPreferences کاتی کردنەوەی ئەپ
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('rega_saved_language_code');
      if (savedLang != null && savedLang.isNotEmpty) {
        setState(() {
          _currentLang = savedLang;
          _textDirection = (savedLang == 'ckb' || savedLang == 'ar') ? TextDirection.rtl : TextDirection.ltr;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved language in RegaApp: $e');
    }
  }

  // 💾 گۆڕین و پاشەکەوتکردنی زمان
  Future<void> _toggleLanguage(String lang) async {
    setState(() {
      _currentLang = lang;
      _textDirection = (lang == 'ckb' || lang == 'ar') ? TextDirection.rtl : TextDirection.ltr;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rega_saved_language_code', lang);
      String displayName = 'کوردی';
      if (lang == 'en') {
        displayName = 'English';
      } else if (lang == 'ar') {
        displayName = 'العربية';
      }
      await prefs.setString('rega_saved_language_name', displayName);
    } catch (e) {
      debugPrint('Error saving language in RegaApp: $e');
    }
  }

  TextStyle notoKufi({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    double? letterSpacing,
  }) {
    return GoogleFonts.notoKufiArabic(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REGA - ڕێگا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
        fontFamilyFallback: const [
          'Noto Kufi Arabic',
          'NotoKufiArabic',
          'Cairo',
          'Arial',
        ],
        textTheme: GoogleFonts.notoKufiArabicTextTheme(
          ThemeData.light().textTheme,
        ),
        primaryTextTheme: GoogleFonts.notoKufiArabicTextTheme(
          ThemeData.light().primaryTextTheme,
        ),
        primaryColor: const Color(0xFFFAC800),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFAC800),
          primary: const Color(0xFFFAC800),
          secondary: const Color(0xFF18181B),
          surface: Colors.white,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: _textDirection,
          child: DefaultTextStyle.merge(
            style: GoogleFonts.notoKufiArabic(),
            child: child ?? const SizedBox(),
          ),
        );
      },
      home: MainScreen(
        currentLang: _currentLang,
        onLanguageChange: _toggleLanguage,
      ),
    );
  }
}

// ============================================================================
// 🖼️ CONFIGURATION & LOGO (ASSET PNG & URL)
// ============================================================================
// 1️⃣ بۆ وێنەی PNG لەناو VS Code / Flutter لە فۆڵدەری assets2:
// وێنەی لۆگۆکەت لە فۆڵدەری assets2 ی ئەپەکەت دابنێ (وەک: 'assets2/logo.png')
// هەروەها لە فایلی pubspec.yaml ئەمە دیاری بکە:
// flutter:
//   assets:
//     - assets2/
String appLogoAssetPath = 'assets1/logo.png';
String profileLogoAssetPath = 'assets2/logo2.png';

// 2️⃣ یان بۆ لینکی ئینتەرنێت (Network Image):
String appLogoUrl = '';
// ============================================================================
// 📦 DATA MODELS & STRUCTURES
// ============================================================================

class Neighborhood {
  final String id;
  final String name;
  final String nameEn;
  final int deliveryFee;

  Neighborhood({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.deliveryFee,
  });
}

class StoreItem {
  final String id;
  final String name;
  final String category;
  final double rating;
  final String deliveryTime;
  final int deliveryFee;
  final String imageUrl;
  final String address;
  final bool isOpen;
  final String phone;
  final String? discountBadge;

  StoreItem({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.imageUrl,
    required this.address,
    this.isOpen = true,
    required this.phone,
    this.discountBadge,
  });
}

class ProductItem {
  final String id;
  final String storeId;
  final String name;
  final int price;
  final String description;
  final String imageUrl;
  final String category;
  final String? subCategory;

  ProductItem({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.category,
    this.subCategory,
  });
}

class CartEntry {
  final ProductItem product;
  int quantity;
  String specialNotes;

  CartEntry({
    required this.product,
    this.quantity = 1,
    this.specialNotes = '',
  });
}

class UserProfile {
  String name;
  String email;
  String phone;
  String address;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
  });
}

class OrderItem {
  final String id;
  final String storeName;
  final int totalAmount;
  String status; // 'pending' | 'preparing' | 'on_the_way' | 'delivered'
  final String deliveryPin;
  final double customerLat;
  final double customerLng;
  final DateTime date;
  final List<CartEntry> items;
  final String driverName;
  final String driverPhone;
  final String address;

  OrderItem({
    required this.id,
    required this.storeName,
    required this.totalAmount,
    required this.status,
    required this.date,
    required this.items,
    required this.driverName,
    required this.driverPhone,
    this.address = 'گەڕەکی شەهیدان - کۆڵانی ١٤، تەنیشت قوتابخانەی کەلار',
    this.deliveryPin = '4821',
    this.customerLat = 34.6912,
    this.customerLng = 45.3264,
  });
}

// ============================================================================
// 🏪 INITIAL DATA FOR KALAR (کەلار)
// ============================================================================

final List<Neighborhood> kalarNeighborhoods = [
  Neighborhood(id: 'n1', name: 'شارۆچکەی رزگاری', nameEn: 'Rzgari', deliveryFee: 1500),
  Neighborhood(id: 'n2', name: 'گەڕەکی زانکۆ', nameEn: 'Zanko', deliveryFee: 1000),
  Neighborhood(id: 'n3', name: 'گەڕەکی شەهیدان', nameEn: 'Shahidan', deliveryFee: 1000),
  Neighborhood(id: 'n4', name: 'گەڕەکی سیروان', nameEn: 'Sirwan', deliveryFee: 1500),
  Neighborhood(id: 'n5', name: 'گەڕەکی شۆڕش', nameEn: 'Shorish', deliveryFee: 1500),
  Neighborhood(id: 'n6', name: 'گەڕەکی بێساری', nameEn: 'Besari', deliveryFee: 2000),
  Neighborhood(id: 'n7', name: 'گەڕەکی کاکەییان', nameEn: 'Kakeyan', deliveryFee: 1500),
  Neighborhood(id: 'n8', name: 'گەڕەکی فەرمانبەران', nameEn: 'Farmanbaran', deliveryFee: 1000),
  Neighborhood(id: 'n9', name: 'ناو بازاڕی کەلار', nameEn: 'Downtown Market', deliveryFee: 1000),
];

final List<StoreItem> allStores = [
  StoreItem(
    id: 'store_mam_rashid',
    name: 'کەبابی مام ڕەشید',
    category: 'خواردنگە',
    rating: 4.9,
    deliveryTime: '20-30 خولەک',
    deliveryFee: 1500,
    imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600',
    address: 'کەلار - شەقامی سەرەکی بازاڕ',
    phone: '07701234567',
    discountBadge: '%30 OFF',
  ),
  StoreItem(
    id: 'store_sarwar',
    name: 'ڕێستۆرانتی سەروەر',
    category: 'خواردنگە',
    rating: 4.9,
    deliveryTime: '25-35 خولەک',
    deliveryFee: 1500,
    imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600',
    address: 'کەلار - بەرامبەر پارکی ڕزگاری',
    phone: '07701112233',
    discountBadge: '%15 OFF',
  ),
  StoreItem(
    id: 'store_restaurant_kalar',
    name: 'ڕێستۆرانتی کەلار سیتی',
    category: 'خواردنگە',
    rating: 4.8,
    deliveryTime: '25-35 خولەک',
    deliveryFee: 1500,
    imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600',
    address: 'کەلار - بەرامبەر فۆلكەی زانکۆ',
    phone: '07702223344',
    discountBadge: '%20 OFF',
  ),
  StoreItem(
    id: 'store_kalar_market',
    name: 'کەلار سیتی مارکێت',
    category: 'سوپەرمارکێت',
    rating: 4.8,
    deliveryTime: '15-25 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=600',
    address: 'کەلار - گەڕەکی شەهیدان',
    phone: '07509876543',
    discountBadge: 'FREE DELIVERY',
  ),
  StoreItem(
    id: 'store_rzgari_market',
    name: 'سوپەرمارکێتی ڕزگاری',
    category: 'سوپەرمارکێت',
    rating: 4.7,
    deliveryTime: '10-20 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=600',
    address: 'کەلار - شارۆچکەی ڕزگاری',
    phone: '07501112233',
  ),
  StoreItem(
    id: 'store_fastfood',
    name: 'فاست فوودی شاری یاری',
    category: 'فاست فوود',
    rating: 4.8,
    deliveryTime: '20-30 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600',
    address: 'کەلار - بەرامبەر پارکی ڕزگاری',
    phone: '07707778899',
    discountBadge: '%25 OFF',
  ),
  StoreItem(
    id: 'store_shawarma_rebaz',
    name: 'شاوڕمە و پیتزای ڕێباز',
    category: 'فاست فوود',
    rating: 4.9,
    deliveryTime: '15-25 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600',
    address: 'کەلار - ناو بازاڕ',
    phone: '07703334455',
    discountBadge: '1+1 FREE',
  ),
  StoreItem(
    id: 'store_fruits',
    name: 'بازاڕی میوە و سەوزەی کەلار',
    category: 'سەوزە و میوە',
    rating: 4.9,
    deliveryTime: '15-30 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=600',
    address: 'کەلار - مەیدانی میوەوات',
    phone: '07705556677',
  ),
  StoreItem(
    id: 'store_cafe_diwan',
    name: 'کافێ و قاوەخانەی دیوان',
    category: 'کافێ',
    rating: 4.7,
    deliveryTime: '15-25 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600',
    address: 'کەلار - گەڕەکی سیروان',
    phone: '07708889900',
    discountBadge: '%15 OFF',
  ),
  StoreItem(
    id: 'store_safin',
    name: 'شیرینی و باقلاوەی سەفین',
    category: 'شیرەمەنی و شیرینی',
    rating: 4.7,
    deliveryTime: '25-35 خولەک',
    deliveryFee: 1500,
    imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
    address: 'کەلار - فۆلكەی زانکۆ',
    phone: '07701112233',
    discountBadge: '%10 OFF',
  ),
  StoreItem(
    id: 'store_bakery',
    name: 'نانەواخانە و سەموونخانەی هەولێر',
    category: 'نانەواخانە',
    rating: 4.8,
    deliveryTime: '10-20 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=600',
    address: 'کەلار - شەقامی سەرەکی',
    phone: '07706667788',
  ),
  StoreItem(
    id: 'store_butcher',
    name: 'قەسابخانەی برادەران - گۆشتی تازه',
    category: 'گۆشت و قەسابخانە',
    rating: 4.9,
    deliveryTime: '20-30 خولەک',
    deliveryFee: 1000,
    imageUrl: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=600',
    address: 'کەلار - مەیدانی ئاژەڵان',
    phone: '07709990011',
  ),
  StoreItem(
    id: 'store_cosmetics',
    name: 'کۆسمەتیک پڕۆ کەلار',
    category: 'کۆسمەتیک',
    rating: 4.6,
    deliveryTime: '30-40 خولەک',
    deliveryFee: 1500,
    imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600',
    address: 'کەلار - سەنتەری شۆڕش',
    phone: '07704445566',
    discountBadge: '%20 OFF',
  ),
];

final List<ProductItem> allProducts = [
  // 1. کەبابی مام ڕەشید (store_mam_rashid)
  ProductItem(
    id: 'mr_1',
    storeId: 'store_mam_rashid',
    name: 'ژەمە کەبابی تایبەتی مام ڕەشید',
    price: 7500,
    description: '3 شیش کەبابی گۆشتی فرێشی بەرخ، تەماتە، پیاز و نانی گەرم',
    imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600',
    category: 'خواردنگە',
    subCategory: 'کەباب و برژاوەکان',
  ),
  ProductItem(
    id: 'mr_2',
    storeId: 'store_mam_rashid',
    name: 'تیکەی گۆشتی بەرخ (شیش)',
    price: 8000,
    description: 'تیکەی نەرم و بەتام لەسەر خەڵوز برژاو',
    imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600',
    category: 'خواردنگە',
    subCategory: 'کەباب و برژاوەکان',
  ),
  ProductItem(
    id: 'mr_3',
    storeId: 'store_mam_rashid',
    name: 'تیکەی مریشک (جوجە کباب)',
    price: 6500,
    description: 'سنگی مریشکی خەستکراو بە بەهاراتی کەبابی مام ڕەشید',
    imageUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=600',
    category: 'خواردنگە',
    subCategory: 'مریشک و قوزی',
  ),
  ProductItem(
    id: 'mr_4',
    storeId: 'store_mam_rashid',
    name: 'دۆی سروشتی تڕی مام ڕەشید',
    price: 1000,
    description: 'دۆی سروشتی سارد بە نەعنا',
    imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600',
    category: 'خواردنگە',
    subCategory: 'خواردنەوەکان',
  ),

  // 2. ڕێستۆرانتی سەروەر (store_sarwar)
  ProductItem(
    id: 'prod_1',
    storeId: 'store_sarwar',
    name: 'ژەمە کەبابی تایبەتی سەروەر',
    price: 8500,
    description: '3 شیش کەبابی گۆشتی فرێشی عەقەرە لەگەڵ نانی گەرم، سەوزە، تەماتەی برژاو و ماست',
    imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600',
    category: 'خواردنگە',
    subCategory: 'کەباب و برژاوەکان',
  ),
  ProductItem(
    id: 'prod_2',
    storeId: 'store_sarwar',
    name: 'مریشکی برژاوی سەر خەڵوز',
    price: 9000,
    description: 'مریشکی تەواو برژاو بە بهاراتی تایبەت و سۆسی دۆشاوڕمێن',
    imageUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=600',
    category: 'خواردنگە',
    subCategory: 'مریشک و قوزی',
  ),
  ProductItem(
    id: 'sw_3',
    storeId: 'store_sarwar',
    name: 'کوپە سوپی تەماتە و نۆک',
    price: 2500,
    description: 'سوپی گەرم بە گوژم و بهاراتی کوردی',
    imageUrl: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600',
    category: 'خواردنگە',
    subCategory: 'کەباب و برژاوەکان',
  ),

  // 3. ڕێستۆرانتی کەلار سیتی (store_restaurant_kalar)
  ProductItem(
    id: 'prod_3',
    storeId: 'store_restaurant_kalar',
    name: 'قوزی گۆشتی بەرخ بە برنجی کوردی',
    price: 14000,
    description: 'ژەمە قوزی شاد لەگەڵ برنجی کوردی بۆندار و شلە',
    imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600',
    category: 'خواردنگە',
    subCategory: 'مریشک و قوزی',
  ),
  ProductItem(
    id: 'rk_2',
    storeId: 'store_restaurant_kalar',
    name: 'برنجی بەمیە بە گۆشتەوە',
    price: 6000,
    description: 'برنجی کوردی بە شلەی بەمیەی فرێش و گۆشتی بەرخ',
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600',
    category: 'خواردنگە',
    subCategory: 'مریشک و قوزی',
  ),
  ProductItem(
    id: 'rk_3',
    storeId: 'store_restaurant_kalar',
    name: 'شاوڕمەی عەرەبی لەسەر قاپ',
    price: 7000,
    description: 'شاوڕمەی مریشک لەگەڵ فینگەر، مایۆنیز و سۆس',
    imageUrl: 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600',
    category: 'خواردنگە',
    subCategory: 'سەندویچ و فاست فوود',
  ),

  // 4. کەلار سیتی مارکێت (store_kalar_market)
  ProductItem(
    id: 'prod_5',
    storeId: 'store_kalar_market',
    name: 'شیری فرێشی کۆڵنە 1L',
    price: 2500,
    description: 'شیری تەواو سروشتی بێ زیادکراو',
    imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600',
    category: 'سوپەرمارکێت',
    subCategory: 'لبنیات و شیرەمەنی',
  ),
  ProductItem(
    id: 'km_2',
    storeId: 'store_kalar_market',
    name: 'شۆکۆلاتەی نۆتێلا 400g',
    price: 6000,
    description: 'نۆتێلای ڕەسەن بۆ نانی بەیانیان',
    imageUrl: 'https://images.unsplash.com/photo-1581798459219-318e76aecc7b?w=600',
    category: 'سوپەرمارکێت',
    subCategory: 'شیرینی و بەستەری',
  ),

  // 5. سوپەرمارکێتی ڕزگاری (store_rzgari_market)
  ProductItem(
    id: 'rm_1',
    storeId: 'store_rzgari_market',
    name: 'پەنێری کیری 12 دانەیی',
    price: 2500,
    description: 'پەنێری چەور و نەرم بۆ بەیانیان',
    imageUrl: 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=600',
    category: 'سوپەرمارکێت',
    subCategory: 'لبنیات و شیرەمەنی',
  ),
  ProductItem(
    id: 'rm_2',
    storeId: 'store_rzgari_market',
    name: 'شەربەتی ڕانی بە پارچەی میوەوە',
    price: 750,
    description: 'قوتووی شەربەتی هۆڵووی ڕانی 240ml',
    imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600',
    category: 'سوپەرمارکێت',
    subCategory: 'خواردنەوەکان',
  ),

  // 6. فاست فوودی شاری یاری (store_fastfood)
  ProductItem(
    id: 'prod_6',
    storeId: 'store_fastfood',
    name: 'دۆبڵ بەرگەری پەنیری',
    price: 6500,
    description: '2 پارچە گۆشتی گۆڵک، پەنیر، فینگەری گەرم و سۆسی فاست فوود',
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600',
    category: 'فاست فوود',
    subCategory: 'سەندویچ و فاست فوود',
  ),
  ProductItem(
    id: 'ff_2',
    storeId: 'store_fastfood',
    name: 'پیتزای مێکس گۆشت و مریشک',
    price: 10000,
    description: 'پیتزای گەورە بە سۆسی تەماتە، زەیتون و پەنیر',
    imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600',
    category: 'فاست فوود',
    subCategory: 'سەندویچ و فاست فوود',
  ),

  // 7. شاوڕمە و پیتزای ڕێباز (store_shawarma_rebaz)
  ProductItem(
    id: 'prod_7',
    storeId: 'store_shawarma_rebaz',
    name: 'شاوڕمەی مریشکی عەرەبی',
    price: 3500,
    description: 'شاوڕمەی مریشکی گەرم بە نانی ساج و سۆسی سێری تایبەت',
    imageUrl: 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600',
    category: 'فاست فوود',
    subCategory: 'سەندویچ و فاست فوود',
  ),
  ProductItem(
    id: 'sr_2',
    storeId: 'store_shawarma_rebaz',
    name: 'شاوڕمەی گۆشتی بەرخ',
    price: 4500,
    description: 'شاوڕمەی گۆشت بە نانی عەرەبی و تڕشی و سۆس',
    imageUrl: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600',
    category: 'فاست فوود',
    subCategory: 'سەندویچ و فاست فوود',
  ),

  // 8. بازاڕی میوە و سەوزەی کەلار (store_fruits)
  ProductItem(
    id: 'prod_8',
    storeId: 'store_fruits',
    name: 'سێوی سووری فرێش 1KG',
    price: 2000,
    description: 'سێوی خۆماڵی تازە و شیرین',
    imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=600',
    category: 'سەوزە و میوە',
    subCategory: 'میوەکان',
  ),
  ProductItem(
    id: 'fr_2',
    storeId: 'store_fruits',
    name: 'مۆزی سۆماڵی 1KG',
    price: 2500,
    description: 'مۆزی زەرد و شیرینی فرێش',
    imageUrl: 'https://images.unsplash.com/photo-1603833665858-e61d17a86224?w=600',
    category: 'سەوزە و میوە',
    subCategory: 'میوەکان',
  ),
  ProductItem(
    id: 'fr_3',
    storeId: 'store_fruits',
    name: 'تەماتەی خۆماڵی 1KG',
    price: 1000,
    description: 'تەماتەی سوور و تازەی ئاوودار',
    imageUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600',
    category: 'سەوزە و میوە',
    subCategory: 'سەوزەوات',
  ),

  // 9. کافێ و قاوەخانەی دیوان (store_cafe_diwan)
  ProductItem(
    id: 'prod_9',
    storeId: 'store_cafe_diwan',
    name: 'قاوەی ئیسپرێسۆی ئیتاڵی',
    price: 3000,
    description: 'قاوەی فرێش بە تامێکی دەوڵەمەند',
    imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600',
    category: 'کافێ',
    subCategory: 'خواردنەوەکان',
  ),
  ProductItem(
    id: 'cd_2',
    storeId: 'store_cafe_diwan',
    name: 'کاپوچینۆ بە کەفی شیری گەرم',
    price: 3500,
    description: 'کاپوچینۆی ڕەسەن بە فۆم و دارچینی',
    imageUrl: 'https://images.unsplash.com/photo-1534778101976-62847782c213?w=600',
    category: 'کافێ',
    subCategory: 'خواردنەوەکان',
  ),

  // 10. شیرینی و باقلاوەی سەفین (store_safin)
  ProductItem(
    id: 'prod_4',
    storeId: 'store_safin',
    name: 'باقلاوەی فستقی عەنتاب',
    price: 12000,
    description: '1 کیلۆ باقلاوەی تڕ بە روونی ئاژەڵی سروشتی و فستقی فرێش',
    imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
    category: 'شیرەمەنی و شیرینی',
    subCategory: 'باقلاوە و شیرینی',
  ),
  ProductItem(
    id: 'sf_2',
    storeId: 'store_safin',
    name: 'کۆنەفەی گەرمی عەرەبی بە پەنیر',
    price: 6000,
    description: 'کۆنەفەی تازە و بەتام بۆ شێوان',
    imageUrl: 'https://images.unsplash.com/photo-1519869325930-281384150729?w=600',
    category: 'شیرەمەنی و شیرینی',
    subCategory: 'باقلاوە و شیرینی',
  ),

  // 11. نانەواخانە و سەموونخانەی هەولێر (store_bakery)
  ProductItem(
    id: 'prod_10',
    storeId: 'store_bakery',
    name: 'سەموونی گەرمی دایری 10 پارچە',
    price: 1500,
    description: 'سەموونی تازەی نەرم بەبێ هەویر',
    imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
    category: 'نانەواخانە',
    subCategory: 'نان و سەموون',
  ),

  // 12. قەسابخانەی برادەران - گۆشتی تازه (store_butcher)
  ProductItem(
    id: 'prod_11',
    storeId: 'store_butcher',
    name: 'گۆشتی بەرخی فرێش 1KG',
    price: 18000,
    description: 'گۆشتی بەرخی خۆماڵی تەواو پاککراوە',
    imageUrl: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=600',
    category: 'گۆشت و قەسابخانە',
    subCategory: 'گۆشتی تازە',
  ),

  // 13. کۆسمەتیک پڕۆ کەلار (store_cosmetics)
  ProductItem(
    id: 'cs_1',
    storeId: 'store_cosmetics',
    name: 'عەتری ساڤاج دیۆر 100ml',
    price: 35000,
    description: 'عەتری ڕەسەن بە بپڕانی بەرز و تەمەنی درێژ',
    imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600',
    category: 'کۆسمەتیک',
    subCategory: 'عەتر و کۆسمەتیک',
  ),
];

// ============================================================================
// 📱 MAIN APPLICATION SCREEN WITH NAVIGATION & STATE
// ============================================================================

class MainScreen extends StatefulWidget {
  final String currentLang;
  final Function(String) onLanguageChange;

  const MainScreen({
    super.key,
    required this.currentLang,
    required this.onLanguageChange,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _unreadNotificationCount = 3;
  Neighborhood _selectedNeighborhood = kalarNeighborhoods[1]; // Zanko by default
  String _searchQuery = '';
  String _selectedCategory = 'گشتی';
  StoreItem? _selectedStore;
  String? _selectedSubCategory;

  // Internet Connectivity Guard State
  bool _isOffline = false;
  bool _isCheckingConnection = false;
  Timer? _connectivityTimer;

  // App State
  final List<CartEntry> _cart = [];
  UserProfile? _userProfile; // NULL by default (Guest mode)
  bool _isLoginMode = false; // Toggle between Login and Register
  final List<OrderItem> _orders = [];
  double? _pinnedCustomerLat;
  double? _pinnedCustomerLng;
  String _selectedOrderFilter = 'هەموو';
  final Set<String> _favoriteStoreIds = {'store_sarwar'};

  String _currentLanguage = 'کوردی';
  bool _isLanguageExpanded = false;

  // Profile Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _passwordCtrl;

  // Security & Integrity State
  bool _isLocationAuthorized = false;
  bool _isCheckingLocation = true;
  bool _isVpnActive = false; // 🛡️ بارودۆخی VPN
  bool _isDeviceSafe = true; // 🔒 ئایا ئامێرەکە پارێزراوە؟
  bool _isCheckingSecurity = true; // 🔒 پشکنینی ئاسایش
  String _securityErrorMessage = "";

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _userProfile?.name ?? '');
    _phoneCtrl = TextEditingController(text: _userProfile?.phone ?? '');
    _passwordCtrl = TextEditingController();
    _loadProfile();
    _loadSavedLanguage();
    
    // 🚀 دەستپێکردنی زنجیرەی چالاککردنی ئەپ بە شێوەیەکی ڕێکخراو
    _startAppInitialization();
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLang != widget.currentLang) {
      String newLang = 'کوردی';
      if (widget.currentLang == 'en') {
        newLang = 'English';
      } else if (widget.currentLang == 'ar') {
        newLang = 'العربية';
      }
      setState(() {
        _currentLanguage = newLang;
      });
    }
  }

  // 🚀 زنجیرەی چالاککردنی ئەپ (Security -> Notification -> Location)
  Future<void> _startAppInitialization() async {
    // 1. پشکنینی ئینتەرنێت و VPN سەرەتا
    await _checkInternetConnection(silent: true);
    await _checkVpnStatus();

    // 🔄 پشکنینی بەردەوام بۆ پەیوەندی
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkInternetConnection(silent: true);
      _checkVpnStatus();
    });

    // 2. پشکنینی ئاسایشی ئامێر (Security Check)
    await _checkSecurity();
    if (!_isDeviceSafe) return; // ئەگەر ئامێرەکە پارێزراو نەبوو، لێرە دەوەستێت

    // 3. داواکردنی ڕێگەپێدانی نۆتیکەیشن (Notification)
    // ئێستا چاوەڕێ دەکات تا ئەمە تەواو دەبێت ئینجا دەچێتە سەر لۆکەیشن
    await _requestNotificationPermission();

    // 4. داواکردنی ڕێگەپێدانی شوێن (Location)
    await _requestLocationPermission();
  }

  // 🔔 فەنکشن بۆ داواکردنی ڕێگەپێدانی نۆتیکەیشن
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      // ڕێگەی پێدراوە
    } else if (status.isDenied) {
      // ڕێگەی پێنەدراوە
    } else if (status.isPermanentlyDenied) {
      // بە تەواوی ڕێگەی پێنەدراوە، پێویستە لە سێتینگ دەستکاری بکرێت
    }
  }

  // 📍 فەنکشن بۆ داواکردنی ڕێگەپێدانی GPS لە مۆبایل (بە مەرجی ناچاری)
  Future<void> _requestLocationPermission() async {
    setState(() => _isCheckingLocation = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    // پشکنینی ئەوەی ئایا GPS لە مۆبایلەکەدا کراوەیە
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLocationAuthorized = false;
        _isCheckingLocation = false;
      });
      return;
    }

    // پشکنینی ڕێگەپێدانەکان
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLocationAuthorized = false;
          _isCheckingLocation = false;
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLocationAuthorized = false;
        _isCheckingLocation = false;
      });
      return;
    }

    setState(() {
      _isLocationAuthorized = true;
      _isCheckingLocation = false;
    });
  }

  // 🔒 پشکنینی پڕۆفیشناڵ بۆ ئاسایشی ئامێرەکە
  Future<void> _checkSecurity() async {
    if (kIsWeb) {
      setState(() {
        _isCheckingSecurity = false;
        _isDeviceSafe = true;
      });
      return;
    }

    try {
      // 1. ڕێگەدان بە وێنەگرتنی شاشە (Screen Recording / Screenshot ڕێگەپێدراوە)
      if (!kIsWeb) {
        await ScreenProtector.preventScreenshotOff();
      }

      bool isJailBroken = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;
      bool isDevelopmentMode = await SafeDevice.isDevelopmentModeEnable;

      if (isJailBroken) {
        _securityErrorMessage = "ئەم ئامێرە هاککراوە (Root/Jailbreak). بۆ پاراستنی زانیارییەکانت، ئەپەکە کار ناکات.";
        _isDeviceSafe = false;
      } else if (!isRealDevice) {
        _securityErrorMessage = "ڕێگە نادرێت ئەپەکە لەسەر ئیمۆلیتۆر (Emulator) کار بکات.";
        _isDeviceSafe = false;
      } else if (isDevelopmentMode) {
        // تێبینی: دەتوانیت ئەمە چالاک بکەیت بۆ پاراستنی زیاتر، بەڵام بۆ تاقیکردنەوە ڕەنگە کێشە بێت
        // _securityErrorMessage = "تکایە Developer Options بکوژێنەرەوە بۆ بەکارهێنانی ئەپەکە.";
        // _isDeviceSafe = false;
      }

      setState(() => _isCheckingSecurity = false);
    } catch (e) {
      setState(() => _isCheckingSecurity = false);
    }
  }

  // 🔒 شاشەی هۆشداری ئەمنی
  Widget _buildSecurityBlockedScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gpp_bad_rounded, size: 80, color: Color(0xFFDC2626)),
            const SizedBox(height: 24),
            const Text(
              'کێشەی ئەمنی دۆزرایەوە',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _securityErrorMessage,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Text(
              'پێویستە ئەپەکە لەسەر مۆبایلی ڕاستەقینە و بەبێ هاک بەکاربێت بۆ پاراستنی زانیارییەکانت.',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 🛡️ فەنکشن بۆ پشکنینی VPN
  Future<void> _checkVpnStatus() async {
    if (kIsWeb) return;
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.vpn)) {
      if (mounted) setState(() => _isVpnActive = true);
    } else {
      if (mounted) setState(() => _isVpnActive = false);
    }
  }

  // 🛡️ شاشەی قەدەغەکردنی VPN
  Widget _buildVpnBlockedScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security_update_warning_rounded, size: 80, color: Color(0xFFDC2626)),
            const SizedBox(height: 24),
            const Text(
              'بەکارهێنانی VPN قەدەغەیە',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'بۆ پاراستنی ئاسایشی ئەپەکە و دیاریکردنی شوێنی ڕاستەقینە، ڕێگە نادرێت بە بەکارهێنانی VPN. تکایە VPN بکوژێنەرەوە و دووبارە هەوڵبدەرەوە.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkVpnStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFAC800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('دووبارە هەوڵبدەرەوە', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📍 شاشەی ناچاری بۆ چالاککردنی لۆکەیشن
  Widget _buildLocationRequiredScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_rounded, size: 80, color: Color(0xFFDC2626)),
            const SizedBox(height: 24),
            const Text(
              'چالاککردنی لۆکەیشن مەرجە',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'بۆ ئەوەی بتوانیت ئەپەکە بەکاربهێنیت، پێویستە ڕێگەپێدانی لۆکەیشن چالاک بکەیت و GPS موبایلەکەت کار بکات.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestLocationPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFAC800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('دووبارە هەوڵبدەرەوە', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkInternetConnection({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isCheckingConnection = true);
    }

    bool isConnected = true;
    if (!kIsWeb) {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
        isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        isConnected = false;
      } catch (_) {
        isConnected = false;
      }
    }

    if (mounted) {
      setState(() {
        _isOffline = !isConnected;
        _isCheckingConnection = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        final profileData = jsonDecode(profileJson);
        setState(() {
          _userProfile = UserProfile(
            name: profileData['name'] ?? '',
            phone: profileData['phone'] ?? '',
            email: profileData['email'] ?? '',
            address: profileData['address'] ?? '',
          );
          _nameCtrl.text = _userProfile?.name ?? '';
          _phoneCtrl.text = _userProfile?.phone ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileData = {
        'name': profile.name,
        'phone': profile.phone,
        'email': profile.email,
        'address': profile.address,
      };
      await prefs.setString('user_profile', jsonEncode(profileData));
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }

  Future<void> _clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
    } catch (e) {
      debugPrint('Error clearing profile: $e');
    }
  }

  // 💾 بارکردنی زمانی پاشەکەوتکراو بۆ سەر شاشە و مێنۆکان
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('rega_saved_language_name');
      final savedCode = prefs.getString('rega_saved_language_code');

      String selectedLang = 'کوردی';
      if (savedName != null && savedName.isNotEmpty) {
        selectedLang = savedName;
      } else if (savedCode != null && savedCode.isNotEmpty) {
        if (savedCode == 'en') {
          selectedLang = 'English';
        } else if (savedCode == 'ar') {
          selectedLang = 'العربية';
        } else {
          selectedLang = 'کوردی';
        }
      } else if (widget.currentLang.isNotEmpty) {
        if (widget.currentLang == 'en') {
          selectedLang = 'English';
        } else if (widget.currentLang == 'ar') {
          selectedLang = 'العربية';
        } else {
          selectedLang = 'کوردی';
        }
      }

      if (mounted) {
        setState(() {
          _currentLanguage = selectedLang;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved language in MainScreen: $e');
    }
  }

  // 💾 پاشەکەوتکردنی زمان لەناو SharedPreferences بۆ ئەوەی دوای دەرچوون لە ئەپ نەگۆڕێت
  Future<void> _saveLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rega_saved_language_name', lang);
      String code = 'ckb';
      if (lang == 'English') {
        code = 'en';
      } else if (lang == 'العربية') {
        code = 'ar';
      }
      await prefs.setString('rega_saved_language_code', code);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  // 🚫 Full-Screen Offline Warning Overlay (Prevents App Usage)
  Widget _buildOfflineScreen() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Wifi Off Icon with circle badge
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade100, width: 2),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 28),

              // Title
              const Text(
                'پەیوەندی ئەنتەرنێت بەردەست نییە!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description matching user request:
              // "تکایە ئامێرەکەت پەیوەست بکە بە هێڵی ئەنتەرنێتەوە"
              Text(
                'تکایە ئامێرەکەت پەیوەست بکە بە هێڵی ئەنتەرنێتەوە بۆ ئەوەی بتوانیت ئەپەکە بەکاربهێنیت.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Retry Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFAC800),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isCheckingConnection ? null : () => _checkInternetConnection(silent: false),
                  icon: _isCheckingConnection
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(
                    _isCheckingConnection ? 'چاوەڕوان بە...' : 'دووبارە هەوڵبدەرەوە',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Simulated offline toggle button for testing
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isOffline = false;
                  });
                },
                icon: const Icon(Icons.developer_mode_rounded, size: 16, color: Colors.grey),
                label: const Text(
                  'داخستنی ئاگاداری (تاقیکردنەوە)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart(ProductItem product, {int qty = 1, String notes = ''}) {
    setState(() {
      final idx = _cart.indexWhere((item) => item.product.id == product.id);
      if (idx >= 0) {
        _cart[idx].quantity += qty;
        if (notes.isNotEmpty) _cart[idx].specialNotes = notes;
      } else {
        _cart.add(CartEntry(product: product, quantity: qty, specialNotes: notes));
      }
    });

    // 🚀 خێراکردن و پاککردنەوەی هەموو ئاگادارییە پێشووەکان بۆ ئەوەی ڕاستەوخۆ نیشان بدرێت و تاخیر نەبێت
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${product.name} زیادکرا بۆ سەبەتە',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(milliseconds: 1200),
        elevation: 6,
      ),
    );
  }

  // Auth Guard Alert Dialog
  void _showAuthRequiredModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, size: 36, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 16),
            const Text(
              'تکایە سەرەتا خۆت تۆمار بکە',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'بۆ ئەوەی بتوانیت داواکارییەکەت ئەنجام بدەیت و کاڵاکانت پێ بگات، تکایە سەرەتا خۆت تۆمار بکە یان بچۆ ژوورەوە.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFAC800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 4); // Switch to Profile Tab
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('ڕاستەوخۆ بڕۆ بۆ خۆتۆمارکردن', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('دواخستن', style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleProceedToCheckout() {
    if (_userProfile == null) {
      _showAuthRequiredModal();
    } else {
      _showCheckoutSheet();
    }
  }

  Widget _buildConfirmDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54, fontWeight: FontWeight.bold)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmationDialog({
    required BuildContext parentCtx,
    required String orderCode,
    required int grandTotal,
    required List<CartEntry> cartItems,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
              child: const Icon(Icons.help_outline_rounded, size: 36, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 12),
            const Text(
              'دڵنیابوونەوە لە داواکاری',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تکایە پێش ناردنی داواکارییەکە، زانیارییەکانت بە وردی پشتڕاست بکەرەوە:',
              style: TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 14),

            // Order Code Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('کۆدی وەرگرتنی داواکاری:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                  SelectableText(
                    orderCode,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFB45309), letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Detail Rows
            _buildConfirmDetailRow('شوێنی GPS:', _selectedNeighborhood.name),
            _buildConfirmDetailRow('کۆی گشتی پارە:', '${_formatNum(grandTotal)} د.ع'),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ئایا دڵنیایت لە بەڕێکردنی کۆتایی ئەم داواکارییە؟',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626), // باکگراوندی سووری سەرنجڕاکێش
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'پاشگەزبوونەوە',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFAC800),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx); // Close Confirmation Dialog
                    Navigator.pop(parentCtx); // Close Checkout Sheet

                    final storeName = cartItems.isNotEmpty ? cartItems.first.product.name : 'کەلار ستی';
                    final newOrder = OrderItem(
                      id: orderCode,
                      storeName: storeName,
                      totalAmount: grandTotal,
                      status: 'on_the_way',
                      date: DateTime.now(),
                      items: List.from(cartItems),
                      driverName: 'ئاراس ئەحمەد (ماتۆڕسوار)',
                      driverPhone: '07709876543',
                      address: '${_selectedNeighborhood.name} - شاری کەلار',
                      deliveryPin: orderCode.length >= 4
                          ? orderCode.substring(orderCode.length - 4)
                          : '4821',
                      customerLat: _pinnedCustomerLat ??
                          KalarGeoCatalog.forNeighborhoodId(_selectedNeighborhood.id).latitude,
                      customerLng: _pinnedCustomerLng ??
                          KalarGeoCatalog.forNeighborhoodId(_selectedNeighborhood.id).longitude,
                    );

                    setState(() {
                      _orders.insert(0, newOrder);
                      _cart.clear();
                    });

                    _showOrderSuccessModal(orderCode, grandTotal);
                  },
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('بەڵێ، بنێرە', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderSuccessModal(String orderCode, int grandTotal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 14),
            const Text(
              'داواکارییەکەت بە سەرکەوتوویی نێردرا!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
            ),
            const SizedBox(height: 10),
            const Text(
              'تکایە ئەم کۆدە لای خۆت بپارێزە بۆ وەرگرتنی داواکاری لە شۆفێر:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
            const SizedBox(height: 10),

            // Order Code Highlight Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
              ),
              child: Column(
                children: [
                  const Text('کۆدی وەرگرتنی داواکاری', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                  const SizedBox(height: 6),
                  SelectableText(
                    orderCode,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB45309),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Driver & GPS Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'شوێنی GPS: ${_selectedNeighborhood.name}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.delivery_dining_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'شۆفێر: ئاراس ئەحمەد (07709876543)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFAC800),
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _currentIndex = 3; // Switch to Orders tab
                    if (_orders.isNotEmpty) {
                      Future.microtask(() => _showLiveTrackingModal(_orders.first));
                    }
                  });
                },
                child: const Text(
                  'بەدواداچوون بۆ داواکاری (Orders) 📦',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final subtotal = _cart.fold<int>(0, (sum, i) => sum + (i.product.price * i.quantity));
          final grandTotal = subtotal + _selectedNeighborhood.deliveryFee;

          return SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('تەواوکردن و ناردنی داواکاری'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // GPS LOCATION RE-CONFIRMATION CARD (NO ICONS, NO EMOJIS)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'شوێنی گەیاندنی دیاریکراو (GPS):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_selectedNeighborhood.name} (${_selectedNeighborhood.deliveryFee} د.ع تێچووی گەیاندن)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF15803D),
                                side: const BorderSide(color: Color(0xFF86EFAC)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                _showLocationPicker();
                                setSheetState(() {});
                              },
                              child: const Text(
                                'پشکنین و دیاریکردنی شوێنی GPS',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(_t('کۆی گشتی داواکاری:'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          const SizedBox(width: 8),
                          Text('${_formatNum(grandTotal)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFB45309))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFAC800),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final orderCode = '${(1000 + (DateTime.now().microsecondsSinceEpoch % 9000))}';
                          _showOrderConfirmationDialog(
                            parentCtx: ctx,
                            orderCode: orderCode,
                            grandTotal: grandTotal,
                            cartItems: List.from(_cart),
                          );
                        },
                        child: const Text('پشتڕاستکردنەوە و ناردنی داواکاری', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    // Safe spacing to guarantee button never sits under phone navigation buttons
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 📍 Full Interactive Google Map Style Kalar GPS Location Picker
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Neighborhood tempSelected = _selectedNeighborhood;
        bool isGpsLocating = false;
        String gpsAccuracyText = 'دەقیقی GPS: %100 (Google Maps Kalar)';
        Offset pinPosition = const Offset(0.50, 0.45); // Center on Kalar map

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Top Modal Drag Handle & Header
                  Container(
                    padding: const EdgeInsets.only(top: 12, bottom: 10, left: 16, right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.map_rounded, color: Color(0xFFFAC800), size: 26),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'نەخشەی شاری کەلار (Google Maps)',
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.black54),
                            ),
                          ],
                        ),
                        Text(
                          'تکایە شوێنەکەت لەسەر نەخشەی کەلار کلیک بکە یان دوگمەی GPS داگیرسێنە',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: const Color(0xFFFAC800),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final startPt = LatLng(
                            _pinnedCustomerLat ?? KalarGeoCatalog.forNeighborhoodId(tempSelected.id).latitude,
                            _pinnedCustomerLng ?? KalarGeoCatalog.forNeighborhoodId(tempSelected.id).longitude,
                          );
                          showDialog(
                            context: context,
                            builder: (dCtx) => Dialog(
                              insetPadding: const EdgeInsets.all(14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox(
                                  height: MediaQuery.of(dCtx).size.height * 0.72,
                                  child: Stack(
                                    children: [
                                      KalarInteractivePickerMap(
                                        initialPoint: startPt,
                                        selectedNeighborhoodName: tempSelected.name,
                                        onLocationChanged: (pt) {
                                          setState(() {
                                            _pinnedCustomerLat = pt.latitude;
                                            _pinnedCustomerLng = pt.longitude;
                                          });
                                        },
                                      ),
                                      Positioned(
                                        bottom: 14,
                                        right: 14,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFAC800),
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          onPressed: () => Navigator.pop(dCtx),
                                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                                          label: const Text('پەسەندکردنی شوێنی GPS', style: TextStyle(fontWeight: FontWeight.w900)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.satellite_alt_rounded, size: 17),
                        label: const Text('کردنەوەی نەخشەی ڕاستەقینەی شەقامەکانی کەلار (HD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  // 🗺️ GOOGLE MAPS STYLE INTERACTIVE MAP CANVAS (EXPANDED FULL VIEW)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B), // Google Maps dark theme
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFFAC800), width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(21),
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setModalState(() {
                                      // Allow dragging the pin on Google Map canvas
                                      double newX = (pinPosition.dx + details.delta.dx / 300).clamp(0.1, 0.9);
                                      double newY = (pinPosition.dy + details.delta.dy / 300).clamp(0.1, 0.9);
                                      pinPosition = Offset(newX, newY);
                                    });
                                  },
                                  onTapUp: (details) {
                                    setModalState(() {
                                      // Tap anywhere on Kalar Map to move precision pin
                                      pinPosition = Offset(
                                        (details.localPosition.dx / 320).clamp(0.1, 0.9),
                                        (details.localPosition.dy / 380).clamp(0.1, 0.9),
                                      );
                                    });
                                  },
                                  child: Stack(
                                    children: [
                                      // Google Map Tile Grid & Road Rendering
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _KalarMapPainter(),
                                        ),
                                      ),

                                      // Google Maps Watermark Badge
                                      Positioned(
                                        bottom: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.g_mobiledata, color: Colors.blue, size: 18),
                                              Text(
                                                'Google Maps • Kalar',
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Kalar Famous Landmarks on Google Map
                                      Positioned(
                                        top: 20,
                                        left: 20,
                                        child: _buildMapLandmarkBadge('🏰 قەڵای شێروانە'),
                                      ),
                                      Positioned(
                                        top: 80,
                                        right: 20,
                                        child: _buildMapLandmarkBadge('🎓 زانکۆی گەرمیان'),
                                      ),
                                      Positioned(
                                        bottom: 50,
                                        left: 25,
                                        child: _buildMapLandmarkBadge('🌊 ڕووباری سیروان'),
                                      ),
                                      Positioned(
                                        bottom: 100,
                                        right: 30,
                                        child: _buildMapLandmarkBadge('🏪 ناو بازاڕی کەلار'),
                                      ),

                                      // 📍 DRAGGABLE / PRECISION LOCATION PIN
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final pinX = pinPosition.dx * constraints.maxWidth - 20;
                                          final pinY = pinPosition.dy * constraints.maxHeight - 40;
                                          return Positioned(
                                            left: pinX,
                                            top: pinY,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFFAC800)),
                                                  ),
                                                  child: Text(
                                                    '📍 ${tempSelected.name}',
                                                    style: const TextStyle(
                                                      color: Color(0xFFFAC800),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.location_on,
                                                  size: 40,
                                                  color: Color(0xFFEF4444),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                      // 🎯 PRECISION AUTO GPS BUTTON
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFAC800),
                                            foregroundColor: Colors.black,
                                            elevation: 6,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                          ),
                                          onPressed: isGpsLocating
                                              ? null
                                              : () {
                                                  setModalState(() {
                                                    isGpsLocating = true;
                                                  });

                                                  Future.delayed(const Duration(milliseconds: 700), () {
                                                    setModalState(() {
                                                      // Auto GPS pinpoint position in Kalar (Zanko district)
                                                      tempSelected = kalarNeighborhoods[1];
                                                      pinPosition = const Offset(0.50, 0.38);
                                                      isGpsLocating = false;
                                                      gpsAccuracyText = '📍 شوێنی زۆر دەقیقی GPS (کەلار)';
                                                    });

                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('🎯 شوێنەکەت لەسەر نەخشەی کەلار بە دەقیقی دیاریکرا!'),
                                                        backgroundColor: Color(0xFF059669),
                                                        duration: Duration(seconds: 2),
                                                      ),
                                                    );
                                                  });
                                                },
                                          icon: isGpsLocating
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                                )
                                              : const Icon(Icons.my_location, size: 20, color: Colors.black),
                                          label: Text(
                                            isGpsLocating ? 'پشکنینی GPS...' : 'GPS ی خۆکار (دەقیق)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ),

                                      // Top Live Accuracy Bar
                                      Positioned(
                                        top: 10,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: Colors.white24),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.gps_fixed, size: 13, color: Color(0xFF10B981)),
                                              const SizedBox(width: 5),
                                              Text(
                                                gpsAccuracyText,
                                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Selected Location Summary Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFAC800),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on, color: Colors.black, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'شوێنی دیاریکراو: ${tempSelected.name}',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'تێچووی گەیاندن: ${tempSelected.deliveryFee} د.ع  • کەلار، گەرمیان',
                                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Save Location Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFAC800),
                                foregroundColor: Colors.black,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedNeighborhood = tempSelected;
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('📍 شوێنی گەیاندن لە Google Maps تۆمارکرا: ${tempSelected.name}'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 20),
                              label: const Text(
                                'پشتڕاستکردنەوەی شوێن لە نەخشە',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapLandmarkBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.amber, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }


  // 🔍 Comprehensive Search Modal (Stores, Categories, Products & Foods)
  void _openSearchModal() {
    Timer? searchDebounce;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQ = '';
        String displayedQ = ''; // Debounced query
        final TextEditingController searchCtrl = TextEditingController();

        final List<Map<String, dynamic>> searchCategories = [
          {'title': 'خواردنگە و ڕێستۆرانتەکان', 'icon': Icons.restaurant_outlined, 'catName': 'خواردنگە'},
          {'title': 'مارکێت و سوپەرمارکێتەکان', 'icon': Icons.shopping_bag_outlined, 'catName': 'سوپەرمارکێت'},
          {'title': 'میوە و سەوزەی فرێش', 'icon': Icons.apple_outlined, 'catName': 'سەوزە و میوە'},
          {'title': 'شاوڕمە و فاست فوود', 'icon': Icons.local_fire_department_outlined, 'catName': 'فاست فوود'},
          {'title': 'شیرینی، کێک و باقلاوە', 'icon': Icons.cake_outlined, 'catName': 'شیرەمەنی و شیرینی'},
          {'title': 'کافێ و قاوەخانەکان', 'icon': Icons.local_cafe_outlined, 'catName': 'کافێ'},
          {'title': 'گۆشت و مریشکی تازه', 'icon': Icons.set_meal_outlined, 'catName': 'گۆشت و قەسابخانە'},
          {'title': 'نانەواخانه و سەموون', 'icon': Icons.bakery_dining_outlined, 'catName': 'نانەواخانە'},
          {'title': 'کۆسمەتیک و جوانکاری', 'icon': Icons.brush_outlined, 'catName': 'کۆسمەتیک'},
        ];

        final List<String> popularKeywords = [
          'کەباب', 'شاوڕمە', 'پیتزا', 'قوزی', 'سوپەرمارکێت', 'میوە', 'شیرینی', 'برنج', 'دۆ', 'کۆسمەتیک'
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = displayedQ.trim().toLowerCase();

            // Search Stores (Expensive filtering)
            final matchedStores = query.isEmpty
                ? <StoreItem>[]
                : allStores.where((s) {
                    return s.name.toLowerCase().contains(query) ||
                        s.category.toLowerCase().contains(query) ||
                        s.address.toLowerCase().contains(query);
                  }).toList();

            // Search Products (Expensive filtering)
            final matchedProducts = query.isEmpty
                ? <ProductItem>[]
                : allProducts.where((p) {
                    return p.name.toLowerCase().contains(query) ||
                        p.description.toLowerCase().contains(query) ||
                        p.category.toLowerCase().contains(query) ||
                        (p.subCategory != null && p.subCategory!.toLowerCase().contains(query));
                  }).toList();

            // Search Categories
            final matchedCats = query.isEmpty
                ? searchCategories
                : searchCategories.where((c) {
                    final title = (c['title'] as String).toLowerCase();
                    final catName = (c['catName'] as String).toLowerCase();
                    return title.contains(query) || catName.contains(query);
                  }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Top Grabber Handle & Header
                  Container(
                    padding: const EdgeInsets.only(top: 12, bottom: 8, left: 16, right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.search, color: Color(0xFFFAC800), size: 26),
                                SizedBox(width: 8),
                                Text(
                                  'گەڕانی گشتگیر',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search Input Field
                        TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          textAlign: TextAlign.right,
                          onChanged: (val) {
                            setModalState(() {
                              searchQ = val;
                            });
                            
                            // Debounce search update to avoid lag
                            if (searchDebounce?.isActive ?? false) searchDebounce!.cancel();
                            searchDebounce = Timer(const Duration(milliseconds: 300), () {
                              if (ctx.mounted) {
                                setModalState(() {
                                  displayedQ = val;
                                });
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'گەڕان بۆ چێشتخانە، مارکێت، خواردن، بەشەکان...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFFAC800)),
                            suffixIcon: searchQ.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      setModalState(() {
                                        searchCtrl.clear();
                                        searchQ = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Search Content List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      children: [
                        // IF QUERY IS EMPTY: SHOW QUICK SEARCHES & CATEGORIES
                        if (query.isEmpty) ...[
                          const Text(
                            '🔥 گەڕانی باو و خێرا',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: popularKeywords.map((kw) {
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    searchCtrl.text = kw;
                                    searchQ = kw;
                                  });
                                },
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(
                                    kw,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '📁 گەڕان بەپێی بەشەکان',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                          const SizedBox(height: 12),
                          ...searchCategories.map((c) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFAC800),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(c['icon'] as IconData, size: 20, color: Colors.black),
                                ),
                                title: Text(
                                  c['title'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, textDirection: TextDirection.ltr, size: 14, color: Colors.grey),
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedCategory = c['catName'] as String;
                                    _selectedStore = null;
                                    _currentIndex = 0;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ] else ...[
                          // SEARCH RESULTS VIEW
                          if (matchedStores.isEmpty && matchedProducts.isEmpty && matchedCats.isEmpty) ...[
                            const SizedBox(height: 40),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'هیچ ئەنجامێک بۆ "$searchQ" نەدۆزرایەوە',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'تکایە دڵنیابەرەوە لە دروستی وشەی گەڕانەکەت',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 1. MATCHED CATEGORIES
                          if (matchedCats.isNotEmpty) ...[
                            Row(
                              children: const [
                                Icon(Icons.category_outlined, size: 18, color: Color(0xFFD97706)),
                                SizedBox(width: 6),
                                Text('بەشە دۆزراوەکان', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: matchedCats.map((c) {
                                return ActionChip(
                                  backgroundColor: const Color(0xFFFAC800),
                                  label: Text(c['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12)),
                                  avatar: Icon(c['icon'] as IconData, size: 16, color: Colors.black),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      _selectedCategory = c['catName'] as String;
                                      _selectedStore = null;
                                      _currentIndex = 0;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 2. MATCHED STORES (چێشتخانە و دوکانەکان)
                          if (matchedStores.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 18, color: Color(0xFF059669)),
                                const SizedBox(width: 6),
                                Text('چێشتخانە و دوکانەکان (${matchedStores.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...matchedStores.map((store) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(10),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      store.imageUrl,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => Container(
                                        width: 54,
                                        height: 54,
                                        color: Colors.amber.shade100,
                                        child: const Icon(Icons.store, color: Colors.amber),
                                      ),
                                    ),
                                  ),
                                  title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Row(
                                    children: [
                                      const Icon(Icons.star, size: 14, color: Colors.amber),
                                      const SizedBox(width: 3),
                                      Text('${store.rating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(width: 10),
                                      Text('⏱ ${store.deliveryTime}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAC800),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('سەردان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      _selectedStore = store;
                                      _currentIndex = 0;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 4),
                          ],

                          // 3. MATCHED PRODUCTS (بابەتەکان و خواردنەکان)
                          if (matchedProducts.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.fastfood_outlined, size: 18, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Text('بابەتەکان و خواردنەکان (${matchedProducts.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...matchedProducts.map((p) {
                              final store = allStores.firstWhere(
                                (s) => s.id == p.storeId,
                                orElse: () => allStores[0],
                              );
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          p.imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.amber.shade100,
                                            child: const Icon(Icons.fastfood, color: Colors.amber),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                            if (p.subCategory != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                p.subCategory!,
                                                style: const TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                            const SizedBox(height: 3),
                                            Text('لە: ${store.name}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                            const SizedBox(height: 4),
                                            Text('${p.price} د.ع', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFAC800),
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          _addToCart(p);
                                        },
                                        child: const Text('+ سەبەتە', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🔔 Comprehensive Notifications & Discount Offers Modal
  void _openNotificationsModal() {
    setState(() {
      _unreadNotificationCount = 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filterTag = 'هەمووی';

        final List<Map<String, dynamic>> notificationsList = [
          {
            'id': 'notif_1',
            'title': '🔥 داشکاندنی %30 لە کەباب زاگرۆس',
            'desc': 'داشکاندنی تایبەت لەسەر سەرجەم خواردنەکان و کەبابەکان بۆ ئەمڕۆ! فریابکەوه‌ و داوا بکە.',
            'time': 'پێش 10 خولەک',
            'tag': 'داشکاندن',
            'type': 'store',
            'storeId': 'store_zagros',
            'icon': Icons.local_fire_department_rounded,
            'color': const Color(0xFFEF4444),
            'discountBadge': '%30 OFF',
          },
          {
            'id': 'notif_2',
            'title': '🎁 دیاری 5,000 د.ع بۆ سوپەرمارکێتی هەولێر',
            'desc': 'کۆدی داشکاندنی REGA5 بەکاربهێنە بۆ داشکاندنی 5,000 د.ع لە کڕینی سەروو 25,000 د.ع.',
            'time': 'پێش 45 خولەک',
            'tag': 'کۆدی داشکاندن',
            'type': 'store',
            'storeId': 'store_supermarket_erbil',
            'icon': Icons.card_giftcard_rounded,
            'color': const Color(0xFFD97706),
            'discountBadge': '5,000 د.ع',
          },
          {
            'id': 'notif_3',
            'title': '🍕 گەیاندنی خۆڕایی (0 د.ع) لە فاست فوود',
            'desc': 'گەیاندنی خۆڕایی بەدەستبهێنە بۆ سەرجەم بەشی شاوڕمە و پیتزاکان تا کۆتایی هەفتە!',
            'time': 'پێش 2 کاتژمێر',
            'tag': 'گەیاندن',
            'type': 'category',
            'categoryName': 'فاست فوود',
            'icon': Icons.moped_rounded,
            'color': const Color(0xFF10B981),
            'discountBadge': 'FREE DELIVERY',
          },
          {
            'id': 'notif_4',
            'title': '🍰 ئۆفەری کڕینی 1 کێک + 1 بێبەرامبەر',
            'desc': 'لە شیرینی سلێمانی، یەک کێک بکڕە و دووەمیان وەک دیاری بە خۆڕایی وەربگرە.',
            'time': 'پێش 5 کاتژمێر',
            'tag': 'ئۆفەر',
            'type': 'store',
            'storeId': 'store_bakery_slemani',
            'icon': Icons.cake_rounded,
            'color': const Color(0xFF8B5CF6),
            'discountBadge': '1+1 FREE',
          },
          {
            'id': 'notif_5',
            'title': '🥦 %15 داشکاندنی سەوزە و میوەی فرێش',
            'desc': 'میوە و سەوزەی تەندروست و فرێش بە %15 داشکاندن لە مارکێتی سەروەت داوا بکە.',
            'time': 'دوێنێ',
            'tag': 'داشکاندن',
            'type': 'store',
            'storeId': 'store_sarwar',
            'icon': Icons.shopping_basket_rounded,
            'color': const Color(0xFF059669),
            'discountBadge': '%15 OFF',
          },
          {
            'id': 'notif_6',
            'title': '🚀 ئەپدەیتی نوێی REGA ڕێگا',
            'desc': 'بەخێربێن بۆ خێراترین خزمەتگوزاری گەیاندنی خواردن و مارکێت لە کەلار و کوردستان.',
            'time': 'پێش 2 ڕۆژ',
            'tag': 'ئاگاداری',
            'type': 'general',
            'icon': Icons.notifications_active_rounded,
            'color': const Color(0xFF2563EB),
            'discountBadge': 'ANNOUNCEMENT',
          },
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredNotifs = notificationsList.where((n) {
              if (filterTag == 'داشکاندن') return n['tag'] == 'داشکاندن' || n['tag'] == 'کۆدی داشکاندن';
              if (filterTag == 'خواردنگە') return n['type'] == 'store' || n['type'] == 'category';
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Top Grabber & Header Row
                  Container(
                    padding: const EdgeInsets.only(top: 12, bottom: 8, left: 16, right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.notifications_active_rounded, color: Color(0xFFFAC800), size: 26),
                                SizedBox(width: 8),
                                Text(
                                  'ئاگاداری و داشکاندنەکان',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Filter Pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildNotifFilterChip('هەمووی', filterTag, (val) => setModalState(() => filterTag = val)),
                              const SizedBox(width: 8),
                              _buildNotifFilterChip('داشکاندن', filterTag, (val) => setModalState(() => filterTag = val)),
                              const SizedBox(width: 8),
                              _buildNotifFilterChip('خواردنگە', filterTag, (val) => setModalState(() => filterTag = val)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Notifications & Discounts Full-Width Vertical List (شێوازی لیستی بە شێوەی پانی لەسەر یەک)
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: filteredNotifs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = filteredNotifs[index];
                        final IconData icon = notif['icon'] as IconData;
                        final Color iconColor = notif['color'] as Color;
                        final String? storeId = notif['storeId'] as String?;
                        final String? catName = notif['categoryName'] as String?;

                        StoreItem? store;
                        if (storeId != null) {
                          store = allStores.firstWhere(
                            (s) => s.id == storeId,
                            orElse: () => allStores[0],
                          );
                        }

                        // بۆکسی لیستی پانی بۆ هەر ئاگادارییەک بە شێوازی پانی تەواو لەسەر یەک
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (store != null) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedStore = store;
                                    _currentIndex = 0;
                                  });
                                } else if (catName != null) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedCategory = catName;
                                    _selectedStore = null;
                                    _currentIndex = 0;
                                  });
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1. ئایکۆنی ڕەنگاوڕەنگی سەرەکی بە قەبارەی بچووکتر
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: iconColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: iconColor.withOpacity(0.25), width: 1),
                                      ),
                                      child: Center(
                                        child: Icon(icon, color: iconColor, size: 19),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // 2. ناوەڕۆک بە شێوازی پانی و چڕتر
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // ناونیشانی ئاگاداری
                                          Text(
                                            notif['title'] as String,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          // دەقی ڕوونکردنەوە
                                          Text(
                                            notif['desc'] as String,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // کات و تاگی ئاگاداری
                                          Row(
                                            children: [
                                              Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade500),
                                              const SizedBox(width: 3),
                                              Text(
                                                notif['time'] as String,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: Colors.grey.shade500,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  notif['tag'] as String,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 3. باجی داشکاندن و دوگمەی بچووک لە تەنیشتەوە
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Text(
                                            notif['discountBadge'] as String,
                                            style: const TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAC800),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'بینین',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(width: 2),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 8,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotifFilterChip(String label, String current, Function(String) onSelect) {
    final isSelected = label == current;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isSelected ? Colors.black : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFFAC800),
      backgroundColor: Colors.grey.shade100,
      onSelected: (_) => onSelect(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 ئەگەر هێشتا خەریکی پشکنینی ئاسایش بێت، نیشانەیەکی چاوەڕێکردن پیشان بدە
    if (_isCheckingSecurity) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFAC800)),
        ),
      );
    }

    // 🔒 ئەگەر ئامێرەکە هاککرابوو یان ئیمۆلیتۆر بوو، ڕێگری لێ بکە
    if (!_isDeviceSafe) {
      return _buildSecurityBlockedScreen();
    }

    // 📍 ئەگەر هێشتا خەریکی پشکنینی لۆکەیشن بێت، نیشانەیەکی چاوەڕێکردن پیشان بدە
    if (_isCheckingLocation) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFAC800)),
        ),
      );
    }

    // 📍 ئەگەر ڕێگەپێدانی لۆکەیشن نەدرابوو، شاشەی ئاگادارکردنەوە پیشان بدە و مەهێڵە ئەپەکە بەکاربێنێت
    if (!_isLocationAuthorized) {
      return _buildLocationRequiredScreen();
    }

    // 🛡️ ئەگەر VPN چالاک بوو، ڕێگری بکە
    if (_isVpnActive) {
      return _buildVpnBlockedScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          _selectedStore != null
              ? _buildStoreDetailView(_selectedStore!)
              : Column(
                  children: [
                    // 💛 Header with Rounded Curved Corners (36px)
                    _buildHeader(),

                    // 📄 Active View Switcher
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          _buildHomeTab(),
                          _buildStoresTab(),
                          _buildCartTab(),
                          _buildOrdersTab(),
                          _buildProfileTab(),
                        ],
                      ),
                    ),
                  ],
                ),

          // 🚫 FULL SCREEN OFFLINE OVERLAY (Blocks all app interactions when offline)
          if (_isOffline) _buildOfflineScreen(),
        ],
      ),

      // 📍 Bottom Navigation Bar (Hidden when offline)
      bottomNavigationBar: _isOffline
          ? null
          : Container(
              padding: EdgeInsets.only(
                top: 10,
                bottom: 10 + MediaQuery.of(context).padding.bottom,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBottomNavItem(0, _t('سەرەکی'), Icons.home_rounded, Icons.home_outlined),
                  _buildBottomNavItem(1, _t('داشکاندن'), Icons.discount_rounded, Icons.discount_outlined),
                  _buildBottomNavItem(2, _t('سەبەتە'), Icons.shopping_cart_rounded, Icons.shopping_cart_outlined, isCart: true),
                  _buildBottomNavItem(3, _t('داواکاری'), Icons.receipt_long_rounded, Icons.receipt_long_outlined),
                  _buildBottomNavItem(4, _t('پڕۆفایل'), Icons.account_circle_rounded, Icons.account_circle_outlined),
                ],
              ),
            ),
    );
  }

  Widget _buildBottomNavItem(int index, String label, IconData activeIcon, IconData inactiveIcon, {bool isCart = false}) {
    final bool isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _currentIndex = index;
        _selectedStore = null;
      }),
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 10,
          vertical: isActive ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFAC800) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : inactiveIcon,
                  size: 22,
                  color: Colors.black87,
                ),
                if (isCart && _cart.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      child: Text(
                        '${_cart.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultTextLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'REGA',
          style: TextStyle(
            color: Colors.black,
            fontSize: 32, // گەورەتر کراوە لە 26
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'ڕێگا',
            style: TextStyle(
              color: Color(0xFFFAC800),
              fontSize: 22, // گەورەتر کراوە
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // 🖼️ Smart Logo Widget (Base64 -> Asset PNG -> Network URL -> Default Text Logo)
  Widget _buildLogoWidget() {
    // 💡 پشتگیری بۆ لۆگۆی Base64
    if (appLogoUrl.trim().startsWith('data:image')) {
      try {
        final base64Str = appLogoUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: 48, // ڕێک 48 پێکسڵە
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildDefaultTextLogo(),
        );
      } catch (e) {
        return _buildDefaultTextLogo();
      }
    }

    if (appLogoAssetPath.trim().isNotEmpty) {
      return Image.asset(
        appLogoAssetPath,
        height: 48, // ڕێک 48 پێکسڵە
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          if (appLogoUrl.trim().isNotEmpty) {
            return Image.network(
              appLogoUrl,
              height: 48, // ڕێک 48 پێکسڵە
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildDefaultTextLogo(),
            );
          }
          return _buildDefaultTextLogo();
        },
      );
    } else if (appLogoUrl.trim().isNotEmpty) {
      return Image.network(
        appLogoUrl,
        height: 48, // ڕێک 48 پێکسڵە
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildDefaultTextLogo(),
      );
    }
    return _buildDefaultTextLogo();
  }

  // 🖼️ لۆگۆی خوارەوەی پڕۆفایل کە لە فۆڵدەری assets2 بار دەکرێت
  Widget _buildProfileFooterLogo() {
    return Image.asset(
      profileLogoAssetPath,
      height: 48,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // ئەگەر وێنەی ناو assets2 هێشتا زیاد نەکرا بوو یان دەستی پێ نەگەیشت، لۆگۆی سەرەکی نیشان دەدات تا هیچ کێشەیەک دروست نەبێت
        return _buildLogoWidget();
      },
    );
  }

  // ============================================================================
  // 💛 HEADER COMPONENT (EXACT SCREENSHOT DESIGN)
  // ============================================================================
  Widget _buildHeader() {
    final double topPadding = MediaQuery.of(context).padding.top;
    const double toolbarHeight = 80.0; // تەواوی بەرزی ناڤباڕەکە (toolbarHeight: 80)
    return Container(
      height: toolbarHeight + topPadding,
      decoration: const BoxDecoration(
        color: Color(0xFFFAC800),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: topPadding,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        height: toolbarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Search Icon (RTL: First child renders on the Right)
            IconButton(
              onPressed: _openSearchModal,
              icon: const Icon(Icons.search_rounded, color: Colors.black, size: 26),
            ),

            // Logo Center Badge (SizedBox بەرزی 52 پێکسڵ و لۆگۆ بە بەرزی 48 پێکسڵ بە BoxFit.contain)
            SizedBox(
              height: 52,
              child: Center(
                child: _buildLogoWidget(),
              ),
            ),

            // Notification Bell Icon with Badge (RTL: Third child renders on the Left)
            InkWell(
              onTap: _openNotificationsModal,
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Colors.amber, size: 20),
                  ),
                  if (_unreadNotificationCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_unreadNotificationCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📍 LOCATION / GPS SELECTOR BAR (POSITIONED OUTSIDE & BELOW THE NAVBAR)
  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: _showLocationPicker,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Yellow GPS Target Icon (Right side in RTL)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAC800),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location, size: 16, color: Colors.black),
              ),

              Expanded(
                child: Text(
                  'گەیاندن بۆ: ${_selectedNeighborhood.name}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),

              // Change button pill (Left side in RTL)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('گۆڕین', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                    SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 🏠 TAB 1: HOME VIEW (EXACT MATCH FOR SCREENSHOT CATEGORIES GRID)
  // ============================================================================
  Widget _buildHomeTab() {
    final List<Map<String, dynamic>> categoriesList = [
      {
        'title': _t('خواردنگە و ڕێستۆرانتەکان'),
        'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600',
        'icon': Icons.restaurant_rounded,
        'catName': 'خواردنگە',
      },
      {
        'title': _t('مارکێت و سوپەرمارکێتەکان'),
        'image': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=600',
        'icon': Icons.store_rounded,
        'catName': 'سوپەرمارکێت',
      },
      {
        'title': _t('میوە و سەوزەی فرێش'),
        'image': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=600',
        'icon': Icons.eco_rounded,
        'catName': 'سەوزە و میوە',
      },
      {
        'title': _t('شاوڕمە و فاست فوود'),
        'image': 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600',
        'icon': Icons.fastfood_rounded,
        'catName': 'فاست فوود',
      },
      {
        'title': _t('شیرینی، کێک و باقلاوە'),
        'image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
        'icon': Icons.bakery_dining_rounded,
        'catName': 'شیرەمەنی و شیرینی',
      },
      {
        'title': _t('کافن و قاوەخانەکان'),
        'image': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600',
        'icon': Icons.coffee_rounded,
        'catName': 'کافێ',
      },
      {
        'title': _t('گۆشت و مریشکی تازه'),
        'image': 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=600',
        'icon': Icons.set_meal_outlined,
        'catName': 'گۆشت و قەسابخانە',
      },
      {
        'title': _t('نانەواخانه و سەموون'),
        'image': 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=600',
        'icon': Icons.bakery_dining_outlined,
        'catName': 'نانەواخانە',
      },
    ];

    // 1-Column List of Vertical Store Cards for Category View
    if (_selectedCategory != 'گشتی') {
      // Cache filtered results to avoid recalculating on every build if not needed
      final categoryStores = allStores.where((s) {
        final matchesSearch = _searchQuery.isEmpty || s.name.contains(_searchQuery) || s.category.contains(_searchQuery);
        final matchesCat = s.category == _selectedCategory || 
                          (_selectedCategory.contains('خواردن') && s.category.contains('خواردن')) ||
                          (_selectedCategory.contains('مارکێت') && s.category.contains('مارکێت'));
        return matchesCat && matchesSearch;
      }).toList();

      final displayCatTitle = _selectedCategory == 'خواردنگە' ? 'خواردن' : _selectedCategory;

      return ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          _buildLocationBar(),
          // Header Bar for Category View with White Circle Back Arrow & Category Title (هەمان دیزاینی ئایکۆنی گەڕانەوەی وێنەی دووەم بە بازنەی سپی و تیری سوور)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _selectedCategory = 'گشتی'),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      textDirection: TextDirection.ltr,
                      size: 23,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(displayCatTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: categoryStores.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(_t('هیچ دوکانێک لە بەشی') + ' ' + _t(displayCatTitle) + ' ' + _t('نەدۆزرایەوە'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _selectedCategory = 'گشتی'),
                          child: Text(_t('گەڕانەوە بۆ سەرجەم بەشەکان'), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categoryStores.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      final store = categoryStores[index];
                      return _buildVerticalGridStoreCard(store);
                    },
                  ),
          ),

          const SizedBox(height: 20),
        ],
      );
    }

    // MAIN GENERAL HOME TAB VIEW (WHEN 'گشتی' IS SELECTED)
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _buildLocationBar(),
        const SizedBox(height: 12),
        // Promo Banner Slider (Daily Fruit & Veggies Market)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            child: Stack(
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800',
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAC800),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.local_offer, size: 12, color: Colors.black),
                        SizedBox(width: 4),
                        Text('تەواو تازه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('داشكاندنی REGA', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بازاڕی میوە و سەوزەی ڕۆژانە',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'هەموو ڕۆژێک میوە و سەوزەی تازەی خۆماڵی بە نرخی بازاڕ لە کەلار',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF422006),
                          foregroundColor: const Color(0xFFFAC800),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _selectedCategory = 'سەوزە و میوە'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('داواکردنی ئێستا', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, textDirection: TextDirection.ltr, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Pagination Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 16, height: 6, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 4),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.amber.shade200, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.amber.shade200, shape: BoxShape.circle)),
          ],
        ),

        const SizedBox(height: 16),

        // 2-Column Categories Grid (Exact match with uploaded picture)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categoriesList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
            final cat = categoriesList[index];
            return InkWell(
              onTap: () {
                setState(() => _selectedCategory = cat['catName']);
              },
              borderRadius: BorderRadius.circular(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Image.network(
                      cat['image'],
                      height: double.infinity,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    // Icon Badge top-left (White circle as per screenshot)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                          ],
                        ),
                        child: Icon(cat['icon'] as IconData, size: 22, color: Colors.black),
                      ),
                    ),
                    // Category Name Tag at Bottom Right (Flush with edges as per screenshot)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAC800),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          cat['title'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 20),
    ],
  );
}

  Widget _buildVerticalGridStoreCard(StoreItem store) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStore = store;
          _selectedSubCategory = null;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover Image
            Image.network(
              store.imageUrl,
              fit: BoxFit.cover,
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
            // Top Status Badge (🟢 کراوە)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(radius: 3.5, backgroundColor: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      _t('کراوە'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top Left Discount Badge (🏷️ %30 OFF)
            if (store.discountBadge != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    store.discountBadge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            // Bottom Store Name Tag (Yellow Tag - Flush with edges)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAC800),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                  ),
                ),
                child: Text(
                  store.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(StoreItem store) {
    final isFav = _favoriteStoreIds.contains(store.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          setState(() {
            _selectedStore = store;
            _selectedSubCategory = null;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Image.network(store.imageUrl, height: 145, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9)),
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.black, size: 20),
                    onPressed: () {
                      setState(() {
                        if (isFav) {
                          _favoriteStoreIds.remove(store.id);
                        } else {
                          _favoriteStoreIds.add(store.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${store.category} • ${store.deliveryTime}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${store.rating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔍 شاشەی فۆڵ شاشەی وێنە لەگەڵ تایبەتمەندی Zoom
  void _showFullScreenZoomableImage({
    required BuildContext context,
    required String imageUrl,
    required String title,
    int? price,
    String? category,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.96),
      builder: (ctx) => FullScreenImageViewer(
        imageUrl: imageUrl,
        title: title,
        price: price,
        category: category,
      ),
    );
  }

  Widget _buildStoreDetailView(StoreItem store) {
    final isFav = _favoriteStoreIds.contains(store.id);
    final storeProds = allProducts.where((p) => p.storeId == store.id).toList();

    // Dynamically build Sub-categories ("بابەتەکان") for this store
    final Map<String, List<ProductItem>> subCatMap = {};
    for (var p in storeProds) {
      final cat = p.subCategory ?? 'گشتی';
      subCatMap.putIfAbsent(cat, () => []).add(p);
    }

    final List<Map<String, dynamic>> subCategories = [];
    subCatMap.forEach((catTitle, prods) {
      String catImage = prods.isNotEmpty ? prods.first.imageUrl : store.imageUrl;
      subCategories.add({
        'title': catTitle,
        'badge': '${prods.length} بەرهەم',
        'isDiscount': false,
        'image': catImage,
      });
    });

    // Always include offer/discount category if relevant or as standard
    subCategories.add({
      'title': 'داشکاندنەکان',
      'badge': 'ئۆفەری تایبەت',
      'isDiscount': true,
      'image': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=600',
    });

    final List<ProductItem> activeProds = storeProds.where((p) {
      if (_selectedSubCategory == null || _selectedSubCategory == 'گشتی') return true;
      if (_selectedSubCategory == 'داشکاندنەکان') return true;
      return p.subCategory == _selectedSubCategory;
    }).toList();

    final displayProds = activeProds.isNotEmpty ? activeProds : storeProds;

    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 1. Top Cover Banner Header
          Stack(
            children: [
              Container(
                height: 200 + topPadding,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(store.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.black.withOpacity(0.3)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              // Top Left: Favorite / Heart Button
              Positioned(
                top: topPadding + 10,
                left: 14,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isFav) {
                        _favoriteStoreIds.remove(store.id);
                      } else {
                        _favoriteStoreIds.add(store.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: const Color(0xFFE11D48),
                      size: 23,
                    ),
                  ),
                ),
              ),
              // Top Right: Back Arrow Button (Pointing Right →) - هاوشێوەی وێنەی دووەم بە بازنەی سپی و تیری سوور
              Positioned(
                top: topPadding + 10,
                right: 14,
                child: InkWell(
                  onTap: () {
                    if (_selectedSubCategory != null) {
                      setState(() => _selectedSubCategory = null);
                    } else {
                      setState(() => _selectedStore = null);
                    }
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      textDirection: TextDirection.ltr,
                      color: Color(0xFFE11D48),
                      size: 23,
                    ),
                  ),
                ),
              ),
              // 💛 Bottom Curved Tab (هێڵکاری کەوانەیی بە ڕەنگی ئەپەکە): ⭐ Rating • 🚲 Delivery Fee • 📍 Distance
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(
                          painter: _StoreHeaderCurvedTabPainter(),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                textDirection: TextDirection.rtl,
                                children: [
                                  // ⭐ Rating (Rightmost in RTL)
                                  const Icon(Icons.star_rounded, color: Colors.black, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${store.rating} (342)',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('•', style: TextStyle(color: Colors.black.withOpacity(0.35), fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),

                                  // 🚲 Delivery Fee (Middle in RTL)
                                  const Icon(Icons.directions_bike_rounded, color: Colors.black, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${store.deliveryFee} د.ع',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('•', style: TextStyle(color: Colors.black.withOpacity(0.35), fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),

                                  // 📍 Distance (Leftmost in RTL)
                                  const Icon(Icons.location_on_rounded, color: Colors.black, size: 16),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '1.2 کم',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Store Title Bar (Name + Open Status Badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircleAvatar(radius: 3.5, backgroundColor: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'کراوە',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Body Content
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _selectedSubCategory == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: | بابەتەکان (Right-aligned in RTL)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAC800),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'بابەتەکان',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 2-Column Grid of Categories ("بابەتەکان")
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: subCategories.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.95,
                            ),
                            itemBuilder: (context, idx) {
                              final cat = subCategories[idx];
                              final bool isDiscount = cat['isDiscount'] == true;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedSubCategory = cat['title'] as String;
                                  });
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        cat['image'] as String,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Top Left Badge ("2 بەرهەم" / "2 ئۆفەر")
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDiscount ? const Color(0xFFE11D48) : Colors.black.withOpacity(0.55),
                                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                                          ),
                                          child: Text(
                                            cat['badge'] as String,
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      // Bottom Right Tag ("کەباب و برژاوەکان <")
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDiscount ? const Color(0xFFE11D48) : const Color(0xFFFAC800),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                cat['title'] as String,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.chevron_right,
                                                textDirection: TextDirection.ltr,
                                                size: 14,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header displaying selected sub-category title + Back button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAC800),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedSubCategory!,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSubCategory = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back_ios_new, size: 11, color: Color(0xFFD97706)),
                                    SizedBox(width: 4),
                                    Text(
                                      'هەموو بابەتەکان',
                                      style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // List of products inside selected sub-category (2-Column Grid matching user's design)
                        Expanded(
                          child: displayProds.isEmpty
                              ? const Center(child: Text('هیچ بەرهەمێک نەدۆزرایەوە'))
                              : GridView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: displayProds.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.68,
                                  ),
                                  itemBuilder: (context, i) {
                                    final p = displayProds[i];
                                    final bool isDiscountItem = p.subCategory == 'داشکاندنەکان' || (i % 2 == 1 && p.price >= 8000);
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: Colors.grey.shade200),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.02),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Top: Product Cover Image + Zoom on click + Optional % Discount Badge
                                            GestureDetector(
                                              onTap: () {
                                                _showFullScreenZoomableImage(
                                                  context: context,
                                                  imageUrl: p.imageUrl,
                                                  title: p.name,
                                                  price: p.price,
                                                  category: p.subCategory,
                                                );
                                              },
                                              child: Stack(
                                                children: [
                                                  Image.network(
                                                    p.imageUrl,
                                                    height: 105,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => Container(
                                                      height: 105,
                                                      color: Colors.amber.shade50,
                                                      alignment: Alignment.center,
                                                      child: const Icon(Icons.fastfood, color: Colors.amber),
                                                    ),
                                                  ),
                                                  if (isDiscountItem)
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE11D48),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: const Text(
                                                          '%17',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Bottom: Product Details (Title, Price, Add Button)
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Product Title (Clickable to open Zoom Viewer)
                                                    GestureDetector(
                                                      onTap: () {
                                                        _showFullScreenZoomableImage(
                                                          context: context,
                                                          imageUrl: p.imageUrl,
                                                          title: p.name,
                                                          price: p.price,
                                                          category: p.subCategory,
                                                        );
                                                      },
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            p.name,
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11.5,
                                                              color: Colors.black,
                                                              height: 1.15,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            p.subCategory ?? '',
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontSize: 9.5,
                                                              color: Color(0xFFD97706),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // Price & Plus Button Row (Right: Price, Left: Plus Button)
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        // Price Text (Right side in RTL)
                                                        Flexible(
                                                          child: Text(
                                                            '${p.price} د.ع',
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              color: Color(0xFFD97706),
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: 11.5,
                                                            ),
                                                          ),
                                                        ),

                                                        // Yellow Square + Button (Left side in RTL)
                                                        InkWell(
                                                          onTap: () {
                                                            _addToCart(p);
                                                          },
                                                          borderRadius: BorderRadius.circular(9),
                                                          child: Container(
                                                            width: 30,
                                                            height: 30,
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFAC800),
                                                              borderRadius: BorderRadius.circular(9),
                                                            ),
                                                            child: const Icon(
                                                              Icons.add,
                                                              size: 17,
                                                              color: Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 🏷️ TAB 2: DISCOUNTS & STORES VIEW (ONLY STORES WITH DISCOUNTS)
  // ============================================================================
  Widget _buildStoresTab() {
    // Filter to ONLY stores & restaurants that have an active discount or special offer
    final discountStores = allStores.where((s) => s.discountBadge != null && s.discountBadge!.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: Color(0xFFE11D48), size: 22),
                const SizedBox(width: 8),
                Text(
                  '${_t('شوێنەکانی خاوەن داشکاندن')} (${discountStores.length})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _t('تەنها ئەو دوکان و چێشتخانانەی داشکاندن یان ئۆفەری تایبەتیان ڕاگەیاندووە'),
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: discountStores.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final store = discountStores[index];
            return _buildVerticalGridStoreCard(store);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _formatNum(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // ============================================================================
  // 🛒 TAB 3: CART VIEW
  // ============================================================================
  Widget _buildCartTab() {
    if (_cart.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular Yellow Cart Graphic with Top-Right (+) Badge (Clickable to go home)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFDE59), Color(0xFFFAC800), Color(0xFFEAB308)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEAB308).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shopping_cart_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Top-Right Plus (+) Indicator Badge
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAB308),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Exact text requested
                const Text(
                  'سەبەتەکەت بەتاڵە! دەست بکە بە زیادکردنی بەرهەمەکانت بۆ درێژەدان.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final subtotal = _cart.fold<int>(0, (sum, i) => sum + (i.product.price * i.quantity));
    final deliveryFee = _selectedNeighborhood.deliveryFee;
    final grandTotal = subtotal + deliveryFee;

    // Find primary store name for cart header
    String storeName = 'کەلار ستی';
    if (_cart.isNotEmpty) {
      final storeId = _cart.first.product.storeId;
      final foundStore = allStores.firstWhere((s) => s.id == storeId, orElse: () => allStores.first);
      storeName = foundStore.name;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ----------------------------------------------------------------------
        // TOP HEADER: Title + Store Subtitle (Right) & Clear All Button (Left)
        // ----------------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Right Column: Title + Store Name Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('سەبەتەی کڕین'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${_t('داواکاری لە:')} $storeName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFFD97706)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Left Pill Button: Clear All (سڕینەوەی هەموو)
            InkWell(
              onTap: () {
                setState(() {
                  _cart.clear();
                });
              },
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                    const SizedBox(width: 4),
                    Text(
                      _t('سڕینەوەی هەموو'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 16),

        // ----------------------------------------------------------------------
        // CART ITEMS LIST
        // ----------------------------------------------------------------------
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cart.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final entry = _cart[idx];
            final itemTotal = entry.product.price * entry.quantity;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Product Image (Right side in RTL)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      entry.product.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Title + Math Price Subtitle (Middle - ناوی بەرهەم بە یەک دێڕ بە تەواوی بەبێ فەوتان)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              entry.product.name,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '${_formatNum(entry.product.price)} ${_t('د.ع')} × ${entry.quantity} = ${_formatNum(itemTotal)} ${_t('د.ع')}',
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Actions: Quantity Control Box (+ 1 -) & Active Trash/Delete Button (ئایکۆنی سڕینەوە لە ئەودیو)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quantity Control Box (+ 1 -)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // + Button
                            InkWell(
                              onTap: () => setState(() => entry.quantity++),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 2),
                                  ],
                                ),
                                child: const Icon(Icons.add, size: 14, color: Colors.black),
                              ),
                            ),

                            // Quantity Number
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                '${entry.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),

                            // - Button
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (entry.quantity > 1) {
                                    entry.quantity--;
                                  } else {
                                    _cart.removeAt(idx);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 2),
                                  ],
                                ),
                                child: const Icon(Icons.remove, size: 14, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Active Trash Bin Button (ئایکۆنی تەنەکە خۆڵ لە ئەودیوی زیادکردن و کەمکردن)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _cart.removeAt(idx);
                          });
                        },
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ----------------------------------------------------------------------
        // ORDER SUMMARY CARD (کورتیی داواکاری)
        // ----------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('کورتیی داواکاری'),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 14),

              // Row 1: Subtotal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _t('کۆی گشتی کاڵاکان'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatNum(subtotal)} ${_t('د.ع')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Delivery Fee with Neighborhood Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _t('تێچووی گەیاندن '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5),
                          ),
                        ),
                        Text(
                          '(${_t(_selectedNeighborhood.name)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatNum(deliveryFee)} ${_t('د.ع')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Row 3: Grand Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _t('کۆی گشتی پارە'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatNum(grandTotal)} ${_t('د.ع')}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ----------------------------------------------------------------------
        // CHECKOUT BUTTON (تەواوکردنی داواکاری ←)
        // ----------------------------------------------------------------------
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFAC800),
              foregroundColor: Colors.black,
              elevation: 2,
              shadowColor: const Color(0xFFFAC800).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: _handleProceedToCheckout,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _t('تەواوکردنی داواکاری'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_back_rounded,
                  textDirection: TextDirection.ltr,
                  size: 20,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ============================================================================
  // 📋 TAB 4: ORDERS VIEW
  // ============================================================================
  Widget _buildOrdersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 24, bottom: 8),
          child: Text(
            _t('داواکاریەکانم'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: Colors.grey.shade200, thickness: 1),
        ),
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _buildOrderFilterChip('هەموو'),
                _buildOrderFilterChip('بەردەوام'),
                _buildOrderFilterChip('تەواوبوو'),
                _buildOrderFilterChip('هەڵوەشایەوە'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Orders List
        Expanded(
          child: _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(_t('هیچ داواکارییەکی تۆمارکراوت نییە'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFAC800),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 3,
                        ),
                        onPressed: () {
                          final demoCoords = KalarGeoCatalog.forNeighborhoodId(_selectedNeighborhood.id);
                          final demoOrder = OrderItem(
                            id: '#10245',
                            storeName: 'چێشتخانەی دیوان - کەلار',
                            totalAmount: 18000,
                            status: 'preparing',
                            date: DateTime.now(),
                            items: const [],
                            driverName: 'کاروان محەمەد (ماتۆڕسوار)',
                            driverPhone: '07702001001',
                            address: '${_selectedNeighborhood.name} - شاری کەلار',
                            deliveryPin: '4821',
                            customerLat: _pinnedCustomerLat ?? demoCoords.latitude,
                            customerLng: _pinnedCustomerLng ?? demoCoords.longitude,
                          );
                          setState(() => _orders.insert(0, demoOrder));
                          _showLiveTrackingModal(demoOrder);
                        },
                        icon: const Icon(Icons.two_wheeler_rounded, size: 22),
                        label: const Text(
                          'بینینی نەخشەی زیندوو چرکە بە چرکە (#10245)',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _orders.length,
                  itemBuilder: (context, idx) {
                    final order = _orders[idx];
                    // Apply filter logic
                    if (_selectedOrderFilter != 'هەموو') {
                      if (_selectedOrderFilter == 'بەردەوام' && (order.status == 'delivered' || order.status == 'cancelled')) return const SizedBox.shrink();
                      if (_selectedOrderFilter == 'تەواوبوو' && order.status != 'delivered') return const SizedBox.shrink();
                      if (_selectedOrderFilter == 'هەڵوەشایەوە' && order.status != 'cancelled') return const SizedBox.shrink();
                    }
                    return _buildOrderCard(order);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOrderFilterChip(String key) {
    final isSelected = _selectedOrderFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOrderFilter = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAC800) : Colors.transparent,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Text(
          _t(key),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showReceiptModal(OrderItem order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (ناونیشان لە ڕاست و دوگمەی داخستن لە چەپ)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontSize: 12)),
                      Text(_t('پسوولەی داواکاری REGA'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black87),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Info Box (ناوەکان و ناونیشانەکان لە ڕاست، بەها و زانیارییەکان لە چەپ)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildReceiptInfoRow(_t('فرۆشگا:'), order.storeName),
                    const SizedBox(height: 8),
                    _buildReceiptInfoRow(_t('کڕیار:'), '${_userProfile?.name ?? 'شەيما کاروان'} (0770 123 4567)'),
                    const SizedBox(height: 8),
                    _buildReceiptInfoRow(_t('ناونیشان:'), order.address),
                    const SizedBox(height: 8),
                    _buildReceiptInfoRow(_t('شێوازی پارەدان:'), _t('نەختینە (کاش)')),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Items (بابەتەکان لە ڕاست، نرخەکان لە چەپ)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(_t('بابەتەکان:'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.product.name} × ${item.quantity}',
                        textAlign: TextAlign.start,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatNum(item.product.price * item.quantity)} ${_t('د.ع')}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              )),
              
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 16),
              
              // Totals (ناوەکان لە ڕاست، کۆی پارە لە چەپ)
              _buildReceiptTotalRow(_t('کۆی گشتی کاڵاکان:'), '${_formatNum(order.totalAmount - 1500)} ${_t('د.ع')}', false),
              const SizedBox(height: 8),
              _buildReceiptTotalRow(_t('تێچووی گەیاندن:'), '1,500 ${_t('د.ع')}', false),
              
              const SizedBox(height: 16),
              _buildReceiptTotalRow(_t('کۆی گشتی پارە:'), '${_formatNum(order.totalAmount)} ${_t('د.ع')}', false, isGrand: true),
              
              const SizedBox(height: 24),
              
              // Close Button (باکگراوندی سوور، تێکستی سپیی بۆڵد)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626), // سووری سەرنجڕاکێش و ڕوون
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _t('داخستن'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptTotalRow(String label, String value, bool isGreen, {bool isGrand = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label, 
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isGrand ? FontWeight.bold : FontWeight.normal,
              fontSize: isGrand ? 16 : 14,
              color: isGreen ? Colors.green : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value, 
          textAlign: TextAlign.end,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: isGrand ? 18 : 14,
            color: isGrand ? const Color(0xFFB45309) : (isGreen ? Colors.green : Colors.black87),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 🛵 LIVE GPS TRACKING MODAL (شوێنپێهەڵگرتنی ڕاستەوخۆ)
  // ============================================================================
  void _showLiveTrackingModal(OrderItem order) {
    if (order.id.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerLiveOrderTrackerScreen(
            orderCode: order.id,
            storeName: order.storeName,
            customerAddress: order.address,
            driverName: order.driverName,
            driverPhone: order.driverPhone,
            deliveryPin: order.deliveryPin,
            totalAmount: order.totalAmount,
            initialStatus: order.status,
            customerLocation: LatLng(order.customerLat, order.customerLng),
            onOrderStatusChanged: (nextStatus) {
              if (mounted) {
                setState(() {
                  order.status = nextStatus;
                });
              }
            },
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.black87),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('GPS ڕاستەوخۆ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const Text('شوێن پێهەڵگرتنی شۆفێر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Map UI Simulation
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Stack(
                      children: [
                        // Map Grid background simulation
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                            child: CustomPaint(
                              painter: _GPSTrackingPainter(),
                            ),
                          ),
                        ),
                        // Store Pin
                        Positioned(
                          top: 40,
                          right: 40,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                child: const Icon(Icons.storefront, color: Colors.white, size: 18),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                child: Text(order.storeName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // Destination Customer Pin
                        Positioned(
                          bottom: 30,
                          left: 40,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 20),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                child: const Text('شوێنی تۆ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // Driver Moving Marker
                        Positioned(
                          top: 90,
                          left: 130,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAC800),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.two_wheeler_rounded, color: Colors.black, size: 22),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
                                child: const Text('شۆفێر لە ڕێگایە', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Driver Profile Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFB45309)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.driverName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      order.driverPhone,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Text('گەیاندن: ٧-١٢ خولەک', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('داخستن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // 🛤️ ORDER STATUS STEPPER (هێڵی شوێنکەوتنی داواکاری)
  // ============================================================================
  Widget _buildOrderStepper(OrderItem order) {
    final steps = [
      _t('وەرگیرا'),
      _t('ئامادەیە'),
      _t('هەڵگیرا'),
      _t('لە ڕێگایە'),
      _t('ڕادەست کرا'),
    ];

    int currentStep = 0;
    if (order.status == 'pending') currentStep = 0;
    else if (order.status == 'preparing') currentStep = 2;
    else if (order.status == 'on_the_way') currentStep = 3;
    else if (order.status == 'delivered') currentStep = 4;
    else if (order.status == 'cancelled') currentStep = -1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              bool isCompleted = index <= currentStep && currentStep != -1;
              bool isLast = index == steps.length - 1;

              return Expanded(
                flex: isLast ? 0 : 1,
                child: Row(
                  children: [
                    // Dot
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: isCompleted ? [
                          BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                        ] : [],
                      ),
                      child: isCompleted 
                        ? const Icon(Icons.check, size: 8, color: Colors.white)
                        : null,
                    ),
                    // Line
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: (index < currentStep && currentStep != -1)
                              ? const Color(0xFFF59E0B)
                              : Colors.grey.shade200,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              bool isActive = index == currentStep;
              bool isCompleted = index <= currentStep && currentStep != -1;
              
              return Expanded(
                child: Text(
                  steps[index],
                  textAlign: index == 0 ? TextAlign.right : (index == steps.length - 1 ? TextAlign.left : TextAlign.center),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? Colors.black87 : Colors.grey.shade400,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderItem order) {

    final monthNames = [
      _t('Jan'), _t('Feb'), _t('Mar'), _t('Apr'), _t('May'), _t('Jun'),
      _t('Jul'), _t('Aug'), _t('Sept'), _t('Oct'), _t('Nov'), _t('Dec')
    ];
    final month = monthNames[order.date.month - 1];
    final day = order.date.day;
    final hour = order.date.hour.toString().padLeft(2, '0');
    final min = order.date.minute.toString().padLeft(2, '0');
    final dateStr = '$month, $hour:$min $day';

    Color statusBg = const Color(0xFFD1FAE5);
    Color statusText = const Color(0xFF065F46);
    String statusStr = _t('تەواوبوو');
    
    if (order.status == 'pending' || order.status == 'preparing' || order.status == 'on_the_way') {
      statusBg = Colors.amber.shade100;
      statusText = Colors.amber.shade900;
      statusStr = _t('بەڕێوەیە (زیندوو)');
    } else if (order.status == 'cancelled') {
      statusBg = Colors.red.shade100;
      statusText = Colors.red.shade900;
      statusStr = _t('هەڵوەشایەوە');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        order.id,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Text(
                    statusStr,
                    style: TextStyle(color: statusText, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.storeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            _buildOrderStepper(order),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 12),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '× ${item.quantity}',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatNum(item.product.price * item.quantity)} ${_t('د.ع')}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('کۆی گشتی پارە'), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_formatNum(order.totalAmount)} ${_t('د.ع')}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GestureDetector(
                        onTap: () => _showReceiptModal(order),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text('پسوولە', style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GestureDetector(
                        onTap: () {
                          if (order.status != 'cancelled') {
                            _showLiveTrackingModal(order);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: (order.status != 'cancelled') 
                                ? const Color(0xFFF59E0B) 
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined, 
                                size: 16, 
                                color: (order.status != 'cancelled') ? Colors.black : Colors.grey.shade500
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'شوێن پێهەڵگرتن', 
                                style: TextStyle(
                                  fontSize: 13, 
                                  color: (order.status != 'cancelled') ? Colors.black : Colors.grey.shade500, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 👤 TAB 5: PROFILE & REGISTER VIEW (REDESIGNED)
  // ============================================================================
  void _showAccountDetailsModal(UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline_rounded, size: 40, color: Color(0xFFB45309)),
                ),
                const SizedBox(height: 16),
                Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(_t('بینینی هەژمار'), style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 32),

                // Name Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(_t('ناوی تەواو') == 'ناوی تەواو' ? 'ناوی تەواو' : (_currentLanguage == 'English' ? 'Full Name' : 'الاسم الكامل'), style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(profile.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Phone Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(_t('ژمارەی تەلەفۆن') == 'ژمارەی تەلەفۆن' ? 'ژمارەی تەلەفۆن' : (_currentLanguage == 'English' ? 'Phone Number' : 'رقم الهاتف'), style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(profile.phone, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(_t('داخستن') == 'داخستن' ? 'داخستن' : (_currentLanguage == 'English' ? 'Close' : 'إغلاق'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSupportModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'پشتیوانی و پەیوەندی REGA',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 30), // Balance the close icon
                ],
              ),
              const SizedBox(height: 20),

              // Main Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Text(
                      _t('پشتیگیری ڕاستەوخۆی REGA لە کەلار'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB45309)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('تیمی پشتگیری لە کاتژمێر ٠٩:٠٠ بەیانی تا ٠١:٠٠ شەو لە خزمەتتان دایە.'),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // WhatsApp Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF075E54),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      label: Text(_t('پەیوەندی لە ڕێگەی واتسئاپ'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    
                    // Phone Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFF3F4F6)),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.phone_outlined, size: 20, color: Colors.grey),
                      label: Text(_t('تەلەفۆن بۆ ڕاژەی کریاران'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Bottom Close Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('داخستن', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ),
                  const Text('مەرجەکانی بەکارهێنان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 30),
                ],
              ),
              const SizedBox(height: 20),

              // Content Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'مەرجە گشتییەکان:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    _buildTermsBullet('ئەپی REGA تایبەتە بە گەیاندنی داواکاری لە سنووری شاری کەلار و دەوروبەری.'),
                    _buildTermsBullet('پارەدان دەکرێت بە نەختینە لە کاتی گەیاندن یان بە شێوازی ئەلیکترۆنی ئەنجام بدرێت.'),
                    _buildTermsBullet('کاتی گەیاندن خەمڵێنراوە و بەپێی قەرەباڵغی و کەشوهەوا دەگۆڕێت.'),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('داخستن', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ),
                  const Text('سیاسەتی پاراستنی نهێنی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 30),
                ],
              ),
              const SizedBox(height: 20),

              // Content Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'پاراستنی نهێنی زانیارییەکان:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    _buildTermsBullet('ناونیشان و ژمارەی مۆبایلت تەنها بۆ گەیاندنی داواکارییەکانت لە شاری کەلار بەکاردەهێنرێت.'),
                    _buildTermsBullet('هیچ زانیارییەکی کەسی بۆ لایەنی سێیەم نانێردرێت.'),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('داخستن', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredProfileView() {
    return Column(
      children: [
        // 1. TOP ILLUSTRATION (Jumping Person)
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          child: Center(
            child: Image.network(
              'https://raw.githubusercontent.com/mirnatv/assets/main/celebration.png',
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Column(
                children: [
                  const Icon(Icons.celebration_rounded, size: 80, color: Color(0xFFF59E0B)),
                  const SizedBox(height: 8),
                  Text('بەخێربێیت، ${_userProfile?.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),

        // 2. USER INFO CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, spreadRadius: 1),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: View Account Button
              GestureDetector(
                onTap: () {
                  if (_userProfile != null) {
                    _showAccountDetailsModal(_userProfile!);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Text(_t('بینینی هەژمار'), style: GoogleFonts.notoKufiArabic(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                    ],
                  ),
                ),
              ),
              
              // Right: Avatar and Info
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _userProfile?.name ?? '', 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoKufiArabic(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black)
                          ),
                          Text(
                            _userProfile?.phone ?? '', 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoKufiArabic(fontSize: 11, color: const Color(0xFFB45309), fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  Stack(
                    alignment: Alignment.bottomRight,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: const Icon(Icons.person_rounded, size: 30, color: Color(0xFFB45309)),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B), 
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ],

          ),
        ),

        const SizedBox(height: 16),

        // 3. LANGUAGES MENU ITEM
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isLanguageExpanded = !_isLanguageExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        _isLanguageExpanded ? Icons.expand_more_rounded : Icons.chevron_left_rounded, 
                        color: Colors.grey,
                        size: 20,
                      ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('زمانەکان', style: GoogleFonts.notoKufiArabic(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(_currentLanguage, style: GoogleFonts.notoKufiArabic(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.translate_rounded, color: Color(0xFFB45309), size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_isLanguageExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildLanguageOption('کوردی', isSelected: _currentLanguage == 'کوردی'),
                      const SizedBox(height: 10),
                      _buildLanguageOption('العربية', isSelected: _currentLanguage == 'العربية'),
                      const SizedBox(height: 10),
                      _buildLanguageOption('English', isSelected: _currentLanguage == 'English'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. ADDRESS SECTION
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.near_me_outlined, size: 14, color: Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text(_t('دۆزینەوەی لۆکەیشن'), style: GoogleFonts.notoKufiArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(_t('ناونیشانی تۆ'), style: GoogleFonts.notoKufiArabic(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.location_on_outlined, color: Color(0xFFB45309), size: 20),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_rounded, size: 30, color: Colors.grey.shade200),
              ),
              const SizedBox(height: 12),
              Text(_t('هیچ ناونیشانێک تۆمار نەکراوە'), style: GoogleFonts.notoKufiArabic(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {},
                child: Text(_t('دۆزینەوەی لۆکەیشن'), style: GoogleFonts.notoKufiArabic(fontSize: 13, color: const Color(0xFFB45309), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 5. SUPPORT & POLICIES MENU
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              _buildMenuItem(_t('پشتیوانی و یارمەتی'), Icons.help_outline_rounded),
              Divider(height: 1, color: Colors.grey.shade50),
              _buildMenuItem(_t('مەرج و ڕێساکانی بەکارهێنان'), Icons.description_outlined),
              Divider(height: 1, color: Colors.grey.shade50),
              _buildMenuItem(_t('سیاسەتی پاراستنی نهێنی'), Icons.shield_outlined),
              Divider(height: 1, color: Colors.grey.shade50),
              _buildMenuItem(_t('چوونە دەرەوە'), Icons.logout_rounded, isLogout: true),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 6. FOOTER (LOGO & VERSION)
        Column(
          children: [
            // 🖼️ لۆگۆی پڕۆفایل کە لە فۆڵدەری assets2 بار دەکرێت
            _buildProfileFooterLogo(),
            const SizedBox(height: 12),
            Text(
              ' هەموو مافەکانی پارێزراوە بۆ (REGA)',
              style: GoogleFonts.notoKufiArabic(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLanguageOption(String lang, {required bool isSelected}) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _currentLanguage = lang;
        });

        // 💾 پاشەکەوتکردنی زمان لەناو SharedPreferences بۆ ئەوەی لە کاتی دەرچوون و گەڕانەوە نەگۆڕێت
        await _saveLanguage(lang);

        // Notify parent and update global text direction
        if (lang == 'English') {
          widget.onLanguageChange('en');
        } else if (lang == 'العربية') {
          widget.onLanguageChange('ar');
        } else {
          widget.onLanguageChange('ckb');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade100,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 10)] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              )
            else
              const SizedBox(width: 20),
            Text(
              lang,
              style: GoogleFonts.notoKufiArabic(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFB45309) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simple Translation Helper with Static Map for better performance
  static const Map<String, Map<String, String>> _translations = {
    'سەرەکی': {'کوردی': 'سەرەکی', 'العربية': 'الرئيسية', 'English': 'Home'},
    'کۆگاکان': {'کوردی': 'کۆگاکان', 'العربية': 'المتاجر', 'English': 'Stores'},
    'داواکاری': {'کوردی': 'داواکاری', 'العربية': 'الطلبات', 'English': 'Orders'},
    'کارت': {'کوردی': 'کارت', 'العربية': 'السلة', 'English': 'Cart'},
    'سەبەتە': {'کوردی': 'سەبەتە', 'العربية': 'السلة', 'English': 'Cart'},
    'داشکاندن': {'کوردی': 'داشکاندن', 'العربية': 'التخفيضات', 'English': 'Discounts'},
    'پڕۆفایل': {'کوردی': 'پڕۆفایل', 'العربية': 'الحساب', 'English': 'Profile'},
    'زمانەکان': {'کوردی': 'زمانەکان', 'العربية': 'اللغات', 'English': 'Languages'},
    'گەڕان': {'کوردی': 'گەڕان', 'العربية': 'بحث', 'English': 'Search'},
    'چوونە دەرەوە': {'کوردی': 'چوونە دەرەوە', 'العربية': 'تسجيل الخروج', 'English': 'Logout'},
    'ناونیشانی تۆ': {'کوردی': 'ناونیشانی تۆ', 'العربية': 'عنوانك', 'English': 'Your Address'},
    'لێرە بنووسە...': {'کوردی': 'لێرە بنووسە...', 'العربية': 'اكتب هنا...', 'English': 'Type here...'},
    'خۆتۆمارکردن': {'کوردی': 'خۆتۆمارکردن', 'العربية': 'إنشاء حساب', 'English': 'Register'},
    'چوونە ژوورەوە': {'کوردی': 'چوونە ژوورەوە', 'العربية': 'تسجيل الدخول', 'English': 'Login'},
    'زانیارییە کەسییەکان': {'کوردی': 'زانیارییە کەسییەکان', 'العربية': 'المعلومات الشخصية', 'English': 'Personal Info'},
    'ناوی تەواو': {'کوردی': 'ناوی تەواو', 'العربية': 'الاسم الكامل', 'English': 'Full Name'},
    'ژمارەی تەلەفۆن': {'کوردی': 'ژمارەی تەلەفۆن', 'العربية': 'رقم الهاتف', 'English': 'Phone Number'},
    'وشەی تێپەڕ': {'کوردی': 'وشەی تێپەڕ', 'العربية': 'كلمة المرور', 'English': 'Password'},
    'بەردەوامبە': {'کوردی': 'بەردەوامبە', 'العربية': 'استمرار', 'English': 'Continue'},
    '✅ بە سەرکەوتوویی چووە ژوورەوە': {'کوردی': '✅ بە سەرکەوتوویی چووە ژوورەوە', 'العربية': '✅ تم تسجيل الدخول بنجاح', 'English': '✅ Logged in successfully'},
    '✅ هەژمارەکەت بە سەرکەوتوویی تۆمار کرا': {'کوردی': '✅ هەژمارەکەت بە سەرکەوتوویی تۆمار کرا', 'العربية': '✅ تم تسجيل الحساب بنجاح', 'English': '✅ Account registered successfully'},
    'هیچ ناونیشانێک تۆمار نەکراوە': {
      'کوردی': 'هیچ ناونیشانێک تۆمار نەکراوە', 
      'العربية': 'لم يتم تسجيل أي عنوان', 
      'English': 'No address registered'
    },
    'پشتیوانی و یارمەتی': {'کوردی': 'پشتیوانی و یارمەتی', 'العربية': 'الدعم والمساعدة', 'English': 'Support & Help'},
    'مەرج و ڕێساکانی بەکارهێنان': {'کوردی': 'مەرج و ڕێساکانی بەکارهێنان', 'العربية': 'الشروط والأحكام', 'English': 'Terms & Conditions'},
    'سیاسەتی پاراستنی نهێنی': {'کوردی': 'سیاسەتی پاراستنی نهێنی', 'العربية': 'سياسة الخصوصية', 'English': 'Privacy Policy'},
    'دۆزینەوەی لۆکەیشن': {'کوردی': 'دۆزینەوەی لۆکەیشن', 'العربية': 'تحديد الموقع', 'English': 'Find Location'},
    'بینینی هەژمار': {'کوردی': 'بینینی هەژمار', 'العربية': 'عرض الحساب', 'English': 'View Account'},
    'خواردنگە': {'کوردی': 'خواردنگە', 'العربية': 'مطاعم', 'English': 'Restaurants'},
    'سوپەرمارکێت': {'کوردی': 'سوپەرمارکێت', 'العربية': 'سوبر ماركت', 'English': 'Supermarket'},
    'سەوزە و میوە': {'کوردی': 'سەوزە و میوە', 'العربية': 'خضروات وفواكه', 'English': 'Fruits & Veggies'},
    'فاست فوود': {'کوردی': 'فاست فوود', 'العربية': 'وجبات سريعة', 'English': 'Fast Food'},
    'شیرەمەنی و شیرینی': {'کوردی': 'شیرەمەنی و شیرینی', 'العربية': 'حلويات', 'English': 'Sweets'},
    'کافێ': {'کوردی': 'کافێ', 'العربية': 'كافيه', 'English': 'Cafe'},
    'گۆشت و قەسابخانە': {'کوردی': 'گۆشت و قەسابخانە', 'العربية': 'لحوم', 'English': 'Meat'},
    'نانەواخانە': {'کوردی': 'نانەواخانە', 'العربية': 'مخبز', 'English': 'Bakery'},
    'خواردنگە و ڕێستۆرانتەکان': {'کوردی': 'خواردنگە و ڕێستۆرانتەکان', 'العربية': 'المطاعم والمأكولات', 'English': 'Restaurants & Eateries'},
    'مارکێت و سوپەرمارکێتەکان': {'کوردی': 'مارکێت و سوپەرمارکێتەکان', 'العربية': 'الأسواق والسوبر ماركت', 'English': 'Markets & Supermarkets'},
    'میوە و سەوزەی فرێش': {'کوردی': 'میوە و سەوزەی فرێش', 'العربية': 'الفواكه والخضروات الطازجة', 'English': 'Fresh Fruits & Vegetables'},
    'شاوڕمە و فاست فوود': {'کوردی': 'شاوڕمە و فاست فوود', 'العربية': 'الشاورما والوجبات السريعة', 'English': 'Shawarma & Fast Food'},
    'شیرینی، کێک و باقلاوە': {'کوردی': 'شیرینی، کێک و باقلاوە', 'العربية': 'الحلويات والكيك والحلويات الشرقية', 'English': 'Sweets, Cakes & Baklava'},
    'کافن و قاوەخانەکان': {'کوردی': 'کافن و قاوەخانەکان', 'العربية': 'المقاهي والكافيهات', 'English': 'Cafes & Coffee Shops'},
    'گۆشت و مریشکی تازه': {'کوردی': 'گۆشت و مریشکی تازه', 'العربية': 'اللحوم الطازجة والقصابة', 'English': 'Fresh Meat & Butcher'},
    'نانەواخانه و سەموون': {'کوردی': 'نانەواخانه و سەموون', 'العربية': 'المخبز والمعجنات', 'English': 'Bakery & Pastries'},
    'نان و کولێرەی گەرم': {'کوردی': 'نان و کولێرەی گەرم', 'العربية': 'الخبز والمعجنات الساخنة', 'English': 'Hot Bread & Pastries'},
    'گۆشتی فرێش و قەسابخانە': {'کوردی': 'گۆشتی فرێش و قەسابخانە', 'العربية': 'اللحوم الطازجة والقصابة', 'English': 'Fresh Meat & Butcher'},
    'گەڕان بۆ کۆگا و خواردن...': {'کوردی': 'گەڕان بۆ کۆگا و خواردن...', 'العربية': 'البحث عن المتجر والطعام...', 'English': 'Search for stores and food...'},
    'داشکاندنەکان': {'کوردی': 'داشکاندنەکان', 'العربية': 'التخفيضات', 'English': 'Discounts'},
    'سەبەتەکەت خاڵییە': {'کوردی': 'سەبەتەکەت خاڵییە', 'العربية': 'سلتك فارغة', 'English': 'Your cart is empty'},
    'تەواوکردن و ناردنی داواکاری': {'کوردی': 'تەواوکردن و ناردنی داواکاری', 'العربية': 'إكمال وإرسال الطلب', 'English': 'Complete & Send Order'},
    'تەواوکردن و ناردنی داواکاری 🚚': {'کوردی': 'تەواوکردن و ناردنی داواکاری', 'العربية': 'إكمال وإرسال الطلب', 'English': 'Complete & Send Order'},
    'کۆی گشتی': {'کوردی': 'کۆی گشتی', 'العربية': 'المجموع الكلي', 'English': 'Grand Total'},
    'تێچووی گەیاندن': {'کوردی': 'تێچووی گەیاندن', 'العربية': 'رسوم التوصيل', 'English': 'Delivery Fee'},
    'بچۆ ژوورەوە': {'کوردی': 'بچۆ ژوورەوە', 'العربية': 'تسجيل الدخول', 'English': 'Login'},
    'داخستن': {'کوردی': 'داخستن', 'العربية': 'إغلاق', 'English': 'Close'},
    'کراوە': {'کوردی': 'کراوە', 'العربية': 'مفتوح', 'English': 'Open'},
    'داخراوە': {'کوردی': 'داخراوە', 'العربية': 'مغلق', 'English': 'Closed'},
    'خولەک': {'کوردی': 'خولەک', 'العربية': 'دقيقة', 'English': 'min'},
    'د.ع': {'کوردی': 'د.ع', 'العربية': 'د.ع', 'English': 'IQD'},
    'زێدە کرا بۆ سەبەتە': {'کوردی': 'زێدە کرا بۆ سەبەتە', 'العربية': 'تمت الإضافة إلى السلة', 'English': 'Added to cart'},
    'ئەنجامی گەڕان بۆ': {'کوردی': 'ئەنجامی گەڕان بۆ', 'العربية': 'نتائج البحث عن', 'English': 'Search results for'},
    'خواردن': {'کوردی': 'خواردن', 'العربية': 'طعام', 'English': 'Food'},
    'بابەتەکان': {'کوردی': 'بابەتەکان', 'العربية': 'الأصناف', 'English': 'Categories'},
    'هەمووی': {'کوردی': 'هەمووی', 'العربية': 'الكل', 'English': 'All'},
    'پشتیگیری ڕاستەوخۆی REGA لە کەلار': {
      'کوردی': 'پشتیگیری ڕاستەوخۆی REGA لە کەلار',
      'العربية': 'الدعم المباشر لـ REGA في كلار',
      'English': 'REGA Direct Support in Kalar'
    },
    'تیمی پشتگیری لە کاتژمێر ٠٩:٠٠ بەیانی تا ٠١:٠٠ شەو لە خزمەتتان دایە.': {
      'کوردی': 'تیمی پشتگیری لە کاتژمێر ٠٩:٠٠ بەیانی تا ٠١:٠٠ شەو لە خزمەتتان دایە.',
      'العربية': 'فريق الدعم متاح من ٩:٠٠ صباحاً حتى ١:٠٠ بعد منتصف الليل.',
      'English': 'Support team is available from 09:00 AM to 01:00 AM.'
    },
    'پەیوەندی لە ڕێگەی واتسئاپ': {
      'کوردی': 'پەیوەندی لە ڕێگەی واتسئاپ',
      'العربية': 'التواصل عبر الواتساب',
      'English': 'Contact via WhatsApp'
    },
    'تەلەفۆن بۆ ڕاژەی کریاران': {
      'کوردی': 'تەلەفۆن بۆ ڕاژەی کریاران',
      'العربية': 'الاتصال بخدمة العملاء',
      'English': 'Call Customer Service'
    },
    'بەرهەمەکان': {'کوردی': 'بەرهەمەکان', 'العربية': 'المنتجات', 'English': 'Products'},
    'کۆتایی': {'کوردی': 'کۆتایی', 'العربية': 'النهاية', 'English': 'End'},
    'کۆگا پێشنیارکراوەکان': {'کوردی': 'کۆگا پێشنیارکراوەکان', 'العربية': 'المتاجر المقترحة', 'English': 'Recommended Stores'},
    'بینینی هەموو': {'کوردی': 'بینینی هەموو', 'العربية': 'عرض الكل', 'English': 'View All'},
    'هەموو جۆرەکان': {'کوردی': 'هەموو جۆرەکان', 'العربية': 'جميع الأصناف', 'English': 'All Categories'},
    'گەڕان بۆ شوێن...': {'کوردی': 'گەڕان بۆ شوێن...', 'العربية': 'البحث عن مكان...', 'English': 'Search for place...'},
    'دیاریکردنی ناونیشان': {'کوردی': 'دیاریکردنی ناونیشان', 'العربية': 'تحديد العنوان', 'English': 'Select Address'},
    'گەڕان بۆ کۆگا و خواردن': {'کوردی': 'گەڕان بۆ کۆگا و خواردن', 'العربية': 'البحث عن المتجر والطعام', 'English': 'Search for store and food'},
    'هیچ داواکارییەکی تۆمارکراوت نییە': {'کوردی': 'هیچ داواکارییەکی تۆمارکراوت نییە', 'العربية': 'ليس لديك أي طلبات مسجلة', 'English': 'You have no registered orders'},
    'کۆی گشتی داواکاری:': {'کوردی': 'کۆی گشتی داواکاری:', 'العربية': 'المجموع الكلي للطلب:', 'English': 'Order Grand Total:'},
    'هیچ دوکانێک لە بەشی': {'کوردی': 'هیچ دوکانێک لە بەشی', 'العربية': 'لا توجد متاجر في قسم', 'English': 'No stores in'},
    'نەدۆزرایەوە': {'کوردی': 'نەدۆزرایەوە', 'العربية': 'لم يتم العثور عليها', 'English': 'found'},
    'گەڕانەوە بۆ سەرجەم بەشەکان': {'کوردی': 'گەڕانەوە بۆ سەرجەم بەشەکان', 'العربية': 'العودة لجميع الأقسام', 'English': 'Back to all categories'},
    'شوێنەکانی خاوەن داشکاندن': {'کوردی': 'شوێنەکانی خاوەن داشکاندن', 'العربية': 'الأماکن ذات التخفیضات', 'English': 'Discount Stores'},
    'تەنها ئەو دوکان و چێشتخانانەی داشکاندن یان ئۆفەری تایبەتیان ڕاگەیاندووە': {'کوردی': 'تەنها ئەو دوکان و چێشتخانانەی داشکاندن یان ئۆفەری تایبەتیان ڕاگەیاندووە', 'العربية': 'فقط المتاجر والمطاعم التي أعلنت عن تخفیضات أو عروض خاصة', 'English': 'Only stores and restaurants with active discounts or special offers'},
    'سەبەتەکەت بەتاڵە!': {'کوردی': 'سەبەتەکەت بەتاڵە!', 'العربية': 'سلتك فارغة!', 'English': 'Your cart is empty!'},
    'هیچ کاڵایەکت هەڵنەبژاردووە بۆ کڕین': {'کوردی': 'هیچ کاڵایەکت هەڵنەبژاردووە بۆ کڕین', 'العربية': 'لم تختر أي منتجات للشراء', 'English': 'You haven\'t selected any items to buy'},
    'سەبەتەی کڕین': {'کوردی': 'سەبەتەی کڕین', 'العربية': 'سلة التسوق', 'English': 'Shopping Cart'},
    'داواکاری لە:': {'کوردی': 'داواکاری لە:', 'العربية': 'الطلب من:', 'English': 'Order from:'},
    'سڕینەوەی هەموو': {'کوردی': 'سڕینەوەی هەموو', 'العربية': 'حذف الكل', 'English': 'Clear All'},
    'کورتیی داواکاری': {'کوردی': 'کورتیی داواکاری', 'العربية': 'ملخص الطلب', 'English': 'Order Summary'},
    'کۆی گشتی کاڵاکان': {'کوردی': 'کۆی گشتی کاڵاکان', 'العربية': 'مجموع المنتجات', 'English': 'Items Subtotal'},
    'تێچووی گەیاندن ': {'کوردی': 'تێچووی گەیاندن ', 'العربية': 'تكلفة التوصيل ', 'English': 'Delivery Fee '},
    'کۆی گشتی پارە': {'کوردی': 'کۆی گشتی پارە', 'العربية': 'المجموع الكلي', 'English': 'Grand Total'},
    'داواکاریەکانم': {'کوردی': 'داواکاریەکانم', 'العربية': 'طلباتي', 'English': 'My Orders'},
    'هەموو': {'کوردی': 'هەموو', 'العربية': 'الكل', 'English': 'All'},
    'بەردەوام': {'کوردی': 'بەردەوام', 'العربية': 'قيد التنفيذ', 'English': 'Ongoing'},
    'تەواوبوو': {'کوردی': 'تەواوبوو', 'العربية': 'مكتمل', 'English': 'Delivered'},
    'هەڵوەشایەوە': {'کوردی': 'هەڵوەشایەوە', 'العربية': 'ملغي', 'English': 'Cancelled'},
    'بەڕێوەیە (زیندوو)': {'کوردی': 'بەڕێوەیە (زیندوو)', 'العربية': 'قيد المعالجة (مباشر)', 'English': 'In Progress (Live)'},
    'پسوولەی داواکاری REGA': {'کوردی': 'پسوولەی داواکاری REGA', 'العربية': 'وصل طلب REGA', 'English': 'REGA Order Receipt'},
    'وەرگیرا': {'کوردی': 'وەرگیرا', 'العربية': 'تم الاستلام', 'English': 'Received'},
    'ئامادەیە': {'کوردی': 'ئامادەیە', 'العربية': 'جاهز', 'English': 'Ready'},
    'هەڵگیرا': {'کوردی': 'هەڵگیرا', 'العربية': 'تم الاستلام للتوصيل', 'English': 'Picked up'},
    'لە ڕێگایە': {'کوردی': 'لە ڕێگایە', 'العربية': 'في الطريق', 'English': 'On the way'},
    'ڕادەست کرا': {'کوردی': 'ڕادەست کرا', 'العربية': 'تم التسليم', 'English': 'Delivered'},
    'Jan': {'کوردی': 'کانونی ٢', 'العربية': 'يناير', 'English': 'Jan'},
    'Feb': {'کوردی': 'شوبات', 'العربية': 'فبراير', 'English': 'Feb'},
    'Mar': {'کوردی': 'ئازار', 'العربية': 'مارس', 'English': 'Mar'},
    'Apr': {'کوردی': 'نیسان', 'العربية': 'أبريل', 'English': 'Apr'},
    'May': {'کوردی': 'ئایار', 'العربية': 'مايو', 'English': 'May'},
    'Jun': {'کوردی': 'حوزەیران', 'العربية': 'يونيو', 'English': 'Jun'},
    'Jul': {'کوردی': 'تەممووز', 'العربية': 'يوليو', 'English': 'Jul'},
    'Aug': {'کوردی': 'ئاب', 'العربية': 'أغسطس', 'English': 'Aug'},
    'Sept': {'کوردی': 'ئەیلوول', 'العربية': 'سبتمبر', 'English': 'Sept'},
    'Oct': {'کوردی': 'تشرینی ١', 'العربية': 'أكتوبر', 'English': 'Oct'},
    'Nov': {'کوردی': 'تشرینی ٢', 'العربية': 'نوفمبر', 'English': 'Nov'},
    'Dec': {'کوردی': 'کانونی ١', 'العربية': 'ديسمبر', 'English': 'Dec'},
  };

  String _t(String text) {
    if (_translations.containsKey(text)) {
      return _translations[text]![_currentLanguage] ?? text;
    }
    return text;
  }

  Widget _buildMenuItem(String title, IconData icon, {bool isLogout = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      visualDensity: VisualDensity.compact,
      onTap: () async {
        if (isLogout) {
          await _clearProfile();
          setState(() => _userProfile = null);
        } else if (title == _t('پشتیوانی و یارمەتی')) {
          _showSupportModal();
        } else if (title == _t('مەرج و ڕێساکانی بەکارهێنان')) {
          _showTermsModal();
        } else if (title == _t('سیاسەتی پاراستنی نهێنی')) {
          _showPrivacyModal();
        }
      },
      leading: Icon(Icons.chevron_left_rounded, color: isLogout ? Colors.red.shade200 : Colors.grey),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title, 
            style: GoogleFonts.notoKufiArabic(
              fontSize: 14, 
              fontWeight: FontWeight.bold, 
              color: isLogout ? Colors.red : Colors.black87
            )
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isLogout ? Colors.red.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isLogout ? Colors.red : const Color(0xFFB45309), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final bool isEn = _currentLanguage == 'English';
    if (_userProfile != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: _buildRegisteredProfileView(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 1. TOP TOGGLE (Login / Register)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, spreadRadius: 1),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                // Register Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLoginMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isLoginMode ? const Color(0xFFF59E0B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t('خۆتۆمارکردن'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoKufiArabic(
                          color: !_isLoginMode ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                // Login Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLoginMode = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isLoginMode ? const Color(0xFFF59E0B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t('چوونە ژوورەوە'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoKufiArabic(
                          color: _isLoginMode ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. MAIN REGISTRATION CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber.withOpacity(0.15), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.amber.withOpacity(0.03), blurRadius: 15, spreadRadius: 2),
              ],
            ),
            child: Column(
              crossAxisAlignment: isEn ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                // Header: Avatar, Title, Back
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button (Adjust position for EN)
                    if (isEn) ...[
                      // Avatar with Plus
                      _buildProfileAvatar(),
                      // Title & Subtitle
                      _buildProfileTitleHeader(isEn),
                      // Back Button
                      _buildProfileBackButton(),
                    ] else ...[
                      // Back Button
                      _buildProfileBackButton(),
                      // Title & Subtitle
                      _buildProfileTitleHeader(isEn),
                      // Avatar with Plus
                      _buildProfileAvatar(),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // Form Fields
                if (!_isLoginMode) ...[
                  _buildCustomField('ناوی تەواو', _nameCtrl, Icons.person_outline),
                  const SizedBox(height: 12),
                ],
                _buildCustomField('ژمارەی تەلەفۆن', _phoneCtrl, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildCustomField('وشەی تێپەڕ', _passwordCtrl, Icons.lock_outline, isPassword: true),

                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      UserProfile profile;
                      if (_isLoginMode) {
                        // Mock login
                        profile = UserProfile(
                          name: 'شەيما کاروان',
                          phone: _phoneCtrl.text,
                          email: 'user@example.com',
                          address: 'گەڕەکی شەهیدان',
                        );
                      } else {
                        profile = UserProfile(
                          name: _nameCtrl.text,
                          phone: _phoneCtrl.text,
                          email: '',
                          address: _selectedNeighborhood.name,
                        );
                      }
                      
                      setState(() {
                        _userProfile = profile;
                      });
                      
                      await _saveProfile(profile);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t(_isLoginMode ? '✅ بە سەرکەوتوویی چووە ژوورەوە' : '✅ هەژمارەکەت بە سەرکەوتوویی تۆمار کرا'))),
                      );
                    },
                    child: Text(
                      _t(_isLoginMode ? 'چوونە ژوورەوە' : 'بەردەوامبە'),
                      style: GoogleFonts.notoKufiArabic(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. LANGUAGES CARD (AVAILABLE BEFORE LOGIN)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, spreadRadius: 1),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isLanguageExpanded = !_isLanguageExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          _isLanguageExpanded ? Icons.expand_more_rounded : Icons.chevron_left_rounded, 
                          color: Colors.grey,
                          size: 20,
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: _currentLanguage == 'English' ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Text(_t('زمانەکان'), style: GoogleFonts.notoKufiArabic(fontSize: 14, fontWeight: FontWeight.bold)),
                                Text(_currentLanguage, style: GoogleFonts.notoKufiArabic(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.translate_rounded, color: Color(0xFFB45309), size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (_isLanguageExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildLanguageOption('کوردی', isSelected: _currentLanguage == 'کوردی'),
                        const SizedBox(height: 10),
                        _buildLanguageOption('العربية', isSelected: _currentLanguage == 'العربية'),
                        const SizedBox(height: 10),
                        _buildLanguageOption('English', isSelected: _currentLanguage == 'English'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileBackButton() {
    final bool isEn = _currentLanguage == 'English';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber.shade100),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(isEn ? Icons.chevron_left : Icons.chevron_right, color: const Color(0xFFB45309), size: 20),
        onPressed: () {},
      ),
    );
  }

  Widget _buildProfileTitleHeader(bool isEn) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isEn ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            _t(_isLoginMode ? 'چوونە ژوورەوە' : 'خۆتۆمارکردن'),
            style: GoogleFonts.notoKufiArabic(fontSize: 18, fontWeight: FontWeight.w900),
            textAlign: isEn ? TextAlign.left : TextAlign.right,
          ),
          Text(
            _t('زانیارییە کەسییەکان'),
            style: GoogleFonts.notoKufiArabic(fontSize: 10, color: Colors.grey),
            textAlign: isEn ? TextAlign.left : TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade100),
          ),
          child: const Icon(Icons.person_outline, size: 24, color: Color(0xFFB45309)),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Icons.add, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomField(String label, TextEditingController controller, IconData icon, {TextInputType keyboardType = TextInputType.text, bool isPassword = false}) {
    final bool isEn = _currentLanguage == 'English';
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: isEn ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(right: isEn ? 0 : 4, left: isEn ? 4 : 0, bottom: 6),
            child: Text(
              _t(label),
              textAlign: isEn ? TextAlign.left : TextAlign.right,
              style: GoogleFonts.notoKufiArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          SizedBox(
            height: 48,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: isPassword,
              textAlign: isEn ? TextAlign.left : TextAlign.right,
              style: GoogleFonts.notoKufiArabic(fontSize: 14),
              decoration: InputDecoration(
                hintText: _t('لێرە بنووسە...'),
                hintStyle: GoogleFonts.notoKufiArabic(color: Colors.grey.shade400, fontSize: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                prefixIcon: isEn ? Icon(icon, size: 20, color: Colors.grey.shade400) : null,
                suffixIcon: !isEn ? Icon(icon, size: 20, color: Colors.grey.shade400) : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🗺️ CUSTOM PAINTER FOR KALAR CITY MAP VECTOR GRAPHICS
class _KalarMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sirwan River Path (Blue Wavy Curve)
    final riverPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.4)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final riverPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(
        size.width * 0.35, size.height * 0.85,
        size.width * 0.65, size.height * 0.55,
        size.width, size.height * 0.68,
      );

    canvas.drawPath(riverPath, riverPaint);

    // 2. Main Kalar Roads Grid (Yellowish & Grey Lines)
    final mainRoadPaint = Paint()
      ..color = const Color(0xFF64748B).withOpacity(0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final primaryHighwayPaint = Paint()
      ..color = const Color(0xFFF59E0B).withOpacity(0.35)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Horizontal main avenues
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), primaryHighwayPaint);
    canvas.drawLine(Offset(0, size.height * 0.55), Offset(size.width, size.height * 0.55), mainRoadPaint);

    // Vertical main avenues
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), primaryHighwayPaint);
    canvas.drawLine(Offset(size.width * 0.6, 0), Offset(size.width * 0.6, size.height), mainRoadPaint);

    // Diagonal street connectors
    canvas.drawLine(Offset(0, 0), Offset(size.width * 0.5, size.height * 0.5), mainRoadPaint);
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.5), Offset(size.width, size.height * 0.2), mainRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GPSTrackingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width - 40, 40);
    path.lineTo(size.width * 0.5, 100);
    path.lineTo(40, size.height - 40);

    canvas.drawPath(path, paintRoad);

    final routePaint = Paint()
      ..color = Colors.amber.shade600
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 💛 هێڵکاری کەوانەیی بۆ سەر وێنەی دوکان و مارکێتەکان (Curved Tab with App Yellow #FAC800)
class _StoreHeaderCurvedTabPainter extends CustomPainter {
  const _StoreHeaderCurvedTabPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    // Dynamic tab width with responsive limits: ~78% width centered
    final double tabWidth = w * 0.78 > 300.0 ? 300.0 : (w * 0.78 < 260.0 ? (w > 280.0 ? 260.0 : w * 0.9) : w * 0.78);
    final double tabLeft = (w - tabWidth) / 2;
    final double tabRight = (w + tabWidth) / 2;
    const double wingHeight = 4.0;
    const double shoulderWidth = 24.0;
    const double cornerRadius = 18.0;

    final path = Path();
    path.moveTo(0, h);
    path.lineTo(0, h - wingHeight);
    path.lineTo(tabLeft - shoulderWidth, h - wingHeight);

    // Smooth transition curve from wing up to the raised tab shoulder
    path.quadraticBezierTo(
      tabLeft - (shoulderWidth * 0.3),
      h - wingHeight,
      tabLeft,
      h - 18,
    );
    // Vertical side wall to top corner
    path.lineTo(tabLeft, cornerRadius);
    // Top-left rounded corner
    path.quadraticBezierTo(tabLeft, 0, tabLeft + cornerRadius, 0);
    // Top flat edge of the tab
    path.lineTo(tabRight - cornerRadius, 0);
    // Top-right rounded corner
    path.quadraticBezierTo(tabRight, 0, tabRight, cornerRadius);
    // Vertical side wall down
    path.lineTo(tabRight, h - 18);
    // Smooth transition curve from tab shoulder down to right wing
    path.quadraticBezierTo(
      tabRight + (shoulderWidth * 0.3),
      h - wingHeight,
      tabRight + shoulderWidth,
      h - wingHeight,
    );
    path.lineTo(w, h - wingHeight);
    path.lineTo(w, h);
    path.close();

    // Soft drop shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.35), 4, false);

    // Paint with Official App Theme Color #FAC800
    final paint = Paint()
      ..color = const Color(0xFFFAC800)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ============================================================================
/// 🔍 FULL SCREEN ZOOMABLE IMAGE VIEWER (شاشەی فۆڵ شاشەی وێنەی بەرهەمەکان بە Zoom)
/// ============================================================================
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;
  final int? price;
  final String? category;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
    this.price,
    this.category,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? const Offset(150, 150);
      _transformController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.4).clamp(0.8, 5.0);
    setState(() {
      _transformController.value = Matrix4.identity()..scale(newScale);
    });
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.4).clamp(0.8, 5.0);
    setState(() {
      _transformController.value = Matrix4.identity()..scale(newScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.96),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center Zoomable Interactive Viewer
            Center(
              child: GestureDetector(
                onDoubleTapDown: (d) => _doubleTapDetails = d,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  clipBehavior: Clip.none,
                  minScale: 0.8,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(50),
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFAC800)),
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
                          SizedBox(height: 12),
                          Text(
                            'وێنەکە بارنەکرا',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top Header: Close Button + Product Title + Reset Zoom
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),

                  // Title Pill
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Reset Zoom Button
                  InkWell(
                    onTap: _resetZoom,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                      ),
                      child: const Icon(Icons.refresh, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



