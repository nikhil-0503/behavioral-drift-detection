# behavioral_drift_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Google OAuth setup (Firebase Auth)

This app uses `firebase_auth` + `google_sign_in` in `lib/services/auth_service.dart`.

### 1. Enable Google provider in Firebase

1. Open Firebase Console -> Authentication -> Sign-in method.
2. Enable `Google`.

### 2. Android setup

1. In Firebase Console -> Project settings -> Your Android app (`com.example.behavioral_drift_app`), add:
   - Debug SHA-1 / SHA-256
   - Release SHA-1 / SHA-256
2. Re-download `google-services.json`.
3. Replace `android/app/google-services.json`.
4. Confirm the new file contains non-empty `oauth_client`.

### 3. iOS setup

1. Add an iOS app in Firebase with your iOS bundle id.
2. Download `GoogleService-Info.plist` and place it under `ios/Runner/GoogleService-Info.plist`.
3. In Xcode, add the file to the Runner target.
4. Add the `REVERSED_CLIENT_ID` from that plist to `ios/Runner/Info.plist` under `CFBundleURLTypes`.

### 4. Verify

1. Run `flutter clean`.
2. Run `flutter pub get`.
3. Run the app and test Google sign in.

If Android sign-in fails with `ApiException: 10`, SHA keys or OAuth client config are missing/mismatched.
