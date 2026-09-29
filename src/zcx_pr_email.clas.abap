CLASS zcx_pr_email DEFINITION PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA detail TYPE string READ-ONLY.
    METHODS constructor IMPORTING iv_detail TYPE string previous TYPE REF TO cx_root OPTIONAL.
ENDCLASS.

CLASS zcx_pr_email IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    detail = iv_detail.
  ENDMETHOD.
ENDCLASS.

