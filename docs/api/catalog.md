# Implemented Category / Product API

Phase 2 only; no POS checkout, stock, options, recipes, discounts or tax. Base `/api/v1`. All operations require an unexpired Sanctum bearer token with staff ability and an active assigned cashier/manager/admin account. Existing auth/JSON errors are reused. See [OpenAPI](openapi.json) and [authentication](README.md).

## Roles and lifecycle

Cashier/manager/admin can browse active categories and sellable products. Managers/admins can also view and manage retired records. Cashier mutations return 403; retired/non-sellable detail reads return 404 for cashiers. Retirement/reactivation updates is_active; no DELETE route exists. Category retirement leaves product records intact. Reactivating a product under an inactive category still gives is_sellable=false; reactivating that category makes active children sellable again.

This is a shared shop catalog, with no ownership field. Manager/admin rights apply to catalog objects; IDs never grant those rights. is_sellable is derived from current product/category flags. Future checkout must revalidate it.

## Implemented operations

| Method / URI | Roles / behavior | Request | Success | Errors |
| --- | --- | --- | --- | --- |
| GET `/categories` | All staff; active by default; manager/admin can filter retired | Query below; no body | 200 paginated Category resources | 401; 403 staff/ability/filter; 422 invalid/unknown query |
| GET `/categories/{category}` | Active for staff; manager/admin may view retired | Path ID; no body | 200 Category resource | 401; 403 staff/ability; 404 missing/hidden |
| POST `/categories` | Manager/admin | Required name; optional is_active | 201 Category resource | 401; 403; 422 invalid/unknown fields |
| PUT/PATCH `/categories/{category}` | Manager/admin | Nonempty subset of editable fields | 200 Category resource | 401; 403; 404 missing; 422 invalid/empty/unknown fields |
| GET `/products` | All staff; sellable by default; manager/admin can filter non-sellable | Query below; no body | 200 paginated Product resources | 401; 403 staff/ability/filter; 422 invalid/unknown query |
| GET `/products/{product}` | Sellable for staff; manager/admin may view non-sellable | Path ID; no body | 200 Product resource | 401; 403 staff/ability; 404 missing/hidden |
| POST `/products` | Manager/admin | Required category_id/sku/name/price_minor/currency; optional description/is_active | 201 Product resource | 401; 403; 422 invalid/unknown fields or duplicate SKU |
| PUT/PATCH `/products/{product}` | Manager/admin | Nonempty subset of editable fields | 200 Product resource | 401; 403; 404 missing; 422 invalid/empty/unknown fields or duplicate SKU |

PUT and PATCH both perform partial updates; omitted fields are preserved. GET routes support HEAD. Unknown IDs return 404 through binding. Create returns persisted defaults. A SKU claimed after uniqueness validation also returns 422 with a sku error; unrelated DB exceptions are not hidden.

## Category fields and examples

Only name (required create, nonblank trimmed string <=120 characters) and is_active (optional strict JSON boolean, default true create) are writable. Name uniqueness is not assumed. Unknown properties, including id/role/permissions/created_by/timestamps, return 422. Empty update returns 422 with errors.body.

POST `/categories`:

```json
{"name":"Coffee","is_active":true}
```

201 response (GET/update return the same shape with 200):

```json
{
  "data": {
    "id": 1,
    "name": "Coffee",
    "is_active": true,
    "created_at": "2026-10-06T08:00:00+00:00",
    "updated_at": "2026-10-06T08:00:00+00:00"
  }
}
```

PATCH `/categories/1` with `{"is_active":false}` retires; `{"is_active":true}` reactivates. Neither changes the ID or deletes child products.

## Product fields and money

The user approved USD/scale 2 on 2026-10-06. price_minor is **integer cents**, accepted/serialized as a canonical decimal string, `"0"` through `"999999"` ($0.00 through $9,999.99). This is an administrative input bound, not a suggested coffee price. Fractional cents, floats/JSON numbers, negatives, leading zeros, scientific notation and excessive values are rejected. No conversion, exchange rate or rounding occurs.

| Field | Validation / behavior |
| --- | --- |
| category_id | Required create; positive integer referencing an existing category. Manager/admin may maintain products under retired categories, which remain non-sellable |
| sku | Required create; trimmed/uppercased; 1-64 ASCII letters/digits/hyphen/underscore; first character letter/digit; case-insensitive unique. Own current SKU may be retained on update |
| name | Required create; nonblank trimmed string <=160 characters |
| description | Optional nullable string <=2000 characters; null/blank clears; omitted update preserves |
| price_minor | Required create; canonical cent string 0-999999; manager/admin may reprice |
| currency | Required create; exactly USD after standard whitespace trimming; lowercase/other/malformed values rejected |
| is_active | Optional strict JSON boolean; default true create |

Unknown properties, including is_sellable/id/role/permissions/created_by/timestamps/payment_status/stock_quantity/variants/tax/discount, are rejected. Authorized catalog price maintenance is separate from future checkout, which will reject client-authoritative prices.

POST `/products`:

```json
{
  "category_id": 1,
  "sku": "coffee-01",
  "name": "Coffee",
  "description": null,
  "price_minor": "325",
  "currency": "USD",
  "is_active": true
}
```

201 response (detail/update use the same envelope):

```json
{
  "data": {
    "id": 1,
    "category_id": 1,
    "category": {"id":1,"name":"Coffee","is_active":true},
    "sku": "COFFEE-01",
    "name": "Coffee",
    "description": null,
    "price_minor": "325",
    "currency": "USD",
    "is_active": true,
    "is_sellable": true,
    "created_at": "2026-10-06T08:00:00+00:00",
    "updated_at": "2026-10-06T08:00:00+00:00"
  }
}
```

PATCH `/products/1` accepts e.g. `{"price_minor":"450"}`, `{"description":null}` or `{"is_active":false}`. Resources expose only approved catalog fields plus a minimal category summary; no staff/token/provider/inventory data. Timestamps are server-managed ISO 8601 UTC values; schema permits null timestamps in trusted raw fixtures.

## Query contract

| Parameter | Categories | Products | Validation |
| --- | --- | --- | --- |
| status | active default; inactive means category retired | active default means sellable; inactive means product or category retired | active/inactive/all; inactive/all require manage-catalog |
| category_id | Not accepted | Filter by ID | Positive integer; nonexistent category returns empty results rather than an existence error |
| search | Name substring | Name or SKU substring | Optional/nullable string <=80 characters; literal %, _ and ! escaped; parameters bound; `"0"` is a real term |
| per_page | Yes | Yes | Integer 1-100; default 25 |
| page | Yes | Yes | Integer 1-10000; default 1 |

Order is fixed name ascending, id ascending. sort, is_active, ownership and other unknown query fields return 422. No caching or FULLTEXT dependency. Offset pagination is deterministic for a given dataset; concurrent changes can alter later pages.

Examples: GET `/products?category_id=1&search=coffee&per_page=25&page=1`; GET `/categories?search=coffee`; manager GET `/products?status=all`. Responses use standard Laravel Resource data/links/meta pagination, e.g. abbreviated empty result:

```json
{
  "data": [],
  "links": {
    "first": "https://example.test/api/v1/products?page=1",
    "last": "https://example.test/api/v1/products?page=1",
    "prev": null,
    "next": null
  },
  "meta": {
    "current_page": 1,
    "from": null,
    "last_page": 1,
    "path": "https://example.test/api/v1/products",
    "per_page": 25,
    "to": null,
    "total": 0
  }
}
```

Laravel additionally supplies meta.links with navigation labels/URLs. URLs are synthetic. Product listing eager-loads categories once per page; [verification](../system-analysis/phase-2-verification.md) records query counts and MySQL plans.

## Errors and database limits

401: missing/expired/revoked token. 403: inactive/unassigned/unknown-role staff, missing ability, disallowed action/filter. 404: missing/hidden detail. 422: existing message/errors format, for example:

```json
{"message":"The price minor field format is invalid.","errors":{"price_minor":["The price minor field format is invalid."]}}
```

API errors inherit no-store/private headers. HTTPS and APP_DEBUG=false remain deployment requirements. MySQL 8.0.16+ is required for production CHECKs: signed BIGINT bounds, exact USD currency, case-insensitive SKU uniqueness and RESTRICT FK are verified on isolated MySQL. SQLite omits MySQL CHECKs and skips four direct invalid-money tests, while exercising HTTP validation/authorization. No shared database was reset.
