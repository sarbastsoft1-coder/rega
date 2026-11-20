import 'dart:typed_data';

import 'customer_image_pick_stub.dart'
    if (dart.library.js_interop) 'customer_image_pick_web.dart' as impl;

/// Pick a customer direct-request image (camera or gallery).
/// Web uses HTML file input; mobile uses image_picker.
Future<({String name, Uint8List bytes})?> pickCustomerImage({
  required bool fromCamera,
}) =>
    impl.pickCustomerImage(fromCamera: fromCamera);
