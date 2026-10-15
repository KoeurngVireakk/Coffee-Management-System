# Luna Cafe mobile asset integration — supplied logo kit

The owner requested use of `design/Luna_Cafe_Vector_Logo_Kit` on 2026-10-15. Read its `guides/CODEX_USE_THIS_BRAND_KIT.md` and `guides/README.md`. The application now uses those supplied assets. The earlier candidate redraw, vector painter and Playfair branding font have been removed. Compare [kit artwork applied to login and app icons](../../design/luna-cafe/artwork/supplied-kit/REVIEW.md).

## Source and runtime manifest

Original SVG masters remain in the supplied kit and are never modified. The kit includes pre-rendered transparent PNG equivalents, so runtime `Image.asset` preserves the gold gradients and outlined lettering without an SVG package, new geometry or a branding font. Only three selected PNGs and a source manifest are declared under `apps/mobile/assets/branding/` in `pubspec.yaml`.

| Runtime file | Exact supplied source | Use |
| --- | --- | --- |
| `logo_stacked_transparent.png` | `png/logo_stacked_transparent_1200x1390.png` | Login lockup, gold artwork on a coffee-brown backing, unchanged alpha. |
| `monogram_gold.png` | `png/monogram_gold_transparent_512x512.png` | Dark shell/More identities, decorative beside readable native shop name. |
| `monogram_espresso.png` | `png/monogram_espresso_transparent_1024x1024.png` | Light shell/More identities. |
| `manifest.json` | Source mappings and owner selection | Declarative asset provenance and geometry policy. |

The three runtime PNGs are **byte-identical** to their supplied source files and total **246,498 bytes**. `LunaBrandLockup` reserves layout space with `AspectRatio`, scales the entire image to fit shorter viewports and supplies the accessible name. Small repeated marks exclude duplicate semantics. Image decoding uses the rendered pixel width to bound cache memory. Operational text remains scalable native text; the image's own letters are the supplied outlined artwork.

The provided horizontal lockup is not needed at current compact/sidebar widths; its supplied export also reaches the top canvas edge. It is not cropped, reconstructed or substituted into a narrow header. No reference boards, kit contact sheets, SVG masters or review captures enter the runtime bundle. No price, catalog or dashboard values come from branding art.

## Platform packaging

`apps/mobile/tool/luna_asset_export_test.dart` derives native resources solely from supplied PNGs using Flutter's image codec, proportional resampling and a standard RGB encoder. It does not redraw the geometry.

| Files/resources | Supplied source and handling |
| --- | --- |
| `design/luna-cafe/artwork/supplied-kit/icon-1024.png` | `png/app_icon_square_dark_1024x1024.png`, composited on matching coffee color to fill transparent corners. |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | Same supplied icon in 48/72/96/144/192px legacy sizes. |
| `drawable-*/luna_adaptive_foreground.png`, `luna_adaptive_monochrome.png` | `png/android_foreground_monogram_1024x1024.png` in 108/162/216/324/432px density variants. Monochrome changes only color while preserving alpha/geometry. |
| `mipmap-anydpi-v{26,33}/ic_launcher.xml`, `values/luna_colors.xml` | Adaptive foreground and coffee background matching `svg/android_background.svg`; Android 13 monochrome layer. |
| `drawable-*/luna_splash_mark.png`, `drawable-night-*/luna_splash_mark.png`, `drawable{,-v21}/launch_background.xml`, `values*-v31/styles.xml` | Provided espresso/light and gold/dark monograms on the appropriate native background; Android 12 uses supplied adaptive foreground. |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png` | All existing icon sizes, including 1024px, exported as RGB with no alpha channel. No white corner backing; OS masking remains authoritative. |
| `LaunchImage.imageset/LaunchImage*.png`, `LunaLaunchBackground.colorset`, `Base.lproj/LaunchScreen.storyboard` | Supplied monograms and named light/dark launch background. Source configuration is prepared; Xcode/device verification remains required. |

The kit's Android foreground lies within the adaptive mask-safe central region. The supplied iOS-style icon has transparent rounded corners; filling with its matching coffee background produces an opaque square asset without changing the visible monogram. Inspect small 20–48px exports in the comparison document. At very small sizes ornament loses fine detail naturally; no autonomous simplified redraw is substituted.

## Attribution and offline UI fonts

The source kit describes its artwork as original derivative concept assets commissioned for Luna Cafe, a stylized interpretation of the original approved reference. The owner explicitly supplied and selected it for integration. It has no separate third-party LICENSE file; preserve its provenance and do not relabel the artwork as third-party MIT-licensed material. Repository code retains the root license. Source kit files remain untouched, including the guides and reference.

Only two local UI fonts remain, total **1,236,364 bytes**. They are unmodified normal-style variable fonts from the official [Google Fonts repository](https://github.com/google/fonts), revision `67bc647ce1910e92f461bcc82aae30f21d21a9cc`. Exact source URLs, sizes and SHA-256 hashes are in `apps/mobile/assets/fonts/sources.json`. Each directory includes upstream `METADATA.pb` and **SIL Open Font License 1.1** `OFL.txt`; notices are bundled.

- **Inter**: Rasmus Andersson / The Inter Project Authors, `inter/Inter.ttf`, for native UI text and existing tabular numeric styles.
- **Noto Sans Khmer**: Google / The Noto Project Authors, `notosanskhmer/NotoSansKhmer.ttf`, local Khmer fallback. Inspection found 114 covered Khmer-block code points, including the existing login subtitle/preview label, with GSUB/GPOS shaping tables. Full linguistic/cluster review is not claimed.

No Playfair/Montserrat font is needed to reproduce the kit's outlined wordmark. No `flutter_svg`, `google_fonts`, chart or animation dependency was added. No font fetch occurs at startup; dependency versions and lockfile are retained.

## Brand conventions and reproduction

Keep the existing `AppColors`, `AppTheme`, `CafeThemeExtension`, spacing, radius and shadow tokens. Coffee `#2B1B0F`, espresso `#4B3626`, cream `#F8F3EA`, beige `#DCCEB7`, decorative gold `#C9A96A` remain the palette. Foreground gold `#806127` achieves 5.20:1 on cream; ordinary gold does not carry operational text or state. Success/error/warning/info values, exact money formatting and fixed-point inventory logic are unchanged. The supplied logo gradients are branding art, with native high-contrast labels for operational information.

From `apps/mobile`:

```powershell
flutter pub get
flutter test tool/luna_asset_export_test.dart --reporter expanded
flutter test tool/luna_mobile_capture_test.dart --reporter expanded
flutter run -d <android-device-id> -t tool/luna_audit_preview.dart --dart-define=AUDIT_ROLE=login
```

The supplied kit must be present for platform regeneration. Capture output lives under `design/luna-cafe/previews/phase-8a`; these are native widget captures, not stable golden baselines or real-device evidence. The isolated preview harness supports `AUDIT_ROLE=login|cashier|manager|admin`, `AUDIT_THEME=light|dark`, `AUDIT_STATE=data|empty|error`. Its MockClient rejects writes and uses a reserved `.invalid` URL and memory-only token; it never reaches the live backend. Use `lib/main.dart` for actual backend operation.
