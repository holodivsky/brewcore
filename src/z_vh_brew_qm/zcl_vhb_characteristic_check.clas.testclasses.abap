*"* use this source file for your ABAP unit test classes

"! Valuation and plausibility of inspection results
CLASS ltc_characteristic_check DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_vhb_characteristic_check.

    METHODS setup.
    METHODS limits_are_included FOR TESTING RAISING cx_static_check.
    METHODS comma_is_decimal_separator FOR TESTING RAISING cx_static_check.
    METHODS empty_result_is_not_recorded FOR TESTING.
    METHODS text_is_out_of_tolerance FOR TESTING.
    METHODS finding_names_the_limits FOR TESTING.

    "! Original extract with limits 11.70 to 12.30 degrees Plato
    METHODS extract
      IMPORTING
        result_value  TYPE zvhb_char_result
      RETURNING
        VALUE(result) TYPE zcl_vhb_characteristic_check=>ty_characteristic.
ENDCLASS.


CLASS ltc_characteristic_check IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( ).
  ENDMETHOD.

  METHOD limits_are_included.
    cl_abap_unit_assert=>assert_equals( exp = zcl_vhb_characteristic_check=>valuation-accepted
                                        act = cut->valuate( extract( '11.7' ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_vhb_characteristic_check=>valuation-accepted
                                        act = cut->valuate( extract( '12.30' ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_vhb_characteristic_check=>valuation-rejected
                                        act = cut->valuate( extract( '12.31' ) ) ).
  ENDMETHOD.

  METHOD comma_is_decimal_separator.
    cl_abap_unit_assert=>assert_equals( exp = '11.95' act = cut->to_number( '11,95' ) ).
  ENDMETHOD.

  METHOD empty_result_is_not_recorded.
    cl_abap_unit_assert=>assert_equals( exp = zcl_vhb_characteristic_check=>valuation-not_recorded
                                        act = cut->valuate( extract( '' ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = '002' act = cut->check_acceptance( extract( '' ) )-number ).
  ENDMETHOD.

  METHOD text_is_out_of_tolerance.
    cl_abap_unit_assert=>assert_equals( exp = zcl_vhb_characteristic_check=>valuation-rejected
                                        act = cut->valuate( extract( 'high' ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = '004' act = cut->check_result( extract( 'high' ) )-number ).
  ENDMETHOD.

  METHOD finding_names_the_limits.
    DATA(finding) = cut->check_acceptance( extract( '12.6' ) ).

    cl_abap_unit_assert=>assert_equals( exp = '003' act = finding-number ).
    cl_abap_unit_assert=>assert_equals( exp = `12.6 Plato` act = finding-v2 ).
    cl_abap_unit_assert=>assert_char_cp( exp = '11*70' act = finding-v3 ).
  ENDMETHOD.

  METHOD extract.
    result = VALUE #( Characteristic = zcl_vhb_characteristic_check=>characteristics-extract
                      Description    = 'Original extract'
                      UnitText       = 'Plato'
                      LowerLimit     = '11.70'
                      UpperLimit     = '12.30'
                      ResultValue    = result_value ).
  ENDMETHOD.

ENDCLASS.

