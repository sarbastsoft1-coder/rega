import 'dart:typed_data';

import 'image_compress_service.dart';
import 'media_pick_service_stub.dart'
    if (dart.library.js_interop) 'media_pick_service_web.dart' as impl;

/// Shared media picker for every admin upload (products, catalog, drivers, …).
///
/// On web this never relies solely on plugin registration — if `FilePicker`
/// throws `UnimplementedError`, an HTML file input is used instead.
class MediaPickService {
  MediaPickService._();

  /// Pick a single image and compress it for upload.
  static Future<({String name, Uint8List bytes})?> pickImageForUpload() async {
    final raw = await impl.pickMediaBytes(imagesOnly: true);
    if (raw == null) return null;
    return ImageCompressService.compressForUpload(name: raw.name, bytes: raw.bytes);
  }

  /// Pick image or PDF (driver documents). Images are compressed; PDFs are left as-is.
  static Future<({String name, Uint8List bytes})?> pickImageOrPdf() async {
    final raw = await impl.pickMediaBytes(imagesOnly: false);
    if (raw == null) return null;
    final lower = raw.name.toLowerCase();
    if (lower.endsWith('.pdf')) return raw;
    return ImageCompressService.compressForUpload(name: raw.name, bytes: raw.bytes);
  }
}
