import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rega_vendor/assigned_driver_map.dart';
import 'package:rega_vendor/blocked_account.dart';
import 'package:rega_vendor/main.dart';
import 'package:rega_vendor/rega_colors.dart';
import 'package:rega_vendor/rega_i18n.dart';
import 'package:rega_vendor/rega_mobile.dart';
import 'package:rega_vendor/service_area.dart';
import 'package:rega_vendor/state/vendor_nav_notifier.dart';
import 'package:rega_vendor/state/vendor_session_notifier.dart';
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

class _MockVendorHttpOverrides extends HttpOverrides {
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

List<Order> _buildSampleOrders() {
  final now = DateTime.now();
  return [
    Order(
      id: '#10041',
      dbId: 10041,
      items: ['2x پیتزای پێپەرۆنی گەورە', '1x کۆلای سارد'],
      total: 18500,
      status: OrderStatus.pending,
      timestamp: now.subtract(const Duration(minutes: 4)),
      customerName: 'ئاراس محەمەد کەلاری',
      customerPhone: '07701234567',
      deliveryAddress: 'گەڕەکی شەهیدان - کۆڵانی ١٤',
      handoverPin: '4821',
      customerNotes: 'تکایە بە گەرمی بیهێنن و سۆسی زیادە دابنێن',
    ),
    Order(
      id: '#10042',
      dbId: 10042,
      items: ['1x بەرگری دەبڵ چێدار', '1x پەتاتەی سورکراوە'],
      total: 12000,
      status: OrderStatus.accepted,
      timestamp: now.subtract(const Duration(minutes: 10)),
      acceptedAt: now.subtract(const Duration(minutes: 8)),
      customerName: 'سارا ئەحمەد',
      customerPhone: '07501112233',
      deliveryAddress: 'گەڕەکی فەرمانبەران - نزیک قوتابخانە',
      handoverPin: '7190',
    ),
    Order(
      id: '#10043',
      dbId: 10043,
      items: ['3x شاورمەی مریشک بە پەنیر'],
      total: 15000,
      status: OrderStatus.preparing,
      timestamp: now.subtract(const Duration(minutes: 18)),
      acceptedAt: now.subtract(const Duration(minutes: 15)),
      customerName: 'کاروان عەلی',
      customerPhone: '07719998877',
      deliveryAddress: 'گەڕەکی ڕاپەڕین - شەقامی سەرەکی',
      handoverPin: '5309',
      driverName: 'هێمن شۆفێر',
      driverPhone: '07705554433',
      driverVehicle: 'ماتۆڕسکلی هۆندا',
      driverLat: 34.6845,
      driverLng: 45.3201,
      storeLat: 34.6836,
      storeLng: 45.3189,
      customerLat: 34.6912,
      customerLng: 45.3264,
    ),
    Order(
      id: '#10044',
      dbId: 10044,
      items: ['2x کەبابی برژاو', '2x دۆی خۆماڵی'],
      total: 24000,
      status: OrderStatus.ready,
      timestamp: now.subtract(const Duration(minutes: 25)),
      acceptedAt: now.subtract(const Duration(minutes: 22)),
      customerName: 'دڵشاد حەسەن',
      customerPhone: '07703332211',
      deliveryAddress: 'گەڕەکی سیروان - تەنیشت مزگەوت',
      handoverPin: '8812',
      driverName: 'بەرهەم کاپتن',
      driverPhone: '07504445566',
      driverVehicle: 'ماتۆڕسکلی یاماها',
    ),
    Order(
      id: '#10045',
      dbId: 10045,
      items: ['1x پیتزای مێکسیکی', '2x پیپسی'],
      total: 16500,
      status: OrderStatus.completed,
      timestamp: now.subtract(const Duration(hours: 1)),
      acceptedAt: now.subtract(const Duration(minutes: 55)),
      customerName: 'هەژار کەریم',
      customerPhone: '07708887766',
      deliveryAddress: 'ناوەندی بازاڕی کەلار',
      handoverPin: '9914',
      driverName: 'هێمن شۆفێر',
      driverPhone: '07705554433',
    ),
  ];
}

List<Product> _buildSampleProducts() => [
      Product(
        id: '1',
        name: 'پیتزای پێپەرۆنی تایبەت',
        category: 'پیتزا',
        price: 10000,
        costPrice: 6500,
        discountPrice: 8500,
        isAvailable: true,
        description: 'پەنیر و پێپەرۆنی تازە بە سۆسی ئیتاڵی',
      ),
      Product(
        id: '2',
        name: 'بەرگری دەبڵ چێدار',
        category: 'بەرگر',
        price: 7500,
        costPrice: 4500,
        isAvailable: true,
        description: 'گۆشتی گوێرەکەی تازە لەگەڵ پەنیری چێدار',
      ),
      Product(
        id: '3',
        name: 'کۆلای سارد ٣٣٠مل',
        category: 'خواردنەوەکان',
        price: 1000,
        costPrice: 600,
        isAvailable: false,
      ),
    ];

Future<void> _pumpVendorWithGuard(
  WidgetTester tester, {
  required Size viewport,
  required String lang,
  bool isDark = false,
  required Widget Function() builder,
  Future<void> Function()? afterMount,
}) async {
  Trans.lang.value = lang;
  Trans.dark.value = isDark;
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
          ChangeNotifierProvider(create: (_) => VendorSessionNotifier()),
          ChangeNotifierProvider(create: (_) => VendorNavNotifier()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // Match production: ku/ar use Locale('ar') + flutter_localizations.
          // Without delegates, TextFields crash as gray ErrorWidgets.
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
            fontFamily: kAppFontFamily,
          ),
          builder: (context, child) => RegaResponsive.appBuilder(
            context,
            child,
            direction: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
          ),
          home: Scaffold(body: builder()),
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
        '[rega_froshyar $lang dark=$isDark @ ${viewport.width.toInt()}x${viewport.height.toInt()}] ${capturedErrors.join('\n---\n')}',
  );
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockVendorHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Trans.lang.value = 'ku';
    Trans.dark.value = false;
    RegaI18n.setLang('ku');
    RC.setDark(false);
  });

  testWidgets(
    'rega_froshyar LoginScreen renders without overflow across all 8 viewports, 3 languages & light/dark themes',
    (tester) async {
      for (final lang in _locales) {
        for (final isDark in [false, true]) {
          for (final vp in _allViewports) {
            await _pumpVendorWithGuard(
              tester,
              viewport: vp.size,
              lang: lang,
              isDark: isDark,
              builder: () => const LoginScreen(),
              afterMount: () async {
                expect(
                  find.byType(ErrorWidget),
                  findsNothing,
                  reason:
                      'Login TextFields must not crash as gray ErrorWidgets (lang=$lang)',
                );
                expect(find.byType(TextField), findsWidgets);
              },
            );
          }
        }
      }
    },
  );

  testWidgets(
    'rega_froshyar MainNavigationScreen shell (all 4 tabs: Settings, Revenue, Menu, Orders) renders across all viewports',
    (tester) async {
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          for (var tabIndex = 0; tabIndex < 4; tabIndex++) {
            await _pumpVendorWithGuard(
              tester,
              viewport: vp.size,
              lang: lang,
              builder: () => MainNavigationScreen(initialIndex: tabIndex),
            );
          }
        }
      }
    },
  );

  testWidgets(
    'rega_froshyar OrdersScreen across all 5 status tabs (pending, accepted, preparing, ready, completed) & dialogs',
    (tester) async {
      final sampleOrders = _buildSampleOrders();
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          await _pumpVendorWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => OrdersScreen(
              orders: sampleOrders,
              onUpdateStatus: (id, status, {reason}) {},
              onOrdersChanged: () {},
              onSimulateNewOrder: () {},
              onDeleteOrder: (_) {},
              onClearCompletedOrders: () {},
            ),
            afterMount: () async {
              // Cycle through all 5 status filter tabs
              final tabLabels = [
                'داواکاری نوێ',
                'قبوڵکراو',
                'لە ئامادەکردندایە',
                'ئامادەیە بۆ شۆفێر',
                'تەواوبوو',
              ];
              for (final label in tabLabels) {
                final finder = find.textContaining(tx(label));
                if (finder.evaluate().isNotEmpty) {
                  await tester.ensureVisible(finder.first);
                  await tester.tap(finder.first);
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 180));
                }
              }
            },
          );
        }
      }
    },
  );

  testWidgets(
    'rega_froshyar ProductsMenuScreen (categories grid, draft category card, category detail view & add product sheet)',
    (tester) async {
      final products = _buildSampleProducts();
      final categories = ['پیتزا', 'بەرگر', 'خواردنەوەکان'];
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          await _pumpVendorWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => ProductsMenuScreen(
              products: products,
              categories: categories,
              categoryImages: const {},
              onToggle: (_) {},
              onDelete: (_) {},
              onAdd: (_) {},
              onEdit: (_) {},
              onAddCategory: (_, {imageUrl}) {},
              onDeleteCategory: (_) {},
              onUpdateCategory: (oldName, newName, {imageUrl}) async {},
            ),
            afterMount: () async {
              // Tap a category to enter category products view
              final catFinder = find.text(tx('پیتزا'));
              if (catFinder.evaluate().isNotEmpty) {
                await tester.ensureVisible(catFinder.first);
                await tester.tap(catFinder.first);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 200));

                // Open Add Product sheet inside the category
                final addProdIcon = find.byIcon(Icons.add_rounded);
                if (addProdIcon.evaluate().isNotEmpty) {
                  await tester.ensureVisible(addProdIcon.first);
                  await tester.tap(addProdIcon.first);
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 250));
                }
              }
            },
          );
        }
      }
    },
  );

  testWidgets(
    'rega_froshyar RevenueScreen (Today/Week/Month/Date tabs) & SettingsScreen across all viewports & themes',
    (tester) async {
      final sampleOrders = _buildSampleOrders();
      for (final lang in _locales) {
        for (final isDark in [false, true]) {
          for (final vp in _coreViewports) {
            await _pumpVendorWithGuard(
              tester,
              viewport: vp.size,
              lang: lang,
              isDark: isDark,
              builder: () => RevenueScreen(
                orders: sampleOrders,
                onRefresh: () async {},
              ),
            );
            await _pumpVendorWithGuard(
              tester,
              viewport: vp.size,
              lang: lang,
              isDark: isDark,
              builder: () => SettingsScreen(
                businessName: 'چێشتخانەی دیوانی کەلار',
                onNameChange: (_) {},
                language: lang,
                onLangChange: (_) {},
                isOnline: true,
                onOnlineChange: (_) {},
              ),
            );
          }
        }
      }
    },
  );

  testWidgets(
    'rega_froshyar AssignedDriverMap, ServiceAreaBlockedScreen & BlockedAccountContacts render cleanly across viewports',
    (tester) async {
      for (final lang in _locales) {
        for (final vp in _coreViewports) {
          await _pumpVendorWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => const AssignedDriverMap(
              orderNumber: '#10043',
              driverName: 'هێمن شۆفێر',
              initialDriverLat: 34.6845,
              initialDriverLng: 45.3201,
              storeLat: 34.6836,
              storeLng: 45.3189,
              customerLat: 34.6912,
              customerLng: 45.3264,
            ),
          );

          await _pumpVendorWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => ServiceAreaBlockedScreen(onRetry: () async {}),
          );

          await _pumpVendorWithGuard(
            tester,
            viewport: vp.size,
            lang: lang,
            builder: () => Builder(
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
