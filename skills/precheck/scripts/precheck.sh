#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# APP STORE PRE-CHECK - Flutter & Expo Edition
# Pre-submission validation for App Store (iOS) and Google Play (Android)
#
# Supports:
#   - Flutter projects (pubspec.yaml)
#   - Expo projects with prebuild (npx expo run:ios/android)
#   - React Native projects
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ───────────────────────────────────────────────────────────────────────────────
# Counters and Arrays
# ───────────────────────────────────────────────────────────────────────────────

# iOS
IOS_BLOCKERS=0
IOS_WARNINGS=0
IOS_PASSED=0
declare -a IOS_BLOCKER_MSGS
declare -a IOS_WARNING_MSGS

# Android
ANDROID_BLOCKERS=0
ANDROID_WARNINGS=0
ANDROID_PASSED=0
declare -a ANDROID_BLOCKER_MSGS
declare -a ANDROID_WARNING_MSGS

# General
GENERAL_BLOCKERS=0
GENERAL_WARNINGS=0
GENERAL_PASSED=0
declare -a GENERAL_BLOCKER_MSGS
declare -a GENERAL_WARNING_MSGS

# Project info
PROJECT_TYPE=""
PROJECT_NAME=""

# ───────────────────────────────────────────────────────────────────────────────
# Header
# ───────────────────────────────────────────────────────────────────────────────

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                     APP STORE PRE-CHECK VALIDATOR                         ║"
echo "║                       Flutter & Expo Edition                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# ───────────────────────────────────────────────────────────────────────────────
# Project Detection
# ───────────────────────────────────────────────────────────────────────────────

if [ -f "pubspec.yaml" ]; then
    PROJECT_TYPE="flutter"
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | sed 's/name: //' | tr -d ' ')
    FLUTTER_VERSION=$(grep "sdk:" pubspec.yaml | head -1 | sed 's/.*sdk: //' | tr -d ' "')
    echo -e "${MAGENTA}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${NC}  ${BOLD}Flutter Project${NC}: $PROJECT_NAME"
    if [ -n "$FLUTTER_VERSION" ]; then
        echo -e "${MAGENTA}│${NC}  SDK Constraint: $FLUTTER_VERSION"
    fi
    echo -e "${MAGENTA}└─────────────────────────────────────────────┘${NC}"
    
elif [ -f "app.json" ] && grep -q "expo" app.json 2>/dev/null; then
    PROJECT_TYPE="expo"
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
    EXPO_SDK=$(grep -o '"sdkVersion"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | sed 's/.*: *"//' | sed 's/"//')
    
    # Check if prebuild has been run
    HAS_PREBUILD=false
    [ -d "ios" ] && [ -d "android" ] && HAS_PREBUILD=true
    
    echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${BOLD}Expo Project${NC}: $PROJECT_NAME"
    if [ -n "$EXPO_SDK" ]; then
        echo -e "${BLUE}│${NC}  SDK Version: $EXPO_SDK"
    fi
    if [ "$HAS_PREBUILD" = true ]; then
        echo -e "${BLUE}│${NC}  Prebuild: ${GREEN}✓ Native directories exist${NC}"
    else
        echo -e "${BLUE}│${NC}  Prebuild: ${YELLOW}✗ Run 'npx expo prebuild' first${NC}"
    fi
    echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"
    
elif [ -f "package.json" ] && grep -q "react-native" package.json 2>/dev/null; then
    PROJECT_TYPE="react-native"
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1 | sed 's/.*: *"//' | sed 's/"//')
    echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}React Native Project${NC}: $PROJECT_NAME"
    echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
else
    echo -e "${RED}❌ Could not detect Flutter or Expo/React Native project${NC}"
    echo "   Run this script from your project root directory."
    exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                              iOS CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   iOS CHECKS (Apple App Store)                                           ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

# Find Info.plist
PLIST=""
if [ "$PROJECT_TYPE" = "flutter" ]; then
    [ -f "ios/Runner/Info.plist" ] && PLIST="ios/Runner/Info.plist"
elif [ "$PROJECT_TYPE" = "expo" ]; then
    # Expo prebuild generates ios/<ProjectName>/Info.plist
    if [ -d "ios" ]; then
        # Find Info.plist in ios directory
        PLIST=$(find ios -name "Info.plist" -path "*/ios/*/Info.plist" 2>/dev/null | head -1)
        [ -z "$PLIST" ] && PLIST=$(find ios -name "Info.plist" 2>/dev/null | head -1)
    fi
else
    # React Native
    PLIST=$(find ios -name "Info.plist" 2>/dev/null | grep -v "Tests" | head -1)
fi

if [ -z "$PLIST" ]; then
    if [ "$PROJECT_TYPE" = "expo" ]; then
        echo -e "${YELLOW}⚠️  No ios/ directory found${NC}"
        echo -e "   Run ${CYAN}npx expo prebuild${NC} to generate native projects"
        echo ""
        
        # Check app.json for iOS config instead
        echo "▸ Expo iOS Configuration (app.json)"
        
        # Check for iOS bundle identifier
        IOS_BUNDLE=$(grep -o '"bundleIdentifier"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | sed 's/.*: *"//' | sed 's/"//')
        if [ -n "$IOS_BUNDLE" ]; then
            echo -e "  ${GREEN}✅${NC} Bundle ID: ${CYAN}$IOS_BUNDLE${NC}"
            ((IOS_PASSED++))
        else
            echo -e "  ${RED}❌ BLOCKER: No ios.bundleIdentifier in app.json${NC}"
            IOS_BLOCKER_MSGS+=("Missing ios.bundleIdentifier in app.json")
            ((IOS_BLOCKERS++))
        fi
        
        # Check for infoPlist overrides in app.json
        if grep -q '"infoPlist"' app.json 2>/dev/null; then
            echo -e "  ${CYAN}ℹ️${NC}  Custom infoPlist overrides found in app.json"
            
            # Check for UIBackgroundModes
            if grep -q '"UIBackgroundModes"' app.json 2>/dev/null; then
                if grep -A5 '"UIBackgroundModes"' app.json | grep -q '"audio"'; then
                    echo -e "  ${RED}❌ BLOCKER: UIBackgroundModes 'audio' in app.json${NC}"
                    echo "     Remove from ios.infoPlist unless streaming app"
                    IOS_BLOCKER_MSGS+=("UIBackgroundModes 'audio' in app.json - remove unless streaming app")
                    ((IOS_BLOCKERS++))
                fi
            fi
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠️  No Info.plist found - skipping iOS native checks${NC}"
        IOS_WARNING_MSGS+=("No Info.plist found")
        ((IOS_WARNINGS++))
    fi
else
    echo -e "${BLUE}Found:${NC} $PLIST"
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # iOS Check 1: UIBackgroundModes (Guideline 2.5.4)
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ UIBackgroundModes (Guideline 2.5.4)"
    
    BG_MODES=$(plutil -extract UIBackgroundModes xml1 -o - "$PLIST" 2>/dev/null || echo "")
    
    if [ -n "$BG_MODES" ]; then
        FOUND_ISSUE=false
        
        if echo "$BG_MODES" | grep -q ">audio<"; then
            echo -e "  ${RED}❌ BLOCKER: 'audio' background mode declared${NC}"
            echo "     Only valid for music streaming/playback apps."
            echo "     Push notification sounds work WITHOUT this."
            echo "     ${BOLD}Fix:${NC} Remove 'audio' from UIBackgroundModes in Info.plist"
            IOS_BLOCKER_MSGS+=("UIBackgroundModes 'audio' - remove unless streaming app")
            ((IOS_BLOCKERS++))
            FOUND_ISSUE=true
        fi
        
        if echo "$BG_MODES" | grep -q ">voip<"; then
            echo -e "  ${YELLOW}⚠️  WARNING: 'voip' background mode declared${NC}"
            echo "     Only valid for VoIP calling apps (WhatsApp, Zoom, etc.)"
            IOS_WARNING_MSGS+=("UIBackgroundModes 'voip' - verify this is needed")
            ((IOS_WARNINGS++))
            FOUND_ISSUE=true
        fi
        
        if echo "$BG_MODES" | grep -q ">location<"; then
            echo -e "  ${YELLOW}⚠️  WARNING: 'location' background mode declared${NC}"
            echo "     Requires clear user-facing justification"
            IOS_WARNING_MSGS+=("UIBackgroundModes 'location' - ensure justified")
            ((IOS_WARNINGS++))
            FOUND_ISSUE=true
        fi
        
        if [ "$FOUND_ISSUE" = false ]; then
            echo -e "  ${GREEN}✅${NC} Background modes look OK"
            ((IOS_PASSED++))
        fi
    else
        echo -e "  ${GREEN}✅${NC} No UIBackgroundModes declared"
        ((IOS_PASSED++))
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # iOS Check 2: Privacy Purpose Strings (Guideline 5.1.1)
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ Privacy Purpose Strings (Guideline 5.1.1)"
    echo "  Apple requires specific descriptions with examples of usage"
    echo ""
    
    declare -A USAGE_KEYS=(
        ["NSCameraUsageDescription"]="Camera"
        ["NSPhotoLibraryUsageDescription"]="Photo Library (read)"
        ["NSPhotoLibraryAddUsageDescription"]="Photo Library (write)"
        ["NSMicrophoneUsageDescription"]="Microphone"
        ["NSLocationWhenInUseUsageDescription"]="Location (in use)"
        ["NSLocationAlwaysUsageDescription"]="Location (always)"
        ["NSContactsUsageDescription"]="Contacts"
        ["NSCalendarsUsageDescription"]="Calendars"
        ["NSFaceIDUsageDescription"]="Face ID"
        ["NSBluetoothAlwaysUsageDescription"]="Bluetooth"
        ["NSSpeechRecognitionUsageDescription"]="Speech Recognition"
        ["NSMotionUsageDescription"]="Motion"
        ["NSUserTrackingUsageDescription"]="App Tracking (ATT)"
    )

    FOUND_KEYS=0
    for key in "${!USAGE_KEYS[@]}"; do
        friendly_name="${USAGE_KEYS[$key]}"
        value=$(plutil -extract "$key" raw -o - "$PLIST" 2>/dev/null || echo "")
        
        if [ -n "$value" ]; then
            ((FOUND_KEYS++))
            len=${#value}
            
            # Check for placeholder text
            if echo "$value" | grep -qiE "(example|todo|fill this|placeholder|you should|describe|enter|CHANGEME|REPLACE)"; then
                echo -e "  ${RED}❌ BLOCKER: $friendly_name - contains placeholder text${NC}"
                echo "     \"$value\""
                IOS_BLOCKER_MSGS+=("$key contains placeholder text")
                ((IOS_BLOCKERS++))
            # Check minimum length
            elif [ $len -lt 20 ]; then
                echo -e "  ${YELLOW}⚠️  WARNING: $friendly_name - too short ($len chars)${NC}"
                echo "     \"$value\""
                echo "     ${CYAN}Tip: Include a specific example of how it's used${NC}"
                IOS_WARNING_MSGS+=("$key too short - add specific usage example")
                ((IOS_WARNINGS++))
            # Check for generic starts
            elif echo "$value" | grep -qiE "^(this app needs|we need|required for|access to|needs access|used for|for |to )"; then
                echo -e "  ${YELLOW}⚠️  WARNING: $friendly_name - may be too generic${NC}"
                echo "     \"$value\""
                echo "     ${CYAN}Tip: Be specific, e.g., \"Take photos of receipts to attach to expense reports\"${NC}"
                IOS_WARNING_MSGS+=("$key may be too generic - be more specific")
                ((IOS_WARNINGS++))
            else
                echo -e "  ${GREEN}✅${NC} $friendly_name ($len chars)"
                ((IOS_PASSED++))
            fi
        fi
    done
    
    if [ $FOUND_KEYS -eq 0 ]; then
        echo -e "  ${CYAN}ℹ️${NC}  No privacy permission strings found"
        echo "     (OK if your app doesn't use camera, location, etc.)"
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # iOS Check 3: App Transport Security
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ App Transport Security (ATS)"
    
    ATS=$(plutil -extract NSAppTransportSecurity xml1 -o - "$PLIST" 2>/dev/null || echo "")
    
    if [ -n "$ATS" ]; then
        if echo "$ATS" | grep -q "NSAllowsArbitraryLoads.*true"; then
            echo -e "  ${YELLOW}⚠️  WARNING: NSAllowsArbitraryLoads is enabled${NC}"
            echo "     This disables HTTPS requirement for all connections."
            echo "     May require justification during review."
            IOS_WARNING_MSGS+=("NSAllowsArbitraryLoads enabled - may need justification")
            ((IOS_WARNINGS++))
        else
            echo -e "  ${GREEN}✅${NC} ATS configuration looks secure"
            ((IOS_PASSED++))
        fi
    else
        echo -e "  ${GREEN}✅${NC} Default ATS (HTTPS required)"
        ((IOS_PASSED++))
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # iOS Check 4: Version Info
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ App Version Info"
    
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$PLIST" 2>/dev/null || echo "")
    VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST" 2>/dev/null || echo "")
    BUILD=$(plutil -extract CFBundleVersion raw -o - "$PLIST" 2>/dev/null || echo "")
    DISPLAY_NAME=$(plutil -extract CFBundleDisplayName raw -o - "$PLIST" 2>/dev/null || echo "")
    
    [ -n "$BUNDLE_ID" ] && echo -e "  Bundle ID: ${CYAN}$BUNDLE_ID${NC}"
    [ -n "$DISPLAY_NAME" ] && echo -e "  Display Name: ${CYAN}$DISPLAY_NAME${NC}"
    [ -n "$VERSION" ] && [ -n "$BUILD" ] && echo -e "  Version: ${CYAN}$VERSION${NC} (Build: ${CYAN}$BUILD${NC})"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                            ANDROID CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   ANDROID CHECKS (Google Play Store)                                     ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

# Find build.gradle
GRADLE=""
if [ "$PROJECT_TYPE" = "flutter" ]; then
    [ -f "android/app/build.gradle.kts" ] && GRADLE="android/app/build.gradle.kts"
    [ -f "android/app/build.gradle" ] && GRADLE="android/app/build.gradle"
elif [ "$PROJECT_TYPE" = "expo" ] || [ "$PROJECT_TYPE" = "react-native" ]; then
    [ -f "android/app/build.gradle" ] && GRADLE="android/app/build.gradle"
fi

if [ -z "$GRADLE" ]; then
    if [ "$PROJECT_TYPE" = "expo" ]; then
        echo -e "${YELLOW}⚠️  No android/ directory found${NC}"
        echo -e "   Run ${CYAN}npx expo prebuild${NC} to generate native projects"
        echo ""
        
        # Check app.json for Android config
        echo "▸ Expo Android Configuration (app.json)"
        
        ANDROID_PACKAGE=$(grep -o '"package"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
        if [ -n "$ANDROID_PACKAGE" ]; then
            echo -e "  ${GREEN}✅${NC} Package: ${CYAN}$ANDROID_PACKAGE${NC}"
            ((ANDROID_PASSED++))
        else
            echo -e "  ${RED}❌ BLOCKER: No android.package in app.json${NC}"
            ANDROID_BLOCKER_MSGS+=("Missing android.package in app.json")
            ((ANDROID_BLOCKERS++))
        fi
        
        # Check version code
        ANDROID_VERSION_CODE=$(grep -o '"versionCode"[[:space:]]*:[[:space:]]*[0-9]*' app.json 2>/dev/null | sed 's/.*: *//')
        if [ -n "$ANDROID_VERSION_CODE" ]; then
            echo -e "  ${GREEN}✅${NC} Version Code: ${CYAN}$ANDROID_VERSION_CODE${NC}"
            ((ANDROID_PASSED++))
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠️  No build.gradle found - skipping Android native checks${NC}"
        ANDROID_WARNING_MSGS+=("No build.gradle found")
        ((ANDROID_WARNINGS++))
    fi
else
    echo -e "${BLUE}Found:${NC} $GRADLE"
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # Android Check 1: Target SDK Level
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ Target SDK Level (Google Play Requirement - Aug 2025)"
    echo "  New apps: targetSdk 35 (Android 15)"
    echo "  Updates:  targetSdk 34 (Android 14) minimum"
    echo ""
    
    # Try different patterns for Kotlin DSL and Groovy
    TARGET_SDK=$(grep -oP "targetSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    [ -z "$TARGET_SDK" ] && TARGET_SDK=$(grep -oP "targetSdkVersion\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    
    COMPILE_SDK=$(grep -oP "compileSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    [ -z "$COMPILE_SDK" ] && COMPILE_SDK=$(grep -oP "compileSdkVersion\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    
    MIN_SDK=$(grep -oP "minSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    [ -z "$MIN_SDK" ] && MIN_SDK=$(grep -oP "minSdkVersion\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    
    if [ -n "$TARGET_SDK" ]; then
        if [ "$TARGET_SDK" -lt 34 ]; then
            echo -e "  ${RED}❌ BLOCKER: targetSdk $TARGET_SDK is below minimum${NC}"
            echo "     Google Play requires targetSdk 34+ for updates"
            echo "     New apps require targetSdk 35+"
            ANDROID_BLOCKER_MSGS+=("targetSdk $TARGET_SDK - must be 34+ (35+ for new apps)")
            ((ANDROID_BLOCKERS++))
        elif [ "$TARGET_SDK" -lt 35 ]; then
            echo -e "  ${YELLOW}⚠️  WARNING: targetSdk $TARGET_SDK${NC}"
            echo "     OK for existing app updates"
            echo "     New apps require targetSdk 35"
            ANDROID_WARNING_MSGS+=("targetSdk 34 - new apps require 35")
            ((ANDROID_WARNINGS++))
        else
            echo -e "  ${GREEN}✅${NC} targetSdk $TARGET_SDK meets requirements"
            ((ANDROID_PASSED++))
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC}  Could not determine targetSdk"
        ANDROID_WARNING_MSGS+=("Could not determine targetSdk from build.gradle")
        ((ANDROID_WARNINGS++))
    fi
    
    [ -n "$COMPILE_SDK" ] && echo -e "  compileSdk: ${CYAN}$COMPILE_SDK${NC}"
    [ -n "$MIN_SDK" ] && echo -e "  minSdk: ${CYAN}$MIN_SDK${NC}"
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # Android Check 2: Signing Configuration
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ Release Signing Configuration"
    
    if grep -q "signingConfigs" "$GRADLE" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} signingConfigs block found"
        ((ANDROID_PASSED++))
        
        if grep -qE "release\s*\{" "$GRADLE" && grep -A10 -E "release\s*\{" "$GRADLE" | grep -q "signingConfig"; then
            echo -e "  ${GREEN}✅${NC} Release build uses signing config"
            ((ANDROID_PASSED++))
        else
            echo -e "  ${YELLOW}⚠️${NC}  Verify release build has signingConfig"
            ANDROID_WARNING_MSGS+=("Verify release build uses signingConfig")
            ((ANDROID_WARNINGS++))
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC}  No signingConfigs in build.gradle"
        echo "     Ensure Play App Signing is configured in Play Console"
        ANDROID_WARNING_MSGS+=("No signingConfigs - ensure Play App Signing enrolled")
        ((ANDROID_WARNINGS++))
    fi
    
    # Check for key.properties (Flutter) or keystore reference
    if [ -f "android/key.properties" ]; then
        echo -e "  ${GREEN}✅${NC} key.properties file exists"
        ((ANDROID_PASSED++))
        
        # Check it's in .gitignore
        if [ -f ".gitignore" ] && grep -q "key.properties" .gitignore 2>/dev/null; then
            echo -e "  ${GREEN}✅${NC} key.properties is in .gitignore"
            ((ANDROID_PASSED++))
        else
            echo -e "  ${YELLOW}⚠️${NC}  Add key.properties to .gitignore!"
            ANDROID_WARNING_MSGS+=("key.properties should be in .gitignore")
            ((ANDROID_WARNINGS++))
        fi
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # Android Check 3: App Version Info
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ App Version Info"
    
    APP_ID=$(grep -oP "(applicationId|namespace)\s*[=:]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1)
    VERSION_NAME=$(grep -oP "versionName\s*[=:]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1)
    VERSION_CODE=$(grep -oP "versionCode\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    
    [ -n "$APP_ID" ] && echo -e "  Application ID: ${CYAN}$APP_ID${NC}"
    [ -n "$VERSION_NAME" ] && echo -e "  Version Name: ${CYAN}$VERSION_NAME${NC}"
    [ -n "$VERSION_CODE" ] && echo -e "  Version Code: ${CYAN}$VERSION_CODE${NC}"
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # Android Check 4: ProGuard/R8 (Code Shrinking)
    # ─────────────────────────────────────────────────────────────────────────
    echo "▸ Code Shrinking (R8/ProGuard)"
    
    if grep -qE "minifyEnabled\s*[=:]\s*true" "$GRADLE" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} minifyEnabled is true for release"
        ((ANDROID_PASSED++))
        
        if grep -qE "shrinkResources\s*[=:]\s*true" "$GRADLE" 2>/dev/null; then
            echo -e "  ${GREEN}✅${NC} shrinkResources is enabled"
            ((ANDROID_PASSED++))
        fi
    else
        echo -e "  ${CYAN}ℹ️${NC}  minifyEnabled not set (optional but reduces APK/AAB size)"
    fi
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                           GENERAL CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   GENERAL CHECKS (Both Platforms)                                        ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

# Determine source directory
if [ "$PROJECT_TYPE" = "flutter" ]; then
    SRC_DIR="lib"
    PKG_FILE="pubspec.yaml"
elif [ "$PROJECT_TYPE" = "expo" ] || [ "$PROJECT_TYPE" = "react-native" ]; then
    SRC_DIR="src"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="app"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="."
    PKG_FILE="package.json"
fi

# ─────────────────────────────────────────────────────────────────────────────
# General Check 1: Account Deletion (iOS 5.1.1(v), Google Play Policy)
# ─────────────────────────────────────────────────────────────────────────────
echo "▸ Account Management (Required: iOS 5.1.1(v), Google Play)"
echo "  If app has login/signup, must have account deletion option"
echo ""

HAS_LOGIN=false
HAS_DELETE=false

if [ -d "$SRC_DIR" ]; then
    # Check for login/auth functionality
    if grep -rqE "signIn|login|authenticate|FirebaseAuth|createUser|signUp|register|supabase.*auth|Auth0|useAuth|AuthContext" "$SRC_DIR" 2>/dev/null; then
        HAS_LOGIN=true
        echo -e "  ${CYAN}ℹ️${NC}  Account/login functionality detected"
    fi
    
    # Check for account deletion
    if grep -rqE "deleteUser|deleteAccount|delete.*account|account.*delet|removeAccount|closeAccount|accountDeletion" "$SRC_DIR" 2>/dev/null; then
        HAS_DELETE=true
    fi
fi

if [ "$HAS_LOGIN" = true ]; then
    if [ "$HAS_DELETE" = true ]; then
        echo -e "  ${GREEN}✅${NC} Account deletion functionality found"
        ((GENERAL_PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: Login exists but no account deletion${NC}"
        echo "     iOS requires in-app account deletion (Guideline 5.1.1(v))"
        echo "     Google Play also requires this for account-based apps"
        echo "     ${BOLD}Fix:${NC} Add account deletion in Settings/Profile"
        GENERAL_BLOCKER_MSGS+=("Account creation exists but no deletion found")
        ((GENERAL_BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  No account/login features detected"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# General Check 2: In-App Purchases (iOS 3.1.1)
# ─────────────────────────────────────────────────────────────────────────────
echo "▸ In-App Purchases (iOS 3.1.1 - Restore Purchases Required)"
echo ""

HAS_IAP=false
HAS_RESTORE=false

if [ -f "$PKG_FILE" ]; then
    # Flutter packages
    if [ "$PROJECT_TYPE" = "flutter" ]; then
        if grep -qE "in_app_purchase|purchases_flutter|flutter_inapp_purchase|revenue_cat" "$PKG_FILE" 2>/dev/null; then
            HAS_IAP=true
            echo -e "  ${CYAN}ℹ️${NC}  In-app purchase package detected"
        fi
    # Expo/RN packages
    else
        if grep -qE "react-native-iap|expo-in-app-purchases|react-native-purchases|revenue-cat|@revenuecat" "$PKG_FILE" 2>/dev/null; then
            HAS_IAP=true
            echo -e "  ${CYAN}ℹ️${NC}  In-app purchase package detected"
        fi
    fi
    
    # Check for restore functionality
    if [ -d "$SRC_DIR" ]; then
        if grep -rqE "restorePurchases|restore.*purchase|restoreTransactions|getPurchaseHistory|restoreCompletedTransactions" "$SRC_DIR" 2>/dev/null; then
            HAS_RESTORE=true
        fi
    fi
fi

if [ "$HAS_IAP" = true ]; then
    if [ "$HAS_RESTORE" = true ]; then
        echo -e "  ${GREEN}✅${NC} Restore purchases functionality found"
        ((GENERAL_PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: IAP exists but no restore purchases${NC}"
        echo "     iOS requires 'Restore Purchases' button for non-consumables"
        echo "     ${BOLD}Fix:${NC} Add visible Restore Purchases button on paywall/settings"
        GENERAL_BLOCKER_MSGS+=("IAP exists but no restore purchases functionality")
        ((GENERAL_BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  No in-app purchase packages detected"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# General Check 3: Privacy Policy
# ─────────────────────────────────────────────────────────────────────────────
echo "▸ Privacy Policy (Required: Both Stores)"
echo ""

FOUND_PRIVACY=false

if [ -d "$SRC_DIR" ]; then
    if grep -rqE "privacy.*policy|privacyPolicy|privacy_policy|PrivacyPolicy|privacyPolicyUrl" "$SRC_DIR" 2>/dev/null; then
        FOUND_PRIVACY=true
        echo -e "  ${GREEN}✅${NC} Privacy policy reference found in code"
        ((GENERAL_PASSED++))
    fi
fi

# Also check app.json for Expo
if [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
    if grep -qE "privacyPolicyUrl|privacy" app.json 2>/dev/null; then
        FOUND_PRIVACY=true
        echo -e "  ${GREEN}✅${NC} Privacy policy config found in app.json"
        ((GENERAL_PASSED++))
    fi
fi

if [ "$FOUND_PRIVACY" = false ]; then
    echo -e "  ${YELLOW}⚠️${NC}  No privacy policy link found in code"
    echo "     Should be accessible inside app (Settings/About)"
    echo "     Also required in App Store Connect & Play Console"
    GENERAL_WARNING_MSGS+=("Add privacy policy link inside app")
    ((GENERAL_WARNINGS++))
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# General Check 4: Flutter Version (if Flutter)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$PROJECT_TYPE" = "flutter" ]; then
    echo "▸ Flutter Version Check"
    
    # Check if flutter is available
    if command -v flutter &> /dev/null; then
        FLUTTER_VER=$(flutter --version 2>/dev/null | head -1 | grep -oP "Flutter \K[0-9]+\.[0-9]+\.[0-9]+")
        
        if [ -n "$FLUTTER_VER" ]; then
            echo -e "  Flutter version: ${CYAN}$FLUTTER_VER${NC}"
            
            # Check for known problematic versions (3.24.3-3.24.4 had iOS rejection issues)
            if [[ "$FLUTTER_VER" == "3.24.3" ]] || [[ "$FLUTTER_VER" == "3.24.4" ]]; then
                echo -e "  ${RED}❌ BLOCKER: Flutter $FLUTTER_VER has known iOS rejection issues${NC}"
                echo "     These versions use non-public iOS APIs (Guideline 2.5.1)"
                echo "     ${BOLD}Fix:${NC} Upgrade to Flutter 3.24.5 or later"
                GENERAL_BLOCKER_MSGS+=("Flutter $FLUTTER_VER - upgrade to 3.24.5+ (iOS rejection)")
                ((GENERAL_BLOCKERS++))
            else
                echo -e "  ${GREEN}✅${NC} Flutter version OK"
                ((GENERAL_PASSED++))
            fi
        fi
    else
        echo -e "  ${CYAN}ℹ️${NC}  Flutter CLI not available (skipping version check)"
    fi
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                              SUMMARIES
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                          iOS SUMMARY                                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ ${#IOS_BLOCKER_MSGS[@]} -gt 0 ]; then
    echo -e "${RED}❌ BLOCKERS (${#IOS_BLOCKER_MSGS[@]}) - Will cause rejection:${NC}"
    for msg in "${IOS_BLOCKER_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

if [ ${#IOS_WARNING_MSGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS (${#IOS_WARNING_MSGS[@]}) - May cause rejection:${NC}"
    for msg in "${IOS_WARNING_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

echo -e "${GREEN}✅ PASSED: $IOS_PASSED automated checks${NC}"
echo ""

echo "📋 iOS MANUAL CHECKLIST:"
echo "   [ ] Privacy Policy URL added in App Store Connect"
echo "   [ ] Privacy Policy accessible inside app (Settings/About)"
echo "   [ ] App Privacy (nutrition labels) completed in App Store Connect"
echo "   [ ] Demo credentials provided in App Review Notes (if login required)"
echo "   [ ] Review account has test data populated"
echo "   [ ] Screenshots: 6.9\" iPhone (1320×2868) - REQUIRED"
echo "   [ ] Screenshots: 13\" iPad (2064×2752) - if iPad supported"
echo "   [ ] Screenshots match current app UI"
echo "   [ ] App description accurate (no unreleased features)"
echo "   [ ] Backend API accessible (no maintenance during review)"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                        ANDROID SUMMARY                                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ ${#ANDROID_BLOCKER_MSGS[@]} -gt 0 ]; then
    echo -e "${RED}❌ BLOCKERS (${#ANDROID_BLOCKER_MSGS[@]}) - Will cause rejection:${NC}"
    for msg in "${ANDROID_BLOCKER_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

if [ ${#ANDROID_WARNING_MSGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS (${#ANDROID_WARNING_MSGS[@]}) - May cause rejection:${NC}"
    for msg in "${ANDROID_WARNING_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

echo -e "${GREEN}✅ PASSED: $ANDROID_PASSED automated checks${NC}"
echo ""

echo "📋 ANDROID MANUAL CHECKLIST:"
echo "   [ ] Data Safety form completed (must match actual SDK behavior)"
echo "   [ ] Content rating questionnaire completed accurately"
echo "   [ ] Privacy Policy URL added (must be hosted webpage, not PDF)"
echo "   [ ] Using AAB format (not APK) for upload"
echo "   [ ] Play App Signing enrolled"
echo "   [ ] Screenshots: Phone (1080×1920 or 9:16) - min 2 required"
echo "   [ ] Screenshots: 7\" Tablet - if tablet supported"
echo "   [ ] Screenshots: 10\" Tablet - if tablet supported"
echo "   [ ] Store listing: Title ≤30 characters"
echo "   [ ] Store listing: Short description ≤80 characters"
echo "   [ ] 64-bit native libraries included"
echo "   [ ] Backend API accessible during review"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                        GENERAL SUMMARY                                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ ${#GENERAL_BLOCKER_MSGS[@]} -gt 0 ]; then
    echo -e "${RED}❌ BLOCKERS (${#GENERAL_BLOCKER_MSGS[@]}) - Will cause rejection:${NC}"
    for msg in "${GENERAL_BLOCKER_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

if [ ${#GENERAL_WARNING_MSGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS (${#GENERAL_WARNING_MSGS[@]}) - May cause rejection:${NC}"
    for msg in "${GENERAL_WARNING_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

echo -e "${GREEN}✅ PASSED: $GENERAL_PASSED automated checks${NC}"
echo ""

echo "📋 GENERAL MANUAL CHECKLIST:"
echo "   [ ] App tested in release mode (not just debug)"
echo "   [ ] No crashes or white screens on launch"
echo "   [ ] Network error handling (graceful offline behavior)"
echo "   [ ] Deep links work correctly"
echo "   [ ] Push notifications configured and working"
echo "   [ ] Analytics/crash reporting configured"

# ═══════════════════════════════════════════════════════════════════════════════
#                             FINAL VERDICT
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              FINAL VERDICT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOTAL_BLOCKERS=$((IOS_BLOCKERS + ANDROID_BLOCKERS + GENERAL_BLOCKERS))
TOTAL_WARNINGS=$((IOS_WARNINGS + ANDROID_WARNINGS + GENERAL_WARNINGS))
TOTAL_PASSED=$((IOS_PASSED + ANDROID_PASSED + GENERAL_PASSED))

printf "  %-12s %2d blockers   %2d warnings   %2d passed\n" "iOS:" "$IOS_BLOCKERS" "$IOS_WARNINGS" "$IOS_PASSED"
printf "  %-12s %2d blockers   %2d warnings   %2d passed\n" "Android:" "$ANDROID_BLOCKERS" "$ANDROID_WARNINGS" "$ANDROID_PASSED"
printf "  %-12s %2d blockers   %2d warnings   %2d passed\n" "General:" "$GENERAL_BLOCKERS" "$GENERAL_WARNINGS" "$GENERAL_PASSED"
echo "  ─────────────────────────────────────────────────────────"
printf "  %-12s %2d blockers   %2d warnings   %2d passed\n" "TOTAL:" "$TOTAL_BLOCKERS" "$TOTAL_WARNINGS" "$TOTAL_PASSED"
echo ""

if [ $TOTAL_BLOCKERS -gt 0 ]; then
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   🚫 NOT READY FOR SUBMISSION                                             ║${NC}"
    echo -e "${RED}║   Fix $TOTAL_BLOCKERS blocker(s) before submitting to stores                          ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    exit 1
elif [ $TOTAL_WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║   ⚠️  REVIEW WARNINGS BEFORE SUBMISSION                                   ║${NC}"
    echo -e "${YELLOW}║   $TOTAL_WARNINGS warning(s) may cause rejection - review carefully                   ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ AUTOMATED CHECKS PASSED                                              ║${NC}"
    echo -e "${GREEN}║   Complete the manual checklists above before submitting                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
fi