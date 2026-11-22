import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // 📍 پێویستە ئەم پاکێجە لە pubspec.yaml زیاد کرابێت
import 'package:permission_handler/permission_handler.dart'; // 🔔 بۆ داواکردنی ڕێگەپێدانی نۆتیکەیشن و ئەوانی تر
import 'package:connectivity_plus/connectivity_plus.dart'; // 🛡️ بۆ پشکنینی VPN و ئینتەرنێت
import 'package:safe_device/safe_device.dart'; // 🔒 بۆ پشکنینی هاک و ئیمۆلیتۆر
import 'package:screen_protector/screen_protector.dart'; // 🔒 بۆ ڕێگری لە وێنەگرتنی شاشە
// Platform import removed to fix unused warning
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'live_order_tracker.dart';
import 'map/mapbox_geocoding.dart';
import 'customer_api_service.dart';
import 'blocked_account.dart';
import 'rega_mobile.dart';
import 'l10n/customer_l10n.dart';
import 'models/customer_models.dart';
import 'app/providers.dart';
import 'app/app_router.dart';
import 'state/cart_notifier.dart';
import 'state/locale_notifier.dart';
import 'iraq_phone_formatter.dart';
import 'state/location_notifier.dart';
import 'state/navigation_notifier.dart';
import 'state/orders_notifier.dart';
import 'state/session_notifier.dart';
import 'services/push_notifications.dart';
import 'services/customer_notification_sound.dart';

import 'direct_request_screen.dart';
import 'onboarding/onboarding_notifier.dart';
import 'rega_i18n.dart';
import 'rega_colors.dart';
export 'models/customer_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Native only — lock-screen push + 3s in-app banner.
  if (!kIsWeb) {
    await PushNotifications.instance.init();
  }
  runApp(buildCustomerProviders(child: const RegaApp()));
}

/// ============================================================================
/// 🚀 REGA - ڕێگا (تەواوی کۆدی فڵاتەر / Full Flutter App Code)
/// ----------------------------------------------------------------------------
/// ئەم کۆدە 100% چاککراوەتەوە و بێ ئیرۆرە. دەتوانیت تەواوی ئەم کۆدە کۆپی بکەیت و لە Visual Studio Code
/// لە فایلی `lib/main.dart` دایبنێیت.
/// ============================================================================

class RegaApp extends StatefulWidget {
  const RegaApp({super.key});

  @override
  State<RegaApp> createState() => _RegaAppState();
}

class _RegaAppState extends State<RegaApp> {
  GoRouter? _router;
  Listenable? _routerRefresh;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null) return;
    final session = context.read<SessionNotifier>();
    final onboarding = context.read<OnboardingNotifier>();
    _routerRefresh = Listenable.merge([session, onboarding]);
    _router = createCustomerRouter(
      refreshListenable: _routerRefresh!,
      loginBuilder: (context) {
        final locale = context.watch<LocaleNotifier>();
        return MainScreen(
          currentLang: locale.langCode,
          onLanguageChange: (lang) => context.read<LocaleNotifier>().setLanguage(lang),
          initialTabIndex: 4,
          openStoreId: null,
          forceAuthOnly: true,
        );
      },
      shellBuilder: (context, tabIndex, openStoreId) {
        final locale = context.watch<LocaleNotifier>();
        return MainScreen(
          currentLang: locale.langCode,
          onLanguageChange: (lang) => context.read<LocaleNotifier>().setLanguage(lang),
          initialTabIndex: tabIndex,
          openStoreId: openStoreId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleNotifier>();
    // Drives tx(): every on-screen string follows the selected language.
    RegaI18n.setLang(locale.langCode);
    RC.setDark(locale.isDark);
    final router = _router;
    if (router == null) return const SizedBox.shrink();
    return MaterialApp.router(
      title: tx('REGA - ڕێگا'),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'NotoKufiArabic',
        primaryColor: const Color(0xFFFAC800),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFAC800),
          brightness: Brightness.light,
          primary: const Color(0xFFFAC800),
          secondary: const Color(0xFF18181B),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'NotoKufiArabic',
        primaryColor: const Color(0xFFFAC800),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFAC800),
          brightness: Brightness.dark,
          primary: const Color(0xFFFAC800),
          secondary: const Color(0xFF00E676),
          surface: const Color(0xFF111827),
        ),
      ),
      themeMode: locale.themeMode,
      builder: (context, child) {
        final wrapped = RegaResponsive.appBuilder(
          context,
          DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'NotoKufiArabic'),
            child: child ?? const SizedBox(),
          ),
          direction: locale.textDirection,
        );
        return PushBannerHost(child: wrapped);
      },
    );
  }
}

// ============================================================================
// 🖼️ CONFIGURATION & LOGO (ASSET PNG & URL)
// ============================================================================
// 1️⃣ بۆ وێنەی PNG لەناو VS Code / Flutter لە فۆڵدەری assets2:
// وێنەی لۆگۆکەت لە فۆڵدەری assets2 ی ئەپەکەت دابنێ (وەک: 'assets2/logo.png')
// هەروەها لە فایلی pubspec.yaml ئەمە دیاری بکە:
// flutter:
//   assets:
//     - assets2/
String appLogoAssetPath = 'assets1/logo.png';
String profileLogoAssetPath = 'assets2/logo2.png';

// 2️⃣ یان بۆ لینکی ئینتەرنێت (Network Image):
String appLogoUrl = '';
// ============================================================================
// 📦 DATA MODELS & STRUCTURES
// ============================================================================

// ============================================================================
// LIVE DATA (filled from backend bootstrap — no fake seed catalog)
// ============================================================================

final List<StoreItem> allStores = [];

final List<ProductItem> allProducts = [];

// ============================================================================
// 📱 MAIN APPLICATION SCREEN WITH NAVIGATION & STATE
// ============================================================================

class MainScreen extends StatefulWidget {
  final String currentLang;
  final Function(String) onLanguageChange;
  final int initialTabIndex;
  final String? openStoreId;
  /// When true, only the login/register UI is shown (auth gate).
  final bool forceAuthOnly;

  const MainScreen({
    super.key,
    required this.currentLang,
    required this.onLanguageChange,
    this.initialTabIndex = 0,
    this.openStoreId,
    this.forceAuthOnly = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  int _unreadNotificationCount = 0;
  List<Map<String, dynamic>> _dynamicNotifications = [];
  String _searchQuery = '';
  String _selectedCategory = 'گشتی';
  StoreItem? _selectedStore;
  String? _selectedSubCategory;

  // Provider-backed app state (source of truth for cart / session / location / orders)
  List<CartEntry> get _cart => context.read<CartNotifier>().mutableItems;
  UserProfile? get _userProfile => context.read<SessionNotifier>().user;
  set _userProfile(UserProfile? value) {
    final session = context.read<SessionNotifier>();
    if (value == null) {
      session.signOut();
    } else {
      session.signIn(value);
    }
  }

  bool get _isLoginMode => context.read<SessionNotifier>().isLoginMode;
  set _isLoginMode(bool value) => context.read<SessionNotifier>().setLoginMode(value);

  List<OrderItem> get _orders => context.read<OrdersNotifier>().mutableOrders;

  Neighborhood? get _selectedNeighborhood => context.read<LocationNotifier>().neighborhood;
  Neighborhood? get _selectedNeighborhoodOrNull => _selectedNeighborhood;
  set _selectedNeighborhood(Neighborhood? value) =>
      context.read<LocationNotifier>().setNeighborhood(value);

  double? get _pinnedCustomerLat => context.read<LocationNotifier>().pinnedLat;
  set _pinnedCustomerLat(double? value) {
    final loc = context.read<LocationNotifier>();
    if (value == null && loc.pinnedLng == null) {
      loc.clearPin();
    } else {
      loc.updateCoords(lat: value);
    }
  }

  double? get _pinnedCustomerLng => context.read<LocationNotifier>().pinnedLng;
  set _pinnedCustomerLng(double? value) {
    final loc = context.read<LocationNotifier>();
    if (value == null && loc.pinnedLat == null) {
      loc.clearPin();
    } else {
      loc.updateCoords(lng: value);
    }
  }

  String? get _deliveryPlaceNote => context.read<LocationNotifier>().placeNote;
  set _deliveryPlaceNote(String? value) => context.read<LocationNotifier>().setPlaceNote(value);

  String? get _resolvedPlaceName => context.read<LocationNotifier>().resolvedPlaceName;
  set _resolvedPlaceName(String? value) =>
      context.read<LocationNotifier>().setResolvedPlaceName(value);

  /// Home bar / confirm chips — never a frozen Flutter neighborhood const.
  String get _deliveryDisplayLabel {
    final label = context.read<LocationNotifier>().displayPlaceLabel;
    if (label != null && label.isNotEmpty) return label;
    return _t('شوێنی گەیاندن هەڵبژێرە');
  }

  bool get _hasDeliveryPlaceChosen => context.read<LocationNotifier>().hasChosenPlace;

  int get _deliveryFeeOrZero {
    if (_cart.isNotEmpty) {
      final sId = _cart.first.product.storeId;
      final s = allStores.where((st) => st.id == sId).firstOrNull;
      if (s != null && s.isFreeDelivery) return 0;
    }
    if (_selectedStore != null && _selectedStore!.isFreeDelivery) return 0;
    return context.read<LocationNotifier>().deliveryFeeOrZero;
  }

  // Dynamic Marketplace Data from Backend (Categories, Banners)
  List<Map<String, dynamic>> _dynamicCategories = [];
  List<Map<String, dynamic>> _dynamicBanners = [];
  /// storeId -> menu category name_ku -> {image_url, secondary_image_url, sort_order}
  final Map<String, Map<String, Map<String, dynamic>>> _storeMenuCategoryMeta = {};

  IconData _getCategoryIcon(String catName) {
    if (catName.contains('خواردن') || catName.contains('ڕێستۆرانت')) return Icons.restaurant_rounded;
    if (catName.contains('مارکێت') || catName.contains('سوپەرمارکێت')) return Icons.store_rounded;
    if (catName.contains('میوە') || catName.contains('سەوزە')) return Icons.eco_rounded;
    if (catName.contains('فاست') || catName.contains('بەرگر') || catName.contains('پیتزا')) return Icons.fastfood_rounded;
    if (catName.contains('شیرینی') || catName.contains('کێک') || catName.contains('باقلاوە')) return Icons.bakery_dining_rounded;
    if (catName.contains('کافێ') || catName.contains('قاوە')) return Icons.coffee_rounded;
    if (catName.contains('گۆشت') || catName.contains('مریشک') || catName.contains('قەساب')) return Icons.set_meal_outlined;
    if (catName.contains('نان') || catName.contains('سەموون')) return Icons.bakery_dining_outlined;
    if (catName.contains('کۆسمەتیک') || catName.contains('جوانکاری')) return Icons.face_retouching_natural_rounded;
    return Icons.category_rounded;
  }

  // Internet Connectivity Guard State
  bool _isOffline = false;
  bool _isCheckingConnection = false;
  Timer? _connectivityTimer;
  Timer? _backendOrdersTimer;

  /// Orders already auto-opened on the live motorcycle map (avoid repeat popups).
  final Set<String> _autoOpenedTrackOrders = {};

  // App State (cart / session / location / orders live in Provider notifiers)
  bool _isGpsLocating = false;
  String _selectedOrderFilter = 'هەموو';
  final Set<String> _favoriteStoreIds = {'store_sarwar'};

  String _currentLanguage = 'کوردی';
  bool _isLanguageExpanded = false;

  bool get _profileLtr => _currentLanguage == 'English';

  IconData get _settingsChevronIcon =>
      _isLanguageExpanded ? Icons.expand_more_rounded : (_profileLtr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded);

  // Profile Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _otpCtrl;
  late TextEditingController _confirmPasswordCtrl;
  bool _isAccountRenewal = false;
  int _accountRenewalStep = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Security & Integrity State
  bool _isLocationAuthorized = kIsWeb;
  bool _isCheckingLocation = !kIsWeb;
  bool _isVpnActive = false; // 🛡️ بارودۆخی VPN
  bool _isDeviceSafe = true; // 🔒 ئایا ئامێرەکە پارێزراوە؟
  bool _isCheckingSecurity = !kIsWeb; // 🔒 پشکنینی ئاسایش
  String _securityErrorMessage = "";

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, 4);
    _currentLanguage = CustomerL10n.displayName(widget.currentLang);
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _otpCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _loadProfile();
    _loadSavedLanguage();
    _syncMarketplaceFromBackend();
    _startAppInitialization();
    PushNotifications.instance.onNotificationOpened = _onPushOpened;
    PushNotifications.instance.onForegroundMessage = (_) {
      unawaited(_syncNotificationsFromBackend());
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameCtrl.text = _userProfile?.name ?? '';
      _phoneCtrl.text = _userProfile?.phone ?? '';
      _applyOpenStoreFromRoute();
      unawaited(_runFirstLoginPermissionFlow());
      unawaited(PushNotifications.instance.syncTokenToBackend());
    });
  }

  /// After first login/sign-up: notification prompt first, then location.
  Future<void> _runFirstLoginPermissionFlow() async {
    await _maybeShowFirstLoginNotificationDialog();
    if (!mounted) return;
    await _maybeShowFirstLoginLocationDialog();
  }

  Future<void> _onPushOpened(PushBannerPayload payload) async {
    if (!mounted) return;
    await _syncNotificationsFromBackend();
    if (!mounted) return;
    final data = payload.data;
    final type = data['type']?.toString() ?? 'general';
    final tag = data['tag']?.toString() ?? '';
    final orderRef = data['order_ref']?.toString() ??
        data['order_number']?.toString() ??
        _extractOrderRefFromText('${payload.title} ${payload.body}');
    final storeId = data['store_id'] != null ? 'db_store_${data['store_id']}' : null;
    final catName = data['category_name']?.toString();

    final isOrderNotif = type == 'order' || tag.contains('گەیاندن') || orderRef != null;
    if (isOrderNotif && orderRef != null) {
      await _syncCustomerOrdersFromBackend();
      if (!mounted) return;
      OrderItem? order;
      try {
        order = _orders.firstWhere((o) => o.id.toUpperCase() == orderRef.toUpperCase());
      } catch (_) {
        order = null;
      }
      if (order != null) {
        final target = order;
        _goTab(3);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_isLiveTrackStatus(target.status)) {
            _showLiveTrackingModal(target);
          } else {
            _showReceiptModal(target);
          }
        });
        return;
      }
    }

    if (storeId != null && allStores.isNotEmpty) {
      StoreItem? store;
      try {
        store = allStores.firstWhere((s) => s.id == storeId);
      } catch (_) {
        store = null;
      }
      if (store != null) {
        setState(() {
          _selectedStore = store;
          _selectedSubCategory = null;
        });
        _goTab(0);
        return;
      }
    }

    if (catName != null && catName.trim().isNotEmpty) {
      setState(() => _selectedCategory = catName);
      _goTab(0);
      return;
    }

    // Fallback: open the in-app notifications sheet.
    if (mounted) {
      unawaited(_openNotificationsModal());
    }
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLang != widget.currentLang) {
      setState(() {
        _currentLanguage = CustomerL10n.displayName(widget.currentLang);
      });
    }
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        _currentIndex != widget.initialTabIndex) {
      setState(() {
        _currentIndex = widget.initialTabIndex.clamp(0, 4);
        if (widget.openStoreId == null) _selectedStore = null;
      });
    }
    if (oldWidget.openStoreId != widget.openStoreId) {
      _applyOpenStoreFromRoute();
    }
  }

  void _applyOpenStoreFromRoute() {
    final id = widget.openStoreId;
    if (id == null || id.isEmpty) return;
    StoreItem? match;
    for (final s in allStores) {
      if (s.id == id) {
        match = s;
        break;
      }
    }
    if (match != null && mounted) {
      setState(() => _selectedStore = match);
    }
  }

  void _goTab(int index) {
    final path = NavigationNotifier.pathForIndex(index);
    context.read<NavigationNotifier>().setTabIndex(index);
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _selectedStore = null;
      });
    }
    context.go(path);
  }

  // 🚀 زنجیرەی چالاککردنی ئەپ (Security -> Notification -> Location)
  Future<void> _startAppInitialization() async {
    // 1. پشکنینی ئینتەرنێت و VPN سەرەتا
    await _checkInternetConnection(silent: true);
    await _checkVpnStatus();

    // 🔄 پشکنینی بەردەوام بۆ پەیوەندی
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkInternetConnection(silent: true);
      _checkVpnStatus();
    });

    // 2. پشکنینی ئاسایشی ئامێر (Security Check)
    await _checkSecurity();
    if (!_isDeviceSafe) return; // ئەگەر ئامێرەکە پارێزراو نەبوو، لێرە دەوەستێت

    // 3. Notification permission is deferred to first login / sign-up
    //    (native OS dialog — see _maybeShowFirstLoginNotificationDialog).

    // 4. داواکردنی ڕێگەپێدانی شوێن (Location)
    await _requestLocationPermission();
  }

  // 📍 فەنکشن بۆ داواکردنی ڕێگەپێدانی GPS لە مۆبایل (بە مەرجی ناچاری)
  /// [forcePrompt] true after first-login dialog — also requests on web.
  Future<void> _requestLocationPermission({bool forcePrompt = false}) async {
    // Soft boot on web: don't block the app; wait for first-login dialog.
    if (kIsWeb && !forcePrompt) {
      if (mounted) {
        setState(() {
          _isLocationAuthorized = true;
          _isCheckingLocation = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isCheckingLocation = true);

    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (forcePrompt) {
            try {
              await Geolocator.openLocationSettings();
            } catch (_) {}
          }
          if (mounted) {
            setState(() {
              // Web-style soft fail when prompted from dialog: don't lock the app.
              _isLocationAuthorized = forcePrompt ? true : false;
              _isCheckingLocation = false;
            });
          }
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (forcePrompt && permission == LocationPermission.deniedForever && !kIsWeb) {
          try {
            await Geolocator.openAppSettings();
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            // After the explain dialog, never hard-block — user can pick on map.
            _isLocationAuthorized = forcePrompt || kIsWeb ? true : false;
            _isCheckingLocation = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLocationAuthorized = true;
          _isCheckingLocation = false;
        });
      }

      // دوای ڕێگەپێدان، شوێنی ڕاستەقینەی بەکارهێنەر بدۆزەرەوە
      await _detectUserLocation(silent: !forcePrompt);
    } catch (_) {
      if (mounted) {
        setState(() {
          // لە وێب/هەڵەدا ڕێگە بدە بەکارهێنەر شوێن بە دەستی هەڵبژێرێت
          _isLocationAuthorized = kIsWeb || forcePrompt ? true : _isLocationAuthorized;
          _isCheckingLocation = false;
        });
      }
    }
  }

  /// Closest admin/backend zone within [KalarGeoCatalog.maxZoneMatchMeters], else null.
  /// Used for associating delivery fee zones around Kalar & Rizgari.
  Neighborhood? _closestNeighborhoodTo(double lat, double lng, {double? maxMeters}) {
    if (kalarNeighborhoods.isEmpty) return null;
    final pt = LatLng(lat, lng);
    final localMatch = MapboxGeocoding.matchLocalPlace(pt);
    if (localMatch != null) {
      for (final n in kalarNeighborhoods) {
        if (n.id == localMatch.id ||
            n.name.trim() == localMatch.nameKu ||
            n.name.contains(localMatch.nameKu) ||
            localMatch.nameKu.contains(n.name.trim())) {
          return n;
        }
      }
    }

    Neighborhood? closest;
    double minDistance = double.infinity;
    for (final n in kalarNeighborhoods) {
      final resolvedCoord = MapboxGeocoding.resolveKnownCoordForName(
        n.name,
        nameEn: n.nameEn,
        code: n.id,
        rawLat: n.lat ?? KalarGeoCatalog.neighborhoodCoords[n.id]?.latitude,
        rawLng: n.lng ?? KalarGeoCatalog.neighborhoodCoords[n.id]?.longitude,
      );
      final geoLat = resolvedCoord?.latitude ?? n.lat ?? KalarGeoCatalog.neighborhoodCoords[n.id]?.latitude;
      final geoLng = resolvedCoord?.longitude ?? n.lng ?? KalarGeoCatalog.neighborhoodCoords[n.id]?.longitude;
      if (geoLat == null || geoLng == null) continue;
      final dist = Geolocator.distanceBetween(lat, lng, geoLat, geoLng);
      if (dist < minDistance) {
        minDistance = dist;
        closest = n;
      }
    }
    if (closest == null) return null;
    final limit = maxMeters ?? KalarGeoCatalog.maxZoneMatchMeters;
    if (minDistance > limit) return null;
    return closest;
  }

  /// Strict neighborhood/compound name for [lat], [lng] — only returns a specific
  /// neighborhood name when the pin is inside its geofence or within 900m,
  /// preventing wrong distant neighborhood names in new housing complexes.
  String? _strictNeighborhoodNameAt(double lat, double lng) {
    final pt = LatLng(lat, lng);
    final local = MapboxGeocoding.matchLocalPlace(pt);
    if (local != null) return local.nameKu;
    final strictZone = _closestNeighborhoodTo(
      lat,
      lng,
      maxMeters: KalarGeoCatalog.strictNeighborhoodLabelMeters,
    );
    return strictZone?.name;
  }

  Future<String?> _reverseGeocodeLabel(double lat, double lng) {
    return MapboxGeocoding.reversePlaceName(LatLng(lat, lng));
  }

  /// دۆزینەوەی شوێنی GPS ی بەکارهێنەر و نوێکردنەوەی گەڕەک
  Future<bool> _detectUserLocation({bool silent = false}) async {
    if (_isGpsLocating) return false;
    if (mounted) setState(() => _isGpsLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('تکایە GPS / Location مۆبایلەکەت هەڵبکە')),
              backgroundColor: RC.bg(Color(0xFFDC2626)),
            ),
          );
          await Geolocator.openLocationSettings();
        }
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('ڕێگەپێدانی لۆکەیشن پێویستە بۆ دیاریکردنی شوێنەکەت')),
              backgroundColor: RC.bg(Color(0xFFDC2626)),
            ),
          );
        }
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('لە ڕێکخستنی مۆبایل ڕێگەپێدانی لۆکەیشن چالاک بکە')),
              backgroundColor: RC.bg(Color(0xFFDC2626)),
            ),
          );
          await Geolocator.openAppSettings();
        }
        return false;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('نەتوانرا شوێنەکەت بدۆزرێتەوە. دووبارە هەوڵبدەرەوە')),
              backgroundColor: RC.bg(Color(0xFFDC2626)),
            ),
          );
        }
        return false;
      }

      final fixedPos = pos;
      final closest = _closestNeighborhoodTo(fixedPos.latitude, fixedPos.longitude);
      final strictName = _strictNeighborhoodNameAt(fixedPos.latitude, fixedPos.longitude);
      final geocoded = await _reverseGeocodeLabel(fixedPos.latitude, fixedPos.longitude);
      if (mounted) {
        final label = geocoded ?? strictName;
        // Preserve any manual user input in "ناوی شوێن" (clearPlaceNote: false).
        context.read<LocationNotifier>().setPin(
          lat: fixedPos.latitude,
          lng: fixedPos.longitude,
          neighborhood: closest,
          clearNeighborhood: closest == null,
          clearPlaceNote: false,
          resolvedPlaceName: label,
          clearResolvedPlaceName: label == null,
        );
        setState(() {
          _isLocationAuthorized = true;
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tx('🎯 شوێنەکەت دیاریکرا: ${label ?? '${fixedPos.latitude.toStringAsFixed(4)}, ${fixedPos.longitude.toStringAsFixed(4)}'}'),
              ),
              backgroundColor: RC.bg(Color(0xFF059669)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      return true;
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('هەڵەی GPS. تکایە دووبارە هەوڵبدەرەوە')),
            backgroundColor: RC.bg(Color(0xFFDC2626)),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isGpsLocating = false);
    }
  }

  // 🔒 پشکنینی پڕۆفیشناڵ بۆ ئاسایشی ئامێرەکە
  Future<void> _checkSecurity() async {
    if (kIsWeb) {
      setState(() {
        _isCheckingSecurity = false;
        _isDeviceSafe = true;
      });
      return;
    }

    try {
      // 1. ڕێگەدان بە وێنەگرتنی شاشە (Screen Recording / Screenshot ڕێگەپێدراوە)
      if (!kIsWeb) {
        await ScreenProtector.preventScreenshotOff();
      }

      bool isJailBroken = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;
      bool isDevelopmentMode = await SafeDevice.isDevelopmentModeEnable;

      if (isJailBroken) {
        _securityErrorMessage = "ئەم ئامێرە هاککراوە (Root/Jailbreak). بۆ پاراستنی زانیارییەکانت، ئەپەکە کار ناکات.";
        _isDeviceSafe = false;
      } else if (!isRealDevice) {
        _securityErrorMessage = "ڕێگە نادرێت ئەپەکە لەسەر ئیمۆلیتۆر (Emulator) کار بکات.";
        _isDeviceSafe = false;
      } else if (isDevelopmentMode) {
        // تێبینی: دەتوانیت ئەمە چالاک بکەیت بۆ پاراستنی زیاتر، بەڵام بۆ تاقیکردنەوە ڕەنگە کێشە بێت
        // _securityErrorMessage = "تکایە Developer Options بکوژێنەرەوە بۆ بەکارهێنانی ئەپەکە.";
        // _isDeviceSafe = false;
      }

      setState(() => _isCheckingSecurity = false);
    } catch (e) {
      setState(() => _isCheckingSecurity = false);
    }
  }

  // 🔒 شاشەی هۆشداری ئەمنی
  Widget _buildSecurityBlockedScreen() {
    return Scaffold(
      backgroundColor: RC.bg(Colors.white),
      body: RegaResponsive.constrain(
        alignment: Alignment.center,
        maxWidth: 520,
        child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gpp_bad_rounded, size: 80, color: RC.fg(Color(0xFFDC2626))),
            const SizedBox(height: 24),
            Text(
              tx('کێشەی ئەمنی دۆزرایەوە'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              tx(_securityErrorMessage),
              style: TextStyle(fontSize: 14, color: RC.fg(Colors.grey)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              tx('پێویستە ئەپەکە لەسەر مۆبایلی ڕاستەقینە و بەبێ هاک بەکاربێت بۆ پاراستنی زانیارییەکانت.'),
              style: TextStyle(fontSize: 12, color: RC.fg(Colors.redAccent)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ),
    );
  }

  // 🛡️ فەنکشن بۆ پشکنینی VPN
  Future<void> _checkVpnStatus() async {
    if (kIsWeb) return;
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.vpn)) {
      if (mounted) setState(() => _isVpnActive = true);
    } else {
      if (mounted) setState(() => _isVpnActive = false);
    }
  }

  // 🛡️ شاشەی قەدەغەکردنی VPN
  Widget _buildVpnBlockedScreen() {
    return Scaffold(
      backgroundColor: RC.bg(Colors.white),
      body: RegaResponsive.constrain(
        alignment: Alignment.center,
        maxWidth: 520,
        child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_update_warning_rounded, size: 80, color: RC.fg(Color(0xFFDC2626))),
            const SizedBox(height: 24),
            Text(
              tx('بەکارهێنانی VPN قەدەغەیە'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              tx('بۆ پاراستنی ئاسایشی ئەپەکە و دیاریکردنی شوێنی ڕاستەقینە، ڕێگە نادرێت بە بەکارهێنانی VPN. تکایە VPN بکوژێنەرەوە و دووبارە هەوڵبدەرەوە.'),
              style: TextStyle(fontSize: 14, color: RC.fg(Colors.grey)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkVpnStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFFAC800)),
                  foregroundColor: RC.fg(Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tx('دووبارە هەوڵبدەرەوە'), style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // 📍 شاشەی ناچاری بۆ چالاککردنی لۆکەیشن
  Widget _buildLocationRequiredScreen() {
    return Scaffold(
      backgroundColor: RC.bg(Colors.white),
      body: RegaResponsive.constrain(
        alignment: Alignment.center,
        maxWidth: 520,
        child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded, size: 80, color: RC.fg(Color(0xFFDC2626))),
            const SizedBox(height: 24),
            Text(
              tx('چالاککردنی لۆکەیشن مەرجە'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              tx('بۆ ئەوەی بتوانیت ئەپەکە بەکاربهێنیت، پێویستە ڕێگەپێدانی لۆکەیشن چالاک بکەیت و GPS موبایلەکەت کار بکات.'),
              style: TextStyle(fontSize: 14, color: RC.fg(Colors.grey)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    await Geolocator.openLocationSettings();
                  }
                  final perm = await Geolocator.checkPermission();
                  if (perm == LocationPermission.deniedForever) {
                    await Geolocator.openAppSettings();
                  }
                  await _requestLocationPermission();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFFAC800)),
                  foregroundColor: RC.fg(Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tx('دووبارە هەوڵبدەرەوە'), style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _backendOrdersTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkInternetConnection({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isCheckingConnection = true);
    }

    bool isConnected = true;
    if (!kIsWeb) {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
        isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        isConnected = false;
      } catch (_) {
        isConnected = false;
      }
    }

    if (mounted) {
      setState(() {
        _isOffline = !isConnected;
        _isCheckingConnection = false;
      });
    }
  }

  Future<void> _syncMarketplaceFromBackend() async {
    try {
      final boot = await CustomerApiService.instance.fetchBootstrap();
      if (boot != null && mounted) {
        final rawZones = boot['neighborhoods'] as List<dynamic>? ?? [];
        if (rawZones.isNotEmpty) {
          kalarNeighborhoods
            ..clear()
            ..addAll(rawZones.map((z) {
              final m = z as Map<String, dynamic>;
              final code = m['code']?.toString();
              final id = (code != null && code.isNotEmpty) ? code : 'n${m['id']}';
              final nameKu = m['name_ku']?.toString() ?? '';
              final nameEn = m['name_en']?.toString() ?? '';
              final rawLat = (m['center_lat'] as num?)?.toDouble();
              final rawLng = (m['center_lng'] as num?)?.toDouble();
              final fixedCoord = MapboxGeocoding.resolveKnownCoordForName(
                nameKu,
                nameEn: nameEn,
                code: id,
                rawLat: rawLat,
                rawLng: rawLng,
              );
              return Neighborhood(
                id: id,
                name: nameKu,
                nameEn: nameEn,
                deliveryFee: (m['delivery_fee'] as num?)?.toInt() ?? 0,
                lat: fixedCoord?.latitude ?? rawLat,
                lng: fixedCoord?.longitude ?? rawLng,
              );
            }));
          KalarGeoCatalog.syncFromZones(
            kalarNeighborhoods.map((n) => (id: n.id, lat: n.lat, lng: n.lng)),
          );
          // Refresh fee/name from backend — never invent a default zone on first launch
          context.read<LocationNotifier>().rebindNeighborhoodFromCatalog(kalarNeighborhoods);
        }

        final rawCategories = boot['categories'] as List<dynamic>? ?? [];
        if (rawCategories.isNotEmpty) {
          // Home grid: only active + is_featured_home from admin (ordered by sort_order).
          // If none are featured, fall back to all active so the grid is not blank after seed/API quirks.
          final homeCats = rawCategories.where((c) {
            final m = c as Map<String, dynamic>;
            final featured = m['is_featured_home'];
            return featured == true || featured == 1;
          }).toList();
          final source = homeCats.isNotEmpty ? homeCats : rawCategories;
          final mapped = source.map((c) {
            final m = c as Map<String, dynamic>;
            final nameKu = m['name_ku']?.toString() ?? '';
            final nameAr = m['name_ar']?.toString() ?? '';
            final nameEn = m['name_en']?.toString() ?? '';
            final imgUrl = RegaApiHost.resolveMediaUrl(m['image_url']?.toString());
            final secUrl = RegaApiHost.resolveMediaUrl(m['secondary_image_url']?.toString());
            return {
              'id': m['id'],
              // Display title resolved at render time via _homeCatTitle (locale-aware).
              'title': nameKu,
              'name_ku': nameKu,
              'name_ar': nameAr,
              'name_en': nameEn,
              // Empty/missing image is OK — grid uses a local placeholder.
              // Always rewrite /storage and :8001 hosts to same-origin /api/v1/media.
              'image': imgUrl,
              'secondaryImage': secUrl,
              'icon': _getCategoryIcon(nameKu),
              // Stable match key for store.category (always Kurdish/source key).
              'catName': nameKu,
              'slug': m['slug']?.toString() ?? '',
              'sort_order': (m['sort_order'] as num?)?.toInt() ?? 0,
            };
          }).toList();
          mapped.sort((a, b) =>
              ((a['sort_order'] as int?) ?? 0).compareTo((b['sort_order'] as int?) ?? 0));
          _dynamicCategories = mapped;
        } else {
          _dynamicCategories = [];
        }

        final rawBanners = boot['banners'] as List<dynamic>? ?? [];
        if (rawBanners.isNotEmpty) {
          _dynamicBanners = rawBanners.map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            final img = m['image_url']?.toString();
            if (img != null && img.isNotEmpty) {
              m['image_url'] = RegaApiHost.resolveMediaUrl(img);
            }
            return m;
          }).toList();
        }

        final rawStores = boot['stores'] as List<dynamic>? ?? [];
        for (final rs in rawStores) {
          final sm = rs as Map<String, dynamic>;
          final dbStoreId = (sm['id'] as num?)?.toInt();
          if (dbStoreId == null) continue;
          final storeKey = 'db_store_$dbStoreId';
          final storeName = sm['name_ku']?.toString() ?? '';
          // Match key stays name_ku; UI labels use name_ar/name_en via locale helper.
          final catMap = sm['category'] as Map<String, dynamic>?;
          final catName = catMap?['name_ku']?.toString() ?? 'خواردنگە';
          final catId = (sm['category_id'] as num?)?.toInt() ??
              (catMap?['id'] as num?)?.toInt();

          final existingIdx = allStores.indexWhere((s) => s.id == storeKey || s.name == storeName);
          final rawBadge = sm['discount_badge']?.toString().trim();
          var mappedStore = StoreItem(
            id: existingIdx >= 0 ? allStores[existingIdx].id : storeKey,
            name: storeName,
            category: catName,
            categoryId: catId,
            rating: ((sm['rating'] as num?) ?? 9.6).toDouble(),
            reviewCount: (sm['review_count'] as num?)?.toInt() ?? 0,
            deliveryTime: sm['delivery_time']?.toString() ?? '20-30 خولەک',
            deliveryFee: (sm['base_delivery_fee'] as num?)?.toInt() ?? (sm['delivery_fee'] as num?)?.toInt() ?? 1500,
            imageUrl: () {
              final cover = RegaApiHost.resolveMediaUrl(sm['cover_url']?.toString());
              return cover.isNotEmpty
                  ? cover
                  : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600';
            }(),
            address: sm['address_ku']?.toString() ?? 'کەلار',
            isOpen: sm['is_online'] == true,
            phone: sm['phone']?.toString() ?? '',
            discountBadge: (rawBadge != null && rawBadge.isNotEmpty) ? rawBadge : null,
            lat: (sm['lat'] as num?)?.toDouble() ?? 34.6836,
            lng: (sm['lng'] as num?)?.toDouble() ?? 45.3189,
          );
          if (existingIdx >= 0) {
            allStores[existingIdx] = mappedStore;
          } else {
            allStores.insert(0, mappedStore);
          }

          final detail = await CustomerApiService.instance.fetchStoreDetails(dbStoreId);
          final menuCats = detail?['store_categories'] as List<dynamic>? ?? [];
          final metaForStore = <String, Map<String, dynamic>>{};
          for (final rawCat in menuCats) {
            final cm = rawCat as Map<String, dynamic>;
            final cName = cm['name_ku']?.toString() ?? '';
            if (cName.isEmpty) continue;
            metaForStore[cName] = {
              'image_url': cm['image_url']?.toString() ?? '',
              'secondary_image_url': cm['secondary_image_url']?.toString() ?? '',
              'sort_order': (cm['sort_order'] as num?)?.toInt() ?? 0,
              'name_ku': cName,
              'name_ar': cm['name_ar']?.toString() ?? '',
              'name_en': cm['name_en']?.toString() ?? '',
            };
          }
          _storeMenuCategoryMeta[mappedStore.id] = metaForStore;
          final prods = detail?['products'] as List<dynamic>? ?? [];
          int bestDiscountPct = 0;
          for (final rp in prods) {
            final pm = rp as Map<String, dynamic>;
            final pid = '${pm['id']}';
            final pName = pm['name_ku']?.toString() ?? '';
            final basePrice = ((pm['price'] ?? 2500) as num).toInt();
            final discPrice = (pm['discount_price'] as num?)?.toInt();
            if (discPrice != null && discPrice > 0 && discPrice < basePrice && basePrice > 0) {
              final pct = (((basePrice - discPrice) / basePrice) * 100).round();
              if (pct > bestDiscountPct) bestDiscountPct = pct;
            }
            final pIdx = allProducts.indexWhere((p) => p.id == pid || (p.storeId == mappedStore.id && p.name == pName));
            final mappedProd = ProductItem(
              id: pid,
              storeId: mappedStore.id,
              name: pName,
              price: (discPrice != null && discPrice > 0 && discPrice < basePrice) ? discPrice : basePrice,
              description: pm['description_ku']?.toString() ?? '',
              imageUrl: () {
                final img = RegaApiHost.resolveMediaUrl(pm['image_url']?.toString());
                return img.isNotEmpty ? img : mappedStore.imageUrl;
              }(),
              category: catName,
              subCategory: pm['store_category']?['name_ku']?.toString(),
            );
            if (pIdx >= 0) {
              allProducts[pIdx] = mappedProd;
            } else {
              allProducts.insert(0, mappedProd);
            }
          }

          // باجی داشکاندن لە ٪ بەرهەمەکانی فرۆشیار — ئەگەر نەبێت باجی ئەدمین دەمێنێتەوە
          final String? computedBadge = bestDiscountPct > 0
              ? 'OFF %$bestDiscountPct'
              : ((rawBadge != null && rawBadge.isNotEmpty) ? rawBadge : null);
          mappedStore = StoreItem(
            id: mappedStore.id,
            name: mappedStore.name,
            category: mappedStore.category,
            categoryId: mappedStore.categoryId,
            rating: mappedStore.rating,
            reviewCount: mappedStore.reviewCount,
            deliveryTime: mappedStore.deliveryTime,
            deliveryFee: mappedStore.deliveryFee,
            imageUrl: mappedStore.imageUrl,
            address: mappedStore.address,
            isOpen: mappedStore.isOpen,
            phone: mappedStore.phone,
            discountBadge: computedBadge,
            lat: mappedStore.lat,
            lng: mappedStore.lng,
          );
          final storeIdx = allStores.indexWhere((s) => s.id == mappedStore.id);
          if (storeIdx >= 0) allStores[storeIdx] = mappedStore;
        }
        final currentDbStoreKeys = rawStores.map((rs) {
          final id = ((rs as Map)['id'] as num?)?.toInt();
          return id != null ? 'db_store_$id' : '';
        }).where((k) => k.isNotEmpty).toSet();
        allStores.removeWhere((s) => s.id.startsWith('db_store_') && !currentDbStoreKeys.contains(s.id));
      }

      await _syncNotificationsFromBackend();
      if (mounted) setState(() {});

      await _syncCustomerOrdersFromBackend();
      _backendOrdersTimer?.cancel();
      _backendOrdersTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) {
          _syncMarketplaceFromBackend();
          _syncCustomerOrdersFromBackend();
        },
      );
    } catch (_) {}
  }

  /// Open a customer-home section and load only vendors assigned to that category_id.
  Future<void> _openHomeCategory(Map<String, dynamic> cat) async {
    final catName = cat['catName']?.toString() ?? '';
    final catId = (cat['id'] as num?)?.toInt();
    if (!mounted) return;
    setState(() {
      _selectedCategory = catName;
      _selectedStore = null;
    });
    if (catId == null) return;
    try {
      final rows = await CustomerApiService.instance.fetchStoresByCategory(catId);
      if (!mounted || rows.isEmpty) return;
      for (final sm in rows) {
        final dbStoreId = (sm['id'] as num?)?.toInt();
        if (dbStoreId == null) continue;
        final storeKey = 'db_store_$dbStoreId';
        final storeName = sm['name_ku']?.toString() ?? '';
        final catMap = sm['category'] as Map<String, dynamic>?;
        final mappedCatName = catMap?['name_ku']?.toString() ?? catName;
        final mappedCatId = (sm['category_id'] as num?)?.toInt() ??
            (catMap?['id'] as num?)?.toInt() ??
            catId;
        final rawBadge = sm['discount_badge']?.toString().trim();
        final mappedStore = StoreItem(
          id: storeKey,
          name: storeName,
          category: mappedCatName,
          categoryId: mappedCatId,
          rating: ((sm['rating'] as num?) ?? 9.6).toDouble(),
          reviewCount: (sm['review_count'] as num?)?.toInt() ?? 0,
          deliveryTime: sm['delivery_time']?.toString() ?? '20-30 خولەک',
          deliveryFee: (sm['base_delivery_fee'] as num?)?.toInt() ?? (sm['delivery_fee'] as num?)?.toInt() ?? 1500,
          imageUrl: () {
            final cover = RegaApiHost.resolveMediaUrl(sm['cover_url']?.toString());
            return cover.isNotEmpty
                ? cover
                : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600';
          }(),
          address: sm['address_ku']?.toString() ?? 'کەلار',
          isOpen: sm['is_online'] == true,
          phone: sm['phone']?.toString() ?? '',
          discountBadge: (rawBadge != null && rawBadge.isNotEmpty) ? rawBadge : null,
          lat: (sm['lat'] as num?)?.toDouble() ?? 34.6836,
          lng: (sm['lng'] as num?)?.toDouble() ?? 45.3189,
        );
        final existingIdx = allStores.indexWhere((s) => s.id == storeKey || s.name == storeName);
        if (existingIdx >= 0) {
          allStores[existingIdx] = mappedStore;
        } else {
          allStores.insert(0, mappedStore);
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  IconData _notifIconFor(String tag, String type) {
    if (tag.contains('داشکاندن') || tag.contains('ئۆفەر')) return Icons.local_offer_rounded;
    if (tag.contains('گەیاندن')) return Icons.moped_rounded;
    if (tag.contains('دیاری') || tag.contains('کۆد')) return Icons.card_giftcard_rounded;
    if (type == 'store') return Icons.storefront_rounded;
    if (type == 'category') return Icons.grid_view_rounded;
    if (type == 'order') return Icons.receipt_long_rounded;
    return Icons.notifications_active_rounded;
  }

  Color _notifColorFor(String tag, String type) {
    if (tag.contains('داشکاندن')) return RC.bg(Color(0xFFEF4444));
    if (tag.contains('کۆد') || tag.contains('دیاری')) return RC.bg(Color(0xFFD97706));
    if (tag.contains('گەیاندن')) return RC.bg(Color(0xFF10B981));
    if (tag.contains('ئۆفەر')) return RC.bg(Color(0xFF8B5CF6));
    if (type == 'store') return RC.bg(Color(0xFF059669));
    return RC.bg(Color(0xFF2563EB));
  }

  String _formatNotifTime(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt.toString());
    if (dt == null) return createdAt.toString();
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60) return 'پێش ${diff.inMinutes} خولەک';
    if (diff.inHours < 24) return 'پێش ${diff.inHours} کاتژمێر';
    if (diff.inDays == 1) return 'دوێنێ';
    return 'پێش ${diff.inDays} ڕۆژ';
  }

  String? _extractOrderRefFromText(String text) {
    final match = RegExp(r'RA-\d+', caseSensitive: false).firstMatch(text);
    return match?.group(0)?.toUpperCase();
  }

  Map<String, dynamic> _mapApiNotification(Map<String, dynamic> m) {
    final tag = m['tag']?.toString() ?? 'ئاگاداری';
    final type = m['type']?.toString() ?? 'general';
    final store = m['store'] as Map<String, dynamic>?;
    final storeId = store?['id'] ?? m['store_id'];
    final badge = m['discount_badge']?.toString();
    final titleKu = m['title_ku']?.toString() ?? '';
    final titleEn = m['title_en']?.toString() ?? '';
    final bodyKu = m['body_ku']?.toString() ?? '';
    final orderRef = _extractOrderRefFromText('$titleKu $titleEn $bodyKu');
    return {
      'id': '${m['id']}',
      'title': titleKu,
      'desc': bodyKu,
      'time': _formatNotifTime(m['created_at']),
      'tag': tag,
      'type': type,
      'storeId': storeId != null ? 'db_store_$storeId' : null,
      'categoryName': m['category_name']?.toString(),
      'orderRef': orderRef,
      'icon': _notifIconFor(tag, type),
      'color': _notifColorFor(tag, type),
      'discountBadge': (badge != null && badge.isNotEmpty) ? badge : tag,
      'isRead': m['is_read'] == true,
    };
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notif, BuildContext modalCtx) async {
    final type = notif['type']?.toString() ?? '';
    final tag = notif['tag']?.toString() ?? '';
    final storeId = notif['storeId'] as String?;
    final catName = notif['categoryName'] as String?;
    final orderRef = (notif['orderRef'] as String?) ??
        _extractOrderRefFromText('${notif['title'] ?? ''} ${notif['desc'] ?? ''}');

    // 1) Order / delivery notifications → open that order
    final isOrderNotif = type == 'order' || tag.contains('گەیاندن') || orderRef != null;
    if (isOrderNotif && orderRef != null) {
      await _syncCustomerOrdersFromBackend();
      if (!mounted || !modalCtx.mounted) return;
      OrderItem? order;
      try {
        order = _orders.firstWhere((o) => o.id.toUpperCase() == orderRef.toUpperCase());
      } catch (_) {
        order = null;
      }
      if (order != null) {
        final target = order;
        Navigator.pop(modalCtx);
        _goTab(3);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_isLiveTrackStatus(target.status)) {
            _showLiveTrackingModal(target);
          } else {
            _showReceiptModal(target);
          }
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('داواکارییەکە نەدۆزرایەوە'))),
      );
      return;
    }

    if (!modalCtx.mounted) return;

    // 2) Linked store
    StoreItem? store;
    if (storeId != null && allStores.isNotEmpty) {
      try {
        store = allStores.firstWhere((s) => s.id == storeId);
      } catch (_) {
        store = null;
      }
    }
    if (store != null) {
      Navigator.pop(modalCtx);
      setState(() {
        _selectedStore = store;
        _selectedSubCategory = null;
      });
      _goTab(0);
      return;
    }

    // 3) Linked category
    if (catName != null && catName.trim().isNotEmpty) {
      Navigator.pop(modalCtx);
      setState(() {
        _selectedCategory = catName;
        _selectedStore = null;
      });
      _goTab(0);
      return;
    }

    // 4) Discount / offer with no store → discounts tab
    if (tag.contains('داشکاندن') || tag.contains('ئۆفەر') || tag.contains('کۆد') || type == 'promo') {
      Navigator.pop(modalCtx);
      _goTab(1);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('هیچ لینکێک بۆ ئەم ئاگادارییە نییە'))),
      );
    }
  }

  Future<void> _syncNotificationsFromBackend() async {
    try {
      final raw = await CustomerApiService.instance.fetchNotifications();
      final mapped = raw
          .whereType<Map>()
          .map((e) => _mapApiNotification(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      final prevUnread = _unreadNotificationCount;
      final nextUnread = mapped.where((n) => n['isRead'] != true).length;
      _dynamicNotifications = mapped;
      _unreadNotificationCount = nextUnread;
      // New inbox items while app is open → play customer chime.
      if (nextUnread > prevUnread) {
        unawaited(CustomerNotificationSound.instance.play());
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  bool _isLiveTrackStatus(String status) {
    const live = {
      'preparing',
      'ready',
      'driver_assigned',
      'picked_up',
      'arrived_pickup',
      'on_the_way',
      'arrived_customer',
      'at_store',
    };
    return live.contains(status);
  }

  bool _shouldAutoOpenMotorcycleMap(String? previousStatus, String nextStatus) {
    if (previousStatus == null || previousStatus == nextStatus) return false;
    // Auto-open map when seller sends order to delivery (ready / on the way).
    const openOn = {'ready', 'picked_up', 'on_the_way', 'arrived_customer'};
    if (!openOn.contains(nextStatus)) return false;
    const alreadyOut = {'ready', 'picked_up', 'on_the_way', 'arrived_customer'};
    return !alreadyOut.contains(previousStatus);
  }

  Future<void> _syncCustomerOrdersFromBackend() async {
    try {
      final list = await CustomerApiService.instance.fetchCustomerOrders(phone: _userProfile?.phone);
      if (!mounted || list.isEmpty) return;

      final previousStatusById = <String, String>{
        for (final o in _orders) o.id: o.status,
      };

      final synced = <OrderItem>[];
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final isDirect = m['is_direct_request'] == true ||
            (m['order_number'] != null && m['order_number'].toString().startsWith('DR-'));
        final rawItems = m['items'] as List<dynamic>? ?? [];
        final cartEntries = rawItems.map((ri) {
          final im = ri as Map<String, dynamic>;
          return CartEntry(
            product: ProductItem(
              id: '${im['product_id'] ?? im['id'] ?? '1'}',
              storeId: 'db_store_${m['store_id'] ?? 1}',
              name: im['product_name']?.toString() ?? 'بەرهەم',
              price: ((im['unit_price'] ?? 0) as num).toInt(),
              description: '',
              imageUrl: im['product_image']?.toString() ?? '',
              category: isDirect ? 'داواکاری ڕاستەوخۆ' : 'خواردنگە',
            ),
            quantity: ((im['quantity'] ?? 1) as num).toInt(),
            specialNotes: im['special_notes']?.toString() ?? '',
          );
        }).toList();

        final rawStore = m['store'] as Map<String, dynamic>?;
        final storeName = isDirect
            ? '⚡ داواکاری ڕاستەوخۆ'
            : (rawStore?['name_ku']?.toString() ?? 'فرۆشگا');

        synced.add(
          OrderItem(
            id: m['order_number']?.toString() ?? 'RA-${m['id']}',
            storeName: storeName,
            totalAmount: ((m['total_amount'] ?? 0) as num).toInt(),
            status: m['status']?.toString() ?? 'pending',
            date: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
            items: cartEntries,
            driverName: m['driver']?['name']?.toString() ?? '',
            driverPhone: m['driver']?['phone']?.toString() ?? '',
            address: m['delivery_address']?.toString() ?? 'کەلار',
            deliveryPin: m['delivery_pin']?.toString() ?? '4821',
            storeLat: ((rawStore?['lat'] ?? 34.6836) as num).toDouble(),
            storeLng: ((rawStore?['lng'] ?? 45.3189) as num).toDouble(),
            customerLat: ((m['delivery_lat'] ?? 34.6912) as num).toDouble(),
            customerLng: ((m['delivery_lng'] ?? 45.3264) as num).toDouble(),
            isDirectRequest: isDirect,
            directRequestNotes: m['direct_notes']?.toString() ?? m['direct_subject']?.toString(),
            directRequestImage: m['direct_image']?.toString(),
            dbId: (m['id'] as num?)?.toInt(),
          ),
        );
      }

      OrderItem? autoOpenOrder;
      for (final order in synced) {
        final prev = previousStatusById[order.id];
        if (_shouldAutoOpenMotorcycleMap(prev, order.status) &&
            !_autoOpenedTrackOrders.contains(order.id)) {
          _autoOpenedTrackOrders.add(order.id);
          autoOpenOrder ??= order;
        }
      }

      if (mounted) {
        setState(() {
          _orders
            ..clear()
            ..addAll(synced);
        });
        context.read<OrdersNotifier>().notify();

        if (autoOpenOrder != null) {
          final target = autoOpenOrder;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _goTab(3);
            _showLiveTrackingModal(target);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      // SessionNotifier.restoreSession owns token/profile restore.
      // Here we only mirror into text fields once restore finishes.
      final session = context.read<SessionNotifier>();
      if (session.isRestoring) {
        void listener() {
          if (!mounted) return;
          if (session.isRestoring) return;
          session.removeListener(listener);
          final profile = session.user;
          if (profile != null) {
            setState(() {
              _nameCtrl.text = profile.name;
              _phoneCtrl.text = profile.phone;
            });
          }
          _showPendingBlockedIfNeeded();
        }

        session.addListener(listener);
        return;
      }
      final profile = session.user;
      if (profile != null && mounted) {
        setState(() {
          _nameCtrl.text = profile.name;
          _phoneCtrl.text = profile.phone;
        });
      }
      _showPendingBlockedIfNeeded();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _showPendingBlockedIfNeeded() async {
    if (!mounted) return;
    final session = context.read<SessionNotifier>();
    final blocked = session.pendingBlocked;
    if (blocked == null) return;
    session.clearPendingBlocked();
    // Enrich WhatsApp / support numbers from admin settings when API contact is thin.
    var error = blocked;
    if (error.contact.isEmpty ||
        (error.contact['whatsapp_number'] == null &&
            error.contact['support_phone'] == null)) {
      final contacts = await CustomerApiService.instance.fetchSupportContacts();
      if (contacts.isNotEmpty) {
        error = AccountBlockedException(
          message: blocked.message,
          contact: {...blocked.contact, ...contacts},
        );
      }
    }
    if (!mounted) return;
    await BlockedAccountContacts.show(context, error, lang: _currentLanguage);
  }

  Future<void> _saveProfile(UserProfile profile, {bool allowRegister = true}) async {
    await CustomerApiService.instance.authenticateOrRegister(
      name: profile.name,
      phone: profile.phone,
      password: _passwordCtrl.text,
      allowRegister: allowRegister,
    );
    if (!CustomerApiService.instance.hasToken) {
      throw Exception('login_failed');
    }
    // Persist profile + logged_in via SessionNotifier (source of truth).
    await context.read<SessionNotifier>().signIn(profile);
    await _markFirstLoginPermissionPromptsPending();
    await PushNotifications.instance.syncTokenToBackend();
    await _syncNotificationsFromBackend();
    _syncCustomerOrdersFromBackend();
    if (mounted) setState(() {});
  }

  static const _kLocPromptDone = 'rega_location_prompt_done';
  static const _kLocPromptPending = 'rega_location_prompt_pending';
  static const _kNotifPromptDone = 'rega_notif_prompt_done';
  static const _kNotifPromptPending = 'rega_notif_prompt_pending';

  /// First successful login/register on this device → show notif + location once.
  Future<void> _markFirstLoginPermissionPromptsPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kNotifPromptDone) != true) {
        await prefs.setBool(_kNotifPromptPending, true);
      }
      if (prefs.getBool(_kLocPromptDone) != true) {
        await prefs.setBool(_kLocPromptPending, true);
      }
    } catch (_) {}
  }

  /// First successful login/register on this device → show location allow dialog once.
  Future<void> _markLocationPromptPendingIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kLocPromptDone) == true) return;
      await prefs.setBool(_kLocPromptPending, true);
    } catch (_) {}
  }

  Future<void> _maybeShowFirstLoginNotificationDialog() async {
    if (!mounted || widget.forceAuthOnly || kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kNotifPromptPending) != true) return;
      await prefs.setBool(_kNotifPromptPending, false);
      await prefs.setBool(_kNotifPromptDone, true);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    await _showAllowNotificationsDialog();
  }

  /// Pre-prompt (localized) → then native OS notification dialog (سماح / عدم السماح).
  Future<void> _showAllowNotificationsDialog() async {
    if (!mounted) return;
    final allow = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 48,
                      color: RC.fg(const Color(0xFF007AFF)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      tx('ئایا دەتەوێت ڕێگە بدەیت بە ئەپی REGA کە ئاگاداریت بۆ بنێرێت؟'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                        color: RC.fg(Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Divider(height: 1),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        foregroundColor: RC.fg(const Color(0xFF007AFF)),
                      ),
                      child: Text(
                        tx('ڕێگەبدە'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Divider(height: 1),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        foregroundColor: RC.fg(const Color(0xFF007AFF)),
                      ),
                      child: Text(
                        tx('ڕێگە مەدە'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (allow == true) {
      // Triggers the native iOS/Android system dialog (سماح / عدم السماح).
      if (!kIsWeb) {
        try {
          await Permission.notification.request();
        } catch (_) {}
      }
      await PushNotifications.instance.requestPermissionAndSync();
    }
  }

  Future<void> _maybeShowFirstLoginLocationDialog() async {
    if (!mounted || widget.forceAuthOnly) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kLocPromptPending) != true) return;
      await prefs.setBool(_kLocPromptPending, false);
      await prefs.setBool(_kLocPromptDone, true);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    await _showAllowLocationDialog();
  }

  Future<void> _showAllowLocationDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        insetPadding: EdgeInsets.symmetric(
          horizontal: (MediaQuery.sizeOf(ctx).width - RegaResponsive.dialogMaxWidth(ctx)) / 2,
          vertical: 24,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: RegaResponsive.dialogMaxWidth(ctx)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RC.bg(const Color(0xFFFEF3C7)),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_rounded, size: 40, color: RC.fg(const Color(0xFFD97706))),
              ),
              const SizedBox(height: 16),
              Text(
                tx('ڕێگەپێدانی لۆکەیشن'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: RC.fg(Colors.black),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tx('بۆ دیاریکردنی شوێنی گەیاندن و نیشاندانی فرۆشگا نزیکەکانت، تکایە ڕێگە بدە بە لۆکەیشنی ئامێرەکەت.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: RC.fg(Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(const Color(0xFFFAC800)),
                    foregroundColor: RC.fg(Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _requestLocationPermission(forcePrompt: true);
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  label: Text(
                    tx('ڕێگەبدە بە لۆکەیشن'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  tx('دواتر'),
                  style: TextStyle(color: RC.fg(Colors.grey.shade600), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearProfile() async {
    try {
      await context.read<SessionNotifier>().signOut();
      if (mounted) setState(() => _userProfile = null);
    } catch (e) {
      debugPrint('Error clearing profile: $e');
    }
  }

  // 💾 بارکردنی زمانی پاشەکەوتکراو بۆ سەر شاشە و مێنۆکان
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('rega_saved_language_name');
      final savedCode = prefs.getString('rega_saved_language_code');

      String selectedLang = 'کوردی';
      if (savedName != null && savedName.isNotEmpty) {
        selectedLang = savedName;
      } else if (savedCode != null && savedCode.isNotEmpty) {
        if (savedCode == 'en') {
          selectedLang = 'English';
        } else if (savedCode == 'ar') {
          selectedLang = 'العربية';
        } else {
          selectedLang = 'کوردی';
        }
      } else if (widget.currentLang.isNotEmpty) {
        if (widget.currentLang == 'en') {
          selectedLang = 'English';
        } else if (widget.currentLang == 'ar') {
          selectedLang = 'العربية';
        } else {
          selectedLang = 'کوردی';
        }
      }

      if (mounted) {
        setState(() {
          _currentLanguage = selectedLang;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved language in MainScreen: $e');
    }
  }

  // 💾 پاشەکەوتکردنی زمان لەناو SharedPreferences بۆ ئەوەی دوای دەرچوون لە ئەپ نەگۆڕێت
  Future<void> _saveLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rega_saved_language_name', lang);
      String code = 'ku';
      if (lang == 'English') {
        code = 'en';
      } else if (lang == 'العربية') {
        code = 'ar';
      }
      await prefs.setString('rega_saved_language_code', code);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  // 🚫 Full-Screen Offline Warning Overlay (Prevents App Usage)
  Widget _buildOfflineScreen() {
    return Container(
      color: RC.bg(Colors.white),
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: RegaResponsive.pagePadding(context)),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Wifi Off Icon with circle badge
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.red.shade50),
                  shape: BoxShape.circle,
                  border: Border.all(color: RC.bg(Colors.red.shade100), width: 2),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: RC.fg(Colors.red.shade600),
                ),
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                tx('پەیوەندی ئەنتەرنێت بەردەست نییە!'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: RC.fg(Colors.black),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description matching user request:
              // "تکایە ئامێرەکەت پەیوەست بکە بە هێڵی ئەنتەرنێتەوە"
              Text(
                tx('تکایە ئامێرەکەت پەیوەست بکە بە هێڵی ئەنتەرنێتەوە بۆ ئەوەی بتوانیت ئەپەکە بەکاربهێنیت.'),
                style: TextStyle(
                  fontSize: 14,
                  color: RC.fg(Colors.grey.shade700),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Retry Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFFFAC800)),
                    foregroundColor: RC.fg(Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isCheckingConnection ? null : () => _checkInternetConnection(silent: false),
                  icon: _isCheckingConnection
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: RC.bg(Colors.black)),
                        )
                      : const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(
                    tx(_isCheckingConnection ? 'چاوەڕوان بە...' : 'دووبارە هەوڵبدەرەوە'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Simulated offline toggle button for testing
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isOffline = false;
                  });
                },
                icon: Icon(Icons.developer_mode_rounded, size: 16, color: RC.fg(Colors.grey)),
                label: Text(
                  tx('داخستنی ئاگاداری (تاقیکردنەوە)'),
                  style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart(ProductItem product, {int qty = 1, String notes = ''}) {
    setState(() {
      final idx = _cart.indexWhere((item) => item.product.id == product.id);
      if (idx >= 0) {
        _cart[idx].quantity += qty;
        if (notes.isNotEmpty) _cart[idx].specialNotes = notes;
      } else {
        _cart.add(CartEntry(product: product, quantity: qty, specialNotes: notes));
      }
    });

    // 🚀 خێراکردن و پاککردنەوەی هەموو ئاگادارییە پێشووەکان بۆ ئەوەی ڕاستەوخۆ نیشان بدرێت و تاخیر نەبێت
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: RC.fg(Colors.white), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tx('${product.name} ${_t('زیادکرا بۆ سەبەتە')}'),
                style: TextStyle(
                  color: RC.fg(Colors.white),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: RC.bg(Color(0xFF047857)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(milliseconds: 1200),
        elevation: 6,
      ),
    );
  }

  // Auth Guard Alert Dialog
  void _showAuthRequiredModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        insetPadding: EdgeInsets.symmetric(
          horizontal: (MediaQuery.sizeOf(ctx).width - RegaResponsive.dialogMaxWidth(ctx)) / 2,
          vertical: 24,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: RegaResponsive.dialogMaxWidth(ctx)),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RC.bg(Colors.amber.shade100),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_add_rounded, size: 36, color: RC.fg(Color(0xFFD97706))),
            ),
            const SizedBox(height: 16),
            Text(
              _t('تکایە سەرەتا خۆت تۆمار بکە'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _t('بۆ ئەوەی بتوانیت داواکارییەکەت ئەنجام بدەیت و کاڵاکانت پێ بگات، تکایە سەرەتا خۆت تۆمار بکە یان بچۆ ژوورەوە.'),
              style: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade700), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFFAC800)),
                  foregroundColor: RC.fg(Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _goTab(4); // Switch to Profile Tab
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(_t('ڕاستەوخۆ بڕۆ بۆ خۆتۆمارکردن'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('دواخستن'), style: TextStyle(color: RC.fg(Colors.grey.shade600))),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _handleProceedToCheckout() {
    if (_userProfile == null) {
      _showAuthRequiredModal();
    } else {
      _showCheckoutSheet();
    }
  }

  Widget _buildConfirmDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tx(label), style: TextStyle(fontSize: 12.5, color: RC.fg(Colors.black54), fontWeight: FontWeight.bold)),
          Flexible(
            child: Text(
              tx(value),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, color: RC.fg(Colors.black87), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmationDialog({
    required BuildContext parentCtx,
    required String orderCode,
    required int grandTotal,
    required List<CartEntry> cartItems,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: RC.bg(Color(0xFFFEF3C7)), shape: BoxShape.circle),
              child: Icon(Icons.help_outline_rounded, size: 36, color: RC.fg(Color(0xFFD97706))),
            ),
            const SizedBox(height: 12),
            Text(
              tx('دڵنیابوونەوە لە داواکاری'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmDetailRow('شوێن:', _deliveryDisplayLabel),
            _buildConfirmDetailRow('کۆی گشتی حساب:', '${_formatNum(grandTotal)} د.ع'),
          ],
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFFDC2626)), // باکگراوندی سووری سەرنجڕاکێش
                    foregroundColor: RC.fg(Colors.white),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tx('پاشگەزبوونەوە'),
                      maxLines: 1,
                      style: TextStyle(
                        color: RC.fg(Colors.white),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFFFAC800)),
                    foregroundColor: RC.fg(Colors.black),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx); // Close Confirmation Dialog
                    Navigator.pop(parentCtx); // Close Checkout Sheet

                    final matchedStore = cartItems.isNotEmpty
                        ? allStores.where((s) => s.id == cartItems.first.product.storeId).firstOrNull
                        : null;
                    final storeName = matchedStore?.name ??
                        (cartItems.isNotEmpty ? cartItems.first.product.name : 'کەبابخانەی کەلار');
                    final newOrder = OrderItem(
                      id: orderCode,
                      storeName: storeName,
                      totalAmount: grandTotal,
                      status: 'pending',
                      date: DateTime.now(),
                      items: List.from(cartItems),
                      driverName: '',
                      driverPhone: '',
                      address: _deliveryDisplayLabel,
                      deliveryPin: orderCode.length >= 4
                          ? orderCode.substring(orderCode.length - 4)
                          : '4821',
                      storeLat: matchedStore?.lat ?? KalarGeoCatalog.kalarCenter.latitude,
                      storeLng: matchedStore?.lng ?? KalarGeoCatalog.kalarCenter.longitude,
                      customerLat: _pinnedCustomerLat ?? KalarGeoCatalog.kalarCenter.latitude,
                      customerLng: _pinnedCustomerLng ?? KalarGeoCatalog.kalarCenter.longitude,
                    );

                    setState(() {
                      _orders.insert(0, newOrder);
                      _cart.clear();
                    });

                    _submitOrderToBackendAndShowModal(
                      newOrder,
                      matchedStore,
                      orderCode,
                      grandTotal,
                      cartItems,
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tx('بەڵێ، بنێرە'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrderToBackendAndShowModal(
    OrderItem localOrder,
    StoreItem? matchedStore,
    String fallbackCode,
    int grandTotal,
    List<CartEntry> cartItems,
  ) async {
    int? dbStoreId;
    if (matchedStore != null && matchedStore.id.startsWith('db_store_')) {
      dbStoreId = int.tryParse(matchedStore.id.replaceFirst('db_store_', ''));
    }

    final mappedItems = cartItems
        .map(
          (c) => <String, dynamic>{
            'product_id': int.tryParse(c.product.id),
            'name': c.product.name,
            'quantity': c.quantity,
            'price': c.product.price,
            'notes': c.specialNotes,
          },
        )
        .toList();

    final created = await CustomerApiService.instance.placeBackendOrder(
      storeId: dbStoreId,
      storeName: localOrder.storeName,
      neighborhoodName: _selectedNeighborhoodOrNull?.name ?? _deliveryDisplayLabel,
      customerName: _userProfile?.name ?? 'سەربەست عەلی',
      customerPhone: _userProfile?.phone ?? '07703331122',
      deliveryAddress: localOrder.address,
      deliveryLat: localOrder.customerLat,
      deliveryLng: localOrder.customerLng,
      deliveryFee: _deliveryFeeOrZero,
      items: mappedItems,
    );

    if (!mounted) return;

    if (created != null) {
      final realOrderNum = (created['order_number'] ?? fallbackCode).toString();
      final realStatus = (created['status'] ?? 'pending').toString();
      final syncedOrder = OrderItem(
        id: realOrderNum,
        storeName: localOrder.storeName,
        totalAmount: (created['grand_total'] as num?)?.toInt() ?? grandTotal,
        status: realStatus,
        date: DateTime.now(),
        items: localOrder.items,
        driverName: localOrder.driverName,
        driverPhone: localOrder.driverPhone,
        address: localOrder.address,
        deliveryPin: localOrder.deliveryPin,
        storeLat: localOrder.storeLat,
        storeLng: localOrder.storeLng,
        customerLat: localOrder.customerLat,
        customerLng: localOrder.customerLng,
      );
      setState(() {
        final idx = _orders.indexWhere((o) => o.id == localOrder.id);
        if (idx >= 0) {
          _orders[idx] = syncedOrder;
        } else {
          _orders.insert(0, syncedOrder);
        }
      });
      _showOrderSuccessModal();
    } else {
      _showOrderSuccessModal();
    }
  }

  void _showOrderSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFDCFCE7)),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, size: 48, color: RC.fg(Color(0xFF16A34A))),
            ),
            const SizedBox(height: 14),
            Text(
              _t('داواکارییەکەت بە سەرکەوتوویی نێردرا!'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
            ),
            const SizedBox(height: 14),

            // Delivery tracking hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFF9FAFB)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RC.bg(Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 16, color: RC.fg(Color(0xFFD97706))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tx('شوێنی گەیاندن: $_deliveryDisplayLabel'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RC.fg(Colors.black87)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.moped_rounded, size: 16, color: RC.fg(Color(0xFF16A34A))),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tx('کاتێک فرۆشیار داواکاری قبوڵدەکات و دەینێرێت بۆ گەیاندن، نەخشەی ڕاستەوخۆی ماتۆرسوار خۆکارانە دەکرێتەوە.'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Colors.black87), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(Color(0xFFFAC800)),
                  foregroundColor: RC.fg(Colors.black),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _goTab(3); // Switch to Orders tab
                },
                child: Text(
                  _t('چوون بۆ داواکارییەکان'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final subtotal = _cart.fold<int>(0, (sum, i) => sum + (i.product.price * i.quantity));
          final grandTotal = subtotal + _deliveryFeeOrZero;

          // Content-sized sheet — avoid full-screen white blank above the form.
          return Padding(
            padding: EdgeInsets.only(
              left: RegaResponsive.pagePadding(context),
              right: RegaResponsive.pagePadding(context),
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: RegaResponsive.dialogMaxWidth(context)),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: RC.bg(Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _t('تەواوکردن و ناردنی داواکاری'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_deliveryDisplayLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: RC.bg(const Color(0xFFF0FDF4)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: RC.bg(const Color(0xFFBBF7D0))),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 18, color: RC.fg(const Color(0xFF15803D))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tx(_deliveryDisplayLabel),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: RC.fg(Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RC.fg(const Color(0xFF15803D)),
                          side: BorderSide(color: RC.bg(const Color(0xFF86EFAC))),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          _showLocationPicker();
                          setSheetState(() {});
                        },
                        child: Text(
                          tx('دیاری کردنی شوێن'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.amber.shade50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RC.bg(Colors.amber.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _t('کۆی گشتی داواکاری:'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tx('${_formatNum(grandTotal)} د.ع'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: RC.fg(const Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(const Color(0xFFFAC800)),
                          foregroundColor: RC.fg(Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final orderCode = '${(1000 + (DateTime.now().microsecondsSinceEpoch % 9000))}';
                          _showOrderConfirmationDialog(
                            parentCtx: ctx,
                            orderCode: orderCode,
                            grandTotal: grandTotal,
                            cartItems: List.from(_cart),
                          );
                        },
                        child: Text(
                          _t('پشتڕاستکردنەوە و ناردنی داواکاری'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Pick delivery place: current GPS anywhere in Iraq, OR tap/search a future place
  /// (e.g. a park, neighborhood, or residential compound) so the driver goes to exact
  /// GPS coordinates with a clean Kurdish neighborhood/place label.
  Future<void> _showLocationPicker() async {
    final hasSavedPin = _pinnedCustomerLat != null && _pinnedCustomerLng != null;
    final isLegacySayyidKhalilDefault = hasSavedPin &&
        (_pinnedCustomerLat! - 34.6836).abs() < 0.0005 &&
        (_pinnedCustomerLng! - 45.3189).abs() < 0.0005 &&
        (_deliveryPlaceNote == null || _deliveryPlaceNote!.trim().isEmpty);

    LatLng draftPin = (hasSavedPin && !isLegacySayyidKhalilDefault)
        ? LatLng(_pinnedCustomerLat!, _pinnedCustomerLng!)
        : KalarGeoCatalog.kalarCenter;
    Neighborhood? draftNeighborhood = _closestNeighborhoodTo(
      draftPin.latitude,
      draftPin.longitude,
    ) ?? _selectedNeighborhood;
    String? draftGeocode = isLegacySayyidKhalilDefault ? null : _resolvedPlaceName;
    String? customNeighborhoodOverride;
    LatLng? overrideAnchorPin;
    bool geocoding = false;
    int geocodeGen = 0;
    Timer? geocodeDebounce;
    Timer? searchDebounce;
    bool searchingPlaces = false;
    List<GeocodedPlaceSuggestion> searchResults = [];
    final searchCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: _deliveryPlaceNote ?? '');

    String resolvedNeighborhoodLabel() {
      if (customNeighborhoodOverride != null &&
          customNeighborhoodOverride!.trim().isNotEmpty) {
        return customNeighborhoodOverride!.trim();
      }
      if (draftGeocode != null &&
          draftGeocode!.isNotEmpty &&
          !MapboxGeocoding.looksLikeCoordinates(draftGeocode)) {
        return draftGeocode!;
      }
      final strict = _strictNeighborhoodNameAt(draftPin.latitude, draftPin.longitude);
      if (strict != null && strict.isNotEmpty) {
        return strict;
      }
      if (MapboxGeocoding.isInsideKalarUrbanArea(draftPin)) {
        final near = MapboxGeocoding.nearestLocalPlace(draftPin, maxMeters: 1350);
        if (near != null) {
          return 'کەلار · نزیک ${near.place.nameKu}';
        }
        return 'کەلار · گەڕەک / کۆمەڵگای نوێ';
      }
      if (MapboxGeocoding.isInsideRizgariArea(draftPin)) {
        return 'شارۆچکەی ڕزگاری · ناوچەی نیشتەجێبوون';
      }
      return 'شوێنی دیاریکراو لەسەر نەخشە (GPS)';
    }

    String draftLabel() {
      final area = resolvedNeighborhoodLabel();
      final note = noteCtrl.text.trim();
      if (note.isNotEmpty) {
        if (area.isNotEmpty && !note.contains(area) && !area.contains(note)) {
          return '$area · $note';
        }
        return note;
      }
      return area;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refreshGeocode(LatLng pt) async {
              final gen = ++geocodeGen;
              setModalState(() => geocoding = true);
              final name = await _reverseGeocodeLabel(pt.latitude, pt.longitude);
              if (gen != geocodeGen) return;
              if (!context.mounted) return;
              setModalState(() {
                draftGeocode = (name != null &&
                        name.isNotEmpty &&
                        !MapboxGeocoding.looksLikeCoordinates(name))
                    ? name
                    : _strictNeighborhoodNameAt(pt.latitude, pt.longitude);
                geocoding = false;
              });
            }

            void applyPin(LatLng pt) {
              draftPin = pt;
              draftNeighborhood = _closestNeighborhoodTo(pt.latitude, pt.longitude);
              // Clear manual chip override only if the user panned away (> 350m) from where they picked it.
              if (overrideAnchorPin != null &&
                  MapboxGeocoding.distanceMeters(pt, overrideAnchorPin!) > 350) {
                customNeighborhoodOverride = null;
                overrideAnchorPin = null;
              }
              // Immediate local Kurdish geofence preview while reverse-geocode fetches details.
              draftGeocode = _strictNeighborhoodNameAt(pt.latitude, pt.longitude);
              setModalState(() => geocoding = true);
              geocodeDebounce?.cancel();
              geocodeDebounce = Timer(const Duration(milliseconds: 350), () {
                if (!context.mounted) return;
                refreshGeocode(pt);
              });
            }

            void runPlaceSearch(String q) {
              searchDebounce?.cancel();
              final trimmed = q.trim();
              if (trimmed.isEmpty) {
                setModalState(() {
                  searchingPlaces = false;
                  searchResults = [];
                });
                return;
              }
              setModalState(() => searchingPlaces = true);
              searchDebounce = Timer(const Duration(milliseconds: 260), () async {
                final found = await MapboxGeocoding.searchPlaces(
                  trimmed,
                  proximity: draftPin,
                );
                if (!context.mounted) return;
                setModalState(() {
                  searchResults = found;
                  searchingPlaces = false;
                });
              });
            }

            // Always resolve place name for the pin when the picker opens.
            if (!geocoding && geocodeGen == 0) {
              refreshGeocode(draftPin);
            }

            final activeAreaLabel = resolvedNeighborhoodLabel();
            final coordsText = MapboxGeocoding.coordinatesLabel(draftPin, decimals: 5);

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Material(
                  color: RC.bg(Colors.white),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.94,
                    child: Column(
                      children: [
                        // REGA brand gold header + forward search bar
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                RC.bg(const Color(0xFFFFDE59)),
                                RC.bg(const Color(0xFFFAC800)),
                                RC.bg(const Color(0xFFEAB308)),
                              ],
                            ),
                          ),
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top > 0 ? 4 : 8,
                            bottom: 10,
                            left: 10,
                            right: 10,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(Icons.close_rounded, color: RC.fg(Colors.black)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _t('دیاریکردنی شوێن'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: RC.fg(Colors.black),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                ],
                              ),
                              // Forward search / autocomplete for Kurdish neighborhoods & compounds
                              SizedBox(
                                height: 42,
                                child: TextField(
                                  controller: searchCtrl,
                                  textInputAction: TextInputAction.search,
                                  onChanged: runPlaceSearch,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    hintText: tx('گەڕان بۆ گەڕەک، سیتی، کۆمەڵگا یان شوێن...'),
                                    hintStyle: TextStyle(
                                      fontSize: 12.5,
                                      color: RC.fg(const Color(0xFF64748B)),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      size: 19,
                                      color: RC.fg(const Color(0xFF0F172A)),
                                    ),
                                    suffixIcon: searchingPlaces
                                        ? const Padding(
                                            padding: EdgeInsets.all(11),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : (searchCtrl.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear_rounded, size: 17),
                                                onPressed: () {
                                                  searchCtrl.clear();
                                                  runPlaceSearch('');
                                                },
                                              )
                                            : null),
                                    filled: true,
                                    fillColor: RC.bg(Colors.white),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              KalarInteractivePickerMap(
                                initialPoint: draftPin,
                                pinLabel: draftLabel(),
                                pinLoading: geocoding,
                                allowIraqWide: true,
                                onLocationChanged: applyPin,
                              ),
                              if (searchResults.isNotEmpty)
                                Positioned(
                                  top: 8,
                                  left: 12,
                                  right: 12,
                                  child: Material(
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(16),
                                    color: RC.bg(Colors.white),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 220),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        itemCount: searchResults.length,
                                        separatorBuilder: (_, __) => Divider(
                                          height: 1,
                                          color: RC.bg(const Color(0xFFF1F5F9)),
                                        ),
                                        itemBuilder: (ctx2, i) {
                                          final s = searchResults[i];
                                          return ListTile(
                                            dense: true,
                                            leading: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: RC.bg(const Color(0xFFFFFBEB)),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                s.isLocalCurated
                                                    ? Icons.location_city_rounded
                                                    : Icons.place_rounded,
                                                size: 18,
                                                color: RC.fg(const Color(0xFFD97706)),
                                              ),
                                            ),
                                            title: Text(
                                              s.title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            subtitle: Text(
                                              s.subtitle,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: RC.fg(const Color(0xFF64748B)),
                                              ),
                                            ),
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              setModalState(() {
                                                draftPin = s.point;
                                                draftNeighborhood = _closestNeighborhoodTo(
                                                  s.point.latitude,
                                                  s.point.longitude,
                                                );
                                                customNeighborhoodOverride =
                                                    s.neighborhoodName ?? s.title;
                                                overrideAnchorPin = s.point;
                                                draftGeocode = s.title;
                                                searchResults = [];
                                                searchCtrl.clear();
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.white),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.fromLTRB(
                            14,
                            10,
                            14,
                            12 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Live resolved Kurdish neighborhood + exact GPS coordinates badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                                decoration: BoxDecoration(
                                  color: RC.bg(const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.my_location_rounded,
                                      size: 17,
                                      color: RC.fg(const Color(0xFF059669)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeAreaLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: RC.fg(const Color(0xFF0F172A)),
                                            ),
                                          ),
                                          Text(
                                            'GPS: $coordsText',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: RC.fg(const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (customNeighborhoodOverride != null)
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () {
                                          setModalState(() {
                                            customNeighborhoodOverride = null;
                                            overrideAnchorPin = null;
                                          });
                                        },
                                        child: Text(
                                          tx('خۆکار'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: RC.fg(const Color(0xFFD97706)),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Quick Kurdish neighborhood & residential compound selector chips
                              // (never overwrites manual user text in "ناوی شوێن")
                              SizedBox(
                                height: 34,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: MapboxGeocoding.localPlaces.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                                  itemBuilder: (ctx3, idx) {
                                    final place = MapboxGeocoding.localPlaces[idx];
                                    final isSelected = activeAreaLabel == place.nameKu ||
                                        activeAreaLabel.startsWith('${place.nameKu} ·');
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        final dist = MapboxGeocoding.distanceMeters(
                                          draftPin,
                                          place.center,
                                        );
                                        setModalState(() {
                                          customNeighborhoodOverride = place.nameKu;
                                          // If pin is far (> 2.2 km), move pin to that neighborhood;
                                          // if already near/inside Kalar, keep exact house GPS pin!
                                          if (dist > 2200) {
                                            draftPin = place.center;
                                          }
                                          overrideAnchorPin = draftPin;
                                          draftNeighborhood = _closestNeighborhoodTo(
                                            draftPin.latitude,
                                            draftPin.longitude,
                                          );
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? RC.bg(const Color(0xFFFAC800))
                                              : RC.bg(const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? RC.bg(const Color(0xFFEAB308))
                                                : RC.bg(const Color(0xFFE2E8F0)),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          place.nameKu,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                            color: isSelected
                                                ? RC.fg(Colors.black)
                                                : RC.fg(const Color(0xFF334155)),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 9),
                              TextField(
                                controller: noteCtrl,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  hintText: _t('ناوی شوێن (پارک، ناوەند، ...)'),
                                  prefixIcon: Icon(Icons.location_on_rounded, color: RC.fg(Color(0xFFEAB308))),
                                  filled: true,
                                  fillColor: RC.bg(const Color(0xFFF8FAFC)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: RC.bg(Colors.grey.shade200)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: RC.bg(Colors.grey.shade200)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: RC.bg(const Color(0xFFFAC800)), width: 1.6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RC.bg(const Color(0xFFFAC800)),
                                    foregroundColor: RC.fg(Colors.black),
                                    elevation: 0,
                                    shadowColor: RC.bg(const Color(0xFFFAC800)).withValues(alpha: 0.45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () {
                                    final note = noteCtrl.text.trim();
                                    final resolvedArea = resolvedNeighborhoodLabel();
                                    // Always save exact GPS coordinates (lat, lng) as primary,
                                    // while preserving both resolvedArea and manual placeNote.
                                    context.read<LocationNotifier>().setPin(
                                      lat: draftPin.latitude,
                                      lng: draftPin.longitude,
                                      neighborhood: draftNeighborhood,
                                      clearNeighborhood: draftNeighborhood == null,
                                      placeNote: note.isEmpty ? null : note,
                                      clearPlaceNote: note.isEmpty,
                                      resolvedPlaceName: resolvedArea,
                                      clearResolvedPlaceName: resolvedArea.isEmpty,
                                    );
                                    setState(() {});
                                    Navigator.pop(context);
                                    final savedLabel =
                                        context.read<LocationNotifier>().displayPlaceLabel ??
                                        draftLabel();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          tx('📍 ${_t('شوێنی گەیاندن پاشەکەوت کرا')}: $savedLabel'),
                                        ),
                                        backgroundColor: RC.bg(Color(0xFF059669)),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check_rounded, size: 22),
                                  label: Text(
                                    _t('دیاریکردنی شوێن'),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      geocodeDebounce?.cancel();
      searchDebounce?.cancel();
      searchCtrl.dispose();
      noteCtrl.dispose();
    });
  }


  // 🔍 Comprehensive Search Modal (Stores, Categories, Products & Foods)
  void _openSearchModal() {
    Timer? searchDebounce;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQ = '';
        String displayedQ = ''; // Debounced query
        final TextEditingController searchCtrl = TextEditingController();

        final List<Map<String, dynamic>> searchCategories = _dynamicCategories.isNotEmpty
            ? _dynamicCategories
            : [
          {'title': 'خواردنگە و ڕێستۆرانتەکان', 'icon': Icons.restaurant_outlined, 'catName': 'خواردنگە'},
          {'title': 'مارکێت و سوپەرمارکێتەکان', 'icon': Icons.shopping_bag_outlined, 'catName': 'سوپەرمارکێت'},
          {'title': 'میوە و سەوزەی فرێش', 'icon': Icons.apple_outlined, 'catName': 'سەوزە و میوە'},
          {'title': 'شاوڕمە و فاست فوود', 'icon': Icons.local_fire_department_outlined, 'catName': 'فاست فوود'},
          {'title': 'شیرینی، کێک و باقلاوە', 'icon': Icons.cake_outlined, 'catName': 'شیرەمەنی و شیرینی'},
          {'title': 'کافێ و قاوەخانەکان', 'icon': Icons.local_cafe_outlined, 'catName': 'کافێ'},
          {'title': 'گۆشت و مریشکی تازه', 'icon': Icons.set_meal_outlined, 'catName': 'گۆشت و قەسابخانە'},
          {'title': 'نانەواخانه و سەموون', 'icon': Icons.bakery_dining_outlined, 'catName': 'نانەواخانە'},
          {'title': 'کۆسمەتیک و جوانکاری', 'icon': Icons.brush_outlined, 'catName': 'کۆسمەتیک'},
        ];

        final List<String> popularKeywords = [
          'کەباب', 'شاوڕمە', 'پیتزا', 'قوزی', 'سوپەرمارکێت', 'میوە', 'شیرینی', 'برنج', 'دۆ', 'کۆسمەتیک'
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = displayedQ.trim().toLowerCase();

            // Search Stores (Expensive filtering)
            final matchedStores = query.isEmpty
                ? <StoreItem>[]
                : allStores.where((s) {
                    return s.name.toLowerCase().contains(query) ||
                        s.category.toLowerCase().contains(query) ||
                        s.address.toLowerCase().contains(query);
                  }).toList();

            // Search Products (Expensive filtering)
            final matchedProducts = query.isEmpty
                ? <ProductItem>[]
                : allProducts.where((p) {
                    return p.name.toLowerCase().contains(query) ||
                        p.description.toLowerCase().contains(query) ||
                        p.category.toLowerCase().contains(query) ||
                        (p.subCategory != null && p.subCategory!.toLowerCase().contains(query));
                  }).toList();

            // Search Categories (match any of KU/AR/EN names)
            final matchedCats = query.isEmpty
                ? searchCategories
                : searchCategories.where((c) {
                    final title = _homeCatTitle(c).toLowerCase();
                    final catName = (c['catName'] as String? ?? '').toLowerCase();
                    final ar = (c['name_ar'] as String? ?? '').toLowerCase();
                    final en = (c['name_en'] as String? ?? '').toLowerCase();
                    return title.contains(query) ||
                        catName.contains(query) ||
                        ar.contains(query) ||
                        en.contains(query);
                  }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.88,
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                children: [
                  // Top Grabber Handle & Header
                  Container(
                    padding: const EdgeInsets.only(top: 12, bottom: 8, left: 16, right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.search, color: RC.fg(Color(0xFFFAC800)), size: 26),
                                SizedBox(width: 8),
                                Text(
                                  tx('گەڕان'),
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: RC.fg(Colors.black54)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search Input Field
                        TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          textAlign: TextAlign.right,
                          onChanged: (val) {
                            setModalState(() {
                              searchQ = val;
                            });
                            
                            // Debounce search update to avoid lag
                            if (searchDebounce?.isActive ?? false) searchDebounce!.cancel();
                            searchDebounce = Timer(const Duration(milliseconds: 300), () {
                              if (ctx.mounted) {
                                setModalState(() {
                                  displayedQ = val;
                                });
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: tx('گەڕان بۆ چێشتخانە، مارکێت، خواردن، بەشەکان...'),
                            hintStyle: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade500)),
                            prefixIcon: Icon(Icons.search, color: RC.fg(Color(0xFFFAC800))),
                            suffixIcon: searchQ.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 18, color: RC.fg(Colors.grey)),
                                    onPressed: () {
                                      setModalState(() {
                                        searchCtrl.clear();
                                        searchQ = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: RC.bg(Colors.grey.shade100),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Search Content List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      children: [
                        // IF QUERY IS EMPTY: SHOW QUICK SEARCHES & CATEGORIES
                        if (query.isEmpty) ...[
                          Text(
                            tx('🔥 گەڕانی باو و خێرا'),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: popularKeywords.map((kw) {
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    searchCtrl.text = kw;
                                    searchQ = kw;
                                  });
                                },
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: RC.bg(Color(0xFFFFFBEB)),
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                                    border: Border.all(color: RC.bg(Color(0xFFFDE68A))),
                                  ),
                                  child: Text(
                                    tx(kw),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFFD97706))),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            tx('📁 گەڕان بەپێی بەشەکان'),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                          ),
                          const SizedBox(height: 12),
                          ...searchCategories.map((c) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: RC.bg(Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: RC.bg(Colors.grey.shade200)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: RC.bg(Color(0xFFFAC800)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(c['icon'] as IconData, size: 20, color: RC.fg(Colors.black)),
                                ),
                                title: Text(
                                  tx(_homeCatTitle(c)),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                trailing: Icon(Icons.arrow_forward_ios, textDirection: TextDirection.ltr, size: 14, color: RC.fg(Colors.grey)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _openHomeCategory(c);
                                  _goTab(0);
                                },
                              ),
                            );
                          }).toList(),
                        ] else ...[
                          // SEARCH RESULTS VIEW
                          if (matchedStores.isEmpty && matchedProducts.isEmpty && matchedCats.isEmpty) ...[
                            const SizedBox(height: 40),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off_rounded, size: 64, color: RC.fg(Colors.grey.shade400)),
                                  const SizedBox(height: 12),
                                  Text(
                                    tx('هیچ ئەنجامێک بۆ "$searchQ" نەدۆزرایەوە'),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: RC.fg(Colors.black87)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    tx('تکایە دڵنیابەرەوە لە دروستی وشەی گەڕانەکەت'),
                                    style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade600)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 1. MATCHED CATEGORIES
                          if (matchedCats.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.category_outlined, size: 18, color: RC.fg(Color(0xFFD97706))),
                                SizedBox(width: 6),
                                Text(tx('بەشە دۆزراوەکان'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: matchedCats.map((c) {
                                return ActionChip(
                                  backgroundColor: RC.bg(Color(0xFFFAC800)),
                                  label: Text(tx(_homeCatTitle(c)), style: TextStyle(fontWeight: FontWeight.bold, color: RC.fg(Colors.black), fontSize: 12)),
                                  avatar: Icon(c['icon'] as IconData, size: 16, color: RC.fg(Colors.black)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _openHomeCategory(c);
                                    _goTab(0);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 2. MATCHED STORES (چێشتخانە و دوکانەکان)
                          if (matchedStores.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.storefront, size: 18, color: RC.fg(Color(0xFF059669))),
                                const SizedBox(width: 6),
                                Text(tx('چێشتخانە و دوکانەکان (${matchedStores.length})'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...matchedStores.map((store) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(10),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        _wrapClosedFilter(
                                          isOpen: store.isOpen,
                                          child: Image.network(
                                            store.imageUrl,
                                            width: 54,
                                            height: 54,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => Container(
                                              width: 54,
                                              height: 54,
                                              color: RC.bg(Colors.amber.shade100),
                                              child: Icon(Icons.store, color: RC.fg(Colors.amber)),
                                            ),
                                          ),
                                        ),
                                        if (!store.isOpen)
                                          Positioned.fill(
                                            child: Container(color: RC.bg(Colors.black).withOpacity(0.30)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  title: Text(tx(store.name), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Row(
                                    children: [
                                      Icon(Icons.star, size: 14, color: RC.fg(Colors.amber)),
                                      const SizedBox(width: 3),
                                      Text(tx('${store.ratingOutOf10}/10'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(width: 10),
                                      Text(tx('⏱ ${store.deliveryTime}'), style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade600))),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: RC.bg(Color(0xFFFAC800)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(tx('سەردان'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: RC.fg(Colors.black))),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() => _selectedStore = store);
                                    _goTab(0);
                                  },
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 4),
                          ],

                          // 3. MATCHED PRODUCTS (بابەتەکان و خواردنەکان)
                          if (matchedProducts.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.fastfood_outlined, size: 18, color: RC.fg(Color(0xFFD97706))),
                                const SizedBox(width: 6),
                                Text(tx('بابەتەکان و خواردنەکان (${matchedProducts.length})'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...matchedProducts.map((p) {
                              final store = allStores.cast<StoreItem?>().firstWhere(
                                (s) => s?.id == p.storeId,
                                orElse: () => null,
                              );
                              if (store == null) return const SizedBox.shrink();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          p.imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => Container(
                                            width: 60,
                                            height: 60,
                                            color: RC.bg(Colors.amber.shade100),
                                            child: Icon(Icons.fastfood, color: RC.fg(Colors.amber)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tx(p.name), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                            if (p.subCategory != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                tx(p.subCategory!),
                                                style: TextStyle(fontSize: 10, color: RC.fg(Color(0xFFD97706)), fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                            const SizedBox(height: 3),
                                            Text(tx('لە: ${store.name}'), style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade600))),
                                            const SizedBox(height: 4),
                                            Text(tx('${p.price} د.ع'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFFD97706)), fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: RC.bg(Color(0xFFFAC800)),
                                          foregroundColor: RC.fg(Colors.black),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          _addToCart(p);
                                        },
                                        child: Text(tx('+ سەبەتە'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }

  // 🔔 Comprehensive Notifications & Discount Offers Modal (from Admin)
  Future<void> _openNotificationsModal() async {
    await _syncNotificationsFromBackend();
    if (!mounted) return;

    // Persist mark-read for personal / fan-out rows when logged in.
    final unreadIds = _dynamicNotifications
        .where((n) => n['isRead'] != true)
        .map((n) => int.tryParse('${n['id']}'))
        .whereType<int>()
        .toList();
    if (unreadIds.isNotEmpty) {
      // Fire-and-forget; local badge clears immediately.
      CustomerApiService.instance.markNotificationsRead(ids: unreadIds);
    }

    setState(() {
      _unreadNotificationCount = 0;
      for (final n in _dynamicNotifications) {
        n['isRead'] = true;
      }
    });

    final List<Map<String, dynamic>> notificationsList =
        List<Map<String, dynamic>>.from(_dynamicNotifications);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filterTag = 'هەمووی';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredNotifs = notificationsList.where((n) {
              final tag = n['tag']?.toString() ?? '';
              if (filterTag == 'داشکاندن') {
                return tag.contains('داشکاندن') ||
                    tag.contains('کۆد') ||
                    tag.contains('ئۆفەر') ||
                    tag.contains('پرۆمۆشن');
              }
              if (filterTag == 'خواردنگە') return n['type'] == 'store' || n['type'] == 'category';
              return true;
            }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                children: [
                  // Top Grabber & Header Row
                  Container(
                    padding: const EdgeInsets.only(top: 12, bottom: 8, left: 16, right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Icon(Icons.notifications_active_rounded, color: RC.fg(Color(0xFFFAC800)), size: 26),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      tx('ئاگاداری و داشکاندنەکان'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: RC.fg(Colors.black54)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Filter Pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildNotifFilterChip('هەمووی', filterTag, (val) => setModalState(() => filterTag = val)),
                              const SizedBox(width: 8),
                              _buildNotifFilterChip('داشکاندن', filterTag, (val) => setModalState(() => filterTag = val)),
                              const SizedBox(width: 8),
                              _buildNotifFilterChip('خواردنگە', filterTag, (val) => setModalState(() => filterTag = val)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Notifications & Discounts Full-Width Vertical List (لە ئەدمینەوە)
                  Expanded(
                    child: filteredNotifs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none_rounded, size: 56, color: RC.fg(Colors.grey.shade300)),
                                  const SizedBox(height: 12),
                                  Text(
                                    tx('هیچ ئاگادارییەک نییە'),
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: RC.fg(Colors.grey.shade700)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: filteredNotifs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = filteredNotifs[index];
                        final IconData icon = notif['icon'] as IconData;
                        final Color iconColor = notif['color'] as Color;

                        // بۆکسی لیستی پانی بۆ هەر ئاگادارییەک بە شێوازی پانی تەواو لەسەر یەک
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: RC.bg(Colors.grey.shade200), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Colors.black).withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _handleNotificationTap(notif, context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1. ئایکۆنی ڕەنگاوڕەنگی سەرەکی بە قەبارەی بچووکتر
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: iconColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: iconColor.withOpacity(0.25), width: 1),
                                      ),
                                      child: Center(
                                        child: Icon(icon, color: iconColor, size: 19),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // 2. ناوەڕۆک بە شێوازی پانی و چڕتر
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // ناونیشانی ئاگاداری
                                          Text(
                                            tx(notif['title'] as String),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                              color: RC.fg(Colors.black87),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          // دەقی ڕوونکردنەوە
                                          Text(
                                            tx(notif['desc'] as String),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: RC.fg(Colors.grey.shade600),
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // کات و تاگی ئاگاداری
                                          Row(
                                            children: [
                                              Icon(Icons.access_time_rounded, size: 11, color: RC.fg(Colors.grey.shade500)),
                                              const SizedBox(width: 3),
                                              Text(
                                                tx(notif['time'] as String),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: RC.fg(Colors.grey.shade500),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: RC.bg(Colors.grey.shade100),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  tx(notif['tag'] as String),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: RC.fg(Colors.grey.shade700),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 3. باجی داشکاندن و دوگمەی بچووک لە تەنیشتەوە
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: RC.bg(Color(0xFFFEF3C7)),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: RC.bg(Color(0xFFFDE68A))),
                                          ),
                                          child: Text(
                                            tx(notif['discountBadge'] as String),
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              color: RC.fg(Color(0xFFD97706)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: RC.bg(Color(0xFFFAC800)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tx('بینین'),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: RC.fg(Colors.black),
                                                ),
                                              ),
                                              SizedBox(width: 2),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 8,
                                                color: RC.fg(Colors.black),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }

  Widget _buildNotifFilterChip(String label, String current, Function(String) onSelect) {
    final isSelected = label == current;
    return ChoiceChip(
      label: Text(
        tx(label),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isSelected ? RC.bg(Colors.black) : RC.bg(Colors.grey.shade700),
        ),
      ),
      selected: isSelected,
      selectedColor: RC.bg(Color(0xFFFAC800)),
      backgroundColor: RC.bg(Colors.grey.shade100),
      onSelected: (_) => onSelect(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when Provider-backed state changes.
    context.watch<CartNotifier>();
    context.watch<LocationNotifier>();
    final session = context.watch<SessionNotifier>();
    context.watch<OrdersNotifier>();
    context.watch<NavigationNotifier>();

    if (session.isRestoring) {
      // No splash: blank shell while session restores.
      return Scaffold(backgroundColor: RC.bg(const Color(0xFFF8FAFC)), body: const SizedBox.shrink());
    }

    // First launch / logged out: only login/register (no browsing).
    if (widget.forceAuthOnly || !session.isLoggedIn) {
      return Scaffold(
        backgroundColor: RC.bg(Color(0xFFF8FAFC)),
        body: SafeArea(child: _buildProfileTab()),
      );
    }

    // 🔒 No splash spinner while security check runs.
    if (_isCheckingSecurity) {
      return Scaffold(backgroundColor: RC.bg(Colors.white), body: const SizedBox.shrink());
    }

    // 🔒 ئەگەر ئامێرەکە هاککرابوو یان ئیمۆلیتۆر بوو، ڕێگری لێ بکە
    if (!_isDeviceSafe) {
      return _buildSecurityBlockedScreen();
    }

    // 📍 No splash spinner while location permission is checked.
    if (_isCheckingLocation) {
      return Scaffold(backgroundColor: RC.bg(Colors.white), body: const SizedBox.shrink());
    }

    // 📍 ئەگەر ڕێگەپێدانی لۆکەیشن نەدرابوو، شاشەی ئاگادارکردنەوە پیشان بدە و مەهێڵە ئەپەکە بەکاربێنێت
    if (!_isLocationAuthorized) {
      return _buildLocationRequiredScreen();
    }

    // 🛡️ ئەگەر VPN چالاک بوو، ڕێگری بکە
    if (_isVpnActive) {
      return _buildVpnBlockedScreen();
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _selectedStore != null
              ? _buildStoreDetailView(_selectedStore!)
              : Column(
                  children: [
                    // 💛 Header with Rounded Curved Corners (36px)
                    _buildHeader(),

                    // 📄 Active View Switcher
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: IndexedStack(
                            index: _currentIndex,
                            children: [
                              _buildHomeTab(),
                              _buildStoresTab(),
                              RegaResponsive.constrain(child: _buildCartTab()),
                              RegaResponsive.constrain(child: _buildOrdersTab()),
                              _buildProfileTab(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

          // 🚫 FULL SCREEN OFFLINE OVERLAY (Blocks all app interactions when offline)
          if (_isOffline) _buildOfflineScreen(),
        ],
      ),

      // 📍 Bottom Navigation Bar — yellow pill active tab (icon + label)
      bottomNavigationBar: _isOffline
          ? null
          : Container(
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
                        vertical: RegaResponsive.isPhone(context) ? 8 : 10,
                      ),
                      child: Row(
                        children: [
                          _buildBottomNavItem(0, _t('سەرەکی'), Icons.home_rounded, Icons.home_outlined),
                          _buildBottomNavItem(1, _t('داشکاندن'), Icons.local_offer_rounded, Icons.local_offer_outlined),
                          _buildBottomNavItem(2, _t('سەبەتە'), Icons.shopping_cart_rounded, Icons.shopping_cart_outlined, isCart: true),
                          _buildBottomNavItem(3, _t('داواکاری'), Icons.receipt_long_rounded, Icons.receipt_long_outlined),
                          _buildBottomNavItem(4, _t('پڕۆفایل'), Icons.person_rounded, Icons.person_outline_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // 📱 RESPONSIVE BREAKPOINT HELPERS (IPHONE, ANDROID, IPAD, TABLET)
  int _responsiveGridCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1024) return 4;
    if (w >= 640) return 3;
    return 2;
  }

  double _responsiveAspectRatio(BuildContext context, {required double mobile, required double tablet}) {
    final w = MediaQuery.of(context).size.width;
    return w >= 640 ? tablet : mobile;
  }

  Widget _buildBottomNavItem(int index, String label, IconData activeIcon, IconData inactiveIcon, {bool isCart = false}) {
    final bool isSelected = _currentIndex == index;
    final bool phone = RegaResponsive.isPhone(context);
    const pillYellow = Color(0xFFFAC800);
    const iconColor = Color(0xFF0F172A);
    final cartCount = isCart
        ? _cart.fold<int>(0, (sum, e) => sum + e.quantity)
        : 0;
    final iconSize = phone ? 20.0 : 22.0;

    Widget iconWidget = Icon(
      isSelected ? activeIcon : inactiveIcon,
      color: iconColor,
      size: iconSize,
    );

    // Cart: yellow pill look with red count badge on the cart icon (like design)
    if (isCart) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            isSelected ? activeIcon : inactiveIcon,
            color: iconColor,
            size: iconSize,
          ),
          if (cartCount > 0)
            Positioned(
              top: -6,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFEF4444)),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: RC.bg(Colors.white), width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  tx(cartCount > 99 ? '99+' : '$cartCount'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RC.fg(Colors.white),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Expanded(
      // Active yellow pill needs more width so 5 tabs don't clip on phone
      flex: isSelected ? (phone ? 3 : 2) : 1,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _goTab(index);
          if (index == 3) {
            _syncCustomerOrdersFromBackend();
          }
        },
        splashColor: pillYellow.withOpacity(0.2),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            clipBehavior: Clip.hardEdge,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? (phone ? 8 : 12) : (phone ? 4 : 8),
              vertical: phone ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? pillYellow : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                if (isSelected) ...[
                  SizedBox(width: phone ? 5 : 8),
                  Flexible(
                    child: Text(
                      tx(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: phone ? 11.5 : 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultTextLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tx('REGA'),
          style: TextStyle(
            color: RC.fg(Colors.black),
            fontSize: 32, // گەورەتر کراوە لە 26
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: RC.bg(Colors.black),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: RC.bg(Colors.black).withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            tx('ڕێگا'),
            style: TextStyle(
              color: RC.fg(Color(0xFFFAC800)),
              fontSize: 22, // گەورەتر کراوە
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // 🖼️ Smart Logo Widget (Base64 -> Asset PNG -> Network URL -> Default Text Logo)
  Widget _buildLogoWidget() {
    // 💡 پشتگیری بۆ لۆگۆی Base64
    if (appLogoUrl.trim().startsWith('data:image')) {
      try {
        final base64Str = appLogoUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: 48, // ڕێک 48 پێکسڵە
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildDefaultTextLogo(),
        );
      } catch (e) {
        return _buildDefaultTextLogo();
      }
    }

    if (appLogoAssetPath.trim().isNotEmpty) {
      return Image.asset(
        appLogoAssetPath,
        height: 48, // ڕێک 48 پێکسڵە
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          if (appLogoUrl.trim().isNotEmpty) {
            return Image.network(
              appLogoUrl,
              height: 48, // ڕێک 48 پێکسڵە
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildDefaultTextLogo(),
            );
          }
          return _buildDefaultTextLogo();
        },
      );
    } else if (appLogoUrl.trim().isNotEmpty) {
      return Image.network(
        appLogoUrl,
        height: 48, // ڕێک 48 پێکسڵە
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildDefaultTextLogo(),
      );
    }
    return _buildDefaultTextLogo();
  }

  // 🖼️ لۆگۆی خوارەوەی پڕۆفایل کە لە فۆڵدەری assets2 بار دەکرێت
  Widget _buildProfileFooterLogo() {
    return Image.asset(
      profileLogoAssetPath,
      height: 48,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // ئەگەر وێنەی ناو assets2 هێشتا زیاد نەکرا بوو یان دەستی پێ نەگەیشت، لۆگۆی سەرەکی نیشان دەدات تا هیچ کێشەیەک دروست نەبێت
        return _buildLogoWidget();
      },
    );
  }

  // ============================================================================
  // 💛 HEADER COMPONENT (EXACT SCREENSHOT DESIGN)
  // ============================================================================
  /// Row under yellow header: yellow GPS target (left) + داواکاری ڕاستەوخۆ pill (right).
  Widget _buildHomeDirectRequestBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Yellow circular location / GPS target (white ring like screenshot)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showLocationPicker,
              customBorder: const CircleBorder(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: RC.bg(Colors.black).withOpacity(0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    color: RC.bg(const Color(0xFFFAC800)),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.gps_fixed_rounded,
                    size: 20,
                    color: RC.fg(Colors.black),
                  ),
                ),
              ),
            ),
          ),
          // داواکاری ڕاستەوخۆ pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openDirectRequestScreen,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: RC.bg(Colors.black).withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  tx('داواکاری ڕاستەوخۆ'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: RC.fg(const Color(0xFF1E293B)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirectRequestScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DirectRequestScreen(
          initialPhone: _userProfile?.phone ?? '',
          initialAddress: _deliveryDisplayLabel == _t('شوێنی گەیاندن هەڵبژێرە')
              ? ''
              : _deliveryDisplayLabel,
          onPickAddress: () async {
            await _showLocationPicker();
            final label = _deliveryDisplayLabel;
            if (label == _t('شوێنی گەیاندن هەڵبژێرە')) return null;
            return label;
          },
        ),
      ),
    );
    if (result == true && mounted) {
      await _syncCustomerOrdersFromBackend();
      _goTab(3);
    }
  }

  Widget _buildHeader() {
    final double topPadding = MediaQuery.of(context).padding.top;
    const double toolbarHeight = 80.0; // تەواوی بەرزی ناڤباڕەکە (toolbarHeight: 80)
    return Container(
      height: toolbarHeight + topPadding,
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFFAC800)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: topPadding,
        left: 16,
        right: 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: SizedBox(
            height: toolbarHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Search Icon (RTL: First child renders on the Right)
                IconButton(
                  onPressed: _openSearchModal,
                  icon: Icon(Icons.search_rounded, color: RC.fg(Colors.black), size: 26),
                ),

                // Logo Center Badge (SizedBox بەرزی 52 پێکسڵ و لۆگۆ بە بەرزی 48 پێکسڵ بە BoxFit.contain)
                SizedBox(
                  height: 52,
                  child: Center(
                    child: _buildLogoWidget(),
                  ),
                ),

                // Notification Bell Icon with Badge (RTL: Third child renders on the Left)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: _openNotificationsModal,
                      icon: Icon(Icons.notifications_rounded, color: RC.fg(Colors.black), size: 26),
                    ),
                    if (_unreadNotificationCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.red),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            tx('$_unreadNotificationCount'),
                            style: TextStyle(color: RC.fg(Colors.white), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 🏠 TAB 1: HOME VIEW (EXACT MATCH FOR SCREENSHOT CATEGORIES GRID)
  // ============================================================================
  Widget _buildHomeTab() {
    final List<Map<String, dynamic>> categoriesList = _dynamicCategories;

    // 1-Column List of Vertical Store Cards for Category View
    if (_selectedCategory != 'گشتی') {
      final matchedHomeCat = _dynamicCategories.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['catName'] == _selectedCategory,
            orElse: () => null,
          );
      final selectedCatId = (matchedHomeCat?['id'] as num?)?.toInt();

      // Strict: vendor/items only under the home tile matching stores.category_id.
      // No fuzzy name matching (avoids leaking restaurants into other sections).
      final categoryStores = allStores.where((s) {
        final matchesSearch = _searchQuery.isEmpty ||
            s.name.contains(_searchQuery) ||
            s.category.contains(_searchQuery);
        final matchesCat = selectedCatId != null
            ? s.categoryId == selectedCatId
            : s.category == _selectedCategory;
        return matchesCat && matchesSearch;
      }).toList();
      final displayCatTitle = matchedHomeCat != null
          ? _homeCatTitle(matchedHomeCat)
          : (_selectedCategory == 'خواردنگە' ? 'خواردن' : _selectedCategory);

      return ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          // Header Bar for Category View with White Circle Back Arrow & Category Title (هەمان دیزاینی ئایکۆنی گەڕانەوەی وێنەی دووەم بە بازنەی سپی و تیری سوور)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _selectedCategory = 'گشتی'),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: RC.bg(Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(color: RC.bg(Colors.grey.shade200), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: RC.bg(Colors.black).withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      textDirection: TextDirection.ltr,
                      size: 23,
                      color: RC.fg(Color(0xFFE11D48)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx(displayCatTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: categoryStores.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RC.bg(Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Colors.grey.shade200)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.storefront_outlined, size: 48, color: RC.fg(Colors.grey.shade400)),
                        const SizedBox(height: 8),
                        Text(_t('هیچ دوکانێک لە بەشی') + ' ' + displayCatTitle + ' ' + _t('نەدۆزرایەوە'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _selectedCategory = 'گشتی'),
                          child: Text(_t('گەڕانەوە بۆ سەرجەم بەشەکان'), style: TextStyle(color: RC.fg(Colors.amber), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categoryStores.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _responsiveGridCount(context),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: _responsiveAspectRatio(context, mobile: 0.72, tablet: 0.82),
                    ),
                    itemBuilder: (context, index) {
                      final store = categoryStores[index];
                      return _buildVerticalGridStoreCard(store);
                    },
                  ),
          ),

          const SizedBox(height: 20),
        ],
      );
    }

    // MAIN GENERAL HOME TAB VIEW (WHEN 'گشتی' IS SELECTED)
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        // Location + داواکاری ڕاستەوخۆ — directly under yellow header
        _buildHomeDirectRequestBar(),
        // Dynamic promo / reklaming banners (admin-uploaded images)
        if (_dynamicBanners.isEmpty)
          const SizedBox.shrink()
        else
          _HomePromoBannerCarousel(
            banners: _dynamicBanners,
            onBannerTap: (banner) {
              if (banner['target_type'] == 'store' && banner['store_id'] != null) {
                StoreItem? matchStore;
                for (final st in allStores) {
                  if (st.id == 'db_store_${banner['store_id']}' ||
                      st.id == banner['store_id'].toString()) {
                    matchStore = st;
                    break;
                  }
                }
                if (matchStore != null) {
                  setState(() => _selectedStore = matchStore);
                }
              } else if (banner['target_type'] == 'category' && banner['category'] != null) {
                final cat = banner['category'];
                final cName = cat is Map ? cat['name_ku'] : null;
                if (cName != null) {
                  setState(() => _selectedCategory = cName.toString());
                }
              }
            },
          ),

        // Categories from backend only
        if (categoriesList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
            child: Center(
              child: Text(
                _t('هیچ داتایەک نییە'),
                style: TextStyle(color: RC.fg(Color(0xFF94A3B8)), fontWeight: FontWeight.w700),
              ),
            ),
          )
        else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categoriesList.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _responsiveGridCount(context),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: _responsiveAspectRatio(context, mobile: 0.82, tablet: 0.95),
            ),
            itemBuilder: (context, index) {
            final cat = categoriesList[index];
            final imageUrl = cat['image']?.toString() ?? '';
            return InkWell(
              onTap: () => _openHomeCategory(cat),
              borderRadius: BorderRadius.circular(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    if (imageUrl.isEmpty)
                      Container(
                        color: RC.bg(Color(0xFFE2E8F0)),
                        alignment: Alignment.center,
                        child: Icon(
                          (cat['icon'] as IconData?) ?? Icons.category_rounded,
                          size: 42,
                          color: RC.fg(Color(0xFF94A3B8)),
                        ),
                      )
                    else
                      Image.network(
                        imageUrl,
                        height: double.infinity,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: RC.bg(Color(0xFFE2E8F0)),
                          alignment: Alignment.center,
                          child: Icon(
                            (cat['icon'] as IconData?) ?? Icons.category_rounded,
                            size: 42,
                            color: RC.fg(Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    // Category Name Tag at Bottom Right (Flush with edges as per screenshot)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFFFAC800)),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          tx(_homeCatTitle(cat)),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: RC.fg(Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 20),
    ],
  );
}

  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  Widget _wrapClosedFilter({required bool isOpen, required Widget child}) {
    if (isOpen) return child;
    return ColorFiltered(
      colorFilter: _grayscaleFilter,
      child: child,
    );
  }

  Widget _buildVerticalGridStoreCard(StoreItem store) {
    final rawBadge = store.discountBadge?.trim() ?? '';
    final isFreeDelivery = store.isFreeDelivery;
    final isFreeBadge = rawBadge.toUpperCase().contains('FREE') || rawBadge.contains('خۆڕای');
    final hasDiscount = rawBadge.isNotEmpty && !isFreeBadge;
    final pctMatch = RegExp(r'(\d+)\s*%|%\s*(\d+)').firstMatch(rawBadge);
    final pctText = pctMatch != null
        ? '%${pctMatch.group(1) ?? pctMatch.group(2)}'
        : rawBadge.replaceFirst(RegExp(r'^OFF\s*', caseSensitive: false), '').trim();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStore = store;
          _selectedSubCategory = null;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover Image
            _wrapClosedFilter(
              isOpen: store.isOpen,
              child: Image.network(
                store.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: RC.bg(Colors.grey.shade200),
                  alignment: Alignment.center,
                  child: Icon(Icons.storefront_rounded, color: RC.fg(Colors.grey), size: 36),
                ),
              ),
            ),
            // Dimmed overlay when closed
            if (!store.isOpen)
              Positioned.fill(
                child: Container(
                  color: RC.bg(Colors.black).withOpacity(0.30),
                ),
              ),
            // Soft bottom fade so yellow bar stays readable
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      RC.bg(Colors.black).withOpacity(0.45),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // Top Green Free Delivery Banner (گەیاندن خۆڕاییە) — exactly matches design
            if (isFreeDelivery)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: RC.bg(const Color(0xFF059669)),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tx('گەیاندن خۆڕاییە'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Top-right status pill (کراوە / داخراوە)
            Positioned(
              top: isFreeDelivery ? 36 : 10,
              right: 10,
              child: _buildStoreOpenBadge(store.isOpen),
            ),
            // Top-left diagonal discount ribbon (داشکاندن %)
            if (hasDiscount)
              Positioned(
                top: isFreeDelivery ? 28 : 0,
                left: 0,
                child: _buildDiscountCornerRibbon(pctText, size: 86),
              ),
            // Bottom-right yellow name tag (same style as category cards)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: RC.bg(const Color(0xFFFAC800)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                  ),
                ),
                child: Text(
                  tx(store.name),
                  style: TextStyle(
                    color: RC.fg(Colors.black),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(StoreItem store) {
    final isFav = _favoriteStoreIds.contains(store.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: RC.bg(Colors.grey.shade200)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          setState(() {
            _selectedStore = store;
            _selectedSubCategory = null;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: _wrapClosedFilter(
                    isOpen: store.isOpen,
                    child: Image.network(store.imageUrl, height: 145, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
                if (!store.isOpen)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      child: Container(color: RC.bg(Colors.black).withOpacity(0.30)),
                    ),
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    style: IconButton.styleFrom(backgroundColor: RC.bg(Colors.white).withOpacity(0.9)),
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? RC.fg(Colors.red) : RC.bg(Colors.black), size: 20),
                    onPressed: () {
                      setState(() {
                        if (isFav) {
                          _favoriteStoreIds.remove(store.id);
                        } else {
                          _favoriteStoreIds.add(store.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx(store.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tx('${store.category} • ${store.deliveryTime}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: RC.bg(Colors.amber.shade50), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 14, color: RC.fg(Colors.amber)),
                        const SizedBox(width: 4),
                        Text(tx('${store.ratingOutOf10}/10'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔍 شاشەی فۆڵ شاشەی وێنە لەگەڵ تایبەتمەندی Zoom
  void _showFullScreenZoomableImage({
    required BuildContext context,
    required String imageUrl,
    required String title,
    int? price,
    String? category,
  }) {
    showDialog(
      context: context,
      barrierColor: RC.bg(Colors.black).withOpacity(0.96),
      builder: (ctx) => FullScreenImageViewer(
        imageUrl: imageUrl,
        title: title,
        price: price,
        category: category,
      ),
    );
  }

  Widget _buildStoreDetailView(StoreItem store) {
    final isFav = _favoriteStoreIds.contains(store.id);
    final storeProds = allProducts.where((p) => p.storeId == store.id).toList();

    // Dynamically build Sub-categories ("بابەتەکان") for this store
    final Map<String, List<ProductItem>> subCatMap = {};
    for (var p in storeProds) {
      final cat = p.subCategory ?? 'گشتی';
      subCatMap.putIfAbsent(cat, () => []).add(p);
    }

    final menuMeta = _storeMenuCategoryMeta[store.id] ?? {};
    final List<Map<String, dynamic>> subCategories = [];
    subCatMap.forEach((catTitle, prods) {
      final meta = menuMeta[catTitle];
      final primary = meta?['image_url']?.toString() ?? '';
      final secondary = meta?['secondary_image_url']?.toString() ?? '';
      final fallback = prods.isNotEmpty ? prods.first.imageUrl : store.imageUrl;
      subCategories.add({
        // Stable key (name_ku) for product filtering; displayTitle is locale-aware.
        'title': catTitle,
        'displayTitle': _menuChipTitle(catTitle, meta),
        'badge': '${prods.length} بەرهەم',
        'isDiscount': false,
        'image': primary.isNotEmpty ? primary : fallback,
        'secondaryImage': secondary,
        'sort_order': (meta?['sort_order'] as int?) ?? 999,
      });
    });
    subCategories.sort((a, b) =>
        ((a['sort_order'] as int?) ?? 999).compareTo((b['sort_order'] as int?) ?? 999));

    final List<ProductItem> activeProds = storeProds.where((p) {
      if (_selectedSubCategory == null || _selectedSubCategory == 'گشتی') return true;
      return p.subCategory == _selectedSubCategory;
    }).toList();

    final displayProds = activeProds.isNotEmpty ? activeProds : storeProds;

    final topPadding = MediaQuery.of(context).padding.top;
    final coverHeight = (MediaQuery.of(context).size.width >= 640 ? 240.0 : 200.0) + topPadding;

    return Container(
      color: RC.bg(Colors.white),
      child: Column(
        children: [
          // 1. Top Cover Banner Header
          Stack(
            children: [
              Container(
                height: coverHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(store.imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: !store.isOpen ? _grayscaleFilter : null,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: !store.isOpen ? RC.bg(Colors.black).withOpacity(0.30) : null,
                    gradient: LinearGradient(
                      colors: [RC.bg(Colors.black).withOpacity(0.5), Colors.transparent, RC.bg(Colors.black).withOpacity(0.3)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              // Top Left: Favorite / Heart Button
              Positioned(
                top: topPadding + 10,
                left: 14,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isFav) {
                        _favoriteStoreIds.remove(store.id);
                      } else {
                        _favoriteStoreIds.add(store.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: RC.bg(Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(color: RC.bg(Colors.grey.shade200), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: RC.bg(Colors.black).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: RC.fg(Color(0xFFE11D48)),
                      size: 23,
                    ),
                  ),
                ),
              ),
              // Top Right: Back Arrow Button (Pointing Right →) - هاوشێوەی وێنەی دووەم بە بازنەی سپی و تیری سوور
              Positioned(
                top: topPadding + 10,
                right: 14,
                child: InkWell(
                  onTap: () {
                    if (_selectedSubCategory != null) {
                      setState(() => _selectedSubCategory = null);
                    } else {
                      setState(() => _selectedStore = null);
                    }
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: RC.bg(Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(color: RC.bg(Colors.grey.shade200), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: RC.bg(Colors.black).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      textDirection: TextDirection.ltr,
                      color: RC.fg(Color(0xFFE11D48)),
                      size: 23,
                    ),
                  ),
                ),
              ),
              // 💛 Bottom Curved Tab (هێڵکاری کەوانەیی بە ڕەنگی ئەپەکە): ⭐ Rating • 🚲 Delivery Fee • 📍 Distance
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(
                          painter: _StoreHeaderCurvedTabPainter(),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Builder(
                                builder: (context) {
                                  final loc = context.watch<LocationNotifier>();
                                  final userLat = loc.pinnedLat;
                                  final userLng = loc.pinnedLng;
                                  String distanceLabel = '— کم';
                                  if (userLat != null && userLng != null) {
                                    final meters = Geolocator.distanceBetween(
                                      userLat,
                                      userLng,
                                      store.lat,
                                      store.lng,
                                    );
                                    final km = meters / 1000.0;
                                    distanceLabel = km < 10
                                        ? '${km.toStringAsFixed(1)} کم'
                                        : '${km.toStringAsFixed(0)} کم';
                                  }
                                  final fee = store.isFreeDelivery
                                      ? 0
                                      : (store.deliveryFee > 0
                                          ? store.deliveryFee
                                          : _deliveryFeeOrZero);
                                  final reviews = store.reviewCount > 0 ? store.reviewCount : null;
                                  final ratingText = reviews != null
                                      ? '${store.ratingOutOf10}/10 ($reviews)'
                                      : '${store.ratingOutOf10}/10';

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      // ⭐ ڕێژەی ئەستێرە لە ١٠
                                      Icon(Icons.star_rounded, color: RC.fg(Colors.black), size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        tx(ratingText),
                                        style: TextStyle(
                                          color: RC.fg(Colors.black),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(tx('•'), style: TextStyle(color: RC.fg(Colors.black).withOpacity(0.35), fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 8),

                                      // 🚲 نرخی گەیاندنی ماتۆرسوار
                                      Icon(Icons.directions_bike_rounded, color: RC.fg(Colors.black), size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        store.isFreeDelivery || fee == 0
                                            ? tx('خۆڕایی')
                                            : tx('$fee د.ع'),
                                        style: TextStyle(
                                          color: RC.fg(Colors.black),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(tx('•'), style: TextStyle(color: RC.fg(Colors.black).withOpacity(0.35), fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 8),

                                      // 📍 دووری کیلۆمەتر لە شوێنی کڕیار
                                      Icon(Icons.location_on_rounded, color: RC.fg(Colors.black), size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        tx(distanceLabel),
                                        style: TextStyle(
                                          color: RC.fg(Colors.black),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Store Title Bar (Name + Open Status Badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              border: Border(bottom: BorderSide(color: RC.bg(Colors.grey.shade200))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tx(store.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                  ),
                ),
                const SizedBox(width: 12),
                _buildStoreOpenBadge(store.isOpen),
              ],
            ),
          ),

          // 3. Body Content
          Expanded(
            child: Container(
              color: RC.bg(Colors.grey.shade50),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: RegaResponsive.constrain(
                maxWidth: RegaResponsive.wideMaxWidth,
                child: _selectedSubCategory == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: | بابەتەکان (Right-aligned in RTL)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: RC.bg(Color(0xFFFAC800)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tx('بابەتەکان'),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 2-Column Grid of Categories ("بابەتەکان")
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: subCategories.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _responsiveGridCount(context),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 8,
                              childAspectRatio: _responsiveAspectRatio(context, mobile: 0.95, tablet: 1.10),
                            ),
                            itemBuilder: (context, idx) {
                              final cat = subCategories[idx];
                              final bool isDiscount = cat['isDiscount'] == true;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedSubCategory = cat['title'] as String;
                                  });
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        cat['image'] as String,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [RC.bg(Colors.black).withOpacity(0.4), Colors.transparent],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Top-left badge only for discounts (ئۆفەری تایبەت) — hide "N بەرهەم"
                                      if (isDiscount)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: RC.bg(Color(0xFFE11D48)),
                                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                                            ),
                                            child: Text(
                                              tx(cat['badge'] as String),
                                              style: TextStyle(color: RC.fg(Colors.white), fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      // Bottom Right Tag ("کەباب و برژاوەکان <")
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDiscount ? RC.bg(Color(0xFFE11D48)) : RC.bg(Color(0xFFFAC800)),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tx((cat['displayTitle'] as String?) ??
                                                    (cat['title'] as String)),
                                                style: TextStyle(
                                                  color: RC.fg(Colors.black),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.chevron_right,
                                                textDirection: TextDirection.ltr,
                                                size: 14,
                                                color: RC.fg(Colors.black),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header displaying selected sub-category title + Back button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: RC.bg(Color(0xFFFAC800)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tx(() {
                                    final key = _selectedSubCategory!;
                                    final hit = subCategories.cast<Map<String, dynamic>?>().firstWhere(
                                          (c) => c?['title'] == key,
                                          orElse: () => null,
                                        );
                                    return (hit?['displayTitle'] as String?) ?? key;
                                  }()),
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSubCategory = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: RC.bg(Colors.amber.shade50),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: RC.bg(Colors.amber.shade300)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back_ios_new, size: 11, color: RC.fg(Color(0xFFD97706))),
                                    SizedBox(width: 4),
                                    Text(
                                      tx('هەموو بابەتەکان'),
                                      style: TextStyle(
                                        color: RC.fg(Color(0xFFD97706)),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // List of products inside selected sub-category (2-Column Grid matching user's design)
                        Expanded(
                          child: displayProds.isEmpty
                              ? Center(child: Text(tx('هیچ بەرهەمێک نەدۆزرایەوە')))
                              : GridView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: displayProds.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _responsiveGridCount(context),
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: _responsiveAspectRatio(context, mobile: 0.68, tablet: 0.76),
                                  ),
                                  itemBuilder: (context, i) {
                                    final p = displayProds[i];
                                    final bool isDiscountItem = p.subCategory == 'داشکاندنەکان' || (i % 2 == 1 && p.price >= 8000);
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: RC.bg(Colors.white),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: RC.bg(Colors.grey.shade200)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: RC.bg(Colors.black).withOpacity(0.02),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Top: Product Cover Image + Zoom on click + Optional % Discount Badge
                                            GestureDetector(
                                              onTap: () {
                                                _showFullScreenZoomableImage(
                                                  context: context,
                                                  imageUrl: p.imageUrl,
                                                  title: p.name,
                                                  price: p.price,
                                                  category: p.subCategory,
                                                );
                                              },
                                              child: Stack(
                                                children: [
                                                  Image.network(
                                                    p.imageUrl,
                                                    height: 105,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => Container(
                                                      height: 105,
                                                      color: RC.bg(Colors.amber.shade50),
                                                      alignment: Alignment.center,
                                                      child: Icon(Icons.fastfood, color: RC.fg(Colors.amber)),
                                                    ),
                                                  ),
                                                  if (isDiscountItem)
                                                    Positioned(
                                                      top: 0,
                                                      left: 0,
                                                      child: _buildDiscountCornerRibbon('%17', size: 72),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Bottom: Product Details (Title, Price, Add Button)
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Product Title (Clickable to open Zoom Viewer)
                                                    GestureDetector(
                                                      onTap: () {
                                                        _showFullScreenZoomableImage(
                                                          context: context,
                                                          imageUrl: p.imageUrl,
                                                          title: p.name,
                                                          price: p.price,
                                                          category: p.subCategory,
                                                        );
                                                      },
                                                      child: Text(
                                                        tx(p.name),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11.5,
                                                          color: RC.fg(Colors.black),
                                                          height: 1.15,
                                                        ),
                                                      ),
                                                    ),

                                                    // Price & Plus Button Row (Right: Price, Left: Plus Button)
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        // Price Text (Right side in RTL)
                                                        Flexible(
                                                          child: Text(
                                                            tx('${p.price} د.ع'),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              color: RC.fg(Color(0xFFD97706)),
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: 11.5,
                                                            ),
                                                          ),
                                                        ),

                                                        // Yellow Square + Button (Left side in RTL)
                                                        InkWell(
                                                          onTap: () {
                                                            _addToCart(p);
                                                          },
                                                          borderRadius: BorderRadius.circular(12),
                                                          child: Container(
                                                            width: 42,
                                                            height: 42,
                                                            decoration: BoxDecoration(
                                                              color: RC.bg(Color(0xFFFAC800)),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Icon(
                                                              Icons.add,
                                                              size: 24,
                                                              color: RC.fg(Colors.black),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
        ],
      ),
    );
  }

  // ============================================================================
  // 🏷️ TAB 2: DISCOUNTS & STORES VIEW (ONLY STORES WITH DISCOUNTS)
  // ============================================================================
  Widget _buildStoresTab() {
    // Filter to ONLY stores & restaurants that have an active discount or special offer
    final discountStores = allStores.where((s) => (s.discountBadge != null && s.discountBadge!.trim().isNotEmpty) || s.isFreeDelivery).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.local_offer_rounded, color: RC.fg(Color(0xFFE11D48)), size: 22),
                const SizedBox(width: 8),
                Text(
                  tx('${_t('ئۆفەرەکان')} (${discountStores.length})'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: discountStores.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _responsiveGridCount(context),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: _responsiveAspectRatio(context, mobile: 0.72, tablet: 0.82),
          ),
          itemBuilder: (context, index) {
            final store = discountStores[index];
            return _buildVerticalGridStoreCard(store);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _formatNum(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // ============================================================================
  // 🛒 TAB 3: CART VIEW
  // ============================================================================
  Widget _buildCartTab() {
    if (_cart.isEmpty) {
      return Container(
        color: RC.bg(Colors.white),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: RegaResponsive.pagePadding(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular Yellow Cart Graphic with Top-Right (+) Badge (Clickable to go home)
                GestureDetector(
                  onTap: () => _goTab(0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [RC.bg(Color(0xFFFFDE59)), RC.bg(Color(0xFFFAC800)), RC.bg(Color(0xFFEAB308))],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: RC.bg(Color(0xFFEAB308)).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shopping_cart_rounded,
                            size: 48,
                            color: RC.fg(Colors.white),
                          ),
                        ),
                      ),
                      // Top-Right Plus (+) Indicator Badge
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFEAB308)),
                            shape: BoxShape.circle,
                            border: Border.all(color: RC.bg(Colors.white), width: 2),
                            boxShadow: [
                              BoxShadow(color: RC.bg(Colors.black12), blurRadius: 4),
                            ],
                          ),
                          child: Center(
                            child: Icon(Icons.add, size: 14, color: RC.fg(Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Exact text requested
                Text(
                  _t('سەبەتەکەت بەتاڵە! دەست بکە بە زیادکردنی بەرهەمەکانت بۆ درێژەدان.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Colors.black87),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final subtotal = _cart.fold<int>(0, (sum, i) => sum + (i.product.price * i.quantity));
    final deliveryFee = _deliveryFeeOrZero;
    final grandTotal = subtotal + deliveryFee;

    // Find primary store name for cart header
    String storeName = '-';
    if (_cart.isNotEmpty) {
      final storeId = _cart.first.product.storeId;
      for (final s in allStores) {
        if (s.id == storeId) {
          storeName = s.name;
          break;
        }
      }
      if (storeName == '-') storeName = _cart.first.product.storeId;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ----------------------------------------------------------------------
        // TOP HEADER: Title + Store Subtitle (Right) & Clear All Button (Left)
        // ----------------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Right Column: Title + Store Name Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('سەبەتەی کڕین'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: RC.fg(Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx('${_t('داواکاری لە:')} $storeName'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: RC.fg(Colors.grey.shade700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.storefront_rounded, size: 16, color: RC.fg(Color(0xFFD97706))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Left Pill Button: Clear All (سڕینەوەی هەموو)
            InkWell(
              onTap: () {
                setState(() {
                  _cart.clear();
                });
              },
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFF1F2)),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  border: Border.all(color: RC.bg(Color(0xFFFECDD3))),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: RC.fg(Color(0xFFE11D48))),
                    const SizedBox(width: 4),
                    Text(
                      _t('سڕینەوەی هەموو'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: RC.fg(Color(0xFFE11D48)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Divider(height: 1, color: RC.bg(Colors.grey.shade200)),
        const SizedBox(height: 16),

        // ----------------------------------------------------------------------
        // CART ITEMS LIST
        // ----------------------------------------------------------------------
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cart.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final entry = _cart[idx];
            final itemTotal = entry.product.price * entry.quantity;

            Widget yellowQtyBtn({required IconData icon, required VoidCallback onTap}) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: RC.bg(const Color(0xFFFAC800)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: RC.fg(Colors.black)),
                ),
              );
            }

            Widget moneyLine({
              required int amount,
              required Color amountColor,
              required double amountSize,
            }) {
              return Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _formatNum(amount),
                      style: TextStyle(
                        color: amountColor,
                        fontSize: amountSize,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    TextSpan(
                      text: ' ${_t('دینار')}',
                      style: TextStyle(
                        color: RC.fg(Colors.grey.shade500),
                        fontSize: amountSize * 0.72,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: RC.bg(Colors.black).withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Right (RTL start): product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      entry.product.imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: RC.bg(Colors.grey.shade200),
                        child: Icon(Icons.fastfood, color: RC.fg(Colors.grey)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Middle: title + unit price + qty
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx(entry.product.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: RC.fg(const Color(0xFF0F172A)),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        moneyLine(
                          amount: entry.product.price,
                          amountColor: RC.fg(const Color(0xFFE11D48)),
                          amountSize: 13,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.white),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: RC.bg(Colors.grey.shade300)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              yellowQtyBtn(
                                icon: Icons.add,
                                onTap: () => setState(() => entry.quantity++),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  tx('${entry.quantity}'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: RC.fg(Colors.black),
                                  ),
                                ),
                              ),
                              yellowQtyBtn(
                                icon: Icons.remove,
                                onTap: () {
                                  setState(() {
                                    if (entry.quantity > 1) {
                                      entry.quantity--;
                                    } else {
                                      _cart.removeAt(idx);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Left (RTL end): delete + line total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _cart.removeAt(idx)),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 22,
                            color: RC.fg(const Color(0xFFE11D48)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      moneyLine(
                        amount: itemTotal,
                        amountColor: RC.fg(const Color(0xFF0F172A)),
                        amountSize: 15,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ----------------------------------------------------------------------
        // ORDER SUMMARY CARD (کورتیی داواکاری)
        // ----------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RC.bg(Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: RC.bg(Colors.black).withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('کورتیی داواکاری'),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: RC.fg(Colors.black),
                ),
              ),
              const SizedBox(height: 14),

              // Row 1: Subtotal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _t('کۆی گشتی کاڵاکان'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: RC.fg(Colors.grey.shade800), fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tx('${_formatNum(subtotal)} ${_t('د.ع')}'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RC.fg(Colors.black)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Delivery Fee
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _t('تێچووی گەیاندن'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: RC.fg(Colors.grey.shade800), fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    deliveryFee == 0
                        ? tx('خۆڕایی')
                        : tx('${_formatNum(deliveryFee)} ${_t('د.ع')}'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: deliveryFee == 0 ? RC.fg(const Color(0xFF059669)) : RC.fg(Colors.black),
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Row 3: Grand Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _t('کۆی گشتی حساب'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tx('${_formatNum(grandTotal)} ${_t('د.ع')}'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: RC.fg(Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ----------------------------------------------------------------------
        // CHECKOUT BUTTON (تەواوکردنی داواکاری ←)
        // ----------------------------------------------------------------------
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFFAC800)),
              foregroundColor: RC.fg(Colors.black),
              elevation: 2,
              shadowColor: RC.bg(Color(0xFFFAC800)).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: _handleProceedToCheckout,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _t('تەواوکردنی داواکاری'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(Colors.black),
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_back_rounded,
                  textDirection: TextDirection.ltr,
                  size: 20,
                  color: RC.fg(Colors.black),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ============================================================================
  // 📋 TAB 4: ORDERS VIEW
  // ============================================================================
  ({int total, int active, int completed, int cancelled}) _orderStats() {
    var active = 0;
    var completed = 0;
    var cancelled = 0;
    for (final o in _orders) {
      final isDelivered = o.status == 'delivered' || o.status == 'completed';
      final isCancelled = o.status == 'cancelled' || o.status == 'rejected';
      if (isDelivered) {
        completed++;
      } else if (isCancelled) {
        cancelled++;
      } else {
        active++;
      }
    }
    return (total: _orders.length, active: active, completed: completed, cancelled: cancelled);
  }

  Widget _buildOrderStatsSummary() {
    final stats = _orderStats();
    Widget cell({
      required String label,
      required int count,
      required Color color,
      required String filterKey,
      required IconData icon,
    }) {
      final selected = _selectedOrderFilter == filterKey;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _selectedOrderFilter = filterKey),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.14) : RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : RC.bg(Colors.grey.shade200),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 4),
                Text(
                  tx('$count'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx(label),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : RC.fg(Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cells = [
      cell(
        label: _t('هەموو'),
        count: stats.total,
        color: RC.bg(Color(0xFF111827)),
        filterKey: 'هەموو',
        icon: Icons.receipt_long_rounded,
      ),
      cell(
        label: _t('بەردەوام'),
        count: stats.active,
        color: RC.bg(Color(0xFFD97706)),
        filterKey: 'بەردەوام',
        icon: Icons.timelapse_rounded,
      ),
      cell(
        label: _t('تەواوبوو'),
        count: stats.completed,
        color: RC.bg(Color(0xFF059669)),
        filterKey: 'تەواوبوو',
        icon: Icons.check_circle_rounded,
      ),
      cell(
        label: _t('هەڵوەشایەوە'),
        count: stats.cancelled,
        color: RC.bg(Color(0xFFDC2626)),
        filterKey: 'هەڵوەشایەوە',
        icon: Icons.cancel_rounded,
      ),
    ];

    final phone = MediaQuery.sizeOf(context).width < RegaBreakpoints.phone;
    if (phone) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          children: [
            Row(children: [cells[0], const SizedBox(width: 8), cells[1]]),
            const SizedBox(height: 8),
            Row(children: [cells[2], const SizedBox(width: 8), cells[3]]),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            cells[i],
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    final stats = _orderStats();
    final filteredOrders = _orders.where((order) {
      if (_selectedOrderFilter == 'هەموو') return true;
      final isDelivered = order.status == 'delivered' || order.status == 'completed';
      final isCancelled = order.status == 'cancelled' || order.status == 'rejected';
      final isActive = !isDelivered && !isCancelled;
      if (_selectedOrderFilter == 'بەردەوام') return isActive;
      if (_selectedOrderFilter == 'تەواوبوو') return isDelivered;
      if (_selectedOrderFilter == 'هەڵوەشایەوە') return isCancelled;
      return true;
    }).toList();

    return RefreshIndicator(
      color: RC.bg(const Color(0xFFF59E0B)),
      onRefresh: _syncCustomerOrdersFromBackend,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Title
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: RegaResponsive.pagePadding(context),
                right: RegaResponsive.pagePadding(context),
                bottom: 4,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    _t('داواکاریەکانم'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  );
                  final count = Text(
                    tx('${stats.total} ${_t('داواکاری')}'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: RC.fg(Colors.grey.shade600),
                    ),
                  );
                  if (constraints.maxWidth < RegaBreakpoints.phone) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        count,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      count,
                    ],
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildOrderStatsSummary(),
          ),
          // Divider
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: RC.bg(Colors.grey.shade200), thickness: 1),
            ),
          ),
          // Filter Chips
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: RC.bg(Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    _buildOrderFilterChip('هەموو', count: stats.total),
                    _buildOrderFilterChip('بەردەوام', count: stats.active),
                    _buildOrderFilterChip('تەواوبوو', count: stats.completed),
                    _buildOrderFilterChip('هەڵوەشایەوە', count: stats.cancelled),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 8),
          ),
          // Orders List or Empty State
          if (_orders.isEmpty || filteredOrders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 72, color: RC.fg(Colors.grey.shade400)),
                      const SizedBox(height: 16),
                      Text(
                        _orders.isEmpty
                            ? _t('هیچ داواکارییەکی تۆمارکراوت نییە')
                            : _t('هیچ داواکارییەک لەم بەشەدا نییە'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    final order = filteredOrders[idx];
                    return _buildOrderCard(order);
                  },
                  childCount: filteredOrders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderFilterChip(String key, {int? count}) {
    final isSelected = _selectedOrderFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOrderFilter = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? RC.bg(Color(0xFFFAC800)) : Colors.transparent,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Text(
          tx(count == null ? _t(key) : '${_t(key)} ($count)'),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? RC.bg(Colors.black) : RC.bg(Colors.grey.shade600),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showReceiptModal(OrderItem order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).padding.bottom + 20,
              ),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (ناونیشان لە ڕاست و دوگمەی داخستن لە چەپ)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _t('پسوولەی داواکاری REGA'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: RC.bg(Colors.grey.shade100),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: RC.fg(Colors.black87)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Info Box (ناوەکان و ناونیشانەکان لە ڕاست، بەها و زانیارییەکان لە چەپ)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RC.bg(Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    _buildReceiptInfoRow(_t('فرۆشگا:'), order.storeName),
                    const SizedBox(height: 8),
                    _buildReceiptInfoRow(_t('کڕیار:'), '${_userProfile?.name ?? '-'} (${_userProfile?.phone ?? '-'})'),
                    const SizedBox(height: 8),
                    _buildReceiptInfoRow(_t('ناونیشان:'), order.address),
                    const SizedBox(height: 8),
                    _buildReceiptInfoRow(_t('شێوازی پارەدان:'), _t('نەختینە (کاش)')),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Items (بابەتەکان لە ڕاست، نرخەکان لە چەپ)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(_t('بابەتەکان:'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tx('${item.product.name} × ${item.quantity}'),
                        textAlign: TextAlign.start,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tx('${_formatNum(item.product.price * item.quantity)} ${_t('د.ع')}'),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              )),
              
              const SizedBox(height: 16),
              Divider(color: RC.bg(Colors.grey.shade200)),
              const SizedBox(height: 16),
              
              // Totals (ناوەکان لە ڕاست، کۆی پارە لە چەپ)
              _buildReceiptTotalRow(_t('کۆی گشتی کاڵاکان:'), '${_formatNum(order.totalAmount - 1500)} ${_t('د.ع')}', false),
              const SizedBox(height: 8),
              _buildReceiptTotalRow(_t('تێچووی گەیاندن:'), '1,500 ${_t('د.ع')}', false),
              
              const SizedBox(height: 16),
              _buildReceiptTotalRow(_t('کۆی گشتی حساب:'), '${_formatNum(order.totalAmount)} ${_t('د.ع')}', false, isGrand: true),
              
              const SizedBox(height: 24),
              
              // Close Button (باکگراوندی سوور، تێکستی سپیی بۆڵد)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFFDC2626)), // سووری سەرنجڕاکێش و ڕوون
                    foregroundColor: RC.fg(Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _t('داخستن'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: RC.fg(Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  Widget _buildReceiptInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx(label),
          style: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tx(value),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptTotalRow(String label, String value, bool isGreen, {bool isGrand = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            tx(label), 
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isGrand ? FontWeight.bold : FontWeight.normal,
              fontSize: isGrand ? 16 : 14,
              color: isGreen ? RC.bg(Colors.green) : RC.bg(Colors.black87),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          tx(value), 
          textAlign: TextAlign.end,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: isGrand ? 18 : 14,
            color: isGrand ? RC.bg(Color(0xFFB45309)) : (isGreen ? RC.bg(Colors.green) : RC.bg(Colors.black87)),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 🛵 LIVE GPS TRACKING MODAL (شوێنپێهەڵگرتنی ڕاستەوخۆ)
  // ============================================================================
  void _showLiveTrackingModal(OrderItem order) {
    if (order.id.isNotEmpty) {
      context.push('/track/${Uri.encodeComponent(order.id)}', extra: order);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(ctx).padding.bottom + 20,
                  ),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: RC.bg(Colors.grey.shade100),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close, color: RC.fg(Colors.black87)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: RC.bg(Colors.green),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(tx('GPS ڕاستەوخۆ'), style: TextStyle(color: RC.fg(Colors.green), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          Text(tx('شوێن پێهەڵگرتنی شۆفێر'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Map UI Simulation
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFE5E7EB)),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                      border: Border.all(color: RC.bg(Colors.grey.shade300)),
                    ),
                    child: Stack(
                      children: [
                        // Map Grid background simulation
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                            child: CustomPaint(
                              painter: _GPSTrackingPainter(),
                            ),
                          ),
                        ),
                        // Store Pin
                        Positioned(
                          top: 40,
                          right: 40,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: RC.bg(Colors.blue), shape: BoxShape.circle),
                                child: Icon(Icons.storefront, color: RC.fg(Colors.white), size: 18),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: RC.bg(Colors.white), borderRadius: BorderRadius.circular(6)),
                                child: Text(tx(order.storeName), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // Destination Customer Pin
                        Positioned(
                          bottom: 30,
                          left: 40,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: RC.bg(Colors.red), shape: BoxShape.circle),
                                child: Icon(Icons.person_pin_circle, color: RC.fg(Colors.white), size: 20),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: RC.bg(Colors.white), borderRadius: BorderRadius.circular(6)),
                                child: Text(tx('شوێنی تۆ'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // Driver Moving Marker
                        Positioned(
                          top: 90,
                          left: 130,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFFFAC800)),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: RC.bg(Colors.amber).withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.two_wheeler_rounded, color: RC.fg(Colors.black), size: 22),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: RC.bg(Colors.black), borderRadius: BorderRadius.circular(6)),
                                child: Text(tx('شۆفێر لە ڕێگایە'), style: TextStyle(fontSize: 10, color: RC.fg(Colors.white), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Driver Profile Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: RC.bg(Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: RC.bg(Colors.amber.shade100),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.two_wheeler_rounded, color: RC.fg(Color(0xFFB45309))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx(order.driverName.isNotEmpty ? order.driverName : 'شۆفێر دیاری نەکراوە'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      tx(order.driverPhone.isNotEmpty ? order.driverPhone : 'لە چاوەڕوانی دیاریکردنی شۆفێر'),
                                      style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade600)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.green.shade50),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: RC.bg(Colors.green.shade200)),
                          ),
                          child: Text(tx('گەیاندن: ٧-١٢ خولەک'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: RC.fg(Colors.green))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFFDC2626)),
                        foregroundColor: RC.fg(Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        _t('داخستن'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: RC.fg(Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }

  // ============================================================================
  // 🛤️ ORDER STATUS STEPPER (هێڵی شوێنکەوتنی داواکاری)
  // ============================================================================
  Widget _buildOrderStepper(OrderItem order) {
    final steps = [
      _t('وەرگیرا'),
      _t('ئامادەیە'),
      _t('هەڵگیرا'),
      _t('لە ڕێگایە'),
      _t('ڕادەست کرا'),
    ];

    int currentStep = 0;
    switch (order.status) {
      case 'pending':
      case 'accepted':
        currentStep = 0;
        break;
      case 'preparing':
      case 'ready':
        currentStep = 1;
        break;
      case 'picked_up':
      case 'arrived_pickup':
        currentStep = 2;
        break;
      case 'on_the_way':
      case 'arrived_customer':
        currentStep = 3;
        break;
      case 'delivered':
      case 'completed':
        currentStep = 4;
        break;
      case 'cancelled':
      case 'rejected':
        currentStep = -1;
        break;
      default:
        currentStep = 0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              bool isCompleted = index <= currentStep && currentStep != -1;
              bool isLast = index == steps.length - 1;

              return Expanded(
                flex: isLast ? 0 : 1,
                child: Row(
                  children: [
                    // Dot
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isCompleted ? RC.bg(Color(0xFFF59E0B)) : RC.bg(Colors.grey.shade300),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? RC.bg(Color(0xFFF59E0B)) : RC.bg(Colors.grey.shade300),
                          width: 2,
                        ),
                        boxShadow: isCompleted ? [
                          BoxShadow(color: RC.bg(Color(0xFFF59E0B)).withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                        ] : [],
                      ),
                      child: isCompleted 
                        ? Icon(Icons.check, size: 8, color: RC.fg(Colors.white))
                        : null,
                    ),
                    // Line
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: (index < currentStep && currentStep != -1)
                              ? RC.bg(Color(0xFFF59E0B))
                              : RC.bg(Colors.grey.shade200),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              bool isActive = index == currentStep;
              bool isCompleted = index <= currentStep && currentStep != -1;
              
              return Expanded(
                child: Text(
                  tx(steps[index]),
                  textAlign: index == 0 ? TextAlign.right : (index == steps.length - 1 ? TextAlign.left : TextAlign.center),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? RC.bg(Colors.black87) : RC.bg(Colors.grey.shade400),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderItem order) {

    final monthNames = [
      _t('Jan'), _t('Feb'), _t('Mar'), _t('Apr'), _t('May'), _t('Jun'),
      _t('Jul'), _t('Aug'), _t('Sept'), _t('Oct'), _t('Nov'), _t('Dec')
    ];
    final month = monthNames[order.date.month - 1];
    final day = order.date.day;
    final hour = order.date.hour.toString().padLeft(2, '0');
    final min = order.date.minute.toString().padLeft(2, '0');
    final dateStr = '$month, $hour:$min $day';

    Color statusBg = RC.bg(Color(0xFFD1FAE5));
    Color statusText = RC.bg(Color(0xFF065F46));
    String statusStr = _t('تەواوبوو');
    
    switch (order.status) {
      case 'pending':
      case 'accepted':
        statusBg = RC.bg(Color(0xFFFEF3C7));
        statusText = RC.bg(Color(0xFFB45309));
        statusStr = _t('وەرگیرا');
        break;
      case 'preparing':
        statusBg = RC.bg(Color(0xFFDBEAFE));
        statusText = RC.bg(Color(0xFF1D4ED8));
        statusStr = _t('لە ئامادەکردن');
        break;
      case 'ready':
        statusBg = RC.bg(Color(0xFFE0E7FF));
        statusText = RC.bg(Color(0xFF4338CA));
        statusStr = _t('ئامادەیە بۆ شۆفێر');
        break;
      case 'picked_up':
      case 'arrived_pickup':
        statusBg = RC.bg(Color(0xFFF3E8FF));
        statusText = RC.bg(Color(0xFF7E22CE));
        statusStr = _t('وەرگیرا لە فرۆشگا');
        break;
      case 'on_the_way':
      case 'arrived_customer':
        statusBg = RC.bg(Color(0xFFFEF9C3));
        statusText = RC.bg(Color(0xFFA16207));
        statusStr = _t('لە ڕێگایە (بەڕێوەیە)');
        break;
      case 'delivered':
      case 'completed':
        statusBg = RC.bg(Color(0xFFD1FAE5));
        statusText = RC.bg(Color(0xFF065F46));
        statusStr = _t('تەواوبوو');
        break;
      case 'cancelled':
      case 'rejected':
        statusBg = RC.bg(Color(0xFFFEE2E2));
        statusText = RC.bg(Color(0xFFB91C1C));
        statusStr = _t('هەڵوەشایەوە');
        break;
      default:
        statusBg = RC.bg(Colors.grey.shade100);
        statusText = RC.bg(Colors.grey.shade800);
        statusStr = order.status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Colors.grey.shade200)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tx(dateStr),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RC.fg(Colors.grey.shade700),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tx(statusStr),
                    style: TextStyle(color: statusText, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _confirmDeleteOrder(order),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (order.isDirectRequest) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          tx('داواکاری ڕاستەوخۆ'),
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tx('#${order.id}'),
                    style: TextStyle(
                      color: RC.fg(Colors.grey.shade600),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              tx(order.storeName),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            _buildOrderStepper(order),
            if (order.isDirectRequest) ...[
              if (order.directRequestImage != null && order.directRequestImage!.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    order.directRequestImage!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              if (order.directRequestNotes != null && order.directRequestNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RC.bg(Colors.grey.shade200)),
                  ),
                  child: Text(
                    tx(order.directRequestNotes!),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: RC.fg(Colors.black87),
                    ),
                  ),
                ),
              ],
              if (order.address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: RC.fg(Colors.grey.shade600)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tx(order.address),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade700)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (_isLiveTrackStatus(order.status)) ...[
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showLiveTrackingModal(order),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [RC.bg(Color(0xFFFFF7ED)), RC.bg(Color(0xFFFEF3C7))],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RC.bg(Color(0xFFF59E0B)), width: 1.4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFF59E0B)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.moped_rounded, color: RC.fg(Colors.black), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx(order.driverName.isNotEmpty
                                    ? 'ماتۆرسوار: ${order.driverName}'
                                    : 'شوێنی ماتۆرسوار لەسەر نەخشە'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: RC.fg(Colors.black),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tx(order.status == 'preparing'
                                    ? 'فرۆشگا ئامادەیدەکات — کرتە بکە بۆ بینینی شوێن'
                                    : 'کرتە بکە بۆ بینینی شوێنی ڕاستەوخۆی گەیاندن'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: RC.fg(Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded, color: RC.fg(Color(0xFFB45309)), size: 26),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (!order.isDirectRequest) ...[
              const SizedBox(height: 16),
              Divider(color: RC.bg(Colors.grey.shade100), height: 1),
              const SizedBox(height: 12),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  tx(item.product.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: RC.fg(Colors.black87)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tx('× ${item.quantity}'),
                                style: TextStyle(fontSize: 14, color: RC.fg(Colors.grey.shade400), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tx('${_formatNum(item.product.price * item.quantity)} ${_t('د.ع')}'),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: RC.fg(Colors.black87)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 4),
            ],
            Divider(color: RC.bg(Colors.grey.shade100), height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.isDirectRequest ? _t('جۆری داواکاری') : _t('کۆی گشتی حساب'),
                        style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade500)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          order.isDirectRequest
                              ? tx('داواکاری ڕاستەوخۆ')
                              : tx('${_formatNum(order.totalAmount)} ${_t('د.ع')}'),
                          style: TextStyle(
                            fontSize: order.isDirectRequest ? 15 : 18,
                            fontWeight: FontWeight.bold,
                            color: RC.fg(const Color(0xFFB45309)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!order.isDirectRequest) ...[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: GestureDetector(
                          onTap: () => _showReceiptModal(order),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: RC.bg(Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 16, color: RC.fg(Colors.grey.shade700)),
                                const SizedBox(width: 6),
                                Text(tx('پسوولە'), style: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade800), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GestureDetector(
                        onTap: () {
                          if (order.status != 'cancelled' && order.status != 'rejected') {
                            _showLiveTrackingModal(order);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: (order.status != 'cancelled' && order.status != 'rejected')
                                ? RC.bg(Color(0xFFF59E0B))
                                : RC.bg(Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.moped_rounded,
                                size: 16,
                                color: (order.status != 'cancelled' && order.status != 'rejected')
                                    ? RC.fg(Colors.black)
                                    : RC.bg(Colors.grey.shade500),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tx(_isLiveTrackStatus(order.status)
                                    ? 'شوێنی ماتۆرسوار'
                                    : 'شوێن پێهەڵگرتن'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: (order.status != 'cancelled' && order.status != 'rejected')
                                      ? RC.bg(Colors.black)
                                      : RC.bg(Colors.grey.shade500),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOrder(OrderItem order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RC.bg(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 8),
            Text(
              tx('سڕینەوەی داواکاری'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          tx('ئایا دڵنیایت لە سڕینەوەی ئەم داواکارییە؟'),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tx('پاشگەزبوونەوە'),
              style: TextStyle(color: RC.fg(Colors.grey.shade700), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              tx('سڕینەوە'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final success = await CustomerApiService.instance.deleteOrder(order.id);
      if (!mounted) return;
      if (success) {
        setState(() {
          _orders.removeWhere((o) => o.id == order.id);
        });
        context.read<OrdersNotifier>().notify();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx('داواکاری بە سەرکەوتوویی سڕایەوە')),
            backgroundColor: RC.bg(const Color(0xFF059669)),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx('سڕینەوە سەرکەوتوو نەبوو')),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('هەڵەیەک ڕوویدا لە سڕینەوەی داواکاری')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  // ============================================================================
  // 👤 TAB 5: PROFILE & REGISTER VIEW (REDESIGNED)
  // ============================================================================
  void _showAccountDetailsModal(UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: (MediaQuery.sizeOf(ctx).width - RegaResponsive.dialogMaxWidth(ctx, cap: 480)) / 2,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: RegaResponsive.dialogMaxWidth(ctx, cap: 480)),
            child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RC.bg(Colors.amber.shade50), shape: BoxShape.circle),
                  child: Icon(Icons.person_outline_rounded, size: 40, color: RC.fg(Color(0xFFB45309))),
                ),
                const SizedBox(height: 16),
                Text(tx(profile.name), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(_t('بینینی هەژمار'), style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade400), fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 32),

                // Name Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(_t('ناوی تەواو') == 'ناوی تەواو' ? 'ناوی تەواو' : (_currentLanguage == 'English' ? 'Full Name' : 'الاسم الكامل'), style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade400), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(tx(profile.name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Phone Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(_t('ژمارەی تەلەفۆن') == 'ژمارەی تەلەفۆن' ? 'ژمارەی تەلەفۆن' : (_currentLanguage == 'English' ? 'Phone Number' : 'رقم الهاتف'), style: TextStyle(fontSize: 11, color: RC.fg(Colors.grey.shade400), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(tx(profile.phone), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFFB45309)))),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RC.bg(Color(0xFFDC2626)),
                      foregroundColor: RC.fg(Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      _t('داخستن') == 'داخستن' ? 'داخستن' : (_currentLanguage == 'English' ? 'Close' : 'إغلاق'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: RC.fg(Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  void _showSupportModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: RC.bg(Colors.grey.shade100), shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 18, color: RC.fg(Colors.grey)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tx('پشتیوانی و پەیوەندی REGA'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 30), // Balance the close icon
                ],
              ),
              const SizedBox(height: 20),

              // Main Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.grey.shade50),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Text(
                      _t('پشتیگیری ڕاستەوخۆی REGA لە کەلار'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RC.fg(Color(0xFFB45309))),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('تیمی پشتگیری ٢٤ کاتژمێر لە خزمەتاندایە'),
                      style: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade600), height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // WhatsApp Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFF075E54)),
                        foregroundColor: RC.fg(Colors.white),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      label: Text(_t('پەیوەندی لە ڕێگەی واتسئاپ'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    
                    // Phone Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Colors.white),
                        foregroundColor: RC.fg(Colors.black87),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: RC.bg(Color(0xFFF3F4F6))),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {},
                      icon: Icon(Icons.phone_outlined, size: 20, color: RC.fg(Colors.grey)),
                      label: Text(_t('تەلەفۆن بۆ ڕاژەی کریاران'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Bottom Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFFDC2626)),
                    foregroundColor: RC.fg(Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _t('داخستن'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: RC.fg(Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: RC.bg(Colors.grey.shade100), shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 18, color: RC.fg(Colors.grey)),
                    ),
                  ),
                  Text(tx('مەرجەکانی بەکارهێنان'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 30),
                ],
              ),
              const SizedBox(height: 20),

              // Content Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.grey.shade50),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  border: Border.all(color: RC.bg(Colors.grey.shade100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tx('مەرجە گشتییەکان:'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RC.fg(Colors.black)),
                    ),
                    const SizedBox(height: 12),
                    _buildTermsBullet('ئەپی REGA تایبەتە بە گەیاندنی داواکاری لە سنووری شاری کەلار و دەوروبەری.'),
                    _buildTermsBullet('پارەدان تەنها بە نەختینە (کاش / COD) لە کاتی گەیاندن ئەنجام دەدرێت.'),
                    _buildTermsBullet('کاتی گەیاندن خەمڵێنراوە و بەپێی قەرەباڵغی و کەشوهەوا دەگۆڕێت.'),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFFDC2626)),
                    foregroundColor: RC.fg(Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _t('داخستن'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: RC.fg(Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: RC.bg(Colors.grey.shade100), shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 18, color: RC.fg(Colors.grey)),
                    ),
                  ),
                  Text(tx('سیاسەتی پاراستنی نهێنی'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 30),
                ],
              ),
              const SizedBox(height: 20),

              // Content Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.grey.shade50),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  border: Border.all(color: RC.bg(Colors.grey.shade100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tx('پاراستنی نهێنی زانیارییەکان:'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RC.fg(Colors.black)),
                    ),
                    const SizedBox(height: 12),
                    _buildTermsBullet('ناونیشان و ژمارەی مۆبایلت تەنها بۆ گەیاندنی داواکارییەکانت لە شاری کەلار بەکاردەهێنرێت.'),
                    _buildTermsBullet('هیچ زانیارییەکی کەسی بۆ لایەنی سێیەم نانێردرێت.'),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RC.bg(Color(0xFFDC2626)),
                    foregroundColor: RC.fg(Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _t('داخستن'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: RC.fg(Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              tx(text),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade700), height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: RC.fg(Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredProfileView() {
    final ltr = _profileLtr;
    return Column(
      children: [
        // 1. TOP ILLUSTRATION (Jumping Person)
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          child: Center(
            child: Image.network(
              'https://raw.githubusercontent.com/mirnatv/assets/main/celebration.png',
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Column(
                children: [
                  Icon(Icons.celebration_rounded, size: 80, color: RC.fg(Color(0xFFF59E0B))),
                  const SizedBox(height: 8),
                  Text(tx('بەخێربێیت، ${_userProfile?.name}'), style: TextStyle(fontWeight: FontWeight.bold, color: RC.fg(Colors.grey))),
                ],
              ),
            ),
          ),
        ),

        // 2. USER INFO CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RC.bg(Colors.grey.shade100)),
            boxShadow: [
              BoxShadow(color: RC.bg(Colors.black).withOpacity(0.04), blurRadius: 12, spreadRadius: 1),
            ],
          ),
          child: Row(
            children: [
              // Standard: avatar+info | View Account (mirrored in RTL)
              if (!ltr) ...[
                _buildViewAccountChip(),
                const SizedBox(width: 10),
              ],
              Expanded(child: _buildProfileUserInfoRow(ltr)),
              if (ltr) ...[
                const SizedBox(width: 10),
                _buildViewAccountChip(),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. LANGUAGES MENU ITEM
        Container(
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            border: Border.all(color: RC.bg(Colors.grey.shade100)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isLanguageExpanded = !_isLanguageExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: _buildSettingsLanguageHeader(),
                ),
              ),
              
              if (_isLanguageExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildLanguageOption('کوردی', isSelected: _currentLanguage == 'کوردی'),
                      const SizedBox(height: 10),
                      _buildLanguageOption('العربية', isSelected: _currentLanguage == 'العربية'),
                      const SizedBox(height: 10),
                      _buildLanguageOption('English', isSelected: _currentLanguage == 'English'),
                      const SizedBox(height: 14),
                      _buildSettingsDarkModeSwitch(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. ADDRESS SECTION (Interactive Location Card)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RC.bg(Colors.grey.shade100)),
            boxShadow: [
              BoxShadow(
                color: RC.bg(Colors.black).withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded, color: RC.fg(Color(0xFFB45309)), size: 20),
                      const SizedBox(width: 6),
                      Text(_t('ناونیشانی تۆ'), style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  InkWell(
                    onTap: _showLocationPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.amber.shade50),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: RC.bg(Colors.amber.shade200), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.near_me_rounded, size: 14, color: RC.fg(Color(0xFFB45309))),
                          const SizedBox(width: 4),
                          Text(
                            _t('دۆزینەوەی لۆکەیشن'),
                            style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 11, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFFB45309))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _showLocationPicker,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFFFFFBEB)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: RC.bg(Color(0xFFFDE68A))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFFFAC800)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.location_on_rounded, size: 22, color: RC.fg(Color(0xFF422006))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: ltr ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(
                              tx(_deliveryDisplayLabel),
                              textAlign: ltr ? TextAlign.left : TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'NotoKufiArabic',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: RC.fg(Color(0xFF1E293B)),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        ltr ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: RC.fg(Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5. SUPPORT & POLICIES MENU
        Container(
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            border: Border.all(color: RC.bg(Colors.grey.shade100)),
          ),
          child: Column(
            children: [
              _buildMenuItem(_t('پشتیوانی و یارمەتی'), Icons.help_outline_rounded),
              Divider(height: 1, color: RC.bg(Colors.grey.shade50)),
              _buildMenuItem(_t('مەرج و ڕێساکانی بەکارهێنان'), Icons.description_outlined),
              Divider(height: 1, color: RC.bg(Colors.grey.shade50)),
              _buildMenuItem(_t('سیاسەتی پاراستنی نهێنی'), Icons.shield_outlined),
              Divider(height: 1, color: RC.bg(Colors.grey.shade50)),
              _buildMenuItem(_t('چوونە دەرەوە'), Icons.logout_rounded, isLogout: true),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 6. FOOTER (LOGO & VERSION)
        Column(
          children: [
            // 🖼️ لۆگۆی پڕۆفایل کە لە فۆڵدەری assets2 بار دەکرێت
            _buildProfileFooterLogo(),
            const SizedBox(height: 12),
            Text(
              tx(' هەموو مافەکانی پارێزراوە بۆ (REGA)'),
              style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 10, color: RC.fg(Colors.grey.shade400), fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildViewAccountChip() {
    return GestureDetector(
      onTap: () {
        if (_userProfile != null) {
          _showAccountDetailsModal(_userProfile!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: RC.bg(Colors.amber.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RC.bg(Colors.amber.shade100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 16, color: RC.fg(Color(0xFFB45309))),
            const SizedBox(width: 6),
            Text(
              _t('بینینی هەژمار'),
              style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 12, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFFB45309))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileUserInfoRow(bool ltr) {
    final avatar = Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: RC.bg(Colors.amber.shade50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.bg(Colors.amber.shade200)),
          ),
          child: Icon(Icons.person_rounded, size: 28, color: RC.fg(Color(0xFFB45309))),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: RC.bg(Color(0xFFF59E0B)),
              shape: BoxShape.circle,
              border: Border.all(color: RC.bg(Colors.white), width: 2),
            ),
            child: Icon(Icons.check, size: 10, color: RC.fg(Colors.white)),
          ),
        ),
      ],
    );

    final info = Flexible(
      child: Column(
        crossAxisAlignment: ltr ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            tx(_userProfile?.name ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: ltr ? TextAlign.left : TextAlign.right,
            style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 16, fontWeight: FontWeight.w900, color: RC.fg(Colors.black)),
          ),
          const SizedBox(height: 2),
          Text(
            tx(_userProfile?.phone ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: ltr ? TextAlign.left : TextAlign.right,
            style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 11, color: RC.fg(Color(0xFFB45309)), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    // Standard: avatar → name/phone (LTR); mirrored for RTL
    return Row(
      mainAxisAlignment: ltr ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: ltr
          ? [avatar, const SizedBox(width: 12), info]
          : [info, const SizedBox(width: 12), avatar],
    );
  }

  Widget _buildSettingsLanguageHeader() {
    final ltr = _profileLtr;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: RC.bg(Colors.amber.shade50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.translate_rounded, color: RC.fg(Color(0xFFB45309)), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: ltr ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(_t('زمانەکان'), style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 14, fontWeight: FontWeight.bold)),
              Text(tx(_currentLanguage), style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 11, color: RC.fg(Colors.grey))),
            ],
          ),
        ),
        Icon(_settingsChevronIcon, color: RC.fg(Colors.grey), size: 20),
      ],
    );
  }

  Widget _buildLanguageOption(String lang, {required bool isSelected}) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _currentLanguage = lang;
        });

        // 💾 پاشەکەوتکردنی زمان لەناو SharedPreferences بۆ ئەوەی لە کاتی دەرچوون و گەڕانەوە نەگۆڕێت
        await _saveLanguage(lang);

        // Notify parent and update global text direction
        if (lang == 'English') {
          widget.onLanguageChange('en');
        } else if (lang == 'العربية') {
          widget.onLanguageChange('ar');
        } else {
          widget.onLanguageChange('ku');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? RC.bg(Colors.white) : RC.bg(Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? RC.bg(Color(0xFFF59E0B)) : RC.bg(Colors.grey.shade100),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: RC.bg(Colors.amber).withOpacity(0.1), blurRadius: 10)] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tx(lang),
              textAlign: _profileLtr ? TextAlign.left : TextAlign.right,
              style: TextStyle(fontFamily: 'NotoKufiArabic', 
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? RC.bg(Color(0xFFB45309)) : RC.bg(Colors.black87),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: RC.bg(Color(0xFFF59E0B)), shape: BoxShape.circle),
                child: Icon(Icons.check, size: 12, color: RC.fg(Colors.white)),
              )
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  // Simple Translation Helper with Static Map for better performance
  static const Map<String, Map<String, String>> _translations = {
    'سەرەکی': {'کوردی': 'سەرەکی', 'العربية': 'الرئيسية', 'English': 'Home'},
    'کۆگاکان': {'کوردی': 'کۆگاکان', 'العربية': 'المتاجر', 'English': 'Stores'},
    'داواکاری': {'کوردی': 'داواکاری', 'العربية': 'الطلبات', 'English': 'Orders'},
    'داواکاری ڕاستەوخۆ': {
      'کوردی': 'داواکاری ڕاستەوخۆ',
      'العربية': 'طلب مباشر',
      'English': 'Direct Request',
    },
    'ئایا دەتەوێت ڕێگە بدەیت بە ئەپی REGA کە ئاگاداریت بۆ بنێرێت؟': {
      'کوردی': 'ئایا دەتەوێت ڕێگە بدەیت بە ئەپی REGA کە ئاگاداریت بۆ بنێرێت؟',
      'العربية': 'هل تريد السماح لتطبيق REGA بإرسال إشعارات إليك؟',
      'English': 'Allow REGA to send you notifications?',
    },
    'ڕێگە بدە': {'کوردی': 'ڕێگە بدە', 'العربية': 'سماح', 'English': 'Allow'},
    'ڕێگە مەدە': {'کوردی': 'ڕێگە مەدە', 'العربية': 'عدم السماح', 'English': 'Don\'t Allow'},
    'ناوی بابەت': {'کوردی': 'ناوی بابەت', 'العربية': 'اسم الموضوع', 'English': 'Subject name'},
    'تێبینی بابەت': {'کوردی': 'تێبینی بابەت', 'العربية': 'ملاحظات الموضوع', 'English': 'Subject notes'},
    'ناونیشانی داواکاری': {'کوردی': 'ناونیشانی داواکاری', 'العربية': 'عنوان الطلب', 'English': 'Request address'},
    'ژمارەی مۆبایل': {'کوردی': 'ژمارەی مۆبایل', 'العربية': 'رقم الموبايل', 'English': 'Mobile number'},
    'وێنەی بابەت': {'کوردی': 'وێنەی بابەت', 'العربية': 'صورة الموضوع', 'English': 'Subject image'},
    'کامێرا': {'کوردی': 'کامێرا', 'العربية': 'كاميرا', 'English': 'Camera'},
    'گەلەری': {'کوردی': 'گەلەری', 'العربية': 'المعرض', 'English': 'Gallery'},
    'ناردنی داواکاری': {'کوردی': 'ناردنی داواکاری', 'العربية': 'إرسال الطلب', 'English': 'Send request'},
    'کارت': {'کوردی': 'کارت', 'العربية': 'السلة', 'English': 'Cart'},
    'سەبەتە': {'کوردی': 'سەبەتە', 'العربية': 'السلة', 'English': 'Cart'},
    'داشکاندن': {'کوردی': 'داشکاندن', 'العربية': 'التخفيضات', 'English': 'Discounts'},
    'پڕۆفایل': {'کوردی': 'پڕۆفایل', 'العربية': 'الحساب', 'English': 'Profile'},
    'زمانەکان': {'کوردی': 'زمانەکان', 'العربية': 'اللغات', 'English': 'Languages'},
    'گەڕان': {'کوردی': 'گەڕان', 'العربية': 'بحث', 'English': 'Search'},
    'چوونە دەرەوە': {'کوردی': 'چوونە دەرەوە', 'العربية': 'تسجيل الخروج', 'English': 'Logout'},
    'ناونیشانی تۆ': {'کوردی': 'ناونیشانی تۆ', 'العربية': 'عنوانك', 'English': 'Your Address'},
    'لێرە بنووسە...': {'کوردی': 'لێرە بنووسە...', 'العربية': 'اكتب هنا...', 'English': 'Type here...'},
    'خۆتۆمارکردن': {'کوردی': 'خۆتۆمارکردن', 'العربية': 'إنشاء حساب', 'English': 'Register'},
    'چوونە ژوورەوە': {'کوردی': 'چوونە ژوورەوە', 'العربية': 'تسجيل الدخول', 'English': 'Login'},
    'زانیارییە کەسییەکان': {'کوردی': 'زانیارییە کەسییەکان', 'العربية': 'المعلومات الشخصية', 'English': 'Personal Info'},
    'ناوی تەواو': {'کوردی': 'ناوی تەواو', 'العربية': 'الاسم الكامل', 'English': 'Full Name'},
    'ژمارەی تەلەفۆن': {'کوردی': 'ژمارەی تەلەفۆن', 'العربية': 'رقم الهاتف', 'English': 'Phone Number'},
    'وشەی نهێنی': {'کوردی': 'وشەی نهێنی', 'العربية': 'كلمة المرور', 'English': 'Password'},
    'بەردەوامبە': {'کوردی': 'بەردەوامبە', 'العربية': 'استمرار', 'English': 'Continue'},
    '✅ بە سەرکەوتوویی چووە ژوورەوە': {'کوردی': '✅ بە سەرکەوتوویی چووە ژوورەوە', 'العربية': '✅ تم تسجيل الدخول بنجاح', 'English': '✅ Logged in successfully'},
    '✅ هەژمارەکەت بە سەرکەوتوویی تۆمار کرا': {'کوردی': '✅ هەژمارەکەت بە سەرکەوتوویی تۆمار کرا', 'العربية': '✅ تم تسجيل الحساب بنجاح', 'English': '✅ Account registered successfully'},
    'چوونە ژوورەوە سەرکەوتوو نەبوو': {
      'کوردی': 'چوونە ژوورەوە سەرکەوتوو نەبوو',
      'العربية': 'فشل تسجيل الدخول',
      'English': 'Login was unsuccessful',
    },
    'خۆتۆمارکردن سەرکەوتوو نەبوو': {
      'کوردی': 'خۆتۆمارکردن سەرکەوتوو نەبوو',
      'العربية': 'فشل إنشاء الحساب',
      'English': 'Registration was unsuccessful',
    },
    'وشەی نهێنی پێویستە (لانیکەم ٦ پیت)': {
      'کوردی': 'وشەی نهێنی پێویستە (لانیکەم ٦ پیت)',
      'العربية': 'كلمة المرور مطلوبة (٦ أحرف على الأقل)',
      'English': 'Password required (at least 6 characters)',
    },
    'ژمارەی تەلەفۆن پێویستە': {
      'کوردی': 'ژمارەی تەلەفۆن پێویستە',
      'العربية': 'رقم الهاتف مطلوب',
      'English': 'Phone number is required',
    },
    'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 0770 000 0000': {
      'کوردی': 'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 0770 000 0000',
      'العربية': 'رقم الجوال غير صالح — الصيغة العراقية: 0770 000 0000',
      'English': 'Invalid mobile — Iraqi format: 0770 000 0000',
    },
    'ناوی تەواو پێویستە': {
      'کوردی': 'ناوی تەواو پێویستە',
      'العربية': 'الاسم الكامل مطلوب',
      'English': 'Full name is required',
    },
    'ئەم ژمارەیە پێشتر تۆمارکراوە — تکایە بچۆ ژوورەوە': {
      'کوردی': 'ئەم ژمارەیە پێشتر تۆمارکراوە — تکایە بچۆ ژوورەوە',
      'العربية': 'هذا الرقم مسجل مسبقاً — يرجى تسجيل الدخول',
      'English': 'This number is already registered — please log in',
    },
    'هیچ ناونیشانێک تۆمار نەکراوە': {
      'کوردی': 'هیچ ناونیشانێک تۆمار نەکراوە', 
      'العربية': 'لم يتم تسجيل أي عنوان', 
      'English': 'No address registered'
    },
    'پشتیوانی و یارمەتی': {'کوردی': 'پشتیوانی و یارمەتی', 'العربية': 'الدعم والمساعدة', 'English': 'Support & Help'},
    'مەرج و ڕێساکانی بەکارهێنان': {'کوردی': 'مەرج و ڕێساکانی بەکارهێنان', 'العربية': 'الشروط والأحكام', 'English': 'Terms & Conditions'},
    'سیاسەتی پاراستنی نهێنی': {'کوردی': 'سیاسەتی پاراستنی نهێنی', 'العربية': 'سياسة الخصوصية', 'English': 'Privacy Policy'},
    'دۆزینەوەی لۆکەیشن': {'کوردی': 'دۆزینەوەی لۆکەیشن', 'العربية': 'تحديد الموقع', 'English': 'Find Location'},
    'دیاری کردنی شوێن': {
      'کوردی': 'دیاری کردنی شوێن',
      'العربية': 'تحديد الموقع',
      'English': 'Set location',
    },
    'دیاریکردنی شوێن': {
      'کوردی': 'دیاریکردنی شوێن',
      'العربية': 'تحديد الموقع',
      'English': 'Select location',
    },
    'شوێنی گەیاندن لە عێراق': {
      'کوردی': 'دیاری کردنی شوێن',
      'العربية': 'تحديد الموقع',
      'English': 'Set location',
    },
    'شوێنی ئێستات یان پارک/شوێنێک هەڵبژێرە بۆ دواتر': {
      'کوردی': 'شوێنی ئێستات یان پارک/شوێنێک هەڵبژێرە بۆ دواتر — تەنانەت ئەگەر ئێستا لەوێ نەبیت',
      'العربية': 'استخدم موقعك الحالي أو اختر مكاناً (مثل حديقة) للوصول لاحقاً',
      'English': 'Use current GPS or pick a place (e.g. park) for later delivery',
    },
    'ناوی شوێن (پارک، ناوەند، ...)': {
      'کوردی': 'ناوی شوێن (پارک، ناوەند، ...)',
      'العربية': 'اسم المكان (حديقة، مركز، ...)',
      'English': 'Place name (park, plaza, ...)',
    },
    'شوێنی دیاریکراو': {'کوردی': 'شوێنی دیاریکراو', 'العربية': 'الموقع المحدد', 'English': 'Selected place'},
    'شوێنی گەیاندن پاشەکەوت کرا': {
      'کوردی': 'شوێنی گەیاندن پاشەکەوت کرا',
      'العربية': 'تم حفظ موقع التوصيل',
      'English': 'Delivery place saved',
    },
    'پشتڕاستکردنەوەی شوێنەکەت': {
      'کوردی': 'پشتڕاستکردنەوەی شوێنەکەت',
      'العربية': 'تأكيد موقعك',
      'English': 'Confirm your place',
    },
    'پشتڕاستکردنەوەی شوێنی گەیاندن': {
      'کوردی': 'پشتڕاستکردنەوەی شوێنەکەت',
      'العربية': 'تأكيد موقعك',
      'English': 'Confirm your place',
    },
    'کردنەوەی نەخشە بۆ دیاریکردنی شوێنی گەیاندن': {
      'کوردی': 'کردنەوەی نەخشە بۆ دیاریکردنی شوێنی گەیاندن',
      'العربية': 'افتح الخريطة لتحديد موقع التوصيل',
      'English': 'Open map to set delivery place',
    },
    'GPS چالاکە': {'کوردی': 'GPS چالاکە', 'العربية': 'GPS نشط', 'English': 'GPS active'},
    'GPS نییە': {'کوردی': 'GPS نییە', 'العربية': 'لا يوجد GPS', 'English': 'No GPS'},
    'گەیاندن': {'کوردی': 'گەیاندن', 'العربية': 'توصيل', 'English': 'Delivery'},
    'گەیاندن بۆ': {'کوردی': 'گەیاندن بۆ', 'العربية': 'التوصيل إلى', 'English': 'Deliver to'},
    'بینینی هەژمار': {'کوردی': 'بینینی هەژمار', 'العربية': 'عرض الحساب', 'English': 'View Account'},
    'خواردنگە': {'کوردی': 'خواردنگە', 'العربية': 'مطاعم', 'English': 'Restaurants'},
    'سوپەرمارکێت': {'کوردی': 'سوپەرمارکێت', 'العربية': 'سوبر ماركت', 'English': 'Supermarket'},
    'سەوزە و میوە': {'کوردی': 'سەوزە و میوە', 'العربية': 'خضروات وفواكه', 'English': 'Fruits & Veggies'},
    'فاست فوود': {'کوردی': 'فاست فوود', 'العربية': 'وجبات سريعة', 'English': 'Fast Food'},
    'شیرەمەنی و شیرینی': {'کوردی': 'شیرەمەنی و شیرینی', 'العربية': 'حلويات', 'English': 'Sweets'},
    'کافێ': {'کوردی': 'کافێ', 'العربية': 'كافيه', 'English': 'Cafe'},
    'گۆشت و قەسابخانە': {'کوردی': 'گۆشت و قەسابخانە', 'العربية': 'لحوم', 'English': 'Meat'},
    'نانەواخانە': {'کوردی': 'نانەواخانە', 'العربية': 'مخبز', 'English': 'Bakery'},
    'خواردنگە و ڕێستۆرانتەکان': {'کوردی': 'خواردنگە و ڕێستۆرانتەکان', 'العربية': 'المطاعم والمأكولات', 'English': 'Restaurants & Eateries'},
    'مارکێت و سوپەرمارکێتەکان': {'کوردی': 'مارکێت و سوپەرمارکێتەکان', 'العربية': 'الأسواق والسوبر ماركت', 'English': 'Markets & Supermarkets'},
    'میوە و سەوزەی فرێش': {'کوردی': 'میوە و سەوزەی فرێش', 'العربية': 'الفواكه والخضروات الطازجة', 'English': 'Fresh Fruits & Vegetables'},
    'شاوڕمە و فاست فوود': {'کوردی': 'شاوڕمە و فاست فوود', 'العربية': 'الشاورما والوجبات السريعة', 'English': 'Shawarma & Fast Food'},
    'شیرینی، کێک و باقلاوە': {'کوردی': 'شیرینی، کێک و باقلاوە', 'العربية': 'الحلويات والكيك والحلويات الشرقية', 'English': 'Sweets, Cakes & Baklava'},
    'کافن و قاوەخانەکان': {'کوردی': 'کافن و قاوەخانەکان', 'العربية': 'المقاهي والكافيهات', 'English': 'Cafes & Coffee Shops'},
    'گۆشت و مریشکی تازه': {'کوردی': 'گۆشت و مریشکی تازه', 'العربية': 'اللحوم الطازجة والقصابة', 'English': 'Fresh Meat & Butcher'},
    'نانەواخانه و سەموون': {'کوردی': 'نانەواخانه و سەموون', 'العربية': 'المخبز والمعجنات', 'English': 'Bakery & Pastries'},
    'نان و کولێرەی گەرم': {'کوردی': 'نان و کولێرەی گەرم', 'العربية': 'الخبز والمعجنات الساخنة', 'English': 'Hot Bread & Pastries'},
    'گۆشتی فرێش و قەسابخانە': {'کوردی': 'گۆشتی فرێش و قەسابخانە', 'العربية': 'اللحوم الطازجة والقصابة', 'English': 'Fresh Meat & Butcher'},
    'گەڕان بۆ کۆگا و خواردن...': {'کوردی': 'گەڕان بۆ کۆگا و خواردن...', 'العربية': 'البحث عن المتجر والطعام...', 'English': 'Search for stores and food...'},
    'داشکاندنەکان': {'کوردی': 'داشکاندنەکان', 'العربية': 'التخفيضات', 'English': 'Discounts'},
    'سەبەتەکەت خاڵییە': {'کوردی': 'سەبەتەکەت خاڵییە', 'العربية': 'سلتك فارغة', 'English': 'Your cart is empty'},
    'تەواوکردن و ناردنی داواکاری': {'کوردی': 'تەواوکردن و ناردنی داواکاری', 'العربية': 'إكمال وإرسال الطلب', 'English': 'Complete & Send Order'},
    'تەواوکردن و ناردنی داواکاری 🚚': {'کوردی': 'تەواوکردن و ناردنی داواکاری', 'العربية': 'إكمال وإرسال الطلب', 'English': 'Complete & Send Order'},
    'کۆی گشتی': {'کوردی': 'کۆی گشتی', 'العربية': 'المجموع الكلي', 'English': 'Grand Total'},
    'تێچووی گەیاندن': {'کوردی': 'تێچووی گەیاندن', 'العربية': 'رسوم التوصيل', 'English': 'Delivery Fee'},
    'بچۆ ژوورەوە': {'کوردی': 'بچۆ ژوورەوە', 'العربية': 'تسجيل الدخول', 'English': 'Login'},
    'داخستن': {'کوردی': 'داخستن', 'العربية': 'إغلاق', 'English': 'Close'},
    'کراوە': {'کوردی': 'کراوە', 'العربية': 'مفتوح', 'English': 'Open'},
    'داخراوە': {'کوردی': 'داخراوە', 'العربية': 'مغلق', 'English': 'Closed'},
    'خولەک': {'کوردی': 'خولەک', 'العربية': 'دقيقة', 'English': 'min'},
    'د.ع': {'کوردی': 'د.ع', 'العربية': 'د.ع', 'English': 'IQD'},
    'زێدە کرا بۆ سەبەتە': {'کوردی': 'زێدە کرا بۆ سەبەتە', 'العربية': 'تمت الإضافة إلى السلة', 'English': 'Added to cart'},
    'زیادکرا بۆ سەبەتە': {'کوردی': 'زیادکرا بۆ سەبەتە', 'العربية': 'أُضيف إلى السلة', 'English': 'added to cart'},
    'تەواوکردنی داواکاری': {'کوردی': 'تەواوکردنی داواکاری', 'العربية': 'إتمام الطلب', 'English': 'Complete Order'},
    'تکایە سەرەتا خۆت تۆمار بکە': {'کوردی': 'تکایە سەرەتا خۆت تۆمار بکە', 'العربية': 'يرجى التسجيل أولاً', 'English': 'Please register first'},
    'بۆ ئەوەی بتوانیت داواکارییەکەت ئەنجام بدەیت و کاڵاکانت پێ بگات، تکایە سەرەتا خۆت تۆمار بکە یان بچۆ ژوورەوە.': {
      'کوردی': 'بۆ ئەوەی بتوانیت داواکارییەکەت ئەنجام بدەیت و کاڵاکانت پێ بگات، تکایە سەرەتا خۆت تۆمار بکە یان بچۆ ژوورەوە.',
      'العربية': 'لكي تتمكن من إتمام طلبك واستلام منتجاتك، يرجى التسجيل أو تسجيل الدخول أولاً.',
      'English': 'To complete your order and receive your items, please register or log in first.',
    },
    'ڕاستەوخۆ بڕۆ بۆ خۆتۆمارکردن': {'کوردی': 'ڕاستەوخۆ بڕۆ بۆ خۆتۆمارکردن', 'العربية': 'انتقل إلى التسجيل مباشرة', 'English': 'Go to Register'},
    'دواخستن': {'کوردی': 'دواخستن', 'العربية': 'لاحقاً', 'English': 'Dismiss'},
    'داواکارییەکەت بە سەرکەوتوویی نێردرا!': {'کوردی': 'داواکارییەکەت بە سەرکەوتوویی نێردرا!', 'العربية': 'تم إرسال طلبك بنجاح!', 'English': 'Your order was sent successfully!'},
    'تکایە ئەم کۆدە لای خۆت بپارێزە بۆ وەرگرتنی داواکاری لە شۆفێر:': {
      'کوردی': 'تکایە ئەم کۆدە لای خۆت بپارێزە بۆ وەرگرتنی داواکاری لە شۆفێر:',
      'العربية': 'يرجى الاحتفاظ بهذا الرمز لاستلام الطلب من السائق:',
      'English': 'Keep this code to receive your order from the driver:',
    },
    'کۆدی وەرگرتنی داواکاری': {'کوردی': 'کۆدی وەرگرتنی داواکاری', 'العربية': 'رمز استلام الطلب', 'English': 'Order pickup code'},
    'ژمارەی داواکاری': {'کوردی': 'ژمارەی داواکاری', 'العربية': 'رقم الطلب', 'English': 'Order number'},
    'چوون بۆ داواکارییەکان': {'کوردی': 'چوون بۆ داواکارییەکان', 'العربية': 'الذهاب إلى الطلبات', 'English': 'Go to My Orders'},
    'پشتڕاستکردنەوە و ناردنی داواکاری': {'کوردی': 'پشتڕاستکردنەوە و ناردنی داواکاری', 'العربية': 'تأكيد وإرسال الطلب', 'English': 'Confirm & Send Order'},
    'سەبەتەکەت بەتاڵە! دەست بکە بە زیادکردنی بەرهەمەکانت بۆ درێژەدان.': {
      'کوردی': 'سەبەتەکەت بەتاڵە! دەست بکە بە زیادکردنی بەرهەمەکانت بۆ درێژەدان.',
      'العربية': 'سلتك فارغة! ابدأ بإضافة منتجاتك للمتابعة.',
      'English': 'Your cart is empty! Start adding products to continue.',
    },
    'ئەنجامی گەڕان بۆ': {'کوردی': 'ئەنجامی گەڕان بۆ', 'العربية': 'نتائج البحث عن', 'English': 'Search results for'},
    'خواردن': {'کوردی': 'خواردن', 'العربية': 'طعام', 'English': 'Food'},
    'بابەتەکان': {'کوردی': 'بابەتەکان', 'العربية': 'الأصناف', 'English': 'Categories'},
    'هەمووی': {'کوردی': 'هەمووی', 'العربية': 'الكل', 'English': 'All'},
    'پشتیگیری ڕاستەوخۆی REGA لە کەلار': {
      'کوردی': 'پشتیگیری ڕاستەوخۆی REGA لە کەلار',
      'العربية': 'الدعم المباشر لـ REGA في كلار',
      'English': 'REGA Direct Support in Kalar'
    },
    'تیمی پشتگیری ٢٤ کاتژمێر لە خزمەتاندایە': {
      'کوردی': 'تیمی پشتگیری ٢٤ کاتژمێر لە خزمەتاندایە',
      'العربية': 'فريق الدعم في خدمتكم على مدار ٢٤ ساعة',
      'English': 'The support team is at your service 24 hours'
    },
    'داواکارییەکە نەدۆزرایەوە': {
      'کوردی': 'داواکارییەکە نەدۆزرایەوە',
      'العربية': 'لم يتم العثور على الطلب',
      'English': 'Order not found'
    },
    'هیچ لینکێک بۆ ئەم ئاگادارییە نییە': {
      'کوردی': 'هیچ لینکێک بۆ ئەم ئاگادارییە نییە',
      'العربية': 'لا يوجد رابط لهذا الإشعار',
      'English': 'No link for this notification'
    },
    'پەیوەندی لە ڕێگەی واتسئاپ': {
      'کوردی': 'پەیوەندی لە ڕێگەی واتسئاپ',
      'العربية': 'التواصل عبر الواتساب',
      'English': 'Contact via WhatsApp'
    },
    'تەلەفۆن بۆ ڕاژەی کریاران': {
      'کوردی': 'تەلەفۆن بۆ ڕاژەی کریاران',
      'العربية': 'الاتصال بخدمة العملاء',
      'English': 'Call Customer Service'
    },
    'بەرهەمەکان': {'کوردی': 'بەرهەمەکان', 'العربية': 'المنتجات', 'English': 'Products'},
    'کۆتایی': {'کوردی': 'کۆتایی', 'العربية': 'النهاية', 'English': 'End'},
    'کۆگا پێشنیارکراوەکان': {'کوردی': 'کۆگا پێشنیارکراوەکان', 'العربية': 'المتاجر المقترحة', 'English': 'Recommended Stores'},
    'بینینی هەموو': {'کوردی': 'بینینی هەموو', 'العربية': 'عرض الكل', 'English': 'View All'},
    'هەموو جۆرەکان': {'کوردی': 'هەموو جۆرەکان', 'العربية': 'جميع الأصناف', 'English': 'All Categories'},
    'گەڕان بۆ شوێن...': {'کوردی': 'گەڕان بۆ شوێن...', 'العربية': 'البحث عن مكان...', 'English': 'Search for place...'},
    'دیاریکردنی ناونیشان': {'کوردی': 'دیاریکردنی ناونیشان', 'العربية': 'تحديد العنوان', 'English': 'Select Address'},
    'گەڕان بۆ کۆگا و خواردن': {'کوردی': 'گەڕان بۆ کۆگا و خواردن', 'العربية': 'البحث عن المتجر والطعام', 'English': 'Search for store and food'},
    'هیچ داواکارییەکی تۆمارکراوت نییە': {'کوردی': 'هیچ داواکارییەکی تۆمارکراوت نییە', 'العربية': 'ليس لديك أي طلبات مسجلة', 'English': 'You have no registered orders'},
    'کۆی گشتی داواکاری:': {'کوردی': 'کۆی گشتی داواکاری:', 'العربية': 'المجموع الكلي للطلب:', 'English': 'Order Grand Total:'},
    'هیچ دوکانێک لە بەشی': {'کوردی': 'هیچ دوکانێک لە بەشی', 'العربية': 'لا توجد متاجر في قسم', 'English': 'No stores in'},
    'نەدۆزرایەوە': {'کوردی': 'نەدۆزرایەوە', 'العربية': 'لم يتم العثور عليها', 'English': 'found'},
    'گەڕانەوە بۆ سەرجەم بەشەکان': {'کوردی': 'گەڕانەوە بۆ سەرجەم بەشەکان', 'العربية': 'العودة لجميع الأقسام', 'English': 'Back to all categories'},
    'شوێنەکانی خاوەن داشکاندن': {'کوردی': 'ئۆفەرەکان', 'العربية': 'العروض', 'English': 'Offers'},
    'ئۆفەرەکان': {'کوردی': 'ئۆفەرەکان', 'العربية': 'العروض', 'English': 'Offers'},
    'تەنها ئەو دوکان و چێشتخانانەی داشکاندن یان ئۆفەری تایبەتیان ڕاگەیاندووە': {'کوردی': 'تەنها ئەو دوکان و چێشتخانانەی داشکاندن یان ئۆفەری تایبەتیان ڕاگەیاندووە', 'العربية': 'فقط المتاجر والمطاعم التي أعلنت عن تخفیضات أو عروض خاصة', 'English': 'Only stores and restaurants with active discounts or special offers'},
    'سەبەتەکەت بەتاڵە!': {'کوردی': 'سەبەتەکەت بەتاڵە!', 'العربية': 'سلتك فارغة!', 'English': 'Your cart is empty!'},
    'هیچ کاڵایەکت هەڵنەبژاردووە بۆ کڕین': {'کوردی': 'هیچ کاڵایەکت هەڵنەبژاردووە بۆ کڕین', 'العربية': 'لم تختر أي منتجات للشراء', 'English': 'You haven\'t selected any items to buy'},
    'سەبەتەی کڕین': {'کوردی': 'سەبەتەی کڕین', 'العربية': 'سلة التسوق', 'English': 'Shopping Cart'},
    'داواکاری لە:': {'کوردی': 'داواکاری لە:', 'العربية': 'الطلب من:', 'English': 'Order from:'},
    'سڕینەوەی هەموو': {'کوردی': 'سڕینەوەی هەموو', 'العربية': 'حذف الكل', 'English': 'Clear All'},
    'کورتیی داواکاری': {'کوردی': 'کورتیی داواکاری', 'العربية': 'ملخص الطلب', 'English': 'Order Summary'},
    'کۆی گشتی کاڵاکان': {'کوردی': 'کۆی گشتی کاڵاکان', 'العربية': 'مجموع المنتجات', 'English': 'Items Subtotal'},
    'تێچووی گەیاندن ': {'کوردی': 'تێچووی گەیاندن ', 'العربية': 'تكلفة التوصيل ', 'English': 'Delivery Fee '},
    'کۆی گشتی پارە': {'کوردی': 'کۆی گشتی حساب', 'العربية': 'المجموع الكلي', 'English': 'Grand Total'},
    'کۆی گشتی حساب': {'کوردی': 'کۆی گشتی حساب', 'العربية': 'المجموع الكلي', 'English': 'Grand Total'},
    'کۆی گشتی حساب:': {'کوردی': 'کۆی گشتی حساب:', 'العربية': 'المجموع الكلي:', 'English': 'Grand Total:'},
    'داواکاریەکانم': {'کوردی': 'داواکاریەکانم', 'العربية': 'طلباتي', 'English': 'My Orders'},
    'هەموو': {'کوردی': 'هەموو', 'العربية': 'الكل', 'English': 'All'},
    'بەردەوام': {'کوردی': 'بەردەوام', 'العربية': 'قيد التنفيذ', 'English': 'Ongoing'},
    'تەواوبوو': {'کوردی': 'تەواوبوو', 'العربية': 'مكتمل', 'English': 'Delivered'},
    'هەڵوەشایەوە': {'کوردی': 'هەڵوەشایەوە', 'العربية': 'ملغي', 'English': 'Cancelled'},
    'بەڕێوەیە (زیندوو)': {'کوردی': 'بەڕێوەیە (زیندوو)', 'العربية': 'قيد المعالجة (مباشر)', 'English': 'In Progress (Live)'},
    'پسوولەی داواکاری REGA': {'کوردی': 'پسوولەی داواکاری REGA', 'العربية': 'وصل طلب REGA', 'English': 'REGA Order Receipt'},
    'وەرگیرا': {'کوردی': 'وەرگیرا', 'العربية': 'تم الاستلام', 'English': 'Received'},
    'ئامادەیە': {'کوردی': 'ئامادەیە', 'العربية': 'جاهز', 'English': 'Ready'},
    'هەڵگیرا': {'کوردی': 'هەڵگیرا', 'العربية': 'تم الاستلام للتوصيل', 'English': 'Picked up'},
    'لە ڕێگایە': {'کوردی': 'لە ڕێگایە', 'العربية': 'في الطريق', 'English': 'On the way'},
    'ڕادەست کرا': {'کوردی': 'ڕادەست کرا', 'العربية': 'تم التسليم', 'English': 'Delivered'},
    'لە ئامادەکردن': {'کوردی': 'لە ئامادەکردن', 'العربية': 'قيد التحضير', 'English': 'Preparing'},
    'ئامادەیە بۆ شۆفێر': {'کوردی': 'ئامادەیە بۆ شۆفێر', 'العربية': 'جاهز للسائق', 'English': 'Ready for Driver'},
    'وەرگیرا لە فرۆشگا': {'کوردی': 'وەرگیرا لە فرۆشگا', 'العربية': 'تم الاستلام من المتجر', 'English': 'Picked up from Store'},
    'لە ڕێگایە (بەڕێوەیە)': {'کوردی': 'لە ڕێگایە (بەڕێوەیە)', 'العربية': 'في الطريق إليك', 'English': 'On the way'},
    'شۆفێر گەیشتە ناونیشان': {'کوردی': 'شۆفێر گەیشتە ناونیشان', 'العربية': 'وصل السائق إلى العنوان', 'English': 'Driver Arrived'},
    'Jan': {'کوردی': 'کانونی ٢', 'العربية': 'يناير', 'English': 'Jan'},
    'Feb': {'کوردی': 'شوبات', 'العربية': 'فبراير', 'English': 'Feb'},
    'Mar': {'کوردی': 'ئازار', 'العربية': 'مارس', 'English': 'Mar'},
    'Apr': {'کوردی': 'نیسان', 'العربية': 'أبريل', 'English': 'Apr'},
    'May': {'کوردی': 'ئایار', 'العربية': 'مايو', 'English': 'May'},
    'Jun': {'کوردی': 'حوزەیران', 'العربية': 'يونيو', 'English': 'Jun'},
    'Jul': {'کوردی': 'تەممووز', 'العربية': 'يوليو', 'English': 'Jul'},
    'Aug': {'کوردی': 'ئاب', 'العربية': 'أغسطس', 'English': 'Aug'},
    'Sept': {'کوردی': 'ئەیلوول', 'العربية': 'سبتمبر', 'English': 'Sept'},
    'Oct': {'کوردی': 'تشرینی ١', 'العربية': 'أكتوبر', 'English': 'Oct'},
    'Nov': {'کوردی': 'تشرینی ٢', 'العربية': 'نوفمبر', 'English': 'Nov'},
    'Dec': {'کوردی': 'کانونی ١', 'العربية': 'ديسمبر', 'English': 'Dec'},
  };

  String _t(String text) {
    // New ku/ar/en dictionary (also accepts display names / ckb)
    final localized = CustomerL10n.tr(text, _currentLanguage);
    if (localized != text) return localized;
    // Legacy map keyed by display language names
    if (_translations.containsKey(text)) {
      final legacyKey = CustomerL10n.displayName(_currentLanguage);
      return _translations[text]![legacyKey] ??
          _translations[text]![_currentLanguage] ??
          text;
    }
    return tx(text);
  }

  /// Locale-aware label for home/marketplace categories (name_ku / name_ar / name_en).
  String _homeCatTitle(Map<String, dynamic> cat) {
    return CustomerL10n.entityName(
      nameKu: cat['name_ku']?.toString() ?? cat['catName']?.toString() ?? cat['title']?.toString(),
      nameAr: cat['name_ar']?.toString(),
      nameEn: cat['name_en']?.toString(),
      lang: _currentLanguage,
    );
  }

  String _menuChipTitle(String key, Map<String, dynamic>? meta) {
    if (meta != null) {
      final localized = CustomerL10n.entityName(
        nameKu: meta['name_ku']?.toString() ?? key,
        nameAr: meta['name_ar']?.toString(),
        nameEn: meta['name_en']?.toString(),
        lang: _currentLanguage,
      );
      if (localized.isNotEmpty) return localized;
    }
    return _t(key);
  }

  Widget _buildSettingsDarkModeSwitch() {
    final ltr = _profileLtr;
    final isDark = context.watch<LocaleNotifier>().isDark;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        tx(isDark ? _t('دۆخی تاریک') : _t('دۆخی ڕووناک')),
        textAlign: ltr ? TextAlign.left : TextAlign.right,
        style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 13, fontWeight: FontWeight.bold),
      ),
      secondary: Icon(
        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: RC.fg(Color(0xFFB45309)),
      ),
      value: isDark,
      activeColor: RC.bg(Color(0xFFFAC800)),
      onChanged: (v) => context.read<LocaleNotifier>().setDark(v),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, {bool isLogout = false}) {
    final ltr = _profileLtr;
    final chevron = ltr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded;
    final textColor = isLogout ? RC.bg(Colors.red) : RC.bg(Colors.black87);
    final iconFg = isLogout ? RC.fg(Colors.red) : RC.bg(Color(0xFFB45309));
    final iconBg = isLogout ? RC.bg(Colors.red.shade50) : RC.bg(Colors.amber.shade50);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      visualDensity: VisualDensity.compact,
      onTap: () async {
        if (isLogout) {
          await _clearProfile();
          if (!mounted) return;
          setState(() => _userProfile = null);
          context.go('/login');
        } else if (title == _t('پشتیوانی و یارمەتی')) {
          _showSupportModal();
        } else if (title == _t('مەرج و ڕێساکانی بەکارهێنان')) {
          _showTermsModal();
        } else if (title == _t('سیاسەتی پاراستنی نهێنی')) {
          _showPrivacyModal();
        }
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconFg, size: 20),
      ),
      title: Text(
        tx(title),
        textAlign: ltr ? TextAlign.left : TextAlign.right,
        style: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      trailing: Icon(
        chevron,
        color: isLogout ? RC.fg(Colors.red.shade200) : RC.bg(Colors.grey),
      ),
    );
  }

  Widget _buildProfileTab() {
    final bool isEn = _currentLanguage == 'English';
    if (_userProfile != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: RegaResponsive.constrain(child: _buildRegisteredProfileView()),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RegaResponsive.constrain(
        maxWidth: RegaResponsive.formMaxWidth,
        child: Column(
        children: [
          // 1. TOP TOGGLE (Login / Register)
          if (!_isAccountRenewal)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: RC.bg(Colors.black).withOpacity(0.03), blurRadius: 8, spreadRadius: 1),
              ],
              border: Border.all(color: RC.bg(Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Register Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLoginMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isLoginMode ? RC.bg(Color(0xFFF59E0B)) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t('خۆتۆمارکردن'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'NotoKufiArabic', 
                          color: !_isLoginMode ? RC.bg(Colors.white) : RC.bg(Colors.black54),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                // Login Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLoginMode = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isLoginMode ? RC.bg(Color(0xFFF59E0B)) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t('چوونە ژوورەوە'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'NotoKufiArabic', 
                          color: _isLoginMode ? RC.bg(Colors.white) : RC.bg(Colors.black54),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!_isAccountRenewal) const SizedBox(height: 16),

          // 2. MAIN REGISTRATION CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: RC.bg(Colors.amber).withOpacity(0.15), width: 1),
              boxShadow: [
                BoxShadow(color: RC.bg(Colors.amber).withOpacity(0.03), blurRadius: 15, spreadRadius: 2),
              ],
            ),
            child: Column(
              crossAxisAlignment: isEn ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                // Header: Title, Back
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isEn) ...[
                      _buildProfileTitleHeader(isEn),
                      _buildProfileBackButton(),
                    ] else ...[
                      _buildProfileBackButton(),
                      _buildProfileTitleHeader(isEn),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                if (_isAccountRenewal) ...[
                  Text(
                    _t(_accountRenewalStep == 0
                        ? 'ژمارەی تەلەفۆنەکەت بنووسە و کۆدی پشتڕاستکردنەوە وەربگرە'
                        : 'کۆد و وشەی نهێنی نوێ بنووسە'),
                    textAlign: _profileLtr ? TextAlign.left : TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'NotoKufiArabic',
                      fontSize: 12.5,
                      color: RC.fg(Colors.black54),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Form Fields
                if (_isAccountRenewal) ...[
                  if (_accountRenewalStep == 0)
                    _buildCustomField('ژمارەی تەلەفۆن', _phoneCtrl, Icons.phone_android_outlined, keyboardType: TextInputType.phone)
                  else ...[
                    _buildCustomField('کۆدی پشتڕاستکردنەوە', _otpCtrl, Icons.pin_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildCustomField('وشەی نهێنی', _passwordCtrl, Icons.lock_outline, isPassword: true),
                    const SizedBox(height: 12),
                    _buildCustomField('دووبارەکردنەوەی وشەی نهێنی', _confirmPasswordCtrl, Icons.lock_reset_rounded, isPassword: true),
                    const SizedBox(height: 8),
                    Text(
                      _t('کۆدەکە بۆ ١٠ خولەک کار دەکات.'),
                      textAlign: _profileLtr ? TextAlign.left : TextAlign.right,
                      style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 11.5, color: RC.fg(Colors.black45)),
                    ),
                  ],
                ] else ...[
                  if (!_isLoginMode) ...[
                    _buildCustomField('ناوی تەواو', _nameCtrl, Icons.person_outline),
                    const SizedBox(height: 12),
                  ],
                  _buildCustomField('ژمارەی تەلەفۆن', _phoneCtrl, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildCustomField('وشەی نهێنی', _passwordCtrl, Icons.lock_outline, isPassword: true),
                  if (_isLoginMode) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: _profileLtr ? Alignment.centerLeft : Alignment.centerRight,
                      child: TextButton(
                        onPressed: _startAccountRenewal,
                        style: TextButton.styleFrom(
                          foregroundColor: RC.bg(Color(0xFFB45309)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _t('وشەی نهێنیم لەبیر چوو؟'),
                          style: TextStyle(fontFamily: 'NotoKufiArabic', fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RC.bg(Color(0xFFF59E0B)),
                      foregroundColor: RC.fg(Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _isAccountRenewal
                        ? (_accountRenewalStep == 0 ? _requestPasswordResetOtp : _confirmPasswordReset)
                        : () async {
                      UserProfile profile;
                      if (_isLoginMode) {
                        profile = UserProfile(
                          name: _nameCtrl.text.trim().isEmpty ? _phoneCtrl.text.trim() : _nameCtrl.text.trim(),
                          phone: _phoneCtrl.text.trim(),
                          email: '',
                          address: _deliveryDisplayLabel,
                        );
                      } else {
                        profile = UserProfile(
                          name: _nameCtrl.text.trim(),
                          phone: _phoneCtrl.text.trim(),
                          email: '',
                          address: _deliveryDisplayLabel,
                        );
                      }

                      try {
                        await _saveProfile(profile, allowRegister: !_isLoginMode);
                        if (!mounted) return;
                        setState(() {
                          _userProfile = profile;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_t(_isLoginMode ? '✅ بە سەرکەوتوویی چووە ژوورەوە' : '✅ هەژمارەکەت بە سەرکەوتوویی تۆمار کرا'))),
                        );
                        if (widget.forceAuthOnly) {
                          context.go('/home');
                          // Home MainScreen will show notif + location first-login dialogs.
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            unawaited(_runFirstLoginPermissionFlow());
                          });
                        }
                      } on AccountBlockedException catch (e) {
                        if (!mounted) return;
                        setState(() => _userProfile = null);
                        await _clearProfile();
                        if (!mounted) return;
                        var error = e;
                        if (error.contact.isEmpty ||
                            (error.contact['whatsapp_number'] == null &&
                                error.contact['support_phone'] == null)) {
                          final contacts =
                              await CustomerApiService.instance.fetchSupportContacts();
                          if (contacts.isNotEmpty) {
                            error = AccountBlockedException(
                              message: e.message,
                              contact: {...e.contact, ...contacts},
                            );
                          }
                        }
                        if (!mounted) return;
                        await BlockedAccountContacts.show(
                          context,
                          error,
                          lang: _currentLanguage,
                        );
                      } catch (e) {
                        if (!mounted) return;
                        final err = e.toString();
                        final String msgKey;
                        if (err.contains('password_required')) {
                          msgKey = 'وشەی نهێنی پێویستە (لانیکەم ٦ پیت)';
                        } else if (err.contains('phone_required')) {
                          msgKey = 'ژمارەی تەلەفۆن پێویستە';
                        } else if (err.contains('phone_invalid')) {
                          msgKey = 'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 0770 000 0000';
                        } else if (err.contains('name_required')) {
                          msgKey = 'ناوی تەواو پێویستە';
                        } else if (err.contains('phone_taken')) {
                          msgKey = 'ئەم ژمارەیە پێشتر تۆمارکراوە — تکایە بچۆ ژوورەوە';
                        } else if (err.contains('register_failed') || !_isLoginMode) {
                          msgKey = 'خۆتۆمارکردن سەرکەوتوو نەبوو';
                        } else {
                          msgKey = 'چوونە ژوورەوە سەرکەوتوو نەبوو';
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_t(msgKey))),
                        );
                      }
                    },
                    child: Text(
                      _t(_isAccountRenewal
                          ? (_accountRenewalStep == 0 ? 'ناردنی کۆدی پشتڕاستکردنەوە' : 'نوێکردنەوەی وشەی نهێنی')
                          : (_isLoginMode ? 'چوونە ژوورەوە' : 'بەردەوامبە')),
                      style: TextStyle(fontFamily: 'NotoKufiArabic', fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                if (_isAccountRenewal) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _exitAccountRenewal,
                    child: Text(
                      _t('گەڕانەوە بۆ چوونە ژوورەوە'),
                      style: TextStyle(fontFamily: 'NotoKufiArabic', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. LANGUAGES CARD (AVAILABLE BEFORE LOGIN)
          Container(
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: RC.bg(Colors.grey.shade100)),
              boxShadow: [
                BoxShadow(color: RC.bg(Colors.black).withOpacity(0.03), blurRadius: 10, spreadRadius: 1),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isLanguageExpanded = !_isLanguageExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: _buildSettingsLanguageHeader(),
                  ),
                ),
                
                if (_isLanguageExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildLanguageOption('کوردی', isSelected: _currentLanguage == 'کوردی'),
                        const SizedBox(height: 10),
                        _buildLanguageOption('العربية', isSelected: _currentLanguage == 'العربية'),
                        const SizedBox(height: 10),
                        _buildLanguageOption('English', isSelected: _currentLanguage == 'English'),
                        const SizedBox(height: 14),
                        _buildSettingsDarkModeSwitch(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      ),
    );
  }

  Widget _buildProfileBackButton() {
    final bool isEn = _currentLanguage == 'English';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: RC.bg(Colors.amber.shade100)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(isEn ? Icons.chevron_left : Icons.chevron_right, color: RC.fg(Color(0xFFB45309)), size: 20),
        onPressed: _isAccountRenewal ? _exitAccountRenewal : () {},
      ),
    );
  }

  void _startAccountRenewal() {
    setState(() {
      _isAccountRenewal = true;
      _accountRenewalStep = 0;
      _isLoginMode = true;
      _otpCtrl.clear();
      _confirmPasswordCtrl.clear();
      _passwordCtrl.clear();
    });
  }

  void _exitAccountRenewal() {
    setState(() {
      _isAccountRenewal = false;
      _accountRenewalStep = 0;
      _otpCtrl.clear();
      _confirmPasswordCtrl.clear();
    });
  }

  Future<void> _requestPasswordResetOtp() async {
    try {
      final data = await CustomerApiService.instance.requestPasswordResetOtp(_phoneCtrl.text);
      if (!mounted) return;
      setState(() => _accountRenewalStep = 1);
      var msg = data['message']?.toString() ?? '';
      if (msg.isEmpty) msg = _t('ناردنی کۆدی پشتڕاستکردنەوە');
      final debugOtp = data['debug_otp']?.toString();
      if (debugOtp != null && debugOtp.isNotEmpty) {
        msg = '$msg ($debugOtp)';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(e.message))));
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      final String msgKey;
      if (err.contains('phone_invalid')) {
        msgKey = 'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 0770 000 0000';
      } else {
        msgKey = 'دووبارە هەوڵبدەرەوە';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(msgKey))));
    }
  }

  Future<void> _confirmPasswordReset() async {
    final otp = _otpCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;
    if (otp.replaceAll(RegExp(r'\s+'), '').length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('کۆدی پشتڕاستکردنەوە دەبێت ٦ ژمارە بێت'))),
      );
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('وشەی نهێنی پێویستە (لانیکەم ٦ پیت)'))),
      );
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('وشەی نهێنییەکان یەکسان نین'))),
      );
      return;
    }
    try {
      await CustomerApiService.instance.resetPasswordWithOtp(
        phone: _phoneCtrl.text,
        otp: otp,
        newPassword: pass,
      );
      if (!mounted) return;
      _passwordCtrl.text = pass;
      _exitAccountRenewal();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('✅ وشەی نهێنی نوێکرایەوە — ئێستا بچۆ ژوورەوە'))),
      );
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(e.message))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('دووبارە هەوڵبدەرەوە'))));
    }
  }

  /// Red corner ribbon: داشکاندن + % — matches design reference.
  Widget _buildDiscountCornerRibbon(String pctText, {double size = 86}) {
    final labelSize = size >= 80 ? 10.0 : 8.5;
    final pctSize = size >= 80 ? 13.0 : 11.0;
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: const _DiscountCornerRibbonClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                RC.bg(const Color(0xFFF43F5E)),
                RC.bg(const Color(0xFFE11D48)),
              ],
            ),
          ),
          child: Align(
            alignment: const Alignment(-0.42, -0.42),
            child: Transform.rotate(
              angle: -0.785398, // -45°
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tx('داشکاندن'),
                    style: TextStyle(
                      color: RC.fg(Colors.white),
                      fontSize: labelSize,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tx(pctText),
                    style: TextStyle(
                      color: RC.fg(Colors.white),
                      fontSize: pctSize,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
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

  /// Standard open/closed pill used on store cards and store header.
  Widget _buildStoreOpenBadge(bool isOpen) {
    final bg = isOpen ? const Color(0xFF059669) : const Color(0xFF64748B);
    final dot = isOpen ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: RC.bg(bg),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: RC.bg(Colors.white.withValues(alpha: 0.22)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: RC.bg(dot),
              shape: BoxShape.circle,
              boxShadow: isOpen
                  ? [
                      BoxShadow(
                        color: const Color(0xFF34D399).withValues(alpha: 0.85),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _t(isOpen ? 'کراوە' : 'داخراوە'),
            style: TextStyle(
              color: RC.fg(Colors.white),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTitleHeader(bool isEn) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isEn ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            _t(_isAccountRenewal
                ? 'نوێکردنەوەی هەژمار'
                : (_isLoginMode ? 'چوونە ژوورەوە' : 'خۆتۆمارکردن')),
            style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 18, fontWeight: FontWeight.w900),
            textAlign: isEn ? TextAlign.left : TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomField(String label, TextEditingController controller, IconData icon, {TextInputType keyboardType = TextInputType.text, bool isPassword = false}) {
    final bool isEn = _currentLanguage == 'English';
    final bool isPhone = keyboardType == TextInputType.phone;
    final bool isConfirm = identical(controller, _confirmPasswordCtrl);
    final bool obscure = isPassword && (isConfirm ? _obscureConfirmPassword : _obscurePassword);
    final Widget? eyeToggle = isPassword
        ? IconButton(
            onPressed: () => setState(() {
              if (isConfirm) {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              } else {
                _obscurePassword = !_obscurePassword;
              }
            }),
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: RC.fg(Colors.grey.shade500),
            ),
          )
        : null;
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: isEn || isPhone ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(right: isEn || isPhone ? 0 : 4, left: isEn || isPhone ? 4 : 0, bottom: 6),
            child: Text(
              _t(label),
              textAlign: isEn || isPhone ? TextAlign.left : TextAlign.right,
              style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 13, fontWeight: FontWeight.bold, color: RC.fg(Colors.black87)),
            ),
          ),
          SizedBox(
            height: 48,
            child: Directionality(
              textDirection: isPhone ? TextDirection.ltr : (isEn ? TextDirection.ltr : TextDirection.rtl),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscure,
                textAlign: isPhone || isEn ? TextAlign.left : TextAlign.right,
                inputFormatters: isPhone ? [IraqPhoneFormatter()] : null,
                style: TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 14),
                decoration: InputDecoration(
                  hintText: txn(isPhone ? IraqPhoneFormatter.hint : _t('لێرە بنووسە...')),
                  hintStyle: TextStyle(fontFamily: 'NotoKufiArabic', color: RC.fg(Colors.grey.shade400), fontSize: 12),
                  filled: true,
                  fillColor: RC.bg(Colors.grey.shade50),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  prefixIcon: isPassword
                      ? Icon(icon, size: 20, color: RC.fg(Colors.grey.shade400))
                      : (isEn || isPhone ? Icon(icon, size: 20, color: RC.fg(Colors.grey.shade400)) : null),
                  suffixIcon: isPassword
                      ? eyeToggle
                      : (!isEn && !isPhone ? Icon(icon, size: 20, color: RC.fg(Colors.grey.shade400)) : null),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: RC.bg(Colors.amber).withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: RC.bg(Color(0xFFF59E0B)), width: 1.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GPSTrackingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = RC.bg(Colors.white)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width - 40, 40);
    path.lineTo(size.width * 0.5, 100);
    path.lineTo(40, size.height - 40);

    canvas.drawPath(path, paintRoad);

    final routePaint = Paint()
      ..color = RC.bg(Colors.amber.shade600)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🔴 Diagonal corner ribbon for store-grid discount badge (داشکاندن %)
class _DiscountCornerRibbonClipper extends CustomClipper<Path> {
  const _DiscountCornerRibbonClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 💛 هێڵکاری کەوانەیی بۆ سەر وێنەی دوکان و مارکێتەکان (Curved Tab with App Yellow #FAC800)
class _StoreHeaderCurvedTabPainter extends CustomPainter {
  const _StoreHeaderCurvedTabPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    // Dynamic tab width with responsive limits: ~78% width centered
    final double tabWidth = w * 0.78 > 300.0 ? 300.0 : (w * 0.78 < 260.0 ? (w > 280.0 ? 260.0 : w * 0.9) : w * 0.78);
    final double tabLeft = (w - tabWidth) / 2;
    final double tabRight = (w + tabWidth) / 2;
    const double wingHeight = 4.0;
    const double shoulderWidth = 24.0;
    const double cornerRadius = 18.0;

    final path = Path();
    path.moveTo(0, h);
    path.lineTo(0, h - wingHeight);
    path.lineTo(tabLeft - shoulderWidth, h - wingHeight);

    // Smooth transition curve from wing up to the raised tab shoulder
    path.quadraticBezierTo(
      tabLeft - (shoulderWidth * 0.3),
      h - wingHeight,
      tabLeft,
      h - 18,
    );
    // Vertical side wall to top corner
    path.lineTo(tabLeft, cornerRadius);
    // Top-left rounded corner
    path.quadraticBezierTo(tabLeft, 0, tabLeft + cornerRadius, 0);
    // Top flat edge of the tab
    path.lineTo(tabRight - cornerRadius, 0);
    // Top-right rounded corner
    path.quadraticBezierTo(tabRight, 0, tabRight, cornerRadius);
    // Vertical side wall down
    path.lineTo(tabRight, h - 18);
    // Smooth transition curve from tab shoulder down to right wing
    path.quadraticBezierTo(
      tabRight + (shoulderWidth * 0.3),
      h - wingHeight,
      tabRight + shoulderWidth,
      h - wingHeight,
    );
    path.lineTo(w, h - wingHeight);
    path.lineTo(w, h);
    path.close();

    // Soft drop shadow
    canvas.drawShadow(path, RC.bg(Colors.black).withOpacity(0.35), 4, false);

    // Paint with Official App Theme Color #FAC800
    final paint = Paint()
      ..color = RC.bg(Color(0xFFFAC800))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ============================================================================
/// 🔍 FULL SCREEN ZOOMABLE IMAGE VIEWER (شاشەی فۆڵ شاشەی وێنەی بەرهەمەکان بە Zoom)
/// ============================================================================
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;
  final int? price;
  final String? category;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
    this.price,
    this.category,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? const Offset(150, 150);
      _transformController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.4).clamp(0.8, 5.0);
    setState(() {
      _transformController.value = Matrix4.identity()..scale(newScale);
    });
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.4).clamp(0.8, 5.0);
    setState(() {
      _transformController.value = Matrix4.identity()..scale(newScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg(Colors.black).withOpacity(0.96),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center Zoomable Interactive Viewer
            Center(
              child: GestureDetector(
                onDoubleTapDown: (d) => _doubleTapDetails = d,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  clipBehavior: Clip.none,
                  minScale: 0.8,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(50),
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(RC.bg(Color(0xFFFAC800))),
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 64, color: RC.fg(Colors.white54)),
                          SizedBox(height: 12),
                          Text(
                            tx('وێنەکە بارنەکرا'),
                            style: TextStyle(color: RC.fg(Colors.white70), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top Header: Close Button + Product Title + Reset Zoom
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.black).withOpacity(0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: RC.bg(Colors.white).withOpacity(0.25), width: 1),
                      ),
                      child: Icon(Icons.close, color: RC.fg(Colors.white), size: 24),
                    ),
                  ),

                  // Title Pill
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.black).withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: RC.bg(Colors.white).withOpacity(0.2), width: 1),
                      ),
                      child: Text(
                        tx(widget.title),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: RC.fg(Colors.white),
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Reset Zoom Button
                  InkWell(
                    onTap: _resetZoom,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.black).withOpacity(0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: RC.bg(Colors.white).withOpacity(0.25), width: 1),
                      ),
                      child: Icon(Icons.refresh, color: RC.fg(Colors.white), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home reklaming carousel — images come from admin Marketing → Banners upload.
class _HomePromoBannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final void Function(Map<String, dynamic> banner) onBannerTap;

  const _HomePromoBannerCarousel({
    required this.banners,
    required this.onBannerTap,
  });

  @override
  State<_HomePromoBannerCarousel> createState() => _HomePromoBannerCarouselState();
}

class _HomePromoBannerCarouselState extends State<_HomePromoBannerCarousel> {
  late final PageController _pageCtrl;
  Timer? _autoTimer;
  int _index = 0;
  int _pageCount = 1;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    // Start after first frame so PageView has clients (web-safe).
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoRotate());
  }

  void _startAutoRotate() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) => _goNext());
  }

  void _goNext() {
    if (!mounted) return;
    if (_pageCount <= 1) return;
    if (!_pageCtrl.hasClients) return;
    final next = (_index + 1) % _pageCount;
    try {
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } catch (_) {
      try {
        _pageCtrl.jumpToPage(next);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners
        .where((b) => (b['image_url']?.toString() ?? '').trim().isNotEmpty)
        .toList();
    if (banners.isEmpty) return const SizedBox(height: 8);

    final bannerHeight = MediaQuery.of(context).size.width >= 640 ? 230.0 : 170.0;
    // Up to 5 reklaming images — image only, auto-advance every 5s.
    final count = banners.length.clamp(1, 5);
    _pageCount = count;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: bannerHeight,
              // Force LTR so "next" page always slides toward the right visually.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: count,
                  allowImplicitScrolling: true,
                  onPageChanged: (i) {
                    if (mounted) setState(() => _index = i);
                  },
                  itemBuilder: (context, i) {
                    final banner = banners[i];
                    final bannerImg =
                        RegaApiHost.resolveMediaUrl(banner['image_url']?.toString());
                    return GestureDetector(
                      onTap: () => widget.onBannerTap(banner),
                      child: Image.network(
                        bannerImg,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: bannerHeight,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            Container(color: RC.bg(const Color(0xFF1E293B))),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: active ? RC.bg(Colors.orange) : RC.bg(Colors.amber.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

