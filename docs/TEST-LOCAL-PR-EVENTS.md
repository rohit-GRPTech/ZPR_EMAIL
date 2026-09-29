# Test local PR events for 4900000120

This is a diagnostic probe, not the automatic email integration. It records only
PR `4900000120`, sends no mail, never calls the email service, and does not change
`ZPR_EMAIL_LOG`. It appends observations to the separate `ZPR_EMAIL_EVT` table.
No scheduled job or Event Mesh connection is used by this probe.

## Activate in Eclipse

Updating local files does not activate them in SAP. Activate these objects in
package `ZPR_EMAIL`, in this order:

1. Database table `ZPR_EMAIL_EVT` (`src/zpr_email_evt.tabl.xml` for abapGit).
2. Class `ZCL_PR_EMAIL_EVENT_CHECK` (Global Class source).
3. Class `ZCL_PR_EMAIL_EVENTS`: `.clas.abap` in Global Class and
   `.clas.locals_imp.abap` in **Local Types**. Activate both parts together.

For manual creation of the database table in ADT, use:

```abap
@EndUserText.label : 'PR event diagnostic observations'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zpr_email_evt {
  key client      : abap.clnt not null;
  key pr          : abap.char(10) not null;
  key observed_at : abap.dec(21,7) not null;
  key event_type  : abap.char(10) not null;
  key row_no      : abap.int4 not null;
  row_kind        : abap.char(10);
  workflow_id     : abap.numc(12);
  task_id         : abap.numc(12);
  status          : abap.char(12);
  definition      : abap.char(8);
  result          : abap.char(32);
  user_id         : abap.char(12);
  detail          : abap.char(255);
}
```

The behavior interface must expose the four events and be released for local
consumption (C1) in this tenant. Report any activation/release-contract errors;
do not modify SAP's behavior definition or bypass release checks.

## Run the two-step approval test

1. Confirm PR `4900000120` still has its first approval pending in Approval Details.
   If it has already advanced, it cannot prove the earlier transition: use a new
   two-step PR and change `TEST_PR` in `ZCL_PR_EMAIL_EVENT_CHECK` before testing.
2. Execute `ZCL_PR_EMAIL_EVENT_CHECK` with F9. Save the output. The **LIVE SNAPSHOT**
   shows the current task and recipients. The persisted observations can be empty.
3. Approve **only level 1** in My Inbox. Note the action time and the second
   approver shown in Approval Details. Avoid unrelated PR edits during the test.
4. After SAP finishes asynchronous processing, run the check again. If necessary,
   allow a short time and rerun manually; this is not scheduling a job.
5. Send the before/after output for inspection. Leave level 2 pending until the
   intermediate transition is checked. Final approval and rejection can then be
   tested separately with appropriate business test documents.

This PR already existed before the handler was installed. Its old Created event
and old approvals are not replayed by this probe. Test creation using a fresh PR
after adjusting the filter, if creation coverage is required.

## Interpret the output

- Persisted `SIGNAL`: the local handler ran for that named header event.
- `WORKFLOW`: the latest matching overall workflow visible when the handler ran.
- `TASK`: all visible tasks of that workflow, including statuses/results.
- `CANDIDATE`: a notification identified by the existing email policy.
- `RECIPIENT`: an actual current recipient of an actionable approval candidate.
- `ERROR`: the handler ran, but a snapshot read failed; inspect DETAIL.
- **LIVE SNAPSHOT / MANUAL** is an on-demand read only. It is not persisted and
  never proves that SAP emitted an event.

A new event observation after level 1, containing the level-2 actionable task and
correct RECIPIENT, supports using that event for this transition in this tenant.
It is evidence for this test, not a guarantee for all workflow variants.
An event with only the old task, or no next task, exposes a timing problem that
must be resolved before email integration. A live snapshot showing level 2 while
event observations do not show it does not pass the automatic-trigger test.

No logged event is inconclusive until handler activation, API release, background
event processing, authorizations and runtime errors have been checked. A controlled
PR edit can serve as a Changed-event positive control if suitable for the business
test; note its time separately because an edit may restart a workflow.

Observations contain handler timestamps in UTC, not producer timestamps. Delivery
can be asynchronous or repeated. The probe is append-only and does not claim
exactly-once event capture; a database error is left visible to runtime monitoring.
The viewer limits output to the latest 500 rows; table data preview shows older rows.

The service still owns explicit commits/rollbacks. Do not call it from this handler
until its transaction model and durable retry handling have been adapted.

## Basis and verification boundary

The handler follows SAP's local event consumption pattern: `FOR EVENTS OF`, a local
subclass of `CL_ABAP_BEHAVIOR_EVENT_HANDLER`, and `CL_ABAP_TX=>SAVE()` before direct
database writes. The framework completes the transaction; no explicit commit is
issued in the handler.

- [SAP local business event consumption](https://help.sap.com/docs/abap-cloud/abap-rap/business-event-consumption)
- [SAP exercise: local event handler and database log](https://github.com/SAP-samples/teched2025-AD164/blob/main/exercises/ex07/README.md)

Local parsing/tests cannot verify tenant event delivery, API contracts, CDS read
permissions in the handler's execution context, or workflow timing. Those require
activation and this SAP integration test. No emails or SAP changes are made by
running the repository's Node validation tools.
