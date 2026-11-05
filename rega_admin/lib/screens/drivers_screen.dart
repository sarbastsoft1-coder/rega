import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DriversScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const DriversScreen({super.key, required this.api, required this.lang});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final _searchCtrl = TextEditingController();
  bool? _verifiedFilter;
  bool _loading = true;
  String? _error;
  List<dynamic> _drivers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.getDrivers(
        search: _searchCtrl.text.trim(),
        isVerified: _verifiedFilter,
      );
      if (mounted) setState(() => _drivers = list);
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
        content: Text(msg),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  String _docLabel(String type) {
    switch (type) {
      case 'national_id':
        return 'کارتی نیشتمانی';
      case 'driver_license':
        return 'مۆڵەتی شۆفێری';
      case 'vehicle_registration':
        return 'ساڵانەی ماتۆڕ';
      default:
        return type;
    }
  }

  void _showVerifyDocDialog(Map<String, dynamic> doc, String driverName) {
    final reasonCtrl = TextEditingController(text: doc['rejection_reason']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('پشکنینی ${_docLabel(doc['doc_type']?.toString() ?? '')} — $driverName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ژمارەی بەڵگەنامە: ${doc['document_number'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('بارودۆخی ئێستا: '),
                StatusBadge(status: doc['status']?.toString() ?? 'pending', lang: widget.lang),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'هۆکاری ڕەتکردنەوە (تەنها لە کاتی ڕەتکردنەوە)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('داخستن')),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.api.verifyDriverDocument(doc['id'] as int, 'rejected', reason: reasonCtrl.text.trim());
              _showSnack('بەڵگەنامە ڕەتکرایەوە', error: true);
              _load();
            },
            icon: const Icon(Icons.close_rounded, color: RegaColors.crimson),
            label: const Text('ڕەتکردنەوە', style: TextStyle(color: RegaColors.crimson)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.api.verifyDriverDocument(doc['id'] as int, 'verified');
              _showSnack('بەڵگەنامە بە سەرکەوتوویی پشتڕاستکرایەوە ✅');
              _load();
            },
            icon: const Icon(Icons.verified_rounded),
            label: const Text('پشتڕاستکردنەوە (Verify)'),
          ),
        ],
      ),
    );
  }

  void _showDriverFormDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final u = existing?['user'] as Map<String, dynamic>? ?? {};
    final nameCtrl = TextEditingController(text: u['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: u['phone']?.toString() ?? '');
    final passCtrl = TextEditingController(text: isEdit ? '' : 'password123');
    final motorCtrl = TextEditingController(text: existing?['motor_type']?.toString() ?? 'هۆندا CBR 150R');
    final plateCtrl = TextEditingController(text: existing?['plate_number']?.toString() ?? '');
    final yearCtrl = TextEditingController(text: existing?['model_year']?.toString() ?? '2024');
    final colorCtrl = TextEditingController(text: existing?['motor_color']?.toString() ?? 'ڕەش و سەوز');
    bool verifiedNow = existing?['is_verified'] ?? true;
    bool onlineNow = existing?['is_online'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'دەستکاریکردنی زانیاری شۆفێر (${existing['driver_code']})' : 'تۆمارکردنی شۆفێری نوێ لە سیستەمی REGA'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'ناوی سیانی شۆفێر *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'ژمارەی مۆبایل *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: isEdit ? 'وشەی نهێنی نوێ (ئارەزوومەندانە)' : 'وشەی نهێنی *',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: motorCtrl,
                    decoration: const InputDecoration(labelText: 'جۆر و مۆدێلی ماتۆڕسکیل *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: plateCtrl,
                          decoration: const InputDecoration(labelText: 'ژمارەی تابلۆ (Plate) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: yearCtrl,
                          decoration: const InputDecoration(labelText: 'ساڵی دروستکردن'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: colorCtrl,
                    decoration: const InputDecoration(labelText: 'ڕەنگی ماتۆڕ'),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: verifiedNow,
                    onChanged: (v) => setDialogState(() => verifiedNow = v ?? false),
                    title: const Text('پشتڕاستکردنی یاسایی KYC'),
                  ),
                  if (isEdit)
                    CheckboxListTile(
                      value: onlineNow,
                      onChanged: (v) => setDialogState(() => onlineNow = v ?? false),
                      title: const Text('دۆخی ئۆنلاین / ئۆفلاین'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || plateCtrl.text.trim().isEmpty) {
                  _showSnack('تکایە ناو، مۆبایل و تابلۆی ماتۆڕ پڕبکەرەوە', error: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final payload = <String, dynamic>{
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'motor_type': motorCtrl.text.trim(),
                    'plate_number': plateCtrl.text.trim(),
                    'model_year': yearCtrl.text.trim(),
                    'motor_color': colorCtrl.text.trim(),
                    'is_verified': verifiedNow,
                  };
                  if (passCtrl.text.trim().isNotEmpty) {
                    payload['password'] = passCtrl.text.trim();
                  }
                  if (isEdit) {
                    payload['is_online'] = onlineNow;
                    await widget.api.updateDriver(existing['id'] as int, payload);
                    _showSnack('زانیاری شۆفێر نوێکرایەوە ✅');
                  } else {
                    await widget.api.createDriver(payload);
                    _showSnack('شۆفێری نوێ بە سەرکەوتوویی تۆمارکرا ✅');
                  }
                  _load();
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: Text(AppStrings.tr('save', widget.lang)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
          child: SectionHeader(
            title: AppStrings.tr('nav_drivers', widget.lang),
            subtitle: 'بەڕێوەبردنی ماتۆڕسوارەکان، پشکنینی ٣ بەڵگەنامە یاساییەکە (KYC) و پارەی کاشی کۆکراوە',
            trailing: ElevatedButton.icon(
              onPressed: () => _showDriverFormDialog(),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('تۆمارکردنی شۆفێری نوێ'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(),
                  decoration: const InputDecoration(
                    hintText: 'گەڕان بە ناو، کۆدی RA، یان تابلۆ...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                ),
              ),
              ChoiceChip(
                selected: _verifiedFilter == null,
                label: const Text('هەمووی'),
                onSelected: (_) {
                  setState(() => _verifiedFilter = null);
                  _load();
                },
              ),
              ChoiceChip(
                selected: _verifiedFilter == true,
                label: const Text('پشتڕاستکراوەکان ✅'),
                onSelected: (_) {
                  setState(() => _verifiedFilter = true);
                  _load();
                },
              ),
              ChoiceChip(
                selected: _verifiedFilter == false,
                label: const Text('چاوەڕوانی KYC ⏳'),
                onSelected: (_) {
                  setState(() => _verifiedFilter = false);
                  _load();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                      itemCount: _drivers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, idx) {
                        final dp = _drivers[idx] as Map<String, dynamic>;
                        final u = dp['user'] as Map<String, dynamic>? ?? {};
                        final docs = dp['documents'] as List<dynamic>? ?? [];
                        final verified = dp['is_verified'] == true;
                        final online = dp['is_online'] == true;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: (online ? RegaColors.emerald : Colors.grey).withValues(alpha: 0.16),
                                          child: Icon(
                                            Icons.two_wheeler_rounded,
                                            color: online ? RegaColors.emeraldDark : Colors.grey,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  u['name']?.toString() ?? '',
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: RegaColors.gold,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    dp['driver_code']?.toString() ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w900,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                StatusBadge(
                                                  status: verified ? 'verified' : 'pending',
                                                  lang: widget.lang,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '📞 ${u['phone'] ?? ''}  •  🏍️ ${dp['motor_type'] ?? ''} (${dp['plate_number'] ?? ''} - ${dp['motor_color'] ?? ''})',
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      spacing: 14,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'کاشی لای شۆفێر (COD): ${formatIqd(dp['cash_collected_hand'] as num?, lang: widget.lang)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: RegaColors.purple,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'شایستەی شۆفێر: ${formatIqd(dp['wallet_balance'] as num?, lang: widget.lang)}  •  📦 ${dp['total_deliveries'] ?? 0} گەیاندن',
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        FilterChip(
                                          selected: online,
                                          selectedColor: RegaColors.emerald.withValues(alpha: 0.2),
                                          label: Text(online ? 'ئۆنلاین' : 'ئۆفلاین'),
                                          onSelected: (_) async {
                                            await widget.api.toggleDriverField(dp['id'] as int, 'is_online');
                                            _load();
                                          },
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _showDriverFormDialog(existing: dp),
                                          icon: const Icon(Icons.edit_rounded, size: 16),
                                          label: const Text('دەستکاریکردن'),
                                        ),
                                        if (!verified)
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              await widget.api.toggleDriverField(dp['id'] as int, 'is_verified');
                                              _showSnack('شۆفێر و سەرجەم بەڵگەنامەکانی پەسەندکران ✅');
                                              _load();
                                            },
                                            icon: const Icon(Icons.verified_user_rounded, size: 16),
                                            label: const Text('پەسەندکردنی گشتی'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 22),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'بەڵگەنامە یاساییەکان (گرتە بکە بۆ پشکنین):',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                    ...docs.map((rawDoc) {
                                      final d = rawDoc as Map<String, dynamic>;
                                      final st = d['status']?.toString() ?? 'pending';
                                      final c = StatusBadge.colorFor(st);
                                      return ActionChip(
                                        avatar: Icon(
                                          st == 'verified'
                                              ? Icons.check_circle_rounded
                                              : (st == 'rejected' ? Icons.cancel_rounded : Icons.pending_rounded),
                                          size: 16,
                                          color: c,
                                        ),
                                        label: Text(
                                          '${_docLabel(d['doc_type']?.toString() ?? '')} (${AppStrings.statusLabel(st, widget.lang)})',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c),
                                        ),
                                        onPressed: () => _showVerifyDocDialog(d, u['name']?.toString() ?? ''),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

