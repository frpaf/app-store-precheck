---
name: precheck
description: Pre-submission validation for Flutter/mobile apps before App Store and Google Play submission. Use when preparing to submit an app for review or checking compliance.
argument-hint: "[--ios-only|--android-only] [--verbose]"
user-invocable: true
disable-model-invocation: false
context: fork
allowed-tools: Bash, Read
---

# App Store Pre-Check

Validates Flutter (and other mobile) apps against Apple App Store and Google Play Store requirements before submission. Catches the most common rejection reasons automatically.

## When to Use

- Before submitting a new app to App Store or Play Store
- Before submitting an update
- When preparing for app review after previous rejection
- When auditing an existing app for compliance

## Quick Start

Run from the Flutter project root:

```bash
bash scripts/precheck.sh
```

Or invoke via Claude: "Pre-check my app for App Store submission"

## Workflow

1. **Identify project type**: Flutter, React Native/Expo, or native
2. **Locate project root**: Find `pubspec.yaml` (Flutter), `package.json` (RN/Expo)
3. **Run automated scans** on:
   - `ios/Runner/Info.plist`
   - `android/app/build.gradle` or `android/app/build.gradle.kts`
   - `android/app/src/main/AndroidManifest.xml`
   - Source code for feature detection
4. **Generate checklist** for manual verification items
5. **Output report** with blockers, warnings, and recommendations

---

## iOS Checks (Info.plist)

### 1. UIBackgroundModes Audit (Guideline 2.5.4)

**Critical**: The `audio` background mode is ONLY for apps that play persistent audio (music players, streaming apps). Custom notification sounds do NOT qualify.

```bash
# Check for UIBackgroundModes
plutil -extract UIBackgroundModes xml1 -o - ios/Runner/Info.plist 2>/dev/null || echo "No UIBackgroundModes"
```

**Flag if**:
- `audio` is present but app doesn't stream music/audio
- `voip` is present but app doesn't make VoIP calls
- `location` is present without clear location-based features

**Recommendation**: Remove unused background modes. Firebase push notifications handle notification sounds without `audio` mode.

### 2. Privacy Purpose Strings (Guideline 5.1.1)

All `NS*UsageDescription` keys must contain:
- **Specific explanation** of why the permission is needed
- **Concrete example** of how it's used in the app

**Bad**: `"This app needs camera access"`
**Good**: `"Take photos to attach to your daily activity reports and share with caregivers"`

**Required keys to check** (if corresponding APIs are used):

| Key | Required When |
|-----|---------------|
| `NSCameraUsageDescription` | Camera access |
| `NSPhotoLibraryUsageDescription` | Reading photos |
| `NSPhotoLibraryAddUsageDescription` | Saving photos |
| `NSMicrophoneUsageDescription` | Audio recording |
| `NSLocationWhenInUseUsageDescription` | Location (foreground) |
| `NSLocationAlwaysUsageDescription` | Location (background) |
| `NSContactsUsageDescription` | Contacts access |
| `NSCalendarsUsageDescription` | Calendar access |
| `NSFaceIDUsageDescription` | Face ID authentication |
| `NSBluetoothAlwaysUsageDescription` | Bluetooth |
| `NSBluetoothPeripheralUsageDescription` | Bluetooth peripherals |
| `NSSpeechRecognitionUsageDescription` | Speech recognition |
| `NSMotionUsageDescription` | Motion/fitness data |
| `NSHealthShareUsageDescription` | HealthKit read |
| `NSHealthUpdateUsageDescription` | HealthKit write |

**Validation rules**:
- String length > 20 characters (reject generic text)
- Contains action verb (take, capture, record, access, save)
- No placeholder text ("Example:", "TODO", "You should fill this in")

### 3. App Transport Security

**Flag if**:
- `NSAllowsArbitraryLoads` is `true` without justification
- HTTP domains are allowed without reason

---

## iOS Checks (App Features)

### 4. Account Deletion Requirement (Guideline 5.1.1(v))

**Rule**: If your app allows account creation, you MUST provide in-app account deletion.

**Check**:
- Search codebase for account creation flows (signIn, login, createUser, FirebaseAuth)
- Verify deletion flow exists (deleteUser, deleteAccount)
- Deletion must delete data, not just deactivate

**Not acceptable**:
- "Email support to delete account"
- Redirect to website only
- Deactivation without data deletion

### 5. Restore Purchases (Guideline 3.1.1)

**Rule**: If you have non-consumable IAP or subscriptions, you MUST have a "Restore Purchases" button.

**Check**:
- Look for `in_app_purchase` or `purchases_flutter` packages
- Verify restore button exists on paywall/settings
- Test: Buy → Reinstall → Restore → Content unlocks

### 6. Privacy Policy Accessibility

**Required locations**:
1. App Store Connect metadata
2. Inside app (typically Settings or About screen)

---

## Android Checks (build.gradle)

### 7. Target SDK Level

**2025/2026 Requirements**:
- New apps: `targetSdk 35` (Android 15) required
- Updates: `targetSdk 34` minimum

```bash
# Check compileSdk and targetSdk
grep -E "(compileSdk|targetSdk)" android/app/build.gradle*
```

**Flag if**:
- `targetSdk < 34` for updates
- `targetSdk < 35` for new apps

### 8. Build Format (AAB Required)

Google Play requires Android App Bundle (`.aab`), not APK.

```bash
# Verify AAB is being built
flutter build appbundle --release
```

### 9. Signing Configuration

**Check for Play App Signing enrollment**:
- `signingConfigs` block in build.gradle
- Upload key vs signing key configuration
- Key properties file exists

### 10. 16KB Page Size Support (Android 15)

New requirement for Android 15 compatibility. Check native libraries.

---

## Android Checks (Metadata)

### 11. Store Listing Limits

| Field | Limit |
|-------|-------|
| Title | 30 characters max |
| Short description | 80 characters max |
| Full description | 4000 characters max |

### 12. Data Safety Form

Must accurately reflect:
- Data collected by app AND all SDKs
- Data shared with third parties
- Data handling practices

**Google cross-references** with actual app behavior. Mismatches cause rejection.

### 13. Content Rating

Complete the questionnaire honestly. Incorrect ratings → rejection or removal.

---

## Both Platforms

### 14. Backend Availability

**Critical**: Your API must be UP during review.

**Checklist**:
- [ ] API endpoints accessible
- [ ] Test accounts populated with data
- [ ] No maintenance windows during review period
- [ ] Error handling for network failures (don't show blank screen)

### 15. Screenshot/Metadata Accuracy (Guideline 2.3)

- Screenshots must show actual app UI
- Description must match available features
- No promises of features not yet implemented

### 16. User-Generated Content (Guideline 1.2)

If your app has UGC (comments, posts, profiles, uploads):

**Required**:
- [ ] Report content mechanism
- [ ] Block user mechanism
- [ ] Content filtering/moderation
- [ ] Contact information for support

### 17. AI Transparency (2025 Requirement)

If using external AI services:
- Disclose AI usage to users
- Get user consent for AI processing
- Document in privacy policy

---

## Output Format

Generate a report with three sections:

### ❌ Blockers (Will cause rejection)
- Issues that must be fixed before submission

### ⚠️ Warnings (May cause rejection)
- Issues that could trigger review depending on reviewer

### ✅ Passed
- Checks that passed validation

### 📋 Manual Checklist
- Items requiring human verification

---

## Common Rejection Scenarios

| Issue | Guideline | Resolution |
|-------|-----------|------------|
| UIBackgroundModes audio without streaming | 2.5.4 | Remove "audio" from Info.plist |
| Generic camera purpose string | 5.1.1 | Add specific usage example |
| Backend down during review | 2.1 | Ensure API availability |
| Missing privacy policy for Apple TV | N/A | Add to App Store Connect |
| Android signing not configured | N/A | Enroll in Play App Signing |
| Account creation without deletion | 5.1.1(v) | Add in-app account deletion |
| IAP without restore purchases | 3.1.1 | Add "Restore Purchases" button |
| targetSdk too low | Google Play | Update to 34+ (35 for new apps) |

---

## Arguments

$ARGUMENTS

If no arguments provided, run full check on both iOS and Android.

---

## References

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Developer Policy](https://play.google.com/about/developer-content-policy/)
- [Apple Info.plist Key Reference](https://developer.apple.com/documentation/bundleresources/information_property_list)
- [Offering Account Deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [In-App Purchase Guidelines](https://developer.apple.com/in-app-purchase/)