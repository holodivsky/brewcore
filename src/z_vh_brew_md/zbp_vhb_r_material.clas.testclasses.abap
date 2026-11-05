*"* use this source file for your ABAP unit test classes

"! Validations and determinations of the material BO, run against a test double
"! of its transactional buffer, so no database table is touched.
CLASS ltc_material DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_material.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_material.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_material.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_material\\material.

    CLASS-DATA environment TYPE REF TO if_botd_txbufdbl_bo_test_env.

    DATA material_handler TYPE REF TO lhc_material.
    DATA unit_handler     TYPE REF TO lhc_unit.
    DATA plant_handler    TYPE REF TO lhc_plant.
    DATA failed           TYPE ty_failed.
    DATA reported         TYPE ty_reported.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS valid_material_passes FOR TESTING.
    METHODS lowercase_number_fails FOR TESTING.
    METHODS unknown_type_fails FOR TESTING.
    METHODS missing_base_unit_fails FOR TESTING.
    METHODS unknown_base_unit_fails FOR TESTING.
    METHODS product_without_batches_fails FOR TESTING.
    METHODS batches_need_shelf_life FOR TESTING.
    METHODS packaging_without_batches_ok FOR TESTING.
    METHODS new_material_is_active FOR TESTING.
    METHODS product_gets_batch_management FOR TESTING.
    METHODS valid_conversion_passes FOR TESTING.
    METHODS zero_factor_fails FOR TESTING.
    METHODS base_unit_as_alt_unit_fails FOR TESTING.
    METHODS valid_plant_data_passes FOR TESTING.
    METHODS unknown_plant_fails FOR TESTING.
    METHODS min_above_reorder_point_fails FOR TESTING.
    METHODS negative_stock_level_fails FOR TESTING.
    METHODS plant_data_gets_base_unit FOR TESTING.
    METHODS saved_material_can_deactivate FOR TESTING.
    METHODS draft_has_no_status_actions FOR TESTING.

    METHODS create_material
      IMPORTING
        material         TYPE zvhb_material DEFAULT 'PILS-BTL05'
        material_type    TYPE zvhb_material_type DEFAULT 'FERT'
        base_unit        TYPE zvhb_unit DEFAULT 'ST'
        batch_managed    TYPE abap_boolean DEFAULT abap_true
        shelf_life_days  TYPE int2 DEFAULT 180
        draft            TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
      RETURNING
        VALUE(result)    TYPE ty_mapped.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.

    METHODS create_unit
      IMPORTING
        alt_unit      TYPE zvhb_unit
        numerator     TYPE i
        denominator   TYPE i
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS create_plant
      IMPORTING
        plant         TYPE zvhb_plant DEFAULT 'BR01'
        min_stock     TYPE zvhb_quantity
        reorder_point TYPE zvhb_quantity
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS validate_material
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_material IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_MATERIAL' ) ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    CREATE OBJECT material_handler FOR TESTING.
    CREATE OBJECT unit_handler FOR TESTING.
    CREATE OBJECT plant_handler FOR TESTING.
    CLEAR: failed, reported.
  ENDMETHOD.

  METHOD create_material.
    MODIFY ENTITIES OF zvhb_r_material
      ENTITY Material
        CREATE FIELDS ( Material MaterialType BaseUnit IsBatchManaged ShelfLifeDays )
        WITH VALUE #( ( %cid           = 'MATERIAL'
                        %is_draft      = draft
                        Material       = material
                        MaterialType   = material_type
                        BaseUnit       = base_unit
                        IsBatchManaged = batch_managed
                        ShelfLifeDays  = shelf_life_days ) )
      MAPPED result.
  ENDMETHOD.

  METHOD create_unit.
    MODIFY ENTITIES OF zvhb_r_material
      ENTITY Material
        CREATE FIELDS ( Material MaterialType BaseUnit IsBatchManaged ShelfLifeDays )
        WITH VALUE #( ( %cid = 'MATERIAL' Material = 'PILS-BTL05' MaterialType = 'FERT'
                        BaseUnit = 'ST' IsBatchManaged = abap_true ShelfLifeDays = 180 ) )
        CREATE BY \_Unit
        FIELDS ( AltUnit Numerator Denominator )
        WITH VALUE #( ( %cid_ref = 'MATERIAL'
                        %target  = VALUE #( ( %cid        = 'UNIT'
                                              AltUnit     = alt_unit
                                              Numerator   = numerator
                                              Denominator = denominator ) ) ) )
      MAPPED result.
  ENDMETHOD.

  METHOD create_plant.
    MODIFY ENTITIES OF zvhb_r_material
      ENTITY Material
        CREATE FIELDS ( Material MaterialType BaseUnit IsBatchManaged ShelfLifeDays )
        WITH VALUE #( ( %cid = 'MATERIAL' Material = 'PILS-BTL05' MaterialType = 'FERT'
                        BaseUnit = 'ST' IsBatchManaged = abap_true ShelfLifeDays = 180 ) )
        CREATE BY \_Plant
        FIELDS ( Plant MinStock ReorderPoint )
        WITH VALUE #( ( %cid_ref = 'MATERIAL'
                        %target  = VALUE #( ( %cid         = 'PLANT'
                                              Plant        = plant
                                              MinStock     = min_stock
                                              ReorderPoint = reorder_point ) ) ) )
      MAPPED result.
  ENDMETHOD.

  METHOD validate_material.
    DATA(keys) = mapped-material.
    material_handler->validatematerialnumber( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    material_handler->validatematerialtype( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    material_handler->validatebaseunit( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    material_handler->validatebatchmanagement( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_differs( act = lines( failed-material ) + lines( failed-unit ) + lines( failed-plant )
                                         exp = 0
                                         msg = 'Validation should fail' ).

    DATA(messages) = VALUE string_table(
      FOR m IN reported-material WHERE ( %msg IS BOUND ) ( CONV string( m-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR u IN reported-unit WHERE ( %msg IS BOUND ) ( CONV string( u-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR p IN reported-plant WHERE ( %msg IS BOUND ) ( CONV string( p-%msg->if_t100_message~t100key-msgno ) ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MD { msgno } expected| ).
  ENDMETHOD.

  METHOD valid_material_passes.
    validate_material( create_material( ) ).

    cl_abap_unit_assert=>assert_initial( failed-material ).
  ENDMETHOD.

  METHOD lowercase_number_fails.
    validate_material( create_material( material = 'pils-btl05' ) ).

    assert_error( '001' ).
  ENDMETHOD.

  METHOD unknown_type_fails.
    validate_material( create_material( material_type = 'XXXX' ) ).

    assert_error( '002' ).
  ENDMETHOD.

  METHOD missing_base_unit_fails.
    validate_material( create_material( base_unit = '' ) ).

    assert_error( '011' ).
  ENDMETHOD.

  METHOD unknown_base_unit_fails.
    validate_material( create_material( base_unit = 'XYZ' ) ).

    assert_error( '003' ).
  ENDMETHOD.

  METHOD product_without_batches_fails.
    validate_material( create_material( batch_managed = abap_false ) ).

    assert_error( '004' ).
  ENDMETHOD.

  METHOD batches_need_shelf_life.
    validate_material( create_material( shelf_life_days = 0 ) ).

    assert_error( '005' ).
  ENDMETHOD.

  METHOD packaging_without_batches_ok.
    validate_material( create_material( material         = 'CRATE-20'
                                        material_type    = 'VERP'
                                        batch_managed    = abap_false
                                        shelf_life_days  = 0 ) ).

    cl_abap_unit_assert=>assert_initial( failed-material ).
  ENDMETHOD.

  METHOD new_material_is_active.
    DATA(mapped) = create_material( ).

    material_handler->setdefaults( keys = CORRESPONDING #( mapped-material ) ).

    READ ENTITIES OF zvhb_r_material
      ENTITY Material FIELDS ( IsActive ) WITH CORRESPONDING #( mapped-material )
      RESULT DATA(materials).
    cl_abap_unit_assert=>assert_true( materials[ 1 ]-IsActive ).
  ENDMETHOD.

  METHOD product_gets_batch_management.
    DATA(mapped) = create_material( batch_managed = abap_false ).

    material_handler->setbatchmanagement( keys = CORRESPONDING #( mapped-material ) ).

    READ ENTITIES OF zvhb_r_material
      ENTITY Material FIELDS ( IsBatchManaged ) WITH CORRESPONDING #( mapped-material )
      RESULT DATA(materials).
    cl_abap_unit_assert=>assert_true( materials[ 1 ]-IsBatchManaged ).
  ENDMETHOD.

  METHOD valid_conversion_passes.
    DATA(mapped) = create_unit( alt_unit = 'L' numerator = 2 denominator = 1 ).

    unit_handler->validateconversion( EXPORTING keys = CORRESPONDING #( mapped-unit ) CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-unit ).
  ENDMETHOD.

  METHOD zero_factor_fails.
    DATA(mapped) = create_unit( alt_unit = 'L' numerator = 0 denominator = 1 ).

    unit_handler->validateconversion( EXPORTING keys = CORRESPONDING #( mapped-unit ) CHANGING failed = failed reported = reported ).

    assert_error( '006' ).
  ENDMETHOD.

  METHOD base_unit_as_alt_unit_fails.
    DATA(mapped) = create_unit( alt_unit = 'ST' numerator = 1 denominator = 1 ).

    unit_handler->validateconversion( EXPORTING keys = CORRESPONDING #( mapped-unit ) CHANGING failed = failed reported = reported ).

    assert_error( '007' ).
  ENDMETHOD.

  METHOD valid_plant_data_passes.
    DATA(mapped) = create_plant( min_stock = 100 reorder_point = 250 ).

    plant_handler->validateplant( EXPORTING keys = CORRESPONDING #( mapped-plant ) CHANGING failed = failed reported = reported ).
    plant_handler->validatestocklevels( EXPORTING keys = CORRESPONDING #( mapped-plant ) CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-plant ).
  ENDMETHOD.

  METHOD unknown_plant_fails.
    DATA(mapped) = create_plant( plant = 'XX01' min_stock = 100 reorder_point = 250 ).

    plant_handler->validateplant( EXPORTING keys = CORRESPONDING #( mapped-plant ) CHANGING failed = failed reported = reported ).

    assert_error( '008' ).
  ENDMETHOD.

  METHOD min_above_reorder_point_fails.
    DATA(mapped) = create_plant( min_stock = 300 reorder_point = 250 ).

    plant_handler->validatestocklevels( EXPORTING keys = CORRESPONDING #( mapped-plant ) CHANGING failed = failed reported = reported ).

    assert_error( '009' ).
  ENDMETHOD.

  METHOD negative_stock_level_fails.
    DATA(mapped) = create_plant( min_stock = -1 reorder_point = 250 ).

    plant_handler->validatestocklevels( EXPORTING keys = CORRESPONDING #( mapped-plant ) CHANGING failed = failed reported = reported ).

    assert_error( '010' ).
  ENDMETHOD.

  METHOD plant_data_gets_base_unit.
    DATA(mapped) = create_plant( min_stock = 100 reorder_point = 250 ).

    plant_handler->setbaseunit( keys = CORRESPONDING #( mapped-plant ) ).

    READ ENTITIES OF zvhb_r_material
      ENTITY Plant FIELDS ( BaseUnit ) WITH CORRESPONDING #( mapped-plant )
      RESULT DATA(plants).
    cl_abap_unit_assert=>assert_equals( act = plants[ 1 ]-BaseUnit exp = 'ST' ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_material.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_material.

    material_handler->setdefaults( keys = CORRESPONDING #( mapped-material ) ).
    material_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-material )
        requested_features = VALUE #( %action-deactivate = if_abap_behv=>mk-on
                                      %action-reactivate = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed_early
        reported           = reported_early ).
  ENDMETHOD.

  METHOD saved_material_can_deactivate.
    DATA(features) = get_features( create_material( ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-deactivate exp = if_abap_behv=>fc-o-enabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-reactivate exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

  METHOD draft_has_no_status_actions.
    " Creating a draft checks the key against the database, so use a number no real material has
    DATA(features) = get_features( create_material( material = 'ZZ-UNIT-TEST-DRAFT'
                                                    draft    = if_abap_behv=>mk-on ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-deactivate exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-reactivate exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

ENDCLASS.

