# سير عمل الهجرة إلى Riverpod

## 0. تثبيت Git (إن لم يكن موجود)

```powershell
cd c:\Users\user\Music\WawApp\root
.\tools\install_git.ps1
# أعد تشغيل PowerShell بعد التثبيت
```

## 1. فحص الإعداد

```powershell
cd c:\Users\user\Music\WawApp\root
.\tools\check_setup.ps1
```

## 2. تنظيف Bloc

### في pubspec.yaml (client & driver):
```yaml
# احذف:
# flutter_bloc: ^x.x.x
# bloc: ^x.x.x
# bloc_test: ^x.x.x

# أضف:
dependencies:
  flutter_riverpod: ^2.5.0
```

```powershell
flutter pub get
.\tools\clean_bloc.ps1 -DryRun
```

## 3. هجرة Auth

```powershell
.\tools\migrate_to_riverpod.ps1 -Feature auth
```

### الخطوات:
1. إنشاء `lib/features/auth/auth_controller.dart`
2. تحديث `main.dart` → `ProviderScope`
3. تحديث الشاشات:
   - `BlocBuilder` → `Consumer + ref.watch`
   - `BlocListener` → `ref.listen`
   - `context.read<Bloc>()` → `ref.read(provider.notifier)`

### الفحص:
```powershell
dart format . --set-exit-if-changed
flutter analyze
.\tools\arch_guard.ps1
```

### الاختبار:
```powershell
flutter test
```

### الالتزام:
```powershell
git add .
git commit -m "refactor(auth): migrate Bloc→Riverpod"
```

## 4. هجرة Nearby

```powershell
.\tools\migrate_to_riverpod.ps1 -Feature nearby
# كرر نفس الخطوات
git add . && git commit -m "refactor(nearby): riverpod migration"
```

## 5. هجرة Wallet

```powershell
.\tools\migrate_to_riverpod.ps1 -Feature wallet
# كرر نفس الخطوات
git add . && git commit -m "refactor(wallet): riverpod migration"
```

## 6. اختبار التشغيل

```powershell
flutter run -d windows --debug
# اختبر: login → otp/pin → nearby → wallet
```

## القوالب المتاحة

- `tools/riverpod_controller_template.dart` - Controller
- `tools/riverpod_ui_template.dart` - UI
- `tools/test_auth_template.dart` - Tests

## الفحص النهائي

```powershell
.\tools\clean_bloc.ps1
.\tools\arch_guard.ps1
flutter analyze
flutter test
```
