import 'dart:typed_data';

import 'vendor_image_pick_stub.dart'
    if (dart.library.js_interop) 'vendor_image_pick_web.dart' as impl;

/// Pick a vendor image (camera or gallery).
/// Web uses HTML file input; mobile uses image_picker.
Future<({String name, Uint8List bytes})?> pickVendorImage({
  required bool fromCamera,
}) =>
    impl.pickVendorImage(fromCamera: fromCamera);
