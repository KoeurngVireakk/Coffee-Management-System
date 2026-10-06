# Implemented Orders / POS checkout API (Phase 3)

Base `/api/v1`. Auth remains the existing Sanctum bearer token with staff ability, active assigned cashier/manager/admin account. Checkout still creates **unpaid pending orders** and scoped history. Phase 4 now separately implements [payment attempts/cash settlement and verification foundation](payments.md), moving eligible orders to paid. Phase 5 adds optional tracked reservations, shared atomic payment/stock finalization and safe manual cancellation; see [inventory contract](inventory.md). No real KHQR adapter, refund/void, generic order mutation route or paid receipt printing exists.

## Operations and permissions

| Method / URL | Roles / scope | Request | Success | Errors |
| --- | --- | --- | --- | --- |
| POST `/orders` | Cashier/manager/admin with process-pos; creator is caller | JSON cart + Idempotency-Key header | 201 first create; 200 same semantic replay | 401 auth; 403 account/role/ability/action; 422 input/header/catalog; 409 changed intent under key |
| GET `/orders` | Cashier own orders; manager/admin shop orders | History query below; no body | 200 Resource pagination | 401; 403 account/ability/action; 422 invalid/unknown filter |
| GET `/orders/{order}` | Cashier own only; manager/admin shop orders | ORD-ULID public reference; no body | 200 Order Resource | 401; 403 account/ability/action; 404 unknown/hidden/malformed reference |

GET supports HEAD. Detail lookup scopes the query before checking existence, then applies OrderPolicy; another cashier's reference has the same 404 body as an unknown reference. Numeric order IDs are not public URI keys. No PUT/PATCH/DELETE or receipt-printing endpoint exists. Separate Phase 4 payment routes are documented in payments.md.

## Checkout contract

```http
POST /api/v1/orders
Authorization: Bearer SYNTHETIC_TOKEN_PLACEHOLDER
Accept: application/json
Content-Type: application/json
Idempotency-Key: 6583ca16-7074-48ae-83a9-5b01b0d6a981
```

```json
{
  "items": [
    {"product_id":12,"quantity":2},
    {"product_id":18,"quantity":1}
  ]
}
```

- Body accepts exactly items, a list of 1-50 distinct lines. Each line accepts exactly product_id and quantity: strict positive JSON integers, quantity 1-99. Numeric strings, booleans/floats, duplicate IDs, missing values and additional fields are rejected. Oversized lists are bounded before wildcard expansion or catalog queries.
- Exactly one Idempotency-Key header, 8-64 ASCII characters: first letter/digit, remaining letters/digits/dot/underscore/hyphen. Case-sensitive; no whitespace, comma-combined values or body checkout_key. Clients generate a fresh opaque key per new cart and retain it for retries. The key is not an authentication mechanism and should contain no personal/secret data.
- Invalid headers produce errors.idempotency_key. Structural failures use message/errors keyed by items or its line fields. Forbidden input includes client price/name/SKU/subtotal/discount/tax/total/currency/status/created_by/role/paid/inventory/options, at the top level or inside a line.
- Laravel reloads products and category status under shared locks. Unknown/retired/inactive-category/invalid-authoritative-currency-or-price items return 422 with a generic items error; nothing is persisted.
- Prices come from catalog, USD cents only. Each line is unit_price_minor * quantity; discount/tax are zero; subtotal=total. Maximum possible cart total is 4949995050 cents from the line/quantity/catalog caps. Checked integer multiplication/addition never use float, decimal rounding or currency conversion.
- All writes commit together in one local transaction. status=pending_payment; inventory_tracked is the immutable deployment cutover decision. Tracking disabled has no stock locks/reservations; enabled requires active recipes and atomically reserves exact quantities. No payment/provider I/O. No final paid receipt is produced.

## Replay semantics

| Request | Result |
| --- | --- |
| New key for this actor | Create once, 201 |
| Same actor/key and same semantic cart | Original persisted order/snapshots, 200; no new rows |
| Same actor/key but different products/quantities | 409; original untouched |
| Same key, different actor | Independent actor-scoped checkout |
| Concurrent same actor/key | Unique constraint selects one winner; loser reloads after rollback and compares hash, returning 200 or 409 |

Intent hash version 1 contains sorted integer product IDs/quantities and fixed USD context. Input item ordering is semantically irrelevant; persisted line numbering follows ascending product IDs. Prices, names, timestamps, credentials and tokens are absent from the hash. Duplicate products are rejected rather than merged. Original replay works after catalog changes/retirement, including the tested race where a winner committed while another request's old read snapshot did not see it. Structurally invalid requests still fail validation before replay. A failed transaction does not consume its key.

No expiry of checkout keys is implemented; retained orders retain their key/hash. Reusing a key for a new cart conflicts even after later payment lifecycle changes. No automatic retry after an unrelated database failure is implied; transactions retry deadlocks at most three times.

## Order Resource

Example 201 response (detail/history entries/replay use the same fields):

```json
{
  "data": {
    "public_reference": "ORD-01K6WY00000000000000000000",
    "status": "pending_payment",
    "currency": "USD",
    "subtotal_minor": "850",
    "discount_minor": "0",
    "tax_minor": "0",
    "total_minor": "850",
    "inventory_tracked": false,
    "created_at": "2026-10-06T08:00:00+00:00",
    "creator": {"id":1,"name":"Synthetic cashier"},
    "items": [
      {"line_number":1,"product_id":12,"product_name":"Coffee","product_sku":"COFFEE-01","unit_price_minor":"325","quantity":2,"subtotal_minor":"650","discount_minor":"0","tax_minor":"0","line_total_minor":"650"},
      {"line_number":2,"product_id":18,"product_name":"Tea","product_sku":"TEA-01","unit_price_minor":"200","quantity":1,"subtotal_minor":"200","discount_minor":"0","tax_minor":"0","line_total_minor":"200"}
    ]
  }
}
```

All monetary fields are strings of exact cents. Product ID is a retained historical FK; displayed name/SKU/price are stored snapshots, never fetched dynamically from the current product. No numeric order/item ID, checkout_key, request_hash, token, password, email or permissions are serialized. Creator summary is safe within authorized own/shop scope. Paid responses additionally include safe accepted_payment and paid_at. Order/item facts and arbitrary instance mutations/deletes remain guarded; query-builder/raw SQL bypass Eloquent events and remain trusted maintenance operations, not API capabilities. Cross-row sum consistency is enforced by checkout transaction, not a simple CHECK.

## History query

| Parameter | Contract |
| --- | --- |
| status | pending_payment/paid/cancelled/expired enum values; checkout creates pending_payment and Phase 4 settlement creates paid; safe pending cancellation is implemented in Phase 5; automatic expiry remains unimplemented |
| created_from | Inclusive lower timestamp boundary |
| created_to | Inclusive upper timestamp boundary, >= created_from |
| per_page | Integer 1-100, default 25 |
| page | Integer 1-10000, default 1 |

Timestamp boundaries use ISO 8601 with seconds, optional 1-6 fractional digits, and Z or explicit ±HH:MM (offset <=14 hours). Invalid calendar dates, leap-second normalization, malformed offsets and reversed ranges are rejected. Date-only or timezone-less values are invalid. Boundaries convert to UTC while preserving supplied fractional precision; storage timestamps have second precision. URL-encode plus offsets (`%2B07:00`). There is no business-day/calendar interpretation or reporting timezone requirement.

Examples: GET `/orders?status=pending_payment&per_page=25`, GET `/orders?created_from=2026-10-06T08%3A00%3A00Z&created_to=2026-10-06T10%3A00%3A00Z`. Ordering is created_at DESC then internal id DESC. Unknown fields (including created_by/user_id/sort/payment filters) return 422; callers cannot widen ownership scope. Responses use standard data/links/meta pagination as documented for Catalog. Items and creator summaries are eager-loaded for a page; query count does not grow per order. No cache or reporting endpoint is added.

## Errors and operating limits

401/403 use existing auth/account/ability behavior. 422 uses Laravel message/errors; 409 returns `{"message":"This Idempotency-Key was already used for a different checkout intent."}`. 404 hides unowned/missing order identity. API errors use no-store/private; deployment requires HTTPS and APP_DEBUG=false.

MySQL 8.0.16+ enforces FK/unique/money/quantity/status/currency CHECKs. SQLite fast tests omit MySQL CHECK and locking guarantees. Laravel MySQL sessions now explicitly use +00:00 so physical TIMESTAMP epochs match UTC application values. Before rollout, audit legacy timestamps if a previous server/session timezone was non-UTC; this task performs no shared-data backfill or reinterpretation. New migration down operations delete order data and are not an allowed order-cancellation workflow. See [Phase 3 verification](../system-analysis/phase-3-verification.md) for real MySQL race/upgrade/query-plan evidence and remaining limits.

## Phase 5 cancellation and tracked checkout

POST `/orders/{order}/cancel` accepts no client properties, returns the persisted OrderResource with200, and is repeat-safe for cancelled orders. Cashier owns the order or management has shop access. Paid orders and active/unresolved/review payments return409. Tracked snapshots release exactly once; on_hand is unchanged. Tracking config is not client input; missing/inactive/insufficient recipes/stock return422 under items, with no partial order/reservation. Payment settlement consumes snapshots, not the current recipe. Existing checkout keys replay their original tracking flag across configuration changes. See [Phase 5 evidence](../system-analysis/phase-5-verification.md).
