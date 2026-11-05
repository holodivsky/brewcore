*"* use this source file for your ABAP unit test classes

"! Validations and determinations of the recipe BO on all three levels.
"! The transactional buffer and the tables ZVHB_MAT and ZVHB_RECIPE are replaced by test doubles.
CLASS ltc_recipe DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_recipe.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_recipe.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_recipe.
    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_mat WITH EMPTY KEY.
    TYPES tt_recipes   TYPE STANDARD TABLE OF zvhb_recipe WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_version,
        cid          TYPE abp_behv_cid,
        active       TYPE abap_boolean,
        yield        TYPE zvhb_quantity,
        gravity      TYPE zvhb_plato,
        alcohol      TYPE zvhb_alcohol,
        fermentation TYPE zvhb_days,
        maturation   TYPE zvhb_days,
      END OF ty_version,
      tt_versions TYPE STANDARD TABLE OF ty_version WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_component,
        version_cid TYPE abp_behv_cid,
        cid         TYPE abp_behv_cid,
        material    TYPE zvhb_material,
        quantity    TYPE zvhb_quantity,
      END OF ty_component,
      tt_components TYPE STANDARD TABLE OF ty_component WITH EMPTY KEY.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA recipe_handler    TYPE REF TO lhc_recipe.
    DATA version_handler   TYPE REF TO lhc_version.
    DATA component_handler TYPE REF TO lhc_component.
    DATA failed            TYPE ty_failed.
    DATA reported          TYPE ty_reported.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS valid_recipe_passes FOR TESTING.
    METHODS unknown_material_fails FOR TESTING.
    METHODS inactive_material_fails FOR TESTING.
    METHODS raw_material_recipe_fails FOR TESTING.
    METHODS second_recipe_for_beer_fails FOR TESTING.
    METHODS valid_version_passes FOR TESTING.
    METHODS zero_yield_fails FOR TESTING.
    METHODS gravity_out_of_range_fails FOR TESTING.
    METHODS alcohol_out_of_range_fails FOR TESTING.
    METHODS no_fermentation_days_fails FOR TESTING.
    METHODS one_active_version_passes FOR TESTING.
    METHODS two_active_versions_fail FOR TESTING.
    METHODS active_version_needs_parts FOR TESTING.
    METHODS new_versions_are_numbered FOR TESTING.
    METHODS valid_component_passes FOR TESTING.
    METHODS packaging_component_fails FOR TESTING.
    METHODS zero_quantity_fails FOR TESTING.
    METHODS duplicate_component_fails FOR TESTING.
    METHODS component_gets_base_unit FOR TESTING.

    METHODS create_recipe
      IMPORTING
        material      TYPE zvhb_material DEFAULT 'PILS'
        versions      TYPE tt_versions OPTIONAL
        components    TYPE tt_components OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_mapped.

    "! A plausible Pils version: 50 hl, 11.5 °P, 4.9 % vol, 7 days fermentation, 21 days maturation
    METHODS pils_version
      IMPORTING
        cid           TYPE abp_behv_cid DEFAULT 'V1'
        active        TYPE abap_boolean DEFAULT abap_true
      RETURNING
        VALUE(result) TYPE ty_version.

    "! Malt and hops for one version
    METHODS pils_components
      IMPORTING
        version_cid   TYPE abp_behv_cid DEFAULT 'V1'
      RETURNING
        VALUE(result) TYPE tt_components.

    METHODS validate_versions
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS validate_components
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_recipe IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_RECIPE' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_MAT' ) ( 'ZVHB_RECIPE' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    DATA(materials) = VALUE tt_materials(
      ( material = 'PILS'       material_type = 'FERT' base_unit = 'ST' is_active = abap_true )
      ( material = 'HELLES'     material_type = 'FERT' base_unit = 'ST' is_active = abap_true )
      ( material = 'DUNKEL-OLD' material_type = 'FERT' base_unit = 'ST' is_active = abap_false )
      ( material = 'MALT-PILS'  material_type = 'ROH'  base_unit = 'KG' is_active = abap_true )
      ( material = 'HOPS-HALL'  material_type = 'ROH'  base_unit = 'KG' is_active = abap_true )
      ( material = 'CAP-26'     material_type = 'VERP' base_unit = 'ST' is_active = abap_true ) ).
    sql_environment->insert_test_data( materials ).

    " Saved recipe for Helles
    DATA(saved_recipes) = VALUE tt_recipes( ( recipe_uuid = '1A2B3C4D5E6F708192A3B4C5D6E7F801' material = 'HELLES' ) ).
    sql_environment->insert_test_data( saved_recipes ).

    CREATE OBJECT recipe_handler FOR TESTING.
    CREATE OBJECT version_handler FOR TESTING.
    CREATE OBJECT component_handler FOR TESTING.
    CLEAR: failed, reported.
  ENDMETHOD.

  METHOD create_recipe.
    MODIFY ENTITIES OF zvhb_r_recipe
      ENTITY Recipe
        CREATE FIELDS ( Material )
        WITH VALUE #( ( %cid = 'RECIPE' Material = material ) )
        CREATE BY \_Version
        FIELDS ( IsActive YieldQuantity TargetGravity TargetAlcohol FermentationDays MaturationDays )
        WITH VALUE #( ( %cid_ref = 'RECIPE'
                        %target  = VALUE #( FOR version IN versions
                                            ( %cid             = version-cid
                                              IsActive         = version-active
                                              YieldQuantity    = version-yield
                                              TargetGravity    = version-gravity
                                              TargetAlcohol    = version-alcohol
                                              FermentationDays = version-fermentation
                                              MaturationDays   = version-maturation ) ) ) )
      ENTITY Version
        CREATE BY \_Component
        FIELDS ( Material Quantity )
        WITH VALUE #( FOR version IN versions
                      ( %cid_ref = version-cid
                        %target  = VALUE #( FOR component IN components WHERE ( version_cid = version-cid )
                                            ( %cid     = component-cid
                                              Material = component-material
                                              Quantity = component-quantity ) ) ) )
      MAPPED result.
  ENDMETHOD.

  METHOD pils_version.
    result = VALUE #( cid          = cid
                      active       = active
                      yield        = 50
                      gravity      = '11.5'
                      alcohol      = '4.90'
                      fermentation = 7
                      maturation   = 21 ).
  ENDMETHOD.

  METHOD pils_components.
    result = VALUE #( ( version_cid = version_cid cid = |{ version_cid }-MALT| material = 'MALT-PILS' quantity = 900 )
                      ( version_cid = version_cid cid = |{ version_cid }-HOPS| material = 'HOPS-HALL' quantity = 12 ) ).
  ENDMETHOD.

  METHOD validate_versions.
    DATA(keys) = mapped-version.
    version_handler->validateversion( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    version_handler->validatesingleactive( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    version_handler->validatecomponents( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
  ENDMETHOD.

  METHOD validate_components.
    DATA(keys) = mapped-component.
    component_handler->validatecomponent( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_differs( act = lines( failed-recipe ) + lines( failed-version ) + lines( failed-component )
                                         exp = 0
                                         msg = 'Validation should fail' ).

    DATA(messages) = VALUE string_table(
      FOR r IN reported-recipe WHERE ( %msg IS BOUND ) ( CONV string( r-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR v IN reported-version WHERE ( %msg IS BOUND ) ( CONV string( v-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR c IN reported-component WHERE ( %msg IS BOUND ) ( CONV string( c-%msg->if_t100_message~t100key-msgno ) ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MD { msgno } expected| ).
  ENDMETHOD.

  METHOD valid_recipe_passes.
    DATA(mapped) = create_recipe( ).

    recipe_handler->validatematerial( EXPORTING keys = CORRESPONDING #( mapped-recipe ) CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-recipe ).
  ENDMETHOD.

  METHOD unknown_material_fails.
    DATA(mapped) = create_recipe( material = 'NO-SUCH-BEER' ).

    recipe_handler->validatematerial( EXPORTING keys = CORRESPONDING #( mapped-recipe ) CHANGING failed = failed reported = reported ).

    assert_error( '021' ).
  ENDMETHOD.

  METHOD inactive_material_fails.
    DATA(mapped) = create_recipe( material = 'DUNKEL-OLD' ).

    recipe_handler->validatematerial( EXPORTING keys = CORRESPONDING #( mapped-recipe ) CHANGING failed = failed reported = reported ).

    assert_error( '022' ).
  ENDMETHOD.

  METHOD raw_material_recipe_fails.
    DATA(mapped) = create_recipe( material = 'MALT-PILS' ).

    recipe_handler->validatematerial( EXPORTING keys = CORRESPONDING #( mapped-recipe ) CHANGING failed = failed reported = reported ).

    assert_error( '032' ).
  ENDMETHOD.

  METHOD second_recipe_for_beer_fails.
    DATA(mapped) = create_recipe( material = 'HELLES' ).

    recipe_handler->validatematerial( EXPORTING keys = CORRESPONDING #( mapped-recipe ) CHANGING failed = failed reported = reported ).

    assert_error( '033' ).
  ENDMETHOD.

  METHOD valid_version_passes.
    validate_versions( create_recipe( versions   = VALUE #( ( pils_version( ) ) )
                                      components = pils_components( ) ) ).

    cl_abap_unit_assert=>assert_initial( failed-version ).
  ENDMETHOD.

  METHOD zero_yield_fails.
    DATA(version) = pils_version( active = abap_false ).
    version-yield = 0.

    validate_versions( create_recipe( versions = VALUE #( ( version ) ) ) ).

    assert_error( '036' ).
  ENDMETHOD.

  METHOD gravity_out_of_range_fails.
    DATA(version) = pils_version( active = abap_false ).
    version-gravity = '35.0'.

    validate_versions( create_recipe( versions = VALUE #( ( version ) ) ) ).

    assert_error( '037' ).
  ENDMETHOD.

  METHOD alcohol_out_of_range_fails.
    DATA(version) = pils_version( active = abap_false ).
    version-alcohol = '16.00'.

    validate_versions( create_recipe( versions = VALUE #( ( version ) ) ) ).

    assert_error( '038' ).
  ENDMETHOD.

  METHOD no_fermentation_days_fails.
    DATA(version) = pils_version( active = abap_false ).
    version-fermentation = 0.

    validate_versions( create_recipe( versions = VALUE #( ( version ) ) ) ).

    assert_error( '039' ).
  ENDMETHOD.

  METHOD one_active_version_passes.
    validate_versions( create_recipe( versions   = VALUE #( ( pils_version( cid = 'V1' active = abap_true ) )
                                                            ( pils_version( cid = 'V2' active = abap_false ) ) )
                                      components = VALUE #( ( LINES OF pils_components( 'V1' ) )
                                                            ( LINES OF pils_components( 'V2' ) ) ) ) ).

    cl_abap_unit_assert=>assert_initial( failed-version ).
  ENDMETHOD.

  METHOD two_active_versions_fail.
    validate_versions( create_recipe( versions   = VALUE #( ( pils_version( cid = 'V1' ) )
                                                            ( pils_version( cid = 'V2' ) ) )
                                      components = VALUE #( ( LINES OF pils_components( 'V1' ) )
                                                            ( LINES OF pils_components( 'V2' ) ) ) ) ).

    assert_error( '034' ).
  ENDMETHOD.

  METHOD active_version_needs_parts.
    validate_versions( create_recipe( versions = VALUE #( ( pils_version( ) ) ) ) ).

    assert_error( '035' ).
  ENDMETHOD.

  METHOD new_versions_are_numbered.
    DATA(mapped) = create_recipe( versions = VALUE #( ( pils_version( cid = 'V1' active = abap_false ) )
                                                      ( pils_version( cid = 'V2' active = abap_false ) ) ) ).

    version_handler->setdefaults( keys = CORRESPONDING #( mapped-version ) ).

    READ ENTITIES OF zvhb_r_recipe
      ENTITY Version FIELDS ( Version YieldUnit ) WITH CORRESPONDING #( mapped-version )
      RESULT DATA(versions).
    SORT versions BY Version.
    cl_abap_unit_assert=>assert_equals( act = versions[ 1 ]-Version exp = '001' ).
    cl_abap_unit_assert=>assert_equals( act = versions[ 2 ]-Version exp = '002' ).
    cl_abap_unit_assert=>assert_equals( act = versions[ 1 ]-YieldUnit exp = 'HL' ).
  ENDMETHOD.

  METHOD valid_component_passes.
    validate_components( create_recipe( versions   = VALUE #( ( pils_version( ) ) )
                                        components = pils_components( ) ) ).

    cl_abap_unit_assert=>assert_initial( failed-component ).
  ENDMETHOD.

  METHOD packaging_component_fails.
    validate_components( create_recipe(
      versions   = VALUE #( ( pils_version( ) ) )
      components = VALUE #( ( version_cid = 'V1' cid = 'CAP' material = 'CAP-26' quantity = 100 ) ) ) ).

    assert_error( '041' ).
  ENDMETHOD.

  METHOD zero_quantity_fails.
    validate_components( create_recipe(
      versions   = VALUE #( ( pils_version( ) ) )
      components = VALUE #( ( version_cid = 'V1' cid = 'MALT' material = 'MALT-PILS' quantity = 0 ) ) ) ).

    assert_error( '042' ).
  ENDMETHOD.

  METHOD duplicate_component_fails.
    validate_components( create_recipe(
      versions   = VALUE #( ( pils_version( ) ) )
      components = VALUE #( ( version_cid = 'V1' cid = 'MALT-1' material = 'MALT-PILS' quantity = 600 )
                            ( version_cid = 'V1' cid = 'MALT-2' material = 'MALT-PILS' quantity = 300 ) ) ) ).

    assert_error( '043' ).
  ENDMETHOD.

  METHOD component_gets_base_unit.
    DATA(mapped) = create_recipe( versions   = VALUE #( ( pils_version( ) ) )
                                  components = pils_components( ) ).

    component_handler->setunit( keys = CORRESPONDING #( mapped-component ) ).

    READ ENTITIES OF zvhb_r_recipe
      ENTITY Component FIELDS ( Unit ) WITH CORRESPONDING #( mapped-component )
      RESULT DATA(components).
    cl_abap_unit_assert=>assert_equals( act = components[ 1 ]-Unit exp = 'KG' ).
  ENDMETHOD.

ENDCLASS.

