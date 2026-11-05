*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_material DEFINITION DEFERRED FOR TESTING.

CLASS lhc_material DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_material.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    CONSTANTS:
      "! Material types that are always handled in batches
      BEGIN OF batch_managed_type,
        finished_product TYPE zvhb_material_type VALUE 'FERT',
        raw_material     TYPE zvhb_material_type VALUE 'ROH',
      END OF batch_managed_type.

    TYPES tt_material_keys TYPE TABLE FOR READ IMPORT zvhb_r_material\\material.
    TYPES tt_materials     TYPE TABLE FOR READ RESULT zvhb_r_material\\material.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Material RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Material RESULT result.

    METHODS reactivate FOR MODIFY
      IMPORTING keys FOR ACTION Material~reactivate RESULT result.

    METHODS deactivate FOR MODIFY
      IMPORTING keys FOR ACTION Material~deactivate RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Material~setDefaults.

    METHODS setBatchManagement FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Material~setBatchManagement.

    METHODS validateMaterialNumber FOR VALIDATE ON SAVE
      IMPORTING keys FOR Material~validateMaterialNumber.

    METHODS validateMaterialType FOR VALIDATE ON SAVE
      IMPORTING keys FOR Material~validateMaterialType.

    METHODS validateBaseUnit FOR VALIDATE ON SAVE
      IMPORTING keys FOR Material~validateBaseUnit.

    METHODS validateBatchManagement FOR VALIDATE ON SAVE
      IMPORTING keys FOR Material~validateBatchManagement.

    "! Sets the active flag and returns the changed materials
    METHODS set_status
      IMPORTING
        material_keys TYPE tt_material_keys
        active        TYPE abap_boolean
      RETURNING
        VALUE(result) TYPE tt_materials.
ENDCLASS.


CLASS lhc_material IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        FIELDS ( IsActive IsBatchManaged ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials)
      FAILED failed.

    " The status actions work on saved materials only, never on a draft
    result = VALUE #(
      FOR material IN materials
      LET changeable = COND #( WHEN material-IsActive = abap_true
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )
          can_deactivate = COND #( WHEN material-%is_draft = if_abap_behv=>mk-off
                                    AND material-IsActive = abap_true
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )
          can_reactivate = COND #( WHEN material-%is_draft = if_abap_behv=>mk-off
                                    AND material-IsActive = abap_false
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky                 = material-%tky
        %update              = changeable
        %delete              = changeable
        %action-Edit         = changeable
        %action-deactivate   = can_deactivate
        %action-reactivate   = can_reactivate
        %assoc-_Text         = changeable
        %assoc-_Unit         = changeable
        %assoc-_Plant        = changeable
        %field-ShelfLifeDays = COND #( WHEN material-IsBatchManaged = abap_true
                                       THEN if_abap_behv=>fc-f-unrestricted
                                       ELSE if_abap_behv=>fc-f-read_only ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by plant follows in stage v1.0 together with authorization object ZVHB_PLANT
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD reactivate.
    DATA(materials) = set_status( material_keys = CORRESPONDING #( keys )
                                  active        = abap_true ).
    result = VALUE #( FOR material IN materials ( %tky = material-%tky %param = material ) ).
  ENDMETHOD.

  METHOD deactivate.
    DATA(materials) = set_status( material_keys = CORRESPONDING #( keys )
                                  active        = abap_false ).
    result = VALUE #( FOR material IN materials ( %tky = material-%tky %param = material ) ).
  ENDMETHOD.

  METHOD set_status.
    MODIFY ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        UPDATE FIELDS ( IsActive )
        WITH VALUE #( FOR key IN material_keys ( %tky = key-%tky IsActive = active ) ).

    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        ALL FIELDS WITH CORRESPONDING #( material_keys )
      RESULT result.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        FIELDS ( IsActive ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    DELETE materials WHERE IsActive = abap_true.
    IF materials IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        UPDATE FIELDS ( IsActive )
        WITH VALUE #( FOR material IN materials ( %tky = material-%tky IsActive = abap_true ) ).
  ENDMETHOD.

  METHOD setBatchManagement.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        FIELDS ( MaterialType IsBatchManaged ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    DELETE materials WHERE IsBatchManaged = abap_true
                        OR (     MaterialType <> batch_managed_type-finished_product
                             AND MaterialType <> batch_managed_type-raw_material ).
    IF materials IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        UPDATE FIELDS ( IsBatchManaged )
        WITH VALUE #( FOR material IN materials ( %tky = material-%tky IsBatchManaged = abap_true ) ).
  ENDMETHOD.

  METHOD validateMaterialNumber.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    LOOP AT materials INTO DATA(material).
      APPEND VALUE #( %tky = material-%tky %state_area = 'MATERIAL_NUMBER' ) TO reported-material.

      IF NOT matches( val = material-Material pcre = `[A-Z0-9][A-Z0-9-]*` ).
        APPEND VALUE #( %tky = material-%tky ) TO failed-material.
        APPEND VALUE #( %tky              = material-%tky
                        %state_area       = 'MATERIAL_NUMBER'
                        %msg              = new_message( id       = c_msgid
                                                         number   = '001'
                                                         severity = if_abap_behv_message=>severity-error
                                                         v1       = material-Material )
                        %element-Material = if_abap_behv=>mk-on ) TO reported-material.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMaterialType.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        FIELDS ( MaterialType ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    LOOP AT materials INTO DATA(material).
      APPEND VALUE #( %tky = material-%tky %state_area = 'MATERIAL_TYPE' ) TO reported-material.

      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-material_type
                                             value  = material-MaterialType ).
        APPEND VALUE #( %tky = material-%tky ) TO failed-material.
        APPEND VALUE #( %tky                  = material-%tky
                        %state_area           = 'MATERIAL_TYPE'
                        %msg                  = new_message( id       = c_msgid
                                                             number   = '002'
                                                             severity = if_abap_behv_message=>severity-error
                                                             v1       = material-MaterialType )
                        %element-MaterialType = if_abap_behv=>mk-on ) TO reported-material.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateBaseUnit.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        FIELDS ( BaseUnit ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    IF materials IS INITIAL.
      RETURN.
    ENDIF.

    SELECT UnitOfMeasure FROM I_UnitOfMeasure WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @materials
      WHERE UnitOfMeasure = @materials-BaseUnit
      INTO TABLE @DATA(known_units).

    LOOP AT materials INTO DATA(material).
      APPEND VALUE #( %tky = material-%tky %state_area = 'BASE_UNIT' ) TO reported-material.

      IF material-BaseUnit IS NOT INITIAL AND line_exists( known_units[ UnitOfMeasure = material-BaseUnit ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = material-%tky ) TO failed-material.
      APPEND VALUE #( %tky              = material-%tky
                      %state_area       = 'BASE_UNIT'
                      %msg              = COND #( WHEN material-BaseUnit IS INITIAL
                                                  THEN new_message( id       = c_msgid
                                                                    number   = '011'
                                                                    severity = if_abap_behv_message=>severity-error
                                                                    v1       = material-Material )
                                                  ELSE new_message( id       = c_msgid
                                                                    number   = '003'
                                                                    severity = if_abap_behv_message=>severity-error
                                                                    v1       = material-BaseUnit ) )
                      %element-BaseUnit = if_abap_behv=>mk-on ) TO reported-material.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateBatchManagement.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Material
        FIELDS ( MaterialType IsBatchManaged ShelfLifeDays ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    LOOP AT materials INTO DATA(material).
      APPEND VALUE #( %tky = material-%tky %state_area = 'BATCH_MANAGEMENT' ) TO reported-material.

      IF (    material-MaterialType = batch_managed_type-finished_product
           OR material-MaterialType = batch_managed_type-raw_material )
         AND material-IsBatchManaged = abap_false.
        APPEND VALUE #( %tky = material-%tky ) TO failed-material.
        APPEND VALUE #( %tky                    = material-%tky
                        %state_area             = 'BATCH_MANAGEMENT'
                        %msg                    = new_message( id       = c_msgid
                                                               number   = '004'
                                                               severity = if_abap_behv_message=>severity-error
                                                               v1       = material-MaterialType )
                        %element-IsBatchManaged = if_abap_behv=>mk-on ) TO reported-material.

      ELSEIF material-IsBatchManaged = abap_true AND material-ShelfLifeDays <= 0.
        APPEND VALUE #( %tky = material-%tky ) TO failed-material.
        APPEND VALUE #( %tky                   = material-%tky
                        %state_area            = 'BATCH_MANAGEMENT'
                        %msg                   = new_message( id       = c_msgid
                                                              number   = '005'
                                                              severity = if_abap_behv_message=>severity-error
                                                              v1       = material-Material )
                        %element-ShelfLifeDays = if_abap_behv=>mk-on ) TO reported-material.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_unit DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_material.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    METHODS validateConversion FOR VALIDATE ON SAVE
      IMPORTING keys FOR Unit~validateConversion.
ENDCLASS.


CLASS lhc_unit IMPLEMENTATION.

  METHOD validateConversion.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Unit
        FIELDS ( AltUnit Numerator Denominator ) WITH CORRESPONDING #( keys )
      RESULT DATA(units).

    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Unit BY \_Material
        FIELDS ( BaseUnit ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    IF units IS INITIAL.
      RETURN.
    ENDIF.

    SELECT UnitOfMeasure FROM I_UnitOfMeasure WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @units
      WHERE UnitOfMeasure = @units-AltUnit
      INTO TABLE @DATA(known_units).

    LOOP AT units INTO DATA(unit).
      APPEND VALUE #( %tky                    = unit-%tky
                      %state_area             = 'CONVERSION'
                      %path-material-%is_draft = unit-%is_draft
                      %path-material-Material  = unit-Material ) TO reported-unit.

      DATA(base_unit) = VALUE #( materials[ KEY id COMPONENTS %is_draft = unit-%is_draft
                                                               Material  = unit-Material ]-BaseUnit OPTIONAL ).

      DATA(message) = COND #(
        WHEN unit-Numerator <= 0 OR unit-Denominator <= 0
        THEN new_message( id = c_msgid number = '006' severity = if_abap_behv_message=>severity-error v1 = unit-AltUnit )
        WHEN unit-AltUnit = base_unit
        THEN new_message( id = c_msgid number = '007' severity = if_abap_behv_message=>severity-error v1 = unit-AltUnit )
        WHEN NOT line_exists( known_units[ UnitOfMeasure = unit-AltUnit ] )
        THEN new_message( id = c_msgid number = '003' severity = if_abap_behv_message=>severity-error v1 = unit-AltUnit ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = unit-%tky ) TO failed-unit.
        APPEND VALUE #( %tky                     = unit-%tky
                        %state_area              = 'CONVERSION'
                        %msg                     = message
                        %path-material-%is_draft = unit-%is_draft
                        %path-material-Material  = unit-Material
                        %element-Numerator       = if_abap_behv=>mk-on
                        %element-Denominator     = if_abap_behv=>mk-on ) TO reported-unit.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_plant DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_material.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    METHODS setBaseUnit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Plant~setBaseUnit.

    METHODS validatePlant FOR VALIDATE ON SAVE
      IMPORTING keys FOR Plant~validatePlant.

    METHODS validateStockLevels FOR VALIDATE ON SAVE
      IMPORTING keys FOR Plant~validateStockLevels.
ENDCLASS.


CLASS lhc_plant IMPLEMENTATION.

  METHOD setBaseUnit.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Plant BY \_Material
        FIELDS ( BaseUnit ) WITH CORRESPONDING #( keys )
      RESULT DATA(materials)
      LINK DATA(links).

    MODIFY ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Plant
        UPDATE FIELDS ( BaseUnit )
        WITH VALUE #( FOR link IN links
                      ( %tky     = link-source-%tky
                        BaseUnit = VALUE #( materials[ KEY id COMPONENTS %is_draft = link-target-%tky-%is_draft
                                                                         Material  = link-target-%tky-Material ]-BaseUnit OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD validatePlant.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Plant
        FIELDS ( Plant ) WITH CORRESPONDING #( keys )
      RESULT DATA(plants).

    LOOP AT plants INTO DATA(plant).
      APPEND VALUE #( %tky                     = plant-%tky
                      %state_area              = 'PLANT'
                      %path-material-%is_draft = plant-%is_draft
                      %path-material-Material  = plant-Material ) TO reported-plant.

      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant
                                             value  = plant-Plant ).
        APPEND VALUE #( %tky = plant-%tky ) TO failed-plant.
        APPEND VALUE #( %tky                     = plant-%tky
                        %state_area              = 'PLANT'
                        %msg                     = new_message( id       = c_msgid
                                                                number   = '008'
                                                                severity = if_abap_behv_message=>severity-error
                                                                v1       = plant-Plant )
                        %path-material-%is_draft = plant-%is_draft
                        %path-material-Material  = plant-Material
                        %element-Plant           = if_abap_behv=>mk-on ) TO reported-plant.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateStockLevels.
    READ ENTITIES OF zvhb_r_material IN LOCAL MODE
      ENTITY Plant
        FIELDS ( Plant MinStock ReorderPoint ) WITH CORRESPONDING #( keys )
      RESULT DATA(plants).

    LOOP AT plants INTO DATA(plant).
      APPEND VALUE #( %tky                     = plant-%tky
                      %state_area              = 'STOCK_LEVELS'
                      %path-material-%is_draft = plant-%is_draft
                      %path-material-Material  = plant-Material ) TO reported-plant.

      DATA(message) = COND #(
        WHEN plant-MinStock < 0 OR plant-ReorderPoint < 0
        THEN new_message( id = c_msgid number = '010' severity = if_abap_behv_message=>severity-error v1 = plant-Plant )
        WHEN plant-MinStock > plant-ReorderPoint
        THEN new_message( id = c_msgid number = '009' severity = if_abap_behv_message=>severity-error v1 = plant-Plant ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = plant-%tky ) TO failed-plant.
        APPEND VALUE #( %tky                     = plant-%tky
                        %state_area              = 'STOCK_LEVELS'
                        %msg                     = message
                        %path-material-%is_draft = plant-%is_draft
                        %path-material-Material  = plant-Material
                        %element-MinStock        = if_abap_behv=>mk-on
                        %element-ReorderPoint    = if_abap_behv=>mk-on ) TO reported-plant.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

