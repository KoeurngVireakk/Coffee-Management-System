# Operational Settings (Phase 6)

Base `/api/v1`, Sanctum bearer token with staff ability and active recognized staff.
Access rules:
- **Cashier:** `403 Forbidden` on all endpoints.
- **Manager:** Read-only access (`view-settings` permission).
- **Admin:** Read and update access (`manage-settings` permission).

## Endpoints

| Method / path | Description | Access | Response |
| --- | --- | --- | --- |
| `GET /settings` | List all allow-listed settings | Manager / Admin | 200 array of setting resources |
| `GET /settings/{key}` | Retrieve single setting | Manager / Admin | 200 setting resource or 404 |
| `PUT /settings/{key}` | Update setting value | Admin | 200 updated setting, emits `setting.updated` |

## Allow-Listed Setting Keys

Every setting key is strictly defined by backend application code. Arbitrary keys and secret injection attempts are rejected with `404 Not Found`.

| Key | Type | Constraints / Validation |
| --- | --- | --- |
| `shop_name` | string | Trimmed, non-empty, max 120 characters |
| `shop_timezone` | string | Valid IANA timezone identifier (e.g. `Asia/Phnom_Penh`, `UTC`) |

### Explicitly Excluded Settings

The following are strictly forbidden from being stored in the database settings table:
- Database credentials (`DB_PASSWORD`, `DB_USERNAME`)
- Application keys (`APP_KEY`)
- Payment provider secrets or merchant private keys
- Deployment toggles (`INVENTORY_TRACKING_ENABLED` remains deployment-only configuration)
- Currency settings (historical records remain immutable in USD cents)

## Reading Settings (`GET /settings`, `GET /settings/{key}`)

If a setting has not yet been configured in the database, the API represents it with `value: null` and `updated_by: null`:

```json
{
  "data": [
    {
      "key": "shop_name",
      "value": "Artisan Coffee Roasters",
      "updated_by": {
        "id": 1,
        "name": "Admin"
      },
      "updated_at": "2026-10-06T12:00:00Z"
    },
    {
      "key": "shop_timezone",
      "value": "Asia/Phnom_Penh",
      "updated_by": {
        "id": 1,
        "name": "Admin"
      },
      "updated_at": "2026-10-06T12:00:00Z"
    }
  ]
}
```

## Updating Settings (`PUT /settings/{key}`)

Request body:
```json
{
  "value": "Artisan Coffee Roasters"
}
```

- Key is validated against allow-list (unknown or forbidden key returns `404 Not Found`).
- Value is validated against typed rules (invalid type or bounds returns `422 Unprocessable Entity`).
- Written atomically with an immutable audit event (`setting.updated`) recording previous and new values.
- Response (200 OK):
```json
{
  "data": {
    "key": "shop_name",
    "value": "Artisan Coffee Roasters",
    "updated_by": {
      "id": 1,
      "name": "Admin"
    },
    "updated_at": "2026-10-06T12:00:00Z"
  }
}
```

