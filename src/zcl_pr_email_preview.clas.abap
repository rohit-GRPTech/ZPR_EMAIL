CLASS zcl_pr_email_preview DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.


CLASS zcl_pr_email_preview IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    "Sample data only. No emails or database changes.
    DATA(lt_items) = VALUE zif_pr_email_types=>tt_items(
      (
        pr               = '0010001234'
        item             = '00010'
        material         = 'MAT-1001'
        description      = 'Bearing & housing <sample>'
        material_group   = 'SPARES'
        quantity         = 20
        unit             = 'EA'
        price            = 150
        price_unit       = 1
        currency         = 'INR'
        plant            = '1010'
        purchasing_group = '001'
        delivery_date    = '20261015'
        creator          = 'EXAMPLE'
        creation_date    = '20260928'
      )
      (
        pr               = '0010001234'
        item             = '00020'
        material         = 'MAT-1002'
        description      = 'Motor assembly'
        quantity         = 5
        unit             = 'EA'
        price            = 5000
        price_unit       = 1
        currency         = 'INR'
        plant            = '1010'
        purchasing_group = '001'
        delivery_date    = '20261020'
        creator          = 'EXAMPLE'
        creation_date    = '20260928'
      )
    ).

    DATA(ls_notice) = VALUE zif_pr_email_types=>ty_notice(
      pr          = '0010001234'
      workflow_id = '000000000001'
      task_id     = '000000000002'
      event       = zif_pr_email_types=>approval
    ).

    DATA(lv_html) = zcl_pr_email_html=>render(
      is_notice = ls_notice
      it_items  = lt_items
      iv_inbox  = ''
    ).

    out->write( lv_html ).

  ENDMETHOD.

ENDCLASS.
