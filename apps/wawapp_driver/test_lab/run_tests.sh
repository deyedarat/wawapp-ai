#!/usr/bin/env bash
# =============================================================================
# WawApp Driver — Firebase Test Lab Integration Test Runner
#
# Builds debug + instrumentation APKs and runs on Firebase Test Lab.
# Devices: Pixel 6 (API 33), Samsung Galaxy S21 (API 31)
#
# Usage:
#   chmod +x test_lab/run_tests.sh
#   cd apps/wawapp_driver
#   ./test_lab/run_tests.sh
#
# Prerequisites:
#   - gcloud CLI authenticated (gcloud auth login)
#   - Firebase project set (gcloud config set project <PROJECT_ID>)
#   - Flutter SDK on PATH
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_BUCKET="${RESULTS_BUCKET:-gs://wawapp-test-results}"
RESULTS_DIR="notification_flow_$(date +%Y%m%d_%H%M%S)"

cd "$PROJECT_DIR"

echo "══════════════════════════════════════════════════════════"
echo "  WawApp Driver — Firebase Test Lab Runner"
echo "══════════════════════════════════════════════════════════"

# ── Step 1: Clean + get dependencies ──
echo ""
echo "▶ Step 1/4: Preparing build..."
flutter clean
flutter pub get

# ── Step 2: Build debug APK ──
echo ""
echo "▶ Step 2/4: Building debug APK..."
flutter build apk --debug

# ── Step 3: Build instrumentation test APK ──
echo ""
echo "▶ Step 3/4: Building instrumentation test APK..."

pushd android > /dev/null
./gradlew app:assembleAndroidTest -Ptarget=integration_test/notification_flow_test.dart
popd > /dev/null

APP_APK="build/app/outputs/flutter-apk/app-debug.apk"
TEST_APK="build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

# Verify APKs exist
if [[ ! -f "$APP_APK" ]]; then
  echo "❌ Debug APK not found at $APP_APK"
  exit 1
fi
if [[ ! -f "$TEST_APK" ]]; then
  echo "❌ Test APK not found at $TEST_APK"
  exit 1
fi

echo "✅ APKs built:"
echo "   App:  $APP_APK ($(du -h "$APP_APK" | cut -f1))"
echo "   Test: $TEST_APK ($(du -h "$TEST_APK" | cut -f1))"

# ── Step 4: Run on Firebase Test Lab ──
echo ""
echo "▶ Step 4/4: Running on Firebase Test Lab..."
echo "   Devices: Pixel 6 (API 33), Samsung Galaxy S21 (API 31)"
echo "   Results: $RESULTS_BUCKET/$RESULTS_DIR"
echo ""

gcloud firebase test android run \
  --type instrumentation \
  --app "$APP_APK" \
  --test "$TEST_APK" \
  --device model=oriole,version=33,locale=ar,orientation=portrait \
  --device model=o1s,version=31,locale=ar,orientation=portrait \
  --timeout 5m \
  --results-bucket "$RESULTS_BUCKET" \
  --results-dir "$RESULTS_DIR" \
  --use-orchestrator \
  --no-performance-metrics

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  ✅ Test Lab run complete"
echo "  Results: $RESULTS_BUCKET/$RESULTS_DIR"
echo "══════════════════════════════════════════════════════════"
