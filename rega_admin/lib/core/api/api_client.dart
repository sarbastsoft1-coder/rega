import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static const String _defaultBaseUrl = 'http://127.0.0.1:8001/api/v1';
  static const String _prefTokenKey = 'rega_admin_token';
  static const String _prefBaseUrlKey = 'rega_admin_base_url';
  static const String _prefLangKey = 'rega_admin_lang';
  static const String _prefDarkKey = 'rega_admin_dark_mode';

  String _baseUrl = _defaultBaseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  String get serverOrigin {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null) return 'http://127.0.0.1:8001';
    return '${uri.scheme}://${uri.authority}';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefBaseUrlKey) ?? _defaultBaseUrl;
    _token = prefs.getString(_prefTokenKey);
  }

  Future<void> setBaseUrl(String url) async {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (!cleaned.endsWith('/api/v1')) {
      if (cleaned.endsWith('/api')) {
        cleaned = '$cleaned/v1';
      } else {
        cleaned = '$cleaned/api/v1';
      }
    }
    _baseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrlKey, _baseUrl);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_prefTokenKey);
    } else {
      await prefs.setString(_prefTokenKey, token);
    }
  }

  static Future<String> getSavedLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLangKey) ?? 'ku';
  }

  static Future<void> saveLang(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLangKey, lang);
  }

  static Future<bool> getSavedDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefDarkKey) ?? false;
  }

  static Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDarkKey, isDark);
  }

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final full = path.startsWith('http')
        ? path
        : '$_baseUrl${path.startsWith('/') ? path : '/$path'}';
    final uri = Uri.parse(full);
    if (query == null || query.isEmpty) return uri;

    final filtered = <String, String>{};
    query.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        filtered[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: filtered);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path, query);
    late http.Response res;

    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          res = await http
              .post(uri, headers: _headers(), body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: _headers(), body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          res = await http
              .patch(uri, headers: _headers(), body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 15));
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw ApiException('سێرڤەر وەڵامی نەدایەوە (Timeout). دڵنیابەرەوە لە کارکردنی Laravel Backend.');
    } catch (e) {
      throw ApiException('پەیوەندی بە سێرڤەر نەکرا ($serverOrigin). تکایە دڵنیابەرەوە کە سێرڤەر کاردەکات.');
    }

    Map<String, dynamic> decoded = {};
    if (res.body.isNotEmpty) {
      try {
        final raw = jsonDecode(utf8.decode(res.bodyBytes));
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (_) {
        // Non-JSON error body
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    String msg = decoded['message']?.toString() ?? 'هەڵەیەک ڕوویدا (${res.statusCode})';
    if (decoded['errors'] is Map) {
      final errs = (decoded['errors'] as Map).values.expand((e) => e is List ? e : [e]).join('\n');
      if (errs.isNotEmpty) msg = errs;
    }
    throw ApiException(msg, res.statusCode);
  }

  // --- Health & Auth ---
  Future<Map<String, dynamic>> checkHealth() async {
    return _send('GET', '$serverOrigin/api/health');
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final res = await _send('POST', '/auth/login', body: {
      'identifier': identifier,
      'password': password,
      'role_filter': 'admin',
      'device_name': 'rega-admin-console',
    });
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final tk = data['token']?.toString();
    if (tk != null) {
      await setToken(tk);
    }
    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _send('GET', '/auth/me');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } catch (_) {}
    await setToken(null);
  }

  // --- Dashboard ---
  Future<Map<String, dynamic>> getDashboard({int days = 7}) async {
    final res = await _send('GET', '/admin/dashboard', query: {'days': days});
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // --- Orders & Dispatch ---
  Future<Map<String, dynamic>> getOrders({
    String status = 'all',
    String? search,
    int? storeId,
    int page = 1,
  }) async {
    return _send('GET', '/admin/orders', query: {
      'status': status,
      'search': search,
      'store_id': storeId,
      'page': page,
      'per_page': 40,
    });
  }

  Future<Map<String, dynamic>> getOrderDetails(int orderId) async {
    final res = await _send('GET', '/admin/orders/$orderId');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> assignDriver(int orderId, int driverUserId) async {
    return _send('POST', '/admin/orders/$orderId/assign-driver', body: {
      'driver_id': driverUserId,
    });
  }

  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status, {String? reason}) async {
    return _send('PATCH', '/admin/orders/$orderId/status', body: {
      'status': status,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> addWaitingBonus(int orderId, int bonus, {String? note}) async {
    return _send('POST', '/admin/orders/$orderId/waiting-bonus', body: {
      'waiting_bonus': bonus,
      'note': ?note,
    });
  }

  // --- Stores / Vendors ---
  Future<List<dynamic>> getStores({String? search, int? categoryId, bool? isOnline, bool? isApproved}) async {
    final res = await _send('GET', '/admin/stores', query: {
      'search': search,
      'category_id': categoryId,
      'is_online': ?isOnline,
      'is_approved': ?isApproved,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getStoreDetails(int storeId) async {
    return _send('GET', '/admin/stores/$storeId');
  }

  Future<Map<String, dynamic>> createStore(Map<String, dynamic> payload) async {
    return _send('POST', '/admin/stores', body: payload);
  }

  Future<Map<String, dynamic>> updateStore(int storeId, Map<String, dynamic> payload) async {
    return _send('PUT', '/admin/stores/$storeId', body: payload);
  }

  Future<Map<String, dynamic>> toggleStoreField(int storeId, String field) async {
    return _send('PATCH', '/admin/stores/$storeId/toggle', body: {'field': field});
  }

  Future<void> deleteStore(int storeId) async {
    await _send('DELETE', '/admin/stores/$storeId');
  }

  Future<Map<String, dynamic>> addStoreCategory(int storeId, String nameKu) async {
    return _send('POST', '/admin/stores/$storeId/categories', body: {'name_ku': nameKu});
  }

  Future<void> deleteStoreCategory(int storeCategoryId) async {
    await _send('DELETE', '/admin/store-categories/$storeCategoryId');
  }

  // --- Products ---
  Future<List<dynamic>> getProducts({int? storeId, String? search, bool? isAvailable, bool? hasDiscount}) async {
    final res = await _send('GET', '/admin/products', query: {
      'store_id': storeId,
      'search': search,
      'is_available': ?isAvailable,
      if (hasDiscount == true) 'has_discount': 1,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload) async {
    return _send('POST', '/admin/products', body: payload);
  }

  Future<Map<String, dynamic>> updateProduct(int productId, Map<String, dynamic> payload) async {
    return _send('PUT', '/admin/products/$productId', body: payload);
  }

  Future<void> toggleProductAvailability(int productId) async {
    await _send('PATCH', '/admin/products/$productId/toggle-availability');
  }

  Future<void> deleteProduct(int productId) async {
    await _send('DELETE', '/admin/products/$productId');
  }

  // --- Drivers & KYC ---
  Future<List<dynamic>> getDrivers({String? search, bool? isOnline, bool? isVerified}) async {
    final res = await _send('GET', '/admin/drivers', query: {
      'search': search,
      'is_online': ?isOnline,
      'is_verified': ?isVerified,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createDriver(Map<String, dynamic> payload) async {
    return _send('POST', '/admin/drivers', body: payload);
  }

  Future<Map<String, dynamic>> updateDriver(int driverProfileId, Map<String, dynamic> payload) async {
    return _send('PUT', '/admin/drivers/$driverProfileId', body: payload);
  }

  Future<void> toggleDriverField(int driverProfileId, String field) async {
    await _send('PATCH', '/admin/drivers/$driverProfileId/toggle', body: {'field': field});
  }

  Future<void> verifyDriverDocument(int docId, String status, {String? reason}) async {
    await _send('PATCH', '/admin/driver-documents/$docId/verify', body: {
      'status': status,
      if (reason != null && reason.isNotEmpty) 'rejection_reason': reason,
    });
  }

  // --- Customers ---
  Future<List<dynamic>> getCustomers({String? search, bool? isActive}) async {
    final res = await _send('GET', '/admin/customers', query: {
      'search': search,
      'is_active': ?isActive,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getCustomerDetails(int customerId) async {
    final res = await _send('GET', '/admin/customers/$customerId');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> createCustomer(Map<String, dynamic> payload) async {
    await _send('POST', '/admin/customers', body: payload);
  }

  Future<void> toggleCustomerActive(int customerId) async {
    await _send('PATCH', '/admin/customers/$customerId/toggle-active');
  }

  // --- Categories & Kalar Neighborhoods ---
  Future<List<dynamic>> getCategories() async {
    final res = await _send('GET', '/admin/categories');
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<void> createCategory(Map<String, dynamic> payload) async {
    await _send('POST', '/admin/categories', body: payload);
  }

  Future<void> updateCategory(int id, Map<String, dynamic> payload) async {
    await _send('PUT', '/admin/categories/$id', body: payload);
  }

  Future<void> deleteCategory(int id) async {
    await _send('DELETE', '/admin/categories/$id');
  }

  Future<List<dynamic>> getNeighborhoods() async {
    final res = await _send('GET', '/admin/neighborhoods');
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<void> createNeighborhood(Map<String, dynamic> payload) async {
    await _send('POST', '/admin/neighborhoods', body: payload);
  }

  Future<void> updateNeighborhood(int id, Map<String, dynamic> payload) async {
    await _send('PUT', '/admin/neighborhoods/$id', body: payload);
  }

  Future<void> deleteNeighborhood(int id) async {
    await _send('DELETE', '/admin/neighborhoods/$id');
  }

  // --- Marketing: Coupons, Banners & Notifications ---
  Future<List<dynamic>> getCoupons() async {
    final res = await _send('GET', '/admin/coupons');
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<void> createCoupon(Map<String, dynamic> payload) async {
    await _send('POST', '/admin/coupons', body: payload);
  }

  Future<void> updateCoupon(int id, Map<String, dynamic> payload) async {
    await _send('PUT', '/admin/coupons/$id', body: payload);
  }

  Future<void> deleteCoupon(int id) async {
    await _send('DELETE', '/admin/coupons/$id');
  }

  Future<List<dynamic>> getBanners() async {
    final res = await _send('GET', '/admin/banners');
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<void> createBanner(Map<String, dynamic> payload) async {
    await _send('POST', '/admin/banners', body: payload);
  }

  Future<void> updateBanner(int id, Map<String, dynamic> payload) async {
    await _send('PUT', '/admin/banners/$id', body: payload);
  }

  Future<void> deleteBanner(int id) async {
    await _send('DELETE', '/admin/banners/$id');
  }

  Future<List<dynamic>> getNotifications() async {
    final res = await _send('GET', '/admin/notifications');
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<void> sendNotification(Map<String, dynamic> payload) async {
    await _send('POST', '/admin/notifications', body: payload);
  }

  Future<void> deleteNotification(int id) async {
    await _send('DELETE', '/admin/notifications/$id');
  }

  // --- Finance, Payouts, Tickets & Settings ---
  Future<Map<String, dynamic>> getFinanceSummary() async {
    final res = await _send('GET', '/admin/finance/summary');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> getPayouts({String? recipientType, String? status}) async {
    final res = await _send('GET', '/admin/payouts', query: {
      'recipient_type': recipientType,
      'status': status,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<void> createPayout(Map<String, dynamic> payload) async {
    await _send('POST', '/admin/payouts', body: payload);
  }

  Future<void> updatePayoutStatus(int payoutId, String status, {String? notes}) async {
    await _send('PATCH', '/admin/payouts/$payoutId/status', body: {
      'status': status,
      'notes': ?notes,
    });
  }

  Future<List<dynamic>> getTickets({String status = 'all'}) async {
    final res = await _send('GET', '/admin/tickets', query: {'status': status});
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<void> updateTicket(int ticketId, Map<String, dynamic> payload) async {
    await _send('PATCH', '/admin/tickets/$ticketId', body: payload);
  }

  Future<Map<String, dynamic>> getSettings() async {
    final res = await _send('GET', '/admin/settings');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    final res = await _send('PUT', '/admin/settings', body: {'settings': settings});
    return res['data'] as Map<String, dynamic>? ?? {};
  }
}

