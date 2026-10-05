# Finding criteria

Adapted review criteria and local reporting rules; BSD-3-Clause.

Report each finding with severity, file/line, concrete trigger, impact, confidence and suggested correction or regression test. Severity reflects plausible impact and preconditions, not the number of alarming keywords.

- Critical/high: demonstrated privilege boundary failure, material payment/data integrity risk, credible credential exposure or an affected essential workflow that cannot complete.
- Medium: reproducible behavior/compatibility fault affecting a narrower path, or a materially unsafe migration/performance regression.
- Low: a concrete maintainability/accessibility defect with limited impact; do not elevate preference disagreements.

For payment code, distinguish failed transport from failed payment and identify whether a duplicate transaction can be applied. For Laravel input, trace the request through authorization, validation, persistence and serialization. For Flutter, inspect asynchronous state ownership and layout/state transitions, not just the screenshot.

Lead with findings. Then state checks performed and gaps. Do not include private values in examples or upload review artifacts to external services.
