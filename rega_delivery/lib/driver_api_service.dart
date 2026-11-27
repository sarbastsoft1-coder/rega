import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'blocked_account.dart';
import 'rega_i18n.dart';
import 'rega_mobile.dart';

/// Thrown when a mutation cannot reach the server (timeout / socket / offline).
class DriverNetworkException implements Exception {
  DriverNetworkException([this.message = 'network']);
  final String message;

  @override
  String toString() => 'DriverNetworkException($message)';
}

class DriverApiService {
  DriverApiService._();
  static final DriverApiService instance = DriverApiService._();

  static String get baseUrl => RegaApiHost.apiV1;
  static const String _tokenKey = 'rega_driver_sanctum_token';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
  );

  String? _token;
  bool _handlingUnauthorized = false;

  /// Fired once when a protected API returns 401 (token expired/revoked).
  VoidCallback? onUnauthorized;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Map<String, String> _headers({String? idempotencyKey}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'Idempotency-Key': idempotencyKey,
      };

  /// Auth token for authenticated live-telemetry writes.
  Map<String, String> authHeaders() => _headers();

  bool _isNetworkFailure(Object e) {
    if (e is TimeoutException ||
        e is http.ClientException ||
        e is DriverNetworkException) {
      return true;
    }
    // Avoid dart:io so web builds stay clean.
    return e.runtimeType.toString().contains('SocketException');
  }

  Future<void> initToken() async {
    try {
      _token = await _secure.read(key: _tokenKey);
      if (_token != null && _token!.isNotEmpty) return;

      // One-time migrate from legacy plaintext SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_tokenKey);
      if (legacy != null && legacy.isNotEmpty) {
        _token = legacy;
        await _secure.write(key: _tokenKey, value: legacy);
        await prefs.remove(_tokenKey);
      }
    } catch (_) {}
  }

  Future<void> _persistToken(String token) async {
    _token = token;
    try {
      await _secure.write(key: _tokenKey, value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<void> _clearLocalToken() async {
    _token = null;
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<bool> _rejectIfUnauthorized(http.Response res) async {
    if (res.statusCode != 401) return false;
    if (_handlingUnauthorized) return true;
    _handlingUnauthorized = true;
    try {
      await _clearLocalToken();
      onUnauthorized?.call();
    } finally {
      _handlingUnauthorized = false;
    }
    return true;
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
              'role_filter': 'driver',
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 403) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        if (body['code']?.toString() == 'account_blocked') {
          await logout();
          throw AccountBlockedException.fromBody(body);
        }
      }

      if (res.statusCode == 429) {
        return false;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        final tok = body['data']?['token']?.toString();
        if (tok != null && tok.isNotEmpty) {
          await _persistToken(tok);
          return true;
        }
      }
    } on AccountBlockedException {
      rethrow;
    } catch (_) {}
    return _token != null && _token!.isNotEmpty;
  }

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
      if (await _rejectIfUnauthorized(res)) return false;
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        await http
            .post(Uri.parse('$baseUrl/auth/logout'), headers: _headers())
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
    await _clearLocalToken();
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/driver/profile'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (await _rejectIfUnauthorized(res)) return null;
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'];
        if (data is! Map) return null;
        final out = Map<String, dynamic>.from(data);
        if (body['location_trusted'] != null) {
          out['location_trusted'] = body['location_trusted'];
        }
        if (body['dispatch_eligible'] != null) {
          out['dispatch_eligible'] = body['dispatch_eligible'];
        }
        return out;
      }
    } catch (_) {}
    return null;
  }

  /// Last human-readable API error from [updateOnlineStatus] / [claimOrder].
  String? lastMutationError;

  Future<Map<String, dynamic>?> updateOnlineStatus(
    bool isOnline, {
    double? lat,
    double? lng,
    String? idempotencyKey,
  }) async {
    lastMutationError = null;
    try {
      await initToken();
      if (_token == null || _token!.isEmpty) {
        lastMutationError = 'session_expired';
        return null;
      }

      final res = await http
          .patch(
            Uri.parse('$baseUrl/driver/status'),
            headers: _headers(idempotencyKey: idempotencyKey),
            body: jsonEncode({
              'is_online': isOnline,
              if (lat != null) 'lat': lat,
              if (lng != null) 'lng': lng,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (await _rejectIfUnauthorized(res)) {
        lastMutationError = 'session_expired';
        return null;
      }
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = body['data'];
        Map<String, dynamic> out;
        if (data is Map<String, dynamic>) {
          out = data;
        } else if (data is Map) {
          out = Map<String, dynamic>.from(data);
        } else {
          out = <String, dynamic>{'is_online': isOnline};
        }
        if (body['location_trusted'] != null) {
          out['location_trusted'] = body['location_trusted'];
        }
        if (body['dispatch_eligible'] != null) {
          out['dispatch_eligible'] = body['dispatch_eligible'];
        }
        if (body['warning'] != null) {
          out['warning'] = body['warning'];
        }
        return out;
      }
      lastMutationError = body['message']?.toString() ?? 'status_update_failed';
      return null;
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      lastMutationError = 'status_update_failed';
      return null;
    }
  }

  /// Returns true when the server accepted the ping.
  /// Throws [DriverNetworkException] on timeout / offline so callers can queue.
  Future<bool> updateLocation(
    double lat,
    double lng, {
    double? heading,
    double? speedKmh,
  }) async {
    try {
      await initToken();
      if (_token == null || _token!.isEmpty) return false;
      final res = await http
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
      if (await _rejectIfUnauthorized(res)) return false;
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchActiveOrder() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/driver/orders/active'), headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (await _rejectIfUnauthorized(res)) return null;
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] is Map
            ? Map<String, dynamic>.from(body['data'] as Map)
            : null;
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
      if (await _rejectIfUnauthorized(res)) return [];
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> fetchAvailableOrders() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/driver/orders/available'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));
      if (await _rejectIfUnauthorized(res)) return [];
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> claimOrder(
    int orderId, {
    String? idempotencyKey,
  }) async {
    lastMutationError = null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/claim'),
            headers: _headers(idempotencyKey: idempotencyKey),
            body: jsonEncode(const <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 8));
      if (await _rejectIfUnauthorized(res)) {
        lastMutationError = 'session_expired';
        return null;
      }
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body['success'] == true) {
        final data = body['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return <String, dynamic>{'id': orderId};
      }
      lastMutationError = body['message']?.toString() ?? 'claim_failed';
      return null;
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      lastMutationError = 'claim_failed';
      return null;
    }
  }

  /// Decline / timeout the 30s accept window. May reassign to another driver.
  Future<(bool, String?)> declineOrderOffer(
    int orderId, {
    required String reason,
    bool timedOut = false,
    String? idempotencyKey,
  }) async {
    lastMutationError = null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/decline-offer'),
            headers: _headers(idempotencyKey: idempotencyKey),
            body: jsonEncode({
              'reason': reason,
              'timed_out': timedOut,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (await _rejectIfUnauthorized(res)) {
        lastMutationError = 'session_expired';
        return (false, 'session_expired');
      }
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body['success'] == true) {
        return (true, body['message']?.toString());
      }
      final msg = body['message']?.toString() ?? 'decline_failed';
      lastMutationError = msg;
      return (false, msg);
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      lastMutationError = 'decline_failed';
      return (false, 'decline_failed');
    }
  }

  Future<Map<String, dynamic>?> advanceOrderStatus(
    int orderId,
    String driverStatus, {
    String? idempotencyKey,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/driver/orders/$orderId/status'),
            headers: _headers(idempotencyKey: idempotencyKey),
            body: jsonEncode({'driver_status': driverStatus}),
          )
          .timeout(const Duration(seconds: 5));
      if (await _rejectIfUnauthorized(res)) return null;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      return null;
    }
  }

  Future<(bool, String?)> completeDelivery(
    int orderId, {
    String? deliveryPin,
    String? idempotencyKey,
  }) async {
    try {
      final pin = deliveryPin?.trim() ?? '';
      if (pin.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(pin)) {
        return (false, 'PIN must be 4 digits');
      }
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/verify-delivery'),
            headers: _headers(idempotencyKey: idempotencyKey),
            body: jsonEncode({
              if (pin.isNotEmpty) 'delivery_pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (await _rejectIfUnauthorized(res)) {
        return (false, 'Session expired — please log in again');
      }
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body['success'] == true) {
        return (true, body['message']?.toString());
      }
      return (false, body['message']?.toString());
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      return (false, null);
    }
  }

  Future<(bool, String?, Map<String, dynamic>?)> claimWaitingBonus(
    int orderId, {
    int waitedMinutes = 16,
    String? idempotencyKey,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/waiting-bonus'),
            headers: _headers(idempotencyKey: idempotencyKey),
            body: jsonEncode({'waited_minutes': waitedMinutes}),
          )
          .timeout(const Duration(seconds: 5));
      if (await _rejectIfUnauthorized(res)) {
        return (false, 'Session expired — please log in again', null);
      }
      final body = regaJsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : null;
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body['success'] == true) {
        return (true, body['message']?.toString(), data);
      }
      return (false, body['message']?.toString(), data);
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      return (false, null, null);
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
      if (await _rejectIfUnauthorized(res)) return null;
      if (res.statusCode == 200) {
        final body = regaJsonDecode(res.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> requestCancellation(
    int orderId,
    String reason, {
    String? idempotencyKey,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/driver/orders/$orderId/cancel-request'),
            headers: _headers(idempotencyKey: idempotencyKey),
            body: jsonEncode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 5));
      if (await _rejectIfUnauthorized(res)) return false;
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      if (_isNetworkFailure(e)) throw DriverNetworkException();
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchSupportContacts() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/public/support-contacts'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return const {};
  }
}
