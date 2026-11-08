*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_delivery DEFINITION DEFERRED FOR TESTING.

INTERFACE lif_delivery.
  CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_SD'.

  CONSTANTS:
    "! Delivery status values of domain ZVHB_DLV_STATUS
    BEGIN OF status,
      picked       TYPE zvhb_dlv_status VALUE 'PICK',
      goods_issued TYPE zvhb_dlv_status VALUE 'GI',
      invoiced     TYPE zvhb_dlv_status VALUE 'BILL',
    END OF status.

  CONSTANTS c_deposit TYPE zvhb_item_cat VALUE 'DEPO'.
  CONSTANTS c_invoice TYPE zvhb_bill_type VALUE 'INV'.
  CONSTANTS c_goods_issue TYPE zvhb_movement_type VALUE '601'.
ENDINTERFACE.


CLASS lhc_delivery DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_delivery.
  PRIVATE SECTION.
    TYPES tt_delivery_keys TYPE TABLE FOR READ IMPORT zvhb_r_delivery\\delivery.
    TYPES tt_deliveries TYPE TABLE FOR READ RESULT zvhb_r_delivery\\delivery.
    TYPES ty_delivery TYPE STRUCTURE FOR READ RESULT zvhb_r_delivery\\delivery.
    TYPES tt_items TYPE TABLE FOR READ RESULT zvhb_r_delivery\\item.
    TYPES tt_billing_items TYPE TABLE FOR CREATE zvhb_r_billingdocument\\billingdocument\_item.
    TYPES tt_order_items TYPE TABLE FOR READ RESULT zvhb_r_salesorder\\item.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Delivery RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Delivery RESULT result.

    METHODS postGoodsIssue FOR MODIFY
      IMPORTING keys FOR ACTION Delivery~postGoodsIssue RESULT result.

    METHODS createInvoice FOR MODIFY
      IMPORTING keys FOR ACTION Delivery~createInvoice RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Delivery~setDefaults.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Delivery~setNumber.

    "! FR-SD-05: invoice items at the prices of the sales order; batch splits of one order item are billed together
    METHODS invoice_items
      IMPORTING
        items         TYPE tt_items
        order_items   TYPE tt_order_items
      EXPORTING
        net_amount    TYPE zvhb_amount
        deposit       TYPE zvhb_amount
        currency      TYPE zvhb_currency
      RETURNING
        VALUE(result) TYPE tt_billing_items.

    METHODS set_status
      IMPORTING
        delivery_keys TYPE tt_delivery_keys
        status        TYPE zvhb_dlv_status
      RETURNING
        VALUE(result) TYPE tt_deliveries.

    METHODS message
      IMPORTING
        number        TYPE symsgno
        severity      TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        v1            TYPE simple OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.
ENDCLASS.


CLASS lhc_delivery IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(deliveries)
      FAILED failed.

    result = VALUE #( FOR d IN deliveries
                      ( %tky                   = d-%tky
                        %action-postGoodsIssue = COND #( WHEN d-Status = lif_delivery=>status-picked
                                                         THEN if_abap_behv=>fc-o-enabled
                                                         ELSE if_abap_behv=>fc-o-disabled )
                        %action-createInvoice  = COND #( WHEN d-Status = lif_delivery=>status-goods_issued
                                                         THEN if_abap_behv=>fc-o-enabled
                                                         ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD postGoodsIssue.
    DATA movements TYPE TABLE FOR ACTION IMPORT zvhb_r_materialdocument~postgoodsmovement.
    DATA issued TYPE tt_delivery_keys.

    READ ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(deliveries)
      ENTITY Delivery BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT deliveries INTO DATA(delivery).
      " FR-SD-04: beer leaves from the picked batches, crates from the empties store, with movement type 601
      movements = VALUE #( FOR i IN items USING KEY entity WHERE ( DeliveryUUID = delivery-DeliveryUUID )
                           ( %cid   = |GI{ i-Item }|
                             %param = VALUE #( MovementType    = lif_delivery=>c_goods_issue
                                               Material        = i-Material
                                               Plant           = i-Plant
                                               StorageLocation = i-StorageLocation
                                               Batch           = i-Batch
                                               Quantity        = i-Quantity
                                               HeaderText      = |Delivery { delivery-Delivery }| ) ) ).

      MODIFY ENTITIES OF zvhb_r_materialdocument
        ENTITY MaterialDocument
          EXECUTE postGoodsMovement FROM movements
        FAILED DATA(issue_failed)
        REPORTED DATA(issue_reported).

      IF issue_failed IS NOT INITIAL.
        APPEND VALUE #( %tky = delivery-%tky ) TO failed-delivery.
        APPEND VALUE #( %tky = delivery-%tky
                        %msg = VALUE #( issue_reported-materialdocument[ 1 ]-%msg OPTIONAL ) ) TO reported-delivery.
        CLEAR issue_failed.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( delivery ) TO issued.
      APPEND VALUE #( %tky = delivery-%tky
                      %msg = message( number   = '017'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = delivery-Delivery ) ) TO reported-delivery.
    ENDLOOP.

    IF issued IS NOT INITIAL.
      MODIFY ENTITIES OF zvhb_r_delivery IN LOCAL MODE
        ENTITY Delivery
          UPDATE FIELDS ( GoodsIssueDate )
          WITH VALUE #( FOR d IN issued ( %tky = d-%tky GoodsIssueDate = cl_abap_context_info=>get_system_date( ) ) ).
    ENDIF.

    DATA(changed) = set_status( delivery_keys = issued status = lif_delivery=>status-goods_issued ).
    result = VALUE #( FOR c IN changed ( %tky = c-%tky %param = c ) ).
  ENDMETHOD.

  METHOD createInvoice.
    DATA invoiced TYPE tt_delivery_keys.
    DATA net_amount TYPE zvhb_amount.
    DATA deposit TYPE zvhb_amount.
    DATA currency TYPE zvhb_currency.

    READ ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(deliveries)
      ENTITY Delivery BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT deliveries INTO DATA(delivery).
      READ ENTITIES OF zvhb_r_salesorder
        ENTITY SalesOrder BY \_Item
          ALL FIELDS WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off SalesOrderUUID = delivery-SalesOrderUUID ) )
        RESULT DATA(order_items).

      DATA(billing_items) = invoice_items(
        EXPORTING items       = VALUE #( FOR i IN items USING KEY entity WHERE ( DeliveryUUID = delivery-DeliveryUUID ) ( i ) )
                  order_items = order_items
        IMPORTING net_amount = net_amount
                  deposit    = deposit
                  currency   = currency ).

      MODIFY ENTITIES OF zvhb_r_billingdocument
        ENTITY BillingDocument
          CREATE FIELDS ( BillingType Customer SalesOrder Delivery BillingDate Currency NetAmount DepositAmount
                          TotalAmount )
          WITH VALUE #( ( %cid          = 'INVOICE'
                          BillingType   = lif_delivery=>c_invoice
                          Customer      = delivery-Customer
                          SalesOrder    = delivery-SalesOrder
                          Delivery      = delivery-Delivery
                          BillingDate   = cl_abap_context_info=>get_system_date( )
                          Currency      = currency
                          NetAmount     = net_amount
                          DepositAmount = deposit
                          TotalAmount   = net_amount + deposit ) )
          CREATE BY \_Item
          FIELDS ( Item ItemCategory Material Unit Quantity Currency NetAmount ) WITH billing_items
        FAILED DATA(billing_failed)
        REPORTED DATA(billing_reported).

      " The sales order is billed as well; both are saved with the invoice
      IF billing_failed IS INITIAL.
        MODIFY ENTITIES OF zvhb_r_salesorder
          ENTITY SalesOrder
            EXECUTE setInvoiced
            FROM VALUE #( ( %is_draft = if_abap_behv=>mk-off SalesOrderUUID = delivery-SalesOrderUUID ) )
          FAILED DATA(order_failed)
          REPORTED DATA(order_reported).
      ENDIF.

      IF billing_failed IS NOT INITIAL OR order_failed IS NOT INITIAL.
        APPEND VALUE #( %tky = delivery-%tky ) TO failed-delivery.
        APPEND VALUE #( %tky = delivery-%tky
                        %msg = COND #( WHEN billing_failed IS NOT INITIAL
                                       THEN VALUE #( billing_reported-billingdocument[ 1 ]-%msg OPTIONAL )
                                       ELSE VALUE #( order_reported-salesorder[ 1 ]-%msg OPTIONAL ) ) )
               TO reported-delivery.
        CLEAR: billing_failed, order_failed.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( delivery ) TO invoiced.
      APPEND VALUE #( %tky = delivery-%tky
                      %msg = message( number   = '018'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = delivery-Delivery ) ) TO reported-delivery.
    ENDLOOP.

    DATA(changed) = set_status( delivery_keys = invoiced status = lif_delivery=>status-invoiced ).
    result = VALUE #( FOR c IN changed ( %tky = c-%tky %param = c ) ).
  ENDMETHOD.

  METHOD invoice_items.
    TYPES:
      BEGIN OF ty_billed,
        order_item TYPE zvhb_sd_item,
        quantity   TYPE zvhb_quantity,
      END OF ty_billed.
    DATA billed TYPE SORTED TABLE OF ty_billed WITH UNIQUE KEY order_item.
    DATA amount TYPE zvhb_amount.

    CLEAR: net_amount, deposit, currency.

    LOOP AT items INTO DATA(item).
      ASSIGN billed[ order_item = item-OrderItem ] TO FIELD-SYMBOL(<billed>).
      IF sy-subrc <> 0.
        INSERT VALUE #( order_item = item-OrderItem ) INTO TABLE billed ASSIGNING <billed>.
      ENDIF.
      <billed>-quantity += item-Quantity.
    ENDLOOP.

    DATA order_item LIKE LINE OF order_items.

    APPEND VALUE #( %cid_ref = 'INVOICE' ) TO result ASSIGNING FIELD-SYMBOL(<invoice>).
    LOOP AT billed INTO DATA(line).
      CLEAR order_item.
      LOOP AT order_items INTO DATA(candidate) WHERE Item = line-order_item.
        order_item = candidate.
        EXIT.
      ENDLOOP.
      CHECK order_item-Quantity > 0.

      " The delivered quantity is billed at the net price per unit of the order item
      amount = line-quantity * order_item-NetAmount / order_item-Quantity.
      currency = order_item-Currency.
      IF order_item-ItemCategory = lif_delivery=>c_deposit.
        deposit += amount.
      ELSE.
        net_amount += amount.
      ENDIF.

      APPEND VALUE #( %cid         = |BILL{ line-order_item }|
                      Item         = line-order_item
                      ItemCategory = order_item-ItemCategory
                      Material     = order_item-Material
                      Unit         = order_item-Unit
                      Quantity     = line-quantity
                      Currency     = order_item-Currency
                      NetAmount    = amount ) TO <invoice>-%target.
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaults.
    MODIFY ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = lif_delivery=>status-picked ) ).
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        FIELDS ( Delivery ) WITH CORRESPONDING #( keys )
      RESULT DATA(deliveries).

    DELETE deliveries WHERE Delivery IS NOT INITIAL.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.

    LOOP AT deliveries ASSIGNING FIELD-SYMBOL(<delivery>).
      TRY.
          <delivery>-Delivery = number_range->get_next( zif_vhb_number_range=>objects-delivery ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <delivery>-%tky %msg = message( number = '001' v1 = exception->get_text( ) ) )
                 TO reported-delivery.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        UPDATE FIELDS ( Delivery )
        WITH VALUE #( FOR d IN deliveries WHERE ( Delivery IS NOT INITIAL ) ( %tky = d-%tky Delivery = d-Delivery ) ).
  ENDMETHOD.

  METHOD set_status.
    IF delivery_keys IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN delivery_keys ( %tky = key-%tky Status = status ) ).

    READ ENTITIES OF zvhb_r_delivery IN LOCAL MODE
      ENTITY Delivery
        ALL FIELDS WITH CORRESPONDING #( delivery_keys )
      RESULT result.
  ENDMETHOD.

  METHOD message.
    result = new_message( id       = lif_delivery=>c_msgid
                          number   = number
                          severity = severity
                          v1       = v1 ).
  ENDMETHOD.

ENDCLASS.

