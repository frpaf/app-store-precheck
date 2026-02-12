#!/bin/bash
# app-store-precheck.sh
# Automated pre-submission validation for Flutter apps
# Run from Flutter project root directory

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters - iOS
IOS_BLOCKERS=0
IOS_WARNINGS=0
IOS_PASSED=0

# Counters - Android
ANDROID_BLOCKERS=0
ANDROID_WARNINGS=0
ANDROID_PASSED=0

# Counters - General
GENERAL_BLOCKERS=0
GENERAL_WARNINGS=0
GENERAL_PASSED=0

# Output arrays - iOS
declare -a IOS_BLOCKER_MSGS
declare -a IOS_WARNING_MSGS
declare -a IOS_PASSED_MSGS
declare -a IOS_MANUAL_CHECKS

# Output arrays - Android
declare -a ANDROID_BLOCKER_MSGS
declare -a ANDROID_WARNING_MSGS
declare -a ANDROID_PASSED_MSGS
declare -a ANDROID_MANUAL_CHECKS

# Output arrays - General
declare -a GENERAL_BLOCKER_MSGS
declare -a GENERAL_WARNING_MSGS
declare -a GENERAL_PASSED_MSGS
declare -a GENERAL_MANUAL_CHECKS

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           APP STORE PRE-SUBMISSION VALIDATOR                     ║"
echo "║           iOS (App Store) + Android (Google Play)                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Detect project type
if [ -f "pubspec.yaml" ]; then
    PROJECT_TYPE="flutter"
    echo -e "${BLUE}📱 Detected: Flutter project${NC}"
elif [ -f "package.json" ] && grep -q "expo\|react-native" package.json 2>/dev/null; then
    PROJECT_TYPE="react-native"
    echo -e "${BLUE}📱 Detected: React Native/Expo project${NC}"
else
    echo -e "${YELLOW}⚠️  Could not detect project type. Assuming Flutter.${NC}"
    PROJECT_TYPE="flutter"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# iOS CHECKS (APPLE APP STORE)
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  iOS CHECKS (Apple App Store)                                   ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

PLIST=""
if [ -f "ios/Runner/Info.plist" ]; then
    PLIST="ios/Runner/Info.plist"
elif [ -f "ios/App/App/Info.plist" ]; then
    PLIST="ios/App/App/Info.plist"
fi

if [ -z "$PLIST" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  No Info.plist found - skipping iOS checks${NC}"
    IOS_WARNING_MSGS+=("No Info.plist found - iOS checks skipped")
    ((IOS_WARNINGS++))
else
    echo ""
    echo -e "${BLUE}Found: $PLIST${NC}"
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # iOS Check 1: UIBackgroundModes
    # ─────────────────────────────────────────────────────────────────
    echo "▸ UIBackgroundModes (Guideline 2.5.4)"
    
    BG_MODES=$(plutil -extract UIBackgroundModes xml1 -o - "$PLIST" 2>/dev/null || echo "")
    
    if [ -n "$BG_MODES" ]; then
        if echo "$BG_MODES" | grep -q ">audio<"; then
            echo -e "  ${RED}❌ BLOCKER: 'audio' background mode found${NC}"
            echo "     This is ONLY valid for music/streaming apps."
            echo "     Firebase push notifications work WITHOUT this mode."
            echo "     Action: Remove 'audio' from UIBackgroundModes in Info.plist"
            IOS_BLOCKER_MSGS+=("UIBackgroundModes contains 'audio' - remove unless streaming app")
            ((IOS_BLOCKERS++))
        fi
        
        if echo "$BG_MODES" | grep -q ">voip<"; then
            echo -e "  ${YELLOW}⚠️  WARNING: 'voip' background mode found${NC}"
            echo "     Only valid for VoIP calling apps."
            IOS_WARNING_MSGS+=("UIBackgroundModes contains 'voip' - verify needed")
            ((IOS_WARNINGS++))
        fi
        
        if echo "$BG_MODES" | grep -q ">location<"; then
            echo -e "  ${YELLOW}⚠️  WARNING: 'location' background mode found${NC}"
            echo "     Requires clear justification for background location."
            IOS_WARNING_MSGS+=("UIBackgroundModes contains 'location' - ensure justified")
            ((IOS_WARNINGS++))
        fi
        
        # Check if we added any issues
        if ! echo "$BG_MODES" | grep -qE ">audio<|>voip<|>location<"; then
            echo -e "  ${GREEN}✅ Background modes look OK${NC}"
            ((IOS_PASSED++))
        fi
    else
        echo -e "  ${GREEN}✅ No UIBackgroundModes declared${NC}"
        ((IOS_PASSED++))
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # iOS Check 2: Privacy Purpose Strings
    # ─────────────────────────────────────────────────────────────────
    echo "▸ Privacy Purpose Strings (Guideline 5.1.1)"
    
    USAGE_KEYS=(
        "NSCameraUsageDescription"
        "NSPhotoLibraryUsageDescription"
        "NSPhotoLibraryAddUsageDescription"
        "NSMicrophoneUsageDescription"
        "NSLocationWhenInUseUsageDescription"
        "NSLocationAlwaysUsageDescription"
        "NSContactsUsageDescription"
        "NSCalendarsUsageDescription"
        "NSFaceIDUsageDescription"
        "NSBluetoothAlwaysUsageDescription"
        "NSSpeechRecognitionUsageDescription"
        "NSMotionUsageDescription"
    )

    FOUND_KEYS=0
    for key in "${USAGE_KEYS[@]}"; do
        value=$(plutil -extract "$key" raw -o - "$PLIST" 2>/dev/null || echo "")
        
        if [ -n "$value" ]; then
            ((FOUND_KEYS++))
            len=${#value}
            
            # Check for placeholder text
            if echo "$value" | grep -qiE "(example|todo|fill this|you should|placeholder)"; then
                echo -e "  ${RED}❌ BLOCKER: $key contains placeholder text${NC}"
                echo "     Value: \"$value\""
                IOS_BLOCKER_MSGS+=("$key contains placeholder text")
                ((IOS_BLOCKERS++))
            # Check length
            elif [ $len -lt 20 ]; then
                echo -e "  ${YELLOW}⚠️  WARNING: $key is too short ($len chars)${NC}"
                echo "     Value: \"$value\""
                echo "     Should include specific example of usage"
                IOS_WARNING_MSGS+=("$key too short ($len chars) - add specific example")
                ((IOS_WARNINGS++))
            # Check for generic text
            elif echo "$value" | grep -qiE "^(this app needs|we need|required for|access to|needs access)"; then
                echo -e "  ${YELLOW}⚠️  WARNING: $key may be too generic${NC}"
                echo "     Value: \"$value\""
                echo "     Consider adding a specific example"
                IOS_WARNING_MSGS+=("$key may be too generic")
                ((IOS_WARNINGS++))
            else
                echo -e "  ${GREEN}✅ $key OK ($len chars)${NC}"
                ((IOS_PASSED++))
            fi
        fi
    done
    
    if [ $FOUND_KEYS -eq 0 ]; then
        echo -e "  ${CYAN}ℹ️  No privacy permission keys found${NC}"
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # iOS Check 3: App Transport Security
    # ─────────────────────────────────────────────────────────────────
    echo "▸ App Transport Security"
    
    ATS=$(plutil -extract NSAppTransportSecurity xml1 -o - "$PLIST" 2>/dev/null || echo "")
    
    if [ -n "$ATS" ]; then
        if echo "$ATS" | grep -q "NSAllowsArbitraryLoads.*true"; then
            echo -e "  ${YELLOW}⚠️  WARNING: NSAllowsArbitraryLoads is enabled${NC}"
            echo "     This disables ATS for all connections."
            echo "     Consider using NSExceptionDomains for specific domains."
            IOS_WARNING_MSGS+=("NSAllowsArbitraryLoads enabled - may need justification")
            ((IOS_WARNINGS++))
        else
            echo -e "  ${GREEN}✅ ATS exceptions look reasonable${NC}"
            ((IOS_PASSED++))
        fi
    else
        echo -e "  ${GREEN}✅ No ATS exceptions (default secure)${NC}"
        ((IOS_PASSED++))
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # iOS Check 4: Bundle Configuration
    # ─────────────────────────────────────────────────────────────────
    echo "▸ Bundle Configuration"
    
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$PLIST" 2>/dev/null || echo "")
    VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST" 2>/dev/null || echo "")
    BUILD=$(plutil -extract CFBundleVersion raw -o - "$PLIST" 2>/dev/null || echo "")
    
    if [ -n "$BUNDLE_ID" ]; then
        echo -e "  Bundle ID: ${CYAN}$BUNDLE_ID${NC}"
    fi
    if [ -n "$VERSION" ] && [ -n "$BUILD" ]; then
        echo -e "  Version: ${CYAN}$VERSION ($BUILD)${NC}"
    fi
    echo ""
fi

# iOS Manual Checks
IOS_MANUAL_CHECKS+=(
    "Privacy Policy URL in App Store Connect"
    "Privacy Policy accessible inside app (Settings/About)"
    "Demo credentials in App Review Notes"
    "Test data populated for review account"
    "Screenshots match current iOS app UI"
    "App description matches functionality"
    "Apple TV privacy policy (if applicable)"
)

# ═══════════════════════════════════════════════════════════════════════
# ANDROID CHECKS (GOOGLE PLAY STORE)
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  ANDROID CHECKS (Google Play Store)                             ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

GRADLE=""
if [ -f "android/app/build.gradle.kts" ]; then
    GRADLE="android/app/build.gradle.kts"
elif [ -f "android/app/build.gradle" ]; then
    GRADLE="android/app/build.gradle"
fi

if [ -z "$GRADLE" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  No build.gradle found - skipping Android checks${NC}"
    ANDROID_WARNING_MSGS+=("No build.gradle found - Android checks skipped")
    ((ANDROID_WARNINGS++))
else
    echo ""
    echo -e "${BLUE}Found: $GRADLE${NC}"
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # Android Check 1: Target SDK Level
    # ─────────────────────────────────────────────────────────────────
    echo "▸ Target SDK Level (Google Play Requirement)"
    
    TARGET_SDK=$(grep -oP "targetSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    COMPILE_SDK=$(grep -oP "compileSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    MIN_SDK=$(grep -oP "minSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    
    if [ -n "$TARGET_SDK" ]; then
        if [ "$TARGET_SDK" -lt 34 ]; then
            echo -e "  ${RED}❌ BLOCKER: targetSdk $TARGET_SDK is too low${NC}"
            echo "     Minimum for updates: 34 (Android 14)"
            echo "     Required for new apps: 35 (Android 15)"
            echo "     Action: Update targetSdk in build.gradle"
            ANDROID_BLOCKER_MSGS+=("targetSdk $TARGET_SDK - must be 34+ (35+ for new apps)")
            ((ANDROID_BLOCKERS++))
        elif [ "$TARGET_SDK" -lt 35 ]; then
            echo -e "  ${YELLOW}⚠️  WARNING: targetSdk $TARGET_SDK${NC}"
            echo "     OK for updates, but new apps require targetSdk 35"
            ANDROID_WARNING_MSGS+=("targetSdk 34 - new apps require 35")
            ((ANDROID_WARNINGS++))
        else
            echo -e "  ${GREEN}✅ targetSdk $TARGET_SDK meets requirements${NC}"
            ((ANDROID_PASSED++))
        fi
    else
        echo -e "  ${YELLOW}⚠️  Could not determine targetSdk${NC}"
        ANDROID_WARNING_MSGS+=("Could not determine targetSdk")
        ((ANDROID_WARNINGS++))
    fi
    
    if [ -n "$COMPILE_SDK" ]; then
        echo -e "  compileSdk: ${CYAN}$COMPILE_SDK${NC}"
    fi
    if [ -n "$MIN_SDK" ]; then
        echo -e "  minSdk: ${CYAN}$MIN_SDK${NC}"
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # Android Check 2: Signing Configuration
    # ─────────────────────────────────────────────────────────────────
    echo "▸ Signing Configuration (Play App Signing)"
    
    if grep -q "signingConfigs" "$GRADLE" 2>/dev/null; then
        echo -e "  ${GREEN}✅ signingConfigs block found${NC}"
        ((ANDROID_PASSED++))
        
        # Check for release signing
        if grep -q "release\s*{" "$GRADLE" && grep -A10 "release\s*{" "$GRADLE" | grep -q "signingConfig"; then
            echo -e "  ${GREEN}✅ Release build uses signing config${NC}"
            ((ANDROID_PASSED++))
        else
            echo -e "  ${YELLOW}⚠️  Verify release build has signingConfig${NC}"
            ANDROID_WARNING_MSGS+=("Verify release build uses signingConfig")
            ((ANDROID_WARNINGS++))
        fi
    else
        echo -e "  ${YELLOW}⚠️  No signingConfigs block found${NC}"
        echo "     Ensure Play App Signing is configured"
        ANDROID_WARNING_MSGS+=("No signingConfigs - ensure Play App Signing enrolled")
        ((ANDROID_WARNINGS++))
    fi
    
    # Check for key.properties
    if [ -f "android/key.properties" ]; then
        echo -e "  ${GREEN}✅ key.properties file exists${NC}"
        ((ANDROID_PASSED++))
    else
        echo -e "  ${YELLOW}⚠️  No key.properties file found${NC}"
        ANDROID_WARNING_MSGS+=("No key.properties - needed for release signing")
        ((ANDROID_WARNINGS++))
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # Android Check 3: Application Configuration
    # ─────────────────────────────────────────────────────────────────
    echo "▸ Application Configuration"
    
    APP_ID=$(grep -oP "(applicationId|namespace)\s*[=:]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1)
    VERSION_NAME=$(grep -oP "versionName\s*[=:]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1)
    VERSION_CODE=$(grep -oP "versionCode\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    
    if [ -n "$APP_ID" ]; then
        echo -e "  Application ID: ${CYAN}$APP_ID${NC}"
    fi
    if [ -n "$VERSION_NAME" ] && [ -n "$VERSION_CODE" ]; then
        echo -e "  Version: ${CYAN}$VERSION_NAME ($VERSION_CODE)${NC}"
    fi
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # Android Check 4: ProGuard/R8
    # ─────────────────────────────────────────────────────────────────
    echo "▸ Code Shrinking (ProGuard/R8)"
    
    if grep -q "minifyEnabled\s*[=:]\s*true" "$GRADLE" 2>/dev/null; then
        echo -e "  ${GREEN}✅ minifyEnabled is true for release${NC}"
        ((ANDROID_PASSED++))
    else
        echo -e "  ${CYAN}ℹ️  minifyEnabled not explicitly set to true${NC}"
        echo "     Consider enabling for smaller APK size"
    fi
    echo ""
fi

# Android Manual Checks
ANDROID_MANUAL_CHECKS+=(
    "Data Safety form matches actual SDK behavior"
    "Content rating questionnaire completed accurately"
    "Store listing: Title ≤30 chars, Short desc ≤80 chars"
    "Privacy Policy URL hosted online (not PDF)"
    "Screenshots match current Android app UI"
    "AAB format used (not APK)"
    "64-bit native libraries included"
    "16KB page size support (Android 15)"
)

# ═══════════════════════════════════════════════════════════════════════
# GENERAL CHECKS (BOTH PLATFORMS)
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  GENERAL CHECKS (Both Platforms)                                ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

# ─────────────────────────────────────────────────────────────────
# General Check 1: Account Management
# ─────────────────────────────────────────────────────────────────
echo "▸ Account Features Detection"

HAS_LOGIN=false
HAS_DELETE=false

if [ "$PROJECT_TYPE" = "flutter" ] && [ -d "lib" ]; then
    # Check for login/auth features
    if grep -rq "signIn\|login\|authenticate\|FirebaseAuth\|createUser\|signUp\|register" lib/ 2>/dev/null; then
        HAS_LOGIN=true
        echo -e "  ${CYAN}ℹ️  Found: Account creation/login functionality${NC}"
    fi
    
    # Check for account deletion
    if grep -rq "deleteUser\|deleteAccount\|delete.*account\|account.*delet\|removeAccount" lib/ 2>/dev/null; then
        HAS_DELETE=true
    fi
fi

if [ "$HAS_LOGIN" = true ]; then
    if [ "$HAS_DELETE" = true ]; then
        echo -e "  ${GREEN}✅ Account deletion code found${NC}"
        ((GENERAL_PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: Login exists but no account deletion found${NC}"
        echo "     iOS Guideline 5.1.1(v) requires in-app account deletion"
        echo "     Google Play also recommends account deletion option"
        GENERAL_BLOCKER_MSGS+=("Account creation exists but no deletion found")
        ((GENERAL_BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️  No account/login features detected${NC}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────
# General Check 2: In-App Purchases
# ─────────────────────────────────────────────────────────────────
echo "▸ In-App Purchase Detection"

HAS_IAP=false
HAS_RESTORE=false

if [ "$PROJECT_TYPE" = "flutter" ] && [ -f "pubspec.yaml" ]; then
    # Check pubspec for IAP packages
    if grep -qE "in_app_purchase|purchases_flutter|flutter_inapp_purchase|revenue_cat" pubspec.yaml 2>/dev/null; then
        HAS_IAP=true
        echo -e "  ${CYAN}ℹ️  Found: In-app purchase package${NC}"
    fi
    
    # Check for restore purchases
    if [ -d "lib" ]; then
        if grep -rq "restorePurchases\|restore.*purchase\|restoreTransactions" lib/ 2>/dev/null; then
            HAS_RESTORE=true
        fi
    fi
fi

if [ "$HAS_IAP" = true ]; then
    if [ "$HAS_RESTORE" = true ]; then
        echo -e "  ${GREEN}✅ Restore purchases functionality found${NC}"
        ((GENERAL_PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: IAP exists but no restore purchases found${NC}"
        echo "     iOS Guideline 3.1.1 requires 'Restore Purchases' button"
        echo "     Action: Add visible Restore Purchases button on paywall/settings"
        GENERAL_BLOCKER_MSGS+=("IAP exists but no restore purchases found")
        ((GENERAL_BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️  No in-app purchase packages detected${NC}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────
# General Check 3: Privacy Policy
# ─────────────────────────────────────────────────────────────────
echo "▸ Privacy Policy Detection"

if [ "$PROJECT_TYPE" = "flutter" ] && [ -d "lib" ]; then
    if grep -rq "privacy.*policy\|privacyPolicy\|privacy_policy" lib/ 2>/dev/null; then
        echo -e "  ${GREEN}✅ Privacy policy reference found in code${NC}"
        ((GENERAL_PASSED++))
    else
        echo -e "  ${YELLOW}⚠️  No privacy policy link found in code${NC}"
        echo "     Should be accessible in app (Settings or About screen)"
        GENERAL_WARNING_MSGS+=("Add privacy policy link inside app")
        ((GENERAL_WARNINGS++))
    fi
else
    echo -e "  ${CYAN}ℹ️  Could not scan for privacy policy${NC}"
fi
echo ""

# General Manual Checks
GENERAL_MANUAL_CHECKS+=(
    "Backend API accessible during review period"
    "No maintenance windows scheduled during review"
    "Error handling for network failures (no blank screens)"
    "App description matches available features"
    "No promises of features not yet implemented"
)

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY - iOS
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    iOS SUMMARY (App Store)                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

if [ ${#IOS_BLOCKER_MSGS[@]} -gt 0 ]; then
    echo -e "${RED}❌ BLOCKERS (${#IOS_BLOCKER_MSGS[@]}):${NC}"
    for msg in "${IOS_BLOCKER_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

if [ ${#IOS_WARNING_MSGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS (${#IOS_WARNING_MSGS[@]}):${NC}"
    for msg in "${IOS_WARNING_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

echo -e "${GREEN}✅ PASSED: $IOS_PASSED checks${NC}"
echo ""

echo "📋 MANUAL VERIFICATION:"
for check in "${IOS_MANUAL_CHECKS[@]}"; do
    echo "   [ ] $check"
done

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY - Android
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                 ANDROID SUMMARY (Google Play)                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

if [ ${#ANDROID_BLOCKER_MSGS[@]} -gt 0 ]; then
    echo -e "${RED}❌ BLOCKERS (${#ANDROID_BLOCKER_MSGS[@]}):${NC}"
    for msg in "${ANDROID_BLOCKER_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

if [ ${#ANDROID_WARNING_MSGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS (${#ANDROID_WARNING_MSGS[@]}):${NC}"
    for msg in "${ANDROID_WARNING_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

echo -e "${GREEN}✅ PASSED: $ANDROID_PASSED checks${NC}"
echo ""

echo "📋 MANUAL VERIFICATION:"
for check in "${ANDROID_MANUAL_CHECKS[@]}"; do
    echo "   [ ] $check"
done

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY - General
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                 GENERAL SUMMARY (Both Platforms)                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

if [ ${#GENERAL_BLOCKER_MSGS[@]} -gt 0 ]; then
    echo -e "${RED}❌ BLOCKERS (${#GENERAL_BLOCKER_MSGS[@]}):${NC}"
    for msg in "${GENERAL_BLOCKER_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

if [ ${#GENERAL_WARNING_MSGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS (${#GENERAL_WARNING_MSGS[@]}):${NC}"
    for msg in "${GENERAL_WARNING_MSGS[@]}"; do
        echo "   • $msg"
    done
    echo ""
fi

echo -e "${GREEN}✅ PASSED: $GENERAL_PASSED checks${NC}"
echo ""

echo "📋 MANUAL VERIFICATION:"
for check in "${GENERAL_MANUAL_CHECKS[@]}"; do
    echo "   [ ] $check"
done

# ═══════════════════════════════════════════════════════════════════════
# FINAL VERDICT
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                         FINAL VERDICT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOTAL_BLOCKERS=$((IOS_BLOCKERS + ANDROID_BLOCKERS + GENERAL_BLOCKERS))
TOTAL_WARNINGS=$((IOS_WARNINGS + ANDROID_WARNINGS + GENERAL_WARNINGS))
TOTAL_PASSED=$((IOS_PASSED + ANDROID_PASSED + GENERAL_PASSED))

echo "  iOS:      ${IOS_BLOCKERS} blockers, ${IOS_WARNINGS} warnings, ${IOS_PASSED} passed"
echo "  Android:  ${ANDROID_BLOCKERS} blockers, ${ANDROID_WARNINGS} warnings, ${ANDROID_PASSED} passed"
echo "  General:  ${GENERAL_BLOCKERS} blockers, ${GENERAL_WARNINGS} warnings, ${GENERAL_PASSED} passed"
echo "  ─────────────────────────────────────────────────"
echo "  Total:    ${TOTAL_BLOCKERS} blockers, ${TOTAL_WARNINGS} warnings, ${TOTAL_PASSED} passed"
echo ""

if [ $TOTAL_BLOCKERS -gt 0 ]; then
    echo -e "${RED}🚫 NOT READY FOR SUBMISSION${NC}"
    echo -e "   Fix ${TOTAL_BLOCKERS} blocker(s) before submitting"
    exit 1
elif [ $TOTAL_WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  REVIEW WARNINGS BEFORE SUBMISSION${NC}"
    echo -e "   ${TOTAL_WARNINGS} warning(s) may cause rejection"
    exit 0
else
    echo -e "${GREEN}✅ AUTOMATED CHECKS PASSED${NC}"
    echo -e "   Complete manual verification checklists above"
    exit 0
fi