INTERFACE zif_pr_email_types PUBLIC.
  TYPES ty_pr TYPE c LENGTH 10.
  TYPES ty_user TYPE c LENGTH 12.
  TYPES ty_id TYPE n LENGTH 12.
  TYPES ty_event TYPE c LENGTH 10.
  TYPES ty_address TYPE c LENGTH 241.
  TYPES ty_amount TYPE p LENGTH 16 DECIMALS 2.
  TYPES ty_timestamp TYPE p LENGTH 11 DECIMALS 7.
  TYPES tt_users TYPE SORTED TABLE OF ty_user WITH UNIQUE KEY table_line.
  TYPES ty_definition TYPE c LENGTH 8.
  TYPES tt_definitions TYPE RANGE OF ty_definition.
  TYPES:
    BEGIN OF ty_item,
      pr TYPE ty_pr,
      item TYPE n LENGTH 5,
      material TYPE c LENGTH 40,
      description TYPE c LENGTH 80,
      material_group TYPE c LENGTH 9,
      quantity TYPE decfloat34,
      unit TYPE c LENGTH 3,
      price TYPE ty_amount,
      price_unit TYPE decfloat34,
      currency TYPE c LENGTH 5,
      plant TYPE c LENGTH 4,
      storage_location TYPE c LENGTH 4,
      purchasing_group TYPE c LENGTH 3,
      purchasing_org TYPE c LENGTH 4,
      account_category TYPE c LENGTH 1,
      delivery_date TYPE d,
      creation_date TYPE d,
      creator TYPE ty_user,
      release_status TYPE c LENGTH 2,
    END OF ty_item,
    tt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY,
    BEGIN OF ty_workflow,
      workflow_id TYPE ty_id,
      scenario TYPE c LENGTH 8,
      status TYPE c LENGTH 12,
      created_at TYPE ty_timestamp,
    END OF ty_workflow,
    tt_workflows TYPE STANDARD TABLE OF ty_workflow WITH EMPTY KEY,
    BEGIN OF ty_task,
      workflow_id TYPE ty_id,
      task_id TYPE ty_id,
      definition TYPE c LENGTH 8,
      status TYPE c LENGTH 12,
      result TYPE c LENGTH 32,
      processor TYPE ty_user,
    END OF ty_task,
    tt_tasks TYPE STANDARD TABLE OF ty_task WITH EMPTY KEY,
    BEGIN OF ty_recipient,
      user_id TYPE ty_user,
      substituted_user TYPE ty_user,
      visible TYPE abap_bool,
    END OF ty_recipient,
    tt_recipients TYPE STANDARD TABLE OF ty_recipient WITH EMPTY KEY,
    BEGIN OF ty_participant,
      workflow_id TYPE ty_id,
      task_id TYPE ty_id,
      user_id TYPE ty_user,
    END OF ty_participant,
    tt_participants TYPE STANDARD TABLE OF ty_participant WITH EMPTY KEY,
    BEGIN OF ty_notice,
      pr TYPE ty_pr,
      workflow_id TYPE ty_id,
      task_id TYPE ty_id,
      event TYPE ty_event,
    END OF ty_notice,
    tt_notices TYPE STANDARD TABLE OF ty_notice WITH EMPTY KEY,
    tt_messages TYPE STANDARD TABLE OF string WITH EMPTY KEY.
  CONSTANTS approval TYPE ty_event VALUE 'APPROVAL'.
  CONSTANTS approved TYPE ty_event VALUE 'APPROVED'.
  CONSTANTS rejected TYPE ty_event VALUE 'REJECTED'.
ENDINTERFACE.
