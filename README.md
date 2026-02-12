# App Store Pre-Check Plugin

Pre-submission validation for **Flutter** and **Expo** apps before App Store and Google Play submission.

Catches common rejection issues automatically so you don't waste days in review limbo.

## v3.0.0 — What's New

- **Split into platform-specific skills** — separate Android and iOS checks for targeted validation
- **Comprehensive Android permissions audit** — scans AndroidManifest.xml for restricted, dangerous, and deprecated permissions
- **Foreground service type validation** — catches missing `foregroundServiceType` (crash on API 34+)
- **Network security checks** — cleartext traffic detection, HTTPS enforcement
- **Scoped Storage migration** — flags legacy storage permissions
- **AAB format requirement** — blocks APK-only builds
- **Play Billing Library v7+** — validates IAP library version
- **SDK Data Safety audit** — detects 20+ common SDKs and maps them to required Data Safety form declarations
- **Play Console manual checklist** — 11 items that must be completed in console
- **Updated targetSdk** — now requires API 35 (Aug 2025 deadline passed)

## Skills

| Skill | Path | Description |
|-------|------|-------------|
| **Android Pre-Check** | `skills/android-precheck/` | Google Play Store submission validation |
| **iOS Pre-Check** | `skills/ios-precheck/` | Apple App Store submission validation |

### Android Pre-Check (`skills/android-precheck/`)

Validates your app against Google Play requirements:

| Category | Checks |
|----------|--------|
| **Build & Config** | targetSdk 35+, compileSdk, AAB format, signing, R8/ProGuard |
| **Permissions** | 15 checks — restricted (SMS, Call Log), dangerous (Location, Camera), legacy (Storage) |
| **Foreground Services** | Missing `foregroundServiceType`, invalid types |
| **Network Security** | Cleartext traffic, HTTPS enforcement, network_security_config.xml |
| **Storage Policy** | Scoped Storage migration, legacy permission detection |
| **In-App Purchases** | Play Billing Library v7+, restore mechanism |
| **Account & Privacy** | Account deletion, privacy policy, data deletion URL |
| **SDK Data Safety** | 20 SDKs mapped to Data Safety form declarations |

### iOS Pre-Check (`skills/ios-precheck/`)

Validates your app against Apple App Store requirements:

| Category | Checks |
|----------|--------|
| **Background Modes** | UIBackgroundModes audit (audio, voip, location) — Guideline 2.5.4 |
| **Privacy Strings** | 16 privacy keys checked for placeholders, length, specificity — Guideline 5.1.1 |
| **App Transport Security** | NSAllowsArbitraryLoads, exception domains |
| **Build Config** | Bundle ID, version, build number, deployment target |
| **Account & Privacy** | Account deletion (5.1.1(v)), restore purchases (3.1.1), privacy policy |
| **Flutter Version** | Known problematic versions (3.24.3, 3.24.4) |

## Supported Frameworks

| Framework | Detection | Build Workflow |
|-----------|-----------|----------------|
| **Flutter** | `pubspec.yaml` | `flutter build ios` / `flutter build appbundle` |
| **Expo** | `app.json` + expo | `npx expo prebuild` → `npx expo run:ios/android` |
| **React Native** | `package.json` | Native builds |

## Quick Start

```bash
cd your-flutter-or-expo-project

# For Expo: run prebuild first
npx expo prebuild

# Run precheck
./precheck.sh
```

Or use Claude:

> "Run the Play Store precheck on my Flutter app"

> "Run the App Store precheck on my Expo project"

## Why?

App Store reviews take 1-4 days. Google Play reviews take 1-7 days. Getting rejected for something like:

- ❌ targetSdk below 35 (instant rejection since Aug 2025)
- ❌ Legacy storage permissions without `maxSdkVersion` 
- ❌ Missing `foregroundServiceType` (crash on Android 14+)
- ❌ `READ_SMS` permission without being default handler
- ❌ UIBackgroundModes "audio" (you don't need it for push notifications!)
- ❌ Generic camera permission string ("Camera access needed")
- ❌ Missing account deletion (required by both stores)
- ❌ No "Restore Purchases" button (iOS)
- ❌ Data Safety form mismatch (Firebase SDK detected but not declared)

...means another multi-day wait. This plugin catches these before you submit.

## Output

```
╔═══════════════════════════════════════════════════════════════════════════╗
║               GOOGLE PLAY STORE PRE-CHECK VALIDATOR v3.0                  ║
╚═══════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────┐
│  Project: my-app                            │
│  Framework: Flutter 3.27.1                  │
└─────────────────────────────────────────────┘

┃   BUILD & CONFIGURATION                                                  ┃
▸ Target SDK Level (must be 35+)          ✅
▸ Build Format (AAB required)             ✅
▸ Release Signing Configuration           ✅

┃   PERMISSIONS AUDIT (AndroidManifest.xml)                                ┃
▸ Restricted Permissions                  ✅
▸ Background Location                     ✅
▸ Legacy Storage Permissions              ❌ WRITE_EXTERNAL_STORAGE without maxSdkVersion

┃   FOREGROUND SERVICES                                                    ┃
▸ Service type declarations               ⚠️  LocationService missing foregroundServiceType

┃   SDK DATA SAFETY AUDIT                                                  ┃
▸ Firebase Analytics detected             ℹ️  Declare: Device IDs, App activity
▸ Firebase Crashlytics detected           ℹ️  Declare: Crash logs, Device IDs
▸ Google Maps SDK detected                ℹ️  Declare: Location data

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TOTAL:  1 blocker   1 warning   12 passed
  🚫 NOT READY FOR SUBMISSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Screenshot Requirements

| Platform | Size | Dimensions | Required |
|----------|------|------------|----------|
| iOS | iPhone 6.9" | 1320 × 2868 | ✅ Yes |
| iOS | iPad 13" | 2064 × 2752 | If iPad app |
| Android | Phone | 1080 × 1920 | ✅ Min 2 |
| Android | Tablet | Various | If supported |

## Installation

### As Claude Skill

Add to your `.claude/skills/` directory or install via marketplace.

### Standalone

```bash
# Copy to your project
cp skills/android-precheck/scripts/precheck-android.sh /path/to/your/project/
cp skills/ios-precheck/scripts/precheck-ios.sh /path/to/your/project/
chmod +x precheck-*.sh

# Run
./precheck-android.sh
./precheck-ios.sh
```

## References

### Android
- [Google Play Developer Program Policy](https://support.google.com/googleplay/android-developer/answer/16810878)
- [Google Play Data Safety Requirements](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Target API Level Requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Permissions and Sensitive APIs Policy](https://support.google.com/googleplay/android-developer/answer/16558241)
- [Google Play SDK Index](https://developer.android.com/distribute/sdk-index)

### iOS
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

## License

MIT
