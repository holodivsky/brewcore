"! Batches that expire soon: every batch with stock in the plant whose best-before date is within the next
"! days (14 by default) is reported as a warning, a batch that has already expired with stock as an error.
"! The result goes to the application log ZVHB_LOG, subobject BATCH_EXPIRY. Runs as application job
"! (catalog entry ZVHB_BATCH_EXPIRY) or with F9 in ADT.
CLASS zcl_vhb_batch_expiry_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
    INTERFACES if_oo_adt_classrun.

    TYPES:
      BEGIN OF ty_batch,
        material         TYPE zvhb_material,
        storage_location TYPE zvhb_storage_loc,
        batch            TYPE zvhb_batch,
        expiry_date      TYPE d,
        unit             TYPE zvhb_unit,
        quantity         TYPE zvhb_quantity,
      END OF ty_batch,
      tt_batches TYPE STANDARD TABLE OF ty_batch WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF parameter,
        plant TYPE c LENGTH 8 VALUE 'P_PLANT',
        days  TYPE c LENGTH 8 VALUE 'P_DAYS',
      END OF parameter.

    CONSTANTS c_default_days TYPE i VALUE 14.

    "! Batches with stock in the plant that expire on or before today plus the given days, expired ones included
    METHODS find_expiring
      IMPORTING
        plant         TYPE zvhb_plant
        days          TYPE i
      RETURNING
        VALUE(result) TYPE tt_batches.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_IM'.
    CONSTANTS c_default_plant TYPE zvhb_plant VALUE 'BR01'.

    DATA log TYPE REF TO zif_vhb_app_log.
    DATA texts TYPE string_table.

    METHODS run
      IMPORTING
        plant         TYPE zvhb_plant
        days          TYPE i
      RETURNING
        VALUE(result) TYPE string_table.

    "! Adds a message of class ZVHB_IM to the log and to the texts for the console
    METHODS note
      IMPORTING
        severity TYPE zif_vhb_app_log=>ty_severity DEFAULT zif_vhb_app_log=>severity-info
        number   TYPE symsgno
        v1       TYPE simple OPTIONAL
        v2       TYPE simple OPTIONAL
        v3       TYPE simple OPTIONAL
        v4       TYPE simple OPTIONAL.
ENDCLASS.



CLASS zcl_vhb_batch_expiry_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = parameter-plant kind = if_apj_dt_exec_object=>parameter datatype = 'C' length = 4
        param_text = 'Plant' changeable_ind = abap_true mandatory_ind = abap_true )
      ( selname = parameter-days kind = if_apj_dt_exec_object=>parameter datatype = 'N' length = 3
        param_text = 'Days ahead' changeable_ind = abap_true mandatory_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = parameter-plant kind = if_apj_dt_exec_object=>parameter sign = 'I' option = 'EQ'
        low = c_default_plant )
      ( selname = parameter-days kind = if_apj_dt_exec_object=>parameter sign = 'I' option = 'EQ'
        low = |{ c_default_days }| ) ).
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    DATA(plant) = c_default_plant.
    DATA(days) = c_default_days.

    LOOP AT it_parameters INTO DATA(value).
      CASE value-selname.
        WHEN parameter-plant.
          plant = value-low.
        WHEN parameter-days.
          days = value-low.
      ENDCASE.
    ENDLOOP.

    run( plant = plant days = days ).
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    out->write( run( plant = c_default_plant days = c_default_days ) ).
  ENDMETHOD.

  METHOD find_expiring.
    DATA(limit) = CONV d( cl_abap_context_info=>get_system_date( ) + days ).

    SELECT Material, StorageLocation, Batch, ExpiryDate, Unit, TotalQuantity FROM zvhb_i_stock
      WHERE Plant          = @plant
        AND Batch         <> ' '
        AND TotalQuantity  > 0
        AND ExpiryDate    <> '00000000'
        AND ExpiryDate    <= @limit
      ORDER BY ExpiryDate, Material, Batch
      INTO TABLE @DATA(batches).

    result = VALUE #( FOR b IN batches ( material         = b-Material
                                         storage_location = b-StorageLocation
                                         batch            = b-Batch
                                         expiry_date      = b-ExpiryDate
                                         unit             = b-Unit
                                         quantity         = b-TotalQuantity ) ).
  ENDMETHOD.

  METHOD run.
    CLEAR texts.
    log = zcl_vhb_app_log=>create( subobject   = zif_vhb_app_log=>subobject-batch_expiry
                                   external_id = plant ).

    DATA(today) = cl_abap_context_info=>get_system_date( ).
    DATA(batches) = find_expiring( plant = plant days = days ).

    LOOP AT batches INTO DATA(batch).
      " Expired stock may only be scrapped; stock that expires soon should be sold or used first
      note( severity = COND #( WHEN batch-expiry_date < today THEN zif_vhb_app_log=>severity-error
                               ELSE zif_vhb_app_log=>severity-warning )
            number   = COND #( WHEN batch-expiry_date < today THEN '020' ELSE '019' )
            v1       = batch-batch
            v2       = batch-material
            v3       = |{ batch-expiry_date DATE = ISO }|
            v4       = |{ batch-quantity NUMBER = USER } { batch-unit } in { batch-storage_location }| ).
    ENDLOOP.

    IF batches IS INITIAL.
      note( severity = zif_vhb_app_log=>severity-success number = '022' v1 = plant v2 = days ).
    ELSE.
      note( number = '021' v1 = plant v2 = lines( batches ) v3 = days ).
    ENDIF.

    log->save( ).
    result = texts.
  ENDMETHOD.

  METHOD note.
    log->add_message( severity = severity msgid = c_msgid msgno = number v1 = v1 v2 = v2 v3 = v3 v4 = v4 ).

    DATA text TYPE string.
    MESSAGE ID c_msgid TYPE 'I' NUMBER number WITH v1 v2 v3 v4 INTO text.
    APPEND text TO texts.
  ENDMETHOD.

ENDCLASS.
