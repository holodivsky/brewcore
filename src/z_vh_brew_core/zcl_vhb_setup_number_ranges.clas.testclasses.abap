*"* use this source file for your ABAP unit test classes

CLASS ltc_intervals DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA intervals TYPE zcl_vhb_setup_number_ranges=>tt_intervals.

    METHODS setup.
    METHODS every_object_has_interval FOR TESTING.
    METHODS no_object_twice FOR TESTING.
    METHODS from_below_to FOR TESTING.
    METHODS prefixes_are_unique FOR TESTING.
ENDCLASS.


CLASS ltc_intervals IMPLEMENTATION.

  METHOD setup.
    intervals = NEW zcl_vhb_setup_number_ranges( )->get_intervals( ).
  ENDMETHOD.

  METHOD every_object_has_interval.
    DATA(objects) = VALUE string_table(
      ( CONV #( zif_vhb_number_range=>objects-business_partner ) )
      ( CONV #( zif_vhb_number_range=>objects-batch ) )
      ( CONV #( zif_vhb_number_range=>objects-material_document ) )
      ( CONV #( zif_vhb_number_range=>objects-purchase_requisition ) )
      ( CONV #( zif_vhb_number_range=>objects-purchase_order ) )
      ( CONV #( zif_vhb_number_range=>objects-supplier_invoice ) )
      ( CONV #( zif_vhb_number_range=>objects-brew_order ) )
      ( CONV #( zif_vhb_number_range=>objects-inspection_lot ) )
      ( CONV #( zif_vhb_number_range=>objects-sales_order ) )
      ( CONV #( zif_vhb_number_range=>objects-delivery ) )
      ( CONV #( zif_vhb_number_range=>objects-billing_document ) )
      ( CONV #( zif_vhb_number_range=>objects-tax_declaration ) ) ).

    LOOP AT objects INTO DATA(object).
      cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( intervals[ object = object ] ) )
                                        msg = |No interval defined for { object }| ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lines( intervals ) exp = lines( objects ) ).
  ENDMETHOD.

  METHOD no_object_twice.
    DATA(unique) = intervals.
    SORT unique BY object.
    DELETE ADJACENT DUPLICATES FROM unique COMPARING object.

    cl_abap_unit_assert=>assert_equals( act = lines( unique ) exp = lines( intervals ) ).
  ENDMETHOD.

  METHOD from_below_to.
    LOOP AT intervals INTO DATA(interval).
      cl_abap_unit_assert=>assert_true( act = xsdbool( interval-from_number < interval-to_number )
                                        msg = |Interval of { interval-object } is empty| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD prefixes_are_unique.
    DATA(prefixes) = VALUE string_table( FOR interval IN intervals ( substring( val = interval-from_number len = 2 ) ) ).
    SORT prefixes.
    DELETE ADJACENT DUPLICATES FROM prefixes.

    cl_abap_unit_assert=>assert_equals( act = lines( prefixes ) exp = lines( intervals ) ).
  ENDMETHOD.

ENDCLASS.

