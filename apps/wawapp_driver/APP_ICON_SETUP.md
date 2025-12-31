# Driver App Icon Setup Guide

## Overview
This guide explains how to implement the official WawApp Driver app icon based on the Manus Visual Identity.

## Design Assets Required
The official driver app icon (`app_icon_1024.png`) should be obtained from the Manus Visual Identity package. The icon features:
- Driver logo on gradient background
- Size: 1024x1024 pixels
- Optimized for both Android and iOS

## Android Icon Implementation

### Directory Structure
```
android/app/src/main/res/
├── mipmap-hdpi/       (72x72)
├── mipmap-mdpi/       (48x48)
├── mipmap-xhdpi/      (96x96)
├── mipmap-xxhdpi/     (144x144)
└── mipmap-xxxhdpi/    (192x192)
```

### Required Files for Each Directory
Each mipmap directory needs:
- `ic_launcher.png` - Standard launcher icon
- `ic_launcher_foreground.png` - Adaptive icon foreground layer (Android 8.0+)
- `ic_launcher_background.png` - Adaptive icon background layer (Android 8.0+)

### Adaptive Icon XML
File: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

### Generation Commands (Using ImageMagick)
```bash
# Install ImageMagick if not available
# For Ubuntu/Debian: sudo apt-get install imagemagick

# From 1024x1024 source image, generate Android icons:
convert app_icon_1024.png -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
convert app_icon_1024.png -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
convert app_icon_1024.png -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
convert app_icon_1024.png -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
convert app_icon_1024.png -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
```

## iOS Icon Implementation

### Directory Structure
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
├── Icon-App-20x20@1x.png        (20x20)
├── Icon-App-20x20@2x.png        (40x40)
├── Icon-App-20x20@3x.png        (60x60)
├── Icon-App-29x29@1x.png        (29x29)
├── Icon-App-29x29@2x.png        (58x58)
├── Icon-App-29x29@3x.png        (87x87)
├── Icon-App-40x40@1x.png        (40x40)
├── Icon-App-40x40@2x.png        (80x80)
├── Icon-App-40x40@3x.png        (120x120)
├── Icon-App-60x60@2x.png        (120x120)
├── Icon-App-60x60@3x.png        (180x180)
├── Icon-App-76x76@1x.png        (76x76)
├── Icon-App-76x76@2x.png        (152x152)
├── Icon-App-83.5x83.5@2x.png    (167x167)
└── Icon-App-1024x1024@1x.png    (1024x1024)
```

### Contents.json
File: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`

This file defines all icon sizes and their mapping. See the existing file for the complete structure.

### Generation Commands (Using ImageMagick)
```bash
# From 1024x1024 source image, generate iOS icons:
cd ios/Runner/Assets.xcassets/AppIcon.appiconset/

convert app_icon_1024.png -resize 20x20 Icon-App-20x20@1x.png
convert app_icon_1024.png -resize 40x40 Icon-App-20x20@2x.png
convert app_icon_1024.png -resize 60x60 Icon-App-20x20@3x.png
convert app_icon_1024.png -resize 29x29 Icon-App-29x29@1x.png
convert app_icon_1024.png -resize 58x58 Icon-App-29x29@2x.png
convert app_icon_1024.png -resize 87x87 Icon-App-29x29@3x.png
convert app_icon_1024.png -resize 40x40 Icon-App-40x40@1x.png
convert app_icon_1024.png -resize 80x80 Icon-App-40x40@2x.png
convert app_icon_1024.png -resize 120x120 Icon-App-40x40@3x.png
convert app_icon_1024.png -resize 120x120 Icon-App-60x60@2x.png
convert app_icon_1024.png -resize 180x180 Icon-App-60x60@3x.png
convert app_icon_1024.png -resize 76x76 Icon-App-76x76@1x.png
convert app_icon_1024.png -resize 152x152 Icon-App-76x76@2x.png
convert app_icon_1024.png -resize 167x167 Icon-App-83.5x83.5@2x.png
cp app_icon_1024.png Icon-App-1024x1024@1x.png
```

## Automated Icon Generation Tools

### flutter_launcher_icons Package
Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon_1024.png"
  adaptive_icon_background: "#00704A"  # Manus primary green
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

Run:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

## Verification Steps

### Android
1. Build the app: `flutter build apk`
2. Install on device: `flutter install`
3. Check home screen for correct icon
4. Check app drawer for correct icon
5. Verify adaptive icon on Android 8.0+ devices

### iOS
1. Build the app: `flutter build ios`
2. Install on device via Xcode or TestFlight
3. Check home screen for correct icon
4. Verify all icon sizes in Xcode (no warnings)

## Design Specifications (Manus Visual Identity)

### Color Palette
- **Primary Green**: #00704A (Mauritania flag green)
- **Golden Yellow**: #F5A623 (Mauritania flag gold)
- **Accent Red**: #C1272D (Mauritania flag red)
- **Background**: #F8F9FA (Light)
- **Dark Background**: #0A1612 (Dark mode)

### Typography
- **Primary Font**: Inter (Bold for headings, Medium for UI)
- **Secondary Font**: DM Sans (Regular for body text)

### Icon Design Principles
- Clear visibility at all sizes
- Driver logo centered
- Gradient background using Mauritania flag colors
- Consistent with client app but distinguishable for drivers

## Troubleshooting

### Android Issues
- **Icon not updating**: Clear app data and reinstall
- **Adaptive icon not showing**: Ensure mipmap-anydpi-v26 XML is correct
- **Build fails**: Check all mipmap directories have required files

### iOS Issues
- **Missing icon sizes**: Verify all sizes in Contents.json exist as files
- **Xcode warnings**: Ensure all referenced files are present
- **Icon appears black**: Check image has no transparency issues

## Next Steps
1. Obtain official `app_icon_1024.png` from design team
2. Run icon generation script or use flutter_launcher_icons
3. Test on both Android and iOS devices
4. Verify adaptive icons on Android 8.0+
5. Submit to app stores with proper icon assets
