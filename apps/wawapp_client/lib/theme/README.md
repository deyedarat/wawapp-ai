# WawApp Client - Theme System Documentation

## Overview

This directory contains the complete, production-ready Flutter theme system for the WawApp Client app. The theme system provides:

- ✅ **Light & Dark themes** with full Material 3 support
- ✅ **Professional color palette** with semantic colors
- ✅ **Typography system** optimized for Arabic & French
- ✅ **Comprehensive component theming** (buttons, cards, inputs, etc.)
- ✅ **RTL/LTR compatibility** with directional spacing
- ✅ **Theme extensions** for custom data (shipment types, etc.)
- ✅ **No magic numbers** - all spacing/sizing constants defined
- ✅ **Backward compatible** with existing screens

## File Structure

```
theme/
├── app_theme.dart          # Main theme configurations (light & dark)
├── colors.dart             # Color palette & spacing constants
├── typography.dart         # Text styles for all use cases
├── theme_extensions.dart   # Custom theme extensions
├── components.dart         # Reusable styled components
└── README.md              # This file
```

## Quick Start

### Using the Theme

The theme is automatically applied via `MaterialApp` in `main.dart`:

```dart
MaterialApp.router(
  theme: AppTheme.lightTheme,      // Light theme
  darkTheme: AppTheme.darkTheme,   // Dark theme  
  themeMode: ThemeMode.system,     // Follows system preference
  // ...
)
```

### Accessing Theme in Widgets

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final textTheme = theme.textTheme;
  
  // Using colors
  Container(
    color: colors.primary,
    // ...
  )
  
  // Using text styles
  Text(
    'Hello',
    style: textTheme.titleLarge,
  )
}
```

### Using Custom Extensions

```dart
// Shipment type colors
final shipmentColors = context.shipmentTypeColors;
Container(color: shipmentColors.construction)

// Custom theme data
final customTheme = context.wawAppTheme;
Container(color: customTheme.successColor)
```

## Color Palette

### Primary Brand Colors

```dart
WawAppColors.primary        // #006AFF - Blue (main brand)
WawAppColors.secondary      // #FFC727 - Yellow/Gold
WawAppColors.success        // #1ABC9C - Green
WawAppColors.warning        // #F39C12 - Orange
WawAppColors.error          // #E74C3C - Red
```

### Shipment Type Colors

```dart
WawAppColors.shipmentFood           // #2ECC71 - Food & Perishables
WawAppColors.shipmentFurniture      // #A0522D - Furniture
WawAppColors.shipmentConstruction   // #E67E22 - Construction Materials
WawAppColors.shipmentAppliances     // #2980B9 - Electrical Appliances
WawAppColors.shipmentGeneral        // #7F8C8D - General Goods (default)
WawAppColors.shipmentFragile        // #C0392B - Fragile Cargo
```

### Usage Example

```dart
// ❌ NEVER do this
Container(color: Color(0xFF006AFF))

// ✅ ALWAYS do this
Container(color: WawAppColors.primary)

// ✅ Or use from theme
Container(color: Theme.of(context).colorScheme.primary)
```

## Spacing Constants

All spacing uses a base unit system (8dp):

```dart
WawAppSpacing.xxs   // 4px
WawAppSpacing.xs    // 8px
WawAppSpacing.sm    // 12px
WawAppSpacing.md    // 16px  (card padding, screen padding)
WawAppSpacing.lg    // 24px
WawAppSpacing.xl    // 32px
WawAppSpacing.xxl   // 40px
WawAppSpacing.xxxl  // 48px

// Border radius
WawAppSpacing.radiusXs   // 4px
WawAppSpacing.radiusSm   // 8px
WawAppSpacing.radiusMd   // 12px  (buttons, cards, inputs)
WawAppSpacing.radiusLg   // 16px
WawAppSpacing.radiusXl   // 20px

// Component sizes
WawAppSpacing.buttonHeight  // 52px
WawAppSpacing.inputHeight   // 56px
```

### Usage Example

```dart
// ❌ NEVER use magic numbers
Padding(padding: EdgeInsets.all(16))

// ✅ ALWAYS use constants
Padding(padding: EdgeInsets.all(WawAppSpacing.md))

// ✅ For RTL support, use EdgeInsetsDirectional
Padding(
  padding: EdgeInsetsDirectional.symmetric(
    horizontal: WawAppSpacing.md,
    vertical: WawAppSpacing.sm,
  ),
)
```

## Typography

### Text Styles

The theme includes a complete text scale:

```dart
textTheme.displayLarge   // 26px, bold    - Page titles
textTheme.displayMedium  // 22px, bold    - Section headers
textTheme.titleLarge     // 20px, w600    - Card titles
textTheme.titleMedium    // 18px, w600    - AppBar title
textTheme.titleSmall     // 16px, w600    - Subtitles
textTheme.bodyLarge      // 16px, normal  - Primary content
textTheme.bodyMedium     // 14px, normal  - Secondary content
textTheme.bodySmall      // 12px, normal  - Captions
textTheme.labelLarge     // 14px, w600    - Buttons
textTheme.labelMedium    // 12px, w600    - Chips
textTheme.labelSmall     // 11px, w500    - Small labels
```

### Usage Example

```dart
// ❌ NEVER inline text styles
Text(
  'Title',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
)

// ✅ ALWAYS use text theme
Text(
  'Title',
  style: Theme.of(context).textTheme.titleMedium,
)

// ✅ Or with context extension
Text(
  'Title',
  style: context.titleMedium,
)

// ✅ Modify if needed
Text(
  'Title',
  style: context.titleMedium?.copyWith(color: Colors.red),
)
```

## Components

### Pre-Built Styled Components

The theme includes reusable components in `components.dart`:

#### WawActionButton

Primary action button with loading state:

```dart
WawActionButton(
  label: 'احسب السعر',
  icon: Icons.calculate,
  onPressed: () {  },
  isLoading: false,
  isFullWidth: true,  // Default: fills width
)
```

#### WawSecondaryButton

Secondary/outline button:

```dart
WawSecondaryButton(
  label: 'إلغاء',
  onPressed: () {  },
)
```

#### WawCard

Consistently styled card:

```dart
WawCard(
  child: Column(
    children: [
      Text('Content'),
    ],
  ),
)
```

#### WawTextField

Pre-styled text input:

```dart
WawTextField(
  label: 'الاسم',
  hint: 'أدخل اسمك',
  controller: controller,
  prefixIcon: Icons.person,
)
```

## RTL / LTR Support

### Key Principles

1. **Use `EdgeInsetsDirectional`** instead of `EdgeInsets`
2. **Use `AlignmentDirectional`** instead of `Alignment`
3. **Icons automatically flip** based on text direction
4. **Row order** follows text direction automatically

### Examples

```dart
// ❌ WRONG - Fixed direction
Padding(
  padding: EdgeInsets.only(left: 16, right: 8),
)

// ✅ CORRECT - Directional
Padding(
  padding: EdgeInsetsDirectional.only(start: 16, end: 8),
)

// ❌ WRONG - Fixed alignment
Align(alignment: Alignment.centerLeft)

// ✅ CORRECT - Directional
Align(alignment: AlignmentDirectional.centerStart)
```

### Icon Mirroring

Some icons should flip in RTL (arrows, navigation), others shouldn't (symbols):

```dart
// Auto-flips in RTL
Icon(Icons.arrow_forward)  // → becomes ←
Icon(Icons.chevron_right)  // > becomes <

// Doesn't flip
Icon(Icons.star)
Icon(Icons.phone)
```

## Theme Extensions

### Shipment Type Colors

Access shipment-specific colors:

```dart
final shipmentColors = Theme.of(context).extension<ShipmentTypeColors>();

// Or with helper extension
final shipmentColors = context.shipmentTypeColors;

Container(
  color: shipmentColors.construction,
)
```

### Custom Theme Data

Access additional semantic colors:

```dart
final customTheme = context.wawAppTheme;

// Success, warning, info colors
Container(color: customTheme.successColor)
SnackBar(backgroundColor: customTheme.warningColor)

// Or quick access
Container(color: context.successColor)
```

## Component Theming

All Material components are pre-configured:

### Buttons

```dart
ElevatedButton(
  onPressed: () {},
  child: Text('Button'),
)
// Automatically gets:
// - Primary background (#006AFF)
// - White text
// - 12px border radius
// - 52px min height
// - Proper disabled state (25% opacity)
```

### Cards

```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(WawAppSpacing.md),
    child: Text('Card content'),
  ),
)
// Automatically gets:
// - 2dp elevation
// - 12px border radius
// - Proper surface color
```

### Text Fields

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Hint',
  ),
)
// Automatically gets:
// - Filled background
// - 12px border radius
// - Primary color on focus
// - Error state styling
```

## Best Practices

### ✅ DO

- Use theme colors from `WawAppColors` or `Theme.of(context).colorScheme`
- Use spacing constants from `WawAppSpacing`
- Use text styles from `Theme.of(context).textTheme`
- Use `EdgeInsetsDirectional` for RTL support
- Use pre-built components from `components.dart` when available
- Access theme via `Theme.of(context)` or context extensions

### ❌ DON'T

- Use inline colors like `Color(0xFF...)` or `Colors.blue`
- Use magic numbers for spacing/sizing
- Define custom `TextStyle` inline
- Use `EdgeInsets` (use `EdgeInsetsDirectional` instead)
- Use `Alignment` (use `AlignmentDirectional` instead)
- Create custom component styling when theme provides it

## Testing Dark Theme

To test dark theme:

1. **System-wide**: Change device to dark mode
2. **Force dark**: `themeMode: ThemeMode.dark` in MaterialApp
3. **Toggle**: Implement theme switcher in app settings

## Backward Compatibility

The theme system is designed to be **non-breaking**:

- Existing screens continue to work without modification
- Old `AppTheme` class delegates to new system
- Theme styles apply automatically to all Material widgets
- No changes required to existing business logic

## Migration Guide

For screens with hardcoded styling:

### Before

```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFF006AFF),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    'Text',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
)
```

### After

```dart
Container(
  padding: EdgeInsets.all(WawAppSpacing.md),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.primary,
    borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
  ),
  child: Text(
    'Text',
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Colors.white,
    ),
  ),
)
```

### Even Better

```dart
WawCard(
  child: Text(
    'Text',
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Colors.white,
    ),
  ),
)
```

## Extending the Theme

### Adding New Colors

1. Add to `colors.dart`:
```dart
static const Color myNewColor = Color(0xFF...);
```

2. Add to theme extensions if needed

### Adding New Components

1. Create in `components.dart`
2. Follow existing patterns
3. Use theme values, not hardcoded
4. Support RTL/LTR

### Modifying Existing Styles

1. Update in `app_theme.dart`
2. Changes apply app-wide automatically
3. Test both light and dark themes

## Support & Questions

For questions about the theme system:
1. Check this README first
2. Review `app_theme.dart` for comprehensive configuration
3. Refer to Flutter Material 3 theming docs
4. Check component examples in `components.dart`

---

**Version**: 1.0.0  
**Last Updated**: December 2025  
**Maintainer**: WawApp Client Team
