import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rega_i18n.dart';

/// Customer delivery PIN entry — submit stays disabled until exactly 4 digits.
Future<String?> showDeliveryPinDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  required String cancelLabel,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DeliveryPinDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _DeliveryPinDialog extends StatefulWidget {
  const _DeliveryPinDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_DeliveryPinDialog> createState() => _DeliveryPinDialogState();
}

class _DeliveryPinDialogState extends State<_DeliveryPinDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool get _valid => RegExp(r'^\d{4}$').hasMatch(_ctrl.text.trim());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tx(widget.title)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx(widget.hint)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            autofocus: true,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(tx(widget.cancelLabel)),
        ),
        ElevatedButton(
          key: const Key('delivery_pin_confirm'),
          onPressed: _valid ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF94A3B8),
            disabledForegroundColor: Colors.white70,
          ),
          child: Text(tx(widget.confirmLabel)),
        ),
      ],
    );
  }
}
