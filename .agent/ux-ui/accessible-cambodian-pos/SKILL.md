---
name: accessible-cambodian-pos
description: Design or audit Cambodian coffee-shop cashier UX, Khmer/English text, responsive POS interactions and accessibility for touch, keyboard and assistive technology.
license: MIT
---

# Accessible Cambodian POS

Original project workflow. Public Flutter, W3C and NBC materials are linked in [sources](README.md); no third-party manual is copied.

Start with the cashier's actual task, device and connectivity. Confirm language, supported currencies and business rules when they affect the requested flow. Treat the guidance below as acceptance decisions to validate with local staff, not claims about all Cambodian users.

- Keep search, product selection, quantity, cart total and payment choice legible and reachable. Preserve the cart when rotating, resizing or recovering from a network error. Expose draft/pending/failed/confirmed payment states with clear next actions.
- Use verified Khmer translations and fonts with appropriate glyph coverage and licensing. Test Khmer line breaking, tall glyphs, mixed scripts and long labels; avoid manual letter spacing or uppercase transformations on Khmer text. Do not add unreviewed translations as final copy.
- Display currency unambiguously. If KHR and USD are required, distinguish tender, order currency, rate and rounding. A disconnected app must not present an invented conversion or claim a payment succeeded.
- Prefer at least 48 logical-pixel targets for frequent POS controls as a local ergonomic goal. Provide keyboard traversal, visible focus, accessible names/values, and usable screen-reader announcements for meaningful changes.
- Preserve text scaling and sufficient contrast; never encode stock/payment status by color alone. Do not mask errors with celebratory animations or demand repeated taps while a request is pending.

Read [acceptance scenarios](references/acceptance-scenarios.md) during UI verification. WCAG web criteria and native Flutter accessibility tests are complementary; passing automation is not a complete conformance assessment.
