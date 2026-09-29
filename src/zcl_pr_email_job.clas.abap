CLASS zcl_pr_email_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_apj_rt_run.

    "! <p class="shorttext synchronized" lang="en">Fixed PR creation start date</p>
    DATA from_date TYPE d.

    "! <p class="shorttext synchronized" lang="en">Purchase requisitions (optional scope)</p>
    DATA prs TYPE zcl_pr_email_service=>tt_pr_range.

    "! <p class="shorttext synchronized" lang="en">Approval tasks override (blank = SAP defaults)</p>
    DATA approval_tasks TYPE zcl_pr_email_service=>tt_definitions.

    "! <p class="shorttext synchronized" lang="en">Approved task result for rejection history</p>
    DATA approved_result TYPE zif_pr_email_types=>ty_result VALUE 'RELEASED'.

    "! <p class="shorttext synchronized" lang="en">Maximum PRs in configured scope</p>
    DATA max_prs TYPE i VALUE 1000.

    "! <p class="shorttext synchronized" lang="en">Preview only - do not send or update journal</p>
    DATA dry_run TYPE abap_bool VALUE abap_true.

    "! <p class="shorttext synchronized" lang="en">HTTPS URL of SAP My Inbox</p>
    DATA inbox_url TYPE c LENGTH 255.

    "! <p class="shorttext synchronized" lang="en">Purchasing email - final approval only</p>
    DATA purchasing_email TYPE zif_pr_email_types=>ty_address.

ENDCLASS.


CLASS zcl_pr_email_job IMPLEMENTATION.

  METHOD if_apj_rt_run~execute.

    DATA ls_report TYPE zcl_pr_email_service=>ty_report.

    TRY.

        ls_report = NEW zcl_pr_email_service( )->run(
          VALUE #(
            from_date        = from_date
            prs              = prs
            approval_tasks   = approval_tasks
            dry_run          = dry_run
            inbox_url        = CONV string( inbox_url )
            purchasing_email = purchasing_email
            approved_result  = approved_result
            max_prs          = max_prs
          )
        ).

      CATCH zcx_pr_email INTO DATA(lx_error).

        ls_report-errors = 1.

        APPEND lx_error->detail
          TO ls_report-messages.

    ENDTRY.

    TRY.

        DATA(lo_log) = cl_bali_log=>create_with_header(
          cl_bali_header_setter=>create(
            object    = 'ZPR_EMAIL'
            subobject = 'DISPATCH'
          )
        ).

        LOOP AT ls_report-messages INTO DATA(lv_message).
          "BALI free text is bounded. Preserve long addresses/error details.
          DATA(lv_remaining) = lv_message.
          WHILE lv_remaining IS NOT INITIAL.
            DATA(lv_length) = nmin( val1 = strlen( lv_remaining ) val2 = 200 ).
            lo_log->add_item(
              cl_bali_free_text_setter=>create(
                severity = COND #(
                  WHEN ls_report-errors > 0
                  THEN if_bali_constants=>c_severity_error
                  ELSE if_bali_constants=>c_severity_information
                )
                text = CONV #( lv_remaining(lv_length) )
              )
            ).
            lv_remaining = substring( val = lv_remaining off = lv_length ).
          ENDWHILE.
        ENDLOOP.

        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection(
          log                        = lo_log
          assign_to_current_appl_job = abap_true
        ).

      CATCH cx_bali_runtime INTO DATA(lx_log).

        RAISE EXCEPTION TYPE cx_apj_rt_content
          EXPORTING
            previous = lx_log.

    ENDTRY.

    "Do not report a successful job when any recipient/PR failed.
    IF ls_report-errors > 0.
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
