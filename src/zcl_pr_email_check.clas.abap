CLASS zcl_pr_email_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pr_email_check IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    "Blank: inspect up to 20 PRs created today. Or enter one PR here.
    CONSTANTS c_pr TYPE zif_pr_email_types=>ty_pr VALUE ''.
    DATA lt_prs TYPE zcl_pr_email_service=>tt_pr_range.
    DATA(lv_from_date) = cl_abap_context_info=>get_system_date( ).
    IF c_pr IS NOT INITIAL.
      lv_from_date = '00010101'.
      lt_prs = VALUE #( ( sign = 'I' option = 'EQ' low = |{ c_pr ALPHA = IN }| ) ).
    ENDIF.
    SELECT DISTINCT PurchaseRequisition
      FROM I_PurchaseRequisitionItemAPI01
      WHERE CreationDate >= @lv_from_date
        AND PurchaseRequisition IN @lt_prs
        AND IsDeleted = @abap_false
      ORDER BY PurchaseRequisition DESCENDING
      INTO TABLE @DATA(lt_prs_found)
      UP TO 20 ROWS.
    out->write( 'READ ONLY: no email sent; no journal updated.' ).
    IF lt_prs_found IS INITIAL.
      out->write( 'No matching PR visible. Check the date, PR number and read authorizations.' ).
    ENDIF.
    LOOP AT lt_prs_found INTO DATA(ls_pr).
      TRY.
          out->write( |PR { ls_pr-PurchaseRequisition }| ).
          DATA(lt_items) = zcl_pr_email_source=>items( ls_pr-PurchaseRequisition ).
          out->write( lt_items ).
          DATA(lt_workflows) = zcl_pr_email_source=>workflows( ls_pr-PurchaseRequisition ).
          out->write( 'Applied overall workflow instances:' ).
          out->write( lt_workflows ).
          "Diagnostic only: mirror the tracking report's six-key search,
          "but show the scenario and actual keys. Never use these candidates
          "as email routing authority without verifying the PR object mapping.
          DATA lv_pr_padded TYPE zif_pr_email_types=>ty_pr.
          lv_pr_padded = |{ ls_pr-PurchaseRequisition ALPHA = IN }|.
          DATA(lv_pr_unpadded) = |{ lv_pr_padded ALPHA = OUT }|.
          CONDENSE lv_pr_unpadded NO-GAPS.
          SELECT FROM I_WorkflowStatusOverview
            FIELDS WorkflowInternalID AS workflow_id,
              WorkflowScenarioDefinition AS scenario,
              WorkflowExternalStatus AS status,
              WrkflwTskCreationUTCDateTime AS created_at,
              SAPBusinessObjectNodeKey1 AS key1,
              SAPBusinessObjectNodeKey2 AS key2,
              SAPBusinessObjectNodeKey3 AS key3,
              SAPBusinessObjectNodeKey4 AS key4,
              SAPBusinessObjectNodeKey5 AS key5,
              SAPBusinessObjectNodeKey6 AS key6
            WHERE SAPBusinessObjectNodeKey1 = @lv_pr_padded
               OR SAPBusinessObjectNodeKey1 = @lv_pr_unpadded
               OR SAPBusinessObjectNodeKey2 = @lv_pr_padded
               OR SAPBusinessObjectNodeKey2 = @lv_pr_unpadded
               OR SAPBusinessObjectNodeKey3 = @lv_pr_padded
               OR SAPBusinessObjectNodeKey3 = @lv_pr_unpadded
               OR SAPBusinessObjectNodeKey4 = @lv_pr_padded
               OR SAPBusinessObjectNodeKey4 = @lv_pr_unpadded
               OR SAPBusinessObjectNodeKey5 = @lv_pr_padded
               OR SAPBusinessObjectNodeKey5 = @lv_pr_unpadded
               OR SAPBusinessObjectNodeKey6 = @lv_pr_padded
               OR SAPBusinessObjectNodeKey6 = @lv_pr_unpadded
            ORDER BY WrkflwTskCreationUTCDateTime DESCENDING,
              WorkflowInternalID DESCENDING
            INTO TABLE @DATA(lt_candidates)
            UP TO 50 ROWS.
          out->write( 'DIAGNOSTIC: up to 50 exact number matches across all six object keys and all scenarios.' ).
          out->write( 'A number match alone does not prove this is a PR workflow. Check scenario and all keys.' ).
          out->write( lt_candidates ).
          IF lt_candidates IS INITIAL.
            out->write( 'No exact key match in any scenario. The tracking report may be displaying an unrelated workflow.' ).
          ENDIF.
          DATA(ls_workflow) = zcl_pr_email_policy=>latest( lt_workflows ).
          IF ls_workflow-workflow_id IS INITIAL.
            out->write( 'No overall workflow visible yet. Retry after workflow creation.' ).
            CONTINUE.
          ENDIF.
          out->write( 'Latest instance selected; older instances are not used:' ).
          out->write( ls_workflow ).
          DATA(lt_tasks) = zcl_pr_email_source=>tasks( ls_workflow-workflow_id ).
          out->write( 'All tasks: compare definition, step type, status, result and processor with Approval Details.' ).
          out->write( lt_tasks ).
          DATA(lt_notices) = zcl_pr_email_policy=>notices(
            iv_pr = ls_pr-PurchaseRequisition is_workflow = ls_workflow
            it_tasks = lt_tasks it_items = lt_items
            it_definitions = zcl_pr_email_policy=>default_definitions( ) ).
          out->write( 'Notification candidates using SAP standard approval tasks:' ).
          out->write( lt_notices ).
          LOOP AT lt_notices INTO DATA(ls_notice)
              WHERE event = zif_pr_email_types=>approval.
            DATA(lt_users) = zcl_pr_email_source=>recipients( ls_notice ).
            out->write( |Current recipients of task { ls_notice-task_id }:| ).
            out->write( lt_users ).
            LOOP AT lt_users INTO DATA(lv_user).
              TRY.
                  DATA(lv_email) = zcl_pr_email_source=>email( lv_user ).
                  out->write( |{ lv_user }: { lv_email }| ).
                CATCH zcx_pr_email INTO DATA(lx_user).
                  out->write( lx_user->detail ).
              ENDTRY.
            ENDLOOP.
          ENDLOOP.
        CATCH cx_root INTO DATA(lx_error).
          out->write( lx_error->get_text( ) ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
