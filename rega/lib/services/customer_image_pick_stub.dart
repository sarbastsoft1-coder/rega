import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Mobile / desktop: camera or gallery via image_picker.
Future<({String name, Uint8List bytes})?> pickCustomerImage({
  required bool fromCamera,
}) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 82,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  final name = file.name.trim().isEmpty ? 'photo.jpg' : file.name.trim();
  return (name: name, bytes: bytes);
}
