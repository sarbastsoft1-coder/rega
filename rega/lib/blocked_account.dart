import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'iraq_phone_formatter.dart';
import 'l10n/customer_l10n.dart';
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
              'هەژمارەکەت مسدود کراوە. تکایە پەیوەندی بە یارمەتی پشتگیری بکە لە ڕێگەی واتسئاپ.')
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
      telegramUsername:
          (c['telegram_username'] ?? 'rega_support').toString().replaceAll('@', ''),
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
  Uri get telUri => Uri.parse('tel:$_phoneTel');

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

  /// Shown when admin blocks a customer — localized ku / ar / en, WhatsApp help/support.
  static Future<void> show(
    BuildContext context,
    AccountBlockedException error, {
    String lang = 'ku',
  }) {
    final contacts = BlockedAccountContacts.fromException(error);
    final code = CustomerL10n.normalizeLang(lang);
    String t(String key) => CustomerL10n.tr(key, code);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isRtl = CustomerL10n.directionFor(code) == TextDirection.rtl;
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: RegaResponsive.dialogInset(ctx, cap: 400),
            title: Row(
              children: [
                Icon(Icons.block_rounded, color: RC.fg(Color(0xFFDC2626)), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('هەژمارەکەت مسدود کراوە'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
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
                    Text(
                      t('هەژمارەکەت لەلایەن بەڕێوەبەرەوە مسدود کراوە. تکایە پەیوەندی بە یارمەتی پشتگیری بکە لە ڕێگەی واتسئاپ.'),
                      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    _ContactBtn(
                      icon: Icons.chat_rounded,
                      color: RC.bg(Color(0xFF16A34A)),
                      label: tx('${t('پەیوەندی لە ڕێگەی واتسئاپ')}  ${contacts.whatsapp}'),
                      onTap: () => contacts.open(
                        contacts.whatsappUri,
                        clipboardFallback: contacts.whatsapp,
                      ),
                    ),
                    if (contacts.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ContactBtn(
                        icon: Icons.phone_rounded,
                        color: RC.bg(Color(0xFFEA580C)),
                        label: tx('${t('تەلەفۆن بۆ ڕاژەی کریاران')}  ${contacts.phone}'),
                        onTap: () => contacts.open(
                          contacts.telUri,
                          clipboardFallback: contacts.phone,
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
                child: Text(
                  t('باشە'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
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
                child: Text(
                  tx(label),
                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13),
                ),
              ),
              Icon(Icons.open_in_new_rounded, color: color.withValues(alpha: 0.7), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
