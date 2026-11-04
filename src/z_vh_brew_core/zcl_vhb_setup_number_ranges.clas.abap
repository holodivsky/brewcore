"! Creates interval 01 for every BrewCore number range object. Run with F9 once per system.
"! Safe to run again: existing intervals stay untouched. Result goes to the console and to
"! the application log (object ZVHB_LOG, subobject SETUP).
CLASS zcl_vhb_setup_number_ranges DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    TYPES:
      BEGIN OF ty_interval,
        object      TYPE zif_vhb_number_range=>ty_object,
        from_number TYPE zif_vhb_number_range=>ty_number,
        to_number   TYPE zif_vhb_number_range=>ty_number,
      END OF ty_interval,
      tt_intervals TYPE STANDARD TABLE OF ty_interval WITH KEY object.

    "! Interval 01 of each object. As in S/4HANA, the leading digits tell the document type
    "! (45... purchase order, 49... material document, 80... delivery, 90... billing).
    METHODS get_intervals
      RETURNING
        VALUE(result) TYPE tt_intervals.

    "! Creates all missing intervals; one log message per object
    METHODS create_missing_intervals
      IMPORTING
        log TYPE REF TO zif_vhb_app_log.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_CORE'.

    METHODS interval_exists
      IMPORTING
        object        TYPE zif_vhb_number_range=>ty_object
      RETURNING
        VALUE(result) TYPE abap_bool
      RAISING
        cx_nr_object_not_found
        cx_nr_subobject
        cx_number_ranges.

    METHODS create_interval
      IMPORTING
        interval TYPE ty_interval
      RAISING
        cx_nr_object_not_found
        cx_number_ranges.

    METHODS process_interval
      IMPORTING
        interval TYPE ty_interval
        log      TYPE REF TO zif_vhb_app_log.
ENDCLASS.



CLASS zcl_vhb_setup_number_ranges IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA(log) = zcl_vhb_app_log=>create( subobject   = zif_vhb_app_log=>subobject-setup
                                         external_id = 'NUMBER RANGES' ).
    create_missing_intervals( log ).
    log->save( ).

    IF log->has_errors( ).
      MESSAGE ID c_msgid TYPE 'I' NUMBER '010'
              WITH zcl_vhb_app_log=>c_log_object zif_vhb_app_log=>subobject-setup
              INTO DATA(summary).
    ELSE.
      MESSAGE ID c_msgid TYPE 'I' NUMBER '009'
              WITH log->get_item_count( )
              INTO summary.
    ENDIF.
    out->write( summary ).
  ENDMETHOD.

  METHOD get_intervals.
    result = VALUE #(
      ( object = zif_vhb_number_range=>objects-business_partner     from_number = '1000000000' to_number = '1099999999' )
      ( object = zif_vhb_number_range=>objects-purchase_requisition from_number = '1100000000' to_number = '1199999999' )
      ( object = zif_vhb_number_range=>objects-batch                from_number = '2000000000' to_number = '2099999999' )
      ( object = zif_vhb_number_range=>objects-inspection_lot       from_number = '3000000000' to_number = '3099999999' )
      ( object = zif_vhb_number_range=>objects-purchase_order       from_number = '4500000000' to_number = '4599999999' )
      ( object = zif_vhb_number_range=>objects-material_document    from_number = '4900000000' to_number = '4999999999' )
      ( object = zif_vhb_number_range=>objects-supplier_invoice     from_number = '5100000000' to_number = '5199999999' )
      ( object = zif_vhb_number_range=>objects-brew_order           from_number = '6000000000' to_number = '6099999999' )
      ( object = zif_vhb_number_range=>objects-sales_order          from_number = '7000000000' to_number = '7099999999' )
      ( object = zif_vhb_number_range=>objects-delivery             from_number = '8000000000' to_number = '8099999999' )
      ( object = zif_vhb_number_range=>objects-billing_document     from_number = '9000000000' to_number = '9099999999' )
      ( object = zif_vhb_number_range=>objects-tax_declaration      from_number = '9900000000' to_number = '9999999999' ) ).
  ENDMETHOD.

  METHOD create_missing_intervals.
    LOOP AT get_intervals( ) INTO DATA(interval).
      process_interval( interval = interval
                        log      = log ).
    ENDLOOP.
  ENDMETHOD.

  METHOD process_interval.
    TRY.
        IF interval_exists( interval-object ).
          log->add_message( msgid = c_msgid
                            msgno = '007'
                            v1    = zcl_vhb_number_range=>c_interval
                            v2    = interval-object ).
        ELSE.
          create_interval( interval ).
          log->add_message( severity = zif_vhb_app_log=>severity-success
                            msgid    = c_msgid
                            msgno    = '006'
                            v1       = zcl_vhb_number_range=>c_interval
                            v2       = interval-object ).
        ENDIF.
      CATCH cx_nr_object_not_found cx_nr_subobject cx_number_ranges INTO DATA(error).
        log->add_message( severity = zif_vhb_app_log=>severity-error
                          msgid    = c_msgid
                          msgno    = '008'
                          v1       = zcl_vhb_number_range=>c_interval
                          v2       = interval-object
                          v3       = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD interval_exists.
    cl_numberrange_intervals=>read( EXPORTING object   = object
                                    IMPORTING interval = DATA(intervals) ).
    result = xsdbool( line_exists( intervals[ nrrangenr = zcl_vhb_number_range=>c_interval ] ) ).
  ENDMETHOD.

  METHOD create_interval.
    cl_numberrange_intervals=>create(
      interval = VALUE #( ( nrrangenr  = zcl_vhb_number_range=>c_interval
                            fromnumber = interval-from_number
                            tonumber   = interval-to_number
                            procind    = 'I' ) )
      object   = interval-object ).
  ENDMETHOD.

ENDCLASS.
