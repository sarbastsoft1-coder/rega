import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
/// Shared admin preview / helper for blocked-account contact UI.
/// Apps use their own copy of the same UX via [BlockedAccountContacts.show].
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

  factory BlockedAccountContacts.fromJson(Map<String, dynamic>? contact, {String? message}) {
    final c = contact ?? const <String, dynamic>{};
    return BlockedAccountContacts(
      phone: (c['support_phone'] ?? c['phone'] ?? '0770 000 1122').toString(),
      whatsapp: (c['whatsapp_number'] ?? c['support_phone'] ?? '+9647700001122').toString(),
      telegramNumber: (c['telegram_number'] ?? c['support_phone'] ?? '0770 000 1122').toString(),
      telegramUsername: (c['telegram_username'] ?? 'rega_support').toString().replaceAll('@', ''),
      message: message ??
          'هەژمارەکەت مسدود کراوە. تکایە پەیوەندی بە ئادمین بکە لە ڕێگەی واتسئاپ یان تێلێگرام.',
    );
  }

  String get whatsappDigits => whatsapp.replaceAll(RegExp(r'[^\d+]'), '');
  String get phoneDigits => phone.replaceAll(RegExp(r'[^\d+]'), '');
  String get telegramDigits => telegramNumber.replaceAll(RegExp(r'[^\d+]'), '');

  String get whatsappUrl => 'https://wa.me/${whatsappDigits.replaceFirst('+', '')}';
  String get telegramUrl => telegramUsername.isNotEmpty
      ? 'https://t.me/$telegramUsername'
      : 'https://t.me/+${telegramDigits.replaceFirst('+', '')}';
  String get telUrl => 'tel:$phoneDigits';

  static Future<void> show(BuildContext context, BlockedAccountContacts contacts) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.block_rounded, color: RC.fg(Color(0xFFDC2626))),
            SizedBox(width: 8),
            Expanded(child: Text(tx('هەژمار مسدودکراوە'), style: TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tx(contacts.message), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 16),
            _ContactBtn(
              icon: Icons.chat_rounded,
              color: RC.bg(Color(0xFF16A34A)),
              label: 'WhatsApp  ${contacts.whatsapp}',
              onTap: () => Clipboard.setData(ClipboardData(text: contacts.whatsappUrl)),
            ),
            const SizedBox(height: 8),
            _ContactBtn(
              icon: Icons.send_rounded,
              color: RC.bg(Color(0xFF0284C7)),
              label: 'Telegram  @${contacts.telegramUsername}',
              onTap: () => Clipboard.setData(ClipboardData(text: contacts.telegramUrl)),
            ),
            const SizedBox(height: 8),
            _ContactBtn(
              icon: Icons.phone_rounded,
              color: RC.bg(Color(0xFFEA580C)),
              label: 'Call  ${contacts.phone}',
              onTap: () => Clipboard.setData(ClipboardData(text: contacts.phone)),
            ),
            const SizedBox(height: 10),
            Text(
              tx('کرتە بکە بۆ کۆپیکردنی لینک / ژمارە'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: RC.fg(Color(0xFF64748B))),
            ),
          ],
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
            ],
          ),
        ),
      ),
    );
  }
}
