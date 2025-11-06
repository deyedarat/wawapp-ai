# خطة الهجرة إلى Riverpod

## الترتيب المقترح

### 1. Auth (الأولوية القصوى)
- [ ] إنشاء `lib/features/auth/auth_controller.dart`
- [ ] تحديث `phone_pin_login_screen.dart`
- [ ] تحديث `otp_screen.dart`
- [ ] تحديث `create_pin_screen.dart`
- [ ] فحص: `flutter analyze && .\tools\arch_guard.ps1`

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
