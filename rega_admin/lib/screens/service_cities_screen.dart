import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../rega_i18n.dart';
import '../rega_colors.dart';

/// Admin CRUD for multi-city work locations (کەلار، هەولێر، …).
class ServiceCitiesScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const ServiceCitiesScreen({super.key, required this.api, required this.lang});

  @override
  State<ServiceCitiesScreen> createState() => _ServiceCitiesScreenState();
}

class _ServiceCitiesScreenState extends State<ServiceCitiesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _cities = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.getServiceCities();
      if (!mounted) return;
      setState(() => _cities = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(msg)),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  void _showCityDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final kuCtrl = TextEditingController(text: existing?['name_ku']?.toString() ?? '');
    final arCtrl = TextEditingController(text: existing?['name_ar']?.toString() ?? '');
    final enCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final latCtrl = TextEditingController(
      text: (existing?['center_lat'] as num?)?.toString() ?? '34.6295',
    );
    final lngCtrl = TextEditingController(
      text: (existing?['center_lng'] as num?)?.toString() ?? '45.3159',
    );
    int radiusKm = (existing?['radius_km'] as num?)?.toInt() ?? 10;
    bool active = existing == null ? true : existing['is_active'] == true;
    final orderCtrl = TextEditingController(
      text: (existing?['sort_order'] ?? (_cities.length + 1)).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          title: Text(tx(isEdit ? 'دەستکاریکردنی شاری کار' : 'زیادکردنی شاری کار')),
          content: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 440),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 520),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: kuCtrl,
                      decoration: InputDecoration(labelText: tx('ناو (کوردی) *')),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: arCtrl,
                      decoration: InputDecoration(labelText: tx('ناو (عەرەبی)')),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: enCtrl,
                      decoration: InputDecoration(labelText: tx('ناو (ئینگلیزی)')),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: tx('ناوەند Lat')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: tx('ناوەند Lng')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(tx('مەودای GPS (کم)'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [5, 10, 15, 20].map((km) {
                        return ChoiceChip(
                          label: Text('$km'),
                          selected: radiusKm == km,
                          onSelected: (_) => setDialogState(() => radiusKm = km),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tx('ڕیزبەندی')),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tx('چالاک')),
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('هەڵوەشاندنەوە'))),
            ElevatedButton(
              onPressed: () async {
                if (kuCtrl.text.trim().isEmpty) return;
                final lat = double.tryParse(latCtrl.text.trim());
                final lng = double.tryParse(lngCtrl.text.trim());
                if (lat == null || lng == null) {
                  _showSnack('کۆئۆردیناتەکان هەڵەن', error: true);
                  return;
                }
                final payload = <String, dynamic>{
                  'name_ku': kuCtrl.text.trim(),
                  'name_ar': arCtrl.text.trim().isEmpty ? kuCtrl.text.trim() : arCtrl.text.trim(),
                  'name_en': enCtrl.text.trim().isEmpty ? kuCtrl.text.trim() : enCtrl.text.trim(),
                  'center_lat': lat,
                  'center_lng': lng,
                  'radius_km': radiusKm,
                  'is_active': active,
                  'sort_order': int.tryParse(orderCtrl.text.trim()) ?? (_cities.length + 1),
                };
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await widget.api.updateServiceCity(existing['id'] as int, payload);
                    _showSnack('شار نوێکرایەوە');
                  } else {
                    await widget.api.createServiceCity(payload);
                    _showSnack('شار زیادکرا');
                  }
                  _load();
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: Text(tx('پاشەکەوتکردن')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('سڕینەوەی شار؟')),
        content: Text(tx('${c['name_ku'] ?? ''} — تەنها ئەگەر گەڕەک/فرۆشگای نەبێت.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx('نەخێر'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: RegaColors.crimson),
            child: Text(tx('سڕینەوە')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteServiceCity(c['id'] as int);
      _showSnack('شار سڕایەوە');
      _load();
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padH = AdminBreakpoints.pagePadH(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padH, padH < 16 ? 10 : 18, padH, 6),
          child: SectionHeader(
            title: 'شارەکانی کار',
            subtitle: 'کەلار و أربيل (هەولێر) و شارەکانی تر — زیادکردن / دەستکاری / سڕینەوە + مەودای GPS',
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : ListView(
                      padding: EdgeInsets.all(padH),
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: RegaColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: RegaColors.gold.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            tx(
                              'لێرە شارەکانی خزمەتگوزاری زیاد بکە یان دەستکاری بکە (وەک کەلار و أربيل). '
                              'گەڕەکەکان لە تابـی «گەڕەکەکان» بەپێی هەر شارێک زیاد دەکرێن.',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.45),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: ElevatedButton.icon(
                            onPressed: () => _showCityDialog(),
                            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                            label: Text(tx('زیادکردنی شار')),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._cities.map((raw) {
                          final c = raw as Map<String, dynamic>;
                          final active = c['is_active'] == true;
                          final zones = c['neighborhoods_count'] ?? 0;
                          final stores = c['stores_count'] ?? 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: LayoutBuilder(
                              builder: (context, cardConstraints) {
                                final isCompactCard = cardConstraints.maxWidth < 430;
                                final leadingAvatar = CircleAvatar(
                                  backgroundColor: active
                                      ? RegaColors.emerald.withValues(alpha: 0.15)
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.location_city_rounded,
                                    color: active ? RegaColors.emeraldDark : Colors.grey,
                                  ),
                                );
                                final titleText = Text(
                                  tx(c['name_ku']?.toString() ?? ''),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                );
                                final subtitleText = Text(
                                  tx(
                                    '${c['name_en'] ?? ''} · ${c['radius_km'] ?? 10} کم · '
                                    'گەڕەک: $zones · فرۆشگا: $stores\n'
                                    '${c['center_lat']} , ${c['center_lng']}',
                                  ),
                                );
                                final actionsRow = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: active,
                                      onChanged: (v) async {
                                        try {
                                          await widget.api.updateServiceCity(
                                            c['id'] as int,
                                            {'is_active': v},
                                          );
                                          _load();
                                        } catch (e) {
                                          _showSnack(e.toString(), error: true);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      onPressed: () => _showCityDialog(existing: c),
                                      icon: const Icon(Icons.edit_outlined, color: RegaColors.blue),
                                    ),
                                    IconButton(
                                      onPressed: () => _confirmDelete(c),
                                      icon: const Icon(Icons.delete_outline, color: RegaColors.crimson),
                                    ),
                                  ],
                                );
                                if (isCompactCard) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            leadingAvatar,
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  titleText,
                                                  const SizedBox(height: 4),
                                                  subtitleText,
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Align(
                                          alignment: AlignmentDirectional.centerEnd,
                                          child: actionsRow,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return ListTile(
                                  leading: leadingAvatar,
                                  title: titleText,
                                  subtitle: subtitleText,
                                  isThreeLine: true,
                                  trailing: actionsRow,
                                );
                              },
                            ),
                          );
                        }),
                      ],
                    ),
        ),
      ],
    );
  }
}
