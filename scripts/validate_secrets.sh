#!/bin/bash
# WawApp Secrets Validation Script
# Validates that all required configuration files and secrets exist before building
# Usage: ./scripts/validate_secrets.sh apps/wawapp_client

set -e  # Exit on any error

APP_PATH=$1
APP_NAME=$(basename "$APP_PATH")
ERRORS=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 WawApp Secret Validation${NC}"
echo -e "${BLUE}   App: $APP_NAME${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check file existence
check_file() {
    local file_path=$1
    local severity=$2  # "error" or "warning"
    local message=$3

    if [ ! -f "$file_path" ]; then
        if [ "$severity" == "error" ]; then
            echo -e "${RED}❌ ERROR: $message${NC}"
            echo -e "   Missing: $file_path"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${YELLOW}⚠️  WARNING: $message${NC}"
            echo -e "   Missing: $file_path"
            WARNINGS=$((WARNINGS + 1))
        fi
        return 1
    else
        echo -e "${GREEN}✅ Found: $file_path${NC}"
        return 0
    fi
}

# Function to check file content
check_content() {
    local file_path=$1
    local pattern=$2
    local message=$3

    if grep -q "$pattern" "$file_path" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  WARNING: $message${NC}"
        echo -e "   File: $file_path"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
    return 0
}

echo "📋 Checking Firebase configuration..."
echo "────────────────────────────────────"

# Check firebase_options.dart
if check_file "$APP_PATH/lib/firebase_options.dart" "error" "firebase_options.dart not found"; then
    # Check for placeholder values
    if check_content "$APP_PATH/lib/firebase_options.dart" "your-project-id" \
        "firebase_options.dart contains placeholder project ID"; then
        echo ""
    fi
fi

# Check google-services.json (Android)
if check_file "$APP_PATH/android/app/google-services.json" "error" \
    "google-services.json not found (required for Android builds)"; then
    # Validate it's valid JSON
    if ! python3 -m json.tool "$APP_PATH/android/app/google-services.json" > /dev/null 2>&1; then
        echo -e "${RED}❌ ERROR: google-services.json is not valid JSON${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check GoogleService-Info.plist (iOS)
if [ -d "$APP_PATH/ios" ]; then
    check_file "$APP_PATH/ios/Runner/GoogleService-Info.plist" "warning" \
        "GoogleService-Info.plist not found (required for iOS builds)"
fi

echo ""
echo "🗺️  Checking Google Maps API Key (Client app only)..."
echo "────────────────────────────────────"

if [[ "$APP_NAME" == "wawapp_client" ]]; then
    # Check api_keys.xml
    API_KEYS_FILE="$APP_PATH/android/app/src/main/res/values/api_keys.xml"

    if check_file "$API_KEYS_FILE" "warning" \
        "api_keys.xml not found (maps will not work unless using --dart-define)"; then

        # Check for placeholder value
        if check_content "$API_KEYS_FILE" "YOUR_GOOGLE_MAPS_API_KEY" \
            "api_keys.xml contains placeholder API key"; then
            echo ""
        fi
    fi

    # Check .env file
    if [ -f "$APP_PATH/.env" ]; then
        if check_content "$APP_PATH/.env" "your_google_maps_api_key_here" \
            ".env contains placeholder API key"; then
            echo ""
        fi
    else
        echo -e "${YELLOW}ℹ️  INFO: .env file not found (optional)${NC}"
        echo -e "   You can use --dart-define=GOOGLE_MAPS_API_KEY=your_key instead"
    fi
else
    echo -e "${BLUE}ℹ️  Skipping Maps API check (not required for $APP_NAME)${NC}"
fi

echo ""
echo "🔐 Checking Android signing configuration..."
echo "────────────────────────────────────"

KEY_PROPERTIES="$APP_PATH/android/key.properties"
if [ -f "$KEY_PROPERTIES" ]; then
    echo -e "${GREEN}✅ Found: key.properties (release signing configured)${NC}"

    # Validate required fields
    for field in storePassword keyPassword keyAlias storeFile; do
        if ! grep -q "^$field=" "$KEY_PROPERTIES"; then
            echo -e "${RED}❌ ERROR: key.properties missing field: $field${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo -e "${BLUE}ℹ️  key.properties not found (only needed for release builds)${NC}"
fi

echo ""
echo "📦 Checking pubspec.yaml..."
echo "────────────────────────────────────"

check_file "$APP_PATH/pubspec.yaml" "error" "pubspec.yaml not found"

# Check for firebase dependencies
if [ -f "$APP_PATH/pubspec.yaml" ]; then
    REQUIRED_DEPS=("firebase_core" "firebase_auth" "cloud_firestore")
    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! grep -q "^  $dep:" "$APP_PATH/pubspec.yaml"; then
            echo -e "${YELLOW}⚠️  WARNING: Missing dependency: $dep${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
fi

echo ""
echo "=========================================="
echo "📊 Validation Summary"
echo "=========================================="
echo -e "App: ${BLUE}$APP_NAME${NC}"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ VALIDATION FAILED${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Download google-services.json from Firebase Console"
    echo "2. Run: flutterfire configure --project=your-project-id"
    echo "3. Create api_keys.xml with your Google Maps API key"
    echo ""
    echo "See SECRETS_MANAGEMENT.md for detailed instructions"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  VALIDATION PASSED WITH WARNINGS${NC}"
    echo ""
    echo "Build will proceed but some features may not work."
    echo "Review warnings above and fix before production deployment."
    exit 0
else
    echo -e "${GREEN}✅ VALIDATION PASSED${NC}"
    echo ""
    echo "All required secrets and configuration files are present!"
    exit 0
fi
