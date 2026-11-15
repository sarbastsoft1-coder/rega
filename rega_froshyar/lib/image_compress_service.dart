import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Client-side image resize + JPEG compress for vendor uploads (web + native).
class ImageCompressService {
  ImageCompressService._();

  static const int maxDimension = 1280;
  static const int jpegQuality = 80;

  static Future<({String name, Uint8List bytes})> compressForUpload({
    required String name,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      return (name: name, bytes: bytes);
    }

    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
      );
      if (result.isEmpty) {
        return (name: name, bytes: bytes);
      }
      final out = Uint8List.fromList(result);
      if (out.lengthInBytes >= bytes.lengthInBytes && _looksLikeJpeg(bytes)) {
        return (name: name, bytes: bytes);
      }
      return (name: _toJpegName(name), bytes: out);
    } catch (_) {
      return (name: name, bytes: bytes);
    }
  }

  static bool _looksLikeJpeg(Uint8List bytes) {
    return bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  }

  static String _toJpegName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'image.jpg';
    final dot = trimmed.lastIndexOf('.');
    if (dot <= 0) return '$trimmed.jpg';
    return '${trimmed.substring(0, dot)}.jpg';
  }
}
