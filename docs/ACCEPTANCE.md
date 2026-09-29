# SAP integration acceptance — must run in the tenant

These checks are not marked as passed by local tests. Use a test tenant and intended test recipients.

| Case | Expected result |
| --- | --- |
| Two different configured overall workflows selected by different PRs | Each PR follows its own runtime workflow instance and actual agents |
| Newly created PR; first task READY | Only current first approvers receive all non-deleted items |
| Step 1 completed; step 2 READY | Only step 2 recipients receive a new approval email |
| Review/rework tasks READY alongside approval | Review/requester-rework users receive no approval notification |
| Future task WAITING | No email until actionable |
| Duplicate run / two overlapping runs | One queued request per PR/workflow/task/event/user; reconcile BCS and journal |
| Recipient substitution or forwarding | Current visible recipients are used; the substituted original is not added automatically |
| Workflow restart | Latest instance is selected; no pending mail from an older instance |
| Latest workflow cancelled | No fallback to an older completed workflow |
| Final approval | One notification to configured purchasing address only |
| Purchasing mailbox blank | Final mail held, clear error logged, job error status; retry succeeds once configured |
| Rejection at first step | Creators receive rejection; no future approvers |
| Rejection after prior approval | Creators + earlier approved-step processor/available historical recipients/journal participants |
| Approved task result differs from RELEASED | Set APPROVED_RESULT from observed history; prior approvers included |
| Mixed release statuses or unfinished workflow | No false final approval/rejection |
| User has no/ambiguous email | Per-recipient error, no guessed address; other recipients continue |
| Repaired user email | Retry queues the previously failed recipient only |
| Mail registration failure | Transaction rolls back; error in job log; later run can retry |
| SMTP delivery failure after Q | Monitor Email Transmissions handles investigation/retry; no automatic duplicate from the job |
| Scope larger than MAX_PRS | Job fails before sending; no silent partial processing |
| Fixed rollout date, older pending PR | Remains selected across future runs |
| HTML injection characters and zero price unit | Escaped table content; no divide-by-zero |
| Multi-currency and non-two-decimal currency | Verify currency formatting against actual SAP displayed values |
| Restricted job user | Verify intended PR scope is fully visible; missing authorization is not bypassed |

Record PR numbers, workflow/task IDs, job run IDs, transmission status and received recipient lists in your test evidence. Do not share sensitive PR details outside approved systems.

## Known design limits

Polling cannot guarantee transient-step or transient-rejection delivery. Historical potential recipients are only as complete as SAP history plus the journal observed by this service. Actual processors can cover approved tasks completed between polls, but cannot recover all vanished potential recipients. Current data is rendered, not an immutable item snapshot at the exact approval instant. This package intentionally does not implement automatic journal deletion, resend after delivery failure, or an event callback.
