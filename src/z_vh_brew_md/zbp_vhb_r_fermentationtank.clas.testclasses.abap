*"* use this source file for your ABAP unit test classes

"! Validations, determinations and feature control of the fermentation tank BO,
"! run against a test double of its transactional buffer.
CLASS ltc_tank DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed         TYPE RESPONSE FOR FAILED LATE zvhb_r_fermentationtank.
    TYPES ty_reported       TYPE RESPONSE FOR REPORTED LATE zvhb_r_fermentationtank.
    TYPES ty_mapped         TYPE RESPONSE FOR MAPPED EARLY zvhb_r_fermentationtank.
    TYPES ty_features       TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_fermentationtank\\tank.
    TYPES ty_cleaning_result TYPE TABLE FOR ACTION RESULT zvhb_r_fermentationtank\\tank~startcleaning.

    CLASS-DATA environment TYPE REF TO if_botd_txbufdbl_bo_test_env.

    DATA tank_handler TYPE REF TO lhc_tank.
    DATA failed       TYPE ty_failed.
    DATA reported     TYPE ty_reported.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS valid_tank_passes FOR TESTING.
    METHODS lowercase_number_fails FOR TESTING.
    METHODS unknown_plant_fails FOR TESTING.
    METHODS zero_capacity_fails FOR TESTING.
    METHODS new_tank_is_free_in_hl FOR TESTING.
    METHODS free_tank_can_start_cleaning FOR TESTING.
    METHODS cleaning_tank_can_finish FOR TESTING.
    METHODS draft_has_no_cleaning_actions FOR TESTING.

    METHODS create_tank
      IMPORTING
        tank          TYPE zvhb_tank DEFAULT 'FT-01'
        plant         TYPE zvhb_plant DEFAULT 'BR01'
        capacity      TYPE zvhb_quantity DEFAULT 400
        draft         TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.

    METHODS validate_tank
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_tank IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_FERMENTATIONTANK' ) ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    CREATE OBJECT tank_handler FOR TESTING.
    CLEAR: failed, reported.
  ENDMETHOD.

  METHOD create_tank.
    MODIFY ENTITIES OF zvhb_r_fermentationtank
      ENTITY Tank
        CREATE FIELDS ( Tank Plant Description Capacity )
        WITH VALUE #( ( %cid        = 'TANK'
                        %is_draft   = draft
                        Tank        = tank
                        Plant       = plant
                        Description = 'Fermentation tank 1'
                        Capacity    = capacity ) )
      MAPPED result.

    tank_handler->setdefaults( keys = CORRESPONDING #( result-tank ) ).
  ENDMETHOD.

  METHOD validate_tank.
    DATA(keys) = mapped-tank.
    tank_handler->validatetanknumber( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    tank_handler->validateplant( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    tank_handler->validatecapacity( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_fermentationtank.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_fermentationtank.

    tank_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-tank )
        requested_features = VALUE #( %delete                = if_abap_behv=>mk-on
                                      %action-startCleaning  = if_abap_behv=>mk-on
                                      %action-finishCleaning = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed_early
        reported           = reported_early ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_not_initial( act = failed-tank msg = 'Validation should fail' ).

    DATA(messages) = VALUE string_table(
      FOR m IN reported-tank WHERE ( %msg IS BOUND ) ( CONV string( m-%msg->if_t100_message~t100key-msgno ) ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MD { msgno } expected| ).
  ENDMETHOD.

  METHOD valid_tank_passes.
    validate_tank( create_tank( ) ).

    cl_abap_unit_assert=>assert_initial( failed-tank ).
  ENDMETHOD.

  METHOD lowercase_number_fails.
    validate_tank( create_tank( tank = 'ft-01' ) ).

    assert_error( '044' ).
  ENDMETHOD.

  METHOD unknown_plant_fails.
    validate_tank( create_tank( plant = 'XX99' ) ).

    assert_error( '008' ).
  ENDMETHOD.

  METHOD zero_capacity_fails.
    validate_tank( create_tank( capacity = 0 ) ).

    assert_error( '045' ).
  ENDMETHOD.

  METHOD new_tank_is_free_in_hl.
    DATA(mapped) = create_tank( ).

    READ ENTITIES OF zvhb_r_fermentationtank
      ENTITY Tank FIELDS ( Status CapacityUnit ) WITH CORRESPONDING #( mapped-tank )
      RESULT DATA(tanks).
    cl_abap_unit_assert=>assert_equals( act = tanks[ 1 ]-Status exp = 'FREE' ).
    cl_abap_unit_assert=>assert_equals( act = tanks[ 1 ]-CapacityUnit exp = 'HL' ).
  ENDMETHOD.

  METHOD free_tank_can_start_cleaning.
    DATA(features) = get_features( create_tank( ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-startCleaning exp = if_abap_behv=>fc-o-enabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-finishCleaning exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%delete exp = if_abap_behv=>fc-o-enabled ).
  ENDMETHOD.

  METHOD cleaning_tank_can_finish.
    DATA cleaning_result TYPE ty_cleaning_result.
    DATA mapped_early TYPE RESPONSE FOR MAPPED EARLY zvhb_r_fermentationtank.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_fermentationtank.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_fermentationtank.
    DATA(mapped) = create_tank( ).

    tank_handler->startcleaning( EXPORTING keys     = CORRESPONDING #( mapped-tank )
                                 CHANGING  result   = cleaning_result
                                           mapped   = mapped_early
                                           failed   = failed_early
                                           reported = reported_early ).

    cl_abap_unit_assert=>assert_equals( act = cleaning_result[ 1 ]-%param-Status exp = 'CIP' ).
    DATA(features) = get_features( mapped ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-startCleaning exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-finishCleaning exp = if_abap_behv=>fc-o-enabled ).
  ENDMETHOD.

  METHOD draft_has_no_cleaning_actions.
    " Creating a draft checks the key against the database, so use a number no real tank has
    DATA(features) = get_features( create_tank( tank  = 'ZZ-TEST-01'
                                                draft = if_abap_behv=>mk-on ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-startCleaning exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-finishCleaning exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

ENDCLASS.

