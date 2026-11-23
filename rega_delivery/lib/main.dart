import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'live_captain_map.dart';
import 'driver_api_service.dart';
import 'blocked_account.dart';
import 'rega_mobile.dart';
import 'app/providers.dart';
import 'app/app_router.dart';
import 'state/driver_nav_notifier.dart';
import 'state/driver_session_notifier.dart';
import 'iraq_phone_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'service_area.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;
import 'map/mapbox_tiles.dart';
import 'rega_i18n.dart';
import 'rega_colors.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (MapboxTiles.accessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(MapboxTiles.accessToken);
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(buildDriverProviders(child: const DeliveryDriverApp()));
}

/// ئەپی سەرەکی شۆفێری گەیاندن بە دیزاینی مۆدێرن و تەواو کوردی
class DeliveryDriverApp extends StatefulWidget {
  const DeliveryDriverApp({super.key});

  @override
  State<DeliveryDriverApp> createState() => _DeliveryDriverAppState();
}

class _DeliveryDriverAppState extends State<DeliveryDriverApp> {
  GoRouter? _router;
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
    final data = await DriverApiService.instance.fetchSupportContacts();
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
    _router ??= createDriverRouter(
      refreshListenable: context.read<DriverSessionNotifier>(),
      authBuilder: (context) {
        final session = context.watch<DriverSessionNotifier>();
        return AuthScreen(
          currentLocale: session.locale,
          onLogin: (phone) async {
            await session.login(phone: phone);
            if (context.mounted) context.go('/map');
          },
        );
      },
      shellBuilder: (context, tabIndex) {
        final session = context.watch<DriverSessionNotifier>();
        return DriverMainScreen(
          currentLocale: session.locale,
          isDark: session.isDark,
          onLanguageChange: session.setLocale,
          onThemeChanged: session.setDark,
          onLogout: () async {
            // session.logout clears Sanctum token + logged_in flag.
            await session.logout();
            if (context.mounted) context.go('/login');
          },
          driverPhone: session.driverPhone,
          initialTabIndex: tabIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSessionNotifier>();
    // Drives tx(): every on-screen string follows the selected language.
    RegaI18n.setLang(session.locale);
    RC.setDark(session.isDark);
    final router = _router;
    if (router == null) return const SizedBox.shrink();

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

    return MaterialApp.router(
      title: 'REGA Delivery',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'NotoKufiArabic',
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.light,
          primary: const Color(0xFF00E676),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'NotoKufiArabic',
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.dark,
          primary: const Color(0xFF00E676),
          surface: const Color(0xFF111827),
        ),
      ),
      themeMode: session.themeMode,
      builder: (context, child) {
        return RegaResponsive.appBuilder(
          context,
          child,
          direction: session.textDirection,
        );
      },
    );
  }
}

final Map<String, Map<String, String>> _trans = {
  'ku': {
    'home': 'نەخشە',
    'orders': 'داواکارییەکان',
    'earnings': 'داهات',
    'profile': 'پڕۆفایل',
    'online': 'ئۆنلاین',
    'offline': 'ئۆفلاین',
    'today': 'ئەمڕۆ',
    'this_week': 'ئەم هەفتەیە',
    'this_month': 'ئەم مانگە',
    'total_earnings': 'داهاتی',
    'bonus': 'پاداشت',
    'avg_delivery': 'تێکرا/گەیاندن',
    'total_deliveries': 'کۆی گەیاندن',
    'online_hours': 'کاتژمێرەکانی ئۆنلاین',
    'customer_tip': 'بەخشیشی کڕیار',
    'earnings_history': 'مێژووی داهاتی گەیاندنەکان',
    'motor_info': 'زانیاری ماتۆڕسکل',
    'motor_type': 'جۆری ماتۆڕ',
    'motor_id': 'ژمارەی ماتۆڕ',
    'motor_model': 'مۆدێل',
    'motor_color': 'ڕەنگی ماتۆڕ',
    'legal_docs': 'بەڵگەنامه یاساییەکان',
    'languages': 'زمانەکان',
    'support': 'پشتیوانی خێرای شۆفێران',
    'logout': 'چوونەدەرەوە لە هەژمار',
    'verified': 'پشتڕاستکراوە',
    'rating': 'هەڵسەنگاندن',
    'completion': 'تەواوکردن',
    'search_hint': 'گەڕان بەپێی ژمارەی داواکاری...',
    'all': 'هەموو',
    'delivered': 'گەیەندراو',
    'cancelled': 'هەڵوەشێندراوە',
    'no_orders': 'هیچ داواکارییەک نەدۆزرایەوە',
    'show_info': 'پیشاندانی بۆکسی زانیارییەکان',
    'iqd': 'دینار',
    'support_title': 'پشتیوانی شۆفێرانی REGA',
    'support_subtitle': 'تیمی ئۆپەراسیۆن و بەڕێوەبردنی گەیاندن',
    'emergency_title': 'حاڵەتی فریاگوزاری یان ڕووداو',
    'emergency_desc': 'لە کاتی کێشەی ئەمنی یان ڕووداوی هاتووچۆ',
    'emergency_btn': 'پەیوەندی بەپەلە',
    'hotline_title': 'هێڵی گەرمی بەڕێوەبەری شۆفێران',
    'hotline_btn': 'پەیوەندی کردن',
    'faq_title': 'پرسیارە باوەکانی شۆفێران:',
    'faq_1_q': 'ئەگەر کڕیار وەڵامی تەلەفۆنی نەدایەوە چی بکەم؟',
    'faq_1_a': 'تکایە لانیکەم ٣ جار لە ماوەی ١٠ خولەکدا پەیوەندی پێوە بکە، ئەگەر وەڵامی نەبوو لە ڕێگەی دوگمەی پشتیوانییەوە داواکاری هەڵوەشێنەوە تۆمار بکە.',
    'faq_2_q': 'ئەگەر چێشتخانە خواردنەکەی ئامادە نەکردبوو؟',
    'faq_2_a': 'دەتوانیت کاتی چاوەڕوانی لە ئەپەکەدا بنووسیت؛ ئەگەر زیاتر لە ١٥ خولەکی خایاند، پاداشتی چاوەڕوانی بۆ هەژمارەکەت زیاد دەبێت.',
    'login_subtitle': 'بەرنامەی تایبەتی شۆفێرانی ماتۆڕسکلی گەیاندن',
    'phone_label': 'ژمارەی مۆبایل',
    'continue': 'بەردەوام بە',
    'footer_text': 'پەیوەستە بە سیستمێی یەکگرتووی مارکێتپڵەیسی REGA',
    'notifications': 'ئاگادارکردنەوەکان',
    'no_notifications': 'هیچ ئاگادارکردنەوەیەکی نوێ نییە',
    'new_order_notif': 'داواکاری نوێی #%s گەیشت',
    'just_now': 'ئێستا',
    'view_details': 'بینینی وردەکاری',
    'status_on_way': 'بەرەو کڕیار',
    'status_waiting': 'چاوەڕوانی شۆفێر',
    'status_delivered': 'گەیەندرا',
    'status_cancelled': 'هەڵوەشێندراوە',
    'follow_driver': 'شوێنکەوتنی شۆفێر',
    'show_full_route': 'پیشاندانی تەواوی ڕێڕەو',
    'map_style': 'گۆڕینی شێوازی نەخشە',
    'phone_gps': 'GPS ی مۆبایل — شوێنی ڕاستەقینەی گەیاندن',
    'gps_locating': 'چاوەڕوانی GPSی مۆبایل...',
    'gps_allow_phone': 'کرتە بکە بۆ ڕێگەدان بە GPS — شوێنی ساختە پیشان نادرێت',
    'gps_required_online': 'بۆ ئۆنلاین بوون پێویستە GPSی مۆبایل کاربکات',
    'gps_missing_online_warn': 'ئۆنلاین بوویت، بەڵام GPS بەردەست نییە — شوێن نوێ ناکرێتەوە هەتا GPS کاربکات',
    'status_update_failed': 'نوێکردنەوەی دۆخی ئۆنلاین سەرکەوتوو نەبوو — پەیوەندی بپشکنە و دووبارە هەوڵ بدە',
    'sim_drive': 'دەمۆی خۆکار',
    'sync_order': 'هاوکاتکردنی نوێترین داواکاری کڕیار',
    'arrived': 'گەیشتم',
    'verify_pin': 'پشتڕاستکردنەوەی PIN',
    'delivery_pin': 'PIN ی گەیاندن',
    'eta': 'کاتی گەیشتن',
    'distance': 'دووری',
    'speed': 'خێرایی',
    'new_order_arrived': 'داواکاری نوێ گەیشت!',
    'order_completed': 'داواکارییەکە تەواو کرا!',
    'accept_new_order': 'وەرگرتنی داواکاری نوێ',
    'waiting_admin_order': 'چاوەڕوانی دیاریکردنی داواکاری لە ئادمینەوە...',
    'go_online_for_orders': 'ئۆفلاینیت • بۆ وەرگرتنی داواکاری ئۆنلاین بە',
    'handover_pin_hint': '🔑 کۆدی وەرگرتن بدە بە فرۆشیار:',
    'merchant_pickup': 'فرۆشیار (وەرگرتن)',
    'customer_dropoff': 'کڕیار (گەیاندن)',
    'items_total': '{count} کاڵا • کۆی گشتی {total} د.ع',
    'badge_new_order': 'داواکاری نوێ',
    'badge_to_merchant': 'بەرەو فرۆشیار',
    'badge_at_merchant': 'گەیشتە فرۆشیار',
    'badge_picked': 'کاڵاکە وەرگیرا',
    'badge_to_customer': 'بەرەو کڕیار',
    'badge_at_customer': 'گەیشتە کڕیار',
    'badge_delivered': 'گەیەندرا',
    'btn_start_to_merchant': 'بەرەو فرۆشیار دەکەومەڕێ',
    'btn_arrived_merchant': 'گەیشتمە لای فرۆشیار',
    'btn_picked_up': 'کاڵاکەم وەرگرت',
    'btn_start_to_customer': 'بەرەو کڕیار بەڕێکەوتم',
    'btn_arrived_customer': 'گەیشتمە لای کڕیار',
    'btn_complete_pin': 'گەیاندن تەواو بکە',
    'btn_completed': 'تەواوکراوە',
    'pin_verify_title': 'پشتڕاستکردنەوەی گەیاندن',
    'pin_verify_hint': 'کۆدی ٤ ژمارەیی لە خاوەن داواکاری وەربگرە',
    'nav_to_merchant': 'بەرەو {name}',
    'nav_at_store': 'لە بەردەم چێشتخانەیت — داواکاری وەربگرە',
    'nav_to_customer': 'بەرەو ماڵی {name}',
    'nav_ask_pin': 'گەیشتیت! گەیاندن تەواو بکە',
    'nav_done': 'گەیاندن تەواوبوو بە سەرکەوتوویی!',
    'gps_live_sync': 'GPS LIVE • چرکە بە چرکە هاوکاتە',
    'gps_live_kalar': 'GPS LIVE • نەخشەی زیندووی کەلار',
    'km_unit': 'کم',
    'm_unit': 'مەتر',
    'dark_mode': 'دۆخی تاریک',
    'light_mode': 'دۆخی ڕووناک',
    'theme': 'ڕووکار',
    'data_refreshed': 'داتا نوێکرایەوە',
  },
  'ar': {
    'home': 'الخريطة',
    'orders': 'الطلبات',
    'earnings': 'الأرباح',
    'profile': 'الملف الشخصي',
    'online': 'متصل',
    'offline': 'غير متصل',
    'today': 'اليوم',
    'this_week': 'هذا الأسبوع',
    'this_month': 'هذا الشهر',
    'total_earnings': 'إجمالي الأرباح',
    'bonus': 'مكافأة',
    'avg_delivery': 'متوسط/طلب',
    'total_deliveries': 'إجمالي الطلبات',
    'online_hours': 'ساعات العمل',
    'customer_tip': 'إكرامية العميل',
    'earnings_history': 'سجل الأرباح',
    'motor_info': 'معلومات الدراجة',
    'motor_type': 'نوع الدراجة',
    'motor_id': 'رقم الدراجة',
    'motor_model': 'الموديل',
    'motor_color': 'اللون',
    'legal_docs': 'الوثائق القانونية',
    'languages': 'اللغات',
    'support': 'دعم السائقين',
    'logout': 'تسجيل الخروج',
    'verified': 'تم التحقق',
    'rating': 'التقييم',
    'completion': 'الإكمال',
    'search_hint': 'البحث برقم الطلب...',
    'all': 'الكل',
    'delivered': 'تم التوصيل',
    'cancelled': 'ملغى',
    'no_orders': 'لم يتم العثور على طلبات',
    'show_info': 'إظهار صندوق المعلومات',
    'iqd': 'دينار',
    'support_title': 'دعم سائقي REGA',
    'support_subtitle': 'فريق العمليات وإدارة التوصيل',
    'emergency_title': 'حالة طوارئ أو حادث',
    'emergency_desc': 'في حالة وجود مشاكل أمنية أو حوادث مرورية',
    'emergency_btn': 'اتصال طارئ',
    'hotline_title': 'الخط الساخن لمدير السائقين',
    'hotline_btn': 'اتصال',
    'faq_title': 'الأسئلة الشائعة للسائقين:',
    'faq_1_q': 'ماذا أفعل إذا لم يرد العميل على الهاتف؟',
    'faq_1_a': 'يرجى الاتصال ٣ مرات على الأقل خلال ١٠ دقائق، إذا لم يكن هناك رد، فقم بتسجيل طلب إلغاء عبر زر الدعم.',
    'faq_2_q': 'ماذا لو لم يجهز المطعم الطعام؟',
    'faq_2_a': 'يمكنك إدخال وقت الانتظار في التطبيق؛ إذا تجاوز ١٥ دقيقة، فستتم إضافة مكافأة انتظار إلى حسابك.',
    'login_subtitle': 'تطبيق خاص لسائقي دراجات التوصيل',
    'phone_label': 'رقم الموبايل',
    'continue': 'استمرار',
    'footer_text': 'مرتبط بنظام موحد لماركت بليس REGA',
    'notifications': 'الإشعارات',
    'no_notifications': 'لا توجد إشعارات جديدة',
    'new_order_notif': 'وصل طلب جديد #%s',
    'just_now': 'الآن',
    'view_details': 'عرض التفاصيل',
    'status_on_way': 'في الطريق',
    'status_waiting': 'في انتظار السائق',
    'status_delivered': 'تم التوصيل',
    'status_cancelled': 'ملغى',
    'follow_driver': 'تتبع السائق',
    'show_full_route': 'عرض المسار الكامل',
    'map_style': 'تغيير نمط الخريطة',
    'phone_gps': 'GPS الهاتف — موقع التوصيل الحقيقي',
    'gps_locating': 'جاري تحديد موقع الهاتف...',
    'gps_allow_phone': 'اضغط للسماح بـ GPS — لن نعرض مكاناً وهمياً',
    'gps_required_online': 'يجب تفعيل GPS الهاتف للاتصال أونلاين',
    'gps_missing_online_warn': 'أنت متصل الآن، لكن GPS غير متاح — لن يُحدَّث الموقع حتى يعمل GPS',
    'status_update_failed': 'تعذر تحديث حالة الاتصال — تحقق من الشبكة وحاول مرة أخرى',
    'sim_drive': 'محاكاة القيادة',
    'sync_order': 'مزامنة أحدث طلب عميل',
    'arrived': 'وصلت',
    'verify_pin': 'تحقق من PIN',
    'delivery_pin': 'رمز التسليم',
    'eta': 'وقت الوصول',
    'distance': 'المسافة',
    'speed': 'السرعة',
    'new_order_arrived': 'وصل طلب جديد!',
    'order_completed': 'تم إكمال الطلب!',
    'accept_new_order': 'استلام طلب جديد',
    'waiting_admin_order': 'بانتظار تعيين طلب من الإدارة...',
    'go_online_for_orders': 'أنت غير متصل • فعّل الاتصال لاستلام الطلبات',
    'handover_pin_hint': '🔑 أعط رمز الاستلام للبائع:',
    'merchant_pickup': 'البائع (الاستلام)',
    'customer_dropoff': 'العميل (التسليم)',
    'items_total': '{count} أصناف • المجموع {total} د.ع',
    'badge_new_order': 'طلب جديد',
    'badge_to_merchant': 'إلى البائع',
    'badge_at_merchant': 'وصل للبائع',
    'badge_picked': 'تم استلام الطلب',
    'badge_to_customer': 'إلى العميل',
    'badge_at_customer': 'وصل للعميل',
    'badge_delivered': 'تم التوصيل',
    'btn_start_to_merchant': 'انطلق نحو البائع',
    'btn_arrived_merchant': 'وصلت إلى البائع',
    'btn_picked_up': 'استلمت الطلب',
    'btn_start_to_customer': 'انطلق نحو العميل',
    'btn_arrived_customer': 'وصلت إلى العميل',
    'btn_complete_pin': 'أكمل التوصيل',
    'btn_completed': 'مكتمل',
    'pin_verify_title': 'تأكيد التسليم',
    'pin_verify_hint': 'خذ الرمز المكون من 4 أرقام من صاحب الطلب',
    'nav_to_merchant': 'إلى {name}',
    'nav_at_store': 'أمام المطعم — استلم الطلب',
    'nav_to_customer': 'إلى منزل {name}',
    'nav_ask_pin': 'وصلت! أكمل التوصيل',
    'nav_done': 'تم التوصيل بنجاح!',
    'gps_live_sync': 'GPS مباشر • مزامنة ثانية بثانية',
    'gps_live_kalar': 'GPS مباشر • خريطة كلار الحية',
    'km_unit': 'كم',
    'm_unit': 'م',
    'dark_mode': 'الوضع الداكن',
    'light_mode': 'الوضع الفاتح',
    'theme': 'المظهر',
    'data_refreshed': 'تم تحديث البيانات',
  },
  'en': {
    'home': 'Map',
    'orders': 'Orders',
    'earnings': 'Earnings',
    'profile': 'Profile',
    'online': 'Online',
    'offline': 'Offline',
    'today': 'Today',
    'this_week': 'This Week',
    'this_month': 'This Month',
    'total_earnings': 'Total Earnings',
    'bonus': 'Bonus',
    'avg_delivery': 'Avg/Delivery',
    'total_deliveries': 'Total Deliveries',
    'online_hours': 'Online Hours',
    'customer_tip': 'Customer Tip',
    'earnings_history': 'Earnings History',
    'motor_info': 'Motorcycle Info',
    'motor_type': 'Type',
    'motor_id': 'ID Number',
    'motor_model': 'Model',
    'motor_color': 'Color',
    'legal_docs': 'Legal Documents',
    'languages': 'Languages',
    'support': 'Driver Support',
    'logout': 'Log Out',
    'verified': 'Verified',
    'rating': 'Rating',
    'completion': 'Completion',
    'search_hint': 'Search by order ID...',
    'all': 'All',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
    'no_orders': 'No orders found',
    'show_info': 'Show Info Box',
    'iqd': 'IQD',
    'support_title': 'REGA Driver Support',
    'support_subtitle': 'Operations and Delivery Management Team',
    'emergency_title': 'Emergency or Incident',
    'emergency_desc': 'In case of security issues or traffic accidents',
    'emergency_btn': 'Emergency Call',
    'hotline_title': 'Driver Manager Hotline',
    'hotline_btn': 'Call',
    'faq_title': 'Driver FAQs:',
    'faq_1_q': 'What if the customer doesnt answer the phone?',
    'faq_1_a': 'Please call at least 3 times within 10 minutes. If no response, register a cancellation request via the support button.',
    'faq_2_q': 'What if the restaurant hasnt prepared the food?',
    'faq_2_a': 'You can enter the waiting time in the app; if it exceeds 15 minutes, a waiting reward will be added to your account.',
    'login_subtitle': 'Dedicated app for delivery motorcycle drivers',
    'phone_label': 'Phone Number',
    'continue': 'Continue',
    'footer_text': 'Connected to REGA Marketplace unified system',
    'notifications': 'Notifications',
    'no_notifications': 'No new notifications',
    'new_order_notif': 'New order #%s received',
    'just_now': 'Just now',
    'view_details': 'View Details',
    'status_on_way': 'On the way',
    'status_waiting': 'Waiting for Driver',
    'status_delivered': 'Delivered',
    'status_cancelled': 'Cancelled',
    'follow_driver': 'Follow driver',
    'show_full_route': 'Show full route',
    'map_style': 'Change map style',
    'phone_gps': 'Phone GPS — real delivery place',
    'gps_locating': 'Getting phone GPS...',
    'gps_allow_phone': 'Tap to allow GPS — fake place will not be shown',
    'gps_required_online': 'Phone GPS is required to go online',
    'gps_missing_online_warn': 'You are online, but GPS is unavailable — location will not update until GPS works',
    'status_update_failed': 'Could not update online status — check connection and try again',
    'sim_drive': 'Auto demo drive',
    'sync_order': 'Sync latest customer order',
    'arrived': 'I arrived',
    'verify_pin': 'Verify PIN',
    'delivery_pin': 'Delivery PIN',
    'eta': 'ETA',
    'distance': 'Distance',
    'speed': 'Speed',
    'new_order_arrived': 'New order arrived!',
    'order_completed': 'Order completed!',
    'accept_new_order': 'Accept new order',
    'waiting_admin_order': 'Waiting for admin to assign an order...',
    'go_online_for_orders': 'You are offline • Go online to receive orders',
    'handover_pin_hint': '🔑 Give pickup code to merchant:',
    'merchant_pickup': 'Merchant (Pickup)',
    'customer_dropoff': 'Customer (Dropoff)',
    'items_total': '{count} items • Total {total} IQD',
    'badge_new_order': 'New order',
    'badge_to_merchant': 'To merchant',
    'badge_at_merchant': 'At merchant',
    'badge_picked': 'Picked up',
    'badge_to_customer': 'To customer',
    'badge_at_customer': 'At customer',
    'badge_delivered': 'Delivered',
    'btn_start_to_merchant': 'Heading to merchant',
    'btn_arrived_merchant': 'Arrived at merchant',
    'btn_picked_up': 'I picked up the order',
    'btn_start_to_customer': 'Heading to customer',
    'btn_arrived_customer': 'Arrived at customer',
    'btn_complete_pin': 'Complete delivery',
    'btn_completed': 'Completed',
    'pin_verify_title': 'Verify delivery',
    'pin_verify_hint': 'Enter the 4-digit code from the customer',
    'nav_to_merchant': 'To {name}',
    'nav_at_store': 'At the store — pick up the order',
    'nav_to_customer': 'To {name}',
    'nav_ask_pin': 'Arrived! Complete the delivery',
    'nav_done': 'Delivery completed successfully!',
    'gps_live_sync': 'GPS LIVE • second-by-second sync',
    'gps_live_kalar': 'GPS LIVE • live Kalar map',
    'km_unit': 'km',
    'm_unit': 'm',
    'dark_mode': 'Dark mode',
    'light_mode': 'Light mode',
    'theme': 'Theme',
    'data_refreshed': 'Data refreshed',
  }
};

String tr(String key, String locale) {
  final code = locale == 'ckb' ? 'ku' : locale;
  return _trans[code]?[key] ?? _trans['ku']?[key] ?? key;
}

String trFill(String key, String locale, Map<String, String> vars) {
  var out = tr(key, locale);
  vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

// ---------------------------------------------------------
// مۆدێلەکان (Data Models)
// ---------------------------------------------------------

enum OrderStatus {
  driverAssigned,
  driverArrivingPickup,
  arrivedPickup,
  pickedUp,
  onTheWay,
  arrivedCustomer,
  delivered,
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final int price;

  const OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });
}

class OrderModel {
  final String id;
  final String orderNumber;
  OrderStatus status;
  final String merchantName;
  final String merchantAddress;
  final String merchantPhone;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final List<OrderItem> items;
  final int deliveryFee;
  final int tip;
  final int? dbId;
  final String handoverPin;
  final String deliveryPin;
  final double storeLat;
  final double storeLng;
  final double customerLat;
  final double customerLng;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.merchantName,
    required this.merchantAddress,
    required this.merchantPhone,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.items,
    required this.deliveryFee,
    required this.tip,
    this.dbId,
    this.handoverPin = '7392',
    required this.deliveryPin,
    this.storeLat = 34.6836,
    this.storeLng = 45.3189,
    this.customerLat = 34.6912,
    this.customerLng = 45.3264,
  });

  int get itemsTotal => items.fold(0, (sum, i) => sum + (i.price * i.quantity));
  int get itemsCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get totalEarnings => deliveryFee + tip;
}

// ---------------------------------------------------------
// ڕووکاری سەرەکی ئەپ (Main Screen with Bottom Nav)
// ---------------------------------------------------------

class DriverMainScreen extends StatefulWidget {
  final String currentLocale;
  final bool isDark;
  final Function(String) onLanguageChange;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLogout;
  final String driverPhone;
  final int initialTabIndex;

  const DriverMainScreen({
    super.key,
    required this.currentLocale,
    this.isDark = false,
    required this.onLanguageChange,
    required this.onThemeChanged,
    required this.onLogout,
    this.driverPhone = '',
    this.initialTabIndex = 0,
  });

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  String t(String key) => _trans[widget.currentLocale]![key] ?? key;
  int _currentTabIndex = 0;
  bool _isOnline = false;
  bool _onlineToggleBusy = false;
  bool _isOrderCardVisible = true;
  bool _hasNewNotifications = false;
  int _todayEarnings = 0;
  int _completedDeliveriesCount = 0;
  int _selectedFilterIndex = 0;
  int _selectedEarningsTimeIndex = 2; // ئۆتۆماتیکی لەسەر 'ئەمڕۆ' بێت
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _driverProfile;
  List<Map<String, dynamic>>? _backendOrdersList;
  final Map<String, Map<String, dynamic>> _earningsCache = {};
  Timer? _driverSyncTimer;
  bool _didStartBackendSync = false;
  String? _lastNotifiedOrderNum;

  // لیستی ئاگادارکردنەوەکان (تەنها لە داتای ڕاستەقینە)
  final List<Map<String, String>> _notifications = [];

  // لیستی هەموو داواکارییەکان بۆ بەشی لیست
  List<Map<String, dynamic>> get _allOrdersData => _backendOrdersList ?? const [];

  List<Map<String, dynamic>> _getFilteredOrders() {
    return _allOrdersData.where((order) {
      // فلتەر بەپێی تاب
      bool matchesTab = true;
      if (_selectedFilterIndex == 1) matchesTab = order['statusType'] == 'delivered';
      if (_selectedFilterIndex == 2) matchesTab = order['statusType'] == 'cancelled';

      // فلتەر بەپێی گەڕان
      bool matchesSearch = order['id'].contains(_searchQuery) ||
          order['merchant'].contains(_searchQuery) ||
          order['customer'].contains(_searchQuery);

      return matchesTab && matchesSearch;
    }).toList();
  }

  // داواکاری چالاک
  late OrderModel _activeOrder;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex;
    _resetActiveOrder();
  }

  @override
  void didUpdateWidget(covariant DriverMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        _currentTabIndex != widget.initialTabIndex) {
      setState(() => _currentTabIndex = widget.initialTabIndex);
    }
  }

  void _goTab(int index) {
    setState(() => _currentTabIndex = index);
    context.read<DriverNavNotifier>().setTabIndex(index);
    context.go(DriverNavNotifier.pathForIndex(index));
  }

  @override
  void dispose() {
    _driverSyncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initBackendDriverSync() async {
    final ok = await DriverApiService.instance.ensureAuthenticated(phone: widget.driverPhone);
    if (!ok || !mounted) return;
    await _refreshBackendDriverData();
    _driverSyncTimer?.cancel();
    _driverSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshBackendDriverData(silent: true);
    });
  }

  OrderStatus _parseBackendDriverStatus(String? driverStatus, String? orderStatus) {
    switch (driverStatus) {
      case 'driver_arriving_pickup':
        return OrderStatus.driverArrivingPickup;
      case 'arrived_pickup':
        return OrderStatus.arrivedPickup;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'on_the_way':
        return OrderStatus.onTheWay;
      case 'arrived_customer':
        return OrderStatus.arrivedCustomer;
      case 'delivered':
        return OrderStatus.delivered;
      default:
        if (orderStatus == 'delivered') return OrderStatus.delivered;
        if (orderStatus == 'on_the_way') return OrderStatus.onTheWay;
        if (orderStatus == 'picked_up') return OrderStatus.pickedUp;
        return OrderStatus.driverAssigned;
    }
  }

  Future<void> _refreshBackendDriverData({bool silent = false}) async {
    final profile = await DriverApiService.instance.fetchProfile();
    final active = await DriverApiService.instance.fetchActiveOrder();
    final history = await DriverApiService.instance.fetchOrdersHistory();
    final todayEarn = await DriverApiService.instance.fetchEarnings(period: 'today');
    final weekEarn = await DriverApiService.instance.fetchEarnings(period: 'week');
    final monthEarn = await DriverApiService.instance.fetchEarnings(period: 'month');

    if (!mounted) return;

    setState(() {
      if (profile != null) {
        _driverProfile = profile;
        // Keep optimistic UI while a toggle request is in flight.
        if (!_onlineToggleBusy) {
          _isOnline = profile['is_online'] == true;
        }
      }

      if (todayEarn != null) {
        _earningsCache['today'] = todayEarn;
        _todayEarnings = (todayEarn['total_earnings'] as num?)?.toInt() ?? _todayEarnings;
        _completedDeliveriesCount =
            (todayEarn['total_deliveries'] as num?)?.toInt() ?? _completedDeliveriesCount;
      }
      if (weekEarn != null) _earningsCache['week'] = weekEarn;
      if (monthEarn != null) _earningsCache['month'] = monthEarn;

      if (active != null) {
        final dbId = (active['id'] as num?)?.toInt();
        final orderNum = (active['order_number'] ?? '#10245').toString();
        final store = (active['store'] as Map<String, dynamic>?) ?? const {};
        final cust = (active['customer'] as Map<String, dynamic>?) ?? const {};
        final rawItems = (active['items'] as List<dynamic>?) ?? const [];
        final mappedItems = rawItems
            .asMap()
            .entries
            .map((e) {
              final m = e.value as Map<String, dynamic>;
              return OrderItem(
                id: '${m['id'] ?? (e.key + 1)}',
                name: (m['product_name'] ?? m['name'] ?? 'خواردنی کەلار').toString(),
                quantity: (m['quantity'] as num?)?.toInt() ?? 1,
                price: ((m['unit_price'] ?? m['price'] ?? 2500) as num).toInt(),
              );
            })
            .toList();

        final nextStatus = _parseBackendDriverStatus(
          active['driver_status']?.toString(),
          active['status']?.toString(),
        );

        _activeOrder = OrderModel(
          dbId: dbId,
          id: 'db_ord_${dbId ?? orderNum}',
          orderNumber: orderNum.startsWith('#') ? orderNum : '#$orderNum',
          status: nextStatus,
          merchantName: (store['name_ku'] ?? 'فرۆشگای کەلار').toString(),
          merchantAddress: (store['address_ku'] ?? 'ناو بازاڕی کەلار').toString(),
          merchantPhone: (store['phone'] ?? '07701112233').toString(),
          customerName: (active['customer_name'] ?? cust['name'] ?? 'کڕیاری ڕێگا').toString(),
          customerAddress: (active['delivery_address'] ?? 'شاری کەلار').toString(),
          customerPhone: (active['customer_phone'] ?? cust['phone'] ?? '07703001001').toString(),
          items: mappedItems.isNotEmpty ? mappedItems : _activeOrder.items,
          deliveryFee: (active['delivery_fee'] as num?)?.toInt() ?? 1500,
          tip: (active['driver_tip'] as num?)?.toInt() ?? 0,
          handoverPin: (active['handover_pin'] ?? '7392').toString(),
          deliveryPin: _activeOrder.deliveryPin,
          storeLat: (store['lat'] as num?)?.toDouble() ?? 34.6836,
          storeLng: (store['lng'] as num?)?.toDouble() ?? 45.3189,
          customerLat: (active['delivery_lat'] as num?)?.toDouble() ?? 34.6912,
          customerLng: (active['delivery_lng'] as num?)?.toDouble() ?? 45.3264,
        );
        if (_lastNotifiedOrderNum != orderNum) {
          _lastNotifiedOrderNum = orderNum;
          _hasNewNotifications = true;
          _notifications.insert(0, {
            'id': orderNum.replaceAll('#', ''),
            'time': 'ئێستا',
            'type': 'order',
          });
          _isOrderCardVisible = true;
        }
      } else {
        _isOrderCardVisible = false;
        _activeOrder = OrderModel(
          id: 'none',
          orderNumber: '',
          status: OrderStatus.driverAssigned,
          merchantName: '',
          merchantAddress: '',
          merchantPhone: '',
          customerName: '',
          customerAddress: '',
          customerPhone: '',
          items: const [],
          deliveryFee: 0,
          tip: 0,
          dbId: null,
          handoverPin: '',
          deliveryPin: '',
        );
      }

      if (history.isNotEmpty) {
        _backendOrdersList = history.map((raw) {
          final m = raw as Map<String, dynamic>;
          final st = (m['status'] ?? 'pending').toString();
          final store = (m['store'] as Map<String, dynamic>?) ?? const {};
          final cust = (m['customer'] as Map<String, dynamic>?) ?? const {};
          final fee = ((m['driver_total_earning'] ?? m['delivery_fee'] ?? 1500) as num).toInt();
          final isDelivered = st == 'delivered';
          final isCancelled = st == 'cancelled' || st == 'rejected';
          final numStr = (m['order_number'] ?? '').toString();
          return <String, dynamic>{
            'id': numStr.startsWith('#') ? numStr : '#$numStr',
            'merchant': (store['name_ku'] ?? 'فرۆشگای کەلار').toString(),
            'customer': (m['customer_name'] ?? cust['name'] ?? 'کڕیار').toString(),
            'statusKey': isDelivered
                ? 'status_delivered'
                : (isCancelled ? 'status_cancelled' : 'status_on_way'),
            'statusType': isDelivered ? 'delivered' : (isCancelled ? 'cancelled' : 'active'),
            'price': '${_formatMoney(fee)} ${t('iqd')}',
            'time': (m['created_at'] ?? '').toString().replaceFirst('T', ' ').split('.').first,
            'statusColor': isDelivered
                ? RC.bg(Color(0xFF16A34A))
                : (isCancelled ? RC.bg(Color(0xFFEF4444)) : RC.bg(Color(0xFFD97706))),
            'statusBg': isDelivered
                ? RC.bg(Color(0xFFDCFCE7))
                : (isCancelled ? RC.bg(Color(0xFFFEE2E2)) : RC.bg(Color(0xFFFEF3C7))),
          };
        }).toList();
      }
    });
  }

  CaptainRouteStage _toCaptainStage(OrderStatus s) {
    switch (s) {
      case OrderStatus.driverAssigned:
        return CaptainRouteStage.assigned;
      case OrderStatus.driverArrivingPickup:
        return CaptainRouteStage.arrivingPickup;
      case OrderStatus.arrivedPickup:
        return CaptainRouteStage.arrivedPickup;
      case OrderStatus.pickedUp:
        return CaptainRouteStage.pickedUp;
      case OrderStatus.onTheWay:
        return CaptainRouteStage.onTheWay;
      case OrderStatus.arrivedCustomer:
        return CaptainRouteStage.arrivedCustomer;
      case OrderStatus.delivered:
        return CaptainRouteStage.delivered;
    }
  }

  OrderStatus _fromCaptainStage(CaptainRouteStage s) {
    switch (s) {
      case CaptainRouteStage.assigned:
        return OrderStatus.driverAssigned;
      case CaptainRouteStage.arrivingPickup:
        return OrderStatus.driverArrivingPickup;
      case CaptainRouteStage.arrivedPickup:
        return OrderStatus.arrivedPickup;
      case CaptainRouteStage.pickedUp:
        return OrderStatus.pickedUp;
      case CaptainRouteStage.onTheWay:
        return OrderStatus.onTheWay;
      case CaptainRouteStage.arrivedCustomer:
        return OrderStatus.arrivedCustomer;
      case CaptainRouteStage.delivered:
        return OrderStatus.delivered;
    }
  }

  void _applySyncedBackendOrder(Map<String, dynamic> data) {
    final store = (data['store'] as Map<String, dynamic>?) ?? const {};
    final cust = (data['customer'] as Map<String, dynamic>?) ?? const {};
    final rawItems = (data['items'] as List<dynamic>?) ?? const [];
    final ref = (data['order_ref'] ?? '10245').toString();

    final mappedItems = rawItems.isNotEmpty
        ? rawItems.asMap().entries.map((e) {
            final m = e.value as Map<String, dynamic>;
            return OrderItem(
              id: '${e.key + 1}',
              name: (m['name'] ?? 'خواردنی کەلار').toString(),
              quantity: (m['quantity'] as num?)?.toInt() ?? 1,
              price: (m['price'] as num?)?.toInt() ?? 5000,
            );
          }).toList()
        : _activeOrder.items;

    final remoteDriverStatus = data['driver_status']?.toString() ?? 'driver_assigned';
    OrderStatus initialStage = OrderStatus.driverAssigned;
    if (remoteDriverStatus == 'driver_arriving_pickup') {
      initialStage = OrderStatus.driverArrivingPickup;
    } else if (remoteDriverStatus == 'arrived_pickup') {
      initialStage = OrderStatus.arrivedPickup;
    } else if (remoteDriverStatus == 'picked_up') {
      initialStage = OrderStatus.pickedUp;
    } else if (remoteDriverStatus == 'on_the_way') {
      initialStage = OrderStatus.onTheWay;
    } else if (remoteDriverStatus == 'arrived_customer') {
      initialStage = OrderStatus.arrivedCustomer;
    } else if (remoteDriverStatus == 'delivered') {
      initialStage = OrderStatus.delivered;
    }

    setState(() {
      _isOrderCardVisible = true;
      _activeOrder = OrderModel(
        id: 'ord_$ref',
        orderNumber: ref.startsWith('#') ? ref : '#$ref',
        status: initialStage,
        merchantName: (store['name'] ?? 'کەبابخانەی کەلار').toString(),
        merchantAddress: (store['address'] ?? 'ناو بازاڕی کەلار').toString(),
        merchantPhone: (store['phone'] ?? '07701112233').toString(),
        customerName: (cust['name'] ?? 'سەربەست عەلی').toString(),
        customerAddress: (cust['address'] ?? 'گەڕەکی شەهیدان، کەلار').toString(),
        customerPhone: (cust['phone'] ?? '07703001001').toString(),
        items: mappedItems,
        deliveryFee: (data['delivery_fee'] as num?)?.toInt() ?? 1500,
        tip: (data['driver_tip'] as num?)?.toInt() ?? 500,
        deliveryPin: (data['delivery_pin'] ?? '4821').toString(),
        storeLat: (store['lat'] as num?)?.toDouble() ?? 34.6836,
        storeLng: (store['lng'] as num?)?.toDouble() ?? 45.3189,
        customerLat: (cust['lat'] as num?)?.toDouble() ?? 34.6912,
        customerLng: (cust['lng'] as num?)?.toDouble() ?? 45.3264,
      );
    });
    _showSuccessSnackBar('داواکاری زیندووی کڕیار (#$ref) هێنرایە سەر نەخشە!');
  }

  Future<void> _notifyBackendDeliveryComplete() async {
    final cleanRef = _activeOrder.orderNumber.replaceAll('#', '').trim();
    try {
      await http
          .post(
            Uri.parse('${DriverApiService.baseUrl}/live-telemetry/$cleanRef/verify-pin'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void _resetActiveOrder() {
    if (!_didStartBackendSync) {
      _didStartBackendSync = true;
      _initBackendDriverSync();
    } else {
      _refreshBackendDriverData();
    }
    _isOrderCardVisible = false;
    _activeOrder = OrderModel(
      id: 'none',
      orderNumber: '',
      status: OrderStatus.driverAssigned,
      merchantName: '',
      merchantAddress: '',
      merchantPhone: '',
      customerName: '',
      customerAddress: '',
      customerPhone: '',
      items: const [],
      deliveryFee: 0,
      tip: 0,
      dbId: null,
      handoverPin: '',
      deliveryPin: '',
    );
  }

  void _updateOrderStatus(OrderStatus nextStatus) {
    if (_activeOrder.dbId != null && nextStatus != OrderStatus.delivered) {
      final mapped = switch (nextStatus) {
        OrderStatus.driverArrivingPickup => 'driver_arriving_pickup',
        OrderStatus.arrivedPickup => 'arrived_pickup',
        OrderStatus.pickedUp => 'picked_up',
        OrderStatus.onTheWay => 'on_the_way',
        OrderStatus.arrivedCustomer => 'arrived_customer',
        _ => null,
      };
      if (mapped != null) {
        DriverApiService.instance.advanceOrderStatus(_activeOrder.dbId!, mapped);
      }
    }
    setState(() {
      _activeOrder.status = nextStatus;
      if (nextStatus == OrderStatus.delivered) {
        _todayEarnings += _activeOrder.totalEarnings;
        _completedDeliveriesCount += 1;
      }
    });
  }

  Future<void> _completeDelivery() async {
    if (_activeOrder.dbId != null) {
      final (ok, msg) = await DriverApiService.instance.completeDelivery(_activeOrder.dbId!);
      if (!mounted) return;
      if (!ok) {
        _showSuccessSnackBar(msg ?? t('btn_complete_pin'));
        return;
      }
    }
    _updateOrderStatus(OrderStatus.delivered);
    await _notifyBackendDeliveryComplete();
    _refreshBackendDriverData(silent: true);
    if (!mounted) return;
    _showSuccessSnackBar(t('nav_done'));
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: RC.fg(Colors.black)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tx(msg), style: TextStyle(fontWeight: FontWeight.bold, color: RC.fg(Colors.black))),
            ),
          ],
        ),
        backgroundColor: RC.bg(Color(0xFF00E676)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // سەرپەڕەی سەرەوە: شۆفێر، ئۆنلاین/ئۆفلاین و داهاتی ئەمڕۆ
            _buildTopAppBar(),
            // ناوەڕۆکی لاپەڕە بەپێی تاب
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildHomeMapScreen(),
                  _buildOrdersListScreen(),
                  _buildEarningsScreen(),
                  _buildProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// Flip Offline ↔ Online immediately in the UI, then persist to backend.
  /// GPS is best-effort and must never leave the pill stuck/dead on web.
  Future<void> _toggleOnlineStatus() async {
    if (_onlineToggleBusy || !mounted) return;

    final previous = _isOnline;
    final nextOnline = !previous;
    setState(() {
      _onlineToggleBusy = true;
      _isOnline = nextOnline;
    });

    // Persist status first (no GPS gate). Coords are attached later if available.
    final updated = await DriverApiService.instance.updateOnlineStatus(nextOnline);

    if (!mounted) return;

    if (updated == null) {
      setState(() {
        _isOnline = previous;
        _onlineToggleBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('status_update_failed')),
          backgroundColor: RC.bg(Color(0xFFDC2626)),
        ),
      );
      return;
    }

    // Prefer server truth when present.
    final serverOnline = updated['is_online'];
    setState(() {
      if (serverOnline is bool) {
        _isOnline = serverOnline;
      } else if (serverOnline != null) {
        _isOnline = serverOnline == true || serverOnline.toString() == '1';
      }
      _onlineToggleBusy = false;
    });

    if (!nextOnline || !mounted) return;

    // Best-effort GPS after Online is already live — never blocks the toggle.
    unawaited(() async {
      try {
        final fix = await _tryCaptureGpsForOnline().timeout(
          const Duration(seconds: 4),
          onTimeout: () => (null, null, true),
        );
        final lat = fix.$1;
        final lng = fix.$2;
        final gpsMissing = fix.$3 || lat == null || lng == null;
        if (lat != null && lng != null) {
          await DriverApiService.instance.updateOnlineStatus(
            true,
            lat: lat,
            lng: lng,
          );
          await DriverApiService.instance.updateLocation(lat, lng);
        } else if (gpsMissing && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('gps_missing_online_warn')),
              backgroundColor: RC.bg(Color(0xFFD97706)),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('gps_missing_online_warn')),
              backgroundColor: RC.bg(Color(0xFFD97706)),
            ),
          );
        }
      }
    }());
  }

  /// Returns `(lat, lng, missing)`. Never throws for denied/unavailable GPS.
  Future<(double?, double?, bool)> _tryCaptureGpsForOnline() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        // Native only — on web this often hangs or navigates away.
        if (!kIsWeb) {
          try {
            await Geolocator.openLocationSettings();
          } catch (_) {}
        }
        return (null, null, true);
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (null, null, true);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.high,
                maximumAge: Duration.zero,
                timeLimit: const Duration(seconds: 3),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 3),
              ),
      );
      return (pos.latitude, pos.longitude, false);
    } catch (_) {
      return (null, null, true);
    }
  }

  // سەرپەڕەی سەرەوە: شێوازی مۆدێرن بە ڕەنگی سەوز و لۆگۆی REGA
  Widget _buildTopAppBar() {
    final phone = RegaResponsive.isPhone(context);
    final padH = RegaResponsive.pagePadding(context);
    final notifBtn = InkWell(
      onTap: () {
        setState(() => _hasNewNotifications = false);
        _showNotificationsBottomSheet();
      },
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(phone ? 8 : 10),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.notifications_none_rounded, color: RC.fg(Colors.white), size: phone ? 24 : 28),
          ),
          if (_hasNewNotifications)
            Positioned(
              right: phone ? 8 : 10,
              top: phone ? 8 : 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFEF4444)),
                  shape: BoxShape.circle,
                  border: Border.all(color: RC.bg(Color(0xFF22C55E)), width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    final logo = SizedBox(
      height: phone ? 40 : 52,
      child: Center(
        child: Image.asset(
          'assets1/navbar_logo.png',
          height: phone ? 36 : 48,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delivery_dining_rounded, color: RC.fg(Colors.white), size: phone ? 20 : 24),
                const SizedBox(width: 8),
                Text(
                  tx('REGA'),
                  style: TextStyle(
                    color: RC.fg(Colors.white),
                    fontWeight: FontWeight.w900,
                    fontSize: phone ? 18 : 22,
                    letterSpacing: 1,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    final onlineToggle = InkWell(
      onTap: _onlineToggleBusy ? null : _toggleOnlineStatus,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedOpacity(
        opacity: _onlineToggleBusy ? 0.75 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: phone ? 3 : 4, vertical: phone ? 3 : 4),
          decoration: BoxDecoration(
            color: _isOnline ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFEF4444)),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: RC.bg(Colors.white), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isOnline) ...[
                if (!phone)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      t('online'),
                      style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  )
                else
                  const SizedBox(width: 6),
                Container(
                  width: phone ? 24 : 28,
                  height: phone ? 24 : 28,
                  decoration: BoxDecoration(color: RC.bg(Colors.white), shape: BoxShape.circle),
                ),
                if (phone) const SizedBox(width: 6),
              ] else ...[
                Container(
                  width: phone ? 24 : 28,
                  height: phone ? 24 : 28,
                  decoration: BoxDecoration(color: RC.bg(Colors.white), shape: BoxShape.circle),
                ),
                if (!phone)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      t('offline'),
                      style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  )
                else
                  const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );

    return Container(
      height: phone ? 72 : 80,
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFF22C55E)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              notifBtn,
              Flexible(child: logo),
              onlineToggle,
            ],
          ),
        ),
      ),
    );
  }

  // لاپەڕەی نەخشە و کارتی داواکاری
  Widget _buildHomeMapScreen() {
    return Stack(
      children: [
        // Real phone GPS Mapbox map (no fake place / no auto-drive)
        Positioned.fill(
          child: CaptainLiveMapWidget(
            orderNumber: _activeOrder.orderNumber,
            stage: _toCaptainStage(_activeOrder.status),
            merchantName: _activeOrder.merchantName,
            merchantAddress: _activeOrder.merchantAddress,
            customerName: _activeOrder.customerName,
            customerAddress: _activeOrder.customerAddress,
            deliveryPin: _activeOrder.deliveryPin,
            storeLat: _activeOrder.storeLat,
            storeLng: _activeOrder.storeLng,
            customerLat: _activeOrder.customerLat,
            customerLng: _activeOrder.customerLng,
            isOnline: _isOnline,
            hasActiveOrder: _activeOrder.dbId != null,
            locale: widget.currentLocale,
            translate: t,
            onStageAutoReached: (nextStage) {
              _updateOrderStatus(_fromCaptainStage(nextStage));
            },
            onArrivedPromptPin: _completeDelivery,
            onNewBackendOrderFound: _applySyncedBackendOrder,
          ),
        ),

        // Refresh live driver/order data from backend
        Positioned(
          top: RegaResponsive.isPhone(context) ? 12 : 96,
          left: RegaResponsive.pagePadding(context),
          child: FloatingActionButton.small(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 3,
            tooltip: t('sync_order'),
            onPressed: () async {
              await _refreshBackendDriverData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('data_refreshed')), duration: const Duration(seconds: 1)),
              );
            },
            child: const Icon(Icons.refresh),
          ),
        ),

        // کارتی سەرەکی داواکاری (Bottom Sheet Card)
        if (_isOrderCardVisible)
          Positioned(
            left: RegaResponsive.pagePadding(context),
            right: RegaResponsive.pagePadding(context),
            bottom: 16,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 580),
                ),
                child: _activeOrder.status == OrderStatus.delivered
                    ? _buildCompletedCard()
                    : ActiveOrderCard(
                        order: _activeOrder,
                        locale: widget.currentLocale,
                        onUpdateStatus: _updateOrderStatus,
                        onRequestPinVerification: _completeDelivery,
                        onClose: () => setState(() => _isOrderCardVisible = false),
                      ),
              ),
            ),
          )
        else if (_activeOrder.dbId != null)
          // دوگمەی پیشاندانەوەی کارت کاتێک کارتەکە داخراوە
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFF22C55E)),
                    foregroundColor: RC.fg(Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: () => setState(() => _isOrderCardVisible = true),
                  child: Text(
                    t('show_info'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          )
        else
          // دۆخی چاوەڕوانی: هیچ داواکارییەک لە لایەن ئادمینەوە دیاری نەکراوە
          Positioned(
            left: RegaResponsive.pagePadding(context),
            right: RegaResponsive.pagePadding(context),
            bottom: 24,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 440),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                    boxShadow: [
                      BoxShadow(color: RC.bg(Color(0x14000000)), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.two_wheeler_rounded, color: RC.fg(Color(0xFFEA580C)), size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          tx(_isOnline
                              ? t('waiting_admin_order')
                              : t('go_online_for_orders')),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: RC.fg(Color(0xFF0F172A))),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // کارتی کاتی تەواوبوونی گەیاندن
  Widget _buildCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: RC.bg(Colors.black12), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RC.bg(Color(0xFFE8F5E9)),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, color: RC.fg(Color(0xFF00C853)), size: 36),
          ),
          const SizedBox(height: 12),
          Text(t('order_completed'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            tx('بڕی ${_formatMoney(_activeOrder.totalEarnings)} د.ع زیادکرا بۆ باڵانسەکەت'),
            style: TextStyle(color: RC.fg(Colors.grey.shade600), fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFF00E676)),
                foregroundColor: RC.fg(Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() => _resetActiveOrder());
              },
              child: Text(t('accept_new_order'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // لاپەڕەی داهات (Earnings Screen) ڕێک وەک وێنەکە
  Widget _buildEarningsScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: RegaResponsive.pagePadding(context),
            vertical: 16,
          ),
          children: [
            // ١. سەردێڕ و دەقی لاوەکی
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('earnings'),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                ),
                Text(
                  tx('Analytics & Insights'),
                  style: TextStyle(fontSize: 14, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ٢. تابی کات (ئەمڕۆ، ئەم هەفتەیە، ئەم مانگە)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTimeTab(t('this_month'), _selectedEarningsTimeIndex == 0, onTap: () => setState(() => _selectedEarningsTimeIndex = 0))),
                  Expanded(child: _buildTimeTab(t('this_week'), _selectedEarningsTimeIndex == 1, onTap: () => setState(() => _selectedEarningsTimeIndex = 1))),
                  Expanded(child: _buildTimeTab(t('today'), _selectedEarningsTimeIndex == 2, onTap: () => setState(() => _selectedEarningsTimeIndex = 2))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ٣. کارتی سەرەکی داهات (بەپێی کاتی دیاریکراو دەگۆڕێت)
            _buildMainEarningsCard(),
            const SizedBox(height: 16),

            // ٤. بۆکسەکانی بەخشیش و کاتژمێر
            _buildEarningsSecondaryStats(),
            const SizedBox(height: 24),

            // ٥. سەردێڕی مێژووی داهاتی گەیاندنەکان
            Text(
              t('earnings_history'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
            ),
            const SizedBox(height: 16),

            // ٦. لیستی داواکارییەکان (تەنها لە API)
            if ((_selectedLiveEarnings?['recent'] as List?)?.isNotEmpty == true)
              ...((_selectedLiveEarnings!['recent'] as List).take(10).map((row) {
                final m = Map<String, dynamic>.from(row as Map);
                final id = (m['order_number'] ?? m['id'] ?? '-').toString();
                final time = (m['delivered_at'] ?? m['time'] ?? '').toString();
                final total = '${_formatMoney((m['driver_earning'] as num?)?.toInt() ?? (m['amount'] as num?)?.toInt() ?? 0)} ${t('iqd')}';
                final detail = (m['detail'] ?? total).toString();
                return _buildEarningsHistoryItem(id.startsWith('#') ? id : '#$id', time, total, detail);
              }))
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    t('no_orders').contains('no_orders') ? 'هیچ داهاتێک نییە' : t('no_orders'),
                    style: TextStyle(color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? get _selectedLiveEarnings {
    final key = _selectedEarningsTimeIndex == 2
        ? 'today'
        : (_selectedEarningsTimeIndex == 1 ? 'week' : 'month');
    return _earningsCache[key];
  }

  Widget _buildMainEarningsCard() {
    String label = '${t('total_earnings')} ${t('today')}';
    if (_selectedEarningsTimeIndex == 1) {
      label = '${t('total_earnings')} ${t('this_week')}';
    } else if (_selectedEarningsTimeIndex == 0) {
      label = '${t('total_earnings')} ${t('this_month')}';
    }
    final total = _selectedLiveEarnings != null
        ? '${_formatMoney((_selectedLiveEarnings!['total_earnings'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
        : '0 ${t('iqd')}';
    final bonus = _selectedLiveEarnings != null
        ? '${_formatMoney((_selectedLiveEarnings!['bonus'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
        : '0 ${t('iqd')}';
    final avg = _selectedLiveEarnings != null
        ? '${_formatMoney((_selectedLiveEarnings!['avg_per_delivery'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
        : '0 ${t('iqd')}';
    final count = _selectedLiveEarnings != null
        ? '${_selectedLiveEarnings!['total_deliveries'] ?? 0}'
        : '0';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: RC.bg(Color(0xFFDCFCE7)), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tx(label),
                  style: TextStyle(color: RC.fg(Color(0xFF64748B)), fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFF0FDF4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tx('IQD'), style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              tx(total),
              style: TextStyle(
                fontSize: RegaResponsive.scale(context, 48),
                fontWeight: FontWeight.w900,
                color: RC.fg(Color(0xFF1E293B)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: RC.bg(Color(0xFFF1F5F9))),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final deliveries = Expanded(child: _statItemEarnings(t('total_deliveries'), count));
              final average = Expanded(child: _statItemEarnings(t('avg_delivery'), avg));
              final bonusCol = Expanded(child: _statItemEarnings('${t('bonus')} (Bonus)', bonus, isGreen: true));
              final divider = Container(width: 1, height: 40, color: RC.bg(Color(0xFFF1F5F9)));
              if (constraints.maxWidth < RegaBreakpoints.phone) {
                return Column(
                  children: [
                    Row(children: [deliveries, divider, average]),
                    const SizedBox(height: 12),
                    Row(children: [bonusCol]),
                  ],
                );
              }
              return Row(
                children: [
                  deliveries,
                  divider,
                  average,
                  divider,
                  bonusCol,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSecondaryStats() {
    final hours = '${(_selectedLiveEarnings?['online_hours'] as num?)?.toString() ?? '0'} ${t('hours').contains('hours') ? 'کاتژمێر' : t('hours')}';
    final tips = '${_formatMoney((_selectedLiveEarnings?['tips'] as num?)?.toInt() ?? 0)} ${t('iqd')}';

    return Row(
      children: [
        Expanded(
          child: _buildSecondaryStatBox(
            icon: Icons.timer_outlined,
            iconColor: RC.fg(Color(0xFF3B82F6)),
            iconBg: RC.bg(Color(0xFFEFF6FF)),
            title: t('online_hours'),
            value: hours,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSecondaryStatBox(
            icon: Icons.emoji_events_outlined,
            iconColor: RC.fg(Color(0xFFF59E0B)),
            iconBg: RC.bg(Color(0xFFFFFBEB)),
            title: t('customer_tip'),
            value: tips,
            valueColor: RC.fg(Color(0xFF16A34A)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeTab(String label, bool isSelected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? RC.bg(Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: RC.bg(Colors.black).withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Center(
          child: Text(
            tx(label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryStatBox({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: RC.bg(Colors.black).withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(tx(title), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            tx(value),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor ?? RC.bg(Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  Widget _statItemEarnings(String title, String val, {bool isGreen = false}) {
    return Column(
      children: [
        Text(tx(title), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          tx(val),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isGreen ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsHistoryItem(String id, String time, String price, String breakdown) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx('بینینی وردەکاری داواکاری $id'))),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: RC.bg(Colors.white),
          border: Border(bottom: BorderSide(color: RC.bg(Color(0xFFF1F5F9)))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // لای ڕاست: ID و کات
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tx(id),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                ),
                const SizedBox(height: 4),
                Text(
                  tx(time),
                  style: TextStyle(fontSize: 13, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            // لای چەپ: نرخ و وردەکاری
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(price),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF16A34A))),
                ),
                const SizedBox(height: 4),
                Text(
                  tx(breakdown),
                  style: TextStyle(fontSize: 13, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx(title), style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade600))),
        const SizedBox(height: 2),
        Text(tx(val), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // لاپەڕەی پڕۆفایل (Profile Screen) ڕێک وەک وێنەکە
  Widget _buildProfileScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: RegaResponsive.pagePadding(context),
            vertical: 16,
          ),
          children: [
            // ١. کارتی زانیاری کەسی (Header Card)
            _buildProfileHeaderCard(),
            const SizedBox(height: 16),

            // ٢. کارتی زانیاری ماتۆڕسکل
            _buildMotorcycleInfoCard(),
            const SizedBox(height: 16),

            // ٣. کارتی بەڵگەنامە یاساییەکان
            _buildLegalDocumentsCard(),
            const SizedBox(height: 16),

            // ٤. کارتی زمانەکان
            _buildLanguageSelectionCard(),
            const SizedBox(height: 16),
            _buildThemeSelectionCard(),
            const SizedBox(height: 16),

            // ٥. پشتیوانی خێرای شۆفێران
            _buildSupportTile(),
            const SizedBox(height: 16),

            // ٦. دوگمەی چوونەدەرەوە
            _buildLogoutButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // وێنەی پڕۆفایل و باجی پشتڕاستکردنەوە
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: RC.bg(Color(0xFF22C55E)), width: 3),
                ),
                child: Icon(Icons.person_rounded, size: 64, color: RC.fg(Color(0xFF16A34A))),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFF16A34A)),
                    shape: BoxShape.circle,
                    border: Border.all(color: RC.bg(Colors.white), width: 2),
                  ),
                  child: Icon(Icons.check, color: RC.fg(Colors.white), size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tx((_driverProfile?['user']?['name'] ?? _driverProfile?['name'] ?? '-').toString()),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: RC.bg(Color(0xFFF1F5F9)), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    tx((_driverProfile?['driver_code'] ?? '-').toString()),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF64748B))),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(tx('•'), style: TextStyle(color: RC.fg(Color(0xFFCBD5E1)))),
              ),
              Flexible(
                child: Text(
                  tx((_driverProfile?['user']?['phone'] ?? _driverProfile?['phone'] ?? widget.driverPhone).toString()),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: RC.fg(Color(0xFF64748B)), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // ئامارە خێراکان
          Row(
            children: [
              Expanded(
                child: _buildHeaderStat(
                  'تەواوکردن',
                  '${_driverProfile?['completion_rate'] ?? 0}%',
                  valueColor: RC.fg(Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderStat(
                  'کۆی گەیاندن',
                  '${_driverProfile?['total_deliveries'] ?? 0}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderStat(
                  'هەڵسەنگاندن',
                  '${_driverProfile?['rating'] ?? 0}',
                  isRating: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, {Color? valueColor, bool isRating = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(tx(label), style: TextStyle(fontSize: 11, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRating) ...[
                Icon(Icons.star_rounded, color: RC.fg(Color(0xFFF59E0B)), size: 20),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  tx(value),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isRating ? RC.bg(Color(0xFFF59E0B)) : (valueColor ?? RC.bg(Color(0xFF1E293B))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMotorcycleInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: RC.bg(Color(0xFFDCFCE7)), borderRadius: BorderRadius.circular(100)),
                child: Text(t('verified'), style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        t('motor_info'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.two_wheeler_rounded, color: RC.fg(Color(0xFF16A34A)), size: 24),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 360 ? 1 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 3.2 : 2.0,
                children: [
                  _buildMotorStatItem(t('motor_type'), (_driverProfile?['motor_type'] ?? '-').toString()),
                  _buildMotorStatItem(t('motor_id'), (_driverProfile?['plate_number'] ?? '-').toString()),
                  _buildMotorStatItem(t('motor_model'), (_driverProfile?['model_year'] ?? '-').toString()),
                  _buildMotorStatItem(t('motor_color'), (_driverProfile?['motor_color'] ?? '-').toString()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMotorStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tx(label),
            style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tx(value),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalDocumentsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Text(t('legal_docs'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B)))),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: RC.bg(Color(0xFFEFF6FF)), shape: BoxShape.circle),
                child: Icon(Icons.assignment_rounded, color: RC.fg(Color(0xFF3B82F6)), size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDocumentItem(widget.currentLocale == 'ku' ? 'ناسنامەی باری شارستانی / کارتی نیشتمانی' : (widget.currentLocale == 'ar' ? 'البطاقة الوطنية' : 'National ID Card')),
          _buildDocumentItem(widget.currentLocale == 'ku' ? 'مۆڵەتی شۆفێری ماتۆڕسکل' : (widget.currentLocale == 'ar' ? 'رخصة القيادة' : 'Driver License')),
          _buildDocumentItem(widget.currentLocale == 'ku' ? 'بەڵگەی خاوەندارییەتی ماتۆڕ (ساڵانە)' : (widget.currentLocale == 'ar' ? 'سنوية الدراجة' : 'Motorcycle Registration')),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(String title) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('Viewing $title')))),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: RC.fg(Color(0xFF22C55E)), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tx(title),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF1E293B))),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  t('verified'),
                  style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildThemeSelectionCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isDark ? RC.bg(Color(0xFF1E293B)) : RC.bg(Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  tx(widget.isDark ? t('dark_mode') : t('light_mode')),
                  style: TextStyle(
                    color: widget.isDark ? RC.bg(Color(0xFF00E676)) : RC.bg(Color(0xFF16A34A)),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(t('theme'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isDark ? RC.bg(Color(0xFF1E293B)) : RC.bg(Color(0xFFF0FDF4)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: RC.fg(Color(0xFF16A34A)),
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tx(widget.isDark ? t('dark_mode') : t('light_mode')),
              style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
            ),
            value: widget.isDark,
            activeColor: RC.bg(Color(0xFF00E676)),
            onChanged: widget.onThemeChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectionCard() {
    String currentLangName = 'کوردی';
    if (widget.currentLocale == 'ar') currentLangName = 'العربية';
    if (widget.currentLocale == 'en') currentLangName = 'English';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: RC.bg(Color(0xFFDCFCE7)), borderRadius: BorderRadius.circular(100)),
                child: Text(tx(currentLangName), style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('languages'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B)))),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: RC.bg(Color(0xFFF0FDF4)), shape: BoxShape.circle),
                    child: Icon(Icons.language_rounded, color: RC.fg(Color(0xFF16A34A)), size: 24),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: RC.bg(Color(0xFFF1F5F9)), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Expanded(child: _buildLangOption('English', 'en')),
                Expanded(child: _buildLangOption('العربية', 'ar')),
                Expanded(child: _buildLangOption('کوردی', 'ku')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangOption(String label, String langCode) {
    bool isSelected = widget.currentLocale == langCode;
    return InkWell(
      onTap: () => widget.onLanguageChange(langCode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? RC.bg(Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [BoxShadow(color: RC.bg(Colors.black).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tx(label),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFF64748B)),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(Icons.circle, color: RC.fg(Color(0xFF16A34A)), size: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportTile() {
    return InkWell(
      onTap: () => _showSupportBottomSheet(),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RC.bg(Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            Icon(widget.currentLocale == 'en' ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded, size: 16, color: RC.fg(Color(0xFF94A3B8))),
            const Spacer(),
            Text(t('support'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF1E293B)))),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: RC.bg(Color(0xFFF0FDF4)), shape: BoxShape.circle),
              child: Icon(Icons.help_outline_rounded, color: RC.fg(Color(0xFF16A34A)), size: 24),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: widget.currentLocale == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: RegaResponsive.dialogMaxWidth(ctx, cap: 580),
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.all(RegaResponsive.pagePadding(ctx).clamp(16.0, 24.0)),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: RC.bg(Colors.grey.shade100), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(t('support_title'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B)))),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(t('support_subtitle'), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: RC.bg(Color(0xFFF0FDF4)), shape: BoxShape.circle),
                    child: Icon(Icons.help_outline_rounded, color: RC.fg(Color(0xFF16A34A)), size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Emergency Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFF1F2)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: RC.bg(Color(0xFFFECDD3))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(Color(0xFFEF4444)),
                          foregroundColor: RC.fg(Colors.white),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('Calling Emergency...')))),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(t('emergency_btn'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  t('emergency_title'),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(color: RC.fg(Color(0xFF991B1B)), fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.error_outline_rounded, color: RC.fg(Color(0xFF991B1B)), size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t('emergency_desc'),
                            textAlign: TextAlign.end,
                            style: TextStyle(color: RC.fg(Color(0xFF991B1B)), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Hotline Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
                  boxShadow: [BoxShadow(color: RC.bg(Colors.black).withOpacity(0.02), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            t('hotline_title'),
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: RC.bg(Color(0xFFF0FDF4)), shape: BoxShape.circle),
                          child: Icon(Icons.phone_outlined, color: RC.fg(Color(0xFF16A34A)), size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(Color(0xFF16A34A)),
                          foregroundColor: RC.fg(Colors.white),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('Calling Hotline...')))),
                        icon: const Icon(Icons.phone_in_talk_rounded),
                        label: Text(tx('${t('hotline_btn')} : 0750 000 9372'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // FAQ Section
              Text(t('faq_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B)))),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _buildFAQItem(t('faq_1_q'), t('faq_1_a')),
                    const SizedBox(height: 12),
                    _buildFAQItem(t('faq_2_q'), t('faq_2_a')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx(question), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B)), fontSize: 14)),
          const SizedBox(height: 8),
          Text(tx(answer), style: TextStyle(color: RC.fg(Color(0xFF64748B)), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () => widget.onLogout(),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFFEF4444)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t('logout'),
              style: TextStyle(color: RC.fg(Colors.white), fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            Icon(Icons.logout_rounded, color: RC.fg(Colors.white), size: 22),
          ],
        ),
      ),
    );
  }

  void _showNotificationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: RegaResponsive.dialogMaxWidth(ctx, cap: 580),
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(RegaResponsive.pagePadding(ctx).clamp(14.0, 20.0)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: RC.bg(Colors.grey.shade100), shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 20, color: RC.fg(Colors.black)),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      t('notifications'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 36), // Spacer for balance
                ],
              ),
            ),
            Divider(height: 1, color: RC.bg(Color(0xFFF1F5F9))),
            
            // List
            Expanded(
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: RC.fg(Colors.grey.shade200)),
                          const SizedBox(height: 16),
                          Text(t('no_notifications'), style: TextStyle(color: RC.fg(Colors.grey.shade400))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
                            boxShadow: [BoxShadow(color: RC.bg(Colors.black).withOpacity(0.02), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFFF0FDF4)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.shopping_basket_outlined, color: RC.fg(Color(0xFF16A34A)), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('new_order_notif').replaceAll('%s', notif['id']!),
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: RC.fg(Color(0xFF1E293B))),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tx(notif['time']!),
                                      style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                                    ),
                                    if (RegaResponsive.isPhone(ctx)) ...[
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 28),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            setState(() {
                                              _searchQuery = notif['id']!;
                                              _searchController.text = notif['id']!;
                                            });
                                            _goTab(1);
                                          },
                                          child: Text(t('view_details'), style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontWeight: FontWeight.w900, fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!RegaResponsive.isPhone(ctx)) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _searchQuery = notif['id']!;
                                        _searchController.text = notif['id']!;
                                      });
                                      _goTab(1);
                                    },
                                    child: Text(t('view_details'), style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontWeight: FontWeight.w900, fontSize: 12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  // لاپەڕەی لیستی داواکارییەکان (Orders List Screen) ڕێک وەک وێنەکە
  Widget _buildOrdersListScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ١. سەردێڕی لاپەڕە
            Padding(
              padding: EdgeInsets.fromLTRB(
                RegaResponsive.pagePadding(context),
                16,
                RegaResponsive.pagePadding(context),
                8,
              ),
              child: Text(
                t('orders'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
              ),
            ),

            // ٢. بەشی گەڕان (Search Bar)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: RegaResponsive.pagePadding(context),
                vertical: 8,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: t('search_hint'),
                    hintStyle: TextStyle(fontSize: 13, color: RC.fg(Color(0xFF94A3B8))),
                    prefixIcon: Icon(Icons.search, color: RC.fg(Color(0xFF94A3B8)), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
            ),

            // ٣. فلتەرەکان (Tabs/Filters)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true, // بۆ ئەوەی لە ڕاستەوە دەست پێ بکات
                padding: EdgeInsets.symmetric(horizontal: RegaResponsive.pagePadding(context)),
                child: Row(
                  children: [
                    _buildFilterChip(t('all'), '5', _selectedFilterIndex == 0, onTap: () => setState(() => _selectedFilterIndex = 0)),
                    const SizedBox(width: 8),
                    _buildFilterChip(t('delivered'), '2', _selectedFilterIndex == 1, onTap: () => setState(() => _selectedFilterIndex = 1)),
                    const SizedBox(width: 8),
                    _buildFilterChip(t('cancelled'), '1', _selectedFilterIndex == 2, isDanger: true, onTap: () => setState(() => _selectedFilterIndex = 2)),
                  ],
                ),
              ),
            ),

            // ٤. لیستی داواکارییەکان
            Expanded(
              child: _getFilteredOrders().isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: RC.fg(Colors.grey.shade300)),
                        const SizedBox(height: 16),
                        Text(t('no_orders'), style: TextStyle(color: RC.fg(Colors.grey.shade500))),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final filtered = _getFilteredOrders();
                      final pad = RegaResponsive.pagePadding(context);
                      final cols = RegaResponsive.gridCountForWidth(
                        constraints.maxWidth,
                        phone: 1,
                        tablet: 2,
                        desktop: 2,
                      );
                      if (cols >= 2) {
                        return GridView.builder(
                          padding: EdgeInsets.all(pad),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.7,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            return _buildListOrderCard(
                              id: order['id'],
                              merchant: order['merchant'],
                              customer: order['customer'],
                              status: t(order['statusKey']),
                              price: order['price'],
                              time: order['time'],
                              statusColor: order['statusColor'],
                              statusBg: order['statusBg'],
                            );
                          },
                        );
                      }
                      return ListView.builder(
                        padding: EdgeInsets.all(pad),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          return _buildListOrderCard(
                            id: order['id'],
                            merchant: order['merchant'],
                            customer: order['customer'],
                            status: t(order['statusKey']),
                            price: order['price'],
                            time: order['time'],
                            statusColor: order['statusColor'],
                            statusBg: order['statusBg'],
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String count, bool isSelected, {bool isDanger = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? RC.bg(Color(0xFFE2E8F0)) : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: RC.bg(Colors.black).withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tx(label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? RC.bg(Color(0xFF1E293B)) : RC.bg(Color(0xFF64748B)),
              ),
            ),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                tx(count),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDanger ? RC.bg(Color(0xFFEF4444)) : (isSelected ? RC.bg(Color(0xFF1E293B)) : RC.bg(Color(0xFF64748B))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListOrderCard({
    required String id,
    required String merchant,
    required String customer,
    required String status,
    required String price,
    required String time,
    required Color statusColor,
    required Color statusBg,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ١. بەشی سەرەوە: باری داواکاری (چەپ) و ژمارەی داواکاری (ڕاست)
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    tx(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tx(id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: RC.fg(Color(0xFF1E293B))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ٢. بەشی ناوەڕاست: فرۆشیار -> کڕیار (ڕاست بۆ چەپ)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        tx(customer),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF1E293B))),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward, size: 16, color: RC.fg(Color(0xFF94A3B8))),
                    ),
                    Flexible(
                      child: Text(
                        tx(merchant),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ٣. بەشی خوارەوە: نرخ (چەپ) و کات (ڕاست)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tx(price),
                style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF16A34A)), fontSize: 16),
              ),
              Text(
                tx(time),
                style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // شریتی خوارەوەی ئەپ — brand-green pill active tab (icon + label)
  Widget _buildBottomNav() {
    return Container(
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
            color: RC.bg(Color(0xFF0F172A)).withOpacity(0.04),
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
            constraints: BoxConstraints(
              maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 620),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: RegaResponsive.isPhone(context) ? 6 : 10,
                vertical: 8,
              ),
              child: Row(
                children: [
                  _buildBottomNavItem(
                    index: 0,
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map_rounded,
                    label: t('home'),
                  ),
                  _buildBottomNavItem(
                    index: 1,
                    icon: Icons.format_list_numbered_rounded,
                    activeIcon: Icons.receipt_long_rounded,
                    label: t('orders'),
                  ),
                  _buildBottomNavItem(
                    index: 2,
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: t('earnings'),
                  ),
                  _buildBottomNavItem(
                    index: 3,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: t('profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentTabIndex == index;
    // Same green as Online header / primary chrome (#16A34A)
    const pillGreen = Color(0xFF16A34A);
    const iconColor = Color(0xFF0F172A);

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _goTab(index);
        },
        splashColor: pillGreen.withOpacity(0.2),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 14 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? pillGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? RC.fg(Colors.white) : iconColor,
                  size: 22,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: isSelected
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: Text(
                            tx(label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: RC.fg(Colors.white),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
class ActiveOrderCard extends StatefulWidget {
  final OrderModel order;
  final ValueChanged<OrderStatus> onUpdateStatus;
  final VoidCallback onRequestPinVerification;
  final VoidCallback? onClose;
  final String locale;

  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.onUpdateStatus,
    required this.onRequestPinVerification,
    this.onClose,
    this.locale = 'ku',
  });

  @override
  State<ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends State<ActiveOrderCard> {
  bool _isItemsExpanded = false;

  String _t(String key) => tr(key, widget.locale);

  // دیاریکردنی قۆناغ: ئایا لە قۆناغی فرۆشیارە یان کڕیار
  bool get _isPickupStage =>
      widget.order.status == OrderStatus.driverAssigned ||
      widget.order.status == OrderStatus.driverArrivingPickup ||
      widget.order.status == OrderStatus.arrivedPickup;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig(widget.order.status);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ١. سەرپەڕەی کارت (Card Header) - بە پێچەوانەکراوی وەک داواکاری بەکارهێنەر
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusConfig.badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusConfig.badgeBorder),
                        ),
                        child: Text(
                          tx(statusConfig.badgeLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusConfig.badgeTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tx('${_formatMoney(widget.order.totalEarnings)} د.ع'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: RC.fg(Color(0xFF16A34A)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // بەشی لای چەپ: دوگمەی داخستن (X)
              InkWell(
                onTap: widget.onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFFFEE2E2)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(tx('✕'), style: TextStyle(color: RC.fg(Color(0xFFEF4444)), fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ٢. بەشی زانیاری فرۆشیار / کڕیار (styled-box)
          _buildEntityInfoBox(),
          const SizedBox(height: 12),

          // ٣. بەشی کورتەی بەرهەمەکان (Accordion)
          _buildItemsAccordion(),
          const SizedBox(height: 14),

          // ٤. دوگمەی سەرەکی بە ڕەنگی تایبەتی هەر قۆناغێک
          _buildPrimaryActionButton(statusConfig),
        ],
      ),
    );
  }

  // زانیاری شوێن و فرۆشیار/کڕیار
  Widget _buildEntityInfoBox() {
    final title = _isPickupStage ? _t('merchant_pickup') : _t('customer_dropoff');
    final name = _isPickupStage ? widget.order.merchantName : widget.order.customerName;
    final address = _isPickupStage ? widget.order.merchantAddress : widget.order.customerAddress;
    final lat = _isPickupStage ? widget.order.storeLat : widget.order.customerLat;
    final lng = _isPickupStage ? widget.order.storeLng : widget.order.customerLng;

    Widget infoBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(title),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _isPickupStage ? RC.bg(Color(0xFFC2410C)) : RC.bg(Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tx(name),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF14532D))),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.location_on, size: 12, color: _isPickupStage ? RC.fg(Color(0xFFEA580C)) : RC.bg(Colors.grey.shade500)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  tx(address),
                  style: TextStyle(
                    fontSize: 11,
                    color: _isPickupStage ? RC.bg(Color(0xFF9A3412)) : RC.bg(Colors.grey.shade600),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_isPickupStage) ...[
            const SizedBox(height: 4),
            Text(
              tx('GPS فرۆشگا: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFFEA580C))),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

  final contactActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircularIconButton(Icons.phone, () {
          final phone = _isPickupStage ? widget.order.merchantPhone : widget.order.customerPhone;
          launchUrl(Uri.parse('tel:$phone'));
        }),
        const SizedBox(width: 8),
        _buildCircularIconButton(Icons.navigation, () async {
          final uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
          );
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok && mounted) {
            _showActionToast('نەتوانرا نەخشە بکرێتەوە');
          }
        }),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isPickupStage ? RC.bg(Color(0xFFFFF7ED)) : RC.bg(Color(0xFFF8F9FA)),
        border: Border.all(color: _isPickupStage ? RC.bg(Color(0xFFFED7AA)) : RC.bg(Colors.grey.shade300)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < RegaBreakpoints.phone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoBlock(),
                const SizedBox(height: 10),
                Align(alignment: AlignmentDirectional.centerEnd, child: contactActions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: infoBlock()),
              const SizedBox(width: 8),
              contactActions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildCircularIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFF00E676)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: RC.fg(Colors.black)),
      ),
    );
  }

  // لیستی بەرهەمەکان (Accordion)
  Widget _buildItemsAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isItemsExpanded = !_isItemsExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tx(trFill('items_total', widget.locale, {
                        'count': '${widget.order.items.length}',
                        'total': _formatMoney(widget.order.itemsTotal),
                      })),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF1E293B))),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isItemsExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down, size: 20, color: RC.fg(Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ),
          if (_isItemsExpanded) ...[
            Container(height: 1, color: RC.bg(Color(0xFFE2E8F0))),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.order.items.length,
                separatorBuilder: (ctx, i) => Divider(height: 1, color: RC.bg(Color(0xFFF1F5F9)), indent: 16, endIndent: 16),
                itemBuilder: (ctx, i) {
                  final item = widget.order.items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  tx(item.name),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RC.fg(Color(0xFF1E293B))),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tx('× ${item.quantity}'),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFFEF4444))),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            tx('${_formatMoney(item.price * item.quantity)} د.ع'),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF16A34A))),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // دوگمەی سەرەکی کارتی داواکاری
  Widget _buildPrimaryActionButton(_StatusConfig config) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.buttonBg,
          foregroundColor: config.buttonTextColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () {
          _handleNextStep();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(config.buttonIcon, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tx(config.buttonLabel),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextStep() {
    switch (widget.order.status) {
      case OrderStatus.driverAssigned:
        widget.onUpdateStatus(OrderStatus.driverArrivingPickup);
        break;
      case OrderStatus.driverArrivingPickup:
        widget.onUpdateStatus(OrderStatus.arrivedPickup);
        break;
      case OrderStatus.arrivedPickup:
        widget.onUpdateStatus(OrderStatus.pickedUp);
        break;
      case OrderStatus.pickedUp:
        widget.onUpdateStatus(OrderStatus.onTheWay);
        break;
      case OrderStatus.onTheWay:
        widget.onUpdateStatus(OrderStatus.arrivedCustomer);
        break;
      case OrderStatus.arrivedCustomer:
        widget.onRequestPinVerification();
        break;
      case OrderStatus.delivered:
        break;
    }
  }

  void _showActionToast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx(text)), duration: const Duration(seconds: 1)));
  }

  _StatusConfig _getStatusConfig(OrderStatus status) {
    switch (status) {
      case OrderStatus.driverAssigned:
        return _StatusConfig(
          badgeLabel: _t('badge_new_order'),
          badgeBg: RC.bg(Color(0xFFE8F5E9)),
          badgeBorder: RC.bg(Color(0xFFBBF7D0)),
          badgeTextColor: RC.bg(Color(0xFF16A34A)),
          buttonLabel: _t('btn_start_to_merchant'),
          buttonBg: RC.bg(Color(0xFF22C55E)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.arrow_back,
        );
      case OrderStatus.driverArrivingPickup:
        return _StatusConfig(
          badgeLabel: _t('badge_to_merchant'),
          badgeBg: RC.bg(Color(0xFFEFF6FF)),
          badgeBorder: RC.bg(Color(0xFFBFDBFE)),
          badgeTextColor: RC.bg(Color(0xFF2563EB)),
          buttonLabel: _t('btn_arrived_merchant'),
          buttonBg: RC.bg(Color(0xFF2563EB)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.store,
        );
      case OrderStatus.arrivedPickup:
        return _StatusConfig(
          badgeLabel: _t('badge_at_merchant'),
          badgeBg: RC.bg(Color(0xFFFFF7ED)),
          badgeBorder: RC.bg(Color(0xFFFED7AA)),
          badgeTextColor: RC.bg(Color(0xFFEA580C)),
          buttonLabel: _t('btn_picked_up'),
          buttonBg: RC.bg(Color(0xFFEA580C)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.shopping_bag,
        );
      case OrderStatus.pickedUp:
        return _StatusConfig(
          badgeLabel: _t('badge_picked'),
          badgeBg: RC.bg(Color(0xFFF5F3FF)),
          badgeBorder: RC.bg(Color(0xFFDDD6FE)),
          badgeTextColor: RC.bg(Color(0xFF7C3AED)),
          buttonLabel: _t('btn_start_to_customer'),
          buttonBg: RC.bg(Color(0xFF7C3AED)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.navigation,
        );
      case OrderStatus.onTheWay:
        return _StatusConfig(
          badgeLabel: _t('badge_to_customer'),
          badgeBg: RC.bg(Color(0xFFF0F9FF)),
          badgeBorder: RC.bg(Color(0xFFBAE6FD)),
          badgeTextColor: RC.bg(Color(0xFF0284C7)),
          buttonLabel: _t('btn_arrived_customer'),
          buttonBg: RC.bg(Color(0xFF0284C7)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.home,
        );
      case OrderStatus.arrivedCustomer:
        return _StatusConfig(
          badgeLabel: _t('badge_at_customer'),
          badgeBg: RC.bg(Color(0xFFECFDF5)),
          badgeBorder: RC.bg(Color(0xFFA7F3D0)),
          badgeTextColor: RC.bg(Color(0xFF059669)),
          buttonLabel: _t('btn_complete_pin'),
          buttonBg: RC.bg(Color(0xFF059669)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.check_circle,
        );
      case OrderStatus.delivered:
        return _StatusConfig(
          badgeLabel: _t('badge_delivered'),
          badgeBg: RC.bg(Color(0xFFE8F5E9)),
          badgeBorder: RC.bg(Color(0xFFBBF7D0)),
          badgeTextColor: RC.bg(Color(0xFF16A34A)),
          buttonLabel: _t('btn_completed'),
          buttonBg: RC.bg(Color(0xFF16A34A)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.check,
        );
    }
  }
}

class _StatusConfig {
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeTextColor;
  final String buttonLabel;
  final Color buttonBg;
  final Color buttonTextColor;
  final IconData buttonIcon;

  _StatusConfig({
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeTextColor,
    required this.buttonLabel,
    required this.buttonBg,
    required this.buttonTextColor,
    required this.buttonIcon,
  });
}

// نەخشەی نەخشێندراوی تایبەت (Custom Map Painter)
// ---------------------------------------------------------

class DeliveryMapPainterWidget extends StatefulWidget {
  final OrderStatus status;

  const DeliveryMapPainterWidget({super.key, required this.status});

  @override
  State<DeliveryMapPainterWidget> createState() => _DeliveryMapPainterWidgetState();
}

class _DeliveryMapPainterWidgetState extends State<DeliveryMapPainterWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _MapCanvasPainter(
            pulseValue: _pulseController.value,
            status: widget.status,
          ),
        );
      },
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final double pulseValue;
  final OrderStatus status;

  _MapCanvasPainter({required this.pulseValue, required this.status});

  @override
  void paint(Canvas canvas, Size size) {
    // ١. باکگراوندی ڕووی نەخشە
    final bgPaint = Paint()..color = RC.bg(Color(0xFFE5E7EB));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ٢. ناوچە سەوزەکان (پارکەکان)
    final parkPaint = Paint()..color = RC.bg(Color(0xFFDCFCE7));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.1, size.width * 0.35, size.height * 0.22), const Radius.circular(20)), parkPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.55, size.height * 0.45, size.width * 0.38, size.height * 0.18), const Radius.circular(24)), parkPaint);

    // ٣. ڕێگاکان (Street grid)
    final roadPaint = Paint()
      ..color = RC.bg(Colors.white)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = RC.bg(Color(0xFFD1D5DB))
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // هێڵەکانی شەقام
    final path = Path()
      ..moveTo(0, size.height * 0.25)
      ..lineTo(size.width, size.height * 0.28)
      ..moveTo(0, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.45)
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.25, size.height)
      ..moveTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.68, size.height);

    canvas.drawPath(path, roadBorderPaint);
    canvas.drawPath(path, roadPaint);

    // ٤. شوێنی شۆفێر، فرۆشیار و کڕیار
    final driverOffset = Offset(size.width * 0.35, size.height * 0.38);
    final vendorOffset = Offset(size.width * 0.68, size.height * 0.27);
    final customerOffset = Offset(size.width * 0.28, size.height * 0.18);

    // هێڵی ڕێڕەو (Route Path)
    final routePaint = Paint()
      ..color = RC.bg(Color(0xFF00E676))
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final routePath = Path()
      ..moveTo(driverOffset.dx, driverOffset.dy)
      ..lineTo(vendorOffset.dx, vendorOffset.dy)
      ..lineTo(customerOffset.dx, customerOffset.dy);

    canvas.drawPath(routePath, routePaint);

    // ٥. نەخشاندنی نیشانەکانی فرۆشیار (چێشتخانە)
    _drawMarker(
      canvas: canvas,
      center: vendorOffset,
      icon: Icons.storefront,
      color: RC.bg(Color(0xFFEA580C)),
      label: tx('دیوان'),
    );

    // ٦. نەخشاندنی نیشانەی کڕیار (ماڵ)
    _drawMarker(
      canvas: canvas,
      center: customerOffset,
      icon: Icons.home,
      color: RC.bg(Color(0xFF0284C7)),
      label: tx('ئاراس'),
    );

    // ٧. نەخشاندنی شۆفێر بە لەرەی بازنەیی (Pulse Wave)
    final pulsePaint = Paint()
      ..color = RC.bg(Color(0xFF00E676)).withOpacity(1.0 - pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(driverOffset, 16 + (pulseValue * 22), pulsePaint);

    final driverBgPaint = Paint()..color = RC.bg(Color(0xFF00E676));
    canvas.drawCircle(driverOffset, 18, driverBgPaint);

    final driverBorderPaint = Paint()
      ..color = RC.bg(Colors.black)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(driverOffset, 18, driverBorderPaint);

    _drawIconOnCanvas(canvas, Icons.two_wheeler, driverOffset, RC.bg(Colors.black), 18);
  }

  void _drawMarker({
    required Canvas canvas,
    required Offset center,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    // باکگراوندی دەرەوە
    canvas.drawCircle(center, 16, Paint()..color = color);
    canvas.drawCircle(center, 16, Paint()..color = RC.bg(Colors.white)..strokeWidth = 2..style = PaintingStyle.stroke);

    // ئایکۆن
    _drawIconOnCanvas(canvas, icon, center, RC.bg(Colors.white), 16);

    // نیشانەی تێکست
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: RC.fg(Colors.black87),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: RC.bg(Colors.white),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    textPainter.paint(canvas, Offset(center.dx - (textPainter.width / 2), center.dy + 18));
  }

  void _drawIconOnCanvas(Canvas canvas, IconData icon, Offset offset, Color color, double size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(offset.dx - (textPainter.width / 2), offset.dy - (textPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.status != status;
  }
}

// ---------------------------------------------------------
// یاریدەدەرەکانی ژمارە و ڕێکخستن
// ---------------------------------------------------------

String _formatMoney(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}

class PositionMesh extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Widget child;

  const PositionMesh({super.key, this.top, this.right, this.bottom, this.left, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(top: top, right: right, bottom: bottom, left: left, child: child);
  }
}

// ---------------------------------------------------------
// شاشەی چوونەژوورەوە (Auth Screen) ڕێک وەک وێنەکە
// ---------------------------------------------------------

class AuthScreen extends StatefulWidget {
  final String currentLocale;
  final Future<void> Function(String phone) onLogin;

  const AuthScreen({
    super.key,
    required this.currentLocale,
    required this.onLogin,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _authPhoneCtrl = TextEditingController();
  final TextEditingController _authPasswordCtrl = TextEditingController();
  bool _isAuthenticating = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _authPhoneCtrl.dispose();
    _authPasswordCtrl.dispose();
    super.dispose();
  }
  String t(String key) => _trans[widget.currentLocale]![key] ?? key;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg(Color(0xFFF1F5F9)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: RegaResponsive.pagePadding(context),
              vertical: 40,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 440),
              ),
            child: Container(
              padding: EdgeInsets.all(
                RegaResponsive.scale(context, 32).clamp(18.0, 32.0),
              ),
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: RC.bg(Colors.black).withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Image
                SizedBox(
                  height: 100,
                  child: Image.asset(
                    'assets1/navbar_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.delivery_dining_rounded, size: 80, color: RC.fg(Color(0xFF16A34A))),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tx('REGA'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Color(0xFF1E293B)),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('login_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: RC.fg(Color(0xFF94A3B8)),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                // Phone Input Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('phone_label'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1.5),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _authPhoneCtrl,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [IraqPhoneFormatter()],
                          decoration: InputDecoration(
                            hintText: txn(IraqPhoneFormatter.hint),
                            border: InputBorder.none,
                            suffixIcon: Icon(Icons.phone_android_rounded, color: RC.fg(Color(0xFF94A3B8))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('password_label').contains('password_label') ? 'وشەی تێپەڕ' : t('password_label'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1.5),
                      ),
                      child: TextField(
                        controller: _authPasswordCtrl,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: tx('••••••••'),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: RC.fg(Color(0xFF94A3B8))),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: RC.fg(Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RC.bg(Color(0xFF16A34A)),
                      foregroundColor: RC.fg(Colors.white),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isAuthenticating
                        ? null
                        : () async {
                            setState(() => _isAuthenticating = true);
                            try {
                              final ok = await DriverApiService.instance.ensureAuthenticated(
                                phone: _authPhoneCtrl.text,
                                password: _authPasswordCtrl.text,
                              );
                              if (!mounted) return;
                              setState(() => _isAuthenticating = false);
                              if (ok) {
                                await widget.onLogin(_authPhoneCtrl.text.trim());
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t('login_failed') == 'login_failed'
                                      ? 'چوونە ژوورەوە سەرکەوتوو نەبوو'
                                      : t('login_failed'))),
                                );
                              }
                            } on AccountBlockedException catch (e) {
                              if (!mounted) return;
                              setState(() => _isAuthenticating = false);
                              await BlockedAccountContacts.show(context, e);
                            }
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 20), // Back arrow is forward in RTL
                        const SizedBox(width: 12),
                        Text(
                          t('continue'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_rounded, color: RC.fg(Color(0xFF16A34A)), size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t('footer_text'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: RC.fg(Color(0xFF94A3B8)),
                          fontWeight: FontWeight.w600,
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
      ),
    ),
  );
  }
}
