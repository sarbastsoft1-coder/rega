import 'package:flutter/services.dart';

/// Formats Iraqi mobile numbers as `0750 000 0000` (11 digits, always LTR).
class IraqPhoneFormatter extends TextInputFormatter {
  static const String hint = '0750 000 0000';
  static final RegExp iraqMobile = RegExp(r'^07[0-9]{9}$');

  static String digitsOnly(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('964') && digits.length >= 3) {
      digits = '0${digits.substring(3)}';
    }
    if (digits.startsWith('00964') && digits.length >= 5) {
      digits = '0${digits.substring(5)}';
    }
    return digits;
  }

  static String format(String raw) {
    var digits = digitsOnly(raw);
    if (digits.length > 11) digits = digits.substring(0, 11);
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 4 || i == 7) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  static String display(String raw) {
    final formatted = format(raw);
    if (formatted.isEmpty) return '';
    return '\u200E$formatted\u200E';
  }

  static bool isValidIraqMobile(String raw) => iraqMobile.hasMatch(digitsOnly(raw));

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
