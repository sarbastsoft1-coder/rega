import 'dart:typed_data';

/// Non-web platforms: no browser download helper.
void triggerBrowserDownload(Uint8List bytes, String fileName) {
  throw UnsupportedError('Excel backup download is supported on Flutter web.');
}
