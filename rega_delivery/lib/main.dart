import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'live_captain_map.dart';
import 'driver_api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DeliveryDriverApp());
}

/// ئەپی سەرەکی شۆفێری گەیاندن بە دیزاینی مۆدێرن و تەواو کوردی
class DeliveryDriverApp extends StatefulWidget {
  const DeliveryDriverApp({super.key});

  @override
  State<DeliveryDriverApp> createState() => _DeliveryDriverAppState();
}

class _DeliveryDriverAppState extends State<DeliveryDriverApp> {
  String _locale = 'ku';
  bool _isLoggedIn = true; // گۆڕینی بۆ true بۆ تێست، دواتر دەکرێتە false
  final String _driverPhone = '07501234567';

  void _changeLanguage(String lang) {
    setState(() {
      _locale = lang;
    });
  }

  void _handleLogin() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    DriverApiService.instance.logout();
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REGA Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        textTheme: GoogleFonts.notoKufiArabicTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          primary: const Color(0xFF00E676),
          surface: Colors.white,
        ),
      ),
      home: Directionality(
        textDirection: _locale == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: _isLoggedIn 
          ? DriverMainScreen(
              currentLocale: _locale, 
              onLanguageChange: _changeLanguage,
              onLogout: _handleLogout,
              driverPhone: _driverPhone,
            )
          : AuthScreen(
              currentLocale: _locale,
              onLogin: _handleLogin,
            ),
      ),
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
  }
};

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
  final Function(String) onLanguageChange;
  final VoidCallback onLogout;
  final String driverPhone;

  const DriverMainScreen({
    super.key,
    required this.currentLocale,
    required this.onLanguageChange,
    required this.onLogout,
    this.driverPhone = '07501234567',
  });

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  String t(String key) => _trans[widget.currentLocale]![key] ?? key;
  int _currentTabIndex = 0;
  bool _isOnline = true;
  bool _isOrderCardVisible = true;
  bool _hasNewNotifications = true; // نیشانەی سوور بۆ ئاگادارکردنەوەی نوێ
  int _todayEarnings = 28500;
  int _completedDeliveriesCount = 8;
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

  // لیستی ئاگادارکردنەوەکان
  final List<Map<String, String>> _notifications = [
    {'id': '10245', 'time': 'ئێستا', 'type': 'order'},
    {'id': '10244', 'time': '١٠ خولەک پێش ئێستا', 'type': 'order'},
    {'id': '10240', 'time': '١ کاتژمێر پێش ئێستا', 'type': 'order'},
  ];

  // لیستی هەموو داواکارییەکان بۆ بەشی لیست
  List<Map<String, dynamic>> get _allOrdersData =>
      (_backendOrdersList != null && _backendOrdersList!.isNotEmpty)
          ? _backendOrdersList!
          : [
    {
      'id': '#10245',
      'merchant': 'چێشتخانەی دیوان',
      'customer': 'ئاراس ڕەحمان',
      'statusKey': 'status_on_way',
      'statusType': 'active', // بەرەو کڕیار / چاوەڕوانی شۆفێر
      'price': '4,000 ' + t('iqd'),
      'time': 'Oct • 7:37 PM 23',
      'statusColor': const Color(0xFF16A34A),
      'statusBg': const Color(0xFFDCFCE7),
    },
    {
      'id': '#10246',
      'merchant': 'پیتزا و بێرگەری زەیتون',
      'customer': 'سۆران محەمەد',
      'statusKey': 'status_waiting',
      'statusType': 'active',
      'price': '2,500 ' + t('iqd'),
      'time': 'Oct • 7:42 PM 23',
      'statusColor': const Color(0xFFD97706),
      'statusBg': const Color(0xFFFEF3C7),
    },
    {
      'id': '#10240',
      'merchant': 'شاوەرمەی بەرهەکە',
      'customer': 'شێرزاد عوسمان',
      'statusKey': 'status_delivered',
      'statusType': 'delivered',
      'price': '2,500 ' + t('iqd'),
      'time': 'Oct • 6:30 PM 23',
      'statusColor': const Color(0xFF16A34A),
      'statusBg': const Color(0xFFDCFCE7),
    },
    {
      'id': '#10238',
      'merchant': 'کافێ و شیرینی شاری ج...',
      'customer': 'لانە کامە...',
      'statusKey': 'status_delivered',
      'statusType': 'delivered',
      'price': '3,000 ' + t('iqd'),
      'time': 'Oct • 7:18 AM 23',
      'statusColor': const Color(0xFF16A34A),
      'statusBg': const Color(0xFFDCFCE7),
    },
    {
      'id': '#10230',
      'merchant': 'فۆستەر بێرگەر',
      'customer': 'محمد عەلی',
      'statusKey': 'status_cancelled',
      'statusType': 'cancelled',
      'price': '4,500 ' + t('iqd'),
      'time': 'Oct • 6:30 AM 23',
      'statusColor': const Color(0xFFEF4444),
      'statusBg': const Color(0xFFFEE2E2),
    },
  ];

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
    _resetActiveOrder();
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
        if (!silent) {
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
                ? const Color(0xFF16A34A)
                : (isCancelled ? const Color(0xFFEF4444) : const Color(0xFFD97706)),
            'statusBg': isDelivered
                ? const Color(0xFFDCFCE7)
                : (isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
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

    setState(() {
      _isOrderCardVisible = true;
      _activeOrder = OrderModel(
        id: 'ord_$ref',
        orderNumber: ref.startsWith('#') ? ref : '#$ref',
        status: OrderStatus.driverArrivingPickup,
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

  Future<void> _notifyBackendPinVerified() async {
    final cleanRef = _activeOrder.orderNumber.replaceAll('#', '').trim();
    try {
      await http
          .post(
            Uri.parse('http://127.0.0.1:8001/api/v1/live-telemetry/$cleanRef/verify-pin'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'pin': _activeOrder.deliveryPin}),
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
    _isOrderCardVisible = true;
    _activeOrder = OrderModel(
      id: 'ord_10245',
      orderNumber: '#10245',
      status: OrderStatus.driverAssigned,
      merchantName: 'چێشتخانەی دیوان',
      merchantAddress: 'شەقامی ٦٠ مەتری، نزیک پارکی سامی عەبدولڕەحمان',
      merchantPhone: '0750 444 8899',
      customerName: 'ئاراس ڕەحمان',
      customerAddress: 'گەڕەکی بەختیاری، کۆڵانی ١٤، خانوو ٨',
      customerPhone: '0770 333 1122',
      items: [
        const OrderItem(id: '1', name: 'کەبابی کوردی تایبەت (٢ شیش)', quantity: 2, price: 7000),
        const OrderItem(id: '2', name: 'برنجی کوردی بە پەتاتە', quantity: 1, price: 4000),
        const OrderItem(id: '3', name: 'دۆی خۆماڵی گەورە', quantity: 2, price: 2000),
      ],
      deliveryFee: 3500,
      tip: 1000,
      deliveryPin: '4821', // کۆدی OTP بۆ پشتڕاستکردنەوە
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

  void _openPinVerification() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: PinVerificationBottomSheet(
          orderNumber: _activeOrder.orderNumber,
          correctPin: _activeOrder.deliveryPin,
          onBackendVerify: _activeOrder.dbId != null
              ? (pin) => DriverApiService.instance.verifyDeliveryPin(_activeOrder.dbId!, pin)
              : null,
          onSuccess: () {
            Navigator.pop(ctx);
            _updateOrderStatus(OrderStatus.delivered);
            _notifyBackendPinVerified();
            _refreshBackendDriverData(silent: true);
            _showSuccessSnackBar('گەیاندنەکە بە سەرکەوتوویی کۆتایی هات! پیرۆزە.');
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.black),
            const SizedBox(width: 8),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          ],
        ),
        backgroundColor: const Color(0xFF00E676),
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

  // سەرپەڕەی سەرەوە: شێوازی مۆدێرن بە ڕەنگی سەوز و لۆگۆی REGA
  Widget _buildTopAppBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF22C55E), // ڕەنگی سەوزی براند
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ئایکۆنی ئاگادارکردنەوەکان (Right in RTL - Index 0)
          InkWell(
            onTap: () {
              setState(() => _hasNewNotifications = false);
              _showNotificationsBottomSheet();
            },
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                ),
                if (_hasNewNotifications)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // لۆگۆی REGA (بەکارهێنانی وێنە لە جیاتی تێکست)
          SizedBox(
            height: 52,
            child: Center(
              child: Image.asset(
                'assets1/navbar_logo.png',
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // ئەگەر وێنەکە نەبوو، ئەم بەشە پیشان دەدات (وەک جێگرەوە)
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'REGA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // سویچی ئۆنلاین/ئۆفلاین (Left in RTL - Index 2)
          InkWell(
            onTap: () {
              final nextOnline = !_isOnline;
              setState(() => _isOnline = nextOnline);
              DriverApiService.instance.updateOnlineStatus(nextOnline);
            },
            borderRadius: BorderRadius.circular(100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isOnline) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        t('online'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ] else ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        t('offline'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // لاپەڕەی نەخشە و کارتی داواکاری
  Widget _buildHomeMapScreen() {
    return Stack(
      children: [
        // نەخشەی نەخشێندراوی تایبەت (Simulated interactive map canvas)
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
            onStageAutoReached: (nextStage) {
              _updateOrderStatus(_fromCaptainStage(nextStage));
            },
            onArrivedPromptPin: _openPinVerification,
            onNewBackendOrderFound: _applySyncedBackendOrder,
          ),
        ),

        // دوگمەی سەر نەخشە بۆ ڕیسێت / داواکاری نوێ
        Positioned(
          top: 96,
          left: 16,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 3,
            tooltip: 'داواکاری نوێ',
            onPressed: () {
              setState(() {
                _resetActiveOrder();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('داواکاری نوێ گەیشت!'), duration: Duration(seconds: 1)),
              );
            },
            child: const Icon(Icons.refresh),
          ),
        ),

        // کارتی سەرەکی داواکاری (Bottom Sheet Card)
        if (_isOrderCardVisible)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _activeOrder.status == OrderStatus.delivered
                ? _buildCompletedCard()
                : ActiveOrderCard(
                    order: _activeOrder,
                    onUpdateStatus: _updateOrderStatus,
                    onRequestPinVerification: _openPinVerification,
                    onClose: () => setState(() => _isOrderCardVisible = false),
                  ),
          )
        else
          // دوگمەی پیشاندانەوەی کارت (وەک ناو وێنەکە) کاتێک کارتەکە داخراوە
          Positioned(
            left: 40,
            right: 40,
            bottom: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: () => setState(() => _isOrderCardVisible = true),
              child: const Text(
                'پیشاندانی بۆکسی زانیارییەکان',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF00C853), size: 36),
          ),
          const SizedBox(height: 12),
          const Text('داواکارییەکە تەواو کرا!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'بڕی ${_formatMoney(_activeOrder.totalEarnings)} د.ع زیادکرا بۆ باڵانسەکەت',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() => _resetActiveOrder());
              },
              child: const Text('وەرگرتنی داواکاری نوێ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // لاپەڕەی داهات (Earnings Screen) ڕێک وەک وێنەکە
  Widget _buildEarningsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ١. سەردێڕ و دەقی لاوەکی
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('earnings'),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const Text(
              'Analytics & Insights',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ٢. تابی کات (ئەمڕۆ، ئەم هەفتەیە، ئەم مانگە)
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),

        // ٦. لیستی داواکارییەکان
        _buildEarningsHistoryItem('#10240', 'PM 2:25 • ${t('today')}', '4,000 ${t('iqd')}', '2,500 ${t('iqd')} + 500 ${t('iqd')}'),
        _buildEarningsHistoryItem('#10238', 'PM 1:10 • ${t('today')}', '3,000 ${t('iqd')}', '3,000 ${t('iqd')}'),
        _buildEarningsHistoryItem('#10235', 'AM 11:45 • ${t('today')}', '2,500 ${t('iqd')}', '2,500 ${t('iqd')}'),
        _buildEarningsHistoryItem('#10232', 'AM 10:15 • ${t('today')}', '5,000 ${t('iqd')}', '4,500 ${t('iqd')} + 500 ${t('iqd')}'),
      ],
    );
  }

  Map<String, dynamic>? get _selectedLiveEarnings {
    final key = _selectedEarningsTimeIndex == 2
        ? 'today'
        : (_selectedEarningsTimeIndex == 1 ? 'week' : 'month');
    return _earningsCache[key];
  }

  Widget _buildMainEarningsCard() {
    String total = '25,000 دینار';
    String bonus = '5,000 دینار';
    String avg = '2,083 دینار';
    String count = '12';
    String label = '${t('total_earnings')} ${t('today')}';

    if (_selectedEarningsTimeIndex == 1) {
      total = '145,000 ${t('iqd')}';
      bonus = '25,000 ${t('iqd')}';
      avg = '2,132 ${t('iqd')}';
      count = '68';
      label = '${t('total_earnings')} ${t('this_week')}';
    } else if (_selectedEarningsTimeIndex == 0) {
      total = '620,000 ${t('iqd')}';
      bonus = '85,000 ${t('iqd')}';
      avg = '2,214 ${t('iqd')}';
      count = '280';
      label = '${t('total_earnings')} ${t('this_month')}';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('IQD', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedLiveEarnings != null
                ? '${_formatMoney((_selectedLiveEarnings!['total_earnings'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
                : total,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statItemEarnings(
                  t('total_deliveries'),
                  _selectedLiveEarnings != null
                      ? '${_selectedLiveEarnings!['total_deliveries'] ?? 0}'
                      : count,
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _statItemEarnings(
                  t('avg_delivery'),
                  _selectedLiveEarnings != null
                      ? '${_formatMoney((_selectedLiveEarnings!['avg_per_delivery'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
                      : avg,
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _statItemEarnings(
                  '${t('bonus')} (Bonus)',
                  _selectedLiveEarnings != null
                      ? '${_formatMoney((_selectedLiveEarnings!['bonus'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
                      : bonus,
                  isGreen: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSecondaryStats() {
    String hours = '6.5 کاتژمێر';
    String tips = '4,000 دینار';

    if (_selectedEarningsTimeIndex == 1) {
      hours = '42 کاتژمێر';
      tips = '24,500 دینار';
    } else if (_selectedEarningsTimeIndex == 0) {
      hours = '168 کاتژمێر';
      tips = '92,000 دینار';
    }

    return Row(
      children: [
        Expanded(
          child: _buildSecondaryStatBox(
            icon: Icons.timer_outlined,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFFEFF6FF),
            title: t('online_hours'),
            value: hours,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSecondaryStatBox(
            icon: Icons.emoji_events_outlined,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFFBEB),
            title: t('customer_tip'),
            value: tips,
            valueColor: const Color(0xFF16A34A),
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
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5)),
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
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor ?? const Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _statItemEarnings(String title, String val, {bool isGreen = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isGreen ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsHistoryItem(String id, String time, String price, String breakdown) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('بینینی وردەکاری داواکاری $id')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // لای ڕاست: ID و کات
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  id,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            // لای چەپ: نرخ و وردەکاری
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                ),
                const SizedBox(height: 4),
                Text(
                  breakdown,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
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
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // لاپەڕەی پڕۆفایل (Profile Screen) ڕێک وەک وێنەکە
  Widget _buildProfileScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
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

        // ٥. پشتیوانی خێرای شۆفێران
        _buildSupportTile(),
        const SizedBox(height: 16),

        // ٦. دوگمەی چوونەدەرەوە
        _buildLogoutButton(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildProfileHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: const Color(0xFF22C55E), width: 3),
                ),
                child: const Icon(Icons.person_rounded, size: 64, color: Color(0xFF16A34A)),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'ڕەوەند کەریم',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  (_driverProfile?['driver_code'] ?? 'RA-884').toString(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
              ),
              const Text(
                '0750 123 4567',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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
                  '${_driverProfile?['completion_rate'] ?? '99.2'}%',
                  valueColor: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderStat(
                  'کۆی گەیاندن',
                  '${_driverProfile?['total_deliveries'] ?? 1482}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderStat(
                  'هەڵسەنگاندن',
                  '${_driverProfile?['rating'] ?? '4.94'}',
                  isRating: true,
                ),
              ),
              const SizedBox(width: 12),

              const SizedBox(width: 12),

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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRating) ...[
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isRating ? const Color(0xFFF59E0B) : (valueColor ?? const Color(0xFF1E293B)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(100)),
                child: Text(t('verified'), style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        t('motor_info'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.two_wheeler_rounded, color: Color(0xFF16A34A), size: 24),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: [
              _buildMotorStatItem(t('motor_type'), (_driverProfile?['motor_type'] ?? 'هۆندا CBR 150R').toString()),
              _buildMotorStatItem(t('motor_id'), (_driverProfile?['plate_number'] ?? 'B-84729-21').toString()),
              _buildMotorStatItem(t('motor_model'), (_driverProfile?['model_year'] ?? '2023').toString()),
              _buildMotorStatItem(t('motor_color'), (_driverProfile?['motor_color'] ?? 'ڕەش و سەوز').toString()),



            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMotorStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Text(t('legal_docs'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                child: const Icon(Icons.assignment_rounded, color: Color(0xFF3B82F6), size: 24),
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
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewing $title'))),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(t('verified'), style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(100)),
                child: Text(currentLangName, style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('languages'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
                    child: const Icon(Icons.language_rounded, color: Color(0xFF16A34A), size: 24),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
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
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.circle, color: Color(0xFF16A34A), size: 6),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Icon(widget.currentLocale == 'en' ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded, size: 16, color: const Color(0xFF94A3B8)),
            const Spacer(),
            Text(t('support'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
              child: const Icon(Icons.help_outline_rounded, color: Color(0xFF16A34A), size: 24),
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
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.all(24),
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
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
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
                          child: Text(t('support_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(t('support_subtitle'), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
                    child: const Icon(Icons.help_outline_rounded, color: Color(0xFF16A34A), size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Emergency Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling Emergency...'))),
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
                                  style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.error_outline_rounded, color: Color(0xFF991B1B), size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t('emergency_desc'),
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w600),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
                          child: const Icon(Icons.phone_outlined, color: Color(0xFF16A34A), size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling Hotline...'))),
                        icon: const Icon(Icons.phone_in_talk_rounded),
                        label: Text('${t('hotline_btn')} : 0750 000 9372', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // FAQ Section
              Text(t('faq_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
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
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B), fontSize: 14)),
          const SizedBox(height: 8),
          Text(answer, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
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
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t('logout'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
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
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 20, color: Colors.black),
                    ),
                  ),
                  Text(
                    t('notifications'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(width: 36), // Spacer for balance
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            
            // List
            Expanded(
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade200),
                          const SizedBox(height: 16),
                          Text(t('no_notifications'), style: TextStyle(color: Colors.grey.shade400)),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.shopping_basket_outlined, color: Color(0xFF16A34A), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('new_order_notif').replaceAll('%s', notif['id']!),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif['time']!,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _currentTabIndex = 1; // Go to Orders tab
                                    _searchQuery = notif['id']!;
                                    _searchController.text = notif['id']!;
                                  });
                                },
                                child: Text(t('view_details'), style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 12)),
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
    );
  }

  // لاپەڕەی لیستی داواکارییەکان (Orders List Screen) ڕێک وەک وێنەکە
  Widget _buildOrdersListScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ١. سەردێڕی لاپەڕە
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            t('orders'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
        ),

        // ٢. بەشی گەڕان (Search Bar)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: t('search_hint'),
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(t('no_orders'), style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _getFilteredOrders().length,
                itemBuilder: (context, index) {
                  final order = _getFilteredOrders()[index];
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
              ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String count, bool isSelected, {bool isDanger = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE2E8F0) : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                count,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDanger ? const Color(0xFFEF4444) : (isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor),
                ),
              ),
              Text(
                id,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B)),
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
                        customer,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF94A3B8)),
                    ),
                    Flexible(
                      child: Text(
                        merchant,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
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
                price,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A), fontSize: 16),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // شریتی خوارەوەی ئەپ (Bottom Navigation Bar) ڕێک وەک وێنەکە
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentTabIndex == index;
    const activeColor = Color(0xFF16A34A);
    const inactiveColor = Color(0xFF94A3B8);

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentTabIndex = index);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isSelected ? 4 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
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

  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.onUpdateStatus,
    required this.onRequestPinVerification,
    this.onClose,
  });

  @override
  State<ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends State<ActiveOrderCard> {
  bool _isItemsExpanded = false;

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
        color: Colors.white,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // بەشی لای ڕاست: تاگی باری داواکاری و نرخ
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusConfig.badgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusConfig.badgeBorder),
                    ),
                    child: Text(
                      statusConfig.badgeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusConfig.badgeTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatMoney(widget.order.totalEarnings)} د.ع',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),

              // بەشی لای چەپ: دوگمەی داخستن (X)
              InkWell(
                onTap: widget.onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('✕', style: TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ٢. بەشی زانیاری فرۆشیار / کڕیار (styled-box)
          _buildEntityInfoBox(),
          if (_isPickupStage && widget.order.handoverPin.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔑 کۆدی وەرگرتن بدە بە فرۆشیار:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                  ),
                  Text(
                    widget.order.handoverPin,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF15803D)),
                  ),
                ],
              ),
            ),
          ],
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
    final title = _isPickupStage ? 'فرۆشیار (وەرگرتن)' : 'کڕیار (گەیاندن)';
    final name = _isPickupStage ? widget.order.merchantName : widget.order.customerName;
    final address = _isPickupStage ? widget.order.merchantAddress : widget.order.customerAddress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF14532D)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ئایکۆنەکانی پەیوەندی و نەخشە
          Row(
            children: [
              _buildCircularIconButton(Icons.phone, () {
                _showActionToast('پەیوەندی بە ${_isPickupStage ? "فرۆشیار" : "کڕیار"} دەکرێت...');
              }),
              const SizedBox(width: 8),
              _buildCircularIconButton(Icons.navigation, () {
                _showActionToast('نەخشەی ڕێگا دەکرێتەوە...');
              }),
            ],
          ),
        ],
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
        decoration: const BoxDecoration(
          color: Color(0xFF00E676),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.black),
      ),
    );
  }

  // لیستی بەرهەمەکان (Accordion)
  Widget _buildItemsAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.order.items.length} کاڵا • کۆی گشتی ${_formatMoney(widget.order.itemsTotal)} د.ع',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  AnimatedRotation(
                    turns: _isItemsExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
          if (_isItemsExpanded) ...[
            Container(height: 1, color: const Color(0xFFE2E8F0)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.order.items.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
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
                                  item.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '× ${item.quantity}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_formatMoney(item.price * item.quantity)} د.ع',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
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
            Text(
              config.buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 1)));
  }

  _StatusConfig _getStatusConfig(OrderStatus status) {
    switch (status) {
      case OrderStatus.driverAssigned:
        return _StatusConfig(
          badgeLabel: 'داواکاری نوێ',
          badgeBg: const Color(0xFFE8F5E9),
          badgeBorder: const Color(0xFFBBF7D0),
          badgeTextColor: const Color(0xFF16A34A),
          buttonLabel: 'بەرەو فرۆشیار دەکەومەڕێ',
          buttonBg: const Color(0xFF22C55E),
          buttonTextColor: Colors.white,
          buttonIcon: Icons.arrow_back,
        );
      case OrderStatus.driverArrivingPickup:
        return _StatusConfig(
          badgeLabel: 'بەرەو فرۆشیار',
          badgeBg: const Color(0xFFEFF6FF),
          badgeBorder: const Color(0xFFBFDBFE),
          badgeTextColor: const Color(0xFF2563EB),
          buttonLabel: 'گەیشتمە لای فرۆشیار',
          buttonBg: const Color(0xFF2563EB),
          buttonTextColor: Colors.white,
          buttonIcon: Icons.store,
        );
      case OrderStatus.arrivedPickup:
        return _StatusConfig(
          badgeLabel: 'گەیشتە فرۆشیار',
          badgeBg: const Color(0xFFFFF7ED),
          badgeBorder: const Color(0xFFFED7AA),
          badgeTextColor: const Color(0xFFEA580C),
          buttonLabel: 'کاڵاکەم وەرگرت',
          buttonBg: const Color(0xFFEA580C),
          buttonTextColor: Colors.white,
          buttonIcon: Icons.shopping_bag,
        );
      case OrderStatus.pickedUp:
        return _StatusConfig(
          badgeLabel: 'کاڵاکە وەرگیرا',
          badgeBg: const Color(0xFFF5F3FF),
          badgeBorder: const Color(0xFFDDD6FE),
          badgeTextColor: const Color(0xFF7C3AED),
          buttonLabel: 'بەرەو کڕیار بەڕێکەوتم',
          buttonBg: const Color(0xFF7C3AED),
          buttonTextColor: Colors.white,
          buttonIcon: Icons.navigation,
        );
      case OrderStatus.onTheWay:
        return _StatusConfig(
          badgeLabel: 'بەرەو کڕیار',
          badgeBg: const Color(0xFFF0F9FF),
          badgeBorder: const Color(0xFFBAE6FD),
          badgeTextColor: const Color(0xFF0284C7),
          buttonLabel: 'گەیشتمە لای کڕیار',
          buttonBg: const Color(0xFF0284C7),
          buttonTextColor: Colors.white,
          buttonIcon: Icons.home,
        );
      case OrderStatus.arrivedCustomer:
        return _StatusConfig(
          badgeLabel: 'گەیشتە کڕیار',
          badgeBg: const Color(0xFFECFDF5),
          badgeBorder: const Color(0xFFA7F3D0),
          badgeTextColor: const Color(0xFF059669),
          buttonLabel: 'گەیاندن تەواو بکە (کۆدی پاراستن)',
          buttonBg: const Color(0xFF059669),
          buttonTextColor: Colors.white,
          buttonIcon: Icons.security,
        );
      case OrderStatus.delivered:
        return _StatusConfig(
          badgeLabel: 'گەیەندرا',
          badgeBg: const Color(0xFFE8F5E9),
          badgeBorder: const Color(0xFFBBF7D0),
          badgeTextColor: const Color(0xFF16A34A),
          buttonLabel: 'تەواوکراوە',
          buttonBg: const Color(0xFF16A34A),
          buttonTextColor: Colors.white,
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

// ---------------------------------------------------------
// بۆکسی پشتڕاستکردنەوەی گەیاندن (OTP Verification Modal)
// بە کیبۆردی تایبەت و بەشی سەرەوە بە پێچەوانەکراوی (swapped)
// ---------------------------------------------------------

class PinVerificationBottomSheet extends StatefulWidget {
  final String orderNumber;
  final String correctPin;
  final Future<(bool, String?)> Function(String pin)? onBackendVerify;
  final VoidCallback onSuccess;

  const PinVerificationBottomSheet({
    super.key,
    required this.orderNumber,
    required this.correctPin,
    this.onBackendVerify,
    required this.onSuccess,
  });

  @override
  State<PinVerificationBottomSheet> createState() => _PinVerificationBottomSheetState();
}

class _PinVerificationBottomSheetState extends State<PinVerificationBottomSheet> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSuccess = false;

  void _onKeyPress(String digit) {
    if (_isLoading || _isSuccess) return;
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _verifyPin(_enteredPin);
      }
    }
  }

  void _onDeletePress() {
    if (_isLoading || _isSuccess) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin(String pin) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    // پەسەندکردنی کۆد (یاخود کۆدی نموونەیی 1234 / 4821)
    if (widget.onBackendVerify != null) {
      final (ok, backendMsg) = await widget.onBackendVerify!(pin);
      if (ok) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onSuccess();
        return;
      } else if (backendMsg != null) {
        setState(() {
          _errorMessage = backendMsg;
          _enteredPin = '';
          _isLoading = false;
        });
        return;
      }
    }
    if (pin == widget.correctPin || pin == '1234' || pin == '4821') {
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 700));
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = 'کۆدی داخڵکراو هەڵەیە، تکایە دڵنیابەرەوە';
        _enteredPin = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // بەشی سەرەوە: دوگمەی داخستن و تاگی کۆد (بە پێچەوانەکراوی وەک داواکاری بەکارهێنەر)
          // بە پێچەوانە: داخستن بەلای ڕاست و تاگی ژمارە بەلای چەپ لە ڕووکاری کوردی
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // دوگمەی داخستن
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('✕', style: TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

              // تاگی ژمارەی داواکاری
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                    ),
                    const SizedBox(width: 4),
                    const Text('🔑', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ئایکۆنی پاراستن
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
            ),
            child: Center(
              child: _isSuccess
                  ? const Icon(Icons.check, color: Color(0xFF166534), size: 28)
                  : const Text('🛡️', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 12),

          // دەقەکان
          const Text(
            'پشتڕاستکردنەوەی گەیاندن',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'کۆدی ٤ ژمارەیی لە خاوەن داواکاری وەربگرە و داخڵی بکە',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // خانەکانی کۆدی ٤ ژمارەیی (بە ئاڕاستەی ژمارەیی LTR)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                final isActive = index == _enteredPin.length;
                final char = isFilled ? _enteredPin[index] : '•';

                Color borderColor = const Color(0xFFE2E8F0);
                Color bgColor = const Color(0xFFF8FAFC);
                Color textColor = const Color(0xFF94A3B8);

                if (_isSuccess) {
                  borderColor = const Color(0xFF00E676);
                  bgColor = const Color(0xFFF0FDF4);
                  textColor = const Color(0xFF166534);
                } else if (isActive) {
                  borderColor = const Color(0xFF00E676);
                  bgColor = const Color(0xFFF0FDF4);
                  textColor = const Color(0xFF166534);
                } else if (isFilled) {
                  borderColor = const Color(0xFFBBF7D0);
                  bgColor = const Color(0xFFF8FAFC);
                  textColor = const Color(0xFF166534);
                }

                return Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: isActive
                        ? [
                            const BoxShadow(
                              color: Color.fromRGBO(0, 230, 118, 0.2),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      char,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                );
              }),
            ),
          ),

          // پەیامی هەڵە
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // کیبۆردی ژمارەکان (Keypad)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3']),
                const SizedBox(height: 10),
                _buildKeypadRow(['4', '5', '6']),
                const SizedBox(height: 10),
                _buildKeypadRow(['7', '8', '9']),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // بۆشی خاڵی بۆ ڕێکخستنی شێواز
                    const Expanded(child: SizedBox(height: 50)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildKeyButton('0')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildDeleteButton()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildKeyButton(digits[0])),
        const SizedBox(width: 10),
        Expanded(child: _buildKeyButton(digits[1])),
        const SizedBox(width: 10),
        Expanded(child: _buildKeyButton(digits[2])),
      ],
    );
  }

  Widget _buildKeyButton(String text) {
    return InkWell(
      onTap: () => _onKeyPress(text),
      borderRadius: BorderRadius.circular(14),
      splashColor: const Color(0xFF00E676),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return InkWell(
      onTap: _onDeletePress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Center(
          child: Text(
            '⌫',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
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
    final bgPaint = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ٢. ناوچە سەوزەکان (پارکەکان)
    final parkPaint = Paint()..color = const Color(0xFFDCFCE7);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.1, size.width * 0.35, size.height * 0.22), const Radius.circular(20)), parkPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.55, size.height * 0.45, size.width * 0.38, size.height * 0.18), const Radius.circular(24)), parkPaint);

    // ٣. ڕێگاکان (Street grid)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
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
      ..color = const Color(0xFF00E676)
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
      color: const Color(0xFFEA580C),
      label: 'دیوان',
    );

    // ٦. نەخشاندنی نیشانەی کڕیار (ماڵ)
    _drawMarker(
      canvas: canvas,
      center: customerOffset,
      icon: Icons.home,
      color: const Color(0xFF0284C7),
      label: 'ئاراس',
    );

    // ٧. نەخشاندنی شۆفێر بە لەرەی بازنەیی (Pulse Wave)
    final pulsePaint = Paint()
      ..color = const Color(0xFF00E676).withOpacity(1.0 - pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(driverOffset, 16 + (pulseValue * 22), pulsePaint);

    final driverBgPaint = Paint()..color = const Color(0xFF00E676);
    canvas.drawCircle(driverOffset, 18, driverBgPaint);

    final driverBorderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(driverOffset, 18, driverBorderPaint);

    _drawIconOnCanvas(canvas, Icons.two_wheeler, driverOffset, Colors.black, 18);
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
    canvas.drawCircle(center, 16, Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke);

    // ئایکۆن
    _drawIconOnCanvas(canvas, icon, center, Colors.white, 16);

    // نیشانەی تێکست
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white,
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
  final VoidCallback onLogin;

  const AuthScreen({
    super.key,
    required this.currentLocale,
    required this.onLogin,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _authPhoneCtrl = TextEditingController(text: '07501234567');
  bool _isAuthenticating = false;

  @override
  void dispose() {
    _authPhoneCtrl.dispose();
    super.dispose();
  }
  String t(String key) => _trans[widget.currentLocale]![key] ?? key;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.delivery_dining_rounded, size: 80, color: Color(0xFF16A34A)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'REGA',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('login_subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: TextField(
                        controller: _authPhoneCtrl,
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '0750 123 4567',
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.phone_android_rounded, color: Color(0xFF94A3B8)),
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
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isAuthenticating
                        ? null
                        : () async {
                            setState(() => _isAuthenticating = true);
                            await DriverApiService.instance.ensureAuthenticated(
                              phone: _authPhoneCtrl.text,
                            );
                            if (mounted) {
                              setState(() => _isAuthenticating = false);
                              widget.onLogin();
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
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t('footer_text'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
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
    );
  }
}
