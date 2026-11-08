*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_material_document DEFINITION DEFERRED FOR TESTING.

CLASS lhc_material_document DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_material_document.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_IM'.

    CONSTANTS:
      "! Movement types that can be posted with the action postGoodsMovement
      BEGIN OF movement_types,
        goods_receipt    TYPE zvhb_movement_type VALUE '101',
        production_issue TYPE zvhb_movement_type VALUE '261',
        transfer         TYPE zvhb_movement_type VALUE '311',
        scrapping        TYPE zvhb_movement_type VALUE '551',
        initial_entry    TYPE zvhb_movement_type VALUE '561',
        delivery         TYPE zvhb_movement_type VALUE '601',
        customer_return  TYPE zvhb_movement_type VALUE '653',
      END OF movement_types.

    TYPES ty_movement TYPE zvhb_d_goodsmovement.

    TYPES:
      BEGIN OF ty_material,
        Material       TYPE zvhb_material,
        BaseUnit       TYPE zvhb_unit,
        IsBatchManaged TYPE abap_boolean,
        IsActive       TYPE abap_boolean,
      END OF ty_material.

    TYPES:
      BEGIN OF ty_header,
        PostingDate      TYPE d,
        HeaderText       TYPE zvhb_description,
        ReversedDocument TYPE zvhb_matdoc,
      END OF ty_header.

    TYPES:
      BEGIN OF ty_item,
        MovementType      TYPE zvhb_movement_type,
        Material          TYPE zvhb_material,
        Plant             TYPE zvhb_plant,
        StorageLocation   TYPE zvhb_storage_loc,
        ReceivingLocation TYPE zvhb_storage_loc,
        Batch             TYPE zvhb_batch,
        Unit              TYPE zvhb_unit,
        Quantity          TYPE zvhb_quantity,
        ReversedItem      TYPE zvhb_matdoc_item,
        PurchaseOrder     TYPE zvhb_purch_order,
        PurchaseOrderItem TYPE zvhb_po_item,
        BrewOrder         TYPE zvhb_brew_order,
      END OF ty_item,
      tt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR MaterialDocument RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MaterialDocument RESULT result.

    METHODS postGoodsMovement FOR MODIFY
      IMPORTING keys FOR ACTION MaterialDocument~postGoodsMovement.

    METHODS reverse FOR MODIFY
      IMPORTING keys FOR ACTION MaterialDocument~reverse.

    "! Checks one goods movement, creates a new batch if needed and creates the document
    "! @parameter pid    | Preliminary ID of the new document
    "! @parameter result | First error, or not bound if the document was created
    METHODS post
      IMPORTING
        movement      TYPE ty_movement
      EXPORTING
        pid           TYPE abp_behv_pid
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS check_master_data
      IMPORTING
        movement      TYPE ty_movement
      EXPORTING
        material      TYPE ty_material
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! Checks the batch; an empty batch means a new batch for receipts and a FEFO proposal for issues
    METHODS check_batch
      IMPORTING
        material      TYPE ty_material
      EXPORTING
        new_batch     TYPE abap_boolean
      CHANGING
        movement      TYPE ty_movement
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! First expired, first out: the free, unexpired batch with the earliest best-before date
    METHODS propose_fefo_batch
      CHANGING
        movement      TYPE ty_movement
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS check_stock
      IMPORTING
        movement      TYPE ty_movement
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS create_batch
      CHANGING
        movement      TYPE ty_movement
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS check_reversal
      IMPORTING
        document      TYPE zvhb_matdoc
        reversed      TYPE zvhb_matdoc
        items         TYPE tt_items
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! Mirror item of a reversal document: 101 becomes 102, 261 becomes 262 and so on
    METHODS reversal_of
      IMPORTING
        item          TYPE ty_item
        item_number   TYPE zvhb_matdoc_item
      RETURNING
        VALUE(result) TYPE ty_item.

    METHODS create_document
      IMPORTING
        header        TYPE ty_header
        items         TYPE tt_items
      RETURNING
        VALUE(result) TYPE abp_behv_pid.

    METHODS is_issue
      IMPORTING
        movement_type TYPE zvhb_movement_type
      RETURNING
        VALUE(result) TYPE abap_boolean.

    METHODS error
      IMPORTING
        number        TYPE symsgno
        v1            TYPE simple OPTIONAL
        v2            TYPE simple OPTIONAL
        v3            TYPE simple OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS get_number_range
      RETURNING
        VALUE(result) TYPE REF TO zif_vhb_number_range.
ENDCLASS.


CLASS lhc_material_document IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_materialdocument IN LOCAL MODE
      ENTITY MaterialDocument
        FIELDS ( ReversedDocument ) WITH CORRESPONDING #( keys )
      RESULT DATA(documents)
      FAILED failed.

    IF documents IS INITIAL.
      RETURN.
    ENDIF.

    SELECT reversed_document FROM zvhb_mdochdr
      FOR ALL ENTRIES IN @documents
      WHERE reversed_document = @documents-MaterialDocument
      INTO TABLE @DATA(reversals).

    " A document is reversed once; a reversal itself cannot be reversed
    result = VALUE #( FOR document IN documents
                      ( %tky            = document-%tky
                        %action-reverse = COND #( WHEN document-ReversedDocument IS INITIAL
                                                   AND NOT line_exists( reversals[ reversed_document = document-MaterialDocument ] )
                                                  THEN if_abap_behv=>fc-o-enabled
                                                  ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by plant follows in stage v1.0 together with authorization object ZVHB_PLANT
    IF requested_authorizations-%action-postGoodsMovement = if_abap_behv=>mk-on.
      result-%action-postGoodsMovement = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-reverse = if_abap_behv=>mk-on.
      result-%action-reverse = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD postGoodsMovement.
    DATA pid TYPE abp_behv_pid.

    LOOP AT keys INTO DATA(key).
      CLEAR pid.
      DATA(message) = post( EXPORTING movement = key-%param
                            IMPORTING pid      = pid ).

      IF message IS BOUND.
        APPEND VALUE #( %cid = key-%cid ) TO failed-materialdocument.
        APPEND VALUE #( %cid = key-%cid %msg = message ) TO reported-materialdocument.
      ELSE.
        APPEND VALUE #( %cid = key-%cid %pid = pid ) TO mapped-materialdocument.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD post.
    DATA material TYPE ty_material.
    DATA new_batch TYPE abap_boolean.

    DATA(movement_data) = movement.
    IF movement_data-PostingDate IS INITIAL.
      movement_data-PostingDate = cl_abap_context_info=>get_system_date( ).
    ENDIF.

    result = check_master_data( EXPORTING movement = movement_data
                                IMPORTING material = material ).
    IF result IS NOT BOUND.
      result = check_batch( EXPORTING material  = material
                            IMPORTING new_batch = new_batch
                            CHANGING  movement  = movement_data ).
    ENDIF.
    IF result IS NOT BOUND AND new_batch = abap_false.
      result = check_stock( movement_data ).
    ENDIF.
    IF result IS NOT BOUND AND new_batch = abap_true.
      result = create_batch( CHANGING movement = movement_data ).
    ENDIF.
    IF result IS BOUND.
      RETURN.
    ENDIF.

    pid = create_document(
      header = VALUE #( PostingDate = movement_data-PostingDate HeaderText = movement_data-HeaderText )
      items  = VALUE #( ( MovementType      = movement_data-MovementType
                          Material          = movement_data-Material
                          Plant             = movement_data-Plant
                          StorageLocation   = movement_data-StorageLocation
                          ReceivingLocation = movement_data-ReceivingLocation
                          Batch             = movement_data-Batch
                          Unit              = material-BaseUnit
                          Quantity          = movement_data-Quantity
                          PurchaseOrder     = movement_data-PurchaseOrder
                          PurchaseOrderItem = movement_data-PurchaseOrderItem
                          BrewOrder         = movement_data-BrewOrder ) ) ).
  ENDMETHOD.

  METHOD check_master_data.
    CASE movement-MovementType.
      WHEN movement_types-goods_receipt OR movement_types-production_issue OR movement_types-transfer
        OR movement_types-scrapping OR movement_types-initial_entry OR movement_types-delivery
        OR movement_types-customer_return.
      WHEN OTHERS.
        result = error( number = '001' v1 = movement-MovementType ).
        RETURN.
    ENDCASE.

    SELECT SINGLE Material, BaseUnit, IsBatchManaged, IsActive FROM zvhb_r_material
      WHERE Material = @movement-Material
      INTO CORRESPONDING FIELDS OF @material.
    DATA(found) = xsdbool( sy-subrc = 0 ).

    result = COND #(
      WHEN found = abap_false
      THEN error( number = '002' v1 = movement-Material )
      WHEN material-IsActive = abap_false
      THEN error( number = '003' v1 = movement-Material )
      WHEN NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant value = movement-Plant )
      THEN error( number = '004' v1 = movement-Plant )
      WHEN NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-storage_location
                                               value  = movement-StorageLocation )
      THEN error( number = '005' v1 = movement-StorageLocation )
      WHEN movement-MovementType = movement_types-transfer
       AND (    movement-ReceivingLocation = movement-StorageLocation
             OR NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-storage_location
                                                    value  = movement-ReceivingLocation ) )
      THEN error( number = '013' )
      WHEN movement-Quantity <= 0
      THEN error( number = '006' ) ).
  ENDMETHOD.

  METHOD check_batch.
    new_batch = abap_false.

    IF material-IsBatchManaged = abap_false.
      IF movement-Batch IS NOT INITIAL.
        result = error( number = '008' v1 = movement-Material ).
      ENDIF.
      RETURN.
    ENDIF.

    IF movement-Batch IS INITIAL.
      CASE movement-MovementType.
        WHEN movement_types-goods_receipt OR movement_types-initial_entry.
          new_batch = abap_true.
        WHEN movement_types-scrapping OR movement_types-customer_return.
          result = error( number = '007' v1 = movement-Material ).
        WHEN OTHERS.
          result = propose_fefo_batch( CHANGING movement = movement ).
      ENDCASE.
      RETURN.
    ENDIF.

    SELECT SINGLE ExpiryDate FROM zvhb_r_batch
      WHERE Material = @movement-Material
        AND Batch    = @movement-Batch
      INTO @DATA(expiry_date).

    IF sy-subrc <> 0.
      result = error( number = '009' v1 = movement-Batch v2 = movement-Material ).
    ELSEIF is_issue( movement-MovementType ) = abap_true
       AND movement-MovementType <> movement_types-scrapping
       AND expiry_date IS NOT INITIAL
       AND expiry_date < cl_abap_context_info=>get_system_date( ).
      result = error( number = '010' v1 = movement-Batch v2 = |{ expiry_date DATE = ISO }| ).
    ENDIF.
  ENDMETHOD.

  METHOD propose_fefo_batch.
    SELECT FROM zvhb_i_fefobatch
      FIELDS Batch
      WHERE Material        = @movement-Material
        AND Plant           = @movement-Plant
        AND StorageLocation = @movement-StorageLocation
        AND FreeQuantity   >= @movement-Quantity
      ORDER BY ExpiryDate, Batch
      INTO TABLE @DATA(candidates)
      UP TO 1 ROWS.

    IF candidates IS INITIAL.
      result = error( number = '012' v1 = movement-Material v2 = movement-Quantity v3 = movement-StorageLocation ).
    ELSE.
      movement-Batch = candidates[ 1 ]-Batch.
    ENDIF.
  ENDMETHOD.

  METHOD check_stock.
    IF is_issue( movement-MovementType ) = abap_false.
      RETURN.
    ENDIF.

    SELECT SINGLE FreeQuantity, TotalQuantity FROM zvhb_i_stock
      WHERE Material        = @movement-Material
        AND Plant           = @movement-Plant
        AND StorageLocation = @movement-StorageLocation
        AND Batch           = @movement-Batch
      INTO @DATA(stock).

    " Scrapping may also take blocked stock, all other issues only free stock
    DATA(available) = COND zvhb_quantity( WHEN movement-MovementType = movement_types-scrapping
                                          THEN stock-TotalQuantity
                                          ELSE stock-FreeQuantity ).
    IF available < movement-Quantity.
      result = error( number = '011' v1 = available v2 = movement-Material v3 = movement-StorageLocation ).
    ENDIF.
  ENDMETHOD.

  METHOD create_batch.
    TRY.
        movement-Batch = get_number_range( )->get_next( zif_vhb_number_range=>objects-batch ).
      CATCH zcx_vhb_number_range INTO DATA(exception).
        result = error( number = '017' v1 = exception->get_text( ) ).
        RETURN.
    ENDTRY.

    MODIFY ENTITIES OF zvhb_r_batch
      ENTITY Batch
        CREATE FIELDS ( Material Batch ProductionDate )
        WITH VALUE #( ( %cid           = 'BATCH'
                        Material       = movement-Material
                        Batch          = movement-Batch
                        ProductionDate = COND #( WHEN movement-ProductionDate IS INITIAL
                                                 THEN movement-PostingDate
                                                 ELSE movement-ProductionDate ) ) )
      FAILED DATA(batch_failed)
      REPORTED DATA(batch_reported).

    IF batch_failed IS NOT INITIAL.
      result = VALUE #( batch_reported-batch[ 1 ]-%msg OPTIONAL ).
    ENDIF.
  ENDMETHOD.

  METHOD reverse.
    READ ENTITIES OF zvhb_r_materialdocument IN LOCAL MODE
      ENTITY MaterialDocument
        FIELDS ( ReversedDocument ) WITH CORRESPONDING #( keys )
      RESULT DATA(documents)
      ENTITY MaterialDocument BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT keys INTO DATA(key).
      DATA(reversal_items) = VALUE tt_items( FOR item IN items WHERE ( MaterialDocument = key-MaterialDocument )
                                             ( reversal_of( item        = CORRESPONDING #( item )
                                                            item_number = item-Item ) ) ).

      DATA(message) = check_reversal(
        document = key-MaterialDocument
        reversed = VALUE #( documents[ MaterialDocument = key-MaterialDocument ]-ReversedDocument OPTIONAL )
        items    = reversal_items ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = key-%tky ) TO failed-materialdocument.
        APPEND VALUE #( %tky = key-%tky %msg = message ) TO reported-materialdocument.
        CONTINUE.
      ENDIF.

      DATA(pid) = create_document( header = VALUE #( PostingDate      = cl_abap_context_info=>get_system_date( )
                                                     ReversedDocument = key-MaterialDocument )
                                   items  = reversal_items ).
      APPEND VALUE #( %cid = key-%cid %pid = pid ) TO mapped-materialdocument.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_reversal.
    IF reversed IS NOT INITIAL.
      result = error( number = '015' v1 = document ).
      RETURN.
    ENDIF.

    SELECT SINGLE @abap_true FROM zvhb_mdochdr
      WHERE reversed_document = @document
      INTO @DATA(already_reversed).
    IF already_reversed = abap_true.
      result = error( number = '014' v1 = document ).
      RETURN.
    ENDIF.

    " Reversing a receipt takes the stock out again, so it must still be there
    LOOP AT items INTO DATA(item) WHERE MovementType = '102' OR MovementType = '312' OR MovementType = '562'.
      SELECT SINGLE FreeQuantity FROM zvhb_i_stock
        WHERE Material        = @item-Material
          AND Plant           = @item-Plant
          AND StorageLocation = @( COND #( WHEN item-MovementType = '312' THEN item-ReceivingLocation ELSE item-StorageLocation ) )
          AND Batch           = @item-Batch
        INTO @DATA(free_quantity).
      IF free_quantity < item-Quantity.
        result = error( number = '018' v1 = item-Material ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD reversal_of.
    result = item.
    result-MovementType = SWITCH #( item-MovementType
                                    WHEN movement_types-goods_receipt    THEN '102'
                                    WHEN movement_types-production_issue THEN '262'
                                    WHEN movement_types-transfer         THEN '312'
                                    WHEN movement_types-scrapping        THEN '552'
                                    WHEN movement_types-initial_entry    THEN '562'
                                    WHEN movement_types-delivery         THEN '602'
                                    WHEN movement_types-customer_return  THEN '654' ).
    result-ReversedItem = item_number.
  ENDMETHOD.

  METHOD create_document.
    MODIFY ENTITIES OF zvhb_r_materialdocument IN LOCAL MODE
      ENTITY MaterialDocument
        CREATE FIELDS ( PostingDate HeaderText ReversedDocument )
        WITH VALUE #( ( %cid             = 'DOCUMENT'
                        PostingDate      = header-PostingDate
                        HeaderText       = header-HeaderText
                        ReversedDocument = header-ReversedDocument ) )
        CREATE BY \_Item
        FIELDS ( MovementType Material Plant StorageLocation ReceivingLocation Batch Unit Quantity ReversedItem
                 PurchaseOrder PurchaseOrderItem BrewOrder )
        WITH VALUE #( ( %cid_ref = 'DOCUMENT'
                        %target  = VALUE #( FOR item IN items INDEX INTO i
                                            ( %cid              = |ITEM{ i }|
                                              MovementType      = item-MovementType
                                              Material          = item-Material
                                              Plant             = item-Plant
                                              StorageLocation   = item-StorageLocation
                                              ReceivingLocation = item-ReceivingLocation
                                              Batch             = item-Batch
                                              Unit              = item-Unit
                                              Quantity          = item-Quantity
                                              ReversedItem      = item-ReversedItem
                                              PurchaseOrder     = item-PurchaseOrder
                                              PurchaseOrderItem = item-PurchaseOrderItem
                                              BrewOrder         = item-BrewOrder ) ) ) )
      MAPPED DATA(created).

    result = created-materialdocument[ 1 ]-%pid.
  ENDMETHOD.

  METHOD is_issue.
    result = xsdbool( movement_type = movement_types-production_issue
                   OR movement_type = movement_types-transfer
                   OR movement_type = movement_types-scrapping
                   OR movement_type = movement_types-delivery ).
  ENDMETHOD.

  METHOD error.
    result = new_message( id       = c_msgid
                          number   = number
                          severity = if_abap_behv_message=>severity-error
                          v1       = v1
                          v2       = v2
                          v3       = v3 ).
  ENDMETHOD.

  METHOD get_number_range.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.
    result = number_range.
  ENDMETHOD.

ENDCLASS.


"! Late numbering and the insert-only save of the material document journal
CLASS lsc_material_document DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS adjust_numbers REDEFINITION.
    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_counter,
        pid  TYPE abp_behv_pid,
        item TYPE zvhb_matdoc_item,
      END OF ty_counter,
      tt_counters TYPE HASHED TABLE OF ty_counter WITH UNIQUE KEY pid.

    TYPES tt_receipt_events TYPE TABLE FOR EVENT zvhb_r_materialdocument~GoodsReceiptPosted.

    CONSTANTS:
      "! Movement types published with the event GoodsReceiptPosted
      BEGIN OF receipt_types,
        receipt  TYPE zvhb_movement_type VALUE '101',
        reversal TYPE zvhb_movement_type VALUE '102',
      END OF receipt_types.
ENDCLASS.


CLASS lsc_material_document IMPLEMENTATION.

  METHOD adjust_numbers.
    DATA counters TYPE tt_counters.
    DATA(number_range) = CAST zif_vhb_number_range( NEW zcl_vhb_number_range( ) ).

    LOOP AT mapped-materialdocument ASSIGNING FIELD-SYMBOL(<document>).
      TRY.
          <document>-MaterialDocument = number_range->get_next( zif_vhb_number_range=>objects-material_document ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %pid = <document>-%pid
                          %msg = new_message( id       = 'ZVHB_IM'
                                              number   = '016'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = exception->get_text( ) ) ) TO reported-materialdocument.
      ENDTRY.
    ENDLOOP.

    IF mapped-item IS INITIAL.
      RETURN.
    ENDIF.

    " Items take the number of their document and are counted 0001, 0002 ... per document
    READ ENTITIES OF zvhb_r_materialdocument IN LOCAL MODE
      ENTITY Item BY \_MaterialDocument
        FROM VALUE #( FOR item IN mapped-item ( %pid = item-%pid %key = item-%tmp ) )
      LINK DATA(links).

    LOOP AT mapped-item ASSIGNING FIELD-SYMBOL(<item>).
      DATA(document_pid) = links[ source-%pid = <item>-%pid ]-target-%pid.
      ASSIGN counters[ pid = document_pid ] TO FIELD-SYMBOL(<counter>).
      IF sy-subrc <> 0.
        INSERT VALUE #( pid = document_pid ) INTO TABLE counters ASSIGNING <counter>.
      ENDIF.
      <counter>-item += 1.

      <item>-MaterialDocument = mapped-materialdocument[ %pid = document_pid ]-MaterialDocument.
      <item>-Item             = <counter>-item.
    ENDLOOP.
  ENDMETHOD.

  METHOD save_modified.
    DATA headers TYPE STANDARD TABLE OF zvhb_mdochdr WITH EMPTY KEY.
    DATA items TYPE STANDARD TABLE OF zvhb_mdocitm WITH EMPTY KEY.
    DATA now TYPE timestampl.

    " Only inserts: the BO has no update and no delete, a posted document never changes
    IF create-materialdocument IS NOT INITIAL.
      GET TIME STAMP FIELD now.
      headers = CORRESPONDING #( create-materialdocument MAPPING FROM ENTITY ).
      DATA(user) = cl_abap_context_info=>get_user_technical_name( ).
      MODIFY headers FROM VALUE #( created_by = user created_at = now ) TRANSPORTING created_by created_at
        WHERE created_by IS INITIAL.
      INSERT zvhb_mdochdr FROM TABLE @headers.
    ENDIF.

    IF create-item IS NOT INITIAL.
      items = CORRESPONDING #( create-item MAPPING FROM ENTITY ).
      INSERT zvhb_mdocitm FROM TABLE @items.
    ENDIF.

    " Purchasing updates the received quantity of the purchase order, quality management opens an
    " inspection lot for the new batch; only receipts from a purchase order or a brew order are published
    DATA(receipts) = VALUE tt_receipt_events(
      FOR item IN create-item
      WHERE ( ( MovementType = receipt_types-receipt OR MovementType = receipt_types-reversal )
          AND ( PurchaseOrder IS NOT INITIAL OR BrewOrder IS NOT INITIAL ) )
      ( MaterialDocument = item-MaterialDocument
        %param           = VALUE #( Item              = item-Item
                                    MovementType      = item-MovementType
                                    PurchaseOrder     = item-PurchaseOrder
                                    PurchaseOrderItem = item-PurchaseOrderItem
                                    BrewOrder         = item-BrewOrder
                                    Material          = item-Material
                                    Batch             = item-Batch
                                    Plant             = item-Plant
                                    StorageLocation   = item-StorageLocation
                                    Unit              = item-Unit
                                    Quantity          = item-Quantity ) ) ).
    IF receipts IS NOT INITIAL.
      RAISE ENTITY EVENT zvhb_r_materialdocument~GoodsReceiptPosted FROM receipts.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

