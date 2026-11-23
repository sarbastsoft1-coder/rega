import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../map/mapbox_tiles.dart';
import '../rega_colors.dart';
import '../rega_i18n.dart';

/// Fullscreen center-pin picker for admin vendor lat/lng.
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
  State<_VendorLocationPickerSheet> createState() => _VendorLocationPickerSheetState();
}

class _VendorLocationPickerSheetState extends State<_VendorLocationPickerSheet> {
  final MapController _mapCtrl = MapController();
  late LatLng _pinned;
  bool _applying = false;

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
                              style: MapboxStyle.streets,
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
                        const IgnorePointer(
                          child: Align(
                            alignment: Alignment(0, -0.04),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 54,
                              color: Color(0xFFE11D48),
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          bottom: 88,
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
                          icon: Icon(Icons.close_rounded, color: RC.fg(const Color(0xFF0F172A))),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: RC.bg(Colors.white.withValues(alpha: 0.92)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
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
  }

  Widget _zoomBtn(IconData icon, double delta) {
    return Material(
      color: Colors.white,
      elevation: 4,
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
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}
