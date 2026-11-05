*"* use this source file for your ABAP unit test classes

"! Validations, determinations and feature control of the price condition BO.
"! The transactional buffer and the tables ZVHB_MAT and ZVHB_PRICE are replaced by test doubles.
CLASS ltc_price DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_pricecondition.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_pricecondition.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_pricecondition.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_pricecondition\\price.
    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_mat WITH EMPTY KEY.
    TYPES tt_prices    TYPE STANDARD TABLE OF zvhb_price WITH EMPTY KEY.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA price_handler TYPE REF TO lhc_price.
    DATA scale_handler TYPE REF TO lhc_scale.
    DATA failed        TYPE ty_failed.
    DATA reported      TYPE ty_reported.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS valid_base_price_passes FOR TESTING.
    METHODS known_condition_type_passes FOR TESTING.
    METHODS unknown_condition_type_fails FOR TESTING.
    METHODS unknown_material_fails FOR TESTING.
    METHODS inactive_material_fails FOR TESTING.
    METHODS deposit_needs_empties FOR TESTING.
    METHODS deposit_for_crate_passes FOR TESTING.
    METHODS base_price_needs_channel FOR TESTING.
    METHODS unknown_channel_fails FOR TESTING.
    METHODS reversed_validity_fails FOR TESTING.
    METHODS zero_amount_fails FOR TESTING.
    METHODS overlapping_validity_fails FOR TESTING.
    METHODS following_validity_passes FOR TESTING.
    METHODS new_price_gets_defaults FOR TESTING.
    METHODS deposit_clears_channel FOR TESTING.
    METHODS unit_taken_from_material FOR TESTING.
    METHODS deposit_has_no_scales FOR TESTING.
    METHODS zero_scale_quantity_fails FOR TESTING.
    METHODS discount_over_100_fails FOR TESTING.

    METHODS create_price
      IMPORTING
        condition_type TYPE zvhb_cond_type DEFAULT 'BASE'
        material       TYPE zvhb_material DEFAULT 'PILS-BTL05'
        channel        TYPE zvhb_distr_channel DEFAULT 'GA'
        valid_from     TYPE d DEFAULT '20261101'
        valid_to       TYPE d DEFAULT '99991231'
        amount         TYPE zvhb_amount DEFAULT '0.89'
        currency       TYPE zvhb_currency DEFAULT 'EUR'
      RETURNING
        VALUE(result)  TYPE ty_mapped.

    METHODS create_scale
      IMPORTING
        from_quantity TYPE zvhb_quantity
        discount      TYPE zvhb_percent
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS validate_price
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_price IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_PRICECONDITION' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_MAT' ) ( 'ZVHB_PRICE' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    DATA(materials) = VALUE tt_materials(
      ( material = 'PILS-BTL05' material_type = 'FERT' base_unit = 'ST' is_active = abap_true )
      ( material = 'CRATE-20'   material_type = 'LEER' base_unit = 'ST' is_active = abap_true )
      ( material = 'OLD-BTL05'  material_type = 'FERT' base_unit = 'ST' is_active = abap_false ) ).
    sql_environment->insert_test_data( materials ).

    " Saved base price for the gastronomy channel until the end of October 2026
    DATA(saved_prices) = VALUE tt_prices(
      ( price_uuid = '0A1B2C3D4E5F60718293A4B5C6D7E8F9'
        condition_type = 'BASE' material = 'PILS-BTL05' distr_channel = 'GA'
        valid_from = '20260101' valid_to = '20261031' amount = '0.85' currency = 'EUR' base_unit = 'ST' ) ).
    sql_environment->insert_test_data( saved_prices ).

    CREATE OBJECT price_handler FOR TESTING.
    CREATE OBJECT scale_handler FOR TESTING.
    CLEAR: failed, reported.
  ENDMETHOD.

  METHOD create_price.
    MODIFY ENTITIES OF zvhb_r_pricecondition
      ENTITY Price
        CREATE FIELDS ( ConditionType Material DistributionChannel ValidFrom ValidTo Amount Currency )
        WITH VALUE #( ( %cid                = 'PRICE'
                        ConditionType       = condition_type
                        Material            = material
                        DistributionChannel = channel
                        ValidFrom           = valid_from
                        ValidTo             = valid_to
                        Amount              = amount
                        Currency            = currency ) )
      MAPPED result.
  ENDMETHOD.

  METHOD create_scale.
    MODIFY ENTITIES OF zvhb_r_pricecondition
      ENTITY Price
        CREATE FIELDS ( ConditionType Material DistributionChannel ValidFrom ValidTo Amount Currency )
        WITH VALUE #( ( %cid = 'PRICE' ConditionType = 'BASE' Material = 'PILS-BTL05' DistributionChannel = 'GA'
                        ValidFrom = '20261101' ValidTo = '99991231' Amount = '0.89' Currency = 'EUR' ) )
        CREATE BY \_Scale
        FIELDS ( FromQuantity DiscountPercent )
        WITH VALUE #( ( %cid_ref = 'PRICE'
                        %target  = VALUE #( ( %cid            = 'SCALE'
                                              FromQuantity    = from_quantity
                                              DiscountPercent = discount ) ) ) )
      MAPPED result.
  ENDMETHOD.

  METHOD validate_price.
    DATA(keys) = mapped-price.
    price_handler->validatematerial( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    price_handler->validatechannel( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    price_handler->validatevalidity( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    price_handler->validateamount( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    price_handler->validateoverlap( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_differs( act = lines( failed-price ) + lines( failed-scale )
                                         exp = 0
                                         msg = 'Validation should fail' ).

    DATA(messages) = VALUE string_table(
      FOR p IN reported-price WHERE ( %msg IS BOUND ) ( CONV string( p-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR s IN reported-scale WHERE ( %msg IS BOUND ) ( CONV string( s-%msg->if_t100_message~t100key-msgno ) ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MD { msgno } expected| ).
  ENDMETHOD.

  METHOD valid_base_price_passes.
    validate_price( create_price( ) ).

    cl_abap_unit_assert=>assert_initial( failed-price ).
  ENDMETHOD.

  METHOD known_condition_type_passes.
    DATA(mapped) = create_price( condition_type = 'DEPO' ).

    price_handler->validateconditiontype( EXPORTING keys = CORRESPONDING #( mapped-price ) CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-price ).
  ENDMETHOD.

  METHOD unknown_condition_type_fails.
    DATA(mapped) = create_price( condition_type = 'XXXX' ).

    price_handler->validateconditiontype( EXPORTING keys = CORRESPONDING #( mapped-price ) CHANGING failed = failed reported = reported ).

    assert_error( '020' ).
  ENDMETHOD.

  METHOD unknown_material_fails.
    validate_price( create_price( material = 'NOPE' ) ).

    assert_error( '021' ).
  ENDMETHOD.

  METHOD inactive_material_fails.
    validate_price( create_price( material = 'OLD-BTL05' ) ).

    assert_error( '022' ).
  ENDMETHOD.

  METHOD deposit_needs_empties.
    validate_price( create_price( condition_type = 'DEPO' channel = '' ) ).

    assert_error( '024' ).
  ENDMETHOD.

  METHOD deposit_for_crate_passes.
    validate_price( create_price( condition_type = 'DEPO' material = 'CRATE-20' channel = '' amount = '3.10' ) ).

    cl_abap_unit_assert=>assert_initial( failed-price ).
  ENDMETHOD.

  METHOD base_price_needs_channel.
    validate_price( create_price( channel = '' ) ).

    assert_error( '030' ).
  ENDMETHOD.

  METHOD unknown_channel_fails.
    validate_price( create_price( channel = 'XX' ) ).

    assert_error( '023' ).
  ENDMETHOD.

  METHOD reversed_validity_fails.
    validate_price( create_price( valid_from = '20261201' valid_to = '20261130' ) ).

    assert_error( '025' ).
  ENDMETHOD.

  METHOD zero_amount_fails.
    validate_price( create_price( amount = 0 ) ).

    assert_error( '026' ).
  ENDMETHOD.

  METHOD overlapping_validity_fails.
    validate_price( create_price( valid_from = '20261001' ) ).

    assert_error( '027' ).
  ENDMETHOD.

  METHOD following_validity_passes.
    validate_price( create_price( valid_from = '20261101' ) ).

    cl_abap_unit_assert=>assert_initial( failed-price ).
  ENDMETHOD.

  METHOD new_price_gets_defaults.
    DATA(mapped) = create_price( valid_from = '00000000' valid_to = '00000000' currency = '' ).

    price_handler->setdefaults( keys = CORRESPONDING #( mapped-price ) ).

    READ ENTITIES OF zvhb_r_pricecondition
      ENTITY Price FIELDS ( Currency ValidFrom ValidTo ) WITH CORRESPONDING #( mapped-price )
      RESULT DATA(prices).
    cl_abap_unit_assert=>assert_equals( act = prices[ 1 ]-Currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = prices[ 1 ]-ValidFrom exp = cl_abap_context_info=>get_system_date( ) ).
    cl_abap_unit_assert=>assert_equals( act = prices[ 1 ]-ValidTo exp = '99991231' ).
  ENDMETHOD.

  METHOD deposit_clears_channel.
    DATA(mapped) = create_price( condition_type = 'DEPO' material = 'CRATE-20' ).

    price_handler->cleardepositchannel( keys = CORRESPONDING #( mapped-price ) ).

    READ ENTITIES OF zvhb_r_pricecondition
      ENTITY Price FIELDS ( DistributionChannel ) WITH CORRESPONDING #( mapped-price )
      RESULT DATA(prices).
    cl_abap_unit_assert=>assert_initial( prices[ 1 ]-DistributionChannel ).
  ENDMETHOD.

  METHOD unit_taken_from_material.
    DATA(mapped) = create_price( ).

    price_handler->setbaseunit( keys = CORRESPONDING #( mapped-price ) ).

    READ ENTITIES OF zvhb_r_pricecondition
      ENTITY Price FIELDS ( BaseUnit ) WITH CORRESPONDING #( mapped-price )
      RESULT DATA(prices).
    cl_abap_unit_assert=>assert_equals( act = prices[ 1 ]-BaseUnit exp = 'ST' ).
  ENDMETHOD.

  METHOD deposit_has_no_scales.
    DATA features TYPE ty_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_pricecondition.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_pricecondition.
    DATA(mapped) = create_price( condition_type = 'DEPO' material = 'CRATE-20' channel = '' ).

    price_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-price )
        requested_features = VALUE #( %assoc-_Scale = if_abap_behv=>mk-on %field-DistributionChannel = if_abap_behv=>mk-on )
      CHANGING
        result             = features
        failed             = failed_early
        reported           = reported_early ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%assoc-_Scale exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%field-DistributionChannel exp = if_abap_behv=>fc-f-read_only ).
  ENDMETHOD.

  METHOD zero_scale_quantity_fails.
    DATA(mapped) = create_scale( from_quantity = 0 discount = 5 ).

    scale_handler->validatescale( EXPORTING keys = CORRESPONDING #( mapped-scale ) CHANGING failed = failed reported = reported ).

    assert_error( '028' ).
  ENDMETHOD.

  METHOD discount_over_100_fails.
    DATA(mapped) = create_scale( from_quantity = 100 discount = 120 ).

    scale_handler->validatescale( EXPORTING keys = CORRESPONDING #( mapped-scale ) CHANGING failed = failed reported = reported ).

    assert_error( '029' ).
  ENDMETHOD.

ENDCLASS.

