# Premium Café OS — Client API Contract

Version: 1.0.0 (API v1)
Target Client: Flutter Mobile & Tablet POS (Android, iOS, Web)
Persisted Persistence Baseline: Laravel 13.x REST API + MySQL 8.0.16+
Status: **Frozen Baseline** (Phases 1–7 verified)

---

## 1. Architectural Principles & Base Conventions

1. **Base URL:**
   - Development Local: `http://127.0.0.1:8000/api/v1`
   - Android Emulator: `http://10.0.2.2:8000/api/v1`
   - Production / Staging: HTTPS required. All API routes are prefixed with `/api/v1`.
   - Boot check: `GET /up` (returns 200 OK; does not evaluate MySQL state).

2. **Transport & Data Format:**
   - Content-Type: `application/json`
   - Accept: `application/json`
   - Request bodies must be valid JSON objects. Empty bodies for POST endpoints should pass `{}`.
   - Unknown request parameters are strictly rejected (`422 Unprocessable Content`). Clients must never inject unmodeled fields.

3. **Authentication & Session:**
   - Mechanism: Laravel Sanctum Bearer Token.
   - Header: `Authorization: Bearer <plain_text_token>`.
   - Token creation occurs via `POST /api/v1/auth/login`.
   - Token revocation:
     - Explicit sign-out: `POST /api/v1/auth/logout`.
     - Administrative revocation: role changes, deactivation, or password resets invalidate all personal access tokens for that account immediately.
   - Login rejects invalid credentials and inactive/unassigned accounts with `401 Unauthorized` (`The provided credentials are incorrect.`). Existing active tokens used by accounts subsequently deactivated fail closed with `403 Forbidden` via active-staff authorization middleware.
   - Token hashes, password hashes, and database internal secrets are never returned to clients.

4. **Monetary Precision:**
   - Currency: Strictly `USD`.
   - Representation: All monetary values are integer cents (`BIGINT`), formatted in JSON as string or integer minor units (e.g., `$10.50` is `1050` minor units).
   - Invariants:
     - `subtotal_minor` = $\sum(\text{unit\_price\_minor} \times \text{quantity})$.
     - `discount_minor` = 0 (frozen; discounts deferred).
     - `tax_minor` = 0 (frozen; taxes deferred).
     - `total_minor` = `subtotal_minor`.
   - Floating-point numbers are strictly forbidden for currency.

5. **Inventory Quantity Precision:**
   - Units: Base units are `g` (grams), `ml` (milliliters), or `unit` (discrete pieces).
   - Representation: Exact decimal strings with 4 fractional digits (`DECIMAL(14,4)`), e.g., `"100.0000"`, `"0.5000"`.
   - Invariant: `available = on_hand - reserved >= 0`. Stock cannot be reserved or consumed past available inventory when tracking is enabled.

6. **Timestamps & Business Time:**
   - Database and API timestamps are serialized in ISO-8601 format in UTC (`YYYY-MM-DDTHH:MM:SS.uuuuuuZ` or `YYYY-MM-DDTHH:MM:SSZ`).
   - Operational reporting dates (`from_date`, `to_date`) are evaluated in the shop's operational timezone configured via `SettingRegistry::SHOP_TIMEZONE` (`shop_timezone`).
   - If `shop_timezone` is unconfigured or invalid, reporting endpoints return `409 Conflict` (`INVALID_STORE_TIMEZONE`).

7. **Idempotency & Safe Retries:**
   - Mutating POS operations accept an `Idempotency-Key` header (UUID or string up to 64 chars).
   - Required/Supported on:
     - `POST /api/v1/orders` (POS checkout)
     - `POST /api/v1/orders/{order}/payments/cash` (cash settlement)
     - `POST /api/v1/orders/{order}/payments/external` (external settlement initiation)
     - `POST /api/v1/inventory/items/{item}/movements` (stock adjustments)
   - Behavior:
     - Same key + same payload: returns identical original response.
     - Same key + different payload: returns `409 Conflict`.
     - Concurrent same key: serializes safely via database locks; exactly one mutation occurs.

---

## 2. Role-Based Access Control (RBAC) Matrix

Fixed roles: `cashier`, `manager`, `admin`.

| Endpoint Group | Cashier | Manager | Admin | Notes |
| --- | :---: | :---: | :---: | --- |
| **Auth** (`/auth/*`) | Yes | Yes | Yes | All active staff can login, logout, get me |
| **Active Menu** (`GET /products`, `GET /categories`) | Yes | Yes | Yes | Filtered to active items for cashier |
| **Catalog Admin** (`POST/PUT /categories`, `POST/PUT /products`) | No | Yes | Yes | Requires `manage-catalog` permission |
| **Recipes** (`GET/PUT /products/{id}/recipe`) | No | Yes | Yes | Requires `manage-inventory` permission |
| **POS Checkout** (`POST /orders`, `GET /orders/*`) | Yes | Yes | Yes | Cashier sees own orders; Manager/Admin sees all |
| **Order Cancel** (`POST /orders/{id}/cancel`) | Yes | Yes | Yes | Only pending_payment orders; releases reservations |
| **Payments** (`POST /payments/cash`, `external`) | Yes | Yes | Yes | Atomic settlement and reservation consumption |
| **Reconcile** (`POST /payments/{id}/reconcile`) | No | Yes | Yes | Requires `manage-orders` permission |
| **Inventory Browse** (`GET /inventory/items`) | Yes | Yes | Yes | Active staff have `view-inventory` permission |
| **Stock Movements** (`POST /inventory/movements`) | No | Yes | Yes | Requires `adjust-inventory` permission |
| **Staff Management** (`/staff/*`) | No | No | Yes | Admin only (`manage-staff`); last admin protected |
| **Settings Read** (`GET /settings/*`) | No | Yes | Yes | Manager and Admin |
| **Settings Write** (`PUT /settings/*`) | No | No | Yes | Admin only (`manage-settings`) |
| **Audit Log** (`GET /audit-events`) | No | No | Yes | Admin only (`view-audit-logs`); append-only |
| **Reports** (`GET /reports/*`) | No | Yes | Yes | Manager and Admin (`view-reports`) |

---

## 3. Standard HTTP Statuses & Error Envelopes

### Status Codes
- `200 OK`: Request succeeded. Returned on GET queries and updates.
- `201 Created`: Resource successfully created (e.g., checkout, staff creation).
- `401 Unauthorized`: Unauthenticated or token invalid/revoked/expired.
- `403 Forbidden`: Authenticated, but lacking required role permission or staff account is inactive (`is_active = false`).
- `404 Not Found`: Target resource does not exist or has been retired.
- `405 Method Not Allowed`: Unsupported HTTP verb invoked on endpoint.
- `409 Conflict`: Business rule or concurrency violation (e.g., idempotency mismatch, last admin deactivation, invalid timezone).
- `422 Unprocessable Content`: Validation failure or unknown parameter passed.
- `429 Too Many Requests`: Rate limit exceeded.
- `500 Internal Server Error`: Unhandled server failure.

### Standard Validation Error Envelope (`422`)
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "field_name": [
      "Specific validation failure explanation."
    ]
  }
}
```

### Standard Business Conflict Envelope (`409`)
```json
{
  "message": "Human-readable explanation of conflict.",
  "code": "SPECIFIC_CONFLICT_CODE",
  "details": {}
}
```

---

## 4. Primary Endpoint Specifications

### 4.1 Authentication (`/auth`)
- `POST /api/v1/auth/login`
  - Rate limit: `throttle:staff-login` (10 per minute per IP).
  - Body:
    ```json
    {
      "email": "staff@example.test",
      "password": "password123",
      "device_name": "Coffee POS Android"
    }
    ```
    - `email`: required, RFC email, max 255 chars, normalized to lowercase/trimmed.
    - `password`: required string, max 1024 chars.
    - `device_name`: required string, max 100 chars (human-readable device/client label).
    - Unknown fields are strictly disallowed (`422 Unprocessable Content`).
  - Response `200`:
    ```json
    {
      "data": {
        "id": 1,
        "name": "Staff User",
        "email": "staff@example.test",
        "role": "cashier",
        "permissions": [
          "view-catalog",
          "process-pos",
          "view-own-orders",
          "view-inventory"
        ]
      },
      "token": "plain-text-token-returned-once",
      "token_type": "Bearer",
      "expires_at": "2026-10-07T01:00:00+00:00"
    }
    ```
  - Response `401`: `{ "message": "The provided credentials are incorrect." }` (on invalid credentials, inactive staff, or unassigned role).
- `POST /api/v1/auth/logout`
  - Header: `Authorization: Bearer <token>`
  - Response `204`: No Content (empty response body). Token is deleted from server.
- `GET /api/v1/auth/me`
  - Header: `Authorization: Bearer <token>`
  - Response `200`:
    ```json
    {
      "data": {
        "id": 1,
        "name": "Staff User",
        "email": "staff@example.test",
        "role": "cashier",
        "permissions": [...]
      }
    }
    ```

### 4.2 Categories & Products (`/categories`, `/products`)
- `GET /api/v1/categories`: List categories (`id`, `name`, `is_active`, `created_at`, `updated_at`).
- `POST /api/v1/categories`: Admin/Manager create category.
- `PUT /api/v1/categories/{id}`: Admin/Manager update category.
- `GET /api/v1/products`: List products. Cashier receives only active products in active categories. Supports `category_id`, `search`, `page`, `per_page`.
- `POST /api/v1/products`: Admin/Manager create product (`name`, `sku`, `price_minor`, `category_id`, `is_active`).
- `PUT /api/v1/products/{id}`: Admin/Manager update product.

### 4.3 Orders & POS Checkout (`/orders`)
- `POST /api/v1/orders`: POS checkout.
  - Header: `Idempotency-Key: <uuid>`
  - Body:
    ```json
    {
      "items": [
        { "product_id": 1, "quantity": 2 }
      ]
    }
    ```
  - Response `201`: Order resource in `pending_payment` status. If inventory tracking is enabled, stock reservations are created.
- `GET /api/v1/orders`: List orders. Bounded pagination. Scoped by role.
- `GET /api/v1/orders/{order:public_reference}`: Order detail by public reference (`ORD-<ULID>`), returning line items, snapshots, and payment history.
- `POST /api/v1/orders/{order:public_reference}/cancel`: Cancel unpaid order by public reference. Releases stock reservations.

### 4.4 Payments (`/orders/{order:public_reference}/payments`)
- `POST /api/v1/orders/{order:public_reference}/payments/cash`
  - Header: `Idempotency-Key: <uuid>`
  - Body: `{ "tender_minor": 1500 }`
  - Response `200`: Settles order. `change_minor` computed (`tender_minor - total_minor`). Consumes reservations and moves stock atomically. Order transitions to `paid`.
- `POST /api/v1/orders/{order:public_reference}/payments/external`
  - Header: `Idempotency-Key: <uuid>`
  - Body: `{}` (No request body fields accepted; provider is simulated/fixed; real bank integration disabled).
  - Response `200`: Generates external payment attempt with `initiated`, `pending`, or `uncertain` state. (Status is never `completed`).
- `POST /api/v1/orders/{order:public_reference}/payments/{payment}/reconcile`
  - Admin/Manager manual reconciliation for unresolved or mismatched attempts.

### 4.5 Inventory & Recipes (`/inventory`)
- `GET /api/v1/inventory/items`: List inventory items (`id`, `sku`, `name`, `base_unit`, `on_hand`, `reserved`, `available`, `reorder_level`, `is_active`, `low_stock`, `created_at`, `updated_at`). Filter by `is_active`, `search`.
- `POST /api/v1/inventory/items`: Create inventory item (`sku`, `name`, `base_unit`, `reorder_level`).
- `PUT /api/v1/inventory/items/{id}`: Update inventory item.
- `POST /api/v1/inventory/items/{id}/movements`: Create manual stock adjustment.
  - Body: `{ "quantity_delta": "10.0000", "reason": "receipt" }`
  - Allowed manual reasons: `opening_balance`, `receipt`, `waste`, `adjustment`.
- `GET /api/v1/products/{product}/recipe`: View recipe ingredients.
- `PUT /api/v1/products/{product}/recipe`: Replace recipe ingredients (`items: [{ inventory_item_id, quantity }]`).

### 4.6 Staff Administration (`/staff`)
- `GET /api/v1/staff`: List staff. Filters: `role`, `is_active`, `search`.
- `POST /api/v1/staff`: Provision new staff account.
- `GET /api/v1/staff/{user}`: Staff detail. Never exposes password or token hashes.
- `PATCH /api/v1/staff/{user}`: Update name, email, role, or active status. Last operational admin protected against deactivation/demotion. Role or deactivation changes revoke all active tokens.
- `POST /api/v1/staff/{user}/password`: Admin reset password. Revokes all active tokens.
- `POST /api/v1/staff/{user}/revoke-tokens`: Explicit revocation of all tokens for an account.

### 4.7 Settings & Audit (`/settings`, `/audit-events`)
- `GET /api/v1/settings`: View operational settings.
- `GET /api/v1/settings/{key}`: View single setting. Allow-listed keys: `shop_name`, `shop_timezone`. Absent keys return `{ "key": "...", "value": null }`.
- `PUT /api/v1/settings/{key}`: Admin update setting. Validates key and value type.
- `GET /api/v1/audit-events`: Admin-only immutable audit trail. Bounded pagination. Filters: `actor_id`, `action`, `subject_type`, `from_date`, `to_date`.

### 4.8 Operational Reports (`/reports`)
- `GET /api/v1/reports/overview`: Executive KPI card metrics (`revenue_minor`, `paid_orders`, `average_order_value_minor`, `low_stock_items`, `reconciliation_required`).
- `GET /api/v1/reports/sales-trend`: Continuous chronological daily buckets with zero-filling.
- `GET /api/v1/reports/payment-methods`: Breakdown by payment method (`cash`, `external`).
- `GET /api/v1/reports/top-products`: Ranked by revenue DESC, quantity DESC, product_id ASC (`limit` 1..100).
- `GET /api/v1/reports/inventory`: Items with low-stock status filter (`status=all|low`).
- `GET /api/v1/reports/reconciliation`: Unresolved financial exceptions (sanitized of secrets).

---

## 5. Deliberately Unavailable Features (Do NOT Implement in Client)

The upcoming Flutter client must NOT invent or assume support for the following out-of-scope features:
1. **Real Bakong / KHQR Bank Calls:** Network bank communication is disabled pending merchant keys; POS displays provider-neutral external payment simulation.
2. **Refunds and Voids:** No endpoint exists for post-settlement order cancellation or partial refunds.
3. **Automatic Reservation Expiry:** Unpaid orders do not auto-cancel on a background worker; cancellation is explicit via `POST /orders/{id}/cancel`.
4. **Physical Receipt Printing:** Printing protocols (ESC/POS, Bluetooth, USB) are not handled by the API.
5. **Customer Accounts & Loyalty:** System is strictly staff-operated POS; no customer logins or points ledger.
6. **Multi-Store Tenancy:** All operations apply to a single coffee shop instance.
7. **Offline POS Mode:** Flutter client operates online against the REST API. Local SQLite caching on Flutter is presentation-only, not an offline transaction store.

---

## 6. Semantic Contract Evolution Guidelines

This contract is frozen for the initial Flutter client release. Future backend modifications must adhere to:
- **Additive changes are permitted:** Adding new optional response attributes or new endpoints will not break existing Flutter builds.
- **Breaking changes are prohibited:** Renaming or removing existing JSON attributes, altering integer-cent representations to floating point, changing quantity decimals, or modifying HTTP status meanings requires explicit migration coordination.
