# WawApp Client Localization Guide

## Overview

This guide helps you complete the bilingual localization (Arabic + French) for the WawApp client app.

## Current Status

### ✅ Completed
- **ARB Files Created**: `lib/l10n/intl_ar.arb` and `lib/l10n/intl_fr.arb` with 150+ translation keys
- **ShipmentType Model**: Updated to support localization via `getLabel(BuildContext)`
- **ShipmentTypeScreen**: Fully localized
- **AboutScreen**: Fully localized
- **Infrastructure**: Flutter localization setup is ready

### ⏳ Remaining Work

The following files still contain hard-coded Arabic strings and need localization:

#### High Priority (User-facing screens)
1. `lib/features/quote/quote_screen.dart` - Quote/pricing display
2. `lib/features/home/home_screen.dart` - Main map/home screen
3. `lib/features/track/track_screen.dart` - Order tracking
4. `lib/features/track/driver_found_screen.dart` - Driver found notification
5. `lib/features/track/trip_completed_screen.dart` - Trip completion
6. `lib/features/profile/client_profile_screen.dart` - User profile
7. `lib/features/profile/saved_locations_screen.dart` - Saved locations
8. `lib/features/profile/add_saved_location_screen.dart` - Add/edit location

#### Medium Priority (Dialogs and Widgets)
9. `lib/features/map/places_autocomplete_sheet.dart` - Place search
10. `lib/features/map/saved_location_selector_sheet.dart` - Location selector
11. `lib/features/track/widgets/rating_bottom_sheet.dart` - Rating dialog
12. `lib/features/track/widgets/order_status_timeline.dart` - Status timeline
13. `lib/features/quote/widgets/order_summary_sheet.dart` - Order summary

#### Low Priority (Auth screens - may have separate localization)
14. `lib/features/auth/phone_pin_login_screen.dart`
15. `lib/features/auth/otp_screen.dart`
16. `lib/features/auth/create_pin_screen.dart`

## Step-by-Step Localization Process

### Step 1: Generate Localization Files

Run the Flutter localization generation command:

\`\`\`bash
cd apps/wawapp_client
flutter gen-l10n
\`\`\`

This will generate/update:
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_ar.dart`
- `lib/l10n/app_localizations_fr.dart`

### Step 2: Update Each Screen

For each file in the "Remaining Work" list:

1. **Import the localization package**:
   \`\`\`dart
   import '../../l10n/app_localizations.dart';
   \`\`\`

2. **Get the localizations instance in build method**:
   \`\`\`dart
   final l10n = AppLocalizations.of(context)!;
   \`\`\`

3. **Replace hard-coded strings**:
   
   **Before:**
   \`\`\`dart
   Text('احسب السعر')
   \`\`\`
   
   **After:**
   \`\`\`dart
   Text(l10n.get_quote)
   \`\`\`

4. **For strings with parameters**, use the ARB placeholder format:
   
   **Before:**
   \`\`\`dart
   Text('السعر: $price أوقية')
   \`\`\`
   
   **After:**
   \`\`\`dart
   Text(l10n.price.replaceAll('{price}', price.toString()))
   \`\`\`
   
   Or better, check if the ARB file has proper placeholders and use:
   \`\`\`dart
   // In intl_ar.arb:
   // "priceWithAmount": "السعر: {amount} أوقية"
   // "@priceWithAmount": {
   //   "placeholders": {
   //     "amount": {"type": "String"}
   //   }
   // }
   
   Text(l10n.priceWithAmount(price.toString()))
   \`\`\`

### Step 3: Test Both Languages

1. **Test Arabic (Default)**:
   \`\`\`bash
   flutter run
   \`\`\`
   - Should display Arabic text
   - Layout should be RTL
   - All screens should show Arabic translations

2. **Test French**:
   Change device language to French or use:
   \`\`\`dart
   // In main.dart, MaterialApp:
   locale: const Locale('fr'),
   \`\`\`
   - Should display French text
   - Layout should be LTR
   - All screens should show French translations

3. **Test Language Switching** (if implemented):
   - Add language selector in profile/settings
   - Test switching between Arabic ↔ French
   - Verify layout direction changes (RTL ↔ LTR)

## Translation Keys Reference

All translation keys are in:
- `apps/wawapp_client/lib/l10n/intl_ar.arb` (Arabic)
- `apps/wawapp_client/lib/l10n/intl_fr.arb` (French)

### Key Categories

- **App Basics**: `appTitle`, `pickup`, `dropoff`, `currency`
- **Shipment Types**: `shipmentFoodPerishables`, `shipmentFurniture`, etc.
- **Order Status**: `statusAssigning`, `statusAccepted`, `statusCompleted`
- **Driver Info**: `driverName`, `driverPhone`, `vehicle`
- **Actions**: `save`, `cancel`, `delete`, `edit`, `retry`
- **Profile**: `profile`, `editProfile`, `name`, `phone`, `address`
- **Locations**: `savedLocations`, `addLocation`, `latitude`, `longitude`
- **Messages**: `orderCreatedSuccess`, `ratingSuccess`, `profileSaved`
- **Errors**: `orderCreationError`, `profileLoadError`, etc.

## RTL/LTR Layout Considerations

### Automatic RTL Support

Flutter automatically handles RTL for Arabic when you use:

\`\`\`dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ...
)
\`\`\`

### Manual RTL Fixes

If you encounter layout issues, use:

1. **DirectionalPadding**:
   \`\`\`dart
   // Instead of:
   padding: EdgeInsets.only(left: 16)
   
   // Use:
   padding: EdgeInsetsDirectional.only(start: 16)
   \`\`\`

2. **TextDirection**:
   \`\`\`dart
   Text(
     text,
     textDirection: TextDirection.rtl, // or ltr
   )
   \`\`\`

3. **Alignment**:
   \`\`\`dart
   // Instead of:
   alignment: Alignment.centerLeft
   
   // Use:
   alignment: AlignmentDirectional.centerStart
   \`\`\`

## Adding New Translation Keys

If you need a translation not in the ARB files:

1. **Add to `intl_ar.arb`**:
   \`\`\`json
   {
     "newKey": "النص العربي",
     "newKeyWithParam": "النص مع {param}",
     "@newKeyWithParam": {
       "placeholders": {
         "param": {"type": "String"}
       }
     }
   }
   \`\`\`

2. **Add to `intl_fr.arb`**:
   \`\`\`json
   {
     "newKey": "Texte français",
     "newKeyWithParam": "Texte avec {param}"
   }
   \`\`\`

3. **Regenerate localization files**:
   \`\`\`bash
   flutter gen-l10n
   \`\`\`

4. **Use in code**:
   \`\`\`dart
   Text(l10n.newKey)
   Text(l10n.newKeyWithParam('value'))
   \`\`\`

## Common Patterns

### Pattern 1: Simple Text Replacement

\`\`\`dart
// Before
const Text('احسب السعر')

// After
Text(l10n.get_quote)
\`\`\`

### Pattern 2: Conditional Text

\`\`\`dart
// Before
Text(isCompleted ? 'تم الإكمال' : 'قيد التنفيذ')

// After
Text(isCompleted ? l10n.statusCompleted : l10n.statusAssigning)
\`\`\`

### Pattern 3: Formatted Strings

\`\`\`dart
// Before
Text('المسافة: ${distance.toStringAsFixed(1)} كم')

// After (assuming ARB has proper placeholders)
Text(l10n.distance.replaceAll('{km}', distance.toStringAsFixed(1)))
\`\`\`

### Pattern 4: SnackBar Messages

\`\`\`dart
// Before
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('تم الحفظ بنجاح')),
);

// After
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(l10n.profileSaved)),
);
\`\`\`

### Pattern 5: Dialog Messages

\`\`\`dart
// Before
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('تأكيد الحذف'),
    content: Text('هل تريد حذف "$name"؟'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      TextButton(
        onPressed: () => _delete(),
        child: const Text('حذف'),
      ),
    ],
  ),
);

// After
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(l10n.deleteLocation),
    content: Text(l10n.deleteLocationConfirm.replaceAll('{name}', name)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.cancel),
      ),
      TextButton(
        onPressed: () => _delete(),
        child: Text(l10n.delete),
      ),
    ],
  ),
);
\`\`\`

## Testing Checklist

- [ ] All screens display correct language
- [ ] Arabic text appears in RTL layout
- [ ] French text appears in LTR layout
- [ ] No hard-coded Arabic/French strings remain
- [ ] Shipment type categories display correctly
- [ ] Price calculations show in correct format
- [ ] Error messages are localized
- [ ] Success messages are localized
- [ ] Dialog buttons use correct language
- [ ] SnackBars show localized text
- [ ] Navigation works in both languages
- [ ] Forms validate with localized messages
- [ ] Date/time formatting is culturally appropriate

## Troubleshooting

### Issue: "AppLocalizations.of(context) returns null"

**Solution**: Make sure you're calling it in a widget that's below the MaterialApp:

\`\`\`dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(), // AppLocalizations available here
    );
  }
}
\`\`\`

### Issue: "Translation key not found"

**Solution**: 
1. Check if the key exists in both `intl_ar.arb` and `intl_fr.arb`
2. Run `flutter gen-l10n` to regenerate localization files
3. Restart your IDE/Flutter app

### Issue: "Layout breaks in RTL"

**Solution**:
- Use `EdgeInsetsDirectional` instead of `EdgeInsets`
- Use `AlignmentDirectional` instead of `Alignment`
- Avoid hardcoded left/right in positioning

### Issue: "Text doesn't wrap properly in Arabic"

**Solution**:
\`\`\`dart
Text(
  arabicText,
  softWrap: true,
  overflow: TextOverflow.visible,
  textDirection: TextDirection.rtl,
)
\`\`\`

## Best Practices

1. **Always use l10n keys**: Never hardcode displayable text
2. **Test both languages**: Don't assume it works in one if it works in the other
3. **Use meaningful key names**: `orderCreatedSuccess` not `message1`
4. **Group related keys**: Use prefixes like `shipment*`, `status*`, `profile*`
5. **Document parameters**: Use ARB `@key` metadata for placeholders
6. **Handle plurals properly**: Use ICU message format for countable items
7. **Consider text length**: French text is often 20-30% longer than English
8. **Test edge cases**: Long names, special characters, empty states

## Resources

- [Flutter Internationalization](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB Format](https://github.com/google/app-resource-bundle)
- [ICU Message Format](https://unicode-org.github.io/icu/userguide/format_parse/messages/)

## Need Help?

If you encounter issues or need clarification:
1. Check this guide first
2. Review the existing localized screens (ShipmentTypeScreen, AboutScreen)
3. Look at the ARB files for available keys
4. Test in both languages before committing

---

**Next Steps**: Start with the high-priority screens listed above and work your way through the list. Good luck! 🚀
