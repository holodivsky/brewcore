"! FR-IM-05: automatic reorder. For every purchased material of a plant whose free, unexpired stock is
"! below the reorder point, a purchase requisition tops the stock up to twice the reorder point. Materials
"! with an open requisition or purchase order are only reported. The result goes to the application log
"! ZVHB_LOG, subobject REORDER. Runs as application job (catalog entry ZVHB_REORDER) or with F9 in ADT.
CLASS zcl_vhb_reorder_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
    INTERFACES if_oo_adt_classrun.

    TYPES:
      "! A material below its reorder point and the quantity to order
      BEGIN OF ty_proposal,
        material         TYPE zvhb_material,
        plant            TYPE zvhb_plant,
        storage_location TYPE zvhb_storage_loc,
        unit             TYPE zvhb_unit,
        free_quantity    TYPE zvhb_quantity,
        reorder_point    TYPE zvhb_quantity,
        quantity         TYPE zvhb_quantity,
        open_document    TYPE c LENGTH 10,
      END OF ty_proposal,
      tt_proposals TYPE STANDARD TABLE OF ty_proposal WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF parameter,
        plant    TYPE c LENGTH 8 VALUE 'P_PLANT',
        test_run TYPE c LENGTH 8 VALUE 'P_TEST',
      END OF parameter.

    "! Materials of the plant below their reorder point, with the open requisition or order if there is one
    METHODS plan
      IMPORTING
        plant         TYPE zvhb_plant
      RETURNING
        VALUE(result) TYPE tt_proposals.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MM'.
    CONSTANTS c_default_plant TYPE zvhb_plant VALUE 'BR01'.
    CONSTANTS c_lead_time_days TYPE i VALUE 7.

    CONSTANTS:
      BEGIN OF storage,
        raw_materials TYPE zvhb_storage_loc VALUE 'RM01',
        empties       TYPE zvhb_storage_loc VALUE 'LE01',
      END OF storage.

    DATA log TYPE REF TO zif_vhb_app_log.
    DATA texts TYPE string_table.

    "! Checks the plant and creates the requisitions unless it is a test run; returns the log texts
    METHODS run
      IMPORTING
        plant         TYPE zvhb_plant
        test_run      TYPE abap_boolean
      RETURNING
        VALUE(result) TYPE string_table.

    "! Returns the number of the new requisition, or nothing if it could not be created
    METHODS create_requisition
      IMPORTING
        proposal      TYPE ty_proposal
      RETURNING
        VALUE(result) TYPE zvhb_purch_req.

    "! Adds a message of class ZVHB_MM to the log and to the texts for the console
    METHODS note
      IMPORTING
        severity TYPE zif_vhb_app_log=>ty_severity DEFAULT zif_vhb_app_log=>severity-info
        number   TYPE symsgno
        v1       TYPE simple OPTIONAL
        v2       TYPE simple OPTIONAL
        v3       TYPE simple OPTIONAL
        v4       TYPE simple OPTIONAL.
ENDCLASS.



CLASS zcl_vhb_reorder_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = parameter-plant kind = if_apj_dt_exec_object=>parameter datatype = 'C' length = 4
        param_text = 'Plant' changeable_ind = abap_true mandatory_ind = abap_true )
      ( selname = parameter-test_run kind = if_apj_dt_exec_object=>parameter datatype = 'C' length = 1
        param_text = 'Test run, no requisitions' changeable_ind = abap_true checkbox_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = parameter-plant kind = if_apj_dt_exec_object=>parameter sign = 'I' option = 'EQ'
        low = c_default_plant ) ).
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    DATA(plant) = c_default_plant.
    DATA(test_run) = abap_false.

    LOOP AT it_parameters INTO DATA(value).
      CASE value-selname.
        WHEN parameter-plant.
          plant = value-low.
        WHEN parameter-test_run.
          test_run = xsdbool( value-low = abap_true ).
      ENDCASE.
    ENDLOOP.

    run( plant = plant test_run = test_run ).
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    out->write( run( plant = c_default_plant test_run = abap_false ) ).
  ENDMETHOD.

  METHOD plan.
    TYPES:
      BEGIN OF ty_open,
        material TYPE zvhb_material,
        document TYPE c LENGTH 10,
      END OF ty_open.
    DATA open_documents TYPE STANDARD TABLE OF ty_open WITH EMPTY KEY.

    " Finished products are brewed, not bought
    SELECT plant_data~material, plant_data~base_unit, plant_data~reorder_point, material~material_type
      FROM zvhb_matplnt AS plant_data
        INNER JOIN zvhb_mat AS material ON material~material = plant_data~material
      WHERE plant_data~plant          = @plant
        AND plant_data~reorder_point  > 0
        AND material~is_active        = @abap_true
        AND material~material_type   <> 'FERT'
      ORDER BY plant_data~material
      INTO TABLE @DATA(materials).
    IF materials IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Material, SUM( FreeQuantity ) AS FreeQuantity FROM zvhb_i_stock
      WHERE Plant     = @plant
        AND IsExpired = ' '
      GROUP BY Material
      INTO TABLE @DATA(stock).

    SELECT material, purchase_requisition AS document FROM zvhb_preq
      WHERE plant = @plant
        AND ( status = 'NEW' OR status = 'APPR' )
      INTO CORRESPONDING FIELDS OF TABLE @open_documents.

    SELECT item~material, header~purchase_order AS document
      FROM zvhb_poitm AS item
        INNER JOIN zvhb_pohdr AS header ON header~po_uuid = item~po_uuid
      WHERE item~plant         = @plant
        AND item~is_delivered  = @abap_false
        AND ( header~status = 'NEW' OR header~status = 'WAIT' OR header~status = 'ORDR' )
      APPENDING CORRESPONDING FIELDS OF TABLE @open_documents.

    LOOP AT materials INTO DATA(material).
      DATA(free) = VALUE #( stock[ Material = material-material ]-FreeQuantity OPTIONAL ).
      IF free >= material-reorder_point.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( material         = material-material
                      plant            = plant
                      storage_location = COND #( WHEN material-material_type = 'LEER'
                                                 THEN storage-empties
                                                 ELSE storage-raw_materials )
                      unit             = material-base_unit
                      free_quantity    = free
                      reorder_point    = material-reorder_point
                      quantity         = 2 * material-reorder_point - free
                      open_document    = VALUE #( open_documents[ material = material-material ]-document OPTIONAL ) )
             TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD run.
    DATA created TYPE i.

    CLEAR texts.
    log = zcl_vhb_app_log=>create( subobject   = zif_vhb_app_log=>subobject-reorder
                                   external_id = plant ).

    DATA(proposals) = plan( plant ).
    LOOP AT proposals INTO DATA(proposal).
      DATA(quantity) = |{ proposal-quantity NUMBER = USER } { proposal-unit }|.

      IF proposal-open_document IS NOT INITIAL.
        note( number = '042' v1 = proposal-material v2 = proposal-open_document ).
        CONTINUE.
      ENDIF.

      note( severity = zif_vhb_app_log=>severity-warning
            number   = '040'
            v1       = proposal-material
            v2       = plant
            v3       = |{ proposal-free_quantity NUMBER = USER } { proposal-unit }|
            v4       = |{ proposal-reorder_point NUMBER = USER } { proposal-unit }| ).

      IF test_run = abap_true.
        note( number = '043' v1 = quantity v2 = proposal-material ).
        CONTINUE.
      ENDIF.

      DATA(requisition) = create_requisition( proposal ).
      IF requisition IS INITIAL.
        note( severity = zif_vhb_app_log=>severity-error number = '045' v1 = proposal-material ).
      ELSE.
        created += 1.
        note( severity = zif_vhb_app_log=>severity-success
              number   = '041'
              v1       = requisition
              v2       = quantity
              v3       = proposal-material ).
      ENDIF.
    ENDLOOP.

    note( severity = zif_vhb_app_log=>severity-success
          number   = '044'
          v1       = plant
          v2       = lines( proposals )
          v3       = created ).
    log->save( ).
    result = texts.
  ENDMETHOD.

  METHOD create_requisition.
    " The requisition goes through the business object, so the same checks apply as in the app
    MODIFY ENTITIES OF zvhb_r_purchaserequisition
      ENTITY Requisition
        CREATE FIELDS ( Material Plant StorageLocation Quantity DeliveryDate )
        WITH VALUE #( ( %cid            = 'REORDER'
                        Material        = proposal-material
                        Plant           = proposal-plant
                        StorageLocation = proposal-storage_location
                        Quantity        = proposal-quantity
                        DeliveryDate    = cl_abap_context_info=>get_system_date( ) + c_lead_time_days ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zvhb_r_purchaserequisition
        FAILED DATA(commit_failed)
        REPORTED DATA(commit_reported).
    ENDIF.

    IF failed IS NOT INITIAL OR commit_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      LOOP AT reported-requisition INTO DATA(message) WHERE %msg IS BOUND.
        log->add_text( severity = zif_vhb_app_log=>severity-error text = message-%msg->if_message~get_text( ) ).
      ENDLOOP.
      LOOP AT commit_reported-requisition INTO DATA(late_message) WHERE %msg IS BOUND.
        log->add_text( severity = zif_vhb_app_log=>severity-error text = late_message-%msg->if_message~get_text( ) ).
      ENDLOOP.
      RETURN.
    ENDIF.

    DATA(requisition_uuid) = mapped-requisition[ 1 ]-RequisitionUUID.
    SELECT SINGLE purchase_requisition FROM zvhb_preq
      WHERE preq_uuid = @requisition_uuid
      INTO @result.
  ENDMETHOD.

  METHOD note.
    log->add_message( severity = severity msgid = c_msgid msgno = number v1 = v1 v2 = v2 v3 = v3 v4 = v4 ).

    DATA text TYPE string.
    MESSAGE ID c_msgid TYPE 'I' NUMBER number WITH v1 v2 v3 v4 INTO text.
    APPEND text TO texts.
  ENDMETHOD.

ENDCLASS.
