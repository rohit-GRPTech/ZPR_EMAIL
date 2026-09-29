# Activate and test a newly created PR

## 1. Update the existing SAP package

The files in `D:\SAP-Repositories\ZPR_EMAIL\src` are local source. Copy the changed sources into the matching ADT objects, or use your established import process. No Git push or SAP deployment was performed by this update.

Activate in this order:

1. `ZIF_PR_EMAIL_TYPES` — expanded task diagnostics and result type.
2. `ZCX_PR_EMAIL`, `ZI_PR_EMAIL_USER`, `ZPR_EMAIL_LOG` — existing dependencies; retain journal data.
3. `ZCL_PR_EMAIL_POLICY` and its Test Classes source — defaults, normalization and routing.
4. `ZCL_PR_EMAIL_SOURCE` — reads the workflow actually applied to each PR, its tasks and recipients.
5. `ZCL_PR_EMAIL_HTML` and its Test Classes source.
6. `ZCL_PR_EMAIL_SERVICE` — selects PRs and queues one notification per event/task/user.
7. Application Log Object `ZPR_EMAIL`: ensure subobject `DISPATCH` exists. The exported legacy subobject is preserved but unused by this job.
8. `ZCL_PR_EMAIL_JOB` — includes new parameters `APPROVED_RESULT` and `MAX_PRS`.
9. Application Job Catalog Entry `ZPR_EMAIL`: synchronize parameters with the execution class, then apply the settings in `zpr_email.sajc.json`. `APPROVAL_TASKS` is now optional; `DRY_RUN` is a checkbox.
10. Application Job Template `ZPR_EMAIL`: defaults in `zpr_email.sajt.json`. Keep `DRY_RUN = X` initially.
11. `ZCL_PR_EMAIL_PREVIEW`, `ZCL_PR_EMAIL_CHECK`, and the new class `ZCL_PR_EMAIL_TEST_RUN`.

For `.clas.testclasses.abap`, use the class's Test Classes tab. For form-based APLO/SAJC/SAJT editors, reproduce the JSON fields using the form. Existing scheduled jobs may retain old parameter values; review/recreate their schedule after the catalog/template changes.

Run ABAP Unit on policy and HTML classes and run the relevant ABAP Cloud ATC checks. Resolve activation or release-contract errors before sending.

## 2. Create a real test PR

Use at least two items with material descriptions, quantities, currencies and values representative of your business. Ensure an overall flexible workflow with at least two approvers applies. Wait until Approval Details/My Inbox shows the first approver task.

In `ZCL_PR_EMAIL_CHECK`, press F9. With `C_PR` blank, it inspects up to 20 PRs created on the SAP system date, in descending PR number order. To inspect a specific or older PR, set `C_PR` to that PR number and activate again.

Check:

- An applied workflow instance is returned and the latest selected ID matches the workflow history.
- Its task IDs and active recipients match My Inbox, including substitution/forwarding where used.
- `DEFINITION` is normalized to eight digits, and `STEP_TYPE` identifies the expected approval step.
- Each recipient resolves to one workplace email address. Fix missing or ambiguous business-user email data before sending.

No workflow means either it has not started yet, no supported overall workflow applied, or data/authorization does not match. The job retries on later runs; it does not manufacture an approver.

## 3. Preview and send for one PR

Open `ZCL_PR_EMAIL_TEST_RUN`:

```abap
CONSTANTS c_pr TYPE zif_pr_email_types=>ty_pr VALUE 'YOUR_PR'.
CONSTANTS c_send TYPE abap_bool VALUE abap_false.
```

Replace `YOUR_PR` with the actual numeric PR (maximum ten characters). Leading zeros are added by the runner. Activate and press F9. The report should include `PREVIEW` with the current task, user and email; the journal is not modified.

For the live single-PR test, change `C_SEND` to `abap_true`, activate and press F9. This sends real notification requests to the actual workflow recipients. Check `QUEUED` in the output and delivery in Monitor Email Transmissions. The HTML-only sample class does not test SMTP.

Run again before approval: queued count should be zero and duplicate count should increase. Approve step 1 in My Inbox, wait for the next task to appear, then run again. Only current step 2 recipients should receive the new notification.

After the first completed approval, inspect `RESULT` in `ZCL_PR_EMAIL_CHECK`. Confirm `RELEASED` or update `C_APPROVED_RESULT` / the job's `APPROVED_RESULT` to the exact observed approved result. Do this before testing rejection history.

For final approval, populate `C_PURCHASING_EMAIL` with the configured test purchasing mailbox. With this value blank, final notification is deliberately held and reported as an error. Configure the mailbox and rerun to release the held notification.

On a second test PR, approve step 1 and reject step 2. Run the service after the overall workflow completes. Verify the creator(s) and prior approved-step participants receive the rejection email, with all current items. Future approvers must not receive it.

## 4. Enable automatic processing after PR creation

In Application Jobs, schedule template `ZPR_EMAIL` with:

| Parameter | Value |
| --- | --- |
| FROM_DATE | Fixed rollout/test start date; do not use a moving date |
| PRS | Initially the one test PR; later the intended PR ranges |
| APPROVAL_TASKS | Blank for standard overall approval task defaults |
| APPROVED_RESULT | Verified approved-task RESULT; default RELEASED |
| MAX_PRS | 1000 initially; adjust scope/capacity if exceeded |
| DRY_RUN | X for preview; unchecked for actual emails |
| INBOX_URL | Optional tenant HTTPS My Inbox URL |
| PURCHASING_EMAIL | Configured final-approval mailbox; blank holds final mail |

Use a recurrence your tenant supports. Select an execution user authorized to read the entire intended PR scope. Verify SAP outbound mail configuration/default sender and allowed recipient domains. Schedule before creating the next test PR and leave each step pending until the poll has processed it.

The job is periodic; PR creation does not directly invoke this class. For predictable acceptance testing, a manual F9 invocation or immediate single application-job run provides the processing trigger. Check job application logs and Monitor Email Transmissions after each step.
