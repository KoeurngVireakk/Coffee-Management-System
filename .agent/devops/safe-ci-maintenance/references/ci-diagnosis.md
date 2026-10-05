# CI diagnosis

Original workflow. The scaffold has backend and mobile jobs; inspect the current file before relying on this summary.

Backend gates validate Composer, PHP formatting, migrations on isolated MySQL, and bootstrap tests. Mobile gates install locked packages, check Dart formatting, analyze, test, and build web/debug Android targets. A failure may expose drift between local tools and the runner rather than an application defect.

Locate the first meaningful error, verify the job's working directory and environment, and reproduce only its relevant command. If network retrieval failed, document that distinction; do not rewrite the app to hide a transient package download failure. Never paste unredacted job logs or request broad token scopes just to diagnose a local reproduction.

Use existing authorized read-only GitHub access when available. If authentication is absent, analyze local configuration and request only the missing access needed for the remote portion. Do not add a hook or installer to enable log retrieval.

Report the cause, changed configuration, local evidence and remaining remote/platform gaps. YAML parsing alone does not prove a workflow works on GitHub.
