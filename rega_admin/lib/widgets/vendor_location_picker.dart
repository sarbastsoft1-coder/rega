import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../map/mapbox_tiles.dart';
import '../rega_colors.dart';
import '../rega_i18n.dart';

/// Fullscreen Customer-style center-pin picker for Admin vendor lat/lng.
Future<LatLng?> showVendorLocationPicker(
  BuildContext context, {
  required LatLng initial,
  String title = 'دیاریکردنی شوێنی فرۆشگا',
}) {
  return showModalBottomSheet<LatLng>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _VendorLocationPickerSheet(initial: initial, title: title),
  );
}

class _VendorLocationPickerSheet extends StatefulWidget {
  final LatLng initial;
  final String title;

  const _VendorLocationPickerSheet({
    required this.initial,
    required this.title,
  });

  @override
  State<_VendorLocationPickerSheet> createState() =>
      _VendorLocationPickerSheetState();
}

class _VendorLocationPickerSheetState
    extends State<_VendorLocationPickerSheet> {
  final MapController _mapCtrl = MapController();
  late LatLng _pinned;
  bool _applying = false;
  bool _isSatellite = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.initial;
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (_applying) return;
    if (event is MapEventMove || event is MapEventMoveEnd) {
      final c = event.camera.center;
      if ((c.latitude - _pinned.latitude).abs() < 1e-7 &&
          (c.longitude - _pinned.longitude).abs() < 1e-7) {
        return;
      }
      setState(() => _pinned = c);
    }
  }

  Future<void> _goToCurrentGps() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      _applying = true;
      setState(() => _pinned = widget.initial);
      _mapCtrl.move(widget.initial, 16.2);
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        _applying = false;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _modeChip({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return Material(
      color: active ? activeColor : Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F172A),
                  ),
                )
              else
                Icon(icon, size: 17, color: const Color(0xFF0F172A)),
              const SizedBox(width: 6),
              Text(
                tx(label),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFAC800);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Material(
          color: RC.bg(Colors.white),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.92,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 52,
                    ),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(
                            initialCenter: _pinned,
                            initialZoom: 16.2,
                            minZoom: 5,
                            maxZoom: 20,
                            backgroundColor: const Color(0xFFE8EEF4),
                            onMapEvent: _onMapEvent,
                          ),
                          children: [
                            MapboxTiles.layer(
                              style: _isSatellite
                                  ? MapboxStyle.satellite
                                  : MapboxStyle.streets,
                              userAgentPackageName: 'tech.rega.admin',
                              fallbackStyle: MapboxStyle.outdoors,
                            ),
                            RichAttributionWidget(
                              attributions: const [
                                TextSourceAttribution('Mapbox'),
                                TextSourceAttribution('OpenStreetMap'),
                              ],
                            ),
                          ],
                        ),
                        // Customer-style top chips: سەتەلایت | شوێنەکەم
                        Positioned(
                          top: 12,
                          left: 10,
                          right: 10,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              children: [
                                _modeChip(
                                  label: 'سەتەلایت',
                                  icon: Icons.satellite_alt_rounded,
                                  active: _isSatellite,
                                  activeColor: gold,
                                  onTap: () => setState(
                                      () => _isSatellite = !_isSatellite),
                                ),
                                const Spacer(),
                                _modeChip(
                                  label: 'شوێنەکەم',
                                  icon: Icons.my_location_rounded,
                                  active: true,
                                  activeColor: gold,
                                  busy: _locating,
                                  onTap: _goToCurrentGps,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const IgnorePointer(
                          child: Align(
                            alignment: Alignment(0, -0.04),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 54,
                              color: Color(0xFFE11D48),
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          bottom: 108,
                          child: Column(
                            children: [
                              _zoomBtn(Icons.add_rounded, 1),
                              const SizedBox(height: 10),
                              _zoomBtn(Icons.remove_rounded, -1),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: RC.bg(gold),
                    padding: EdgeInsets.fromLTRB(
                      4,
                      MediaQuery.of(context).padding.top + 2,
                      4,
                      8,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            tx(widget.title),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: RC.fg(const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: RC.fg(const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12 + bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: RC.bg(Colors.white.withValues(alpha: 0.92)),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                        ),
                        child: Text(
                          '${_pinned.latitude.toStringAsFixed(6)}, ${_pinned.longitude.toStringAsFixed(6)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: RC.fg(const Color(0xFF334155)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(gold),
                            foregroundColor: RC.fg(Colors.black),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, _pinned),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            tx('پاشەکەوتکردنی شوێنی فرۆشگا'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
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
  }

  Widget _zoomBtn(IconData icon, double delta) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          try {
            final cam = _mapCtrl.camera;
            _applying = true;
            _mapCtrl.move(cam.center, (cam.zoom + delta).clamp(5.0, 20.0));
            Future<void>.delayed(const Duration(milliseconds: 80), () {
              _applying = false;
            });
          } catch (_) {}
        },
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: const Color(0xFF0F172A), size: 24),
        ),
      ),
    );
  }
}
