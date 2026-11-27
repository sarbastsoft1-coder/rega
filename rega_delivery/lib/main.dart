import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'live_captain_map.dart';
import 'driver_api_service.dart';
import 'blocked_account.dart';
import 'rega_mobile.dart';
import 'app/providers.dart';
import 'app/app_router.dart';
import 'state/driver_nav_notifier.dart';
import 'state/driver_session_notifier.dart';
import 'iraq_phone_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'service_area.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;
import 'map/mapbox_tiles.dart';
import 'rega_i18n.dart';
import 'rega_colors.dart';
import 'services/push_notifications.dart';
import 'services/driver_network.dart';
import 'services/driver_mutation_queue.dart';
import 'services/driver_sync_plan.dart';
import 'driver_shell_i18n.dart';
import 'package:uuid/uuid.dart';
import 'models/order_models.dart';
import 'widgets/active_order_card.dart';
import 'widgets/incoming_order_offer.dart';
import 'widgets/driver_home_dashboard.dart';
import 'screens/auth_screen.dart';
export 'models/order_models.dart';
export 'widgets/active_order_card.dart';
export 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (MapboxTiles.accessToken.isNotEmpty) {
    try {
      MapboxOptions.setAccessToken(MapboxTiles.accessToken);
    } catch (_) {}
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await PushNotifications.instance.init();
  DriverNetworkGate.check = () => DriverNetwork.instance.isOnline;
  await DriverNetwork.instance.start();
  await DriverMutationQueue.instance.load();
  DriverNetwork.instance.addListener(() {
    if (DriverNetwork.instance.isOnline) {
      DriverMutationQueue.instance.scheduleDrain();
    }
  });
  runApp(buildDriverProviders(child: const DeliveryDriverApp()));
}

/// ئەپی سەرەکی شۆفێری گەیاندن بە دیزاینی مۆدێرن و تەواو کوردی
class DeliveryDriverApp extends StatefulWidget {
  const DeliveryDriverApp({super.key});

  @override
  State<DeliveryDriverApp> createState() => _DeliveryDriverAppState();
}

class _DeliveryDriverAppState extends State<DeliveryDriverApp> {
  GoRouter? _router;
  bool _isOutsideServiceArea = false;
  bool _checkingServiceArea = false;
  Timer? _serviceAreaTimer;

  @override
  void initState() {
    super.initState();
    _initServiceAreaGate();
  }

  Future<void> _initServiceAreaGate() async {
    await _refreshServiceAreaConfig();
    await _checkServiceArea(requestPermission: true);
    _serviceAreaTimer?.cancel();
    _serviceAreaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkServiceArea();
    });
  }

  Future<void> _refreshServiceAreaConfig() async {
    final data = await DriverApiService.instance.fetchSupportContacts();
    if (data.isNotEmpty) {
      ServiceAreaGate.applyFromMap(data);
    }
  }

  Future<void> _checkServiceArea({bool requestPermission = false}) async {
    if (_checkingServiceArea) return;
    _checkingServiceArea = true;
    try {
      final result =
          await ServiceAreaGate.check(requestPermission: requestPermission);
      if (!mounted) return;
      setState(() => _isOutsideServiceArea = result.blocksApp);
    } finally {
      _checkingServiceArea = false;
    }
  }

  @override
  void dispose() {
    _serviceAreaTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createDriverRouter(
      refreshListenable: context.read<DriverSessionNotifier>(),
      authBuilder: (context) {
        final session = context.watch<DriverSessionNotifier>();
        return AuthScreen(
          currentLocale: session.locale,
          onLogin: (phone) async {
            await session.login(phone: phone);
            await PushNotifications.instance.requestPermissionAndSync();
            if (context.mounted) context.go('/map');
          },
        );
      },
      shellBuilder: (context, tabIndex) {
        final session = context.watch<DriverSessionNotifier>();
        return DriverMainScreen(
          currentLocale: session.locale,
          isDark: session.isDark,
          onLanguageChange: session.setLocale,
          onThemeChanged: session.setDark,
          onLogout: () async {
            // session.logout clears Sanctum token + logged_in flag.
            await session.logout();
            if (context.mounted) context.go('/login');
          },
          driverPhone: session.driverPhone,
          initialTabIndex: tabIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSessionNotifier>();
    // Drives tx(): every on-screen string follows the selected language.
    RegaI18n.setLang(session.locale);
    RC.setDark(session.isDark);
    final router = _router;
    if (router == null) return const SizedBox.shrink();

    if (_isOutsideServiceArea) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'NotoKufiArabic',
        ),
        home: ServiceAreaBlockedScreen(
          onRetry: () async {
            await _refreshServiceAreaConfig();
            await _checkServiceArea(requestPermission: true);
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'REGA Delivery',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // ku/ar → Arabic locale so Material inputs start from the right like Arabic.
      // Requires flutter_localizations — without these delegates TextFields crash
      // as gray ErrorWidgets when locale is 'ar'.
      locale: session.locale == 'en' ? const Locale('en') : const Locale('ar'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'NotoKufiArabic',
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.light,
          primary: const Color(0xFF00E676),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'NotoKufiArabic',
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.dark,
          primary: const Color(0xFF00E676),
          surface: const Color(0xFF111827),
        ),
      ),
      themeMode: session.themeMode,
      builder: (context, child) {
        return PushBannerHost(
          child: RegaResponsive.appBuilder(
            context,
            child,
            direction: session.textDirection,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// مۆدێلەکان (Data Models)
// ---------------------------------------------------------

// ---------------------------------------------------------
// ڕووکاری سەرەکی ئەپ (Main Screen with Bottom Nav)
// ---------------------------------------------------------

class DriverMainScreen extends StatefulWidget {
  final String currentLocale;
  final bool isDark;
  final Function(String) onLanguageChange;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLogout;
  final String driverPhone;
  final int initialTabIndex;

  const DriverMainScreen({
    super.key,
    required this.currentLocale,
    this.isDark = false,
    required this.onLanguageChange,
    required this.onThemeChanged,
    required this.onLogout,
    this.driverPhone = '',
    this.initialTabIndex = 0,
  });

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen>
    with WidgetsBindingObserver {
  String t(String key) => tr(key, widget.currentLocale);
  int _currentTabIndex = 0;
  bool _isOnline = false;
  bool _onlineToggleBusy = false;
  bool _isOrderCardVisible = true;
  bool _hasNewNotifications = false;
  int _todayEarnings = 0;
  int _completedDeliveriesCount = 0;
  int _selectedFilterIndex = 0;
  int _selectedEarningsTimeIndex = 2; // ئۆتۆماتیکی لەسەر 'ئەمڕۆ' بێت
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _driverProfile;
  List<Map<String, dynamic>>? _backendOrdersList;
  List<Map<String, dynamic>>? _availableOrdersList;
  int? _claimingOrderId;
  /// Incoming 30s accept offer shown above the map.
  Map<String, dynamic>? _pendingOffer;
  /// `available` (marketplace) or `assigned` (auto-dispatch).
  String? _pendingOfferSource;
  Timer? _offerTimer;
  int _offerSecondsLeft = 30;
  static const int _offerTimeoutSecs = 30;
  bool _offerActionBusy = false;
  final Set<int> _skippedOfferIds = <int>{};
  final Set<int> _seenAvailableIds = <int>{};
  final Set<int> _confirmedOfferIds = <int>{};
  bool _locationTrusted = false;
  Map<String, dynamic> _supportContacts = const {};
  final Map<String, Map<String, dynamic>> _earningsCache = {};
  Timer? _driverSyncTimer;
  bool _didStartBackendSync = false;
  String? _lastNotifiedOrderNum;
  bool _netOnline = true;
  int _pendingMutations = 0;
  int _syncTick = 0;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  bool _appInForeground = true;
  static const _uuid = Uuid();
  VoidCallback? _netListener;
  VoidCallback? _queueListener;

  // لیستی ئاگادارکردنەوەکان (تەنها لە داتای ڕاستەقینە)
  final List<Map<String, String>> _notifications = [];

  // لیستی هەموو داواکارییەکان بۆ بەشی لیست (مێژوو + بەردەست)
  List<Map<String, dynamic>> get _allOrdersData {
    final history = _backendOrdersList ?? const <Map<String, dynamic>>[];
    final available = _availableOrdersList ?? const <Map<String, dynamic>>[];
    return [...available, ...history];
  }

  bool _parseOnlineFlag(dynamic value) =>
      value == true || value == 1 || value?.toString() == '1' || value?.toString().toLowerCase() == 'true';

  List<Map<String, dynamic>> _mapOrdersFromBackend(
    List<dynamic> history, {
    required bool available,
  }) {
    return history.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final st = (m['status'] ?? 'pending').toString();
      final store = (m['store'] is Map)
          ? Map<String, dynamic>.from(m['store'] as Map)
          : const <String, dynamic>{};
      final cust = (m['customer'] is Map)
          ? Map<String, dynamic>.from(m['customer'] as Map)
          : const <String, dynamic>{};
      final fee =
          ((m['driver_total_earning'] ?? m['delivery_fee'] ?? 1500) as num)
              .toInt();
      final totalAmt =
          ((m['total_amount'] ?? m['subtotal'] ?? 0) as num).toInt();
      final isDelivered = st == 'delivered';
      final isCancelled = st == 'cancelled' || st == 'rejected';
      final numStr = (m['order_number'] ?? m['id'] ?? '').toString();
      final statusType = available
          ? 'available'
          : (isDelivered
              ? 'delivered'
              : (isCancelled ? 'cancelled' : 'active'));
      final statusKey = available
          ? 'status_available'
          : (isDelivered
              ? 'status_delivered'
              : (isCancelled ? 'status_cancelled' : 'status_on_way'));
      final rawItems = (m['items'] as List<dynamic>?) ?? const [];
      final mappedItems = rawItems.map((rawItem) {
        final it = Map<String, dynamic>.from(rawItem as Map);
        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
        final unit = ((it['unit_price'] ?? it['price'] ?? 0) as num).toInt();
        return <String, dynamic>{
          'name': (it['product_name'] ?? it['name'] ?? 'کاڵا').toString(),
          'qty': qty,
          'price': '${formatMoney(unit * qty)} ${t('iqd')}',
        };
      }).toList();
      final storeLat = (store['lat'] as num?)?.toDouble();
      final storeLng = (store['lng'] as num?)?.toDouble();
      final driverLat = (_driverProfile?['current_lat'] as num?)?.toDouble();
      final driverLng = (_driverProfile?['current_lng'] as num?)?.toDouble();
      String? distanceLabel;
      final distanceMeters = (m['distance_meters'] as num?)?.toDouble();
      if (distanceMeters != null && distanceMeters > 0) {
        distanceLabel = distanceMeters >= 1000
            ? '${(distanceMeters / 1000).toStringAsFixed(1)} ${t('km_unit')}'
            : '${distanceMeters.round()} ${t('m_unit')}';
      } else if (storeLat != null &&
          storeLng != null &&
          driverLat != null &&
          driverLng != null) {
        final meters = Geolocator.distanceBetween(
          driverLat,
          driverLng,
          storeLat,
          storeLng,
        );
        distanceLabel = meters >= 1000
            ? '${(meters / 1000).toStringAsFixed(1)} ${t('km_unit')}'
            : '${meters.round()} ${t('m_unit')}';
      }
      return <String, dynamic>{
        'raw': m,
        'dbId': (m['id'] as num?)?.toInt(),
        'id': formatOrderCode(numStr),
        'merchant': (store['name_ku'] ?? 'فرۆشگای کەلار').toString(),
        'merchantAddress': (store['address_ku'] ?? 'شاری کەلار').toString(),
        'merchantPhone': (store['phone'] ?? '').toString(),
        'customer':
            (m['customer_name'] ?? cust['name'] ?? 'کڕیار').toString(),
        'customerAddress':
            (m['delivery_address'] ?? 'شاری کەلار').toString(),
        'customerPhone':
            (m['customer_phone'] ?? cust['phone'] ?? '').toString(),
        'note': (m['delivery_note'] ?? m['notes'] ?? m['customer_note'] ?? '')
            .toString(),
        'items': mappedItems,
        'distanceLabel': distanceLabel,
        'statusKey': statusKey,
        'statusType': statusType,
        'price': '${formatMoney(fee)} ${t('iqd')}',
        'totalAmount': '${formatMoney(totalAmt)} ${t('iqd')}',
        'time': (m['created_at'] ?? m['ready_at'] ?? '')
            .toString()
            .replaceFirst('T', ' ')
            .split('.')
            .first,
        'statusColor': available
            ? RC.bg(const Color(0xFF2563EB))
            : (isDelivered
                ? RC.bg(const Color(0xFF16A34A))
                : (isCancelled
                    ? RC.bg(const Color(0xFFEF4444))
                    : RC.bg(const Color(0xFFD97706)))),
        'statusBg': available
            ? RC.bg(const Color(0xFFDBEAFE))
            : (isDelivered
                ? RC.bg(const Color(0xFFDCFCE7))
                : (isCancelled
                    ? RC.bg(const Color(0xFFFEE2E2))
                    : RC.bg(const Color(0xFFFEF3C7)))),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    final q = _searchQuery.trim().toLowerCase();
    return _allOrdersData.where((order) {
      bool matchesTab = true;
      if (_selectedFilterIndex == 1) {
        matchesTab = order['statusType'] == 'available';
      }
      if (_selectedFilterIndex == 2) {
        matchesTab = order['statusType'] == 'delivered';
      }
      if (_selectedFilterIndex == 3) {
        matchesTab = order['statusType'] == 'cancelled';
      }

      bool matchesSearch = q.isEmpty ||
          order['id'].toString().toLowerCase().contains(q) ||
          order['merchant'].toString().toLowerCase().contains(q) ||
          order['customer'].toString().toLowerCase().contains(q);

      return matchesTab && matchesSearch;
    }).toList();
  }

  // داواکاری چالاک
  late OrderModel _activeOrder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTabIndex = widget.initialTabIndex;
    _resetActiveOrder();
    _netOnline = DriverNetwork.instance.isOnline;
    _pendingMutations = DriverMutationQueue.instance.pendingCount;
    _netListener = () {
      if (!mounted) return;
      final online = DriverNetwork.instance.isOnline;
      setState(() => _netOnline = online);
      if (online) DriverMutationQueue.instance.scheduleDrain();
    };
    _queueListener = () {
      if (!mounted) return;
      setState(() => _pendingMutations = DriverMutationQueue.instance.pendingCount);
    };
    DriverNetwork.instance.addListener(_netListener!);
    DriverMutationQueue.instance.addListener(_queueListener!);
    DriverMutationQueue.instance.scheduleDrain();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _appInForeground) return;
    _appInForeground = fg;
    if (fg) {
      _armDriverSyncTimer();
      if (DriverNetwork.instance.isOnline) {
        unawaited(_refreshBackendDriverData(silent: true));
      }
    } else {
      _driverSyncTimer?.cancel();
      _driverSyncTimer = null;
    }
  }

  @override
  void didUpdateWidget(covariant DriverMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        _currentTabIndex != widget.initialTabIndex) {
      setState(() => _currentTabIndex = widget.initialTabIndex);
    }
  }

  void _goTab(int index) {
    setState(() => _currentTabIndex = index);
    context.read<DriverNavNotifier>().setTabIndex(index);
    context.go(DriverNavNotifier.pathForIndex(index));
    if (DriverNetwork.instance.isOnline) {
      unawaited(_refreshBackendDriverData(silent: true, forceTabScoped: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_netListener != null) {
      DriverNetwork.instance.removeListener(_netListener!);
    }
    if (_queueListener != null) {
      DriverMutationQueue.instance.removeListener(_queueListener!);
    }
    _driverSyncTimer?.cancel();
    _offerTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _armDriverSyncTimer() {
    _driverSyncTimer?.cancel();
    if (!_appInForeground) return;
    final secs = DriverSyncPlan.intervalSeconds(
      hasActiveOrder: _activeOrder.dbId != null,
    );
    _driverSyncTimer = Timer.periodic(Duration(seconds: secs), (_) {
      if (!mounted || !_appInForeground || !DriverNetwork.instance.isOnline) {
        return;
      }
      unawaited(_refreshBackendDriverData(silent: true));
    });
  }

  Future<void> _initBackendDriverSync() async {
    final ok = await DriverApiService.instance.ensureAuthenticated(phone: widget.driverPhone);
    if (!ok || !mounted) return;
    unawaited(PushNotifications.instance.requestPermissionAndSync());
    await _refreshBackendDriverData(forceFull: true);
    _armDriverSyncTimer();
    DriverMutationQueue.instance.scheduleDrain();
  }

  Widget _buildConnectivityBanner() {
    final offline = !_netOnline;
    final pending = _pendingMutations > 0;
    if (!offline && !pending) return const SizedBox.shrink();
    final text = offline
        ? t('offline_banner')
        : t('sync_pending_banner').replaceAll('{count}', '$_pendingMutations');
    return Material(
      color: offline ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.cloud_sync_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tx(text),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  OrderStatus _parseBackendDriverStatus(String? driverStatus, String? orderStatus) {
    switch (driverStatus) {
      case 'driver_arriving_pickup':
        return OrderStatus.driverArrivingPickup;
      case 'arrived_pickup':
        return OrderStatus.arrivedPickup;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'on_the_way':
        return OrderStatus.onTheWay;
      case 'arrived_customer':
        return OrderStatus.arrivedCustomer;
      case 'delivered':
        return OrderStatus.delivered;
      default:
        if (orderStatus == 'delivered') return OrderStatus.delivered;
        if (orderStatus == 'on_the_way') return OrderStatus.onTheWay;
        if (orderStatus == 'picked_up') return OrderStatus.pickedUp;
        return OrderStatus.driverAssigned;
    }
  }

  Future<void> _refreshBackendDriverData({
    bool silent = false,
    bool forceFull = false,
    bool forceTabScoped = false,
  }) async {
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;
    final hadActive = _activeOrder.dbId != null;
    try {
      if (!silent) {
        forceFull = true;
      }
      final tick = forceFull ? 0 : ++_syncTick;
      final plan = DriverSyncPlan.forTick(
        tick: forceTabScoped ? 0 : tick,
        tabIndex: _currentTabIndex,
        earningsPeriodIndex: _selectedEarningsTimeIndex,
        forceFull: forceFull,
        needSupportContacts: _supportContacts.isEmpty,
      );

      // Tab switch: fetch tab-relevant endpoints even on tick 0 without full fan-out.
      final effective = forceTabScoped && !forceFull
          ? DriverSyncPlan.forTick(
              tick: 4, // treat as deep enough for tab-local endpoints
              tabIndex: _currentTabIndex,
              earningsPeriodIndex: _selectedEarningsTimeIndex,
              forceFull: false,
              needSupportContacts: false,
            )
          : plan;

      final profileFuture = effective.profile
          ? DriverApiService.instance.fetchProfile()
          : Future<Map<String, dynamic>?>.value(null);
      final activeFuture = effective.activeOrder
          ? DriverApiService.instance.fetchActiveOrder()
          : Future<Map<String, dynamic>?>.value(null);
      final historyFuture = effective.ordersHistory
          ? DriverApiService.instance.fetchOrdersHistory()
          : Future<List<dynamic>>.value(const []);
      final availableFuture = effective.availableOrders
          ? DriverApiService.instance.fetchAvailableOrders()
          : Future<List<dynamic>>.value(const []);
      final todayEarnFuture = effective.earningsToday
          ? DriverApiService.instance.fetchEarnings(period: 'today')
          : Future<Map<String, dynamic>?>.value(null);
      final weekEarnFuture = effective.earningsWeek
          ? DriverApiService.instance.fetchEarnings(period: 'week')
          : Future<Map<String, dynamic>?>.value(null);
      final monthEarnFuture = effective.earningsMonth
          ? DriverApiService.instance.fetchEarnings(period: 'month')
          : Future<Map<String, dynamic>?>.value(null);
      final supportFuture = effective.supportContacts
          ? DriverApiService.instance.fetchSupportContacts()
          : Future<Map<String, dynamic>>.value(_supportContacts);

      final profile = await profileFuture;
      final active = effective.activeOrder ? await activeFuture : null;
      final history = effective.ordersHistory ? await historyFuture : null;
      final available =
          effective.availableOrders ? await availableFuture : null;
      final todayEarn = await todayEarnFuture;
      final weekEarn = await weekEarnFuture;
      final monthEarn = await monthEarnFuture;
      final support = await supportFuture;

      if (!mounted) return;

      setState(() {
        if (effective.supportContacts && support.isNotEmpty) {
          _supportContacts = support;
        }

        if (profile != null) {
          _driverProfile = profile;
          if (!_onlineToggleBusy) {
            _isOnline = _parseOnlineFlag(profile['is_online']);
          }
          final trusted = profile['location_trusted'];
          if (trusted is bool) {
            _locationTrusted = trusted;
          }
        }

        if (todayEarn != null) {
          _earningsCache['today'] = todayEarn;
          _todayEarnings =
              (todayEarn['total_earnings'] as num?)?.toInt() ?? _todayEarnings;
          _completedDeliveriesCount =
              (todayEarn['total_deliveries'] as num?)?.toInt() ??
                  _completedDeliveriesCount;
        }
        if (weekEarn != null) _earningsCache['week'] = weekEarn;
        if (monthEarn != null) _earningsCache['month'] = monthEarn;

        if (effective.activeOrder) {
          if (active != null) {
            _applyActiveOrderMap(active);
          } else {
            _isOrderCardVisible = false;
            _activeOrder = OrderModel(
              id: 'none',
              orderNumber: '',
              status: OrderStatus.driverAssigned,
              merchantName: '',
              merchantAddress: '',
              merchantPhone: '',
              customerName: '',
              customerAddress: '',
              customerPhone: '',
              items: const [],
              deliveryFee: 0,
              tip: 0,
              dbId: null,
              handoverPin: '',
              deliveryPin: '',
            );
          }
        }

        if (history != null) {
          _backendOrdersList =
              _mapOrdersFromBackend(history, available: false);
        }
        if (available != null) {
          _availableOrdersList =
              _mapOrdersFromBackend(available, available: true);
        }
      });

      if (available != null) {
        _maybeStartAvailableOffer();
      }

      final hasActive = _activeOrder.dbId != null;
      if (hasActive != hadActive) {
        _armDriverSyncTimer();
      }
    } finally {
      _refreshInFlight = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(_refreshBackendDriverData(silent: true));
      }
    }
  }

  void _applyActiveOrderMap(Map<String, dynamic> active) {
    final dbId = (active['id'] as num?)?.toInt();
    final orderNum = (active['order_number'] ?? '#10245').toString();
    final store = (active['store'] is Map)
        ? Map<String, dynamic>.from(active['store'] as Map)
        : const <String, dynamic>{};
    final cust = (active['customer'] is Map)
        ? Map<String, dynamic>.from(active['customer'] as Map)
        : const <String, dynamic>{};
    final rawItems = (active['items'] as List<dynamic>?) ?? const [];
    final mappedItems = rawItems.asMap().entries.map((e) {
      final m = Map<String, dynamic>.from(e.value as Map);
      return OrderItem(
        id: '${m['id'] ?? (e.key + 1)}',
        name: (m['product_name'] ?? m['name'] ?? 'خواردنی کەلار').toString(),
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        price: ((m['unit_price'] ?? m['price'] ?? 2500) as num).toInt(),
      );
    }).toList();

    final nextStatus = _parseBackendDriverStatus(
      active['driver_status']?.toString(),
      active['status']?.toString(),
    );

    _activeOrder = OrderModel(
      dbId: dbId,
      id: 'db_ord_${dbId ?? orderNum}',
      orderNumber: orderNum.startsWith('#') ? orderNum : '#$orderNum',
      status: nextStatus,
      vendorStatus: (active['vendor_status'] ?? active['status'] ?? 'preparing').toString(),
      merchantName: (store['name_ku'] ?? active['store_name'] ?? 'فرۆشگای کەلار').toString(),
      merchantAddress: (store['address_ku'] ?? active['store_address'] ?? 'ناو بازاڕی کەلار').toString(),
      merchantPhone: (store['phone'] ?? active['store_phone'] ?? '07701112233').toString(),
      customerName: (active['customer_name'] ?? cust['name'] ?? 'کڕیاری ڕێگا').toString(),
      customerAddress: (active['delivery_address'] ?? 'شاری کەلار').toString(),
      customerPhone: (active['customer_phone'] ?? cust['phone'] ?? '07703001001').toString(),
      items: mappedItems.isNotEmpty ? mappedItems : _activeOrder.items,
      subtotal: (active['subtotal'] as num?)?.toInt() ?? 0,
      discountAmount: (active['discount_amount'] as num?)?.toInt() ?? 0,
      deliveryFee: (active['delivery_fee'] as num?)?.toInt() ?? 1500,
      tip: (active['driver_tip'] as num?)?.toInt() ?? 0,
      waitingBonus: (active['waiting_bonus'] as num?)?.toInt() ?? 0,
      totalAmount: (active['total_amount'] as num?)?.toInt() ?? 0,
      paymentMethod: (active['payment_method'] ?? 'cash').toString(),
      customerNotes: (active['customer_notes'] ?? '').toString(),
      handoverPin: (active['handover_pin'] ?? '').toString(),
      // delivery_pin is never returned by API — customer tells the driver.
      deliveryPin: '',
      storeLat: (store['lat'] as num?)?.toDouble() ??
          (active['store_lat'] as num?)?.toDouble() ??
          34.6295,
      storeLng: (store['lng'] as num?)?.toDouble() ??
          (active['store_lng'] as num?)?.toDouble() ??
          45.3159,
      customerLat: (active['delivery_lat'] as num?)?.toDouble() ??
          (active['customer_lat'] as num?)?.toDouble() ??
          34.6345,
      customerLng: (active['delivery_lng'] as num?)?.toDouble() ??
          (active['customer_lng'] as num?)?.toDouble() ??
          45.3220,
    );
    if (_lastNotifiedOrderNum != orderNum) {
      _lastNotifiedOrderNum = orderNum;
      _hasNewNotifications = true;
      _notifications.insert(0, {
        'id': orderNum.replaceAll('#', ''),
        'time': 'ئێستا',
        'type': 'order',
      });
      _isOrderCardVisible = true;
      if (dbId != null &&
          nextStatus == OrderStatus.driverAssigned &&
          !_confirmedOfferIds.contains(dbId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _startOfferFromActiveOrder();
        });
      }
    }
  }

  void _maybeStartAvailableOffer() {
    if (!_isOnline || _activeOrder.dbId != null || _pendingOffer != null) {
      return;
    }
    final list = _availableOrdersList ?? const <Map<String, dynamic>>[];
    for (final order in list) {
      final id = order['dbId'] as int?;
      if (id == null) continue;
      final isNew = _seenAvailableIds.add(id);
      if (!isNew || _skippedOfferIds.contains(id) || _confirmedOfferIds.contains(id)) {
        continue;
      }
      _startOffer(order, source: 'available');
      return;
    }
  }

  void _startOfferFromActiveOrder() {
    final dbId = _activeOrder.dbId;
    if (dbId == null ||
        _activeOrder.status != OrderStatus.driverAssigned ||
        _confirmedOfferIds.contains(dbId) ||
        _pendingOffer != null) {
      return;
    }
    _startOffer({
      'dbId': dbId,
      'id': _activeOrder.orderNumber,
      'merchant': _activeOrder.merchantName,
      'merchantAddress': _activeOrder.merchantAddress,
      'customer': _activeOrder.customerName,
      'customerAddress': _activeOrder.customerAddress,
      'note': _activeOrder.customerNotes,
      'items': _activeOrder.items
          .map(
            (it) => <String, dynamic>{
              'name': it.name,
              'qty': it.quantity,
              'price': '${formatMoney(it.price * it.quantity)} ${t('iqd')}',
            },
          )
          .toList(),
      'price': '${formatMoney(_activeOrder.totalEarnings)} ${t('iqd')}',
      'totalAmount':
          '${formatMoney(_activeOrder.totalAmount > 0 ? _activeOrder.totalAmount : _activeOrder.totalEarnings)} ${t('iqd')}',
    }, source: 'assigned');
  }

  void _startOffer(Map<String, dynamic> order, {required String source}) {
    final dbId = order['dbId'] as int?;
    if (dbId == null) return;
    if (_pendingOffer != null) return;
    if (_skippedOfferIds.contains(dbId) || _confirmedOfferIds.contains(dbId)) {
      return;
    }

    _offerTimer?.cancel();
    setState(() {
      _pendingOffer = Map<String, dynamic>.from(order);
      _pendingOfferSource = source;
      _offerSecondsLeft = _offerTimeoutSecs;
      _offerActionBusy = false;
      _isOrderCardVisible = true;
    });
    if (_currentTabIndex != 0) {
      _goTab(0);
    }
    _offerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_offerSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _offerSecondsLeft = 0);
        unawaited(_handleOfferTimeout());
        return;
      }
      setState(() => _offerSecondsLeft -= 1);
    });
  }

  void _clearOffer({bool markSkipped = false, bool markConfirmed = false}) {
    final id = _pendingOffer?['dbId'] as int?;
    _offerTimer?.cancel();
    _offerTimer = null;
    if (id != null) {
      if (markSkipped) _skippedOfferIds.add(id);
      if (markConfirmed) _confirmedOfferIds.add(id);
    }
    if (!mounted) {
      _pendingOffer = null;
      _pendingOfferSource = null;
      _offerActionBusy = false;
      return;
    }
    setState(() {
      _pendingOffer = null;
      _pendingOfferSource = null;
      _offerActionBusy = false;
      _offerSecondsLeft = _offerTimeoutSecs;
    });
  }

  Future<void> _handleOfferTimeout() async {
    if (_pendingOffer == null || _offerActionBusy) return;
    await _declinePendingOffer(
      reason: t('offer_timeout_reason'),
      timedOut: true,
      askReason: true,
    );
  }

  Future<void> _acceptPendingOffer() async {
    final offer = _pendingOffer;
    final source = _pendingOfferSource;
    if (offer == null || _offerActionBusy) return;
    final dbId = offer['dbId'] as int?;
    if (dbId == null) return;

    setState(() => _offerActionBusy = true);
    _offerTimer?.cancel();

    if (source == 'available') {
      await _claimAvailableOrder(offer);
      if (!mounted) return;
      final claimed = _activeOrder.dbId == dbId;
      _clearOffer(markConfirmed: claimed, markSkipped: !claimed);
      return;
    }

    // Assigned: confirm by advancing to en-route-to-merchant.
    try {
      final updated = await DriverApiService.instance.advanceOrderStatus(
        dbId,
        'driver_arriving_pickup',
        idempotencyKey: _uuid.v4(),
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _applyActiveOrderMap(updated);
          _isOrderCardVisible = true;
        });
      } else {
        setState(() {
          _activeOrder.status = OrderStatus.driverArrivingPickup;
          _isOrderCardVisible = true;
        });
      }
      _clearOffer(markConfirmed: true);
      _showSuccessSnackBar(t('new_order_arrived'));
    } on DriverNetworkException {
      if (!mounted) return;
      setState(() => _offerActionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('offline_banner'))),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _offerActionBusy = false);
    }
  }

  Future<void> _declinePendingOffer({
    String? reason,
    bool timedOut = false,
    bool askReason = false,
  }) async {
    final offer = _pendingOffer;
    if (offer == null || _offerActionBusy) return;
    final dbId = offer['dbId'] as int?;
    if (dbId == null) return;

    var finalReason = reason?.trim() ?? '';
    if (askReason || finalReason.isEmpty) {
      finalReason = await _promptOfferDeclineReason(
            initial: finalReason.isNotEmpty ? finalReason : null,
            timedOut: timedOut,
          ) ??
          '';
      if (finalReason.isEmpty) {
        // User cancelled dialog on manual decline — resume timer if still open.
        if (!timedOut && _pendingOffer != null && _offerSecondsLeft > 0) {
          return;
        }
        finalReason = timedOut
            ? t('offer_timeout_reason')
            : t('offer_reassign');
      }
    }

    final source = _pendingOfferSource;
    setState(() => _offerActionBusy = true);
    try {
      final (ok, msg) = await DriverApiService.instance.declineOrderOffer(
        dbId,
        reason: finalReason,
        timedOut: timedOut,
        idempotencyKey: _uuid.v4(),
      );
      if (!mounted) return;
      _clearOffer(markSkipped: true);
      if (source == 'assigned' || _activeOrder.dbId == dbId) {
        setState(() => _resetActiveOrder());
      }
      await _refreshBackendDriverData(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(ok ? (msg ?? t('offer_declined_ok')) : (msg ?? t('offer_decline_failed')))),
          backgroundColor: ok ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626),
        ),
      );
    } on DriverNetworkException {
      if (!mounted) return;
      _clearOffer(markSkipped: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('offline_banner'))),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
    }
  }

  Future<String?> _promptOfferDeclineReason({
    String? initial,
    bool timedOut = false,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: !timedOut,
      builder: (ctx) => AlertDialog(
        backgroundColor: RC.bg(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          tx(t('offer_reason_title')),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: RC.fg(const Color(0xFF0F172A)),
          ),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tx(t('offer_reason_hint')),
            filled: true,
            fillColor: RC.bg(const Color(0xFFF8FAFC)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          if (!timedOut)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tx('پاشگەزبوونەوە')),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final text = ctrl.text.trim();
              Navigator.pop(
                ctx,
                text.isEmpty ? t('offer_reassign') : text,
              );
            },
            child: Text(tx(t('offer_reassign'))),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  CaptainRouteStage _toCaptainStage(OrderStatus s) {
    switch (s) {
      case OrderStatus.driverAssigned:
        return CaptainRouteStage.assigned;
      case OrderStatus.driverArrivingPickup:
        return CaptainRouteStage.arrivingPickup;
      case OrderStatus.arrivedPickup:
        return CaptainRouteStage.arrivedPickup;
      case OrderStatus.pickedUp:
        return CaptainRouteStage.pickedUp;
      case OrderStatus.onTheWay:
        return CaptainRouteStage.onTheWay;
      case OrderStatus.arrivedCustomer:
        return CaptainRouteStage.arrivedCustomer;
      case OrderStatus.delivered:
        return CaptainRouteStage.delivered;
    }
  }

  OrderStatus _fromCaptainStage(CaptainRouteStage s) {
    switch (s) {
      case CaptainRouteStage.assigned:
        return OrderStatus.driverAssigned;
      case CaptainRouteStage.arrivingPickup:
        return OrderStatus.driverArrivingPickup;
      case CaptainRouteStage.arrivedPickup:
        return OrderStatus.arrivedPickup;
      case CaptainRouteStage.pickedUp:
        return OrderStatus.pickedUp;
      case CaptainRouteStage.onTheWay:
        return OrderStatus.onTheWay;
      case CaptainRouteStage.arrivedCustomer:
        return OrderStatus.arrivedCustomer;
      case CaptainRouteStage.delivered:
        return OrderStatus.delivered;
    }
  }

  void _applySyncedBackendOrder(Map<String, dynamic> data) {
    final store = (data['store'] as Map<String, dynamic>?) ?? const {};
    final cust = (data['customer'] as Map<String, dynamic>?) ?? const {};
    final rawItems = (data['items'] as List<dynamic>?) ?? const [];
    final ref = (data['order_ref'] ?? '10245').toString();

    final mappedItems = rawItems.isNotEmpty
        ? rawItems.asMap().entries.map((e) {
            final m = e.value as Map<String, dynamic>;
            return OrderItem(
              id: '${e.key + 1}',
              name: (m['name'] ?? 'خواردنی کەلار').toString(),
              quantity: (m['quantity'] as num?)?.toInt() ?? 1,
              price: (m['price'] as num?)?.toInt() ?? 5000,
            );
          }).toList()
        : _activeOrder.items;

    final remoteDriverStatus = data['driver_status']?.toString() ?? 'driver_assigned';
    OrderStatus initialStage = OrderStatus.driverAssigned;
    if (remoteDriverStatus == 'driver_arriving_pickup') {
      initialStage = OrderStatus.driverArrivingPickup;
    } else if (remoteDriverStatus == 'arrived_pickup') {
      initialStage = OrderStatus.arrivedPickup;
    } else if (remoteDriverStatus == 'picked_up') {
      initialStage = OrderStatus.pickedUp;
    } else if (remoteDriverStatus == 'on_the_way') {
      initialStage = OrderStatus.onTheWay;
    } else if (remoteDriverStatus == 'arrived_customer') {
      initialStage = OrderStatus.arrivedCustomer;
    } else if (remoteDriverStatus == 'delivered') {
      initialStage = OrderStatus.delivered;
    }

    setState(() {
      _isOrderCardVisible = true;
      _activeOrder = OrderModel(
        id: 'ord_$ref',
        orderNumber: ref.startsWith('#') ? ref : '#$ref',
        status: initialStage,
        merchantName: (store['name'] ?? 'کەبابخانەی کەلار').toString(),
        merchantAddress: (store['address'] ?? 'ناو بازاڕی کەلار').toString(),
        merchantPhone: (store['phone'] ?? '07701112233').toString(),
        customerName: (cust['name'] ?? 'سەربەست عەلی').toString(),
        customerAddress: (cust['address'] ?? 'گەڕەکی شەهیدان، کەلار').toString(),
        customerPhone: (cust['phone'] ?? '07703001001').toString(),
        items: mappedItems,
        deliveryFee: (data['delivery_fee'] as num?)?.toInt() ?? 1500,
        tip: (data['driver_tip'] as num?)?.toInt() ?? 500,
        deliveryPin: '',
        storeLat: (store['lat'] as num?)?.toDouble() ??
            (data['store_lat'] as num?)?.toDouble() ??
            34.6836,
        storeLng: (store['lng'] as num?)?.toDouble() ??
            (data['store_lng'] as num?)?.toDouble() ??
            45.3189,
        customerLat: (cust['lat'] as num?)?.toDouble() ??
            (data['customer_lat'] as num?)?.toDouble() ??
            34.6912,
        customerLng: (cust['lng'] as num?)?.toDouble() ??
            (data['customer_lng'] as num?)?.toDouble() ??
            45.3264,
      );
    });
    _showSuccessSnackBar('داواکاری زیندووی کڕیار (#$ref) هێنرایە سەر نەخشە!');
  }

  void _resetActiveOrder() {
    if (!_didStartBackendSync) {
      _didStartBackendSync = true;
      _initBackendDriverSync();
    } else {
      _refreshBackendDriverData();
    }
    _isOrderCardVisible = false;
    _activeOrder = OrderModel(
      id: 'none',
      orderNumber: '',
      status: OrderStatus.driverAssigned,
      merchantName: '',
      merchantAddress: '',
      merchantPhone: '',
      customerName: '',
      customerAddress: '',
      customerPhone: '',
      items: const [],
      deliveryFee: 0,
      tip: 0,
      dbId: null,
      handoverPin: '',
      deliveryPin: '',
    );
  }

  Future<void> _updateOrderStatus(OrderStatus nextStatus) async {
    if (_activeOrder.dbId != null && nextStatus != OrderStatus.delivered) {
      final mapped = switch (nextStatus) {
        OrderStatus.driverArrivingPickup => 'driver_arriving_pickup',
        OrderStatus.arrivedPickup => 'arrived_pickup',
        OrderStatus.pickedUp => 'picked_up',
        OrderStatus.onTheWay => 'on_the_way',
        OrderStatus.arrivedCustomer => 'arrived_customer',
        _ => null,
      };
      if (mapped != null) {
        final orderId = _activeOrder.dbId!;
        final key = _uuid.v4();
        try {
          final data = await DriverApiService.instance.advanceOrderStatus(
            orderId,
            mapped,
            idempotencyKey: key,
          );
          if (data == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tx(t('status_update_failed'))),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
            return;
          }
        } on DriverNetworkException {
          await DriverMutationQueue.instance.enqueue(
            type: 'order_status',
            idempotencyKey: key,
            payload: {'order_id': orderId, 'driver_status': mapped},
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tx(t('mutation_queued'))),
                backgroundColor: const Color(0xFF1D4ED8),
              ),
            );
          }
        }
      }
    }
    if (!mounted) return;
    // Earnings KPIs come from fetchEarnings only — never invent local bumps.
    setState(() => _activeOrder.status = nextStatus);
  }

  Future<void> _completeDelivery() async {
    if (_activeOrder.dbId == null) {
      // No backend order id — do not fake a successful settlement.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('status_update_failed'))),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Complete without PIN dialog — one tap finishes delivery.
    final orderId = _activeOrder.dbId!;
    final key = _uuid.v4();
    var ok = false;
    String? msg;
    Object? lastErr;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await DriverApiService.instance.completeDelivery(
          orderId,
          idempotencyKey: key,
        );
        ok = result.$1;
        msg = result.$2;
        lastErr = null;
        break;
      } on DriverNetworkException catch (e) {
        lastErr = e;
        await Future<void>.delayed(Duration(milliseconds: 600 * (1 << attempt)));
      }
    }
    if (!mounted) return;
    if (lastErr != null || !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(
            lastErr != null
                ? t('complete_needs_network')
                : (msg ?? t('status_update_failed')),
          )),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _updateOrderStatus(OrderStatus.delivered);
    // Server is source of truth for wallet / today earnings counters.
    await _refreshBackendDriverData(forceFull: true);
    if (!mounted) return;
    _showSuccessSnackBar(t('nav_done'));
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tx(msg),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: RC.fg(Colors.black),
          ),
        ),
        backgroundColor: RC.bg(const Color(0xFF00E676)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // سەرپەڕەی سەرەوە: شۆفێر، ئۆنلاین/ئۆفلاین و داهاتی ئەمڕۆ
            _buildTopAppBar(),
            // Offline / pending sync — below locked header, never inside it.
            _buildConnectivityBanner(),
            // ناوەڕۆکی لاپەڕە بەپێی تاب
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildHomeMapScreen(),
                  _buildOrdersListScreen(),
                  _buildEarningsScreen(),
                  _buildProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentTabIndex == 1 && !_isOnline) _buildClaimNeedOnlineBar(),
          _buildBottomNav(),
        ],
      ),
    );
  }

  /// Sticky hint above bottom nav on Orders tab while driver is offline.
  Widget _buildClaimNeedOnlineBar() {
    return Material(
      color: const Color(0xFFF97316),
      child: InkWell(
        onTap: _onlineToggleBusy ? null : _toggleOnlineStatus,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tx(t('claim_need_online')),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  tx(t('online')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Flip Offline ↔ Online. Try GPS first when going online so dispatch/claim works.
  Future<void> _toggleOnlineStatus() async {
    // Sync lock first — Switch+label can fire twice before setState runs.
    if (_onlineToggleBusy || !mounted) return;
    _onlineToggleBusy = true;

    final previous = _isOnline;
    final nextOnline = !previous;
    final key = _uuid.v4();
    if (mounted) {
      setState(() => _isOnline = nextOnline);
    }

    double? lat;
    double? lng;
    var gpsMissing = false;
    if (nextOnline) {
      try {
        final fix = await _tryCaptureGpsForOnline().timeout(
          const Duration(seconds: 6),
          onTimeout: () => (null, null, true),
        );
        lat = fix.$1;
        lng = fix.$2;
        gpsMissing = fix.$3 || lat == null || lng == null;
      } catch (_) {
        gpsMissing = true;
      }
    }

    Map<String, dynamic>? updated;
    var queued = false;
    try {
      updated = await DriverApiService.instance.updateOnlineStatus(
        nextOnline,
        lat: lat,
        lng: lng,
        idempotencyKey: key,
      );
      if (nextOnline && lat != null && lng != null) {
        try {
          await DriverApiService.instance.updateLocation(lat, lng);
        } on DriverNetworkException {
          await DriverMutationQueue.instance.enqueue(
            type: 'location_update',
            idempotencyKey: 'location_latest',
            payload: {'lat': lat, 'lng': lng},
          );
        } catch (_) {}
      }
    } on DriverNetworkException {
      await DriverMutationQueue.instance.enqueue(
        type: 'online_status',
        idempotencyKey: key,
        payload: {
          'is_online': nextOnline,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      queued = true;
    }

    if (!mounted) return;

    if (updated == null && !queued) {
      setState(() {
        _isOnline = previous;
        _onlineToggleBusy = false;
      });
      final err = DriverApiService.instance.lastMutationError;
      final msg = err == 'session_expired'
          ? t('session_expired')
          : (err != null && err != 'status_update_failed' ? err : t('status_update_failed'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(msg)),
          backgroundColor: RC.bg(const Color(0xFFDC2626)),
        ),
      );
      return;
    }

    if (queued) {
      setState(() => _onlineToggleBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('mutation_queued'))),
          backgroundColor: const Color(0xFF1D4ED8),
        ),
      );
      return;
    }

    final data = updated!;
    final serverOnline = data['is_online'];
    final warning = data['warning']?.toString();
    final trusted = data['location_trusted'];
    setState(() {
      _isOnline = _parseOnlineFlag(serverOnline ?? nextOnline);
      if (trusted is bool) _locationTrusted = trusted;
      _onlineToggleBusy = false;
      if (_driverProfile != null) {
        _driverProfile = {
          ..._driverProfile!,
          'is_online': _isOnline,
          if (data.containsKey('is_verified'))
            'is_verified': data['is_verified'],
        };
      }
    });

    if (!nextOnline || !mounted) return;

    if (warning != null && warning.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(warning)),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
    } else if (gpsMissing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('gps_missing_online_warn'))),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
    } else if (_parseOnlineFlag(updated['is_verified']) == false &&
        updated['is_verified'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('not_verified_online'))),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
    }
  }

  Future<void> _claimAvailableOrder(Map<String, dynamic> order) async {
    final dbId = order['dbId'] as int?;
    if (dbId == null || _claimingOrderId != null) return;

    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('claim_need_online'))),
          backgroundColor: const Color(0xFFB45309),
          action: SnackBarAction(
            label: t('online'),
            textColor: Colors.white,
            onPressed: _toggleOnlineStatus,
          ),
        ),
      );
      return;
    }

    setState(() => _claimingOrderId = dbId);
    final key = _uuid.v4();
    Map<String, dynamic>? claimed;
    try {
      claimed = await DriverApiService.instance.claimOrder(
        dbId,
        idempotencyKey: key,
      );
    } on DriverNetworkException {
      if (!mounted) return;
      setState(() => _claimingOrderId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('offline_banner'))),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _claimingOrderId = null);

    if (claimed == null) {
      final err = DriverApiService.instance.lastMutationError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(
            err == null || err == 'claim_failed' ? t('claim_failed') : err,
          )),
          backgroundColor: RC.bg(const Color(0xFFDC2626)),
        ),
      );
      await _refreshBackendDriverData(silent: true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(t('new_order_arrived'))),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
    if (_pendingOffer?['dbId'] == dbId) {
      _clearOffer(markConfirmed: true);
    } else {
      _confirmedOfferIds.add(dbId);
    }
    setState(() {
      _isOrderCardVisible = true;
      _selectedFilterIndex = 0;
    });
    await _refreshBackendDriverData(silent: false);
    if (mounted) _goTab(0);
  }

  /// Returns `(lat, lng, missing)`. Never throws for denied/unavailable GPS.
  Future<(double?, double?, bool)> _tryCaptureGpsForOnline() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        // Native only — on web this often hangs or navigates away.
        if (!kIsWeb) {
          try {
            await Geolocator.openLocationSettings();
          } catch (_) {}
        }
        return (null, null, true);
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (null, null, true);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                maximumAge: Duration.zero,
                timeLimit: const Duration(seconds: 12),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                timeLimit: Duration(seconds: 12),
              ),
      );
      return (pos.latitude, pos.longitude, false);
    } catch (_) {
      return (null, null, true);
    }
  }

  // سەرپەڕەی سەرەوە: شێوازی مۆدێرن بە ڕەنگی سەوز و لۆگۆی REGA
  // PHASE LOCK: green REGA header — do not edit _buildTopAppBar visuals/handlers.
  Widget _buildTopAppBar() {
    final phone = RegaResponsive.isPhone(context);
    final padH = RegaResponsive.pagePadding(context);
    final notifBtn = InkWell(
      onTap: () {
        setState(() => _hasNewNotifications = false);
        _showNotificationsBottomSheet();
      },
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(phone ? 8 : 10),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.notifications_none_rounded, color: RC.fg(Colors.white), size: phone ? 24 : 28),
          ),
          if (_hasNewNotifications)
            Positioned(
              right: phone ? 8 : 10,
              top: phone ? 8 : 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFEF4444)),
                  shape: BoxShape.circle,
                  border: Border.all(color: RC.bg(Color(0xFF22C55E)), width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    final logo = SizedBox(
      height: phone ? 40 : 52,
      child: Center(
        child: Image.asset(
          'assets1/navbar_logo.png',
          height: phone ? 36 : 48,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delivery_dining_rounded, color: RC.fg(Colors.white), size: phone ? 20 : 24),
                const SizedBox(width: 8),
                Text(
                  tx('REGA'),
                  style: TextStyle(
                    color: RC.fg(Colors.white),
                    fontWeight: FontWeight.w900,
                    fontSize: phone ? 18 : 22,
                    letterSpacing: 1,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    final onlineToggle = InkWell(
      onTap: _onlineToggleBusy ? null : _toggleOnlineStatus,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedOpacity(
        opacity: _onlineToggleBusy ? 0.75 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: phone ? 4 : 5,
            vertical: phone ? 3 : 4,
          ),
          decoration: BoxDecoration(
            color: _isOnline
                ? const Color(0xFF15803D)
                : const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white, width: 1.8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isOnline) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: phone ? 7 : 10),
                  child: Text(
                    t('online'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: phone ? 11.5 : 13.5,
                    ),
                  ),
                ),
                Container(
                  width: phone ? 22 : 26,
                  height: phone ? 22 : 26,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Color(0xFF15803D),
                  ),
                ),
              ] else ...[
                Container(
                  width: phone ? 22 : 26,
                  height: phone ? 22 : 26,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    size: 14,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: phone ? 7 : 10),
                  child: Text(
                    t('offline'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: phone ? 11.5 : 13.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Container(
      height: phone ? 66 : 76,
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        color: RC.bg(const Color(0xFF22C55E)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              notifBtn,
              Flexible(child: logo),
              onlineToggle,
            ],
          ),
        ),
      ),
    );
  }

  // لاپەڕەی نەخشە و کارتی داواکاری
  Widget _buildHomeMapScreen() {
    final padH = RegaResponsive.pagePadding(context);
    final profileLat = (_driverProfile?['current_lat'] as num?)?.toDouble();
    final profileLng = (_driverProfile?['current_lng'] as num?)?.toDouble();
    final hasOffer = _pendingOffer != null;
    final hasActive = _activeOrder.dbId != null;
    final showActiveCard =
        !hasOffer && _isOrderCardVisible && hasActive;

    final liveMap = CaptainLiveMapWidget(
      orderNumber: _activeOrder.orderNumber,
      stage: _toCaptainStage(_activeOrder.status),
      merchantName: _activeOrder.merchantName,
      merchantAddress: _activeOrder.merchantAddress,
      customerName: _activeOrder.customerName,
      customerAddress: _activeOrder.customerAddress,
      deliveryPin: _activeOrder.deliveryPin,
      storeLat: _activeOrder.storeLat,
      storeLng: _activeOrder.storeLng,
      customerLat: _activeOrder.customerLat,
      customerLng: _activeOrder.customerLng,
      profileLat: profileLat,
      profileLng: profileLng,
      isOnline: _isOnline,
      hasActiveOrder: hasActive || hasOffer,
      isOrderCardExpanded: showActiveCard || hasOffer,
      locale: widget.currentLocale,
      translate: t,
      onRefreshData: () => _refreshBackendDriverData(silent: false),
      onStageAutoReached: (nextStage) {
        _updateOrderStatus(_fromCaptainStage(nextStage));
      },
      onArrivedPromptPin: _completeDelivery,
      onNewBackendOrderFound: _applySyncedBackendOrder,
    );

    // Idle home = full-bleed map + compact bottom sheet (map-first redesign).
    if (!hasOffer && !hasActive) {
      final available = _availableOrdersList ?? const <Map<String, dynamic>>[];
      final incomingCount = available.length;
      final firstMerchant = available.isEmpty
          ? ''
          : '${available.first['merchant'] ?? ''}'.trim();
      final nearbyTitle = firstMerchant.isNotEmpty
          ? firstMerchant
          : (incomingCount > 0
              ? '$incomingCount ${t('nearby_requests')}'
              : t('nearby_requests'));
      return DriverHomeDashboard(
        mapChild: liveMap,
        isOnline: _isOnline,
        onlineBusy: _onlineToggleBusy,
        todayEarningsLabel: '${formatMoney(_todayEarnings)} ${t('iqd')}',
        completedCount: _completedDeliveriesCount,
        incomingCount: incomingCount,
        nearbyTitle: nearbyTitle,
        onToggleOnline: _toggleOnlineStatus,
        onOpenIncoming: () {
          setState(() => _selectedFilterIndex = 1);
          _goTab(1);
        },
        onOpenOrders: () {
          setState(() => _selectedFilterIndex = 1);
          _goTab(1);
        },
        todayEarningsCaption: t('today_earnings'),
        completedCaption: t('completed_requests'),
        offlineLabel: t('offline'),
        waitingLabel: t('waiting_admin_order'),
        acceptLabel: t('accept_short'),
        ordersLabel: t('orders'),
        goOnlineLabel: t('online'),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: liveMap),

        // کارتی سەرەکی داواکاری (Bottom Sheet Card) — behind offer, above map
        if (showActiveCard)
          Positioned(
            left: padH,
            right: padH,
            bottom: 12,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 580),
                ),
                child: Material(
                  elevation: 20,
                  color: Colors.transparent,
                  shadowColor: Colors.black45,
                  borderRadius: BorderRadius.circular(24),
                  child: _activeOrder.status == OrderStatus.delivered
                      ? _buildCompletedCard()
                      : ActiveOrderCard(
                          order: _activeOrder,
                          locale: widget.currentLocale,
                          onUpdateStatus: _updateOrderStatus,
                          onRequestPinVerification: _completeDelivery,
                          onClaimWaitingBonus: _claimWaitingBonusForActiveOrder,
                          onRequestCancel: _showCancelOrderDialog,
                          onClose: () => setState(() => _isOrderCardVisible = false),
                        ),
                ),
              ),
            ),
          )
        else if (hasActive)
          // کارتی کورتکراوە — دیزاینی سادە (چێشتخانە / کڕیار)
          Positioned(
            left: padH,
            right: padH,
            bottom: 12,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Material(
                  color: RC.bg(Colors.white),
                  elevation: 10,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => setState(() => _isOrderCardVisible = true),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: RC.bg(const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  (_activeOrder.status == OrderStatus.pickedUp ||
                                          _activeOrder.status == OrderStatus.onTheWay ||
                                          _activeOrder.status == OrderStatus.arrivedCustomer)
                                      ? Icons.home_rounded
                                      : Icons.storefront_rounded,
                                  color: const Color(0xFF16A34A),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tx((_activeOrder.status == OrderStatus.pickedUp ||
                                          _activeOrder.status == OrderStatus.onTheWay ||
                                          _activeOrder.status == OrderStatus.arrivedCustomer)
                                      ? (_activeOrder.customerName.isNotEmpty
                                          ? _activeOrder.customerName
                                          : t('customer_dropoff'))
                                      : (_activeOrder.merchantName.isNotEmpty
                                          ? _activeOrder.merchantName
                                          : 'چێشتخانە')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: RC.fg(const Color(0xFF0F172A)),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: RC.fg(const Color(0xFF16A34A)),
                                size: 28,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => _isOrderCardVisible = true),
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: Text(
                                tx(t('show_info')),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // بۆکسی داواکاری نوێ — هەمیشە پێش نەخشە (z-order سەرەوە)
        if (hasOffer)
          Positioned(
            left: padH,
            right: padH,
            bottom: 12,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 520),
                ),
                child: IncomingOrderOffer(
                  orderIdLabel: formatOrderCode(_pendingOffer!['id']),
                  merchant: '${_pendingOffer!['merchant'] ?? ''}',
                  merchantAddress:
                      '${_pendingOffer!['merchantAddress'] ?? ''}',
                  customer: '${_pendingOffer!['customer'] ?? ''}',
                  customerAddress:
                      '${_pendingOffer!['customerAddress'] ?? ''}',
                  deliveryFeeLabel: '${_pendingOffer!['price'] ?? ''}',
                  totalLabel: '${_pendingOffer!['totalAmount'] ?? _pendingOffer!['price'] ?? ''}',
                  distanceLabel: _pendingOffer!['distanceLabel']?.toString(),
                  note: _pendingOffer!['note']?.toString(),
                  items: ((_pendingOffer!['items'] as List<dynamic>?) ??
                          const [])
                      .map((raw) {
                    final it = Map<String, dynamic>.from(raw as Map);
                    return (
                      name: '${it['name'] ?? ''}',
                      qty: (it['qty'] as num?)?.toInt() ?? 1,
                      price: '${it['price'] ?? ''}',
                    );
                  }).toList(),
                  secondsLeft: _offerSecondsLeft,
                  totalSeconds: _offerTimeoutSecs,
                  busy: _offerActionBusy,
                  acceptLabel: t('accept_order'),
                  declineLabel: t('offer_decline'),
                  pickupLabel: t('merchant_pickup'),
                  dropoffLabel: t('customer_dropoff'),
                  feeCaption: t('delivery_fee_label'),
                  totalCaption: t('order_total'),
                  noteCaption: t('offer_note'),
                  onAccept: () => unawaited(_acceptPendingOffer()),
                  onDecline: () => unawaited(
                    _declinePendingOffer(askReason: true),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // کارتی کاتی تەواوبوونی گەیاندن
  Widget _buildCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: RC.bg(Colors.black12), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RC.bg(const Color(0xFFE8F5E9)),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, color: RC.fg(const Color(0xFF00C853)), size: 36),
          ),
          const SizedBox(height: 12),
          Text(t('order_completed'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            tx('بڕی ${formatMoney(_activeOrder.totalEarnings)} د.ع زیادکرا بۆ باڵانسەکەت'),
            style: TextStyle(color: RC.fg(Colors.grey.shade600), fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(const Color(0xFF00E676)),
                foregroundColor: RC.fg(Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() => _resetActiveOrder());
              },
              child: Text(t('accept_new_order'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _claimWaitingBonusForActiveOrder() async {
    final dbId = _activeOrder.dbId;
    if (dbId == null) return;
    final key = _uuid.v4();
    try {
      final (ok, msg, updated) = await DriverApiService.instance.claimWaitingBonus(
        dbId,
        idempotencyKey: key,
      );
      if (!mounted) return;
      if (ok) {
        if (updated != null) {
          setState(() => _applyActiveOrderMap(updated));
        } else {
          await _refreshBackendDriverData(silent: true);
        }
        if (!mounted) return;
        _showSuccessSnackBar(msg ?? 'پاداشتی چاوەڕوانی زیادکرا');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(msg ?? 'هێشتا ١٥ خولەک چاوەڕوانیت تەواو نەکردووە')),
            backgroundColor: RC.bg(const Color(0xFFD97706)),
          ),
        );
      }
    } on DriverNetworkException {
      await DriverMutationQueue.instance.enqueue(
        type: 'waiting_bonus',
        idempotencyKey: key,
        payload: {'order_id': dbId, 'waited_minutes': 16},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('mutation_queued'))),
          backgroundColor: const Color(0xFF1D4ED8),
        ),
      );
    }
  }

  Future<void> _showCancelOrderDialog() async {
    final dbId = _activeOrder.dbId;
    if (dbId == null) return;
    final reasonCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RC.bg(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          tx('داواکاری هەڵوەشاوە'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: RC.fg(const Color(0xFF0F172A)),
          ),
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: tx('هۆکاری کێشەکە بنوسە'),
            hintStyle: TextStyle(
              color: RC.fg(const Color(0xFF94A3B8)),
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: RC.bg(const Color(0xFFF8FAFC)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF94A3B8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tx('پاشگەزبوونەوە')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tx('ناردن بۆ ئادمین')),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (submitted != true || !mounted) return;
    final key = _uuid.v4();
    final reasonText =
        reason.isEmpty ? 'کڕیار وەڵامی پەیوەندی ناداتەوە' : reason;
    try {
      final ok = await DriverApiService.instance.requestCancellation(
        dbId,
        reasonText,
        idempotencyKey: key,
      );
      if (!mounted) return;
      if (ok) {
        _showSuccessSnackBar('داواکارییەکە نێردرا بۆ بەشی چاودێری ئادمین');
      }
    } on DriverNetworkException {
      await DriverMutationQueue.instance.enqueue(
        type: 'cancel_request',
        idempotencyKey: key,
        payload: {'order_id': dbId, 'reason': reasonText},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(t('mutation_queued'))),
          backgroundColor: const Color(0xFF1D4ED8),
        ),
      );
    }
  }

  // لاپەڕەی داهات (Earnings Screen) ڕێک وەک وێنەکە
  Widget _buildEarningsScreen() {
    final historyRows =
        (_selectedLiveEarnings?['history'] as List?) ??
        (_selectedLiveEarnings?['recent'] as List?) ??
        const [];
    final walletBal = (_selectedLiveEarnings?['wallet_balance'] as num?)?.toInt() ??
        (_driverProfile?['wallet_balance'] as num?)?.toInt() ??
        0;
    final cashHand = (_selectedLiveEarnings?['cash_collected_hand'] as num?)?.toInt() ??
        (_driverProfile?['cash_collected_hand'] as num?)?.toInt() ??
        0;
    final tipsVal = (_selectedLiveEarnings?['customer_tips'] as num?)?.toInt() ??
        (_selectedLiveEarnings?['tips'] as num?)?.toInt() ??
        0;
    final hoursRaw = (_selectedLiveEarnings?['online_hours'] as num?)?.toString() ??
        (_driverProfile?['online_hours_total'] as num?)?.toString() ??
        '0';
    final hours = '$hoursRaw ${t('hours_unit')}';

    void selectPeriod(int index) {
      setState(() => _selectedEarningsTimeIndex = index);
      unawaited(
        _refreshBackendDriverData(silent: true, forceTabScoped: true),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF16A34A),
      onRefresh: () => _refreshBackendDriverData(silent: false),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: RegaResponsive.pagePadding(context),
              vertical: 12,
            ),
            children: [
              // ١. سەردێڕ + نوێکردنەوە
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('earnings'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t('data_refreshed'),
                    onPressed: () =>
                        _refreshBackendDriverData(silent: false),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 22,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ٢. تابی کات — لە RTL: ئەمڕۆ ڕاست، مانگ چەپ
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: RC.bg(const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // RTL: یەکەم منداڵ دەکەوێتە ڕاست — ئەمڕۆ لای ڕاست
                    Expanded(
                      child: _buildTimeTab(
                        t('today'),
                        _selectedEarningsTimeIndex == 2,
                        onTap: () => selectPeriod(2),
                      ),
                    ),
                    Expanded(
                      child: _buildTimeTab(
                        t('this_week'),
                        _selectedEarningsTimeIndex == 1,
                        onTap: () => selectPeriod(1),
                      ),
                    ),
                    Expanded(
                      child: _buildTimeTab(
                        t('this_month'),
                        _selectedEarningsTimeIndex == 0,
                        onTap: () => selectPeriod(0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ٣. کارتی سەرەکی داهات
              _buildMainEarningsCard(),
              const SizedBox(height: 10),

              // ٤. ٢×٢ (بێ ئایکۆن لەبەردەم تێکست)
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryStatBox(
                      title: t('online_hours'),
                      value: hours,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSecondaryStatBox(
                      title: t('customer_tip'),
                      value: '${formatMoney(tipsVal)} ${t('iqd')}',
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryStatBox(
                      title: t('wallet_balance'),
                      value: '${formatMoney(walletBal)} ${t('iqd')}',
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSecondaryStatBox(
                      title: t('cash_from_customer'),
                      value: '${formatMoney(cashHand)} ${t('iqd')}',
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ٥. مێژووی داهات
              Text(
                t('earnings_history'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: RC.fg(const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 8),

              if (historyRows.isNotEmpty)
                ...historyRows.take(20).map((row) {
                  final m = Map<String, dynamic>.from(row as Map);
                  final id = (m['order_number'] ?? m['id'] ?? '-').toString();
                  final time =
                      (m['delivered_at'] ?? m['created_at'] ?? m['time'] ?? '')
                          .toString()
                          .replaceFirst('T', ' ')
                          .split('.')
                          .first;
                  final earnAmt =
                      (m['driver_total_earning'] as num?)?.toInt() ??
                          (m['driver_earning'] as num?)?.toInt() ??
                          (m['delivery_fee'] as num?)?.toInt() ??
                          0;
                  final total = '${formatMoney(earnAmt)} ${t('iqd')}';
                  final orderTotal = (m['total_amount'] as num?)?.toInt() ?? 0;
                  final detail = orderTotal > 0
                      ? 'کۆی داواکاری: ${formatMoney(orderTotal)} ${t('iqd')}'
                      : total;
                  return _buildEarningsHistoryItem(
                    formatOrderCode(id),
                    time,
                    total,
                    detail,
                  );
                })
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                  ),
                  child: Text(
                    tx(t('no_orders')),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RC.fg(const Color(0xFF94A3B8)),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? get _selectedLiveEarnings {
    final key = _selectedEarningsTimeIndex == 2
        ? 'today'
        : (_selectedEarningsTimeIndex == 1 ? 'week' : 'month');
    return _earningsCache[key];
  }

  Widget _buildMainEarningsCard() {
    String label = '${t('total_earnings')} ${t('today')}';
    if (_selectedEarningsTimeIndex == 1) {
      label = '${t('total_earnings')} ${t('this_week')}';
    } else if (_selectedEarningsTimeIndex == 0) {
      label = '${t('total_earnings')} ${t('this_month')}';
    }
    final total = _selectedLiveEarnings != null
        ? '${formatMoney((_selectedLiveEarnings!['total_earnings'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
        : '0 ${t('iqd')}';
    final bonus = _selectedLiveEarnings != null
        ? '${formatMoney((_selectedLiveEarnings!['bonus'] as num?)?.toInt() ?? 0)} ${t('iqd')}'
        : '0 ${t('iqd')}';
    final avg = _selectedLiveEarnings != null
        ? '${formatMoney((_selectedLiveEarnings!['avg_per_delivery'] as num?)?.toInt() ?? 0)}'
        : '0';
    final count = _selectedLiveEarnings != null
        ? '${_selectedLiveEarnings!['total_deliveries'] ?? 0}'
        : '0';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tx(label),
            style: TextStyle(
              color: RC.fg(const Color(0xFF64748B)),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              tx(total),
              style: TextStyle(
                fontSize: RegaResponsive.scale(context, 18),
                fontWeight: FontWeight.w900,
                color: RC.fg(const Color(0xFF1D4ED8)),
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: RC.bg(const Color(0xFFF1F5F9))),
          const SizedBox(height: 6),
          // RTL: یەکەم ڕاست — کۆی گەیاندن ڕاست، تێکرا چەپ (وەک وێنەکە)
          Row(
            children: [
              Expanded(
                child: _statItemEarnings(t('total_deliveries'), count),
              ),
              Container(
                width: 1,
                height: 26,
                color: RC.bg(const Color(0xFFF1F5F9)),
              ),
              Expanded(
                child: _statItemEarnings(t('avg_delivery'), avg),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: RC.bg(const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tx('${t('bonus')} (Bonus)'),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: RC.fg(const Color(0xFF64748B)),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  tx(bonus),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(const Color(0xFF16A34A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTab(String label, bool isSelected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withOpacity(0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            tx(label),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : RC.fg(const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryStatBox({
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: RC.fg(const Color(0xFF64748B)),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              tx(value),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: valueColor ?? RC.fg(const Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItemEarnings(String title, String val, {bool isGreen = false}) {
    return Column(
      children: [
        Text(
          tx(title),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            color: RC.fg(const Color(0xFF94A3B8)),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tx(val),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isGreen
                ? RC.fg(const Color(0xFF16A34A))
                : RC.fg(const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsHistoryItem(String id, String time, String price, String breakdown) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx('بینینی وردەکاری داواکاری $id'))),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: RC.bg(Colors.white),
          border: Border(bottom: BorderSide(color: RC.bg(Color(0xFFF1F5F9)))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // لای ڕاست: ID و کات
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tx(id),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                ),
                const SizedBox(height: 4),
                Text(
                  tx(time),
                  style: TextStyle(fontSize: 13, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            // لای چەپ: نرخ و وردەکاری
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(price),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF16A34A))),
                ),
                const SizedBox(height: 4),
                Text(
                  tx(breakdown),
                  style: TextStyle(fontSize: 13, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx(title), style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade600))),
        const SizedBox(height: 2),
        Text(tx(val), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // لاپەڕەی پڕۆفایل — ناڤباری سەرەوە دستنەدراو
  Widget _buildProfileScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: RegaResponsive.pagePadding(context),
            vertical: 16,
          ),
          children: [
            _buildProfileHeaderCard(),
            const SizedBox(height: 14),
            _buildMotorcycleInfoCard(),
            const SizedBox(height: 14),
            _buildBalanceInfoCard(),
            const SizedBox(height: 14),
            _buildSettingsCard(),
            const SizedBox(height: 14),
            _buildSupportTile(),
            const SizedBox(height: 14),
            _buildLogoutButton(),
            const SizedBox(height: 28),
            Center(
              child: Image.asset(
                RC.isDark ? 'assets1/logo2_dark.png' : 'assets1/logo2.png',
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tx(title),
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: RC.fg(const Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileKvRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tx(label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: RC.fg(const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              tx(value),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: valueColor ?? RC.fg(const Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final name =
        (_driverProfile?['user']?['name'] ?? _driverProfile?['name'] ?? '-')
            .toString();
    final phone = (_driverProfile?['user']?['phone'] ??
            _driverProfile?['phone'] ??
            widget.driverPhone)
        .toString();
    final code = (_driverProfile?['driver_code'] ?? '-').toString();
    final rating = (_driverProfile?['rating'] ?? 0).toString();
    final deliveries = (_driverProfile?['total_deliveries'] ?? 0).toString();
    final completion = '${_driverProfile?['completion_rate'] ?? 0}%';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: RC.bg(const Color(0xFFF0FDF4)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF22C55E),
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: RC.fg(const Color(0xFF16A34A)),
                ),
              ),
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            tx(name),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: RC.fg(const Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: RC.bg(const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              tx('$phone  •  $code'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: RC.fg(const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildHeaderStat(t('rating'), rating),
              ),
              Container(
                width: 1,
                height: 44,
                color: RC.bg(const Color(0xFFE2E8F0)),
              ),
              Expanded(
                child: _buildHeaderStat(t('orders'), deliveries),
              ),
              Container(
                width: 1,
                height: 44,
                color: RC.bg(const Color(0xFFE2E8F0)),
              ),
              Expanded(
                child: _buildHeaderStat(
                  t('completion'),
                  completion,
                  valueColor: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          tx(value),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: valueColor ?? RC.fg(const Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tx(label),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: RC.fg(const Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }

  Widget _buildMotorcycleInfoCard() {
    return _buildProfileSectionCard(
      title: t('motor_info'),
      children: [
        _buildProfileKvRow(
          t('motor_id'),
          (_driverProfile?['plate_number'] ?? '-').toString(),
        ),
        Divider(height: 1, color: RC.bg(const Color(0xFFF1F5F9))),
        _buildProfileKvRow(
          t('motor_type'),
          (_driverProfile?['motor_type'] ?? '-').toString(),
        ),
        Divider(height: 1, color: RC.bg(const Color(0xFFF1F5F9))),
        _buildProfileKvRow(
          t('motor_color'),
          (_driverProfile?['motor_color'] ?? '-').toString(),
        ),
        Divider(height: 1, color: RC.bg(const Color(0xFFF1F5F9))),
        _buildProfileKvRow(
          t('motor_model'),
          (_driverProfile?['model_year'] ?? '-').toString(),
        ),
      ],
    );
  }

  Widget _buildBalanceInfoCard() {
    final walletBal =
        (_driverProfile?['wallet_balance'] as num?)?.toInt() ?? 0;
    final cashHand =
        (_driverProfile?['cash_collected_hand'] as num?)?.toInt() ?? 0;
    final lifetime =
        (_driverProfile?['lifetime_earnings'] as num?)?.toInt() ??
            (_driverProfile?['total_earnings'] as num?)?.toInt() ??
            _todayEarnings;

    return _buildProfileSectionCard(
      title: t('balance_section'),
      children: [
        _buildProfileKvRow(
          t('total_earnings'),
          '${formatMoney(lifetime)} ${t('iqd')}',
          valueColor: const Color(0xFF16A34A),
        ),
        Divider(height: 1, color: RC.bg(const Color(0xFFF1F5F9))),
        _buildProfileKvRow(
          t('cash_on_hand'),
          '${formatMoney(cashHand)} ${t('iqd')}',
          valueColor: const Color(0xFF16A34A),
        ),
        Divider(height: 1, color: RC.bg(const Color(0xFFF1F5F9))),
        _buildProfileKvRow(
          t('wallet_balance'),
          '${formatMoney(walletBal)} ${t('iqd')}',
          valueColor: const Color(0xFF16A34A),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    String currentLangName = 'کوردی';
    if (widget.currentLocale == 'ar') currentLangName = 'العربية';
    if (widget.currentLocale == 'en') currentLangName = 'English';

    return _buildProfileSectionCard(
      title: t('settings'),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tx(t('theme')),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: RC.fg(const Color(0xFF64748B)),
                ),
              ),
            ),
            Switch.adaptive(
              value: widget.isDark,
              activeColor: const Color(0xFF16A34A),
              onChanged: widget.onThemeChanged,
            ),
            const SizedBox(width: 6),
            Text(
              tx(widget.isDark ? t('dark_mode') : t('light_mode')),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: RC.fg(const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: RC.bg(const Color(0xFFF1F5F9))),
        const SizedBox(height: 10),
        Text(
          tx(t('languages')),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: RC.fg(const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: RC.bg(const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(child: _buildLangOption('English', 'en')),
              Expanded(child: _buildLangOption('العربية', 'ar')),
              Expanded(child: _buildLangOption('کوردی', 'ku')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tx(currentLangName),
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: RC.fg(const Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }

  Widget _buildLangOption(String label, String langCode) {
    final isSelected = widget.currentLocale == langCode;
    return InkWell(
      onTap: () => widget.onLanguageChange(langCode),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            tx(label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : RC.fg(const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportTile() {
    return InkWell(
      onTap: () => _showSupportBottomSheet(),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: RC.bg(Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t('support'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: RC.fg(const Color(0xFF0F172A)),
                ),
              ),
            ),
            Icon(
              widget.currentLocale == 'en'
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: RC.fg(const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: widget.currentLocale == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: RegaResponsive.dialogMaxWidth(ctx, cap: 580),
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.all(RegaResponsive.pagePadding(ctx).clamp(16.0, 24.0)),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: RC.bg(Colors.grey.shade100), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t('support_title'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: RC.fg(const Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t('support_subtitle'),
                            style: TextStyle(
                              fontSize: 12,
                              color: RC.fg(const Color(0xFF94A3B8)),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Emergency Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFF1F2)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: RC.bg(Color(0xFFFECDD3))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(Color(0xFFEF4444)),
                          foregroundColor: RC.fg(Colors.white),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final emergencyPhone = (_supportContacts['emergency_phone'] ??
                                  _supportContacts['support_phone'] ??
                                  '07500009372')
                              .toString()
                              .replaceAll(' ', '');
                          launchUrl(Uri.parse('tel:$emergencyPhone'));
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(t('emergency_btn'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            t('emergency_title'),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: RC.fg(const Color(0xFF991B1B)),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t('emergency_desc'),
                            textAlign: TextAlign.end,
                            style: TextStyle(color: RC.fg(Color(0xFF991B1B)), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Hotline Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
                  boxShadow: [BoxShadow(color: RC.bg(Colors.black).withOpacity(0.02), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Text(
                      t('hotline_title'),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(const Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(const Color(0xFF16A34A)),
                          foregroundColor: RC.fg(Colors.white),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          final hotline = (_supportContacts['support_phone'] ??
                                  _supportContacts['whatsapp_phone'] ??
                                  '07500009372')
                              .toString()
                              .replaceAll(' ', '');
                          launchUrl(Uri.parse('tel:$hotline'));
                        },
                        child: Text(
                          tx('${t('hotline_btn')} : ${_supportContacts['support_phone'] ?? '0750 000 9372'}'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // FAQ Section
              Text(t('faq_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B)))),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _buildFAQItem(t('faq_1_q'), t('faq_1_a')),
                    const SizedBox(height: 12),
                    _buildFAQItem(t('faq_2_q'), t('faq_2_a')),
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
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx(question), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B)), fontSize: 14)),
          const SizedBox(height: 8),
          Text(tx(answer), style: TextStyle(color: RC.fg(Color(0xFF64748B)), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () => widget.onLogout(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RC.bg(const Color(0xFFFEE2E2)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RC.bg(const Color(0xFFFECACA))),
        ),
        child: Text(
          t('logout'),
          style: TextStyle(
            color: RC.fg(const Color(0xFFDC2626)),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _showNotificationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: RegaResponsive.dialogMaxWidth(ctx, cap: 580),
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(RegaResponsive.pagePadding(ctx).clamp(14.0, 20.0)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: RC.bg(Colors.grey.shade100), shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 20, color: RC.fg(Colors.black)),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      t('notifications'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1E293B))),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 36), // Spacer for balance
                ],
              ),
            ),
            Divider(height: 1, color: RC.bg(Color(0xFFF1F5F9))),
            
            // List
            Expanded(
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: RC.fg(Colors.grey.shade200)),
                          const SizedBox(height: 16),
                          Text(t('no_notifications'), style: TextStyle(color: RC.fg(Colors.grey.shade400))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
                            boxShadow: [BoxShadow(color: RC.bg(Colors.black).withOpacity(0.02), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('new_order_notif').replaceAll('%s', notif['id']!),
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: RC.fg(Color(0xFF1E293B))),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tx(notif['time']!),
                                      style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w600),
                                    ),
                                    if (RegaResponsive.isPhone(ctx)) ...[
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 28),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            setState(() {
                                              _searchQuery = notif['id']!;
                                              _searchController.text = notif['id']!;
                                            });
                                            _goTab(1);
                                          },
                                          child: Text(t('view_details'), style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontWeight: FontWeight.w900, fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!RegaResponsive.isPhone(ctx)) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _searchQuery = notif['id']!;
                                        _searchController.text = notif['id']!;
                                      });
                                      _goTab(1);
                                    },
                                    child: Text(t('view_details'), style: TextStyle(color: RC.fg(Color(0xFF16A34A)), fontWeight: FontWeight.w900, fontSize: 12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  // لاپەڕەی لیستی داواکارییەکان (Orders List Screen)
  Widget _buildOrdersListScreen() {
    final allCount = _allOrdersData.length;
    final availableCount =
        _allOrdersData.where((o) => o['statusType'] == 'available').length;
    final deliveredCount =
        _allOrdersData.where((o) => o['statusType'] == 'delivered').length;
    final cancelledCount =
        _allOrdersData.where((o) => o['statusType'] == 'cancelled').length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ١. سەردێڕی لاپەڕە + دوگمەی نوێکردنەوە
            Padding(
              padding: EdgeInsets.fromLTRB(
                RegaResponsive.pagePadding(context),
                16,
                RegaResponsive.pagePadding(context),
                8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      t('orders'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(const Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t('data_refreshed'),
                    onPressed: () =>
                        _refreshBackendDriverData(silent: false),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),

            // ٢. بەشی گەڕان (Search Bar)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: RegaResponsive.pagePadding(context),
                vertical: 6,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: t('search_hint'),
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: RC.fg(const Color(0xFF94A3B8)),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: RC.fg(const Color(0xFF94A3B8)),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
            ),

            // ٣. فلتەرەکان (Tabs/Filters — ژمارەی ڕاستەقینە لە داتابەیسەوە)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: RegaResponsive.pagePadding(context),
                ),
                child: Row(
                  children: [
                    _buildFilterChip(
                      t('all'),
                      '$allCount',
                      _selectedFilterIndex == 0,
                      onTap: () => setState(() => _selectedFilterIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      t('status_available'),
                      '$availableCount',
                      _selectedFilterIndex == 1,
                      onTap: () => setState(() => _selectedFilterIndex = 1),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      t('delivered'),
                      '$deliveredCount',
                      _selectedFilterIndex == 2,
                      onTap: () => setState(() => _selectedFilterIndex = 2),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      t('cancelled'),
                      '$cancelledCount',
                      _selectedFilterIndex == 3,
                      isDanger: true,
                      onTap: () => setState(() => _selectedFilterIndex = 3),
                    ),
                  ],
                ),
              ),
            ),

            // ٤. لیستی داواکارییەکان
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF16A34A),
                onRefresh: () => _refreshBackendDriverData(silent: false),
                child: _getFilteredOrders().isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 90),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: RC.fg(Colors.grey.shade300),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  tx(_selectedFilterIndex == 1
                                      ? t('no_available_orders')
                                      : t('no_orders')),
                                  style: TextStyle(
                                    color: RC.fg(Colors.grey.shade500),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!_isOnline) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    tx(t('go_online_hint')),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: RC.fg(Colors.grey.shade400),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextButton(
                                    onPressed: _onlineToggleBusy
                                        ? null
                                        : _toggleOnlineStatus,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF16A34A),
                                    ),
                                    child: Text(tx(t('online'))),
                                  ),
                                ] else if (!_locationTrusted) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    tx(t('gps_missing_online_warn')),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: RC.fg(Colors.grey.shade400),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final filtered = _getFilteredOrders();
                          final pad = RegaResponsive.pagePadding(context);
                          final cols = RegaResponsive.gridCountForWidth(
                            constraints.maxWidth,
                            phone: 1,
                            tablet: 2,
                            desktop: 2,
                          );
                          Widget cardFor(Map<String, dynamic> order) {
                            final isAvailable =
                                order['statusType'] == 'available';
                            return _buildListOrderCard(
                              id: order['id'],
                              merchant: order['merchant'],
                              customer: order['customer'],
                              status: t(order['statusKey']),
                              price: order['price'],
                              totalAmount:
                                  order['totalAmount']?.toString() ??
                                      order['price']?.toString() ??
                                      '',
                              time: order['time'],
                              statusColor: order['statusColor'],
                              statusBg: order['statusBg'],
                              onTap: () => _showOrderDetailsModal(order),
                              trailingAction: isAvailable
                                  ? _buildAcceptOrderButton(order)
                                  : null,
                            );
                          }

                          // Content-height cards (no fixed aspect ratio = no empty space).
                          if (cols >= 2) {
                            final rows = <Widget>[];
                            for (var i = 0; i < filtered.length; i += cols) {
                              final slice = filtered.skip(i).take(cols).toList();
                              rows.add(
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: i + cols < filtered.length ? 10 : 0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var j = 0; j < cols; j++) ...[
                                        if (j > 0) const SizedBox(width: 10),
                                        Expanded(
                                          child: j < slice.length
                                              ? cardFor(slice[j])
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(pad),
                              children: rows,
                            );
                          }
                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(pad),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                cardFor(filtered[index]),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalGridCell({
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: RC.fg(const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            tx(value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: emphasize ? 13 : 12,
              fontWeight: FontWeight.w900,
              color: RC.fg(
                emphasize ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsModal(Map<String, dynamic> order) {
    final isActive = order['statusType'] == 'active';
    final isAvailable = order['statusType'] == 'available';
    final divider = BorderSide(color: RC.bg(const Color(0xFFE2E8F0)), width: 1);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: RegaResponsive.dialogMaxWidth(ctx, cap: 540),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        formatOrderCode(order['id']),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: RC.fg(const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: order['statusBg'] as Color?,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tx(t(order['statusKey'].toString())),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: order['statusColor'] as Color?,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ٢×٢ وەک وێنەی ٢: کڕیار | فرۆشیار / کۆی گشتی | کرێی گەیاندن
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // RTL: یەکەم = ڕاست → فرۆشیار ڕاست، کڕیار چەپ (وەک وێنە)
                            Expanded(
                              child: _buildModalGridCell(
                                label: t('label_seller'),
                                value: '${order['merchant'] ?? ''}',
                              ),
                            ),
                            VerticalDivider(width: 1, thickness: 1, color: divider.color),
                            Expanded(
                              child: _buildModalGridCell(
                                label: t('label_customer'),
                                value: '${order['customer'] ?? ''}',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: divider.color),
                      IntrinsicHeight(
                        child: Row(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildModalGridCell(
                                label: t('delivery_fee_label'),
                                value: '${order['price'] ?? ''}',
                                emphasize: true,
                              ),
                            ),
                            VerticalDivider(width: 1, thickness: 1, color: divider.color),
                            Expanded(
                              child: _buildModalGridCell(
                                label: t('order_total'),
                                value: '${order['totalAmount'] ?? order['price'] ?? ''}',
                                emphasize: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (isAvailable)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(_claimAvailableOrder(order));
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      tx(t('accept_order')),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  )
                else if (isActive)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _isOrderCardVisible = true);
                      _goTab(0);
                    },
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: Text(
                      tx('پیشاندان لەسەر نەخشەی زیندوو'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tx('داخستن')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptOrderButton(Map<String, dynamic> order) {
    final dbId = order['dbId'] as int?;
    final busy = dbId != null && _claimingOrderId == dbId;
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF86EFAC),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: busy ? null : () => unawaited(_claimAvailableOrder(order)),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_rounded, size: 18),
        label: Text(
          tx(busy ? t('accepting_order') : t('accept_order')),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String count, bool isSelected, {bool isDanger = false, VoidCallback? onTap}) {
    final selectedBg = const Color(0xFF16A34A);
    final idleBg = RC.bg(const Color(0xFFF1F5F9));
    final selectedFg = Colors.white;
    final idleFg = RC.fg(const Color(0xFF64748B));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : idleBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedBg : RC.bg(const Color(0xFFE2E8F0)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedBg.withOpacity(0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tx(label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? selectedFg : idleFg,
              ),
            ),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                tx(count),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? selectedFg
                      : (isDanger
                          ? RC.fg(const Color(0xFFEF4444))
                          : idleFg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCardMetaCell({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    bool emphasizeValue = false,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: RC.bg(iconBg),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            tx(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: emphasizeValue ? 12.5 : 12,
              fontWeight: FontWeight.w800,
              color: RC.fg(
                emphasizeValue
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListOrderCard({
    required String id,
    required String merchant,
    required String customer,
    required String status,
    required String price,
    required String totalAmount,
    required String time,
    required Color statusColor,
    required Color statusBg,
    VoidCallback? onTap,
    Widget? trailingAction,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: RC.bg(Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: RC.bg(Colors.black).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      tx(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      formatOrderCode(id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: RC.fg(const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Image-2 style: icon rows (customer | merchant)
            Row(
              children: [
                Expanded(
                  child: _buildOrderCardMetaCell(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFDBEAFE),
                    title: customer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOrderCardMetaCell(
                    icon: Icons.storefront_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFEF3C7),
                    title: merchant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Image-2 style: delivery fee | total
            Row(
              children: [
                Expanded(
                  child: _buildOrderCardMetaCell(
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFEDE9FE),
                    title: price,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOrderCardMetaCell(
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF16A34A),
                    iconBg: const Color(0xFFDCFCE7),
                    title: totalAmount,
                    emphasizeValue: true,
                  ),
                ),
              ],
            ),
            if (trailingAction != null) ...[
              const SizedBox(height: 10),
              trailingAction,
            ],
          ],
        ),
      ),
    );
  }

  // شریتی خوارەوەی ئەپ — brand-green pill active tab (icon + label)
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        border: Border(
          top: BorderSide(
            color: RC.bg(Color(0xFFF1F5F9)),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Color(0xFF0F172A)).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 620),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: RegaResponsive.isPhone(context) ? 6 : 10,
                vertical: 8,
              ),
              child: Row(
                children: [
                  _buildBottomNavItem(
                    index: 0,
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map_rounded,
                    label: t('home'),
                  ),
                  _buildBottomNavItem(
                    index: 1,
                    icon: Icons.format_list_numbered_rounded,
                    activeIcon: Icons.receipt_long_rounded,
                    label: t('orders'),
                  ),
                  _buildBottomNavItem(
                    index: 2,
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: t('earnings'),
                  ),
                  _buildBottomNavItem(
                    index: 3,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: t('profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentTabIndex == index;
    final phone = RegaResponsive.isPhone(context);
    const pillGreen = Color(0xFF16A34A);

    return Expanded(
      flex: isSelected ? (phone ? 3 : 2) : 2,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _goTab(index);
        },
        splashColor: pillGreen.withValues(alpha: 0.2),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? (phone ? 10 : 14) : 8,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: isSelected ? pillGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? Colors.white
                        : RC.fg(const Color(0xFF0F172A)),
                    size: phone ? 20 : 22,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      tx(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: phone ? 12 : 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
class DeliveryMapPainterWidget extends StatefulWidget {
  final OrderStatus status;

  const DeliveryMapPainterWidget({super.key, required this.status});

  @override
  State<DeliveryMapPainterWidget> createState() => _DeliveryMapPainterWidgetState();
}

class _DeliveryMapPainterWidgetState extends State<DeliveryMapPainterWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _MapCanvasPainter(
            pulseValue: _pulseController.value,
            status: widget.status,
          ),
        );
      },
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final double pulseValue;
  final OrderStatus status;

  _MapCanvasPainter({required this.pulseValue, required this.status});

  @override
  void paint(Canvas canvas, Size size) {
    // ١. باکگراوندی ڕووی نەخشە
    final bgPaint = Paint()..color = RC.bg(Color(0xFFE5E7EB));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ٢. ناوچە سەوزەکان (پارکەکان)
    final parkPaint = Paint()..color = RC.bg(Color(0xFFDCFCE7));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.1, size.width * 0.35, size.height * 0.22), const Radius.circular(20)), parkPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.55, size.height * 0.45, size.width * 0.38, size.height * 0.18), const Radius.circular(24)), parkPaint);

    // ٣. ڕێگاکان (Street grid)
    final roadPaint = Paint()
      ..color = RC.bg(Colors.white)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = RC.bg(Color(0xFFD1D5DB))
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // هێڵەکانی شەقام
    final path = Path()
      ..moveTo(0, size.height * 0.25)
      ..lineTo(size.width, size.height * 0.28)
      ..moveTo(0, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.45)
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.25, size.height)
      ..moveTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.68, size.height);

    canvas.drawPath(path, roadBorderPaint);
    canvas.drawPath(path, roadPaint);

    // ٤. شوێنی شۆفێر، فرۆشیار و کڕیار
    final driverOffset = Offset(size.width * 0.35, size.height * 0.38);
    final vendorOffset = Offset(size.width * 0.68, size.height * 0.27);
    final customerOffset = Offset(size.width * 0.28, size.height * 0.18);

    // هێڵی ڕێڕەو (Route Path)
    final routePaint = Paint()
      ..color = RC.bg(Color(0xFF00E676))
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final routePath = Path()
      ..moveTo(driverOffset.dx, driverOffset.dy)
      ..lineTo(vendorOffset.dx, vendorOffset.dy)
      ..lineTo(customerOffset.dx, customerOffset.dy);

    canvas.drawPath(routePath, routePaint);

    // ٥. نەخشاندنی نیشانەکانی فرۆشیار (چێشتخانە)
    _drawMarker(
      canvas: canvas,
      center: vendorOffset,
      icon: Icons.storefront,
      color: RC.bg(Color(0xFFEA580C)),
      label: tx('دیوان'),
    );

    // ٦. نەخشاندنی نیشانەی کڕیار (ماڵ)
    _drawMarker(
      canvas: canvas,
      center: customerOffset,
      icon: Icons.home,
      color: RC.bg(Color(0xFF0284C7)),
      label: tx('ئاراس'),
    );

    // ٧. نەخشاندنی شۆفێر بە لەرەی بازنەیی (Pulse Wave)
    final pulsePaint = Paint()
      ..color = RC.bg(Color(0xFF00E676)).withOpacity(1.0 - pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(driverOffset, 16 + (pulseValue * 22), pulsePaint);

    final driverBgPaint = Paint()..color = RC.bg(Color(0xFF00E676));
    canvas.drawCircle(driverOffset, 18, driverBgPaint);

    final driverBorderPaint = Paint()
      ..color = RC.bg(Colors.black)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(driverOffset, 18, driverBorderPaint);

    _drawIconOnCanvas(canvas, Icons.two_wheeler, driverOffset, RC.bg(Colors.black), 18);
  }

  void _drawMarker({
    required Canvas canvas,
    required Offset center,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    // باکگراوندی دەرەوە
    canvas.drawCircle(center, 16, Paint()..color = color);
    canvas.drawCircle(center, 16, Paint()..color = RC.bg(Colors.white)..strokeWidth = 2..style = PaintingStyle.stroke);

    // ئایکۆن
    _drawIconOnCanvas(canvas, icon, center, RC.bg(Colors.white), 16);

    // نیشانەی تێکست
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: RC.fg(Colors.black87),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: RC.bg(Colors.white),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    textPainter.paint(canvas, Offset(center.dx - (textPainter.width / 2), center.dy + 18));
  }

  void _drawIconOnCanvas(Canvas canvas, IconData icon, Offset offset, Color color, double size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(offset.dx - (textPainter.width / 2), offset.dy - (textPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.status != status;
  }
}

// ---------------------------------------------------------
// یاریدەدەرەکانی ژمارە و ڕێکخستن
// ---------------------------------------------------------

class PositionMesh extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Widget child;

  const PositionMesh({super.key, this.top, this.right, this.bottom, this.left, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(top: top, right: right, bottom: bottom, left: left, child: child);
  }
}

