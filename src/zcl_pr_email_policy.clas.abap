CLASS zcl_pr_email_policy DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS default_definitions
      RETURNING VALUE(rt_definitions) TYPE zif_pr_email_types=>tt_definitions.
    CLASS-METHODS definition IMPORTING iv_definition TYPE string
      RETURNING VALUE(rv_definition) TYPE zif_pr_email_types=>ty_definition.
    CLASS-METHODS notices
      IMPORTING iv_pr TYPE zif_pr_email_types=>ty_pr
        is_workflow TYPE zif_pr_email_types=>ty_workflow
        it_tasks TYPE zif_pr_email_types=>tt_tasks
        it_items TYPE zif_pr_email_types=>tt_items
        it_definitions TYPE zif_pr_email_types=>tt_definitions
      RETURNING VALUE(rt_notices) TYPE zif_pr_email_types=>tt_notices.
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
        iv_approved_result TYPE zif_pr_email_types=>ty_result DEFAULT 'RELEASED'
      RETURNING VALUE(rt_users) TYPE zif_pr_email_types=>tt_users.
ENDCLASS.

CLASS zcl_pr_email_policy IMPLEMENTATION.
  METHOD default_definitions.
    "SAP standard overall PR approval; review and requester rework excluded.
    rt_definitions = VALUE #(
      ( sign = 'I' option = 'EQ' low = '02000702' )
      ( sign = 'I' option = 'EQ' low = '01800239' ) ).
  ENDMETHOD.
  METHOD definition.
    DATA(lv_definition) = iv_definition.
    CONDENSE lv_definition NO-GAPS.
    TRANSLATE lv_definition TO UPPER CASE.
    IF strlen( lv_definition ) = 10 AND lv_definition(2) = 'TS'.
      lv_definition = lv_definition+2.
    ENDIF.
    IF strlen( lv_definition ) = 8 AND lv_definition CO '0123456789'.
      rv_definition = lv_definition.
    ENDIF.
  ENDMETHOD.
  METHOD notices.
    IF is_workflow-workflow_id IS INITIAL OR it_items IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_notice) = VALUE zif_pr_email_types=>ty_notice(
      pr = iv_pr workflow_id = is_workflow-workflow_id ).
    IF active( is_workflow-status ) = abap_true.
      "An empty ABAP range matches everything; never allow that here.
      IF it_definitions IS INITIAL.
        RETURN.
      ENDIF.
      LOOP AT it_tasks INTO DATA(ls_task)
          WHERE workflow_id = is_workflow-workflow_id
            AND definition IN it_definitions.
        IF ls_task-task_id IS INITIAL OR active( ls_task-status ) = abap_false.
          CONTINUE.
        ENDIF.
        ls_notice-task_id = ls_task-task_id.
        ls_notice-event = zif_pr_email_types=>approval.
        APPEND ls_notice TO rt_notices.
      ENDLOOP.
      SORT rt_notices BY task_id.
      DELETE ADJACENT DUPLICATES FROM rt_notices COMPARING task_id.
    ELSEIF is_workflow-status = 'COMPLETED'.
      ls_notice-event = outcome( it_items ).
      IF ls_notice-event IS NOT INITIAL.
        APPEND ls_notice TO rt_notices.
      ENDIF.
    ENDIF.
  ENDMETHOD.
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
        AND status = 'COMPLETED' AND result = iv_approved_result
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

