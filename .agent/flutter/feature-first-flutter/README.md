# Feature-first Flutter - provenance

| Field | Record |
| --- | --- |
| Name | `feature-first-flutter` |
| Category | Flutter / Mobile Development |
| Origin | Adapted upstream skills |
| Author / organization | The Flutter Authors; adapted by Coffee Management System maintainers |
| Source repository | [flutter/agent-plugins](https://github.com/flutter/agent-plugins) |
| GitHub popularity | 3,026 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-01T09:14:31Z (UTC); not proof of skill-content freshness |
| License | BSD-3-Clause; see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | 2026-04-21: architecture/layout skill additions; repository remains active |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Official Flutter separation-of-concerns and constraint-based layout guidance directly fits phone/tablet POS work.

## Adaptation and scope

Preserved project feature-first data/domain/presentation layout; removed mandatory ChangeNotifier, code generation and DI-package choices, model metadata and unsafe example caching assumptions; added SDK-version/state-lifecycle checks.

## Security review

Read selected Markdown and root BSD license. No generator, Gemini key requirement, MCP configuration, code examples or runtime rules imported. This preserves the user-selected architecture rather than the upstream hybrid directory layout.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [Upstream `skills/flutter-apply-architecture-best-practices/SKILL.md`](https://github.com/flutter/agent-plugins/blob/0ef3972f93e2baa4156ba1cbb1e515cd53079c68/skills/flutter-apply-architecture-best-practices/SKILL.md)
- [Upstream `skills/flutter-build-responsive-layout/SKILL.md`](https://github.com/flutter/agent-plugins/blob/0ef3972f93e2baa4156ba1cbb1e515cd53079c68/skills/flutter-build-responsive-layout/SKILL.md)
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Adaptive layouts](https://docs.flutter.dev/ui/adaptive-responsive/general)
