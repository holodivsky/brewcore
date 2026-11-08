*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_tank DEFINITION DEFERRED FOR TESTING.

CLASS lhc_tank DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_tank.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    CONSTANTS:
      "! Tank status values of domain ZVHB_TANK_STATUS
      BEGIN OF tank_status,
        free     TYPE zvhb_tank_status VALUE 'FREE',
        occupied TYPE zvhb_tank_status VALUE 'BUSY',
        cleaning TYPE zvhb_tank_status VALUE 'CIP',
      END OF tank_status.

    CONSTANTS c_hectoliter TYPE zvhb_unit VALUE 'HL'.

    TYPES tt_tank_keys TYPE TABLE FOR READ IMPORT zvhb_r_fermentationtank\\tank.
    TYPES tt_tanks     TYPE TABLE FOR READ RESULT zvhb_r_fermentationtank\\tank.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Tank RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Tank RESULT result.

    METHODS startCleaning FOR MODIFY
      IMPORTING keys FOR ACTION Tank~startCleaning RESULT result.

    METHODS finishCleaning FOR MODIFY
      IMPORTING keys FOR ACTION Tank~finishCleaning RESULT result.

    METHODS occupy FOR MODIFY
      IMPORTING keys FOR ACTION Tank~occupy RESULT result.

    METHODS empty FOR MODIFY
      IMPORTING keys FOR ACTION Tank~empty RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Tank~setDefaults.

    METHODS validateTankNumber FOR VALIDATE ON SAVE
      IMPORTING keys FOR Tank~validateTankNumber.

    METHODS validatePlant FOR VALIDATE ON SAVE
      IMPORTING keys FOR Tank~validatePlant.

    METHODS validateCapacity FOR VALIDATE ON SAVE
      IMPORTING keys FOR Tank~validateCapacity.

    "! Sets the tank status and returns the changed tanks
    METHODS set_status
      IMPORTING
        tank_keys     TYPE tt_tank_keys
        status        TYPE zvhb_tank_status
      RETURNING
        VALUE(result) TYPE tt_tanks.
ENDCLASS.


CLASS lhc_tank IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(tanks)
      FAILED failed.

    " Cleaning is started and finished on saved tanks only; an occupied tank cannot be deleted
    result = VALUE #(
      FOR tank IN tanks
      LET saved = xsdbool( tank-%is_draft = if_abap_behv=>mk-off ) IN
      ( %tky                  = tank-%tky
        %delete               = COND #( WHEN tank-Status = tank_status-occupied
                                        THEN if_abap_behv=>fc-o-disabled
                                        ELSE if_abap_behv=>fc-o-enabled )
        %action-startCleaning = COND #( WHEN saved = abap_true AND tank-Status = tank_status-free
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-finishCleaning = COND #( WHEN saved = abap_true AND tank-Status = tank_status-cleaning
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )
        %action-occupy         = COND #( WHEN saved = abap_true AND tank-Status = tank_status-free
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )
        %action-empty          = COND #( WHEN saved = abap_true AND tank-Status = tank_status-occupied
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD occupy.
    DATA(tanks) = set_status( tank_keys = CORRESPONDING #( keys )
                              status    = tank_status-occupied ).
    result = VALUE #( FOR tank IN tanks ( %tky = tank-%tky %param = tank ) ).
  ENDMETHOD.

  METHOD empty.
    " After the beer is filled the tank has to be cleaned before the next brew
    DATA(tanks) = set_status( tank_keys = CORRESPONDING #( keys )
                              status    = tank_status-cleaning ).
    result = VALUE #( FOR tank IN tanks ( %tky = tank-%tky %param = tank ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by plant follows in stage v1.0 together with authorization object ZVHB_PLANT
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD startCleaning.
    DATA(tanks) = set_status( tank_keys = CORRESPONDING #( keys )
                              status    = tank_status-cleaning ).
    result = VALUE #( FOR tank IN tanks ( %tky = tank-%tky %param = tank ) ).
  ENDMETHOD.

  METHOD finishCleaning.
    DATA(tanks) = set_status( tank_keys = CORRESPONDING #( keys )
                              status    = tank_status-free ).
    result = VALUE #( FOR tank IN tanks ( %tky = tank-%tky %param = tank ) ).
  ENDMETHOD.

  METHOD set_status.
    MODIFY ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN tank_keys ( %tky = key-%tky Status = status ) ).

    READ ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        ALL FIELDS WITH CORRESPONDING #( tank_keys )
      RESULT result.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        FIELDS ( Status CapacityUnit ) WITH CORRESPONDING #( keys )
      RESULT DATA(tanks).

    DELETE tanks WHERE Status IS NOT INITIAL AND CapacityUnit IS NOT INITIAL.
    IF tanks IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        UPDATE FIELDS ( Status CapacityUnit )
        WITH VALUE #( FOR tank IN tanks
                      ( %tky         = tank-%tky
                        Status       = COND #( WHEN tank-Status IS INITIAL THEN tank_status-free ELSE tank-Status )
                        CapacityUnit = COND #( WHEN tank-CapacityUnit IS INITIAL THEN c_hectoliter ELSE tank-CapacityUnit ) ) ).
  ENDMETHOD.

  METHOD validateTankNumber.
    READ ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        FIELDS ( Tank ) WITH CORRESPONDING #( keys )
      RESULT DATA(tanks).

    LOOP AT tanks INTO DATA(tank).
      APPEND VALUE #( %tky = tank-%tky %state_area = 'TANK_NUMBER' ) TO reported-tank.

      IF NOT matches( val = tank-Tank pcre = `[A-Z0-9][A-Z0-9-]*` ).
        APPEND VALUE #( %tky = tank-%tky ) TO failed-tank.
        APPEND VALUE #( %tky          = tank-%tky
                        %state_area   = 'TANK_NUMBER'
                        %msg          = new_message( id       = c_msgid
                                                     number   = '044'
                                                     severity = if_abap_behv_message=>severity-error
                                                     v1       = tank-Tank )
                        %element-Tank = if_abap_behv=>mk-on ) TO reported-tank.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatePlant.
    READ ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        FIELDS ( Plant ) WITH CORRESPONDING #( keys )
      RESULT DATA(tanks).

    LOOP AT tanks INTO DATA(tank).
      APPEND VALUE #( %tky = tank-%tky %state_area = 'PLANT' ) TO reported-tank.

      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant
                                             value  = tank-Plant ).
        APPEND VALUE #( %tky = tank-%tky ) TO failed-tank.
        APPEND VALUE #( %tky           = tank-%tky
                        %state_area    = 'PLANT'
                        %msg           = new_message( id       = c_msgid
                                                      number   = '008'
                                                      severity = if_abap_behv_message=>severity-error
                                                      v1       = tank-Plant )
                        %element-Plant = if_abap_behv=>mk-on ) TO reported-tank.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCapacity.
    READ ENTITIES OF zvhb_r_fermentationtank IN LOCAL MODE
      ENTITY Tank
        FIELDS ( Capacity ) WITH CORRESPONDING #( keys )
      RESULT DATA(tanks).

    LOOP AT tanks INTO DATA(tank).
      APPEND VALUE #( %tky = tank-%tky %state_area = 'CAPACITY' ) TO reported-tank.

      IF tank-Capacity <= 0.
        APPEND VALUE #( %tky = tank-%tky ) TO failed-tank.
        APPEND VALUE #( %tky              = tank-%tky
                        %state_area       = 'CAPACITY'
                        %msg              = new_message( id       = c_msgid
                                                         number   = '045'
                                                         severity = if_abap_behv_message=>severity-error
                                                         v1       = tank-Tank )
                        %element-Capacity = if_abap_behv=>mk-on ) TO reported-tank.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

