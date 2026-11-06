*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_purchase_order DEFINITION DEFERRED FOR TESTING.

"! Status values and limits shared by the handlers of the purchase order
INTERFACE lif_purchase_order.
  CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MM'.

  CONSTANTS:
    "! Purchase order status values of domain ZVHB_PO_STATUS
    BEGIN OF status,
      created           TYPE zvhb_po_status VALUE 'NEW',
      awaiting_approval TYPE zvhb_po_status VALUE 'WAIT',
      ordered           TYPE zvhb_po_status VALUE 'ORDR',
      rejected          TYPE zvhb_po_status VALUE 'REJ',
      completed         TYPE zvhb_po_status VALUE 'DONE',
    END OF status.

  "! Orders above this net amount need an approval
  CONSTANTS c_approval_limit TYPE zvhb_amount VALUE '10000.00'.
  CONSTANTS c_currency TYPE zvhb_currency VALUE 'EUR'.
ENDINTERFACE.


CLASS lhc_purchase_order DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_purchase_order.
  PRIVATE SECTION.
    TYPES tt_keys   TYPE TABLE FOR READ IMPORT zvhb_r_purchaseorder\\purchaseorder.
    TYPES tt_orders TYPE TABLE FOR READ RESULT zvhb_r_purchaseorder\\purchaseorder.
    TYPES ty_key    TYPE STRUCTURE FOR READ IMPORT zvhb_r_purchaseorder\\purchaseorder.

    TYPES:
      BEGIN OF ty_requisition,
        preq_uuid        TYPE sysuuid_x16,
        material         TYPE zvhb_material,
        plant            TYPE zvhb_plant,
        storage_location TYPE zvhb_storage_loc,
        quantity         TYPE zvhb_quantity,
        delivery_date    TYPE d,
        supplier         TYPE zvhb_partner,
        status           TYPE zvhb_pr_status,
      END OF ty_requisition.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrder RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR PurchaseOrder RESULT result.

    METHODS createFromRequisition FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~createFromRequisition.

    METHODS order FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~order RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~reject RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrder~setDefaults.

    METHODS copySupplierTerms FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrder~copySupplierTerms.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR PurchaseOrder~setNumber.

    METHODS validateSupplier FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseOrder~validateSupplier.

    METHODS validateCurrency FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseOrder~validateCurrency.

    METHODS validateItems FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseOrder~validateItems.

    "! Creates an active purchase order with one item from the requisition and marks the requisition as ordered
    METHODS create_from_requisition
      IMPORTING
        requisition   TYPE ty_requisition
        reference     TYPE zvhb_d_requisitionreference
      RETURNING
        VALUE(result) TYPE ty_key.

    "! Sets the status and returns the changed orders
    METHODS set_status
      IMPORTING
        order_keys    TYPE tt_keys
        status        TYPE zvhb_po_status
      RETURNING
        VALUE(result) TYPE tt_orders.

    METHODS error
      IMPORTING
        number        TYPE symsgno
        v1            TYPE simple OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS get_number_range
      RETURNING
        VALUE(result) TYPE REF TO zif_vhb_number_range.
ENDCLASS.


CLASS lhc_purchase_order IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED failed.

    " A purchase order can be changed until it is sent; the status actions work on saved orders only
    result = VALUE #(
      FOR o IN orders
      LET changeable = COND #( WHEN o-Status = lif_purchase_order=>status-created OR o-Status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )
          saved      = xsdbool( o-%is_draft = if_abap_behv=>mk-off )
          waiting    = COND #( WHEN saved = abap_true AND o-Status = lif_purchase_order=>status-awaiting_approval
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky            = o-%tky
        %update         = changeable
        %delete         = changeable
        %action-Edit    = changeable
        %assoc-_Item    = changeable
        %action-order   = COND #( WHEN saved = abap_true AND o-Status = lif_purchase_order=>status-created
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled )
        %action-approve = waiting
        %action-reject  = waiting ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " The purchaser and approver roles follow in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-createFromRequisition = if_abap_behv=>mk-on.
      result-%action-createFromRequisition = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD createFromRequisition.
    DATA requisition TYPE ty_requisition.

    LOOP AT keys INTO DATA(key).
      CLEAR requisition.
      SELECT SINGLE preq_uuid, material, plant, storage_location, quantity, delivery_date, supplier, status
        FROM zvhb_preq
        WHERE purchase_requisition = @key-%param-PurchaseRequisition
        INTO CORRESPONDING FIELDS OF @requisition.
      DATA(found) = xsdbool( sy-subrc = 0 ).

      DATA(message) = COND #(
        WHEN found = abap_false OR requisition-status = 'NEW'
        THEN error( number = '015' v1 = key-%param-PurchaseRequisition )
        WHEN requisition-status = 'ORDR'
        THEN error( number = '016' v1 = key-%param-PurchaseRequisition ) ).

      IF message IS BOUND.
        APPEND VALUE #( %cid = key-%cid ) TO failed-purchaseorder.
        APPEND VALUE #( %cid = key-%cid %msg = message ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.

      DATA(created) = create_from_requisition( requisition = requisition
                                               reference   = CORRESPONDING #( key-%param ) ).
      IF created IS INITIAL.
        APPEND VALUE #( %cid = key-%cid ) TO failed-purchaseorder.
        APPEND VALUE #( %cid = key-%cid %msg = error( number = '016' v1 = key-%param-PurchaseRequisition ) )
               TO reported-purchaseorder.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %cid = key-%cid %tky = created-%tky ) TO mapped-purchaseorder.
    ENDLOOP.
  ENDMETHOD.

  METHOD create_from_requisition.
    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        CREATE FIELDS ( Supplier Currency )
        WITH VALUE #( ( %cid      = 'ORDER'
                        %is_draft = if_abap_behv=>mk-off
                        Supplier  = COND #( WHEN reference-Supplier IS INITIAL
                                            THEN requisition-supplier ELSE reference-Supplier )
                        Currency  = lif_purchase_order=>c_currency ) )
        CREATE BY \_Item
        FIELDS ( Material Plant StorageLocation Quantity NetPrice DeliveryDate RequisitionUUID )
        WITH VALUE #( ( %cid_ref  = 'ORDER'
                        %is_draft = if_abap_behv=>mk-off
                        %target   = VALUE #( ( %cid            = 'ITEM'
                                               %is_draft       = if_abap_behv=>mk-off
                                               Material        = requisition-material
                                               Plant           = requisition-plant
                                               StorageLocation = requisition-storage_location
                                               Quantity        = requisition-quantity
                                               NetPrice        = reference-NetPrice
                                               DeliveryDate    = requisition-delivery_date
                                               RequisitionUUID = requisition-preq_uuid ) ) ) )
      MAPPED DATA(created).

    MODIFY ENTITIES OF zvhb_r_purchaserequisition
      ENTITY Requisition
        EXECUTE markOrdered
        FROM VALUE #( ( RequisitionUUID = requisition-preq_uuid %is_draft = if_abap_behv=>mk-off ) )
      FAILED DATA(requisition_failed).

    " Without the status change the requisition could be ordered twice, so no order is created then
    IF requisition_failed IS INITIAL.
      result = CORRESPONDING #( created-purchaseorder[ 1 ] ).
    ENDIF.
  ENDMETHOD.

  METHOD order.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( PurchaseOrder TotalAmount Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    " Above the limit the order waits for an approval, otherwise it goes to the supplier at once
    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR o IN orders
                      ( %tky   = o-%tky
                        Status = COND #( WHEN o-TotalAmount > lif_purchase_order=>c_approval_limit
                                         THEN lif_purchase_order=>status-awaiting_approval
                                         ELSE lif_purchase_order=>status-ordered ) ) ).

    reported-purchaseorder = VALUE #(
      FOR o IN orders WHERE ( TotalAmount > lif_purchase_order=>c_approval_limit )
      ( %tky = o-%tky
        %msg = new_message( id       = lif_purchase_order=>c_msgid
                            number   = '020'
                            severity = if_abap_behv_message=>severity-information
                            v1       = o-PurchaseOrder
                            v2       = o-TotalAmount
                            v3       = o-Currency
                            v4       = lif_purchase_order=>c_approval_limit ) ) ).

    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(changed).
    result = VALUE #( FOR c IN changed ( %tky = c-%tky %param = c ) ).
  ENDMETHOD.

  METHOD approve.
    DATA(orders) = set_status( order_keys = CORRESPONDING #( keys )
                               status     = lif_purchase_order=>status-ordered ).
    result = VALUE #( FOR o IN orders ( %tky = o-%tky %param = o ) ).
  ENDMETHOD.

  METHOD reject.
    DATA(orders) = set_status( order_keys = CORRESPONDING #( keys )
                               status     = lif_purchase_order=>status-rejected ).
    result = VALUE #( FOR o IN orders ( %tky = o-%tky %param = o ) ).
  ENDMETHOD.

  METHOD set_status.
    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky Status = status ) ).

    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        ALL FIELDS WITH CORRESPONDING #( order_keys )
      RESULT result.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( Status OrderDate Currency )
        WITH VALUE #( FOR o IN orders
                      ( %tky      = o-%tky
                        Status    = lif_purchase_order=>status-created
                        OrderDate = cl_abap_context_info=>get_system_date( )
                        Currency  = COND #( WHEN o-Currency IS INITIAL THEN lif_purchase_order=>c_currency ELSE o-Currency ) ) ).
  ENDMETHOD.

  METHOD copySupplierTerms.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Supplier ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    IF orders IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Supplier, Currency, PaymentTerms FROM zvhb_i_suppliervh
      FOR ALL ENTRIES IN @orders
      WHERE Supplier = @orders-Supplier
      INTO TABLE @DATA(suppliers).

    " Payment terms and currency come from the supplier master record
    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( PaymentTerms Currency )
        WITH VALUE #( FOR o IN orders
                      FOR s IN suppliers WHERE ( Supplier = o-Supplier )
                      ( %tky = o-%tky PaymentTerms = s-PaymentTerms Currency = s-Currency ) ).
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( PurchaseOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DELETE orders WHERE PurchaseOrder IS NOT INITIAL.

    LOOP AT orders ASSIGNING FIELD-SYMBOL(<order>).
      TRY.
          <order>-PurchaseOrder = get_number_range( )->get_next( zif_vhb_number_range=>objects-purchase_order ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <order>-%tky %msg = error( number = '014' v1 = exception->get_text( ) ) )
                 TO reported-purchaseorder.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( PurchaseOrder )
        WITH VALUE #( FOR o IN orders WHERE ( PurchaseOrder IS NOT INITIAL )
                      ( %tky = o-%tky PurchaseOrder = o-PurchaseOrder ) ).
  ENDMETHOD.

  METHOD validateSupplier.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Supplier ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(check) = NEW zcl_vhb_purchasing_check( ).

    LOOP AT orders INTO DATA(o).
      APPEND VALUE #( %tky = o-%tky %state_area = 'SUPPLIER' ) TO reported-purchaseorder.

      DATA(problem) = COND zcl_vhb_purchasing_check=>ty_error( WHEN o-Supplier IS INITIAL
                                                               THEN VALUE #( msgno = '008' )
                                                               ELSE check->check_supplier( o-Supplier ) ).
      IF problem IS NOT INITIAL.
        APPEND VALUE #( %tky = o-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky              = o-%tky
                        %state_area       = 'SUPPLIER'
                        %msg              = error( number = problem-msgno v1 = problem-v1 )
                        %element-Supplier = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCurrency.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(o).
      APPEND VALUE #( %tky = o-%tky %state_area = 'CURRENCY' ) TO reported-purchaseorder.

      SELECT SINGLE @abap_true FROM i_currency WITH PRIVILEGED ACCESS
        WHERE Currency = @o-Currency
        INTO @DATA(exists).
      IF exists = abap_false.
        APPEND VALUE #( %tky = o-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky              = o-%tky
                        %state_area       = 'CURRENCY'
                        %msg              = error( number = '012' v1 = o-Currency )
                        %element-Currency = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.
      CLEAR exists.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateItems.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Item
        FIELDS ( Item ) WITH CORRESPONDING #( keys )
      LINK DATA(links).

    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky %state_area = 'ITEMS' ) TO reported-purchaseorder.

      IF NOT line_exists( links[ KEY id COMPONENTS source-%tky = key-%tky ] ).
        APPEND VALUE #( %tky = key-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky        = key-%tky
                        %state_area = 'ITEMS'
                        %msg        = error( number = '013' ) ) TO reported-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD error.
    result = new_message( id       = lif_purchase_order=>c_msgid
                          number   = number
                          severity = if_abap_behv_message=>severity-error
                          v1       = v1 ).
  ENDMETHOD.

  METHOD get_number_range.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.
    result = number_range.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_purchase_order.
  PRIVATE SECTION.
    CONSTANTS c_goods_receipt TYPE zvhb_movement_type VALUE '101'.

    CONSTANTS:
      BEGIN OF defaults,
        plant            TYPE zvhb_plant VALUE 'BR01',
        storage_location TYPE zvhb_storage_loc VALUE 'RM01',
        lead_time_days   TYPE i VALUE 14,
        item_step        TYPE i VALUE 10,
      END OF defaults.

    TYPES ty_item TYPE STRUCTURE FOR READ RESULT zvhb_r_purchaseorder\\item.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item RESULT result.

    METHODS receiveGoods FOR MODIFY
      IMPORTING keys FOR ACTION Item~receiveGoods RESULT result.

    METHODS applyGoodsReceipt FOR MODIFY
      IMPORTING keys FOR ACTION Item~applyGoodsReceipt RESULT result.

    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setItemDefaults.

    METHODS setUnit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setUnit.

    METHODS calculateAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculateAmount.

    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItem.

    "! Posts the goods receipt (movement type 101) with a reference to the order item
    METHODS post_goods_receipt
      IMPORTING
        item           TYPE ty_item
        purchase_order TYPE zvhb_purch_order
        receipt        TYPE zvhb_d_goodsreceipt
      RETURNING
        VALUE(result)  TYPE REF TO if_abap_behv_message.

    METHODS check_item
      IMPORTING
        item          TYPE ty_item
      RETURNING
        VALUE(result) TYPE zcl_vhb_purchasing_check=>ty_error.

    "! Sets the order to Completed when all items are delivered, and back to Ordered after a reversal
    METHODS update_order_status
      IMPORTING
        order_uuids TYPE string_table.

    METHODS error
      IMPORTING
        number        TYPE symsgno
        v1            TYPE simple OPTIONAL
        v2            TYPE simple OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.
ENDCLASS.


CLASS lhc_item IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( IsDelivered ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      ENTITY Item BY \_PurchaseOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED failed.

    " Items change with their order; goods are received on saved, ordered items that are still open
    result = VALUE #(
      FOR i IN items
      LET status     = VALUE #( orders[ KEY entity COMPONENTS PurchaseOrderUUID = i-PurchaseOrderUUID ]-Status OPTIONAL )
          changeable = COND #( WHEN status = lif_purchase_order=>status-created OR status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky                 = i-%tky
        %update              = changeable
        %delete              = changeable
        %action-receiveGoods = COND #( WHEN i-%is_draft = if_abap_behv=>mk-off
                                        AND status = lif_purchase_order=>status-ordered
                                        AND i-IsDelivered = abap_false
                                       THEN if_abap_behv=>fc-o-enabled
                                       ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " The goods receipt role follows in stage v1.0
    IF requested_authorizations-%action-receiveGoods = if_abap_behv=>mk-on.
      result-%action-receiveGoods = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-applyGoodsReceipt = if_abap_behv=>mk-on.
      result-%action-applyGoodsReceipt = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD receiveGoods.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      ENTITY Item BY \_PurchaseOrder
        FIELDS ( PurchaseOrder Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT keys INTO DATA(key).
      DATA(item) = items[ ItemUUID = key-ItemUUID ].
      DATA(order) = VALUE #( orders[ KEY entity COMPONENTS PurchaseOrderUUID = item-PurchaseOrderUUID ] OPTIONAL ).
      DATA(open_quantity) = CONV zvhb_quantity( item-Quantity - item-ReceivedQuantity ).

      DATA(message) = COND #(
        WHEN order-Status <> lif_purchase_order=>status-ordered
        THEN error( number = '019' v1 = order-PurchaseOrder )
        WHEN key-%param-Quantity <= 0
        THEN error( number = '017' )
        WHEN key-%param-Quantity > open_quantity
        THEN error( number = '018' v1 = open_quantity v2 = item-Item )
        ELSE post_goods_receipt( item           = item
                                 purchase_order = order-PurchaseOrder
                                 receipt        = CORRESPONDING #( key-%param ) ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = key-%tky ) TO failed-item.
        APPEND VALUE #( %tky                             = key-%tky
                        %msg                             = message
                        %path-purchaseorder-%is_draft    = key-%is_draft
                        %path-purchaseorder-PurchaseOrderUUID = key-PurchaseOrderUUID ) TO reported-item.
      ENDIF.
    ENDLOOP.

    " The received quantity follows when inventory raises GoodsReceiptPosted after the save
    result = VALUE #( FOR i IN items ( %tky = i-%tky %param = i ) ).
  ENDMETHOD.

  METHOD post_goods_receipt.
    MODIFY ENTITIES OF zvhb_r_materialdocument
      ENTITY MaterialDocument
        EXECUTE postGoodsMovement
        FROM VALUE #( ( %cid   = 'RECEIPT'
                        %param = VALUE #( MovementType      = c_goods_receipt
                                          Material          = item-Material
                                          Plant             = item-Plant
                                          StorageLocation   = item-StorageLocation
                                          Quantity          = receipt-Quantity
                                          ProductionDate    = receipt-ProductionDate
                                          PurchaseOrder     = purchase_order
                                          PurchaseOrderItem = item-Item ) ) )
      FAILED DATA(receipt_failed)
      REPORTED DATA(receipt_reported).

    IF receipt_failed IS NOT INITIAL.
      result = VALUE #( receipt_reported-materialdocument[ 1 ]-%msg OPTIONAL ).
    ENDIF.
  ENDMETHOD.

  METHOD applyGoodsReceipt.
    DATA order_uuids TYPE string_table.

    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( Quantity ReceivedQuantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( ReceivedQuantity IsDelivered )
        WITH VALUE #( FOR i IN items
                      LET received = CONV zvhb_quantity( i-ReceivedQuantity + keys[ ItemUUID = i-ItemUUID ]-%param-Quantity ) IN
                      ( %tky             = i-%tky
                        ReceivedQuantity = received
                        IsDelivered      = xsdbool( received >= i-Quantity ) ) ).

    order_uuids = VALUE #( FOR i IN items ( CONV string( i-PurchaseOrderUUID ) ) ).
    SORT order_uuids.
    DELETE ADJACENT DUPLICATES FROM order_uuids.
    update_order_status( order_uuids ).

    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(changed).
    result = VALUE #( FOR c IN changed ( %tky = c-%tky %param = c ) ).
  ENDMETHOD.

  METHOD update_order_status.
    DATA order_keys TYPE TABLE FOR READ IMPORT zvhb_r_purchaseorder\\purchaseorder.

    order_keys = VALUE #( FOR uuid IN order_uuids ( PurchaseOrderUUID = CONV sysuuid_x16( uuid )
                                                    %is_draft         = if_abap_behv=>mk-off ) ).

    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Status ) WITH order_keys
      RESULT DATA(orders)
      ENTITY PurchaseOrder BY \_Item
        FIELDS ( IsDelivered ) WITH CORRESPONDING #( order_keys )
      RESULT DATA(items).

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR o IN orders
                      ( %tky   = o-%tky
                        Status = COND #( WHEN REDUCE i( INIT open = 0
                                                        FOR i IN items USING KEY entity
                                                        WHERE ( PurchaseOrderUUID = o-PurchaseOrderUUID AND IsDelivered = abap_false )
                                                        NEXT open = open + 1 ) > 0
                                         THEN lif_purchase_order=>status-ordered
                                         ELSE lif_purchase_order=>status-completed ) ) ).
  ENDMETHOD.

  METHOD setItemDefaults.
    DATA updates TYPE TABLE FOR UPDATE zvhb_r_purchaseorder\\item.

    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( Item Plant StorageLocation DeliveryDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(new_items)
      ENTITY Item BY \_PurchaseOrder
        FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Item
        FIELDS ( Item ) WITH CORRESPONDING #( orders )
      RESULT DATA(all_items).

    " Items are numbered 00010, 00020 ... as in S/4HANA
    LOOP AT new_items INTO DATA(item).
      DATA(number) = REDUCE i( INIT last = 0
                               FOR existing IN all_items USING KEY entity
                               WHERE ( PurchaseOrderUUID = item-PurchaseOrderUUID )
                               NEXT last = nmax( val1 = last val2 = CONV i( existing-Item ) ) ) + defaults-item_step.
      ASSIGN all_items[ KEY id COMPONENTS %is_draft         = item-%is_draft
                                          PurchaseOrderUUID = item-PurchaseOrderUUID
                                          ItemUUID          = item-ItemUUID ] TO FIELD-SYMBOL(<numbered>).
      IF sy-subrc = 0.
        <numbered>-Item = number.
      ENDIF.

      APPEND VALUE #( %tky            = item-%tky
                      Item            = number
                      Currency        = VALUE #( orders[ KEY entity COMPONENTS PurchaseOrderUUID = item-PurchaseOrderUUID ]-Currency
                                                 OPTIONAL )
                      Plant           = COND #( WHEN item-Plant IS INITIAL THEN defaults-plant ELSE item-Plant )
                      StorageLocation = COND #( WHEN item-StorageLocation IS INITIAL
                                                THEN defaults-storage_location ELSE item-StorageLocation )
                      DeliveryDate    = COND #( WHEN item-DeliveryDate IS INITIAL
                                                THEN cl_abap_context_info=>get_system_date( ) + defaults-lead_time_days
                                                ELSE item-DeliveryDate ) ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( Item Currency Plant StorageLocation DeliveryDate ) WITH updates.
  ENDMETHOD.

  METHOD setUnit.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    IF items IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Material, BaseUnit FROM zvhb_r_material
      FOR ALL ENTRIES IN @items
      WHERE Material = @items-Material
      INTO TABLE @DATA(materials).

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( Unit )
        WITH VALUE #( FOR i IN items
                      ( %tky = i-%tky Unit = VALUE #( materials[ Material = i-Material ]-BaseUnit OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD calculateAmount.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( Quantity NetPrice ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      ENTITY Item BY \_PurchaseOrder
        FIELDS ( TotalAmount ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( NetAmount )
        WITH VALUE #( FOR i IN items ( %tky = i-%tky NetAmount = CONV zvhb_amount( i-Quantity * i-NetPrice ) ) ).

    " The order total is the sum of all item amounts, including the ones just changed
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Item
        FIELDS ( NetAmount ) WITH CORRESPONDING #( orders )
      RESULT DATA(all_items).

    MODIFY ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( TotalAmount )
        WITH VALUE #( FOR o IN orders
                      ( %tky        = o-%tky
                        TotalAmount = REDUCE zvhb_amount( INIT sum = CONV zvhb_amount( 0 )
                                                          FOR a IN all_items USING KEY entity
                                                          WHERE ( PurchaseOrderUUID = o-PurchaseOrderUUID )
                                                          NEXT sum = sum + a-NetAmount ) ) ).
  ENDMETHOD.

  METHOD validateItem.
    READ ENTITIES OF zvhb_r_purchaseorder IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky                                  = item-%tky
                      %state_area                           = 'ITEM'
                      %path-purchaseorder-%is_draft         = item-%is_draft
                      %path-purchaseorder-PurchaseOrderUUID = item-PurchaseOrderUUID ) TO reported-item.

      DATA(problem) = check_item( item ).
      IF problem IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = item-%tky ) TO failed-item.
      APPEND VALUE #( %tky                                  = item-%tky
                      %state_area                           = 'ITEM'
                      %msg                                  = error( number = problem-msgno v1 = problem-v1 )
                      %path-purchaseorder-%is_draft         = item-%is_draft
                      %path-purchaseorder-PurchaseOrderUUID = item-PurchaseOrderUUID
                      %element-Material        = COND #( WHEN problem-msgno BETWEEN '001' AND '003' THEN if_abap_behv=>mk-on )
                      %element-Quantity        = COND #( WHEN problem-msgno = '004' THEN if_abap_behv=>mk-on )
                      %element-DeliveryDate    = COND #( WHEN problem-msgno = '005' THEN if_abap_behv=>mk-on )
                      %element-Plant           = COND #( WHEN problem-msgno = '006' THEN if_abap_behv=>mk-on )
                      %element-StorageLocation = COND #( WHEN problem-msgno = '007' THEN if_abap_behv=>mk-on )
                      %element-NetPrice        = COND #( WHEN problem-msgno = '011' THEN if_abap_behv=>mk-on ) )
             TO reported-item.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_item.
    DATA(check) = NEW zcl_vhb_purchasing_check( ).

    result = check->check_material( item-Material ).
    IF result IS INITIAL AND item-Quantity <= 0.
      result-msgno = '004'.
    ENDIF.
    IF result IS INITIAL AND item-NetPrice <= 0.
      result-msgno = '011'.
    ENDIF.
    IF result IS INITIAL AND item-DeliveryDate < cl_abap_context_info=>get_system_date( ).
      result-msgno = '005'.
    ENDIF.
    IF result IS INITIAL.
      result = check->check_location( plant = item-Plant storage_location = item-StorageLocation ).
    ENDIF.
  ENDMETHOD.

  METHOD error.
    result = new_message( id       = lif_purchase_order=>c_msgid
                          number   = number
                          severity = if_abap_behv_message=>severity-error
                          v1       = v1
                          v2       = v2 ).
  ENDMETHOD.

ENDCLASS.

