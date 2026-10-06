# Operational Reporting + Analytics Foundation (Phase 7)

Base `/api/v1/reports`, Sanctum bearer token with staff ability and active recognized staff.

Access rules:
- **Cashier:** `403 Forbidden` on all report endpoints (`view-reports` permission denied).
- **Manager:** Read-only access (`view-reports` permission allowed).
- **Admin:** Read-only access (`view-reports` permission allowed).
- **Inactive Staff:** `403 Forbidden`.
- **Unauthenticated:** `401 Unauthorized`.

## Shop Timezone Prerequisite

All reporting date-range queries operate under authoritative business calendar dates resolved in the shop's operational timezone.
The timezone identifier is read from the allow-listed setting `shop_timezone` (e.g. `Asia/Phnom_Penh`, `America/New_York`, `UTC`).

If `shop_timezone` is not configured or contains an unrecognized identifier, all report endpoints return `409 Conflict`:

```json
{
  "message": "The shop timezone is not configured. An administrator must set shop_timezone before generating reports."
}
```

## Endpoints

| Method / path | Description | Access | Response |
| --- | --- | --- | --- |
| `GET /reports/overview` | Executive KPI summary | Manager / Admin | 200 overview metrics object |
| `GET /reports/sales-trend` | Daily revenue & volume trend | Manager / Admin | 200 consecutive daily buckets |
| `GET /reports/payment-methods` | Breakdown by accepted tender method | Manager / Admin | 200 payment method breakdown |
| `GET /reports/top-products` | Top selling products by revenue | Manager / Admin | 200 ranked product items |
| `GET /reports/inventory` | Inventory status & low stock alert | Manager / Admin | 200 inventory summary & paginated items |
| `GET /reports/reconciliation` | Payment exceptions requiring audit | Manager / Admin | 200 exception counts & paginated records |

## Common Date Range Parameters

The first four endpoints (`overview`, `sales-trend`, `payment-methods`, `top-products`) accept optional calendar date range filters:

| Parameter | Type | Default | Validation / Constraint |
| --- | --- | --- | --- |
| `from_date` | string | 29 days before today | Format `Y-m-d`. Required if `to_date` is present. |
| `to_date` | string | Today | Format `Y-m-d`. Required if `from_date` is present. Must be `>= from_date`. |

**Date Range Constraints:**
- Maximum allowable range between `from_date` and `to_date` is **366 days**. Ranges exceeding 366 days return `422 Unprocessable Content`.
- Unknown query parameters are strictly rejected with `422 Unprocessable Content`.

---

## 1. Overview (`GET /reports/overview`)

Aggregates high-level operational and financial KPIs for the requested period.

### Query Parameters
- `from_date` (optional)
- `to_date` (optional)

### 200 OK Response Example

```json
{
  "data": {
    "period": {
      "from_date": "2026-10-01",
      "to_date": "2026-10-06",
      "timezone": "Asia/Phnom_Penh"
    },
    "revenue_minor": "125450",
    "currency": "USD",
    "paid_orders": 35,
    "average_order_value_minor": "3584",
    "low_stock_items": 3,
    "reconciliation_required": 1
  }
}
```

### Metrics Semantics
- `revenue_minor`: Exact string representation of the sum of `orders.total_minor` where order `status = 'paid'` and `accepted_payment_id IS NOT NULL`.
- `currency`: Authoritative monetary currency (`USD`).
- `paid_orders`: Exact integer count of paid orders settled within the business period.
- `average_order_value_minor`: Integer floor minor units (`intdiv(revenue, paid_orders)`). Returns `"0"` if `paid_orders` is zero.
- `low_stock_items`: Current real-time count of active inventory items where `(on_hand - reserved) <= reorder_level`. Inactive items are excluded.
- `reconciliation_required`: Current real-time count of payments flagged with `reconciliation_required = true`.

---

## 2. Sales Trend (`GET /reports/sales-trend`)

Returns continuous chronological business-day buckets from `from_date` to `to_date`. Days with zero sales are always included with zeroed amounts.

### Query Parameters
- `from_date` (optional)
- `to_date` (optional)

### 200 OK Response Example

```json
{
  "data": [
    {
      "date": "2026-10-01",
      "revenue_minor": "25000",
      "paid_orders": 8
    },
    {
      "date": "2026-10-02",
      "revenue_minor": "0",
      "paid_orders": 0
    },
    {
      "date": "2026-10-03",
      "revenue_minor": "42300",
      "paid_orders": 12
    }
  ],
  "period": {
    "from_date": "2026-10-01",
    "to_date": "2026-10-03",
    "timezone": "Asia/Phnom_Penh"
  }
}
```

---

## 3. Payment Method Breakdown (`GET /reports/payment-methods`)

Returns total revenue and order count grouped by the accepted payment method (`cash`, `external`) for orders paid within the period.

### Query Parameters
- `from_date` (optional)
- `to_date` (optional)

### 200 OK Response Example

```json
{
  "data": [
    {
      "method": "cash",
      "paid_orders": 24,
      "amount_minor": "85400"
    },
    {
      "method": "external",
      "paid_orders": 11,
      "amount_minor": "40050"
    }
  ],
  "currency": "USD",
  "period": {
    "from_date": "2026-10-01",
    "to_date": "2026-10-06",
    "timezone": "Asia/Phnom_Penh"
  }
}
```

---

## 4. Top Selling Products (`GET /reports/top-products`)

Aggregates historical order item snapshots (`line_total_minor`, `quantity`) for all paid orders in the period.
Results are ordered by `revenue_minor` DESC, `quantity_sold` DESC, and `product_id` ASC.

### Query Parameters
- `from_date` (optional)
- `to_date` (optional)
- `limit` (optional, integer, min: 1, max: 50, default: 10)

### 200 OK Response Example

```json
{
  "data": [
    {
      "product_id": 4,
      "sku": "ICED-LATTE",
      "name": "Iced Caffe Latte",
      "quantity_sold": 18,
      "revenue_minor": "54000"
    },
    {
      "product_id": 1,
      "sku": "HOT-AME-REG",
      "name": "Americano",
      "quantity_sold": 15,
      "revenue_minor": "37500"
    }
  ],
  "currency": "USD",
  "period": {
    "from_date": "2026-10-01",
    "to_date": "2026-10-06",
    "timezone": "Asia/Phnom_Penh"
  }
}
```

---

## 5. Current Inventory Report (`GET /reports/inventory`)

Provides current operational stock visibility, highlighting low-stock items requiring replenishment.

### Query Parameters
- `status` (optional, string: `low` or `all`, default: `low`)
  - `low`: Only active items where `(on_hand - reserved) <= reorder_level`.
  - `all`: All items.
- `search` (optional, string, max 100 chars): Case-insensitive match on name or SKU.
- `page` (optional, integer, min: 1, default: 1)
- `per_page` (optional, integer, min: 1, max: 100, default: 25)

### 200 OK Response Example

```json
{
  "summary": {
    "total_items": 12,
    "low_stock_items": 2
  },
  "data": [
    {
      "id": 1,
      "sku": "COFFEE-BEANS-ARABICA",
      "name": "Arabica Beans (Dark Roast)",
      "base_unit": "g",
      "on_hand": "1200.0000",
      "reserved": "400.0000",
      "available": "800.0000",
      "reorder_level": "1000.0000",
      "is_low_stock": true,
      "is_active": true
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 25,
    "total": 1
  }
}
```

---

## 6. Reconciliation Exceptions (`GET /reports/reconciliation`)

Surfaces all payment records requiring administrative reconciliation or currently in an unresolved state (`pending`, `uncertain`).
Zero credentials, hashes, attempt keys, or provider raw payloads are exposed.

### Query Parameters
- `page` (optional, integer, min: 1, default: 1)
- `per_page` (optional, integer, min: 1, max: 100, default: 25)

### 200 OK Response Example

```json
{
  "summary": {
    "reconciliation_required_count": 1,
    "unresolved_attempts_count": 2
  },
  "data": [
    {
      "id": 84,
      "order_id": 42,
      "order_reference": "ORD-01K8...",
      "method": "external",
      "status": "confirmed",
      "expected_amount_minor": "450",
      "currency": "USD",
      "tender_minor": null,
      "change_minor": null,
      "reconciliation_required": true,
      "reconciliation_reason": "amount_mismatch_settled_override",
      "created_at": "2026-10-06T09:30:00.000000Z",
      "updated_at": "2026-10-06T09:35:12.000000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 25,
    "total": 1
  }
}
```

### Sanitized Field Guarantees
The reconciliation payload deliberately strips and excludes:
- `attempt_key`
- `request_hash`
- `provider`
- `external_transaction_id`
- `merchant_reference`
- `correlation_reference`
- `qr_payload`
- `initiated_by`

---

## Future Frontend Integration (Premium Café OS)

The response schemas are tailored for consumption by Flutter state management and UI widgets:
- Single-pass executive cards (`overview`) for the manager dashboard.
- Direct Cartesian charting series (`sales-trend`) without client-side date-filling logic.
- Donut/pie breakdown (`payment-methods`).
- Ranked list tiles (`top-products`).
- Alert badges and filter tabs (`inventory`).
- Incident triage queue (`reconciliation`).
