*"* use this source file for your ABAP unit test classes

"! Material, supplier and location checks against SQL test doubles of the master data views
CLASS ltc_purchasing_check DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_r_material WITH EMPTY KEY.
    TYPES tt_suppliers TYPE STANDARD TABLE OF zvhb_i_suppliervh WITH EMPTY KEY.
    TYPES tt_partners  TYPE STANDARD TABLE OF zvhb_r_businesspartner WITH EMPTY KEY.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA check TYPE REF TO zcl_vhb_purchasing_check.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS raw_material_passes FOR TESTING.
    METHODS unknown_material_fails FOR TESTING.
    METHODS inactive_material_fails FOR TESTING.
    METHODS finished_product_fails FOR TESTING.
    METHODS supplier_passes FOR TESTING.
    METHODS empty_supplier_passes FOR TESTING.
    METHODS unknown_supplier_fails FOR TESTING.
    METHODS customer_as_supplier_fails FOR TESTING.
    METHODS blocked_supplier_fails FOR TESTING.
    METHODS valid_location_passes FOR TESTING.
    METHODS unknown_plant_fails FOR TESTING.
    METHODS unknown_location_fails FOR TESTING.
ENDCLASS.


CLASS ltc_purchasing_check IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_R_MATERIAL' )
                                                                                     ( 'ZVHB_I_SUPPLIERVH' )
                                                                                     ( 'ZVHB_R_BUSINESSPARTNER' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_environment->clear_doubles( ).

    DATA(materials) = VALUE tt_materials( ( Material = 'MALT-PILS' MaterialType = 'ROH'  IsActive = abap_true )
                                          ( Material = 'MALT-OLD'  MaterialType = 'ROH'  IsActive = abap_false )
                                          ( Material = 'PILS'      MaterialType = 'FERT' IsActive = abap_true ) ).
    sql_environment->insert_test_data( materials ).

    DATA(suppliers) = VALUE tt_suppliers( ( Supplier = '1000000020' SupplierName = 'Malt supplier' )
                                          ( Supplier = '1000000030' SupplierName = 'Blocked supplier' IsBlocked = abap_true ) ).
    sql_environment->insert_test_data( suppliers ).

    DATA(partners) = VALUE tt_partners( ( PartnerUUID = '00000000000000000000000000000020' Partner = '1000000020' )
                                        ( PartnerUUID = '00000000000000000000000000000030' Partner = '1000000030' )
                                        ( PartnerUUID = '00000000000000000000000000000040' Partner = '1000000040' ) ).
    sql_environment->insert_test_data( partners ).

    check = NEW #( ).
  ENDMETHOD.

  METHOD raw_material_passes.
    cl_abap_unit_assert=>assert_initial( check->check_material( 'MALT-PILS' ) ).
  ENDMETHOD.

  METHOD unknown_material_fails.
    cl_abap_unit_assert=>assert_equals( act = check->check_material( 'NO-SUCH' )-msgno exp = '001' ).
  ENDMETHOD.

  METHOD inactive_material_fails.
    cl_abap_unit_assert=>assert_equals( act = check->check_material( 'MALT-OLD' )-msgno exp = '002' ).
  ENDMETHOD.

  METHOD finished_product_fails.
    cl_abap_unit_assert=>assert_equals( act = check->check_material( 'PILS' )-msgno exp = '003' ).
  ENDMETHOD.

  METHOD supplier_passes.
    cl_abap_unit_assert=>assert_initial( check->check_supplier( '1000000020' ) ).
  ENDMETHOD.

  METHOD empty_supplier_passes.
    cl_abap_unit_assert=>assert_initial( check->check_supplier( '' ) ).
  ENDMETHOD.

  METHOD unknown_supplier_fails.
    cl_abap_unit_assert=>assert_equals( act = check->check_supplier( '1000009999' )-msgno exp = '008' ).
  ENDMETHOD.

  METHOD customer_as_supplier_fails.
    " Partner 1000000040 exists but has no supplier role
    cl_abap_unit_assert=>assert_equals( act = check->check_supplier( '1000000040' )-msgno exp = '009' ).
  ENDMETHOD.

  METHOD blocked_supplier_fails.
    cl_abap_unit_assert=>assert_equals( act = check->check_supplier( '1000000030' )-msgno exp = '010' ).
  ENDMETHOD.

  METHOD valid_location_passes.
    cl_abap_unit_assert=>assert_initial( check->check_location( plant = 'BR01' storage_location = 'RM01' ) ).
  ENDMETHOD.

  METHOD unknown_plant_fails.
    cl_abap_unit_assert=>assert_equals( act = check->check_location( plant = 'XX99' storage_location = 'RM01' )-msgno
                                        exp = '006' ).
  ENDMETHOD.

  METHOD unknown_location_fails.
    cl_abap_unit_assert=>assert_equals( act = check->check_location( plant = 'BR01' storage_location = 'XX99' )-msgno
                                        exp = '007' ).
  ENDMETHOD.

ENDCLASS.

