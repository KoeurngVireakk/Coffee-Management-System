# License scope

The existing root [MIT license](../../LICENSE) is preserved. This collection has multiple per-skill licenses; it is not uniformly relicensed as MIT.

| Material | Applicable license / notice |
| --- | --- |
| Frontend design adaptation | [Anthropic Apache-2.0](anthropic-apache-2.0.txt) |
| Flutter architecture/layout, code-review and widget-test adaptations | [Flutter BSD-3-Clause](flutter-bsd-3-clause.txt), copyright 2026 The Flutter Authors |
| Laravel Boost adaptation | [Laravel MIT](laravel-boost-mit.txt), copyright Taylor Otwell |
| API/payment security adaptation | [OpenAI Apache-2.0](openai-apache-2.0.txt) |
| Independently authored project skills, index, routing and research records | Root MIT license |

License files are copied verbatim from the inspected upstream revision. Each adapted `SKILL.md` identifies that it was modified and its README describes the changes. Keep those notices and source records when redistributing. Apache-2.0 and BSD-3-Clause material retains its own terms alongside the project's MIT material; do not remove notices because the application has an MIT root license. No upstream trademark endorsement is implied.

Anthropic's repository-wide third-party notice was inspected. It lists fonts/libraries belonging to other artifacts; no such asset, library or executable is included here. No source-specific NOTICE file was found for the selected frontend or OpenAI threat-model skill. If future imports include additional components, review their own notices rather than assuming these records cover them.

## Reference-only sources

- OWASP API Security/Cheat Sheet content is CC-BY-SA-4.0. Links and independently authored control checks are included; their manuals/text are not vendored. Any later textual adaptation needs attribution, change identification and the applicable share-alike license rather than a blanket MIT label.
- W3C WCAG documents have their own document-license constraints. No normative text is modified or repackaged as a local standard.
- Flutter website prose is generally CC-BY-4.0 and samples BSD-3-Clause; the copied adaptations come from the separately BSD-licensed agent-plugins repository. Website pages are references only.
- GitHub documentation is CC-BY-4.0; these original Git/CI skills link to it without copying page text.
- MySQL server has GPLv2 and third-party terms, while Oracle manuals have separate documentation terms. Neither server code nor manual text is copied into these original database instructions.
- NBC/Bakong PDFs have copyright notices and no redistribution license verified here. They remain external references; no PDF or SDK is included.
- Vercel's reviewed README declares MIT, but the inspected repository tree has no full license/NOTICE file. No Vercel skill text is copied; redistribution is deferred pending complete license evidence.

These boundaries apply to the documents in this collection. They do not install or change the licenses of runtime dependencies in either application. Reassess the exact material and license before every future import.
