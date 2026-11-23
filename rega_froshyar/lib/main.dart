import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import "package:flutter/foundation.dart";
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vendor_api_service.dart';
import 'blocked_account.dart';
import 'assigned_driver_map.dart';
import 'rega_mobile.dart';
import 'image_compress_service.dart';
import 'app/providers.dart';
import 'app/app_router.dart';
import 'state/vendor_nav_notifier.dart';
import 'state/vendor_session_notifier.dart';
import 'iraq_phone_formatter.dart';
import 'service_area.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;
import 'map/mapbox_tiles.dart';
import 'rega_i18n.dart';
import 'rega_colors.dart';
// ==============================================================================
// 🔔 خزمەتگوزاری دەنگی موزیک و ئاگادارکردنەوە بۆ داواکارییە نوێیەکان (Order Sound Service)
// ئەم بەشە بەرپرسە لە لێدانی زەنگی گەورە و بەهێز بۆ داواکاری نوێ
// ==============================================================================
// 🔔 خزمەتگوزاری دەنگی موزیک و ئاگادارکردنەوە بۆ داواکارییە نوێیەکان (Order Sound Service)
// ئەم بەشە بەرپرسە لە لێدانی زەنگی گەورە و بەهێز بۆ داواکاری نوێ
// ==============================================================================
class OrderSoundService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// لێدانی زەنگی موزیک و ئاگادارکردنەوەی گەورە (طنین و موسیقای زەنگ)
  static const String _newOrderSoundAsset =
      'assets/sounds/mixkit-happy-bells-notification-937.wav';

  static Future<void> playNewOrderAlert({bool soundEnabled = true}) async {
    if (!soundEnabled) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource(_newOrderSoundAsset));
    } catch (e) {
      debugPrint('Error playing AudioPlayer sound: $e');
    }

    try {
      // Haptic pulse with the bells (no extra system beep — WAV is the alert).
      for (int i = 0; i < 2; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 280));
      }
    } catch (e) {
      debugPrint('Error playing haptic alert: $e');
    }
  }

  /// تاقیکردنەوەی زەنگ و موزیک
  static Future<void> playTestTone() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setSource(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error playing test tone: $e');
    }
  }
}

// ==============================================================================
// 📌 لۆگۆی ناڤ باڕی سەرەوە (Top Bar Logo Configuration)
// بە پێی فایلی پرۆژەکەت لێرە دانراوە: 'assets/logo.png'
// ئەپەکە بە شێوازی سەلامەت فایلی logo.png لە فۆڵدەری assets دەخوێنێتەوە
// ==============================================================================
const String kAppLogoFilePath = 'assets/logo.png';

// ==============================================================================
// 📌 فۆنتی سەرەکی ئەپ (Global Font Family)
// فۆنتی دیاریکراو بۆ هەموو تێکست و بەشەکانی ئەپەکە: Noto Kufi Arabic
// ==============================================================================
const String kAppFontFamily = 'NotoKufiArabic';


class Trans {
  static const String _prefKey = 'rega_vendor_lang';
  static final ValueNotifier<String> lang = ValueNotifier<String>('ku');
  static const String _darkKey = 'rega_vendor_dark_mode';
  static final ValueNotifier<bool> dark = ValueNotifier<bool>(false);

  static Future<void> setDark(bool value) async {
    dark.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkKey, value);
    } catch (e) {
      debugPrint('Error saving vendor theme: $e');
    }
  }

  static Future<void> loadSavedLang() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      dark.value = prefs.getBool(_darkKey) ?? false;
      if (saved != null && (saved == 'ku' || saved == 'ar' || saved == 'en')) {
        lang.value = saved;
      }
    } catch (e) {
      debugPrint('Error loading vendor language: $e');
    }
  }

  static Future<void> _persistLang(String l) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, l);
    } catch (e) {
      debugPrint('Error saving vendor language: $e');
    }
  }

  static void setLang(String l) {
    lang.value = l;
    _persistLang(l);
  }
  static TextDirection get direction => lang.value == 'en' ? TextDirection.ltr : TextDirection.rtl;

  static String get(String key) {
    if (lang.value == 'ku') return tx(key);
    return _dict[key]?[lang.value] ?? tx(key);
  }

  static final Map<String, Map<String, String>> _dict = {
     'ڕێکخستن': {'en': 'Settings', 'ar': 'الإعدادات'},
     'داهاتی فرۆشیار': {'en': 'Vendor Revenue', 'ar': 'إيرادات البائع'},
     'مێنۆ و بەرهەم': {'en': 'Menu & Products', 'ar': 'القائمة والمنتجات'},
     'داواکارییەکان': {'en': 'Orders', 'ar': 'الطلبات'},
     'ڕێکخستنی دوکان': {'en': 'Store Settings', 'ar': 'إعدادات المتجر'},
     'زانیاری بنەڕەتی، زمان و کاتژمێری کارکردن': {'en': 'Basic Info, Language & Working Hours', 'ar': 'المعلومات الأساسية، اللغة وساعات العمل'},
     'زانیاری بنەڕەتی': {'en': 'Basic Info', 'ar': 'المعلومات الأساسية'},
     'ژمارەی مۆبایل *': {'en': 'Mobile Number *', 'ar': 'رقم الموبايل *'},
     'ناوی دوکان *': {'en': 'Store Name *', 'ar': 'اسم المتجر *'},
     'فرۆشگا': {'en': 'Store', 'ar': 'المتجر'},
     'کاتی کارکردن': {'en': 'Working Hours', 'ar': 'ساعات العمل'},
     'کاتی داخستن': {'en': 'Closing Time', 'ar': 'وقت الإغلاق'},
     'کاتی کردنەوە': {'en': 'Opening Time', 'ar': 'وقت الفتح'},
     'وێنەی دوکان (لۆگۆ و بەرگ)': {'en': 'Store Images (Logo & Cover)', 'ar': 'صور المتجر (الشعار والغلاف)'},
     'وێنەی بەرگ (Cover)': {'en': 'Cover Image', 'ar': 'صورة الغلاف'},
     'گۆڕینی بەرگ': {'en': 'Change Cover', 'ar': 'تغيير الغلاف'},
     'لۆگۆی دوکان (Logo)': {'en': 'Store Logo', 'ar': 'شعار المتجر'},
     'گۆڕینی لۆگۆ': {'en': 'Change Logo', 'ar': 'تغيير الشعار'},
     'زمانی بەرنامە': {'en': 'App Language', 'ar': 'لغة التطبيق'},
     'کوردی': {'en': 'Kurdish', 'ar': 'كردي'},
     'پاشەکەوتکردنی گۆڕانکارییەکان': {'en': 'Save Changes', 'ar': 'حفظ التغييرات'},
     'چوونە دەرەوە لە هەژمار': {'en': 'Log Out', 'ar': 'تسجيل الخروج'},
     'گۆڕانکارییەکان پاشەکەوت کران': {'en': 'Changes Saved', 'ar': 'تم حفظ التغييرات'},
     'هەڵبژاردنی وێنە لە': {'en': 'Choose Image From', 'ar': 'اختر صورة من'},
     'کامێرا': {'en': 'Camera', 'ar': 'الكاميرا'},
     'گەلەری': {'en': 'Gallery', 'ar': 'المعرض'},
     'REGA - LIVE': {'en': 'REGA - LIVE', 'ar': 'ريجا - مباشر'},
     'داواکارییە چالاکەکان': {'en': 'Active Orders', 'ar': 'الطلبات النشطة'},
     'چاوەڕوانکراو': {'en': 'Pending', 'ar': 'قيد الانتظار'},
     'لە ئامادەکردندایە': {'en': 'Preparing', 'ar': 'جاري التجهيز'},
     'ئامادەیە بۆ شۆفێر': {'en': 'Ready for Driver', 'ar': 'جاهز للسائق'},
     'تەواو': {'en': 'Completed', 'ar': 'مكتمل'},
     'پاشگەزبوونەوە': {'en': 'Cancelled', 'ar': 'ملغى'},
     'ڕەتکردنەوە': {'en': 'Reject', 'ar': 'رفض'},
     'قبولکردن': {'en': 'Accept', 'ar': 'قبول'},
     'ڕادەستکردنی داواکاری': {'en': 'Deliver Order', 'ar': 'تسليم الطلب'},
     'هیچ داواکارییەک نییە': {'en': 'No Orders', 'ar': 'لا توجد طلبات'},
     'لە کاتی هاتنی داواکاری لە ئەپی کڕیاران لێرە دەردەکەوێت': {'en': 'When orders arrive from the customer app, they will appear here.', 'ar': 'عند وصول الطلبات من تطبيق العملاء ستظهر هنا'},
     'ئەمڕۆ': {'en': 'Today', 'ar': 'اليوم'},
     'ئەم هەفتەیە': {'en': 'This Week', 'ar': 'هذا الأسبوع'},
     'ئەم مانگە': {'en': 'This Month', 'ar': 'هذا الشهر'},
     'کۆی داواکاری تەواوکراو': {'en': 'Total Completed Orders', 'ar': 'إجمالي الطلبات المكتملة'},
     'ع.د صافی قازانج': {'en': 'IQD Net Profit', 'ar': 'د.ع صافي الربح'},
     'کۆمیسیۆن (١٢٪)': {'en': 'Commission (12%)', 'ar': 'العمولة (١٢٪)'},
     'کۆی فرۆش': {'en': 'Total Sales', 'ar': 'إجمالي المبيعات'},
     'شیکاری داهاتی کاتژمێرەکانی ئەمڕۆ': {'en': 'Today\'s Hourly Revenue Analysis', 'ar': 'تحليل الإيرادات بالساعة لليوم'},
     'شیکاری داهاتی ٧ ڕۆژی ڕابردوو': {'en': 'Past 7 Days Revenue Analysis', 'ar': 'تحليل الإيرادات لآخر ٧ أيام'},
     'شیکاری داهاتی هەفتەکانی ئەم مانگە': {'en': 'This Month\'s Weekly Revenue Analysis', 'ar': 'تحليل الإيرادات الأسبوعية لهذا الشهر'},
     'بەپێی کۆی فرۆش': {'en': 'By Total Sales', 'ar': 'حسب إجمالي المبيعات'},
     'پڕداهاتترین بەرهەمەکان': {'en': 'Top Grossing Products', 'ar': 'المنتجات الأعلى إيراداً'},
     'هیچ فرۆشێک تۆمار نەکراوە تا ئێستا': {'en': 'No sales recorded yet', 'ar': 'لم يتم تسجيل أي مبيعات حتى الآن'},
     'ع.د': {'en': 'IQD', 'ar': 'د.ع'},
     'زیادکردنی بەرهەم': {'en': 'Add Product', 'ar': 'إضافة منتج'},
     'زیادکردنی بەشی نوێ': {'en': 'Add New Category', 'ar': 'إضافة قسم جديد'},
     'تکایە ناوی ئەو بەشە بنووسە کە دەتەوێت زیادی بکەیت': {'en': 'Please enter the name of the category you want to add', 'ar': 'الرجاء إدخال اسم القسم الذي تريد إضافته'},
     'ناوی بەش': {'en': 'Category Name', 'ar': 'اسم القسم'},
     'وێنەی بەش': {'en': 'Category Image', 'ar': 'صورة القسم'},
     'پاشگەزبونەوە': {'en': 'Cancel', 'ar': 'إلغاء'},
     'زیادکردن': {'en': 'Add', 'ar': 'إضافة'},
     'دەستکاریکردنی بەرهەم': {'en': 'Edit Product', 'ar': 'تعديل المنتج'},
     'ناوی بەرهەم *': {'en': 'Product Name *', 'ar': 'اسم المنتج *'},
     'بەش / پۆڵێن *': {'en': 'Category *', 'ar': 'القسم / التصنيف *'},
     'بەشێک هەڵبژێرە': {'en': 'Select Category', 'ar': 'اختر القسم'},
     'نرخی ئاسایی *': {'en': 'Regular Price *', 'ar': 'السعر العادي *'},
     'نرخی دوای داشکان': {'en': 'Price after Discount', 'ar': 'السعر بعد الخصم'},
     'داشکاندنی بەرهەم (٪)': {'en': 'Product Discount (%)', 'ar': 'خصم المنتج (%)'},
     'بێ داشکاندن': {'en': 'No Discount', 'ar': 'بدون خصم'},
     'نرخی دوای داشکاندن': {'en': 'Price after discount', 'ar': 'السعر بعد الخصم'},
     'داشکاندنی دوکان': {'en': 'Store Discount', 'ar': 'خصم المتجر'},
     'داشکاندن بۆ هەموو دوکانەکە': {'en': 'Discount for whole store', 'ar': 'خصم على كل المتجر'},
     'داشکاندن بۆ بەرهەمێک': {'en': 'Discount for one product', 'ar': 'خصم على منتج واحد'},
     'ڕێژەی داشکاندن هەڵبژێرە': {'en': 'Select discount percentage', 'ar': 'اختر نسبة الخصم'},
     'جێبەجێکردنی داشکاندن': {'en': 'Apply Discount', 'ar': 'تطبيق الخصم'},
     'لابردنی داشکاندنی دوکان': {'en': 'Remove store discount', 'ar': 'إزالة خصم المتجر'},
     'داشکاندن بۆ هەموو بەرهەمەکان جێبەجێ دەکرێت': {'en': 'Discount will apply to all products', 'ar': 'سيتم تطبيق الخصم على كل المنتجات'},
     'وەسفی بەرهەم - کوردی (ئارەزوومەندانە)': {'en': 'Product Description - Kurdish (Optional)', 'ar': 'وصف المنتج - كردي (اختياري)'},
     'وەسفی بەرهەم - عەرەبی': {'en': 'Product Description - Arabic', 'ar': 'وصف المنتج - عربي'},
     'وێنەی بەرهەم': {'en': 'Product Image', 'ar': 'صورة المنتج'},
     'هەڵبژاردنی فایل': {'en': 'Choose File', 'ar': 'اختر ملف'},
     'هەڵبژاردن و بارکردنی وێنە': {'en': 'Choose & upload image', 'ar': 'اختيار ورفع صورة'},
     'گۆڕینی وێنە': {'en': 'Change image', 'ar': 'تغيير الصورة'},
     'کرتە بکە بۆ هەڵبژاردنی وێنە': {'en': 'Tap to choose an image', 'ar': 'اضغط لاختيار صورة'},
     'بارکردنی وێنە...': {'en': 'Uploading image...', 'ar': 'جاري رفع الصورة...'},
     'بارکردنی وێنە سەرکەوتوو نەبوو': {'en': 'Image upload failed', 'ar': 'فشل رفع الصورة'},
     'هیچ فایلێک دیاری نەکراوە': {'en': 'No file selected', 'ar': 'لم يتم تحديد ملف'},
     'بەردەست': {'en': 'Available', 'ar': 'متاح'},
     'بەردەستە': {'en': 'Available', 'ar': 'متاح'},
     'نابەردەست': {'en': 'Unavailable', 'ar': 'غير متاح'},
     'تۆمارکردنی بەرهەم': {'en': 'Save Product', 'ar': 'حفظ المنتج'},
     'هیچ بەرهەمێک نەدۆزرایەوە': {'en': 'No Products Found', 'ar': 'لم يتم العثور على منتجات'},
     'دەتوانیت بە کلیک لەسەر دوگمەی (بەرهەمی نوێ) یەکەمین کاڵا زیادبکەیت.': {'en': 'You can add your first item by clicking (Add Product).', 'ar': 'يمكنك إضافة العنصر الأول بالنقر على (إضافة منتج).'},
     'پانیڵى بەڕێوەبردنى فرۆشیاران (REGA Vendor)': {'en': 'Vendor Management Panel (REGA Vendor)', 'ar': 'لوحة إدارة البائعين (REGA Vendor)'},
     'بەخێر بێیت بۆ ئەپی ڕێگا': {'en': 'Welcome to REGA App', 'ar': 'أهلاً بك في تطبيق ريجا'},
     'ژمارەی مۆبایل': {'en': 'Mobile Number', 'ar': 'رقم الموبايل'},
     'وشەی تێپەڕ': {'en': 'Password', 'ar': 'كلمة المرور'},
     'چوونە ژوورەوە': {'en': 'Log In', 'ar': 'تسجيل الدخول'},
     'هێشتا نەبوویتە فرۆشیار لە ئەپی ڕێگا': {'en': 'Not a vendor in REGA App yet?', 'ar': 'لست بائعاً في تطبيق ريجا بعد؟'},
     'خۆت تۆمار بکە': {'en': 'Register', 'ar': 'سجل الآن'},
     'تۆمارکردنی فرۆشگای نوێ': {'en': 'New Shop Registration', 'ar': 'تسجيل متجر جديد'},
     'بۆ بەشداریکردن و کردنەوەی هەژماری فرۆشیار لە ڕێگا، تکایە پەیوەندی بە تیمی پشتگیرییەوە بکە لە ڕێگەی WhatsApp یان Telegram، یان سەردانی نووسینگەمان بکە.': {
       'en': 'To join and open a seller account on REGA, please contact support via WhatsApp or Telegram, or visit our office.',
       'ar': 'للمشاركة وفتح حساب بائع في ريجا، يرجى التواصل مع فريق الدعم عبر واتساب أو تيليجرام، أو زيارة مكتبنا.',
     },
     'باشە': {'en': 'OK', 'ar': 'حسناً'},
     'کراوەیە': {'en': 'Open', 'ar': 'مفتوح'},
     'داخراوە': {'en': 'Closed', 'ar': 'مغلق'},
     'داخستن': {'en': 'Close', 'ar': 'إغلاق'},
     'ڕادەستکردن بە شۆفێر': {
       'en': 'Hand over to driver',
       'ar': 'تسليم للسائق',
     },
  };
}

String t(String key) => Trans.get(key);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (MapboxTiles.accessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(MapboxTiles.accessToken);
  }
  await Trans.loadSavedLang();
  runApp(buildVendorProviders(child: const RegaVendorApp()));
}

class RegaVendorApp extends StatefulWidget {
  const RegaVendorApp({super.key});

  @override
  State<RegaVendorApp> createState() => _RegaVendorAppState();
}

class _RegaVendorAppState extends State<RegaVendorApp> {
  GoRouter? _router;
  /// Keeps catalog/orders state alive across GoRouter shell rebuilds & tab changes.
  final GlobalKey<_MainNavigationScreenState> _shellKey =
      GlobalKey<_MainNavigationScreenState>();
  bool _isOutsideServiceArea = false;
  bool _checkingServiceArea = false;
  Timer? _serviceAreaTimer;

  @override
  void initState() {
    super.initState();
    _initServiceAreaGate();
  }

  Future<void> _initServiceAreaGate() async {
    await _refreshServiceAreaConfig();
    await _checkServiceArea(requestPermission: true);
    _serviceAreaTimer?.cancel();
    _serviceAreaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkServiceArea();
    });
  }

  Future<void> _refreshServiceAreaConfig() async {
    final data = await VendorApiService.instance.fetchSupportContacts();
    if (data.isNotEmpty) {
      ServiceAreaGate.applyFromMap(data);
    }
  }

  Future<void> _checkServiceArea({bool requestPermission = false}) async {
    if (_checkingServiceArea) return;
    _checkingServiceArea = true;
    try {
      final result =
          await ServiceAreaGate.check(requestPermission: requestPermission);
      if (!mounted) return;
      setState(() => _isOutsideServiceArea = result.blocksApp);
    } finally {
      _checkingServiceArea = false;
    }
  }

  @override
  void dispose() {
    _serviceAreaTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createVendorRouter(
      refreshListenable: context.read<VendorSessionNotifier>(),
      loginBuilder: (_) => const LoginScreen(),
      shellBuilder: (context, tabIndex) {
        final s = context.watch<VendorSessionNotifier>();
        return MainNavigationScreen(
          key: _shellKey,
          initialIndex: tabIndex,
          loginPhone: s.phone,
          loginPassword: s.password,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return const SizedBox.shrink();
    }
    if (_isOutsideServiceArea) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'NotoKufiArabic',
        ),
        home: ServiceAreaBlockedScreen(
          onRetry: () async {
            await _refreshServiceAreaConfig();
            await _checkServiceArea(requestPermission: true);
          },
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: Trans.dark,
      builder: (context, isDark, _) => ValueListenableBuilder<String>(
      valueListenable: Trans.lang,
      builder: (context, currentLang, child) {
        // Drives tx(): every on-screen string follows the selected language.
        RegaI18n.setLang(currentLang);
        RC.setDark(isDark);
        return MaterialApp.router(
          title: 'REGA Vendor',
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: 'NotoKufiArabic',
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: 'NotoKufiArabic',
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: RC.darkPage,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFF06400),
              brightness: Brightness.dark,
              primary: const Color(0xFFF06400),
              surface: RC.darkCard,
            ),
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return RegaResponsive.appBuilder(
              context,
              child,
              direction: Trans.direction,
            );
          },
        );
      },
    ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();

  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Trans.direction,
      child: Scaffold(
        backgroundColor: RC.bg(Color(0xFFF8FAFC)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: RegaResponsive.pagePadding(context),
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 430),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: RC.bg(Color(0x0C000000)),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: RegaResponsive.scale(context, 26).clamp(16.0, 26.0),
                    vertical: 34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Logo Badge
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFFEA580C)),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: RC.bg(Colors.white).withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: RC.bg(Color(0xFFEA580C)).withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: _TopBarLogoWidget(
                            primaryPath: kAppLogoFilePath,
                            height: 64,
                            fallbackColor: RC.bg(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 2. Welcome Title & Subtitle
                      Text(
                        t('بەخێر بێیت بۆ ئەپی ڕێگا'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: RC.fg(Color(0xFF0F172A)),
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t('پانیڵى بەڕێوەبردنى فرۆشیاران (REGA Vendor)'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: RC.fg(Color(0xFF64748B)),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // 3. Mobile Number Field
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_iphone_rounded, size: 18, color: RC.fg(Color(0xFFEA580C))),
                            const SizedBox(width: 8),
                            Text(
                              t('ژمارەی مۆبایل'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: RC.fg(Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          inputFormatters: [IraqPhoneFormatter()],
                          decoration: InputDecoration(
                            hintText: txn(IraqPhoneFormatter.hint),
                            hintStyle: TextStyle(color: RC.fgn(Colors.grey[400]), fontSize: 14),
                            filled: true,
                            fillColor: RC.bg(Color(0xFFF8FAFC)),
                            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: RC.fg(Color(0xFF94A3B8))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: RC.bg(Color(0xFFEA580C)), width: 1.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Password Field
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 18, color: RC.fg(Color(0xFFEA580C))),
                            const SizedBox(width: 8),
                            Text(
                              t('وشەی تێپەڕ'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: RC.fg(Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: tx('••••••••'),
                          hintStyle: TextStyle(color: RC.fgn(Colors.grey[400]), fontSize: 14),
                          filled: true,
                          fillColor: RC.bg(Color(0xFFF8FAFC)),
                          prefixIcon: Icon(Icons.lock_outline, size: 18, color: RC.fg(Color(0xFF94A3B8))),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 19,
                              color: RC.fg(Color(0xFF94A3B8)),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: RC.bg(Color(0xFFE2E8F0))),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: RC.bg(Color(0xFFEA580C)), width: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 5. Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              final ok = await VendorApiService.instance.login(
                                _phoneController.text,
                                _passwordController.text,
                              );
                              if (!mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(tx('زانیاری چوونە ژوورەوە هەڵەیە'))),
                                );
                                return;
                              }
                              await context.read<VendorSessionNotifier>().login(
                                phone: _phoneController.text,
                                password: _passwordController.text,
                              );
                              if (!mounted) return;
                              context.go('/orders');
                            } on AccountBlockedException catch (e) {
                              if (!mounted) return;
                              await BlockedAccountContacts.show(context, e);
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(tx('پەیوەندی سێرڤەر سەرکەوتوو نەبوو'))),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(Color(0xFFEA580C)),
                            foregroundColor: RC.fg(Colors.white),
                            elevation: 2,
                            shadowColor: RC.bg(Color(0x40EA580C)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t('چوونە ژوورەوە'),
                                style: TextStyle(
                                  color: RC.fg(Colors.white),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Icon(
                                  Icons.arrow_right_alt_rounded,
                                  color: RC.fg(Colors.white),
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // 6. Register Section
                      Text(
                        t('هێشتا نەبوویتە فرۆشیار لە ئەپی ڕێگا'),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF64748B)),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 7. Register Button — opens support WhatsApp / Telegram dialog
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () async {
                            Map<String, dynamic> contacts = const {};
                            try {
                              contacts = await VendorApiService.instance.fetchSupportContacts();
                            } catch (_) {}
                            if (!context.mounted) return;
                            await BlockedAccountContacts.showSellerRegistrationDialog(
                              context,
                              contactMap: contacts,
                              title: t('تۆمارکردنی فرۆشگای نوێ'),
                              body: t('بۆ بەشداریکردن و کردنەوەی هەژماری فرۆشیار لە ڕێگا، تکایە پەیوەندی بە تیمی پشتگیرییەوە بکە لە ڕێگەی WhatsApp یان Telegram، یان سەردانی نووسینگەمان بکە.'),
                              okLabel: t('باشە'),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: RC.bg(Color(0xFFCBD5E1)), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storefront_outlined, color: RC.fg(Color(0xFFEA580C)), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                t('خۆت تۆمار بکە'),
                                style: TextStyle(
                                  color: RC.fg(Color(0xFFEA580C)),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
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
        ),
      ),
    );
  }
}

// --- Models ---
class Product {
  final String id;
  String name;
  String category;
  double price;
  double costPrice;
  double? discountPrice;
  bool isAvailable;
  String? description;
  String? imagePath;
  String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.costPrice = 0,
    this.discountPrice,
    this.isAvailable = true,
    this.description,
    this.imagePath,
    this.imageUrl,
  });
}

enum OrderStatus { pending, preparing, ready, completed, rejected }

class Order {
  final String id;
  final List<String> items;
  final double total;
  OrderStatus status;
  final DateTime timestamp;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String handoverPin;
  final String? customerNotes;
  final int? dbId;
  String? driverName;
  String? driverPhone;
  String? driverVehicle;
  double? driverLat;
  double? driverLng;
  double? storeLat;
  double? storeLng;
  double? customerLat;
  double? customerLng;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.timestamp,
    this.customerName = '',
    this.customerPhone = '',
    this.deliveryAddress = '',
    this.handoverPin = '',
    this.customerNotes,
    this.dbId,
    this.driverName,
    this.driverPhone,
    this.driverVehicle,
    this.driverLat,
    this.driverLng,
    this.storeLat,
    this.storeLng,
    this.customerLat,
    this.customerLng,
  });
}

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final String? loginPhone;
  final String? loginPassword;
  const MainNavigationScreen({super.key, this.initialIndex = 3, this.loginPhone, this.loginPassword});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex; 
  bool _isOnline = false;
  bool _soundEnabled = true;
  String _language = 'ku';
  String _businessName = t('فرۆشگا');
  Timer? _backendPollTimer;
  final Set<int> _seenBackendOrderIds = {};
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _language = Trans.lang.value;
    _initBackendVendorSync();
  }

  @override
  void didUpdateWidget(covariant MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex &&
        _selectedIndex != widget.initialIndex) {
      setState(() => _selectedIndex = widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _backendPollTimer?.cancel();
    super.dispose();
  }
  
  // Central Dynamic State (Synchronized 100% dynamically with PostgreSQL Backend)
  final List<String> _categories = [];
  final List<Product> _products = [];
  final List<Order> _orders = [];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    context.read<VendorNavNotifier>().setTabIndex(index);
    context.go(VendorNavNotifier.pathForIndex(index));
  }

  OrderStatus _mapBackendVendorStatus(String raw) {
    switch (raw) {
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
      case 'picked_up':
      case 'on_the_way':
      case 'delivered':
        return OrderStatus.completed;
      case 'rejected':
      case 'cancelled':
        return OrderStatus.rejected;
      default:
        return OrderStatus.pending;
    }
  }

  Future<void> _initBackendVendorSync({bool forceRelogin = false}) async {
    try {
      final needsLogin = forceRelogin || !VendorApiService.instance.isAuthenticated;
      if (needsLogin &&
          widget.loginPhone != null &&
          widget.loginPhone!.trim().isNotEmpty &&
          widget.loginPassword != null &&
          widget.loginPassword!.trim().length >= 6) {
        try {
          await VendorApiService.instance.login(
            widget.loginPhone!,
            widget.loginPassword!,
          );
        } on AccountBlockedException catch (e) {
          if (!mounted) return;
          await BlockedAccountContacts.show(context, e);
          if (!mounted) return;
          await context.read<VendorSessionNotifier>().logout();
          if (!mounted) return;
          context.go('/login');
          return;
        }
      } else {
        await VendorApiService.instance.ensureAuthenticated();
      }

      if (!VendorApiService.instance.isAuthenticated) {
        debugPrint('Vendor backend sync skipped: not authenticated');
        return;
      }

      final store = await VendorApiService.instance.fetchStoreProfile();
      final cats = await VendorApiService.instance.fetchCategories();
      final prods = await VendorApiService.instance.fetchProducts();
      await _syncVendorOrdersOnly(initialLoad: true);

      if (!mounted) return;
      setState(() {
        if (store != null) {
          _businessName = store['name_ku']?.toString() ?? _businessName;
          _isOnline = store['is_online'] == true;
        }
        // Replace catalog only when the API succeeded (non-null). Empty list is valid.
        if (cats != null) {
          _categories
            ..clear()
            ..addAll(cats
                .map((c) => (c as Map<String, dynamic>)['name_ku']?.toString() ?? '')
                .where((s) => s.isNotEmpty));
        }
        if (prods != null) {
          _products
            ..clear()
            ..addAll(prods.map((raw) {
              final p = raw as Map<String, dynamic>;
              return Product(
                id: '${p['id']}',
                name: p['name_ku']?.toString() ?? '',
                category: p['store_category']?['name_ku']?.toString() ??
                    (_categories.isNotEmpty ? _categories.first : 'گشتی'),
                price: ((p['price'] as num?) ?? 0).toDouble(),
                costPrice: ((p['cost_price'] as num?) ?? 0).toDouble(),
                discountPrice: (p['discount_price'] as num?)?.toDouble(),
                isAvailable: p['is_available'] == true,
                description: p['description_ku']?.toString(),
                imageUrl: () {
                  final u = VendorApiService.instance.resolveMediaUrl(p['image_url']?.toString());
                  return u.isEmpty ? null : u;
                }(),
              );
            }));
        }
      });

      _backendPollTimer?.cancel();
      _backendPollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _syncVendorOrdersOnly(initialLoad: false),
      );
    } catch (e) {
      debugPrint('Vendor backend sync fallback: $e');
    }
  }

  Future<void> _syncVendorOrdersOnly({required bool initialLoad}) async {
    try {
      final list = await VendorApiService.instance.fetchOrders();
      if (!mounted || list.isEmpty) return;

      bool hasBrandNewPending = false;
      final parsed = <Order>[];

      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final dbId = (m['id'] as num?)?.toInt();
        final vStatus = m['vendor_status']?.toString() ?? m['status']?.toString() ?? 'pending';
        if (dbId != null && !_seenBackendOrderIds.contains(dbId)) {
          _seenBackendOrderIds.add(dbId);
          if (!initialLoad && vStatus == 'pending') {
            hasBrandNewPending = true;
          }
        }

        final itemsList = (m['items'] as List<dynamic>? ?? [])
            .map((it) {
              final im = it as Map<String, dynamic>;
              return '${im['quantity'] ?? 1}x ${im['product_name'] ?? ''}';
            })
            .toList();

        parsed.add(
          Order(
            id: '${m['order_number'] ?? 'RA-$dbId'}#',
            dbId: dbId,
            items: itemsList.isEmpty ? ['1x داواکاری'] : itemsList,
            total: ((m['subtotal'] ?? m['total_amount'] ?? 0) as num).toDouble(),
            status: _mapBackendVendorStatus(vStatus),
            timestamp: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
            customerName: m['customer_name']?.toString() ?? m['customer']?['name']?.toString() ?? 'کڕیار',
            customerPhone: m['customer_phone']?.toString() ?? m['customer']?['phone']?.toString() ?? '',
            deliveryAddress: m['delivery_address']?.toString() ?? '',
            handoverPin: m['handover_pin']?.toString() ?? '',
            customerNotes: m['customer_notes']?.toString(),
            driverName: m['driver']?['name']?.toString(),
            driverPhone: m['driver']?['phone']?.toString(),
            driverVehicle: m['driver']?['driver_profile']?['plate_number']?.toString() ??
                m['driver']?['driver_profile']?['motor_type']?.toString(),
            driverLat: (m['driver_lat'] as num?)?.toDouble() ??
                (m['driver']?['lat'] as num?)?.toDouble() ??
                (m['driver']?['current_lat'] as num?)?.toDouble(),
            driverLng: (m['driver_lng'] as num?)?.toDouble() ??
                (m['driver']?['lng'] as num?)?.toDouble() ??
                (m['driver']?['current_lng'] as num?)?.toDouble(),
            storeLat: (m['store_lat'] as num?)?.toDouble(),
            storeLng: (m['store_lng'] as num?)?.toDouble(),
            customerLat: (m['customer_lat'] as num?)?.toDouble() ?? (m['delivery_lat'] as num?)?.toDouble(),
            customerLng: (m['customer_lng'] as num?)?.toDouble() ?? (m['delivery_lng'] as num?)?.toDouble(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(parsed);
      });

      if (hasBrandNewPending && _soundEnabled) {
        OrderSoundService.playNewOrderAlert(soundEnabled: _soundEnabled);
      }
    } catch (_) {}
  }

  void _legacyUnusedHook(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleProductAvailability(String id) {
    setState(() {
      final product = _products.firstWhere((p) => p.id == id);
      product.isAvailable = !product.isAvailable;
      final pid = int.tryParse(id);
      if (pid != null) {
        VendorApiService.instance.toggleProductAvailability(pid);
      }
    });
  }

  void _deleteProduct(String id) {
    setState(() {
      _products.removeWhere((p) => p.id == id);
      final pid = int.tryParse(id);
      if (pid != null) {
        VendorApiService.instance.deleteProduct(pid);
      }
    });
  }

  void _updateOrderStatus(String id, OrderStatus newStatus) {
    final order = _orders.firstWhere((o) => o.id == id);
    final dbId = order.dbId;

    if (newStatus == OrderStatus.completed && dbId != null) {
      VendorApiService.instance.handoverToDriver(dbId).then((res) {
        if (!mounted) return;
        final (ok, msg) = res;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(msg)),
            backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFE50010)),
          ),
        );
        if (ok) {
          setState(() => order.status = OrderStatus.completed);
          _syncVendorOrdersOnly(initialLoad: false);
        }
      });
      return;
    }

    setState(() {
      order.status = newStatus;
      if (dbId != null) {
        if (newStatus == OrderStatus.preparing) {
          VendorApiService.instance.acceptOrder(dbId);
        } else if (newStatus == OrderStatus.ready) {
          VendorApiService.instance.markReady(dbId).then((res) {
            final (ok, msg, data) = res;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tx(msg)),
                  backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFEA580C)),
                  duration: const Duration(seconds: 4),
                ),
              );
              _syncVendorOrdersOnly(initialLoad: false);
            }
          });
        } else if (newStatus == OrderStatus.rejected) {
          VendorApiService.instance.rejectOrder(dbId);
        }
      }
    });
  }

  Future<void> _addProduct(Product product) async {
    setState(() => _products.add(product));
    final saved = await VendorApiService.instance.addProduct(
      nameKu: product.name,
      categoryName: product.category,
      price: product.price.round(),
      costPrice: product.costPrice.round(),
      discountPrice: product.discountPrice?.round(),
      descriptionKu: product.description,
      imageUrl: product.imageUrl,
      isAvailable: product.isAvailable,
    );
    if (!mounted) return;
    if (saved == null) {
      setState(() => _products.removeWhere((p) => p.id == product.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('پاشەکەوتکردنی بەرهەم سەرکەوتوو نەبوو — تکایە دووبارە هەوڵ بدە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(Color(0xFFE50010)),
        ),
      );
      return;
    }
    // Reload from server so local IDs/images match persisted rows after leave/logout.
    await _initBackendVendorSync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx('بەرهەم پاشەکەوت کرا'), textAlign: TextAlign.center),
        backgroundColor: RC.bg(Color(0xFF00894C)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addCategory(String category, {String? imageUrl}) async {
    if (_categories.contains(category)) return;
    setState(() => _categories.add(category));
    final id = await VendorApiService.instance.addCategory(category, imageUrl: imageUrl);
    if (!mounted) return;
    if (id == null) {
      setState(() => _categories.remove(category));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('پاشەکەوتکردنی بەش سەرکەوتوو نەبوو — تکایە دووبارە هەوڵ بدە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(Color(0xFFE50010)),
        ),
      );
      return;
    }
    await _initBackendVendorSync();
  }

  void _deleteCategory(String category) {
    setState(() {
      _categories.remove(category);
      VendorApiService.instance.deleteCategoryByName(category);
    });
  }

  void _editProduct(Product product) {
    setState(() {
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        final pid = int.tryParse(product.id);
        if (pid != null) {
          VendorApiService.instance.updateProduct(
            productId: pid,
            nameKu: product.name,
            categoryName: product.category,
            price: product.price.round(),
            costPrice: product.costPrice.round(),
            discountPrice: product.discountPrice?.round(),
            descriptionKu: product.description,
            imageUrl: product.imageUrl,
            isAvailable: product.isAvailable,
          );
        }
      }
    });
  }

  Future<void> _applyStoreWideDiscount(int percent) async {
    final (ok, msg) = await VendorApiService.instance.applyStoreDiscount(percent);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(msg), textAlign: TextAlign.center),
        backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFE50010)),
      ),
    );
    if (ok) {
      await _initBackendVendorSync();
    }
  }

  /// Online/Offline Capsule Switch styled exactly after reference (Image 2)
  Widget _buildOnlineOfflineSwitch() {
    return Semantics(
      button: true,
      toggled: _isOnline,
      label: _isOnline ? 'Online' : 'Offline',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isOnline = !_isOnline;
            VendorApiService.instance.updateOnlineStatus(_isOnline);
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: RC.bg(Colors.black).withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: RC.bg(Colors.white).withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 22,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _isOnline ? RC.bg(const Color(0xFF10B981)) : RC.bg(Colors.black45),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: RC.bg(Colors.black26),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SettingsScreen(
        businessName: _businessName,
        onNameChange: (val) {
          setState(() => _businessName = val);
          VendorApiService.instance.updateStoreInfo(nameKu: val);
        },
        language: Trans.lang.value,
        onLangChange: (val) { Trans.setLang(val); setState(() => _language = val); },
      ),
      RevenueScreen(
        orders: _orders,
        onRefresh: () => _syncVendorOrdersOnly(initialLoad: false),
      ),
      ProductsScreen(
        products: _products, 
        categories: _categories,
        onToggle: _toggleProductAvailability,
        onDelete: _deleteProduct,
        onAdd: _addProduct,
        onEdit: _editProduct,
        onAddCategory: _addCategory,
        onDeleteCategory: _deleteCategory,
        onStoreDiscount: _applyStoreWideDiscount,
      ),
      OrdersScreen(
        orders: _orders,
        onUpdateStatus: _updateOrderStatus,
        onOrdersChanged: () => _syncVendorOrdersOnly(initialLoad: false),
        onSimulate: () {
          OrderSoundService.playNewOrderAlert(soundEnabled: true);
        },
      ),
    ];

    bool isRtl = _language != 'en';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: 80,
            titleSpacing: 14,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [RC.bg(Color(0xFFD97706)), RC.bg(Color(0xFFEA580C))],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: RC.bg(Color(0x33000000)),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            title: SizedBox(
              width: double.infinity,
              height: 52,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final storeLeading = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: RC.bg(Colors.white).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: RC.bg(Colors.white).withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  color: RC.fg(Colors.white),
                                  size: 24,
                                ),
                              ),
                              Positioned(
                                bottom: -1,
                                right: -1,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: _isOnline ? RC.bg(const Color(0xFF10B981)) : RC.bg(const Color(0xFFF43F5E)),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: RC.bg(const Color(0xFFD97706)), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width < RegaBreakpoints.phone ? 120 : 260,
                            ),
                            child: Text(
                              tx(_businessName),
                              style: TextStyle(
                                color: RC.fg(Colors.white),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );

                      final actionTrailing = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sound Button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _soundEnabled = !_soundEnabled;
                              });
                              if (_soundEnabled) {
                                OrderSoundService.playTestTone();
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(tx('دەنگی ئاگادارکردنەوەی داواکاری چالاک کرا 🔔'), textAlign: TextAlign.center),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(tx('دەنگی ئاگادارکردنەوە بێدەنگ کرا 🔕'), textAlign: TextAlign.center),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _soundEnabled
                                    ? RC.bg(Colors.white).withOpacity(0.2)
                                    : RC.bg(Colors.black).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _soundEnabled
                                      ? RC.bg(Colors.white).withOpacity(0.35)
                                      : RC.bg(Colors.white).withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _soundEnabled ? Icons.volume_up : Icons.volume_off,
                                color: _soundEnabled ? RC.fg(Colors.white) : RC.bg(Colors.white70),
                                size: 19,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Online/Offline Capsule Switch
                          _buildOnlineOfflineSwitch(),
                        ],
                      );

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              storeLeading,
                              actionTrailing,
                            ],
                          ),
                          _buildTopLogo(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
    ),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        border: Border(
          top: BorderSide(
            color: RC.bg(Color(0xFFF1F5F9)),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Color(0xFF0F172A)).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  // 1. Far Right in RTL: داواکارییەکان (Orders) - index 3
                  _buildNavItem(
                    3,
                    Icons.receipt_long_rounded,
                    Icons.receipt_long_outlined,
                    t('داواکارییەکان'),
                    hasNotification: true,
                  ),
                  // 2. Next in RTL: مێنۆ و بەرهەم (Menu & Products) - index 2
                  _buildNavItem(
                    2,
                    Icons.restaurant_menu_rounded,
                    Icons.restaurant_menu_outlined,
                    t('مێنۆ و بەرهەم'),
                  ),
                  // 3. Next in RTL: داهاتی فرۆشیار (Seller Revenue) - index 1
                  _buildNavItem(
                    1,
                    Icons.trending_up_rounded,
                    Icons.trending_up_rounded,
                    t('داهاتی فرۆشیار'),
                  ),
                  // 4. Far Left in RTL: ڕێکخستن (Settings) - index 0
                  _buildNavItem(
                    0,
                    Icons.tune_rounded,
                    Icons.tune_rounded,
                    t('ڕێکخستن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label, {
    bool hasNotification = false,
  }) {
    final bool isSelected = _selectedIndex == index;
    const primeOrange = Color(0xFFEA580C);
    final iconColor = isSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF64748B));
    final textColor = isSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF64748B));

    // Notification badge on orders (index 3)
    final pendingCount = _orders.where((o) => o.status == OrderStatus.pending).length;
    final int badgeCount = pendingCount > 0 ? pendingCount : 1;
    final bool showBadge = hasNotification && pendingCount > 0;

    return Expanded(
      flex: isSelected ? 2 : 1,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _onItemTapped(index);
        },
        splashColor: primeOrange.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 14 : 8,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primeOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primeOrange.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      color: iconColor,
                      size: 20,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: isSelected
                          ? Padding(
                              padding: const EdgeInsetsDirectional.only(start: 6),
                              child: Text(
                                tx(label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              if (showBadge)
                Positioned(
                  top: -2,
                  right: isSelected ? 4 : -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFEF4444)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: RC.bg(Colors.white), width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        tx('$badgeCount'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RC.fg(Colors.white),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  // ============================================================================
  // 📌 ویجێتی لۆگۆی سەرەوە (بە شێوازی زیرەکانە و فرە-قۆناغ فایلی لۆکاڵ و ئاسێت دەدۆزێتەوە)
  // ============================================================================
  Widget _buildTopLogo() {
    return const IgnorePointer(
      child: _TopBarLogoWidget(
        primaryPath: kAppLogoFilePath,
        height: 44,
      ),
    );
  }
}

class _TopBarLogoWidget extends StatelessWidget {
  final String primaryPath;
  final double height;
  final Color? fallbackColor;

  const _TopBarLogoWidget({
    Key? key,
    required this.primaryPath,
    this.height = 48,
    this.fallbackColor,
  }) : super(key: key);

  List<String> _buildCandidateList() {
    final List<String> list = [];
    final cleanPrimary = primaryPath.trim();
    if (cleanPrimary.isNotEmpty && !list.contains(cleanPrimary)) {
      list.add(cleanPrimary);
    }
    const defaultCandidates = [
      'assets/logo REGA 1 ar.png',
      'assets/logo_rega.png',
      'assets/logo.png',
      'assets/logo.jpg',
      'assets/logo.jpeg',
      'assets/images/logo.png',
      'assets/images/logo.jpg',
    ];
    for (final candidate in defaultCandidates) {
      if (!list.contains(candidate)) {
        list.add(candidate);
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final clean = primaryPath.trim();

    // ١. ئەگەر بەستەری ئۆنلاین بێت (Online URL)
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildChain(context, _buildCandidateList(), 0),
      );
    }

    // ٢. ئەگەر Base64 کۆد کرابێت (Base64 Image)
    if (clean.startsWith('data:image') || clean.length > 500) {
      try {
        final String base64Clean = clean.contains(',') ? clean.split(',').last : clean;
        final bytes = base64Decode(base64Clean);
        return Image.memory(
          bytes,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildChain(context, _buildCandidateList(), 0),
        );
      } catch (_) {}
    }

    // ٣. پشکنینی فایلی فیزیکی ڕەها (Absolute Local File Path)
    if (!kIsWeb && (clean.startsWith('/') || clean.contains(':\\') || clean.startsWith('file:'))) {
      try {
        final file = File(clean.replaceFirst('file://', ''));
        if (file.existsSync()) {
          return Image.file(
            file,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildChain(context, _buildCandidateList(), 0),
          );
        }
      } catch (_) {}
    }

    // ٤. بارکردنی ئاسێتی فەرمی Flutter بەبێ دروستبوونی هیچ ئیڕۆڕێکی سیستەم
    final candidates = _buildCandidateList();
    return _buildChain(context, candidates, 0);
  }

  Widget _buildChain(BuildContext context, List<String> candidates, int index) {
    if (index >= candidates.length) {
      // ئەگەر لە ناو هیچ کام لە فایلەکان نەدۆزرایەوە، لینکی فەرمی بەکار دەهێنێت
      return Image.network(
        'https://i.postimg.cc/CKsXsdD6/logo-REGA-png.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildLogoFallbackText(),
      );
    }

    final currentPath = candidates[index];

    return Image.asset(
      currentPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildChain(context, candidates, index + 1);
      },
    );
  }

  Widget _buildLogoFallbackText() {
    final effectiveColor = fallbackColor ?? RC.bg(Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          tx('REGA'),
          style: TextStyle(
            color: effectiveColor,
            fontSize: height > 55 ? 18 : 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          tx('ڕێگا'),
          style: TextStyle(
            color: effectiveColor,
            fontSize: height > 55 ? 12 : 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// --- Screens ---

String getOrderItemImageUrl(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('پیتزا') || lower.contains('pizza') || lower.contains('پێپەرۆنی') || lower.contains('مارگاریتا')) {
    return 'https://images.unsplash.com/photo-1628840042765-356cda07504e?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('بەرگر') || lower.contains('burger') || lower.contains('برغر') || lower.contains('همبرغر')) {
    return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('کۆلا') || lower.contains('cola') || lower.contains('پپسی') || lower.contains('pepsi') || lower.contains('ئاوی') || lower.contains('شەربەت') || lower.contains('خواردنەوە')) {
    return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('مریشک') || lower.contains('کریسپی') || lower.contains('شاوەرمە') || lower.contains('chicken') || lower.contains('گۆشت')) {
    return 'https://images.unsplash.com/photo-1562967914-608f82629710?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('پەتاتە') || lower.contains('fries') || lower.contains('فینگە')) {
    return 'https://images.unsplash.com/photo-1576107232684-1279f3908594?q=80&w=240&auto=format&fit=crop';
  }
  return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=240&auto=format&fit=crop';
}

String formatAmountOnly(int amount) {
  return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
}

String formatPrice(int amount) {
  return 'د.ع ${formatAmountOnly(amount)}';
}

int getEstimatedItemPrice(String name, int qty) {
  final lower = name.toLowerCase();
  int unitPrice = 5000;
  if (lower.contains('پێپەرۆنی') || lower.contains('pepperoni')) {
    unitPrice = 8500;
  } else if (lower.contains('مەرگەریتا') || lower.contains('مارگاریتا') || lower.contains('سەوزە')) {
    unitPrice = 7000;
  } else if (lower.contains('پیتزا') || lower.contains('pizza')) {
    unitPrice = 7500;
  } else if (lower.contains('بەرگر') || lower.contains('burger')) {
    unitPrice = 6000;
  } else if (lower.contains('کریسپی') || lower.contains('crispy') || lower.contains('مریشک')) {
    unitPrice = 7500;
  } else if (lower.contains('کۆلا') || lower.contains('cola') || lower.contains('pepsi') || lower.contains('پپسی')) {
    unitPrice = 1000;
  } else if (lower.contains('ئاو') || lower.contains('water')) {
    unitPrice = 500;
  } else if (lower.contains('پەتاتە') || lower.contains('fries')) {
    unitPrice = 2500;
  } else if (lower.contains('سۆس') || lower.contains('sauce')) {
    unitPrice = 500;
  }
  return unitPrice * (qty <= 0 ? 1 : qty);
}

String getProductImageUrl(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('پیتزا') || lower.contains('pizza') || lower.contains('پێپەرۆنی') || lower.contains('پێپەڕۆنی') || lower.contains('مارگاریتا') || lower.contains('مەرگەریتا')) {
    return 'https://images.unsplash.com/photo-1628840042765-356cda07504e?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('بەرگر') || lower.contains('burger') || lower.contains('برغر') || lower.contains('همبرغر')) {
    return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('کۆلا') || lower.contains('cola') || lower.contains('پپسی') || lower.contains('pepsi') || lower.contains('سۆدا') || lower.contains('خواردنەوە')) {
    return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('مریشک') || lower.contains('کریسپی') || lower.contains('شاوەرمە') || lower.contains('کەباب') || lower.contains('گۆشت')) {
    return 'https://images.unsplash.com/photo-1562967914-608f82629710?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('پەتاتە') || lower.contains('فینگە') || lower.contains('fries')) {
    return 'https://images.unsplash.com/photo-1576107232684-1279f3908594?q=80&w=300&auto=format&fit=crop';
  }
  return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=300&auto=format&fit=crop';
}

void showFullScreenImageDialog(BuildContext context, {String? imageUrl, ImageProvider? imageProvider, String? title}) {
  showDialog(
    context: context,
    barrierColor: RC.bg(Colors.black).withOpacity(0.85),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.75;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: RegaResponsive.dialogInset(ctx),
          child: SizedBox(
            height: maxH,
            width: RegaResponsive.dialogMaxWidth(ctx),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (title != null && title.isNotEmpty)
                      Expanded(
                        child: Text(
                          tx(title),
                          style: TextStyle(
                            color: RC.fg(Colors.white),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: RC.bg(Colors.white).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: RC.fg(Colors.white), size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      maxScale: 4.0,
                      minScale: 0.8,
                      child: imageProvider != null
                          ? Image(
                              image: imageProvider,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: RC.fg(Colors.white70), size: 64),
                            )
                          : Image.network(
                              imageUrl ?? '',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: RC.fg(Colors.white70), size: 64),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class OrdersScreen extends StatefulWidget {
  final List<Order> orders;
  final Function(String, OrderStatus) onUpdateStatus;
  final VoidCallback onSimulate;
  final VoidCallback? onOrdersChanged;

  const OrdersScreen({
    super.key,
    required this.orders,
    required this.onUpdateStatus,
    required this.onSimulate,
    this.onOrdersChanged,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> get orders => widget.orders;
  Function(String, OrderStatus) get onUpdateStatus => widget.onUpdateStatus;
  VoidCallback get onSimulate => widget.onSimulate;

  List<Map<String, dynamic>> _drivers = [];
  String? _selectedOrderId;
  Timer? _driversTimer;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _driversTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadDrivers());
  }

  @override
  void dispose() {
    _driversTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    final data = await VendorApiService.instance.fetchNearbyDrivers();
    if (!mounted || data == null) return;
    final list = (data['drivers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    list.sort((a, b) {
      final ao = a['is_online'] == true ? 0 : 1;
      final bo = b['is_online'] == true ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      final ad = (a['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final bd = (b['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      if (ad != bd) return ad.compareTo(bd);
      final at = (a['today_orders'] as num?)?.toInt() ?? 0;
      final bt = (b['today_orders'] as num?)?.toInt() ?? 0;
      return at.compareTo(bt);
    });
    setState(() => _drivers = list);
  }

  Order? get _selectedOrder {
    if (_selectedOrderId == null) return null;
    for (final o in orders) {
      if (o.id == _selectedOrderId) return o;
    }
    return null;
  }

  Future<void> _assignDriverToOrder(Order order, Map<String, dynamic> driver) async {
    final dbId = order.dbId;
    final driverUserId = (driver['user_id'] as num?)?.toInt();
    if (dbId == null || driverUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('داواکاری یان ماتۆرسوار نادروستە')), backgroundColor: RC.bg(Color(0xFFE50010))),
      );
      return;
    }
    final (ok, msg, data) = await VendorApiService.instance.assignDriver(dbId, driverUserId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx(msg)), backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFE50010))),
    );
    if (ok) {
      final nested = data?['driver'] as Map<String, dynamic>?;
      setState(() {
        order.driverName = nested?['name']?.toString() ?? driver['name']?.toString() ?? order.driverName;
        order.driverPhone = nested?['phone']?.toString() ?? driver['phone']?.toString() ?? order.driverPhone;
      });
      widget.onOrdersChanged?.call();
    }
  }

  String _fmtDriverDistance(dynamic meters) {
    final m = (meters as num?)?.toDouble();
    if (m == null) return 'بێ GPS';
    if (m < 1000) return '${m.round()} م';
    return '${(m / 1000).toStringAsFixed(1)} کم';
  }

  Future<void> _showAssignDriverDialog(Order order) async {
    setState(() => _selectedOrderId = order.id);
    await _loadDrivers();
    final drivers = List<Map<String, dynamic>>.from(_drivers);
    drivers.sort((a, b) {
      final ao = a['is_online'] == true ? 0 : 1;
      final bo = b['is_online'] == true ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      final ad = (a['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final bd = (b['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      return ad.compareTo(bd);
    });
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: RegaResponsive.dialogInset(ctx, cap: 440),
          title: Text(tx('دیاریکردنی ماتۆرسوار بۆ ${order.id}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: RegaResponsive.dialogMaxWidth(ctx, cap: 440),
            height: 420,
            child: drivers.isEmpty
                ? Center(child: Text(tx('هیچ ماتۆرسوارێک بەردەست نییە')))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tx('نزیکترین بۆ فرۆشگاکەت یەکەمە — ئەمڕۆ چەند داواکاری گەیاندوویەتی'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Colors.grey.shade700)),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: drivers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final d = drivers[idx];
                            final online = d['is_online'] == true;
                            final today = (d['today_deliveries'] as num?)?.toInt() ?? 0;
                            final todayAssigned = (d['today_orders'] as num?)?.toInt() ?? 0;
                            final near = idx == 0 && d['distance_meters'] != null ? ' · نزیکترین' : '';
                            final phone = RegaResponsive.isPhone(ctx);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: phone
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.two_wheeler_rounded, color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tx('${d['name'] ?? ''} (${d['driver_code'] ?? ''})$near'),
                                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    tx('${online ? '🟢 ئۆنلاین' : '⚫ ئۆفلاین'} • ${_fmtDriverDistance(d['distance_meters'])}\n'
                                                    'ئەمڕۆ: $today گەیاندن · $todayAssigned داواکاری • ${IraqPhoneFormatter.display((d['phone'] ?? '').toString())}'),
                                                    style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade700), height: 1.35),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: RC.bg(Color(0xFF16A34A)),
                                              foregroundColor: RC.fg(Colors.white),
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await _assignDriverToOrder(order, d);
                                            },
                                            child: Text(tx(online ? 'پێدان' : 'دیاریکردن')),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.two_wheeler_rounded, color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey)),
                                      title: Text(tx('${d['name'] ?? ''} (${d['driver_code'] ?? ''})$near'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                      subtitle: Text(
                                        tx('${online ? '🟢 ئۆنلاین' : '⚫ ئۆفلاین'} • ${_fmtDriverDistance(d['distance_meters'])}\n'
                                        'ئەمڕۆ: $today گەیاندن · $todayAssigned داواکاری • ${IraqPhoneFormatter.display((d['phone'] ?? '').toString())}'),
                                      ),
                                      isThreeLine: true,
                                      trailing: ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: RC.bg(Color(0xFF16A34A)), foregroundColor: RC.fg(Colors.white)),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await _assignDriverToOrder(order, d);
                                        },
                                        child: Text(tx(online ? 'پێدان' : 'دیاریکردن')),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(const Color(0xFFDC2626)),
                  foregroundColor: RC.fg(Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  t('داخستن'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RC.fg(Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = orders
        .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.rejected)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  RegaResponsive.pagePadding(context),
                  16,
                  RegaResponsive.pagePadding(context),
                  8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      t('داواکارییە چالاکەکان'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    ElevatedButton.icon(
                      onPressed: onSimulate,
                      icon: Icon(Icons.notifications_active_rounded, size: 18, color: RC.fg(Colors.white)),
                      label: Text(
                        tx('تاقیکردنەوەی دەنگ'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: RC.fg(Colors.white),
                          letterSpacing: 0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(const Color(0xFFFF6418)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: activeOrders.isEmpty
                    ? _buildEmptyState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final padH = RegaResponsive.pagePadding(context);
                          final crossAxisCount = RegaResponsive.gridCountForWidth(
                            constraints.maxWidth,
                            phone: 1,
                            tablet: 2,
                            desktop: 3,
                          );
                          if (crossAxisCount == 1) {
                            return ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: padH, vertical: 6),
                              itemCount: activeOrders.length,
                              itemBuilder: (context, index) {
                                return _buildOrderCard(context, activeOrders[index]);
                              },
                            );
                          }
                          if (activeOrders.length == 1) {
                            return Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 540),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: 6),
                                  child: _buildOrderCard(context, activeOrders.first),
                                ),
                              ),
                            );
                          }
                          return GridView.builder(
                            padding: EdgeInsets.symmetric(horizontal: padH, vertical: 6),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: crossAxisCount >= 3 ? 420 : 440,
                            ),
                            itemCount: activeOrders.length,
                            itemBuilder: (context, index) {
                              return _buildOrderCard(context, activeOrders[index]);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final formattedPrice = '${order.total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع';
    String idDisplay = order.id;
    if (!idDisplay.endsWith('#') && !idDisplay.startsWith('#')) {
      idDisplay = '$idDisplay#';
    }
    final selected = _selectedOrderId == order.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedOrderId = order.id),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFFFEDD5)),
          width: selected ? 2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Order ID (Right) & Status Badge + Price Pill (Left) in RTL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              // Order ID badge on the right
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: RC.bg(Colors.black).withOpacity(0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  tx(idDisplay),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: RC.fg(Color(0xFF0F172A)),
                    letterSpacing: 0,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Status Badge & Price Pill on the left (FittedBox prevents any RenderFlex overflow)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(order.status),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFF0F172A)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tx(formattedPrice),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: RC.fg(Colors.white),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Items
          ...order.items.map((item) => _buildOrderItem(item)),
          GestureDetector(
            onTap: () => _showAssignDriverDialog(order),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                    ? RC.bg(Color(0xFFF0FDF4))
                    : RC.bg(Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                      ? RC.bg(Color(0xFFBBF7D0))
                      : RC.bg(Color(0xFFFECACA)),
                ),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    Icons.two_wheeler_rounded,
                    size: 20,
                    color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                        ? RC.fg(Color(0xFF16A34A))
                        : RC.bg(Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx((order.driverName != null && order.driverName!.trim().isNotEmpty)
                          ? 'ماتۆرسوار: ${order.driverName} (${IraqPhoneFormatter.display(order.driverPhone ?? "")})'
                          : 'ماتۆرسوار: دیاری نەکراوە — کرتە بکە بۆ هەڵبژاردن'),
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                            ? RC.bg(Color(0xFF166534))
                            : RC.bg(Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                        ? RC.fg(Color(0xFF16A34A))
                        : RC.bg(Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ),
          if (order.driverName != null && order.driverName!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AssignedDriverMap(
                orderNumber: order.id,
                storeLat: order.storeLat,
                storeLng: order.storeLng,
                customerLat: order.customerLat,
                customerLng: order.customerLng,
                initialDriverLat: order.driverLat,
                initialDriverLng: order.driverLng,
                driverName: order.driverName,
                height: 170,
              ),
            ),

          // Customer Notes Box (بۆکسی تێبینی - Cyber Cyan لە وێنەکەدا)
          if (order.customerNotes != null && order.customerNotes!.trim().isNotEmpty) ...[
            _buildCustomerNotesBox(order.customerNotes!),
            const SizedBox(height: 6),
          ],

          // Time badge & Details Button Row (ڕاست: وردەکاری داواکاری, چەپ: کاتژمێر)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              GestureDetector(
                onTap: () => _showOrderDetails(context, order),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx('وردەکاری داواکاری'),
                      style: TextStyle(
                        color: RC.fg(Color(0xFF475569)),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: RC.fg(Color(0xFF475569)),
                      size: 18,
                    ),
                  ],
                ),
              ),
              _buildTimeBadge(order.timestamp),
            ],
          ),

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              ..._buildActionButtons(context, order),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAssignDriverDialog(order),
              icon: const Icon(Icons.two_wheeler_rounded, size: 17),
              label: Text(
                tx((order.driverName != null && order.driverName!.trim().isNotEmpty)
                    ? 'گۆڕینی ماتۆرسوار'
                    : 'ناردنی ماتۆرسوار'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: RC.fg(Color(0xFF16A34A)),
                side: BorderSide(color: RC.bg(Color(0xFF16A34A))),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildOrderItem(String itemText) {
    int qtyNumber = 1;
    String name = itemText.trim();

    final arabicToStandard = {
      '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5',
      '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };

    final regex = RegExp(r'^([0-9١-٩]+)\s*[xX*×]\s*(.*)$');
    final match = regex.firstMatch(itemText.trim());
    if (match != null) {
      String numPart = match.group(1)!;
      arabicToStandard.forEach((k, v) {
        numPart = numPart.replaceAll(k, v);
      });
      qtyNumber = int.tryParse(numPart) ?? 1;
      name = match.group(2)!.trim();
    }

    final rawItemPrice = getEstimatedItemPrice(name, 1);
    final itemPriceAmount = formatAmountOnly(rawItemPrice);
    final imgUrl = getProductImageUrl(name);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 360;
        final imgSize = isSmall ? 62.0 : 72.0;
        final gap = isSmall ? 10.0 : 14.0;
        final priceFontSize = isSmall ? 14.5 : 16.0;
        final nameFontSize = isSmall ? 13.5 : 14.5;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: 12),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: RC.bg(Colors.black).withOpacity(0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl, // RTL: First child (Image) on Right, Last child (Price) on Left
            children: [
              // وێنەی بەرهەم لە لای ڕاست (Image on the right)
              GestureDetector(
                onTap: () => showFullScreenImageDialog(context, imageUrl: imgUrl, title: name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imgUrl,
                    width: imgSize,
                    height: imgSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: imgSize,
                      height: imgSize,
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFFFF2E8)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.fastfood_rounded, size: 28, color: RC.fg(Color(0xFFFF6418))),
                    ),
                  ),
                ),
              ),

              SizedBox(width: gap),

              // ناوی بەرهەم (لە تەنیشت وێنە بەبێ Bold، ڕاست‌چین)
              Expanded(
                child: Text(
                  tx(name),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: nameFontSize,
                    color: RC.fg(Color(0xFF0F172A)),
                    letterSpacing: 0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(width: gap),

              // نرخ و بڕی داواکاری لە لای چەپ (د.ع 8,500  X 1 وەک ناو وێنەکە)
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.ltr,
                    children: [
                      Text(
                        tx('د.ع'),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF64748B)),
                          fontWeight: FontWeight.normal,
                          fontSize: 13,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tx(itemPriceAmount),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF0F172A)),
                          fontWeight: FontWeight.normal,
                          fontSize: priceFontSize,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        tx('X $qtyNumber'),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF10B981)), // ڕەنگی سەوز لە وێنەکەدا
                          fontWeight: FontWeight.normal,
                          fontSize: priceFontSize,
                          letterSpacing: 0,
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
  }

  /// بۆکسی تێبینی کڕیار (ڕەنگی گەرمی نیشانەی تێبینی لەسەر ڕەنگی پڕایم)
  Widget _buildCustomerNotesBox(String notes) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFFFF7ED)), // Warm soft orange background
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFFED7AA)), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: RC.fg(Color(0xFFEA580C))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tx('تێبینی: $notes'),
              style: TextStyle(
                color: RC.fg(Color(0xFF9A3412)),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBadge(DateTime time) {
    final hourStr = time.hour.toString().padLeft(2, '0');
    final minStr = time.minute.toString().padLeft(2, '0');
    final timeDisplay = '$hourStr:$minStr';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 13,
            color: RC.fg(Color(0xFF64748B)),
          ),
          const SizedBox(width: 4),
          Text(
            tx(timeDisplay),
            style: TextStyle(
              color: RC.fg(Color(0xFF64748B)),
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: RC.bg(Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: RC.bg(Colors.grey[200]!)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RC.bgn(Colors.orange[50]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_bag_outlined, color: RC.fgn(Colors.orange[800]), size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                t('هیچ داواکارییەک نییە'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1A1A1A))),
              ),
              const SizedBox(height: 8),
              Text(
                t('لە کاتی هاتنی داواکاری لە ئەپی کڕیاران لێرە دەردەکەوێت'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: RC.fg(Colors.grey), height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onSimulate,
                icon: Icon(Icons.notifications_active_rounded, size: 18, color: RC.fg(Colors.white)),
                label: Text(
                  tx('تاقیکردنەوەی دەنگی داواکاری نوێ'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: RC.fg(Colors.white)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFFF6418)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    String text;
    switch (status) {
      case OrderStatus.pending:
        color = RC.bg(Color(0xFFEA580C)); // REGA Prime Orange
        text = t('چاوەڕوانکراو');
        break;
      case OrderStatus.preparing:
        color = RC.bg(Color(0xFFD97706)); // Warm Amber Orange
        text = t('لە ئامادەکردندایە');
        break;
      case OrderStatus.ready:
        color = RC.bg(Color(0xFF16A34A)); // Clean Ready Green
        text = t('ئامادەیە بۆ شۆفێر');
        break;
      default:
        color = RC.bg(Color(0xFF64748B));
        text = 'نادیار';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        tx(text),
        style: TextStyle(
          color: RC.fg(Colors.white),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, Order order) {
    if (order.status == OrderStatus.pending) {
      return [
        Expanded(
          child: _buildGreenButton(
            label: t('قبولکردن'),
            icon: Icons.check_circle_outline,
            onTap: () => onUpdateStatus(order.id, OrderStatus.preparing),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildRedButton(
            label: t('ڕەتکردنەوە'),
            onTap: () => onUpdateStatus(order.id, OrderStatus.rejected),
          ),
        ),
      ];
    } else if (order.status == OrderStatus.preparing) {
      return [
        Expanded(
          child: _buildGreenButton(
            label: t('ئامادەیە بۆ شۆفێر'),
            icon: Icons.check_circle_outline,
            onTap: () => onUpdateStatus(order.id, OrderStatus.ready),
          ),
        ),
      ];
    } else if (order.status == OrderStatus.ready) {
      return [
        Expanded(
          child: _buildGreenButton(
            label: t('ڕادەستکردن بە شۆفێر'),
            icon: Icons.delivery_dining_outlined,
            onTap: () => onUpdateStatus(order.id, OrderStatus.completed),
          ),
        ),
      ];
    }
    return [];
  }

  Widget _buildGreenButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFF16A34A)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: RC.bg(Color(0xFF16A34A)).withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: RC.fg(Colors.white), size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tx(label),
                  style: TextStyle(
                    color: RC.fg(Colors.white),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFFE50010)), // Red from screenshot
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tx(label),
              style: TextStyle(
                color: RC.fg(Colors.white),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showOrderDetails(BuildContext context, Order order) {
    int hour12 = order.timestamp.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = order.timestamp.minute.toString().padLeft(2, '0');
    final periodStr = order.timestamp.hour >= 12 ? 'م' : 'ب';
    final timeFormatted = '$hourStr:$minStr $periodStr';
    final formattedPrice = '${order.total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع';
    String idDisplay = order.id;
    if (!idDisplay.endsWith('#') && !idDisplay.startsWith('#')) {
      idDisplay = '$idDisplay#';
    }

    // Status details
    String statusLabel = 'نادیار';
    Color statusBg = RC.bg(Color(0xFFF3F4F6));
    Color statusTextColor = RC.bg(Color(0xFF374151));

    switch (order.status) {
      case OrderStatus.pending:
        statusLabel = 'چاوەڕوانی قبوڵکردن';
        statusBg = RC.bg(Color(0xFFFFEDD5));
        statusTextColor = RC.bg(Color(0xFF9A3412));
        break;
      case OrderStatus.preparing:
        statusLabel = 'لە ئامادەکردندایە';
        statusBg = RC.bg(Color(0xFFDBEAFE));
        statusTextColor = RC.bg(Color(0xFF1E40AF));
        break;
      case OrderStatus.ready:
        statusLabel = 'ئامادەیە بۆ شۆفێر';
        statusBg = RC.bg(Color(0xFFD1FAE5));
        statusTextColor = RC.bg(Color(0xFF065F46));
        break;
      case OrderStatus.completed:
        statusLabel = 'گەیەندرا و تەواوبوو';
        statusBg = RC.bg(Color(0xFFD1FAE5));
        statusTextColor = RC.bg(Color(0xFF047857));
        break;
      case OrderStatus.rejected:
        statusLabel = 'ڕەتکراوەتەوە';
        statusBg = RC.bg(Color(0xFFFFE4E6));
        statusTextColor = RC.bg(Color(0xFFBE123C));
        break;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            backgroundColor: RC.bg(Colors.white),
            elevation: 16,
            insetPadding: RegaResponsive.dialogInset(dialogCtx, cap: 440, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(dialogCtx, cap: 440),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Close button, Order Number & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: RC.bg(Color(0xFFFF6418)),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: RC.bg(Color(0xFFFF6418)).withOpacity(0.35),
                                    blurRadius: 5,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.close_rounded, color: RC.fg(Colors.white), size: 18),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                tx(idDisplay),
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: RC.fg(Color(0xFF1B2028)),
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tx(statusLabel),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: statusTextColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    tx('تۆمارکراوە: $timeFormatted'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: RC.fgn(Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(height: 1, color: RC.bg(Color(0xFFEEEEEE))),
                      const SizedBox(height: 10),

                      // Customer & Delivery Information
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFFF8F9FA)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: RC.bg(Color(0xFFE9ECEF))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_rounded, size: 15, color: RC.fg(Color(0xFFEA580C))),
                                const SizedBox(width: 5),
                                Text(tx('کڕیار: '), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    tx(order.customerName),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.phone_rounded, size: 15, color: RC.fg(Color(0xFFEA580C))),
                                const SizedBox(width: 5),
                                Text(tx('مۆبایل: '), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      tx(IraqPhoneFormatter.display(order.customerPhone)),
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF1B2028))),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 15, color: RC.fg(Color(0xFFEA580C))),
                                const SizedBox(width: 5),
                                Text(tx('ناونیشان: '), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    tx(order.deliveryAddress),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (order.customerNotes != null && order.customerNotes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _buildCustomerNotesBox(order.customerNotes!),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Order Items List ("لیستی کڕین")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tx('لیستی کڕین'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: RC.fg(Color(0xFF1B2028)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: RC.bg(Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              tx('${order.items.length} بەرهەم'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: RC.fg(Color(0xFF4B5563)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      ...order.items.map((itemText) {
                        String qty = "1x";
                        int qtyNumber = 1;
                        String name = itemText.trim();
                        final regex = RegExp(r'^([0-9١-٩]+)\s*[xX*×]\s*(.*)$');
                        final match = regex.firstMatch(itemText.trim());
                        if (match != null) {
                          String numPart = match.group(1)!;
                          final arabicToStandard = {
                            '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5',
                            '٦': '6', '٧': '7', '٨': '8', '٩': '9',
                          };
                          arabicToStandard.forEach((k, v) {
                            numPart = numPart.replaceAll(k, v);
                          });
                          qtyNumber = int.tryParse(numPart) ?? 1;
                          qty = '${numPart}x';
                          name = match.group(2)!.trim();
                        }
                        final rawItemPrice = getEstimatedItemPrice(name, qtyNumber);
                        final itemPriceAmount = formatAmountOnly(rawItemPrice);
                        final imgUrl = getProductImageUrl(name);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Colors.black).withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (itemCtx, itemConstraints) {
                              final compact = itemConstraints.maxWidth < 360;
                              final imgSize = compact ? 56.0 : 78.0;
                              final priceBlock = FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.ltr,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection: TextDirection.ltr,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          tx('د.ع'),
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                            color: RC.fg(Color(0xFF6B7280)),
                                            fontWeight: FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          tx(itemPriceAmount),
                                          textDirection: TextDirection.ltr,
                                          style: TextStyle(
                                            color: RC.fg(Color(0xFF1E2024)),
                                            fontWeight: FontWeight.normal,
                                            fontSize: compact ? 16 : 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: compact ? 8 : 12),
                                    Text(
                                      tx('X $qtyNumber'),
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                        color: RC.fg(Color(0xFF16A34A)),
                                        fontWeight: FontWeight.normal,
                                        fontSize: compact ? 16 : 20,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              final nameText = Text(
                                tx(name),
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: compact ? 13 : 14,
                                  color: RC.fg(Color(0xFF1E2024)),
                                ),
                                maxLines: compact ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                              );
                              final image = GestureDetector(
                                onTap: () => showFullScreenImageDialog(dialogCtx, imageUrl: imgUrl, title: name),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    imgUrl,
                                    width: imgSize,
                                    height: imgSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: imgSize,
                                      height: imgSize,
                                      color: RC.bg(Color(0xFFF3F4F6)),
                                      child: Icon(Icons.fastfood_rounded, size: compact ? 24 : 30, color: RC.fg(Color(0xFF9CA3AF))),
                                    ),
                                  ),
                                ),
                              );
                              if (compact) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    image,
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          nameText,
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: AlignmentDirectional.centerEnd,
                                            child: priceBlock,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  image,
                                  const SizedBox(width: 12),
                                  Expanded(child: nameText),
                                  const SizedBox(width: 8),
                                  Flexible(child: priceBlock),
                                ],
                              );
                            },
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // Simplified Financials (Dark Card)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFF1B2028)),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: RC.bg(Colors.black).withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tx('کۆی نرخ'), style: TextStyle(color: RC.fg(Color(0xFF9CA3AF)), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(tx(formattedPrice), style: TextStyle(color: RC.fg(Colors.white), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tx('داشکان'), style: TextStyle(color: RC.fg(Color(0xFF9CA3AF)), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(tx('٠ د.ع'), style: TextStyle(color: RC.fg(Color(0xFFF87171)), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(height: 1, color: RC.bg(Color(0xFF374151))),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tx('کۆی گشتی حساب'),
                                  style: TextStyle(
                                    color: RC.fg(Color(0xFF34D399)),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  tx(formattedPrice),
                                  style: TextStyle(
                                    color: RC.fg(Colors.white),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Contextual Action Buttons in Details Modal
                      if (order.status == OrderStatus.pending) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(Color(0xFF16A34A)),
                                  foregroundColor: RC.fg(Colors.white),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  onUpdateStatus(order.id, OrderStatus.preparing);
                                },
                                child: Text(t('قبولکردن'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(Color(0xFFE50010)),
                                  foregroundColor: RC.fg(Colors.white),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  onUpdateStatus(order.id, OrderStatus.rejected);
                                },
                                child: Text(t('ڕەتکردنەوە'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ] else if (order.status == OrderStatus.preparing) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(Color(0xFF16A34A)),
                            foregroundColor: RC.fg(Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            onUpdateStatus(order.id, OrderStatus.ready);
                          },
                          child: Text(t('ئامادەیە بۆ شۆفێر'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                      ] else if (order.status == OrderStatus.ready) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(Color(0xFF16A34A)),
                            foregroundColor: RC.fg(Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            onUpdateStatus(order.id, OrderStatus.completed);
                          },
                          child: Text(t('ڕادەستکردن بە شۆفێر'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(const Color(0xFFDC2626)),
                            foregroundColor: RC.fg(Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text(
                            t('داخستن'),
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: RC.fg(Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class ProductsScreen extends StatefulWidget {
  final List<Product> products;
  final List<String> categories;
  final Function(String) onToggle;
  final Function(String) onDelete;
  final Function(Product) onAdd;
  final Function(Product) onEdit;
  final void Function(String name, {String? imageUrl}) onAddCategory;
  final Function(String)? onDeleteCategory;
  final Future<void> Function(int percent)? onStoreDiscount;

  const ProductsScreen({
    super.key, 
    required this.products, 
    required this.categories,
    required this.onToggle, 
    required this.onDelete,
    required this.onAdd,
    required this.onEdit,
    required this.onAddCategory,
    this.onDeleteCategory,
    this.onStoreDiscount,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteCategory(BuildContext context, String category) {
    final count = widget.products.where((p) => p.category.trim() == category.trim()).length;
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: RC.bg(Colors.white),
          insetPadding: RegaResponsive.dialogInset(dialogCtx, cap: 420),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFEBEE)),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: RC.fg(Color(0xFFE50010)), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx('سڕینەوەی بەش'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: RegaResponsive.dialogMaxWidth(dialogCtx, cap: 420),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx('ئایا دڵنیایت لە سڕینەوەی بەشی "$category"؟'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF374151)), height: 1.4),
              ),
              if (count > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFFFFFBEB)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RC.bg(Color(0xFFFDE68A))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: RC.fg(Color(0xFFB45309))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx('ئەم بەشە $count بەرهەمی تێدایە.'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF92400E))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(tx('پاشگەزبوونەوە'), style: TextStyle(color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFE50010)),
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                setState(() {
                  if (_selectedCategory == category) {
                    _selectedCategory = null;
                  }
                  widget.categories.remove(category);
                });
                widget.onDeleteCategory?.call(category);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tx('بەشی "$category" بە سەرکەوتوویی سڕایەوە'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: RC.bg(Color(0xFFE50010)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(tx('سڕینەوە'), style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: RC.bg(Colors.white),
          insetPadding: RegaResponsive.dialogInset(dialogCtx, cap: 420),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFEBEE)),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: RC.fg(Color(0xFFE50010)), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx('سڕینەوەی بەرهەم'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: RegaResponsive.dialogMaxWidth(dialogCtx, cap: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx('ئایا دڵنیایت لە سڕینەوەی بەرهەمی "${product.name}"؟'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF374151)), height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  tx('ئەم بەرهەمە لە مێنۆکەت دەسڕدرێتەوە.'),
                  style: TextStyle(fontSize: 12, color: RC.fgn(Colors.grey[600])),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(tx('پاشگەزبوونەوە'), style: TextStyle(color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFE50010)),
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                widget.onDelete(product.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tx('بەرهەمی "${product.name}" بە سەرکەوتوویی سڕایەوە'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: RC.bg(Color(0xFFE50010)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(tx('سڕینەوە'), style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter products
    List<Product> filteredProducts = widget.products.where((p) {
      final matchesCategory = _selectedCategory == null || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              // 1. Search Bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              RegaResponsive.pagePadding(context),
              12,
              RegaResponsive.pagePadding(context),
              6,
            ),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RC.bg(Color(0xFFE5E7EB)), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: RC.bg(Colors.black).withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: RC.fg(Color(0xFF4A4A4A)), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: t('مێنۆ و بەرهەم'),
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: RC.fg(Color(0xFF262626)),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: RC.fg(Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Action & Categories Box (Header Card)
          Container(
            margin: EdgeInsets.fromLTRB(
              RegaResponsive.pagePadding(context),
              4,
              RegaResponsive.pagePadding(context),
              8,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RC.bg(Color(0xFFE5E7EB)), width: 1),
              boxShadow: [
                BoxShadow(
                  color: RC.bg(Colors.black).withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Two Action Buttons Row
                Row(
                  children: [
                    // Action 1: Add New Category (Right in RTL)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showAddCategoryDialog(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF7ED)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RC.bg(Color(0xFFFED7AA)), width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: RC.fg(Color(0xFFEA580C)), size: 19),
                                  SizedBox(width: 5),
                                  Text(
                                    tx('زیادکردنی بەشی نوێ'),
                                    style: TextStyle(
                                      color: RC.fg(Color(0xFFEA580C)),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action 2: Add Product (Left in RTL)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showAddProductDialog(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFEA580C)),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: RC.fg(Colors.white), size: 20),
                                  SizedBox(width: 5),
                                  Text(
                                    tx('زیادکردنی بەرهەم'),
                                    style: TextStyle(
                                      color: RC.fg(Colors.white),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Store-wide discount
                GestureDetector(
                  onTap: () => _showStoreDiscountDialog(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RC.bg(Color(0xFFFECACA)), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Icon(Icons.local_offer_rounded, color: RC.fg(Color(0xFFE11D48)), size: 20),
                          Text(
                            t('داشکاندنی دوکان'),
                            style: TextStyle(
                              color: RC.fg(Color(0xFFE11D48)),
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                          if (!RegaResponsive.isPhone(context))
                            Text(
                              tx('(${t('داشکاندن بۆ هەموو دوکانەکە')})'),
                              style: TextStyle(
                                color: RC.fg(Colors.red.shade300),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Categories Filter Chips
                if (widget.categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                       scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.categories.length + 1,
                      itemBuilder: (context, index) {
                        // First Chip is "All" (هەمووی)
                        if (index == 0) {
                          final isAllSelected = _selectedCategory == null;
                          final totalCount = widget.products.length;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = null),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAllSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAllSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFE2E8F0)),
                                  width: isAllSelected ? 1.5 : 1,
                                ),
                                boxShadow: isAllSelected
                                    ? [
                                        BoxShadow(
                                          color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tx('هەمووی'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: isAllSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF1E293B)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAllSelected ? RC.bg(Colors.white).withValues(alpha: 0.25) : RC.bg(Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tx('$totalCount'),
                                      style: TextStyle(
                                        color: isAllSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF475569)),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final catIndex = index - 1;
                        final cat = widget.categories[catIndex];
                        final count = widget.products.where((p) => p.category.trim() == cat.trim()).length;
                        final isSelected = _selectedCategory == cat;
                        return Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    if (_selectedCategory == cat) {
                                      _selectedCategory = null;
                                    } else {
                                      _selectedCategory = cat;
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 7, 12, 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tx(cat),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: isSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF1E293B)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? RC.bg(Colors.white).withValues(alpha: 0.25) : RC.bg(Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tx('$count'),
                                          style: TextStyle(
                                            color: isSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF475569)),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _confirmDeleteCategory(context, cat),
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(8, 0, 4, 0),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isSelected ? RC.bg(Colors.white).withValues(alpha: 0.25) : RC.bg(Color(0xFFE2E8F0)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: isSelected ? RC.fg(Colors.white) : RC.bg(Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Products Grid (Responsive for Phone, iPad & Tablet)
          Expanded(
            child: filteredProducts.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final crossAxisCount = w < 400
                          ? 1
                          : RegaResponsive.gridCountForWidth(
                              w,
                              phone: 2,
                              tablet: 3,
                              desktop: 4,
                            );
                      return GridView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: RegaResponsive.pagePadding(context),
                          vertical: 6,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: crossAxisCount >= 3 ? 280 : 260,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(context, filteredProducts[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_outlined, color: RC.fg(Color(0xFFEA580C)), size: 48),
          const SizedBox(height: 24),
          Text(t('هیچ بەرهەمێک نەدۆزرایەوە'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(t('دەتوانیت بە کلیک لەسەر دوگمەی (بەرهەمی نوێ) یەکەمین کاڵا زیادبکەیت.'), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final resolvedUrl = VendorApiService.instance.resolveMediaUrl(product.imageUrl);
    ImageProvider imageProvider;
    if (!kIsWeb && product.imagePath != null && product.imagePath!.isNotEmpty) {
      try {
        final f = File(product.imagePath!);
        if (f.existsSync()) {
          imageProvider = FileImage(f);
        } else if (resolvedUrl.isNotEmpty) {
          imageProvider = NetworkImage(resolvedUrl);
        } else {
          imageProvider = const NetworkImage('https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&auto=format&fit=crop');
        }
      } catch (_) {
        imageProvider = resolvedUrl.isNotEmpty
            ? NetworkImage(resolvedUrl)
            : const NetworkImage('https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&auto=format&fit=crop');
      }
    } else if (resolvedUrl.isNotEmpty) {
      imageProvider = NetworkImage(resolvedUrl);
    } else {
      imageProvider = const NetworkImage('https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&auto=format&fit=crop');
    }

    final hasDiscount = product.discountPrice != null && product.discountPrice! > 0 && product.discountPrice! < product.price;
    final priceFormatted = '${product.price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع';
    final discountPriceFormatted = hasDiscount ? '${product.discountPrice!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع' : '';

    return Container(
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB)), width: 1),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          GestureDetector(
            onTap: () => showFullScreenImageDialog(context, imageProvider: imageProvider, title: product.name),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 115,
                    width: double.infinity,
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: RC.bgn(Colors.grey[200]),
                        child: Icon(Icons.fastfood, color: RC.fg(Colors.grey), size: 36),
                      ),
                    ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFEF4444)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tx('داشکاندن'),
                        style: TextStyle(
                          color: RC.fg(Colors.white),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Name
          Text(
            tx(product.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
              color: RC.fg(Color(0xFF1E2024)),
            ),
          ),
          const SizedBox(height: 2),

          // Description
          Text(
            tx(product.description ?? 'بەرهەمی فرێش...'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: RC.fg(Color(0xFF8E8E93)),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 6),

          // Price
          hasDiscount
              ? Row(
                  children: [
                    Text(
                      tx(discountPriceFormatted),
                      style: TextStyle(
                        color: RC.fg(Color(0xFFEA580C)),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tx(priceFormatted),
                      style: TextStyle(
                        color: RC.fg(Color(0xFFDC2626)),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: RC.bg(Color(0xFFDC2626)),
                        decorationThickness: 1.6,
                      ),
                    ),
                  ],
                )
              : Text(
                  tx(priceFormatted),
                  style: TextStyle(
                    color: RC.fg(Color(0xFFEA580C)),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),

          const Spacer(),

          // Bottom Bar Actions
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.isAvailable ? RC.bg(Color(0xFFE8FAF0)) : RC.bg(Color(0xFFFFEBEE)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          tx(product.isAvailable ? t('بەردەستە') : t('نابەردەست')),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: product.isAvailable ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFD32F2F)),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: product.isAvailable ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFD32F2F)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showEditProductDialog(context, product),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, color: RC.fg(Color(0xFF9E9E9E)), size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmDeleteProduct(context, product),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, color: RC.fg(Color(0xFF9E9E9E)), size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final categoryController = TextEditingController();
    String? localImagePath;
    String? uploadedImageUrl;
    Uint8List? previewBytes;
    var imageBusy = false;
    String? imageError;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Dialog(
                insetPadding: RegaResponsive.dialogInset(context, cap: 380),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  constraints: BoxConstraints(
                    maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 380),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('زیادکردنی بەشی نوێ'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(t('تکایە ناوی ئەو بەشە بنووسە کە دەتەوێت زیادی بکەیت'),
                          style: TextStyle(color: RC.fg(Colors.grey), fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel(t('ناوی بەش')),
                        _buildTextField(categoryController, 'بۆ نموونە: پیتزاکان'),
                        const SizedBox(height: 14),
                        _buildLabel(t('وێنەی بەش')),
                        _buildImagePicker(
                          thumbnail: uploadedImageUrl,
                          localImagePath: localImagePath,
                          previewBytes: previewBytes,
                          busy: imageBusy,
                          errorText: txn(imageError),
                          onTap: imageBusy
                              ? null
                              : () => _pickCompressUploadProductImage(
                                    setDialogState,
                                    onBusy: (v) => imageBusy = v,
                                    onError: (e) => imageError = e,
                                    onResult: (path, url, bytes) {
                                      localImagePath = path;
                                      uploadedImageUrl = url;
                                      previewBytes = bytes;
                                    },
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: imageBusy ? null : () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(t('پاشگەزبونەوە'), style: TextStyle(color: RC.fg(Colors.grey), fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: imageBusy
                                    ? null
                                    : () {
                                        final name = categoryController.text.trim();
                                        if (name.isNotEmpty) {
                                          widget.onAddCategory(name, imageUrl: uploadedImageUrl);
                                          Navigator.pop(context);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(Color(0xFF00C853)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: Text(t('زیادکردن'),
                                  style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w900, fontSize: 13.5),
                                ),
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
        );
      },
    );
  }

  static const List<int> _discountPercents = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100];

  int? _percentFromPrices(double price, double? discountPrice) {
    if (discountPrice == null || discountPrice <= 0 || price <= 0 || discountPrice >= price) {
      return null;
    }
    final raw = (((price - discountPrice) / price) * 100).round();
    final snapped = ((raw / 5).round() * 5).clamp(5, 100);
    return snapped;
  }

  double? _priceFromPercent(double price, int? percent) {
    if (percent == null || percent <= 0 || price <= 0) return null;
    final v = (price * (100 - percent) / 100).roundToDouble();
    return v < price ? v : (price - 1).clamp(0, price);
  }

  Widget _buildDiscountPercentDropdown({
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: Text(t('بێ داشکاندن'), style: TextStyle(color: RC.fg(Colors.grey.shade500), fontSize: 13)),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(t('بێ داشکاندن'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            ..._discountPercents.map(
              (p) => DropdownMenuItem<int?>(
                value: p,
                child: Text(tx('$p%'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showStoreDiscountDialog(BuildContext context) {
    int? selectedPercent = 10;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: Trans.direction,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: RegaResponsive.dialogInset(ctx, cap: 380),
              title: Text(t('داشکاندنی دوکان'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              content: SizedBox(
                width: RegaResponsive.dialogMaxWidth(ctx, cap: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t('داشکاندن بۆ هەموو بەرهەمەکان جێبەجێ دەکرێت'),
                      style: TextStyle(fontSize: 12.5, color: RC.fg(Colors.grey.shade600), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    _buildLabel(t('ڕێژەی داشکاندن هەڵبژێرە')),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedPercent,
                          isExpanded: true,
                          items: _discountPercents
                              .map((p) => DropdownMenuItem(value: p, child: Text(tx('$p%'), style: const TextStyle(fontWeight: FontWeight.w800))))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedPercent = v ?? 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(Color(0xFFE11D48)),
                          foregroundColor: RC.fg(Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                setDialogState(() => saving = true);
                                await widget.onStoreDiscount?.call(selectedPercent ?? 10);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: Text(t('جێبەجێکردنی داشکاندن')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setDialogState(() => saving = true);
                                await widget.onStoreDiscount?.call(0);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: Text(t('لابردنی داشکاندنی دوکان'), style: TextStyle(color: RC.fg(Color(0xFFE11D48)))),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: Text(t('پاشگەزبونەوە')),
                      ),
                    ),
                  ],
                ),
              ),
              actions: const [],
            ),
          );
        },
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toInt().toString());
    final costController = TextEditingController(text: product.costPrice.toInt().toString());
    final descKuController = TextEditingController(text: product.id == '3' ? 'بەرگری گۆشتی فرێش لەگەڵ پەنیر و سەوزە' : '');
    final descArController = TextEditingController();
    String selectedCategory = product.category;
    String? localImagePath = product.imagePath;
    String? uploadedImageUrl = product.imageUrl;
    Uint8List? previewBytes;
    var imageBusy = false;
    String? imageError;
    int? selectedDiscountPct = _percentFromPrices(product.price, product.discountPrice);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Dialog(
                insetPadding: RegaResponsive.dialogInset(context, cap: 420, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 420),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFFFFF7ED)),
                                  border: Border.all(color: RC.bg(Color(0xFFFED7AA)), width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: RC.fg(Color(0xFFEA580C)),
                                    size: 20,
                                    shadows: [Shadow(color: RC.bg(Color(0xFFEA580C)), blurRadius: 1)],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    t('دەستکاریکردنی بەرهەم'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: RC.bg(Color(0xFFEEEEEE))),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(t('ناوی بەرهەم *')),
                              _buildTextField(nameController, '...Pizza'),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('بەش / پۆڵێن *')),
                              _buildDropdown(
                                value: selectedCategory,
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedCategory = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('نرخی کڕین (تێچوو) *')),
                              _buildTextField(costController, '5000', onChanged: (_) => setDialogState(() {})),
                              const SizedBox(height: 10),

                              _buildLabel(t('نرخی فرۆشتن *')),
                              _buildTextField(priceController, '7500', onChanged: (_) => setDialogState(() {})),
                              Builder(
                                builder: (_) {
                                  final sell = double.tryParse(priceController.text) ?? 0;
                                  final cost = double.tryParse(costController.text) ?? 0;
                                  final gross = sell - cost;
                                  if (sell <= 0) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('قازانجی سەرەتایی')}: ${gross.toInt()} د.ع'),
                                      style: TextStyle(
                                        color: gross > 0 ? RC.bg(Color(0xFF059669)) : RC.bg(Color(0xFFDC2626)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),

                              _buildLabel('${t('داشکاندنی بەرهەم (٪)')} — ${t('داشکاندن بۆ بەرهەمێک')}'),
                              _buildDiscountPercentDropdown(
                                value: selectedDiscountPct,
                                onChanged: (v) => setDialogState(() => selectedDiscountPct = v),
                              ),
                              Builder(
                                builder: (_) {
                                  final base = double.tryParse(priceController.text) ?? product.price;
                                  final after = _priceFromPercent(base, selectedDiscountPct);
                                  if (after == null) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('نرخی دوای داشکاندن')}: ${after.toInt()} د.ع  (−${selectedDiscountPct}%)'),
                                      style: TextStyle(
                                        color: RC.fg(Color(0xFF059669)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وێنەی بەرهەم')),
                              _buildImagePicker(
                                thumbnail: uploadedImageUrl ??
                                    (product.id == '3'
                                        ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=100'
                                        : product.imageUrl),
                                localImagePath: localImagePath,
                                previewBytes: previewBytes,
                                busy: imageBusy,
                                errorText: txn(imageError),
                                onTap: imageBusy
                                    ? null
                                    : () => _pickCompressUploadProductImage(
                                          setDialogState,
                                          onBusy: (v) => imageBusy = v,
                                          onError: (e) => imageError = e,
                                          onResult: (path, url, bytes) {
                                            localImagePath = path;
                                            uploadedImageUrl = url;
                                            previewBytes = bytes;
                                          },
                                        ),
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - کوردی (ئارەزوومەندانە)')),
                              _buildTextField(descKuController, '', maxLines: 2),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - عەرەبی')),
                              _buildTextField(descArController, '', maxLines: 1),
                              const SizedBox(height: 14),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: imageBusy
                                      ? null
                                      : () {
                                          if (nameController.text.isNotEmpty) {
                                            final base = double.tryParse(priceController.text) ?? 0;
                                            final cost = double.tryParse(costController.text) ?? 0;
                                            if (cost < 0 || cost >= base) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(tx('نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت'), textAlign: TextAlign.center),
                                                  backgroundColor: RC.bg(Color(0xFFDC2626)),
                                                ),
                                              );
                                              return;
                                            }
                                            widget.onEdit(Product(
                                              id: product.id,
                                              name: nameController.text,
                                              category: selectedCategory,
                                              price: base,
                                              costPrice: cost,
                                              discountPrice: _priceFromPercent(base, selectedDiscountPct),
                                              isAvailable: product.isAvailable,
                                              imagePath: localImagePath,
                                              imageUrl: uploadedImageUrl ?? product.imageUrl,
                                            ));
                                            Navigator.pop(context);
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RC.bg(Color(0xFF00C853)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(t('تۆمارکردنی بەرهەم'),
                                    style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w900, fontSize: 14.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _pickCompressUploadProductImage(
    StateSetter setDialogState, {
    required void Function(bool busy) onBusy,
    required void Function(String? error) onError,
    required void Function(String? path, String url, Uint8List bytes) onResult,
  }) async {
    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Directionality(
        textDirection: Trans.direction,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: RC.bgn(Colors.grey[300]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header (Title & Close Button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('هەڵبژاردنی وێنە'),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: RC.fg(Color(0xFF1E293B))),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: RC.bgn(Colors.grey[100]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: RC.fg(Colors.grey)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                
                // Camera Option Card
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RC.bg(Color(0xFFFF9800)), RC.bg(Color(0xFFF57C00))],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Color(0xFFFF9800)).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: RC.fg(Colors.white), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('کامێرا'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: RC.fg(Color(0xFF1E293B))),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەی نوێ وەبگرە'),
                                style: TextStyle(color: RC.fgn(Colors.grey[600]), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF3E0)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: RC.fg(Color(0xFFFF9800)),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Gallery Option Card
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RC.bg(Color(0xFFFF9800)), RC.bg(Color(0xFFF57C00))],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Color(0xFFFF9800)).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.photo_library_rounded, color: RC.fg(Colors.white), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('گالەری'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: RC.fg(Color(0xFF1E293B))),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەیەک لە موبایلەکەت هەڵبژێرە'),
                                style: TextStyle(color: RC.fgn(Colors.grey[600]), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF3E0)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: RC.fg(Color(0xFFFF9800)),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: RC.bg(Color(0xFFE50010)),
                      foregroundColor: RC.fg(Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      t('پاشگەزبوونەوە'),
                      style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

    if (source == null) return;

    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    setDialogState(() {
      onBusy(true);
      onError(null);
    });
    try {
      final raw = await image.readAsBytes();
      if (raw.isEmpty) {
        throw Exception(t('بارکردنی وێنە سەرکەوتوو نەبوو'));
      }
      final compressed = await ImageCompressService.compressForUpload(
        name: image.name.isNotEmpty ? image.name : 'product.jpg',
        bytes: Uint8List.fromList(raw),
      );
      final up = await VendorApiService.instance.uploadMedia(
        compressed.bytes,
        compressed.name,
      );
      final url = up['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception(t('بارکردنی وێنە سەرکەوتوو نەبوو'));
      }
      if (!mounted) return;
      setDialogState(() {
        onResult(kIsWeb ? null : image.path, url, compressed.bytes);
        onBusy(false);
        onError(null);
      });
    } catch (e) {
      if (!mounted) return;
      setDialogState(() {
        onBusy(false);
        onError(e.toString());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(e.toString()), textAlign: TextAlign.center),
          backgroundColor: RC.bg(Color(0xFFE50010)),
        ),
      );
    }
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final descKuController = TextEditingController();
    final descArController = TextEditingController();
    String selectedCategory = widget.categories.isNotEmpty ? widget.categories.first : 'پیتزا';
    String? localImagePath;
    String? uploadedImageUrl;
    Uint8List? previewBytes;
    var imageBusy = false;
    String? imageError;
    int? selectedDiscountPct;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Dialog(
                insetPadding: RegaResponsive.dialogInset(context, cap: 420, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 420),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFFFFF7ED)),
                                  border: Border.all(color: RC.bg(Color(0xFFFED7AA)), width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: RC.fg(Color(0xFFEA580C)),
                                    size: 20,
                                    shadows: [Shadow(color: RC.bg(Color(0xFFEA580C)), blurRadius: 1)],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    tx('زیادکردنی بەرهەمی نوێ'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32), // Balance the close button
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: RC.bg(Color(0xFFEEEEEE))),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(t('ناوی بەرهەم *')),
                              _buildTextField(nameController, '...Pizza'),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('بەش / پۆڵێن *')),
                              _buildDropdown(
                                value: selectedCategory,
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedCategory = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('نرخی کڕین (تێچوو) *')),
                              _buildTextField(costController, '5000', onChanged: (_) => setDialogState(() {})),
                              const SizedBox(height: 10),

                              _buildLabel(t('نرخی فرۆشتن *')),
                              _buildTextField(priceController, '7500', onChanged: (_) => setDialogState(() {})),
                              Builder(
                                builder: (_) {
                                  final sell = double.tryParse(priceController.text) ?? 0;
                                  final cost = double.tryParse(costController.text) ?? 0;
                                  final gross = sell - cost;
                                  if (sell <= 0) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('قازانجی سەرەتایی')}: ${gross.toInt()} د.ع'),
                                      style: TextStyle(
                                        color: gross > 0 ? RC.bg(Color(0xFF059669)) : RC.bg(Color(0xFFDC2626)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),

                              _buildLabel('${t('داشکاندنی بەرهەم (٪)')} — ${t('داشکاندن بۆ بەرهەمێک')}'),
                              _buildDiscountPercentDropdown(
                                value: selectedDiscountPct,
                                onChanged: (v) => setDialogState(() => selectedDiscountPct = v),
                              ),
                              Builder(
                                builder: (_) {
                                  final base = double.tryParse(priceController.text) ?? 0;
                                  final after = _priceFromPercent(base, selectedDiscountPct);
                                  if (after == null) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('نرخی دوای داشکاندن')}: ${after.toInt()} د.ع  (−${selectedDiscountPct}%)'),
                                      style: TextStyle(
                                        color: RC.fg(Color(0xFF059669)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وێنەی بەرهەم')),
                              _buildImagePicker(
                                thumbnail: uploadedImageUrl,
                                localImagePath: localImagePath,
                                previewBytes: previewBytes,
                                busy: imageBusy,
                                errorText: txn(imageError),
                                onTap: imageBusy
                                    ? null
                                    : () => _pickCompressUploadProductImage(
                                          setDialogState,
                                          onBusy: (v) => imageBusy = v,
                                          onError: (e) => imageError = e,
                                          onResult: (path, url, bytes) {
                                            localImagePath = path;
                                            uploadedImageUrl = url;
                                            previewBytes = bytes;
                                          },
                                        ),
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - کوردی (ئارەزوومەندانە)')),
                              _buildTextField(descKuController, '', maxLines: 2),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - عەرەبی')),
                              _buildTextField(descArController, '', maxLines: 1),
                              const SizedBox(height: 14),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: imageBusy
                                      ? null
                                      : () {
                                          if (nameController.text.isNotEmpty) {
                                            final base = double.tryParse(priceController.text) ?? 0;
                                            final cost = double.tryParse(costController.text) ?? 0;
                                            if (cost < 0 || cost >= base) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(tx('نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت'), textAlign: TextAlign.center),
                                                  backgroundColor: RC.bg(Color(0xFFDC2626)),
                                                ),
                                              );
                                              return;
                                            }
                                            widget.onAdd(Product(
                                              id: DateTime.now().toString(),
                                              name: nameController.text,
                                              category: selectedCategory,
                                              price: base,
                                              costPrice: cost,
                                              discountPrice: _priceFromPercent(base, selectedDiscountPct),
                                              imagePath: localImagePath,
                                              imageUrl: uploadedImageUrl,
                                            ));
                                            Navigator.pop(context);
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RC.bg(Color(0xFF00C853)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(t('تۆمارکردنی بەرهەم'),
                                    style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w900, fontSize: 14.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(tx(text), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: RC.fg(Colors.black))),
  );
  
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    Color? hintColor,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: txn(hint),
          hintStyle: TextStyle(color: hintColor ?? RC.bgn(Colors.grey[400]), fontSize: 12),
          filled: true,
          fillColor: RC.bg(Colors.white),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: RC.bg(Colors.grey[200]!)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: RC.bg(Color(0xFF00C853))),
          ),
        ),
      );

  Widget _buildDropdown({String? value, Function(String?)? onChanged}) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: RC.bg(Colors.grey[200]!)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        icon: Icon(Icons.keyboard_arrow_down, color: RC.fg(Colors.grey), size: 20),
        items: widget.categories.map((e) => DropdownMenuItem(value: e, child: Text(tx(e), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
        onChanged: onChanged,
        hint: Text(tx(widget.categories.isNotEmpty ? widget.categories.first : t('بەشێک هەڵبژێرە')), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: RC.fg(Colors.black))),
      ),
    ),
  );

  Widget _buildImagePicker({
    String? thumbnail,
    String? localImagePath,
    Uint8List? previewBytes,
    bool busy = false,
    String? errorText,
    VoidCallback? onTap,
  }) {
    Widget thumb;
    if (previewBytes != null) {
      thumb = Image.memory(
        previewBytes,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: RC.fg(Colors.grey), size: 28),
      );
    } else if (!kIsWeb && localImagePath != null && localImagePath.isNotEmpty) {
      thumb = Image.file(
        File(localImagePath),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: RC.fg(Colors.grey), size: 28),
      );
    } else if (thumbnail != null && thumbnail.isNotEmpty) {
      thumb = Image.network(
        thumbnail,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: RC.fg(Colors.grey), size: 28),
      );
    } else {
      thumb = Icon(Icons.add_photo_alternate_rounded, color: RC.fg(Color(0xFFEA580C)), size: 28);
    }

    final hasImage = previewBytes != null ||
        (localImagePath != null && localImagePath.isNotEmpty) ||
        (thumbnail != null && thumbnail.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              height: 120,
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFFFF7ED)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: errorText != null
                      ? RC.bg(Color(0xFFE11D48))
                      : (hasImage ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFFED7AA))),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: thumb)),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        thumb,
                        const SizedBox(height: 8),
                        Text(
                          t('کرتە بکە بۆ هەڵبژاردنی وێنە'),
                          style: TextStyle(
                            color: RC.fg(Color(0xFF9A3412)),
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  if (busy)
                    Container(
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0x880F172A)),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: RC.bg(Colors.white)),
                          const SizedBox(height: 8),
                          Text(
                            t('بارکردنی وێنە...'),
                            style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: busy ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: RC.bg(Colors.white)),
                  )
                : Icon(hasImage ? Icons.sync_rounded : Icons.cloud_upload_rounded, size: 18),
            label: Text(
              tx(busy
                  ? t('بارکردنی وێنە...')
                  : (hasImage ? t('گۆڕینی وێنە') : t('هەڵبژاردن و بارکردنی وێنە'))),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            tx(errorText),
            style: TextStyle(color: RC.fg(Color(0xFFE11D48)), fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class RevenueScreen extends StatefulWidget {
  final List<Order> orders;
  final Future<void> Function()? onRefresh;
  const RevenueScreen({super.key, required this.orders, this.onRefresh});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  int _selectedTabIndex = 0; // 0: ئەمڕۆ, 1: ئەم هەفتەیە, 2: ئەم مانگە
  int? _selectedBarIndex;
  Map<String, dynamic>? _analytics;
  bool _analyticsLoading = false;

  String _formatAmount(num value) {
    final intVal = value.round();
    return intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String get _apiPeriod => switch (_selectedTabIndex) {
        1 => 'week',
        2 => 'month',
        _ => 'today',
      };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _analyticsLoading = true);
    final data = await VendorApiService.instance.fetchRevenueAnalytics(period: _apiPeriod);
    if (!mounted) return;
    setState(() {
      _analytics = data;
      _analyticsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<Order> filteredOrders;
    String periodTitle = t('ئەمڕۆ');
    String chartTitle = t('شیکاری فرۆشی کاتژمێری');
    List<String> chartLabels = ['١٠ب', '١٢ن', '٢پ', '٤ئ', '٦ئ', '٨ش', '١٠ش'];
    List<String> chartFullLabels = [
      '١٠:٠٠ بەیانی',
      '١٢:٠٠ نیوەڕۆ',
      '٠٢:٠٠ پاشنیوەڕۆ',
      '٠٤:٠٠ ئێوارە',
      '٠٦:٠٠ ئێوارە',
      '٠٨:٠٠ شەو',
      '١٠:٠٠ شەو',
    ];
    List<double> chartValues = [0, 0, 0, 0, 0, 0, 0];

    if (_selectedTabIndex == 0) {
      // 1. Today
      filteredOrders = widget.orders.where((o) =>
        o.timestamp.year == now.year &&
        o.timestamp.month == now.month &&
        o.timestamp.day == now.day
      ).toList();
      periodTitle = t('ئەمڕۆ');
      chartTitle = t('شیکاری فرۆشی کاتژمێری');
      chartLabels = ['١٠ب', '١٢ن', '٢پ', '٤ئ', '٦ئ', '٨ش', '١٠ش'];
      chartFullLabels = [
        '١٠:٠٠ بەیانی',
        '١٢:٠٠ نیوەڕۆ',
        '٠٢:٠٠ پاشنیوەڕۆ',
        '٠٤:٠٠ ئێوارە',
        '٠٦:٠٠ ئێوارە',
        '٠٨:٠٠ شەو',
        '١٠:٠٠ شەو',
      ];
      final hoursMap = [10, 12, 14, 16, 18, 20, 22];
      chartValues = List.generate(7, (i) {
        final targetHour = hoursMap[i];
        return filteredOrders
            .where((o) => (o.timestamp.hour - targetHour).abs() <= 1)
            .fold<double>(0.0, (sum, o) => sum + o.total);
      });
    } else if (_selectedTabIndex == 1) {
      // 2. This Week
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      filteredOrders = widget.orders.where((o) => o.timestamp.isAfter(sevenDaysAgo)).toList();
      periodTitle = t('ئەم هەفتەیە');
      chartTitle = t('شیکاری فرۆشی ٧ ڕۆژی ڕابردوو');
      chartLabels = ['شەم', 'یەک', 'دوو', 'سێ', 'چوار', 'پێنج', 'هەینی'];
      chartFullLabels = [
        'شەممە',
        'یەکشەممە',
        'دووشەممە',
        'سێشەممە',
        'چوارشەممە',
        'پێنجشەممە',
        'هەینی',
      ];
      chartValues = List.generate(7, (i) {
        final dayOffset = 6 - i;
        final d = now.subtract(Duration(days: dayOffset));
        return filteredOrders
            .where((o) => o.timestamp.year == d.year && o.timestamp.month == d.month && o.timestamp.day == d.day)
            .fold<double>(0.0, (sum, o) => sum + o.total);
      });
    } else {
      // 3. This Month
      filteredOrders = widget.orders.where((o) =>
        o.timestamp.year == now.year && o.timestamp.month == now.month
      ).toList();
      periodTitle = t('ئەم مانگە');
      chartTitle = t('شیکاری فرۆشی ٤ هەفتەی ئەم مانگە');
      chartLabels = ['هەفتەی ١', 'هەفتەی ٢', 'هەفتەی ٣', 'هەفتەی ٤'];
      chartFullLabels = ['هەفتەی یەکەم', 'هەفتەی دووەم', 'هەفتەی سێیەم', 'هەفتەی چوارەم'];
      chartValues = List.generate(4, (weekIdx) {
        final startDay = weekIdx * 7 + 1;
        final endDay = (weekIdx + 1) * 7;
        return filteredOrders
            .where((o) => o.timestamp.day >= startDay && o.timestamp.day <= endDay)
            .fold<double>(0.0, (sum, o) => sum + o.total);
      });
    }

    final double baseSalesLocal = filteredOrders.fold<double>(0.0, (sum, o) => sum + o.total);
    final int baseOrdersLocal = filteredOrders.length;
    final api = _analytics;
    final commissionRatePct = (api?['commission_rate'] as num?)?.toDouble() ?? 20.0;

    // Aggregate Top Selling Products dynamically from filtered orders
    final Map<String, int> productCountMap = {};
    final Map<String, double> productRevMap = {};
    for (final o in filteredOrders) {
      for (final itemStr in o.items) {
        final parts = itemStr.split('x ');
        final qty = parts.length > 1 ? (int.tryParse(parts[0].trim()) ?? 1) : 1;
        final name = parts.length > 1 ? parts.sublist(1).join('x ').trim() : itemStr.trim();
        if (name.isNotEmpty) {
          productCountMap[name] = (productCountMap[name] ?? 0) + qty;
          productRevMap[name] = (productRevMap[name] ?? 0.0) + (o.total / (o.items.isNotEmpty ? o.items.length : 1));
        }
      }
    }

    final sortedProductNames = productCountMap.keys.toList()
      ..sort((a, b) => (productCountMap[b] ?? 0).compareTo(productCountMap[a] ?? 0));

    final int maxSold = sortedProductNames.isNotEmpty ? (productCountMap[sortedProductNames.first] ?? 1) : 1;
    final List<Map<String, dynamic>> topProducts = sortedProductNames.take(5).map((name) {
      final idx = sortedProductNames.indexOf(name) + 1;
      final sold = productCountMap[name] ?? 0;
      final rev = productRevMap[name] ?? 0.0;
      final kuNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      final rankKu = idx.toString().split('').map((c) => int.tryParse(c) != null ? kuNumbers[int.parse(c)] : c).join();
      return {
        'rank': rankKu,
        'name': name,
        'category': 'خواردن و بەرهەم',
        'sold': sold,
        'revenue': rev,
        'image': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&auto=format&fit=crop',
        'percent': maxSold > 0 ? (sold / maxSold).clamp(0.1, 1.0) : 1.0,
      };
    }).toList();

    // Prefer backend realized profit-share: admin_owed = gross_profit × %
    final totalSales = (api?['total_sales'] as num?)?.toDouble() ?? baseSalesLocal;
    final commission = (api?['admin_owed'] as num?)?.toDouble() ??
        (api?['admin_share'] as num?)?.toDouble() ??
        0.0;
    final netProfit = (api?['seller_share'] as num?)?.toDouble() ??
        (api?['net_profit'] as num?)?.toDouble() ??
        (totalSales - commission);
    final baseOrders = (api?['completed_orders_count'] as num?)?.toInt() ?? baseOrdersLocal;
    final avgTicket = baseOrders > 0
        ? ((api?['avg_ticket'] as num?)?.toDouble() ?? (totalSales / baseOrders))
        : 0.0;
    final growthText = baseOrders > 0 ? '+ ٪${(baseOrders * 3.2).toStringAsFixed(1)}' : '٪٠';
    final todayAdminOwed = (api?['today_admin_owed'] as num?)?.toInt() ?? commission.round();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: RegaResponsive.pagePadding(context),
          vertical: 12,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                // 1. Header with title & refresh button
                _buildHeader(context),
                const SizedBox(height: 14),

                // 2. Period Filter Tabs
                _buildTabs(),
                const SizedBox(height: 14),

                // 3. Main Profit Summary Card (Mint Green Card)
                _buildSummaryCard(
                  netProfit: netProfit,
                  totalSales: totalSales,
                  commission: commission,
                  ordersCount: baseOrders,
                  avgTicket: avgTicket,
                  growthText: growthText,
                  periodTitle: periodTitle,
                  commissionRatePct: commissionRatePct,
                  todayAdminOwed: todayAdminOwed,
                  loading: _analyticsLoading,
                ),
                const SizedBox(height: 14),

                // 4. Interactive Chart Card
                _buildChartCard(
                  title: chartTitle,
                  labels: chartLabels,
                  fullLabels: chartFullLabels,
                  values: chartValues,
                ),
                const SizedBox(height: 14),

                // 5. Top Products Card
                _buildTopProductsCard(topProducts),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
  final refreshButton = GestureDetector(
          onTap: () async {
            await widget.onRefresh?.call();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t('داهاتی فرۆشیار نوێکرایەوە'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: RC.bg(Color(0xFFEA580C)),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
              boxShadow: [
                BoxShadow(
                  color: RC.bg(Colors.black).withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 18, color: RC.fg(Color(0xFFEA580C))),
                const SizedBox(width: 6),
                Text(
                  t('نوێکردنەوە'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: RC.fg(Color(0xFFEA580C)),
                  ),
                ),
              ],
            ),
          ),
  );

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('داهاتی فرۆشیار'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: RC.fg(Color(0xFF1E2024)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              t('شیکاری وردی فرۆش و قازانجەکانت'),
              style: TextStyle(
                fontSize: 12,
                color: RC.fg(Color(0xFF8E8E93)),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < RegaBreakpoints.phone) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleColumn,
              const SizedBox(height: 10),
              Align(alignment: AlignmentDirectional.centerStart, child: refreshButton),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: titleColumn),
            refreshButton,
          ],
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(0, t('ئەمڕۆ')),
          _buildTabItem(1, t('ئەم هەفتەیە')),
          _buildTabItem(2, t('ئەم مانگە')),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _selectedBarIndex = null;
          });
          _loadAnalytics();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? RC.bg(Color(0xFFEA580C)) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              tx(title),
              style: TextStyle(
                color: isSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF4B5563)),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required double netProfit,
    required double totalSales,
    required double commission,
    required int ordersCount,
    required double avgTicket,
    required String growthText,
    required String periodTitle,
    double commissionRatePct = 20,
    int todayAdminOwed = 0,
    bool loading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFFFEDD5)), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Net Profit + Growth Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          t('صافی قازانج (قازانجی تۆ)'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: RC.fg(Color(0xFF9A3412)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF7ED)),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: RC.bg(Color(0xFFFED7AA))),
                          ),
                          child: Text(
                            tx(periodTitle),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: RC.fg(Color(0xFFEA580C)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            tx(_formatAmount(netProfit)),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: RC.fg(Color(0xFFEA580C)),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: RC.bg(Color(0xFFEA580C)),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              tx('د.ع'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: RC.fg(Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Growth badge with flipped arrow
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RC.bg(Color(0xFF16A34A)).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: RC.bg(Colors.black).withOpacity(0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.flip(
                      flipX: true,
                      child: Icon(Icons.trending_up, color: RC.fg(Color(0xFF16A34A)), size: 13),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      tx(growthText),
                      style: TextStyle(
                        color: RC.fg(Color(0xFF16A34A)),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // Grid Metrics Card Inside
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                Widget divider() => Container(width: 1, height: 22, color: RC.bg(Color(0xFFE5E7EB)));
                final sales = _buildMetricCol(t('کۆی فرۆش'), '${_formatAmount(totalSales)} د.ع', RC.bg(Color(0xFF1E2024)));
                final commissionCol = _buildMetricCol(
                  'قەرزی ئەدمین (${commissionRatePct.toStringAsFixed(0)}٪)',
                  '${_formatAmount(commission)}- د.ع',
                  RC.bg(Color(0xFFD84315)),
                );
                final orders = _buildMetricCol(t('داواکارییەکان'), '$ordersCount دانە', RC.bg(Color(0xFF1E2024)));
                final avg = _buildMetricCol(t('تێکڕای فرۆش'), '${_formatAmount(avgTicket)} د.ع', RC.bg(Color(0xFFEA580C)));

                if (constraints.maxWidth < RegaBreakpoints.tablet) {
                  return Column(
                    children: [
                      Row(children: [sales, divider(), commissionCol]),
                      const SizedBox(height: 8),
                      Row(children: [orders, divider(), avg]),
                    ],
                  );
                }
                return Row(
                  children: [
                    sales,
                    divider(),
                    commissionCol,
                    divider(),
                    orders,
                    divider(),
                    avg,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: RC.bg(Color(0xFFECFDF5)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RC.bg(Color(0xFF86EFAC))),
            ),
            child: Text(
              tx(loading
                  ? 'بارکردنی حیسابی قازانج…'
                  : 'ئەمڕۆ پێویستە بدرێت بە ئەدمین: ${_formatAmount(todayAdminOwed)} د.ع  (لەسەر قازانج، نەک فرۆش)'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF166534))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color valueColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tx(label),
                style: TextStyle(
                  color: RC.fg(Color(0xFF6B7280)),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tx(value),
                style: TextStyle(
                  color: valueColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required List<String> labels,
    required List<String> fullLabels,
    required List<double> values,
  }) {
    int activeIndex = _selectedBarIndex ?? (values.length - 1);
    double maxVal = values.reduce((curr, next) => curr > next ? curr : next);
    if (maxVal == 0) maxVal = 1;

    String highlightText = '${fullLabels[activeIndex]}: ${_formatAmount(values[activeIndex])} د.ع';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFFFF7ED)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bar_chart, color: RC.fg(Color(0xFFEA580C)), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tx(title),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: RC.fg(Color(0xFF1E2024)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFFFFF7ED)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: RC.bg(Color(0xFFFED7AA))),
                  ),
                  child: Text(
                    tx(highlightText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RC.fg(Color(0xFFEA580C)),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Bar Chart Row
          SizedBox(
            height: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (i) {
                bool isActive = i == activeIndex;
                double normalizedHeight = (values[i] / maxVal) * 90;
                if (normalizedHeight < 12) normalizedHeight = 12;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBarIndex = i;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isActive ? 28 : 22,
                          height: normalizedHeight,
                          decoration: BoxDecoration(
                            color: isActive ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFFFEDD5)),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tx(labels[i]),
                          style: TextStyle(
                            color: isActive ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFF6B7280)),
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(List<Map<String, dynamic>> topProducts) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final titleRow = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFFFF3E0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.workspace_premium, color: RC.fg(Color(0xFFF06400)), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      t('پڕداهاتترین بەرهەمەکان'),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: RC.fg(Color(0xFF1E2024)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
              final subtitle = Text(
                t('بەپێی کۆی فرۆش'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: RC.fg(Color(0xFF8E8E93)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
              if (constraints.maxWidth < RegaBreakpoints.phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleRow,
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleRow),
                  const SizedBox(width: 6),
                  Flexible(child: subtitle),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // List of top products
          ...topProducts.map((p) => _buildTopProductItem(p)),
        ],
      ),
    );
  }

  Widget _buildTopProductItem(Map<String, dynamic> item) {
    Color rankBg = const Color(0xFFF1F3F5);
    Color rankColor = RC.bg(Color(0xFF495057));

    if (item['rank'] == '١') {
      rankBg = RC.bg(Color(0xFFFFF8E1));
      rankColor = RC.bg(Color(0xFFFF8F00));
    } else if (item['rank'] == '٢') {
      rankBg = RC.bg(Color(0xFFECEFF1));
      rankColor = RC.bg(Color(0xFF546E7A));
    } else if (item['rank'] == '٣') {
      rankBg = RC.bg(Color(0xFFEFEBE9));
      rankColor = RC.bg(Color(0xFF6D4C41));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFFAFAF7)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: rankBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  tx(item['rank']),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item['image'],
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 44,
                    height: 44,
                    color: RC.bgn(Colors.grey[200]),
                    child: Icon(Icons.fastfood, color: RC.fg(Colors.grey), size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx(item['name']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: RC.fg(Color(0xFF1E2024)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx('${item['category']} • ${item['sold']} دانە فرۆشراوە'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: RC.fg(Color(0xFF6B7280)),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Revenue
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    tx('${_formatAmount(item['revenue'])} د.ع'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: RC.fg(Color(0xFFEA580C)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress line
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (item['percent'] as double).clamp(0.0, 1.0),
              backgroundColor: RC.bg(Color(0xFFE5E7EB)),
              valueColor: AlwaysStoppedAnimation<Color>(RC.bg(Color(0xFFEA580C))),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String businessName;
  final Function(String) onNameChange;
  final String language;
  final Function(String) onLangChange;

  const SettingsScreen({
    super.key, 
    required this.businessName, 
    required this.onNameChange,
    required this.language,
    required this.onLangChange,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController nameController;
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 23, minute: 0);
  
  final ImagePicker _picker = ImagePicker();
  XFile? _coverImage;
  XFile? _logoImage;

  Future<void> _pickImage(bool isCover) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Directionality(
        textDirection: Trans.direction,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: RC.bgn(Colors.grey[300]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('هەڵبژاردنی وێنە'),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: RC.fg(Color(0xFF1E293B))),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: RC.bgn(Colors.grey[100]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: RC.fg(Colors.grey)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RC.bg(Color(0xFFFF9800)), RC.bg(Color(0xFFF57C00))],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Color(0xFFFF9800)).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: RC.fg(Colors.white), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('کامێرا'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: RC.fg(Color(0xFF1E293B))),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەی نوێ وەبگرە'),
                                style: TextStyle(color: RC.fgn(Colors.grey[600]), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF3E0)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: RC.fg(Color(0xFFFF9800)),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RC.bg(Color(0xFFFF9800)), RC.bg(Color(0xFFF57C00))],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Color(0xFFFF9800)).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.photo_library_rounded, color: RC.fg(Colors.white), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('گالەری'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: RC.fg(Color(0xFF1E293B))),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەیەک لە موبایلەکەت هەڵبژێرە'),
                                style: TextStyle(color: RC.fgn(Colors.grey[600]), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF3E0)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: RC.fg(Color(0xFFFF9800)),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: RC.bg(Color(0xFFE50010)),
                      foregroundColor: RC.fg(Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      t('پاشگەزبوونەوە'),
                      style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (isCover) {
            _coverImage = pickedFile;
          } else {
            _logoImage = pickedFile;
          }
        });
      }
    }
  }

  Widget _buildImagePreview(XFile? file, IconData defaultIcon, {bool isWide = false}) {
    final double width = isWide ? 64 : 48;
    const double height = 48;
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: kIsWeb 
            ? Image.network(
                file.path,
                fit: BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, color: RC.fgn(Colors.grey[400]), size: isWide ? 26 : 22),
              )
            : Image.file(
                File(file.path),
                fit: BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, color: RC.fgn(Colors.grey[400]), size: isWide ? 26 : 22),
              ),
      );
    }
    return Icon(defaultIcon, color: RC.fgn(Colors.grey[400]), size: isWide ? 26 : 22);
  }

  Widget _buildImageSubCard({
    required String title,
    required String buttonText,
    required XFile? imageFile,
    required IconData defaultIcon,
    required VoidCallback onPick,
    bool isWide = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RC.bg(Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(title),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: RC.fg(Color(0xFF1F2937))),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: onPick,
                child: Container(
                  width: isWide ? 64 : 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    border: Border.all(color: RC.bg(Colors.grey[300]!)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _buildImagePreview(imageFile, defaultIcon, isWide: isWide),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: Icon(Icons.upload_outlined, size: 16, color: RC.fg(Color(0xFF00897B))),
                  label: Text(
                    tx(buttonText),
                    style: TextStyle(
                      color: RC.fg(Color(0xFF1F2937)),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: RC.bg(Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: RC.bg(Colors.grey[300]!)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.businessName);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  String formatTime(TimeOfDay time) {
    final int hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final String period = time.hour >= 12 ? "PM" : "AM";
    final String min = time.minute.toString().padLeft(2, '0');
    final String hr = hour.toString().padLeft(2, '0');
    return '$hr:$min $period';
  }

  Future<void> _selectTime(BuildContext context, bool isOpenTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? _openTime : _closeTime,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Trans.direction,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: RegaResponsive.pagePadding(context),
          vertical: 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RC.bg(Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('ڕێکخستنی دوکان'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(t('زانیاری بنەڕەتی، زمان و کاتژمێری کارکردن'), style: TextStyle(color: RC.fgn(Colors.grey[500]), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 1. Working Hours Card (کاتی کارکردن)
            _buildSectionCard(
              title: t('کاتی کارکردن'),
              icon: Icons.access_time,
              iconColor: RC.fg(Color(0xFF00897B)),
              children: [
                Row(
                  children: [
                    // Opening Time (right in RTL)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(t('کاتی کردنەوە')),
                          GestureDetector(
                            onTap: () => _selectTime(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: RC.bg(Color(0xFFF9FAFB)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: RC.bg(Colors.grey[200]!)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx(formatTime(_openTime)),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RC.fg(Color(0xFF1F2937))),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, color: RC.fgn(Colors.grey[400]), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Closing Time (left in RTL)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(t('کاتی داخستن')),
                          GestureDetector(
                            onTap: () => _selectTime(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: RC.bg(Color(0xFFF9FAFB)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: RC.bg(Colors.grey[200]!)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx(formatTime(_closeTime)),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RC.fg(Color(0xFF1F2937))),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, color: RC.fgn(Colors.grey[400]), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. App Language Card (زمانی بەرنامە)
            _buildSectionCard(
              title: t('زمانی بەرنامە'),
              icon: Icons.translate,
              iconColor: RC.fg(Color(0xFFF06400)),
              badge: widget.language == 'ku' ? t('کوردی') : widget.language == 'ar' ? 'عربي' : 'English',
              children: [
                Row(
                  children: [
                    _buildLangBtn(t('کوردی'), 'ku'),
                    const SizedBox(width: 8),
                    _buildLangBtn('عربي', 'ar'),
                    const SizedBox(width: 8),
                    _buildLangBtn('English', 'en'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Appearance (light / dark)
            ValueListenableBuilder<bool>(
              valueListenable: Trans.dark,
              builder: (context, isDark, _) => _buildSectionCard(
                title: t('ڕووکار'),
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: RC.fg(Color(0xFFF06400)),
                badge: isDark ? t('تاریک') : t('ڕووناک'),
                children: [
                  Row(
                    children: [
                      _buildThemeBtn(t('ڕووناک'), Icons.light_mode_rounded, false, isDark),
                      const SizedBox(width: 8),
                      _buildThemeBtn(t('تاریک'), Icons.dark_mode_rounded, true, isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 4. Save Button
            ElevatedButton.icon(
              onPressed: () {
                widget.onNameChange(nameController.text);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('گۆڕانکارییەکان پاشەکەوت کران'))));
              }, 
              icon: Icon(Icons.save_outlined, color: RC.fg(Colors.white), size: 20),
              label: Text(
                t('پاشەکەوتکردنی گۆڕانکارییەکان'),
                style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFF00897B)), 
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ), 
            ),
            const SizedBox(height: 12),
            
            // 5. Logout Button
            ElevatedButton.icon(
              onPressed: () async {
                await context.read<VendorSessionNotifier>().logout();
                if (context.mounted) context.go('/login');
              }, 
              icon: Icon(Icons.logout, color: RC.fg(Colors.white), size: 20),
              label: Text(
                t('چوونە دەرەوە لە هەژمار'),
                style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFD32F2F)),
                foregroundColor: RC.fg(Colors.white),
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildThemeBtn(String label, IconData icon, bool dark, bool current) {
    final selected = dark == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => Trans.setDark(dark),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? RC.bg(Color(0xFFF06400)) : RC.bg(const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RC.bg(Color(0xFFF06400)) : RC.bg(const Color(0xFFE5E7EB)),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? RC.fg(Colors.white) : RC.fg(const Color(0xFF1F2937))),
              const SizedBox(width: 6),
              Text(
                tx(label),
                style: TextStyle(
                  color: selected ? RC.bg(Colors.white) : RC.fg(const Color(0xFF1F2937)),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangBtn(String label, String code) {
    bool isSelected = widget.language == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onLangChange(code),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? RC.bg(Color(0xFFF06400)) : RC.bg(Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? RC.bg(Color(0xFFF06400)) : RC.bg(Colors.grey[200]!),
              width: 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: RC.bg(Color(0xFFF06400)).withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              tx(label),
              style: TextStyle(
                color: isSelected ? RC.bg(Colors.white) : RC.bgn(Colors.grey[800]),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Color? iconColor,
    String? badge,
    required List<Widget> children,
  }) {
    final badgeWidget = badge == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: RC.bg(Color(0xFFFFF3E0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tx(badge),
              style: TextStyle(
                color: RC.fg(Color(0xFFE65100)),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleRow = Row(
                children: [
                  Icon(icon, color: iconColor ?? RC.fg(Color(0xFF00897B)), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx(title),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RC.fg(Color(0xFF111827))),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
              if (badgeWidget == null) return titleRow;
              if (constraints.maxWidth < RegaBreakpoints.phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleRow,
                    const SizedBox(height: 8),
                    Align(alignment: AlignmentDirectional.centerStart, child: badgeWidget),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleRow),
                  const SizedBox(width: 8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool center = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        tx(text),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: RC.fg(Color(0xFF1F2937))),
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return TextField(
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: txn(hint),
        hintStyle: TextStyle(color: RC.fgn(Colors.grey[400]), fontSize: 13),
        filled: true,
        fillColor: RC.bgn(Colors.grey[50]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RC.bg(Colors.grey[200]!)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RC.bg(Colors.grey[200]!)),
        ),
      ),
    );
  }
}
