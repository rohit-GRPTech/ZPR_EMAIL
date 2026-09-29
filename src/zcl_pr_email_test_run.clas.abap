CLASS zcl_pr_email_test_run DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pr_email_test_run IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    "Set only your test PR. False previews; true queues real emails.
    CONSTANTS c_pr TYPE zif_pr_email_types=>ty_pr VALUE ''.
    CONSTANTS c_send TYPE abap_bool VALUE abap_false.
    CONSTANTS c_purchasing_email TYPE zif_pr_email_types=>ty_address VALUE ''.
    CONSTANTS c_inbox_url TYPE string VALUE ''.
    "Confirm RESULT for an approved task in ZCL_PR_EMAIL_CHECK.
    CONSTANTS c_approved_result TYPE zif_pr_email_types=>ty_result VALUE 'RELEASED'.
    IF c_pr IS INITIAL.
      out->write( 'Set C_PR to the newly created test PR, activate, then press F9 again.' ).
      RETURN.
    ENDIF.
    DATA lv_pr TYPE zif_pr_email_types=>ty_pr.
    lv_pr = |{ c_pr ALPHA = IN }|.
    TRY.
        DATA(lt_items) = zcl_pr_email_source=>items( lv_pr ).
        IF lt_items IS INITIAL.
          out->write( 'No items visible for this PR. Check number and authorization.' ).
          RETURN.
        ENDIF.
        SORT lt_items BY creation_date.
        DATA(ls_options) = VALUE zcl_pr_email_service=>ty_options(
          from_date = lt_items[ 1 ]-creation_date
          prs = VALUE #( ( sign = 'I' option = 'EQ' low = lv_pr ) )
          dry_run = xsdbool( c_send = abap_false )
          inbox_url = c_inbox_url purchasing_email = c_purchasing_email
          approved_result = c_approved_result max_prs = 1 ).
        DATA(ls_report) = NEW zcl_pr_email_service( )->run( ls_options ).
        out->write( ls_report ).
        IF c_send = abap_true.
          out->write( 'Q means queued, not delivered. Check Monitor Email Transmissions.' ).
        ELSE.
          out->write( 'Preview only. No email sent and no journal rows written.' ).
        ENDIF.
      CATCH zcx_pr_email INTO DATA(lx_service).
        out->write( lx_service->detail ).
      CATCH cx_root INTO DATA(lx_unexpected).
        ROLLBACK WORK.
        out->write( lx_unexpected->get_text( ) ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
