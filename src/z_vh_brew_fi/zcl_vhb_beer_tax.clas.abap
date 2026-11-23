"! Beer tax by section 2 of the German Beer Tax Act (BierStG): hectoliters x tax class x rate per hectoliter
"! and degree Plato. The tax class is the original extract in whole degrees, fractions are disregarded.
"! Reduced rates of small independent breweries are a share of the standard rate; for them the rate is
"! determined to four decimal places and the tax per hectoliter to two (section 2 paragraph 2).
CLASS zcl_vhb_beer_tax DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES ty_rate TYPE p LENGTH 5 DECIMALS 4.
    TYPES ty_percent TYPE p LENGTH 4 DECIMALS 4.
    TYPES ty_hectoliters TYPE p LENGTH 7 DECIMALS 2.
    TYPES ty_tax_class TYPE n LENGTH 2.

    TYPES:
      "! Hectoliters of one material, tax class and treatment in the month
      BEGIN OF ty_base_line,
        material    TYPE zvhb_material,
        tax_class   TYPE ty_tax_class,
        treatment   TYPE zvhb_tax_treatment,
        quantity_hl TYPE ty_hectoliters,
      END OF ty_base_line,
      tt_base_lines TYPE STANDARD TABLE OF ty_base_line WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_line.
        INCLUDE TYPE ty_base_line.
    TYPES:
        tax_amount TYPE zvhb_amount,
      END OF ty_line,
      tt_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    TYPES:
      "! Lines and totals of a monthly declaration
      BEGIN OF ty_declaration,
        lines      TYPE tt_lines,
        taxable_hl TYPE ty_hectoliters,
        export_hl  TYPE ty_hectoliters,
        tax_amount TYPE zvhb_amount,
      END OF ty_declaration.

    CONSTANTS:
      BEGIN OF treatments,
        taxable TYPE zvhb_tax_treatment VALUE 'TAXD',
        export  TYPE zvhb_tax_treatment VALUE 'EXPT',
      END OF treatments.

    "! Standard rate in EUR per hectoliter and degree Plato
    CONSTANTS c_standard_rate TYPE ty_rate VALUE '0.7870'.
    CONSTANTS c_full_rate TYPE ty_percent VALUE 100.
    CONSTANTS c_lowest_rate TYPE ty_percent VALUE 50.

    "! Tax class: original extract in whole degrees Plato, fractions are disregarded (11.5 °P is class 11)
    CLASS-METHODS tax_class
      IMPORTING
        original_extract TYPE zvhb_plato
      RETURNING
        VALUE(result)    TYPE ty_tax_class.

    "! Rate in EUR per hectoliter and degree: the given share of the standard rate, four decimal places
    CLASS-METHODS rate_per_degree
      IMPORTING
        standard_rate TYPE ty_rate
        percent       TYPE ty_percent
      RETURNING
        VALUE(result) TYPE ty_rate.

    "! Tax in EUR per hectoliter of a tax class; rounded to two decimal places for a reduced rate
    CLASS-METHODS tax_per_hectoliter
      IMPORTING
        tax_class     TYPE ty_tax_class
        rate          TYPE ty_rate
        percent       TYPE ty_percent DEFAULT c_full_rate
      RETURNING
        VALUE(result) TYPE decfloat34.

    "! Tax in EUR for a quantity, rounded to the cent
    CLASS-METHODS tax_amount
      IMPORTING
        hectoliters   TYPE ty_hectoliters
        tax_class     TYPE ty_tax_class
        rate          TYPE ty_rate
        percent       TYPE ty_percent DEFAULT c_full_rate
      RETURNING
        VALUE(result) TYPE zvhb_amount.

    "! Declaration lines with the tax of each taxable line and the totals; export lines carry no tax
    CLASS-METHODS declare
      IMPORTING
        base          TYPE tt_base_lines
        rate          TYPE ty_rate
        percent       TYPE ty_percent DEFAULT c_full_rate
      RETURNING
        VALUE(result) TYPE ty_declaration.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_vhb_beer_tax IMPLEMENTATION.

  METHOD tax_class.
    result = CONV i( floor( original_extract ) ).
  ENDMETHOD.

  METHOD rate_per_degree.
    result = round( val = CONV decfloat34( standard_rate * percent / 100 ) dec = 4 ).
  ENDMETHOD.

  METHOD tax_per_hectoliter.
    result = CONV decfloat34( tax_class ) * rate.
    IF percent < c_full_rate.
      result = round( val = result dec = 2 ).
    ENDIF.
  ENDMETHOD.

  METHOD tax_amount.
    result = round( val = hectoliters * tax_per_hectoliter( tax_class = tax_class rate = rate percent = percent )
                    dec = 2 ).
  ENDMETHOD.

  METHOD declare.
    DATA(lines) = base.
    SORT lines BY treatment DESCENDING material tax_class.

    LOOP AT lines INTO DATA(line) WHERE quantity_hl <> 0.
      DATA(tax) = COND zvhb_amount( WHEN line-treatment = treatments-taxable
                                    THEN tax_amount( hectoliters = line-quantity_hl
                                                     tax_class   = line-tax_class
                                                     rate        = rate
                                                     percent     = percent ) ).
      APPEND VALUE #( BASE CORRESPONDING #( line ) tax_amount = tax ) TO result-lines.

      IF line-treatment = treatments-taxable.
        result-taxable_hl += line-quantity_hl.
      ELSE.
        result-export_hl += line-quantity_hl.
      ENDIF.
      result-tax_amount += tax.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
