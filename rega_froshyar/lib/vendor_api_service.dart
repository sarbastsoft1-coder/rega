import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'blocked_account.dart';
import 'rega_mobile.dart';

import 'rega_i18n.dart';
class VendorApiService {
  VendorApiService._();
  static final VendorApiService instance = VendorApiService._();

  static String get baseUrl => RegaApiHost.apiV1;
  static const String _tokenPrefKey = 'rega_vendor_sanctum_token';

  String? _token;
  Map<String, int> categoryNameToId = {};

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  /// Normalize Laravel media URLs onto the active API host and CORS-safe path.
  /// Rewrites `/storage/...` → `/api/v1/media/...` for Flutter web CanvasKit.
  String resolveMediaUrl(String? url) {
    if (url == null) return '';
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('blob:') || trimmed.startsWith('data:')) return trimmed;

    final origin = RegaApiHost.origin;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return trimmed;

    String path = parsed.hasScheme ? parsed.path : trimmed;
    if (path.startsWith('/storage/')) {
      path = '/api/v1/media/${path.substring('/storage/'.length)}';
    } else if (path.startsWith('storage/')) {
      path = '/api/v1/media/${path.substring('storage/'.length)}';
    } else if (!path.startsWith('/')) {
      path = '/$path';
    }

    if (parsed.hasScheme &&
        (parsed.scheme == 'http' || parsed.scheme == 'https') &&
        !path.startsWith('/api/v1/media/') &&
        !path.startsWith('/storage/')) {
      // External CDN (e.g. Unsplash) — keep as-is unless local API host.
      final host = parsed.host;
      if (host != '127.0.0.1' &&
          host != 'localhost' &&
          parsed.port != 8001 &&
          host != Uri.parse(origin).host) {
        return trimmed;
      }
    }

    return Uri.parse(origin).replace(path: path, query: parsed.hasQuery ? parsed.query : null).toString();
  }

  MediaType? _mediaTypeForName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return null;
  }

  Future<bool> login(String identifier, String password) async {
    final cleanId = identifier.trim().replaceAll(' ', '');
    final cleanPass = password.trim();
    if (cleanId.isEmpty || cleanPass.length < 6) return false;

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

    if (res.statusCode == 403) {
      final decoded = regaJsonDecode(res.body) as Map<String, dynamic>;
      if (decoded['code']?.toString() == 'account_blocked') {
        await logout();
        throw AccountBlockedException.fromBody(decoded);
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = regaJsonDecode(res.body) as Map<String, dynamic>;
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
      return false;
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
    categoryNameToId.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefKey);
    // Note: logout only clears the auth token — never deletes server catalog.
  }

  /// Public support contacts (WhatsApp / Telegram / phone) — no auth required.
  Future<Map<String, dynamic>> fetchSupportContacts() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/public/support-contacts'), headers: {
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = regaJsonDecode(res.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>?> fetchStoreProfile() async {
    if (!await ensureAuthenticated()) return null;
    final res = await http
        .get(Uri.parse('$baseUrl/vendor/store'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Returns the category list on success, or `null` when the request failed
  /// (so callers do not wipe a good in-memory catalog on a transient error).
  Future<List<dynamic>?> fetchCategories() async {
    if (!await ensureAuthenticated()) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/vendor/categories'), headers: _headers())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
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
    } catch (_) {}
    return null;
  }

  /// Returns the product list on success, or `null` on request failure.
  Future<List<dynamic>?> fetchProducts() async {
    if (!await ensureAuthenticated()) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/vendor/products'), headers: _headers())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> fetchOrders() async {
    if (!await ensureAuthenticated()) return [];
    final res = await http
        .get(Uri.parse('$baseUrl/vendor/orders?status=all'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
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

  /// داشکاندنی گشتی بۆ هەموو بەرهەمەکان (percent: 0–100، بە ٥٪؛ 0 = لابردن)
  Future<(bool, String)> applyStoreDiscount(int percent) async {
    if (!await ensureAuthenticated()) return (false, 'پەیوەندی نییە');
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/vendor/store/discount'),
            headers: _headers(),
            body: jsonEncode({'percent': percent}),
          )
          .timeout(const Duration(seconds: 8));
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      final ok = res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true;
      return (ok, body['message']?.toString() ?? (ok ? 'داشکاندن جێبەجێ کرا' : 'کێشەیەک ڕوویدا'));
    } catch (_) {
      return (false, 'کێشەی پەیوەندی');
    }
  }

  Future<void> updateStoreInfo({
    required String nameKu,
    String? phone,
    String? openTime,
    String? closeTime,
    String? coverUrl,
    String? logoUrl,
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
            if (coverUrl != null && coverUrl.trim().isNotEmpty) 'cover_url': coverUrl.trim(),
            if (logoUrl != null && logoUrl.trim().isNotEmpty) 'logo_url': logoUrl.trim(),
          }),
        )
        .timeout(const Duration(seconds: 8));
  }

  Future<bool> acceptOrder(int dbOrderId) async {
    if (!await ensureAuthenticated()) return false;
    final res = await http
        .post(Uri.parse('$baseUrl/vendor/orders/$dbOrderId/accept'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> rejectOrder(int dbOrderId, {String? reason}) async {
    if (!await ensureAuthenticated()) return false;
    final res = await http
        .post(
          Uri.parse('$baseUrl/vendor/orders/$dbOrderId/reject'),
          headers: {
            ..._headers(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
            if (reason != null && reason.trim().isNotEmpty) 'note': reason.trim(),
          }),
        )
        .timeout(const Duration(seconds: 5));
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<(bool, String, Map<String, dynamic>?)> markReady(int dbOrderId) async {
    if (!await ensureAuthenticated()) return (false, 'پەیوەندی نییە', null);
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/vendor/orders/$dbOrderId/ready'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      final ok = res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true;
      final msg = body['message']?.toString() ?? (ok ? 'ئامادەکرا و نێردرا بۆ شۆفێر' : 'کێشەیەک ڕوویدا');
      final data = body['data'] as Map<String, dynamic>?;
      return (ok, msg, data);
    } catch (_) {
      return (false, 'کێشەی پەیوەندی لە کاتی ناردن بۆ شۆفێر', null);
    }
  }

  Future<Map<String, dynamic>?> fetchNearbyDrivers() async {
    if (!await ensureAuthenticated()) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/vendor/nearby-drivers'), headers: _headers())
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<(bool, String, Map<String, dynamic>?)> dispatchNearestDriver(int dbOrderId) async {
    if (!await ensureAuthenticated()) return (false, 'پەیوەندی نییە', null);
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/vendor/orders/$dbOrderId/dispatch-driver'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      final ok = res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true;
      final msg = body['message']?.toString() ?? (ok ? 'شۆفێر دیاریکرا' : 'شۆفێر نەدۆزرایەوە');
      final data = body['data'] as Map<String, dynamic>?;
      return (ok, msg, data);
    } catch (_) {
      return (false, 'کێشەی پەیوەندی لە دۆزینەوەی شۆفێر', null);
    }
  }

  Future<(bool, String, Map<String, dynamic>?)> assignDriver(int dbOrderId, int driverUserId) async {
    if (!await ensureAuthenticated()) return (false, 'پەیوەندی نییە', null);
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/vendor/orders/$dbOrderId/assign-driver'),
            headers: _headers(),
            body: jsonEncode({'driver_id': driverUserId}),
          )
          .timeout(const Duration(seconds: 5));
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      final ok = res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true;
      final msg = body['message']?.toString() ?? (ok ? 'ماتۆرسوار دیاریکرا' : 'دیاریکردن سەرکەوتوو نەبوو');
      final data = body['data'] as Map<String, dynamic>?;
      return (ok, msg, data);
    } catch (_) {
      return (false, 'کێشەی پەیوەندی لە دیاریکردنی ماتۆرسوار', null);
    }
  }

  Future<(bool, String)> handoverToDriver(int dbOrderId) async {
    if (!await ensureAuthenticated()) {
      return (false, 'پەیوەندی بە سێرڤەرەوە نییە');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/vendor/orders/$dbOrderId/handover'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 5));
    final body = regaJsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      return (true, body['message']?.toString() ?? 'سەرکەوتوو بوو');
    }
    return (false, body['message']?.toString() ?? 'ڕادەستکردن سەرکەوتوو نەبوو');
  }

  Future<int?> addCategory(
    String nameKu, {
    String? imageUrl,
    String? secondaryImageUrl,
  }) async {
    if (!await ensureAuthenticated()) return null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/vendor/categories'),
          headers: _headers(),
          body: jsonEncode({
            'name_ku': nameKu,
            if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
            if (secondaryImageUrl != null && secondaryImageUrl.isNotEmpty)
              'secondary_image_url': secondaryImageUrl,
          }),
        )
        .timeout(const Duration(seconds: 5));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      final id = (body['data']?['id'] as num?)?.toInt();
      if (id != null) categoryNameToId[nameKu] = id;
      return id;
    }
    return null;
  }

  Future<(bool, String)> updateCategory({
    required String oldNameKu,
    required String newNameKu,
    String? imageUrl,
    String? secondaryImageUrl,
  }) async {
    final id = categoryNameToId[oldNameKu];
    if (id == null) {
      return (false, 'بەش نەدۆزرایەوە');
    }
    if (!await ensureAuthenticated()) {
      return (false, 'پەیوەندی بە سێرڤەرەوە نییە');
    }
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl/vendor/categories/$id'),
            headers: _headers(),
            body: jsonEncode({
              'name_ku': newNameKu,
              if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
              if (secondaryImageUrl != null && secondaryImageUrl.isNotEmpty)
                'secondary_image_url': secondaryImageUrl,
            }),
          )
          .timeout(const Duration(seconds: 8));
      final body = res.body.isNotEmpty
          ? (regaJsonDecode(res.body) as Map<String, dynamic>)
          : <String, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] != false) {
        categoryNameToId.remove(oldNameKu);
        categoryNameToId[newNameKu] = id;
        return (true, body['message']?.toString() ?? 'بەش نوێکرایەوە');
      }
      return (false, body['message']?.toString() ?? 'نوێکردنەوەی بەش سەرکەوتوو نەبوو');
    } catch (_) {
      return (false, 'نوێکردنەوەی بەش سەرکەوتوو نەبوو');
    }
  }

  Future<void> deleteCategoryByName(String nameKu) async {
    final id = categoryNameToId[nameKu];
    if (id == null || !await ensureAuthenticated()) return;
    await http
        .delete(Uri.parse('$baseUrl/vendor/categories/$id'), headers: _headers())
        .timeout(const Duration(seconds: 5));
  }

  /// Upload image bytes. Returns `{path, url}` or throws on failure.
  Future<Map<String, dynamic>> uploadMedia(Uint8List bytes, String filename) async {
    if (!await ensureAuthenticated()) {
      throw Exception('تکایە دووبارە بچۆ ژوورەوە.');
    }
    final uri = Uri.parse('$baseUrl/vendor/upload');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $_token';
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
    } catch (_) {
      throw Exception('بارکردنی وێنە سەرکەوتوو نەبوو. دڵنیابەرەوە لە کارکردنی سێرڤەر.');
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
      final data = decoded['data'] as Map<String, dynamic>? ?? decoded;
      final rawUrl = data['url']?.toString();
      if (rawUrl != null && rawUrl.isNotEmpty) {
        data['url'] = resolveMediaUrl(rawUrl);
      }
      return data;
    }

    throw Exception(
      decoded['message']?.toString() ??
          'بارکردنی وێنە سەرکەوتوو نەبوو (${streamed.statusCode})',
    );
  }

  Future<Map<String, dynamic>?> addProduct({
    required String nameKu,
    required String categoryName,
    required int price,
    required int costPrice,
    int? discountPrice,
    String? descriptionKu,
    String? imageUrl,
    bool isAvailable = true,
  }) async {
    if (!await ensureAuthenticated()) return null;
    int? catId = categoryNameToId[categoryName];
    catId ??= await addCategory(categoryName);
    if (catId == null) return null;

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/vendor/products'),
            headers: _headers(),
            body: jsonEncode({
              'store_category_id': catId,
              'name_ku': nameKu,
              'price': price,
              'cost_price': costPrice,
              if (discountPrice != null) 'discount_price': discountPrice,
              if (descriptionKu != null && descriptionKu.isNotEmpty) 'description_ku': descriptionKu,
              if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
              'is_available': isAvailable,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<(bool, String)> updateProduct({
    required int productId,
    required String nameKu,
    required String categoryName,
    required int price,
    required int costPrice,
    int? discountPrice,
    String? descriptionKu,
    String? imageUrl,
    required bool isAvailable,
  }) async {
    if (!await ensureAuthenticated()) {
      return (false, 'پەیوەندی بە سێرڤەرەوە نییە');
    }
    final catId = categoryNameToId[categoryName];
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl/vendor/products/$productId'),
            headers: _headers(),
            body: jsonEncode({
              'store_category_id': catId,
              'name_ku': nameKu,
              'price': price,
              'cost_price': costPrice,
              'discount_price': discountPrice,
              'description_ku': descriptionKu,
              'image_url': imageUrl,
              'is_available': isAvailable,
            }),
          )
          .timeout(const Duration(seconds: 8));
      final body = res.body.isNotEmpty
          ? (regaJsonDecode(res.body) as Map<String, dynamic>)
          : <String, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] != false) {
        return (true, body['message']?.toString() ?? 'بەرهەم نوێکرایەوە');
      }
      return (false, body['message']?.toString() ?? 'نوێکردنەوەی بەرهەم سەرکەوتوو نەبوو');
    } catch (_) {
      return (false, 'نوێکردنەوەی بەرهەم سەرکەوتوو نەبوو');
    }
  }

  Future<(bool, String)> toggleProductAvailability(int productId) async {
    if (!await ensureAuthenticated()) {
      return (false, 'پەیوەندی بە سێرڤەرەوە نییە');
    }
    try {
      final res = await http
          .patch(Uri.parse('$baseUrl/vendor/products/$productId/availability'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (true, 'دۆخی بەرهەم نوێکرایەوە');
      }
      final body = res.body.isNotEmpty
          ? (regaJsonDecode(res.body) as Map<String, dynamic>)
          : <String, dynamic>{};
      return (false, body['message']?.toString() ?? 'گۆڕینی دۆخی بەرهەم سەرکەوتوو نەبوو');
    } catch (_) {
      return (false, 'گۆڕینی دۆخی بەرهەم سەرکەوتوو نەبوو');
    }
  }

  Future<(bool, String)> deleteProduct(int productId) async {
    if (!await ensureAuthenticated()) {
      return (false, 'پەیوەندی بە سێرڤەرەوە نییە');
    }
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/vendor/products/$productId'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (true, 'بەرهەم سڕایەوە');
      }
      final body = res.body.isNotEmpty
          ? (regaJsonDecode(res.body) as Map<String, dynamic>)
          : <String, dynamic>{};
      return (false, body['message']?.toString() ?? 'سڕینەوەی بەرهەم سەرکەوتوو نەبوو');
    } catch (_) {
      return (false, 'سڕینەوەی بەرهەم سەرکەوتوو نەبوو');
    }
  }


  /// Realized profit share for this store (admin owed from gross profit).
  Future<Map<String, dynamic>?> fetchRevenueAnalytics({String period = 'today'}) async {
    if (!await ensureAuthenticated()) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/vendor/analytics/revenue?period=$period'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }
}