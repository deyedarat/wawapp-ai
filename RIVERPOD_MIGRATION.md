# خطة الهجرة إلى Riverpod

## الترتيب المقترح

### 1. Auth (الأولوية القصوى) ✅ مكتمل
- [x] إنشاء `lib/features/auth/providers/auth_service_provider.dart` (AuthNotifier + authProvider)
- [x] تحديث `phone_pin_login_screen.dart` (ConsumerStatefulWidget + ref.watch/read)
- [x] تحديث `otp_screen.dart` (Already using service calls)
- [x] تحديث `create_pin_screen.dart` (ConsumerStatefulWidget + ref.watch/read)
- [x] تحديث `auth_gate.dart` (ConsumerWidget + ref.watch)
- [x] إزالة Bloc: لا توجد ملفات Bloc مرتبطة بـ Auth للإزالة
- [x] فحص: No Bloc dependencies in pubspec.yaml, no Bloc imports in code

### 2. Nearby (الطلبات القريبة)
- [ ] إنشاء `lib/features/nearby/nearby_controller.dart`
- [ ] تحديث شاشات nearby
- [ ] فحص: `flutter analyze && .\tools\arch_guard.ps1`

### 3. Wallet (المحفظة)
- [ ] إنشاء `lib/features/wallet/wallet_controller.dart`
- [ ] تحديث شاشات wallet
- [ ] فحص: `flutter analyze && .\tools\arch_guard.ps1`

## القوالب الجاهزة

```powershell
# عرض خطوات الهجرة
.\tools\migrate_to_riverpod.ps1 -Feature auth

# القوالب في
tools/templates/riverpod_controller_template.dart
tools/templates/riverpod_ui_template.dart
```

## التحقق من main.dart

تأكد من وجود:
```dart
runApp(const ProviderScope(child: MyApp()));
```

## الأنماط

### Controller Pattern
```dart
class XController extends StateNotifier<XState> {
  XController(): super(const XState());
  // methods here
}

final xControllerProvider =
  StateNotifierProvider<XController, XState>((ref) => XController());
```

### UI Pattern
```dart
class XScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(xControllerProvider);
    // UI here
  }
}
```

## الفحص النهائي

```powershell
dart format . --set-exit-if-changed
flutter analyze
.\tools\arch_guard.ps1
```

## حالة الهجرة - Auth Feature

### Phase 1-2: إعداد Riverpod ✅
- تم إنشاء AuthNotifier و AuthState في `lib/features/auth/providers/auth_service_provider.dart`
- تم إضافة ProviderScope في main.dart
- تم تكامل authProvider مع Firebase Auth

### Phase 3: هجرة الشاشات ✅
- تاريخ الإنجاز: 2025-11-06
- Commits:
  - `de5a3bf`: feat(auth): migrate create_pin_screen to Riverpod
  - `295b16b`: feat(auth): migrate phone_pin_login_screen to Riverpod
  - `d70eae2`: feat(auth): migrate auth_gate to Riverpod

### Phase 4: إزالة Bloc ✅
- تاريخ التحقق: 2025-11-06
- النتيجة: **لم يتم العثور على ملفات أو تبعيات Bloc للإزالة**
- التحقق:
  - ✅ لا توجد ملفات `*bloc*.dart` أو `*cubit*.dart` في `features/auth/`
  - ✅ لا توجد imports لـ `flutter_bloc` في أي ملف
  - ✅ لا توجد استخدامات لـ `BlocProvider`, `BlocBuilder`, `BlocListener`, `BlocConsumer`
  - ✅ لا توجد تبعية `flutter_bloc` في `pubspec.yaml` (كلا التطبيقين)
  - ✅ لا توجد مجلدات `bloc/` في feature Auth

**الخلاصة**: ميزة Auth مهاجرة بالكامل إلى Riverpod ونظيفة من أي آثار Bloc.
