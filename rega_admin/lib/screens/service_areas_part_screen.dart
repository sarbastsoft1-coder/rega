import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/app_theme.dart';
import '../rega_colors.dart';
import '../rega_i18n.dart';
import 'catalog_zones_screen.dart';
import 'service_cities_screen.dart';

/// Top-level sidebar hub: work cities + neighborhoods/areas.
class ServiceAreasPartScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const ServiceAreasPartScreen({
    super.key,
    required this.api,
    required this.lang,
  });

  @override
  State<ServiceAreasPartScreen> createState() => _ServiceAreasPartScreenState();
}

class _ServiceAreasPartScreenState extends State<ServiceAreasPartScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: RC.bg(const Color(0xFF0F172A)),
          child: TabBar(
            controller: _tabs,
            indicatorColor: RegaColors.gold,
            indicatorWeight: 3.5,
            labelColor: RegaColors.gold,
            unselectedLabelColor: RC.fg(Colors.white70),
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            tabs: [
              Tab(text: tx('شارەکانی کار')),
              Tab(text: tx('گەڕەکەکان / ناوچەکان')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              ServiceCitiesScreen(api: widget.api, lang: widget.lang),
              CatalogZonesScreen(
                api: widget.api,
                lang: widget.lang,
                mode: CatalogZonesMode.zones,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
