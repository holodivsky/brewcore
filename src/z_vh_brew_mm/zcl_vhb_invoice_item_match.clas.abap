"! Virtual elements of ZVHB_C_SupplierInvoiceItem: the price deviation and a match hint
"! while the invoice is still being entered. The binding check on posting is done by
"! view ZVHB_I_SupplierInvoiceMatch; this class only reads the fields of the row,
"! so it works for drafts as well.
CLASS zcl_vhb_invoice_item_match DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

    TYPES:
      BEGIN OF ty_item,
        Quantity         TYPE zvhb_quantity,
        Unit             TYPE zvhb_unit,
        NetPrice         TYPE zvhb_amount,
        Currency         TYPE zvhb_currency,
        OrderNetPrice    TYPE zvhb_amount,
        ReceivedQuantity TYPE zvhb_quantity,
        PriceVariance    TYPE zvhb_percent,
        MatchText        TYPE c LENGTH 80,
        MatchCriticality TYPE int1,
      END OF ty_item.

    "! Fills price deviation, hint and criticality (1 red, 3 green) of one item
    METHODS evaluate
      CHANGING
        item TYPE ty_item.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MM'.

    CONSTANTS:
      BEGIN OF criticality,
        negative TYPE int1 VALUE 1,
        positive TYPE int1 VALUE 3,
      END OF criticality.
ENDCLASS.



CLASS zcl_vhb_invoice_item_match IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    et_requested_orig_elements = VALUE #( ( `QUANTITY` ) ( `UNIT` ) ( `NETPRICE` ) ( `CURRENCY` )
                                          ( `ORDERNETPRICE` ) ( `RECEIVEDQUANTITY` ) ).
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    items = CORRESPONDING #( it_original_data ).
    LOOP AT items ASSIGNING FIELD-SYMBOL(<item>).
      evaluate( CHANGING item = <item> ).
    ENDLOOP.
    ct_calculated_data = CORRESPONDING #( items ).
  ENDMETHOD.

  METHOD evaluate.
    IF item-OrderNetPrice IS INITIAL.
      RETURN.
    ENDIF.

    item-PriceVariance = round( val = ( item-NetPrice - item-OrderNetPrice ) * 100 / item-OrderNetPrice
                                dec = 2 ).
    DATA(deviation) = CONV zvhb_percent( abs( item-PriceVariance ) ).

    IF deviation > zcl_vhb_purchasing_check=>c_price_tolerance.
      DATA(percent) = |{ deviation DECIMALS = 2 }|.
      DATA(order_price) = |{ item-OrderNetPrice } { item-Currency }|.
      MESSAGE ID c_msgid TYPE 'I' NUMBER '036' WITH percent order_price INTO item-MatchText.
      item-MatchCriticality = criticality-negative.
    ELSEIF item-Quantity > item-ReceivedQuantity.
      DATA(received) = |{ item-ReceivedQuantity NUMBER = USER } { item-Unit }|.
      MESSAGE ID c_msgid TYPE 'I' NUMBER '037' WITH received INTO item-MatchText.
      item-MatchCriticality = criticality-negative.
    ELSE.
      MESSAGE ID c_msgid TYPE 'I' NUMBER '038' INTO item-MatchText.
      item-MatchCriticality = criticality-positive.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
