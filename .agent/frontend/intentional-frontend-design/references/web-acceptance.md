# Web acceptance checks

Adapted design guidance with project-specific acceptance checks; Apache-2.0.

Check the actual primary task with keyboard only; open/close a dialog and confirm focus returns to the initiating control. Confirm errors identify the affected field and the next action, rather than showing a generic failure toast only. Check navigation semantics, headings, accessible names and native controls before adding ARIA.

At a narrow viewport and with zoom, preserve the ability to inspect totals, reach the primary action and recover from errors. Make table overflow deliberate and accessible rather than clipping controls. Never render untrusted catalog text as raw HTML.

Prefer existing components. New component abstractions should remove real duplication without hiding state or accessibility behavior. Identify unresolved product decisions rather than inventing discount, currency or payment rules.
