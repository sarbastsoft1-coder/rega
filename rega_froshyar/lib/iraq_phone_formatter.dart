import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formats Iraqi mobile numbers as `0750 000 0000` (11 digits, always LTR).
class IraqPhoneFormatter extends TextInputFormatter {
  static const String hint = '0750 000 0000';
  static final RegExp iraqMobile = RegExp(r'^07[0-9]{9}$');

  /// Digits only, normalized from +964 / 964.
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

  /// Display as `0750 000 0000`.
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

  /// LTR-safe string for embedding inside RTL Text.
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

/// Phone [TextField] forced LTR so `0750 …` never flips in RTL UIs.
class IraqPhoneTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextStyle? style;

  const IraqPhoneTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.decoration,
    this.onChanged,
    this.autofocus = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final base = decoration ?? const InputDecoration();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        autofocus: autofocus,
        style: style,
        inputFormatters: [IraqPhoneFormatter()],
        onChanged: onChanged,
        decoration: base.copyWith(
          hintText: hintText ?? IraqPhoneFormatter.hint,
        ),
      ),
    );
  }
}
