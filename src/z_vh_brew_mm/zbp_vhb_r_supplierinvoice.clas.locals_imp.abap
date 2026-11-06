*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_supplier_invoice DEFINITION DEFERRED FOR TESTING.

"! Status values shared by the handlers of the supplier invoice
INTERFACE lif_invoice.
  CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MM'.

  CONSTANTS:
    "! Invoice status values of domain ZVHB_INV_STATUS
    BEGIN OF status,
      created  TYPE zvhb_inv_status VALUE 'NEW',
      blocked  TYPE zvhb_inv_status VALUE 'BLCK',
      posted   TYPE zvhb_inv_status VALUE 'POST',
      rejected TYPE zvhb_inv_status VALUE 'REJ',
    END OF status.

  CONSTANTS:
    "! Purchase order status values that allow an invoice
    BEGIN OF order_status,
      ordered   TYPE zvhb_po_status VALUE 'ORDR',
      completed TYPE zvhb_po_status VALUE 'DONE',
    END OF order_status.

  CONSTANTS:
    "! Results of view ZVHB_I_SupplierInvoiceMatch
    BEGIN OF match,
      ok       TYPE c LENGTH 4 VALUE 'OK',
      price    TYPE c LENGTH 4 VALUE 'PRIC',
      quantity TYPE c LENGTH 4 VALUE 'QUAN',
    END OF match.
ENDINTERFACE.


CLASS lhc_invoice DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_supplier_invoice.
  PRIVATE SECTION.
    TYPES tt_keys     TYPE TABLE FOR READ IMPORT zvhb_r_supplierinvoice\\invoice.
    TYPES tt_invoices TYPE TABLE FOR READ RESULT zvhb_r_supplierinvoice\\invoice.

    TYPES:
      "! Order item with what was received and what other invoices already charged
      BEGIN OF ty_open_item,
        ItemUUID         TYPE sysuuid_x16,
        Item             TYPE zvhb_po_item,
        Material         TYPE zvhb_material,
        Unit             TYPE zvhb_unit,
        Currency         TYPE zvhb_currency,
        NetPrice         TYPE zvhb_amount,
        ReceivedQuantity TYPE zvhb_quantity,
        InvoicedQuantity TYPE zvhb_quantity,
      END OF ty_open_item,
      tt_open_items TYPE STANDARD TABLE OF ty_open_item WITH EMPTY KEY.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Invoice RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Invoice RESULT result.

    METHODS post FOR MODIFY
      IMPORTING keys FOR ACTION Invoice~post RESULT result.

    METHODS release FOR MODIFY
      IMPORTING keys FOR ACTION Invoice~release RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION Invoice~reject RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Invoice~setDefaults.

    METHODS proposeItems FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Invoice~proposeItems.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Invoice~setNumber.

    METHODS validateOrder FOR VALIDATE ON SAVE
      IMPORTING keys FOR Invoice~validateOrder.

    METHODS validateReference FOR VALIDATE ON SAVE
      IMPORTING keys FOR Invoice~validateReference.

    METHODS validateItems FOR VALIDATE ON SAVE
      IMPORTING keys FOR Invoice~validateItems.

    "! Order items that still have received goods without an invoice
    METHODS get_open_items
      IMPORTING
        order_uuid    TYPE sysuuid_x16
      RETURNING
        VALUE(result) TYPE tt_open_items.

    "! Sets the status and returns the changed invoices
    METHODS set_status
      IMPORTING
        invoice_keys  TYPE tt_keys
        status        TYPE zvhb_inv_status
      RETURNING
        VALUE(result) TYPE tt_invoices.

    METHODS message
      IMPORTING
        number        TYPE symsgno
        severity      TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        v1            TYPE simple OPTIONAL
        v2            TYPE simple OPTIONAL
        v3            TYPE simple OPTIONAL
        v4            TYPE simple OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS get_number_range
      RETURNING
        VALUE(result) TYPE REF TO zif_vhb_number_range.
ENDCLASS.


CLASS lhc_invoice IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices)
      FAILED failed.

    " An invoice is entered and changed until it is posted; a blocked invoice waits for a decision
    result = VALUE #(
      FOR i IN invoices
      LET changeable = COND #( WHEN i-Status = lif_invoice=>status-created OR i-Status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )
          saved      = xsdbool( i-%is_draft = if_abap_behv=>mk-off )
          blocked    = COND #( WHEN saved = abap_true AND i-Status = lif_invoice=>status-blocked
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky            = i-%tky
        %update         = changeable
        %delete         = changeable
        %action-Edit    = changeable
        %assoc-_Item    = changeable
        %action-post    = COND #( WHEN saved = abap_true AND i-Status = lif_invoice=>status-created
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled )
        %action-release = blocked
        %action-reject  = blocked ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " The accounts payable role follows in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD post.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        FIELDS ( SupplierInvoice ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    IF invoices IS INITIAL.
      RETURN.
    ENDIF.

    " The 3-way match itself is calculated in CDS; only the items outside the tolerance come back
    SELECT InvoiceUUID, Item, MatchResult, PriceVariancePercent, QuantityExcess, Unit
      FROM zvhb_i_supplierinvoicematch
      FOR ALL ENTRIES IN @invoices
      WHERE InvoiceUUID = @invoices-InvoiceUUID
        AND MatchResult <> @lif_invoice=>match-ok
      INTO TABLE @DATA(mismatches).
    SORT mismatches BY InvoiceUUID Item.

    DATA updates TYPE TABLE FOR UPDATE zvhb_r_supplierinvoice\\invoice.

    LOOP AT invoices INTO DATA(invoice).
      DATA(mismatch) = VALUE #( mismatches[ InvoiceUUID = invoice-InvoiceUUID ] OPTIONAL ).

      APPEND VALUE #( %tky   = invoice-%tky
                      Status = COND #( WHEN mismatch IS INITIAL
                                       THEN lif_invoice=>status-posted
                                       ELSE lif_invoice=>status-blocked ) ) TO updates.

      APPEND VALUE #(
        %tky = invoice-%tky
        %msg = COND #(
          WHEN mismatch IS INITIAL
          THEN message( number   = '031'
                        severity = if_abap_behv_message=>severity-success
                        v1       = invoice-SupplierInvoice )
          WHEN mismatch-MatchResult = lif_invoice=>match-price
          THEN message( number   = '032'
                        severity = if_abap_behv_message=>severity-warning
                        v1       = invoice-SupplierInvoice
                        v2       = mismatch-Item
                        v3       = |{ CONV zvhb_percent( abs( mismatch-PriceVariancePercent ) ) DECIMALS = 2 }|
                        v4       = |{ zcl_vhb_purchasing_check=>c_price_tolerance DECIMALS = 0 }| )
          ELSE message( number   = '033'
                        severity = if_abap_behv_message=>severity-warning
                        v1       = invoice-SupplierInvoice
                        v2       = mismatch-Item
                        v3       = |{ mismatch-QuantityExcess NUMBER = USER } { mismatch-Unit }| ) ) )
        TO reported-invoice.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        UPDATE FIELDS ( Status ) WITH updates.

    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(changed).
    result = VALUE #( FOR c IN changed ( %tky = c-%tky %param = c ) ).
  ENDMETHOD.

  METHOD release.
    " The manual decision on a blocked invoice: the deviation is accepted and the invoice is paid
    DATA(invoices) = set_status( invoice_keys = CORRESPONDING #( keys )
                                 status       = lif_invoice=>status-posted ).
    reported-invoice = VALUE #( FOR i IN invoices
                                ( %tky = i-%tky
                                  %msg = message( number   = '034'
                                                  severity = if_abap_behv_message=>severity-success
                                                  v1       = i-SupplierInvoice ) ) ).
    result = VALUE #( FOR i IN invoices ( %tky = i-%tky %param = i ) ).
  ENDMETHOD.

  METHOD reject.
    DATA(invoices) = set_status( invoice_keys = CORRESPONDING #( keys )
                                 status       = lif_invoice=>status-rejected ).
    reported-invoice = VALUE #( FOR i IN invoices
                                ( %tky = i-%tky
                                  %msg = message( number   = '039'
                                                  severity = if_abap_behv_message=>severity-success
                                                  v1       = i-SupplierInvoice ) ) ).
    result = VALUE #( FOR i IN invoices ( %tky = i-%tky %param = i ) ).
  ENDMETHOD.

  METHOD set_status.
    MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN invoice_keys ( %tky = key-%tky Status = status ) ).

    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        ALL FIELDS WITH CORRESPONDING #( invoice_keys )
      RESULT result.
  ENDMETHOD.

  METHOD setDefaults.
    MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        UPDATE FIELDS ( Status InvoiceDate )
        WITH VALUE #( FOR key IN keys
                      ( %tky        = key-%tky
                        Status      = lif_invoice=>status-created
                        InvoiceDate = cl_abap_context_info=>get_system_date( ) ) ).
  ENDMETHOD.

  METHOD proposeItems.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        FIELDS ( PurchaseOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices)
      ENTITY Invoice BY \_Item
        FIELDS ( ItemUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(old_items).

    " Another purchase order replaces the whole proposal
    IF old_items IS NOT INITIAL.
      MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
        ENTITY Item
          DELETE FROM VALUE #( FOR old IN old_items ( %tky = old-%tky ) ).
    ENDIF.

    LOOP AT invoices INTO DATA(invoice).
      SELECT SINGLE PurchaseOrderUUID, Supplier, Currency, Status FROM zvhb_r_purchaseorder
        WHERE PurchaseOrder = @invoice-PurchaseOrder
        INTO @DATA(order).
      IF sy-subrc <> 0
         OR ( order-Status <> lif_invoice=>order_status-ordered AND order-Status <> lif_invoice=>order_status-completed ).
        " validateOrder reports the order; the invoice keeps no supplier of a wrong order
        MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
          ENTITY Invoice
            UPDATE FIELDS ( Supplier Currency )
            WITH VALUE #( ( %tky = invoice-%tky ) ).
        CLEAR order.
        CONTINUE.
      ENDIF.

      " Like MIRO: every received but not yet invoiced quantity is proposed at the order price
      DATA(open_items) = get_open_items( order-PurchaseOrderUUID ).

      MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
        ENTITY Invoice
          UPDATE FIELDS ( Supplier Currency )
          WITH VALUE #( ( %tky = invoice-%tky Supplier = order-Supplier Currency = order-Currency ) )
          CREATE BY \_Item
          FIELDS ( Item OrderItemUUID PurchaseOrder PurchaseOrderItem Material Unit Quantity Currency NetPrice )
          WITH VALUE #( ( %tky    = invoice-%tky
                          %target = VALUE #( FOR open IN open_items INDEX INTO i
                                             ( %cid              = |ITEM{ i }|
                                               %is_draft         = invoice-%is_draft
                                               Item              = i
                                               OrderItemUUID     = open-ItemUUID
                                               PurchaseOrder     = invoice-PurchaseOrder
                                               PurchaseOrderItem = open-Item
                                               Material          = open-Material
                                               Unit              = open-Unit
                                               Quantity          = open-ReceivedQuantity - open-InvoicedQuantity
                                               Currency          = order-Currency
                                               NetPrice          = open-NetPrice ) ) ) ).
      CLEAR order.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_open_items.
    DATA order_items TYPE tt_open_items.

    SELECT item~ItemUUID, item~Item, item~Material, item~Unit, item~Currency, item~NetPrice,
           history~ReceivedQuantity, invoiced~InvoicedQuantity
      FROM zvhb_r_purchaseorderitem AS item
        INNER JOIN zvhb_r_purchaseorder AS header
          ON header~PurchaseOrderUUID = item~PurchaseOrderUUID
        LEFT OUTER JOIN zvhb_i_purchaseorderhistory AS history
          ON  history~PurchaseOrder     = header~PurchaseOrder
          AND history~PurchaseOrderItem = item~Item
        LEFT OUTER JOIN zvhb_i_invoicedquantity AS invoiced
          ON invoiced~OrderItemUUID = item~ItemUUID
      WHERE item~PurchaseOrderUUID = @order_uuid
      ORDER BY item~Item
      INTO CORRESPONDING FIELDS OF TABLE @order_items.

    result = VALUE #( FOR o IN order_items
                      WHERE ( ReceivedQuantity IS NOT INITIAL )
                      LET open_quantity = CONV zvhb_quantity( o-ReceivedQuantity - o-InvoicedQuantity ) IN
                      ( LINES OF COND tt_open_items( WHEN open_quantity > 0
                                                     THEN VALUE #( ( CORRESPONDING #( o ) ) ) ) ) ).
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        FIELDS ( SupplierInvoice ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    DELETE invoices WHERE SupplierInvoice IS NOT INITIAL.

    LOOP AT invoices ASSIGNING FIELD-SYMBOL(<invoice>).
      TRY.
          <invoice>-SupplierInvoice = get_number_range( )->get_next( zif_vhb_number_range=>objects-supplier_invoice ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <invoice>-%tky %msg = message( number = '035' v1 = exception->get_text( ) ) )
                 TO reported-invoice.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        UPDATE FIELDS ( SupplierInvoice )
        WITH VALUE #( FOR i IN invoices WHERE ( SupplierInvoice IS NOT INITIAL )
                      ( %tky = i-%tky SupplierInvoice = i-SupplierInvoice ) ).
  ENDMETHOD.

  METHOD validateOrder.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        FIELDS ( PurchaseOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    LOOP AT invoices INTO DATA(invoice).
      APPEND VALUE #( %tky = invoice-%tky %state_area = 'ORDER' ) TO reported-invoice.

      SELECT SINGLE status FROM zvhb_pohdr
        WHERE purchase_order = @invoice-PurchaseOrder
        INTO @DATA(order_status).
      DATA(found) = xsdbool( sy-subrc = 0 AND invoice-PurchaseOrder IS NOT INITIAL ).

      DATA(problem) = COND #(
        WHEN found = abap_false
        THEN message( number = '021' v1 = invoice-PurchaseOrder )
        WHEN order_status <> lif_invoice=>order_status-ordered AND order_status <> lif_invoice=>order_status-completed
        THEN message( number = '022' v1 = invoice-PurchaseOrder ) ).
      CLEAR order_status.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = invoice-%tky ) TO failed-invoice.
        APPEND VALUE #( %tky                   = invoice-%tky
                        %state_area            = 'ORDER'
                        %msg                   = problem
                        %element-PurchaseOrder = if_abap_behv=>mk-on ) TO reported-invoice.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateReference.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        FIELDS ( Supplier InvoiceReference InvoiceDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT invoices INTO DATA(invoice).
      APPEND VALUE #( %tky = invoice-%tky %state_area = 'REFERENCE' ) TO reported-invoice.

      " A supplier invoice must not be entered twice, otherwise it would be paid twice
      SELECT SINGLE supplier_invoice FROM zvhb_sinvhdr
        WHERE supplier          = @invoice-Supplier
          AND invoice_reference = @invoice-InvoiceReference
          AND invoice_uuid     <> @invoice-InvoiceUUID
          AND status           <> @lif_invoice=>status-rejected
        INTO @DATA(duplicate).
      DATA(is_duplicate) = xsdbool( sy-subrc = 0 ).

      DATA(problem) = COND #(
        WHEN invoice-InvoiceReference IS INITIAL
        THEN message( number = '024' )
        WHEN is_duplicate = abap_true
        THEN message( number = '025' v1 = invoice-Supplier v2 = invoice-InvoiceReference v3 = duplicate )
        WHEN invoice-InvoiceDate > today
        THEN message( number = '026' v1 = invoice-InvoiceDate ) ).
      CLEAR duplicate.

      IF problem IS BOUND.
        APPEND VALUE #( %tky                      = invoice-%tky ) TO failed-invoice.
        APPEND VALUE #( %tky                      = invoice-%tky
                        %state_area               = 'REFERENCE'
                        %msg                      = problem
                        %element-InvoiceReference = COND #( WHEN invoice-InvoiceDate <= today THEN if_abap_behv=>mk-on )
                        %element-InvoiceDate      = COND #( WHEN invoice-InvoiceDate > today THEN if_abap_behv=>mk-on ) )
               TO reported-invoice.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateItems.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        FIELDS ( PurchaseOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices)
      ENTITY Invoice BY \_Item
        FIELDS ( Item ) WITH CORRESPONDING #( keys )
      LINK DATA(links).

    LOOP AT invoices INTO DATA(invoice).
      APPEND VALUE #( %tky = invoice-%tky %state_area = 'ITEMS' ) TO reported-invoice.

      IF NOT line_exists( links[ KEY id COMPONENTS source-%tky = invoice-%tky ] )
         AND invoice-PurchaseOrder IS NOT INITIAL.
        APPEND VALUE #( %tky = invoice-%tky ) TO failed-invoice.
        APPEND VALUE #( %tky        = invoice-%tky
                        %state_area = 'ITEMS'
                        %msg        = message( number = '023' v1 = invoice-PurchaseOrder ) ) TO reported-invoice.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD message.
    result = new_message( id       = lif_invoice=>c_msgid
                          number   = number
                          severity = severity
                          v1       = v1
                          v2       = v2
                          v3       = v3
                          v4       = v4 ).
  ENDMETHOD.

  METHOD get_number_range.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.
    result = number_range.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_supplier_invoice.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.

    METHODS calculateAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculateAmount.

    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItem.

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
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Item
        FIELDS ( InvoiceUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      ENTITY Item BY \_Invoice
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices)
      FAILED failed.

    " Items change with their invoice
    result = VALUE #(
      FOR i IN items
      LET status     = VALUE #( invoices[ KEY entity COMPONENTS InvoiceUUID = i-InvoiceUUID ]-Status OPTIONAL )
          changeable = COND #( WHEN status = lif_invoice=>status-created OR status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky    = i-%tky
        %update = changeable
        %delete = changeable ) ).
  ENDMETHOD.

  METHOD calculateAmount.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Item
        FIELDS ( Quantity NetPrice ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      ENTITY Item BY \_Invoice
        FIELDS ( TotalAmount ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( NetAmount )
        WITH VALUE #( FOR i IN items ( %tky = i-%tky NetAmount = CONV zvhb_amount( i-Quantity * i-NetPrice ) ) ).

    " The invoice total is the sum of all item amounts, including the ones just changed
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice BY \_Item
        FIELDS ( NetAmount ) WITH CORRESPONDING #( invoices )
      RESULT DATA(all_items).

    MODIFY ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Invoice
        UPDATE FIELDS ( TotalAmount )
        WITH VALUE #( FOR inv IN invoices
                      ( %tky        = inv-%tky
                        TotalAmount = REDUCE zvhb_amount( INIT sum = CONV zvhb_amount( 0 )
                                                          FOR a IN all_items USING KEY entity
                                                          WHERE ( InvoiceUUID = inv-InvoiceUUID )
                                                          NEXT sum = sum + a-NetAmount ) ) ).
  ENDMETHOD.

  METHOD validateItem.
    READ ENTITIES OF zvhb_r_supplierinvoice IN LOCAL MODE
      ENTITY Item
        FIELDS ( Item Quantity NetPrice Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      ENTITY Item BY \_Invoice
        FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky                          = item-%tky
                      %state_area                   = 'ITEM'
                      %path-invoice-%is_draft       = item-%is_draft
                      %path-invoice-InvoiceUUID     = item-InvoiceUUID ) TO reported-item.

      DATA(currency) = VALUE #( invoices[ KEY entity COMPONENTS InvoiceUUID = item-InvoiceUUID ]-Currency OPTIONAL ).

      DATA(problem) = COND #(
        WHEN item-Quantity <= 0 THEN error( number = '027' v1 = item-Item )
        WHEN item-NetPrice <= 0 THEN error( number = '028' v1 = item-Item )
        WHEN item-Currency <> currency THEN error( number = '029' v1 = item-Item v2 = currency ) ).

      IF problem IS NOT BOUND.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = item-%tky ) TO failed-item.
      APPEND VALUE #( %tky                      = item-%tky
                      %state_area               = 'ITEM'
                      %msg                      = problem
                      %path-invoice-%is_draft   = item-%is_draft
                      %path-invoice-InvoiceUUID = item-InvoiceUUID
                      %element-Quantity         = COND #( WHEN item-Quantity <= 0 THEN if_abap_behv=>mk-on )
                      %element-NetPrice         = COND #( WHEN item-Quantity > 0 AND item-NetPrice <= 0
                                                          THEN if_abap_behv=>mk-on )
                      %element-Currency         = COND #( WHEN item-Quantity > 0 AND item-NetPrice > 0
                                                          THEN if_abap_behv=>mk-on ) ) TO reported-item.
    ENDLOOP.
  ENDMETHOD.

  METHOD error.
    result = new_message( id       = lif_invoice=>c_msgid
                          number   = number
                          severity = if_abap_behv_message=>severity-error
                          v1       = v1
                          v2       = v2 ).
  ENDMETHOD.

ENDCLASS.

