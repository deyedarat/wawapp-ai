#!/bin/bash
#
# WawApp Staging Gate - Automated Static Checks
# Runs Gate A (Build & Static) and Gate B (Emulator/Rules) automatically
#
# Usage:
#   ./scripts/staging_gate.sh
#
# Exit codes:
#   0 = All gates passed
#   1 = One or more gates failed
#

set -e  # Exit on first error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "🚦 WawApp Staging Gate - Automated Checks"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

run_check() {
  local check_name="$1"
  local check_command="$2"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  echo "───────────────────────────────────────────────────"
  echo "🔍 $check_name"
  echo "───────────────────────────────────────────────────"

  if eval "$check_command"; then
    echo -e "${GREEN}✅ PASS${NC}: $check_name"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  else
    echo -e "${RED}❌ FAIL${NC}: $check_name"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  fi
  echo ""
}

# ============================================
# GATE A: BUILD & STATIC GATES
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 GATE A: Build & Static Gates"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# A1: Driver App
run_check "Driver App: pub get" "cd '$ROOT_DIR/apps/wawapp_driver' && flutter pub get > /dev/null 2>&1" || true
run_check "Driver App: flutter analyze" "cd '$ROOT_DIR/apps/wawapp_driver' && flutter analyze --no-fatal-infos --no-fatal-warnings" || true
run_check "Driver App: unit tests" "cd '$ROOT_DIR/apps/wawapp_driver' && flutter test" || true

# A2: Client App
run_check "Client App: pub get" "cd '$ROOT_DIR/apps/wawapp_client' && flutter pub get > /dev/null 2>&1" || true
run_check "Client App: flutter analyze" "cd '$ROOT_DIR/apps/wawapp_client' && flutter analyze --no-fatal-infos --no-fatal-warnings" || true
run_check "Client App: unit tests" "cd '$ROOT_DIR/apps/wawapp_client' && flutter test 2>&1 | grep -q 'No tests ran' && echo '⚠️  No tests yet' || flutter test" || true

# A3: Admin App
run_check "Admin App: pub get" "cd '$ROOT_DIR/apps/wawapp_admin' && flutter pub get > /dev/null 2>&1" || true
run_check "Admin App: flutter analyze" "cd '$ROOT_DIR/apps/wawapp_admin' && flutter analyze --no-fatal-infos --no-fatal-warnings" || true
run_check "Admin App: unit tests" "cd '$ROOT_DIR/apps/wawapp_admin' && flutter test 2>&1 | grep -q 'No tests ran' && echo '⚠️  No tests yet' || flutter test" || true

# A4: Packages
run_check "auth_shared: analyze" "cd '$ROOT_DIR/packages/auth_shared' && flutter pub get > /dev/null 2>&1 && flutter analyze --no-fatal-infos" || true
run_check "auth_shared: tests" "cd '$ROOT_DIR/packages/auth_shared' && flutter test" || true
run_check "core_shared: analyze" "cd '$ROOT_DIR/packages/core_shared' && flutter pub get > /dev/null 2>&1 && flutter analyze --no-fatal-infos" || true

# ============================================
# GATE B: EMULATOR GATES (RULES + TESTS)
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 GATE B: Security & Emulator Gates"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# B1: Firestore Rules Tests
run_check "Firestore Rules: install deps" "cd '$ROOT_DIR/firestore-rules-tests' && npm ci > /dev/null 2>&1" || true
run_check "Firestore Rules: security tests" "cd '$ROOT_DIR/firestore-rules-tests' && npm test" || true

# B2: Integration Tests (requires emulator)
echo ""
echo -e "${YELLOW}⚠️  Integration tests require Firebase Auth emulator running${NC}"
echo "Start emulator in separate terminal: firebase emulators:start --only auth"
echo ""
read -p "Is Firebase Auth emulator running on localhost:9099? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  run_check "Driver Integration: auth flow" "cd '$ROOT_DIR/apps/wawapp_driver' && flutter test integration_test/auth_flow_test.dart" || true
  run_check "Driver Integration: logout flow" "cd '$ROOT_DIR/apps/wawapp_driver' && flutter test integration_test/logout_flow_test.dart" || true
else
  echo -e "${YELLOW}⚠️  SKIPPED${NC}: Integration tests (emulator not running)"
  echo "To run integration tests:"
  echo "  1. Terminal 1: firebase emulators:start --only auth"
  echo "  2. Terminal 2: cd apps/wawapp_driver && flutter test integration_test/"
fi

# ============================================
# SUMMARY
# ============================================

echo ""
echo "=================================================="
echo "📊 STAGING GATE SUMMARY"
echo "=================================================="
echo ""
echo "Total Checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✅ ALL GATES PASSED - GO FOR STAGING${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Complete manual device gates (Gate C)"
  echo "  2. Verify observability (Gate D)"
  echo "  3. Test cloud functions (Gate E)"
  echo "  4. Sign off on STAGING_GO_NO_GO.md"
  exit 0
else
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}❌ $FAILED_CHECKS GATE(S) FAILED - NO-GO${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Action required:"
  echo "  1. Review failed checks above"
  echo "  2. Fix issues"
  echo "  3. Re-run: ./scripts/staging_gate.sh"
  exit 1
fi
