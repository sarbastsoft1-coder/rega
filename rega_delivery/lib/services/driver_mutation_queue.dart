import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../driver_api_service.dart';

/// Durable queue for non-sensitive driver mutations under flaky networks.
/// PIN-bearing complete-delivery is never persisted here.
class DriverMutationQueue extends ChangeNotifier {
  DriverMutationQueue._();
  static final DriverMutationQueue instance = DriverMutationQueue._();

  static const String _prefsKey = 'rega_driver_mutation_queue_v1';
  static const _uuid = Uuid();

  final List<_QueuedMutation> _items = [];
  bool _loaded = false;
  bool _draining = false;
  Timer? _retryTimer;

  int get pendingCount => _items.length;
  bool get hasPending => _items.isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final row in list) {
        if (row is! Map) continue;
        final m = _QueuedMutation.fromJson(Map<String, dynamic>.from(row));
        if (m != null) _items.add(m);
      }
      if (_items.isNotEmpty) notifyListeners();
    } catch (_) {}
  }

  Future<String> enqueue({
    required String type,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    await load();
    final key = (idempotencyKey != null && idempotencyKey.isNotEmpty)
        ? idempotencyKey
        : _uuid.v4();
    // Deduplicate by type+logical identity when same idempotency key already queued.
    _items.removeWhere((e) => e.idempotencyKey == key);
    _items.add(_QueuedMutation(
      idempotencyKey: key,
      type: type,
      payload: payload,
      attempts: 0,
      nextAttemptAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    await _persist();
    notifyListeners();
    scheduleDrain(delay: const Duration(milliseconds: 400));
    return key;
  }

  void scheduleDrain({Duration delay = Duration.zero}) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      unawaited(drain());
    });
  }

  Future<void> drain() async {
    if (_draining) return;
    await load();
    if (_items.isEmpty) return;
    if (!DriverNetworkGate.isOnline) {
      scheduleDrain(delay: const Duration(seconds: 3));
      return;
    }

    _draining = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ready = _items.where((e) => e.nextAttemptAtMs <= now).toList();
      for (final item in ready) {
        final ok = await _dispatch(item);
        if (ok) {
          _items.removeWhere((e) => e.idempotencyKey == item.idempotencyKey);
          await _persist();
          notifyListeners();
          continue;
        }
        item.attempts += 1;
        if (item.attempts >= 12) {
          _items.removeWhere((e) => e.idempotencyKey == item.idempotencyKey);
          await _persist();
          notifyListeners();
          continue;
        }
        final backoffSec = (1 << (item.attempts.clamp(0, 5))).clamp(1, 60);
        item.nextAttemptAtMs =
            DateTime.now().millisecondsSinceEpoch + backoffSec * 1000;
        await _persist();
        notifyListeners();
        // Stop this pass on first network failure so we don't stampede.
        break;
      }
    } finally {
      _draining = false;
    }

    if (_items.isNotEmpty) {
      final next = _items
          .map((e) => e.nextAttemptAtMs)
          .reduce((a, b) => a < b ? a : b);
      final waitMs =
          (next - DateTime.now().millisecondsSinceEpoch).clamp(500, 60000);
      scheduleDrain(delay: Duration(milliseconds: waitMs));
    }
  }

  Future<bool> _dispatch(_QueuedMutation item) async {
    try {
      switch (item.type) {
        case 'online_status':
          final isOnline = item.payload['is_online'] == true;
          final lat = (item.payload['lat'] as num?)?.toDouble();
          final lng = (item.payload['lng'] as num?)?.toDouble();
          final data = await DriverApiService.instance.updateOnlineStatus(
            isOnline,
            lat: lat,
            lng: lng,
            idempotencyKey: item.idempotencyKey,
          );
          return data != null;
        case 'location_update':
          final lat = (item.payload['lat'] as num?)?.toDouble();
          final lng = (item.payload['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return true;
          final heading = (item.payload['heading'] as num?)?.toDouble();
          final speed = (item.payload['speed_kmh'] as num?)?.toDouble();
          return DriverApiService.instance.updateLocation(
            lat,
            lng,
            heading: heading,
            speedKmh: speed,
          );
        case 'order_status':
          final orderId = item.payload['order_id'];
          final status = item.payload['driver_status']?.toString();
          if (orderId is! int || status == null || status.isEmpty) return true;
          final data = await DriverApiService.instance.advanceOrderStatus(
            orderId,
            status,
            idempotencyKey: item.idempotencyKey,
          );
          return data != null;
        case 'cancel_request':
          final orderId = item.payload['order_id'];
          final reason = item.payload['reason']?.toString() ?? '';
          if (orderId is! int) return true;
          return DriverApiService.instance.requestCancellation(
            orderId,
            reason,
            idempotencyKey: item.idempotencyKey,
          );
        case 'waiting_bonus':
          final orderId = item.payload['order_id'];
          final waited = (item.payload['waited_minutes'] as num?)?.toInt() ?? 16;
          if (orderId is! int) return true;
          final (ok, _, _) = await DriverApiService.instance.claimWaitingBonus(
            orderId,
            waitedMinutes: waited,
            idempotencyKey: item.idempotencyKey,
          );
          return ok;
        default:
          return true; // drop unknown
      }
    } on DriverNetworkException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}

/// Thin gate so the queue does not import connectivity_plus directly in tests.
class DriverNetworkGate {
  static bool Function() check = () => true;
  static bool get isOnline => check();
}

class _QueuedMutation {
  _QueuedMutation({
    required this.idempotencyKey,
    required this.type,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAtMs,
  });

  final String idempotencyKey;
  final String type;
  final Map<String, dynamic> payload;
  int attempts;
  int nextAttemptAtMs;

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'type': type,
        'payload': payload,
        'attempts': attempts,
        'next_attempt_at_ms': nextAttemptAtMs,
      };

  static _QueuedMutation? fromJson(Map<String, dynamic> json) {
    final key = json['idempotency_key']?.toString();
    final type = json['type']?.toString();
    final payloadRaw = json['payload'];
    if (key == null || key.isEmpty || type == null || type.isEmpty) return null;
    final payload = payloadRaw is Map
        ? Map<String, dynamic>.from(payloadRaw)
        : <String, dynamic>{};
    return _QueuedMutation(
      idempotencyKey: key,
      type: type,
      payload: payload,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAtMs: (json['next_attempt_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}
