*"* use this source file for your ABAP unit test classes

CLASS ltc_number_range DEFINITION DEFERRED.
CLASS zcl_vhb_number_range DEFINITION LOCAL FRIENDS ltc_number_range.

CLASS ltc_number_range DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS numc20_is_cut_to_ten_digits FOR TESTING.
    METHODS unknown_object_raises FOR TESTING.
ENDCLASS.


CLASS ltc_number_range IMPLEMENTATION.

  METHOD numc20_is_cut_to_ten_digits.
    DATA level TYPE cl_numberrange_runtime=>nr_number VALUE '00000000004500000001'.

    cl_abap_unit_assert=>assert_equals( act = zcl_vhb_number_range=>to_number( level )
                                        exp = '4500000001' ).
  ENDMETHOD.

  METHOD unknown_object_raises.
    DATA(cut) = CAST zif_vhb_number_range( NEW zcl_vhb_number_range( ) ).

    TRY.
        cut->get_next( 'ZVHB_NONE' ).
        cl_abap_unit_assert=>fail( 'Exception expected for an unknown number range object' ).
      CATCH zcx_vhb_number_range INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->object exp = 'ZVHB_NONE' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

