import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VendorApiService {
  VendorApiService._();
  static final VendorApiService instance = VendorApiService._();

  static const String baseUrl = 'http://127.0.0.1:8001/api/v1';
  static const String _tokenPrefKey = 'rega_vendor_sanctum_token';

  String? _token;
  Map<String, int> categoryNameToId = {};

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<bool> login(String identifier, String password) async {
    final cleanId = identifier.trim().isEmpty ? '07701112233' : identifier.trim().replaceAll(' ', '');
    final cleanPass = password.trim().isEmpty ? 'password123' : password.trim();

    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: _headers(),
          body: jsonEncode({
            'identifier': cleanId,
            'password': cleanPass,
            'device_name': 'rega_froshyar_app',
          }),
        )
        .timeout(const Duration(seconds: 6));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final token = decoded['data']?['token']?.toString();
      if (token != null && token.isNotEmpty) {
        _token = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenPrefKey, token);
        return true;
      }
    }
    return false;
  }

  Future<bool> ensureAuthenticated() async {
    if (isAuthenticated) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_tokenPrefKey);
      if (saved != null && saved.isNotEmpty) {
        _token = saved;
        return true;
      }
      return await login('07701112233', 'password123');
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (isAuthenticated) {
        await http
            .post(Uri.parse('$baseUrl/auth/logout'), headers: _headers())
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefKey);
  }

  Future<Map<String, dynamic>?> fetchStoreProfile() async {
    if (!await ensureAuthenticated()) return null;
    final res = await http
        .get(Uri.parse('$baseUrl/vendor/store'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<List<dynamic>> fetchCategories() async {
    if (!await ensureAuthenticated()) return [];
    final res = await http
        .get(Uri.parse('$baseUrl/vendor/categories'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>? ?? [];
      categoryNameToId.clear();
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final name = m['name_ku']?.toString() ?? '';
        final id = (m['id'] as num?)?.toInt();
        if (name.isNotEmpty && id != null) {
          categoryNameToId[name] = id;
        }
      }
      return list;
    }
    return [];
  }

  Future<List<dynamic>> fetchProducts() async {
    if (!await ensureAuthenticated()) return [];
    final res = await http
        .get(Uri.parse('$baseUrl/vendor/products'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    return [];
  }

  Future<List<dynamic>> fetchOrders() async {
    if (!await ensureAuthenticated()) return [];
    final res = await http
        .get(Uri.parse('$baseUrl/vendor/orders?status=all'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    return [];
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (!await ensureAuthenticated()) return;
    await http
        .patch(
          Uri.parse('$baseUrl/vendor/store/status'),
          headers: _headers(),
          body: jsonEncode({'is_online': isOnline}),
        )
        .timeout(const Duration(seconds: 5));
  }

  Future<void> updateStoreInfo({
    required String nameKu,
    String? phone,
    String? openTime,
    String? closeTime,
  }) async {
    if (!await ensureAuthenticated()) return;
    await http
        .patch(
          Uri.parse('$baseUrl/vendor/store'),
          headers: _headers(),
          body: jsonEncode({
            'name_ku': nameKu,
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
            if (openTime != null) 'open_time': openTime,
            if (closeTime != null) 'close_time': closeTime,
          }),
        )
        .timeout(const Duration(seconds: 5));
  }

  Future<bool> acceptOrder(int dbOrderId) async {
    if (!await ensureAuthenticated()) return false;
    final res = await http
        .post(Uri.parse('$baseUrl/vendor/orders/$dbOrderId/accept'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> rejectOrder(int dbOrderId) async {
    if (!await ensureAuthenticated()) return false;
    final res = await http
        .post(Uri.parse('$baseUrl/vendor/orders/$dbOrderId/reject'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> markReady(int dbOrderId) async {
    if (!await ensureAuthenticated()) return false;
    final res = await http
        .post(Uri.parse('$baseUrl/vendor/orders/$dbOrderId/ready'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<(bool, String)> verifyHandoverPin(int dbOrderId, String pin) async {
    if (!await ensureAuthenticated()) {
      return (false, 'پەیوەندی بە سێرڤەرەوە نییە');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/vendor/orders/$dbOrderId/handover'),
          headers: _headers(),
          body: jsonEncode({'pin': pin}),
        )
        .timeout(const Duration(seconds: 5));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      return (true, body['message']?.toString() ?? 'سەرکەوتوو بوو');
    }
    return (false, body['message']?.toString() ?? 'کۆدی PIN هەڵەیە!');
  }

  Future<int?> addCategory(String nameKu) async {
    if (!await ensureAuthenticated()) return null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/vendor/categories'),
          headers: _headers(),
          body: jsonEncode({'name_ku': nameKu}),
        )
        .timeout(const Duration(seconds: 5));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final id = (body['data']?['id'] as num?)?.toInt();
      if (id != null) categoryNameToId[nameKu] = id;
      return id;
    }
    return null;
  }

  Future<void> deleteCategoryByName(String nameKu) async {
    final id = categoryNameToId[nameKu];
    if (id == null || !await ensureAuthenticated()) return;
    await http
        .delete(Uri.parse('$baseUrl/vendor/categories/$id'), headers: _headers())
        .timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>?> addProduct({
    required String nameKu,
    required String categoryName,
    required int price,
    int? discountPrice,
    String? descriptionKu,
    String? imageUrl,
    bool isAvailable = true,
  }) async {
    if (!await ensureAuthenticated()) return null;
    int? catId = categoryNameToId[categoryName];
    catId ??= await addCategory(categoryName);

    final res = await http
        .post(
          Uri.parse('$baseUrl/vendor/products'),
          headers: _headers(),
          body: jsonEncode({
            'store_category_id': catId,
            'name_ku': nameKu,
            'price': price,
            'discount_price': discountPrice,
            'description_ku': descriptionKu,
            'image_url': imageUrl,
            'is_available': isAvailable,
          }),
        )
        .timeout(const Duration(seconds: 5));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<void> updateProduct({
    required int productId,
    required String nameKu,
    required String categoryName,
    required int price,
    int? discountPrice,
    String? descriptionKu,
    String? imageUrl,
    required bool isAvailable,
  }) async {
    if (!await ensureAuthenticated()) return;
    final catId = categoryNameToId[categoryName];
    await http
        .put(
          Uri.parse('$baseUrl/vendor/products/$productId'),
          headers: _headers(),
          body: jsonEncode({
            'store_category_id': catId,
            'name_ku': nameKu,
            'price': price,
            'discount_price': discountPrice,
            'description_ku': descriptionKu,
            'image_url': imageUrl,
            'is_available': isAvailable,
          }),
        )
        .timeout(const Duration(seconds: 5));
  }

  Future<void> toggleProductAvailability(int productId) async {
    if (!await ensureAuthenticated()) return;
    await http
        .patch(Uri.parse('$baseUrl/vendor/products/$productId/availability'), headers: _headers())
        .timeout(const Duration(seconds: 5));
  }

  Future<void> deleteProduct(int productId) async {
    if (!await ensureAuthenticated()) return;
    await http
        .delete(Uri.parse('$baseUrl/vendor/products/$productId'), headers: _headers())
        .timeout(const Duration(seconds: 5));
  }
}