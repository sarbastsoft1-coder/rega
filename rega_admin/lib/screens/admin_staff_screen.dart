import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/admin_top_header.dart';
import '../widgets/bulk_delete_bar.dart';
import '../rega_i18n.dart';
import '../rega_colors.dart';
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
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  bool _bulkBusy = false;

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
        _selectedIds.removeWhere(
          (id) => !_staff.any((s) => s['id'] == id),
        );
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
        content: Text(tx(msg)),
        backgroundColor: error ? RC.bg(Color(0xFFDC2626)) : RC.bg(Color(0xFF16A34A)),
      ),
    );
  }

  List<int> get _staffIds => _staff.map((s) => s['id']).whereType<int>().toList();

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllStaff() {
    setState(() => _selectedIds
      ..clear()
      ..addAll(_staffIds));
  }

  void _toggleStaffSelected(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDeleteStaff({required bool deleteAll}) async {
    final ids = deleteAll ? _staffIds : _selectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await BulkDeleteActions.confirm(
      context: context,
      lang: widget.lang,
      count: ids.length,
      deleteAll: deleteAll,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    final result = await BulkDeleteActions.run(
      ids: ids,
      deleteOne: widget.api.deleteAdminStaff,
    );
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectionMode = false;
      _selectedIds.clear();
    });
    _snack(
      BulkDeleteActions.resultMessage(widget.lang, result),
      error: result.failed > 0 && result.ok == 0,
    );
    await _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> staff) async {
    final id = staff['id'] as int;
    final name = staff['name']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tx('سڕینەوەی ئەدمین؟'), style: TextStyle(fontWeight: FontWeight.w900)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 420),
            maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 280),
          ),
          child: SingleChildScrollView(
            child: Text(tx('دڵنیایت دەتەوێت هەژماری «$name» بسڕیتەوە؟ ئەم کارە ناگەڕێتەوە.')),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx('پاشگەزبوونەوە'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.crimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tx('سڕینەوە')),
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
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            tx(isEdit ? 'دەستکاریکردنی ئەدمین' : 'دروستکردنی هەژماری ئەدمین'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 440),
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 520),
            ),
            child: SizedBox(
              width: AdminBreakpoints.dialogWidth(ctx, max: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: tx('ناو *'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      inputFormatters: [IraqPhoneFormatter()],
                      decoration: InputDecoration(
                        labelText: tx('مۆبایل *'),
                        hintText: tx('0750 000 0000'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: tx('ئیمەیڵ *'),
                        hintText: tx('admin@example.com'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: txn(isEdit ? 'وشەی نهێنی نوێ (ئارەزوومەندانە)' : 'وشەی نهێنی *'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                          icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: tx('ڕۆڵ'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        tx('ئەدمین'),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      title: Text(tx('چالاک'), style: TextStyle(fontWeight: FontWeight.w700)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(tx('پاشگەزبوونەوە')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFEA580C)),
                foregroundColor: RC.fg(Colors.white),
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
              child: Text(tx(isEdit ? 'پاشەکەوتکردن' : 'دروستکردن')),
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
        ? RC.bg(Color(0xFF94A3B8))
        : RC.bg(Color(0xFF64748B));
    final cardBg = Theme.of(context).cardColor;
    final padH = AdminBreakpoints.pagePadH(context);

    return Directionality(
      textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final phone = constraints.maxWidth < AdminBreakpoints.phone;
            final narrow = constraints.maxWidth < 800;

            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx('هەژمارەکانی ئەدمین'),
                  style: TextStyle(
                    fontSize: phone ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx('دروستکردن و دەستکاریکردنی هەژماری ئەدمین — چوونە ژوورەوە بە ئیمەیڵ و وشەی نهێنی'),
                  style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600),
                ),
              ],
            );

            final topActions = AdminTopBarRow(
              searchCtrl: _searchCtrl,
              hintText: tx('گەڕان...'),
              onSearchChanged: (_) {},
            );

            final headerRow = narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(alignment: AlignmentDirectional.centerEnd, child: topActions),
                      const SizedBox(height: 10),
                      title,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      Flexible(child: topActions),
                    ],
                  );

            final toolbar = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BulkDeleteBar(
                  lang: widget.lang,
                  selectionMode: _selectionMode,
                  selectedCount: _selectedIds.length,
                  totalCount: _staff.length,
                  busy: _bulkBusy,
                  onToggleSelectionMode: _toggleSelectionMode,
                  onSelectAll: _selectAllStaff,
                  onClearSelection: _clearSelection,
                  onDeleteSelected: () => _bulkDeleteStaff(deleteAll: false),
                  onDeleteAll: () => _bulkDeleteStaff(deleteAll: true),
                  extraActions: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFFEA580C)),
                        foregroundColor: RC.fg(Colors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _bulkBusy ? null : () => _showEditor(),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(tx('دروستکردنی ئەدمین'), style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: phone ? constraints.maxWidth - padH * 2 : 280,
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: tx('گەڕان بە ناو، مۆبایل یان ئیمەیڵ...'),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            );

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padH, 16, padH, 14),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            headerRow,
                            const SizedBox(height: 14),
                            toolbar,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(color: RC.bg(Color(0xFFEA580C)))),
                  )
                else if (_staff.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: padH, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_off_rounded, size: 48, color: muted),
                            const SizedBox(height: 10),
                            Text(
                              tx('هیچ هەژماری ئەدمین نییە'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: onSurface),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RC.bg(Color(0xFFEA580C)),
                                foregroundColor: RC.fg(Colors.white),
                              ),
                              onPressed: () => _showEditor(),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(tx('دروستکردنی یەکەم ئەدمین')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padH, 0, padH, 24),
                    sliver: SliverList.separated(
                      itemCount: _staff.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final staff = _staff[i];
                        final id = staff['id'] as int;
                        final active = staff['is_active'] != false;
                        final email = staff['email']?.toString();
                        final selected = _selectedIds.contains(id);
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1080),
                            child: Material(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: _selectionMode ? () => _toggleStaffSelected(id) : null,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? RegaColors.orange
                                      : (Theme.of(context).brightness == Brightness.dark
                                          ? RC.bg(Color(0xFF334155))
                                          : RC.bg(Color(0xFFE2E8F0))),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, rowC) {
                                  final rowPhone = rowC.maxWidth < 520;
                                  final avatarCol = Row(
                                    crossAxisAlignment: rowPhone ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                    children: [
                                      if (_selectionMode)
                                        Padding(
                                          padding: const EdgeInsetsDirectional.only(end: 8),
                                          child: BulkSelectBadge(
                                            selected: selected,
                                            onChanged: (_) => _toggleStaffSelected(id),
                                          ),
                                        ),
                                      CircleAvatar(
                                        backgroundColor: RC.bg(Color(0xFFFFEDD5)),
                                        child: Icon(
                                          Icons.admin_panel_settings_rounded,
                                          color: active ? RC.fg(Color(0xFFEA580C)) : RC.bg(Color(0xFF94A3B8)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx(staff['name']?.toString() ?? ''),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                                color: onSurface,
                                              ),
                                            ),
                                            Text(
                                              tx('${staff['phone'] ?? ''} • ئەدمین'
                                              '${email != null && email.isNotEmpty ? ' • $email' : ''}'),
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
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: active ? RC.bg(Color(0xFFDCFCE7)) : RC.bg(Color(0xFFFEE2E2)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          tx(active ? 'چالاک' : 'ناچالاک'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: active ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFDC2626)),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: tx('دەستکاری'),
                                        onPressed: () => _showEditor(existing: staff),
                                        icon: const Icon(Icons.edit_rounded),
                                      ),
                                      IconButton(
                                        tooltip: txn(active ? 'ناچالاککردن' : 'چالاککردن'),
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
                                          color: active ? RC.fg(Color(0xFF16A34A)) : RC.bg(Color(0xFF94A3B8)),
                                          size: 32,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: tx('سڕینەوە'),
                                        onPressed: () => _confirmDelete(staff),
                                        icon: Icon(Icons.delete_forever_rounded, color: RC.fg(Color(0xFFDC2626))),
                                      ),
                                    ],
                                  );
                                  if (rowPhone) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        avatarCol,
                                        const SizedBox(height: 10),
                                        Align(alignment: AlignmentDirectional.centerEnd, child: actions),
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(child: avatarCol),
                                      const SizedBox(width: 8),
                                      actions,
                                    ],
                                  );
                                },
                              ),
                            ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
