import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DriverApiService {
  DriverApiService._();
  static final DriverApiService instance = DriverApiService._();

  static const String baseUrl = 'http://127.0.0.1:8001/api/v1';
  static const String _tokenKey = 'rega_driver_sanctum_token';

  String? _token;

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
    String phone = '07501234567',
    String password = 'password123',
  }) async {
    await initToken();
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final targetPhone = cleanPhone.isEmpty ? '07501234567' : cleanPhone;

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'identifier': targetPhone,
              'password': password.trim().isEmpty ? 'password123' : password.trim(),
              'device_name': 'rega_delivery_app',
            }),
          )
          .timeout(const Duration(seconds: 5));

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

  Future<Map<String, dynamic>?> updateOnlineStatus(bool isOnline) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/driver/status'),
            headers: _headers(),
            body: jsonEncode({'is_online': isOnline}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateLocation(double lat, double lng) async {
    try {
      await http
          .patch(
            Uri.parse('$baseUrl/driver/location'),
            headers: _headers(),
            body: jsonEncode({'lat': lat, 'lng': lng}),
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

  Future<(bool, String?)> verifyDeliveryPin(int orderId, String pin) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/verify-delivery'),
            headers: _headers(),
            body: jsonEncode({'pin': pin}),
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
