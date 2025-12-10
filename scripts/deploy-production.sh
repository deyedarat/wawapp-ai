#!/bin/bash
##############################################################################
# WawApp Production Deployment Script
# 
# This script deploys the complete WawApp stack to Firebase:
# - Cloud Functions (reports, finance, admin, core)
# - Firestore Rules & Indexes
# - Admin Panel (Flutter Web to Hosting)
#
# PREREQUISITES:
# - Firebase CLI installed and logged in
# - Flutter SDK installed (3.0.0+)
# - Node.js 20.x installed
# - Chrome browser available for Flutter web build
#
# USAGE:
#   ./scripts/deploy-production.sh [options]
#
# OPTIONS:
#   --functions-only    Deploy only Cloud Functions
#   --firestore-only    Deploy only Firestore rules/indexes
#   --hosting-only      Deploy only Admin Panel hosting
#   --all               Deploy everything (default)
#   --dry-run           Show what would be deployed without executing
#
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
DEPLOY_FUNCTIONS=false
DEPLOY_FIRESTORE=false
DEPLOY_HOSTING=false
DRY_RUN=false

if [ $# -eq 0 ]; then
  DEPLOY_FUNCTIONS=true
  DEPLOY_FIRESTORE=true
  DEPLOY_HOSTING=true
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --functions-only)
      DEPLOY_FUNCTIONS=true
      shift
      ;;
    --firestore-only)
      DEPLOY_FIRESTORE=true
      shift
      ;;
    --hosting-only)
      DEPLOY_HOSTING=true
      shift
      ;;
    --all)
      DEPLOY_FUNCTIONS=true
      DEPLOY_FIRESTORE=true
      DEPLOY_HOSTING=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--functions-only|--firestore-only|--hosting-only|--all|--dry-run]"
      exit 1
      ;;
  esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      WawApp Production Deployment Script                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verify we're in the correct directory
if [ ! -f "$PROJECT_ROOT/firebase.json" ]; then
  echo -e "${RED}Error: firebase.json not found in $PROJECT_ROOT${NC}"
  echo "Please run this script from the WawApp repository root"
  exit 1
fi

cd "$PROJECT_ROOT"

# Check Firebase project
echo -e "${YELLOW}📋 Checking Firebase project...${NC}"
FIREBASE_PROJECT=$(firebase use 2>&1 | grep "Active Project" | awk '{print $3}' || echo "unknown")
echo "Active Firebase project: $FIREBASE_PROJECT"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
  echo ""
fi

##############################################################################
# 1. DEPLOY CLOUD FUNCTIONS
##############################################################################

if [ "$DEPLOY_FUNCTIONS" = true ]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}1. DEPLOYING CLOUD FUNCTIONS${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  cd "$PROJECT_ROOT/functions"

  # Install dependencies
  echo -e "${YELLOW}📦 Installing Cloud Functions dependencies...${NC}"
  if [ "$DRY_RUN" = false ]; then
    npm install
  else
    echo "[DRY RUN] Would run: npm install"
  fi
  echo ""

  # Build TypeScript
  echo -e "${YELLOW}🔨 Building TypeScript...${NC}"
  if [ "$DRY_RUN" = false ]; then
    npm run build
    
    # Check for build errors
    if [ $? -ne 0 ]; then
      echo -e "${RED}❌ TypeScript build failed!${NC}"
      echo "Please fix compilation errors before deploying"
      exit 1
    fi
  else
    echo "[DRY RUN] Would run: npm run build"
  fi
  echo ""

  # List functions to be deployed
  echo -e "${YELLOW}📋 Functions to be deployed:${NC}"
  echo "  Core Functions:"
  echo "    • expireStaleOrders (scheduled)"
  echo "    • aggregateDriverRating (Firestore trigger)"
  echo "    • notifyOrderEvents (Firestore trigger)"
  echo "    • cleanStaleDriverLocations (scheduled)"
  echo ""
  echo "  Admin Functions:"
  echo "    • setAdminRole, removeAdminRole"
  echo "    • getAdminStats"
  echo "    • adminCancelOrder, adminReassignOrder"
  echo "    • adminBlockDriver, adminUnblockDriver, adminVerifyDriver"
  echo "    • adminSetClientVerification, adminBlockClient, adminUnblockClient"
  echo ""
  echo "  Reports Functions:"
  echo "    • getReportsOverview"
  echo "    • getFinancialReport"
  echo "    • getDriverPerformanceReport"
  echo ""
  echo "  Finance Functions:"
  echo "    • onOrderCompleted (Firestore trigger - order settlement)"
  echo "    • adminCreatePayoutRequest"
  echo "    • adminUpdatePayoutStatus"
  echo ""

  # Deploy functions
  echo -e "${YELLOW}🚀 Deploying Cloud Functions...${NC}"
  if [ "$DRY_RUN" = false ]; then
    cd "$PROJECT_ROOT"
    firebase deploy --only functions
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ Cloud Functions deployed successfully!${NC}"
    else
      echo -e "${RED}❌ Cloud Functions deployment failed!${NC}"
      exit 1
    fi
  else
    echo "[DRY RUN] Would run: firebase deploy --only functions"
  fi
  echo ""

  cd "$PROJECT_ROOT"
fi

##############################################################################
# 2. DEPLOY FIRESTORE RULES & INDEXES
##############################################################################

if [ "$DEPLOY_FIRESTORE" = true ]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}2. DEPLOYING FIRESTORE RULES & INDEXES${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Verify files exist
  if [ ! -f "$PROJECT_ROOT/firestore.rules" ]; then
    echo -e "${RED}❌ firestore.rules not found!${NC}"
    exit 1
  fi

  if [ ! -f "$PROJECT_ROOT/firestore.indexes.json" ]; then
    echo -e "${RED}❌ firestore.indexes.json not found!${NC}"
    exit 1
  fi

  echo -e "${YELLOW}📋 Firestore configuration:${NC}"
  echo "  • Rules file: firestore.rules"
  echo "  • Indexes file: firestore.indexes.json"
  echo ""

  echo -e "${YELLOW}📋 Composite indexes to be deployed:${NC}"
  echo "  Orders collection:"
  echo "    • (status ASC, createdAt DESC)"
  echo "    • (driverId ASC, status ASC, completedAt DESC)"
  echo "    • (status ASC, assignedDriverId ASC, createdAt DESC)"
  echo "    • (ownerId ASC, createdAt DESC)"
  echo "    • (ownerId ASC, status ASC, createdAt DESC)"
  echo "    • (driverId ASC, status ASC)"
  echo "    • (driverId ASC, status ASC, updatedAt DESC)"
  echo ""

  # Deploy Firestore
  echo -e "${YELLOW}🚀 Deploying Firestore rules and indexes...${NC}"
  if [ "$DRY_RUN" = false ]; then
    firebase deploy --only firestore
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ Firestore rules and indexes deployed successfully!${NC}"
      echo -e "${YELLOW}⚠️  Note: Index creation may take several minutes to complete.${NC}"
      echo "   Monitor index status at: https://console.firebase.google.com/project/$FIREBASE_PROJECT/firestore/indexes"
    else
      echo -e "${RED}❌ Firestore deployment failed!${NC}"
      exit 1
    fi
  else
    echo "[DRY RUN] Would run: firebase deploy --only firestore"
  fi
  echo ""
fi

##############################################################################
# 3. DEPLOY ADMIN PANEL (Flutter Web)
##############################################################################

if [ "$DEPLOY_HOSTING" = true ]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}3. DEPLOYING ADMIN PANEL (Flutter Web)${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  cd "$PROJECT_ROOT/apps/wawapp_admin"

  # Check if Flutter is installed
  if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    echo "Please install Flutter SDK: https://flutter.dev/docs/get-started/install"
    exit 1
  fi

  echo -e "${YELLOW}📦 Installing Flutter dependencies...${NC}"
  if [ "$DRY_RUN" = false ]; then
    flutter pub get
  else
    echo "[DRY RUN] Would run: flutter pub get"
  fi
  echo ""

  # Build for web
  echo -e "${YELLOW}🔨 Building Flutter web app (production mode)...${NC}"
  echo "⚠️  This may take several minutes..."
  if [ "$DRY_RUN" = false ]; then
    flutter build web --release --web-renderer canvaskit
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}❌ Flutter web build failed!${NC}"
      exit 1
    fi
    
    # Check build output
    if [ ! -d "build/web" ]; then
      echo -e "${RED}❌ Build output directory not found!${NC}"
      exit 1
    fi
    
    echo -e "${GREEN}✅ Flutter web app built successfully!${NC}"
  else
    echo "[DRY RUN] Would run: flutter build web --release --web-renderer canvaskit"
  fi
  echo ""

  # Deploy to Firebase Hosting
  echo -e "${YELLOW}🚀 Deploying to Firebase Hosting...${NC}"
  if [ "$DRY_RUN" = false ]; then
    cd "$PROJECT_ROOT"
    
    # Check if hosting is configured
    if ! grep -q "hosting" firebase.json; then
      echo -e "${RED}❌ Firebase Hosting not configured in firebase.json${NC}"
      echo "Please add hosting configuration"
      exit 1
    fi
    
    firebase deploy --only hosting
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ Admin Panel deployed successfully!${NC}"
      echo ""
      echo -e "${GREEN}🌐 Your admin panel is now live!${NC}"
      echo "   Visit: https://$FIREBASE_PROJECT.web.app"
      echo "   or:    https://$FIREBASE_PROJECT.firebaseapp.com"
    else
      echo -e "${RED}❌ Hosting deployment failed!${NC}"
      exit 1
    fi
  else
    echo "[DRY RUN] Would run: firebase deploy --only hosting"
  fi
  echo ""

  cd "$PROJECT_ROOT"
fi

##############################################################################
# DEPLOYMENT SUMMARY
##############################################################################

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           DEPLOYMENT COMPLETED SUCCESSFULLY                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
  echo -e "${GREEN}✅ Deployment Summary:${NC}"
  if [ "$DEPLOY_FUNCTIONS" = true ]; then
    echo "  ✓ Cloud Functions deployed"
  fi
  if [ "$DEPLOY_FIRESTORE" = true ]; then
    echo "  ✓ Firestore rules and indexes deployed"
  fi
  if [ "$DEPLOY_HOSTING" = true ]; then
    echo "  ✓ Admin Panel (Flutter web) deployed"
  fi
  echo ""
  
  echo -e "${YELLOW}📋 Post-Deployment Checklist:${NC}"
  echo "  1. Monitor index creation: Firebase Console → Firestore → Indexes"
  echo "  2. Create admin user with custom claim { isAdmin: true }"
  echo "  3. Test admin login at: https://$FIREBASE_PROJECT.web.app"
  echo "  4. Verify all Cloud Functions are active: Firebase Console → Functions"
  echo "  5. Check function logs for any errors"
  echo "  6. Test key workflows:"
  echo "     • Admin login"
  echo "     • Dashboard loads"
  echo "     • Reports generate correctly"
  echo "     • Wallets display balances"
  echo "     • Payouts can be created"
  echo ""
  
  echo -e "${YELLOW}⚠️  IMPORTANT SECURITY NOTES:${NC}"
  echo "  • Ensure admin_auth_service_dev.dart is NOT used in production"
  echo "  • Verify Firestore rules are active and secure"
  echo "  • Set up monitoring and alerts for functions"
  echo "  • Configure custom domain if needed"
  echo ""
else
  echo -e "${YELLOW}🔍 DRY RUN COMPLETED - No changes were made${NC}"
  echo ""
fi

echo -e "${GREEN}🎉 Deployment process complete!${NC}"
echo ""
