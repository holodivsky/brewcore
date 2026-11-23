*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS lhc_rate DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_FI'.
    CONSTANTS c_default_currency TYPE zvhb_currency VALUE 'EUR'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Rate RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Rate~setDefaults.

    METHODS calculateRate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Rate~calculateRate.

    METHODS validatePlant FOR VALIDATE ON SAVE
      IMPORTING keys FOR Rate~validatePlant.

    METHODS validateValidFrom FOR VALIDATE ON SAVE
      IMPORTING keys FOR Rate~validateValidFrom.

    METHODS validateRate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Rate~validateRate.
ENDCLASS.


CLASS lhc_rate IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Authorization by role follows in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_beertaxrate IN LOCAL MODE
      ENTITY Rate
        FIELDS ( StandardRate RatePercent Currency ValidFrom ) WITH CORRESPONDING #( keys )
      RESULT DATA(rates).

    " New rates start from the standard rate of section 2 (1) BierStG, valid from today
    MODIFY ENTITIES OF zvhb_r_beertaxrate IN LOCAL MODE
      ENTITY Rate
        UPDATE FIELDS ( StandardRate RatePercent Currency ValidFrom )
        WITH VALUE #( FOR r IN rates
                      ( %tky         = r-%tky
                        StandardRate = COND #( WHEN r-StandardRate IS INITIAL THEN zcl_vhb_beer_tax=>c_standard_rate
                                               ELSE r-StandardRate )
                        RatePercent  = COND #( WHEN r-RatePercent IS INITIAL THEN zcl_vhb_beer_tax=>c_full_rate
                                               ELSE r-RatePercent )
                        Currency     = COND #( WHEN r-Currency IS INITIAL THEN c_default_currency ELSE r-Currency )
                        ValidFrom    = COND #( WHEN r-ValidFrom IS INITIAL THEN cl_abap_context_info=>get_system_date( )
                                               ELSE r-ValidFrom ) ) ).
  ENDMETHOD.

  METHOD calculateRate.
    READ ENTITIES OF zvhb_r_beertaxrate IN LOCAL MODE
      ENTITY Rate
        FIELDS ( StandardRate RatePercent ) WITH CORRESPONDING #( keys )
      RESULT DATA(rates).

    MODIFY ENTITIES OF zvhb_r_beertaxrate IN LOCAL MODE
      ENTITY Rate
        UPDATE FIELDS ( RatePerDegree )
        WITH VALUE #( FOR r IN rates
                      ( %tky          = r-%tky
                        RatePerDegree = zcl_vhb_beer_tax=>rate_per_degree( standard_rate = r-StandardRate
                                                                           percent       = r-RatePercent ) ) ).
  ENDMETHOD.

  METHOD validatePlant.
    READ ENTITIES OF zvhb_r_beertaxrate IN LOCAL MODE
      ENTITY Rate
        FIELDS ( Plant ) WITH CORRESPONDING #( keys )
      RESULT DATA(rates).

    LOOP AT rates INTO DATA(rate).
      APPEND VALUE #( %tky = rate-%tky %state_area = 'PLANT' ) TO reported-rate.
      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant value = rate-Plant ).
        APPEND VALUE #( %tky = rate-%tky ) TO failed-rate.
        APPEND VALUE #( %tky           = rate-%tky
                        %state_area    = 'PLANT'
                        %msg           = new_message( id       = c_msgid
                                                      number   = '001'
                                                      severity = if_abap_behv_message=>severity-error
                                                      v1       = rate-Plant )
                        %element-Plant = if_abap_behv=>mk-on ) TO reported-rate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateValidFrom.
    READ ENTITIES OF zvhb_r_beertaxrate IN LOCAL MODE
      ENTITY Rate
        FIELDS ( Plant ValidFrom ) WITH CORRESPONDING #( keys )
      RESULT DATA(rates).

    IF rates IS INITIAL.
      RETURN.
    ENDIF.

    SELECT rate_uuid, plant, valid_from FROM zvhb_btrate
      FOR ALL ENTRIES IN @rates
      WHERE plant = @rates-Plant
      INTO TABLE @DATA(saved_rates).

    " One rate per plant and day; a later valid-from date replaces the rate from that day on
    LOOP AT rates INTO DATA(rate).
      APPEND VALUE #( %tky = rate-%tky %state_area = 'VALID_FROM' ) TO reported-rate.

      IF rate-ValidFrom IS INITIAL.
        APPEND VALUE #( %tky = rate-%tky ) TO failed-rate.
        APPEND VALUE #( %tky               = rate-%tky
                        %state_area        = 'VALID_FROM'
                        %msg               = new_message( id       = c_msgid
                                                          number   = '005'
                                                          severity = if_abap_behv_message=>severity-error )
                        %element-ValidFrom = if_abap_behv=>mk-on ) TO reported-rate.
        CONTINUE.
      ENDIF.

      LOOP AT saved_rates TRANSPORTING NO FIELDS
           WHERE plant = rate-Plant AND valid_from = rate-ValidFrom AND rate_uuid <> rate-RateUUID.
        APPEND VALUE #( %tky = rate-%tky ) TO failed-rate.
        APPEND VALUE #( %tky               = rate-%tky
                        %state_area        = 'VALID_FROM'
                        %msg               = new_message( id       = c_msgid
                                                          number   = '004'
                                                          severity = if_abap_behv_message=>severity-error
                                                          v1       = rate-Plant
                                                          v2       = |{ rate-ValidFrom DATE = USER }| )
                        %element-ValidFrom = if_abap_behv=>mk-on ) TO reported-rate.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateRate.
    READ ENTITIES OF zvhb_r_beertaxrate IN LOCAL MODE
      ENTITY Rate
        FIELDS ( StandardRate RatePercent ) WITH CORRESPONDING #( keys )
      RESULT DATA(rates).

    LOOP AT rates INTO DATA(rate).
      APPEND VALUE #( %tky = rate-%tky %state_area = 'RATE' ) TO reported-rate.

      IF rate-StandardRate <= 0.
        APPEND VALUE #( %tky = rate-%tky ) TO failed-rate.
        APPEND VALUE #( %tky                  = rate-%tky
                        %state_area           = 'RATE'
                        %msg                  = new_message( id       = c_msgid
                                                             number   = '002'
                                                             severity = if_abap_behv_message=>severity-error )
                        %element-StandardRate = if_abap_behv=>mk-on ) TO reported-rate.
      ENDIF.

      " Section 2 (2) BierStG: small breweries pay between 50 % and the full rate
      IF rate-RatePercent < zcl_vhb_beer_tax=>c_lowest_rate OR rate-RatePercent > zcl_vhb_beer_tax=>c_full_rate.
        APPEND VALUE #( %tky = rate-%tky ) TO failed-rate.
        APPEND VALUE #( %tky                 = rate-%tky
                        %state_area          = 'RATE'
                        %msg                 = new_message( id       = c_msgid
                                                            number   = '003'
                                                            severity = if_abap_behv_message=>severity-error
                                                            v1       = '50'
                                                            v2       = '100' )
                        %element-RatePercent = if_abap_behv=>mk-on ) TO reported-rate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

