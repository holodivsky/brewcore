*"* use this source file for your ABAP unit test classes

"! Defaults and status actions of the batch BO.
"! The transactional buffer and the material view are replaced by test doubles.
CLASS ltc_batch DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_batch.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_batch\\batch.
    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_r_material WITH EMPTY KEY.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA batch_handler TYPE REF TO lhc_batch.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS new_batch_is_free FOR TESTING.
    METHODS expiry_from_shelf_life FOR TESTING.
    METHODS no_shelf_life_no_expiry FOR TESTING.
    METHODS free_batch_can_be_blocked FOR TESTING.
    METHODS blocked_batch_can_release FOR TESTING.

    METHODS create_batch
      IMPORTING
        material      TYPE zvhb_material DEFAULT 'MALT-PILS'
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS read_batch
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE zvhb_r_batch.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.
ENDCLASS.


CLASS ltc_batch IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_BATCH' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_R_MATERIAL' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    DATA(materials) = VALUE tt_materials(
      ( Material = 'MALT-PILS' MaterialType = 'ROH' BaseUnit = 'KG' IsBatchManaged = abap_true ShelfLifeDays = 365 IsActive = abap_true )
      ( Material = 'NO-LIFE'   MaterialType = 'ROH' BaseUnit = 'KG' IsBatchManaged = abap_true ShelfLifeDays = 0 IsActive = abap_true ) ).
    sql_environment->insert_test_data( materials ).

    CREATE OBJECT batch_handler FOR TESTING.
  ENDMETHOD.

  METHOD create_batch.
    MODIFY ENTITIES OF zvhb_r_batch
      ENTITY Batch
        CREATE FIELDS ( Material Batch ProductionDate )
        WITH VALUE #( ( %cid = 'BATCH' Material = material Batch = '2000000001' ProductionDate = '20261101' ) )
      MAPPED result.

    batch_handler->setdefaults( keys = CORRESPONDING #( result-batch ) ).
  ENDMETHOD.

  METHOD read_batch.
    READ ENTITIES OF zvhb_r_batch
      ENTITY Batch ALL FIELDS WITH CORRESPONDING #( mapped-batch )
      RESULT DATA(batches).
    result = CORRESPONDING #( batches[ 1 ] ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed TYPE RESPONSE FOR FAILED EARLY zvhb_r_batch.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zvhb_r_batch.

    batch_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-batch )
        requested_features = VALUE #( %action-block = if_abap_behv=>mk-on %action-release = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed
        reported           = reported ).
  ENDMETHOD.

  METHOD new_batch_is_free.
    cl_abap_unit_assert=>assert_equals( act = read_batch( create_batch( ) )-Status exp = 'FREE' ).
  ENDMETHOD.

  METHOD expiry_from_shelf_life.
    " 1 November 2026 plus 365 days
    cl_abap_unit_assert=>assert_equals( act = read_batch( create_batch( ) )-ExpiryDate exp = '20271101' ).
  ENDMETHOD.

  METHOD no_shelf_life_no_expiry.
    cl_abap_unit_assert=>assert_initial( read_batch( create_batch( 'NO-LIFE' ) )-ExpiryDate ).
  ENDMETHOD.

  METHOD free_batch_can_be_blocked.
    DATA(features) = get_features( create_batch( ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-block exp = if_abap_behv=>fc-o-enabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-release exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

  METHOD blocked_batch_can_release.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_batch\\batch~block.
    DATA mapped TYPE RESPONSE FOR MAPPED EARLY zvhb_r_batch.
    DATA failed TYPE RESPONSE FOR FAILED EARLY zvhb_r_batch.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zvhb_r_batch.
    DATA(created) = create_batch( ).

    batch_handler->block( EXPORTING keys     = CORRESPONDING #( created-batch )
                          CHANGING  result   = result
                                    mapped   = mapped
                                    failed   = failed
                                    reported = reported ).

    cl_abap_unit_assert=>assert_equals( act = result[ 1 ]-%param-Status exp = 'BLKD' ).
    DATA(features) = get_features( created ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-block exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-release exp = if_abap_behv=>fc-o-enabled ).
  ENDMETHOD.

ENDCLASS.

