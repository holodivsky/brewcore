"! Number range access via the released API CL_NUMBERRANGE_RUNTIME.
"! Intervals are created by ZCL_VHB_SETUP_NUMBER_RANGES.
CLASS zcl_vhb_number_range DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_vhb_number_range.

    "! Every BrewCore number range object uses this single internal interval
    CONSTANTS c_interval TYPE cl_numberrange_runtime=>nr_interval VALUE '01'.

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! NUMBER_GET returns NUMC 20; BrewCore objects have number length 10 (domain CHAR10)
    CLASS-METHODS to_number
      IMPORTING
        level         TYPE cl_numberrange_runtime=>nr_number
      RETURNING
        VALUE(result) TYPE zif_vhb_number_range=>ty_number.
ENDCLASS.



CLASS zcl_vhb_number_range IMPLEMENTATION.

  METHOD zif_vhb_number_range~get_next.
    TRY.
        cl_numberrange_runtime=>number_get( EXPORTING nr_range_nr = c_interval
                                                      object      = object
                                            IMPORTING number      = DATA(number)
                                                      returncode  = DATA(returncode) ).
      CATCH cx_nr_object_not_found cx_number_ranges INTO DATA(error).
        RAISE EXCEPTION NEW zcx_vhb_number_range( previous = error
                                                  object   = object
                                                  interval = c_interval ).
    ENDTRY.

    " Return code 3: fewer numbers returned than requested, the interval is exhausted
    IF returncode = '3'.
      RAISE EXCEPTION NEW zcx_vhb_number_range( object   = object
                                                interval = c_interval ).
    ENDIF.

    result = to_number( number ).
  ENDMETHOD.

  METHOD to_number.
    result = substring( val = level
                        off = strlen( level ) - 10
                        len = 10 ).
  ENDMETHOD.

ENDCLASS.
