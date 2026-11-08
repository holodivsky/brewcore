*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_inspection_lot DEFINITION DEFERRED FOR TESTING.

"! Status values, origins and tolerances shared by the handlers of the inspection lot
INTERFACE lif_inspection_lot.
  CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_QM'.

  CONSTANTS:
    "! Inspection lot status values of domain ZVHB_LOT_STATUS
    BEGIN OF status,
      open     TYPE zvhb_lot_status VALUE 'OPEN',
      accepted TYPE zvhb_lot_status VALUE 'ACC',
      rejected TYPE zvhb_lot_status VALUE 'REJ',
    END OF status.

  CONSTANTS:
    "! Inspection lot origins of domain ZVHB_LOT_ORIGIN
    BEGIN OF origin,
      purchase_order TYPE zvhb_lot_origin VALUE '01',
      production     TYPE zvhb_lot_origin VALUE '04',
    END OF origin.

  CONSTANTS:
    BEGIN OF batch_status,
      free    TYPE zvhb_batch_status VALUE 'FREE',
      blocked TYPE zvhb_batch_status VALUE 'BLKD',
    END OF batch_status.

  CONSTANTS c_scrapping TYPE zvhb_movement_type VALUE '551'.

  CONSTANTS:
    "! Allowed deviation from the targets of the recipe, and the fixed limits of the other characteristics
    BEGIN OF tolerance,
      extract     TYPE zvhb_char_value VALUE '0.30',
      alcohol     TYPE zvhb_char_value VALUE '0.20',
      ph_target   TYPE zvhb_char_value VALUE '4.40',
      ph_lower    TYPE zvhb_char_value VALUE '4.20',
      ph_upper    TYPE zvhb_char_value VALUE '4.60',
      score_lower TYPE zvhb_char_value VALUE 3,
      score_upper TYPE zvhb_char_value VALUE 5,
    END OF tolerance.
ENDINTERFACE.


CLASS lhc_inspection_lot DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_inspection_lot.
  PRIVATE SECTION.
    TYPES ty_request TYPE zvhb_d_inspectionrequest.
    TYPES tt_lot_keys TYPE TABLE FOR READ IMPORT zvhb_r_inspectionlot\\inspectionlot.
    TYPES ty_lot TYPE STRUCTURE FOR READ RESULT zvhb_r_inspectionlot\\inspectionlot.
    TYPES tt_lots TYPE TABLE FOR READ RESULT zvhb_r_inspectionlot\\inspectionlot.

    TYPES:
      "! A characteristic to be created with a new lot
      BEGIN OF ty_planned_characteristic,
        sort_order     TYPE n LENGTH 2,
        characteristic TYPE zvhb_insp_char,
        description    TYPE zvhb_description,
        unit_text      TYPE zvhb_char_unit,
        target_value   TYPE zvhb_char_value,
        lower_limit    TYPE zvhb_char_value,
        upper_limit    TYPE zvhb_char_value,
      END OF ty_planned_characteristic,
      tt_planned_characteristics TYPE STANDARD TABLE OF ty_planned_characteristic WITH EMPTY KEY.

    TYPES:
      "! The lot that a goods receipt needs; an initial origin means no inspection
      BEGIN OF ty_plan,
        origin          TYPE zvhb_lot_origin,
        supplier        TYPE zvhb_partner,
        characteristics TYPE tt_planned_characteristics,
      END OF ty_plan.

    TYPES tt_requests TYPE TABLE FOR ACTION IMPORT zvhb_r_inspectionlot\\inspectionlot~createfromgoodsreceipt.
    TYPES ty_failed TYPE RESPONSE FOR FAILED EARLY zvhb_r_inspectionlot.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY zvhb_r_inspectionlot.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR InspectionLot RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR InspectionLot RESULT result.

    METHODS createFromGoodsReceipt FOR MODIFY
      IMPORTING keys FOR ACTION InspectionLot~createFromGoodsReceipt.

    METHODS accept FOR MODIFY
      IMPORTING keys FOR ACTION InspectionLot~accept RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION InspectionLot~reject RESULT result.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR InspectionLot~setNumber.

    "! Opens a lot with its characteristics for each goods receipt that needs an inspection and blocks the
    "! batch; returns the keys of the new lots
    METHODS open_lots
      IMPORTING
        requests      TYPE tt_requests
      CHANGING
        failed        TYPE ty_failed
        reported      TYPE ty_reported
      RETURNING
        VALUE(result) TYPE tt_lot_keys.

    "! FR-QM-01: every new beer batch is inspected; raw materials are inspected until the supplier has
    "! delivered one accepted lot of the material
    METHODS plan_lot
      IMPORTING
        request       TYPE ty_request
      RETURNING
        VALUE(result) TYPE ty_plan.

    "! FR-QM-02: extract and alcohol around the targets of the recipe, pH, microbiology and sensory score
    METHODS beer_characteristics
      IMPORTING
        target_gravity TYPE zvhb_char_value
        target_alcohol TYPE zvhb_char_value
      RETURNING
        VALUE(result)  TYPE tt_planned_characteristics.

    METHODS raw_material_characteristics
      RETURNING
        VALUE(result) TYPE tt_planned_characteristics.

    "! Sets the batch to Blocked unless it is blocked already
    METHODS block_batch
      IMPORTING
        material      TYPE zvhb_material
        batch         TYPE zvhb_batch
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! Sets the batch to Unrestricted unless it is free already
    METHODS release_batch
      IMPORTING
        material      TYPE zvhb_material
        batch         TYPE zvhb_batch
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! Scraps the stock of the batch in the storage location of the lot with movement type 551
    METHODS scrap_stock
      IMPORTING
        lot           TYPE ty_lot
      EXPORTING
        quantity      TYPE zvhb_quantity
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! Sets the usage decision: status and decision date
    METHODS decide
      IMPORTING
        lot_keys      TYPE tt_lot_keys
        status        TYPE zvhb_lot_status
      RETURNING
        VALUE(result) TYPE tt_lots.

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


CLASS lhc_inspection_lot IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lots)
      FAILED failed.

    " Results can be recorded and the usage decision taken only while the lot is in inspection
    result = VALUE #(
      FOR lot IN lots
      LET open     = COND #( WHEN lot-Status = lif_inspection_lot=>status-open
                             THEN if_abap_behv=>fc-o-enabled
                             ELSE if_abap_behv=>fc-o-disabled )
          decision = COND #( WHEN lot-Status = lif_inspection_lot=>status-open AND lot-%is_draft = if_abap_behv=>mk-off
                             THEN if_abap_behv=>fc-o-enabled
                             ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky           = lot-%tky
        %update        = open
        %action-Edit   = open
        %action-accept = decision
        %action-reject = decision ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " The quality inspector role follows in stage v1.0
    IF requested_authorizations-%action-createFromGoodsReceipt = if_abap_behv=>mk-on.
      result-%action-createFromGoodsReceipt = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD createFromGoodsReceipt.
    open_lots( EXPORTING requests = keys
               CHANGING  failed   = failed
                         reported = reported ).
  ENDMETHOD.

  METHOD open_lots.
    DATA lots TYPE TABLE FOR CREATE zvhb_r_inspectionlot\\inspectionlot.
    DATA characteristics TYPE TABLE FOR CREATE zvhb_r_inspectionlot\\inspectionlot\_characteristic.
    DATA planned_batches TYPE SORTED TABLE OF ty_request-batch WITH UNIQUE KEY table_line.

    LOOP AT requests INTO DATA(key).
      DATA(request) = key-%param.
      IF line_exists( planned_batches[ table_line = request-Batch ] ).
        CONTINUE.
      ENDIF.

      DATA(plan) = plan_lot( request ).
      IF plan-origin IS INITIAL.
        CONTINUE.
      ENDIF.

      " The batch waits in blocked stock until the usage decision
      DATA(problem) = block_batch( material = request-Material batch = request-Batch ).
      IF problem IS BOUND.
        APPEND VALUE #( %cid = key-%cid ) TO failed-inspectionlot.
        APPEND VALUE #( %cid = key-%cid %msg = problem ) TO reported-inspectionlot.
        CONTINUE.
      ENDIF.

      INSERT request-Batch INTO TABLE planned_batches.
      DATA(lot_cid) = |LOT{ lines( planned_batches ) }|.
      APPEND VALUE #( %cid             = lot_cid
                      %is_draft        = if_abap_behv=>mk-off
                      Origin           = plan-origin
                      Material         = request-Material
                      Batch            = request-Batch
                      Plant            = request-Plant
                      StorageLocation  = request-StorageLocation
                      Unit             = request-Unit
                      Quantity         = request-Quantity
                      MaterialDocument = request-MaterialDocument
                      DocumentItem     = request-DocumentItem
                      PurchaseOrder    = request-PurchaseOrder
                      Supplier         = plan-supplier
                      BrewOrder        = request-BrewOrder
                      Status           = lif_inspection_lot=>status-open ) TO lots.
      APPEND VALUE #( %cid_ref  = lot_cid
                      %is_draft = if_abap_behv=>mk-off
                      %target   = VALUE #( FOR c IN plan-characteristics
                                           ( %cid           = |{ lot_cid }_{ c-sort_order }|
                                             %is_draft      = if_abap_behv=>mk-off
                                             SortOrder      = c-sort_order
                                             Characteristic = c-characteristic
                                             Description    = c-description
                                             UnitText       = c-unit_text
                                             TargetValue    = c-target_value
                                             LowerLimit     = c-lower_limit
                                             UpperLimit     = c-upper_limit ) ) ) TO characteristics.
    ENDLOOP.

    IF lots IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        CREATE FIELDS ( Origin Material Batch Plant StorageLocation Unit Quantity MaterialDocument DocumentItem
                        PurchaseOrder Supplier BrewOrder Status )
        WITH lots
        CREATE BY \_Characteristic
        FIELDS ( SortOrder Characteristic Description UnitText TargetValue LowerLimit UpperLimit )
        WITH characteristics
      MAPPED DATA(created).

    result = CORRESPONDING #( created-inspectionlot ).
  ENDMETHOD.

  METHOD accept.
    DATA check TYPE REF TO zcl_vhb_characteristic_check.
    DATA accepted TYPE tt_lot_keys.

    check = NEW #( ).

    READ ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lots)
      ENTITY InspectionLot BY \_Characteristic
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(characteristics).

    LOOP AT lots INTO DATA(lot).
      " FR-QM-03: no acceptance while a characteristic is missing or out of tolerance
      DATA(findings) = VALUE string_table( ).
      LOOP AT characteristics INTO DATA(characteristic) USING KEY entity WHERE LotUUID = lot-LotUUID.
        DATA(finding) = check->check_acceptance( CORRESPONDING #( characteristic ) ).
        IF finding IS NOT INITIAL.
          APPEND VALUE #( %tky = lot-%tky
                          %msg = message( number = finding-number
                                          v1     = finding-v1
                                          v2     = finding-v2
                                          v3     = finding-v3
                                          v4     = finding-v4 ) ) TO reported-inspectionlot.
          APPEND finding-v1 TO findings.
        ENDIF.
      ENDLOOP.

      DATA(problem) = COND #( WHEN findings IS INITIAL
                              THEN release_batch( material = lot-Material batch = lot-Batch ) ).
      IF findings IS NOT INITIAL OR problem IS BOUND.
        APPEND VALUE #( %tky = lot-%tky ) TO failed-inspectionlot.
        IF problem IS BOUND.
          APPEND VALUE #( %tky = lot-%tky %msg = problem ) TO reported-inspectionlot.
        ENDIF.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( lot ) TO accepted.
      APPEND VALUE #( %tky = lot-%tky
                      %msg = message( number   = '007'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = lot-InspectionLot
                                      v2       = lot-Batch ) ) TO reported-inspectionlot.
    ENDLOOP.

    DATA(decided) = decide( lot_keys = accepted status = lif_inspection_lot=>status-accepted ).
    result = VALUE #( FOR d IN decided ( %tky = d-%tky %param = d ) ).
  ENDMETHOD.

  METHOD reject.
    DATA rejected TYPE tt_lot_keys.
    DATA scrapped TYPE zvhb_quantity.

    READ ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lots).

    LOOP AT lots INTO DATA(lot).
      " FR-QM-03: the batch is blocked and its stock scrapped; lot, batch and material document are saved together
      CLEAR scrapped.
      DATA(problem) = block_batch( material = lot-Material batch = lot-Batch ).
      IF problem IS NOT BOUND.
        problem = scrap_stock( EXPORTING lot = lot IMPORTING quantity = scrapped ).
      ENDIF.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = lot-%tky ) TO failed-inspectionlot.
        APPEND VALUE #( %tky = lot-%tky %msg = problem ) TO reported-inspectionlot.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( lot ) TO rejected.
      APPEND VALUE #( %tky = lot-%tky
                      %msg = COND #( WHEN scrapped > 0
                                     THEN message( number   = '008'
                                                   severity = if_abap_behv_message=>severity-success
                                                   v1       = lot-InspectionLot
                                                   v2       = |{ scrapped NUMBER = USER } { lot-Unit }|
                                                   v3       = lot-Batch )
                                     ELSE message( number   = '009'
                                                   severity = if_abap_behv_message=>severity-success
                                                   v1       = lot-InspectionLot
                                                   v2       = lot-Batch ) ) ) TO reported-inspectionlot.
    ENDLOOP.

    DATA(decided) = decide( lot_keys = rejected status = lif_inspection_lot=>status-rejected ).
    result = VALUE #( FOR d IN decided ( %tky = d-%tky %param = d ) ).
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        FIELDS ( InspectionLot ) WITH CORRESPONDING #( keys )
      RESULT DATA(lots).

    DELETE lots WHERE InspectionLot IS NOT INITIAL.

    LOOP AT lots ASSIGNING FIELD-SYMBOL(<lot>).
      TRY.
          <lot>-InspectionLot = get_number_range( )->get_next( zif_vhb_number_range=>objects-inspection_lot ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <lot>-%tky %msg = message( number = '001' v1 = exception->get_text( ) ) )
                 TO reported-inspectionlot.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        UPDATE FIELDS ( InspectionLot )
        WITH VALUE #( FOR l IN lots WHERE ( InspectionLot IS NOT INITIAL )
                      ( %tky = l-%tky InspectionLot = l-InspectionLot ) ).
  ENDMETHOD.

  METHOD plan_lot.
    IF request-Batch IS INITIAL.
      RETURN.
    ENDIF.

    " One lot per batch, also when the event arrives twice
    SELECT SINGLE @abap_true FROM zvhb_insplot
      WHERE material = @request-Material
        AND batch    = @request-Batch
      INTO @DATA(lot_exists).
    IF lot_exists = abap_true.
      RETURN.
    ENDIF.

    IF request-BrewOrder IS NOT INITIAL.
      SELECT SINGLE version~target_gravity, version~target_alcohol
        FROM zvhb_brewhdr AS brew
          INNER JOIN zvhb_rcpver AS version ON version~version_uuid = brew~version_uuid
        WHERE brew~brew_order = @request-BrewOrder
        INTO @DATA(targets).
      IF sy-subrc = 0.
        result = VALUE #( origin          = lif_inspection_lot=>origin-production
                          characteristics = beer_characteristics( target_gravity = CONV #( targets-target_gravity )
                                                                  target_alcohol = CONV #( targets-target_alcohol ) ) ).
      ENDIF.
      RETURN.
    ENDIF.

    IF request-PurchaseOrder IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE supplier FROM zvhb_pohdr
      WHERE purchase_order = @request-PurchaseOrder
      INTO @DATA(supplier).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE @abap_true FROM zvhb_insplot
      WHERE supplier = @supplier
        AND material = @request-Material
        AND status   = @lif_inspection_lot=>status-accepted
      INTO @DATA(supplier_approved).
    IF supplier_approved = abap_false.
      result = VALUE #( origin          = lif_inspection_lot=>origin-purchase_order
                        supplier        = supplier
                        characteristics = raw_material_characteristics( ) ).
    ENDIF.
  ENDMETHOD.

  METHOD beer_characteristics.
    result = VALUE #(
      ( sort_order   = '10'
        characteristic = zcl_vhb_characteristic_check=>characteristics-extract
        description  = 'Original extract'
        unit_text    = 'Plato'
        target_value = target_gravity
        lower_limit  = target_gravity - lif_inspection_lot=>tolerance-extract
        upper_limit  = target_gravity + lif_inspection_lot=>tolerance-extract )
      ( sort_order   = '20'
        characteristic = zcl_vhb_characteristic_check=>characteristics-alcohol
        description  = 'Alcohol'
        unit_text    = '% vol'
        target_value = target_alcohol
        lower_limit  = target_alcohol - lif_inspection_lot=>tolerance-alcohol
        upper_limit  = target_alcohol + lif_inspection_lot=>tolerance-alcohol )
      ( sort_order   = '30'
        characteristic = zcl_vhb_characteristic_check=>characteristics-ph
        description  = 'pH value'
        target_value = lif_inspection_lot=>tolerance-ph_target
        lower_limit  = lif_inspection_lot=>tolerance-ph_lower
        upper_limit  = lif_inspection_lot=>tolerance-ph_upper )
      ( sort_order   = '40'
        characteristic = zcl_vhb_characteristic_check=>characteristics-microbiology
        description  = 'Beer-spoiling bacteria (0 no, 1 yes)' )
      ( sort_order   = '50'
        characteristic = zcl_vhb_characteristic_check=>characteristics-sensory
        description  = 'Sensory score (1 to 5)'
        target_value = lif_inspection_lot=>tolerance-score_upper
        lower_limit  = lif_inspection_lot=>tolerance-score_lower
        upper_limit  = lif_inspection_lot=>tolerance-score_upper ) ).
  ENDMETHOD.

  METHOD raw_material_characteristics.
    result = VALUE #(
      ( sort_order   = '10'
        characteristic = zcl_vhb_characteristic_check=>characteristics-microbiology
        description  = 'Contamination (0 no, 1 yes)' )
      ( sort_order   = '20'
        characteristic = zcl_vhb_characteristic_check=>characteristics-sensory
        description  = 'Appearance and aroma (1 to 5)'
        target_value = lif_inspection_lot=>tolerance-score_upper
        lower_limit  = lif_inspection_lot=>tolerance-score_lower
        upper_limit  = lif_inspection_lot=>tolerance-score_upper ) ).
  ENDMETHOD.

  METHOD block_batch.
    READ ENTITIES OF zvhb_r_batch
      ENTITY Batch
        FIELDS ( Status ) WITH VALUE #( ( Material = material Batch = batch ) )
      RESULT DATA(batches).

    IF VALUE #( batches[ 1 ]-Status OPTIONAL ) <> lif_inspection_lot=>batch_status-free.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_batch
      ENTITY Batch
        EXECUTE block FROM VALUE #( ( Material = material Batch = batch ) )
      FAILED DATA(batch_failed)
      REPORTED DATA(batch_reported).

    IF batch_failed IS NOT INITIAL.
      result = VALUE #( batch_reported-batch[ 1 ]-%msg OPTIONAL ).
    ENDIF.
  ENDMETHOD.

  METHOD release_batch.
    READ ENTITIES OF zvhb_r_batch
      ENTITY Batch
        FIELDS ( Status ) WITH VALUE #( ( Material = material Batch = batch ) )
      RESULT DATA(batches).

    IF VALUE #( batches[ 1 ]-Status OPTIONAL ) <> lif_inspection_lot=>batch_status-blocked.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_batch
      ENTITY Batch
        EXECUTE release FROM VALUE #( ( Material = material Batch = batch ) )
      FAILED DATA(batch_failed)
      REPORTED DATA(batch_reported).

    IF batch_failed IS NOT INITIAL.
      result = VALUE #( batch_reported-batch[ 1 ]-%msg OPTIONAL ).
    ENDIF.
  ENDMETHOD.

  METHOD scrap_stock.
    CLEAR quantity.

    SELECT SINGLE TotalQuantity FROM zvhb_i_stock
      WHERE Material        = @lot-Material
        AND Plant           = @lot-Plant
        AND StorageLocation = @lot-StorageLocation
        AND Batch           = @lot-Batch
      INTO @DATA(stock).

    IF stock <= 0.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_materialdocument
      ENTITY MaterialDocument
        EXECUTE postGoodsMovement
        FROM VALUE #( ( %cid   = 'SCRAP'
                        %param = VALUE #( MovementType    = lif_inspection_lot=>c_scrapping
                                          Material        = lot-Material
                                          Plant           = lot-Plant
                                          StorageLocation = lot-StorageLocation
                                          Batch           = lot-Batch
                                          Quantity        = stock
                                          HeaderText      = |Inspection lot { lot-InspectionLot }| ) ) )
      FAILED DATA(scrap_failed)
      REPORTED DATA(scrap_reported).

    IF scrap_failed IS NOT INITIAL.
      result = VALUE #( scrap_reported-materialdocument[ 1 ]-%msg OPTIONAL ).
    ELSE.
      quantity = stock.
    ENDIF.
  ENDMETHOD.

  METHOD decide.
    IF lot_keys IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        UPDATE FIELDS ( Status DecisionDate )
        WITH VALUE #( FOR key IN lot_keys ( %tky         = key-%tky
                                            Status       = status
                                            DecisionDate = cl_abap_context_info=>get_system_date( ) ) ).

    READ ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY InspectionLot
        ALL FIELDS WITH CORRESPONDING #( lot_keys )
      RESULT result.
  ENDMETHOD.

  METHOD message.
    result = new_message( id       = lif_inspection_lot=>c_msgid
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


CLASS lhc_characteristic DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_inspection_lot.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Characteristic RESULT result.

    METHODS validateResult FOR VALIDATE ON SAVE
      IMPORTING keys FOR Characteristic~validateResult.
ENDCLASS.


CLASS lhc_characteristic IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY Characteristic BY \_InspectionLot
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lots)
      LINK DATA(links)
      FAILED failed.

    LOOP AT keys INTO DATA(key).
      DATA(link) = VALUE #( links[ KEY id COMPONENTS source-%tky = key-%tky ] OPTIONAL ).
      DATA(lot) = VALUE #( lots[ KEY id COMPONENTS %tky = link-target-%tky ] OPTIONAL ).
      APPEND VALUE #( %tky    = key-%tky
                      %update = COND #( WHEN lot-Status = lif_inspection_lot=>status-open
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateResult.
    DATA(check) = NEW zcl_vhb_characteristic_check( ).

    READ ENTITIES OF zvhb_r_inspectionlot IN LOCAL MODE
      ENTITY Characteristic
        FIELDS ( Characteristic Description ResultValue ) WITH CORRESPONDING #( keys )
      RESULT DATA(characteristics).

    LOOP AT characteristics INTO DATA(characteristic).
      APPEND VALUE #( %tky = characteristic-%tky %state_area = 'RESULT' ) TO reported-characteristic.

      DATA(finding) = check->check_result( CORRESPONDING #( characteristic ) ).
      IF finding IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = characteristic-%tky ) TO failed-characteristic.
      APPEND VALUE #( %tky                 = characteristic-%tky
                      %state_area          = 'RESULT'
                      %msg                 = new_message( id       = lif_inspection_lot=>c_msgid
                                                          number   = finding-number
                                                          severity = if_abap_behv_message=>severity-error
                                                          v1       = finding-v1
                                                          v2       = finding-v2 )
                      %path                = VALUE #( inspectionlot-%is_draft = characteristic-%is_draft
                                                      inspectionlot-LotUUID   = characteristic-LotUUID )
                      %element-ResultValue = if_abap_behv=>mk-on ) TO reported-characteristic.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

