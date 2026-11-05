*"* use this source file for your ABAP unit test classes

CLASS ltc_fixed_values DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS fixed_value_is_valid FOR TESTING.
    METHODS unknown_value_is_invalid FOR TESTING.
    METHODS empty_value_is_invalid FOR TESTING.
    METHODS each_domain_has_values FOR TESTING.
ENDCLASS.


CLASS ltc_fixed_values IMPLEMENTATION.

  METHOD fixed_value_is_valid.
    cl_abap_unit_assert=>assert_true(
      zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant value = 'BR01' ) ).
  ENDMETHOD.

  METHOD unknown_value_is_invalid.
    cl_abap_unit_assert=>assert_false(
      zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant value = 'XX01' ) ).
  ENDMETHOD.

  METHOD empty_value_is_invalid.
    cl_abap_unit_assert=>assert_false(
      zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-material_type value = '' ) ).
  ENDMETHOD.

  METHOD each_domain_has_values.
    cl_abap_unit_assert=>assert_true(
      zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-material_type value = 'FERT' ) ).
    cl_abap_unit_assert=>assert_true(
      zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-storage_location value = 'FG01' ) ).
    cl_abap_unit_assert=>assert_true(
      zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-distribution_channel value = 'GA' ) ).
  ENDMETHOD.

ENDCLASS.

