---
name: laravel-rest-api
description: Implement or review Laravel versioned REST endpoints, validation, resources, Eloquent workflows and policies using this project's existing Laravel conventions.
license: MIT
---

# Laravel REST API

Adapted from Laravel Boost's Laravel best-practices skill and reviewed rules. Vendor tool dependencies and Blade templates are removed. See [provenance](README.md) and [license](../../licenses/laravel-boost-mit.txt).

Inspect `composer.json`, `composer.lock`, routes, bootstrap configuration and sibling code. This project uses Laravel 13 and `/api/v1`; verify APIs against that version or installed framework code. Do not install Boost/MCP to use these instructions.

- Put HTTP orchestration in `Controllers/Api/V1`, input rules in Requests when they clarify the boundary, output shape in Resources, persistence in Models, and resource/action access in Policies. Use Services for meaningful reusable or transactional workflows; avoid generic CRUD layers over Eloquent.
- Separate authentication, authorization and validation. Model binding or an `exists` rule does not prove the current user owns a resource. Scope queries and authorize the action before returning or changing protected data.
- Pass only intended validated fields. Keep mass-assignment rules narrow; never accept client-controlled roles, prices, paid flags or ownership fields merely to simplify persistence. Allow-list query sort/filter identifiers.
- Use consistent HTTP status/error behavior and bounded pagination with deterministic ordering. Serialize only allowed fields; inspect query count when Resources traverse relationships.
- Use transactions/constraints for mutable invariants. Do not assume a validation-time stock check prevents concurrent overselling. Do not hold a database lock during a remote payment call.
- Read secrets through configuration; call `env()` in config files and `config()` in application code. Preserve production TLS and redacted logging. Configure rate limits for the actual abuse surface.

For auth or external providers, read [endpoint boundaries](references/endpoint-boundaries.md) and the security skill. Test success and denied/invalid paths, then run relevant backend checks. Endpoint documentation must describe actual implemented behavior.
