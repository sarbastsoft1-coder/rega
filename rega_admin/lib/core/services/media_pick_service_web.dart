import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: always use a real HTML `<input type="file">`.
/// Never depends on federated `file_picker` plugin registration
/// (avoids `UnimplementedError: pickFiles()`).
Future<({String name, Uint8List bytes})?> pickMediaBytes({
  required bool imagesOnly,
}) {
  return _pickViaHtmlInput(
    accept: imagesOnly ? 'image/*' : 'image/*,.pdf,application/pdf',
  );
}

Future<({String name, Uint8List bytes})?> _pickViaHtmlInput({
  required String accept,
}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = false;

  final completer = Completer<({String name, Uint8List bytes})?>();

  void finish(({String name, Uint8List bytes})? value) {
    if (!completer.isCompleted) completer.complete(value);
    input.remove();
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final list = input.files;
      if (list == null || list.length == 0) {
        finish(null);
        return;
      }
      final file = list.item(0);
      if (file == null) {
        finish(null);
        return;
      }

      final reader = web.FileReader();
      reader.addEventListener(
        'loadend',
        (web.Event _) {
          final buffer = (reader.result as JSArrayBuffer?)?.toDart;
          final bytes = buffer?.asUint8List();
          if (bytes == null || bytes.isEmpty) {
            finish(null);
            return;
          }
          finish((name: file.name, bytes: bytes));
        }.toJS,
      );
      reader.addEventListener(
        'error',
        (web.Event _) {
          finish(null);
        }.toJS,
      );
      reader.readAsArrayBuffer(file);
    }.toJS,
  );

  // If the user cancels the OS dialog, complete with null shortly after focus returns.
  web.window.addEventListener(
    'focus',
    (web.Event _) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted &&
            (input.files == null || input.files!.length == 0)) {
          finish(null);
        }
      });
    }.toJS,
    web.AddEventListenerOptions(once: true),
  );

  input.style.display = 'none';
  web.document.body?.appendChild(input);
  input.click();
  return completer.future;
}
