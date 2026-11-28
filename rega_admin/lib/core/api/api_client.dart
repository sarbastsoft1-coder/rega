import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../rega_mobile.dart';

import '../../rega_i18n.dart';
class ExcelBackupFile {
  ExcelBackupFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static String get _defaultBaseUrl => RegaApiHost.apiV1;
  static const String _prefTokenKey = 'rega_admin_token';
  static const String _prefBaseUrlKey = 'rega_admin_base_url';
  static const String _prefLangKey = 'rega_admin_lang';
  static const String _prefDarkKey = 'rega_admin_dark_mode';

  String _baseUrl = 'http://127.0.0.1:8001/api/v1';
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  String get serverOrigin {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null) return RegaApiHost.origin;
    return '${uri.scheme}://${uri.authority}';
  }

  /// Normalize Laravel `storage/` / absolute media URLs to the active API host.
  /// Rewrites `/storage/...` → `/api/v1/media/...` for Flutter web CanvasKit CORS.
  String resolveMediaUrl(String? url) {
    if (url == null) return '';
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('blob:') || trimmed.startsWith('data:')) return trimmed;

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return trimmed;

    var path = parsed.hasScheme ? parsed.path : trimmed;
    if (path.startsWith('/storage/')) {
      path = '/api/v1/media/${path.substring('/storage/'.length)}';
    } else if (path.startsWith('storage/')) {
      path = '/api/v1/media/${path.substring('storage/'.length)}';
    }

    if (parsed.hasScheme && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      final origin = Uri.parse(serverOrigin);
      final host = parsed.host;
      if (host != '127.0.0.1' &&
          host != 'localhost' &&
          parsed.port != 8001 &&
          parsed.port != origin.port &&
          host != origin.host) {
        return trimmed;
      }
      return origin
          .replace(
            path: path.startsWith('/') ? path : '/$path',
            query: parsed.hasQuery ? parsed.query : null,
          )
          .toString();
    }

    if (path.startsWith('/')) {
      return '$serverOrigin$path';
    }
    return '$serverOrigin/$path';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Always auto-detect (same-origin on VPS web, localhost:8001 in local/dev).
    // Stale saved URLs (e.g. :8001 from the old settings dialog) caused false "offline".
    _baseUrl = _defaultBaseUrl;
    await prefs.remove(_prefBaseUrlKey);
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
      throw ApiException('سێرڤەر وەڵامی نەدایەوە. دڵنیابەرەوە لە کارکردنی سێرڤەری پشتەوە.');
    } catch (e) {
      throw ApiException('پەیوەندی بە سێرڤەر نەکرا ($serverOrigin). تکایە دڵنیابەرەوە کە سێرڤەر کاردەکات.');
    }

    Map<String, dynamic> decoded = {};
    if (res.body.isNotEmpty) {
      try {
        final raw = regaJsonDecode(utf8.decode(res.bodyBytes));
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

  Future<Map<String, dynamic>> getLiveRadar() async {
    final res = await _send('GET', '/admin/live-radar');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // --- Admin work inbox (pending orders / stores / drivers / tickets) ---
  Future<Map<String, dynamic>> getAdminInbox() async {
    final res = await _send('GET', '/admin/inbox');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<int> getAdminInboxUnreadCount() async {
    final res = await _send('GET', '/admin/inbox/unread-count');
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> markAdminInboxRead(String itemKey) async {
    final res = await _send('POST', '/admin/inbox/mark-read', body: {
      'item_key': itemKey,
    });
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> markAdminInboxAllRead() async {
    final res = await _send('POST', '/admin/inbox/mark-all-read');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // --- Orders & Dispatch ---
  Future<Map<String, dynamic>> getOrders({
    String status = 'all',
    String? search,
    int? storeId,
    int page = 1,
    int perPage = 100,
  }) async {
    return _send('GET', '/admin/orders', query: {
      'status': status,
      'search': search,
      'store_id': storeId,
      'page': page,
      'per_page': perPage,
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

  Future<Map<String, dynamic>> updateOrder(int orderId, Map<String, dynamic> payload) async {
    return _send('PUT', '/admin/orders/$orderId', body: payload);
  }

  Future<void> deleteOrder(int orderId) async {
    await _send('DELETE', '/admin/orders/$orderId');
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

  Future<List<dynamic>> getStoreCategories({int? storeId, int? categoryId, String? search}) async {
    final res = await _send('GET', '/admin/store-categories', query: {
      'store_id': storeId,
      'category_id': categoryId,
      'search': search,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> addStoreCategory(int storeId, Map<String, dynamic> payload) async {
    return _send('POST', '/admin/stores/$storeId/categories', body: payload);
  }

  Future<Map<String, dynamic>> updateStoreCategory(int storeCategoryId, Map<String, dynamic> payload) async {
    return _send('PUT', '/admin/store-categories/$storeCategoryId', body: payload);
  }

  Future<void> reorderStoreCategories(List<int> orderedIds) async {
    await _send('PUT', '/admin/store-categories/reorder', body: {'order': orderedIds});
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
  Future<List<dynamic>> getDrivers({
    String? search,
    bool? isOnline,
    bool? isVerified,
    int? storeId,
    int? orderId,
  }) async {
    final res = await _send('GET', '/admin/drivers', query: {
      'search': search,
      'is_online': ?isOnline,
      'is_verified': ?isVerified,
      'store_id': ?storeId,
      'order_id': ?orderId,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createDriver(Map<String, dynamic> payload) async {
    return _send('POST', '/admin/drivers', body: payload);
  }

  Future<Map<String, dynamic>> updateDriver(int driverProfileId, Map<String, dynamic> payload) async {
    return _send('PUT', '/admin/drivers/$driverProfileId', body: payload);
  }

  Future<void> deleteDriver(int driverProfileId) async {
    await _send('DELETE', '/admin/drivers/$driverProfileId');
  }

  Future<void> toggleDriverActive(int driverProfileId) async {
    await _send('PATCH', '/admin/drivers/$driverProfileId/toggle-active');
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

  Future<List<dynamic>> getDriverDocuments(int driverProfileId) async {
    final res = await _send('GET', '/admin/drivers/$driverProfileId/documents');
    return res['data'] as List<dynamic>? ?? [];
  }

  /// Update document number / status, optionally clear or replace file (multipart).
  Future<Map<String, dynamic>> updateDriverDocument(
    int docId, {
    String? documentNumber,
    String? status,
    String? rejectionReason,
    bool clearFile = false,
    List<int>? fileBytes,
    String? filename,
  }) async {
    final hasFile = fileBytes != null && fileBytes.isNotEmpty && filename != null && filename.isNotEmpty;
    if (hasFile || clearFile) {
      final uri = _buildUri('/admin/driver-documents/$docId');
      final req = http.MultipartRequest('POST', uri);
      if (_token != null && _token!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $_token';
      }
      req.headers['Accept'] = 'application/json';
      if (documentNumber != null) req.fields['document_number'] = documentNumber;
      if (status != null && status.isNotEmpty) req.fields['status'] = status;
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        req.fields['rejection_reason'] = rejectionReason;
      }
      if (clearFile) req.fields['clear_file'] = '1';
      if (hasFile) {
        req.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));
      }

      late http.StreamedResponse streamed;
      try {
        streamed = await req.send().timeout(const Duration(seconds: 45));
      } on TimeoutException {
        throw ApiException('نوێکردنەوەی بەڵگەنامە کاتی زۆری خایاند (Timeout).');
      } catch (_) {
        throw ApiException('نوێکردنەوەی بەڵگەنامە سەرکەوتوو نەبوو.');
      }

      final body = await streamed.stream.bytesToString();
      Map<String, dynamic> decoded = {};
      if (body.isNotEmpty) {
        try {
          final raw = regaJsonDecode(body);
          if (raw is Map<String, dynamic>) decoded = raw;
        } catch (_) {}
      }
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return decoded;
      }
      throw ApiException(
        decoded['message']?.toString() ?? 'نوێکردنەوەی بەڵگەنامە سەرکەوتوو نەبوو (${streamed.statusCode})',
        streamed.statusCode,
      );
    }

    return _send('PATCH', '/admin/driver-documents/$docId', body: {
      if (documentNumber != null) 'document_number': documentNumber,
      if (status != null && status.isNotEmpty) 'status': status,
      if (rejectionReason != null && rejectionReason.isNotEmpty) 'rejection_reason': rejectionReason,
      if (clearFile) 'clear_file': true,
    });
  }

  Future<Map<String, dynamic>> getDriverDetails(int driverProfileId) async {
    final res = await _send('GET', '/admin/drivers/$driverProfileId');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  MediaType? _mediaTypeForName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return MediaType('application', 'octet-stream');
  }

  /// Upload image or PDF (max 10MB). Returns `{path, url}`.
  Future<Map<String, dynamic>> uploadMedia(List<int> bytes, String filename) async {
    final uri = _buildUri('/admin/upload');
    final req = http.MultipartRequest('POST', uri);
    if (_token != null && _token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $_token';
    }
    req.headers['Accept'] = 'application/json';
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _mediaTypeForName(filename),
    ));

    late http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw ApiException('بارکردنی فایل کاتی زۆری خایاند (Timeout).');
    } catch (_) {
      throw ApiException('بارکردنی فایل سەرکەوتوو نەبوو. دڵنیابەرەوە لە کارکردنی سێرڤەر.');
    }

    final body = await streamed.stream.bytesToString();
    Map<String, dynamic> decoded = {};
    if (body.isNotEmpty) {
      try {
        final raw = regaJsonDecode(body);
        if (raw is Map<String, dynamic>) decoded = raw;
      } catch (_) {}
    }

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded['data'] as Map<String, dynamic>? ?? decoded;
    }

    throw ApiException(
      decoded['message']?.toString() ?? 'بارکردنی فایل سەرکەوتوو نەبوو (${streamed.statusCode})',
      streamed.statusCode,
    );
  }

  /// Upload image/PDF directly onto a driver KYC document row.
  Future<Map<String, dynamic>> uploadDriverDocumentFile(
    int docId,
    List<int> bytes,
    String filename, {
    String? documentNumber,
    String? status,
  }) async {
    final uri = _buildUri('/admin/driver-documents/$docId/upload');
    final req = http.MultipartRequest('POST', uri);
    if (_token != null && _token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $_token';
    }
    req.headers['Accept'] = 'application/json';
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    if (documentNumber != null && documentNumber.isNotEmpty) {
      req.fields['document_number'] = documentNumber;
    }
    if (status != null && status.isNotEmpty) {
      req.fields['status'] = status;
    }

    late http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw ApiException('بارکردنی بەڵگەنامە کاتی زۆری خایاند (Timeout).');
    } catch (_) {
      throw ApiException('بارکردنی بەڵگەنامە سەرکەوتوو نەبوو.');
    }

    final body = await streamed.stream.bytesToString();
    Map<String, dynamic> decoded = {};
    if (body.isNotEmpty) {
      try {
        final raw = regaJsonDecode(body);
        if (raw is Map<String, dynamic>) decoded = raw;
      } catch (_) {}
    }

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      decoded['message']?.toString() ?? 'بارکردنی بەڵگەنامە سەرکەوتوو نەبوو (${streamed.statusCode})',
      streamed.statusCode,
    );
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

  Future<void> updateCustomer(int customerId, Map<String, dynamic> payload) async {
    await _send('PUT', '/admin/customers/$customerId', body: payload);
  }

  Future<void> deleteCustomer(int customerId) async {
    await _send('DELETE', '/admin/customers/$customerId');
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

  /// Persist home-grid tile order (list of category ids, first = top-left).
  Future<List<dynamic>> reorderCategories(List<int> orderedIds) async {
    final res = await _send('PUT', '/admin/categories/reorder', body: {'order': orderedIds});
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getNeighborhoods({int? serviceCityId}) async {
    final q = serviceCityId != null ? '?service_city_id=$serviceCityId' : '';
    final res = await _send('GET', '/admin/neighborhoods$q');
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

  Future<List<dynamic>> getServiceCities() async {
    final res = await _send('GET', '/admin/service-cities');
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createServiceCity(Map<String, dynamic> payload) async {
    final res = await _send('POST', '/admin/service-cities', body: payload);
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> updateServiceCity(int id, Map<String, dynamic> payload) async {
    final res = await _send('PUT', '/admin/service-cities/$id', body: payload);
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> deleteServiceCity(int id) async {
    await _send('DELETE', '/admin/service-cities/$id');
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

  // --- Accounting & Profit Management ---
  Future<Map<String, dynamic>> getAccountingDashboard({String? period, String? from, String? to}) async {
    final res = await _send('GET', '/admin/accounting/dashboard', query: {
      'period': period,
      'from': from,
      'to': to,
    });
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getAccountingShops({String? q, String? period, String? from, String? to}) async {
    return _send('GET', '/admin/accounting/shops', query: {
      'q': q,
      'period': period,
      'from': from,
      'to': to,
    });
  }

  Future<Map<String, dynamic>> getAccountingShop(int storeId, {String? period, String? from, String? to}) async {
    final res = await _send('GET', '/admin/accounting/shops/$storeId', query: {
      'period': period,
      'from': from,
      'to': to,
    });
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getAccountingOrders({
    String? storeId,
    String? status,
    String? orderId,
    String? from,
    String? to,
    int? minProfit,
    int? maxProfit,
  }) async {
    return _send('GET', '/admin/accounting/orders', query: {
      'store_id': storeId,
      'status': status,
      'order_id': orderId,
      'from': from,
      'to': to,
      'min_profit': minProfit?.toString(),
      'max_profit': maxProfit?.toString(),
    });
  }

  Future<Map<String, dynamic>> getAccountingOrder(int orderId) async {
    final res = await _send('GET', '/admin/accounting/orders/$orderId');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getProfitSettings() async {
    final res = await _send('GET', '/admin/accounting/profit-settings');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> updateProfitSettings(
    double percentage, {
    int? storeId,
    String? note,
  }) async {
    final res = await _send('PUT', '/admin/accounting/profit-settings', body: {
      'commission_percentage': percentage,
      if (storeId != null) 'store_id': storeId,
      if (note != null) 'note': note,
    });
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getAccountingReports({String period = 'month', String? from, String? to}) async {
    final res = await _send('GET', '/admin/accounting/reports', query: {
      'period': period,
      'from': from,
      'to': to,
    });
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getAccountingTransactions({String? from, String? to}) async {
    return _send('GET', '/admin/accounting/transactions', query: {
      'from': from,
      'to': to,
    });
  }

  Future<void> refundAccountingOrder(int orderId, {int? orderItemId, int? quantity, bool full = false, String? reason}) async {
    await _send('POST', '/admin/accounting/orders/$orderId/refund', body: {
      if (orderItemId != null) 'order_item_id': orderItemId,
      if (quantity != null) 'quantity': quantity,
      'full': full,
      if (reason != null) 'reason': reason,
    });
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

  Future<List<dynamic>> getTickets({
    String status = 'all',
    String? category,
  }) async {
    final res = await _send('GET', '/admin/tickets', query: {
      'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createTicket(Map<String, dynamic> payload) async {
    final res = await _send('POST', '/admin/tickets', body: payload);
    return res['data'] as Map<String, dynamic>? ?? {};
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

  Future<List<dynamic>> getAdminStaff({String? search, String role = 'admin'}) async {
    final res = await _send('GET', '/admin/staff', query: {
      'search': search,
      'role': role,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createAdminStaff(Map<String, dynamic> payload) async {
    return _send('POST', '/admin/staff', body: payload);
  }

  Future<Map<String, dynamic>> updateAdminStaff(int staffId, Map<String, dynamic> payload) async {
    return _send('PUT', '/admin/staff/$staffId', body: payload);
  }

  Future<void> toggleAdminStaffActive(int staffId) async {
    await _send('PATCH', '/admin/staff/$staffId/toggle-active');
  }

  Future<void> deleteAdminStaff(int staffId) async {
    await _send('DELETE', '/admin/staff/$staffId');
  }

  // --- 3 Core Ecosystem Parts (Vendor / Customer / Delivery) ---
  Future<Map<String, dynamic>> getEcosystemHubs() async {
    final res = await _send('GET', '/admin/ecosystem-hubs');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> createAdminOrder(Map<String, dynamic> payload) async {
    final res = await _send('POST', '/admin/orders', body: payload);
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> verifyHandoverPin(int orderId, [String? pin]) async {
    final res = await _send('POST', '/admin/orders/$orderId/verify-handover');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> verifyDeliveryPin(int orderId, [String? pin]) async {
    final res = await _send('POST', '/admin/orders/$orderId/verify-delivery');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // --- Excel backups ---
  Future<ExcelBackupFile> downloadExcelBackupExport() async {
    return _downloadBinary('/admin/backup/export', fallbackName: 'REGA_Backup.xlsx');
  }

  Future<List<Map<String, dynamic>>> listExcelBackups({int limit = 40}) async {
    final res = await _send('GET', '/admin/backups', query: {'limit': limit});
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<ExcelBackupFile> downloadStoredExcelBackup(String fileName) async {
    final safe = Uri.encodeComponent(fileName);
    return _downloadBinary('/admin/backups/$safe', fallbackName: fileName);
  }

  Future<ExcelBackupFile> downloadAccountingReportCsv({
    String period = 'month',
    String? from,
    String? to,
  }) async {
    return _downloadBinary(
      '/admin/accounting/reports/export',
      fallbackName: 'accounting_report_$period.csv',
      query: {
        'period': period,
        'from': from,
        'to': to,
      },
      accept: 'text/csv, application/octet-stream, application/json',
    );
  }

  Future<ExcelBackupFile> _downloadBinary(
    String path, {
    required String fallbackName,
    Map<String, dynamic>? query,
    String accept =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream, application/json',
  }) async {
    final uri = _buildUri(path, query);
    late http.Response res;
    try {
      res = await http
          .get(uri, headers: {
            'Accept': accept,
            if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
          })
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw ApiException('سێرڤەر وەڵامی نەدایەوە (Timeout). باکئەپی Excel درێژخایەنە — دووبارە هەوڵبدەرەوە.');
    } catch (_) {
      throw ApiException('پەیوەندی بە سێرڤەر نەکرا ($serverOrigin). تکایە دڵنیابەرەوە کە سێرڤەر کاردەکات.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'هەڵەیەک ڕوویدا (${res.statusCode})';
      try {
        final raw = regaJsonDecode(utf8.decode(res.bodyBytes));
        if (raw is Map && raw['message'] != null) {
          msg = raw['message'].toString();
        }
      } catch (_) {}
      throw ApiException(msg, res.statusCode);
    }

    final disposition = res.headers['content-disposition'] ?? '';
    var fileName = fallbackName;
    final match = RegExp(r'filename[^;=]*=\s*"?([^";]+)"?', caseSensitive: false)
        .firstMatch(disposition);
    if (match != null) {
      fileName = Uri.decodeFull(match.group(1)!.trim());
    }

    return ExcelBackupFile(bytes: Uint8List.fromList(res.bodyBytes), fileName: fileName);
  }
}

