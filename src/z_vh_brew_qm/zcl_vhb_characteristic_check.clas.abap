"! Rules for the results of an inspection characteristic: plausibility of the entered value and the
"! valuation against the limits. The inspection lot uses them on save and on the usage decision;
"! as virtual elements of ZVHB_C_InspectionChar they show the valuation while results are entered.
CLASS zcl_vhb_characteristic_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

    TYPES ty_valuation TYPE c LENGTH 1.

    CONSTANTS:
      BEGIN OF valuation,
        not_recorded TYPE ty_valuation VALUE ' ',
        accepted     TYPE ty_valuation VALUE 'A',
        rejected     TYPE ty_valuation VALUE 'R',
      END OF valuation.

    CONSTANTS:
      BEGIN OF characteristics,
        extract      TYPE zvhb_insp_char VALUE 'EXTR',
        alcohol      TYPE zvhb_insp_char VALUE 'ALC',
        ph           TYPE zvhb_insp_char VALUE 'PH',
        microbiology TYPE zvhb_insp_char VALUE 'MICR',
        sensory      TYPE zvhb_insp_char VALUE 'SENS',
      END OF characteristics.

    TYPES:
      BEGIN OF ty_characteristic,
        Characteristic       TYPE zvhb_insp_char,
        Description          TYPE zvhb_description,
        UnitText             TYPE zvhb_char_unit,
        LowerLimit           TYPE zvhb_char_value,
        UpperLimit           TYPE zvhb_char_value,
        ResultValue          TYPE zvhb_char_result,
        ValuationText        TYPE c LENGTH 20,
        ValuationCriticality TYPE int1,
      END OF ty_characteristic.

    "! A finding as message number and variables of message class ZVHB_QM; initial means no finding
    TYPES:
      BEGIN OF ty_finding,
        number TYPE symsgno,
        v1     TYPE string,
        v2     TYPE string,
        v3     TYPE string,
        v4     TYPE string,
      END OF ty_finding.

    "! Converts a result as entered, with decimal point or comma, into a number
    "! @raising cx_sy_conversion_error | The result is not a number
    METHODS to_number
      IMPORTING
        result        TYPE zvhb_char_result
      RETURNING
        VALUE(number) TYPE zvhb_char_value
      RAISING
        cx_sy_conversion_error.

    "! Accepted when the result lies within the limits, both limits included
    METHODS valuate
      IMPORTING
        characteristic TYPE ty_characteristic
      RETURNING
        VALUE(result)  TYPE ty_valuation.

    "! Plausibility of an entered result: a number, 0 or 1 for microbiology, 1 to 5 for the sensory score
    METHODS check_result
      IMPORTING
        characteristic TYPE ty_characteristic
      RETURNING
        VALUE(result)  TYPE ty_finding.

    "! A lot can only be accepted when the characteristic is recorded and in tolerance
    METHODS check_acceptance
      IMPORTING
        characteristic TYPE ty_characteristic
      RETURNING
        VALUE(result)  TYPE ty_finding.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_QM'.

    CONSTANTS:
      BEGIN OF criticality,
        neutral  TYPE int1 VALUE 0,
        negative TYPE int1 VALUE 1,
        positive TYPE int1 VALUE 3,
      END OF criticality.
ENDCLASS.



CLASS zcl_vhb_characteristic_check IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    et_requested_orig_elements = VALUE #( ( `CHARACTERISTIC` ) ( `DESCRIPTION` ) ( `UNITTEXT` )
                                          ( `LOWERLIMIT` ) ( `UPPERLIMIT` ) ( `RESULTVALUE` ) ).
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA characteristic_rows TYPE STANDARD TABLE OF ty_characteristic WITH EMPTY KEY.

    characteristic_rows = CORRESPONDING #( it_original_data ).
    LOOP AT characteristic_rows ASSIGNING FIELD-SYMBOL(<row>).
      CASE valuate( <row> ).
        WHEN valuation-accepted.
          MESSAGE ID c_msgid TYPE 'I' NUMBER '010' INTO <row>-ValuationText.
          <row>-ValuationCriticality = criticality-positive.
        WHEN valuation-rejected.
          MESSAGE ID c_msgid TYPE 'I' NUMBER '011' INTO <row>-ValuationText.
          <row>-ValuationCriticality = criticality-negative.
        WHEN OTHERS.
          MESSAGE ID c_msgid TYPE 'I' NUMBER '012' INTO <row>-ValuationText.
          <row>-ValuationCriticality = criticality-neutral.
      ENDCASE.
    ENDLOOP.
    ct_calculated_data = CORRESPONDING #( characteristic_rows ).
  ENDMETHOD.

  METHOD to_number.
    DATA(text) = condense( translate( val = CONV string( result ) from = `,` to = `.` ) ).
    number = CONV zvhb_char_value( text ).
  ENDMETHOD.

  METHOD valuate.
    IF characteristic-ResultValue IS INITIAL.
      result = valuation-not_recorded.
      RETURN.
    ENDIF.

    TRY.
        DATA(number) = to_number( characteristic-ResultValue ).
      CATCH cx_sy_conversion_error.
        result = valuation-rejected.
        RETURN.
    ENDTRY.

    result = COND #( WHEN number BETWEEN characteristic-LowerLimit AND characteristic-UpperLimit
                     THEN valuation-accepted
                     ELSE valuation-rejected ).
  ENDMETHOD.

  METHOD check_result.
    IF characteristic-ResultValue IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(number) = to_number( characteristic-ResultValue ).
      CATCH cx_sy_conversion_error.
        result = VALUE #( number = '004' v1 = characteristic-Description v2 = characteristic-ResultValue ).
        RETURN.
    ENDTRY.

    CASE characteristic-Characteristic.
      WHEN characteristics-microbiology.
        IF number <> 0 AND number <> 1.
          result = VALUE #( number = '005' v1 = characteristic-Description ).
        ENDIF.
      WHEN characteristics-sensory.
        IF frac( number ) <> 0 OR number < 1 OR number > 5.
          result = VALUE #( number = '006' v1 = characteristic-Description ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD check_acceptance.
    CASE valuate( characteristic ).
      WHEN valuation-not_recorded.
        result = VALUE #( number = '002' v1 = characteristic-Description ).
      WHEN valuation-rejected.
        result = VALUE #( number = '003'
                          v1     = characteristic-Description
                          v2     = condense( |{ characteristic-ResultValue } { characteristic-UnitText }| )
                          v3     = |{ characteristic-LowerLimit NUMBER = USER }|
                          v4     = |{ characteristic-UpperLimit NUMBER = USER }| ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
