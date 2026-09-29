# ZPR_EMAIL — overall PR workflow email notifications

Custom ABAP Cloud package for SAP S/4HANA Public Edition. The current source is prepared for SAP activation and integration testing; local checks are not production certification.

## Start here

1. Follow [activation and first PR test](docs/TEST-AFTER-CREATING-PR.md).
2. Activate the changed objects in your SAP package. Updating this directory does not update Eclipse or the SAP backend automatically.
3. Run `ZCL_PR_EMAIL_CHECK` using F9 after creating a PR. It shows the applied workflow, task status and current approver email addresses.
4. Run `ZCL_PR_EMAIL_TEST_RUN` for that one PR. It defaults to preview. Set `C_SEND = abap_true` only for your intended live test.
5. Configure and schedule the `ZPR_EMAIL` application job for automatic ongoing processing.

## Routing

`PR number -> applied workflow instances -> latest overall workflow -> current approval task(s) -> actual workflow recipients -> business-user workplace email`

The service reads the applied instance from `I_WorkflowStatusOverview`, matching the PR header key and scenario `02000458` (also accepting its `WS` prefix). It does not re-evaluate workflow start conditions or invent approvers from purchasing groups. All configured workflows under this scenario are supported through their runtime instances.

- An actionable first/next approval task sends to that task's current recipients only.
- Completed final approval sends to the configured purchasing mailbox only.
- Completed rejection sends to item creators and participants in earlier approved steps in the same workflow instance, deduplicated by SAP user ID.
- Review tasks, requester rework tasks, future WAITING tasks, and cancelled workflow instances do not produce approval emails.
- Latest-instance selection prevents notifications from superseded workflows. A cancelled latest instance does not fall back to an older one.
- The SAP-configured default sender is used. No sender address is hardcoded.
- Purchasing mailbox remains blank by default as requested. Final approval is held with an error until it is configured; the next run can retry it.
- Every message contains all current non-deleted PR items with material, description, quantity, price, currency, plant, purchasing and creator details.

Standard approval definitions `02000702` and `01800239` are used when `APPROVAL_TASKS` is blank. These identify approval task types, not a fixed business workflow or approver list. `01800239` is approval with a rework option; the separate requester rework task is excluded. An explicit override replaces these defaults and must contain eight-digit Include/Equals entries.

## Operational boundary

A local event **diagnostic probe** is available for PR `4900000120`.
Follow [the event test instructions](docs/TEST-LOCAL-PR-EVENTS.md) to activate it,
approve level 1 and compare persisted event observations with the next task.
It sends no emails. Intermediate-step event delivery and timing are not yet
verified; this probe does not replace the scheduled sender below.

This is a polling implementation, not a PR-save or workflow-step callback. Schedule it before the business process starts and choose a recurrence supported by your tenant. A step created and completed between polls can be missed. A rejection followed by workflow restart before the next poll can also be missed. Historical potential recipients no longer exposed by SAP and never observed by this job cannot be reconstructed. If every transient event and every historical potential recipient must be guaranteed, this polling design does not meet that requirement; a tenant-supported event integration and durable event history are needed.

`ZPR_EMAIL_LOG` prevents repeated queueing for the same PR/workflow/task/event/user. `Q` means registered with SAP's asynchronous mail API, not delivered. Delivery and SMTP retries must be checked in Monitor Email Transmissions. Do not delete Q rows or enable a resend until the SAP transmission status is reconciled. Two SAP users sharing a mailbox may each receive an email; deduplication is by user, not mailbox.

Each recipient is committed independently; a later recipient failure does not undo already queued messages. The standalone service owns commits/rollbacks and must not be called from a RAP save, BAdI or another business transaction. Failed jobs retain their application log. No emails are sent by local validation tools.

Use a fixed `FROM_DATE` and maintain scope so pending PRs do not age out. `MAX_PRS` defaults to 1000 and aborts before any sending when the selection exceeds the limit. Partition PR ranges or adjust capacity instead of sliding the start date. A long-lived full-history scope needs operational sizing; there is no background archival/cleanup job in this package.

`APPROVED_RESULT` defaults to the existing implementation's `RELEASED`. Confirm the actual `RESULT` of a completed approved task with the diagnostic class in your tenant. If it differs, set the observed approved result. This value affects rejection history; unknown results must not be guessed as approvals.

## Validation

Run `npm ci` then `npm test` for package consistency, SAP file-format schema validation, ABAP statement parsing, and transpiled ABAP policy/HTML tests. Test-only SAP class stubs live under `tests/runtime`; never import them into SAP. The JavaScript ABAP runtime does not implement SAP currency customizing, so the HTML tests use a two-decimal adapter restricted to their INR/blank fixtures. Actual currency formatting must be verified in SAP. Only `src` contains deployable repository objects. Run native ABAP Unit and ATC in ADT and complete [acceptance tests](docs/ACCEPTANCE.md) before production use. Local execution cannot verify your tenant's released APIs, CDS authorizations, transaction behavior, mail configuration or job scheduling.

## SAP references

- [Workflow scenarios and tasks](https://help.sap.com/docs/SAP_S4HANA_CLOUD/0e602d466b99490187fcbb30d1dc897c/a84badfeaf0445f4bed2a5c9bb0ed9c2.html?locale=he-IL&state=PRODUCTION&version=2608.500): standard approval, review and rework task IDs.
- [Workflow task CDS](https://help.sap.com/docs/SAP_S4HANA_CLOUD/c0c54048d35849128be8e872df5bea6d/5e0156c4a1b6498a83f5011c68e15153.html): runtime task status, result, processor and timestamps.
- [Workflow recipient CDS](https://help.sap.com/docs/SAP_S4HANA_CLOUD/c0c54048d35849128be8e872df5bea6d/329fa8bef9fc4766ba5ede291992ff45.html?locale=sk-SK&state=PRODUCTION&version=2608.500): actual recipient, substituted user and inbox visibility.
- [Asynchronous email API](https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/8d1f989deca1455dabc3d81b433fbdaf.html): COMMIT requirement and Monitor Email Transmissions.

No external paid email service is introduced. SAP licensing, tenant mail limits and delivery prerequisites still apply; this repository does not establish a zero-cost guarantee.
ZPR_EMAIL
