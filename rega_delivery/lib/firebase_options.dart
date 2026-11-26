// Placeholder Firebase options for REGA Delivery (motorcycle / driver).
// Replace via `flutterfire configure` (or paste real values from Firebase Console)
// and drop google-services.json / GoogleService-Info.plist into the Android/iOS folders.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderKeyReplaceMe000000',
    appId: '1:000000000000:web:driver0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rega-placeholder',
    authDomain: 'rega-placeholder.firebaseapp.com',
    storageBucket: 'rega-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderKeyReplaceMe000000',
    appId: '1:000000000000:android:driver00000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rega-placeholder',
    storageBucket: 'rega-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderKeyReplaceMe000000',
    appId: '1:000000000000:ios:driver0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rega-placeholder',
    storageBucket: 'rega-placeholder.appspot.com',
    iosBundleId: 'iq.rega.delivery',
  );
}
