import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CustomerApiService {
  CustomerApiService._();
  static final CustomerApiService instance = CustomerApiService._();

  static const String baseUrl = 'http://127.0.0.1:8001/api/v1';
  static const String _tokenKey = 'rega_customer_sanctum_token';

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

  Future<void> clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<void> authenticateOrRegister({
    required String name,
    required String phone,
    String? password,
  }) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    if (cleanPhone.isEmpty) return;
    final pass = (password != null && password.trim().length >= 6) ? password.trim() : 'password123';

    try {
      final loginRes = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers(),
            body: jsonEncode({
              'identifier': cleanPhone,
              'password': pass,
              'device_name': 'rega_customer_app',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (loginRes.statusCode >= 200 && loginRes.statusCode < 300) {
        final body = jsonDecode(loginRes.body) as Map<String, dynamic>;
        final tok = body['data']?['token']?.toString();
        if (tok != null && tok.isNotEmpty) {
          _token = tok;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, tok);
          return;
        }
      }

      // Register if account does not exist yet
      final regRes = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _headers(),
            body: jsonEncode({
              'name': name.trim().isEmpty ? 'کڕیاری ڕێگا' : name.trim(),
              'phone': cleanPhone,
              'password': pass,
              'device_name': 'rega_customer_app',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (regRes.statusCode >= 200 && regRes.statusCode < 300) {
        final body = jsonDecode(regRes.body) as Map<String, dynamic>;
        final tok = body['data']?['token']?.toString();
        if (tok != null && tok.isNotEmpty) {
          _token = tok;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, tok);
        }
      }
    } catch (_) {}
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
    String paymentMethod = 'cash',
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
              'payment_method': paymentMethod,
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
}
