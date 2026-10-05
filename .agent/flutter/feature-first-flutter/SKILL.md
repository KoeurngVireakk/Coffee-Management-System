---
name: feature-first-flutter
description: Implement or refactor Flutter mobile/tablet features using this repository's feature-first Clean Architecture and constraint-based responsive layouts.
license: BSD-3-Clause
---

# Feature-first Flutter

Adapted from the Flutter Authors' architecture and responsive-layout skills. The upstream hybrid folder layout and mandatory package choices are replaced with this project's existing contract. See [provenance](README.md) and [license](../../licenses/flutter-bsd-3-clause.txt).

Inspect `apps/mobile/pubspec.yaml`, the lockfile, nearby code and `docs/architecture/README.md`. Verify SDK-sensitive APIs against the installed SDK; current online documentation may describe a newer version.

- Keep feature code in `lib/features/<feature>/{data,domain,presentation}`. Domain is plain Dart; API DTOs and plugins stay in data; widgets and UI state stay in presentation.
- Return domain values from data implementations. Use repository contracts where the boundary needs one. Compose concrete dependencies at the app boundary; do not create a DI container, generic repository or use-case wrapper without a demonstrated need.
- Follow the project's selected state approach. Until one is selected, propose the smallest coherent choice for the feature and document the tradeoff; do not install several alternatives or mandate upstream `provider`, `get_it`, `freezed` or `built_value`.
- Model loading, success, empty and error states explicitly. Handle widget/state disposal and prevent late requests from replacing newer state. Keep network calls out of `build()`.
- Treat Laravel responses as authoritative for prices, permissions, order status and payment status. UI visibility is not authorization. Use `AppConfig` for public URLs and platform-secure storage when the authorized auth feature needs persistent tokens.
- Measure parent constraints for local layout and window size for app layout. Read [responsive POS](references/responsive-pos.md) for tablet/mobile work; use the separate POS skill for localization and accessibility acceptance.

Verify observable behavior with relevant domain/widget tests, formatting and `flutter analyze`. Run a platform build when platform configuration changes. Report device/iOS gaps rather than equating a web build with mobile validation.
