CLASS zcl_pr_email_html DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS render IMPORTING is_notice TYPE zif_pr_email_types=>ty_notice
      it_items TYPE zif_pr_email_types=>tt_items iv_inbox TYPE string
      RETURNING VALUE(rv_html) TYPE string.
    CLASS-METHODS escape IMPORTING iv_value TYPE string RETURNING VALUE(rv_value) TYPE string.
    CLASS-METHODS subject IMPORTING is_notice TYPE zif_pr_email_types=>ty_notice
      RETURNING VALUE(rv_subject) TYPE string.
  PRIVATE SECTION.
    CLASS-METHODS cell IMPORTING iv_value TYPE string RETURNING VALUE(rv_cell) TYPE string.
ENDCLASS.

CLASS zcl_pr_email_html IMPLEMENTATION.
  METHOD escape.
    rv_value = iv_value.
    REPLACE ALL OCCURRENCES OF '&' IN rv_value WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN rv_value WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN rv_value WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_value WITH '&quot;'.
    REPLACE ALL OCCURRENCES OF `'` IN rv_value WITH '&#39;'.
  ENDMETHOD.
  METHOD cell.
    rv_cell = |<td style="border:1px solid #cbd5e1;padding:8px;vertical-align:top">{ escape( iv_value ) }</td>|.
  ENDMETHOD.
  METHOD subject.
    DATA(lv_label) = SWITCH string( is_notice-event
      WHEN zif_pr_email_types=>approval THEN 'Approval required'
      WHEN zif_pr_email_types=>approved THEN 'Approved'
      WHEN zif_pr_email_types=>rejected THEN 'Rejected'
      ELSE 'Notification' ).
    rv_subject = |PR { is_notice-pr ALPHA = OUT } - { lv_label }|.
  ENDMETHOD.
  METHOD render.
    rv_html = '<!doctype html><html><head><meta charset="utf-8"></head>' &&
      '<body style="font-family:Arial,sans-serif;color:#172033">' &&
      |<h2>{ escape( subject( is_notice ) ) }</h2>| &&
      '<p>Overall purchase requisition approval. The table contains all current, non-deleted items.</p>' &&
      |<p>Workflow: { is_notice-workflow_id }; task: { is_notice-task_id }.</p>| &&
      '<table style="border-collapse:collapse;font-size:13px"><thead><tr style="background:#e8eef7">'.
    DATA lt_headers TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    lt_headers = VALUE #( ( `Item` ) ( `Material / group` ) ( `PR description` )
      ( `Quantity / unit` ) ( `Valuation price / price unit` ) ( `Estimated value` )
      ( `Plant / storage` ) ( `Purchasing group / org` ) ( `Account category` )
      ( `Delivery date` ) ( `Creator / created on` ) ).
    LOOP AT lt_headers INTO DATA(lv_header).
      rv_html &&= |<th scope="col" style="border:1px solid #cbd5e1;padding:8px;text-align:left">{ lv_header }</th>|.
    ENDLOOP.
    rv_html &&= '</tr></thead><tbody>'.
    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_amount) = CONV string( 'Not calculated' ).
      IF ls_item-price_unit > 0.
        DATA(lv_estimate) = CONV zif_pr_email_types=>ty_amount(
          ls_item-quantity * ls_item-price / ls_item-price_unit ).
        lv_amount = |{ lv_estimate CURRENCY = ls_item-currency } { ls_item-currency }|.
      ENDIF.
      rv_html &&= '<tr>' && cell( |{ ls_item-item ALPHA = OUT }| ) &&
        cell( |{ ls_item-material ALPHA = OUT } / { ls_item-material_group }| ) &&
        cell( CONV string( ls_item-description ) ) &&
        cell( |{ ls_item-quantity NUMBER = RAW } { ls_item-unit }| ) &&
        cell( |{ ls_item-price CURRENCY = ls_item-currency } { ls_item-currency } / { ls_item-price_unit NUMBER = RAW } { ls_item-unit }| ) &&
        cell( lv_amount ) && cell( |{ ls_item-plant } / { ls_item-storage_location }| ) &&
        cell( |{ ls_item-purchasing_group } / { ls_item-purchasing_org }| ) &&
        cell( CONV string( ls_item-account_category ) ) &&
        cell( |{ ls_item-delivery_date DATE = ISO }| ) &&
        cell( |{ ls_item-creator } / { ls_item-creation_date DATE = ISO }| ) && '</tr>'.
    ENDLOOP.
    rv_html &&= '</tbody></table><p>Values are PR valuation estimates, excluding tax. ' &&
      'Limit and service items may require additional details in SAP. No mixed-currency grand total is calculated.</p>'.
    IF iv_inbox CP 'https://*'.
      rv_html &&= |<p><a href="{ escape( iv_inbox ) }">Open SAP My Inbox</a></p>|.
    ENDIF.
    IF is_notice-event = zif_pr_email_types=>approval.
      rv_html &&= '<p>Please review and approve the overall requisition in SAP My Inbox.</p>'.
    ELSEIF is_notice-event = zif_pr_email_types=>approved.
      rv_html &&= '<p>The overall requisition is approved. Purchasing can proceed in SAP.</p>'.
    ELSEIF is_notice-event = zif_pr_email_types=>rejected.
      rv_html &&= '<p>The overall requisition was rejected. This notification is sent to the creator(s) ' &&
        'and participants in earlier approved steps. Review the workflow history in SAP.</p>'.
    ENDIF.
    rv_html &&= '<p>Document values and workflow assignments may have changed since this email was generated.</p></body></html>'.
  ENDMETHOD.
ENDCLASS.

