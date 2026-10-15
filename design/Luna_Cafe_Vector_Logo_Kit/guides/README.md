# LUNA CAFE — Production Vector Logo Kit

European café elegance × Khmer-inspired ornamental soul. All supplied `.svg` files contain actual editable/scalable vector shapes (no embedded JPG/PNG); logo wordmarks are converted to outlined letterforms and do not depend on runtime font installation.

## Important design fidelity note

This is a **carefully redrawn, stylized vector interpretation** of the user-approved AI-generated, 3D embossed LC monogram, **not an exact pixel-for-pixel tracing**. The original reference artwork is included under `reference/` so Codex and designers can compare. The SVG system prioritizes legibility and production use at mobile icon sizes. Khmer ornamental scrolls are original, stylized motifs inspired by kbach phni, not replicas of a particular heritage carving.

## Useful files

- `svg/logo_stacked_transparent.svg` — main vertical logo with name (transparent background)
- `svg/logo_horizontal_transparent.svg` — mobile header / receipts / branded screens
- `svg/wordmark_espresso.svg` — LUNA CAFE text only, dark
- `svg/wordmark_gold.svg` — LUNA CAFE text only, antique gold
- `svg/monogram_gold_transparent.svg` — gold LC artwork only; works on contrasting surfaces
- `svg/monogram_espresso_transparent.svg` — dark LC artwork only
- `svg/monogram_white_transparent.svg` — white mark for solid dark background
- `svg/app_icon_square_dark.svg` — recommended iOS-style marketing app icon visual
- `svg/app_icon_square_light.svg` — cream alternative
- `svg/app_icon_circle_dark.svg` — circular profile/signage icon
- `svg/android_foreground_monogram.svg` — centered adaptive icon foreground
- `svg/android_background.svg` — Android adaptive icon background
- `svg/khmer_ornament_flourish.svg` — decorative motif for splash/branding (not dense content areas)
- `png/` — rendered transparent and opaque PNG equivalents for platforms that require PNG
- `reference/` — original approved image (visual reference, not an app asset)

## Color palette

- Coffee Brown: `#2B1B0F`
- Espresso: `#4B3626`
- Antique Gold: `#C9A96A`
- Champagne Gold: `#E9CD91`
- Ivory: `#F8F3EA`
- Warm Beige: `#DCCEB7`

## Flutter mobile integration

Copy selected production `.svg` assets to `apps/mobile/assets/branding/` and `png` icon assets to a platform-appropriate asset location; add the exact assets to `apps/mobile/pubspec.yaml`. Prefer `flutter_svg` for runtime vector display **only after confirming Flutter/Dart SDK compatibility and project dependency policy**. Use Flutter native theme and semantic widgets for normal UI components. For Android/iOS launcher icons, generate real platform-specific icon resources from the provided opaque PNG/adaptive foreground, using the existing build tooling; do not directly configure an SVG as an iOS launcher icon.

The mockups and concept sheets are not production-ready product photography or authoritative prices. Do not bake decorative branding into receipt totals, confirmed payment states, or stock warnings. Validate logo contrast in light/dark themes and visual clarity at 24–48 dp sizes.

These are original derivative concept assets commissioned for the Luna Cafe project, not copies of Starbucks brand marks. If the café is launched commercially, verify naming/trademark conflicts and cultural/style appropriateness independently.
