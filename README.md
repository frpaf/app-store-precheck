# App Store Pre-Check Plugin

Pre-submission validation for **Flutter** and **Expo** apps before App Store and Google Play submission.

Catches common rejection issues automatically so you don't waste days in review limbo.

## Why?

App Store reviews can take 1-4 days. Getting rejected for something simple like:
- ❌ UIBackgroundModes "audio" (you don't need it for push notifications!)
- ❌ Generic camera permission string ("Camera access needed")
- ❌ Missing account deletion (required since 2022)
- ❌ No "Restore Purchases" button

...means another 1-4 day wait. This plugin catches these before you submit.

## Supported Frameworks

| Framework | Detection | Build Workflow |
|-----------|-----------|----------------|
| **Flutter** | `pubspec.yaml` | `flutter build ios/apk` |
| **Expo** | `app.json` | `npx expo prebuild` → `npx expo run:ios/android` |
| **React Native** | `package.json` | Native builds |

## Quick Start

```bash
cd your-flutter-or-expo-project

# For Expo: run prebuild first
npx expo prebuild

# Run precheck
./precheck.sh
```

## What It Checks

### iOS (Apple App Store)

| Issue | What Happens |
|-------|--------------|
| UIBackgroundModes "audio" | ❌ Rejected (Guideline 2.5.4) |
| Short/generic privacy strings | ❌ Rejected (Guideline 5.1.1) |
| Placeholder text in permissions | ❌ Rejected |
| NSAllowsArbitraryLoads | ⚠️ May need justification |

### Android (Google Play)

| Issue | What Happens |
|-------|--------------|
| targetSdk < 34 | ❌ Rejected (Aug 2025 requirement) |
| targetSdk 34 for new apps | ⚠️ New apps need 35 |
| Missing signing config | ⚠️ Build will fail |

### General (Both Stores)

| Issue | What Happens |
|-------|--------------|
| Login but no account deletion | ❌ Rejected (iOS 5.1.1(v)) |
| IAP but no restore purchases | ❌ Rejected (iOS 3.1.1) |
| No privacy policy in app | ⚠️ Required by both stores |
| Flutter 3.24.3-3.24.4 | ❌ iOS rejects (non-public APIs) |

## Output

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                     APP STORE PRE-CHECK VALIDATOR                         ║
║                       Flutter & Expo Edition                              ║
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
  ❌ BLOCKER: 'audio' background mode declared
     Only valid for music streaming/playback apps.
     Fix: Remove 'audio' from UIBackgroundModes

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              FINAL VERDICT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  iOS:          1 blockers   1 warnings   3 passed
  Android:      0 blockers   0 warnings   5 passed
  General:      0 blockers   1 warnings   2 passed
  ─────────────────────────────────────────────────────────
  TOTAL:        1 blockers   2 warnings  10 passed

╔═══════════════════════════════════════════════════════════════════════════╗
║   🚫 NOT READY FOR SUBMISSION                                             ║
║   Fix 1 blocker(s) before submitting to stores                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## Screenshot Requirements

Included in manual checklists:

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
cp precheck.sh /path/to/your/project/
chmod +x precheck.sh

# Run
./precheck.sh
```

## License

MIT