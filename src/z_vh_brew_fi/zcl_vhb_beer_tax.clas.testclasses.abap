*"* use this source file for your ABAP unit test classes

"! FR-FI-01: beer tax by section 2 BierStG
CLASS ltc_beer_tax DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS fraction_of_degree_is_dropped FOR TESTING.
    METHODS example_of_the_specification FOR TESTING.
    METHODS standard_rate_is_not_rounded FOR TESTING.
    METHODS small_brewery_pays_half FOR TESTING.
    METHODS reduced_tax_per_hl_is_rounded FOR TESTING.
    METHODS export_is_tax_free FOR TESTING.
    METHODS totals_of_the_month FOR TESTING.
ENDCLASS.


CLASS ltc_beer_tax IMPLEMENTATION.

  METHOD fraction_of_degree_is_dropped.
    cl_abap_unit_assert=>assert_equals( exp = '11' act = zcl_vhb_beer_tax=>tax_class( '11.5' ) ).
    cl_abap_unit_assert=>assert_equals( exp = '11' act = zcl_vhb_beer_tax=>tax_class( '11.9' ) ).
    cl_abap_unit_assert=>assert_equals( exp = '16' act = zcl_vhb_beer_tax=>tax_class( '16.0' ) ).
  ENDMETHOD.

  METHOD example_of_the_specification.
    " 1,000 hl Pils with 11 °P at the standard rate: 1,000 x 11 x 0.787
    cl_abap_unit_assert=>assert_equals(
      exp = '8657.00'
      act = zcl_vhb_beer_tax=>tax_amount( hectoliters = 1000 tax_class = '11' rate = zcl_vhb_beer_tax=>c_standard_rate ) ).
  ENDMETHOD.

  METHOD standard_rate_is_not_rounded.
    " 11 x 0.787 = 8.657 per hl stays exact: 72 hl give 623.30, not 72 x 8.66 = 623.52
    cl_abap_unit_assert=>assert_equals(
      exp = '623.30'
      act = zcl_vhb_beer_tax=>tax_amount( hectoliters = 72 tax_class = '11' rate = zcl_vhb_beer_tax=>c_standard_rate ) ).
  ENDMETHOD.

  METHOD small_brewery_pays_half.
    " Up to 5,000 hl a year: 50 % of 0.787 = 0.3935
    cl_abap_unit_assert=>assert_equals(
      exp = '0.3935'
      act = zcl_vhb_beer_tax=>rate_per_degree( standard_rate = zcl_vhb_beer_tax=>c_standard_rate percent = 50 ) ).
    " 40,000 hl: 75 % = 0.59025, four decimal places
    cl_abap_unit_assert=>assert_equals(
      exp = '0.5903'
      act = zcl_vhb_beer_tax=>rate_per_degree( standard_rate = zcl_vhb_beer_tax=>c_standard_rate percent = 75 ) ).
  ENDMETHOD.

  METHOD reduced_tax_per_hl_is_rounded.
    " 11 x 0.5903 = 6.4933 per hl, rounded to 6.49; 100 hl give 649.00
    cl_abap_unit_assert=>assert_equals(
      exp = '6.49'
      act = zcl_vhb_beer_tax=>tax_per_hectoliter( tax_class = '11' rate = '0.5903' percent = 75 ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = '649.00'
      act = zcl_vhb_beer_tax=>tax_amount( hectoliters = 100 tax_class = '11' rate = '0.5903' percent = 75 ) ).
  ENDMETHOD.

  METHOD export_is_tax_free.
    " FR-FI-02: beer for a customer in Austria leaves Germany and is taxed there
    DATA(declaration) = zcl_vhb_beer_tax=>declare(
      base = VALUE #( ( material = 'PILS-BTL05' tax_class = '11' quantity_hl = 6
                        treatment = zcl_vhb_beer_tax=>treatments-export ) )
      rate = zcl_vhb_beer_tax=>c_standard_rate ).

    cl_abap_unit_assert=>assert_equals( exp = 0 act = declaration-tax_amount ).
    cl_abap_unit_assert=>assert_equals( exp = 6 act = declaration-export_hl ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = declaration-taxable_hl ).
  ENDMETHOD.

  METHOD totals_of_the_month.
    DATA(declaration) = zcl_vhb_beer_tax=>declare(
      base = VALUE #( ( material = 'PILS-BTL05' tax_class = '11' quantity_hl = 6
                        treatment = zcl_vhb_beer_tax=>treatments-export )
                      ( material = 'PILS-BTL05' tax_class = '11' quantity_hl = 72
                        treatment = zcl_vhb_beer_tax=>treatments-taxable )
                      ( material = 'BOCK-BTL05' tax_class = '16' quantity_hl = 10
                        treatment = zcl_vhb_beer_tax=>treatments-taxable ) )
      rate = zcl_vhb_beer_tax=>c_standard_rate ).

    " 72 x 11 x 0.787 = 623.30 and 10 x 16 x 0.787 = 125.92
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( declaration-lines ) ).
    cl_abap_unit_assert=>assert_equals( exp = 82 act = declaration-taxable_hl ).
    cl_abap_unit_assert=>assert_equals( exp = '749.22' act = declaration-tax_amount ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_vhb_beer_tax=>treatments-taxable
                                        act = declaration-lines[ 1 ]-treatment ).
  ENDMETHOD.

ENDCLASS.

