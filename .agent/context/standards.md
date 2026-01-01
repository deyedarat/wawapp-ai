# Development Standards - wawapp-ai

## 1. Visual Excellence & UX
- **Premium Design**: Every screen must look premium and state-of-the-art. Avoid generic looks.
- **Color Palette**: Use rich, harmonious colors (HSL preferred). Dark mode support where applicable.
- **Aesthetics**: Use glassmorphism, subtle gradients, and micro-animations for high interaction feel.
- **Typography**: Modern fonts (e.g., Inter, Outfit) instead of browser/system defaults.

## 2. Technical Standards
- **State Management**: **Riverpod** is the mandated state management solution. Hooks are used where appropriate.
- **Localization**: Full support for **Arabic (Primary)** and English. All strings must be in `.arb` files.
- **UI Logic**: Keep UI components focused on rendering. Move logic to providers or services.
- **Clean Code**: Follow the single responsibility principle. Shared logic MUST go into the `packages/` directory.

## 3. Localization Patterns
- **Right-to-Left (RTL)**: Ensure layouts are fully compatible with RTL (Arabic).
- **No Placeholders**: Never use placeholder text in UI. Use generated images/real data.
- **ARB Files**: Ensure consistency between `intl_ar.arb` and `intl_en.arb`.
