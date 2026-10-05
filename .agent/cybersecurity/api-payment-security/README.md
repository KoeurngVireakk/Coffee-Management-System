# API and payment security - provenance

| Field | Record |
| --- | --- |
| Name | `api-payment-security` |
| Category | Cybersecurity / API Security / OWASP / Secure Coding / KHQR |
| Origin | Adapted upstream threat-model workflow with local domain checks |
| Author / organization | OpenAI; adapted by Coffee Management System maintainers. Reference authors: OWASP and National Bank of Cambodia |
| Source repository | [openai/skills](https://github.com/openai/skills) |
| GitHub popularity | 27,881 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-09-08T20:35:26Z (UTC); not proof of skill-content freshness |
| License | Apache-2.0; see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | 2026-02-02: threat-model workflow added; stable source in an active repository. Local adaptation created 2026-10-05. |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Language-neutral, evidence-based threat modeling fits PHP/Dart better than OpenAI's language-limited security-best-practices skill; local API/KHQR checks address the highest-impact boundaries.

## Adaptation and scope

Removed Codex-specific reference/output dependencies and unconditional user-confirmation pause. Added bounded passive review, OWASP-linked endpoint checks and provider-neutral payment invariants without assuming signed callbacks or current endpoints.

## Security review

Reviewed full source Markdown and Apache license. No security scripts, scanner, live tests, ownership-map dependencies or credentials imported. OWASP share-alike pages and NBC copyrighted PDFs are link-only; local domain checks are newly authored technical guidance, not copied excerpts.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [Upstream `skills/.curated/security-threat-model/SKILL.md`](https://github.com/openai/skills/blob/49f948faa9258a0c61caceaf225e179651397431/skills/.curated/security-threat-model/SKILL.md)
- [OWASP API Top 10 (2023)](https://api-security.owasp.org/editions/2023/en/0x11-t10/)
- [OWASP REST security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html)
- [OWASP authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP secrets management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [NBC QR payment integration](https://bakong.nbc.gov.kh/en/download/KHQR/integration/QR%20Payment%20Integration.pdf)
- [NBC KHQR implementation guide](https://bakong.nbc.gov.kh/en/download/KHQR%20SDK.pdf)
