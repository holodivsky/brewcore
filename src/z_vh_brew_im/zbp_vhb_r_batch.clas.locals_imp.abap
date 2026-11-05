*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_batch DEFINITION DEFERRED FOR TESTING.

CLASS lhc_batch DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_batch.
  PRIVATE SECTION.
    CONSTANTS:
      "! Batch status values of domain ZVHB_BATCH_STATUS
      BEGIN OF batch_status,
        free    TYPE zvhb_batch_status VALUE 'FREE',
        blocked TYPE zvhb_batch_status VALUE 'BLKD',
      END OF batch_status.

    TYPES tt_batch_keys TYPE TABLE FOR READ IMPORT zvhb_r_batch\\batch.
    TYPES tt_batches    TYPE TABLE FOR READ RESULT zvhb_r_batch\\batch.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Batch RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Batch RESULT result.

    METHODS block FOR MODIFY
      IMPORTING keys FOR ACTION Batch~block RESULT result.

    METHODS release FOR MODIFY
      IMPORTING keys FOR ACTION Batch~release RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Batch~setDefaults.

    "! Sets the batch status and returns the changed batches
    METHODS set_status
      IMPORTING
        batch_keys    TYPE tt_batch_keys
        status        TYPE zvhb_batch_status
      RETURNING
        VALUE(result) TYPE tt_batches.
ENDCLASS.


CLASS lhc_batch IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_batch IN LOCAL MODE
      ENTITY Batch
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(batches)
      FAILED failed.

    result = VALUE #( FOR batch IN batches
                      ( %tky            = batch-%tky
                        %action-block   = COND #( WHEN batch-Status = batch_status-free
                                                  THEN if_abap_behv=>fc-o-enabled
                                                  ELSE if_abap_behv=>fc-o-disabled )
                        %action-release = COND #( WHEN batch-Status = batch_status-blocked
                                                  THEN if_abap_behv=>fc-o-enabled
                                                  ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by plant follows in stage v1.0 together with authorization object ZVHB_PLANT
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD block.
    DATA(batches) = set_status( batch_keys = CORRESPONDING #( keys )
                                status     = batch_status-blocked ).
    result = VALUE #( FOR batch IN batches ( %tky = batch-%tky %param = batch ) ).
  ENDMETHOD.

  METHOD release.
    DATA(batches) = set_status( batch_keys = CORRESPONDING #( keys )
                                status     = batch_status-free ).
    result = VALUE #( FOR batch IN batches ( %tky = batch-%tky %param = batch ) ).
  ENDMETHOD.

  METHOD set_status.
    MODIFY ENTITIES OF zvhb_r_batch IN LOCAL MODE
      ENTITY Batch
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN batch_keys ( %tky = key-%tky Status = status ) ).

    READ ENTITIES OF zvhb_r_batch IN LOCAL MODE
      ENTITY Batch
        ALL FIELDS WITH CORRESPONDING #( batch_keys )
      RESULT result.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_batch IN LOCAL MODE
      ENTITY Batch
        FIELDS ( ProductionDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    IF batches IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Material, ShelfLifeDays FROM zvhb_r_material
      FOR ALL ENTRIES IN @batches
      WHERE Material = @batches-Material
      INTO TABLE @DATA(materials).

    " Best-before date (MHD) = production date + shelf life of the material
    MODIFY ENTITIES OF zvhb_r_batch IN LOCAL MODE
      ENTITY Batch
        UPDATE FIELDS ( Status ExpiryDate )
        WITH VALUE #( FOR batch IN batches
                      LET shelf_life = VALUE #( materials[ Material = batch-Material ]-ShelfLifeDays OPTIONAL ) IN
                      ( %tky       = batch-%tky
                        Status     = batch_status-free
                        ExpiryDate = COND #( WHEN shelf_life > 0 THEN batch-ProductionDate + shelf_life ) ) ).
  ENDMETHOD.

ENDCLASS.

