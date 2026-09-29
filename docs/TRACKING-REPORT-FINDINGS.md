# PR tracking report comparison

Inspected `ZMM_PR_RPT/src/zcl_mm_pr_rpt_query.clas.abap`, especially the workflow reads around line 303 and pending-person selection around lines 353–402.

The report reads workflow overview, task and recipient data without restricting the scenario. It compares the padded/unpadded PR number with any of six object key fields, then attempts to find a pending task. It prefers an assigned processor; otherwise it takes the first recipient row and prefers its substituted user over its actual recipient. Business-user data supplies the display name.

The email service currently matches scenario `02000458` (or its WS prefix), exact PR key 1, and blank key 2. This difference could explain a match in the report and no match in the email service, but the tenant's actual key/scenario data is required before changing sending behavior.

## Why the report cannot establish the correct approver by itself

- There is no scenario/business-object check; another document can share the same number.
- There is no latest-instance ordering; first match can be an older workflow.
- After `LOOP AT lt_wf_overview`, `sy-subrc = 0` means at least one row was processed, not that the IF condition matched. If no key matches but the overview table has rows, the assigned field symbol is left on the last workflow and the report may use its tasks.
- WAITING tasks are included with actionable tasks.
- Review/requester-rework tasks are not distinguished from approval tasks.
- Only one task and one recipient are displayed; multiple actual recipients are lost.
- A substituted user identifies the person being substituted, not necessarily the current acting recipient. The report does not filter inbox visibility.

The report itself was not modified. Email sending rules were not broadened to all workflows.

## Next tenant check

Activate the updated `ZCL_PR_EMAIL_CHECK`, set `C_PR` to `5000000020`, then execute F9. The new DIAGNOSTIC table shows up to 50 exact number matches with workflow ID, scenario, status, creation timestamp and KEY1–KEY6. Compare these with the PR's Approval Details. This distinguishes a wrong assumed key/scenario from a false match in the tracking report.

Once the actual PR scenario/key mapping is confirmed, adjust the service's source filter and approval task definitions to that supported mapping. Do not route emails using arbitrary number matches or the last row of a workflow table.
