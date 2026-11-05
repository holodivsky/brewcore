"! Fills the system with the demo master data of Nordhopf Brauerei: materials, business partners,
"! prices, the Pils recipe and the fermentation tanks. Run with F9 after ZCL_VHB_SETUP_NUMBER_RANGES.
"! Safe to run again: records that already exist are skipped. All records go through the RAP
"! business objects, so the same validations apply as in the Fiori apps.
CLASS zcl_vhb_demo_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_material,
        material      TYPE zvhb_material,
        material_type TYPE zvhb_material_type,
        base_unit     TYPE zvhb_unit,
        shelf_life    TYPE int2,
        text_en       TYPE zvhb_description,
        text_de       TYPE zvhb_description,
        min_stock     TYPE zvhb_quantity,
        reorder_point TYPE zvhb_quantity,
      END OF ty_material,
      tt_materials TYPE STANDARD TABLE OF ty_material WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_partner,
        name          TYPE c LENGTH 80,
        street        TYPE c LENGTH 60,
        postal_code   TYPE c LENGTH 10,
        city          TYPE c LENGTH 40,
        payment_terms TYPE zvhb_pay_terms,
        credit_limit  TYPE zvhb_amount,
        role          TYPE zvhb_bp_role,
      END OF ty_partner,
      tt_partners TYPE STANDARD TABLE OF ty_partner WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_price,
        cid            TYPE abp_behv_cid,
        condition_type TYPE zvhb_cond_type,
        material       TYPE zvhb_material,
        channel        TYPE zvhb_distr_channel,
        amount         TYPE zvhb_amount,
      END OF ty_price,
      tt_prices TYPE STANDARD TABLE OF ty_price WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_tank,
        tank        TYPE zvhb_tank,
        description TYPE zvhb_description,
        capacity    TYPE zvhb_quantity,
      END OF ty_tank,
      tt_tanks TYPE STANDARD TABLE OF ty_tank WITH EMPTY KEY.

    CONSTANTS c_currency TYPE zvhb_currency VALUE 'EUR'.
    CONSTANTS c_brewery TYPE zvhb_plant VALUE 'BR01'.

    DATA out TYPE REF TO if_oo_adt_classrun_out.

    METHODS create_materials.
    METHODS create_partners.
    METHODS create_prices.
    METHODS create_recipes.
    METHODS create_tanks.

    "! Writes the messages of a RAP response structure (REPORTED) to the console
    METHODS write_messages
      IMPORTING
        reported TYPE data.
ENDCLASS.



CLASS zcl_vhb_demo_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    me->out = out.
    out->write( |BrewCore demo data| ).

    " Order matters: recipes and prices need the materials
    create_materials( ).
    create_partners( ).
    create_prices( ).
    create_recipes( ).
    create_tanks( ).

    out->write( |Done| ).
  ENDMETHOD.

  METHOD create_materials.
    DATA(materials) = VALUE tt_materials(
      ( material = 'PILS-BTL05' material_type = 'FERT' base_unit = 'ST' shelf_life = 180
        text_en = 'Pils 0.5 l bottle' text_de = 'Pils 0,5 l Flasche' )
      ( material = 'CRATE-20' material_type = 'LEER' base_unit = 'ST' shelf_life = 0
        text_en = 'Beer crate 20 x 0.5 l' text_de = 'Bierkasten 20 x 0,5 l' )
      ( material = 'PILS' material_type = 'FERT' base_unit = 'HL' shelf_life = 90
        text_en = 'Pilsner bulk beer' text_de = 'Pils (Tankbier)' )
      ( material = 'MALT-PILS' material_type = 'ROH' base_unit = 'KG' shelf_life = 365
        text_en = 'Pilsner malt' text_de = 'Pilsner Malz' min_stock = 2000 reorder_point = 5000 )
      ( material = 'HOPS-HALL' material_type = 'ROH' base_unit = 'KG' shelf_life = 730
        text_en = 'Hallertau hop pellets' text_de = 'Hallertauer Hopfenpellets' min_stock = 50 reorder_point = 150 )
      ( material = 'YEAST-W34' material_type = 'ROH' base_unit = 'KG' shelf_life = 30
        text_en = 'Lager yeast W-34/70' text_de = 'Untergärige Hefe W-34/70' min_stock = 20 reorder_point = 60 ) ).

    SELECT material FROM zvhb_mat
      FOR ALL ENTRIES IN @materials
      WHERE material = @materials-material
      INTO TABLE @DATA(existing).

    LOOP AT existing INTO DATA(found).
      DELETE materials WHERE material = found-material.
      out->write( |Material { found-material } exists, skipped| ).
    ENDLOOP.

    IF materials IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_material
      ENTITY Material
        CREATE FIELDS ( Material MaterialType BaseUnit IsBatchManaged ShelfLifeDays )
        WITH VALUE #( FOR m IN materials
                      ( %cid           = m-material
                        Material       = m-material
                        MaterialType   = m-material_type
                        BaseUnit       = m-base_unit
                        IsBatchManaged = xsdbool( m-material_type = 'FERT' OR m-material_type = 'ROH' )
                        ShelfLifeDays  = m-shelf_life ) )
        CREATE BY \_Text
        FIELDS ( Language Description )
        WITH VALUE #( FOR m IN materials
                      ( %cid_ref = m-material
                        %target  = VALUE #( ( %cid = |{ m-material }-E| Language = 'E' Description = m-text_en )
                                            ( %cid = |{ m-material }-D| Language = 'D' Description = m-text_de ) ) ) )
        CREATE BY \_Plant
        FIELDS ( Plant MinStock ReorderPoint )
        WITH VALUE #( FOR m IN materials WHERE ( reorder_point > 0 )
                      ( %cid_ref = m-material
                        %target  = VALUE #( ( %cid         = |{ m-material }-{ c_brewery }|
                                              Plant        = c_brewery
                                              MinStock     = m-min_stock
                                              ReorderPoint = m-reorder_point ) ) ) )
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_material
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Materials not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    LOOP AT materials INTO DATA(material).
      out->write( |Material { material-material } created| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD create_partners.
    DATA(partners) = VALUE tt_partners(
      ( name = 'Hopfenhof Hallertau GmbH' street = 'Hopfenstraße 12' postal_code = '84048' city = 'Mainburg'
        payment_terms = 'NT30' credit_limit = 0 role = 'SU' )
      ( name = 'Mälzerei Weyer KG' street = 'Industriestraße 7' postal_code = '96052' city = 'Bamberg'
        payment_terms = 'NT30' credit_limit = 0 role = 'SU' )
      ( name = 'Gasthaus Zum Kupferkessel' street = 'Marktplatz 3' postal_code = '93047' city = 'Regensburg'
        payment_terms = 'NT14' credit_limit = 15000 role = 'CU' )
      ( name = 'Getränke Huber GmbH' street = 'Am Großmarkt 21' postal_code = '81369' city = 'München'
        payment_terms = 'NT30' credit_limit = 50000 role = 'CU' ) ).

    SELECT partner_name FROM zvhb_bp
      FOR ALL ENTRIES IN @partners
      WHERE partner_name = @partners-name
      INTO TABLE @DATA(existing).

    LOOP AT existing INTO DATA(found).
      DELETE partners WHERE name = found-partner_name.
      out->write( |Partner { found-partner_name } exists, skipped| ).
    ENDLOOP.

    IF partners IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_businesspartner
      ENTITY Partner
        CREATE FIELDS ( PartnerName Street PostalCode City Country Currency PaymentTerms CreditLimit )
        WITH VALUE #( FOR p IN partners INDEX INTO i
                      ( %cid         = |P{ i }|
                        PartnerName  = p-name
                        Street       = p-street
                        PostalCode   = p-postal_code
                        City         = p-city
                        Country      = 'DE'
                        Currency     = c_currency
                        PaymentTerms = p-payment_terms
                        CreditLimit  = p-credit_limit ) )
        CREATE BY \_Role
        FIELDS ( PartnerRole )
        WITH VALUE #( FOR p IN partners INDEX INTO i
                      ( %cid_ref = |P{ i }|
                        %target  = VALUE #( ( %cid = |P{ i }-{ p-role }| PartnerRole = p-role ) ) ) )
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_businesspartner
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Business partners not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    LOOP AT partners INTO DATA(partner).
      out->write( |Partner { partner-name } created| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD create_prices.
    DATA(prices) = VALUE tt_prices(
      ( cid = 'PILS-GA' condition_type = 'BASE' material = 'PILS-BTL05' channel = 'GA' amount = '0.89' )
      ( cid = 'PILS-GF' condition_type = 'BASE' material = 'PILS-BTL05' channel = 'GF' amount = '0.79' )
      ( cid = 'CRATE'   condition_type = 'DEPO' material = 'CRATE-20'   channel = ''   amount = '3.10' ) ).

    SELECT condition_type, material, distr_channel FROM zvhb_price
      FOR ALL ENTRIES IN @prices
      WHERE condition_type = @prices-condition_type
        AND material       = @prices-material
        AND distr_channel  = @prices-channel
      INTO TABLE @DATA(existing).

    LOOP AT existing INTO DATA(found).
      DELETE prices WHERE condition_type = found-condition_type
                      AND material       = found-material
                      AND channel        = found-distr_channel.
      out->write( |Price { found-condition_type } { found-material } { found-distr_channel } exists, skipped| ).
    ENDLOOP.

    IF prices IS INITIAL.
      RETURN.
    ENDIF.

    " Quantity discounts for gastronomy: 5 % from 1,000 bottles, 8 % from 5,000
    DATA scales TYPE TABLE FOR CREATE zvhb_r_pricecondition\\price\_scale.
    IF line_exists( prices[ cid = 'PILS-GA' ] ).
      scales = VALUE #( ( %cid_ref = 'PILS-GA'
                          %target  = VALUE #( ( %cid = 'PILS-GA-1000' FromQuantity = 1000 DiscountPercent = 5 )
                                              ( %cid = 'PILS-GA-5000' FromQuantity = 5000 DiscountPercent = 8 ) ) ) ).
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_pricecondition
      ENTITY Price
        CREATE FIELDS ( ConditionType Material DistributionChannel ValidFrom ValidTo Amount Currency )
        WITH VALUE #( FOR p IN prices
                      ( %cid                = p-cid
                        ConditionType       = p-condition_type
                        Material            = p-material
                        DistributionChannel = p-channel
                        ValidFrom           = cl_abap_context_info=>get_system_date( )
                        ValidTo             = '99991231'
                        Amount              = p-amount
                        Currency            = c_currency ) )
        CREATE BY \_Scale
        FIELDS ( FromQuantity DiscountPercent ) WITH scales
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_pricecondition
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Prices not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    LOOP AT prices INTO DATA(price).
      out->write( |Price { price-condition_type } { price-material } { price-channel } created| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD create_recipes.
    SELECT SINGLE @abap_true FROM zvhb_recipe
      WHERE material = 'PILS'
      INTO @DATA(exists).

    IF exists = abap_true.
      out->write( |Recipe PILS exists, skipped| ).
      RETURN.
    ENDIF.

    " Version 001 is the old recipe, version 002 with a little more hops is the active one
    MODIFY ENTITIES OF zvhb_r_recipe
      ENTITY Recipe
        CREATE FIELDS ( Material )
        WITH VALUE #( ( %cid = 'PILS' Material = 'PILS' ) )
        CREATE BY \_Version
        FIELDS ( IsActive YieldQuantity TargetGravity TargetAlcohol FermentationDays MaturationDays )
        WITH VALUE #( ( %cid_ref = 'PILS'
                        %target  = VALUE #( ( %cid             = 'PILS-V1'
                                              IsActive         = abap_false
                                              YieldQuantity    = 50
                                              TargetGravity    = '11.3'
                                              TargetAlcohol    = '4.80'
                                              FermentationDays = 7
                                              MaturationDays   = 21 )
                                            ( %cid             = 'PILS-V2'
                                              IsActive         = abap_true
                                              YieldQuantity    = 50
                                              TargetGravity    = '11.5'
                                              TargetAlcohol    = '4.90'
                                              FermentationDays = 7
                                              MaturationDays   = 21 ) ) ) )
      ENTITY Version
        CREATE BY \_Component
        FIELDS ( Material Quantity )
        WITH VALUE #( ( %cid_ref = 'PILS-V1'
                        %target  = VALUE #( ( %cid = 'V1-MALT'  Material = 'MALT-PILS' Quantity = 900 )
                                            ( %cid = 'V1-HOPS'  Material = 'HOPS-HALL' Quantity = 10 )
                                            ( %cid = 'V1-YEAST' Material = 'YEAST-W34' Quantity = 30 ) ) )
                      ( %cid_ref = 'PILS-V2'
                        %target  = VALUE #( ( %cid = 'V2-MALT'  Material = 'MALT-PILS' Quantity = 900 )
                                            ( %cid = 'V2-HOPS'  Material = 'HOPS-HALL' Quantity = 12 )
                                            ( %cid = 'V2-YEAST' Material = 'YEAST-W34' Quantity = 30 ) ) ) )
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_recipe
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Recipe not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    out->write( |Recipe PILS created with versions 001 and 002 (active)| ).
  ENDMETHOD.

  METHOD create_tanks.
    DATA(tanks) = VALUE tt_tanks(
      ( tank = 'FT-01' description = 'Fermentation tank 1' capacity = 400 )
      ( tank = 'FT-02' description = 'Fermentation tank 2' capacity = 400 )
      ( tank = 'FT-03' description = 'Fermentation tank 3' capacity = 600 )
      ( tank = 'FT-04' description = 'Fermentation tank 4' capacity = 600 ) ).

    SELECT tank FROM zvhb_ftank
      FOR ALL ENTRIES IN @tanks
      WHERE tank = @tanks-tank
      INTO TABLE @DATA(existing).

    LOOP AT existing INTO DATA(found).
      DELETE tanks WHERE tank = found-tank.
      out->write( |Tank { found-tank } exists, skipped| ).
    ENDLOOP.

    IF tanks IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_fermentationtank
      ENTITY Tank
        CREATE FIELDS ( Tank Plant Description Capacity )
        WITH VALUE #( FOR t IN tanks
                      ( %cid        = t-tank
                        Tank        = t-tank
                        Plant       = c_brewery
                        Description = t-description
                        Capacity    = t-capacity ) )
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_fermentationtank
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Tanks not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    LOOP AT tanks INTO DATA(tank).
      out->write( |Tank { tank-tank } created| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD write_messages.
    FIELD-SYMBOLS <entity_messages> TYPE ANY TABLE.
    FIELD-SYMBOLS <message> TYPE REF TO if_abap_behv_message.

    " REPORTED has one table per entity, each line carries the message in %msg
    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE reported TO <entity_messages>.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.

      LOOP AT <entity_messages> ASSIGNING FIELD-SYMBOL(<line>).
        ASSIGN COMPONENT '%MSG' OF STRUCTURE <line> TO <message>.
        IF sy-subrc = 0 AND <message> IS BOUND.
          out->write( <message>->if_message~get_text( ) ).
        ENDIF.
      ENDLOOP.
    ENDDO.
  ENDMETHOD.

ENDCLASS.
