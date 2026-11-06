"! Checks that purchase requisitions and purchase orders share. Each method returns the number
"! and first variable of a message in class ZVHB_MM, or an initial structure if the check passes.
CLASS zcl_vhb_purchasing_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_error,
        msgno TYPE symsgno,
        v1    TYPE symsgv,
      END OF ty_error.

    "! The material exists, is active and is not a finished product (beer is brewed, not bought)
    METHODS check_material
      IMPORTING
        material      TYPE zvhb_material
      RETURNING
        VALUE(result) TYPE ty_error.

    "! The business partner exists, has the supplier role and is not blocked. An empty supplier passes.
    METHODS check_supplier
      IMPORTING
        supplier      TYPE zvhb_partner
      RETURNING
        VALUE(result) TYPE ty_error.

    METHODS check_location
      IMPORTING
        plant            TYPE zvhb_plant
        storage_location TYPE zvhb_storage_loc
      RETURNING
        VALUE(result)    TYPE ty_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_finished_product TYPE zvhb_material_type VALUE 'FERT'.
ENDCLASS.



CLASS zcl_vhb_purchasing_check IMPLEMENTATION.

  METHOD check_material.
    SELECT SINGLE MaterialType, IsActive FROM zvhb_r_material
      WHERE Material = @material
      INTO @DATA(master).

    result = COND #( WHEN sy-subrc <> 0
                     THEN VALUE #( msgno = '001' v1 = material )
                     WHEN master-IsActive = abap_false
                     THEN VALUE #( msgno = '002' v1 = material )
                     WHEN master-MaterialType = c_finished_product
                     THEN VALUE #( msgno = '003' v1 = material ) ).
  ENDMETHOD.

  METHOD check_supplier.
    IF supplier IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE IsBlocked FROM zvhb_i_suppliervh
      WHERE Supplier = @supplier
      INTO @DATA(is_blocked).
    IF sy-subrc = 0.
      result = COND #( WHEN is_blocked = abap_true THEN VALUE #( msgno = '010' v1 = supplier ) ).
      RETURN.
    ENDIF.

    " Not a supplier: either the partner is missing or it has only the customer role
    SELECT SINGLE @abap_true FROM zvhb_r_businesspartner
      WHERE Partner = @supplier
      INTO @DATA(exists).
    result = VALUE #( msgno = COND #( WHEN exists = abap_true THEN '009' ELSE '008' ) v1 = supplier ).
  ENDMETHOD.

  METHOD check_location.
    IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant value = plant ).
      result = VALUE #( msgno = '006' v1 = plant ).
    ELSEIF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-storage_location
                                               value  = storage_location ).
      result = VALUE #( msgno = '007' v1 = storage_location ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
