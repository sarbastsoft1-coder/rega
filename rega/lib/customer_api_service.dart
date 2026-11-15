import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'blocked_account.dart';
import 'rega_mobile.dart';

class CustomerApiService {
  CustomerApiService._();
  static final CustomerApiService instance = CustomerApiService._();

  static String get baseUrl => RegaApiHost.apiV1;
  static const String _tokenKey = 'rega_customer_sanctum_token';

  String? _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<void> initToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
    } catch (_) {}
  }

  Future<void> clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<void> _persistToken(String tok) async {
    _token = tok;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, tok);
  }

  /// Login (allowRegister=false) or register (allowRegister=true).
  /// Always persists Sanctum token on success.
  /// Throws on failure so the UI does not mark the user logged-in without a token.
  Future<Map<String, dynamic>?> authenticateOrRegister({
    required String name,
    required String phone,
    String? password,
    bool allowRegister = true,
  }) async {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleanPhone.isEmpty) {
      throw Exception('phone_required');
    }
    // Iraqi mobile: 07xxxxxxxxx (11 digits).
    if (!RegExp(r'^07\d{9}$').hasMatch(cleanPhone)) {
      throw Exception('phone_invalid');
    }
    final pass = password?.trim() ?? '';
    if (pass.length < 6) {
      throw Exception('password_required');
    }

    if (allowRegister) {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw Exception('name_required');
      }
      return _register(name: trimmedName, phone: cleanPhone, password: pass);
    }
    return _login(phone: cleanPhone, password: pass);
  }

  Future<Map<String, dynamic>?> _login({
    required String phone,
    required String password,
  }) async {
    final loginRes = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'identifier': phone,
            'password': password,
            'device_name': 'rega_customer_app',
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (loginRes.statusCode == 403) {
      final body = jsonDecode(loginRes.body) as Map<String, dynamic>;
      if (body['code']?.toString() == 'account_blocked') {
        await clearToken();
        throw AccountBlockedException.fromBody(body);
      }
    }

    if (loginRes.statusCode >= 200 && loginRes.statusCode < 300) {
      final body = jsonDecode(loginRes.body) as Map<String, dynamic>;
      final tok = body['data']?['token']?.toString();
      if (tok != null && tok.isNotEmpty) {
        await _persistToken(tok);
        return body['data'] as Map<String, dynamic>?;
      }
    }

    throw Exception('login_failed');
  }

  Future<Map<String, dynamic>?> _register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final regRes = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': name,
            'phone': phone,
            'password': password,
            'device_name': 'rega_customer_app',
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (regRes.statusCode >= 200 && regRes.statusCode < 300) {
      final body = jsonDecode(regRes.body) as Map<String, dynamic>;
      final tok = body['data']?['token']?.toString();
      if (tok != null && tok.isNotEmpty) {
        await _persistToken(tok);
        return body['data'] as Map<String, dynamic>?;
      }
      throw Exception('register_failed');
    }

    // Phone already taken (Laravel unique validation → 422).
    if (regRes.statusCode == 422) {
      final body = jsonDecode(regRes.body) as Map<String, dynamic>;
      final errors = body['errors'];
      final phoneErr = errors is Map ? errors['phone'] : null;
      if (phoneErr != null) {
        throw Exception('phone_taken');
      }
    }

    throw Exception('register_failed');
  }

  Future<Map<String, dynamic>?> fetchMe() async {
    await initToken();
    if (!hasToken) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/auth/me'), headers: _headers())
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 403) {
        Map<String, dynamic> body = {};
        try {
          body = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {}
        await clearToken();
        if (body['code']?.toString() == 'account_blocked') {
          throw AccountBlockedException.fromBody(body);
        }
        return null;
      }
      if (res.statusCode == 401) {
        await clearToken();
        return null;
      }
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } on AccountBlockedException {
      rethrow;
    } catch (_) {}
    return null;
  }

  /// Public help/support contacts (WhatsApp) from admin settings.
  Future<Map<String, dynamic>> fetchSupportContacts() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/public/support-contacts'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>?> fetchBootstrap() async {
    await initToken();
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/public/bootstrap'), headers: _headers())
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchStoreDetails(int storeId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/public/stores/$storeId'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> placeBackendOrder({
    int? storeId,
    required String storeName,
    required String neighborhoodName,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required double deliveryLat,
    required double deliveryLng,
    required int deliveryFee,
    required List<Map<String, dynamic>> items,
    String? couponCode,
    String? notes,
  }) async {
    await initToken();
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/public/orders'),
            headers: _headers(),
            body: jsonEncode({
              'store_id': storeId,
              'store_name': storeName,
              'neighborhood_name': neighborhoodName,
              'customer_name': customerName,
              'customer_phone': customerPhone,
              'delivery_address': deliveryAddress,
              'delivery_lat': deliveryLat,
              'delivery_lng': deliveryLng,
              'delivery_fee': deliveryFee,
              'payment_method': 'cash',
              'coupon_code': couponCode,
              'customer_notes': notes,
              'items': items,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> fetchCustomerOrders({String? phone}) async {
    await initToken();
    try {
      final uri = Uri.parse('$baseUrl/public/customer-orders').replace(
        queryParameters: phone != null && phone.trim().isNotEmpty ? {'phone': phone.trim()} : null,
      );
      final res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// ئاگاداری و داشکاندنەکان لە ئەدمین (بۆ زەنگی نۆتیفیکەیشن)
  Future<List<dynamic>> fetchNotifications() async {
    await initToken();
    try {
      // Prefer authenticated inbox so personal / fan-out rows are included.
      if (hasToken) {
        final res = await http
            .get(Uri.parse('$baseUrl/customer/notifications'), headers: _headers())
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['data'] as List<dynamic>? ?? [];
        }
        // Stale / revoked Sanctum token → drop it and fall back to public broadcasts.
        if (res.statusCode == 401 || res.statusCode == 403) {
          await clearToken();
        }
      }

      final pub = await http
          .get(Uri.parse('$baseUrl/public/notifications'), headers: _headers())
          .timeout(const Duration(seconds: 6));
      if (pub.statusCode == 200) {
        final body = jsonDecode(pub.body) as Map<String, dynamic>;
        return body['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Mark outbound notifications as read (own rows only).
  Future<bool> markNotificationsRead({List<int>? ids, bool all = false}) async {
    await initToken();
    if (!hasToken) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/customer/notifications/mark-read'),
            headers: _headers(),
            body: jsonEncode({
              if (all) 'all': true,
              if (ids != null && ids.isNotEmpty) 'ids': ids,
            }),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

