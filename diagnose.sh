#!/bin/bash

# WawApp Driver - Quick Diagnostic Script
# تشخيص سريع لمشاكل الإشعارات والطلبات

echo "========================================="
echo "🔍 WawApp Driver - تشخيص سريع"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check if Firebase CLI is installed
echo "1️⃣ التحقق من Firebase CLI..."
if command -v firebase &> /dev/null; then
    echo -e "${GREEN}✅ Firebase CLI مثبت${NC}"
    firebase --version
else
    echo -e "${RED}❌ Firebase CLI غير مثبت${NC}"
    echo "قم بتثبيته: npm install -g firebase-tools"
    exit 1
fi
echo ""

# 2. Check if logged in to Firebase
echo "2️⃣ التحقق من تسجيل الدخول إلى Firebase..."
if firebase projects:list &> /dev/null; then
    echo -e "${GREEN}✅ مسجل دخول إلى Firebase${NC}"
    echo "المشروع الحالي:"
    firebase use
else
    echo -e "${RED}❌ غير مسجل دخول${NC}"
    echo "قم بتسجيل الدخول: firebase login"
    exit 1
fi
echo ""

# 3. Check Cloud Functions deployment
echo "3️⃣ التحقق من Cloud Functions..."
echo "جاري جلب قائمة Functions..."
firebase functions:list 2>&1 | grep -E "(notifyNewOrder|notifyOrderEvents|notifyUnassignedOrders)" || echo -e "${YELLOW}⚠️ لم يتم العثور على notification functions${NC}"
echo ""

# 4. Check recent Cloud Function logs
echo "4️⃣ آخر سجلات Cloud Functions (آخر 10 سجلات)..."
firebase functions:log -n 10
echo ""

# 5. Check if Flutter is installed
echo "5️⃣ التحقق من Flutter..."
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}✅ Flutter مثبت${NC}"
    flutter --version | head -1
else
    echo -e "${RED}❌ Flutter غير مثبت${NC}"
    exit 1
fi
echo ""

# 6. Check if device is connected
echo "6️⃣ التحقق من الأجهزة المتصلة..."
if command -v adb &> /dev/null; then
    DEVICES=$(adb devices | grep -v "List" | grep "device" | wc -l)
    if [ "$DEVICES" -gt 0 ]; then
        echo -e "${GREEN}✅ جهاز متصل${NC}"
        adb devices
    else
        echo -e "${RED}❌ لا يوجد جهاز متصل${NC}"
        echo "قم بتوصيل جهاز عبر USB أو WiFi"
    fi
else
    echo -e "${YELLOW}⚠️ ADB غير متوفر${NC}"
fi
echo ""

# 7. Summary and next steps
echo "========================================="
echo "📊 ملخص التشخيص"
echo "========================================="
echo ""
echo "✅ الخطوات التالية:"
echo ""
echo "1️⃣ لتشغيل تطبيق السائق:"
echo "   cd apps/wawapp_driver"
echo "   flutter run --release"
echo ""
echo "2️⃣ لمراقبة سجلات Cloud Functions:"
echo "   firebase functions:log --follow"
echo ""
echo "3️⃣ لنشر Cloud Functions (إذا لزم الأمر):"
echo "   cd functions"
echo "   npm run build"
echo "   firebase deploy --only functions:notifyNewOrder"
echo ""
echo "4️⃣ لعرض بيانات Firestore:"
echo "   افتح: https://console.firebase.google.com"
echo "   اذهب إلى: Firestore Database"
echo ""
echo "========================================="
echo "🎯 للمزيد من التفاصيل، راجع:"
echo "   TROUBLESHOOTING_NOTIFICATIONS.md"
echo "========================================="
