*"* use this source file for your ABAP unit test classes

"! FR-SD-05: a customer can return at most the crates that are at the customer. The receipt into stock and
"! the credit memo are checked in the app.
CLASS ltc_billing_document DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_balances TYPE STANDARD TABLE OF zvhb_i_emptiesbalance WITH EMPTY KEY.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.
    DATA cut TYPE REF TO lhc_billing_document.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS return_within_balance_passes FOR TESTING.
    METHODS more_than_balance_fails FOR TESTING.
    METHODS zero_quantity_fails FOR TESTING.
ENDCLASS.


CLASS ltc_billing_document IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_I_EMPTIESBALANCE' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_environment->clear_doubles( ).
    " The wholesaler has 300 crates
    sql_environment->insert_test_data( VALUE tt_balances(
      ( Customer = '1000000004' Material = 'CRATE-20' Unit = 'ST' IssuedQuantity = 300 BalanceQuantity = 300 ) ) ).
    CREATE OBJECT cut FOR TESTING.
  ENDMETHOD.

  METHOD return_within_balance_passes.
    cl_abap_unit_assert=>assert_not_bound(
      cut->check_return( VALUE #( Customer = '1000000004' Material = 'CRATE-20' Quantity = 120 ) ) ).
  ENDMETHOD.

  METHOD more_than_balance_fails.
    DATA(problem) = cut->check_return( VALUE #( Customer = '1000000004' Material = 'CRATE-20' Quantity = 301 ) ).

    cl_abap_unit_assert=>assert_bound( problem ).
    cl_abap_unit_assert=>assert_equals( exp = '020' act = problem->if_t100_message~t100key-msgno ).
  ENDMETHOD.

  METHOD zero_quantity_fails.
    DATA(problem) = cut->check_return( VALUE #( Customer = '1000000004' Material = 'CRATE-20' Quantity = 0 ) ).

    cl_abap_unit_assert=>assert_equals( exp = '019' act = problem->if_t100_message~t100key-msgno ).
  ENDMETHOD.

ENDCLASS.

