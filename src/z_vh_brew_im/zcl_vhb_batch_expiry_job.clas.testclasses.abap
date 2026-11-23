*"* use this source file for your ABAP unit test classes

"! Which batches expire within the horizon. The stock view is replaced by an SQL test double.
CLASS ltc_batch_expiry_job DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_stock TYPE STANDARD TABLE OF zvhb_i_stock WITH EMPTY KEY.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.
    DATA cut TYPE REF TO zcl_vhb_batch_expiry_job.
    DATA today TYPE d.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS batch_within_horizon_found FOR TESTING.
    METHODS later_batch_is_ignored FOR TESTING.
    METHODS expired_batch_is_found FOR TESTING.
    METHODS empty_batch_is_ignored FOR TESTING.
    METHODS earliest_comes_first FOR TESTING.
ENDCLASS.


CLASS ltc_batch_expiry_job IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_I_STOCK' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_environment->clear_doubles( ).
    cut = NEW #( ).
    today = cl_abap_context_info=>get_system_date( ).

    sql_environment->insert_test_data( VALUE tt_stock(
      ( Material = 'PILS-BTL05' Plant = 'BR01' StorageLocation = 'FG01' Batch = '2000000001' Unit = 'ST'
        ExpiryDate = today + 10 TotalQuantity = 2400 )
      ( Material = 'PILS-BTL05' Plant = 'BR01' StorageLocation = 'FG01' Batch = '2000000002' Unit = 'ST'
        ExpiryDate = today + 60 TotalQuantity = 9600 )
      ( Material = 'YEAST-W34' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000003' Unit = 'KG'
        ExpiryDate = today - 5 TotalQuantity = 10 )
      ( Material = 'YEAST-W34' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000004' Unit = 'KG'
        ExpiryDate = today + 3 TotalQuantity = 0 ) ) ).
  ENDMETHOD.

  METHOD batch_within_horizon_found.
    DATA(batches) = cut->find_expiring( plant = 'BR01' days = 14 ).

    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( batches[ batch = '2000000001' ] ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2400 act = batches[ batch = '2000000001' ]-quantity ).
  ENDMETHOD.

  METHOD later_batch_is_ignored.
    DATA(batches) = cut->find_expiring( plant = 'BR01' days = 14 ).

    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( batches[ batch = '2000000002' ] ) ) ).
  ENDMETHOD.

  METHOD expired_batch_is_found.
    DATA(batches) = cut->find_expiring( plant = 'BR01' days = 14 ).

    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( batches[ batch = '2000000003' ] ) ) ).
  ENDMETHOD.

  METHOD empty_batch_is_ignored.
    DATA(batches) = cut->find_expiring( plant = 'BR01' days = 14 ).

    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( batches[ batch = '2000000004' ] ) ) ).
  ENDMETHOD.

  METHOD earliest_comes_first.
    DATA(batches) = cut->find_expiring( plant = 'BR01' days = 90 ).

    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( batches ) ).
    cl_abap_unit_assert=>assert_equals( exp = '2000000003' act = batches[ 1 ]-batch ).
    cl_abap_unit_assert=>assert_equals( exp = '2000000002' act = batches[ 3 ]-batch ).
  ENDMETHOD.

ENDCLASS.

