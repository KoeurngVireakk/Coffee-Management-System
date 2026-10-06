# Premium Café OS — Adaptive App Shell & Role/Permission Navigation

## 1. Overview & Architectural Principles

Flutter Phase 3 introduces the production-grade **Adaptive App Shell** and **Permission-Gated Navigation System** for the Coffee Management System mobile, tablet, and web client (`apps/mobile`).

The implementation adheres to the **Feature-First Clean Architecture** outlined in `.agent/flutter/feature-first-flutter` and incorporates the UX/UI rules from `.agent/ux-ui/accessible-cambodian-pos` and `.agent/ux-ui/intentional-frontend-design`:

- **Shared Navigation Domain (`shared/navigation/app_destinations.dart`):** Pure Dart models defining `AppDestination` records, compact and expanded destination registries, and the pure filtering function `filterDestinations(...)`.
- **Adaptive Presentation (`features/shell/presentation/adaptive_app_shell.dart`):** Responsive root shell that automatically adapts between a bottom `NavigationBar` (compact viewports <600dp) and a persistent left `NavigationRail`/Sidebar (expanded viewports ≥600dp).
- **Placeholder Destinations (`features/shell/presentation/destination_pages.dart`):** Clean, lightweight destination widgets proving navigation routing and layout architecture without fetching premature business data (deferred to Phases 4–11).

---

## 2. Responsive Navigation Layouts

```mermaid
flowchart TD
    Viewport[MediaQuery Viewport Width]
    Viewport -->|< 600dp (Compact / Mobile)| CompactShell[Compact Bottom NavigationBar]
    Viewport -->|≥ 600dp (Medium / Expanded / Tablet / Desktop)| ExpandedShell[Expanded Persistent Sidebar]

    CompactShell --> MobileDestinations[5 Core Workflow Tabs:<br/>Home, Orders, POS, Stock, More]
    MobileDestinations --> MoreSheet[More Screen:<br/>Profile, Role Badge, Overflow Items, Sign Out]

    ExpandedShell --> DesktopDestinations[Full Gated List:<br/>Dashboard, POS, Orders, Products, Inventory, Reports, Staff, Settings]
    ExpandedShell --> SidebarFooter[Sidebar Footer:<br/>Design System Link, Theme Toggle, Sign Out]
```

### 2.1 Compact Layout (<600dp Mobile)
- **Bottom NavigationBar:** Features 5 fixed, ergonomic touch targets:
  1. `Home` (`/home`): Default overview.
  2. `Orders` (`/orders`): Gated by `view-own-orders`.
  3. `POS` (`/pos`): Gated by `process-pos`. **Visually emphasized** with a pill container in primary brand colors to facilitate rapid cashier discovery during high-throughput shifts.
  4. `Stock` (`/stock`): Gated by `view-inventory`.
  5. `More` (`/more`): Opens the dedicated overflow menu.
- **Top AppBar:** Displays canonical title `Coffee Management System` and the live staff `StatusBadge`.
- **More Screen (`MorePage`):** Provides user identity details (name, email, role badge), authorized overflow destinations (`Products`, `Reports`, `Staff`, `Settings`), design preview link, and sign-out action.

### 2.2 Expanded Layout (≥600dp Tablet & Desktop POS)
- **Width:** 280dp persistent left navigation sidebar.
- **Brand Header:** Premium Café OS coffee icon, English brand title (`Coffee Management System`), and Khmer subtitle (`ប្រព័ន្ធគ្រប់គ្រងហាងកាហ្វេ`).
- **Profile Card:** Staff avatar with initial, full name, email, and pill `StatusBadge` scaled cleanly via `FittedBox` to eliminate any horizontal overflow risk.
- **Navigation Items:** Only destinations authorized by the user's server-granted permissions are mounted.
- **POS Emphasis:** The `POS` item features an active caramel accent highlight and a high-contrast `MAIN` badge.
- **Bottom Controls:**
  - Design System Preview navigation link.
  - Theme Toggle (Light / Dark mode).
  - Prominent Sign Out action with semantic error feedback via `SnackBar`.

---

## 3. Role & Permission Navigation Matrix

| Destination | Route | Required Permission | Cashier | Manager | Admin | Notes |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **Dashboard** | `/dashboard` | `null` (unrestricted) | Yes | Yes | Yes | Landing page for Manager/Admin |
| **POS** | `/pos` | `process-pos` | **Yes (MAIN)** | Yes | Yes | Landing page for Cashier |
| **Orders** | `/orders` | `view-own-orders` | Yes | Yes | Yes | Cashier sees own; Manager sees all |
| **Products** | `/products` | `view-catalog` | Yes | Yes | Yes | Menu/catalog exploration |
| **Inventory** | `/inventory` | `view-inventory` | Yes | Yes | Yes | Stock level monitoring |
| **Reports** | `/reports` | `view-reports` | **No** | Yes | Yes | Operational KPIs and analytics |
| **Staff** | `/staff` | `manage-staff` | **No** | **No** | Yes | Admin staff provisioning |
| **Settings** | `/settings` | `manage-settings` | **No** | **No** | Yes | Store configuration |

> [!IMPORTANT]
> **Authoritative Invariant:** Server-returned permissions (`user.hasPermission(...)`) are the sole determinant of destination visibility. UI hiding serves ergonomic clarity only; backend Laravel policies remain authoritative.

---

## 4. Ergonomics, Accessibility & Typography

1. **Touch Target Dimensions:** All interactive controls (navigation destinations, bottom bar tabs, sidebar actions, logout buttons) meet or exceed the mandatory **48 × 48 logical pixels** minimum touch target size.
2. **Bilingual Khmer Typography:** Khmer subtitles use standard Unicode fonts with line-height multipliers strictly maintained between 1.35 and 1.45 to prevent stacked consonant or diacritic clipping. No manual uppercase transforms are applied to Khmer text.
3. **WCAG AA Contrast:** Active navigation items utilize high-contrast primary containers (`AppColors.espresso`, `AppColors.forestGreen`, `AppColors.caramel`), paired with distinct icons and semantic text labels.
4. **State Preservation:** Resizing between compact and expanded views preserves the active destination without resetting application state.

---

## 5. Session Teardown & Security

- **Clean Session Termination:** Invoking "Sign Out" calls `AuthController.logout()`, deleting the server-side Sanctum token via `POST /api/v1/auth/logout` and wiping local secure storage.
- **Immediate Route Guarding:** Transitioning to `Unauthenticated` immediately replaces `AdaptiveAppShell` with `LoginPage`.
- **Zero Secret Exposure:** Shell views and profile summaries display only verified public staff attributes (name, email, role); tokens and credentials are never exposed in UI widgets or logs.
