*"* use this source file for your ABAP unit test classes

"! Recipe copy, checks, availability on release and the phases of the brew order. The transactional
"! buffer, recipes, tanks, materials, stock and other brew orders are replaced by test doubles.
"! Mashing, fermentation and filling post in inventory and change the tank; they are checked in the app.
CLASS ltc_brew_order DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_breworder.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_breworder.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_breworder.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_breworder\\breworder.

    TYPES tt_recipes      TYPE STANDARD TABLE OF zvhb_i_beerrecipevh WITH EMPTY KEY.
    TYPES tt_recipe_items TYPE STANDARD TABLE OF zvhb_r_recipecomponent WITH EMPTY KEY.
    TYPES tt_tanks        TYPE STANDARD TABLE OF zvhb_ftank WITH EMPTY KEY.
    TYPES tt_materials    TYPE STANDARD TABLE OF zvhb_mat WITH EMPTY KEY.
    TYPES tt_stock        TYPE STANDARD TABLE OF zvhb_i_availablestock WITH EMPTY KEY.
    TYPES tt_requirements TYPE STANDARD TABLE OF zvhb_i_openrequirement WITH EMPTY KEY.
    TYPES tt_orders       TYPE STANDARD TABLE OF zvhb_brewhdr WITH EMPTY KEY.
    TYPES tt_recipe_headers  TYPE STANDARD TABLE OF zvhb_recipe WITH EMPTY KEY.
    TYPES tt_recipe_versions TYPE STANDARD TABLE OF zvhb_rcpver WITH EMPTY KEY.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA order_handler     TYPE REF TO lhc_brew_order.
    DATA component_handler TYPE REF TO lhc_component.
    DATA failed            TYPE ty_failed.
    DATA reported          TYPE ty_reported.
    DATA start             TYPE d.

    "! Responses of actions, which report in the interaction phase
    DATA mapped_early   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_breworder.
    DATA failed_early   TYPE RESPONSE FOR FAILED EARLY zvhb_r_breworder.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_breworder.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS new_order_gets_defaults FOR TESTING.
    METHODS recipe_is_copied FOR TESTING.
    METHODS components_are_scaled FOR TESTING.
    METHODS new_quantity_rescales FOR TESTING.
    METHODS beer_without_recipe_fails FOR TESTING.
    METHODS zero_quantity_fails FOR TESTING.
    METHODS tank_too_small_fails FOR TESTING.
    METHODS unknown_tank_fails FOR TESTING.
    METHODS start_in_past_fails FOR TESTING.
    METHODS finished_good_component_fails FOR TESTING.
    METHODS available_order_is_released FOR TESTING.
    METHODS missing_stock_blocks_release FOR TESTING.
    METHODS requirements_reduce_stock FOR TESTING.
    METHODS planned_tank_blocks_release FOR TESTING.
    METHODS released_order_is_locked FOR TESTING.
    METHODS boiling_follows_mashing FOR TESTING.

    "! Brew order for Pils in tank FT-01, starting in a week; determinations are run as in the app
    METHODS create_order
      IMPORTING
        material      TYPE zvhb_material DEFAULT 'PILS'
        quantity      TYPE zvhb_quantity DEFAULT 100
        tank          TYPE zvhb_tank DEFAULT 'FT-01'
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS read_order
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE zvhb_r_breworder.

    METHODS release
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.

    METHODS assert_message
      IMPORTING
        msgno TYPE symsgno.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_brew_order IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_BREWORDER' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_I_BEERRECIPEVH' )
                                                                                     ( 'ZVHB_R_RECIPECOMPONENT' )
                                                                                     ( 'ZVHB_FTANK' )
                                                                                     ( 'ZVHB_MAT' )
                                                                                     ( 'ZVHB_I_AVAILABLESTOCK' )
                                                                                     ( 'ZVHB_I_OPENREQUIREMENT' )
                                                                                     ( 'ZVHB_BREWHDR' )
                                                                                     ( 'ZVHB_RECIPE' )
                                                                                     ( 'ZVHB_RCPVER' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).
    start = cl_abap_context_info=>get_system_date( ) + 7.

    " Pils: 50 hl per brew from 900 kg malt, 12 kg hops and 30 kg yeast; 7 days fermentation, 21 days maturation
    sql_environment->insert_test_data( VALUE tt_recipes(
      ( Material = 'PILS' RecipeUUID = 'A0000000000000000000000000000001' VersionUUID = 'B0000000000000000000000000000001'
        Version = '002' YieldUnit = 'HL' YieldQuantity = 50 FermentationDays = 7 MaturationDays = 21 ) ) ).

    sql_environment->insert_test_data( VALUE tt_recipe_headers(
      ( recipe_uuid = 'A0000000000000000000000000000001' material = 'PILS' ) ) ).
    sql_environment->insert_test_data( VALUE tt_recipe_versions(
      ( recipe_uuid = 'A0000000000000000000000000000001' version_uuid = 'B0000000000000000000000000000001'
        is_active = abap_true ) ) ).

    sql_environment->insert_test_data( VALUE tt_recipe_items(
      ( RecipeUUID = 'A0000000000000000000000000000001' VersionUUID = 'B0000000000000000000000000000001'
        ComponentUUID = 'C0000000000000000000000000000001' Material = 'MALT-PILS' Unit = 'KG' Quantity = 900 )
      ( RecipeUUID = 'A0000000000000000000000000000001' VersionUUID = 'B0000000000000000000000000000001'
        ComponentUUID = 'C0000000000000000000000000000002' Material = 'HOPS-HALL' Unit = 'KG' Quantity = 12 )
      ( RecipeUUID = 'A0000000000000000000000000000001' VersionUUID = 'B0000000000000000000000000000001'
        ComponentUUID = 'C0000000000000000000000000000003' Material = 'YEAST-W34' Unit = 'KG' Quantity = 30 ) ) ).

    sql_environment->insert_test_data( VALUE tt_tanks(
      ( tank = 'FT-01' plant = 'BR01' capacity_unit = 'HL' capacity = 400 status = 'FREE' )
      ( tank = 'FT-02' plant = 'BR01' capacity_unit = 'HL' capacity = 400 status = 'FREE' ) ) ).

    sql_environment->insert_test_data( VALUE tt_materials(
      ( material = 'MALT-PILS' material_type = 'ROH' base_unit = 'KG' is_active = abap_true )
      ( material = 'HOPS-HALL' material_type = 'ROH' base_unit = 'KG' is_active = abap_true )
      ( material = 'YEAST-W34' material_type = 'ROH' base_unit = 'KG' is_active = abap_true )
      ( material = 'PILS' material_type = 'FERT' base_unit = 'HL' is_active = abap_true ) ) ).

    sql_environment->insert_test_data( VALUE tt_stock(
      ( Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01' Unit = 'KG' FreeQuantity = 10000 )
      ( Material = 'HOPS-HALL' Plant = 'BR01' StorageLocation = 'RM01' Unit = 'KG' FreeQuantity = 300 )
      ( Material = 'YEAST-W34' Plant = 'BR01' StorageLocation = 'RM01' Unit = 'KG' FreeQuantity = 100 ) ) ).

    CREATE OBJECT order_handler FOR TESTING.
    CREATE OBJECT component_handler FOR TESTING.
    CLEAR: failed, reported, mapped_early, failed_early, reported_early.
  ENDMETHOD.

  METHOD create_order.
    MODIFY ENTITIES OF zvhb_r_breworder
      ENTITY BrewOrder
        CREATE FIELDS ( Material PlannedQuantity Tank PlannedStart )
        WITH VALUE #( ( %cid = 'BREW' Material = material PlannedQuantity = quantity Tank = tank PlannedStart = start ) )
      MAPPED result.

    order_handler->setdefaults( keys = CORRESPONDING #( result-breworder ) ).
    order_handler->copyrecipe( keys = CORRESPONDING #( result-breworder ) ).

    READ ENTITIES OF zvhb_r_breworder
      ENTITY BrewOrder BY \_Component
        FIELDS ( ComponentUUID ) WITH CORRESPONDING #( result-breworder )
      RESULT DATA(components).
    IF components IS NOT INITIAL.
      component_handler->setcomponentdefaults( keys = CORRESPONDING #( components ) ).
    ENDIF.
    result-component = CORRESPONDING #( components ).
  ENDMETHOD.

  METHOD read_order.
    READ ENTITIES OF zvhb_r_breworder
      ENTITY BrewOrder ALL FIELDS WITH CORRESPONDING #( mapped-breworder )
      RESULT DATA(orders).
    result = CORRESPONDING #( orders[ 1 ] ).
  ENDMETHOD.

  METHOD release.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_breworder\\breworder~release.

    order_handler->release( EXPORTING keys     = CORRESPONDING #( mapped-breworder )
                            CHANGING  result   = result
                                      mapped   = mapped_early
                                      failed   = failed_early
                                      reported = reported_early ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_breworder.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_breworder.

    order_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-breworder )
        requested_features = VALUE #( %update              = if_abap_behv=>mk-on
                                      %action-release      = if_abap_behv=>mk-on
                                      %action-startMashing = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed_early
        reported           = reported_early ).
  ENDMETHOD.

  METHOD assert_message.
    DATA(messages) = VALUE string_table(
      FOR r IN reported-breworder WHERE ( %msg IS BOUND ) ( CONV string( r-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR c IN reported-component WHERE ( %msg IS BOUND ) ( CONV string( c-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR e IN reported_early-breworder WHERE ( %msg IS BOUND ) ( CONV string( e-%msg->if_t100_message~t100key-msgno ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_PP { msgno } expected| ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_differs( act = lines( failed-breworder ) + lines( failed-component )
                                             + lines( failed_early-breworder )
                                         exp = 0
                                         msg = 'Check should fail' ).
    assert_message( msgno ).
  ENDMETHOD.

  METHOD new_order_gets_defaults.
    DATA(order) = read_order( create_order( ) ).

    cl_abap_unit_assert=>assert_equals( act = order-Status exp = 'NEW' ).
    cl_abap_unit_assert=>assert_equals( act = order-Plant exp = 'BR01' ).
  ENDMETHOD.

  METHOD recipe_is_copied.
    DATA(order) = read_order( create_order( ) ).

    cl_abap_unit_assert=>assert_equals( act = order-RecipeVersion exp = '002' ).
    cl_abap_unit_assert=>assert_equals( act = order-Unit exp = 'HL' ).
    " The tank is busy for 7 days of fermentation and 21 days of maturation
    cl_abap_unit_assert=>assert_equals( act = order-PlannedEnd exp = CONV d( start + 28 ) ).
  ENDMETHOD.

  METHOD components_are_scaled.
    " 100 hl is two brews of the 50 hl recipe
    DATA(mapped) = create_order( quantity = 100 ).

    READ ENTITIES OF zvhb_r_breworder
      ENTITY Component ALL FIELDS WITH CORRESPONDING #( mapped-component )
      RESULT DATA(components).
    SORT components BY Material.

    cl_abap_unit_assert=>assert_equals( act = lines( components ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = components[ Material = 'MALT-PILS' ]-Quantity exp = 1800 ).
    cl_abap_unit_assert=>assert_equals( act = components[ Material = 'HOPS-HALL' ]-Quantity exp = 24 ).
    cl_abap_unit_assert=>assert_equals( act = components[ Material = 'YEAST-W34' ]-Quantity exp = 60 ).
    cl_abap_unit_assert=>assert_equals( act = components[ Material = 'YEAST-W34' ]-StorageLocation exp = 'RM01' ).
  ENDMETHOD.

  METHOD new_quantity_rescales.
    DATA(mapped) = create_order( quantity = 100 ).
    MODIFY ENTITIES OF zvhb_r_breworder
      ENTITY BrewOrder
        UPDATE FIELDS ( PlannedQuantity )
        WITH VALUE #( ( %tky = mapped-breworder[ 1 ]-%tky PlannedQuantity = 25 ) ).

    order_handler->copyrecipe( keys = CORRESPONDING #( mapped-breworder ) ).

    READ ENTITIES OF zvhb_r_breworder
      ENTITY BrewOrder BY \_Component
        ALL FIELDS WITH CORRESPONDING #( mapped-breworder )
      RESULT DATA(components).

    " 25 hl is half a brew; the old components are gone
    cl_abap_unit_assert=>assert_equals( act = lines( components ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = components[ Material = 'MALT-PILS' ]-Quantity exp = 450 ).
  ENDMETHOD.

  METHOD beer_without_recipe_fails.
    DATA(mapped) = create_order( material = 'WEISSBIER' ).

    order_handler->validatebeer( EXPORTING keys = CORRESPONDING #( mapped-breworder ) CHANGING failed = failed reported = reported ).

    assert_error( '002' ).
  ENDMETHOD.

  METHOD zero_quantity_fails.
    DATA(mapped) = create_order( quantity = 0 ).

    order_handler->validatequantity( EXPORTING keys     = CORRESPONDING #( mapped-breworder )
                                     CHANGING  failed   = failed
                                               reported = reported ).

    assert_error( '003' ).
  ENDMETHOD.

  METHOD tank_too_small_fails.
    DATA(mapped) = create_order( quantity = 500 ).

    order_handler->validatequantity( EXPORTING keys     = CORRESPONDING #( mapped-breworder )
                                     CHANGING  failed   = failed
                                               reported = reported ).

    assert_error( '007' ).
  ENDMETHOD.

  METHOD unknown_tank_fails.
    DATA(mapped) = create_order( tank = 'FT-99' ).

    order_handler->validatetank( EXPORTING keys = CORRESPONDING #( mapped-breworder ) CHANGING failed = failed reported = reported ).

    assert_error( '005' ).
  ENDMETHOD.

  METHOD start_in_past_fails.
    start = cl_abap_context_info=>get_system_date( ) - 1.
    DATA(mapped) = create_order( ).

    order_handler->validatestart( EXPORTING keys = CORRESPONDING #( mapped-breworder ) CHANGING failed = failed reported = reported ).

    assert_error( '008' ).
  ENDMETHOD.

  METHOD finished_good_component_fails.
    DATA(mapped) = create_order( ).
    MODIFY ENTITIES OF zvhb_r_breworder
      ENTITY Component
        UPDATE FIELDS ( Material )
        WITH VALUE #( ( %tky = mapped-component[ 1 ]-%tky Material = 'PILS' ) ).

    component_handler->validatecomponent( EXPORTING keys     = CORRESPONDING #( mapped-component )
                                          CHANGING  failed   = failed
                                                    reported = reported ).

    assert_error( '014' ).
  ENDMETHOD.

  METHOD available_order_is_released.
    DATA(mapped) = create_order( ).

    release( mapped ).

    cl_abap_unit_assert=>assert_equals( act = read_order( mapped )-Status exp = 'REL' ).
    assert_message( '011' ).
  ENDMETHOD.

  METHOD missing_stock_blocks_release.
    " 200 hl need 120 kg yeast, only 100 kg are free
    DATA(mapped) = create_order( quantity = 200 ).

    release( mapped ).

    cl_abap_unit_assert=>assert_equals( act = read_order( mapped )-Status exp = 'NEW' ).
    assert_error( '010' ).
  ENDMETHOD.

  METHOD requirements_reduce_stock.
    " Another released brew will take 50 kg of the 100 kg yeast, 60 kg are needed here
    sql_environment->insert_test_data( VALUE tt_requirements(
      ( Material = 'YEAST-W34' Plant = 'BR01' StorageLocation = 'RM01' Unit = 'KG' RequiredQuantity = 50 ) ) ).
    DATA(mapped) = create_order( quantity = 100 ).

    release( mapped ).

    assert_error( '010' ).
  ENDMETHOD.

  METHOD planned_tank_blocks_release.
    " A released brew uses FT-01 for four weeks from three days after this start
    sql_environment->insert_test_data( VALUE tt_orders(
      ( brew_uuid = 'D0000000000000000000000000000001' brew_order = '6000000099' tank = 'FT-01' status = 'REL'
        planned_start = start + 3 planned_end = start + 31 ) ) ).
    DATA(mapped) = create_order( ).

    release( mapped ).

    assert_error( '009' ).
  ENDMETHOD.

  METHOD released_order_is_locked.
    DATA(mapped) = create_order( ).
    release( mapped ).

    DATA(features) = get_features( mapped ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%update exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-release exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-startMashing exp = if_abap_behv=>fc-o-enabled ).
  ENDMETHOD.

  METHOD boiling_follows_mashing.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_breworder\\breworder~startboiling.
    DATA(mapped) = create_order( ).
    order_handler->set_phase( order_keys = CORRESPONDING #( mapped-breworder ) status = 'MASH' ).

    order_handler->startboiling( EXPORTING keys     = CORRESPONDING #( mapped-breworder )
                                 CHANGING  result   = result
                                           mapped   = mapped_early
                                           failed   = failed_early
                                           reported = reported_early ).

    DATA(order) = read_order( mapped ).
    cl_abap_unit_assert=>assert_equals( act = order-Status exp = 'BOIL' ).
    cl_abap_unit_assert=>assert_equals( act = order-BoilingStart exp = cl_abap_context_info=>get_system_date( ) ).
  ENDMETHOD.

ENDCLASS.

