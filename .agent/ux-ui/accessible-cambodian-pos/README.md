# Accessible Cambodian POS - provenance

| Field | Record |
| --- | --- |
| Name | `accessible-cambodian-pos` |
| Category | UX/UI Design / Accessibility |
| Origin | Original project skill; documentation references only |
| Author / organization | Coffee Management System maintainers; references by W3C, Flutter Authors and National Bank of Cambodia |
| Source repository | [w3c/wcag](https://github.com/w3c/wcag) |
| GitHub popularity | 1,504 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-04T19:03:22Z (UTC); not proof of skill-content freshness |
| License | MIT (original project text only); see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | Local skill created 2026-10-05. Normative reference is WCAG 2.2; upstream repository activity is tracked separately. |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Operational cashier UX, Khmer script and accessibility need a small local acceptance workflow rather than a generic style-generator database.

## Adaptation and scope

Local ergonomic/device scenarios and product decision boundaries. No copied WCAG/Flutter/NBC text, font, image, executable design search or final Khmer translation.

## Security review

Referenced normative WCAG and Flutter accessibility documentation; inspected W3C document-license restriction and avoided modifying/vendoring standard text. Distinguishes a local 48-logical-pixel goal from WCAG web criteria. Currency/language choices require evidence rather than cultural assumptions.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [Flutter accessibility](https://docs.flutter.dev/ui/accessibility)
- [Flutter internationalization](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)
- [NBC payment reference](https://bakong.nbc.gov.kh/en/download/KHQR/integration/QR%20Payment%20Integration.pdf)
