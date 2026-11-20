import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../customer_api_service.dart';
import '../firebase_options.dart';
import 'customer_notification_sound.dart';

/// Payload shown on the 3s in-app banner / system tray.
class PushBannerPayload {
  const PushBannerPayload({
    required this.title,
    required this.body,
    this.data = const {},
  });

  final String title;
  final String body;
  final Map<String, dynamic> data;
}

/// Background isolate handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
}

/// Customer push: FCM lock-screen + 3s foreground overlay.
class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  static const _androidChannelId = 'rega_customer_push';
  static const _androidChannelName = 'REGA Notifications';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final ValueNotifier<PushBannerPayload?> banner = ValueNotifier<PushBannerPayload?>(null);

  bool _ready = false;
  bool get isReady => _ready;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  Timer? _bannerTimer;
  void Function(PushBannerPayload payload)? onNotificationOpened;
  void Function(PushBannerPayload payload)? onForegroundMessage;

  Future<void> init() async {
    if (kIsWeb || _ready) return;

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      debugPrint('REGA push: Firebase init failed: $e\n$st');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    // Do NOT request iOS permission here — wait for first login / sign-up.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          onNotificationOpened?.call(
            PushBannerPayload(
              title: map['title']?.toString() ?? '',
              body: map['body']?.toString() ?? '',
              data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
            ),
          );
        } catch (_) {}
      },
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Order and promo notifications from REGA',
        importance: Importance.high,
      ),
    );

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    _onMessageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    _tokenRefreshSub = messaging.onTokenRefresh.listen((token) {
      unawaited(CustomerApiService.instance.updateFcmToken(token));
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _onOpened(initial);
    }

    _ready = true;
    // Token sync only works after the user grants permission (first login).
  }

  /// Shows the native OS notification dialog (iOS / Android 13+).
  /// Call after first successful login or sign-up.
  Future<bool> requestPermissionAndSync() async {
    if (kIsWeb) return false;
    if (!_ready) await init();
    if (!_ready) return false;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        await syncTokenToBackend();
      }
      return granted;
    } catch (e) {
      debugPrint('REGA push: permission request failed: $e');
      return false;
    }
  }

  Future<void> syncTokenToBackend() async {
    if (!_ready || kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await CustomerApiService.instance.updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('REGA push: token sync failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final payload = _payloadFrom(message);
    showInAppBanner(payload);
    onForegroundMessage?.call(payload);
  }

  void _onOpened(RemoteMessage message) {
    final payload = _payloadFrom(message);
    onNotificationOpened?.call(payload);
  }

  PushBannerPayload _payloadFrom(RemoteMessage message) {
    final n = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final title = (n?.title ?? data['title'] ?? data['title_ku'] ?? 'REGA').toString();
    final body = (n?.body ?? data['body'] ?? data['body_ku'] ?? '').toString();
    return PushBannerPayload(title: title, body: body, data: data);
  }

  /// Show top overlay for exactly 3 seconds (app already open).
  void showInAppBanner(PushBannerPayload payload) {
    _bannerTimer?.cancel();
    banner.value = payload;
    unawaited(CustomerNotificationSound.instance.play());
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (banner.value == payload) {
        banner.value = null;
      }
    });
  }

  void dismissBanner() {
    _bannerTimer?.cancel();
    banner.value = null;
  }

  Future<void> showSystemNotification(PushBannerPayload payload) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _local.show(
      id,
      payload.title,
      payload.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Order and promo notifications from REGA',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          sound: const RawResourceAndroidNotificationSound('correct_answer_tone'),
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'correct_answer_tone.wav',
        ),
      ),
      payload: jsonEncode({
        'title': payload.title,
        'body': payload.body,
        'data': payload.data,
      }),
    );
  }

  void dispose() {
    _bannerTimer?.cancel();
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}

/// Top-of-screen 3s banner host. Place inside [MaterialApp.builder].
class PushBannerHost extends StatelessWidget {
  const PushBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<PushBannerPayload?>(
          valueListenable: PushNotifications.instance.banner,
          builder: (context, payload, _) {
            if (payload == null) return const SizedBox.shrink();
            final top = MediaQuery.paddingOf(context).top;
            return Positioned(
              top: top + 8,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    PushNotifications.instance.dismissBanner();
                    PushNotifications.instance.onNotificationOpened?.call(payload);
                  },
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets1/logo.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 36,
                                height: 36,
                                color: const Color(0xFFFAC800),
                                alignment: Alignment.center,
                                child: const Text(
                                  'R',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  payload.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    fontFamily: 'NotoKufiArabic',
                                  ),
                                ),
                                if (payload.body.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    payload.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.88),
                                      fontSize: 12.5,
                                      fontFamily: 'NotoKufiArabic',
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
