*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_price DEFINITION DEFERRED FOR TESTING.

CLASS lhc_price DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_price.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    CONSTANTS:
      BEGIN OF condition_types,
        base_price TYPE zvhb_cond_type VALUE 'BASE',
        deposit    TYPE zvhb_cond_type VALUE 'DEPO',
      END OF condition_types.

    "! Deposit is charged only for returnable empties: bottles, crates, kegs
    CONSTANTS c_empties_type TYPE zvhb_material_type VALUE 'LEER'.
    CONSTANTS c_default_currency TYPE zvhb_currency VALUE 'EUR'.
    CONSTANTS c_open_end TYPE d VALUE '99991231'.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Price RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Price RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Price~setDefaults.

    METHODS setBaseUnit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Price~setBaseUnit.

    METHODS clearDepositChannel FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Price~clearDepositChannel.

    METHODS validateConditionType FOR VALIDATE ON SAVE
      IMPORTING keys FOR Price~validateConditionType.

    METHODS validateMaterial FOR VALIDATE ON SAVE
      IMPORTING keys FOR Price~validateMaterial.

    METHODS validateChannel FOR VALIDATE ON SAVE
      IMPORTING keys FOR Price~validateChannel.

    METHODS validateValidity FOR VALIDATE ON SAVE
      IMPORTING keys FOR Price~validateValidity.

    METHODS validateAmount FOR VALIDATE ON SAVE
      IMPORTING keys FOR Price~validateAmount.

    METHODS validateOverlap FOR VALIDATE ON SAVE
      IMPORTING keys FOR Price~validateOverlap.
ENDCLASS.


CLASS lhc_price IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( ConditionType ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices)
      FAILED failed.

    " A deposit is the same in every channel and has no quantity scales
    result = VALUE #(
      FOR price IN prices
      LET is_deposit = xsdbool( price-ConditionType = condition_types-deposit ) IN
      ( %tky                         = price-%tky
        %field-DistributionChannel = COND #( WHEN is_deposit = abap_true
                                               THEN if_abap_behv=>fc-f-read_only
                                               ELSE if_abap_behv=>fc-f-unrestricted )
        %assoc-_Scale              = COND #( WHEN is_deposit = abap_true
                                               THEN if_abap_behv=>fc-o-disabled
                                               ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by role follows in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( Currency ValidFrom ValidTo ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    DELETE prices WHERE Currency IS NOT INITIAL AND ValidFrom IS NOT INITIAL AND ValidTo IS NOT INITIAL.
    IF prices IS INITIAL.
      RETURN.
    ENDIF.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        UPDATE FIELDS ( Currency ValidFrom ValidTo )
        WITH VALUE #( FOR price IN prices
                      ( %tky      = price-%tky
                        Currency  = COND #( WHEN price-Currency IS INITIAL THEN c_default_currency ELSE price-Currency )
                        ValidFrom = COND #( WHEN price-ValidFrom IS INITIAL THEN today ELSE price-ValidFrom )
                        ValidTo   = COND #( WHEN price-ValidTo IS INITIAL THEN c_open_end ELSE price-ValidTo ) ) ).
  ENDMETHOD.

  METHOD setBaseUnit.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    IF prices IS INITIAL.
      RETURN.
    ENDIF.

    SELECT material, base_unit FROM zvhb_mat
      FOR ALL ENTRIES IN @prices
      WHERE material = @prices-Material
      INTO TABLE @DATA(materials).

    MODIFY ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        UPDATE FIELDS ( BaseUnit )
        WITH VALUE #( FOR price IN prices
                      ( %tky     = price-%tky
                        BaseUnit = VALUE #( materials[ material = price-Material ]-base_unit OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD clearDepositChannel.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( ConditionType DistributionChannel ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    DELETE prices WHERE ConditionType <> condition_types-deposit OR DistributionChannel IS INITIAL.
    IF prices IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        UPDATE FIELDS ( DistributionChannel )
        WITH VALUE #( FOR price IN prices ( %tky = price-%tky DistributionChannel = '' ) ).
  ENDMETHOD.

  METHOD validateConditionType.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( ConditionType ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    LOOP AT prices INTO DATA(price).
      APPEND VALUE #( %tky = price-%tky %state_area = 'CONDITION_TYPE' ) TO reported-price.

      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-condition_type
                                             value  = price-ConditionType ).
        APPEND VALUE #( %tky = price-%tky ) TO failed-price.
        APPEND VALUE #( %tky                   = price-%tky
                        %state_area            = 'CONDITION_TYPE'
                        %msg                   = new_message( id       = c_msgid
                                                              number   = '020'
                                                              severity = if_abap_behv_message=>severity-error
                                                              v1       = price-ConditionType )
                        %element-ConditionType = if_abap_behv=>mk-on ) TO reported-price.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMaterial.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( ConditionType Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    IF prices IS INITIAL.
      RETURN.
    ENDIF.

    SELECT material, material_type, is_active FROM zvhb_mat
      FOR ALL ENTRIES IN @prices
      WHERE material = @prices-Material
      INTO TABLE @DATA(materials).

    LOOP AT prices INTO DATA(price).
      APPEND VALUE #( %tky = price-%tky %state_area = 'MATERIAL' ) TO reported-price.

      DATA(material) = VALUE #( materials[ material = price-Material ] OPTIONAL ).

      DATA(message) = COND #(
        WHEN material IS INITIAL
        THEN new_message( id = c_msgid number = '021' severity = if_abap_behv_message=>severity-error v1 = price-Material )
        WHEN material-is_active = abap_false
        THEN new_message( id = c_msgid number = '022' severity = if_abap_behv_message=>severity-error v1 = price-Material )
        WHEN price-ConditionType = condition_types-deposit AND material-material_type <> c_empties_type
        THEN new_message( id = c_msgid number = '024' severity = if_abap_behv_message=>severity-error v1 = price-Material ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = price-%tky ) TO failed-price.
        APPEND VALUE #( %tky              = price-%tky
                        %state_area       = 'MATERIAL'
                        %msg              = message
                        %element-Material = if_abap_behv=>mk-on ) TO reported-price.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateChannel.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( ConditionType Material DistributionChannel ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    LOOP AT prices INTO DATA(price).
      APPEND VALUE #( %tky = price-%tky %state_area = 'CHANNEL' ) TO reported-price.

      IF price-ConditionType = condition_types-deposit.
        CONTINUE.
      ENDIF.

      DATA(message) = COND #(
        WHEN price-DistributionChannel IS INITIAL
        THEN new_message( id = c_msgid number = '030' severity = if_abap_behv_message=>severity-error v1 = price-Material )
        WHEN NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-distribution_channel
                                                 value  = price-DistributionChannel )
        THEN new_message( id = c_msgid number = '023' severity = if_abap_behv_message=>severity-error v1 = price-DistributionChannel ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = price-%tky ) TO failed-price.
        APPEND VALUE #( %tky                         = price-%tky
                        %state_area                  = 'CHANNEL'
                        %msg                         = message
                        %element-DistributionChannel = if_abap_behv=>mk-on ) TO reported-price.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateValidity.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( ValidFrom ValidTo ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    LOOP AT prices INTO DATA(price).
      APPEND VALUE #( %tky = price-%tky %state_area = 'VALIDITY' ) TO reported-price.

      IF price-ValidTo < price-ValidFrom.
        APPEND VALUE #( %tky = price-%tky ) TO failed-price.
        APPEND VALUE #( %tky              = price-%tky
                        %state_area       = 'VALIDITY'
                        %msg              = new_message( id       = c_msgid
                                                         number   = '025'
                                                         severity = if_abap_behv_message=>severity-error )
                        %element-ValidFrom = if_abap_behv=>mk-on
                        %element-ValidTo   = if_abap_behv=>mk-on ) TO reported-price.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateAmount.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( Amount Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    IF prices IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Currency FROM I_Currency WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @prices
      WHERE Currency = @prices-Currency
      INTO TABLE @DATA(known_currencies).

    LOOP AT prices INTO DATA(price).
      APPEND VALUE #( %tky = price-%tky %state_area = 'AMOUNT' ) TO reported-price.

      DATA(message) = COND #(
        WHEN price-Amount <= 0
        THEN new_message( id = c_msgid number = '026' severity = if_abap_behv_message=>severity-error )
        WHEN price-Currency IS INITIAL
        THEN new_message( id = c_msgid number = '031' severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( known_currencies[ Currency = price-Currency ] )
        THEN new_message( id = c_msgid number = '014' severity = if_abap_behv_message=>severity-error v1 = price-Currency ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = price-%tky ) TO failed-price.
        APPEND VALUE #( %tky              = price-%tky
                        %state_area       = 'AMOUNT'
                        %msg              = message
                        %element-Amount   = if_abap_behv=>mk-on
                        %element-Currency = if_abap_behv=>mk-on ) TO reported-price.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateOverlap.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Price
        FIELDS ( ConditionType Material DistributionChannel ValidFrom ValidTo ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices).

    IF prices IS INITIAL.
      RETURN.
    ENDIF.

    SELECT price_uuid, condition_type, material, distr_channel, valid_from, valid_to FROM zvhb_price
      FOR ALL ENTRIES IN @prices
      WHERE condition_type = @prices-ConditionType
        AND material       = @prices-Material
        AND distr_channel  = @prices-DistributionChannel
      INTO TABLE @DATA(saved_prices).

    LOOP AT prices INTO DATA(price).
      APPEND VALUE #( %tky = price-%tky %state_area = 'OVERLAP' ) TO reported-price.

      LOOP AT saved_prices TRANSPORTING NO FIELDS
           WHERE price_uuid     <> price-PriceUUID
             AND condition_type  = price-ConditionType
             AND material        = price-Material
             AND distr_channel   = price-DistributionChannel
             AND valid_from     <= price-ValidTo
             AND valid_to       >= price-ValidFrom.
        APPEND VALUE #( %tky = price-%tky ) TO failed-price.
        APPEND VALUE #( %tky               = price-%tky
                        %state_area        = 'OVERLAP'
                        %msg               = new_message( id       = c_msgid
                                                          number   = '027'
                                                          severity = if_abap_behv_message=>severity-error
                                                          v1       = price-ConditionType
                                                          v2       = price-Material )
                        %element-ValidFrom = if_abap_behv=>mk-on
                        %element-ValidTo   = if_abap_behv=>mk-on ) TO reported-price.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_scale DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_price.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    METHODS setBaseUnit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Scale~setBaseUnit.

    METHODS validateScale FOR VALIDATE ON SAVE
      IMPORTING keys FOR Scale~validateScale.
ENDCLASS.


CLASS lhc_scale IMPLEMENTATION.

  METHOD setBaseUnit.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Scale BY \_Price
        FIELDS ( BaseUnit ) WITH CORRESPONDING #( keys )
      RESULT DATA(prices)
      LINK DATA(links).

    MODIFY ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Scale
        UPDATE FIELDS ( BaseUnit )
        WITH VALUE #( FOR link IN links
                      ( %tky     = link-source-%tky
                        BaseUnit = VALUE #( prices[ KEY id COMPONENTS %is_draft = link-target-%tky-%is_draft
                                                                      PriceUUID = link-target-%tky-PriceUUID ]-BaseUnit OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD validateScale.
    READ ENTITIES OF zvhb_r_pricecondition IN LOCAL MODE
      ENTITY Scale
        FIELDS ( FromQuantity DiscountPercent ) WITH CORRESPONDING #( keys )
      RESULT DATA(scales).

    LOOP AT scales INTO DATA(scale).
      APPEND VALUE #( %tky                    = scale-%tky
                      %state_area             = 'SCALE'
                      %path-price-%is_draft   = scale-%is_draft
                      %path-price-PriceUUID   = scale-PriceUUID ) TO reported-scale.

      DATA(message) = COND #(
        WHEN scale-FromQuantity <= 0
        THEN new_message( id = c_msgid number = '028' severity = if_abap_behv_message=>severity-error )
        WHEN scale-DiscountPercent <= 0 OR scale-DiscountPercent > 100
        THEN new_message( id = c_msgid number = '029' severity = if_abap_behv_message=>severity-error ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = scale-%tky ) TO failed-scale.
        APPEND VALUE #( %tky                     = scale-%tky
                        %state_area              = 'SCALE'
                        %msg                     = message
                        %path-price-%is_draft    = scale-%is_draft
                        %path-price-PriceUUID    = scale-PriceUUID
                        %element-FromQuantity    = if_abap_behv=>mk-on
                        %element-DiscountPercent = if_abap_behv=>mk-on ) TO reported-scale.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

