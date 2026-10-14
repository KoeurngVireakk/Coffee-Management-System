# Codex Brief — Luna Cafe CMS Premium Flutter/Web Rebuild

Act as a senior Flutter architect, design systems engineer, UX researcher, accessibility specialist, and security-conscious POS developer. Modernize the existing Coffee Management System repository into a visually coherent **Luna Cafe** product based on the attached visual references.

## Brand direction

Luna Cafe = **European café elegance × Khmer cultural soul**. Signature LC monogram, crescent, star, and subtle kbach Khmer ornamental flourishes; cocoa/espresso tones, refined antique gold, cream, warm beige. Emphasize modern European restraint, authentic Khmer craft, clean data density, touch usability, and readable bilingual Khmer/English typography. Reference `reference/approved_reference.jpg` as the user's favorite and use `images/01…10` as concept boards. Avoid overdecorating financial and operational workflows.

## Repository context (verify; do not assume unchanged)

GitHub: `https://github.com/KoeurngVireakk/Coffee-Management-System`. Flutter/Dart mobile + web UI; Laravel REST API + MySQL. Feature-first architecture separating presentation/domain/data. Authentication and role-based access for cashier, manager, admin. Existing functional scope includes secure sessions, adaptive navigation, POS catalog/cart, orders, payments and inventory-related workflows. Historical milestones are not a substitute for checking current git state, tests, API behavior or published branches.

## Research/audit first — NO destructive rewrite

1. Inspect repository structure, Flutter SDK/Dart constraints, dependency versions, theme/design-system, routing, feature modules, tests, data models, API contracts, permission gates, existing asset locations, and `.agent/` instructions/skills. Produce a short current-state audit and phased implementation plan before changing architecture. Check the actual code, not memories or assumptions.
2. Identify frontend UX issues across cashier touch workflows, manager dashboards, admin tables, login, cart, checkout, responsive layout, loading/error/empty states, and role navigation. Track existing functionality that must be preserved.
3. Preserve security: backend is authoritative; role permissions enforced at backend, session handling, strict money (integer cents), idempotent order/payment operations, inventory semantics, and API error mapping must not regress. No bypass or fake payments for aesthetics.

## Design system

- Create semantic design tokens: colors (light and dark), typography including verified Khmer glyph coverage and fallback, 4/8-point spacing scale, elevation, border radii, interaction states, opacity, component sizes, responsive breakpoints, motion durations/curves, focus rings and accessible error/success colors.
- Color ideas: `#2B1B0F` coffee brown, `#C9A96A` antique gold, `#F8F3EA` warm cream, `#4B3626` espresso, `#DCCEB7` beige. Validate WCAG contrast rather than using palette values blindly.
- Use available high-quality Flutter conventions: Material 3 as a functional foundation; evaluate `flex_color_scheme` for theming, `google_fonts` or locally licensed fonts for typography, `go_router` for declarative navigation where it suits current structure, `flutter_animate` / Flutter `animations` for purposeful micro-interactions, `lottie` or `rive` only when beneficial and the actual artwork/runtime assets exist, `flutter_svg` for real vector marks, `skeletonizer` where appropriate for skeleton loading. Do **not** add every library blindly: compare project constraints, maintenance, size, accessibility, license, version compatibility, and performance. Reuse existing dependencies when good.
- Create a reusable design-system library including sidebar/rail, app bar, surfaces, form fields, search/filter bars, product cards, category chips, cart list/items, payment-status indicators, tables, badges, alerts/toasts, dialogs, sheets, charts, responsive empty states, skeletons, and snackbars. Use appropriate animation and respect reduced-motion settings.
- Keep images for marketing/menus distinct from UI icons and functional controls. Boards are NOT production-ready logo vectors or isolated beverage photos. Redraw the approved logo for legible sizes, deliver SVG/transparent raster/adaptive icon variants, and show comparison for approval. Include image licensing/source strategy and responsive aspect ratios.

## Screens and interactions to modernize

1. Splash / login / session recovery: brand introduction with ergonomic inputs, clear errors and secure auth.
2. Adaptive role-aware shell (desktop web, tablet, phone): responsive navigation that does not clutter cashier workflows.
3. Dashboard: role-appropriate KPIs, trends, compact readable analytics with grounded data and explicit loading/error states.
4. POS: quick categories, instant product lookup, responsive product cards with realistic images, modifier support only where backend supports it, efficient cart, numerical input, totals and checkout. Prioritize low-tap cashier operations and preserve cart behavior.
5. Orders/history and details: legible states, search/filter and role-scoped data.
6. Payments: make confirmed/uncertain/failed/reconciliation statuses unambiguous; never present unintegrated external methods as live.
7. Inventory: dense but accessible stocks, movement history, warnings and staff permissions.
8. Product/category management, staff/account/settings where modules actually exist or are sanctioned for current project scope.
9. Receipt/invoice and print layouts: branded but printer-safe monochrome output and accurate currency rounding.
10. Khmer/English labels, USD/KHR treatment based on actual product rules (do not invent conversion behavior), keyboard navigation on web, WCAG-accessible component states.

## Menu and brand integration

- Use the provided menu sheet as creative inspiration only. Potential Cambodian-friendly categories: iced coffee with milk, iced Americano, latte, cappuccino, caramel macchiato, coconut coffee, pandan latte, palm sugar latte, matcha, Thai milk tea, lemon tea, frappes, croissants, cakes. Confirm actual SKUs, prices, availability, stock tracking and variants with the real API/data before showing them as sellable.
- Brand splash/login/sidebar/receipt elegantly. Use Khmer ornament only as small edge accents/dividers/empty-state patterns, not behind text-heavy panels.
- Use generically inspired chain-café operational quality; do not copy Starbucks trademarks, logos or other protected brand identity.

## Engineering workflow and acceptance criteria

- Work in phases and request approval at review boundaries: (A) audit + style inventory, (B) tokens/logo/icon assets, (C) shell + auth, (D) POS + cart, (E) orders + payment, (F) management/dashboard/inventory, (G) QA + polished screenshots.
- Each phase should list changed files, screenshots at phone/tablet/desktop widths, dependency rationale, UX/accessibility checks, and regression risks. Keep progress visible in the repository.
- Preserve the established backend API boundaries; avoid changing backend contracts unless requested and coordinated. Use existing `.agent` skill guidance.
- Run `flutter analyze`, suitable unit/widget/golden tests, web build, role/navigation integration checks, backend regression tests where available; report exact outcomes rather than claiming passes without evidence. Check git diff before commits.
- Include error cases (401/403/409/422/503, network timeout/retry, out-of-stock, canceled checkout), accessible focus/contrast/tap target sizes, responsive overflow, localization and reduced-motion.
- Do not implement fictitious data or hardcode sample KPIs into production. Make dummy demo data explicitly demo-scoped if needed for visual previews.

## Your first response

Start by reading repository instructions and inventorying the live code. Produce a concise **Current State → Target UX → Design System → Phased Plan → Dependencies Decision Table → Risks/Regression Checklist**. Do not make broad destructive changes before establishing the working baseline. Then implement the first approved phase with production-quality Flutter code.
