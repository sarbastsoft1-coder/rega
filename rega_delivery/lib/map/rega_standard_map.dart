import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'rega_map_styles.dart';

/// Fullscreen Mapbox map host (streets like customer app).
class RegaStandardMap extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final RegaMapStyleId initialStyle;
  final ValueChanged<MapboxMap>? onMapCreated;
  final OnCameraChangeListener? onCameraChange;
  final bool showLayersFab;
  final ValueChanged<RegaMapStyleId>? onStyleChanged;

  const RegaStandardMap({
    super.key,
    required this.center,
    this.zoom = 14.5,
    this.initialStyle = RegaMapStyles.defaultTracking,
    this.onMapCreated,
    this.onCameraChange,
    this.showLayersFab = false,
    this.onStyleChanged,
  });

  @override
  State<RegaStandardMap> createState() => RegaStandardMapState();
}

class RegaStandardMapState extends State<RegaStandardMap> {
  MapboxMap? map;
  late RegaMapStyleId _styleId;

  @override
  void initState() {
    super.initState();
    _styleId = widget.initialStyle;
  }

  Point _point(LatLng p) => Point(coordinates: Position(p.longitude, p.latitude));

  Future<void> moveTo(LatLng center, {double? zoom}) async {
    final m = map;
    if (m == null) return;
    try {
      final z = zoom ?? (await m.getCameraState()).zoom;
      await m.setCamera(CameraOptions(center: _point(center), zoom: z));
    } catch (_) {}
  }

p
                'جۆری نەخشە',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ...RegaMapStyles.all.map((id) {
                final selected = id == _styleId;
                return ListTile(
                  selected: selected,
                  leading: Icon(
                    id == RegaMapStyleId.satellite
                        ? Icons.satellite_alt_rounded
                        : id == RegaMapStyleId.dark
                            ? Icons.dark_mode_rounded
                            : id == RegaMapStyleId.outdoors
                                ? Icons.terrain_rounded
                                : Icons.map_rounded,
                  ),
                  title: Text('${RegaMapStyles.labelKu(id)} · ${RegaMapStyles.labelEn(id)}'),
                  trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFFFAC800)) : null,
                  onTap: () => Navigator.pop(ctx, id),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await applyStyle(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: ValueKey('rega_std_${_styleId.name}'),
          styleUri: RegaMapStyles.uri(_styleId),
          viewport: CameraViewportState(
            center: _point(widget.center),
            zoom: widget.zoom,
          ),
          onMapCreated: (m) async {
            map = m;
            try {
              await m.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
              await m.compass.updateSettings(CompassSettings(enabled: false));
            } catch (_) {}
            try {
              await RegaMapStyles.applyConfig(m, _styleId);
            } catch (_) {}
            widget.onMapCreated?.call(m);
          },
          onCameraChangeListener: widget.onCameraChange,
          onMapLoadErrorListener: (_) async {
            final m = map;
            if (m == null) return;
            try {
              await m.loadStyleURI(RegaMapStyles.fallbackUri(_styleId));
              await RegaMapStyles.applyConfig(m, _styleId);
            } catch (_) {}
          },
        ),
        if (widget.showLayersFab)
          Positioned(
            right: 12,
            bottom: 16,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _openLayers,
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(Icons.layers_rounded, color: Color(0xFF16A34A)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
