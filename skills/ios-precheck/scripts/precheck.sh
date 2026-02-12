#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# APPLE APP STORE PRE-CHECK v3.0 - Flutter & Expo Edition
# Pre-submission validation for Apple App Store (iOS)
# ═══════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

BLOCKERS=0; WARNINGS=0; PASSED=0
declare -a BLOCKER_MSGS WARNING_MSGS
PROJECT_TYPE=""; PROJECT_NAME=""

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                APPLE APP STORE PRE-CHECK VALIDATOR v3.0                   ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# ─── Project Detection ────────────────────────────────────────────────────────
if [ -f "pubspec.yaml" ]; then
    PROJECT_TYPE="flutter"; PKG_FILE="pubspec.yaml"; SRC_DIR="lib"
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | sed 's/name: //' | tr -d ' ')
    echo -e "${MAGENTA}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${NC}  ${BOLD}Flutter Project${NC}: $PROJECT_NAME"
    echo -e "${MAGENTA}└─────────────────────────────────────────────┘${NC}"
elif [ -f "app.json" ] && grep -q "expo" app.json 2>/dev/null; then
    PROJECT_TYPE="expo"; PKG_FILE="package.json"; SRC_DIR="src"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="app"; [ ! -d "$SRC_DIR" ] && SRC_DIR="."
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
    HAS_PREBUILD=false; [ -d "ios" ] && HAS_PREBUILD=true
    echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${BOLD}Expo Project${NC}: $PROJECT_NAME"
    if [ "$HAS_PREBUILD" = true ]; then
        echo -e "${BLUE}│${NC}  Prebuild: ${GREEN}✓ ios/ exists${NC}"
    else
        echo -e "${BLUE}│${NC}  Prebuild: ${YELLOW}✗ Run 'npx expo prebuild --platform ios'${NC}"
    fi
    echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"
elif [ -f "package.json" ] && grep -q "react-native" package.json 2>/dev/null; then
    PROJECT_TYPE="react-native"; PKG_FILE="package.json"; SRC_DIR="src"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="app"; [ ! -d "$SRC_DIR" ] && SRC_DIR="."
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1 | sed 's/.*: *"//' | sed 's/"//')
    echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}React Native Project${NC}: $PROJECT_NAME"
    echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
else
    echo -e "${RED}❌ Could not detect project. Run from project root.${NC}"; exit 1
fi
echo ""

# ─── Find Info.plist ──────────────────────────────────────────────────────────
PLIST=""
if [ "$PROJECT_TYPE" = "flutter" ]; then
    [ -f "ios/Runner/Info.plist" ] && PLIST="ios/Runner/Info.plist"
elif [ "$PROJECT_TYPE" = "expo" ]; then
    [ -d "ios" ] && PLIST=$(find ios -name "Info.plist" -not -path "*/Pods/*" 2>/dev/null | head -1)
else
    PLIST=$(find ios -name "Info.plist" -not -path "*/Pods/*" 2>/dev/null | grep -v "Tests" | head -1)
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                      BACKGROUND MODES (Guideline 2.5.4)
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   BACKGROUND MODES (Guideline 2.5.4)                                     ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -z "$PLIST" ]; then
    if [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
        echo "▸ Checking app.json infoPlist overrides"
        if grep -q '"UIBackgroundModes"' app.json 2>/dev/null; then
            if grep -A5 '"UIBackgroundModes"' app.json | grep -q '"audio"'; then
                echo -e "  ${RED}❌ BLOCKER: UIBackgroundModes 'audio' in app.json${NC}"
                echo "     Only valid for streaming/playback apps"
                BLOCKER_MSGS+=("UIBackgroundModes 'audio' in app.json"); ((BLOCKERS++))
            fi
            if grep -A5 '"UIBackgroundModes"' app.json | grep -q '"voip"'; then
                echo -e "  ${RED}❌ BLOCKER: UIBackgroundModes 'voip' in app.json${NC}"
                BLOCKER_MSGS+=("UIBackgroundModes 'voip' in app.json"); ((BLOCKERS++))
            fi
        else
            echo -e "  ${GREEN}✅${NC} No UIBackgroundModes in app.json"; ((PASSED++))
        fi
    else
        echo -e "${YELLOW}⚠️  No Info.plist found — skipping${NC}"
        WARNING_MSGS+=("No Info.plist found"); ((WARNINGS++))
    fi
else
    echo -e "${BLUE}Found:${NC} $PLIST"
    echo ""
    echo "▸ UIBackgroundModes"

    BG_MODES=$(plutil -extract UIBackgroundModes xml1 -o - "$PLIST" 2>/dev/null || echo "")
    if [ -n "$BG_MODES" ]; then
        BG_OK=true
        if echo "$BG_MODES" | grep -q ">audio<"; then
            echo -e "  ${RED}❌ BLOCKER: 'audio' — only for streaming/playback apps${NC}"
            echo "     Push notification sounds work WITHOUT this."
            echo "     Fix: Remove 'audio' from UIBackgroundModes"
            BLOCKER_MSGS+=("UIBackgroundModes 'audio'"); ((BLOCKERS++)); BG_OK=false
        fi
        if echo "$BG_MODES" | grep -q ">voip<"; then
            echo -e "  ${RED}❌ BLOCKER: 'voip' — only for VoIP calling apps${NC}"
            BLOCKER_MSGS+=("UIBackgroundModes 'voip'"); ((BLOCKERS++)); BG_OK=false
        fi
        if echo "$BG_MODES" | grep -q ">location<"; then
            echo -e "  ${YELLOW}⚠️  'location' — requires user-facing justification${NC}"
            WARNING_MSGS+=("UIBackgroundModes 'location'"); ((WARNINGS++)); BG_OK=false
        fi
        [ "$BG_OK" = true ] && echo -e "  ${GREEN}✅${NC} Background modes OK" && ((PASSED++))
    else
        echo -e "  ${GREEN}✅${NC} No UIBackgroundModes declared"; ((PASSED++))
    fi
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                    PRIVACY PURPOSE STRINGS (Guideline 5.1.1)
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   PRIVACY PURPOSE STRINGS (Guideline 5.1.1)                              ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -n "$PLIST" ]; then
    declare -A USAGE_KEYS=(
        ["NSCameraUsageDescription"]="Camera"
        ["NSPhotoLibraryUsageDescription"]="Photo Library (read)"
        ["NSPhotoLibraryAddUsageDescription"]="Photo Library (write)"
        ["NSMicrophoneUsageDescription"]="Microphone"
        ["NSLocationWhenInUseUsageDescription"]="Location (in use)"
        ["NSLocationAlwaysUsageDescription"]="Location (always)"
        ["NSLocationAlwaysAndWhenInUseUsageDescription"]="Location (always+inuse)"
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
        friendly="${USAGE_KEYS[$key]}"
        value=$(plutil -extract "$key" raw -o - "$PLIST" 2>/dev/null || echo "")
        if [ -n "$value" ]; then
            ((FOUND_KEYS++))
            len=${#value}
            if echo "$value" | grep -qiE "(example|todo|fill this|placeholder|you should|CHANGEME|REPLACE)"; then
                echo -e "  ${RED}❌ BLOCKER: $friendly — placeholder text${NC}"
                echo "     \"$value\""
                BLOCKER_MSGS+=("$key contains placeholder text"); ((BLOCKERS++))
            elif [ $len -lt 20 ]; then
                echo -e "  ${YELLOW}⚠️  $friendly — too short ($len chars)${NC}"
                echo "     \"$value\""
                echo "     ${CYAN}Tip: Include specific usage example${NC}"
                WARNING_MSGS+=("$key too short"); ((WARNINGS++))
            elif echo "$value" | grep -qiE "^(this app needs|we need|required for|access to|needs access|used for|for |to )"; then
                echo -e "  ${YELLOW}⚠️  $friendly — may be too generic${NC}"
                echo "     \"$value\""
                WARNING_MSGS+=("$key too generic"); ((WARNINGS++))
            else
                echo -e "  ${GREEN}✅${NC} $friendly ($len chars)"; ((PASSED++))
            fi
        fi
    done
    [ $FOUND_KEYS -eq 0 ] && echo -e "  ${CYAN}ℹ️${NC}  No privacy permission strings found"
elif [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
    echo "▸ Checking app.json infoPlist privacy strings"
    for key in NSCameraUsageDescription NSPhotoLibraryUsageDescription NSLocationWhenInUseUsageDescription NSMicrophoneUsageDescription; do
        value=$(grep -oP "\"$key\"\s*:\s*\"\K[^\"]*" app.json 2>/dev/null)
        if [ -n "$value" ]; then
            len=${#value}
            if [ $len -lt 20 ]; then
                echo -e "  ${YELLOW}⚠️  $key — too short ($len chars)${NC}"
                WARNING_MSGS+=("$key too short in app.json"); ((WARNINGS++))
            else
                echo -e "  ${GREEN}✅${NC} $key ($len chars)"; ((PASSED++))
            fi
        fi
    done
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                      APP TRANSPORT SECURITY
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   APP TRANSPORT SECURITY                                                 ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -n "$PLIST" ]; then
    ATS=$(plutil -extract NSAppTransportSecurity xml1 -o - "$PLIST" 2>/dev/null || echo "")
    if [ -n "$ATS" ] && echo "$ATS" | grep -q "NSAllowsArbitraryLoads.*true"; then
        echo -e "  ${YELLOW}⚠️  NSAllowsArbitraryLoads enabled — disables HTTPS requirement${NC}"
        echo "     May require justification during review"
        WARNING_MSGS+=("NSAllowsArbitraryLoads enabled"); ((WARNINGS++))
    else
        echo -e "  ${GREEN}✅${NC} ATS secure (HTTPS required)"; ((PASSED++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  Skipped — no Info.plist"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                      BUILD CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   BUILD CONFIGURATION                                                    ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -n "$PLIST" ]; then
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$PLIST" 2>/dev/null || echo "")
    VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST" 2>/dev/null || echo "")
    BUILD=$(plutil -extract CFBundleVersion raw -o - "$PLIST" 2>/dev/null || echo "")
    [ -n "$BUNDLE_ID" ] && echo -e "  Bundle ID: ${CYAN}$BUNDLE_ID${NC}"
    [ -n "$VERSION" ] && echo -e "  Version: ${CYAN}$VERSION${NC} (Build: ${CYAN}$BUILD${NC})"
elif [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
    IOS_BUNDLE=$(grep -o '"bundleIdentifier"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | sed 's/.*: *"//' | sed 's/"//')
    if [ -n "$IOS_BUNDLE" ]; then
        echo -e "  ${GREEN}✅${NC} Bundle ID: ${CYAN}$IOS_BUNDLE${NC}"; ((PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: No ios.bundleIdentifier in app.json${NC}"
        BLOCKER_MSGS+=("Missing ios.bundleIdentifier"); ((BLOCKERS++))
    fi
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                        ACCOUNT & PRIVACY
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   ACCOUNT & PRIVACY                                                      ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

# Account Deletion (5.1.1(v))
echo "▸ Account Deletion (Guideline 5.1.1(v))"
HAS_LOGIN=false; HAS_DELETE=false
if [ -d "$SRC_DIR" ]; then
    grep -rqE "signIn|login|authenticate|FirebaseAuth|createUser|signUp|register|supabase.*auth|Auth0|useAuth|AuthContext" "$SRC_DIR" 2>/dev/null && HAS_LOGIN=true
    grep -rqE "deleteUser|deleteAccount|delete.*account|account.*delet|removeAccount|closeAccount|accountDeletion" "$SRC_DIR" 2>/dev/null && HAS_DELETE=true
fi
if [ "$HAS_LOGIN" = true ]; then
    if [ "$HAS_DELETE" = true ]; then
        echo -e "  ${GREEN}✅${NC} Account deletion found"; ((PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: Login exists but no account deletion${NC}"
        echo "     iOS requires in-app account deletion (Guideline 5.1.1(v))"
        BLOCKER_MSGS+=("No account deletion found"); ((BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  No login features detected"
fi
echo ""

# Restore Purchases (3.1.1)
echo "▸ Restore Purchases (Guideline 3.1.1)"
HAS_IAP=false; HAS_RESTORE=false
if [ -f "$PKG_FILE" ]; then
    if [ "$PROJECT_TYPE" = "flutter" ]; then
        grep -qE "in_app_purchase|purchases_flutter|flutter_inapp_purchase|revenue_cat" "$PKG_FILE" 2>/dev/null && HAS_IAP=true
    else
        grep -qE "react-native-iap|expo-in-app-purchases|react-native-purchases|@revenuecat" "$PKG_FILE" 2>/dev/null && HAS_IAP=true
    fi
    [ -d "$SRC_DIR" ] && grep -rqE "restorePurchases|restore.*purchase|restoreTransactions|getPurchaseHistory" "$SRC_DIR" 2>/dev/null && HAS_RESTORE=true
fi
if [ "$HAS_IAP" = true ]; then
    if [ "$HAS_RESTORE" = true ]; then
        echo -e "  ${GREEN}✅${NC} Restore purchases found"; ((PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: IAP exists but no restore purchases${NC}"
        echo "     Add visible 'Restore Purchases' button on paywall/settings"
        BLOCKER_MSGS+=("IAP without restore purchases"); ((BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  No IAP packages detected"
fi
echo ""

# Privacy Policy
echo "▸ Privacy Policy"
FOUND_PRIVACY=false
[ -d "$SRC_DIR" ] && grep -rqE "privacy.*policy|privacyPolicy|privacy_policy|PrivacyPolicy|privacyPolicyUrl" "$SRC_DIR" 2>/dev/null && FOUND_PRIVACY=true
if [ "$FOUND_PRIVACY" = true ]; then
    echo -e "  ${GREEN}✅${NC} Privacy policy reference found"; ((PASSED++))
else
    echo -e "  ${YELLOW}⚠️${NC}  No privacy policy link in code"
    WARNING_MSGS+=("Add privacy policy link in app"); ((WARNINGS++))
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                      FLUTTER VERSION CHECK
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$PROJECT_TYPE" = "flutter" ]; then
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃   FLUTTER VERSION                                                        ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo ""

    if command -v flutter &> /dev/null; then
        FLUTTER_VER=$(flutter --version 2>/dev/null | head -1 | grep -oP "Flutter \K[0-9]+\.[0-9]+\.[0-9]+")
        if [ -n "$FLUTTER_VER" ]; then
            echo -e "  Version: ${CYAN}$FLUTTER_VER${NC}"
            if [[ "$FLUTTER_VER" == "3.24.3" ]] || [[ "$FLUTTER_VER" == "3.24.4" ]]; then
                echo -e "  ${RED}❌ BLOCKER: Flutter $FLUTTER_VER uses non-public iOS APIs (2.5.1)${NC}"
                echo "     Fix: Upgrade to 3.24.5+"
                BLOCKER_MSGS+=("Flutter $FLUTTER_VER — upgrade to 3.24.5+"); ((BLOCKERS++))
            else
                echo -e "  ${GREEN}✅${NC} Version OK"; ((PASSED++))
            fi
        fi
    else
        echo -e "  ${CYAN}ℹ️${NC}  Flutter CLI not available"
    fi
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                              SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                          iOS SUMMARY                                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

[ ${#BLOCKER_MSGS[@]} -gt 0 ] && echo -e "${RED}❌ BLOCKERS (${#BLOCKER_MSGS[@]}):${NC}" && for m in "${BLOCKER_MSGS[@]}"; do echo "   • $m"; done && echo ""
[ ${#WARNING_MSGS[@]} -gt 0 ] && echo -e "${YELLOW}⚠️  WARNINGS (${#WARNING_MSGS[@]}):${NC}" && for m in "${WARNING_MSGS[@]}"; do echo "   • $m"; done && echo ""
echo -e "${GREEN}✅ PASSED: $PASSED checks${NC}"
echo ""

echo "📋 APP STORE CONNECT MANUAL CHECKLIST:"
echo "   [ ] Screenshots: 6.9\" iPhone (1320×2868) — REQUIRED"
echo "   [ ] Screenshots: 13\" iPad (2064×2752) — if Universal app"
echo "   [ ] App description, keywords, promotional text"
echo "   [ ] Privacy nutrition labels completed"
echo "   [ ] Age rating questionnaire"
echo "   [ ] Review notes + demo credentials (if login required)"
echo "   [ ] Contact info for App Review team"
echo "   [ ] IDFA declaration (if using advertising identifier)"
echo "   [ ] Export compliance (encryption) answered"
echo "   [ ] In-app purchases submitted for review"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  TOTAL:  %2d blockers   %2d warnings   %2d passed\n" "$BLOCKERS" "$WARNINGS" "$PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $BLOCKERS -gt 0 ]; then
    echo -e "${RED}🚫 NOT READY — fix $BLOCKERS blocker(s)${NC}"; exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  REVIEW $WARNINGS WARNING(S) BEFORE SUBMISSION${NC}"; exit 0
else
    echo -e "${GREEN}✅ AUTOMATED CHECKS PASSED — complete manual checklist${NC}"; exit 0
fi
