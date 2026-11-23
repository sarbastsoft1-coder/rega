import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import '../map/rega_map_styles.dart';
import '../map/rega_standard_map.dart';
import '../models/map_place.dart';
import '../services/location_service.dart';

/// Fullscreen work-city map — Mapbox Standard (replaces Google Maps).
class KalarMapScreen extends StatefulWidget {
  final String language;
  final VoidCallback? onBack;
  final LatLng? initialCenter;
  final String? cityLabel;

  const KalarMapScreen({
    super.key,
    this.language = 'Kurdish',
    this.onBack,
    this.initialCenter,
    this.cityLabel,
  });

  @override
  State<KalarMapScreen> createState() => _KalarMapScreenState();
}

class _KalarMapScreenState extends State<KalarMapScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey<RegaStandardMapState> _mapKey = GlobalKey<RegaStandardMapState>();

  mb.PointAnnotationManager? _points;
  bool _isLocating = false;
  LatLng? _currentGpsLocation;
  MapPlace? _selectedPlace;
  String _activeCategory = 'all';
  List<MapPlace> _searchResults = [];

  bool get _isRtl => widget.language != 'English';

  static const LatLng _kalarCenter = LatLng(34.6313, 45.3177);

  LatLng get _mapCenter => widget.initialCenter ?? _kalarCenter;

  @override
  void initState() {
    super.initState();
    _tryGetInitialLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    try {
      _points = await map.annotations.createPointAnnotationManager();
    } catch (_) {}
    await _syncLandmarks();
  }

  Future<void> _syncLandmarks() async {
    final mgr = _points;
    if (mgr == null) return;
    try {
      await mgr.deleteAll();
    } catch (_) {}

    for (final place in KalarLandmarks.curatedPlaces) {
      if (_activeCategory != 'all' && place.iconKey != _activeCategory) continue;
      final selected = _selectedPlace?.id == place.id;
      try {
        await mgr.create(
          mb.PointAnnotationOptions(
            geometry: mb.Point(
              coordinates: mb.Position(place.longitude, place.latitude),
            ),
            textField: place.localizedName(widget.language),
            textSize: selected ? 13.0 : 11.0,
            textColor: selected ? 0xFF1D4ED8 : 0xFF0F172A,
            textHaloColor: 0xFFFFFFFF,
            textHaloWidth: 1.1,
            iconSize: selected ? 1.4 : 1.1,
          ),
        );
      } catch (_) {}
    }

    if (_currentGpsLocation != null) {
      try {
        await mgr.create(
          mb.PointAnnotationOptions(
            geometry: mb.Point(
              coordinates: mb.Position(
                _currentGpsLocation!.longitude,
                _currentGpsLocation!.latitude,
              ),
            ),
            textField: _isRtl ? 'شوێنی ئێستای تۆ' : 'You',
            textSize: 12.0,
            textColor: 0xFF2563EB,
            textHaloColor: 0xFFFFFFFF,
            textHaloWidth: 1.2,
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _tryGetInitialLocation() async {
    final res = await KalarLocationService.getCurrentLocation(requestIfNeeded: false);
    if (res.isSuccess && mounted) {
      final pos = res.position!;
      setState(() {
        _currentGpsLocation = LatLng(pos.latitude, pos.longitude);
      });
      await _syncLandmarks();
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
      setState(() => _currentGpsLocation = target);
      await _mapKey.currentState?.moveTo(target, zoom: 16.5);
      await _syncLandmarks();
    }
  }

  void _onPlaceSelected(MapPlace place) {
    setState(() => _selectedPlace = place);
    _mapKey.currentState?.moveTo(
      LatLng(place.latitude, place.longitude),
      zoom: 16.8,
    );
    _syncLandmarks();
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = KalarLandmarks.curatedPlaces.where((p) {
      final hay = '${p.nameKu} ${p.nameEn} ${p.nameAr}'.toLowerCase();
      return hay.contains(query);
    }).toList();
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RegaStandardMap(
              key: _mapKey,
              center: _currentGpsLocation ?? _mapCenter,
              zoom: 14.8,
              initialStyle: RegaMapStyles.defaultTracking,
              showLayersFab: true,
              onMapCreated: _onMapCreated,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onBack ?? () => Navigator.maybePop(context),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Material(
                        color: Colors.white,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(16),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearch,
                          decoration: InputDecoration(
                            hintText: _isRtl
                                ? 'گەڕان لە ${widget.cityLabel ?? 'کەلار'}...'
                                : 'Search Kalar...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isLocating ? null : _handleMyLocationTap,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFFAC800),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _isLocating
                                  ? Icons.hourglass_top_rounded
                                  : Icons.gps_fixed_rounded,
                              size: 22,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_searchResults.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 12,
              right: 12,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length.clamp(0, 8),
                  itemBuilder: (_, i) {
                    final p = _searchResults[i];
                    return ListTile(
                      dense: true,
                      title: Text(p.localizedName(widget.language)),
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                        _onPlaceSelected(p);
                      },
                    );
                  },
                ),
              ),
            ),
          if (_selectedPlace != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 24,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _selectedPlace!.localizedName(widget.language),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedPlace!.localizedCategory(widget.language),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final cat in const ['all', 'hospital', 'school', 'market', 'park'])
                            ChoiceChip(
                              label: Text(cat),
                              selected: _activeCategory == cat,
                              onSelected: (_) {
                                setState(() => _activeCategory = cat);
                                _syncLandmarks();
                              },
                            ),
                        ],
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
}
