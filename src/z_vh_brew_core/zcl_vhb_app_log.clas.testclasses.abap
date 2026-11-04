*"* use this source file for your ABAP unit test classes

CLASS ltc_app_log DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zif_vhb_app_log.

    METHODS setup.
    METHODS new_log_is_empty FOR TESTING.
    METHODS info_message_is_no_error FOR TESTING.
    METHODS error_message_sets_error FOR TESTING.
    METHODS exception_counts_as_error FOR TESTING.
    METHODS warning_text_is_no_error FOR TESTING.
    METHODS calls_can_be_chained FOR TESTING.
    METHODS unknown_subobject_raises FOR TESTING.
ENDCLASS.


CLASS ltc_app_log IMPLEMENTATION.

  METHOD setup.
    cut = zcl_vhb_app_log=>create( subobject   = zif_vhb_app_log=>subobject-setup
                                   external_id = 'UNIT TEST' ).
  ENDMETHOD.

  METHOD new_log_is_empty.
    cl_abap_unit_assert=>assert_equals( act = cut->get_item_count( ) exp = 0 ).
    cl_abap_unit_assert=>assert_false( cut->has_errors( ) ).
  ENDMETHOD.

  METHOD info_message_is_no_error.
    cut->add_message( msgid = 'ZVHB_CORE' msgno = '002' v1 = 'MATERIAL' ).

    cl_abap_unit_assert=>assert_equals( act = cut->get_item_count( ) exp = 1 ).
    cl_abap_unit_assert=>assert_false( cut->has_errors( ) ).
  ENDMETHOD.

  METHOD error_message_sets_error.
    cut->add_message( severity = zif_vhb_app_log=>severity-error
                      msgid    = 'ZVHB_CORE'
                      msgno    = '003'
                      v1       = 'XX01'
                      v2       = 'PLANT' ).

    cl_abap_unit_assert=>assert_true( cut->has_errors( ) ).
  ENDMETHOD.

  METHOD exception_counts_as_error.
    cut->add_exception( NEW zcx_vhb_number_range( object = 'ZVHB_PORD' interval = '01' ) ).

    cl_abap_unit_assert=>assert_equals( act = cut->get_item_count( ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( cut->has_errors( ) ).
  ENDMETHOD.

  METHOD warning_text_is_no_error.
    cut->add_text( severity = zif_vhb_app_log=>severity-warning
                   text     = `Stock below reorder point` ).

    cl_abap_unit_assert=>assert_equals( act = cut->get_item_count( ) exp = 1 ).
    cl_abap_unit_assert=>assert_false( cut->has_errors( ) ).
  ENDMETHOD.

  METHOD calls_can_be_chained.
    cut->add_text( text = `first` )->add_text( text = `second` )->add_message( msgid = 'ZVHB_CORE'
                                                                                 msgno = '002'
                                                                                 v1    = 42 ).

    cl_abap_unit_assert=>assert_equals( act = cut->get_item_count( ) exp = 3 ).
  ENDMETHOD.

  METHOD unknown_subobject_raises.
    TRY.
        zcl_vhb_app_log=>create( subobject = 'NOT_MAINTAINED' ).
        cl_abap_unit_assert=>fail( 'Exception expected for a subobject that is not maintained' ).
      CATCH zcx_vhb_app_log.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

