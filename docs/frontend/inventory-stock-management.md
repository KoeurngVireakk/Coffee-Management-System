# Flutter Phase 7 — Mobile-First Inventory & Stock Management

The mobile application now replaces the previous `/inventory` and `/stock` destination placeholders with an authentic, mobile-first Inventory & Stock Management feature. Cashiers, managers, and administrators can monitor stock balances, track low-stock thresholds, record idempotent manual movements, and manage product recipes directly through the frozen Laravel REST API.

## Architecture and layer boundaries

```text
┌─────────────────────────────────────────────────────────────┐
│                       Presentation                          │
│                                                             │
│   InventoryPage (Responsive Phone + Tablet Master-Detail)   │
│   InventoryDetailPage (Compact Mobile Route)                │
│   InventoryDetailView (Shared Item & Ledger Inspector)      │
│   RecipeEditorPage (Atomic Product Recipe Management)       │
│   InventoryCard, InventoryFilterBar, StockMovementDialog     │
│   InventoryItemFormDialog, StockMovementHistoryView         │
│   InventoryController (Session-scoped State Machine)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                          Domain                             │
│                                                             │
│   ExactQuantity (Fixed-point DECIMAL(14,4) Checked Subunits)│
│   InventoryItem (Authoritative Stock Balances & Status)     │
│   StockMovement (Append-Only Ledger Record & Reason)        │
│   StockMovementIntent (Idempotency Key & Sign Direction)    │
│   ProductRecipe & RecipeIngredient (Bill of Materials)      │
│   InventoryFilter (Allowlisted Query Parameters)            │
│   InventoryRepository (Abstract Contract & Failure Hierarchy│
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                           Data                              │
│                                                             │
│   ApiInventoryRepository (Frozen REST API Client)           │
│   InventoryDto (Strict Collection & Resource Decoding)      │
│   ApiClient (HTTP Client with GET, POST, PUT, PATCH)        │
└─────────────────────────────────────────────────────────────┘
```

| File in `apps/mobile/lib/` | Responsibility |
| --- | --- |
| `features/inventory/domain/exact_quantity.dart` | Fixed-point `DECIMAL(14,4)` checked integer subunit arithmetic (scale 10,000, max magnitude 9,999,999,999.9999). Strictly eliminates floating-point roundoff errors and rejects negative zero, plus signs, scientific notation, and excessive precision. |
| `features/inventory/domain/inventory_item.dart` | Immutable entity representing stock items with authoritative server balances (`onHand`, `reserved`, `available`, `reorderLevel`, `baseUnit`, `isActive`, `lowStock`). |
| `features/inventory/domain/stock_movement.dart` | Immutable ledger record and `StockMovementIntent` enforcing valid sign direction per `StockMovementReason` and verifying `Idempotency-Key` format (8–64 ASCII alphanumeric/._-). |
| `features/inventory/domain/product_recipe.dart` | Domain representation of product recipe and ingredient payloads for atomic replace requests (`PUT /products/{id}/recipe`). |
| `features/inventory/domain/inventory_filter.dart` | Immutable query filter producing strictly allowlisted query parameters (`status`, `search`, `low_stock`, `page`, `per_page`). |
| `features/inventory/domain/inventory_repository.dart` | Pure Dart interface for inventory queries, single item retrieval, CRUD, movement logging, and recipe management, with typed `InventoryFailure` exceptions. |
| `features/inventory/data/inventory_dto.dart` | Strict JSON deserializer with duplicate ID detection and strict numeric string validation. |
| `features/inventory/data/api_inventory_repository.dart` | Production API client enforcing Bearer authentication, URL encoding, query allowlisting, and typed failure translation. |
| `features/inventory/presentation/inventory_controller.dart` | Session-scoped state machine managing listing, search debounce (300ms), generation counter protection, pagination, item CRUD, movement idempotency with uncertain retry preservation, movement history, and atomic recipe updates. |
| `features/inventory/presentation/inventory_page.dart` | Responsive screen adapting between compact phone list and tablet master-detail view with permission-based capability gating. |
| `features/inventory/presentation/inventory_detail_page.dart` | Dedicated mobile route for compact phone item inspection. |
| `features/inventory/presentation/recipe_editor_page.dart` | Dedicated management page for product ingredient composition and atomic recipe updates. |
| `features/inventory/presentation/widgets/inventory_card.dart` | High-contrast list card (≥48dp touch target) displaying SKU, name, available balance, status badges, and low-stock warnings with overflow safety. |
| `features/inventory/presentation/widgets/inventory_filter_bar.dart` | Search field with 300ms debounce and horizontal `ChoiceChip` presets (`All`, `Low Stock`, `Active`, `Inactive`). |
| `features/inventory/presentation/widgets/inventory_detail_view.dart` | Authoritative balance metrics (`Available Stock`, `On Hand`, `Reserved`, `Reorder Threshold`) and permission-gated action buttons. |
| `features/inventory/presentation/widgets/stock_movement_dialog.dart` | Modal dialog for recording manual stock movements with reason-specific sign validation, note requirements, and network timeout retry locking. |
| `features/inventory/presentation/widgets/inventory_item_form_dialog.dart` | Modal dialog for creating and updating inventory item metadata. |
| `features/inventory/presentation/widgets/stock_movement_history_view.dart` | Bottom sheet displaying paginated stock movement ledger entries. |
| `core/network/api_client.dart` | Enhanced with `put(...)` and `patch(...)` HTTP methods for RESTful mutations. |
| `features/shell/presentation/adaptive_app_shell.dart` | Wired both `/inventory` and `/stock` navigation destinations to `InventoryPage` with `view-inventory` capability checks. |

---

## Exact Decimal Arithmetic (Zero Double Floating-Point)

In accordance with backend `DECIMAL(14,4)` precision, quantities are never represented or manipulated as binary floating-point `double`s:

- **Internal Representation:** 64-bit checked integer subunits where $1 \text{ unit} = 10,000 \text{ subunits}$.
- **Capacity:** Bounds checked to $[-99999999999999, 99999999999999]$ ($[-9,999,999,999.9999, +9,999,999,999.9999]$).
- **String Parsing:** Strict regular expression verification requiring exact decimal format with at most 4 fractional places; negative zero (`-0`, `-0.0000`), scientific notation (`1e5`), trailing garbage, and plus signs (`+10`) are rejected.
- **Display Formatting:** `toFormattedString()` strips trailing fractional zeros while preserving significant precision; `toCanonicalString()` formats fixed 4 decimal places for wire transmission.

---

## Idempotency Protocol & Safe Network Uncertainty

Manual stock movements (`POST /api/v1/inventory/items/{id}/movements`) alter physical balances and must never be duplicated due to transient network failures.

```mermaid
sequenceDiagram
    participant Op as Manager / Admin
    participant UI as StockMovementDialog
    participant Ctrl as InventoryController
    participant API as Laravel REST API (/api/v1)

    Op->>UI: Selects Reason, Enters Quantity & Submits
    UI->>Ctrl: createMovement(reason, delta, note)
    Note over Ctrl: Generates stable Idempotency-Key (8-64 chars)
    Ctrl->>API: POST /inventory/items/{id}/movements (Header: Idempotency-Key)
    
    alt Network Timeout / 5xx Server Error
        API--xCtrl: Connection drops / Timeout
        Note over Ctrl: Marks isMovementUncertain = true<br/>Locks pendingMovementIntent with SAME key
        Ctrl-->>UI: Displays "Network Timeout - Retry Safe" banner
        Op->>UI: Taps "Retry Movement"
        UI->>Ctrl: retryUncertainMovement()
        Note over Ctrl: Re-submits with identical Idempotency-Key
        Ctrl->>API: POST /inventory/items/{id}/movements (SAME Idempotency-Key)
        API-->>Ctrl: 201 Created (Or idempotently replayed)
        Ctrl-->>UI: Success, balance refreshed
    else Business Conflict (409) / Validation Error (422)
        API-->>Ctrl: 409 Conflict / 422 Unprocessable
        Note over Ctrl: Clears pending intent; does NOT auto-retry
        Ctrl-->>UI: Explains conflict, prompts manual refresh
    end
```

### Protocol Rules:
1. **Key Generation:** Unique `Idempotency-Key` (8–64 ASCII alphanumeric characters plus `._-`) generated once per movement intent.
2. **Failure Locking:** On network error or server timeout, the intent is locked in `pendingMovementIntent` and marked `isMovementUncertain`. The identical key is retained.
3. **Safe Operator Retry:** Retrying via `retryUncertainMovement()` sends the exact same key, allowing Laravel's atomic idempotency middleware to safely return the recorded outcome without duplicate balance deductions.
4. **No Re-Keying on Failure:** The controller never silently generates a new key on uncertain failure or 409 conflicts.

---

## Role-Based Access Control

The UI dynamically adapts to staff permissions validated by Laravel Sanctum:

| Staff Role | Key Abilities | UI Behavior |
| --- | --- | --- |
| **Cashier** | `view-inventory` | Read-only inventory access. Can search, filter, and inspect item balances. Creation FAB, "Record Stock Movement", "Edit Item", and recipe actions are hidden. |
| **Manager** | `view-inventory`, `adjust-inventory`, `manage-catalog` | Full operational access. Can create items, edit metadata, record idempotent stock movements, inspect ledger history, and edit product recipes. |
| **Admin** | Full system permissions | Unrestricted access across all inventory and recipe management operations. |

---

## Responsive Layouts & Accessibility

- **Compact Mobile (<600dp):** Single-column list with pull-to-refresh, debounced search (300ms), preset filter chips (`All`, `Low Stock`, `Active`, `Inactive`), and standard navigation transitions to `InventoryDetailPage`.
- **Tablet / Large Screen (≥600dp):** Two-pane master-detail view presenting the searchable master list on the left and the real-time detail/ledger inspector on the right without route switching.
- **Accessibility & Dynamic Type:** Full compliance with 2.0x text scaling; layouts use `Wrap`, `LayoutBuilder`, and `SingleChildScrollView` to prevent `RenderFlex` pixel overflows. Touch targets maintain a minimum of 48×48dp. High-contrast status badges provide unambiguous visual feedback.

---

## Verification Evidence

| Test Suite | Tests Passed | Assertions | Status |
| --- | --- | --- | --- |
| Mobile Exact Quantity & Domain (`inventory_domain_test.dart`) | 18 | Checked | PASS |
| Mobile API & Repository (`inventory_api_test.dart`) | 11 | Checked | PASS |
| Mobile State Machine & Idempotency (`inventory_controller_test.dart`) | 17 | Checked | PASS |
| Mobile Responsive Layout & Accessibility (`inventory_page_test.dart`) | 12 | Checked | PASS |
| Mobile Baseline + Phase 7 Suites (`flutter test`) | 593 | 593/593 | PASS |
| Mobile Static Analysis (`flutter analyze`) | 0 issues | Clean | PASS |
| Android Compilation (`flutter build apk --debug`) | 1 APK built | Clean | PASS |
| Backend Regression Suite (`php artisan test`) | 380 passed | 2,347 | PASS (73 skipped) |
