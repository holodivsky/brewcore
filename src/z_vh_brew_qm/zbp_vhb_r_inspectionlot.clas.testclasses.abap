*"* use this source file for your ABAP unit test classes

"! Opening lots from goods receipts, the plausibility of results and the usage decision. The transactional
"! buffers of the inspection lot and the batch and the tables of brew orders, recipes, purchase orders,
"! lots and stock are replaced by test doubles. Blocking, releasing and scrapping the batch change inventory;
"! they are checked in the app.
CLASS ltc_inspection_lot DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed TYPE RESPONSE FOR FAILED EARLY zvhb_r_inspectionlot.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY zvhb_r_inspectionlot.
    TYPES ty_failed_late TYPE RESPONSE FOR FAILED LATE zvhb_r_inspectionlot.
    TYPES ty_reported_late TYPE RESPONSE FOR REPORTED LATE zvhb_r_inspectionlot.
    TYPES tt_lot_keys TYPE TABLE FOR READ IMPORT zvhb_r_inspectionlot\\inspectionlot.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_inspectionlot\\inspectionlot.
    TYPES tt_characteristics TYPE TABLE FOR READ RESULT zvhb_r_inspectionlot\\characteristic.

    TYPES tt_lots TYPE STANDARD TABLE OF zvhb_insplot WITH EMPTY KEY.
    TYPES tt_brew_orders TYPE STANDARD TABLE OF zvhb_brewhdr WITH EMPTY KEY.
    TYPES tt_versions TYPE STANDARD TABLE OF zvhb_rcpver WITH EMPTY KEY.
    TYPES tt_orders TYPE STANDARD TABLE OF zvhb_pohdr WITH EMPTY KEY.

    CLASS-DATA environment TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA lot_handler TYPE REF TO lhc_inspection_lot.
    DATA characteristic_handler TYPE REF TO lhc_characteristic.
    DATA mapped TYPE RESPONSE FOR MAPPED EARLY zvhb_r_inspectionlot.
    DATA failed TYPE ty_failed.
    DATA reported TYPE ty_reported.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS beer_receipt_opens_lot FOR TESTING.
    METHODS limits_follow_recipe FOR TESTING.
    METHODS second_receipt_opens_no_lot FOR TESTING.
    METHODS new_supplier_is_inspected FOR TESTING.
    METHODS approved_supplier_is_skipped FOR TESTING.
    METHODS missing_result_blocks_accept FOR TESTING.
    METHODS out_of_tolerance_blocks_accept FOR TESTING.
    METHODS lot_in_tolerance_is_accepted FOR TESTING.
    METHODS lot_is_rejected FOR TESTING.
    METHODS decided_lot_is_locked FOR TESTING.
    METHODS result_must_be_a_number FOR TESTING.
    METHODS microbiology_is_yes_or_no FOR TESTING.
    METHODS sensory_score_is_whole FOR TESTING.

    "! Goods receipt of 48 hl Pils from brew order 6000000000 into batch 2000000012
    METHODS open_beer_lot
      RETURNING
        VALUE(result) TYPE tt_lot_keys.

    METHODS open_lot
      IMPORTING
        request       TYPE zvhb_d_inspectionrequest
      RETURNING
        VALUE(result) TYPE tt_lot_keys.

    "! Enters the results in the order of the characteristics
    METHODS record_results
      IMPORTING
        lot_keys TYPE tt_lot_keys
        results  TYPE string_table.

    METHODS read_lot
      IMPORTING
        lot_keys      TYPE tt_lot_keys
      RETURNING
        VALUE(result) TYPE zvhb_r_inspectionlot.

    METHODS read_characteristics
      IMPORTING
        lot_keys      TYPE tt_lot_keys
      RETURNING
        VALUE(result) TYPE tt_characteristics.

    METHODS accept
      IMPORTING
        lot_keys TYPE tt_lot_keys.

    "! Runs the plausibility check on one result of the beer lot and returns the number of the error message
    METHODS validate_result
      IMPORTING
        sort_order    TYPE n
        result_value  TYPE zvhb_char_result
      RETURNING
        VALUE(result) TYPE symsgno.

    METHODS assert_message
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_inspection_lot IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_INSPECTIONLOT' )
                                                                                    ( 'ZVHB_R_BATCH' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_INSPLOT' )
                                                                                     ( 'ZVHB_BREWHDR' )
                                                                                     ( 'ZVHB_RCPVER' )
                                                                                     ( 'ZVHB_POHDR' )
                                                                                     ( 'ZVHB_I_STOCK' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    " Pils brewed with recipe version 002: 12.0 degrees Plato and 5.0 % alcohol
    sql_environment->insert_test_data( VALUE tt_brew_orders(
      ( brew_uuid = 'A0000000000000000000000000000001' brew_order = '6000000000' material = 'PILS'
        version_uuid = 'B0000000000000000000000000000001' ) ) ).
    sql_environment->insert_test_data( VALUE tt_versions(
      ( recipe_uuid = 'C0000000000000000000000000000001' version_uuid = 'B0000000000000000000000000000001'
        target_gravity = '12.0' target_alcohol = '5.0' ) ) ).
    sql_environment->insert_test_data( VALUE tt_orders(
      ( po_uuid = 'D0000000000000000000000000000001' purchase_order = '4500000000' supplier = '1000000001' ) ) ).

    CREATE OBJECT lot_handler FOR TESTING.
    CREATE OBJECT characteristic_handler FOR TESTING.
    CLEAR: mapped, failed, reported.
  ENDMETHOD.

  METHOD beer_receipt_opens_lot.
    DATA(lot) = read_lot( open_beer_lot( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 'OPEN' act = lot-Status ).
    cl_abap_unit_assert=>assert_equals( exp = '04' act = lot-Origin ).
    cl_abap_unit_assert=>assert_equals( exp = '2000000012' act = lot-Batch ).
    cl_abap_unit_assert=>assert_equals( exp = '6000000000' act = lot-BrewOrder ).
  ENDMETHOD.

  METHOD limits_follow_recipe.
    DATA(characteristics) = read_characteristics( open_beer_lot( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 5 act = lines( characteristics ) ).
    DATA(extract) = characteristics[ Characteristic = 'EXTR' ].
    cl_abap_unit_assert=>assert_equals( exp = '11.70' act = extract-LowerLimit ).
    cl_abap_unit_assert=>assert_equals( exp = '12.30' act = extract-UpperLimit ).
    DATA(alcohol) = characteristics[ Characteristic = 'ALC' ].
    cl_abap_unit_assert=>assert_equals( exp = '4.80' act = alcohol-LowerLimit ).
    cl_abap_unit_assert=>assert_equals( exp = '5.20' act = alcohol-UpperLimit ).
  ENDMETHOD.

  METHOD second_receipt_opens_no_lot.
    sql_environment->insert_test_data( VALUE tt_lots(
      ( lot_uuid = 'E0000000000000000000000000000001' material = 'PILS' batch = '2000000012' status = 'OPEN' ) ) ).

    cl_abap_unit_assert=>assert_initial( open_beer_lot( ) ).
  ENDMETHOD.

  METHOD new_supplier_is_inspected.
    DATA(lot_keys) = open_lot( VALUE #( PurchaseOrder = '4500000000' Material = 'HOPS-HALL' Batch = '2000000001'
                                        Plant = 'BR01' StorageLocation = 'RM01' Unit = 'KG' Quantity = 60 ) ).

    DATA(lot) = read_lot( lot_keys ).
    cl_abap_unit_assert=>assert_equals( exp = '01' act = lot-Origin ).
    cl_abap_unit_assert=>assert_equals( exp = '1000000001' act = lot-Supplier ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( read_characteristics( lot_keys ) ) ).
  ENDMETHOD.

  METHOD approved_supplier_is_skipped.
    sql_environment->insert_test_data( VALUE tt_lots(
      ( lot_uuid = 'E0000000000000000000000000000001' material = 'HOPS-HALL' batch = '2000000001'
        supplier = '1000000001' status = 'ACC' ) ) ).

    DATA(lot_keys) = open_lot( VALUE #( PurchaseOrder = '4500000000' Material = 'HOPS-HALL' Batch = '2000000002'
                                        Plant = 'BR01' StorageLocation = 'RM01' Unit = 'KG' Quantity = 60 ) ).

    cl_abap_unit_assert=>assert_initial( lot_keys ).
  ENDMETHOD.

  METHOD missing_result_blocks_accept.
    DATA(lot_keys) = open_beer_lot( ).
    record_results( lot_keys = lot_keys results = VALUE #( ( `12.1` ) ( `5.0` ) ( `4.4` ) ( `0` ) ) ).

    accept( lot_keys ).

    cl_abap_unit_assert=>assert_not_initial( failed-inspectionlot ).
    assert_message( '002' ).
    cl_abap_unit_assert=>assert_equals( exp = 'OPEN' act = read_lot( lot_keys )-Status ).
  ENDMETHOD.

  METHOD out_of_tolerance_blocks_accept.
    DATA(lot_keys) = open_beer_lot( ).
    record_results( lot_keys = lot_keys results = VALUE #( ( `12.6` ) ( `5.0` ) ( `4.4` ) ( `0` ) ( `4` ) ) ).

    accept( lot_keys ).

    cl_abap_unit_assert=>assert_not_initial( failed-inspectionlot ).
    assert_message( '003' ).
  ENDMETHOD.

  METHOD lot_in_tolerance_is_accepted.
    DATA(lot_keys) = open_beer_lot( ).
    record_results( lot_keys = lot_keys results = VALUE #( ( `12,3` ) ( `4.9` ) ( `4.5` ) ( `0` ) ( `4` ) ) ).

    accept( lot_keys ).

    cl_abap_unit_assert=>assert_initial( failed-inspectionlot ).
    assert_message( '007' ).
    DATA(lot) = read_lot( lot_keys ).
    cl_abap_unit_assert=>assert_equals( exp = 'ACC' act = lot-Status ).
    cl_abap_unit_assert=>assert_equals( exp = cl_abap_context_info=>get_system_date( ) act = lot-DecisionDate ).
  ENDMETHOD.

  METHOD lot_is_rejected.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_inspectionlot\\inspectionlot~reject.
    DATA(lot_keys) = open_beer_lot( ).

    lot_handler->reject( EXPORTING keys     = CORRESPONDING #( lot_keys )
                         CHANGING  result   = result
                                   mapped   = mapped
                                   failed   = failed
                                   reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-inspectionlot ).
    assert_message( '009' ).
    cl_abap_unit_assert=>assert_equals( exp = 'REJ' act = read_lot( lot_keys )-Status ).
  ENDMETHOD.

  METHOD decided_lot_is_locked.
    DATA features TYPE ty_features.
    DATA failed_features TYPE ty_failed.
    DATA reported_features TYPE ty_reported.
    DATA(lot_keys) = open_beer_lot( ).
    record_results( lot_keys = lot_keys results = VALUE #( ( `12.0` ) ( `5.0` ) ( `4.4` ) ( `0` ) ( `5` ) ) ).
    accept( lot_keys ).

    lot_handler->get_instance_features(
      EXPORTING keys               = CORRESPONDING #( lot_keys )
                requested_features = VALUE #( %update = if_abap_behv=>mk-on %action-accept = if_abap_behv=>mk-on
                                              %action-reject = if_abap_behv=>mk-on )
      CHANGING  result             = features
                failed             = failed_features
                reported           = reported_features ).

    DATA(lot_features) = features[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled act = lot_features-%update ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled act = lot_features-%action-accept ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled act = lot_features-%action-reject ).
  ENDMETHOD.

  METHOD result_must_be_a_number.
    cl_abap_unit_assert=>assert_equals( exp = '004' act = validate_result( sort_order = '10' result_value = 'twelve' ) ).
  ENDMETHOD.

  METHOD microbiology_is_yes_or_no.
    cl_abap_unit_assert=>assert_equals( exp = '005' act = validate_result( sort_order = '40' result_value = '2' ) ).
  ENDMETHOD.

  METHOD sensory_score_is_whole.
    cl_abap_unit_assert=>assert_equals( exp = '006' act = validate_result( sort_order = '50' result_value = '3.5' ) ).
  ENDMETHOD.

  METHOD open_beer_lot.
    result = open_lot( VALUE #( MaterialDocument = '4900000010' DocumentItem = '0001' BrewOrder = '6000000000'
                                Material = 'PILS' Batch = '2000000012' Plant = 'BR01' StorageLocation = 'FG01'
                                Unit = 'HL' Quantity = 48 ) ).
  ENDMETHOD.

  METHOD open_lot.
    result = lot_handler->open_lots( EXPORTING requests = VALUE #( ( %cid = 'RECEIPT' %param = request ) )
                                     CHANGING  failed   = failed
                                               reported = reported ).
  ENDMETHOD.

  METHOD record_results.
    READ ENTITIES OF zvhb_r_inspectionlot
      ENTITY InspectionLot BY \_Characteristic
        FIELDS ( SortOrder ) WITH CORRESPONDING #( lot_keys )
      RESULT DATA(characteristics).
    SORT characteristics BY SortOrder.

    MODIFY ENTITIES OF zvhb_r_inspectionlot
      ENTITY Characteristic
        UPDATE FIELDS ( ResultValue )
        WITH VALUE #( FOR c IN characteristics INDEX INTO i WHERE ( SortOrder IS NOT INITIAL )
                      ( %tky = c-%tky ResultValue = COND #( WHEN i <= lines( results ) THEN results[ i ] ) ) ).
  ENDMETHOD.

  METHOD read_lot.
    READ ENTITIES OF zvhb_r_inspectionlot
      ENTITY InspectionLot ALL FIELDS WITH CORRESPONDING #( lot_keys )
      RESULT DATA(lots).
    cl_abap_unit_assert=>assert_not_initial( lots ).
    result = CORRESPONDING #( lots[ 1 ] ).
  ENDMETHOD.

  METHOD read_characteristics.
    READ ENTITIES OF zvhb_r_inspectionlot
      ENTITY InspectionLot BY \_Characteristic ALL FIELDS WITH CORRESPONDING #( lot_keys )
      RESULT DATA(characteristics).
    result = CORRESPONDING #( characteristics ).
  ENDMETHOD.

  METHOD accept.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_inspectionlot\\inspectionlot~accept.

    lot_handler->accept( EXPORTING keys     = CORRESPONDING #( lot_keys )
                         CHANGING  result   = result
                                   mapped   = mapped
                                   failed   = failed
                                   reported = reported ).
  ENDMETHOD.

  METHOD validate_result.
    DATA failed_late TYPE ty_failed_late.
    DATA reported_late TYPE ty_reported_late.

    DATA(lot_keys) = open_beer_lot( ).
    READ ENTITIES OF zvhb_r_inspectionlot
      ENTITY InspectionLot BY \_Characteristic
        FIELDS ( SortOrder ) WITH CORRESPONDING #( lot_keys )
      RESULT DATA(characteristics).
    DATA(characteristic) = characteristics[ SortOrder = sort_order ].

    MODIFY ENTITIES OF zvhb_r_inspectionlot
      ENTITY Characteristic
        UPDATE FIELDS ( ResultValue ) WITH VALUE #( ( %tky = characteristic-%tky ResultValue = result_value ) ).

    characteristic_handler->validateresult( EXPORTING keys     = VALUE #( ( %tky = characteristic-%tky ) )
                                            CHANGING  failed   = failed_late
                                                      reported = reported_late ).

    cl_abap_unit_assert=>assert_not_initial( failed_late-characteristic ).
    LOOP AT reported_late-characteristic INTO DATA(line) WHERE %msg IS BOUND.
      result = line-%msg->if_t100_message~t100key-msgno.
    ENDLOOP.
  ENDMETHOD.

  METHOD assert_message.
    LOOP AT reported-inspectionlot INTO DATA(line) WHERE %msg IS BOUND.
      IF line-%msg->if_t100_message~t100key-msgno = msgno.
        RETURN.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>fail( |Message { msgno } expected| ).
  ENDMETHOD.

ENDCLASS.

