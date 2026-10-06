# Premium Café OS — Design System & Theme Foundation

## 1. Overview & Visual Philosophy

The **Premium Café OS** design system defines the visual language, interaction patterns, and design tokens for the Coffee Management System mobile and tablet client (`apps/mobile`).

The design language moves away from generic, sterile UI templates to deliver an artisanal, warm, and highly functional café point-of-sale and management experience. It is tailored specifically for:
- Fast cashier throughput in high-volume Cambodian café environments.
- First-class bilingual operation in both **English** and **Khmer**.
- Large, reliable touch targets designed for physical tablets and mobile devices.
- Absolute financial accuracy with zero floating-point ambiguities.

### The 60-25-10-5 Palette Proportions

The color distribution is governed by the 60-25-10-5 aesthetic balance:
- **60% Base / Background (`#FAF7F2` Warm Cream / `#171311` Dark Canvas):** Soft, non-glare, warm surface that reduces eye fatigue across long retail shifts.
- **25% Structure & Text (`#3A2618` Espresso / `#211B18` Dark Surface):** Deep roasted coffee tone providing high-contrast typography, cards, and primary buttons.
- **10% Action & Confirmation (`#2F6B4F` Forest Green):** Natural plant green for secondary actions, successful payment verification, and order completion.
- **5% Accent & Highlights (`#D68A3A` Caramel):** Rich warm highlight for active filters, table indicators, and subtle visual badges.

---

## 2. Bilingual Typography (English + Khmer)

### Font Hierarchy & Subscript Safety

```dart
static const List<String> fontFallback = <String>[
  'Inter',
  'Noto Sans Khmer',
  'sans-serif',
];
```

In Khmer typography, characters contain stacked consonants (ជើងអក្សរ, *cheung*) and dual-level diacritics (ស្រៈលើ-ស្រៈក្រោម). Tight line-heights (e.g., 1.0–1.2) cause subscript consonants and upper diacritics to be clipped by Flutter's bounding boxes.

**Mandatory Rule:** All text styles in `AppTypography` enforce a safe line-height multiplier between **1.35 and 1.45**:
- `display` (32px, bold, `height: 1.30`)
- `h1` (28px, bold, `height: 1.35`)
- `h2` (24px, semi-bold, `height: 1.35`)
- `h3` (20px, semi-bold, `height: 1.40`)
- `title` (18px, semi-bold, `height: 1.40`)
- `bodyLarge` (16px, regular, `height: 1.45`)
- `body` (14px, regular, `height: 1.45`)
- `label` (13px, medium, `height: 1.40`)
- `small` (11.5px, regular, `height: 1.35`)

### Tabular Numerics for Financial Scannability

To prevent optical shifting when order quantities, totals, and stock levels change, all price and KPI styles use tabular monospace figures:

```dart
static const TextStyle price = TextStyle(
  fontSize: 24.0,
  fontWeight: FontWeight.w700,
  height: 1.25,
  fontFeatures: [FontFeature.tabularFigures()],
  fontFamilyFallback: fontFallback,
);
```

---

## 3. Financial & Numerical Formatting Standard

### Zero Floating-Point Ambiguity

Currency amounts in the system represent integer minor units (USD cents) to align with backend database schema and API contracts.

```dart
// Formatters.formatCents(int cents) -> String
Formatters.formatCents(0)       // "$0.00"
Formatters.formatCents(325)     // "$3.25"
Formatters.formatCents(1200)    // "$12.00"
Formatters.formatCents(148525)  // "$1485.25"
Formatters.formatCents(-50)     // "-$0.50"
```

Inventory quantities (`DECIMAL(14,4)`) are formatted as exact decimal strings, stripping unnecessary trailing zeros without converting to binary `double`:

```dart
// Formatters.formatExactQuantity(String decimalString, String unit) -> String
Formatters.formatExactQuantity("100.0000", "g")   // "100 g"
Formatters.formatExactQuantity("0.5000", "ml")    // "0.5 ml"
Formatters.formatExactQuantity("2.2500", "unit")  // "2.25 unit"
```

---

## 4. Spacing, Radius, & Touch Target Tokens

### 4px Baseline Scale

All layouts adhere to the `AppSpacing` 4px baseline scale:
- `xs = 2.0`
- `s = 4.0`
- `sm = 8.0`
- `md = 12.0`
- `lg = 16.0` (standard card & screen padding for mobile)
- `xl = 20.0`
- `xxl = 24.0` (standard padding for tablet)
- `xxxl = 32.0` (standard padding for POS desktop)
- `huge = 40.0`
- `giant = 48.0`
- `massive = 64.0`

### Touch Target Standard (WCAG 2.5.5)

In busy café environments, cashiers operate quickly on touchscreen tablets. All interactive elements enforce a minimum touch target of **48.0 × 48.0 logical pixels** via `AppSpacing.minTouchTarget`.

### Corner Radii

- `radiusSm = 8.0` (badges, chips, color swatches)
- `radiusMd = 10.0` (text inputs)
- `radiusLg = 12.0` (buttons)
- `radiusXl = 16.0` (standard cards)
- `radiusXxl = 20.0` (modal sheets, dialogs)
- `radiusPill = 999.0` (status pills, filter tags)

---

## 5. Responsive Breakpoints

Defined in `AppBreakpoints`:
- **Compact (`< 600px`):** Mobile devices (single-column layouts, 16px screen padding).
- **Medium (`600px .. 899px`):** Tablet portrait & small tablets (split catalog/cart layouts, 24px screen padding).
- **Expanded (`>= 900px`):** Tablet landscape & countertop POS terminals (multi-column dashboard, 32px screen padding).

The helper `AppBreakpoints.responsive<T>(context, compact: ..., medium: ..., expanded: ...)` enables clean, declarative layout adaptations without hardcoded media queries.

---

## 6. Color Tokens & Theme Extension

Tokens are defined in `AppColors`, integrated into `AppTheme.buildLightTheme()` and `AppTheme.buildDarkTheme()`, and supplemented with `CafeThemeExtension` for café-specific UI elements.

| Semantic Purpose | Light Theme Value | Dark Theme Value | Contrast Ratio |
| :--- | :--- | :--- | :--- |
| **Scaffold Background** | `#FAF7F2` (Warm Cream) | `#171311` (Deep Dark) | - |
| **Card Surface** | `#FFFFFF` (White) | `#211B18` (Dark Surface) | - |
| **Primary Brand** | `#3A2618` (Espresso) | `#E1C3AD` (Warm Cream Glow) | > 12:1 against bg |
| **Secondary Action** | `#2F6B4F` (Forest Green) | `#8FC9A9` (Muted Green) | > 4.5:1 against bg |
| **Accent Caramel** | `#D68A3A` (Warm Amber) | `#E7AD72` (Glow Amber) | High contrast |
| **Positive / Paid** | `#2E7D32` on `#EDF7ED` | `#81C784` on `#1B2F1F` | WCAG AA compliant |
| **Warning / Low Stock** | `#A05A00` on `#FFF4E5` | `#FFB74D` on `#33230E` | WCAG AA compliant |
| **Error / Voided** | `#B3261E` on `#FDE8E8` | `#E57373` on `#351918` | WCAG AA compliant |
| **Info / Pending** | `#2563EB` on `#EFF6FF` | `#64B5F6` on `#102847` | WCAG AA compliant |

### Caramel Text Contrast Standard

`#D68A3A` (Caramel) possesses insufficient luminance contrast when paired with pure white text. All components displaying text on caramel accents use dark text (`AppColors.textPrimaryLight`), enforced via `CafeThemeExtension.onAccentCaramel`.

---

## 7. Component Library Summary

Located in `apps/mobile/lib/shared/widgets/`:

1. **`AppButton`**:
   - Variants: `primary`, `secondary`, `outline`, `destructive`, `text`.
   - Distinct visual states: Default, pressed (ink ripple), hovered, focused, disabled, and loading.
   - Built-in `Semantics` label and minimum `48.0` touch target.
   - Handles optional `leadingIcon` and `trailingIcon`.

2. **`AppTextField`**:
   - High-contrast border states (idle, focused 1.5px brand outline, error 1.5px red outline).
   - Supports `label`, `hintText`, `helperText`, `errorText`, `prefixIcon`, `suffixIcon`.
   - Accessible keyboard actions, obscuring, and disabled states.

3. **`StatusBadge`**:
   - Multi-attribute status display (never relies solely on color: pairs semantic color, text label, and optional icon).
   - Square (`radiusSm`) and Pill (`radiusPill`) shapes.
   - Semantic accessibility label (e.g. `"PAID status"`).

4. **`AppCard`**:
   - Consistent rounded surface (`radiusXl`), 1px subtle border, and optional interactive `onTap` with properly clipped `InkWell` ripple.

5. **`AppSectionHeader`**:
   - Standardized title, optional secondary subtitle, and optional trailing action button.

6. **`AppEmptyState`**:
   - Rounded circular icon container, header, descriptive prompt, and call-to-action button.

7. **`AppLoadingIndicator`**:
   - Brand-tinted progress spinner with optional accessibility label.

---

## 8. Interactive Preview Page

The interactive design system preview page is available at `apps/mobile/lib/features/preview/presentation/design_system_preview_page.dart` and mounts as the default home screen of `CoffeeManagementApp`.

It provides live interactive verification of:
- Instant Light / Dark theme toggling.
- Full color palette swatches with hex metadata.
- English and Khmer typography scale and script rendering.
- Tabular numeric price, KPI, and quantity formatting.
- Button matrix across all variants, loading, and disabled states.
- Form field states (standard, error, disabled, helper).
- Status badge variants (square & pill).
- Interactive card tap ripple and empty state illustrations.
- Responsive layout adaptation across Compact, Medium, and Expanded viewports.

