"! Access to BrewCore number ranges (interval 01 of each object).
"! Behavior pools receive an instance, so unit tests can replace it with a test double.
INTERFACE zif_vhb_number_range
  PUBLIC .

  TYPES ty_number TYPE c LENGTH 10.
  TYPES ty_object TYPE cl_numberrange_runtime=>nr_object.

  CONSTANTS:
    BEGIN OF objects,
      business_partner     TYPE ty_object VALUE 'ZVHB_PARTN',
      batch                TYPE ty_object VALUE 'ZVHB_BATCH',
      material_document    TYPE ty_object VALUE 'ZVHB_MDOC',
      purchase_requisition TYPE ty_object VALUE 'ZVHB_PREQ',
      purchase_order       TYPE ty_object VALUE 'ZVHB_PORD',
      supplier_invoice     TYPE ty_object VALUE 'ZVHB_SINV',
      brew_order           TYPE ty_object VALUE 'ZVHB_BREW',
      inspection_lot       TYPE ty_object VALUE 'ZVHB_INSP',
      sales_order          TYPE ty_object VALUE 'ZVHB_SORD',
      delivery             TYPE ty_object VALUE 'ZVHB_DELIV',
      billing_document     TYPE ty_object VALUE 'ZVHB_BILL',
      tax_declaration      TYPE ty_object VALUE 'ZVHB_DECL',
    END OF objects.

  "! Draws the next number from interval 01
  "! @parameter object               | Number range object, see constants OBJECTS
  "! @parameter result               | The new number
  "! @raising   zcx_vhb_number_range | Object or interval missing, or interval exhausted
  METHODS get_next
    IMPORTING
      object        TYPE ty_object
    RETURNING
      VALUE(result) TYPE ty_number
    RAISING
      zcx_vhb_number_range.

ENDINTERFACE.
