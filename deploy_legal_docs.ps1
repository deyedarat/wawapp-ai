# ============================================================================
# WawApp - Deploy Legal Documents to Firebase Hosting
# ============================================================================
# This script prepares and deploys privacy policy and terms of service
# to Firebase Hosting for Google Play compliance
# ============================================================================

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  WawApp - Legal Documents Deployment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create public directory for hosting
Write-Host "[1/5] Creating public directory..." -ForegroundColor Yellow
$publicDir = "public"
if (-not (Test-Path $publicDir)) {
    New-Item -ItemType Directory -Path $publicDir -Force | Out-Null
    Write-Host "✓ Created public directory" -ForegroundColor Green
} else {
    Write-Host "✓ Public directory already exists" -ForegroundColor Green
}

# Step 2: Copy legal documents
Write-Host ""
Write-Host "[2/5] Copying legal documents..." -ForegroundColor Yellow

# Copy privacy policy
if (Test-Path "docs/privacy-policy.html") {
    Copy-Item "docs/privacy-policy.html" "$publicDir/privacy.html" -Force
    Write-Host "✓ Copied privacy-policy.html → public/privacy.html" -ForegroundColor Green
} else {
    Write-Host "✗ Error: docs/privacy-policy.html not found!" -ForegroundColor Red
    exit 1
}

# Copy terms of service
if (Test-Path "docs/terms-of-service.html") {
    Copy-Item "docs/terms-of-service.html" "$publicDir/terms.html" -Force
    Write-Host "✓ Copied terms-of-service.html → public/terms.html" -ForegroundColor Green
} else {
    Write-Host "✗ Error: docs/terms-of-service.html not found!" -ForegroundColor Red
    exit 1
}

# Step 3: Create index.html redirect page
Write-Host ""
Write-Host "[3/5] Creating index page..." -ForegroundColor Yellow

$indexHtml = @"
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WawApp - Legal Documents</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        }
        h1 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 2em;
        }
        p {
            color: #666;
            margin-bottom: 30px;
            line-height: 1.6;
        }
        .links {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        a {
            display: block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            padding: 15px 25px;
            border-radius: 10px;
            text-align: center;
            font-weight: 600;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        a:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            color: #999;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>WawApp</h1>
        <p>مرحباً بك في تطبيق واو - خدمة التوصيل السريع في موريتانيا</p>
        <div class="links">
            <a href="/privacy.html">سياسة الخصوصية</a>
            <a href="/terms.html">شروط الخدمة</a>
        </div>
        <div class="footer">
            <p>© 2026 WawApp. جميع الحقوق محفوظة.</p>
        </div>
    </div>
</body>
</html>
"@

Set-Content -Path "$publicDir/index.html" -Value $indexHtml -Encoding UTF8
Write-Host "✓ Created index.html" -ForegroundColor Green

# Step 4: Create 404 page
Write-Host ""
Write-Host "[4/5] Creating 404 page..." -ForegroundColor Yellow

$notFoundHtml = @"
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - الصفحة غير موجودة</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            text-align: center;
        }
        h1 {
            color: #667eea;
            font-size: 4em;
            margin-bottom: 10px;
        }
        h2 {
            color: #333;
            margin-bottom: 20px;
        }
        p {
            color: #666;
            margin-bottom: 30px;
            line-height: 1.6;
        }
        a {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            padding: 15px 30px;
            border-radius: 10px;
            font-weight: 600;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        a:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>404</h1>
        <h2>الصفحة غير موجودة</h2>
        <p>عذراً، الصفحة التي تبحث عنها غير موجودة.</p>
        <a href="/">العودة للصفحة الرئيسية</a>
    </div>
</body>
</html>
"@

Set-Content -Path "$publicDir/404.html" -Value $notFoundHtml -Encoding UTF8
Write-Host "✓ Created 404.html" -ForegroundColor Green

# Step 5: Update firebase.json for legal docs hosting
Write-Host ""
Write-Host "[5/5] Updating firebase.json..." -ForegroundColor Yellow

# Backup original firebase.json
Copy-Item "firebase.json" "firebase.json.backup" -Force
Write-Host "✓ Created backup: firebase.json.backup" -ForegroundColor Green

# Create new firebase.json with multiple hosting sites
$firebaseConfig = @"
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log"
      ]
    }
  ],
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "hosting": [
    {
      "target": "legal",
      "public": "public",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "headers": [
        {
          "source": "**/*.@(html|htm)",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "public, max-age=3600, s-maxage=3600"
            }
          ]
        }
      ]
    },
    {
      "target": "admin",
      "public": "apps/wawapp_admin/build/web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ],
      "headers": [
        {
          "source": "**/*.@(js|css|woff|woff2|ttf|eot|svg|png|jpg|jpeg|gif|ico)",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "public, max-age=604800, s-maxage=604800"
            }
          ]
        }
      ]
    }
  ],
  "emulators": {
    "firestore": {
      "port": 8080
    },
    "auth": {
      "port": 9099
    },
    "functions": {
      "port": 5001
    },
    "ui": {
      "enabled": true,
      "port": 4000
    },
    "singleProjectMode": true
  }
}
"@

Set-Content -Path "firebase.json" -Value $firebaseConfig -Encoding UTF8
Write-Host "✓ Updated firebase.json with legal docs hosting" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Deployment Preparation Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files created:" -ForegroundColor Yellow
Write-Host "  ✓ public/index.html" -ForegroundColor White
Write-Host "  ✓ public/privacy.html" -ForegroundColor White
Write-Host "  ✓ public/terms.html" -ForegroundColor White
Write-Host "  ✓ public/404.html" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: firebase deploy --only hosting:legal" -ForegroundColor White
Write-Host "  2. Verify URLs:" -ForegroundColor White
Write-Host "     - https://wawapp-952d6.web.app/privacy.html" -ForegroundColor Cyan
Write-Host "     - https://wawapp-952d6.web.app/terms.html" -ForegroundColor Cyan
Write-Host "  3. Update Play Console with these URLs" -ForegroundColor White
Write-Host ""
Write-Host "Note: You may need to configure custom domain (wawappmr.com)" -ForegroundColor Yellow
Write-Host "      in Firebase Hosting settings for production URLs." -ForegroundColor Yellow
Write-Host ""
