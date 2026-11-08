*"* use this source file for your ABAP unit test classes

"! FR-SD-05: invoice items from the delivered quantities at the prices of the sales order. Goods issue and
"! invoice creation change inventory, billing and the sales order; they are checked in the app.
CLASS ltc_delivery DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_items TYPE TABLE FOR READ RESULT zvhb_r_delivery\\item.
    TYPES tt_order_items TYPE TABLE FOR READ RESULT zvhb_r_salesorder\\item.

    DATA cut TYPE REF TO lhc_delivery.
    DATA order_items TYPE tt_order_items.

    METHODS setup.
    METHODS batch_split_is_billed_once FOR TESTING.
    METHODS deposit_is_billed_apart FOR TESTING.
    METHODS partial_delivery_is_prorated FOR TESTING.
ENDCLASS.


CLASS ltc_delivery IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT cut FOR TESTING.

    " 6,000 bottles for 4,912.80 EUR and 300 crates for 930.00 EUR
    order_items = VALUE #(
      ( Item = '00010' ItemCategory = 'PROD' Material = 'PILS-BTL05' Unit = 'ST' Quantity = 6000
        Currency = 'EUR' NetAmount = '4912.80' )
      ( Item = '00011' ItemCategory = 'DEPO' Material = 'CRATE-20' Unit = 'ST' Quantity = 300
        Currency = 'EUR' BasePrice = '3.10' NetAmount = '930.00' ) ).
  ENDMETHOD.

  METHOD batch_split_is_billed_once.
    DATA(billing) = cut->invoice_items(
      items       = VALUE tt_items( ( Item = '00010' OrderItem = '00010' Material = 'PILS-BTL05' Batch = '2000000001'
                                      Quantity = 4800 )
                                    ( Item = '00020' OrderItem = '00010' Material = 'PILS-BTL05' Batch = '2000000002'
                                      Quantity = 1200 ) )
      order_items = order_items ).

    DATA(targets) = billing[ 1 ]-%target.
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( targets ) ).
    cl_abap_unit_assert=>assert_equals( exp = 6000 act = targets[ 1 ]-Quantity ).
    cl_abap_unit_assert=>assert_equals( exp = '4912.80' act = targets[ 1 ]-NetAmount ).
  ENDMETHOD.

  METHOD deposit_is_billed_apart.
    DATA net_amount TYPE zvhb_amount.
    DATA deposit TYPE zvhb_amount.

    cut->invoice_items( EXPORTING items       = VALUE tt_items( ( Item = '00010' OrderItem = '00010' Quantity = 6000 )
                                                                ( Item = '00030' OrderItem = '00011' Quantity = 300 ) )
                                  order_items = order_items
                        IMPORTING net_amount  = net_amount
                                  deposit     = deposit ).

    cl_abap_unit_assert=>assert_equals( exp = '4912.80' act = net_amount ).
    cl_abap_unit_assert=>assert_equals( exp = '930.00' act = deposit ).
  ENDMETHOD.

  METHOD partial_delivery_is_prorated.
    DATA net_amount TYPE zvhb_amount.

    cut->invoice_items( EXPORTING items       = VALUE tt_items( ( Item = '00010' OrderItem = '00010' Quantity = 3000 ) )
                                  order_items = order_items
                        IMPORTING net_amount  = net_amount ).

    cl_abap_unit_assert=>assert_equals( exp = '2456.40' act = net_amount ).
  ENDMETHOD.

ENDCLASS.

