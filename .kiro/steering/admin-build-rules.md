---
inclusion: auto
---

# قواعد بناء لوحة الإدارة (wawapp_admin)

## قاعدة إلزامية: flutter clean قبل build web

عند بناء `apps/wawapp_admin` للويب، يجب **دائماً** تنفيذ `flutter clean` أولاً:

```bash
cd apps/wawapp_admin
flutter clean
flutter pub get
flutter build web --release --no-wasm-dry-run
```

### السبب:
Flutter يُخبّئ ملف `web_plugin_registrant.dart` في `.dart_tool/flutter_build/`.
إذا أُضيفت حزمة (مثل `google_maps_flutter`) بعد أول بناء، الملف المُخبّأ لا يُحدّث تلقائياً.
هذا يسبب خطأ `TargetPlatform.windows is not yet supported by the maps plugin` لأن `google_maps_flutter_web` لا يُسجّل.

### النشر:
```bash
firebase deploy --only hosting:admin
```
