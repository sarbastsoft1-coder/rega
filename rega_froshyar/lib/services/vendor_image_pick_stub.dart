import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<({String name, Uint8List bytes})?> pickVendorImage({
  required bool fromCamera,
}) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 92,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  final name = file.name.trim().isEmpty ? 'photo.jpg' : file.name.trim();
  return (name: name, bytes: Uint8List.fromList(bytes));
}
