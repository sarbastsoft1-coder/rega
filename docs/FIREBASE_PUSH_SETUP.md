# REGA customer push (lock screen + 3s in-app)

## 1. Firebase Console
1. Create a Firebase project.
2. Add Android app with package `com.example.xera` (or change `applicationId` to match).
3. Add iOS app with bundle `iq.rega.customer`.
4. Download:
   - `google-services.json` → `rega/android/app/google-services.json`
   - `GoogleService-Info.plist` → `rega/ios/Runner/GoogleService-Info.plist`
5. Run `flutterfire configure` (optional) to refresh `rega/lib/firebase_options.dart`.
6. Project settings → Service accounts → Generate new private key → save as:
   - `rega_backend/storage/app/firebase-credentials.json`
7. Set env on server / `.env`:
   ```
   FIREBASE_CREDENTIALS=/var/www/html/storage/app/firebase-credentials.json
   FCM_PROJECT_ID=your-firebase-project-id
   ```
8. iOS: upload APNs key in Firebase → Cloud Messaging.

## 2. Rebuild & install
```bash
cd rega
flutter pub get
flutter build apk --release
```
Install `REGA.apk` on the phone, log in, allow notifications.

## 3. Test
Admin → send customer notification → lock screen banner when app closed; 3s top banner when app open.
