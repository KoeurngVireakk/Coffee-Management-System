# Staff Administration (Phase 6)

Base `/api/v1`, Sanctum bearer token with staff ability and active recognized staff.
Admin only (`manage-staff` permission). Managers and cashiers receive `403 Forbidden`.
No `DELETE` endpoint: destructive deletion is prohibited due to historical transactions and foreign key integrity.

## Endpoints

| Method / path | Description | Access | Response |
| --- | --- | --- | --- |
| `GET /staff` | List staff with filters and pagination | Admin | 200 paginated list, `name ASC, id ASC` |
| `POST /staff` | Provision a new staff user | Admin | 201 created user, emits `staff.created` audit event |
| `GET /staff/{user}` | Retrieve single staff member | Admin | 200 safe user resource |
| `PATCH /staff/{user}` | Update name, email, role, or activation | Admin | 200 updated user resource, token revocations, audits |
| `POST /staff/{user}/password` | Reset staff password | Admin | 200, revokes all tokens, emits `staff.password_reset` |
| `POST /staff/{user}/revoke-tokens` | Explicitly revoke all tokens for user | Admin | 200, emits `staff.tokens_revoked` with reason |

Numeric user IDs. Pagination defaults to 25 items per page (max 100, page max 10000). Unknown query or body properties return `422 Unprocessable Entity`.

## Staff Provisioning (`POST /staff`)

Body accepts exactly:
```json
{
  "name": "Sok Dara",
  "email": "dara@example.test",
  "role": "cashier",
  "is_active": true,
  "password": "Strong-temporary-passphrase!2026"
}
```

- `name`: string, required, max 255.
- `email`: string, required, RFC-compliant email, max 255. Normalized by trimming and lowercasing; unique in `users` table.
- `role`: string, required, one of `cashier`, `manager`, `admin`.
- `is_active`: boolean, optional (defaults to `true`).
- `password`: string, required, minimum 12 characters, max 1024. Securely hashed before persistence; never returned or logged.
- Injected fields (`role_id`, `permissions`, `abilities`, `user_id`, `is_admin`, etc.) are rejected with `422`.

Response (201 Created):
```json
{
  "data": {
    "id": 2,
    "name": "Sok Dara",
    "email": "dara@example.test",
    "role": "cashier",
    "is_active": true,
    "created_at": "2026-10-06T12:00:00Z",
    "updated_at": "2026-10-06T12:00:00Z"
  }
}
```
Passwords, token hashes, and remember tokens are never serialized.

## Staff Update (`PATCH /staff/{user}`)

Allows updating:
- `name`: string, max 255.
- `email`: string, RFC-compliant email, max 255, unique. Normalized to lowercase trimmed string.
- `role`: string, one of `cashier`, `manager`, `admin`.
- `is_active`: boolean.

Empty updates and unknown properties are rejected with `422`. Passwords sent through `PATCH` are rejected with `422` (password resets must use the dedicated endpoint).

### Token Revocation Policy

- **Name-only update:** Existing personal access tokens remain valid.
- **Role change:** Revokes all personal access tokens for the user to enforce fresh authentication under the new role.
- **Email change:** Revokes all personal access tokens for the user.
- **Deactivation (`is_active: false`):** Revokes all personal access tokens immediately.
- **Reactivation (`is_active: true`):** Does not automatically issue a token; staff must authenticate normally via `/auth/login`.

### Last Operational Admin Protection

An operational administrator has `is_active = true` and `role = 'admin'`. The system prevents any operation that would reduce the active operational admin count from 1 to 0:
- Deactivating the last active admin returns `409 Conflict`.
- Demoting the last active admin returns `409 Conflict`.
- Self-action does not bypass this invariant.
- Concurrency safety: Enforced via deterministic row-level locking on the `admin` role row to serialize competing admin demotions and deactivations.

409 Conflict response:
```json
{
  "message": "Cannot demote or deactivate the last operational administrator."
}
```

## Password Reset (`POST /staff/{user}/password`)

Admin-controlled password reset:
```json
{
  "password": "Brand-new-passphrase!2026",
  "password_confirmation": "Brand-new-passphrase!2026"
}
```
- Requires minimum 12 characters, confirmed.
- Atomically updates password hash, revokes all existing Sanctum tokens for that user, and emits `staff.password_reset` with no password or secret data in metadata.
- Returns `200 OK` with user resource and message.

## Explicit Token Revocation (`POST /staff/{user}/revoke-tokens`)

```json
{
  "reason": "Lost device reported by cashier"
}
```
- Requires `reason` string (1-255 characters).
- Deletes all personal access tokens for the target user; other users' tokens are untouched.
- Emits `staff.tokens_revoked` audit event with reason in metadata.
- Returns `200 OK` with user resource and message.

