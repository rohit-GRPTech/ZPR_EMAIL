"Local test harness ONLY. Never import this SAP-named class into SAP.
CLASS cl_abap_unit_assert DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS assert_equals IMPORTING act TYPE any exp TYPE any.
    CLASS-METHODS assert_true IMPORTING act TYPE abap_bool.
    CLASS-METHODS assert_false IMPORTING act TYPE abap_bool.
    CLASS-METHODS assert_initial IMPORTING act TYPE any.
ENDCLASS.
CLASS cl_abap_unit_assert IMPLEMENTATION.
  METHOD assert_equals.
    ASSERT act = exp.
  ENDMETHOD.
  METHOD assert_true.
    ASSERT act = abap_true.
  ENDMETHOD.
  METHOD assert_false.
    ASSERT act = abap_false.
  ENDMETHOD.
  METHOD assert_initial.
    ASSERT act IS INITIAL.
  ENDMETHOD.
ENDCLASS.
