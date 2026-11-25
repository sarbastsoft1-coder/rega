import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../map/rega_map_styles.dart';
import '../map/rega_standard_map.dart';
import '../models/map_place.dart';
import '../services/location_service.dart';

/// Fullscreen work-city map in Customer app — unified with Customer FlutterMap + MapboxTiles.
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
  final GlobalKey<RegaStandardMapState> _mapKey =
      GlobalKey<RegaStandardMapState>();

  bool _isLocating = false;
  LatLng? _currentGpsLocation;
  MapPlace? _selectedPlace;
  final String _activeCategory = 'all';
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

  List<Marker> _buildLandmarkMarkers() {
    final markers = <Marker>[];
    for (final place in KalarLandmarks.curatedPlaces) {
      if (_activeCategory != 'all' && place.iconKey != _activeCategory) continue;
      final selected = _selectedPlace?.id == place.id;
      markers.add(
        Marker(
          point: LatLng(place.latitude, place.longitude),
          width: 110,
          height: 62,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _onPlaceSelected(place),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    place.localizedName(widget.language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: selected ? 34 : 28,
                  height: selected ? 34 : 28,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFAC800)
                        : const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.place_rounded,
                    size: selected ? 20 : 16,
                    color: selected ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentGpsLocation != null) {
      markers.add(
        Marker(
          point: _currentGpsLocation!,
          width: 90,
          height: 54,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isRtl ? 'شوێنی تۆ' : 'You',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return markers;
  }

  Future<void> _tryGetInitialLocation() async {
    final res =
        await KalarLocationService.getCurrentLocation(requestIfNeeded: false);
    if (res.isSuccess && mounted) {
      final pos = res.position!;
      setState(() {
        _currentGpsLocation = LatLng(pos.latitude, pos.longitude);
      });
    }
  }

  Future<void> _handleMyLocationTap() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    final res =
        await KalarLocationService.getCurrentLocation(requestIfNeeded: true);
    if (!mounted) return;
    setState(() => _isLocating = false);
    if (res.isSuccess) {
      final pos = res.position!;
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentGpsLocation = target);
      await _mapKey.currentState?.moveTo(target, zoom: 16.5);
    }
  }

  void _onPlaceSelected(MapPlace place) {
    setState(() => _selectedPlace = place);
    _mapKey.currentState?.moveTo(
      LatLng(place.latitude, place.longitude),
      zoom: 16.8,
    );
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
              showCustomerControls: true,
              topControlsOffset: MediaQuery.of(context).padding.top + 64,
              markers: _buildLandmarkMarkers(),
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
                        onTap:
                            widget.onBack ?? () => Navigator.maybePop(context),
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
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
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
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Color(0xFFE11D48), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedPlace!.localizedName(widget.language),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _selectedPlace = null),
                        icon: const Icon(Icons.close_rounded),
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
