*"* use this source file for your ABAP unit test classes

"! Match hint of an invoice item: price outside the tolerance, more than received, or a match
CLASS ltc_invoice_item_match DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_vhb_invoice_item_match.

    METHODS setup.
    METHODS price_above_tolerance FOR TESTING.
    METHODS price_within_tolerance FOR TESTING.
    METHODS quantity_above_receipt FOR TESTING.
    METHODS calculate_fills_rows FOR TESTING RAISING cx_sadl_exit.

    "! 10,000 kg received at an order price of 0.48 EUR
    METHODS item
      IMPORTING
        price         TYPE zvhb_amount
        quantity      TYPE zvhb_quantity DEFAULT 10000
      RETURNING
        VALUE(result) TYPE zcl_vhb_invoice_item_match=>ty_item.
ENDCLASS.


CLASS ltc_invoice_item_match IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( ).
  ENDMETHOD.

  METHOD item.
    result = VALUE #( Quantity = quantity Unit = 'KG' NetPrice = price Currency = 'EUR'
                      OrderNetPrice = '0.48' ReceivedQuantity = 10000 ).
  ENDMETHOD.

  METHOD price_above_tolerance.
    " 0.50 instead of 0.48 is 4.17 % more
    DATA(line) = item( '0.50' ).

    cut->evaluate( CHANGING item = line ).

    cl_abap_unit_assert=>assert_equals( act = line-PriceVariance exp = '4.17' ).
    cl_abap_unit_assert=>assert_equals( act = line-MatchCriticality exp = 1 ).
    cl_abap_unit_assert=>assert_char_cp( act = line-MatchText exp = '*4.17*' ).
  ENDMETHOD.

  METHOD price_within_tolerance.
    " The order price and all received goods: the invoice matches
    DATA(line) = item( '0.48' ).

    cut->evaluate( CHANGING item = line ).

    cl_abap_unit_assert=>assert_equals( act = line-PriceVariance exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = line-MatchCriticality exp = 3 ).
  ENDMETHOD.

  METHOD quantity_above_receipt.
    DATA(line) = item( price = '0.48' quantity = 12000 ).

    cut->evaluate( CHANGING item = line ).

    cl_abap_unit_assert=>assert_equals( act = line-MatchCriticality exp = 1 ).
    cl_abap_unit_assert=>assert_char_cp( act = line-MatchText exp = '*received*' ).
  ENDMETHOD.

  METHOD calculate_fills_rows.
    DATA original TYPE STANDARD TABLE OF zcl_vhb_invoice_item_match=>ty_item WITH EMPTY KEY.
    DATA calculated TYPE STANDARD TABLE OF zcl_vhb_invoice_item_match=>ty_item WITH EMPTY KEY.

    original = VALUE #( ( item( '0.50' ) ) ( item( '0.48' ) ) ).
    calculated = original.

    CAST if_sadl_exit_calc_element_read( cut )->calculate(
      EXPORTING it_original_data           = original
                it_requested_calc_elements = VALUE #( ( `MATCHTEXT` ) )
      CHANGING  ct_calculated_data         = calculated ).

    cl_abap_unit_assert=>assert_equals( act = calculated[ 1 ]-MatchCriticality exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = calculated[ 2 ]-MatchCriticality exp = 3 ).
  ENDMETHOD.

ENDCLASS.

