import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Native / desktop / mobile: use federated [FilePicker].
Future<({String name, Uint8List bytes})?> pickMediaBytes({
  required bool imagesOnly,
}) async {
  final files = await FilePicker.pickFiles(
    type: imagesOnly ? FileType.image : FileType.custom,
    allowedExtensions: imagesOnly
        ? null
        : const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'],
  );
  if (files.isEmpty) return null;
  final f = files.first;
  final bytes = await f.readAsBytes();
  if (bytes.isEmpty) return null;
  return (name: f.name, bytes: bytes);
}
