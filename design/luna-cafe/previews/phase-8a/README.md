# Phase 8A native mobile previews

These captures use the Flutter widget renderer with bundled English/Khmer fonts and Material icons. They are **synthetic, read-only fixtures**, not real shop data or actual Android/iOS device screenshots. Every capture contains an audit-fixture banner. No new web or desktop product UI was created.

| Scenario | Capture |
| --- | --- |
| Phone 390×844, light login | [login-phone-light.png](login-phone-light.png) |
| Phone 360×800, dark login | [login-phone-dark.png](login-phone-dark.png) |
| Tablet 768×1024, light login | [login-tablet-light.png](login-tablet-light.png) |
| Phone 360×800, login at 2× text | [login-phone-2x.png](login-phone-2x.png) |
| Phone 390×844, light POS | [pos-phone-light.png](pos-phone-light.png) |
| Tablet 1024×768, dark POS | [pos-tablet-dark.png](pos-tablet-dark.png) |
| Phone 360×800, POS at 2× text | [pos-phone-2x.png](pos-phone-2x.png) |
| Phone 390×844, no catalog data | [pos-phone-empty.png](pos-phone-empty.png) |
| Phone 390×844, service error | [pos-phone-error.png](pos-phone-error.png) |

At 2× text the login form scrolls and the POS list shows fewer products while keeping the cart CTA reachable. These are fixed captures of a scrollable interface, not claims that every control fits simultaneously. The existing cashier Dashboard/Home placeholder remains an audited Phase 8B navigation gap; no report data is attached to it.

Reproduce from `apps/mobile`:

```powershell
flutter test tool/luna_mobile_capture_test.dart --reporter expanded
```

For on-device rendering use the [fixture preview instructions](../../../../docs/frontend/luna-cafe-asset-integration.md). Native OS splash/icon rendering, device animation performance and screen-reader behavior still require device validation. Do not use these fixtures as live SKUs or as golden-test baselines.
