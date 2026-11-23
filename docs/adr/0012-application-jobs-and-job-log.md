# 12. Nightly checks run as application jobs and report to the application log

Status: accepted, 2026-11-23

## Context

Two checks should run every night without anybody opening an app (FR-IM-05):

- Which purchased materials are below their reorder point? Purchasing needs a requisition before the stock runs out.
- Which batches expire within the next 14 days, or have expired with stock left? They should be sold or used first, or scrapped.

The result must be traceable: what the job found, what it created and what failed.

In S/4HANA this is done with application jobs (Fiori app Application Jobs) and the application log (Fiori app Application Logs). Both rest on released APIs in ABAP Cloud. On the BTP trial, however, users get no business roles, so neither Fiori app can be opened. Reading the application log through `CL_BALI_LOG_DB` also needs authorization object `S_APPL_LOG`, which only a business role grants. The log is written, but cannot be read back on the trial.

## Decision

- **Jobs.** Each check is a class with `IF_APJ_DT_EXEC_OBJECT` (parameters) and `IF_APJ_RT_EXEC_OBJECT` (run):
  - `ZCL_VHB_REORDER_JOB` with catalog entry `ZVHB_REORDER` and template `ZVHB_REORDER_BR01`. Parameters: plant (mandatory) and test run.
  - `ZCL_VHB_BATCH_EXPIRY_JOB` with catalog entry `ZVHB_BATCH_EXPIRY` and template `ZVHB_BATCH_EXPIRY_BR01`. Parameters: plant and days ahead (14).

  Both classes also implement `IF_OO_ADT_CLASSRUN`, so the same run can be started with F9.
- **Reorder rule.**
  - Only active materials that are bought, not brewed (not FERT), with a reorder point in the plant are checked.
  - Free, unexpired stock below the reorder point is topped up to twice the reorder point.
  - The requisition is created through the requisition business object, with the same checks as in the app. Delivery date is today plus 7 days, storage location RM01, or LE01 for empties.
  - A material with an open requisition (New or Approved) or an open purchase order is only reported, so the job never orders twice.
- **Expiry rule.** A batch with stock and a best-before date within the horizon is a warning. A batch already expired with stock left is an error.
- **Scheduling.** `ZCL_VHB_SCHEDULE_JOBS` starts both templates with the released API `CL_APJ_RT_API`, which is also used by the Fiori app Application Jobs. The class waits for the status and prints it.
- **Log.**
  - Every run writes one application log (object `ZVHB_LOG`, subobjects `REORDER` and `BATCH_EXPIRY`, external ID = plant) and assigns it to the running job.
  - `ZCL_VHB_APP_LOG` also stores each message in table `ZVHB_LOGMSG`.
  - The custom entity `ZVHB_C_JobLog` reads that table for the app `ZVHB_UI_JOBLOG_O4` (Job Logs): time, job, plant, severity and text of the last 30 days.

## Consequences

- With a business role, the standard apps show the same jobs and logs. The Job Logs app and the scheduler class are only needed where the roles are missing.
- The message texts in `ZVHB_LOGMSG` are stored in the language of the run. The application log itself keeps the message number and variables and can be shown in any language.
- `save` of the log now commits. It may only be called at the end of a job or console run, not inside a RAP transaction.
- The reorder quantity ignores lot sizes, open sales demand and supplier lead times. A material requirements planning run is out of scope.
- Catalog entries and templates are repository objects and travel with abapGit. A catalog entry can only be created and activated when its class compiles, so after a pull the business objects must be active first.
