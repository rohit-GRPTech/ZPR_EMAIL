CLASS ltc_policy DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS excludes_waiting FOR TESTING.
    METHODS newest_cancelled_wins FOR TESTING.
    METHODS actual_substitute FOR TESTING.
    METHODS mixed_not_final FOR TESTING.
    METHODS approved_all_items FOR TESTING.
    METHODS rejected_all_items FOR TESTING.
    METHODS rejection_goes_back FOR TESTING.
    METHODS first_rejection_creator FOR TESTING.
    METHODS normalizes_task_ids FOR TESTING.
    METHODS defaults_exclude_review FOR TESTING.
    METHODS current_step_only FOR TESTING.
    METHODS next_step_after_approval FOR TESTING.
    METHODS completed_has_one_notice FOR TESTING.
    METHODS cancelled_no_notice FOR TESTING.
    METHODS empty_filter_no_notice FOR TESTING.
    METHODS alternate_approved_result FOR TESTING.
ENDCLASS.
CLASS ltc_policy IMPLEMENTATION.
  METHOD normalizes_task_ids.
    cl_abap_unit_assert=>assert_equals( exp = '02000702'
      act = zcl_pr_email_policy=>definition( 'TS02000702' ) ).
    cl_abap_unit_assert=>assert_equals( exp = '01800239'
      act = zcl_pr_email_policy=>definition( '01800239' ) ).
    cl_abap_unit_assert=>assert_initial( zcl_pr_email_policy=>definition( 'TS020007020' ) ).
    cl_abap_unit_assert=>assert_initial( zcl_pr_email_policy=>definition( 'WS02000458' ) ).
  ENDMETHOD.
  METHOD defaults_exclude_review.
    DATA(lt_definitions) = zcl_pr_email_policy=>default_definitions( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_definitions ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( xsdbool( '02000702' IN lt_definitions ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( '01800239' IN lt_definitions ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( '01800285' IN lt_definitions ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( '01800240' IN lt_definitions ) ).
  ENDMETHOD.
  METHOD current_step_only.
    DATA(lt_notices) = zcl_pr_email_policy=>notices(
      iv_pr = '0010000001'
      is_workflow = VALUE #( workflow_id = '000000000002' status = 'STARTED' )
      it_items = VALUE #( ( release_status = '04' ) )
      it_definitions = zcl_pr_email_policy=>default_definitions( )
      it_tasks = VALUE #(
        ( workflow_id = '000000000001' task_id = '000000000010' definition = '02000702' status = 'READY' )
        ( workflow_id = '000000000002' task_id = '000000000020' definition = '02000702' status = 'READY' )
        ( workflow_id = '000000000002' task_id = '000000000030' definition = '02000702' status = 'WAITING' )
        ( workflow_id = '000000000002' task_id = '000000000040' definition = '01800285' status = 'READY' )
        ( workflow_id = '000000000002' task_id = '000000000050' definition = '01800240' status = 'READY' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_notices ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_notices[ 1 ]-task_id exp = '000000000020' ).
  ENDMETHOD.
  METHOD next_step_after_approval.
    DATA(lt_notices) = zcl_pr_email_policy=>notices(
      iv_pr = '0010000001'
      is_workflow = VALUE #( workflow_id = '000000000002' status = 'STARTED' )
      it_items = VALUE #( ( release_status = '04' ) )
      it_definitions = zcl_pr_email_policy=>default_definitions( )
      it_tasks = VALUE #(
        ( workflow_id = '000000000002' task_id = '000000000020' definition = '02000702' status = 'COMPLETED' )
        ( workflow_id = '000000000002' task_id = '000000000030' definition = '01800239' status = 'READY' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_notices ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_notices[ 1 ]-task_id exp = '000000000030' ).
    cl_abap_unit_assert=>assert_equals( act = lt_notices[ 1 ]-event exp = zif_pr_email_types=>approval ).
  ENDMETHOD.
  METHOD completed_has_one_notice.
    DATA(lt_notices) = zcl_pr_email_policy=>notices(
      iv_pr = '0010000001'
      is_workflow = VALUE #( workflow_id = '000000000002' status = 'COMPLETED' )
      it_items = VALUE #( ( release_status = '05' ) ( release_status = '05' ) )
      it_definitions = zcl_pr_email_policy=>default_definitions( )
      it_tasks = VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_notices ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_notices[ 1 ]-event exp = zif_pr_email_types=>approved ).
    cl_abap_unit_assert=>assert_initial( lt_notices[ 1 ]-task_id ).
  ENDMETHOD.
  METHOD cancelled_no_notice.
    DATA(lt_notices) = zcl_pr_email_policy=>notices(
      iv_pr = '0010000001'
      is_workflow = VALUE #( workflow_id = '000000000002' status = 'CANCELLED' )
      it_items = VALUE #( ( release_status = '05' ) )
      it_definitions = zcl_pr_email_policy=>default_definitions( )
      it_tasks = VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( lt_notices ).
  ENDMETHOD.
  METHOD empty_filter_no_notice.
    DATA(lt_notices) = zcl_pr_email_policy=>notices(
      iv_pr = '0010000001'
      is_workflow = VALUE #( workflow_id = '000000000002' status = 'STARTED' )
      it_items = VALUE #( ( release_status = '04' ) )
      it_definitions = VALUE #( )
      it_tasks = VALUE #( ( workflow_id = '000000000002' task_id = '000000000020'
        definition = '01800285' status = 'READY' ) ) ).
    cl_abap_unit_assert=>assert_initial( lt_notices ).
  ENDMETHOD.
  METHOD alternate_approved_result.
    DATA(lt_users) = zcl_pr_email_policy=>rejection_targets(
      iv_workflow = '000000000002' iv_approved_result = 'TENANT_APPROVED'
      it_items = VALUE #( ( creator = 'CREATOR' ) )
      it_definitions = zcl_pr_email_policy=>default_definitions( )
      it_tasks = VALUE #( ( workflow_id = '000000000002' task_id = '000000000020'
        definition = '02000702' status = 'COMPLETED' result = 'TENANT_APPROVED' processor = 'APPROVER' ) )
      it_participants = VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_users ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_users[ table_line = 'APPROVER' ] ) ) ).
  ENDMETHOD.
  METHOD excludes_waiting.
    cl_abap_unit_assert=>assert_false( zcl_pr_email_policy=>active( 'WAITING' ) ).
    cl_abap_unit_assert=>assert_false( zcl_pr_email_policy=>active( 'COMPLETED' ) ).
    cl_abap_unit_assert=>assert_true( zcl_pr_email_policy=>active( 'READY' ) ).
    cl_abap_unit_assert=>assert_true( zcl_pr_email_policy=>active( 'SELECTED' ) ).
  ENDMETHOD.
  METHOD newest_cancelled_wins.
    DATA(ls_latest) = zcl_pr_email_policy=>latest( VALUE #(
      ( workflow_id = '000000000001' created_at = '20260928090000' status = 'READY' )
      ( workflow_id = '000000000002' created_at = '20260928100000' status = 'CANCELLED' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_latest-workflow_id exp = '000000000002' ).
    cl_abap_unit_assert=>assert_equals( act = ls_latest-status exp = 'CANCELLED' ).
  ENDMETHOD.
  METHOD actual_substitute.
    DATA(lt_users) = zcl_pr_email_policy=>users( VALUE #(
      ( user_id = 'SUBSTITUTE' substituted_user = 'ABSENT_USER' visible = abap_true )
      ( user_id = 'SUBSTITUTE' visible = abap_true )
      ( user_id = 'OLD_AGENT' visible = abap_false ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_users ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_users[ table_line = 'SUBSTITUTE' ] ) ) ).
  ENDMETHOD.
  METHOD mixed_not_final.
    cl_abap_unit_assert=>assert_initial( zcl_pr_email_policy=>outcome( VALUE #(
      ( item = '00010' release_status = '05' ) ( item = '00020' release_status = '04' ) ) ) ).
    cl_abap_unit_assert=>assert_initial( zcl_pr_email_policy=>outcome( VALUE #( ) ) ).
  ENDMETHOD.
  METHOD approved_all_items.
    cl_abap_unit_assert=>assert_equals( exp = zif_pr_email_types=>approved
      act = zcl_pr_email_policy=>outcome( VALUE #(
        ( item = '00010' release_status = '05' ) ( item = '00020' release_status = '05' ) ) ) ).
  ENDMETHOD.
  METHOD rejected_all_items.
    cl_abap_unit_assert=>assert_equals( exp = zif_pr_email_types=>rejected
      act = zcl_pr_email_policy=>outcome( VALUE #(
        ( item = '00010' release_status = '08' ) ( item = '00020' release_status = '08' ) ) ) ).
  ENDMETHOD.
  METHOD rejection_goes_back.
    DATA(lt_users) = zcl_pr_email_policy=>rejection_targets(
      iv_workflow = '000000000002'
      it_items = VALUE #( ( creator = 'CREATOR' ) ( creator = 'CREATOR' ) )
      it_definitions = VALUE #( ( sign = 'I' option = 'EQ' low = '00000001' ) )
      it_tasks = VALUE #(
        ( workflow_id = '000000000002' task_id = '000000000010' definition = '00000001'
          status = 'COMPLETED' result = 'RELEASED' processor = 'APPROVER1' )
        ( workflow_id = '000000000002' task_id = '000000000020' definition = '00000001'
          status = 'COMPLETED' result = 'REJECTED' processor = 'REJECTOR' )
        ( workflow_id = '000000000002' task_id = '000000000030' definition = '00000001'
          status = 'WAITING' processor = 'FUTURE' )
        ( workflow_id = '000000000001' task_id = '000000000010' definition = '00000001'
          status = 'COMPLETED' result = 'RELEASED' processor = 'OLD_INSTANCE' ) )
      it_participants = VALUE #(
        ( workflow_id = '000000000002' task_id = '000000000010' user_id = 'TEAMMATE' )
        ( workflow_id = '000000000002' task_id = '000000000020' user_id = 'REJECTOR' )
        ( workflow_id = '000000000001' task_id = '000000000010' user_id = 'OLD_INSTANCE' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_users ) exp = 3 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_users[ table_line = 'CREATOR' ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_users[ table_line = 'APPROVER1' ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_users[ table_line = 'TEAMMATE' ] ) ) ).
  ENDMETHOD.
  METHOD first_rejection_creator.
    DATA(lt_users) = zcl_pr_email_policy=>rejection_targets(
      iv_workflow = '000000000002'
      it_items = VALUE #( ( creator = 'CREATOR' ) )
      it_definitions = VALUE #( ( sign = 'I' option = 'EQ' low = '00000001' ) )
      it_tasks = VALUE #( ( workflow_id = '000000000002' definition = '00000001'
        task_id = '000000000020' status = 'COMPLETED' result = 'REJECTED' processor = 'REJECTOR' ) )
      it_participants = VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_users ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_users[ table_line = 'CREATOR' ] ) ) ).
  ENDMETHOD.
ENDCLASS.

