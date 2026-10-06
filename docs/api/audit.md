# Administrative Audit Events (Phase 6)

Base `/api/v1`, Sanctum bearer token with staff ability and active recognized staff.
Access: Admin only (`manage-staff` permission). Managers and cashiers receive `403 Forbidden`.

## Immutability and Audit Integrity

The `audit_events` table is append-only.
- Audit events are created solely by trusted backend transactional workflows.
- There are no endpoints for creating, editing, or deleting audit events (`POST`, `PUT`, `PATCH`, `DELETE` return 404 or 405).
- Database models enforce immutability: attempting `$event->update()` or `$event->delete()` throws a `LogicException`.

## Endpoints

| Method / path | Description | Access | Response |
| --- | --- | --- | --- |
| `GET /audit-events` | Query audit events with filters and pagination | Admin | 200 paginated list, `created_at DESC, id DESC` |

### Query Filters

| Parameter | Type | Validation / Description |
| --- | --- | --- |
| `actor_id` | integer | Filter by actor user ID (`min:1`) |
| `action` | string | Filter by action name (e.g. `staff.created`, max 64) |
| `subject_type` | string | Filter by subject type (e.g. `user`, `setting`, max 64) |
| `subject_id` | integer | Filter by numeric subject ID (`min:1`) |
| `created_from` | string | ISO-8601 absolute UTC timestamp boundary |
| `created_to` | string | ISO-8601 absolute UTC timestamp boundary (must be >= `created_from`) |
| `per_page` | integer | Items per page (default 25, max 100) |
| `page` | integer | Page number (`min:1`, max 10000) |

Ordering is strictly deterministic: `created_at DESC, id DESC`.

## Recorded Events and Metadata Allow-List

Audit metadata is strictly structured and sanitized. Passwords, password hashes, access token strings, token secrets, authorization headers, and raw request bodies are strictly excluded.

| Action | Subject Type | Subject ID | Metadata Allow-List |
| --- | --- | --- | --- |
| `staff.created` | `user` | User ID | `email`, `role`, `is_active` |
| `staff.updated` | `user` | User ID | Field deltas (e.g. `name`, `email`) |
| `staff.role_changed` | `user` | User ID | `from_role`, `to_role` |
| `staff.activated` | `user` | User ID | `from_active: false`, `to_active: true` |
| `staff.deactivated` | `user` | User ID | `from_active: true`, `to_active: false` |
| `staff.password_reset` | `user` | User ID | `null` (zero secret data) |
| `staff.tokens_revoked` | `user` | User ID | `reason` (string, max 255) |
| `setting.updated` | `setting` | `null` | `key`, `from`, `to` |

## Response Example

`GET /api/v1/audit-events`
```json
{
  "data": [
    {
      "id": 12,
      "actor": {
        "id": 1,
        "name": "Admin User"
      },
      "action": "staff.role_changed",
      "subject_type": "user",
      "subject_id": 4,
      "metadata": {
        "from_role": "cashier",
        "to_role": "manager"
      },
      "created_at": "2026-10-06T12:30:00Z"
    },
    {
      "id": 11,
      "actor": {
        "id": 1,
        "name": "Admin User"
      },
      "action": "setting.updated",
      "subject_type": "setting",
      "subject_id": null,
      "metadata": {
        "key": "shop_timezone",
        "from": "UTC",
        "to": "Asia/Phnom_Penh"
      },
      "created_at": "2026-10-06T12:00:00Z"
    }
  ],
  "links": { ... },
  "meta": {
    "current_page": 1,
    "from": 1,
    "last_page": 1,
    "per_page": 25,
    "to": 2,
    "total": 2
  }
}
```

