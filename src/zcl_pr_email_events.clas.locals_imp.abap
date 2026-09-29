"Diagnostic only. Restricted by TEST_PR in ZCL_PR_EMAIL_EVENT_CHECK.
"Framework owns commit; do not call the standalone email service here.
CLASS lhe_pr_probe DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    METHODS on_created FOR ENTITY EVENT instances FOR PurchaseRequisition~Created.
    METHODS on_changed FOR ENTITY EVENT instances FOR PurchaseRequisition~Changed.
    METHODS on_approved FOR ENTITY EVENT instances FOR PurchaseRequisition~Approved.
    METHODS on_rejected FOR ENTITY EVENT instances FOR PurchaseRequisition~Rejected.
    METHODS persist IMPORTING it_rows TYPE zcl_pr_email_event_check=>tt_probe.
ENDCLASS.

CLASS lhe_pr_probe IMPLEMENTATION.
  METHOD on_created.
    DATA lt_rows TYPE zcl_pr_email_event_check=>tt_probe.
    LOOP AT instances INTO DATA(ls_instance).
      APPEND LINES OF zcl_pr_email_event_check=>snapshot(
        iv_pr = ls_instance-PurchaseRequisition iv_event = 'CREATED' ) TO lt_rows.
    ENDLOOP.
    persist( lt_rows ).
  ENDMETHOD.
  METHOD on_changed.
    DATA lt_rows TYPE zcl_pr_email_event_check=>tt_probe.
    LOOP AT instances INTO DATA(ls_instance).
      APPEND LINES OF zcl_pr_email_event_check=>snapshot(
        iv_pr = ls_instance-PurchaseRequisition iv_event = 'CHANGED' ) TO lt_rows.
    ENDLOOP.
    persist( lt_rows ).
  ENDMETHOD.
  METHOD on_approved.
    DATA lt_rows TYPE zcl_pr_email_event_check=>tt_probe.
    LOOP AT instances INTO DATA(ls_instance).
      APPEND LINES OF zcl_pr_email_event_check=>snapshot(
        iv_pr = ls_instance-PurchaseRequisition iv_event = 'APPROVED' ) TO lt_rows.
    ENDLOOP.
    persist( lt_rows ).
  ENDMETHOD.
  METHOD on_rejected.
    DATA lt_rows TYPE zcl_pr_email_event_check=>tt_probe.
    LOOP AT instances INTO DATA(ls_instance).
      APPEND LINES OF zcl_pr_email_event_check=>snapshot(
        iv_pr = ls_instance-PurchaseRequisition iv_event = 'REJECTED' ) TO lt_rows.
    ENDLOOP.
    persist( lt_rows ).
  ENDMETHOD.
  METHOD persist.
    CHECK it_rows IS NOT INITIAL.
    "Required before direct database writes in the controlled RAP LUW.
    cl_abap_tx=>save( ).
    "Append only; persistence errors must remain visible to event monitoring.
    INSERT zpr_email_evt FROM TABLE @it_rows.
  ENDMETHOD.
ENDCLASS.
