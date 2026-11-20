import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/services/open_url_io.dart'
    if (dart.library.html) '../core/services/open_url_web.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../rega_colors.dart';
import '../rega_i18n.dart';
import '../widgets/common_widgets.dart';

/// Admin inbox for customer داواکاری ڕاستەوخۆ (SupportTicket category=direct_request).
class DirectRequestsScreen extends StatefulWidget {
  const DirectRequestsScreen({
    super.key,
    required this.api,
    required this.lang,
    this.onChanged,
  });

  final ApiClient api;
  final String lang;
  final VoidCallback? onChanged;

  @override
  State<DirectRequestsScreen> createState() => _DirectRequestsScreenState();
}

class _DirectRequestsScreenState extends State<DirectRequestsScreen> {
  bool _loading = true;
  String? _error;
  String _statusFilter = 'open';
  List<Map<String, dynamic>> _tickets = [];
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final raw = await widget.api.getTickets(
        status: _statusFilter,
        category: 'direct_request',
      );
      if (!mounted) return;
      setState(() {
        _tickets = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e.toString());
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
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

  Map<String, dynamic> _parsed(Map<String, dynamic> t) {
    final nested = t['direct_request'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return {
      'address': t['address'],
      'phone': t['request_phone'] ?? t['phone'],
      'notes': t['notes'],
      'image_url': t['image_url'],
    };
  }

  String? _imageUrlOf(Map<String, dynamic> t) {
    final p = _parsed(t);
    final raw = (p['image_url'] ?? t['image_url'])?.toString();
    final resolved = widget.api.resolveMediaUrl(raw);
    return resolved.isEmpty ? null : resolved;
  }

  void _openImage(String? url) {
    final resolved = widget.api.resolveMediaUrl(url);
    if (resolved.isEmpty) {
      _showSnack('هیچ وێنەیەک نییە', error: true);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx('وێنەی داواکاری'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      tooltip: tx('کردنەوە لە تابێکی نوێ'),
                      onPressed: () {
                        try {
                          openExternalUrl(resolved);
                        } catch (_) {
                          _showSnack('نەتوانرا فایل بکرێتەوە', error: true);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      resolved,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(tx('نەتوانرا وێنە باربکرێت')),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(Map<String, dynamic> ticket) async {
    final id = (ticket['id'] as num?)?.toInt();
    if (id == null || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await widget.api.updateTicket(id, {
        'status': 'in_progress',
        'admin_reply': 'داواکاری قبوڵکرا',
      });
      _showSnack('داواکاری قبوڵکرا');
      widget.onChanged?.call();
      await _load(silent: true);
    } catch (e) {
      _showSnack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _resolve(Map<String, dynamic> ticket) async {
    final id = (ticket['id'] as num?)?.toInt();
    if (id == null || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await widget.api.updateTicket(id, {
        'status': 'resolved',
        'admin_reply': ticket['admin_reply']?.toString().isNotEmpty == true
            ? ticket['admin_reply']
            : 'داواکاری تەواوکرا',
      });
      _showSnack('داواکاری تەواوکرا');
      widget.onChanged?.call();
      await _load(silent: true);
    } catch (e) {
      _showSnack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  void _showDetails(Map<String, dynamic> ticket) {
    final parsed = _parsed(ticket);
    final user = ticket['user'] is Map
        ? Map<String, dynamic>.from(ticket['user'] as Map)
        : <String, dynamic>{};
    final imageUrl = _imageUrlOf(ticket);
    final phone = (parsed['phone'] ?? user['phone'] ?? '').toString();
    final status = ticket['status']?.toString() ?? 'open';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tx(ticket['subject']?.toString() ?? 'داواکاری ڕاستەوخۆ'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            StatusBadge(status: status, lang: widget.lang),
          ],
        ),
        content: SizedBox(
          width: AdminBreakpoints.dialogWidth(ctx, max: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tx('${ticket['ticket_number'] ?? ''}  •  ${ticket['created_at'] ?? ''}'),
                  style: TextStyle(
                    fontSize: 12,
                    color: RC.fg(Colors.grey.shade600),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _detailRow(tx('کڕیار'), '${user['name'] ?? '-'}'),
                _detailRow(
                  tx('ژمارەی مۆبایل'),
                  IraqPhoneFormatter.display(phone.isEmpty ? '-' : phone),
                ),
                _detailRow(tx('ناونیشانی داواکاری'), (parsed['address'] ?? '-').toString()),
                _detailRow(tx('تێبینی بابەت'), (parsed['notes'] ?? '-').toString()),
                if (imageUrl != null) ...[
                  const SizedBox(height: 12),
                  Text(tx('وێنەی بابەت'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _openImage(imageUrl),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: AdminSurfaces.of(context).chipFill,
                            child: Center(child: Text(tx('نەتوانرا وێنە باربکرێت'))),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _openImage(imageUrl),
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: Text(tx('کردنەوەی وێنە')),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('داخستن'))),
          if (status == 'open')
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _accept(ticket);
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(tx('قبوڵکردن')),
            ),
          if (status == 'in_progress')
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _resolve(ticket);
              },
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(tx('تەواوکردن')),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: RC.fg(Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AdminBreakpoints.pagePadH(context),
            8,
            AdminBreakpoints.pagePadH(context),
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in const [
                      ('open', 'کراوە'),
                      ('in_progress', 'لە کاردایە'),
                      ('resolved', 'چارەسەرکرا'),
                      ('all', 'هەموو'),
                    ])
                      ChoiceChip(
                        label: Text(tx(f.$2)),
                        selected: _statusFilter == f.$1,
                        onSelected: (_) {
                          setState(() => _statusFilter = f.$1);
                          _load();
                        },
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tx('نوێکردنەوە'),
                onPressed: () => _load(),
                icon: const Icon(Icons.sync_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : _tickets.isEmpty
                      ? Center(
                          child: Text(
                            tx('هیچ داواکاری ڕاستەوخۆیەک نییە'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: RC.fg(Colors.grey.shade600),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            AdminBreakpoints.pagePadH(context),
                            4,
                            AdminBreakpoints.pagePadH(context),
                            24,
                          ),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _buildCard(_tickets[i]),
                        ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> ticket) {
    final parsed = _parsed(ticket);
    final user = ticket['user'] is Map
        ? Map<String, dynamic>.from(ticket['user'] as Map)
        : <String, dynamic>{};
    final status = ticket['status']?.toString() ?? 'open';
    final id = (ticket['id'] as num?)?.toInt();
    final busy = id != null && _busyIds.contains(id);
    final imageUrl = _imageUrlOf(ticket);
    final phone = (parsed['phone'] ?? user['phone'] ?? '').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tx(ticket['subject']?.toString() ?? '-'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                StatusBadge(status: status, lang: widget.lang),
                Text(
                  tx(ticket['ticket_number']?.toString() ?? ''),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RC.fg(Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tx('👤 ${user['name'] ?? '-'}  •  📞 ${IraqPhoneFormatter.display(phone.isEmpty ? '-' : phone)}'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tx('📍 ${parsed['address'] ?? '-'}'),
              style: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade700)),
            ),
            if ((parsed['notes']?.toString() ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tx('📝 ${parsed['notes']}'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: RC.fg(Colors.grey.shade700)),
              ),
            ],
            if (imageUrl != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openImage(imageUrl),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: AdminSurfaces.of(context).chipFill,
                        child: Center(child: Text(tx('نەتوانرا وێنە باربکرێت'))),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDetails(ticket),
                  icon: const Icon(Icons.visibility_rounded, size: 17),
                  label: Text(tx('وردەکاری')),
                ),
                if (imageUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _openImage(imageUrl),
                    icon: const Icon(Icons.image_rounded, size: 17),
                    label: Text(tx('کردنەوەی وێنە')),
                  ),
                if (status == 'open')
                  FilledButton.icon(
                    onPressed: busy ? null : () => _accept(ticket),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 17),
                    label: Text(tx('قبوڵکردن')),
                  ),
                if (status == 'in_progress')
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => _resolve(ticket),
                    icon: const Icon(Icons.done_all_rounded, size: 17),
                    label: Text(tx('تەواوکردن')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
