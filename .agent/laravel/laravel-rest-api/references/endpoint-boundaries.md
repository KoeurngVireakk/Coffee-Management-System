# Endpoint boundaries

Adapted from Laravel Boost's security, validation, routing, configuration and HTTP-client rules; MIT.

For mobile auth, use the documented token flow when Sanctum is selected and installed; a browser cookie flow has different CSRF requirements. Do not disable CSRF globally or treat CORS as authorization. Confirm token expiry, revocation and storage choices during the auth feature.

For a protected mutation, identify the operation's actor, target resource, permitted fields, policy, transaction and response. Verify 401, 403/ownership denial, 422 validation and 429 throttling where applicable without disclosing private existence or credentials.

Outbound provider calls require bounded connection/request timeouts, expected statuses and payload validation. Retry a state-changing request only with a provider-supported idempotency guarantee or equivalent proven duplicate protection. Fake external HTTP and prevent stray requests in tests.

The existing cache/session/queue defaults are file/file/sync. Durable payment work needs a justified worker/retry design; adding a job class to a synchronous queue does not make execution durable. Consult the architecture and security skills before changing those operational defaults.
