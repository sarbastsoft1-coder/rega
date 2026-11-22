import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapFloatingControls extends StatelessWidget {
  final MapType currentMapType;
  final ValueChanged<MapType> onMapTypeChanged;
  final VoidCallback onCompassPressed;
  final VoidCallback onMyLocationPressed;
  final VoidCallback onZoomInPressed;
  final VoidCallback onZoomOutPressed;
  final bool isLocating;
  final String language;

  const MapFloatingControls({
    super.key,
    required this.currentMapType,
    required this.onMapTypeChanged,
    required this.onCompassPressed,
    required this.onMyLocationPressed,
    required this.onZoomInPressed,
    required this.onZoomOutPressed,
    this.isLocating = false,
    this.language = 'Kurdish',
  });

  bool get _isRtl => language != 'English';

  void _showLayersDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isRtl ? 'جۆری نەخشە' : 'Map Type',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _layerOption(
                    title: _isRtl ? 'هایبرید (مانگی دەستکرد)' : 'Hybrid',
                    icon: Icons.satellite_alt_rounded,
                    isSelected: currentMapType == MapType.hybrid,
                    onTap: () {
                      onMapTypeChanged(MapType.hybrid);
                      Navigator.pop(ctx);
                    },
                  ),
                  _layerOption(
                    title: _isRtl ? 'مانگی دەستکرد' : 'Satellite',
                    icon: Icons.layers_rounded,
                    isSelected: currentMapType == MapType.satellite,
                    onTap: () {
                      onMapTypeChanged(MapType.satellite);
                      Navigator.pop(ctx);
                    },
                  ),
                  _layerOption(
                    title: _isRtl ? 'ئاسایی' : 'Standard',
                    icon: Icons.map_rounded,
                    isSelected: currentMapType == MapType.normal,
                    onTap: () {
                      onMapTypeChanged(MapType.normal);
                      Navigator.pop(ctx);
                    },
                  ),
                  _layerOption(
                    title: _isRtl ? 'تەرەین' : 'Terrain',
                    icon: Icons.terrain_rounded,
                    isSelected: currentMapType == MapType.terrain,
                    onTap: () {
                      onMapTypeChanged(MapType.terrain);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _layerOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEAB308).withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFEAB308) : Colors.transparent,
                width: 2.2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFFB45309) : const Color(0xFF475569),
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Layers selector button
        _roundActionButton(
          icon: Icons.layers_rounded,
          onTap: () => _showLayersDialog(context),
          tooltip: _isRtl ? 'گۆڕینی نەخشە' : 'Map Layers',
        ),
        const SizedBox(height: 10),

        // Compass / Reset North button
        _roundActionButton(
          icon: Icons.explore_rounded,
          iconColor: const Color(0xFFDC2626),
          onTap: onCompassPressed,
          tooltip: _isRtl ? 'ڕووگە بۆ باکوور' : 'Compass North',
        ),
        const SizedBox(height: 10),

        // Current GPS location button
        _roundActionButton(
          icon: isLocating ? Icons.hourglass_top_rounded : Icons.my_location_rounded,
          iconColor: isLocating ? const Color(0xFFEAB308) : const Color(0xFF2563EB),
          onTap: onMyLocationPressed,
          tooltip: _isRtl ? 'شوێنی ئێستا' : 'Current Location',
        ),
        const SizedBox(height: 14),

        // Zoom In / Out Pill
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onZoomInPressed,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.add_rounded, color: Color(0xFF1E293B), size: 22),
                ),
              ),
              Container(width: 28, height: 1, color: const Color(0xFFE2E8F0)),
              InkWell(
                onTap: onZoomOutPressed,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.remove_rounded, color: Color(0xFF1E293B), size: 22),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF1E293B),
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}
