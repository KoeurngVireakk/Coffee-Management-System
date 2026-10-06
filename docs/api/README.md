# Implemented API contract

Versioned base `/api/v1`; send `Accept: application/json` and JSON bodies with `Content-Type: application/json`. Errors under `/api/*` also render JSON when Accept is omitted. Unknown paths, including bare `/api/v1`, return JSON 404. No catalog/order/payment/inventory/report/staff-edit/settings endpoints exist. [OpenAPI](openapi.json) describes the three implemented auth operations.

## Authentication contract

Sanctum bearer tokens, eight-hour absolute expiry (no sliding refresh). Send `Authorization: Bearer <token>` on protected operations. Tokens are hashed in the database, plaintext returned once at login, and carry `staff` ability. Permissions come from current database role; token ability alone does not grant a business permission. Role names: cashier, manager, admin. Protected endpoints require an active account with a recognized role and staff token ability. Role gates for planned modules are not additional endpoints.

No public registration/password recovery/token refresh or default account. No cookie/session/CSRF-cookie authentication route in this phase. Flutter/native token storage and first-party browser cookie/CSRF authentication remain future work; see [official Sanctum guidance](https://laravel.com/framework/docs/13.x/sanctum). All auth successes and API errors use `Cache-Control: no-store, private`.

### POST /api/v1/auth/login

Authentication: none. Eligible roles: active assigned cashier/manager/admin, established from database after password verification. Body accepts exactly:

```json
{
  "email": "cashier@example.test",
  "password": "Synthetic-only-example!2026",
  "device_name": "Counter tablet"
}
```

Validation: email required string RFC email <=255 characters, trimmed and lowercased; password required string <=1024 characters (not trimmed); device_name required nonblank string <=100 characters (trimmed). All other top-level fields, including role/role_id/permissions/is_active/user_id/price/payment_status, yield 422. Query/body properties are combined by Laravel validation; send credentials in the JSON body, never URLs/logs. Trusted provisioning must normalize emails consistently.

200 example (synthetic placeholder token, not usable):

```json
{
  "data": {
    "id": 1,
    "name": "Synthetic cashier",
    "email": "cashier@example.test",
    "role": "cashier",
    "permissions": ["view-catalog", "process-pos", "view-own-orders", "view-inventory"]
  },
  "token": "1|SYNTHETIC_TOKEN_PLACEHOLDER",
  "token_type": "Bearer",
  "expires_at": "2026-10-06T15:00:00+00:00"
}
```

The user resource exposes only id/name/email/role/permissions. It never includes password/remember_token/token hashes/internal account flags. Password is rehashed at successful login if Laravel's configured cost has changed.

| Status | Meaning |
| --- | --- |
| 200 | Credentials valid; active assigned staff; token issued |
| 401 | Same `The provided credentials are incorrect.` message for wrong password, unknown email, inactive account or missing/unrecognized role; no token |
| 422 | Validation failed; Laravel `message` plus `errors` keyed by field |
| 429 | Limit exceeded; `message` and Retry-After / X-RateLimit-* headers |

Limits: five requests/minute per normalized email+IP; thirty requests/minute per IP. Successes and invalid requests count. No permanent lockout or reset on success. Keys hash identity/IP rather than storing raw email in cache keys. Default file cache is local; multiple nodes require a shared backend and correct trusted proxy setup.

### GET /api/v1/auth/me

Authentication: bearer token required; all active recognized roles. No request body/target-user ID. UserPolicy authorizes the caller's own identity. Query identifiers cannot select another user. 200 example:

```json
{
  "data": {
    "id": 1,
    "name": "Synthetic cashier",
    "email": "cashier@example.test",
    "role": "cashier",
    "permissions": ["view-catalog", "process-pos", "view-own-orders", "view-inventory"]
  }
}
```

401: missing/invalid/expired/revoked token (`{"message":"Unauthenticated."}`). 403: authenticated token but staff account inactive/unassigned/unknown role (`{"message":"Staff access is unavailable."}`), missing staff ability, or policy denial. The current role is loaded for each request, so downgrade/deactivation applies to existing tokens on their next request. HEAD shares this route and returns headers without body.

### POST /api/v1/auth/logout

Authentication: bearer required; all active recognized roles with staff ability. No body. 204 with empty body and no-store header. Revokes only the calling token, leaving other devices valid. Reusing the token or repeating logout returns 401; this endpoint is not a blanket all-device revocation API. 403 for inactive/unassigned/unknown-role account or missing ability; these accounts already have no staff API access.

## JSON errors

422 representative example (framework message summary may change with error count):

```json
{
  "message": "The email field is required. (and 2 more errors)",
  "errors": {
    "email": ["The email field is required."],
    "password": ["The password field is required."],
    "device_name": ["The device name field is required."]
  }
}
```

403/404/429 use `message`; clients rely on HTTP status and field keys rather than parsing English wording. Unexpected server failures use Laravel JSON error handling; production must run APP_DEBUG=false to suppress traces. No speculative order/payment error contract is presented as working.

## Health and browser configuration

`GET /up` (and HEAD): public framework boot health endpoint, no role/body. With Accept: application/json, 200 returns `{"status":"up"}`; diagnosed boot failure returns 500 with `{"status":"down"}` when debug is disabled. Without JSON Accept it returns HTML. It does not verify MySQL readiness. A successful health check does not prove auth persistence or payment availability. The OpenAPI health operation overrides the API server base to `/`.

Explicit local browser origins `http://localhost:5173` and `http://127.0.0.1:5173` are allowed by CORS. Configure additional explicit origins through CORS_ALLOWED_ORIGINS; CORS is not authorization. Native apps do not use browser CORS. Preserve CSRF protection when a browser cookie flow is introduced later. Use HTTPS for deployed clients.
