CLASS zcl_pr_email_source DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS items
      IMPORTING
        iv_pr           TYPE zif_pr_email_types=>ty_pr
      RETURNING
        VALUE(rt_items) TYPE zif_pr_email_types=>tt_items.

    CLASS-METHODS workflows
      IMPORTING
        iv_pr               TYPE zif_pr_email_types=>ty_pr
      RETURNING
        VALUE(rt_workflows) TYPE zif_pr_email_types=>tt_workflows.

    CLASS-METHODS tasks
      IMPORTING
        iv_workflow     TYPE zif_pr_email_types=>ty_id
      RETURNING
        VALUE(rt_tasks) TYPE zif_pr_email_types=>tt_tasks.

    CLASS-METHODS recipients
      IMPORTING
        is_notice       TYPE zif_pr_email_types=>ty_notice
        iv_history      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_users) TYPE zif_pr_email_types=>tt_users.

    CLASS-METHODS email
      IMPORTING
        iv_user         TYPE zif_pr_email_types=>ty_user
      RETURNING
        VALUE(rv_email) TYPE zif_pr_email_types=>ty_address
      RAISING
        zcx_pr_email.

ENDCLASS.


CLASS zcl_pr_email_source IMPLEMENTATION.

  METHOD items.

    SELECT FROM I_PurchaseRequisitionItemAPI01
      FIELDS
        PurchaseRequisition         AS pr,
        PurchaseRequisitionItem     AS item,
        Material                    AS material,
        PurchaseRequisitionItemText AS description,
        MaterialGroup               AS material_group,
        RequestedQuantity           AS quantity,
        BaseUnit                    AS unit,
        PurchaseRequisitionPrice    AS price,
        PurReqnPriceQuantity         AS price_unit,
        PurReqnItemCurrency          AS currency,
        Plant                       AS plant,
        StorageLocation             AS storage_location,
        PurchasingGroup             AS purchasing_group,
        PurchasingOrganization      AS purchasing_org,
        AccountAssignmentCategory   AS account_category,
        DeliveryDate                AS delivery_date,
        CreationDate                AS creation_date,
        CreatedByUser               AS creator,
        PurReqnReleaseStatus         AS release_status
      WHERE PurchaseRequisition = @iv_pr
        AND IsDeleted = @abap_false
      ORDER BY PurchaseRequisitionItem
      INTO TABLE @DATA(lt_items).

    rt_items = CORRESPONDING #( lt_items ).

  ENDMETHOD.


  METHOD workflows.

    "Match the overall PR scenario and the exact header key.
    DATA(lv_unpadded) = |{ iv_pr ALPHA = OUT }|.

    SELECT FROM I_WorkflowStatusOverview
      FIELDS
        WorkflowInternalID         AS workflow_id,
        WorkflowScenarioDefinition AS scenario,
        WorkflowExternalStatus     AS status,
        WrkflwTskCreationUTCDateTime AS created_at
      WHERE WorkflowScenarioDefinition = '02000458'
        AND ( SAPBusinessObjectNodeKey1 = @iv_pr
           OR SAPBusinessObjectNodeKey1 = @lv_unpadded )
        AND SAPBusinessObjectNodeKey2 = ''
      INTO CORRESPONDING FIELDS OF TABLE @rt_workflows.

  ENDMETHOD.


  METHOD tasks.

    SELECT FROM I_WorkflowStatusDetails
      FIELDS
        WorkflowInternalID         AS workflow_id,
        WorkflowTaskInternalID     AS task_id,
        WorkflowTaskDefinition     AS definition,
        WorkflowTaskExternalStatus AS status,
        WorkflowTaskResult         AS result,
        WorkflowTaskProcessor      AS processor
      WHERE WorkflowInternalID = @iv_workflow
      INTO CORRESPONDING FIELDS OF TABLE @rt_tasks.

  ENDMETHOD.


  METHOD recipients.

    DATA lt_recipients TYPE zif_pr_email_types=>tt_recipients.

    SELECT FROM I_WorkflowRecipients_V2
      FIELDS
        WorkflowTaskRecipient        AS user_id,
        WorkflowTaskSubstitutedUser   AS substituted_user,
        WorkflowTaskIsVisibleInInbox AS visible
      WHERE WorkflowInternalID = @is_notice-workflow_id
        AND WorkflowTaskInternalID = @is_notice-task_id
      INTO CORRESPONDING FIELDS OF TABLE @lt_recipients.

    IF iv_history = abap_true.

      "Include available historical recipient rows.
      LOOP AT lt_recipients ASSIGNING FIELD-SYMBOL(<recipient>).
        <recipient>-visible = abap_true.
      ENDLOOP.

    ENDIF.

    rt_users = zcl_pr_email_policy=>users( lt_recipients ).

  ENDMETHOD.


  METHOD email.

    SELECT FROM ZI_PR_Email_User
      FIELDS EmailAddress AS email
      WHERE UserID = @iv_user
      INTO TABLE @DATA(lt_addresses).

    DELETE lt_addresses WHERE email IS INITIAL.

    SORT lt_addresses BY email.

    DELETE ADJACENT DUPLICATES FROM lt_addresses
      COMPARING email.

    IF lines( lt_addresses ) <> 1.

      RAISE EXCEPTION NEW zcx_pr_email(
        iv_detail = |User { iv_user }: expected one workplace email address|
      ).

    ENDIF.

    rv_email = lt_addresses[ 1 ]-email.

    DATA(lv_address) = CONV string( rv_email ).

    IF lv_address NS '@' OR lv_address CS space.

      RAISE EXCEPTION NEW zcx_pr_email(
        iv_detail = |User { iv_user }: invalid workplace email address|
      ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
