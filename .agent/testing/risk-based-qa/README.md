# Risk-based QA - provenance

| Field | Record |
| --- | --- |
| Name | `risk-based-qa` |
| Category | Testing / QA |
| Origin | Adapted upstream widget-test workflow |
| Author / organization | The Flutter Authors; adapted by Coffee Management System maintainers |
| Source repository | [flutter/agent-plugins](https://github.com/flutter/agent-plugins) |
| GitHub popularity | 3,026 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-01T09:14:31Z (UTC); not proof of skill-content freshness |
| License | BSD-3-Clause; see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | 2026-04-21: widget-test skill added; source workflow stable in an active repository |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Official widget interaction/testing guidance plus local negative-case matrix covers high-impact auth/payment/stock/UI defects.

## Adaptation and scope

Added Laravel/MySQL/provider isolation, explicit pumping and realistic risk selection. The separately inspected integration skill was not installed: mandatory Flutter Driver extension, MCP tools and broad pumpAndSettle use were removed in favor of version-aware official integration docs.

## Security review

No test scripts, runtime app entrypoint modifications, Flutter Driver instrumentation, Firebase upload instructions or test packages installed. Requires actual behavior assertions and truthful platform limits.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [Upstream `skills/flutter-add-widget-test/SKILL.md`](https://github.com/flutter/agent-plugins/blob/0ef3972f93e2baa4156ba1cbb1e515cd53079c68/skills/flutter-add-widget-test/SKILL.md)
- [Flutter testing overview](https://docs.flutter.dev/testing/overview)
- [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)
- [Laravel HTTP tests](https://laravel.com/framework/docs/13.x/http-tests)
- [Project verification](../../../docs/project/verification.md)
