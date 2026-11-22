import 'package:flutter/material.dart';
import '../models/map_place.dart';

class MapBottomSheet extends StatelessWidget {
  final MapPlace? selectedPlace;
  final String? currentLocationAddress;
  final ValueChanged<String> onCategoryFilterSelected;
  final ValueChanged<MapPlace> onPlaceTapped;
  final VoidCallback onDirectionsTapped;
  final String language;
  final String currentCategory;

  const MapBottomSheet({
    super.key,
    this.selectedPlace,
    this.currentLocationAddress,
    required this.onCategoryFilterSelected,
    required this.onPlaceTapped,
    required this.onDirectionsTapped,
    this.language = 'Kurdish',
    this.currentCategory = 'all',
  });

  bool get _isRtl => language != 'English';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.16,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.16, 0.32, 0.65, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Location header + Weather card
              _buildLocationAndWeatherHeader(context),
              const SizedBox(height: 16),

              // Fast category shortcuts (Kurdish: نەخۆشخانە، قوتابخانە، بازاڕ، باخچە، ڕێگاکان)
              _buildCategoryShortcuts(),
              const SizedBox(height: 18),

              // If a place is selected on the map, show its details highlight card
              if (selectedPlace != null) ...[
                _buildSelectedPlaceCard(context, selectedPlace!),
                const SizedBox(height: 18),
              ],

              // Nearby landmarks list in Kalar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isRtl ? 'شوێنە گرنگەکانی کەلار' : 'Prominent Places in Kalar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${KalarLandmarks.curatedPlaces.length} ${_isRtl ? 'شوێن' : 'places'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ...KalarLandmarks.curatedPlaces
                  .where((p) => currentCategory == 'all' || p.iconKey == currentCategory)
                  .map((place) => _buildPlaceItem(place)),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationAndWeatherHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAB308).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: Color(0xFFB45309), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: _isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  _isRtl ? 'کەلار، گەرمیان' : 'Kalar, Garmian',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currentLocationAddress ?? (_isRtl ? 'هەرێمی کوردستان، عێراق' : 'Kurdistan Region, Iraq'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Weather widget placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 16),
                SizedBox(width: 4),
                Text(
                  '28°C',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryShortcuts() {
    final categories = [
      {'key': 'all', 'labelKu': 'هەموو', 'labelAr': 'الكل', 'labelEn': 'All', 'icon': Icons.apps_rounded},
      {'key': 'hospital', 'labelKu': 'نەخۆشخانە', 'labelAr': 'مستشفيات', 'labelEn': 'Hospitals', 'icon': Icons.local_hospital_rounded},
      {'key': 'market', 'labelKu': 'بازاڕ', 'labelAr': 'أسواق', 'labelEn': 'Markets', 'icon': Icons.storefront_rounded},
      {'key': 'school', 'labelKu': 'قوتابخانە', 'labelAr': 'مدارس', 'labelEn': 'Schools', 'icon': Icons.school_rounded},
      {'key': 'park', 'labelKu': 'باخچە', 'labelAr': 'حدائق', 'labelEn': 'Parks', 'icon': Icons.park_rounded},
      {'key': 'general', 'labelKu': 'ڕێگاکان', 'labelAr': 'طرق', 'labelEn': 'Roads', 'icon': Icons.alt_route_rounded},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final key = cat['key'] as String;
          final isSelected = currentCategory == key;

          String label = cat['labelKu'] as String;
          if (language == 'العربية' || language == 'ar') label = cat['labelAr'] as String;
          if (language == 'English' || language == 'en') label = cat['labelEn'] as String;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              cat['icon'] as IconData,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            backgroundColor: const Color(0xFFF1F5F9),
            selectedColor: const Color(0xFFD97706),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
              ),
            ),
            onSelected: (_) => onCategoryFilterSelected(key),
          );
        },
      ),
    );
  }

  Widget _buildSelectedPlaceCard(BuildContext context, MapPlace place) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: _isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Expanded(
                child: Text(
                  place.localizedName(language),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (place.rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${place.rating}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            place.localizedAddress(language) ?? place.localizedCategory(language),
            textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          if (place.openHours != null) ...[
            const SizedBox(height: 4),
            Row(
              textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 6),
                Text(
                  place.openHours!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onDirectionsTapped,
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: Text(
                _isRtl ? 'ڕێنوێنی و گەیشتن' : 'Directions',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceItem(MapPlace place) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: () => onPlaceTapped(place),
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Icon(_categoryIcon(place.iconKey), color: const Color(0xFFD97706), size: 20),
        ),
        title: Text(
          place.localizedName(language),
          textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          place.localizedAddress(language) ?? place.localizedCategory(language),
          textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
      ),
    );
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'market':
        return Icons.storefront_rounded;
      case 'park':
        return Icons.park_rounded;
      default:
        return Icons.place_rounded;
    }
  }
}
