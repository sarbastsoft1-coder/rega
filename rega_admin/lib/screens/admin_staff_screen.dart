import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/theme/admin_breakpoints.dart';
import '../widgets/admin_top_header.dart';
/// Dedicated page to create / edit / deactivate admin accounts.
/// Single role only: `admin` (ئەدمین).
class AdminStaffScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const AdminStaffScreen({
    super.key,
    required this.api,
    required this.lang,
  });

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

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
    setState(() => _loading = true);
    try {
      final list = await widget.api.getAdminStaff(
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        role: 'admin',
      );
      if (!mounted) return;
      setState(() {
        _staff = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString(), error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> staff) async {
    final id = staff['id'] as int;
    final name = staff['name']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('سڕینەوەی ئەدمین؟', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('دڵنیایت دەتەوێت هەژماری «$name» بسڕیتەوە؟ ئەم کارە ناگەڕێتەوە.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('پاشگەزبوونەوە')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('سڕینەوە'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteAdminStaff(id);
      await _load();
      _snack('هەژماری ئەدمین سڕایەوە ✅');
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  void _showEditor({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final passwordCtrl = TextEditingController();
    bool isActive = existing?['is_active'] != false;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isEdit ? 'دەستکاریکردنی ئەدمین' : 'دروستکردنی هەژماری ئەدمین',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: SizedBox(
            width: AdminBreakpoints.dialogWidth(ctx, max: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'ناو *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.left,
                      inputFormatters: [IraqPhoneFormatter()],
                      decoration: InputDecoration(
                        labelText: 'مۆبایل *',
                        hintText: '0750 000 0000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'ئیمەیڵ *',
                      hintText: 'admin@example.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEdit ? 'وشەی نهێنی نوێ (ئارەزوومەندانە)' : 'وشەی نهێنی *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'ڕۆڵ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'ئەدمین',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    title: const Text('چالاک', style: TextStyle(fontWeight: FontWeight.w700)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pass = passwordCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        _snack('ناو و مۆبایل پێویستن', error: true);
                        return;
                      }
                      if (email.isEmpty || !email.contains('@')) {
                        _snack('ئیمەیڵ پێویستە بۆ چوونە ژوورەوە', error: true);
                        return;
                      }
                      if (!isEdit && pass.isEmpty) {
                        _snack('وشەی نهێنی پێویستە', error: true);
                        return;
                      }
                      if (!isEdit && pass.length < 6) {
                        _snack('وشەی نهێنی لانیکەم ٦ پیت بێت', error: true);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final payload = <String, dynamic>{
                          'name': name,
                          'phone': phone,
                          'email': email,
                          'role': 'admin',
                          'is_active': isActive,
                          if (pass.isNotEmpty) 'password': pass,
                        };
                        if (isEdit) {
                          await widget.api.updateAdminStaff(existing['id'] as int, payload);
                        } else {
                          await widget.api.createAdminStaff(payload);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        _snack(
                          isEdit
                              ? 'ئەدمین نوێکرایەوە ✅'
                              : 'هەژماری ئەدمین دروستکرا — دەتوانیت بە ئیمەیڵ و وشەی نهێنی بچیتە ژوورەوە ✅',
                        );
                      } catch (e) {
                        setDialogState(() => saving = false);
                        _snack(e.toString(), error: true);
                      }
                    },
              child: Text(isEdit ? 'پاشەکەوتکردن' : 'دروستکردن'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final cardBg = Theme.of(context).cardColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: AdminBreakpoints.pagePadH(context), vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < AdminBreakpoints.headerCompact;
                  final phone = constraints.maxWidth < AdminBreakpoints.phone;
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'هەژمارەکانی ئەدمین',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'دروستکردن و دەستکاریکردنی هەژماری ئەدمین — چوونە ژوورەوە بە ئیمەیڵ و وشەی نهێنی',
                        style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: phone ? constraints.maxWidth : 220,
                        child: TextField(
                          controller: _searchCtrl,
                          onSubmitted: (_) => _load(),
                          decoration: InputDecoration(
                            hintText: 'گەڕان بە ناو، مۆبایل یان ئیمەیڵ...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () => _showEditor(),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('دروستکردنی ئەدمین', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      if (phone)
                        AdminTopBarRow(
                          searchCtrl: _searchCtrl,
                          hintText: 'گەڕان...',
                          onSearchChanged: (_) {},
                        )
                      else if (!narrow)
                        AdminTopBarRow(
                          searchCtrl: _searchCtrl,
                          hintText: 'گەڕان...',
                          onSearchChanged: (_) {},
                        ),
                    ],
                  );
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [title, const SizedBox(height: 12), actions],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      actions,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
                    : _staff.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group_off_rounded, size: 48, color: muted),
                                const SizedBox(height: 10),
                                Text(
                                  'هیچ هەژماری ئەدمین نییە',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: onSurface),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEA580C),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _showEditor(),
                                  icon: const Icon(Icons.person_add_alt_1_rounded),
                                  label: const Text('دروستکردنی یەکەم ئەدمین'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _staff.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final staff = _staff[i];
                              final id = staff['id'] as int;
                              final active = staff['is_active'] != false;
                              final email = staff['email']?.toString();
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, rowC) {
                                    final rowPhone = rowC.maxWidth < 420;
                                    final avatarCol = Row(
                                      crossAxisAlignment: rowPhone ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(0xFFFFEDD5),
                                          child: Icon(
                                            Icons.admin_panel_settings_rounded,
                                            color: active ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                staff['name']?.toString() ?? '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  color: onSurface,
                                                ),
                                              ),
                                              Text(
                                                '${staff['phone'] ?? ''} • ئەدمین'
                                                '${email != null && email.isNotEmpty ? ' • $email' : ''}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: muted,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                    final actions = Wrap(
                                      spacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: active ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            active ? 'چالاک' : 'ناچالاک',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: active ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'دەستکاری',
                                          onPressed: () => _showEditor(existing: staff),
                                          icon: const Icon(Icons.edit_rounded),
                                        ),
                                        IconButton(
                                          tooltip: active ? 'ناچالاککردن' : 'چالاککردن',
                                          onPressed: () async {
                                            try {
                                              await widget.api.toggleAdminStaffActive(id);
                                              await _load();
                                              _snack('دۆخی هەژمار نوێکرایەوە');
                                            } catch (e) {
                                              _snack(e.toString(), error: true);
                                            }
                                          },
                                          icon: Icon(
                                            active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                            color: active ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                            size: 32,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'سڕینەوە',
                                          onPressed: () => _confirmDelete(staff),
                                          icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
                                        ),
                                      ],
                                    );
                                    if (rowPhone) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          avatarCol,
                                          const SizedBox(height: 10),
                                          actions,
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(child: avatarCol),
                                        actions,
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
