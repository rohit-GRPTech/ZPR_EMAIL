CLASS zcl_pr_email_policy DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS active IMPORTING iv_status TYPE c RETURNING VALUE(rv_active) TYPE abap_bool.
    CLASS-METHODS latest IMPORTING it_workflows TYPE zif_pr_email_types=>tt_workflows
      RETURNING VALUE(rs_workflow) TYPE zif_pr_email_types=>ty_workflow.
    CLASS-METHODS users IMPORTING it_recipients TYPE zif_pr_email_types=>tt_recipients
      RETURNING VALUE(rt_users) TYPE zif_pr_email_types=>tt_users.
    CLASS-METHODS outcome IMPORTING it_items TYPE zif_pr_email_types=>tt_items
      RETURNING VALUE(rv_event) TYPE zif_pr_email_types=>ty_event.
    CLASS-METHODS rejection_targets
      IMPORTING iv_workflow TYPE zif_pr_email_types=>ty_id
        it_items TYPE zif_pr_email_types=>tt_items
        it_tasks TYPE zif_pr_email_types=>tt_tasks
        it_definitions TYPE zif_pr_email_types=>tt_definitions
        it_participants TYPE zif_pr_email_types=>tt_participants
      RETURNING VALUE(rt_users) TYPE zif_pr_email_types=>tt_users.
ENDCLASS.

CLASS zcl_pr_email_policy IMPLEMENTATION.
  METHOD active.
    " WAITING is not an actionable task. Never notify planned/future steps.
    rv_active = xsdbool( iv_status = 'READY' OR iv_status = 'SELECTED' OR iv_status = 'STARTED' ).
  ENDMETHOD.
  METHOD latest.
    DATA(lt_workflows) = it_workflows.
    SORT lt_workflows BY created_at DESCENDING workflow_id DESCENDING.
    READ TABLE lt_workflows INDEX 1 INTO rs_workflow.
    " Keep a cancelled latest instance; do not fall back to an older instance.
  ENDMETHOD.
  METHOD users.
    LOOP AT it_recipients INTO DATA(ls_recipient) WHERE visible = abap_true.
      IF ls_recipient-user_id IS NOT INITIAL.
        " Recipient is the acting substitute; substituted_user is NOT the addressee.
        INSERT ls_recipient-user_id INTO TABLE rt_users.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD outcome.
    IF it_items IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_all_approved) = abap_true.
    DATA(lv_all_rejected) = abap_true.
    LOOP AT it_items INTO DATA(ls_item).
      IF ls_item-release_status <> '05'.
        lv_all_approved = abap_false.
      ENDIF.
      IF ls_item-release_status <> '08'.
        lv_all_rejected = abap_false.
      ENDIF.
    ENDLOOP.
    IF lv_all_approved = abap_true.
      rv_event = zif_pr_email_types=>approved.
    ELSEIF lv_all_rejected = abap_true.
      rv_event = zif_pr_email_types=>rejected.
    ENDIF.
  ENDMETHOD.
  METHOD rejection_targets.
    LOOP AT it_items INTO DATA(ls_item) WHERE creator IS NOT INITIAL.
      INSERT ls_item-creator INTO TABLE rt_users.
    ENDLOOP.
    IF it_definitions IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_tasks INTO DATA(ls_task) WHERE workflow_id = iv_workflow
        AND status = 'COMPLETED' AND result = 'RELEASED'
        AND definition IN it_definitions.
      IF ls_task-processor IS NOT INITIAL.
        INSERT ls_task-processor INTO TABLE rt_users.
      ENDIF.
      LOOP AT it_participants INTO DATA(ls_participant)
          WHERE workflow_id = iv_workflow AND task_id = ls_task-task_id
            AND user_id IS NOT INITIAL.
        INSERT ls_participant-user_id INTO TABLE rt_users.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

