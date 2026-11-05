*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_recipe DEFINITION DEFERRED FOR TESTING.

CLASS lhc_recipe DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_recipe.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.
    CONSTANTS c_finished_product TYPE zvhb_material_type VALUE 'FERT'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Recipe RESULT result.

    METHODS validateMaterial FOR VALIDATE ON SAVE
      IMPORTING keys FOR Recipe~validateMaterial.
ENDCLASS.


CLASS lhc_recipe IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Authorization by plant follows in stage v1.0 together with authorization object ZVHB_PLANT
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD validateMaterial.
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Recipe
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(recipes).

    IF recipes IS INITIAL.
      RETURN.
    ENDIF.

    SELECT material, material_type, is_active FROM zvhb_mat
      FOR ALL ENTRIES IN @recipes
      WHERE material = @recipes-Material
      INTO TABLE @DATA(materials).

    " Each beer has exactly one recipe, the versions live inside it
    SELECT recipe_uuid, material FROM zvhb_recipe
      FOR ALL ENTRIES IN @recipes
      WHERE material = @recipes-Material
      INTO TABLE @DATA(saved_recipes).

    LOOP AT recipes INTO DATA(recipe).
      APPEND VALUE #( %tky = recipe-%tky %state_area = 'MATERIAL' ) TO reported-recipe.

      DATA(material) = VALUE #( materials[ material = recipe-Material ] OPTIONAL ).
      DATA(other_recipes) = REDUCE i( INIT n = 0
                                      FOR saved IN saved_recipes
                                      WHERE ( material = recipe-Material AND recipe_uuid <> recipe-RecipeUUID )
                                      NEXT n = n + 1 ).

      DATA(message) = COND #(
        WHEN material IS INITIAL
        THEN new_message( id = c_msgid number = '021' severity = if_abap_behv_message=>severity-error v1 = recipe-Material )
        WHEN material-is_active = abap_false
        THEN new_message( id = c_msgid number = '022' severity = if_abap_behv_message=>severity-error v1 = recipe-Material )
        WHEN material-material_type <> c_finished_product
        THEN new_message( id = c_msgid number = '032' severity = if_abap_behv_message=>severity-error v1 = recipe-Material )
        WHEN other_recipes > 0
        THEN new_message( id = c_msgid number = '033' severity = if_abap_behv_message=>severity-error v1 = recipe-Material ) ).

      IF message IS BOUND.
        APPEND VALUE #( %tky = recipe-%tky ) TO failed-recipe.
        APPEND VALUE #( %tky              = recipe-%tky
                        %state_area       = 'MATERIAL'
                        %msg              = message
                        %element-Material = if_abap_behv=>mk-on ) TO reported-recipe.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_version DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_recipe.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.
    CONSTANTS c_hectoliter TYPE zvhb_unit VALUE 'HL'.

    CONSTANTS:
      "! Plausible limits for a brewing recipe
      BEGIN OF limits,
        min_gravity TYPE zvhb_plato VALUE '1.0',
        max_gravity TYPE zvhb_plato VALUE '30.0',
        max_alcohol TYPE zvhb_alcohol VALUE '15.00',
      END OF limits.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Version~setDefaults.

    METHODS validateVersion FOR VALIDATE ON SAVE
      IMPORTING keys FOR Version~validateVersion.

    METHODS validateSingleActive FOR VALIDATE ON SAVE
      IMPORTING keys FOR Version~validateSingleActive.

    METHODS validateComponents FOR VALIDATE ON SAVE
      IMPORTING keys FOR Version~validateComponents.
ENDCLASS.


CLASS lhc_version IMPLEMENTATION.

  METHOD setDefaults.
    DATA updates TYPE TABLE FOR UPDATE zvhb_r_recipe\\version.

    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Version
        FIELDS ( Version YieldUnit ) WITH CORRESPONDING #( keys )
      RESULT DATA(new_versions)
      ENTITY Version BY \_Recipe
        FIELDS ( RecipeUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(recipes).

    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Recipe BY \_Version
        FIELDS ( Version ) WITH CORRESPONDING #( recipes )
      RESULT DATA(all_versions).

    " New versions are numbered after the highest version of the same recipe
    LOOP AT new_versions INTO DATA(version).
      DATA(number) = version-Version.

      IF number IS INITIAL.
        number = REDUCE zvhb_recipe_version( INIT last = CONV zvhb_recipe_version( 0 )
                                             FOR existing IN all_versions USING KEY entity
                                             WHERE ( RecipeUUID = version-RecipeUUID )
                                             NEXT last = COND #( WHEN existing-Version > last
                                                                 THEN existing-Version
                                                                 ELSE last ) ) + 1.

        ASSIGN all_versions[ KEY id COMPONENTS %is_draft   = version-%is_draft
                                               RecipeUUID  = version-RecipeUUID
                                               VersionUUID = version-VersionUUID ] TO FIELD-SYMBOL(<numbered>).
        IF sy-subrc = 0.
          <numbered>-Version = number.
        ENDIF.
      ENDIF.

      APPEND VALUE #( %tky      = version-%tky
                      Version   = number
                      YieldUnit = COND #( WHEN version-YieldUnit IS INITIAL THEN c_hectoliter ELSE version-YieldUnit ) )
             TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Version
        UPDATE FIELDS ( Version YieldUnit ) WITH updates.
  ENDMETHOD.

  METHOD validateVersion.
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Version
        FIELDS ( Version YieldQuantity TargetGravity TargetAlcohol FermentationDays MaturationDays )
        WITH CORRESPONDING #( keys )
      RESULT DATA(versions).

    LOOP AT versions INTO DATA(version).
      APPEND VALUE #( %tky                    = version-%tky
                      %state_area             = 'VERSION_DATA'
                      %path-recipe-%is_draft  = version-%is_draft
                      %path-recipe-RecipeUUID = version-RecipeUUID ) TO reported-version.

      DATA(msgno) = COND symsgno(
        WHEN version-YieldQuantity <= 0 THEN '036'
        WHEN version-TargetGravity < limits-min_gravity OR version-TargetGravity > limits-max_gravity THEN '037'
        WHEN version-TargetAlcohol < 0 OR version-TargetAlcohol > limits-max_alcohol THEN '038'
        WHEN version-FermentationDays < 1 THEN '039'
        WHEN version-MaturationDays < 0 THEN '040' ).

      IF msgno IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = version-%tky ) TO failed-version.
      APPEND VALUE #( %tky                      = version-%tky
                      %state_area               = 'VERSION_DATA'
                      %msg                      = new_message( id       = c_msgid
                                                               number   = msgno
                                                               severity = if_abap_behv_message=>severity-error
                                                               v1       = version-Version )
                      %path-recipe-%is_draft    = version-%is_draft
                      %path-recipe-RecipeUUID   = version-RecipeUUID
                      %element-YieldQuantity    = COND #( WHEN msgno = '036' THEN if_abap_behv=>mk-on )
                      %element-TargetGravity    = COND #( WHEN msgno = '037' THEN if_abap_behv=>mk-on )
                      %element-TargetAlcohol    = COND #( WHEN msgno = '038' THEN if_abap_behv=>mk-on )
                      %element-FermentationDays = COND #( WHEN msgno = '039' THEN if_abap_behv=>mk-on )
                      %element-MaturationDays   = COND #( WHEN msgno = '040' THEN if_abap_behv=>mk-on ) )
             TO reported-version.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateSingleActive.
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Version
        FIELDS ( IsActive ) WITH CORRESPONDING #( keys )
      RESULT DATA(versions)
      ENTITY Version BY \_Recipe
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(recipes).

    " The check needs all versions of the recipe, not only the changed ones
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Recipe BY \_Version
        FIELDS ( IsActive ) WITH CORRESPONDING #( recipes )
      RESULT DATA(all_versions).

    LOOP AT versions INTO DATA(version).
      APPEND VALUE #( %tky                    = version-%tky
                      %state_area             = 'ACTIVE_VERSION'
                      %path-recipe-%is_draft  = version-%is_draft
                      %path-recipe-RecipeUUID = version-RecipeUUID ) TO reported-version.

      IF version-IsActive = abap_false.
        CONTINUE.
      ENDIF.

      DATA(active_versions) = REDUCE i( INIT n = 0
                                        FOR sibling IN all_versions USING KEY entity
                                        WHERE ( RecipeUUID = version-RecipeUUID AND IsActive = abap_true )
                                        NEXT n = n + 1 ).
      IF active_versions <= 1.
        CONTINUE.
      ENDIF.

      DATA(material) = VALUE #( recipes[ KEY id COMPONENTS %is_draft  = version-%is_draft
                                                           RecipeUUID = version-RecipeUUID ]-Material OPTIONAL ).

      APPEND VALUE #( %tky = version-%tky ) TO failed-version.
      APPEND VALUE #( %tky                    = version-%tky
                      %state_area             = 'ACTIVE_VERSION'
                      %msg                    = new_message( id       = c_msgid
                                                             number   = '034'
                                                             severity = if_abap_behv_message=>severity-error
                                                             v1       = material
                                                             v2       = active_versions )
                      %path-recipe-%is_draft  = version-%is_draft
                      %path-recipe-RecipeUUID = version-RecipeUUID
                      %element-IsActive       = if_abap_behv=>mk-on ) TO reported-version.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateComponents.
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Version
        FIELDS ( Version IsActive ) WITH CORRESPONDING #( keys )
      RESULT DATA(versions)
      ENTITY Version BY \_Component
        FIELDS ( Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(components).

    LOOP AT versions INTO DATA(version).
      APPEND VALUE #( %tky                    = version-%tky
                      %state_area             = 'COMPONENTS'
                      %path-recipe-%is_draft  = version-%is_draft
                      %path-recipe-RecipeUUID = version-RecipeUUID ) TO reported-version.

      IF version-IsActive = abap_false
         OR line_exists( components[ KEY id COMPONENTS %is_draft   = version-%is_draft
                                                       RecipeUUID  = version-RecipeUUID
                                                       VersionUUID = version-VersionUUID ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = version-%tky ) TO failed-version.
      APPEND VALUE #( %tky                    = version-%tky
                      %state_area             = 'COMPONENTS'
                      %msg                    = new_message( id       = c_msgid
                                                             number   = '035'
                                                             severity = if_abap_behv_message=>severity-error
                                                             v1       = version-Version )
                      %path-recipe-%is_draft  = version-%is_draft
                      %path-recipe-RecipeUUID = version-RecipeUUID
                      %element-IsActive       = if_abap_behv=>mk-on ) TO reported-version.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_component DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_recipe.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.
    CONSTANTS c_raw_material TYPE zvhb_material_type VALUE 'ROH'.

    METHODS setUnit FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Component~setUnit.

    METHODS validateComponent FOR VALIDATE ON SAVE
      IMPORTING keys FOR Component~validateComponent.
ENDCLASS.


CLASS lhc_component IMPLEMENTATION.

  METHOD setUnit.
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
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

    MODIFY ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Component
        UPDATE FIELDS ( Unit )
        WITH VALUE #( FOR component IN components
                      ( %tky = component-%tky
                        Unit = VALUE #( materials[ material = component-Material ]-base_unit OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD validateComponent.
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Component
        FIELDS ( Material Quantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(components)
      ENTITY Component BY \_Version
        FIELDS ( Version ) WITH CORRESPONDING #( keys )
      RESULT DATA(versions).

    IF components IS INITIAL.
      RETURN.
    ENDIF.

    " Duplicates are found among all components of the version
    READ ENTITIES OF zvhb_r_recipe IN LOCAL MODE
      ENTITY Version BY \_Component
        FIELDS ( Material ) WITH CORRESPONDING #( versions )
      RESULT DATA(siblings).

    SELECT material, material_type, is_active FROM zvhb_mat
      FOR ALL ENTRIES IN @components
      WHERE material = @components-Material
      INTO TABLE @DATA(materials).

    LOOP AT components INTO DATA(component).
      APPEND VALUE #( %tky                      = component-%tky
                      %state_area               = 'COMPONENT'
                      %path-recipe-%is_draft    = component-%is_draft
                      %path-recipe-RecipeUUID   = component-RecipeUUID
                      %path-version-%is_draft   = component-%is_draft
                      %path-version-RecipeUUID  = component-RecipeUUID
                      %path-version-VersionUUID = component-VersionUUID ) TO reported-component.

      DATA(material) = VALUE #( materials[ material = component-Material ] OPTIONAL ).
      DATA(version_number) = VALUE #( versions[ KEY id COMPONENTS %is_draft   = component-%is_draft
                                                                  RecipeUUID  = component-RecipeUUID
                                                                  VersionUUID = component-VersionUUID ]-Version OPTIONAL ).
      DATA(same_material) = REDUCE i( INIT n = 0
                                      FOR sibling IN siblings
                                      WHERE ( VersionUUID = component-VersionUUID AND Material = component-Material )
                                      NEXT n = n + 1 ).

      DATA(msgno) = COND symsgno(
        WHEN material IS INITIAL THEN '021'
        WHEN material-is_active = abap_false THEN '022'
        WHEN material-material_type <> c_raw_material THEN '041'
        WHEN component-Quantity <= 0 THEN '042'
        WHEN same_material > 1 THEN '043' ).

      IF msgno IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = component-%tky ) TO failed-component.
      APPEND VALUE #( %tky                      = component-%tky
                      %state_area               = 'COMPONENT'
                      %msg                      = new_message( id       = c_msgid
                                                               number   = msgno
                                                               severity = if_abap_behv_message=>severity-error
                                                               v1       = component-Material
                                                               v2       = version_number )
                      %path-recipe-%is_draft    = component-%is_draft
                      %path-recipe-RecipeUUID   = component-RecipeUUID
                      %path-version-%is_draft   = component-%is_draft
                      %path-version-RecipeUUID  = component-RecipeUUID
                      %path-version-VersionUUID = component-VersionUUID
                      %element-Material         = COND #( WHEN msgno <> '042' THEN if_abap_behv=>mk-on )
                      %element-Quantity         = COND #( WHEN msgno = '042' THEN if_abap_behv=>mk-on ) )
             TO reported-component.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

