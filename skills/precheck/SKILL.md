---
name: app-store-precheck
version: 2.1.0
description: Pre-submission validation for Flutter and Expo apps before App Store and Google Play submission
triggers:
  - app store
  - play store
  - submission
  - precheck
  - app review
  - rejection
  - flutter deploy
  - expo submit
  - expo prebuild
tools:
  - bash
---

# App Store Pre-Check for Flutter & Expo

Automated pre-submission validation to catch common rejection issues **before** you submit to the App Store or Google Play.

## Supported Frameworks

| Framework | Detection | Build Workflow |
|-----------|-----------|----------------|
| **Flutter** | `pubspec.yaml` | `flutter build ios/apk` |
| **Expo** | `app.json` + expo | `npx expo prebuild` → `npx expo run:ios/android` |
| **React Native** | `package.json` | Native builds |

## Quick Start

Run from your project root:

```bash
./precheck.sh
```

Or use Claude to analyze your project:

> "Run the app store precheck on my Flutter app"

### Expo Projects

For Expo, run prebuild first so native files exist:

```bash
npx expo prebuild
./precheck.sh
```

Without prebuild, the script checks `app.json` config only.

## What It Checks

### iOS Checks (Apple App Store)

| Check | Guideline | Severity |
|-------|-----------|----------|
| UIBackgroundModes abuse (audio, voip, location) | 2.5.4 | ❌ Blocker |
| Privacy purpose strings too short | 5.1.1 | ⚠️ Warning |
| Privacy purpose strings with placeholder text | 5.1.1 | ❌ Blocker |
| Privacy purpose strings too generic | 5.1.1 | ⚠️ Warning |
| NSAllowsArbitraryLoads enabled | - | ⚠️ Warning |
| Bundle ID / version configuration | - | ℹ️ Info |

### Android Checks (Google Play)

| Check | Requirement | Severity |
|-------|-------------|----------|
| targetSdk < 34 | Aug 2025 policy | ❌ Blocker |
| targetSdk = 34 (new apps need 35) | Aug 2025 policy | ⚠️ Warning |
| Missing signing configuration | Release builds | ⚠️ Warning |
| key.properties not in .gitignore | Security | ⚠️ Warning |

### General Checks (Both Platforms)

| Check | Requirement | Severity |
|-------|-------------|----------|
| Login exists but no account deletion | iOS 5.1.1(v), Play Policy | ❌ Blocker |
| IAP exists but no restore purchases | iOS 3.1.1 | ❌ Blocker |
| No privacy policy in app | Both stores | ⚠️ Warning |
| Flutter 3.24.3-3.24.4 (iOS API issues) | iOS 2.5.1 | ❌ Blocker |

## Screenshot Requirements

The script provides a manual checklist for screenshots.

### iOS Screenshots (2025)

| Device | Dimensions | Required? |
|--------|------------|-----------|
| **iPhone 6.9"** (16 Pro Max) | 1320 × 2868 px | ✅ Required |
| iPhone 6.7" (15 Pro Max) | 1290 × 2796 px | Auto-scaled |
| **iPad 13"** | 2064 × 2752 px | ✅ If iPad app |

- Max 10 screenshots per device
- First 3 shown in search results (most important!)
- Format: JPEG or PNG, no transparency, max 8MB

### Android Screenshots (2025)

| Device | Dimensions | Required? |
|--------|------------|-----------|
| **Phone** | 1080 × 1920 (or 9:16) | ✅ Min 2 total |
| 7" Tablet | 1200 × 1920 | If supported |
| 10" Tablet | 1600 × 2560 | If supported |

- Max 8 screenshots per device type
- Aspect ratio must not exceed 2:1
- Format: JPEG or PNG, **no transparency**, max 8MB
- **No device frames** (unlike iOS)

## Expo-Specific Notes

### With Prebuild (Recommended)

After running `npx expo prebuild`, the script checks:
- `ios/<ProjectName>/Info.plist` - Full native checks
- `android/app/build.gradle` - Full native checks

### Without Prebuild

If no `ios/` or `android/` directories exist, the script checks:
- `app.json` → `ios.bundleIdentifier`
- `app.json` → `android.package`  
- `app.json` → `ios.infoPlist` overrides

The script will suggest running `npx expo prebuild` for complete checks.

### app.json Configuration

```json
{
  "expo": {
    "ios": {
      "bundleIdentifier": "com.yourcompany.yourapp",
      "infoPlist": {
        "NSCameraUsageDescription": "Take photos of documents to upload"
      }
    },
    "android": {
      "package": "com.yourcompany.yourapp"
    }
  }
}
```

## Flutter-Specific Notes

### Known Problematic Versions

| Version | Issue | Solution |
|---------|-------|----------|
| 3.24.3 | Uses non-public iOS APIs | Upgrade to 3.24.5+ |
| 3.24.4 | Uses non-public iOS APIs | Upgrade to 3.24.5+ |

### Common Flutter Issues

1. **UIBackgroundModes audio** - Often added by Firebase plugins but not needed for push notifications
2. **Generic privacy strings** - Flutter templates have placeholder text
3. **Release mode crashes** - Always test `flutter build` not just `flutter run`

## Output Format

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                     APP STORE PRE-CHECK VALIDATOR                         ║
╚═══════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────┐
│  Expo Project: my-app                       │
│  SDK Version: 51.0.0                        │
│  Prebuild: ✓ Native directories exist       │
└─────────────────────────────────────────────┘

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   iOS CHECKS (Apple App Store)                                           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ UIBackgroundModes (Guideline 2.5.4)
▸ Privacy Purpose Strings (Guideline 5.1.1)  
▸ App Transport Security (ATS)
▸ App Version Info

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   ANDROID CHECKS (Google Play Store)                                     ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Target SDK Level
▸ Release Signing Configuration
▸ App Version Info
▸ Code Shrinking (R8/ProGuard)

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   GENERAL CHECKS (Both Platforms)                                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Account Management (deletion required)
▸ In-App Purchases (restore required)
▸ Privacy Policy

╔═══════════════════════════════════════════════════════════════════════════╗
║                          iOS SUMMARY                                      ║
╚═══════════════════════════════════════════════════════════════════════════╝
❌ BLOCKERS / ⚠️ WARNINGS / ✅ PASSED
📋 MANUAL CHECKLIST

╔═══════════════════════════════════════════════════════════════════════════╗
║                        ANDROID SUMMARY                                    ║
╚═══════════════════════════════════════════════════════════════════════════╝
❌ BLOCKERS / ⚠️ WARNINGS / ✅ PASSED
📋 MANUAL CHECKLIST

╔═══════════════════════════════════════════════════════════════════════════╗
║                        GENERAL SUMMARY                                    ║
╚═══════════════════════════════════════════════════════════════════════════╝
❌ BLOCKERS / ⚠️ WARNINGS / ✅ PASSED
📋 MANUAL CHECKLIST

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              FINAL VERDICT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  iOS:          X blockers   X warnings   X passed
  Android:      X blockers   X warnings   X passed
  General:      X blockers   X warnings   X passed
  ─────────────────────────────────────────────────────────
  TOTAL:        X blockers   X warnings   X passed

🚫 NOT READY / ⚠️ REVIEW WARNINGS / ✅ AUTOMATED CHECKS PASSED
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed (or warnings only) |
| 1 | Blockers found - do not submit |

## Common Fixes

### UIBackgroundModes "audio" (iOS)

```xml
<!-- ios/Runner/Info.plist or ios/<AppName>/Info.plist -->
<!-- REMOVE 'audio' if not a streaming app -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>  <!-- DELETE THIS LINE -->
    <string>remote-notification</string>  <!-- This one is OK -->
</array>
```

For Expo, remove from `app.json`:
```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "UIBackgroundModes": ["remote-notification"]  // Remove "audio"
      }
    }
  }
}
```

### Generic Privacy Strings (iOS)

```xml
<!-- BAD -->
<key>NSCameraUsageDescription</key>
<string>Camera access needed</string>

<!-- GOOD -->
<key>NSCameraUsageDescription</key>
<string>Take photos of receipts to attach to your expense reports</string>
```

For Expo in `app.json`:
```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "NSCameraUsageDescription": "Take photos of receipts to attach to your expense reports"
      }
    }
  }
}
```

### Account Deletion (Both)

Add a "Delete Account" option in Settings or Profile screen that:
1. Clearly explains what will be deleted
2. Requires confirmation
3. Actually deletes the account and data

### Restore Purchases (iOS)

Add a visible "Restore Purchases" button on your paywall or in Settings that calls:

```dart
// Flutter (in_app_purchase)
await InAppPurchase.instance.restorePurchases();
```

```javascript
// Expo/React Native (react-native-iap)
await RNIap.getAvailablePurchases();
```

## References

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policy Center](https://support.google.com/googleplay/android-developer/answer/9859455)
- [App Store Screenshot Specs](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [Play Store Screenshot Requirements](https://support.google.com/googleplay/android-developer/answer/9866151)