# Validation record — 2026-09-29

Local command: `npm test`

- Package references and execution-class/catalog/template parameter alignment: passed.
- APLO, SAJC and SAJT JSON: passed against saved SAP ABAP File Formats v1 schemas.
- 870 ABAP statements across the deployable sources: parsed without unknown statements.
- 16 policy ABAP unit tests: passed via the ABAP transpiler.
- 5 HTML ABAP unit tests: passed via the ABAP transpiler.
- `git diff --check`: passed (Git reported line-ending normalization warnings only).

Policy coverage includes actual current-step selection, exclusion of tasks from older workflow instances, next-step progression, future/review/rework exclusions, cancellation, final overall outcome, duplicate recipients, substitute recipients, rejection history, task-ID normalization and configurable approved result.

The tests execute the ABAP policy and HTML implementation, rather than a separate JavaScript copy of the business rules. The local harness supplies assertion/exception stubs and a two-decimal INR/blank currency fixture adapter because the runtime lacks SAP currency customizing. It does not exercise SAP CDS, journal concurrency, BCS commits/rollbacks, job logs or SMTP.

Not performed in this update: SAP import/activation, native ABAP Unit, ATC, authorization checks, actual workflow-result/agent verification, overlapping job execution, mail delivery or scheduling. Those are required acceptance steps in `ACCEPTANCE.md`. No Git commit/push and no real emails were sent.
