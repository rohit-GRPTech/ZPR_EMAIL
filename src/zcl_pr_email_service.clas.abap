CLASS zcl_pr_email_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES tt_pr_range
      TYPE RANGE OF zif_pr_email_types=>ty_pr.

    TYPES tt_definitions
      TYPE zif_pr_email_types=>tt_definitions.

    TYPES:
      BEGIN OF ty_options,
        from_date        TYPE d,
        prs              TYPE tt_pr_range,
        approval_tasks   TYPE tt_definitions,
        dry_run          TYPE abap_bool,
        inbox_url        TYPE string,
        purchasing_email TYPE zif_pr_email_types=>ty_address,
        approved_result  TYPE zif_pr_email_types=>ty_result,
        max_prs          TYPE i,
      END OF ty_options,

      BEGIN OF ty_report,
        inspected TYPE i,
        queued    TYPE i,
        errors    TYPE i,
        previewed TYPE i,
        skipped   TYPE i,
        duplicate TYPE i,
        messages  TYPE zif_pr_email_types=>tt_messages,
      END OF ty_report.

    METHODS run
      IMPORTING
        is_options       TYPE ty_options
      RETURNING
        VALUE(rs_report) TYPE ty_report
      RAISING
        zcx_pr_email.

  PRIVATE SECTION.

    DATA options TYPE ty_options.
    DATA report  TYPE ty_report.

    METHODS process
      IMPORTING
        iv_pr TYPE zif_pr_email_types=>ty_pr
      RAISING
        zcx_pr_email.

    METHODS notify
      IMPORTING
        is_notice TYPE zif_pr_email_types=>ty_notice
        it_items  TYPE zif_pr_email_types=>tt_items
      RAISING
        zcx_pr_email.

    METHODS deliver
      IMPORTING
        is_notice  TYPE zif_pr_email_types=>ty_notice
        iv_user    TYPE zif_pr_email_types=>ty_user
        iv_html    TYPE string
        iv_address TYPE zif_pr_email_types=>ty_address OPTIONAL
      RAISING
        zcx_pr_email.

    METHODS still_current
      IMPORTING
        is_notice         TYPE zif_pr_email_types=>ty_notice
      RETURNING
        VALUE(rv_current) TYPE abap_bool.

    METHODS rejection_users
      IMPORTING
        is_notice       TYPE zif_pr_email_types=>ty_notice
        it_items        TYPE zif_pr_email_types=>tt_items
      RETURNING
        VALUE(rt_users) TYPE zif_pr_email_types=>tt_users.

ENDCLASS.


CLASS zcl_pr_email_service IMPLEMENTATION.

  METHOD run.

    CLEAR report.
    options = is_options.

    IF options-from_date IS INITIAL
       OR options-from_date > cl_abap_context_info=>get_system_date( ).

      RAISE EXCEPTION NEW zcx_pr_email(
        iv_detail = 'Set a valid, fixed PR creation start date (not a rolling lookback).'
      ).

    ENDIF.

    IF options-approval_tasks IS INITIAL.
      options-approval_tasks = zcl_pr_email_policy=>default_definitions( ).
    ENDIF.
    IF options-approved_result IS INITIAL.
      options-approved_result = 'RELEASED'.
    ENDIF.
    IF options-max_prs = 0.
      options-max_prs = 1000.
    ENDIF.
    IF options-max_prs < 1 OR options-max_prs > 100000.
      RAISE EXCEPTION NEW zcx_pr_email( iv_detail = 'MAX_PRS must be between 1 and 100000.' ).
    ENDIF.
    IF options-dry_run <> abap_true AND options-dry_run <> abap_false.
      RAISE EXCEPTION NEW zcx_pr_email( iv_detail = 'DRY_RUN must be X or blank.' ).
    ENDIF.

    LOOP AT options-approval_tasks INTO DATA(ls_definition).

      IF ls_definition-sign <> 'I'
         OR ls_definition-option <> 'EQ'
         OR ls_definition-low IS INITIAL
         OR ls_definition-low CN '0123456789'
         OR ls_definition-high IS NOT INITIAL.

        RAISE EXCEPTION NEW zcx_pr_email(
          iv_detail = 'Approval task definitions must be explicit Include/Equals entries.'
        ).

      ENDIF.

    ENDLOOP.

    IF options-purchasing_email IS NOT INITIAL.
      DATA(lv_purchasing_email) = CONV string( options-purchasing_email ).
      IF lv_purchasing_email NS '@' OR lv_purchasing_email CS space
          OR lv_purchasing_email CS ';' OR lv_purchasing_email CS ','.
        RAISE EXCEPTION NEW zcx_pr_email( iv_detail = 'Enter one valid purchasing mailbox, or leave it blank.' ).
      ENDIF.
    ENDIF.

    IF options-inbox_url IS NOT INITIAL
       AND options-inbox_url NP 'https://*'.

      RAISE EXCEPTION NEW zcx_pr_email(
        iv_detail = 'My Inbox URL must start with https://.'
      ).

    ENDIF.

    DATA(lv_limit) = options-max_prs + 1.
    SELECT DISTINCT PurchaseRequisition
      FROM I_PurchaseRequisitionItemAPI01
      WHERE CreationDate >= @options-from_date
        AND PurchaseRequisition IN @options-prs
        AND IsDeleted = @abap_false
      ORDER BY PurchaseRequisition
      INTO TABLE @DATA(lt_prs)
      UP TO @lv_limit ROWS.

    IF lines( lt_prs ) > options-max_prs.
      RAISE EXCEPTION NEW zcx_pr_email(
        iv_detail = 'PR scope exceeds MAX_PRS. Partition PR ranges or increase MAX_PRS; do not advance the fixed start date past pending PRs.' ).
    ENDIF.

    LOOP AT lt_prs INTO DATA(ls_pr).

      report-inspected += 1.

      TRY.

          process( ls_pr-PurchaseRequisition ).

        CATCH zcx_pr_email INTO DATA(lx_pr).

          report-errors += 1.

          APPEND
            |PR { ls_pr-PurchaseRequisition }: { lx_pr->detail }|
            TO report-messages.

        CATCH cx_root INTO DATA(lx_unexpected).
          ROLLBACK WORK.
          report-errors += 1.
          APPEND |PR { ls_pr-PurchaseRequisition }: { lx_unexpected->get_text( ) }|
            TO report-messages.

      ENDTRY.

    ENDLOOP.

    APPEND
      |PRs { report-inspected }; queued { report-queued }; preview { report-previewed }; duplicate { report-duplicate }; skipped { report-skipped }; errors { report-errors }|
      TO report-messages.

    rs_report = report.

  ENDMETHOD.


  METHOD process.

    DATA(lt_items) = zcl_pr_email_source=>items( iv_pr ).

    IF lt_items IS INITIAL.
      report-skipped += 1.
      RETURN.
    ENDIF.

    "Exclude PRs having an item created before the configured start date.
    LOOP AT lt_items INTO DATA(ls_item)
      WHERE creation_date < options-from_date.
      report-skipped += 1.
      RETURN.

    ENDLOOP.

    DATA(ls_notice) = VALUE zif_pr_email_types=>ty_notice(
      pr = iv_pr
    ).

    DATA(ls_workflow) = zcl_pr_email_policy=>latest(
      zcl_pr_email_source=>workflows( iv_pr )
    ).

    IF ls_workflow-workflow_id IS INITIAL.
      report-skipped += 1.
      APPEND |PR { iv_pr }: no applied overall workflow visible yet; checked again next run.|
        TO report-messages.
      RETURN.
    ENDIF.

    DATA(lt_tasks) = zcl_pr_email_source=>tasks( ls_workflow-workflow_id ).
    DATA(lt_notices) = zcl_pr_email_policy=>notices(
      iv_pr = iv_pr is_workflow = ls_workflow it_tasks = lt_tasks
      it_items = lt_items it_definitions = options-approval_tasks ).

    IF lt_notices IS INITIAL.
      report-skipped += 1.
      IF ls_workflow-status = 'COMPLETED'.
        RAISE EXCEPTION NEW zcx_pr_email(
          iv_detail = 'Completed overall workflow has no uniform approved/rejected item status; notification held.' ).
      ENDIF.
      APPEND |PR { iv_pr }: workflow { ls_workflow-workflow_id } / { ls_workflow-status }; no actionable approval task.|
        TO report-messages.
    ENDIF.
    LOOP AT lt_notices INTO ls_notice.
      notify( is_notice = ls_notice it_items = lt_items ).
    ENDLOOP.

  ENDMETHOD.


  METHOD notify.

    DATA lt_users TYPE zif_pr_email_types=>tt_users.

    IF is_notice-event = zif_pr_email_types=>approval.

      lt_users = zcl_pr_email_source=>recipients(
        is_notice
      ).

      IF lt_users IS INITIAL.

        RAISE EXCEPTION NEW zcx_pr_email(
          iv_detail = |Task { is_notice-task_id }: no visible recipients; notification held.|
        ).

      ENDIF.

    ELSEIF is_notice-event = zif_pr_email_types=>rejected.

      lt_users = rejection_users(
        is_notice = is_notice
        it_items  = it_items
      ).

      IF lt_users IS INITIAL.

        RAISE EXCEPTION NEW zcx_pr_email(
          iv_detail = 'Rejection: no creators or prior approval participants found.'
        ).

      ENDIF.

    ENDIF.

    DATA(lv_html) = zcl_pr_email_html=>render(
      is_notice = is_notice
      it_items  = it_items
      iv_inbox  = options-inbox_url
    ).

    IF is_notice-event = zif_pr_email_types=>approved.

      IF options-purchasing_email IS INITIAL.

        RAISE EXCEPTION NEW zcx_pr_email(
          iv_detail = 'Final approval: purchasing email is not configured. No email sent; retried next run.'
        ).

      ENDIF.

      deliver(
        is_notice  = is_notice
        iv_user    = '#PURCHASING'
        iv_html    = lv_html
        iv_address = options-purchasing_email
      ).

      RETURN.

    ENDIF.

    LOOP AT lt_users INTO DATA(lv_user).

      TRY.

          deliver(
            is_notice = is_notice
            iv_user   = lv_user
            iv_html   = lv_html
          ).

        CATCH zcx_pr_email INTO DATA(lx_recipient).

          report-errors += 1.

          APPEND
            |PR { is_notice-pr } / { is_notice-event } / { lv_user }: { lx_recipient->detail }|
            TO report-messages.

      ENDTRY.

    ENDLOOP.

  ENDMETHOD.


  METHOD rejection_users.

    DATA lt_participants TYPE zif_pr_email_types=>tt_participants.

    DATA(lt_tasks) = zcl_pr_email_source=>tasks(
      is_notice-workflow_id
    ).

    "Collect participants from approved steps in the same workflow.
    LOOP AT lt_tasks INTO DATA(ls_task)
      WHERE definition IN options-approval_tasks
        AND status = 'COMPLETED'
        AND result = options-approved_result.

      DATA(ls_prior_notice) = is_notice.
      ls_prior_notice-task_id = ls_task-task_id.

      DATA(lt_prior_users) = zcl_pr_email_source=>recipients(
        is_notice  = ls_prior_notice
        iv_history = abap_true
      ).

      LOOP AT lt_prior_users INTO DATA(lv_prior_user).

        APPEND VALUE #(
          workflow_id = is_notice-workflow_id
          task_id     = ls_task-task_id
          user_id     = lv_prior_user
        ) TO lt_participants.

      ENDLOOP.

      "Use the journal if completed-task recipient rows are unavailable.
      SELECT FROM zpr_email_log
        FIELDS user_id
        WHERE pr = @is_notice-pr
          AND workflow_id = @is_notice-workflow_id
          AND task_id = @ls_task-task_id
          AND event_type = 'APPROVAL'
        INTO TABLE @DATA(lt_logged_users).

      LOOP AT lt_logged_users INTO DATA(ls_logged_user)
        WHERE user_id IS NOT INITIAL.

        APPEND VALUE #(
          workflow_id = is_notice-workflow_id
          task_id     = ls_task-task_id
          user_id     = ls_logged_user-user_id
        ) TO lt_participants.

      ENDLOOP.

    ENDLOOP.

    rt_users = zcl_pr_email_policy=>rejection_targets(
      iv_workflow     = is_notice-workflow_id
      it_items        = it_items
      it_tasks        = lt_tasks
      it_definitions  = options-approval_tasks
      it_participants = lt_participants
      iv_approved_result = options-approved_result
    ).

  ENDMETHOD.


  METHOD still_current.

    rv_current = abap_false.

    DATA(ls_workflow) = zcl_pr_email_policy=>latest(
      zcl_pr_email_source=>workflows( is_notice-pr )
    ).

    IF ls_workflow-workflow_id <> is_notice-workflow_id.
      RETURN.
    ENDIF.

    DATA(lt_current) = zcl_pr_email_policy=>notices(
      iv_pr = is_notice-pr is_workflow = ls_workflow
      it_tasks = zcl_pr_email_source=>tasks( is_notice-workflow_id )
      it_items = zcl_pr_email_source=>items( is_notice-pr )
      it_definitions = options-approval_tasks ).
    rv_current = xsdbool( line_exists( lt_current[
      task_id = is_notice-task_id event = is_notice-event ] ) ).

  ENDMETHOD.


  METHOD deliver.

    DATA ls_log TYPE zpr_email_log.

    ls_log-pr          = is_notice-pr.
    ls_log-workflow_id = is_notice-workflow_id.
    ls_log-task_id     = is_notice-task_id.
    ls_log-event_type  = is_notice-event.
    ls_log-user_id     = iv_user.

    SELECT SINGLE FROM zpr_email_log
      FIELDS state
      WHERE pr = @ls_log-pr
        AND workflow_id = @ls_log-workflow_id
        AND task_id = @ls_log-task_id
        AND event_type = @ls_log-event_type
        AND user_id = @ls_log-user_id
      INTO @DATA(lv_state).

    IF sy-subrc = 0 AND lv_state <> 'E' AND options-dry_run = abap_false.
      report-duplicate += 1.
      RETURN.
    ENDIF.

    IF still_current( is_notice ) = abap_false.
      RETURN.
    ENDIF.

    "Recheck the actual recipients of the current approval task.
    IF is_notice-event = zif_pr_email_types=>approval.

      DATA(lt_current_users) = zcl_pr_email_source=>recipients(
        is_notice
      ).

      IF NOT line_exists(
        lt_current_users[ table_line = iv_user ]
      ).

        RETURN.

      ENDIF.

    ENDIF.

    IF options-dry_run = abap_true.

      DATA(lv_preview_address) = iv_address.

      IF lv_preview_address IS INITIAL.

        lv_preview_address = zcl_pr_email_source=>email(
          iv_user
        ).

      ENDIF.

      report-previewed += 1.
      APPEND
        |PREVIEW PR { is_notice-pr }, { is_notice-event }, task { is_notice-task_id }, user { iv_user }, email { lv_preview_address }|
        TO report-messages.

      RETURN.

    ENDIF.

    "Claim this notification using the unique journal key.
    "Commit only after registering the mail and updating its state.
    ls_log-state = 'P'.

    GET TIME STAMP FIELD ls_log-changed_at.

    IF lv_state = 'E'.

      UPDATE zpr_email_log
        SET state = 'P',
            changed_at = @ls_log-changed_at
        WHERE pr = @ls_log-pr
          AND workflow_id = @ls_log-workflow_id
          AND task_id = @ls_log-task_id
          AND event_type = @ls_log-event_type
          AND user_id = @ls_log-user_id
          AND state = 'E'.

    ELSE.

      INSERT zpr_email_log FROM @ls_log.

    ENDIF.

    IF sy-subrc <> 0.

      ROLLBACK WORK.
      RETURN.

    ENDIF.

    TRY.
        "The database claim may have waited for another run. Recheck afterwards.
        IF still_current( is_notice ) = abap_false.
          ROLLBACK WORK.
          RETURN.
        ENDIF.
        IF is_notice-event = zif_pr_email_types=>approval.
          lt_current_users = zcl_pr_email_source=>recipients( is_notice ).
          IF NOT line_exists( lt_current_users[ table_line = iv_user ] ).
            ROLLBACK WORK.
            RETURN.
          ENDIF.
        ENDIF.

        ls_log-email = iv_address.

        IF ls_log-email IS INITIAL.

          ls_log-email = zcl_pr_email_source=>email(
            iv_user
          ).

        ENDIF.

        DATA(lo_mail) = cl_bcs_mail_message=>create_instance( ).

        "Use the SAP-configured default sender.
        lo_mail->add_recipient(
          CONV #( ls_log-email )
        ).

        lo_mail->set_subject(
          CONV #( zcl_pr_email_html=>subject( is_notice ) )
        ).

        lo_mail->set_main(
          cl_bcs_mail_textpart=>create_text_html( iv_html )
        ).

        lo_mail->send_async( ).

        ls_log-state = 'Q'.
        ls_log-detail =
          'Queued with SAP mail API; verify delivery in Monitor Email Transmissions'.

        MODIFY zpr_email_log FROM @ls_log.

        COMMIT WORK AND WAIT.

        report-queued += 1.
        APPEND |QUEUED PR { is_notice-pr }, workflow { is_notice-workflow_id }, task { is_notice-task_id }, { is_notice-event }, { iv_user }, { ls_log-email }|
          TO report-messages.

      CATCH zcx_pr_email INTO DATA(lx_user).

        "Keep address-resolution failures available for retry.
        ls_log-state = 'E'.
        ls_log-detail = lx_user->detail.

        MODIFY zpr_email_log FROM @ls_log.

        COMMIT WORK AND WAIT.

        RAISE EXCEPTION lx_user.

      CATCH cx_bcs_mail INTO DATA(lx_mail).

        ROLLBACK WORK.

        RAISE EXCEPTION NEW zcx_pr_email(
          iv_detail = lx_mail->get_text( )
          previous  = lx_mail
        ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
