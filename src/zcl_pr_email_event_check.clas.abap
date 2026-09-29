CLASS zcl_pr_email_event_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    CONSTANTS test_pr TYPE zif_pr_email_types=>ty_pr VALUE '4900000120'.
    TYPES tt_probe TYPE STANDARD TABLE OF zpr_email_evt WITH EMPTY KEY.
    CLASS-METHODS snapshot
      IMPORTING iv_pr TYPE zif_pr_email_types=>ty_pr
                iv_event TYPE zpr_email_evt-event_type
      RETURNING VALUE(rt_rows) TYPE tt_probe.
ENDCLASS.

CLASS zcl_pr_email_event_check IMPLEMENTATION.
  METHOD snapshot.
    "This helper only reads SAP data. The event handler persists its result.
    CHECK iv_pr = test_pr.
    DATA ls_row TYPE zpr_email_evt.
    ls_row-pr = iv_pr.
    ls_row-event_type = iv_event.
    GET TIME STAMP FIELD ls_row-observed_at.
    ls_row-row_no = 1.
    ls_row-row_kind = 'SIGNAL'.
    ls_row-detail = 'Observed by probe; timestamp is handler time, not event creation time.'.
    APPEND ls_row TO rt_rows.
    TRY.
        DATA(ls_workflow) = zcl_pr_email_policy=>latest(
          zcl_pr_email_source=>workflows( iv_pr ) ).
        ls_row-workflow_id = ls_workflow-workflow_id.
        ls_row-status = ls_workflow-status.
        ls_row-row_no += 1.
        ls_row-row_kind = 'WORKFLOW'.
        ls_row-detail = 'Latest matching overall workflow at observation time.'.
        IF ls_workflow-workflow_id IS INITIAL.
          ls_row-detail = 'No applied overall workflow visible at observation time.'.
          APPEND ls_row TO rt_rows.
          RETURN.
        ENDIF.
        APPEND ls_row TO rt_rows.
        DATA(lt_tasks) = zcl_pr_email_source=>tasks( ls_workflow-workflow_id ).
        LOOP AT lt_tasks INTO DATA(ls_task).
          ls_row-row_no += 1.
          ls_row-row_kind = 'TASK'.
          ls_row-task_id = ls_task-task_id.
          ls_row-status = ls_task-status.
          ls_row-definition = ls_task-definition.
          ls_row-result = ls_task-result.
          ls_row-user_id = ls_task-processor.
          ls_row-detail = ls_task-step_type.
          APPEND ls_row TO rt_rows.
        ENDLOOP.
        CLEAR: ls_row-task_id, ls_row-status, ls_row-definition,
               ls_row-result, ls_row-user_id, ls_row-detail.
        DATA(lt_notices) = zcl_pr_email_policy=>notices(
          iv_pr = iv_pr is_workflow = ls_workflow it_tasks = lt_tasks
          it_items = zcl_pr_email_source=>items( iv_pr )
          it_definitions = zcl_pr_email_policy=>default_definitions( ) ).
        LOOP AT lt_notices INTO DATA(ls_notice).
          ls_row-row_no += 1.
          ls_row-row_kind = 'CANDIDATE'.
          ls_row-task_id = ls_notice-task_id.
          CLEAR ls_row-user_id.
          ls_row-detail = ls_notice-event.
          APPEND ls_row TO rt_rows.
          IF ls_notice-event = zif_pr_email_types=>approval.
            DATA(lt_users) = zcl_pr_email_source=>recipients( ls_notice ).
            LOOP AT lt_users INTO DATA(lv_user).
              ls_row-row_no += 1.
              ls_row-row_kind = 'RECIPIENT'.
              ls_row-user_id = lv_user.
              ls_row-detail = 'Actual current approval recipient; no email sent.'.
              APPEND ls_row TO rt_rows.
            ENDLOOP.
          ENDIF.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        ls_row-row_no += 1.
        ls_row-row_kind = 'ERROR'.
        ls_row-detail = lx_error->get_text( ).
        APPEND ls_row TO rt_rows.
    ENDTRY.
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    out->write( |PR { test_pr }: event diagnostic only; no email or dispatch-journal update.| ).
    SELECT FROM zpr_email_evt FIELDS *
      WHERE pr = @test_pr
      ORDER BY observed_at DESCENDING, event_type, row_no
      INTO TABLE @DATA(lt_events)
      UP TO 500 ROWS.
    out->write( 'PERSISTED EVENT OBSERVATIONS (latest 500 rows; UTC):' ).
    out->write( lt_events ).
    IF lt_events IS INITIAL.
      out->write( 'No event recorded. This alone does not prove SAP raised no event.' ).
      out->write( 'Confirm handler activation, API release, asynchronous processing and errors.' ).
    ENDIF.
    out->write( 'LIVE SNAPSHOT NOW (read only; does not prove an event was raised):' ).
    out->write( snapshot( iv_pr = test_pr iv_event = 'MANUAL' ) ).
    out->write( 'Compare the new TASK/RECIPIENT rows with Approval Details after approving level 1.' ).
    out->write( 'Only persisted event rows demonstrate that this handler actually ran.' ).
  ENDMETHOD.
ENDCLASS.
