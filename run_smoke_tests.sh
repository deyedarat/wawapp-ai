#!/bin/bash
set -e

echo "=== WAWAPP AUTH SMOKE TESTS ==="

# Check for devices
flutter devices

echo ""
echo "[1/2] Running Client Auth Smoke Test..."
cd apps/wawapp_client
flutter test integration_test/smoke_auth_flow_test.dart

echo ""
echo "[2/2] Running Driver Auth Smoke Test..."
cd ../wawapp_driver
flutter test integration_test/smoke_auth_flow_test.dart

cd ../../
echo ""
echo "✅ All Smoke Tests Passed Successfully!"
