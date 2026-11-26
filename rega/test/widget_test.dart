import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:rega_app/blocked_account.dart';
import 'package:rega_app/direct_request_screen.dart';
import 'package:rega_app/live_order_tracker.dart';
import 'package:rega_app/main.dart';
import 'package:rega_app/onboarding/onboarding_notifier.dart';
import 'package:rega_app/onboarding/splash_onboarding.dart';
import 'package:rega_app/rega_colors.dart';
import 'package:rega_app/rega_i18n.dart';
import 'package:rega_app/rega_mobile.dart';
import 'package:rega_app/screens/kalar_map_screen.dart';
import 'package:rega_app/services/service_area.dart';
import 'package:rega_app/state/cart_notifier.dart';
import 'package:rega_app/state/locale_notifier.dart';
import 'package:rega_app/state/location_notifier.dart';
import 'package:rega_app/state/navigation_notifier.dart';
import 'package:rega_app/state/orders_notifier.dart';
import 'package:rega_app/state/session_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List _transparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final Uint8List _emptyJsonBytes = Uint8List.fromList(utf8.encode('{}'));

bool _isImageUri(Uri uri) {
  final p = uri.path.toLowerCase();
  final h = uri.host.toLowerCase();
  return p.endsWith('.png') ||
      p.endsWith('.jpg') ||
      p.endsWith('.jpeg') ||
      p.endsWith('.webp') ||
      h.contains('openstreetmap') ||
      h.contains('cartocdn') ||
      h.contains('mapbox') ||
      h.contains('unsplash') ||
      h.contains('picsum');
}

class _MockCustomerHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _MockHttpRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpRequest implements HttpClientRequest {
  _MockHttpRequest(this.uri);
  @override
  final Uri uri;
  @override
  Encoding encoding = utf8;
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async =>
      _MockHttpResponse(_isImageUri(uri) ? _transparentPng : _emptyJsonBytes);

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void removeAll(String name) {}
  @override
  List<String>? operator [](String name) => null;
  @override
  String? value(String name) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  _MockHttpResponse(this._bytes);
  final Uint8List _bytes;

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ViewportSpec {
  final String name;
  final Size size;
  const _ViewportSpec(this.name, this.size);
}

const List<_ViewportSpec> _allViewports = [
  _ViewportSpec('320x568', Size(320, 568)),
  _ViewportSpec('360x740', Size(360, 740)),
  _ViewportSpec('390x844', Size(390, 844)),
  _ViewportSpec('640x360', Size(640, 360)),
  _ViewportSpec('768x1024', Size(768, 1024)),
  _ViewportSpec('1024x768', Size(1024, 768)),
  _ViewportSpec('1280x720', Size(1280, 720)),
  _ViewportSpec('1920x1080', Size(1920, 1080)),
];

const List<_ViewportSpec> _coreViewports = [
  _ViewportSpec('320x568', Size(320, 568)),
  _ViewportSpec('360x740', Size(360, 740)),
  _ViewportSpec('640x360', Size(640, 360)),
  _ViewportSpec('768x1024', Size(768, 1024)),
  _ViewportSpec('1280x720', Size(1280, 720)),
  _ViewportSpec('1920x1080', Size(1920, 1080)),
];

const List<String> _locales = ['ku', 'ar', 'en'];

List<CartEntry> _sampleCartItems() => [
      CartEntry(
        product: ProductItem(
          id: 'p1',
          storeId: 's1',
          name: 'پیتزای پێپەرۆنی خێزانی گەورە',
          price: 12500,
          description: 'پەنیر و پێپەرۆنی تازە',
          imageUrl: '',
          category: 'خواردنگە',
          subCategory: 'پیتزا',
        ),
        quantity: 3,
        specialNotes: 'بەبێ بیبەری تیژ',
      ),
      CartEntry(
        product: ProductItem(
          id: 'p2',
          storeId: 's1',
          name: 'بەرگری دەبڵ چێدار لەگەڵ پەتاتە',
          price: 8500,
          description: 'گۆشتی تازە',
          imageUrl: '',
          category: 'خواردنگە',
          subCategory: 'بەرگر',
        ),
        quantity: 2,
      ),
    ];

List<OrderItem> _sampleOrders() => [
      OrderItem(
        id: '#10088',
        dbId: 10088,
        storeName: 'چێشتخانەی دیوانی کەلار',
        totalAmount: 42500,
        status: 'بەڕێوەیە',
        date: DateTime.now().subtract(const Duration(minutes: 15)),
        items: _sampleCartItems(),
        driverName: 'هێمن شۆفێر',
        driverPhone: '07705554433',
        deliveryPin: '4821',
      ),
      OrderItem(
        id: '#10089',
        dbId: 10089,
        storeName: 'داواکاری تایبەت (ڕاستەوخۆ)',
        totalAmount: 18000,
        status: 'گەیشتووە',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        items: const [],
        driverName: 'بەرهەم کاپتن',
        driverPhone: '07504445566',
        isDirectRequest: true,
        directRequestNotes: '٢ کیلۆ سێوی سوور و ١ کیلۆ مۆز لە بازاڕی کەلار',
      ),
    ];

Future<void> _pumpCustomerWithGuard(
  WidgetTester tester, {
  required Size viewport,
  required String lang,
  bool isDark = false,
  bool loggedIn = true,
  bool populateCartAndOrders = true,
  required Widget Function(
    LocaleNotifier locale,
    SessionNotifier session,
    CartNotifier cart,
    OrdersNotifier orders,
  ) builder,
  Future<void> Function()? afterMount,
}) async {
  RegaI18n.setLang(lang);
  RC.setDark(isDark);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;

  final capturedErrors = <String>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    capturedErrors.add(
      '${details.exceptionAsString()}\n${details.informationCollector?.call().map((d) => d.toDescription()).join('\n') ?? ''}',
    );
  };

  try {
    final locale = LocaleNotifier();
    await locale.setLanguage(lang);
    await locale.setDark(isDark);

    final onboarding = OnboardingNotifier();
    final session = SessionNotifier();
    if (loggedIn) {
      await session.signIn(
        UserProfile(
          name: 'ئاراس محەمەد کەلاری',
          email: 'aras@rega.krd',
          phone: '07701234567',
          address: 'گەڕەکی شەهیدان - کۆڵانی ١٤، کەلار',
        ),
      );
    }

    final cart = CartNotifier();
    final orders = OrdersNotifier();
    if (populateCartAndOrders) {
      for (final item in _sampleCartItems()) {
        cart.addProduct(item.product, quantity: item.quantity, notes: item.specialNotes);
      }
      orders.replaceAll(_sampleOrders());
    }

    final location = LocationNotifier();
    final nav = NavigationNotifier();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: locale),
          ChangeNotifierProvider.value(value: onboarding),
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: location),
          ChangeNotifierProvider.value(value: orders),
          ChangeNotifierProvider.value(value: nav),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            fontFamily: 'NotoKufiArabic',
          ),
          builder: (context, child) => RegaResponsive.appBuilder(
            context,
            child,
            direction: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
          ),
          home: builder(locale, session, cart, orders),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    if (afterMount != null) {
      await afterMount();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  } finally {
    FlutterError.onError = originalOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  expect(
    capturedErrors,
    isEmpty,
    reason:
        '[rega $lang dark=$isDark @ ${viewport.width.toInt()}x${viewport.height.toInt()}] ${capturedErrors.join('\n---\n')}',
  );
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockCustomerHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kalarNeighborhoods
      ..clear()
      ..addAll(const [
        Neighborhood(
          id: '1',
          name: 'گەڕەکی شەهیدان',
          nameEn: 'Shahidan',
          deliveryFee: 2000,
          lat: 34.6836,
          lng: 45.3189,
        ),
        Neighborhood(
          id: '2',
          name: 'گەڕەکی فەرمانبەران',
          nameEn: 'Farmanbaran',
          deliveryFee: 2500,
          lat: 34.6912,
          lng: 45.3264,
        ),
      ]);
  });

  tearDown(() {
    RegaI18n.setLang('ku');
    RC.setDark(false);
  });

  testWidgets(
    'rega SplashOnboardingFlow renders cleanly across all 8 viewports in RTL & LTR',
    (tester) async {
      for (final lang in _locales) {
        for (final vp in _allViewports) {
          await _pumpCustomerWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            loggedIn: false,
            populateCartAndOrders: false,
            builder: (_, __, ___, ____) => const SplashOnboardingFlow(),
            afterMount: () async {
              // Advance splash timer (2400ms) -> language step -> location step
              await tester.pump(const Duration(milliseconds: 2500));
              await tester.pump(const Duration(milliseconds: 300));
            },
          );
        }
      }
    },
  );

  testWidgets(
    'rega Auth view (Login, Register & Renewal modes) renders without overflow across all 8 viewports',
    (tester) async {
      for (final lang in _locales) {
        for (final isDark in [false, true]) {
          for (final vp in _allViewports) {
            await _pumpCustomerWithGuard(
              tester,
              viewport: vp.size,
              lang: lang,
              isDark: isDark,
              loggedIn: false,
              populateCartAndOrders: false,
              builder: (locale, _, __, ___) => MainScreen(
                currentLang: lang,
                onLanguageChange: locale.setLanguage,
                initialTabIndex: 4,
                forceAuthOnly: true,
              ),
            );
          }
        }
      }
    },
  );

  testWidgets(
    'rega MainScreen all 5 tabs (Home, Offers, Cart populated & empty, Orders populated & empty, Profile) across all viewports & themes',
    (tester) async {
      for (final lang in _locales) {
        for (final isDark in [false, true]) {
          for (final vp in _coreViewports) {
            for (var tabIndex = 0; tabIndex < 5; tabIndex++) {
              await _pumpCustomerWithGuard(
                tester,
                viewport: vp.size,
                lang: lang,
                isDark: isDark,
                loggedIn: true,
                populateCartAndOrders: true,
                builder: (locale, _, __, ___) => MainScreen(
                  currentLang: lang,
                  onLanguageChange: locale.setLanguage,
                  initialTabIndex: tabIndex,
                ),
              );
            }
          }
        }
      }

      // Also test empty states for Cart (tab 2) and Orders (tab 3) on compact and desktop viewports
      for (final vp in const [
        _ViewportSpec('320x568', Size(320, 568)),
        _ViewportSpec('1280x720', Size(1280, 720)),
      ]) {
        for (final tabIndex in [2, 3]) {
          await _pumpCustomerWithGuard(
            tester,
            viewport: vp.size,
            lang: 'ku',
            loggedIn: true,
            populateCartAndOrders: false,
            builder: (locale, _, __, ___) => MainScreen(
              currentLang: 'ku',
              onLanguageChange: locale.setLanguage,
              initialTabIndex: tabIndex,
            ),
          );
        }
      }
    },
  );

  testWidgets(
    'rega DirectRequestScreen, KalarMapScreen, CustomerLiveOrderTrackerScreen, ServiceAreaBlockedScreen & BlockedAccountContacts across viewports',
    (tester) async {
      final sampleOrder = _sampleOrders().first;
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          await _pumpCustomerWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: (_, __, ___, ____) => const DirectRequestScreen(
              initialPhone: '07701234567',
              initialAddress: 'گەڕەکی شەهیدان',
              deliveryLat: 34.6836,
              deliveryLng: 45.3189,
            ),
          );

          await _pumpCustomerWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: (_, __, ___, ____) => const KalarMapScreen(),
          );

          await _pumpCustomerWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: (_, __, ___, ____) => CustomerLiveOrderTrackerScreen(
              orderCode: sampleOrder.id,
              storeName: sampleOrder.storeName,
              customerAddress: sampleOrder.address,
              driverName: sampleOrder.driverName,
              driverPhone: sampleOrder.driverPhone,
              deliveryPin: sampleOrder.deliveryPin,
              totalAmount: sampleOrder.totalAmount,
              initialStatus: 'on_the_way',
            ),
          );

          await _pumpCustomerWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: (_, __, ___, ____) =>
                ServiceAreaBlockedScreen(onRetry: () async {}),
          );

          await _pumpCustomerWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: (_, __, ___, ____) => Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => BlockedAccountContacts.show(
                      ctx,
                      AccountBlockedException.fromBody(const {}),
                    ),
                    child: const Text('open-blocked'),
                  ),
                ),
              ),
            ),
            afterMount: () async {
              await tester.tap(find.text('open-blocked'));
              await tester.pump(const Duration(milliseconds: 220));
            },
          );
        }
      }
    },
  );
}
