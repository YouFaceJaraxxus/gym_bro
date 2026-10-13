# Gym Bro — mobile app

Flutter app for members, trainers, staff, gym owners and shop vendors. It talks only to the
Supabase edge functions in [`../gym_bro_api`](../gym_bro_api) (never to Postgres/REST directly).

- Flutter **3.41.x** (Dart 3.11), Material 3
- iOS 15.0+, Android 7.0+ (API 24), macOS/web for development only
- State: `StatefulWidget` + `setState`; session in `AuthManager.instance`; HTTP in `ApiService`
  (`lib/services/api_service.dart` + one `part` file per domain in `lib/services/api/`)

## Setup

```bash
# 1. Flutter 3.41.x on your PATH (flutter --version)
cd apps/gym_bro_mobile
flutter pub get

# 2. iOS only: CocoaPods
cd ios && pod install && cd ..
#    (if pod crashes with "Unicode Normalization not appropriate for ASCII-8BIT",
#     run it with LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8)
```

## Running locally

Start the API first (see `apps/gym_bro_api`): `supabase start`, then
`./scripts/serve.sh` to serve the edge functions on `http://127.0.0.1:54321/functions/v1`.
Seeded demo users all use the password `GymBroSeed123!` (e.g. `liam.oconnor@example.com`
member, `marcus.bennett@example.com` gym owner).

```bash
flutter run                       # picks a connected device / simulator
flutter run -d "iPhone 16"        # iOS simulator → http://localhost:54321
flutter run -d emulator-5554      # Android emulator → http://10.0.2.2:54321
```

Without `API_BASE_URL` the app targets the local stack: `10.0.2.2` on the Android emulator
(the emulator's alias for your machine), `localhost` everywhere else. On a **physical device**
pass your machine's address, e.g. `--dart-define=API_BASE_URL=http://192.168.1.20:54321/functions/v1`
— note that Android only allows cleartext `http://` to 10.0.2.2 / localhost / 127.0.0.1
(`android/app/src/main/res/xml/network_security_config.xml`), so for a phone use an https
tunnel (ngrok, cloudflared) or temporarily add your LAN IP to that file.

## Build-time configuration (dart-defines)

Everything is optional; features whose config is missing hide themselves.

| Define | Used by | Notes |
|---|---|---|
| `API_BASE_URL` | `lib/config.dart` → `ApiService`, `AuthService` | Edge functions base, e.g. `https://<project>.supabase.co/functions/v1`. **Must be https for release builds.** Default: local stack. |
| `FIREBASE_API_KEY` | `lib/services/push_service.dart` | Push is off unless all four `FIREBASE_*` (except the iOS bundle id) are set. |
| `FIREBASE_APP_ID` | push | Differs per platform — use the Android app's ID for Android builds and the iOS app's for iOS. |
| `FIREBASE_MESSAGING_SENDER_ID` | push | Project number. |
| `FIREBASE_PROJECT_ID` | push | |
| `FIREBASE_IOS_BUNDLE_ID` | push (iOS, optional) | |
| `GOOGLE_SERVER_CLIENT_ID` | `lib/widgets/google_sign_in_button.dart` | "Web application" OAuth client ID (the ID token audience). Google sign-in is hidden without it. |
| `GOOGLE_IOS_CLIENT_ID` | Google sign-in (iOS) | iOS OAuth client ID. Also add its reversed form (`com.googleusercontent.apps.<id>`) as a URL scheme in `ios/Runner/Info.plist` → `CFBundleURLTypes`. |

Keep them in a JSON file per platform (keep files with real keys out of git, e.g. add
`config/*.json` to `.gitignore`) and pass it with `--dart-define-from-file`:

```jsonc
// config/prod.android.json
{
  "API_BASE_URL": "https://<project>.supabase.co/functions/v1",
  "FIREBASE_API_KEY": "…",
  "FIREBASE_APP_ID": "1:1234567890:android:abc…",
  "FIREBASE_MESSAGING_SENDER_ID": "1234567890",
  "FIREBASE_PROJECT_ID": "gym-bro",
  "GOOGLE_SERVER_CLIENT_ID": "….apps.googleusercontent.com"
}
```

```bash
flutter run --dart-define-from-file=config/prod.android.json
```

### API-side configuration

The app's optional features also need secrets on the API (see `apps/gym_bro_api/.env.template`);
without them the API answers `503 {code: "not_configured"}` and the app hides or explains the feature:

| API env | Feature |
|---|---|
| `FCM_SERVICE_ACCOUNT_B64` | Sending push notifications (base64 Firebase service-account JSON). |
| `CRON_SECRET` | `jobs` function (class reminders, expiring memberships), scheduled by pg_cron — see `apps/gym_bro_api/sql/cron.sql`. |
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `PAYMENTS_CURRENCY` | Card payments for orders and memberships. |
| `PAYMENT_RETURN_URL` | Where Stripe Checkout returns after payment. |
| `CHECKIN_SECRET` | Signs gym check-in QR codes (falls back to a key derived from the service role key). |

### Google sign-in setup (iOS)

In `ios/Runner/Info.plist` add the reversed iOS client ID as a URL scheme (Google redirects back
to the app through it), and optionally `GIDClientID` (the app already passes
`GOOGLE_IOS_CLIENT_ID` at runtime):

```xml
<key>CFBundleURLTypes</key>
<array>
  <!-- keep the existing gymbroo entry -->
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string></array>
  </dict>
</array>
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
```

Android needs no app-side change beyond an "Android" OAuth client registered with the package
name and signing SHA-1 (debug and release).

## Offline support

- `lib/services/offline/caching_client.dart` — the shared HTTP client behind `ApiService`:
  20 s timeout per request (2 min for uploads), successful GETs cached on disk (per user, 200
  entries, LRU). When the network is unreachable a GET is answered from the cache with the
  header `x-gymbro-offline: 1` (`isOfflineResponse(r)`).
- `lib/services/offline/connectivity_service.dart` — `ConnectivityService.instance.online`
  (connectivity_plus + "last request failed with a network error").
- `lib/widgets/offline_banner.dart` — `OfflineBanner()`, "You're offline — showing saved data".
- `lib/services/offline/outbox.dart` — queued writes, persisted in shared_preferences and
  replayed in order when the connection returns and at startup. `ApiService.logSessionSet`
  queues on network failure and throws `QueuedOfflineException` (treat as "saved offline").
  Other writes can opt in via `ApiService._sendOrQueue`.
- `OfflineSupport.clearOnLogout()` (in `offline_support.dart`) wipes the cache and the queue.

## Tests and analysis

```bash
dart analyze lib
flutter test                       # models, settings, caching client, outbox, offline banner
```

CI (`.github/workflows/ci.yml` at the repo root) runs both on every PR touching this app.

## Release builds

### Android

1. **Application ID** — still the template's `com.example.gym_bro_mobile`
   (`android/app/build.gradle.kts`, `applicationId` and `namespace`). Pick the real one before the
   first Play upload; it can't change afterwards. Also rename the app label in
   `android/app/src/main/AndroidManifest.xml` if wanted.
2. **Signing** — create an upload keystore and `android/key.properties` (git-ignored):

   ```bash
   keytool -genkey -v -keystore ~/gym-bro-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```

   ```properties
   # android/key.properties
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/Users/you/gym-bro-upload.jks
   ```

   Without `key.properties` release builds are signed with the debug key (fine for
   `flutter run --release`, rejected by Google Play).
3. Build:

   ```bash
   flutter build appbundle --release --dart-define-from-file=config/prod.android.json
   ```

   Register the release (and Play App Signing) SHA-1 in Firebase and in the Google Cloud
   "Android" OAuth client for push and Google sign-in.

Manifest/Gradle already include INTERNET, CAMERA, POST_NOTIFICATIONS and
RECEIVE_BOOT_COMPLETED, flutter_local_notifications receivers, core library desugaring and
`minSdk` 24.

### iOS

1. Open `ios/Runner.xcworkspace` in Xcode → Runner target → **Signing & Capabilities**: choose
   your team and the real bundle identifier.
2. Add the **Push Notifications** capability (this creates `Runner.entitlements` with
   `aps-environment`). It is deliberately not in the repo: the entitlement breaks unsigned and
   simulator builds. (Background Modes → "Remote notifications" is already enabled via
   `UIBackgroundModes` in `Info.plist`.) `UIBackgroundModes → remote-notification` is already in `Info.plist`.
3. Upload an APNs auth key to Firebase (Project settings → Cloud Messaging).
4. For Google sign-in add the reversed iOS client ID URL scheme to `Info.plist` (see
   "Google sign-in setup" above).
5. Build:

   ```bash
   flutter build ipa --release --dart-define-from-file=config/prod.ios.json
   ```

`Info.plist` already has the camera (photos + check-in/barcode scanning) and photo library
usage strings, and App Transport Security only relaxes rules for local networking
(`NSAllowsLocalNetworking`), so the production API must be https.

### Smoke-checking the native config

```bash
flutter build apk --debug
flutter build ios --simulator --debug --no-codesign
```
