import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_place.dart';
import '../services/google_map_service.dart';
import '../services/location_service.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/map_bottom_sheet.dart';

class KalarMapScreen extends StatefulWidget {
  final String language; // 'Kurdish', 'العربية', 'English'
  final VoidCallback? onBack;

  const KalarMapScreen({
    super.key,
    this.language = 'Kurdish',
    this.onBack,
  });

  @override
  State<KalarMapScreen> createState() => _KalarMapScreenState();
}

class _KalarMapScreenState extends State<KalarMapScreen> {
  final GoogleMapService _mapService = GoogleMapService();
  final TextEditingController _searchCtrl = TextEditingController();

  MapType _currentMapType = MapType.hybrid;
  bool _isLocating = false;
  LatLng? _currentGpsLocation;
  String? _currentLocationAddress;

  MapPlace? _selectedPlace;
  String _activeCategory = 'all';

  List<MapPlace> _searchResults = [];
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  bool get _isRtl => widget.language != 'English';

  @override
  void initState() {
    super.initState();
    _buildMarkers();
    _tryGetInitialLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapService.dispose();
    super.dispose();
  }

  void _buildMarkers() {
    final markers = <Marker>{};

    for (final place in KalarLandmarks.curatedPlaces) {
      if (_activeCategory != 'all' && place.iconKey != _activeCategory) {
        continue;
      }

      final isSelected = _selectedPlace?.id == place.id;

      markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.latitude, place.longitude),
          icon: isSelected
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: place.localizedName(widget.language),
            snippet: place.localizedCategory(widget.language),
            onTap: () => _onPlaceSelected(place),
          ),
          onTap: () => _onPlaceSelected(place),
        ),
      );
    }

    // Add current GPS indicator if available
    if (_currentGpsLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_current_location'),
          position: _currentGpsLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: _isRtl ? 'شوێنی ئێستای تۆ' : 'Your Current Location',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _tryGetInitialLocation() async {
    final res = await KalarLocationService.getCurrentLocation(requestIfNeeded: false);
    if (res.isSuccess && mounted) {
      final pos = res.position!;
      setState(() {
        _currentGpsLocation = LatLng(pos.latitude, pos.longitude);
        _currentLocationAddress = 'کەلار، دیاریکراو لە ڕێگەی GPS';
        _circles = {
          Circle(
            circleId: const CircleId('gps_accuracy'),
            center: _currentGpsLocation!,
            radius: pos.accuracy.clamp(10, 80),
            fillColor: const Color(0xFF3B82F6).withValues(alpha: 0.18),
            strokeColor: const Color(0xFF2563EB),
            strokeWidth: 2,
          ),
        };
      });
      _buildMarkers();
    }
  }

  Future<void> _handleMyLocationTap() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    final res = await KalarLocationService.getCurrentLocation(requestIfNeeded: true);
    if (!mounted) return;

    setState(() => _isLocating = false);

    if (res.isSuccess) {
      final pos = res.position!;
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentGpsLocation = target;
        _currentLocationAddress = 'کەلار، پێگەی فەرمی کڕیار';
        _circles = {
          Circle(
            circleId: const CircleId('gps_accuracy'),
            center: target,
            radius: pos.accuracy.clamp(10, 80),
            fillColor: const Color(0xFF3B82F6).withValues(alpha: 0.18),
            strokeColor: const Color(0xFF2563EB),
            strokeWidth: 2,
          ),
        };
      });
      _buildMarkers();
      await _mapService.animateToLocation(target, zoom: 17.0);
    } else {
      _showLocationErrorDialog(res.status, res.errorMessage);
    }
  }

  void _showLocationErrorDialog(LocationStatus status, String? msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
          children: [
            const Icon(Icons.location_disabled_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text(
              _isRtl ? 'کێشە لە دۆزینەوەی شوێن' : 'Location Issue',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          msg ?? (_isRtl ? 'تکایە دڵنیابە لە کاراکردنی GPS لە مۆبایلەکەتدا.' : 'Please enable GPS on your device.'),
          textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (status == LocationStatus.serviceDisabled)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                KalarLocationService.openLocationSettings();
              },
              child: Text(_isRtl ? 'کردنەوەی ڕێکخستنی GPS' : 'Open GPS Settings'),
            ),
          if (status == LocationStatus.permissionDeniedForever)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                KalarLocationService.openAppSettings();
              },
              child: Text(_isRtl ? 'ڕێکخستنی بەرنامەکان' : 'App Settings'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isRtl ? 'داخستن' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _onPlaceSelected(MapPlace place) {
    setState(() {
      _selectedPlace = place;
      _searchResults = [];
    });
    _buildMarkers();
    _mapService.animateToLocation(
      LatLng(place.latitude, place.longitude),
      zoom: 17.5,
    );
  }

  void _onSearchQueryChanged(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final results = KalarLandmarks.curatedPlaces.where((p) {
      return p.nameKu.toLowerCase().contains(clean) ||
          p.nameAr.toLowerCase().contains(clean) ||
          p.nameEn.toLowerCase().contains(clean) ||
          p.categoryKu.toLowerCase().contains(clean);
    }).toList();

    setState(() => _searchResults = results);
  }

  void _onCategoryFilter(String key) {
    setState(() {
      _activeCategory = key;
    });
    _buildMarkers();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Google Maps View occupying the full screen
          GoogleMap(
            initialCameraPosition: GoogleMapConfig.kalarInitialCamera,
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: true,
            trafficEnabled: true,
            indoorViewEnabled: true,
            cameraTargetBounds: CameraTargetBounds(GoogleMapConfig.kalarBounds),
            minMaxZoomPreference: const MinMaxZoomPreference(11.0, 20.0),
            markers: _markers,
            circles: _circles,
            onMapCreated: (ctrl) {
              _mapService.setController(ctrl);
            },
            onTap: (_) {
              if (_selectedPlace != null || _searchResults.isNotEmpty) {
                setState(() {
                  _selectedPlace = null;
                  _searchResults = [];
                });
                _buildMarkers();
              }
            },
          ),

          // 2. Top search bar + back button
          Positioned(
            top: mediaQuery.padding.top + 10,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: MapSearchBar(
                controller: _searchCtrl,
                onChanged: _onSearchQueryChanged,
                onClear: () {
                  _searchCtrl.clear();
                  setState(() => _searchResults = []);
                },
                onFilterTap: () => _showFilterDialog(),
                onBackTap: widget.onBack ?? (Navigator.canPop(context) ? () => Navigator.pop(context) : null),
                language: widget.language,
                searchResults: _searchResults,
                onSelectPlace: _onPlaceSelected,
              ),
            ),
          ),

          // 3. Floating map controls (Layers, Compass, GPS, Zoom +/-)
          Positioned(
            top: mediaQuery.padding.top + 80,
            right: _isRtl ? 16 : null,
            left: _isRtl ? null : 16,
            child: MapFloatingControls(
              currentMapType: _currentMapType,
              onMapTypeChanged: (type) => setState(() => _currentMapType = type),
              onCompassPressed: () => _mapService.resetBearingToNorth(),
              onMyLocationPressed: _handleMyLocationTap,
              onZoomInPressed: () => _mapService.zoomIn(),
              onZoomOutPressed: () => _mapService.zoomOut(),
              isLocating: _isLocating,
              language: widget.language,
            ),
          ),

          // 4. Modern Expandable & Draggable Google Maps Bottom Sheet
          MapBottomSheet(
            selectedPlace: _selectedPlace,
            currentLocationAddress: _currentLocationAddress,
            currentCategory: _activeCategory,
            onCategoryFilterSelected: _onCategoryFilter,
            onPlaceTapped: _onPlaceSelected,
            onDirectionsTapped: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isRtl ? 'ڕێڕەوی ڕاستەوخۆ دیاریکرا' : 'Route displayed for Kalar delivery',
                    textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            language: widget.language,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRtl ? 'فلتەرکردنی شوێنەکان لە کەلار' : 'Filter Kalar Places',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.local_hospital_rounded, color: Color(0xFFDC2626)),
                title: Text(_isRtl ? 'نەخۆشخانە و تەندروستی' : 'Hospitals & Clinics'),
                onTap: () {
                  _onCategoryFilter('hospital');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_rounded, color: Color(0xFFD97706)),
                title: Text(_isRtl ? 'بازاڕ و مۆڵەکان' : 'Markets & Malls'),
                onTap: () {
                  _onCategoryFilter('market');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.school_rounded, color: Color(0xFF2563EB)),
                title: Text(_isRtl ? 'زانکۆ و خوێندنگەکان' : 'Universities & Schools'),
                onTap: () {
                  _onCategoryFilter('school');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.park_rounded, color: Color(0xFF16A34A)),
                title: Text(_isRtl ? 'باخچە و شوێنە گشتییەکان' : 'Parks & Public Greenery'),
                onTap: () {
                  _onCategoryFilter('park');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
