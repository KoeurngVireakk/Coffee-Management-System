# Laravel REST API - provenance

| Field | Record |
| --- | --- |
| Name | `laravel-rest-api` |
| Category | Backend Engineering / Laravel / REST API |
| Origin | Adapted upstream skill and rules |
| Author / organization | Laravel / Taylor Otwell; adapted by Coffee Management System maintainers |
| Source repository | [laravel/boost](https://github.com/laravel/boost) |
| GitHub popularity | 3,645 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-04T18:14:45Z (UTC); not proof of skill-content freshness |
| License | MIT; see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | 2026-09-30: relevant skill-subtree command/template maintenance; 2026-09-04: action-example revision |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Framework-maintainer guidance covers actual Laravel boundaries without a generic repository layer. Useful validation, authorization, query and provider rules.

## Adaptation and scope

Removed search-docs/MCP assumptions, Blade template execution and uninstalled skill links; condensed rules to versioned REST conventions and existing Services layout. No Boost package or generator installed.

## Security review

Read main skill and eight relevant rule files as plain text, including three Blade templates without evaluating them. No PHP/runtime package/config copied. Upstream examples of unsafe code were not imported as executable examples.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [Upstream `.ai/laravel/skill/laravel-best-practices/SKILL.md`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/SKILL.md)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/architecture.md`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/architecture.md)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/security.blade.php`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/security.blade.php)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/validation.md`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/validation.md)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/routing.md`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/routing.md)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/config.blade.php`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/config.blade.php)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/db-performance.md`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/db-performance.md)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/migrations.blade.php`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/migrations.blade.php)
- [Upstream `.ai/laravel/skill/laravel-best-practices/rules/http-client.md`](https://github.com/laravel/boost/blob/97b8da0cb8c2c1da75531a36e34adaa313a64afc/.ai/laravel/skill/laravel-best-practices/rules/http-client.md)
- [Laravel 13 validation](https://laravel.com/framework/docs/13.x/validation)
- [Laravel Sanctum](https://laravel.com/framework/docs/13.x/sanctum)
- [Laravel rate limiting](https://laravel.com/framework/docs/13.x/rate-limiting)
