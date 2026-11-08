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

    "! Initial stock entries (movement type 561); each receipt of a batch-managed material creates a new batch
    METHODS create_initial_stock.

    "! Two requisitions (one approved) and two purchase orders: a small one that goes to the supplier
    "! at once and a large one that waits for approval
    METHODS create_procurement.

    METHODS create_requisitions
      IMPORTING
        malt_supplier TYPE zvhb_partner.

    METHODS create_purchase_orders
      IMPORTING
        malt_supplier TYPE zvhb_partner
        hops_supplier TYPE zvhb_partner.

    TYPES:
      BEGIN OF ty_order,
        po_uuid        TYPE sysuuid_x16,
        purchase_order TYPE zvhb_purch_order,
        status         TYPE zvhb_po_status,
      END OF ty_order.

    "! Receives the goods of both orders and enters two supplier invoices: the hops invoice matches
    "! and is posted, the malt invoice charges a higher price and is blocked by the 3-way match
    METHODS create_supplier_invoices
      IMPORTING
        malt_supplier TYPE zvhb_partner
        hops_supplier TYPE zvhb_partner.

    METHODS find_order
      IMPORTING
        supplier      TYPE zvhb_partner
      RETURNING
        VALUE(result) TYPE ty_order.

    "! Approves the order if needed and posts the goods receipt unless goods were already received
    METHODS receive_goods
      IMPORTING
        order         TYPE ty_order
        quantity      TYPE zvhb_quantity
      RETURNING
        VALUE(result) TYPE abap_boolean.

    "! Two Pils brews: 50 hl run from release through mashing and boiling into tank FT-01;
    "! 200 hl in FT-02 stay new, their release fails because the yeast is not enough
    METHODS create_brew_orders.

    "! Runs the open phases of the first brew up to fermentation, each saved on its own
    METHODS run_brew_phases
      IMPORTING
        brew_uuid TYPE sysuuid_x16
        status    TYPE zvhb_brew_status.

    "! Finishes the cleaning of a tank that an earlier run left in CIP, so fermentation can start
    METHODS prepare_tank
      IMPORTING
        tank TYPE zvhb_tank.

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
    create_initial_stock( ).
    create_procurement( ).
    create_brew_orders( ).

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

  METHOD create_initial_stock.
    TYPES tt_movements TYPE STANDARD TABLE OF zvhb_d_goodsmovement WITH EMPTY KEY.

    " Two Pils batches with different best-before dates show FEFO; one yeast batch is already expired
    DATA(movements) = VALUE tt_movements(
      ( Material = 'MALT-PILS'  StorageLocation = 'RM01' Quantity = 5000 ProductionDate = '20261001' )
      ( Material = 'HOPS-HALL'  StorageLocation = 'RM01' Quantity = 300  ProductionDate = '20260915' )
      ( Material = 'YEAST-W34'  StorageLocation = 'RM01' Quantity = 80   ProductionDate = '20261028' )
      ( Material = 'YEAST-W34'  StorageLocation = 'RM01' Quantity = 10   ProductionDate = '20260901' )
      ( Material = 'PILS-BTL05' StorageLocation = 'FG01' Quantity = 4800 ProductionDate = '20260601' )
      ( Material = 'PILS-BTL05' StorageLocation = 'FG01' Quantity = 9600 ProductionDate = '20260915' )
      ( Material = 'CRATE-20'   StorageLocation = 'LE01' Quantity = 2000 ) ).

    SELECT DISTINCT material FROM zvhb_mdocitm
      WHERE movement_type = '561'
      INTO TABLE @DATA(posted).

    LOOP AT posted INTO DATA(found).
      DELETE movements WHERE Material = found-material.
      out->write( |Initial stock of { found-material } exists, skipped| ).
    ENDLOOP.

    IF movements IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_materialdocument
      ENTITY MaterialDocument
        EXECUTE postGoodsMovement
        FROM VALUE #( FOR m IN movements INDEX INTO i
                      ( %cid   = |STOCK{ i }|
                        %param = VALUE #( BASE m
                                          MovementType = '561'
                                          Plant        = c_brewery
                                          HeaderText   = 'Initial stock' ) ) )
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_materialdocument
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Initial stock not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    LOOP AT movements INTO DATA(movement).
      out->write( |Initial stock { movement-Quantity } of { movement-Material } posted| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD create_procurement.
    SELECT partner, partner_name FROM zvhb_bp
      WHERE partner_name = 'Mälzerei Weyer KG' OR partner_name = 'Hopfenhof Hallertau GmbH'
      INTO TABLE @DATA(suppliers).

    DATA(malt_supplier) = VALUE #( suppliers[ partner_name = 'Mälzerei Weyer KG' ]-partner OPTIONAL ).
    DATA(hops_supplier) = VALUE #( suppliers[ partner_name = 'Hopfenhof Hallertau GmbH' ]-partner OPTIONAL ).
    IF malt_supplier IS INITIAL OR hops_supplier IS INITIAL.
      out->write( |Suppliers missing, procurement skipped| ).
      RETURN.
    ENDIF.

    create_requisitions( malt_supplier ).
    create_purchase_orders( malt_supplier = malt_supplier hops_supplier = hops_supplier ).
    create_supplier_invoices( malt_supplier = malt_supplier hops_supplier = hops_supplier ).
  ENDMETHOD.

  METHOD create_requisitions.
    SELECT SINGLE @abap_true FROM zvhb_preq INTO @DATA(exists).
    IF exists = abap_true.
      out->write( |Purchase requisitions exist, skipped| ).
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_purchaserequisition
      ENTITY Requisition
        CREATE FIELDS ( Material Quantity Supplier )
        WITH VALUE #( ( %cid = 'MALT' Material = 'MALT-PILS' Quantity = 20000 Supplier = malt_supplier )
                      ( %cid = 'HOPS' Material = 'HOPS-HALL' Quantity = 100 ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS INITIAL.
      " The malt requisition is approved and can be turned into a purchase order in the app
      MODIFY ENTITIES OF zvhb_r_purchaserequisition
        ENTITY Requisition
          EXECUTE approve FROM VALUE #( FOR m IN mapped-requisition WHERE ( %cid = 'MALT' ) ( %tky = m-%tky ) )
        FAILED failed
        REPORTED reported.
    ENDIF.

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_purchaserequisition
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Purchase requisitions not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    out->write( |Purchase requisitions created: malt (approved) and hops| ).
  ENDMETHOD.

  METHOD create_purchase_orders.
    SELECT SINGLE @abap_true FROM zvhb_pohdr INTO @DATA(exists).
    IF exists = abap_true.
      out->write( |Purchase orders exist, skipped| ).
      RETURN.
    ENDIF.

    " Hops for 900 EUR go out at once; malt for 12,000 EUR needs an approval
    MODIFY ENTITIES OF zvhb_r_purchaseorder
      ENTITY PurchaseOrder
        CREATE FIELDS ( Supplier )
        WITH VALUE #( ( %cid = 'HOPS' Supplier = hops_supplier )
                      ( %cid = 'MALT' Supplier = malt_supplier ) )
        CREATE BY \_Item
        FIELDS ( Material Quantity NetPrice )
        WITH VALUE #( ( %cid_ref = 'HOPS'
                        %target  = VALUE #( ( %cid = 'HOPS-10' Material = 'HOPS-HALL' Quantity = 50 NetPrice = '18.00' ) ) )
                      ( %cid_ref = 'MALT'
                        %target  = VALUE #( ( %cid = 'MALT-10' Material = 'MALT-PILS' Quantity = 25000 NetPrice = '0.48' ) ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS INITIAL.
      MODIFY ENTITIES OF zvhb_r_purchaseorder
        ENTITY PurchaseOrder
          EXECUTE order FROM VALUE #( FOR m IN mapped-purchaseorder ( %tky = m-%tky ) )
        FAILED failed
        REPORTED reported.
    ENDIF.

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_purchaseorder
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Purchase orders not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    out->write( |Purchase orders created: hops (ordered) and malt (awaiting approval)| ).
  ENDMETHOD.

  METHOD create_supplier_invoices.
    SELECT SINGLE @abap_true FROM zvhb_sinvhdr INTO @DATA(exists).
    IF exists = abap_true.
      out->write( |Supplier invoices exist, skipped| ).
      RETURN.
    ENDIF.

    DATA(malt_order) = find_order( malt_supplier ).
    DATA(hops_order) = find_order( hops_supplier ).
    IF malt_order IS INITIAL OR hops_order IS INITIAL.
      out->write( |Purchase orders missing, supplier invoices skipped| ).
      RETURN.
    ENDIF.

    IF receive_goods( order = hops_order quantity = 50 ) = abap_false
       OR receive_goods( order = malt_order quantity = 10000 ) = abap_false.
      RETURN.
    ENDIF.

    " The items are proposed from the received quantities at the order price
    MODIFY ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Invoice
        CREATE FIELDS ( PurchaseOrder InvoiceReference )
        WITH VALUE #( ( %cid = 'HOPS' PurchaseOrder = hops_order-purchase_order InvoiceReference = 'HH-2026-0815' )
                      ( %cid = 'MALT' PurchaseOrder = malt_order-purchase_order InvoiceReference = 'MW-2026-1107' ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS INITIAL.
      " The maltings charges 0.50 EUR per kg instead of the agreed 0.48
      READ ENTITIES OF zvhb_r_supplierinvoice
        ENTITY Invoice BY \_Item
          FIELDS ( NetPrice ) WITH VALUE #( FOR m IN mapped-invoice WHERE ( %cid = 'MALT' ) ( %tky = m-%tky ) )
        RESULT DATA(malt_items).

      MODIFY ENTITIES OF zvhb_r_supplierinvoice
        ENTITY Item
          UPDATE FIELDS ( NetPrice )
          WITH VALUE #( FOR i IN malt_items ( %tky = i-%tky NetPrice = '0.50' ) )
        FAILED failed
        REPORTED reported.
    ENDIF.

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zvhb_r_supplierinvoice
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Supplier invoices not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    " Posting runs the 3-way match on the saved invoices
    MODIFY ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Invoice
        EXECUTE post FROM VALUE #( FOR m IN mapped-invoice ( %tky = m-%tky ) )
      FAILED failed
      REPORTED reported.

    write_messages( reported ).
    COMMIT ENTITIES RESPONSE OF zvhb_r_supplierinvoice
      FAILED commit_failed
      REPORTED commit_reported.

    IF commit_failed IS NOT INITIAL.
      out->write( |Supplier invoices not posted:| ).
      write_messages( commit_reported ).
    ENDIF.
  ENDMETHOD.

  METHOD find_order.
    SELECT po_uuid, purchase_order, status FROM zvhb_pohdr
      WHERE supplier = @supplier
        AND status <> 'REJ'
      ORDER BY purchase_order
      INTO @result
      UP TO 1 ROWS.
    ENDSELECT.
  ENDMETHOD.

  METHOD receive_goods.
    IF order-status = 'WAIT'.
      MODIFY ENTITIES OF zvhb_r_purchaseorder
        ENTITY PurchaseOrder
          EXECUTE approve FROM VALUE #( ( PurchaseOrderUUID = order-po_uuid ) )
        FAILED DATA(failed)
        REPORTED DATA(reported).
    ENDIF.

    SELECT SINGLE item~item_uuid, history~ReceivedQuantity
      FROM zvhb_poitm AS item
        INNER JOIN zvhb_pohdr AS header
          ON header~po_uuid = item~po_uuid
        LEFT OUTER JOIN zvhb_i_purchaseorderhistory AS history
          ON history~PurchaseOrder      = header~purchase_order
          AND history~PurchaseOrderItem = item~item
      WHERE item~po_uuid = @order-po_uuid
      INTO @DATA(item).

    IF failed IS INITIAL AND item-receivedquantity IS INITIAL.
      MODIFY ENTITIES OF zvhb_r_purchaseorder
        ENTITY Item
          EXECUTE receiveGoods
          FROM VALUE #( ( PurchaseOrderUUID = order-po_uuid
                          ItemUUID          = item-item_uuid
                          %param            = VALUE #( Quantity       = quantity
                                                       ProductionDate = cl_abap_context_info=>get_system_date( ) ) ) )
        FAILED failed
        REPORTED reported.
    ENDIF.

    IF failed IS NOT INITIAL.
      write_messages( reported ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    " Saves the material document as well; the order learns about it from the event
    COMMIT ENTITIES RESPONSE OF zvhb_r_purchaseorder
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |Goods receipt for { order-purchase_order } not saved:| ).
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    out->write( COND #( WHEN item-receivedquantity IS INITIAL
                        THEN |Goods of purchase order { order-purchase_order } received|
                        ELSE |Goods of purchase order { order-purchase_order } already received, skipped| ) ).
    result = abap_true.
  ENDMETHOD.

  METHOD create_brew_orders.
    DATA failed TYPE RESPONSE FOR FAILED EARLY zvhb_r_breworder.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zvhb_r_breworder.
    DATA commit_failed TYPE RESPONSE FOR FAILED LATE zvhb_r_breworder.
    DATA commit_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_breworder.

    SELECT SINGLE @abap_true FROM zvhb_brewhdr INTO @DATA(exists).
    IF exists = abap_true.
      out->write( |Brew orders exist, creation skipped| ).
    ELSE.
      DATA(today) = cl_abap_context_info=>get_system_date( ).

      " The components are copied from the active recipe and scaled to the planned quantity
      MODIFY ENTITIES OF zvhb_r_breworder
        ENTITY BrewOrder
          CREATE FIELDS ( Material PlannedQuantity Tank PlannedStart )
          WITH VALUE #( ( %cid = 'BREW1' Material = 'PILS' PlannedQuantity = 50  Tank = 'FT-01' PlannedStart = today )
                        ( %cid = 'BREW2' Material = 'PILS' PlannedQuantity = 200 Tank = 'FT-02' PlannedStart = today + 3 ) )
        FAILED failed
        REPORTED reported.

      IF failed IS NOT INITIAL.
        write_messages( reported ).
        ROLLBACK ENTITIES.
        RETURN.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF zvhb_r_breworder
        FAILED commit_failed
        REPORTED commit_reported.

      IF commit_failed IS NOT INITIAL.
        out->write( |Brew orders not saved:| ).
        write_messages( commit_reported ).
        RETURN.
      ENDIF.
    ENDIF.

    " The first brew runs in FT-01; a second run continues with the phases that are still open
    SELECT SINGLE brew_uuid, status FROM zvhb_brewhdr
      WHERE tank = 'FT-01'
        AND planned_quantity = 50
      INTO @DATA(first).
    IF sy-subrc = 0.
      prepare_tank( 'FT-01' ).
      run_brew_phases( brew_uuid = first-brew_uuid
                       status    = first-status ).
    ENDIF.

    SELECT brew_order, planned_quantity, tank, status FROM zvhb_brewhdr
      ORDER BY brew_order
      INTO TABLE @DATA(orders).
    LOOP AT orders INTO DATA(order).
      out->write( |Brew order { order-brew_order }: { order-planned_quantity NUMBER = USER } hl Pils in { order-tank }, | &&
                  |status { order-status }| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD run_brew_phases.
    DATA failed TYPE RESPONSE FOR FAILED EARLY zvhb_r_breworder.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zvhb_r_breworder.

    DATA(phases) = VALUE string_table( ( `release` ) ( `startMashing` ) ( `startBoiling` ) ( `startFermentation` ) ).
    DATA(phases_done) = SWITCH i( status WHEN 'NEW'  THEN 0
                                         WHEN 'REL'  THEN 1
                                         WHEN 'MASH' THEN 2
                                         WHEN 'BOIL' THEN 3
                                         ELSE lines( phases ) ).

    " Each phase is saved on its own, as the brewer would do it in the app
    LOOP AT phases INTO DATA(phase) FROM phases_done + 1.
      CASE phase.
        WHEN `release`.
          MODIFY ENTITIES OF zvhb_r_breworder ENTITY BrewOrder
            EXECUTE release FROM VALUE #( ( BrewOrderUUID = brew_uuid ) ) FAILED failed REPORTED reported.
        WHEN `startMashing`.
          MODIFY ENTITIES OF zvhb_r_breworder ENTITY BrewOrder
            EXECUTE startMashing FROM VALUE #( ( BrewOrderUUID = brew_uuid ) ) FAILED failed REPORTED reported.
        WHEN `startBoiling`.
          MODIFY ENTITIES OF zvhb_r_breworder ENTITY BrewOrder
            EXECUTE startBoiling FROM VALUE #( ( BrewOrderUUID = brew_uuid ) ) FAILED failed REPORTED reported.
        WHEN `startFermentation`.
          MODIFY ENTITIES OF zvhb_r_breworder ENTITY BrewOrder
            EXECUTE startFermentation FROM VALUE #( ( BrewOrderUUID = brew_uuid ) ) FAILED failed REPORTED reported.
      ENDCASE.

      write_messages( reported ).
      IF failed IS NOT INITIAL.
        ROLLBACK ENTITIES.
        RETURN.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF zvhb_r_breworder
        FAILED DATA(commit_failed)
        REPORTED DATA(commit_reported).

      IF commit_failed IS NOT INITIAL.
        out->write( |Phase { phase } not saved:| ).
        write_messages( commit_reported ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD prepare_tank.
    SELECT SINGLE status FROM zvhb_ftank
      WHERE tank = @tank
      INTO @DATA(status).
    IF status <> 'CIP'.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_fermentationtank
      ENTITY Tank
        EXECUTE finishCleaning FROM VALUE #( ( Tank = tank ) )
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
      write_messages( commit_reported ).
      RETURN.
    ENDIF.

    out->write( |Cleaning of tank { tank } finished| ).
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
