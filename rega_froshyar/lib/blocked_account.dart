import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'iraq_phone_formatter.dart';

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

  factory BlockedAccountContacts.fromMap(
    Map<String, dynamic> c, {
    String message = '',
  }) {
    return BlockedAccountContacts(
      phone: IraqPhoneFormatter.format(
        (c['support_phone'] ?? c['phone'] ?? '07700001122').toString(),
      ),
      whatsapp: IraqPhoneFormatter.format(
        (c['whatsapp_number'] ?? c['support_phone'] ?? '07700001122').toString(),
      ),
      telegramNumber: IraqPhoneFormatter.format(
        (c['telegram_number'] ?? c['support_phone'] ?? '07700001122').toString(),
      ),
      telegramUsername: (c['telegram_username'] ?? 'rega_support').toString().replaceAll('@', ''),
      message: message,
    );
  }

  factory BlockedAccountContacts.fromException(AccountBlockedException e) {
    return BlockedAccountContacts.fromMap(e.contact, message: e.message);
  }

  String get _waDigits {
    var d = whatsapp.replaceAll(RegExp(r'[^\d]'), '');
    if (d.startsWith('0') && d.length == 11) d = '964${d.substring(1)}';
    return d;
  }

  String get _phoneTel => phone.replaceAll(RegExp(r'[^\d+]'), '');

  Uri get whatsappUri => Uri.parse('https://wa.me/$_waDigits');
  Uri get telegramUri => telegramUsername.isNotEmpty
      ? Uri.parse('https://t.me/$telegramUsername')
      : Uri.parse('https://t.me/$_waDigits');
  Uri get telUri => Uri.parse('tel:$_phoneTel');

  String get telegramLabel => telegramUsername.isNotEmpty
      ? '@$telegramUsername'
      : telegramNumber;

  Future<void> open(Uri uri, {String? clipboardFallback}) async {
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
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Expanded(
              child: Text('هەژمار مسدودکراوە', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(contacts.message, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
            const SizedBox(height: 16),
            _ContactBtn(
              icon: Icons.chat_rounded,
              color: const Color(0xFF16A34A),
              label: 'WhatsApp  ${contacts.whatsapp}',
              onTap: () => contacts.open(contacts.whatsappUri, clipboardFallback: contacts.whatsapp),
            ),
            const SizedBox(height: 8),
            _ContactBtn(
              icon: Icons.send_rounded,
              color: const Color(0xFF0284C7),
              label: 'Telegram  ${contacts.telegramLabel}',
              onTap: () => contacts.open(contacts.telegramUri, clipboardFallback: contacts.telegramLabel),
            ),
            const SizedBox(height: 8),
            _ContactBtn(
              icon: Icons.phone_rounded,
              color: const Color(0xFFEA580C),
              label: 'پەیوەندی تەلەفۆن  ${contacts.phone}',
              onTap: () => contacts.open(contacts.telUri, clipboardFallback: contacts.phone),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('باشە', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Seller login → "new shop registration" contact dialog (WhatsApp / Telegram / phone).
  static Future<void> showSellerRegistrationDialog(
    BuildContext context, {
    required Map<String, dynamic> contactMap,
    required String title,
    required String body,
    required String okLabel,
  }) {
    final contacts = BlockedAccountContacts.fromMap(contactMap, message: body);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(body, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
            const SizedBox(height: 16),
            _ContactBtn(
              icon: Icons.chat_rounded,
              color: const Color(0xFF16A34A),
              label: 'WhatsApp  ${contacts.whatsapp}',
              onTap: () => contacts.open(contacts.whatsappUri, clipboardFallback: contacts.whatsapp),
            ),
            const SizedBox(height: 8),
            _ContactBtn(
              icon: Icons.send_rounded,
              color: const Color(0xFF0284C7),
              label: 'Telegram  ${contacts.telegramLabel}',
              onTap: () => contacts.open(contacts.telegramUri, clipboardFallback: contacts.telegramLabel),
            ),
            if (contacts.phone.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _ContactBtn(
                icon: Icons.phone_rounded,
                color: const Color(0xFFEA580C),
                label: 'پەیوەندی تەلەفۆن  ${contacts.phone}',
                onTap: () => contacts.open(contacts.telUri, clipboardFallback: contacts.phone),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(okLabel, style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
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
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
              ),
              Icon(Icons.open_in_new_rounded, color: color.withValues(alpha: 0.7), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
