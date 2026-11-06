*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_requisition DEFINITION DEFERRED FOR TESTING.

CLASS lhc_requisition DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_requisition.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MM'.

    CONSTANTS:
      "! Requisition status values of domain ZVHB_PR_STATUS
      BEGIN OF requisition_status,
        created  TYPE zvhb_pr_status VALUE 'NEW',
        approved TYPE zvhb_pr_status VALUE 'APPR',
        ordered  TYPE zvhb_pr_status VALUE 'ORDR',
      END OF requisition_status.

    CONSTANTS:
      BEGIN OF defaults,
        plant            TYPE zvhb_plant VALUE 'BR01',
        storage_location TYPE zvhb_storage_loc VALUE 'RM01',
        lead_time_days   TYPE i VALUE 14,
      END OF defaults.

    TYPES tt_keys         TYPE TABLE FOR READ IMPORT zvhb_r_purchaserequisition\\requisition.
    TYPES tt_requisitions TYPE TABLE FOR READ RESULT zvhb_r_purchaserequisition\\requisition.
    TYPES ty_requisition  TYPE STRUCTURE FOR READ RESULT zvhb_r_purchaserequisition\\requisition.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Requisition RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Requisition RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION Requisition~approve RESULT result.

    METHODS markOrdered FOR MODIFY
      IMPORTING keys FOR ACTION Requisition~markOrdered RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Requisition~setDefaults.

    METHODS setUnit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Requisition~setUnit.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Requisition~setNumber.

    METHODS validateRequisition FOR VALIDATE ON SAVE
      IMPORTING keys FOR Requisition~validateRequisition.

    "! First failed check of one requisition, or an initial structure
    METHODS check_requisition
      IMPORTING
        requisition   TYPE ty_requisition
      RETURNING
        VALUE(result) TYPE zcl_vhb_purchasing_check=>ty_error.

    "! Sets the status and returns the changed requisitions
    METHODS set_status
      IMPORTING
        requisition_keys TYPE tt_keys
        status           TYPE zvhb_pr_status
      RETURNING
        VALUE(result)    TYPE tt_requisitions.

    METHODS get_number_range
      RETURNING
        VALUE(result) TYPE REF TO zif_vhb_number_range.
ENDCLASS.


CLASS lhc_requisition IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions)
      FAILED failed.

    " Only a requisition that is not yet approved can be changed; approval needs a saved requisition
    result = VALUE #(
      FOR requisition IN requisitions
      LET changeable = COND #( WHEN requisition-Status = requisition_status-created OR requisition-Status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky            = requisition-%tky
        %update         = changeable
        %delete         = changeable
        %action-Edit    = changeable
        %action-approve = COND #( WHEN requisition-%is_draft = if_abap_behv=>mk-off
                                   AND requisition-Status = requisition_status-created
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by plant and the purchaser role follow in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD approve.
    DATA(requisitions) = set_status( requisition_keys = CORRESPONDING #( keys )
                                     status           = requisition_status-approved ).
    result = VALUE #( FOR requisition IN requisitions ( %tky = requisition-%tky %param = requisition ) ).
  ENDMETHOD.

  METHOD markOrdered.
    DATA(requisitions) = set_status( requisition_keys = CORRESPONDING #( keys )
                                     status           = requisition_status-ordered ).
    result = VALUE #( FOR requisition IN requisitions ( %tky = requisition-%tky %param = requisition ) ).
  ENDMETHOD.

  METHOD set_status.
    MODIFY ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN requisition_keys ( %tky = key-%tky Status = status ) ).

    READ ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        ALL FIELDS WITH CORRESPONDING #( requisition_keys )
      RESULT result.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        FIELDS ( Plant StorageLocation DeliveryDate Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        UPDATE FIELDS ( Plant StorageLocation DeliveryDate Status )
        WITH VALUE #( FOR requisition IN requisitions
                      ( %tky            = requisition-%tky
                        Status          = requisition_status-created
                        Plant           = COND #( WHEN requisition-Plant IS INITIAL
                                                  THEN defaults-plant ELSE requisition-Plant )
                        StorageLocation = COND #( WHEN requisition-StorageLocation IS INITIAL
                                                  THEN defaults-storage_location ELSE requisition-StorageLocation )
                        DeliveryDate    = COND #( WHEN requisition-DeliveryDate IS INITIAL
                                                  THEN today + defaults-lead_time_days ELSE requisition-DeliveryDate ) ) ).
  ENDMETHOD.

  METHOD setUnit.
    READ ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    IF requisitions IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Material, BaseUnit FROM zvhb_r_material
      FOR ALL ENTRIES IN @requisitions
      WHERE Material = @requisitions-Material
      INTO TABLE @DATA(materials).

    MODIFY ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        UPDATE FIELDS ( Unit )
        WITH VALUE #( FOR requisition IN requisitions
                      ( %tky = requisition-%tky
                        Unit = VALUE #( materials[ Material = requisition-Material ]-BaseUnit OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        FIELDS ( PurchaseRequisition ) WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DELETE requisitions WHERE PurchaseRequisition IS NOT INITIAL.

    LOOP AT requisitions ASSIGNING FIELD-SYMBOL(<requisition>).
      TRY.
          <requisition>-PurchaseRequisition = get_number_range( )->get_next(
                                                zif_vhb_number_range=>objects-purchase_requisition ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <requisition>-%tky
                          %msg = new_message( id       = c_msgid
                                              number   = '014'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = exception->get_text( ) ) ) TO reported-requisition.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        UPDATE FIELDS ( PurchaseRequisition )
        WITH VALUE #( FOR requisition IN requisitions WHERE ( PurchaseRequisition IS NOT INITIAL )
                      ( %tky = requisition-%tky PurchaseRequisition = requisition-PurchaseRequisition ) ).
  ENDMETHOD.

  METHOD validateRequisition.
    READ ENTITIES OF zvhb_r_purchaserequisition IN LOCAL MODE
      ENTITY Requisition
        FIELDS ( Material Plant StorageLocation Quantity DeliveryDate Supplier ) WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    LOOP AT requisitions INTO DATA(requisition).
      APPEND VALUE #( %tky = requisition-%tky %state_area = 'REQUISITION' ) TO reported-requisition.

      DATA(error) = check_requisition( requisition ).
      IF error IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = requisition-%tky ) TO failed-requisition.
      APPEND VALUE #( %tky                     = requisition-%tky
                      %state_area              = 'REQUISITION'
                      %msg                     = new_message( id       = c_msgid
                                                              number   = error-msgno
                                                              severity = if_abap_behv_message=>severity-error
                                                              v1       = error-v1 )
                      %element-Material        = COND #( WHEN error-msgno BETWEEN '001' AND '003' THEN if_abap_behv=>mk-on )
                      %element-Quantity        = COND #( WHEN error-msgno = '004' THEN if_abap_behv=>mk-on )
                      %element-DeliveryDate    = COND #( WHEN error-msgno = '005' THEN if_abap_behv=>mk-on )
                      %element-Plant           = COND #( WHEN error-msgno = '006' THEN if_abap_behv=>mk-on )
                      %element-StorageLocation = COND #( WHEN error-msgno = '007' THEN if_abap_behv=>mk-on )
                      %element-Supplier        = COND #( WHEN error-msgno BETWEEN '008' AND '010' THEN if_abap_behv=>mk-on ) )
             TO reported-requisition.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_requisition.
    DATA(check) = NEW zcl_vhb_purchasing_check( ).

    result = check->check_material( requisition-Material ).
    IF result IS INITIAL AND requisition-Quantity <= 0.
      result-msgno = '004'.
    ENDIF.
    IF result IS INITIAL AND requisition-DeliveryDate < cl_abap_context_info=>get_system_date( ).
      result-msgno = '005'.
    ENDIF.
    IF result IS INITIAL.
      result = check->check_location( plant = requisition-Plant storage_location = requisition-StorageLocation ).
    ENDIF.
    IF result IS INITIAL.
      result = check->check_supplier( requisition-Supplier ).
    ENDIF.
  ENDMETHOD.

  METHOD get_number_range.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.
    result = number_range.
  ENDMETHOD.

ENDCLASS.

