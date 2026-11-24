import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'blocked_account.dart';
import 'rega_mobile.dart';

import 'rega_i18n.dart';

class PasswordResetException implements Exception {
  PasswordResetException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

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
      final body = regaJsonDecode(loginRes.body) as Map<String, dynamic>;
      if (body['code']?.toString() == 'account_blocked') {
        await clearToken();
        throw AccountBlockedException.fromBody(body);
      }
    }

    if (loginRes.statusCode >= 200 && loginRes.statusCode < 300) {
      final body = regaJsonDecode(loginRes.body) as Map<String, dynamic>;
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
      final body = regaJsonDecode(regRes.body) as Map<String, dynamic>;
      final tok = body['data']?['token']?.toString();
      if (tok != null && tok.isNotEmpty) {
        await _persistToken(tok);
        return body['data'] as Map<String, dynamic>?;
      }
      throw Exception('register_failed');
    }

    // Phone already taken (Laravel unique validation → 422).
    if (regRes.statusCode == 422) {
      final body = regaJsonDecode(regRes.body) as Map<String, dynamic>;
      final errors = body['errors'];
      final phoneErr = errors is Map ? errors['phone'] : null;
      if (phoneErr != null) {
        throw Exception('phone_taken');
      }
    }

    throw Exception('register_failed');
  }

  /// Step 1 — request 6-digit OTP for customer password reset (phone must exist).
  Future<Map<String, dynamic>> requestPasswordResetOtp(String phone) async {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^07\d{9}$').hasMatch(cleanPhone)) {
      throw Exception('phone_invalid');
    }

    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/password-reset/request-otp'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'phone': cleanPhone}),
        )
        .timeout(const Duration(seconds: 12));

    Map<String, dynamic> body = {};
    try {
      body = regaJsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      final data = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      final msg = body['message']?.toString();
      if (msg != null && msg.isNotEmpty) {
        data['message'] = msg;
      }
      return data;
    }

    final msg = body['message']?.toString();
    if (msg != null && msg.isNotEmpty) {
      throw PasswordResetException(msg, statusCode: res.statusCode);
    }
    throw Exception('password_reset_request_failed');
  }

  /// Step 2 — verify OTP and set a new password.
  Future<String> resetPasswordWithOtp({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    final cleanOtp = otp.trim().replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^07\d{9}$').hasMatch(cleanPhone)) {
      throw Exception('phone_invalid');
    }
    if (cleanOtp.length != 6) {
      throw Exception('otp_invalid');
    }
    if (newPassword.trim().length < 6) {
      throw Exception('password_required');
    }

    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/password-reset/confirm'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'phone': cleanPhone,
            'otp': cleanOtp,
            'new_password': newPassword.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    Map<String, dynamic> body = {};
    try {
      body = regaJsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      return body['message']?.toString() ?? '';
    }

    final msg = body['message']?.toString();
    if (msg != null && msg.isNotEmpty) {
      throw PasswordResetException(msg, statusCode: res.statusCode);
    }
    throw Exception('password_reset_confirm_failed');
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
          body = regaJsonDecode(res.body) as Map<String, dynamic>;
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
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
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
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>?> fetchBootstrap({int? cityId}) async {
    await initToken();
    try {
      final uri = Uri.parse('$baseUrl/public/bootstrap').replace(
        queryParameters: cityId != null ? {'city_id': '$cityId'} : null,
      );
      final res = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
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
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  /// Stores for one customer-home section only (category_id from admin جۆری فرۆشیار).
  Future<List<Map<String, dynamic>>> fetchStoresByCategory(int categoryId) async {
    try {
      final uri = Uri.parse('$baseUrl/public/stores').replace(
        queryParameters: {'category_id': '$categoryId'},
      );
      final res = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'];
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {}
    return const [];
  }

  /// Returns `(data, errorMessage)`. On success `errorMessage` is null.
  Future<(Map<String, dynamic>?, String?)> placeBackendOrder({
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
    // Normalize Flutter cart keys to what the API expects.
    final normalizedItems = items.map((raw) {
      final m = Map<String, dynamic>.from(raw);
      m['product_name'] ??= m['name'];
      m['unit_price'] ??= m['price'];
      m['special_notes'] ??= m['notes'];
      return m;
    }).toList();

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/public/orders'),
            headers: _headers(),
            body: jsonEncode({
              if (storeId != null) 'store_id': storeId,
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
              'items': normalizedItems,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = res.body.isNotEmpty
          ? (regaJsonDecode(res.body) as Map<String, dynamic>)
          : <String, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] != false) {
        return (body['data'] as Map<String, dynamic>?, null);
      }
      final msg = body['message']?.toString();
      return (
        null,
        (msg != null && msg.isNotEmpty)
            ? msg
            : 'ناردنی داواکاری سەرکەوتوو نەبوو (${res.statusCode})',
      );
    } catch (_) {
      return (null, 'پەیوەندی بە سێرڤەرەوە شکستی هێنا. دووبارە هەوڵبدەرەوە.');
    }
  }

  Future<List<dynamic>> fetchCustomerOrders({String? phone}) async {
    await initToken();
    try {
      final uri = Uri.parse('$baseUrl/public/customer-orders').replace(
        queryParameters: phone != null && phone.trim().isNotEmpty ? {'phone': phone.trim()} : null,
      );
      final res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<bool> deleteOrder(String orderId) async {
    await initToken();
    try {
      final uri = Uri.parse('$baseUrl/public/customer-orders/$orderId');
      final res = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['success'] == true;
      }
    } catch (_) {}
    return false;
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
          final body = regaJsonDecode(res.body) as Map<String, dynamic>;
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
        final body = regaJsonDecode(pub.body) as Map<String, dynamic>;
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

  /// Persist FCM device token so admin/order pushes reach this phone.
  Future<bool> updateFcmToken(String token) async {
    await initToken();
    if (!hasToken || token.trim().isEmpty) return false;
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl/auth/profile'),
            headers: _headers(),
            body: jsonEncode({'fcm_token': token.trim()}),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Upload image for داواکاری ڕاستەوخۆ.
  Future<Map<String, dynamic>?> uploadDirectRequestImage({
    required List<int> bytes,
    required String filename,
  }) async {
    await initToken();
    if (!hasToken) throw Exception('login_required');
    final uri = Uri.parse('$baseUrl/customer/direct-requests/upload');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        Uint8List.fromList(bytes),
        filename: filename.isEmpty ? 'photo.jpg' : filename,
      ),
    );
    final streamed = await req.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    final body = regaJsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      final data = body['data'];
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }
      if (map != null) {
        final rawUrl = map['url']?.toString();
        final resolved = RegaApiHost.resolveMediaUrl(rawUrl);
        if (resolved.isNotEmpty) map['url'] = resolved;
        return map;
      }
      return null;
    }
    throw Exception(body['message']?.toString() ?? 'upload_failed');
  }

  /// Submit داواکاری ڕاستەوخۆ form.
  Future<Map<String, dynamic>> submitDirectRequest({
    required String subject,
    required String notes,
    required String address,
    required String phone,
    String? imageUrl,
  }) async {
    await initToken();
    if (!hasToken) throw Exception('login_required');
    final res = await http
        .post(
          Uri.parse('$baseUrl/customer/direct-requests'),
          headers: _headers(),
          body: jsonEncode({
            'subject': subject,
            'notes': notes,
            'address': address,
            'phone': phone,
            if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = regaJsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {};
    }
    throw Exception(body['message']?.toString() ?? 'direct_request_failed');
  }
}

