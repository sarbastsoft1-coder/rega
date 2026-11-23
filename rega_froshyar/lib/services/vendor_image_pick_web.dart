import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: HTML `<input type="file">` — avoids image_picker web failures.
Future<({String name, Uint8List bytes})?> pickVendorImage({
  required bool fromCamera,
}) {
  return _pickViaHtmlInput(fromCamera: fromCamera);
}

Future<({String name, Uint8List bytes})?> _pickViaHtmlInput({
  required bool fromCamera,
}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..multiple = false;

  if (fromCamera) {
    input.setAttribute('capture', 'environment');
  }

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
          final name = file.name.trim().isEmpty ? 'photo.jpg' : file.name.trim();
          finish((name: name, bytes: bytes));
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

  web.window.addEventListener(
    'focus',
    (web.Event _) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!completer.isCompleted &&
            (input.files == null || input.files!.length == 0)) {
          finish(null);
        }
      });
    }.toJS,
  );

  web.document.body?.append(input);
  input.click();
  return completer.future;
}
