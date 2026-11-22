import 'package:flutter/material.dart';
import '../models/map_place.dart';

class MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;
  final VoidCallback? onBackTap;
  final String language;
  final List<MapPlace> searchResults;
  final ValueChanged<MapPlace> onSelectPlace;

  const MapSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onFilterTap,
    this.onBackTap,
    this.language = 'Kurdish',
    this.searchResults = const [],
    required this.onSelectPlace,
  });

  bool get _isRtl => language != 'English';

  String get _placeholder {
    if (language == 'العربية' || language == 'ar') return 'ابحث عن مكان، شارع، أو حي في كلار...';
    if (language == 'English' || language == 'en') return 'Search places, streets, or quarters in Kalar...';
    return 'گەڕان لە کەلار (نەخۆشخانە، قوتابخانە، بازاڕ، گەڕەک)...';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              if (onBackTap != null)
                IconButton(
                  icon: Icon(_isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, color: const Color(0xFF334155)),
                  onPressed: onBackTap,
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 24),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: _placeholder,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 20),
                  onPressed: onClear,
                ),
              Container(
                height: 24,
                width: 1,
                color: const Color(0xFFE2E8F0),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Color(0xFFB45309), size: 22),
                tooltip: _isRtl ? 'فلتەر' : 'Filter',
                onPressed: onFilterTap,
              ),
            ],
          ),
        ),

        // Live drop-down search suggestions
        if (searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final place = searchResults[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_categoryIcon(place.iconKey), color: const Color(0xFFD97706), size: 18),
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
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () => onSelectPlace(place),
                );
              },
            ),
          ),
      ],
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
