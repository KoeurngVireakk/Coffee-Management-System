# Practical system design - provenance

| Field | Record |
| --- | --- |
| Name | `practical-system-design` |
| Category | Software Architecture / Clean Architecture |
| Origin | Original project skill; documentation references only |
| Author / organization | Coffee Management System maintainers; references by Flutter and Laravel |
| Source repository | [laravel/boost](https://github.com/laravel/boost) |
| GitHub popularity | 3,645 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-04T18:14:45Z (UTC); not proof of skill-content freshness |
| License | MIT (original project text only); see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | Local skill created 2026-10-05; no independently maintained upstream skill is claimed. |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Owns cross-app decisions, transactions/durability and failure boundaries while Flutter/Laravel skills own implementation details.

## Adaptation and scope

Original decision workflow respecting the current architecture; avoids hypothetical tenancy, offline POS and distributed systems.

## Security review

No imported meta-agent process, forced delegation, always-on hooks or automatic architecture rewrite. Decision records are proportional to the requested change.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [Project architecture](../../../docs/architecture/README.md)
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Laravel service container](https://laravel.com/framework/docs/13.x/container)
