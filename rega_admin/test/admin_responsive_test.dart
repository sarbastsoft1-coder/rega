import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rega_admin/core/api/api_client.dart';
import 'package:rega_admin/core/theme/app_theme.dart';
import 'package:rega_admin/rega_colors.dart';
import 'package:rega_admin/rega_i18n.dart';
import 'package:rega_admin/screens/accounting_screen.dart';
import 'package:rega_admin/screens/admin_shell.dart';
import 'package:rega_admin/screens/catalog_zones_screen.dart';
import 'package:rega_admin/screens/customer_part_screen.dart';
import 'package:rega_admin/screens/customers_screen.dart';
import 'package:rega_admin/screens/delivery_part_screen.dart';
import 'package:rega_admin/screens/direct_requests_screen.dart';
import 'package:rega_admin/screens/drivers_screen.dart';
import 'package:rega_admin/screens/finance_screen.dart';
import 'package:rega_admin/screens/live_radar_dialog.dart';
import 'package:rega_admin/screens/login_screen.dart';
import 'package:rega_admin/screens/marketing_screen.dart';
import 'package:rega_admin/screens/products_screen.dart';
import 'package:rega_admin/screens/store_menu_categories_screen.dart';
import 'package:rega_admin/screens/stores_screen.dart';
import 'package:rega_admin/screens/support_settings_screen.dart';
import 'package:rega_admin/screens/vendor_part_screen.dart';
import 'package:rega_admin/state/admin_app_notifier.dart';
import 'package:rega_admin/state/admin_domain_notifiers.dart';
import 'package:rega_admin/widgets/blocked_account_dialog.dart';
import 'package:rega_admin/widgets/send_customer_notification_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Minimal valid 1x1 transparent PNG so flutter_map NetworkTileProvider succeeds offline.
final Uint8List _transparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _MockPngHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockPngHttpClient();
}

class _MockPngHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _MockHttpRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpRequest implements HttpClientRequest {
  _MockHttpRequest(this.uri);

  @override
  final Uri uri;

  @override
  Encoding encoding = utf8;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpResponse();

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void removeAll(String name) {}

  @override
  List<String>? operator [](String name) => null;

  @override
  String? value(String name) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeApiClient extends ApiClient {
  @override
  Future<void> init() async {}

  @override
  Future<void> setToken(String? token) async {}

  @override
  Future<Map<String, dynamic>> checkHealth() async => {'db_connected': true};

  @override
  Future<Map<String, dynamic>> me() async => {
        'id': 1,
        'name': 'ئەدمینی سەرەکی گەرمیان',
        'email': 'admin@rega.krd',
        'phone': '07501234567',
        'role': 'admin',
      };

  static final List<Map<String, dynamic>> _sampleStores = [
    {
      'id': 1,
      'name_ku': 'چێشتخانەی گەرمیان و کەبابی تایبەت',
      'name_ar': 'مطعم گرميان',
      'name_en': 'Garmian Special Kebab Restaurant',
      'phone': '07701234567',
      'city': 'کەلار',
      'address_ku': 'شەقامی بازاڕی ناوەندی کەلار — گەڕەکی شەهیدان',
      'is_online': true,
      'is_approved': true,
      'is_active': true,
      'commission_rate': 12,
      'products_count': 24,
      'delivered_orders_count': 340,
      'orders_count': 360,
      'gross_sales': 8500000,
      'net_profit': 4200000,
      'total_commission': 540000,
      'rating': 4.8,
      'lat': 34.622,
      'lng': 45.322,
      'image_url': null,
      'logo_url': null,
      'category': {'id': 1, 'name_ku': 'خواردنە خێراکان و ڕێستۆرانت'},
      'owner': {'id': 10, 'name': 'ڕێبوار ئەحمەد عەلی', 'phone': '07701112233'},
    },
    {
      'id': 2,
      'name_ku': 'سوپەرمارکێتی ڕێگا و میوەفرۆشی ناوەند',
      'name_ar': 'سوبرماركت ريگا',
      'name_en': 'Rega Central Supermarket',
      'phone': '07509876543',
      'city': 'سلێمانی',
      'address_ku': 'جوتسایدی شەهیدانی گەرمیان',
      'is_online': false,
      'is_approved': true,
      'is_active': true,
      'commission_rate': 10,
      'products_count': 56,
      'delivered_orders_count': 195,
      'orders_count': 210,
      'gross_sales': 3900000,
      'net_profit': 2100000,
      'total_commission': 210000,
      'rating': 4.6,
      'lat': 34.626,
      'lng': 45.326,
      'image_url': null,
      'logo_url': null,
      'category': {'id': 1, 'name_ku': 'خواردنە خێراکان و ڕێستۆرانت'},
      'owner': {'id': 11, 'name': 'دانا محەمەد', 'phone': '07502223344'},
    },
  ];

  static final List<Map<String, dynamic>> _sampleDrivers = [
    {
      'id': 1,
      'user_id': 2,
      'driver_code': 'DRV-01',
      'vehicle_type': 'motorcycle',
      'vehicle_plate': '21-K-4490',
      'city': 'کەلار',
      'is_online': true,
      'is_available': true,
      'is_verified': true,
      'is_active': true,
      'rating': 4.9,
      'completed_deliveries': 142,
      'total_deliveries': 142,
      'avg_delivery_minutes': 21,
      'wallet_balance': 350000,
      'cod_debt': 85000,
      'lat': 34.623,
      'lng': 45.323,
      'languages': ['ku', 'ar'],
      'user': {'id': 2, 'name': 'هێمن ڕەشید کەریم', 'phone': '07501112233', 'is_active': true},
    },
    {
      'id': 2,
      'user_id': 3,
      'driver_code': 'DRV-02',
      'vehicle_type': 'car',
      'vehicle_plate': '21-B-8812',
      'city': 'کەلار',
      'is_online': false,
      'is_available': false,
      'is_verified': false,
      'is_active': true,
      'rating': 4.5,
      'completed_deliveries': 64,
      'total_deliveries': 64,
      'avg_delivery_minutes': 27,
      'wallet_balance': 125000,
      'cod_debt': 40000,
      'lat': 34.619,
      'lng': 45.319,
      'languages': ['ku'],
      'user': {'id': 3, 'name': 'شوان عوسمان قادر', 'phone': '07703334455', 'is_active': true},
    },
  ];

  static final List<Map<String, dynamic>> _sampleOrders = [
    {
      'id': 101,
      'order_number': 'ORD-2026-9901',
      'status': 'preparing',
      'payment_method': 'cash',
      'payment_status': 'unpaid',
      'subtotal': 46000,
      'delivery_fee': 2500,
      'discount_amount': 0,
      'total_amount': 48500,
      'customer_name': 'کاروان عەبدوڵڵا محەمەد گەرمیانی',
      'customer_phone': '07701234567',
      'delivery_address': 'گەڕەکی شەهیدان، کۆڵانی ١٤، بەرامبەر قوتابخانە',
      'neighborhood': 'گەڕەکی شەهیدان',
      'city': 'کەلار',
      'created_at': '2026-11-22T10:30:00Z',
      'store_id': 1,
      'store': _sampleStores.first,
      'driver': {'id': 2, 'name': 'هێمن ڕەشید کەریم', 'phone': '07501112233'},
      'items': [
        {
          'id': 1,
          'quantity': 2,
          'product_name': 'پیتزای مەرگەریتا تایبەت قەبارە گەورە',
          'price': 18000,
          'total_price': 36000,
        },
        {
          'id': 2,
          'quantity': 1,
          'product_name': 'کەبابی سەر ساج',
          'price': 10000,
          'total_price': 10000,
        },
      ],
    },
    {
      'id': 102,
      'order_number': 'ORD-2026-9902',
      'status': 'pending',
      'payment_method': 'cash',
      'payment_status': 'unpaid',
      'subtotal': 22000,
      'delivery_fee': 2500,
      'discount_amount': 2000,
      'total_amount': 22500,
      'customer_name': 'سارا نەجمەدین ساڵح',
      'customer_phone': '07504445566',
      'delivery_address': 'گەڕەکی بنگرد، نزیک نەخۆشخانەی گشتی',
      'neighborhood': 'بنگرد',
      'city': 'سلێمانی',
      'created_at': '2026-11-22T11:05:00Z',
      'store_id': 2,
      'store': _sampleStores[1],
      'driver': null,
      'items': [
        {'id': 3, 'quantity': 2, 'product_name': 'شاورمای تایبەتی گەورە', 'price': 11000, 'total_price': 22000},
      ],
    },
  ];

  static final List<Map<String, dynamic>> _sampleCustomers = [
    {
      'id': 1,
      'name': 'شەیما عەبدوڵڵا عوسمان گەرمیانی',
      'phone': '07709998877',
      'city': 'کەلار',
      'total_orders': 28,
      'total_spent': 1450000,
      'is_active': true,
      'is_vip': true,
      'created_at': '2026-01-15T09:00:00Z',
    },
    {
      'id': 2,
      'name': 'بەرزان مستەفا حەسەن',
      'phone': '07505554433',
      'city': 'هەولێر',
      'total_orders': 14,
      'total_spent': 620000,
      'is_active': false,
      'is_vip': false,
      'created_at': '2026-03-10T14:20:00Z',
    },
  ];

  @override
  Future<Map<String, dynamic>> getDashboard({int days = 7}) async => {
        'kpis': {
          'total_orders': 1480,
          'delivered_orders': 1210,
          'active_orders_count': 145,
          'cancelled_orders': 125,
          'total_gmv': 12500000,
          'completion_rate': 82,
          'avg_delivery_minutes': 24,
          'online_stores': 18,
          'total_stores': 24,
          'total_customers': 640,
          'active_customers': 510,
          'new_customers_this_month': 85,
          'today_orders': 92,
          'online_drivers': 14,
          'total_drivers': 22,
          'verified_drivers': 19,
          'open_tickets_count': 6,
          'platform_commission': 1850000,
        },
        'recent_orders': _sampleOrders,
        'radar_drivers': [
          {
            'id': 1,
            'name': 'هێمن ڕەشید کەریم',
            'driver_code': 'DRV-01',
            'lat': 34.623,
            'lng': 45.323,
            'is_online': true,
            'is_available': true,
          },
        ],
        'top_drivers': [
          {'name': 'هێمن ڕەشید کەریم', 'completed_deliveries': 142, 'avg_delivery_minutes': 21, 'rating': 4.9},
          {'name': 'شوان عوسمان قادر', 'completed_deliveries': 98, 'avg_delivery_minutes': 25, 'rating': 4.6},
        ],
        'top_stores': _sampleStores,
        'revenue_chart': [
          {'date': '2026-11-16', 'label': 'شەممە', 'revenue': 950000, 'orders': 42},
          {'date': '2026-11-17', 'label': 'یەکشەممە', 'revenue': 1200000, 'orders': 55},
          {'date': '2026-11-18', 'label': 'دووشەممە', 'revenue': 1850000, 'orders': 74},
          {'date': '2026-11-19', 'label': 'سێشەممە', 'revenue': 1420000, 'orders': 61},
        ],
        'orders_revenue_monthly': [
          for (var m = 1; m <= 12; m++)
            {'month': m, 'orders_count': 80 + m * 12, 'gmv': 1500000 + m * 650000},
        ],
        'new_customers_monthly': [
          {'month': 6, 'label': 'حوزەیران', 'count': 42},
          {'month': 7, 'label': 'تەمموز', 'count': 68},
          {'month': 8, 'label': 'ئاب', 'count': 54},
          {'month': 9, 'label': 'ئەیلول', 'count': 79},
          {'month': 10, 'label': 'تشرینی ١', 'count': 91},
          {'month': 11, 'label': 'تشرینی ٢', 'count': 115},
        ],
      };

  @override
  Future<Map<String, dynamic>> getLiveRadar() async => {
        'drivers': _sampleDrivers,
        'live_sessions': [
          {
            'id': 1,
            'driver_name': 'هێمن ڕەشید کەریم',
            'order_number': 'ORD-2026-9901',
            'lat': 34.624,
            'lng': 45.324,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getAdminInbox() async => {
        'unread_count': 2,
        'items': [
          {
            'key': 'order-101',
            'type': 'order',
            'title': 'داواکاری نوێ #ORD-2026-9901',
            'subtitle': 'چێشتخانەی گەرمیان',
            'is_read': false,
            'created_at': '2026-11-22T10:30:00Z',
          },
        ],
      };

  @override
  Future<int> getAdminInboxUnreadCount() async => 2;

  @override
  Future<Map<String, dynamic>> markAdminInboxRead(String itemKey) async =>
      {'unread_count': 1, 'items': []};

  @override
  Future<Map<String, dynamic>> markAdminInboxAllRead() async =>
      {'unread_count': 0, 'items': []};

  @override
  Future<Map<String, dynamic>> getOrders({
    String status = 'all',
    String? search,
    int? storeId,
    int page = 1,
    int perPage = 100,
  }) async =>
      {
        'data': _sampleOrders,
        'meta': {'total': _sampleOrders.length, 'current_page': 1, 'last_page': 1},
      };

  @override
  Future<Map<String, dynamic>> getOrderDetails(int orderId) async =>
      _sampleOrders.first;

  @override
  Future<Map<String, dynamic>> assignDriver(int orderId, int driverUserId) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String status, {
    String? reason,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> addWaitingBonus(
    int orderId,
    int bonus, {
    String? note,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> updateOrder(
    int orderId,
    Map<String, dynamic> payload,
  ) async =>
      {'success': true};

  @override
  Future<void> deleteOrder(int orderId) async {}

  @override
  Future<List<dynamic>> getStores({
    String? search,
    int? categoryId,
    bool? isOnline,
    bool? isApproved,
  }) async =>
      _sampleStores;

  @override
  Future<Map<String, dynamic>> getStoreDetails(int storeId) async =>
      {'data': _sampleStores.first};

  @override
  Future<List<dynamic>> getStoreCategories({
    int? storeId,
    int? categoryId,
    String? search,
  }) async =>
      [
        {
          'id': 1,
          'store_id': 1,
          'name_ku': 'برژاو و کەبابی تایبەتی بازاڕ',
          'name_ar': 'مشويات',
          'name_en': 'Grills & Kebab',
          'sort_order': 1,
          'products_count': 12,
          'image_url': null,
          'secondary_image_url': null,
          'store': {
            'id': 1,
            'name_ku': 'چێشتخانەی گەرمیان',
            'category': {'id': 1, 'name_ku': 'خواردنە خێراکان'},
          },
        },
      ];

  @override
  Future<List<dynamic>> getProducts({
    int? storeId,
    String? search,
    bool? isAvailable,
    bool? hasDiscount,
  }) async =>
      [
        {
          'id': 1,
          'store_id': 1,
          'name_ku': 'شاورمای تایبەتی قەبارە گەورە بە سۆسی تایبەت',
          'name_ar': 'شاورما خاصة',
          'name_en': 'Special Large Shawarma',
          'price': 6500,
          'cost_price': 4000,
          'discount_price': 5500,
          'is_available': true,
          'category': 'سەندەویچ',
          'image_url': null,
          'store': {'id': 1, 'name_ku': 'چێشتخانەی گەرمیان'},
        },
      ];

  @override
  Future<List<dynamic>> getDrivers({
    String? search,
    bool? isOnline,
    bool? isVerified,
    int? storeId,
    int? orderId,
  }) async =>
      _sampleDrivers;

  @override
  Future<Map<String, dynamic>> getDriverDetails(int driverProfileId) async =>
      _sampleDrivers.first;

  @override
  Future<List<dynamic>> getDriverDocuments(int driverProfileId) async => [
        {'id': 1, 'document_type': 'national_id', 'document_number': '1992004411', 'status': 'approved'},
      ];

  @override
  Future<List<dynamic>> getCustomers({String? search, bool? isActive}) async =>
      _sampleCustomers;

  @override
  Future<Map<String, dynamic>> getCustomerDetails(int customerId) async =>
      {..._sampleCustomers.first, 'recent_orders': _sampleOrders};

  @override
  Future<List<dynamic>> getCategories() async => [
        {
          'id': 1,
          'name_ku': 'خواردنە خێراکان و ڕێستۆرانت',
          'name_ar': 'المطاعم',
          'name_en': 'Fast Food & Restaurants',
          'sort_order': 1,
          'is_active': true,
          'image_url': null,
        },
      ];

  @override
  Future<List<dynamic>> getNeighborhoods() async => [
        {
          'id': 1,
          'name_ku': 'گەڕەکی شەهیدان — ناوەندی کەلار',
          'name_ar': 'حي الشهداء',
          'name_en': 'Shahidan Quarter',
          'delivery_fee': 2500,
          'is_active': true,
        },
      ];

  @override
  Future<List<dynamic>> getCoupons() async => [
        {
          'id': 1,
          'code': 'REGA50',
          'title_ku': 'داشکاندنی تایبەتی بەهارە',
          'discount_type': 'percent',
          'discount_value': 25,
          'min_order_amount': 15000,
          'used_count': 42,
          'max_uses': 200,
          'is_active': true,
        },
      ];

  @override
  Future<List<dynamic>> getBanners() async => [
        {
          'id': 1,
          'title_ku': 'ئۆفەری تایبەتی داشکاندن لە هەموو فرۆشگاکان',
          'subtitle_ku': 'گەیاندنی خۆڕایی بۆ داواکارییەکان',
          'image_url': null,
          'is_active': true,
          'sort_order': 1,
        },
      ];

  @override
  Future<List<dynamic>> getNotifications() async => [
        {
          'id': 1,
          'title': 'ئاگاداری گرنگ بۆ هەموو کڕیارانی ڕێگا',
          'body': 'داشکاندنی نوێ ئێستا بەردەستە لەسەر داواکارییەکانت لە کەلار',
          'audience': 'customers',
          'type': 'discount',
          'created_at': '2026-11-22T09:00:00Z',
        },
      ];

  @override
  Future<Map<String, dynamic>> getFinanceSummary() async =>
      {'total_revenue': 12500000, 'net_profit': 3600000};

  @override
  Future<Map<String, dynamic>> getAccountingDashboard({
    String? period,
    String? from,
    String? to,
  }) async =>
      {
        'stats': {
          'total_orders': 420,
          'completed_orders': 380,
          'cancelled_orders': 15,
          'total_sales_revenue': 12500000,
          'total_product_costs': 8900000,
          'total_gross_profit': 3600000,
          'total_admin_profit': 720000,
          'total_seller_profit': 2880000,
        },
        'commission_percentage': 20,
        'series': [
          {'day': '2026-11-20', 'revenue': 1200000},
          {'day': '2026-11-21', 'revenue': 1850000},
          {'day': '2026-11-22', 'revenue': 2400000},
        ],
        'profit_by_shop': [
          {
            'id': 1,
            'name_ku': 'چێشتخانەی گەرمیان و کەبابی تایبەت',
            'name_en': 'Garmian Special Kebab Restaurant',
            'sales': 4500000,
            'admin_earnings': 320000,
          },
        ],
        'top_products': [
          {'product_name': 'کەبابی تایبەت بە نانی تیری', 'qty_sold': 120, 'gross_profit': 480000},
        ],
      };

  @override
  Future<Map<String, dynamic>> getAccountingShops({
    String? q,
    String? period,
    String? from,
    String? to,
  }) async =>
      {
        'data': [
          {
            'id': 1,
            'name_ku': 'چێشتخانەی گەرمیان و کەبابی تایبەت',
            'name_en': 'Garmian Special Kebab Restaurant',
            'commission_rate': 15,
            'total_orders': 180,
            'completed_orders': 165,
            'total_sales': 6400000,
            'gross_profit': 1900000,
            'admin_earnings': 285000,
            'seller_earnings': 1615000,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getAccountingShop(
    int storeId, {
    String? period,
    String? from,
    String? to,
  }) async =>
      {
        'shop': _sampleStores.first,
        'summary': {
          'admin_commission_percentage': 15,
          'today_admin_owed': 95000,
          'today_gross_profit': 630000,
          'today_sales': 1850000,
          'total_sales': 6400000,
          'total_product_costs': 4500000,
          'gross_profit': 1900000,
          'admin_earnings': 285000,
          'seller_earnings': 1615000,
          'refunds': 25000,
        },
        'daily_breakdown': [
          {'day': '2026-11-22', 'sales': 1850000, 'gross_profit': 630000, 'orders_count': 42, 'admin_owed': 95000},
        ],
        'product_breakdown': [
          {'product_name': 'کەبابی تایبەت', 'admin_share': 120000, 'gross_profit': 480000},
        ],
        'orders': _sampleOrders,
      };

  @override
  Future<Map<String, dynamic>> getAccountingOrders({
    String? storeId,
    String? status,
    String? orderId,
    String? from,
    String? to,
    int? minProfit,
    int? maxProfit,
  }) async =>
      {
        'data': [
          {
            'id': 101,
            'order_number': 'ORD-2026-9901',
            'shop_name': 'چێشتخانەی گەرمیان',
            'order_status': 'delivered',
            'total_sales': 65000,
            'gross_profit': 20000,
            'admin_commission': 20,
            'admin_earnings': 4000,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getAccountingOrder(int orderId) async => {
        'order': {
          'id': orderId,
          'order_number': 'ORD-2026-9901',
          'shop_name': 'چێشتخانەی گەرمیان',
          'order_status': 'delivered',
          'total_sales': 65000,
          'product_costs': 45000,
          'gross_profit': 20000,
          'admin_earnings': 4000,
          'seller_earnings': 16000,
        },
        'items': [
          {
            'product_name': 'کەبابی تایبەت',
            'quantity': 2,
            'cost_price': 15000,
            'selling_price': 22500,
            'commission_percentage': 20,
            'admin_share': 3000,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getProfitSettings() async => {
        'default_commission_percentage': 20,
        'stores': [
          {'id': 1, 'name_ku': 'چێشتخانەی گەرمیان', 'name_en': 'Garmian Restaurant', 'commission_rate': 15},
        ],
        'history': [
          {
            'commission_percentage': 20,
            'note': 'ڕێژەی گشتی',
            'created_at': '2026-11-01',
            'changer': {'name': 'ئەدمین سەرەکی'},
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> updateProfitSettings(
    double percentage, {
    int? storeId,
    String? note,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> getAccountingReports({
    String period = 'month',
    String? from,
    String? to,
  }) async =>
      {
        'period': period,
        'total_revenue': 12500000,
        'total_costs': 8900000,
        'gross_profit': 3600000,
        'admin_earnings': 720000,
        'seller_earnings': 2880000,
        'total_orders': 420,
        'from': '2026-11-01',
        'to': '2026-11-22',
      };

  @override
  Future<Map<String, dynamic>> getAccountingTransactions({
    String? from,
    String? to,
  }) async =>
      {
        'data': [
          {
            'order_id': 101,
            'refunded_sales': 25000,
            'refunded_admin_share': 5000,
            'reason': 'داواکاری کڕیار',
            'created_at': '2026-11-20',
            'order': {'order_number': 'ORD-2026-8801'},
          },
        ],
      };

  @override
  Future<void> refundAccountingOrder(
    int orderId, {
    int? orderItemId,
    int? quantity,
    bool full = false,
    String? reason,
  }) async {}

  @override
  Future<List<dynamic>> getPayouts({String? recipientType, String? status}) async => [
        {
          'id': 1,
          'reference_number': 'PAY-2026-001',
          'amount': 250000,
          'status': 'completed',
          'notes': 'پاکتاوی هەفتانە بۆ فرۆشیار',
          'recipient_type': recipientType ?? 'vendor',
          'store': {'name_ku': 'چێشتخانەی گەرمیان'},
          'user': {'name': 'ڕێبوار ئەحمەد'},
        },
      ];

  @override
  Future<List<dynamic>> getTickets({String status = 'all', String? category}) async => [
        {
          'id': 1,
          'subject': 'داواکاری گەیاندنی خێرا لە سوپەرمارکێتی ناوەند',
          'description': 'تکایە دوو کیلۆ سێو و پێداویستی ماڵەوە بنێرن بۆ ناوەندی کەلار',
          'status': status == 'all' ? 'open' : status,
          'category': category ?? 'direct_request',
          'customer_name': 'بەرزان مستەفا',
          'customer_phone': '07705554433',
          'created_at': '2026-11-22T08:00:00Z',
          'image_url': null,
        },
      ];

  @override
  Future<Map<String, dynamic>> getSettings() async => {
        'default_delivery_fee': 2500,
        'default_commission_rate': 10,
        'working_hours': '23:00 - 9:00',
        'support_phone': '07500000000',
        'whatsapp_number': '+9647700001122',
        'telegram_number': '+9647700001122',
        'telegram_username': 'rega_support',
        'platform_name': 'REGA',
      };

  @override
  Future<List<dynamic>> getAdminStaff({String? search, String role = 'admin'}) async => [
        {
          'id': 1,
          'name': 'سەرپەرشتیاری سەرەکی گەرمیان',
          'phone': '07501234567',
          'email': 'admin@rega.krd',
          'role': 'admin',
          'is_active': true,
        },
      ];

  @override
  Future<Map<String, dynamic>> getEcosystemHubs() async => {
        'vendor_part': {
          'kpis': {
            'online_stores': 18,
            'total_stores': 24,
            'pending_approval_stores': 2,
            'total_products': 312,
            'unavailable_products': 8,
            'active_kitchen_orders': 6,
            'gross_vendor_sales': 12500000,
            'platform_commission': 1500000,
            'vendor_net_profit': 11000000,
            'vendor_payouts_paid': 4200000,
          },
          'stores': _sampleStores,
          'kitchen_orders': _sampleOrders,
        },
        'delivery_part': {
          'kpis': {
            'online_drivers': 14,
            'total_drivers': 22,
            'unassigned_ready_orders': 3,
            'on_the_way_orders': 5,
            'delivered_today': 84,
            'driver_cod_owed': 450000,
            'total_delivery_fees': 1950000,
          },
          'drivers': _sampleDrivers,
          'dispatch_queue': _sampleOrders,
        },
        'customer_part': {
          'kpis': {
            'total_customers': 640,
            'vip_customers_count': 42,
            'direct_orders_today': 28,
            'repeat_customers_rate': 74,
          },
          'vip_customers': _sampleCustomers,
          'recent_orders': _sampleOrders,
        },
      };

  @override
  Future<List<Map<String, dynamic>>> listExcelBackups({int limit = 40}) async => [
        {
          'file': 'REGA_Backup_2026-11-22_09-00.xlsx',
          'type': 'xlsx',
          'size': 245760,
          'modified_at': '2026-11-22T09:00:00Z',
        },
      ];
}

class _ViewportSpec {
  final String name;
  final Size size;
  const _ViewportSpec(this.name, this.size);
}

const List<_ViewportSpec> _allViewports = [
  _ViewportSpec('360x740', Size(360, 740)),
  _ViewportSpec('390x844', Size(390, 844)),
  _ViewportSpec('640x360', Size(640, 360)),
  _ViewportSpec('768x1024', Size(768, 1024)),
  _ViewportSpec('1024x768', Size(1024, 768)),
  _ViewportSpec('1280x720', Size(1280, 720)),
  _ViewportSpec('1920x1080', Size(1920, 1080)),
];

const List<_ViewportSpec> _coreViewports = [
  _ViewportSpec('360x740', Size(360, 740)),
  _ViewportSpec('640x360', Size(640, 360)),
  _ViewportSpec('768x1024', Size(768, 1024)),
  _ViewportSpec('1280x720', Size(1280, 720)),
  _ViewportSpec('1920x1080', Size(1920, 1080)),
];

const List<String> _locales = ['ku', 'en'];

Future<void> _pumpWithGuard(
  WidgetTester tester, {
  required Size viewport,
  required String lang,
  required FakeApiClient api,
  required Widget Function(AdminAppNotifier appState) builder,
  FakeViewPadding viewInsets = FakeViewPadding.zero,
  Future<void> Function()? afterMount,
}) async {
  RegaI18n.setLang(lang);
  RC.setDark(false);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = viewInsets;

  final capturedMessages = <String>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    capturedMessages.add('${details.exceptionAsString()}\n${details.informationCollector?.call().map((d) => d.toDescription()).join('\n') ?? ''}');
  };

  try {
    final appState = AdminAppNotifier(
      api: api,
      lang: lang,
      isDark: false,
      checkingSession: false,
      currentUser: const {'id': 1, 'name': 'Admin', 'role': 'admin'},
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider(create: (_) => AdminNavNotifier()),
          ChangeNotifierProvider(create: (_) => DashboardNotifier(api)),
          ChangeNotifierProvider(create: (_) => AdminInboxNotifier(api)),
          ChangeNotifierProvider(create: (_) => OrdersNotifier(api)),
          ChangeNotifierProvider(create: (_) => DriversNotifier(api)),
          ChangeNotifierProvider(create: (_) => CustomersNotifier(api)),
          ChangeNotifierProvider(create: (_) => StoresNotifier(api)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
              ),
              child: Directionality(
                textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: builder(appState),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    if (afterMount != null) {
      await afterMount();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Tear down widget tree so periodic timers & map controllers dispose cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  } finally {
    FlutterError.onError = originalOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  }

  expect(
    capturedMessages,
    isEmpty,
    reason: '[$lang @ ${viewport.width.toInt()}x${viewport.height.toInt()}] ${capturedMessages.join('\n---\n')}',
  );
}

Future<void> _cycleFirstTabBar(WidgetTester tester) async {
  final tabBarFinder = find.byType(TabBar);
  if (tabBarFinder.evaluate().isNotEmpty) {
    final ctrl = tester.widget<TabBar>(tabBarFinder.first).controller;
    if (ctrl != null) {
      for (var i = 1; i < ctrl.length; i++) {
        ctrl.index = i;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockPngHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    RegaI18n.setLang('ku');
    RC.setDark(false);
  });

  testWidgets('LoginScreen renders without overflow across all 7 viewports in RTL & LTR', (tester) async {
    final api = FakeApiClient();
    for (final lang in _locales) {
      for (final vp in _allViewports) {
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (appState) => LoginScreen(
            api: api,
            lang: lang,
            onLangChanged: appState.setLang,
            onLoggedIn: (_) {},
          ),
        );
      }
    }
  });

  testWidgets('AdminShell all 10 tabs render cleanly across viewports in RTL & LTR + mobile Drawer', (tester) async {
    final api = FakeApiClient();

    // Test mobile drawer open on small phone
    for (final lang in _locales) {
      await _pumpWithGuard(
        tester,
        viewport: const Size(360, 740),
        lang: lang,
        api: api,
        builder: (appState) => AdminShell(
          api: api,
          currentUser: const {'id': 1, 'name': 'Admin', 'role': 'admin'},
          lang: lang,
          isDark: false,
          onLangChanged: appState.setLang,
          onThemeChanged: appState.setDark,
          onLogout: () {},
          initialIndex: 0,
        ),
        afterMount: () async {
          final menuFinder = find.byIcon(Icons.menu_rounded);
          expect(menuFinder, findsAtLeastNWidgets(1));
          await tester.tap(menuFinder.first);
          await tester.pump(const Duration(milliseconds: 300));
        },
      );
    }

    // All 10 AdminShell tabs across phone, landscape, tablet, laptop, ultrawide
    for (var tabIndex = 0; tabIndex < 10; tabIndex++) {
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          await _pumpWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            api: api,
            builder: (appState) => AdminShell(
              api: api,
              currentUser: const {'id': 1, 'name': 'Admin', 'role': 'admin'},
              lang: lang,
              isDark: false,
              onLangChanged: appState.setLang,
              onThemeChanged: appState.setDark,
              onLogout: () {},
              initialIndex: tabIndex,
            ),
          );
        }
      }
    }
  });

  testWidgets('Hubs (Vendor, Delivery, Customer) and sub-tabs render without overflow in RTL & LTR', (tester) async {
    final api = FakeApiClient();
    for (final lang in _locales) {
      for (final vp in _coreViewports) {
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: VendorPartScreen(api: api, lang: lang)),
          afterMount: () async {
            const dockIcons = [
              Icons.restaurant_menu_outlined,
              Icons.auto_graph_outlined,
              Icons.storefront_outlined,
              Icons.account_balance_wallet_outlined,
            ];
            for (final icon in dockIcons) {
              final f = find.byIcon(icon);
              if (f.evaluate().isNotEmpty) {
                await tester.tap(f.first);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 220));
              }
            }
          },
        );
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: DeliveryPartScreen(api: api, lang: lang)),
          afterMount: () => _cycleFirstTabBar(tester),
        );
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: CustomerPartScreen(api: api, lang: lang)),
          afterMount: () => _cycleFirstTabBar(tester),
        );
      }
    }
  });

  testWidgets('FinanceScreen, AccountingScreen (all 6 tabs), SupportSettingsScreen (all 5 tabs) render cleanly', (tester) async {
    final api = FakeApiClient();
    for (final lang in _locales) {
      for (final vp in _coreViewports) {
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => FinanceScreen(api: api, lang: lang),
        );

        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: AccountingScreen(api: api, lang: lang)),
          afterMount: () => _cycleFirstTabBar(tester),
        );

        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => SupportSettingsScreen(api: api, lang: lang),
          afterMount: () async {
            final tabLabels = ['هەژمار', 'ئاگادارکردنەوە', 'پارەدان', 'ئاسایش'];
            for (final label in tabLabels) {
              final localized = tx(label);
              final f = find.text(localized);
              if (f.evaluate().isNotEmpty) {
                await tester.ensureVisible(f.first);
                await tester.tap(f.first);
                await tester.pump(const Duration(milliseconds: 200));
              }
            }
          },
        );
      }
    }
  });

  testWidgets('CatalogZones, Marketing, DirectRequests, StoreMenuCategories, Customers render cleanly', (tester) async {
    final api = FakeApiClient();
    for (final lang in _locales) {
      for (final vp in _coreViewports) {
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: CatalogZonesScreen(api: api, lang: lang)),
          afterMount: () => _cycleFirstTabBar(tester),
        );
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: MarketingScreen(api: api, lang: lang)),
          afterMount: () => _cycleFirstTabBar(tester),
        );
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: DirectRequestsScreen(api: api, lang: lang)),
        );
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: StoreMenuCategoriesScreen(api: api, lang: lang)),
        );
        await _pumpWithGuard(
          tester,
          viewport: vp.size,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(body: CustomersScreen(api: api, lang: lang)),
        );
      }
    }
  });

  testWidgets('Dialogs and modals fit small phones, landscape, and soft keyboard open', (tester) async {
    final api = FakeApiClient();
    final dialogSpecs = <({Size size, FakeViewPadding insets})>[
      (size: const Size(360, 740), insets: FakeViewPadding.zero),
      (size: const Size(390, 844), insets: const FakeViewPadding(bottom: 240)),
      (size: const Size(640, 360), insets: const FakeViewPadding(bottom: 140)),
    ];

    for (final lang in _locales) {
      for (final spec in dialogSpecs) {
        // 1. Live Radar Dialog
        await _pumpWithGuard(
          tester,
          viewport: spec.size,
          viewInsets: spec.insets,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) => AdminLiveRadarDialog(api: api),
                  ),
                  child: const Text('open-radar'),
                ),
              ),
            ),
          ),
          afterMount: () async {
            await tester.tap(find.text('open-radar'));
            await tester.pump(const Duration(milliseconds: 250));
          },
        );

        // 2. Blocked Account Dialog
        await _pumpWithGuard(
          tester,
          viewport: spec.size,
          viewInsets: spec.insets,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => BlockedAccountContacts.show(
                    ctx,
                    BlockedAccountContacts.fromJson(const {}),
                  ),
                  child: const Text('open-blocked'),
                ),
              ),
            ),
          ),
          afterMount: () async {
            await tester.tap(find.text('open-blocked'));
            await tester.pump(const Duration(milliseconds: 250));
          },
        );

        // 3. Send Customer Notification Dialog
        await _pumpWithGuard(
          tester,
          viewport: spec.size,
          viewInsets: spec.insets,
          lang: lang,
          api: api,
          builder: (_) => Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showSendCustomerNotificationDialog(
                    ctx,
                    api: api,
                    lang: lang,
                  ),
                  child: const Text('open-notify'),
                ),
              ),
            ),
          ),
          afterMount: () async {
            await tester.tap(find.text('open-notify'));
            await tester.pump(const Duration(milliseconds: 300));
          },
        );

        // 4. Key Add/Create Dialogs (Customers, CatalogZones, Products, Stores, Drivers, SupportSettings)
        Future<void> openByIcon(Widget screen, IconData icon) => _pumpWithGuard(
              tester,
              viewport: spec.size,
              viewInsets: spec.insets,
              lang: lang,
              api: api,
              builder: (_) => Scaffold(body: screen),
              afterMount: () async {
                final finder = find.byIcon(icon);
                if (finder.evaluate().isNotEmpty) {
                  await tester.ensureVisible(finder.first);
                  await tester.tap(finder.first);
                  await tester.pump(const Duration(milliseconds: 250));
                }
              },
            );

        await openByIcon(CustomersScreen(api: api, lang: lang), Icons.add_rounded);
        await openByIcon(CatalogZonesScreen(api: api, lang: lang), Icons.add_rounded);
        await openByIcon(ProductsScreen(api: api, lang: lang), Icons.add_rounded);
        await openByIcon(StoresScreen(api: api, lang: lang), Icons.add_rounded);
        await openByIcon(DriversScreen(api: api, lang: lang), Icons.add);

        await _pumpWithGuard(
          tester,
          viewport: spec.size,
          viewInsets: spec.insets,
          lang: lang,
          api: api,
          builder: (_) => SupportSettingsScreen(api: api, lang: lang),
          afterMount: () async {
            final tabFinder = find.text(tx('هەژمار'));
            if (tabFinder.evaluate().isNotEmpty) {
              await tester.ensureVisible(tabFinder.first);
              await tester.tap(tabFinder.first);
              await tester.pump(const Duration(milliseconds: 200));
            }
            final addAdminFinder = find.byIcon(Icons.person_add_alt_1_rounded);
            if (addAdminFinder.evaluate().isNotEmpty) {
              await tester.ensureVisible(addAdminFinder.first);
              await tester.tap(addAdminFinder.first);
              await tester.pump(const Duration(milliseconds: 250));
            }
          },
        );
      }
    }
  });
}
