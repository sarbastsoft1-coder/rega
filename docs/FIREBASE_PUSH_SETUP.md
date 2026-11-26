# REGA push notifications (customer + vendor + delivery)

Lock-screen FCM for all three mobile apps when the app is backgrounded or closed.
Foreground shows a 3s in-app banner (and tray notification on vendor/driver).

## 1. Firebase Console
1. Create (or reuse) one Firebase project.
2. Add Android apps:
   - Customer: `com.example.xera` → `rega/android/app/google-services.json`
   - Vendor: `com.example.rega_froshyar` → `rega_froshyar/android/app/google-services.json`
   - Delivery: `com.example.rega_delivery` → `rega_delivery/android/app/google-services.json`
3. Add iOS apps:
   - Customer: `iq.rega.customer`
   - Vendor: `iq.rega.vendor`
   - Delivery: `iq.rega.delivery`
4. Download each `GoogleService-Info.plist` into the matching `ios/Runner/` folder.
5. Optionally run `flutterfire configure` in each app folder to refresh `lib/firebase_options.dart`.
6. Project settings → Service accounts → Generate new private key → save as:
   - `rega_backend/storage/app/firebase-credentials.json`
7. Set env on server / `.env`:
   ```
   FIREBASE_CREDENTIALS=/var/www/html/storage/app/firebase-credentials.json
   FCM_PROJECT_ID=your-firebase-project-id
   ```
8. iOS: upload APNs key in Firebase → Cloud Messaging.

## 2. Android notification channels
| App | Channel ID |
|-----|------------|
| Customer | `rega_customer_push` |
| Vendor | `rega_vendor_push` |
| Delivery | `rega_driver_push` |

Backend picks the channel from the user role (`vendor` / `driver` / other).

## 3. What triggers a push
| Event | Recipient |
|-------|-----------|
| Customer places order | Store owner (vendor) |
| Vendor/admin/auto assigns driver | Driver |
| Vendor accepts / marks ready | Customer |
| Driver status updates | Customer |
| Admin marketing to customers/vendors/drivers | Selected audience |

## 4. Rebuild & install
```bash
cd rega_froshyar && flutter pub get && flutter build apk --release
cd ../rega_delivery && flutter pub get && flutter build apk --release
```
Install the APK, log in, allow notifications when prompted.

## 5. Test
1. Vendor app closed → place a customer order → vendor lock-screen alert.
2. Delivery app closed → assign a driver → driver lock-screen alert.
3. With app open → 3s top banner + tray notification.
