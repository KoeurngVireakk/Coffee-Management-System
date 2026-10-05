# API foundation

- Future feature base path: `/api/v1`.
- Framework health endpoint: `GET /up` returns HTTP 200 when Laravel boots. It does not connect to MySQL.
- No auth, catalog, checkout, payment, or other business routes exist. Unknown `/api/*` paths return JSON 404, including `/api/v1` itself.
- Send `Accept: application/json`; send `Content-Type: application/json` for JSON bodies.
- Local browser origins `http://localhost:5173` and `http://127.0.0.1:5173` are allowed. Update `CORS_ALLOWED_ORIGINS` in the backend `.env` for additional explicit origins. Native mobile apps are not subject to browser CORS.

When endpoints are implemented, use Form Requests, API Resources, Laravel's validation error format, meaningful HTTP status codes, and pagination for collections. Document the actual request/response examples alongside each endpoint. Introduce an OpenAPI contract when the first endpoints exist; no speculative endpoint specification is committed.

The next authentication milestone will define the token contract, authorization policy, and error handling across both apps. Payments/KHQR will require a provider-specific contract, verified server-side callbacks, and idempotency decisions during its implementation.
