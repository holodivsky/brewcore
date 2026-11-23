*"* use this source file for your ABAP unit test classes

"! Which log messages the Job Logs app shows and how. Table ZVHB_LOGMSG is replaced by an SQL test double.
CLASS ltc_job_log_query DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_messages TYPE STANDARD TABLE OF zvhb_logmsg WITH EMPTY KEY.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.
    DATA cut TYPE REF TO zcl_vhb_job_log_query.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS reorder_job_is_named FOR TESTING.
    METHODS warning_is_orange FOR TESTING.
    METHODS error_is_red FOR TESTING.
    METHODS success_is_green FOR TESTING.
    METHODS old_messages_are_hidden FOR TESTING.
    METHODS filter_by_subobject FOR TESTING.
ENDCLASS.


CLASS ltc_job_log_query IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_LOGMSG' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_environment->clear_doubles( ).
    cut = NEW #( ).
  ENDMETHOD.

  METHOD old_messages_are_hidden.
    DATA(now) = utclong_current( ).
    sql_environment->insert_test_data( VALUE tt_messages(
      ( log_handle = 'A' item_number = 1 logged_at = now subobject = 'REORDER' severity = 'W'
        message_text = 'YEAST-W34 is below the reorder point' )
      ( log_handle = 'B' item_number = 1 logged_at = utclong_add( val = now days = -40 ) subobject = 'REORDER'
        severity = 'I' message_text = 'Old run' ) ) ).

    DATA(rows) = cut->read_log( ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( rows ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'Automatic reorder' act = rows[ 1 ]-JobName ).
    cl_abap_unit_assert=>assert_equals( exp = 'Warning' act = rows[ 1 ]-SeverityText ).
  ENDMETHOD.

  METHOD filter_by_subobject.
    DATA(now) = utclong_current( ).
    sql_environment->insert_test_data( VALUE tt_messages(
      ( log_handle = 'A' item_number = 1 logged_at = now subobject = 'REORDER' severity = 'S' )
      ( log_handle = 'C' item_number = 1 logged_at = now subobject = 'BATCH_EXPIRY' severity = 'E' ) ) ).

    DATA(rows) = cut->read_log( 'BATCH_EXPIRY' ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( rows ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = rows[ 1 ]-Criticality ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( cut->read_log( ) ) ).
  ENDMETHOD.

  METHOD reorder_job_is_named.
    DATA(row) = VALUE zvhb_c_joblog( Subobject = 'REORDER' SeverityText = 'I' ).

    cut->describe( CHANGING row = row ).

    cl_abap_unit_assert=>assert_equals( exp = 'Automatic reorder' act = row-JobName ).
    cl_abap_unit_assert=>assert_equals( exp = 'Information' act = row-SeverityText ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = row-Criticality ).
  ENDMETHOD.

  METHOD warning_is_orange.
    DATA(row) = VALUE zvhb_c_joblog( Subobject = 'BATCH_EXPIRY' SeverityText = 'W' ).

    cut->describe( CHANGING row = row ).

    cl_abap_unit_assert=>assert_equals( exp = 'Expiring batches' act = row-JobName ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = row-Criticality ).
  ENDMETHOD.

  METHOD error_is_red.
    DATA(row) = VALUE zvhb_c_joblog( Subobject = 'REORDER' SeverityText = 'E' ).

    cut->describe( CHANGING row = row ).

    cl_abap_unit_assert=>assert_equals( exp = 'Error' act = row-SeverityText ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = row-Criticality ).
  ENDMETHOD.

  METHOD success_is_green.
    DATA(row) = VALUE zvhb_c_joblog( Subobject = 'REORDER' SeverityText = 'S' ).

    cut->describe( CHANGING row = row ).

    cl_abap_unit_assert=>assert_equals( exp = 'Success' act = row-SeverityText ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = row-Criticality ).
  ENDMETHOD.

ENDCLASS.

