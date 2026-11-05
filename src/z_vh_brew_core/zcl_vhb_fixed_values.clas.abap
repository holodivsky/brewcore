"! Checks values against the fixed values of a BrewCore domain.
"! Independent of the logon language, unlike the value help views.
CLASS zcl_vhb_fixed_values DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.
    TYPES ty_domain TYPE c LENGTH 30.

    CONSTANTS:
      BEGIN OF domains,
        plant                TYPE ty_domain VALUE 'ZVHB_PLANT',
        storage_location     TYPE ty_domain VALUE 'ZVHB_STORAGE_LOC',
        distribution_channel TYPE ty_domain VALUE 'ZVHB_DISTR_CHANNEL',
        material_type        TYPE ty_domain VALUE 'ZVHB_MATERIAL_TYPE',
        partner_role         TYPE ty_domain VALUE 'ZVHB_BP_ROLE',
        payment_terms        TYPE ty_domain VALUE 'ZVHB_PAY_TERMS',
        condition_type       TYPE ty_domain VALUE 'ZVHB_COND_TYPE',
      END OF domains.

    "! True if the value is one of the fixed values of the domain
    "! @parameter domain | Domain name, see constants DOMAINS
    "! @parameter value  | Value to check
    "! @parameter result | Value is a fixed value of the domain
    CLASS-METHODS is_valid
      IMPORTING
        domain        TYPE ty_domain
        value         TYPE csequence
      RETURNING
        VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cache_entry,
        domain TYPE ty_domain,
        values TYPE string_table,
      END OF ty_cache_entry,
      tt_cache TYPE HASHED TABLE OF ty_cache_entry WITH UNIQUE KEY domain.

    CLASS-DATA cache TYPE tt_cache.

    CLASS-METHODS get_values
      IMPORTING
        domain        TYPE ty_domain
      RETURNING
        VALUE(result) TYPE string_table.
ENDCLASS.



CLASS zcl_vhb_fixed_values IMPLEMENTATION.

  METHOD is_valid.
    DATA(values) = get_values( domain ).
    result = xsdbool( value IS NOT INITIAL AND line_exists( values[ table_line = CONV string( value ) ] ) ).
  ENDMETHOD.

  METHOD get_values.
    IF line_exists( cache[ domain = domain ] ).
      result = cache[ domain = domain ]-values.
      RETURN.
    ENDIF.

    SELECT DISTINCT value_low
      FROM ddcds_customer_domain_value_t( p_domain_name = @domain ) WITH PRIVILEGED ACCESS
      INTO TABLE @DATA(rows).

    result = VALUE #( FOR row IN rows ( CONV string( row-value_low ) ) ).
    INSERT VALUE #( domain = domain values = result ) INTO TABLE cache.
  ENDMETHOD.

ENDCLASS.
