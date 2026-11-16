import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'iraq_phone_formatter.dart';
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

  /// International dial form for `tel:` (e.g. +9647700001122).
  String get _phoneTel {
    var d = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (d.startsWith('0') && d.length == 11) return '+964${d.substring(1)}';
    if (d.startsWith('964')) return '+$d';
    if (d.startsWith('+')) return d;
    return d.isEmpty ? phone : '+$d';
  }

  Uri get whatsappUri => Uri.parse('https://wa.me/$_waDigits');
  Uri get telegramUri => telegramUsername.isNotEmpty
      ? Uri.parse('https://t.me/$telegramUsername')
      : Uri.parse('https://t.me/$_waDigits');
  Uri get telUri => Uri.parse('tel:$_phoneTel');

  String get telegramLabel => telegramUsername.isNotEmpty
      ? '@$telegramUsername'
      : telegramNumber;

  /// Opens WhatsApp / Telegram / phone. On web uses a new tab; falls back to clipboard.
  Future<bool> open(
    Uri uri, {
    String? clipboardFallback,
    BuildContext? context,
  }) async {
    var ok = false;
    try {
      if (kIsWeb) {
        // externalApplication often fails silently in Flutter web / embedded previews.
        ok = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      } else {
        if (await canLaunchUrl(uri)) {
          ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (!ok) {
          ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      }
    } catch (_) {
      ok = false;
    }

    if (!ok && clipboardFallback != null && clipboardFallback.trim().isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: clipboardFallback.trim()));
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx('لینکەکە نەکرایەوە — کۆپی کرا: $clipboardFallback')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: RC.bg(Color(0xFF0F172A)),
          ),
        );
      }
      return false;
    }
    return ok;
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
                  onTap: () => contacts.open(
                    contacts.whatsappUri,
                    clipboardFallback: contacts.whatsapp,
                    context: ctx,
                  ),
                ),
                const SizedBox(height: 8),
                _ContactBtn(
                  icon: Icons.send_rounded,
                  color: RC.bg(Color(0xFF0284C7)),
                  label: 'Telegram  ${contacts.telegramLabel}',
                  onTap: () => contacts.open(
                    contacts.telegramUri,
                    clipboardFallback: contacts.telegramLabel,
                    context: ctx,
                  ),
                ),
                const SizedBox(height: 8),
                _ContactBtn(
                  icon: Icons.phone_rounded,
                  color: RC.bg(Color(0xFFEA580C)),
                  label: tx('پەیوەندی تەلەفۆن  ${contacts.phone}'),
                  onTap: () => contacts.open(
                    contacts.telUri,
                    clipboardFallback: contacts.phone,
                    context: ctx,
                  ),
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
        insetPadding: RegaResponsive.dialogInset(ctx, cap: 400),
        title: Text(tx(title), style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: RegaResponsive.dialogMaxWidth(ctx, cap: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tx(body), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
                const SizedBox(height: 16),
                _ContactBtn(
                  icon: Icons.chat_rounded,
                  color: RC.bg(Color(0xFF16A34A)),
                  label: 'WhatsApp  ${contacts.whatsapp}',
                  onTap: () => contacts.open(
                    contacts.whatsappUri,
                    clipboardFallback: contacts.whatsapp,
                    context: ctx,
                  ),
                ),
                const SizedBox(height: 8),
                _ContactBtn(
                  icon: Icons.send_rounded,
                  color: RC.bg(Color(0xFF0284C7)),
                  label: 'Telegram  ${contacts.telegramLabel}',
                  onTap: () => contacts.open(
                    contacts.telegramUri,
                    clipboardFallback: contacts.telegramLabel,
                    context: ctx,
                  ),
                ),
                if (contacts.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ContactBtn(
                    icon: Icons.phone_rounded,
                    color: RC.bg(Color(0xFFEA580C)),
                    label: tx('پەیوەندی تەلەفۆن  ${contacts.phone}'),
                    onTap: () => contacts.open(
                      contacts.telUri,
                      clipboardFallback: contacts.phone,
                      context: ctx,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tx(okLabel), style: TextStyle(color: RC.fg(Color(0xFFEA580C)), fontWeight: FontWeight.bold)),
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
