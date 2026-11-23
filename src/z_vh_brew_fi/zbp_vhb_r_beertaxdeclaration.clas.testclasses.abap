*"* use this source file for your ABAP unit test classes

"! FR-FI-03: when a declaration may be generated, which rate applies, and the transactional buffer.
"! Declarations and rates are replaced by SQL test doubles.
CLASS ltc_declaration DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_declarations TYPE STANDARD TABLE OF zvhb_btdecl WITH EMPTY KEY.
    TYPES tt_rates TYPE STANDARD TABLE OF zvhb_btrate WITH EMPTY KEY.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.
    DATA cut TYPE REF TO lhc_declaration.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS invalid_month_is_refused FOR TESTING.
    METHODS future_month_is_refused FOR TESTING.
    METHODS second_declaration_is_refused FOR TESTING.
    METHODS past_month_is_accepted FOR TESTING.
    METHODS last_day_of_the_month FOR TESTING.
    METHODS rate_valid_at_month_end FOR TESTING.
    METHODS created_and_deleted_is_dropped FOR TESTING.
ENDCLASS.


CLASS ltc_declaration IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_BTDECL' )
                                                                                     ( 'ZVHB_BTDECLITM' )
                                                                                     ( 'ZVHB_BTRATE' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_environment->clear_doubles( ).
    lcl_buffer=>clear( ).
    CREATE OBJECT cut FOR TESTING.

    sql_environment->insert_test_data( VALUE tt_declarations(
      ( decl_uuid = 'D0000000000000000000000000000001' declaration = '9000000000' plant = 'BR01'
        period_year = '2026' period_month = '10' status = 'SUBM' ) ) ).
    sql_environment->insert_test_data( VALUE tt_rates(
      ( rate_uuid = 'E0000000000000000000000000000001' plant = 'BR01' valid_from = '20230101'
        standard_rate = '0.7870' rate_percent = 100 rate_per_degree = '0.7870' currency = 'EUR' )
      ( rate_uuid = 'E0000000000000000000000000000002' plant = 'BR01' valid_from = '20261201'
        standard_rate = '0.7870' rate_percent = 75 rate_per_degree = '0.5903' currency = 'EUR' ) ) ).
  ENDMETHOD.

  METHOD teardown.
    lcl_buffer=>clear( ).
  ENDMETHOD.

  METHOD invalid_month_is_refused.
    cl_abap_unit_assert=>assert_equals(
      exp = '010'
      act = cut->check_request( request = VALUE #( plant = 'BR01' periodyear = '2026' periodmonth = '13' )
                                today   = '20261123' ) ).
  ENDMETHOD.

  METHOD future_month_is_refused.
    cl_abap_unit_assert=>assert_equals(
      exp = '013'
      act = cut->check_request( request = VALUE #( plant = 'BR01' periodyear = '2026' periodmonth = '12' )
                                today   = '20261123' ) ).
  ENDMETHOD.

  METHOD second_declaration_is_refused.
    " October is already declared
    cl_abap_unit_assert=>assert_equals(
      exp = '012'
      act = cut->check_request( request = VALUE #( plant = 'BR01' periodyear = '2026' periodmonth = '10' )
                                today   = '20261123' ) ).
  ENDMETHOD.

  METHOD past_month_is_accepted.
    " The running month may be declared as a draft and recalculated until it is submitted
    cl_abap_unit_assert=>assert_initial(
      cut->check_request( request = VALUE #( plant = 'BR01' periodyear = '2026' periodmonth = '11' )
                          today   = '20261123' ) ).
  ENDMETHOD.

  METHOD last_day_of_the_month.
    cl_abap_unit_assert=>assert_equals( exp = '20280229' act = cut->last_day( year = '2028' month = '02' ) ).
    cl_abap_unit_assert=>assert_equals( exp = '20261231' act = cut->last_day( year = '2026' month = '12' ) ).
    cl_abap_unit_assert=>assert_equals( exp = '20261130' act = cut->last_day( year = '2026' month = '11' ) ).
  ENDMETHOD.

  METHOD rate_valid_at_month_end.
    cl_abap_unit_assert=>assert_equals(
      exp = '0.7870' act = cut->find_rate( plant = 'BR01' on_date = '20261130' )-rate_per_degree ).
    cl_abap_unit_assert=>assert_equals(
      exp = '0.5903' act = cut->find_rate( plant = 'BR01' on_date = '20261231' )-rate_per_degree ).
    cl_abap_unit_assert=>assert_initial( cut->find_rate( plant = 'BR01' on_date = '20221231' ) ).
  ENDMETHOD.

  METHOD created_and_deleted_is_dropped.
    DATA(header) = VALUE zvhb_btdecl( decl_uuid = 'D0000000000000000000000000000002' plant = 'BR01' status = 'DRFT' ).

    lcl_buffer=>set_header( header = header change = lcl_buffer=>changes-created ).
    cl_abap_unit_assert=>assert_equals( exp = 'DRFT' act = lcl_buffer=>get_header( header-decl_uuid )-status ).

    " Nothing reaches the database for a declaration that was created and deleted in one transaction
    lcl_buffer=>set_header( header = header change = lcl_buffer=>changes-deleted ).
    cl_abap_unit_assert=>assert_initial( lcl_buffer=>headers ).
    cl_abap_unit_assert=>assert_initial( lcl_buffer=>get_header( header-decl_uuid ) ).
  ENDMETHOD.

ENDCLASS.

