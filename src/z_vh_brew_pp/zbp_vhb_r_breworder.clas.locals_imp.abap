*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_brew_order DEFINITION DEFERRED FOR TESTING.

"! Status values and defaults shared by the handlers of the brew order
INTERFACE lif_brew_order.
  CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_PP'.

  CONSTANTS:
    "! Brew order status values of domain ZVHB_BREW_STATUS, in the order of the phases
    BEGIN OF status,
      created      TYPE zvhb_brew_status VALUE 'NEW',
      released     TYPE zvhb_brew_status VALUE 'REL',
      mashing      TYPE zvhb_brew_status VALUE 'MASH',
      boiling      TYPE zvhb_brew_status VALUE 'BOIL',
      fermentation TYPE zvhb_brew_status VALUE 'FERM',
      maturation   TYPE zvhb_brew_status VALUE 'MATU',
      filled       TYPE zvhb_brew_status VALUE 'DONE',
    END OF status.

  CONSTANTS:
    BEGIN OF defaults,
      plant                TYPE zvhb_plant VALUE 'BR01',
      raw_material_storage TYPE zvhb_storage_loc VALUE 'RM01',
      beer_storage         TYPE zvhb_storage_loc VALUE 'FG01',
    END OF defaults.

  CONSTANTS:
    BEGIN OF movement_type,
      production_issue TYPE zvhb_movement_type VALUE '261',
      goods_receipt    TYPE zvhb_movement_type VALUE '101',
    END OF movement_type.

  CONSTANTS c_tank_free TYPE zvhb_tank_status VALUE 'FREE'.
  CONSTANTS c_raw_material TYPE zvhb_material_type VALUE 'ROH'.
ENDINTERFACE.


CLASS lhc_brew_order DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_brew_order.
  PRIVATE SECTION.
    TYPES tt_keys       TYPE TABLE FOR READ IMPORT zvhb_r_breworder\\breworder.
    TYPES tt_orders     TYPE TABLE FOR READ RESULT zvhb_r_breworder\\breworder.
    TYPES ty_order      TYPE STRUCTURE FOR READ RESULT zvhb_r_breworder\\breworder.
    TYPES tt_components TYPE TABLE FOR READ RESULT zvhb_r_breworder\\component.

    TYPES:
      "! Raw material needed for a brew order, summed over its components
      BEGIN OF ty_need,
        material         TYPE zvhb_material,
        plant            TYPE zvhb_plant,
        storage_location TYPE zvhb_storage_loc,
        unit             TYPE zvhb_unit,
        quantity         TYPE zvhb_quantity,
      END OF ty_need,
      tt_needs TYPE SORTED TABLE OF ty_need WITH UNIQUE KEY material plant storage_location.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR BrewOrder RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR BrewOrder RESULT result.

    METHODS release FOR MODIFY
      IMPORTING keys FOR ACTION BrewOrder~release RESULT result.

    METHODS startMashing FOR MODIFY
      IMPORTING keys FOR ACTION BrewOrder~startMashing RESULT result.

    METHODS startBoiling FOR MODIFY
      IMPORTING keys FOR ACTION BrewOrder~startBoiling RESULT result.

    METHODS startFermentation FOR MODIFY
      IMPORTING keys FOR ACTION BrewOrder~startFermentation RESULT result.

    METHODS startMaturation FOR MODIFY
      IMPORTING keys FOR ACTION BrewOrder~startMaturation RESULT result.

    METHODS fill FOR MODIFY
      IMPORTING keys FOR ACTION BrewOrder~fill RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BrewOrder~setDefaults.

    METHODS copyRecipe FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BrewOrder~copyRecipe.

    METHODS setPlannedEnd FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BrewOrder~setPlannedEnd.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR BrewOrder~setNumber.

    METHODS validateBeer FOR VALIDATE ON SAVE
      IMPORTING keys FOR BrewOrder~validateBeer.

    METHODS validateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR BrewOrder~validateQuantity.

    METHODS validateTank FOR VALIDATE ON SAVE
      IMPORTING keys FOR BrewOrder~validateTank.

    METHODS validateStart FOR VALIDATE ON SAVE
      IMPORTING keys FOR BrewOrder~validateStart.

    METHODS validateComponents FOR VALIDATE ON SAVE
      IMPORTING keys FOR BrewOrder~validateComponents.

    "! No other brew order occupies the tank between planned start and the day the tank is free again
    METHODS check_tank
      IMPORTING
        order         TYPE ty_order
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! Free, unexpired stock covers all components. With requirements, the raw materials that other
    "! released brew orders will take are no longer available.
    METHODS check_stock
      IMPORTING
        components        TYPE tt_components
        with_requirements TYPE abap_boolean
      RETURNING
        VALUE(result)     TYPE REF TO if_abap_behv_message.

    "! Posts one production issue (261) per component with the reference to the brew order
    METHODS issue_components
      IMPORTING
        order         TYPE ty_order
        components    TYPE tt_components
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    "! Sets the next phase with its actual date and returns the changed orders
    METHODS set_phase
      IMPORTING
        order_keys    TYPE tt_keys
        status        TYPE zvhb_brew_status
      RETURNING
        VALUE(result) TYPE tt_orders.

    METHODS read_orders
      IMPORTING
        order_keys    TYPE tt_keys
      RETURNING
        VALUE(result) TYPE tt_orders.

    METHODS message
      IMPORTING
        number        TYPE symsgno
        severity      TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        v1            TYPE simple OPTIONAL
        v2            TYPE simple OPTIONAL
        v3            TYPE simple OPTIONAL
        v4            TYPE simple OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS get_number_range
      RETURNING
        VALUE(result) TYPE REF TO zif_vhb_number_range.
ENDCLASS.


CLASS lhc_brew_order IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED failed.

    " The order is planned while it is new; afterwards each phase opens the next one
    result = VALUE #(
      FOR o IN orders
      LET changeable = COND #( WHEN o-Status = lif_brew_order=>status-created OR o-Status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )
          saved      = xsdbool( o-%is_draft = if_abap_behv=>mk-off ) IN
      ( %tky                      = o-%tky
        %update                   = changeable
        %delete                   = changeable
        %action-Edit              = changeable
        %assoc-_Component         = changeable
        %action-release           = COND #( WHEN saved = abap_true AND o-Status = lif_brew_order=>status-created
                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-startMashing      = COND #( WHEN saved = abap_true AND o-Status = lif_brew_order=>status-released
                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-startBoiling      = COND #( WHEN saved = abap_true AND o-Status = lif_brew_order=>status-mashing
                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-startFermentation = COND #( WHEN saved = abap_true AND o-Status = lif_brew_order=>status-boiling
                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-startMaturation   = COND #( WHEN saved = abap_true AND o-Status = lif_brew_order=>status-fermentation
                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-fill              = COND #( WHEN saved = abap_true AND o-Status = lif_brew_order=>status-maturation
                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " The brewer role follows in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD release.
    DATA(orders) = read_orders( CORRESPONDING #( keys ) ).

    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder BY \_Component
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(components).

    DATA released TYPE tt_keys.

    LOOP AT orders INTO DATA(order).
      DATA(order_components) = VALUE tt_components( FOR c IN components USING KEY entity
                                                    WHERE ( BrewOrderUUID = order-BrewOrderUUID ) ( c ) ).

      " FR-PP-02: the tank must be free for fermentation and maturation, the raw materials must be in stock
      DATA(problem) = check_tank( order ).
      IF problem IS NOT BOUND.
        problem = check_stock( components = order_components with_requirements = abap_true ).
      ENDIF.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky = order-%tky %msg = problem ) TO reported-breworder.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( order ) TO released.
      APPEND VALUE #( %tky = order-%tky
                      %msg = message( number   = '011'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = order-BrewOrder
                                      v2       = order-Tank ) ) TO reported-breworder.
    ENDLOOP.

    DATA(changed) = set_phase( order_keys = released status = lif_brew_order=>status-released ).
    result = VALUE #( FOR r IN changed ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD startMashing.
    DATA(orders) = read_orders( CORRESPONDING #( keys ) ).

    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder BY \_Component
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(components).

    DATA started TYPE tt_keys.

    LOOP AT orders INTO DATA(order).
      DATA(order_components) = VALUE tt_components( FOR c IN components USING KEY entity
                                                    WHERE ( BrewOrderUUID = order-BrewOrderUUID ) ( c ) ).

      " All components are checked first, so that no issue is posted when one of them is missing
      DATA(problem) = check_stock( components = order_components with_requirements = abap_false ).
      IF problem IS NOT BOUND.
        problem = issue_components( order = order components = order_components ).
      ENDIF.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky = order-%tky %msg = problem ) TO reported-breworder.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( order ) TO started.
      APPEND VALUE #( %tky = order-%tky
                      %msg = message( number   = '015'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = order-BrewOrder ) ) TO reported-breworder.
    ENDLOOP.

    DATA(changed) = set_phase( order_keys = started status = lif_brew_order=>status-mashing ).
    result = VALUE #( FOR r IN changed ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD startBoiling.
    DATA(changed) = set_phase( order_keys = CORRESPONDING #( keys ) status = lif_brew_order=>status-boiling ).
    result = VALUE #( FOR r IN changed ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD startFermentation.
    DATA(orders) = read_orders( CORRESPONDING #( keys ) ).
    DATA started TYPE tt_keys.

    LOOP AT orders INTO DATA(order).
      SELECT SINGLE status FROM zvhb_ftank
        WHERE tank = @order-Tank
        INTO @DATA(tank_status).

      " The cooled wort goes into the tank, which must be clean and empty
      IF tank_status <> lif_brew_order=>c_tank_free.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky = order-%tky %msg = message( number = '016' v1 = order-Tank v2 = tank_status ) )
               TO reported-breworder.
        CLEAR tank_status.
        CONTINUE.
      ENDIF.
      CLEAR tank_status.

      MODIFY ENTITIES OF zvhb_r_fermentationtank
        ENTITY Tank
          EXECUTE occupy FROM VALUE #( ( Tank = order-Tank ) )
        FAILED DATA(tank_failed)
        REPORTED DATA(tank_reported).

      IF tank_failed IS NOT INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky = order-%tky %msg = VALUE #( tank_reported-tank[ 1 ]-%msg OPTIONAL ) )
               TO reported-breworder.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( order ) TO started.
    ENDLOOP.

    DATA(changed) = set_phase( order_keys = started status = lif_brew_order=>status-fermentation ).
    result = VALUE #( FOR r IN changed ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD startMaturation.
    DATA(changed) = set_phase( order_keys = CORRESPONDING #( keys ) status = lif_brew_order=>status-maturation ).
    result = VALUE #( FOR r IN changed ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD fill.
    DATA(orders) = read_orders( CORRESPONDING #( keys ) ).
    DATA filled TYPE tt_keys.

    LOOP AT keys INTO DATA(key).
      DATA(order) = orders[ KEY id COMPONENTS %tky = key-%tky ].

      IF key-%param-Quantity <= 0.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky = order-%tky %msg = message( '018' ) ) TO reported-breworder.
        CONTINUE.
      ENDIF.

      " FR-PP-04: the beer is received into a new batch, the empty tank goes to cleaning;
      " brew order, material document, batch and tank are saved together
      MODIFY ENTITIES OF zvhb_r_materialdocument
        ENTITY MaterialDocument
          EXECUTE postGoodsMovement
          FROM VALUE #( ( %cid   = 'BEER'
                          %param = VALUE #( MovementType    = lif_brew_order=>movement_type-goods_receipt
                                            Material        = order-Material
                                            Plant           = order-Plant
                                            StorageLocation = lif_brew_order=>defaults-beer_storage
                                            Quantity        = key-%param-Quantity
                                            ProductionDate  = cl_abap_context_info=>get_system_date( )
                                            HeaderText      = |Brew order { order-BrewOrder }|
                                            BrewOrder       = order-BrewOrder ) ) )
        FAILED DATA(receipt_failed)
        REPORTED DATA(receipt_reported).

      IF receipt_failed IS INITIAL.
        MODIFY ENTITIES OF zvhb_r_fermentationtank
          ENTITY Tank
            EXECUTE empty FROM VALUE #( ( Tank = order-Tank ) )
          FAILED DATA(tank_failed)
          REPORTED DATA(tank_reported).
      ENDIF.

      IF receipt_failed IS NOT INITIAL OR tank_failed IS NOT INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = COND #( WHEN receipt_failed IS NOT INITIAL
                                       THEN VALUE #( receipt_reported-materialdocument[ 1 ]-%msg OPTIONAL )
                                       ELSE VALUE #( tank_reported-tank[ 1 ]-%msg OPTIONAL ) ) ) TO reported-breworder.
        CLEAR: receipt_failed, tank_failed.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
        ENTITY BrewOrder
          UPDATE FIELDS ( FilledQuantity )
          WITH VALUE #( ( %tky = order-%tky FilledQuantity = key-%param-Quantity ) ).

      APPEND CORRESPONDING #( order ) TO filled.
      APPEND VALUE #( %tky = order-%tky
                      %msg = message( number   = '017'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = order-BrewOrder
                                      v2       = |{ key-%param-Quantity NUMBER = USER } { order-Unit }| ) )
             TO reported-breworder.
    ENDLOOP.

    DATA(changed) = set_phase( order_keys = filled status = lif_brew_order=>status-filled ).
    result = VALUE #( FOR r IN changed ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD check_tank.
    " Two brews overlap when one starts before the other ends and ends after the other starts
    SELECT SINGLE brew_order, planned_start, planned_end FROM zvhb_brewhdr
      WHERE tank           = @order-Tank
        AND brew_uuid     <> @order-BrewOrderUUID
        AND status        <> @lif_brew_order=>status-created
        AND status        <> @lif_brew_order=>status-filled
        AND planned_start <= @order-PlannedEnd
        AND planned_end   >= @order-PlannedStart
      INTO @DATA(conflict).

    IF sy-subrc = 0.
      result = message( number = '009'
                        v1     = order-Tank
                        v2     = conflict-brew_order
                        v3     = |{ conflict-planned_start DATE = ISO }|
                        v4     = |{ conflict-planned_end DATE = ISO }| ).
    ENDIF.
  ENDMETHOD.

  METHOD check_stock.
    DATA needs TYPE tt_needs.

    LOOP AT components INTO DATA(component).
      ASSIGN needs[ material         = component-Material
                    plant            = component-Plant
                    storage_location = component-StorageLocation ] TO FIELD-SYMBOL(<need>).
      IF sy-subrc <> 0.
        INSERT VALUE #( material         = component-Material
                        plant            = component-Plant
                        storage_location = component-StorageLocation
                        unit             = component-Unit ) INTO TABLE needs ASSIGNING <need>.
      ENDIF.
      <need>-quantity += component-Quantity.
    ENDLOOP.

    IF needs IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Material, Plant, StorageLocation, FreeQuantity FROM zvhb_i_availablestock
      FOR ALL ENTRIES IN @needs
      WHERE Material        = @needs-material
        AND Plant           = @needs-plant
        AND StorageLocation = @needs-storage_location
      INTO TABLE @DATA(stock).

    SELECT Material, Plant, StorageLocation, RequiredQuantity FROM zvhb_i_openrequirement
      FOR ALL ENTRIES IN @needs
      WHERE Material        = @needs-material
        AND Plant           = @needs-plant
        AND StorageLocation = @needs-storage_location
      INTO TABLE @DATA(requirements).
    IF with_requirements = abap_false.
      CLEAR requirements.
    ENDIF.

    LOOP AT needs INTO DATA(need).
      DATA(available) = CONV zvhb_quantity(
        VALUE zvhb_quantity( stock[ Material        = need-material
                                    Plant           = need-plant
                                    StorageLocation = need-storage_location ]-FreeQuantity OPTIONAL )
        - VALUE zvhb_quantity( requirements[ Material        = need-material
                                             Plant           = need-plant
                                             StorageLocation = need-storage_location ]-RequiredQuantity OPTIONAL ) ).

      IF need-quantity > available.
        result = message( number = '010'
                          v1     = need-material
                          v2     = need-storage_location
                          v3     = |{ need-quantity NUMBER = USER } { need-unit }|
                          v4     = |{ nmax( val1 = available val2 = 0 ) NUMBER = USER } { need-unit }| ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD issue_components.
    DATA movements TYPE TABLE FOR ACTION IMPORT zvhb_r_materialdocument~postgoodsmovement.

    movements = VALUE #( FOR c IN components INDEX INTO i
                         ( %cid   = |ISSUE{ i }|
                           %param = VALUE #( MovementType    = lif_brew_order=>movement_type-production_issue
                                             Material        = c-Material
                                             Plant           = c-Plant
                                             StorageLocation = c-StorageLocation
                                             Quantity        = c-Quantity
                                             HeaderText      = |Brew order { order-BrewOrder }|
                                             BrewOrder       = order-BrewOrder ) ) ).

    " Inventory picks the batch by FEFO and checks the stock again
    MODIFY ENTITIES OF zvhb_r_materialdocument
      ENTITY MaterialDocument
        EXECUTE postGoodsMovement FROM movements
      FAILED DATA(issue_failed)
      REPORTED DATA(issue_reported).

    IF issue_failed IS NOT INITIAL.
      result = VALUE #( issue_reported-materialdocument[ 1 ]-%msg OPTIONAL ).
    ENDIF.
  ENDMETHOD.

  METHOD set_phase.
    IF order_keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky Status = status ) ).

    " The actual date of the phase that starts now
    CASE status.
      WHEN lif_brew_order=>status-mashing.
        MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
          ENTITY BrewOrder UPDATE FIELDS ( MashingStart )
          WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky MashingStart = today ) ).
      WHEN lif_brew_order=>status-boiling.
        MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
          ENTITY BrewOrder UPDATE FIELDS ( BoilingStart )
          WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky BoilingStart = today ) ).
      WHEN lif_brew_order=>status-fermentation.
        MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
          ENTITY BrewOrder UPDATE FIELDS ( FermentationStart )
          WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky FermentationStart = today ) ).
      WHEN lif_brew_order=>status-maturation.
        MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
          ENTITY BrewOrder UPDATE FIELDS ( MaturationStart )
          WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky MaturationStart = today ) ).
      WHEN lif_brew_order=>status-filled.
        MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
          ENTITY BrewOrder UPDATE FIELDS ( FillingDate )
          WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky FillingDate = today ) ).
    ENDCASE.

    result = read_orders( order_keys ).
  ENDMETHOD.

  METHOD read_orders.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        ALL FIELDS WITH CORRESPONDING #( order_keys )
      RESULT result.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( PlannedStart ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        UPDATE FIELDS ( Status Plant PlannedStart )
        WITH VALUE #( FOR o IN orders
                      ( %tky         = o-%tky
                        Status       = lif_brew_order=>status-created
                        Plant        = lif_brew_order=>defaults-plant
                        PlannedStart = COND #( WHEN o-PlannedStart IS INITIAL
                                               THEN cl_abap_context_info=>get_system_date( ) + 1
                                               ELSE o-PlannedStart ) ) ).
  ENDMETHOD.

  METHOD copyRecipe.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( Material PlannedQuantity PlannedStart ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      ENTITY BrewOrder BY \_Component
        FIELDS ( ComponentUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(old_components).

    " Another beer or quantity replaces the components
    IF old_components IS NOT INITIAL.
      MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
        ENTITY Component
          DELETE FROM VALUE #( FOR old IN old_components ( %tky = old-%tky ) ).
    ENDIF.

    LOOP AT orders INTO DATA(order).
      SELECT SINGLE RecipeUUID, VersionUUID, Version, YieldUnit, YieldQuantity, FermentationDays, MaturationDays
        FROM zvhb_i_beerrecipevh
        WHERE Material = @order-Material
        INTO @DATA(recipe).
      IF sy-subrc <> 0.
        CLEAR recipe.
      ENDIF.

      MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
        ENTITY BrewOrder
          UPDATE FIELDS ( RecipeUUID VersionUUID RecipeVersion Unit FermentationDays MaturationDays PlannedEnd )
          WITH VALUE #( ( %tky             = order-%tky
                          RecipeUUID       = recipe-RecipeUUID
                          VersionUUID      = recipe-VersionUUID
                          RecipeVersion    = recipe-Version
                          Unit             = recipe-YieldUnit
                          FermentationDays = recipe-FermentationDays
                          MaturationDays   = recipe-MaturationDays
                          PlannedEnd       = COND #( WHEN order-PlannedStart IS NOT INITIAL
                                                     THEN order-PlannedStart + recipe-FermentationDays
                                                                             + recipe-MaturationDays ) ) ).

      IF recipe IS INITIAL OR order-PlannedQuantity <= 0 OR recipe-YieldQuantity <= 0.
        CLEAR recipe.
        CONTINUE.
      ENDIF.

      SELECT Material, Unit, Quantity FROM zvhb_r_recipecomponent
        WHERE RecipeUUID  = @recipe-RecipeUUID
          AND VersionUUID = @recipe-VersionUUID
        ORDER BY Material
        INTO TABLE @DATA(recipe_components).

      " FR-PP-01: the recipe is written for one brew of its yield and is scaled to the planned quantity
      DATA(factor) = CONV decfloat34( order-PlannedQuantity ) / recipe-YieldQuantity.

      MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
        ENTITY BrewOrder
          CREATE BY \_Component
          FIELDS ( Item Material Plant StorageLocation Unit Quantity )
          WITH VALUE #( ( %tky    = order-%tky
                          %target = VALUE #( FOR rc IN recipe_components INDEX INTO i
                                             ( %cid            = |COMPONENT{ i }|
                                               %is_draft       = order-%is_draft
                                               Item            = i
                                               Material        = rc-Material
                                               Plant           = lif_brew_order=>defaults-plant
                                               StorageLocation = lif_brew_order=>defaults-raw_material_storage
                                               Unit            = rc-Unit
                                               Quantity        = CONV zvhb_quantity( rc-Quantity * factor ) ) ) ) ).
      CLEAR recipe.
    ENDLOOP.
  ENDMETHOD.

  METHOD setPlannedEnd.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( PlannedStart FermentationDays MaturationDays ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    " The tank is busy from the brew day through fermentation and maturation
    MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        UPDATE FIELDS ( PlannedEnd )
        WITH VALUE #( FOR o IN orders WHERE ( PlannedStart IS NOT INITIAL )
                      ( %tky       = o-%tky
                        PlannedEnd = o-PlannedStart + o-FermentationDays + o-MaturationDays ) ).
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( BrewOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DELETE orders WHERE BrewOrder IS NOT INITIAL.

    LOOP AT orders ASSIGNING FIELD-SYMBOL(<order>).
      TRY.
          <order>-BrewOrder = get_number_range( )->get_next( zif_vhb_number_range=>objects-brew_order ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <order>-%tky %msg = message( number = '019' v1 = exception->get_text( ) ) )
                 TO reported-breworder.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        UPDATE FIELDS ( BrewOrder )
        WITH VALUE #( FOR o IN orders WHERE ( BrewOrder IS NOT INITIAL )
                      ( %tky = o-%tky BrewOrder = o-BrewOrder ) ).
  ENDMETHOD.

  METHOD validateBeer.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'BEER' ) TO reported-breworder.

      " Validations may not read the views of the recipe business object, so the tables are read
      SELECT SINGLE @abap_true FROM zvhb_recipe AS recipe
        INNER JOIN zvhb_rcpver AS version ON version~recipe_uuid = recipe~recipe_uuid
        WHERE recipe~material   = @order-Material
          AND version~is_active = @abap_true
        INTO @DATA(has_recipe).

      DATA(problem) = COND #( WHEN order-Material IS INITIAL THEN message( '001' )
                              WHEN has_recipe = abap_false THEN message( number = '002' v1 = order-Material ) ).
      CLEAR has_recipe.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky              = order-%tky
                        %state_area       = 'BEER'
                        %msg              = problem
                        %element-Material = if_abap_behv=>mk-on ) TO reported-breworder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateQuantity.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( PlannedQuantity Unit Tank ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'QUANTITY' ) TO reported-breworder.

      SELECT SINGLE capacity, capacity_unit FROM zvhb_ftank
        WHERE tank = @order-Tank
        INTO @DATA(tank).

      DATA(problem) = COND #(
        WHEN order-PlannedQuantity <= 0
        THEN message( '003' )
        WHEN tank-capacity IS NOT INITIAL AND order-PlannedQuantity > tank-capacity
        THEN message( number = '007'
                      v1     = |{ order-PlannedQuantity NUMBER = USER } { order-Unit }|
                      v2     = |{ tank-capacity NUMBER = USER } { tank-capacity_unit }|
                      v3     = order-Tank ) ).
      CLEAR tank.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky                     = order-%tky
                        %state_area              = 'QUANTITY'
                        %msg                     = problem
                        %element-PlannedQuantity = if_abap_behv=>mk-on ) TO reported-breworder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateTank.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( Tank Plant ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'TANK' ) TO reported-breworder.

      SELECT SINGLE plant FROM zvhb_ftank
        WHERE tank = @order-Tank
        INTO @DATA(tank_plant).
      DATA(found) = xsdbool( sy-subrc = 0 ).

      DATA(problem) = COND #(
        WHEN order-Tank IS INITIAL THEN message( '004' )
        WHEN found = abap_false THEN message( number = '005' v1 = order-Tank )
        WHEN tank_plant <> order-Plant THEN message( number = '006' v1 = order-Tank v2 = tank_plant v3 = order-Plant ) ).
      CLEAR tank_plant.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky          = order-%tky
                        %state_area   = 'TANK'
                        %msg          = problem
                        %element-Tank = if_abap_behv=>mk-on ) TO reported-breworder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateStart.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder
        FIELDS ( PlannedStart Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'START' ) TO reported-breworder.

      " Only a new order is planned; started brews keep their planned start
      IF order-Status = lif_brew_order=>status-created AND order-PlannedStart < today.
        APPEND VALUE #( %tky = order-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky                  = order-%tky
                        %state_area           = 'START'
                        %msg                  = message( number = '008' v1 = |{ order-PlannedStart DATE = ISO }| )
                        %element-PlannedStart = if_abap_behv=>mk-on ) TO reported-breworder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateComponents.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder BY \_Component
        FIELDS ( Item ) WITH CORRESPONDING #( keys )
      LINK DATA(links).

    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky %state_area = 'COMPONENTS' ) TO reported-breworder.

      IF NOT line_exists( links[ KEY id COMPONENTS source-%tky = key-%tky ] ).
        APPEND VALUE #( %tky = key-%tky ) TO failed-breworder.
        APPEND VALUE #( %tky        = key-%tky
                        %state_area = 'COMPONENTS'
                        %msg        = message( '012' ) ) TO reported-breworder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD message.
    result = new_message( id       = lif_brew_order=>c_msgid
                          number   = number
                          severity = severity
                          v1       = v1
                          v2       = v2
                          v3       = v3
                          v4       = v4 ).
  ENDMETHOD.

  METHOD get_number_range.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.
    result = number_range.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_component DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_brew_order.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Component RESULT result.

    METHODS setComponentDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Component~setComponentDefaults.

    METHODS setUnit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Component~setUnit.

    METHODS validateComponent FOR VALIDATE ON SAVE
      IMPORTING keys FOR Component~validateComponent.
ENDCLASS.


CLASS lhc_component IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY Component
        FIELDS ( BrewOrderUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(components)
      ENTITY Component BY \_BrewOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED failed.

    " Components change with their order until it is released
    result = VALUE #(
      FOR c IN components
      LET status     = VALUE #( orders[ KEY entity COMPONENTS BrewOrderUUID = c-BrewOrderUUID ]-Status OPTIONAL )
          changeable = COND #( WHEN status = lif_brew_order=>status-created OR status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled ) IN
      ( %tky    = c-%tky
        %update = changeable
        %delete = changeable ) ).
  ENDMETHOD.

  METHOD setComponentDefaults.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY Component
        FIELDS ( Item Plant StorageLocation ) WITH CORRESPONDING #( keys )
      RESULT DATA(new_components)
      ENTITY Component BY \_BrewOrder
        FIELDS ( BrewOrderUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY BrewOrder BY \_Component
        FIELDS ( Item ) WITH CORRESPONDING #( orders )
      RESULT DATA(all_components).

    DATA updates TYPE TABLE FOR UPDATE zvhb_r_breworder\\component.

    " Components added by hand get the next number and the raw material storage location
    LOOP AT new_components INTO DATA(component).
      DATA(number) = COND zvhb_brew_comp(
        WHEN component-Item IS NOT INITIAL THEN component-Item
        ELSE REDUCE i( INIT last = 0
                       FOR existing IN all_components USING KEY entity
                       WHERE ( BrewOrderUUID = component-BrewOrderUUID )
                       NEXT last = nmax( val1 = last val2 = CONV i( existing-Item ) ) ) + 1 ).
      ASSIGN all_components[ KEY id COMPONENTS %is_draft     = component-%is_draft
                                               BrewOrderUUID = component-BrewOrderUUID
                                               ComponentUUID = component-ComponentUUID ] TO FIELD-SYMBOL(<numbered>).
      IF sy-subrc = 0.
        <numbered>-Item = number.
      ENDIF.

      APPEND VALUE #( %tky            = component-%tky
                      Item            = number
                      Plant           = lif_brew_order=>defaults-plant
                      StorageLocation = COND #( WHEN component-StorageLocation IS INITIAL
                                                THEN lif_brew_order=>defaults-raw_material_storage
                                                ELSE component-StorageLocation ) ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY Component
        UPDATE FIELDS ( Item Plant StorageLocation ) WITH updates.
  ENDMETHOD.

  METHOD setUnit.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY Component
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(components).

    IF components IS INITIAL.
      RETURN.
    ENDIF.

    SELECT material, base_unit FROM zvhb_mat
      FOR ALL ENTRIES IN @components
      WHERE material = @components-Material
      INTO TABLE @DATA(materials).

    MODIFY ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY Component
        UPDATE FIELDS ( Unit )
        WITH VALUE #( FOR c IN components
                      ( %tky = c-%tky
                        Unit = VALUE #( materials[ material = c-Material ]-base_unit OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD validateComponent.
    READ ENTITIES OF zvhb_r_breworder IN LOCAL MODE
      ENTITY Component
        FIELDS ( Item Material Quantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(components).

    LOOP AT components INTO DATA(component).
      APPEND VALUE #( %tky                          = component-%tky
                      %state_area                   = 'COMPONENT'
                      %path-breworder-%is_draft     = component-%is_draft
                      %path-breworder-BrewOrderUUID = component-BrewOrderUUID ) TO reported-component.

      SELECT SINGLE material_type, is_active FROM zvhb_mat
        WHERE material = @component-Material
        INTO @DATA(material).

      DATA(number) = COND symsgno(
        WHEN material-material_type <> lif_brew_order=>c_raw_material OR material-is_active = abap_false THEN '014'
        WHEN component-Quantity <= 0 THEN '013' ).
      CLEAR material.

      IF number IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = component-%tky ) TO failed-component.
      APPEND VALUE #( %tky                          = component-%tky
                      %state_area                   = 'COMPONENT'
                      %msg                          = new_message( id       = lif_brew_order=>c_msgid
                                                                   number   = number
                                                                   severity = if_abap_behv_message=>severity-error
                                                                   v1       = component-Item
                                                                   v2       = component-Material )
                      %path-breworder-%is_draft     = component-%is_draft
                      %path-breworder-BrewOrderUUID = component-BrewOrderUUID
                      %element-Material             = COND #( WHEN number = '014' THEN if_abap_behv=>mk-on )
                      %element-Quantity             = COND #( WHEN number = '013' THEN if_abap_behv=>mk-on ) )
             TO reported-component.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

