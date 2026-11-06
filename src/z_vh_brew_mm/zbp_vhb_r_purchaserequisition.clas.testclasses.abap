*"* use this source file for your ABAP unit test classes

"! Number range double that always returns the same requisition number
CLASS ltd_number_range DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_vhb_number_range.
ENDCLASS.


CLASS ltd_number_range IMPLEMENTATION.

  METHOD zif_vhb_number_range~get_next.
    result = '0010000001'.
  ENDMETHOD.

ENDCLASS.


"! Defaults, checks, numbering and approval of the purchase requisition.
"! The transactional buffer and the master data views are replaced by test doubles.
CLASS ltc_requisition DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_purchaserequisition.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_purchaserequisition.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_purchaserequisition.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_purchaserequisition\\requisition.
    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_r_material WITH EMPTY KEY.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA handler  TYPE REF TO lhc_requisition.
    DATA failed   TYPE ty_failed.
    DATA reported TYPE ty_reported.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS new_requisition_gets_defaults FOR TESTING.
    METHODS unit_comes_from_material FOR TESTING.
    METHODS valid_requisition_passes FOR TESTING.
    METHODS finished_product_fails FOR TESTING.
    METHODS zero_quantity_fails FOR TESTING.
    METHODS past_delivery_date_fails FOR TESTING.
    METHODS number_assigned_on_save FOR TESTING.
    METHODS saved_requisition_approvable FOR TESTING.
    METHODS approved_is_not_changeable FOR TESTING.

    METHODS create_requisition
      IMPORTING
        material      TYPE zvhb_material DEFAULT 'MALT-PILS'
        quantity      TYPE zvhb_quantity DEFAULT 5000
        delivery_date TYPE d OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS read_requisition
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE zvhb_r_purchaserequisition.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_requisition IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_PURCHASEREQUISITION' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_R_MATERIAL' )
                                                                                     ( 'ZVHB_I_SUPPLIERVH' )
                                                                                     ( 'ZVHB_R_BUSINESSPARTNER' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    DATA(materials) = VALUE tt_materials(
      ( Material = 'MALT-PILS' MaterialType = 'ROH'  BaseUnit = 'KG' IsActive = abap_true )
      ( Material = 'PILS'      MaterialType = 'FERT' BaseUnit = 'HL' IsActive = abap_true ) ).
    sql_environment->insert_test_data( materials ).

    CREATE OBJECT handler FOR TESTING.
    handler->number_range = NEW ltd_number_range( ).
    CLEAR: failed, reported.
  ENDMETHOD.

  METHOD create_requisition.
    MODIFY ENTITIES OF zvhb_r_purchaserequisition
      ENTITY Requisition
        CREATE FIELDS ( Material Quantity DeliveryDate )
        WITH VALUE #( ( %cid = 'PR' Material = material Quantity = quantity DeliveryDate = delivery_date ) )
      MAPPED result.

    handler->setdefaults( keys = CORRESPONDING #( result-requisition ) ).
    handler->setunit( keys = CORRESPONDING #( result-requisition ) ).
  ENDMETHOD.

  METHOD read_requisition.
    READ ENTITIES OF zvhb_r_purchaserequisition
      ENTITY Requisition ALL FIELDS WITH CORRESPONDING #( mapped-requisition )
      RESULT DATA(requisitions).
    result = CORRESPONDING #( requisitions[ 1 ] ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_purchaserequisition.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_purchaserequisition.

    handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-requisition )
        requested_features = VALUE #( %update = if_abap_behv=>mk-on %action-approve = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed_early
        reported           = reported_early ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_not_initial( act = failed-requisition msg = 'Validation should fail' ).

    DATA(messages) = VALUE string_table(
      FOR m IN reported-requisition WHERE ( %msg IS BOUND ) ( CONV string( m-%msg->if_t100_message~t100key-msgno ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MM { msgno } expected| ).
  ENDMETHOD.

  METHOD new_requisition_gets_defaults.
    DATA(requisition) = read_requisition( create_requisition( ) ).

    cl_abap_unit_assert=>assert_equals( act = requisition-Status exp = 'NEW' ).
    cl_abap_unit_assert=>assert_equals( act = requisition-Plant exp = 'BR01' ).
    cl_abap_unit_assert=>assert_equals( act = requisition-StorageLocation exp = 'RM01' ).
    cl_abap_unit_assert=>assert_equals( act = requisition-DeliveryDate exp = cl_abap_context_info=>get_system_date( ) + 14 ).
  ENDMETHOD.

  METHOD unit_comes_from_material.
    cl_abap_unit_assert=>assert_equals( act = read_requisition( create_requisition( ) )-Unit exp = 'KG' ).
  ENDMETHOD.

  METHOD valid_requisition_passes.
    DATA(mapped) = create_requisition( ).

    handler->validaterequisition( EXPORTING keys = CORRESPONDING #( mapped-requisition ) CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-requisition ).
  ENDMETHOD.

  METHOD finished_product_fails.
    DATA(mapped) = create_requisition( material = 'PILS' ).

    handler->validaterequisition( EXPORTING keys = CORRESPONDING #( mapped-requisition ) CHANGING failed = failed reported = reported ).

    assert_error( '003' ).
  ENDMETHOD.

  METHOD zero_quantity_fails.
    DATA(mapped) = create_requisition( quantity = 0 ).

    handler->validaterequisition( EXPORTING keys = CORRESPONDING #( mapped-requisition ) CHANGING failed = failed reported = reported ).

    assert_error( '004' ).
  ENDMETHOD.

  METHOD past_delivery_date_fails.
    DATA(mapped) = create_requisition( delivery_date = '20200101' ).

    handler->validaterequisition( EXPORTING keys = CORRESPONDING #( mapped-requisition ) CHANGING failed = failed reported = reported ).

    assert_error( '005' ).
  ENDMETHOD.

  METHOD number_assigned_on_save.
    DATA reported_late TYPE RESPONSE FOR REPORTED LATE zvhb_r_purchaserequisition.
    DATA(mapped) = create_requisition( ).

    handler->setnumber( EXPORTING keys = CORRESPONDING #( mapped-requisition ) CHANGING reported = reported_late ).

    cl_abap_unit_assert=>assert_equals( act = read_requisition( mapped )-PurchaseRequisition exp = '0010000001' ).
  ENDMETHOD.

  METHOD saved_requisition_approvable.
    DATA(features) = get_features( create_requisition( ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-approve exp = if_abap_behv=>fc-o-enabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%update exp = if_abap_behv=>fc-o-enabled ).
  ENDMETHOD.

  METHOD approved_is_not_changeable.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_purchaserequisition\\requisition~approve.
    DATA mapped_early TYPE RESPONSE FOR MAPPED EARLY zvhb_r_purchaserequisition.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_purchaserequisition.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_purchaserequisition.
    DATA(mapped) = create_requisition( ).

    handler->approve( EXPORTING keys     = CORRESPONDING #( mapped-requisition )
                      CHANGING  result   = result
                                mapped   = mapped_early
                                failed   = failed_early
                                reported = reported_early ).

    cl_abap_unit_assert=>assert_equals( act = result[ 1 ]-%param-Status exp = 'APPR' ).
    DATA(features) = get_features( mapped ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%update exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-approve exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

ENDCLASS.

