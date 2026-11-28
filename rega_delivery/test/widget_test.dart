import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/blocked_account.dart';
import 'package:delivery_app/live_captain_map.dart';
import 'package:delivery_app/main.dart';
import 'package:delivery_app/rega_colors.dart';
import 'package:delivery_app/rega_i18n.dart';
import 'package:delivery_app/rega_mobile.dart';
import 'package:delivery_app/service_area.dart';
import 'package:delivery_app/state/driver_nav_notifier.dart';
import 'package:delivery_app/state/driver_session_notifier.dart';
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

class _MockDriverHttpOverrides extends HttpOverrides {
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

OrderModel _sampleActiveOrder(OrderStatus status) => OrderModel(
      id: '10056',
      dbId: 10056,
      orderNumber: 'RA-10056',
      status: status,
      vendorStatus: status.index >= OrderStatus.pickedUp.index ? 'completed' : 'ready',
      merchantName: 'چێشتخانەی دیوانی کەلار',
      merchantAddress: 'بازاڕی کەلار - شەقامی سەرەکی',
      merchantPhone: '07701112233',
      customerName: 'ئاراس محەمەد کەلاری',
      customerAddress: 'گەڕەکی شەهیدان - کۆڵانی ١٤، تەنیشت قوتابخانە',
      customerPhone: '07709998877',
      items: const [
        OrderItem(id: '1', name: 'پیتزای پێپەرۆنی گەورە', quantity: 2, price: 9500),
        OrderItem(id: '2', name: 'بەرگری دەبڵ چێدار', quantity: 1, price: 7500),
      ],
      subtotal: 26500,
      deliveryFee: 2500,
      tip: 1000,
      waitingBonus: 500,
      totalAmount: 30000,
      handoverPin: '7392',
      deliveryPin: '4821',
      customerNotes: 'تکایە زەنگی دەرگا لێمەدە، پەیوەندی بکە',
    );

Future<void> _pumpDriverWithGuard(
  WidgetTester tester, {
  required Size viewport,
  required String lang,
  bool isDark = false,
  required Widget Function() builder,
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
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DriverSessionNotifier()),
          ChangeNotifierProvider(create: (_) => DriverNavNotifier()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // Match production: ku/ar use Locale('ar') + flutter_localizations.
          locale: lang == 'en' ? const Locale('en') : const Locale('ar'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
          home: builder(),
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
    await tester.pump(const Duration(milliseconds: 150));
  } finally {
    FlutterError.onError = originalOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  expect(
    capturedErrors,
    isEmpty,
    reason:
        '[rega_delivery $lang dark=$isDark @ ${viewport.width.toInt()}x${viewport.height.toInt()}] ${capturedErrors.join('\n---\n')}',
  );
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockDriverHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    RegaI18n.setLang('ku');
    RC.setDark(false);
  });

  testWidgets(
    'rega_delivery AuthScreen renders without overflow across all 8 viewports, 3 languages & light/dark themes',
    (tester) async {
      for (final lang in _locales) {
        for (final isDark in [false, true]) {
          for (final vp in _allViewports) {
            await _pumpDriverWithGuard(
              tester,
              viewport: vp.size,
              lang: lang,
              isDark: isDark,
              builder: () => AuthScreen(
                currentLocale: lang,
                onLogin: (_) async {},
              ),
            );
          }
        }
      }
    },
  );

  testWidgets(
    'rega_delivery DriverMainScreen all 4 tabs (Map, Orders List, Earnings, Profile) across all viewports, languages & themes',
    (tester) async {
      for (final lang in _locales) {
        for (final isDark in [false, true]) {
          for (final vp in _coreViewports) {
            for (var tabIndex = 0; tabIndex < 4; tabIndex++) {
              await _pumpDriverWithGuard(
                tester,
                viewport: vp.size,
                lang: lang,
                isDark: isDark,
                builder: () => DriverMainScreen(
                  currentLocale: lang,
                  isDark: isDark,
                  onLanguageChange: (_) {},
                  onThemeChanged: (_) {},
                  onLogout: () {},
                  driverPhone: '07705554433',
                  initialTabIndex: tabIndex,
                ),
                afterMount: () async {
                  // On Earnings tab (2), cycle through Today / Week / Month period pills
                  if (tabIndex == 2) {
                    for (final label in ['ئەمڕۆ', 'ئەم هەفتەیە', 'ئەم مانگە']) {
                      final f = find.text(tx(label));
                      if (f.evaluate().isNotEmpty) {
                        await tester.tap(f.first);
                        await tester.pump(const Duration(milliseconds: 150));
                      }
                    }
                  }
                },
              );
            }
          }
        }
      }
    },
  );

  testWidgets(
    'rega_delivery ActiveOrderCard across all 7 OrderStatus stages (including expanded items accordion) on all viewports',
    (tester) async {
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          for (final status in OrderStatus.values) {
            await _pumpDriverWithGuard(
              tester,
              viewport: vp.size,
              lang: lang,
              builder: () => Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: ActiveOrderCard(
                    order: _sampleActiveOrder(status),
                    locale: lang,
                    onUpdateStatus: (_) {},
                    onRequestPinVerification: () {},
                    onRequestCancel: () {},
                    onClose: () {},
                  ),
                ),
              ),
              afterMount: () async {
                final expandArrow = find.byIcon(Icons.keyboard_arrow_down);
                if (expandArrow.evaluate().isNotEmpty) {
                  await tester.ensureVisible(expandArrow.first);
                  await tester.tap(expandArrow.first, warnIfMissed: false);
                  await tester.pump(const Duration(milliseconds: 200));
                }
              },
            );
          }
        }
      }
    },
  );

  testWidgets(
    'rega_delivery CaptainLiveMapWidget, ServiceAreaBlockedScreen & BlockedAccountContacts render cleanly across viewports',
    (tester) async {
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          await _pumpDriverWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => Scaffold(
              body: CaptainLiveMapWidget(
                orderNumber: '#10056',
                stage: CaptainRouteStage.onTheWay,
                merchantName: 'چێشتخانەی دیوان',
                merchantAddress: 'بازاڕی کەلار',
                customerName: 'ئاراس محەمەد',
                customerAddress: 'گەڕەکی شەهیدان',
                deliveryPin: '4821',
                locale: lang,
                onStageAutoReached: (_) {},
                onArrivedPromptPin: () {},
              ),
            ),
          );

          await _pumpDriverWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => ServiceAreaBlockedScreen(onRetry: () async {}),
          );

          await _pumpDriverWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => Scaffold(
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
