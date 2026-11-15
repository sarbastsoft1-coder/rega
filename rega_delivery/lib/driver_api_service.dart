import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'blocked_account.dart';
import 'rega_mobile.dart';

class DriverApiService {
  DriverApiService._();
  static final DriverApiService instance = DriverApiService._();

  static String get baseUrl => RegaApiHost.apiV1;
  static const String _tokenKey = 'rega_driver_sanctum_token';

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

  Future<bool> ensureAuthenticated({
    String phone = '',
    String password = '',
  }) async {
    await initToken();
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final cleanPass = password.trim();
    if (cleanPhone.isEmpty || cleanPass.length < 6) {
      return _token != null && _token!.isNotEmpty;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'identifier': cleanPhone,
              'password': cleanPass,
              'device_name': 'rega_delivery_app',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 403) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['code']?.toString() == 'account_blocked') {
          await logout();
          throw AccountBlockedException.fromBody(body);
        }
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final tok = body['data']?['token']?.toString();
        if (tok != null && tok.isNotEmpty) {
          _token = tok;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, tok);
          return true;
        }
      }
    } on AccountBlockedException {
      rethrow;
    } catch (_) {}
    return _token != null && _token!.isNotEmpty;
  }

  Future<void> logout() async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        await http
            .post(Uri.parse('$baseUrl/auth/logout'), headers: _headers())
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/driver/profile'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> updateOnlineStatus(
    bool isOnline, {
    double? lat,
    double? lng,
  }) async {
    try {
      await initToken();
      if (_token == null || _token!.isEmpty) return null;

      final res = await http
          .patch(
            Uri.parse('$baseUrl/driver/status'),
            headers: _headers(),
            body: jsonEncode({
              'is_online': isOnline,
              if (lat != null) 'lat': lat,
              if (lng != null) 'lng': lng,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'];
        if (data is Map<String, dynamic>) return data;
        // Some responses nest profile under data.driver / data.profile.
        if (data is Map) return Map<String, dynamic>.from(data);
        return <String, dynamic>{'is_online': isOnline};
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateLocation(
    double lat,
    double lng, {
    double? heading,
    double? speedKmh,
  }) async {
    try {
      await http
          .patch(
            Uri.parse('$baseUrl/driver/location'),
            headers: _headers(),
            body: jsonEncode({
              'lat': lat,
              'lng': lng,
              if (heading != null) 'heading': heading,
              if (speedKmh != null) 'speed_kmh': speedKmh,
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> fetchActiveOrder() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/driver/orders/active'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> fetchOrdersHistory({String status = 'all'}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/driver/orders?status=$status'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> advanceOrderStatus(int orderId, String driverStatus) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/driver/orders/$orderId/status'),
            headers: _headers(),
            body: jsonEncode({'driver_status': driverStatus}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<(bool, String?)> completeDelivery(int orderId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/verify-delivery'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
        return (true, body['message']?.toString());
      }
      return (false, body['message']?.toString());
    } catch (_) {
      return (false, null);
    }
  }

  Future<Map<String, dynamic>?> fetchEarnings({String period = 'today'}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/driver/earnings?period=$period'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> requestCancellation(int orderId, String reason) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/cancel-request'),
            headers: _headers(),
            body: jsonEncode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
