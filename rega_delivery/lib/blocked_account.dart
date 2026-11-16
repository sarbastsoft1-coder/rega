import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'rega_mobile.dart';

import 'rega_i18n.dart';
import 'rega_colors.dart';
class AccountBlockedException implements Exception {
  final String message;
  final Map<String, dynamic> contact;

  AccountBlockedException({
    required this.message,
    Map<String, dynamic>? contact,
  }) : contact = contact ?? const {};

  factory AccountBlockedException.fromBody(Map<String, dynamic> body) {
    final contact = body['contact'];
    return AccountBlockedException(
      message: (body['message'] ??
              'هەژمارەکەت مسدود کراوە. تکایە پەیوەندی بە ئادمین بکە لە ڕێگەی واتسئاپ یان تێلێگرام.')
          .toString(),
      contact: contact is Map<String, dynamic>
          ? contact
          : (contact is Map ? Map<String, dynamic>.from(contact) : const {}),
    );
  }

  @override
  String toString() => message;
}

class BlockedAccountContacts {
  final String phone;
  final String whatsapp;
  final String telegramNumber;
  final String telegramUsername;
  final String message;

  const BlockedAccountContacts({
    required this.phone,
    required this.whatsapp,
    required this.telegramNumber,
    required this.telegramUsername,
    required this.message,
  });

  factory BlockedAccountContacts.fromException(AccountBlockedException e) {
    final c = e.contact;
    return BlockedAccountContacts(
      phone: (c['support_phone'] ?? c['phone'] ?? '0770 000 1122').toString(),
      whatsapp: (c['whatsapp_number'] ?? c['support_phone'] ?? '+9647700001122').toString(),
      telegramNumber: (c['telegram_number'] ?? c['support_phone'] ?? '0770 000 1122').toString(),
      telegramUsername: (c['telegram_username'] ?? 'rega_support').toString().replaceAll('@', ''),
      message: e.message,
    );
  }

  String get _waDigits => whatsapp.replaceAll(RegExp(r'[^\d]'), '');
  String get _phoneTel => phone.replaceAll(RegExp(r'[^\d+]'), '');

  Uri get whatsappUri => Uri.parse('https://wa.me/$_waDigits');
  Uri get telegramUri => telegramUsername.isNotEmpty
      ? Uri.parse('https://t.me/$telegramUsername')
      : Uri.parse('https://t.me/${telegramNumber.replaceAll(RegExp(r'[^\d]'), '')}');
  Uri get telUri => Uri.parse('tel:$_phoneTel');

  Future<void> _open(Uri uri, {String? clipboardFallback}) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && clipboardFallback != null) {
        await Clipboard.setData(ClipboardData(text: clipboardFallback));
      }
    } catch (_) {
      if (clipboardFallback != null) {
        await Clipboard.setData(ClipboardData(text: clipboardFallback));
      }
    }
  }

  static Future<void> show(BuildContext context, AccountBlockedException error) {
    final contacts = BlockedAccountContacts.fromException(error);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: RegaResponsive.dialogInset(ctx, cap: 400),
        title: Row(
          children: [
            Icon(Icons.block_rounded, color: RC.fg(Color(0xFFDC2626))),
            SizedBox(width: 8),
            Expanded(
              child: Text(tx('هەژمار مسدودکراوە'), style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        content: SizedBox(
          width: RegaResponsive.dialogMaxWidth(ctx, cap: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tx(contacts.message), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
                const SizedBox(height: 16),
                _ContactBtn(
                  icon: Icons.chat_rounded,
                  color: RC.bg(Color(0xFF16A34A)),
                  label: 'WhatsApp  ${contacts.whatsapp}',
                  onTap: () => contacts._open(contacts.whatsappUri, clipboardFallback: contacts.whatsapp),
                ),
                const SizedBox(height: 8),
                _ContactBtn(
                  icon: Icons.send_rounded,
                  color: RC.bg(Color(0xFF0284C7)),
                  label: 'Telegram  @${contacts.telegramUsername}',
                  onTap: () => contacts._open(contacts.telegramUri, clipboardFallback: '@${contacts.telegramUsername}'),
                ),
                const SizedBox(height: 8),
                _ContactBtn(
                  icon: Icons.phone_rounded,
                  color: RC.bg(Color(0xFFEA580C)),
                  label: 'Call  ${contacts.phone}',
                  onTap: () => contacts._open(contacts.telUri, clipboardFallback: contacts.phone),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tx('باشە'), style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ContactBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tx(label), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
              ),
              Icon(Icons.open_in_new_rounded, color: color.withValues(alpha: 0.7), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
