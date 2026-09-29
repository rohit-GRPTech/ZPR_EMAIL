CLASS ltc_html DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS escapes_untrusted FOR TESTING.
    METHODS includes_every_item FOR TESTING.
    METHODS zero_price_unit FOR TESTING.
    METHODS rejects_unsafe_link FOR TESTING.
    METHODS respects_price_unit FOR TESTING.
ENDCLASS.
CLASS ltc_html IMPLEMENTATION.
  METHOD escapes_untrusted.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pr_email_html=>escape( `<script a="x">A&B'</script>` )
      exp = `&lt;script a=&quot;x&quot;&gt;A&amp;B&#39;&lt;/script&gt;` ).
  ENDMETHOD.
  METHOD includes_every_item.
    DATA(lv_html) = zcl_pr_email_html=>render( is_notice = VALUE #( pr = '10001234' )
      it_items = VALUE #( ( item = '00010' description = 'FIRST' )
                         ( item = '00020' description = 'LAST' ) ) iv_inbox = '' ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS 'FIRST' AND lv_html CS 'LAST' ) ).
  ENDMETHOD.
  METHOD zero_price_unit.
    DATA(lv_html) = zcl_pr_email_html=>render( is_notice = VALUE #( )
      it_items = VALUE #( ( quantity = 10 price = 50 price_unit = 0 ) ) iv_inbox = '' ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS 'Not calculated' ) ).
  ENDMETHOD.
  METHOD rejects_unsafe_link.
    DATA(lv_html) = zcl_pr_email_html=>render( is_notice = VALUE #( )
      it_items = VALUE #( ) iv_inbox = 'javascript:alert(1)' ).
    cl_abap_unit_assert=>assert_false( xsdbool( lv_html CS 'href=' ) ).
  ENDMETHOD.
  METHOD respects_price_unit.
    DATA(lv_html) = zcl_pr_email_html=>render( is_notice = VALUE #( )
      it_items = VALUE #( ( quantity = 10 price = 250 price_unit = 100 currency = 'INR' ) )
      iv_inbox = '' ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS '25.00 INR' ) ).
  ENDMETHOD.
ENDCLASS.

