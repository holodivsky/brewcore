*"* use this source file for your ABAP unit test classes

"! Number range double that always returns the same batch number
CLASS ltd_number_range DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_vhb_number_range.
ENDCLASS.


CLASS ltd_number_range IMPLEMENTATION.

  METHOD zif_vhb_number_range~get_next.
    result = '2000000099'.
  ENDMETHOD.

ENDCLASS.


"! Posting checks, FEFO proposal and reversal of the material document.
"! The transactional buffers of material document and batch, the material and batch views
"! and the stock views are replaced by test doubles.
CLASS ltc_material_document DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_r_material WITH EMPTY KEY.
    TYPES tt_batches   TYPE STANDARD TABLE OF zvhb_r_batch WITH EMPTY KEY.
    TYPES tt_stock     TYPE STANDARD TABLE OF zvhb_i_stock WITH EMPTY KEY.
    TYPES tt_fefo      TYPE STANDARD TABLE OF zvhb_i_fefobatch WITH EMPTY KEY.
    TYPES tt_headers   TYPE STANDARD TABLE OF zvhb_mdochdr WITH EMPTY KEY.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA handler TYPE REF TO lhc_material_document.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS initial_entry_creates_batch FOR TESTING.
    METHODS reversal_type_fails FOR TESTING.
    METHODS unknown_material_fails FOR TESTING.
    METHODS inactive_material_fails FOR TESTING.
    METHODS unknown_plant_fails FOR TESTING.
    METHODS unknown_location_fails FOR TESTING.
    METHODS zero_quantity_fails FOR TESTING.
    METHODS scrapping_needs_batch FOR TESTING.
    METHODS batch_for_plain_material_fails FOR TESTING.
    METHODS unknown_batch_fails FOR TESTING.
    METHODS expired_batch_issue_fails FOR TESTING.
    METHODS not_enough_free_stock_fails FOR TESTING.
    METHODS fefo_takes_earliest_expiry FOR TESTING.
    METHODS fefo_without_batch_fails FOR TESTING.
    METHODS transfer_same_location_fails FOR TESTING.
    METHODS scrapping_takes_blocked_stock FOR TESTING.
    METHODS reversal_mirrors_item FOR TESTING.
    METHODS reversal_of_reversal_fails FOR TESTING.
    METHODS second_reversal_fails FOR TESTING.
    METHODS used_receipt_reversal_fails FOR TESTING.

    "! 100 kg of Pilsner malt from the raw material store in the brewery
    METHODS movement
      IMPORTING
        movement_type TYPE zvhb_movement_type DEFAULT '261'
        material      TYPE zvhb_material DEFAULT 'MALT-PILS'
        batch         TYPE zvhb_batch DEFAULT '2000000001'
        quantity      TYPE zvhb_quantity DEFAULT 100
      RETURNING
        VALUE(result) TYPE zvhb_d_goodsmovement.

    METHODS post
      IMPORTING
        movement      TYPE zvhb_d_goodsmovement
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS assert_error
      IMPORTING
        message TYPE REF TO if_abap_behv_message
        msgno   TYPE symsgno.
ENDCLASS.


CLASS ltc_material_document IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_MATERIALDOCUMENT' )
                                                                                    ( 'ZVHB_R_BATCH' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_R_MATERIAL' )
                                                                                     ( 'ZVHB_R_BATCH' )
                                                                                     ( 'ZVHB_I_STOCK' )
                                                                                     ( 'ZVHB_I_FEFOBATCH' )
                                                                                     ( 'ZVHB_MDOCHDR' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    DATA(materials) = VALUE tt_materials(
      ( Material = 'MALT-PILS' MaterialType = 'ROH' BaseUnit = 'KG' IsBatchManaged = abap_true IsActive = abap_true )
      ( Material = 'MALT-OLD'  MaterialType = 'ROH' BaseUnit = 'KG' IsBatchManaged = abap_true IsActive = abap_false )
      ( Material = 'CRATE-20'  MaterialType = 'LEER' BaseUnit = 'ST' IsBatchManaged = abap_false IsActive = abap_true ) ).
    sql_environment->insert_test_data( materials ).

    " Batch 1 is good until the end of 2099, batch 2 expired in 2020
    DATA(batches) = VALUE tt_batches( ( Material = 'MALT-PILS' Batch = '2000000001' ExpiryDate = '20991231' Status = 'FREE' )
                                      ( Material = 'MALT-PILS' Batch = '2000000002' ExpiryDate = '20200101' Status = 'FREE' ) ).
    sql_environment->insert_test_data( batches ).

    DATA(stock) = VALUE tt_stock(
      ( Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000001' Unit = 'KG'
        TotalQuantity = 500 FreeQuantity = 500 )
      ( Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000002' Unit = 'KG'
        TotalQuantity = 80 FreeQuantity = 80 IsExpired = abap_true )
      ( Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000003' Unit = 'KG'
        TotalQuantity = 100 FreeQuantity = 0 BlockedQuantity = 100 ) ).
    sql_environment->insert_test_data( stock ).

    DATA(fefo) = VALUE tt_fefo(
      ( Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000001' Unit = 'KG'
        ExpiryDate = '20991231' FreeQuantity = 500 )
      ( Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000005' Unit = 'KG'
        ExpiryDate = '20980101' FreeQuantity = 200 ) ).
    sql_environment->insert_test_data( fefo ).

    DATA(headers) = VALUE tt_headers( ( material_document = '4900000002' reversed_document = '4900000001' ) ).
    sql_environment->insert_test_data( headers ).

    CREATE OBJECT handler FOR TESTING.
    handler->number_range = NEW ltd_number_range( ).
  ENDMETHOD.

  METHOD movement.
    result = VALUE #( MovementType    = movement_type
                      Material        = material
                      Plant           = 'BR01'
                      StorageLocation = 'RM01'
                      Batch           = batch
                      Quantity        = quantity ).
  ENDMETHOD.

  METHOD post.
    DATA pid TYPE abp_behv_pid.
    result = handler->post( EXPORTING movement = movement
                            IMPORTING pid      = pid ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_bound( act = message msg = 'Posting should fail' ).
    cl_abap_unit_assert=>assert_equals( act = message->if_t100_message~t100key-msgno exp = msgno ).
  ENDMETHOD.

  METHOD initial_entry_creates_batch.
    cl_abap_unit_assert=>assert_not_bound( post( movement( movement_type = '561' batch = '' quantity = 1000 ) ) ).

    READ ENTITIES OF zvhb_r_batch
      ENTITY Batch FIELDS ( Status ) WITH VALUE #( ( Material = 'MALT-PILS' Batch = '2000000099' ) )
      RESULT DATA(new_batches).
    cl_abap_unit_assert=>assert_equals( act = lines( new_batches ) exp = 1 ).
  ENDMETHOD.

  METHOD reversal_type_fails.
    assert_error( message = post( movement( movement_type = '102' ) ) msgno = '001' ).
  ENDMETHOD.

  METHOD unknown_material_fails.
    assert_error( message = post( movement( material = 'NO-SUCH' ) ) msgno = '002' ).
  ENDMETHOD.

  METHOD inactive_material_fails.
    assert_error( message = post( movement( material = 'MALT-OLD' ) ) msgno = '003' ).
  ENDMETHOD.

  METHOD unknown_plant_fails.
    DATA(data) = movement( ).
    data-Plant = 'XX99'.

    assert_error( message = post( data ) msgno = '004' ).
  ENDMETHOD.

  METHOD unknown_location_fails.
    DATA(data) = movement( ).
    data-StorageLocation = 'XX99'.

    assert_error( message = post( data ) msgno = '005' ).
  ENDMETHOD.

  METHOD zero_quantity_fails.
    assert_error( message = post( movement( quantity = 0 ) ) msgno = '006' ).
  ENDMETHOD.

  METHOD scrapping_needs_batch.
    assert_error( message = post( movement( movement_type = '551' batch = '' ) ) msgno = '007' ).
  ENDMETHOD.

  METHOD batch_for_plain_material_fails.
    assert_error( message = post( movement( material = 'CRATE-20' ) ) msgno = '008' ).
  ENDMETHOD.

  METHOD unknown_batch_fails.
    assert_error( message = post( movement( batch = '2000000077' ) ) msgno = '009' ).
  ENDMETHOD.

  METHOD expired_batch_issue_fails.
    assert_error( message = post( movement( batch = '2000000002' quantity = 10 ) ) msgno = '010' ).
  ENDMETHOD.

  METHOD not_enough_free_stock_fails.
    assert_error( message = post( movement( quantity = 600 ) ) msgno = '011' ).
  ENDMETHOD.

  METHOD fefo_takes_earliest_expiry.
    DATA new_batch TYPE abap_boolean.
    DATA(data) = movement( batch = '' quantity = 150 ).

    DATA(message) = handler->check_batch( EXPORTING material  = VALUE #( Material = 'MALT-PILS' IsBatchManaged = abap_true )
                                          IMPORTING new_batch = new_batch
                                          CHANGING  movement  = data ).

    cl_abap_unit_assert=>assert_not_bound( message ).
    cl_abap_unit_assert=>assert_equals( act = data-Batch exp = '2000000005' ).
  ENDMETHOD.

  METHOD fefo_without_batch_fails.
    assert_error( message = post( movement( batch = '' quantity = 900 ) ) msgno = '012' ).
  ENDMETHOD.

  METHOD transfer_same_location_fails.
    DATA(data) = movement( movement_type = '311' ).
    data-ReceivingLocation = data-StorageLocation.

    assert_error( message = post( data ) msgno = '013' ).
  ENDMETHOD.

  METHOD scrapping_takes_blocked_stock.
    DATA(data) = movement( movement_type = '551' quantity = 100 ).
    data-Batch = '2000000003'.

    cl_abap_unit_assert=>assert_not_bound( handler->check_stock( data ) ).
  ENDMETHOD.

  METHOD reversal_mirrors_item.
    DATA(reversal) = handler->reversal_of( item        = VALUE #( MovementType = '101' Material = 'MALT-PILS' Quantity = 100 )
                                           item_number = '0001' ).

    cl_abap_unit_assert=>assert_equals( act = reversal-MovementType exp = '102' ).
    cl_abap_unit_assert=>assert_equals( act = reversal-ReversedItem exp = '0001' ).
    cl_abap_unit_assert=>assert_equals( act = reversal-Quantity exp = 100 ).
  ENDMETHOD.

  METHOD reversal_of_reversal_fails.
    assert_error( message = handler->check_reversal( document = '4900000002' reversed = '4900000001' items = VALUE #( ) )
                  msgno   = '015' ).
  ENDMETHOD.

  METHOD second_reversal_fails.
    assert_error( message = handler->check_reversal( document = '4900000001' reversed = '' items = VALUE #( ) )
                  msgno   = '014' ).
  ENDMETHOD.

  METHOD used_receipt_reversal_fails.
    " The receipt brought 1,000 kg, but only 500 kg are left in the store
    DATA(items) = VALUE lhc_material_document=>tt_items(
      ( MovementType = '102' Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01'
        Batch = '2000000001' Quantity = 1000 ) ).

    assert_error( message = handler->check_reversal( document = '4900000010' reversed = '' items = items )
                  msgno   = '018' ).
  ENDMETHOD.

ENDCLASS.

