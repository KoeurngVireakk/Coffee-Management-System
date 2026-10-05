---
name: intentional-frontend-design
description: Design or review a custom HTML/CSS/web interface when explicitly requested, with deliberate visual choices and usable interaction states. For Flutter screens use the Flutter and POS skills instead.
license: Apache-2.0
---

# Intentional frontend design

Adapted from Anthropic's frontend-design skill; scope and workflow changed for this monorepo. See [provenance](README.md) and [license](../../licenses/anthropic-apache-2.0.txt).

Establish the audience, main task and existing brand before choosing a visual direction. Inspect the actual frontend stack; do not add React, a dashboard app or a design system when the request is for Flutter.

For an authorized custom web surface:

- Use the real domain content and a compact set of type, spacing and color decisions. Prioritize cashier speed and legibility over novelty; follow supplied references and existing components.
- Keep rendering separate from persistence and authorization. Account for loading, empty, permission-denied, validation and network-error states.
- Use semantic controls, labeled forms, visible keyboard focus and predictable focus return. Preserve entered values after errors and offer clear recovery actions.
- Build from available width, test zoom and keyboard use, and respect reduced motion. Use text alongside status colors. Do not add decorative motion that delays a transaction.
- Validate the rendered result at narrow and wide widths. Report concrete interaction defects and the evidence for changes; screenshots supplement behavior checks.

Read [web acceptance checks](references/web-acceptance.md) when validating forms or responsive interaction. Do not expand this workflow into a Flutter redesign or business-feature implementation unless requested.
