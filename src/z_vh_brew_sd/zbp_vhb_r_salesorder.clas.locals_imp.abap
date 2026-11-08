*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_sales_order DEFINITION DEFERRED FOR TESTING.

"! Status values, item categories and defaults shared by the handlers of the sales order
INTERFACE lif_sales.
  CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_SD'.

  CONSTANTS:
    "! Sales order status values of domain ZVHB_SO_STATUS
    BEGIN OF status,
      open           TYPE zvhb_so_status VALUE 'OPEN',
      credit_blocked TYPE zvhb_so_status VALUE 'CRBL',
      delivered      TYPE zvhb_so_status VALUE 'DLVD',
      invoiced       TYPE zvhb_so_status VALUE 'BILL',
    END OF status.

  CONSTANTS:
    "! Item categories of domain ZVHB_ITEM_CAT
    BEGIN OF item_category,
      product TYPE zvhb_item_cat VALUE 'PROD',
      deposit TYPE zvhb_item_cat VALUE 'DEPO',
    END OF item_category.

  CONSTANTS:
    BEGIN OF condition_type,
      base_price TYPE zvhb_cond_type VALUE 'BASE',
      deposit    TYPE zvhb_cond_type VALUE 'DEPO',
    END OF condition_type.

  CONSTANTS:
    BEGIN OF defaults,
      plant           TYPE zvhb_plant VALUE 'BR01',
      beer_storage    TYPE zvhb_storage_loc VALUE 'FG01',
      empties_storage TYPE zvhb_storage_loc VALUE 'LE01',
      currency        TYPE zvhb_currency VALUE 'EUR',
      lead_time_days  TYPE i VALUE 2,
    END OF defaults.

  CONSTANTS c_finished_product TYPE zvhb_material_type VALUE 'FERT'.
  CONSTANTS c_customer TYPE zvhb_bp_role VALUE 'CU'.
ENDINTERFACE.


"! FR-SD-01 and FR-SD-02: prices, confirmed quantities and deposit items of one order. Used by the item
"! determinations and when the distribution channel of the order changes.
CLASS lcl_pricing DEFINITION FINAL FRIENDS ltc_sales_order.
  PUBLIC SECTION.
    TYPES ty_order TYPE STRUCTURE FOR READ RESULT zvhb_r_salesorder\\salesorder.
    TYPES tt_orders TYPE TABLE FOR READ RESULT zvhb_r_salesorder\\salesorder.
    TYPES tt_items TYPE TABLE FOR READ RESULT zvhb_r_salesorder\\item.
    TYPES ty_item TYPE STRUCTURE FOR READ RESULT zvhb_r_salesorder\\item.

    TYPES:
      BEGIN OF ty_price,
        unit             TYPE zvhb_unit,
        base_price       TYPE zvhb_amount,
        discount_percent TYPE zvhb_percent,
        net_amount       TYPE zvhb_amount,
      END OF ty_price.

    TYPES:
      BEGIN OF ty_packaging,
        material TYPE zvhb_material,
        unit     TYPE zvhb_unit,
        units    TYPE i,
        rate     TYPE zvhb_amount,
      END OF ty_packaging.

    "! Prices and confirms the product items and keeps one deposit item per product item that is sold in
    "! returnable packaging; changes are written to the transactional buffer
    CLASS-METHODS reprice
      IMPORTING
        orders TYPE tt_orders.

    TYPES tt_updates TYPE TABLE FOR UPDATE zvhb_r_salesorder\\item.
    TYPES tt_creates TYPE TABLE FOR CREATE zvhb_r_salesorder\\salesorder\_item.
    TYPES tt_deletes TYPE TABLE FOR DELETE zvhb_r_salesorder\\item.

    "! Creates, changes or deletes the deposit item of one product item
    CLASS-METHODS plan_deposit
      IMPORTING
        order     TYPE ty_order
        item      TYPE ty_item
        items     TYPE tt_items
        confirmed TYPE zvhb_quantity
      CHANGING
        updates   TYPE tt_updates
        creates   TYPE tt_creates
        deletes   TYPE tt_deletes.

    "! Base price of the channel valid today, reduced by the highest quantity scale that is reached
    CLASS-METHODS price_of
      IMPORTING
        material      TYPE zvhb_material
        channel       TYPE zvhb_distr_channel
        quantity      TYPE zvhb_quantity
      RETURNING
        VALUE(result) TYPE ty_price.

    "! Quantity that can still be confirmed for the order: available to promise plus what the order itself
    "! has confirmed in the database
    CLASS-METHODS available
      IMPORTING
        material      TYPE zvhb_material
        order_uuid    TYPE sysuuid_x16
      RETURNING
        VALUE(result) TYPE zvhb_quantity.

    "! Returnable packaging of a material with units per package and deposit rate; initial without packaging
    CLASS-METHODS packaging_of
      IMPORTING
        material      TYPE zvhb_material
      RETURNING
        VALUE(result) TYPE ty_packaging.

    "! Number of packages needed for a quantity, rounded up
    CLASS-METHODS packages
      IMPORTING
        quantity      TYPE zvhb_quantity
        units         TYPE i
      RETURNING
        VALUE(result) TYPE zvhb_quantity.
ENDCLASS.


CLASS lcl_pricing IMPLEMENTATION.

  METHOD reprice.
    TYPES:
      BEGIN OF ty_used,
        material TYPE zvhb_material,
        quantity TYPE zvhb_quantity,
      END OF ty_used.
    DATA updates TYPE TABLE FOR UPDATE zvhb_r_salesorder\\item.
    DATA deposit_creates TYPE TABLE FOR CREATE zvhb_r_salesorder\\salesorder\_item.
    DATA deposit_deletes TYPE TABLE FOR DELETE zvhb_r_salesorder\\item.
    DATA used TYPE HASHED TABLE OF ty_used WITH UNIQUE KEY material.

    IF orders IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Item
        ALL FIELDS WITH CORRESPONDING #( orders )
      RESULT DATA(all_items).

    LOOP AT orders INTO DATA(order).
      CLEAR used.
      DATA(items) = VALUE tt_items( FOR i IN all_items USING KEY id WHERE ( SalesOrderUUID = order-SalesOrderUUID
                                                               AND %is_draft  = order-%is_draft ) ( i ) ).
      SORT items BY Item.

      LOOP AT items INTO DATA(item) WHERE ItemCategory <> lif_sales=>item_category-deposit.
        DATA(price) = price_of( material = item-Material
                                channel  = order-DistributionChannel
                                quantity = item-Quantity ).

        " Earlier items of the same material in this order have taken their part already
        ASSIGN used[ material = item-Material ] TO FIELD-SYMBOL(<used>).
        IF sy-subrc <> 0.
          INSERT VALUE #( material = item-Material ) INTO TABLE used ASSIGNING <used>.
        ENDIF.
        DATA(free) = CONV zvhb_quantity( available( material = item-Material order_uuid = order-SalesOrderUUID )
                                         - <used>-quantity ).
        DATA(confirmed) = COND zvhb_quantity( WHEN item-Quantity <= 0 OR free <= 0 THEN 0
                                              WHEN free < item-Quantity THEN free
                                              ELSE item-Quantity ).
        <used>-quantity += confirmed.

        APPEND VALUE #( %tky              = item-%tky
                        Unit              = price-unit
                        Currency          = order-Currency
                        BasePrice         = price-base_price
                        DiscountPercent   = price-discount_percent
                        NetAmount         = price-net_amount
                        ConfirmedQuantity = confirmed
                        %control          = VALUE #( Unit              = if_abap_behv=>mk-on
                                                     Currency          = if_abap_behv=>mk-on
                                                     BasePrice         = if_abap_behv=>mk-on
                                                     DiscountPercent   = if_abap_behv=>mk-on
                                                     NetAmount         = if_abap_behv=>mk-on
                                                     ConfirmedQuantity = if_abap_behv=>mk-on ) ) TO updates.

        plan_deposit( EXPORTING order     = order
                                item      = item
                                items     = items
                                confirmed = confirmed
                      CHANGING  updates   = updates
                                creates   = deposit_creates
                                deletes   = deposit_deletes ).
      ENDLOOP.

      " Deposit items whose product item was deleted
      LOOP AT items INTO DATA(orphan) WHERE ItemCategory = lif_sales=>item_category-deposit.
        DATA(parent_found) = abap_false.
        LOOP AT items TRANSPORTING NO FIELDS WHERE ItemUUID = orphan-ParentItemUUID.
          parent_found = abap_true.
        ENDLOOP.
        IF parent_found = abap_false.
          APPEND VALUE #( %tky = orphan-%tky ) TO deposit_deletes.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item
        UPDATE FROM updates
        DELETE FROM deposit_deletes
      ENTITY SalesOrder
        CREATE BY \_Item
        FIELDS ( Item ItemCategory ParentItemUUID Material Unit Quantity ConfirmedQuantity Currency BasePrice
                 NetAmount )
        WITH deposit_creates.
  ENDMETHOD.

  METHOD plan_deposit.
    DATA deposit TYPE ty_item.
    DATA deposit_amount TYPE zvhb_amount.

    LOOP AT items INTO DATA(candidate) WHERE ParentItemUUID = item-ItemUUID.
      deposit = candidate.
      EXIT.
    ENDLOOP.
    DATA(packaging) = packaging_of( item-Material ).
    IF packaging IS INITIAL OR item-Quantity <= 0.
      IF deposit IS NOT INITIAL.
        APPEND VALUE #( %tky = deposit-%tky ) TO deletes.
      ENDIF.
      RETURN.
    ENDIF.

    DATA(package_count) = packages( quantity = item-Quantity units = packaging-units ).
    deposit_amount = package_count * packaging-rate.
    DATA(confirmed_packages) = packages( quantity = confirmed units = packaging-units ).

    IF deposit IS INITIAL.
      " The deposit item follows its product item as a sub-item: 00010 gets 00011
      APPEND VALUE #( %tky    = order-%tky
                      %target = VALUE #( ( %cid              = |D{ item-ItemUUID }|
                                           %is_draft         = order-%is_draft
                                           Item              = item-Item + 1
                                           ItemCategory      = lif_sales=>item_category-deposit
                                           ParentItemUUID    = item-ItemUUID
                                           Material          = packaging-material
                                           Unit              = packaging-unit
                                           Quantity          = package_count
                                           ConfirmedQuantity = confirmed_packages
                                           Currency          = order-Currency
                                           BasePrice         = packaging-rate
                                           NetAmount         = deposit_amount ) ) ) TO creates.
    ELSE.
      APPEND VALUE #( %tky              = deposit-%tky
                      Material          = packaging-material
                      Unit              = packaging-unit
                      Quantity          = package_count
                      ConfirmedQuantity = confirmed_packages
                      Currency          = order-Currency
                      BasePrice         = packaging-rate
                      NetAmount         = deposit_amount
                      %control          = VALUE #( Material          = if_abap_behv=>mk-on
                                                   Unit              = if_abap_behv=>mk-on
                                                   Quantity          = if_abap_behv=>mk-on
                                                   ConfirmedQuantity = if_abap_behv=>mk-on
                                                   Currency          = if_abap_behv=>mk-on
                                                   BasePrice         = if_abap_behv=>mk-on
                                                   NetAmount         = if_abap_behv=>mk-on ) ) TO updates.
    ENDIF.
  ENDMETHOD.

  METHOD price_of.
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    SELECT SINGLE base_unit FROM zvhb_mat
      WHERE material = @material
      INTO @result-unit.

    SELECT SINGLE price_uuid, amount FROM zvhb_price
      WHERE condition_type = @lif_sales=>condition_type-base_price
        AND material       = @material
        AND distr_channel  = @channel
        AND valid_from    <= @today
        AND valid_to      >= @today
      INTO @DATA(price).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT discount_percent FROM zvhb_prcscale
      WHERE price_uuid     = @price-price_uuid
        AND from_quantity <= @quantity
      ORDER BY from_quantity DESCENDING
      INTO @result-discount_percent
      UP TO 1 ROWS.
    ENDSELECT.

    result-base_price = price-amount.
    result-net_amount = round( val = quantity * price-amount * ( 100 - result-discount_percent ) / 100 dec = 2 ).
  ENDMETHOD.

  METHOD available.
    SELECT SINGLE AvailableQuantity FROM zvhb_i_availabletopromise
      WHERE Material = @material
      INTO @DATA(promise).

    SELECT SINGLE ConfirmedQuantity FROM zvhb_i_orderdemand
      WHERE SalesOrderUUID = @order_uuid
        AND Material       = @material
      INTO @DATA(own).

    result = promise + own.
  ENDMETHOD.

  METHOD packaging_of.
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    SELECT SINGLE product~returnable_packaging, product~units_per_package, package~base_unit
      FROM zvhb_mat AS product
        INNER JOIN zvhb_mat AS package ON package~material = product~returnable_packaging
      WHERE product~material           = @material
        AND product~units_per_package  > 0
      INTO @DATA(assignment).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE amount FROM zvhb_price
      WHERE condition_type = @lif_sales=>condition_type-deposit
        AND material       = @assignment-returnable_packaging
        AND valid_from    <= @today
        AND valid_to      >= @today
      INTO @DATA(rate).

    result = VALUE #( material = assignment-returnable_packaging
                      unit     = assignment-base_unit
                      units    = assignment-units_per_package
                      rate     = rate ).
  ENDMETHOD.

  METHOD packages.
    IF units <= 0.
      RETURN.
    ENDIF.
    result = ceil( quantity / units ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_sales_order DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_sales_order.
  PRIVATE SECTION.
    TYPES tt_order_keys TYPE TABLE FOR READ IMPORT zvhb_r_salesorder\\salesorder.
    TYPES tt_orders TYPE TABLE FOR READ RESULT zvhb_r_salesorder\\salesorder.
    TYPES ty_order TYPE STRUCTURE FOR READ RESULT zvhb_r_salesorder\\salesorder.
    TYPES tt_items TYPE TABLE FOR READ RESULT zvhb_r_salesorder\\item.
    TYPES tt_delivery_items TYPE TABLE FOR CREATE zvhb_r_delivery\\delivery\_item.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR SalesOrder RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR SalesOrder RESULT result.

    METHODS releaseCredit FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~releaseCredit RESULT result.

    METHODS createDelivery FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~createDelivery RESULT result.

    METHODS setInvoiced FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~setInvoiced RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~setDefaults.

    METHODS setCurrency FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~setCurrency.

    METHODS repriceItems FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~repriceItems.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR SalesOrder~setNumber.

    METHODS checkCredit FOR DETERMINE ON SAVE
      IMPORTING keys FOR SalesOrder~checkCredit.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateCustomer.

    METHODS validateChannel FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateChannel.

    METHODS validateRequestedDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateRequestedDate.

    METHODS validateItems FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateItems.

    "! FR-SD-03: open orders and invoices of the customer plus this order against the credit limit;
    "! returns the exposure, or nothing when the customer has no credit limit
    METHODS credit_exposure
      IMPORTING
        order         TYPE ty_order
      EXPORTING
        credit_limit  TYPE zvhb_amount
      RETURNING
        VALUE(result) TYPE zvhb_amount.

    "! FR-SD-04: delivery items for the confirmed quantities; beer is split over the batches by FEFO
    METHODS pick
      IMPORTING
        items         TYPE tt_items
      EXPORTING
        problem       TYPE REF TO if_abap_behv_message
      RETURNING
        VALUE(result) TYPE tt_delivery_items.

    METHODS set_status
      IMPORTING
        order_keys    TYPE tt_order_keys
        status        TYPE zvhb_so_status
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


CLASS lhc_sales_order IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED failed.

    " An order can be changed until it is delivered
    result = VALUE #(
      FOR o IN orders
      LET changeable = COND #( WHEN o-Status = lif_sales=>status-open OR o-Status = lif_sales=>status-credit_blocked
                                 OR o-Status IS INITIAL
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )
          active     = xsdbool( o-%is_draft = if_abap_behv=>mk-off ) IN
      ( %tky                   = o-%tky
        %update                = changeable
        %delete                = changeable
        %action-Edit           = changeable
        %assoc-_Item           = changeable
        %action-releaseCredit  = COND #( WHEN active = abap_true AND o-Status = lif_sales=>status-credit_blocked
                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-createDelivery = COND #( WHEN active = abap_true AND o-Status = lif_sales=>status-open
                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-setInvoiced    = COND #( WHEN o-Status = lif_sales=>status-delivered
                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " The sales role follows in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD releaseCredit.
    DATA(orders) = set_status( order_keys = CORRESPONDING #( keys ) status = lif_sales=>status-open ).

    result = VALUE #( FOR o IN orders ( %tky = o-%tky %param = o ) ).
    reported-salesorder = VALUE #( FOR o IN orders
                                   ( %tky = o-%tky
                                     %msg = message( number   = '013'
                                                     severity = if_abap_behv_message=>severity-success
                                                     v1       = o-SalesOrder ) ) ).
  ENDMETHOD.

  METHOD createDelivery.
    DATA delivered TYPE tt_order_keys.
    DATA problem TYPE REF TO if_abap_behv_message.

    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      ENTITY SalesOrder BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(all_items).

    LOOP AT orders INTO DATA(order).
      DATA(delivery_items) = pick( EXPORTING items   = VALUE #( FOR i IN all_items USING KEY entity
                                                                WHERE ( SalesOrderUUID = order-SalesOrderUUID ) ( i ) )
                                   IMPORTING problem = problem ).
      IF problem IS NOT BOUND AND delivery_items IS INITIAL.
        problem = message( number = '015' v1 = order-SalesOrder ).
      ENDIF.

      IF problem IS NOT BOUND.
        MODIFY ENTITIES OF zvhb_r_delivery
          ENTITY Delivery
            CREATE FIELDS ( SalesOrderUUID SalesOrder Customer )
            WITH VALUE #( ( %cid           = 'DELIVERY'
                            SalesOrderUUID = order-SalesOrderUUID
                            SalesOrder     = order-SalesOrder
                            Customer       = order-Customer ) )
            CREATE BY \_Item
            FIELDS ( Item OrderItem ItemCategory Material Batch Plant StorageLocation Unit Quantity )
            WITH delivery_items
          FAILED DATA(delivery_failed)
          REPORTED DATA(delivery_reported).
        IF delivery_failed IS NOT INITIAL.
          problem = VALUE #( delivery_reported-delivery[ 1 ]-%msg OPTIONAL ).
        ENDIF.
      ENDIF.

      IF problem IS BOUND.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky %msg = problem ) TO reported-salesorder.
        CLEAR problem.
        CONTINUE.
      ENDIF.

      APPEND CORRESPONDING #( order ) TO delivered.
      APPEND VALUE #( %tky = order-%tky
                      %msg = message( number   = '014'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = order-SalesOrder ) ) TO reported-salesorder.
    ENDLOOP.

    DATA(changed) = set_status( order_keys = delivered status = lif_sales=>status-delivered ).
    result = VALUE #( FOR c IN changed ( %tky = c-%tky %param = c ) ).
  ENDMETHOD.

  METHOD pick.
    DATA item_number TYPE zvhb_sd_item.

    CLEAR problem.
    DATA(sorted) = items.
    SORT sorted BY Item.

    " One create-by-association line for the new delivery; its targets are the delivery items
    APPEND VALUE #( %cid_ref = 'DELIVERY' ) TO result ASSIGNING FIELD-SYMBOL(<delivery>).

    LOOP AT sorted INTO DATA(item) WHERE ConfirmedQuantity > 0.
      IF item-ItemCategory = lif_sales=>item_category-deposit.
        item_number += 10.
        APPEND VALUE #( %cid            = |ITEM{ item_number }|
                        Item            = item_number
                        OrderItem       = item-Item
                        ItemCategory    = item-ItemCategory
                        Material        = item-Material
                        Plant           = lif_sales=>defaults-plant
                        StorageLocation = lif_sales=>defaults-empties_storage
                        Unit            = item-Unit
                        Quantity        = item-ConfirmedQuantity ) TO <delivery>-%target.
        CONTINUE.
      ENDIF.

      " First expired, first out: the batch with the earliest best-before date goes first
      SELECT Batch, FreeQuantity FROM zvhb_i_fefobatch
        WHERE Material        = @item-Material
          AND Plant           = @lif_sales=>defaults-plant
          AND StorageLocation = @lif_sales=>defaults-beer_storage
        ORDER BY ExpiryDate, Batch
        INTO TABLE @DATA(batches).

      DATA(open) = item-ConfirmedQuantity.
      LOOP AT batches INTO DATA(batch).
        DATA(take) = CONV zvhb_quantity( nmin( val1 = open val2 = batch-FreeQuantity ) ).
        item_number += 10.
        APPEND VALUE #( %cid            = |ITEM{ item_number }|
                        Item            = item_number
                        OrderItem       = item-Item
                        ItemCategory    = item-ItemCategory
                        Material        = item-Material
                        Batch           = batch-Batch
                        Plant           = lif_sales=>defaults-plant
                        StorageLocation = lif_sales=>defaults-beer_storage
                        Unit            = item-Unit
                        Quantity        = take ) TO <delivery>-%target.
        open -= take.
        IF open <= 0.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF open > 0.
        problem = message( number = '016' v1 = item-Material v2 = |{ open NUMBER = USER } { item-Unit }| ).
        CLEAR result.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF <delivery>-%target IS INITIAL.
      CLEAR result.
    ENDIF.
  ENDMETHOD.

  METHOD setInvoiced.
    DATA(orders) = set_status( order_keys = CORRESPONDING #( keys ) status = lif_sales=>status-invoiced ).
    result = VALUE #( FOR o IN orders ( %tky = o-%tky %param = o ) ).
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Status OrderDate RequestedDate Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Status OrderDate RequestedDate Currency )
        WITH VALUE #( FOR o IN orders
                      ( %tky          = o-%tky
                        Status        = COND #( WHEN o-Status IS INITIAL THEN lif_sales=>status-open ELSE o-Status )
                        OrderDate     = COND #( WHEN o-OrderDate IS INITIAL THEN today ELSE o-OrderDate )
                        RequestedDate = COND #( WHEN o-RequestedDate IS INITIAL
                                                THEN today + lif_sales=>defaults-lead_time_days
                                                ELSE o-RequestedDate )
                        Currency      = COND #( WHEN o-Currency IS INITIAL THEN lif_sales=>defaults-currency
                                                ELSE o-Currency ) ) ).
  ENDMETHOD.

  METHOD setCurrency.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Customer ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders ASSIGNING FIELD-SYMBOL(<order>).
      SELECT SINGLE Currency FROM zvhb_i_customervh
        WHERE Customer = @<order>-Customer
        INTO @<order>-Currency.
      IF <order>-Currency IS INITIAL.
        <order>-Currency = lif_sales=>defaults-currency.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Currency )
        WITH VALUE #( FOR o IN orders ( %tky = o-%tky Currency = o-Currency ) ).
  ENDMETHOD.

  METHOD repriceItems.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    lcl_pricing=>reprice( orders ).
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( SalesOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DELETE orders WHERE SalesOrder IS NOT INITIAL.

    LOOP AT orders ASSIGNING FIELD-SYMBOL(<order>).
      TRY.
          <order>-SalesOrder = get_number_range( )->get_next( zif_vhb_number_range=>objects-sales_order ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <order>-%tky %msg = message( number = '001' v1 = exception->get_text( ) ) )
                 TO reported-salesorder.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( SalesOrder )
        WITH VALUE #( FOR o IN orders WHERE ( SalesOrder IS NOT INITIAL ) ( %tky = o-%tky SalesOrder = o-SalesOrder ) ).
  ENDMETHOD.

  METHOD checkCredit.
    DATA credit_limit TYPE zvhb_amount.

    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    " Only orders that are not delivered yet are checked
    DELETE orders WHERE Status <> lif_sales=>status-open AND Status <> lif_sales=>status-credit_blocked.

    LOOP AT orders ASSIGNING FIELD-SYMBOL(<order>).
      DATA(exposure) = credit_exposure( EXPORTING order = <order> IMPORTING credit_limit = credit_limit ).
      IF credit_limit > 0 AND exposure > credit_limit.
        <order>-Status = lif_sales=>status-credit_blocked.
        APPEND VALUE #( %tky = <order>-%tky
                        %msg = message( number   = '012'
                                        severity = if_abap_behv_message=>severity-warning
                                        v1       = |{ credit_limit NUMBER = USER } { <order>-Currency }|
                                        v2       = |{ exposure NUMBER = USER } { <order>-Currency }| ) )
               TO reported-salesorder.
      ELSE.
        <order>-Status = lif_sales=>status-open.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR o IN orders ( %tky = o-%tky Status = o-Status ) ).
  ENDMETHOD.

  METHOD credit_exposure.
    CLEAR credit_limit.

    SELECT SINGLE CreditLimit FROM zvhb_i_customervh
      WHERE Customer = @order-Customer
      INTO @credit_limit.

    SELECT SUM( Amount ) FROM zvhb_i_creditexposureitem
      WHERE Customer      = @order-Customer
        AND DocumentUUID <> @order-SalesOrderUUID
      INTO @DATA(open_amount).

    result = open_amount + order-TotalAmount.
  ENDMETHOD.

  METHOD validateCustomer.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Customer ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'CUSTOMER' ) TO reported-salesorder.

      " Validations may not read the views of the business partner, so the tables are read
      SELECT SINGLE partner~is_blocked FROM zvhb_bp AS partner
        INNER JOIN zvhb_bprole AS role ON role~partner_uuid = partner~partner_uuid
        WHERE partner~partner   = @order-Customer
          AND role~partner_role = @lif_sales=>c_customer
        INTO @DATA(is_blocked).
      DATA(found) = xsdbool( sy-subrc = 0 ).

      DATA(problem) = COND #( WHEN order-Customer IS INITIAL THEN message( '002' )
                              WHEN found = abap_false THEN message( number = '003' v1 = order-Customer )
                              WHEN is_blocked = abap_true THEN message( number = '004' v1 = order-Customer ) ).
      IF problem IS BOUND.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky              = order-%tky
                        %state_area       = 'CUSTOMER'
                        %msg              = problem
                        %element-Customer = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateChannel.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( DistributionChannel ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'CHANNEL' ) TO reported-salesorder.

      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-distribution_channel
                                             value  = order-DistributionChannel ).
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky                         = order-%tky
                        %state_area                  = 'CHANNEL'
                        %msg                         = message( number = '005' v1 = order-DistributionChannel )
                        %element-DistributionChannel = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateRequestedDate.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( RequestedDate Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'REQUESTED_DATE' ) TO reported-salesorder.

      IF order-RequestedDate < today
         AND ( order-Status = lif_sales=>status-open OR order-Status = lif_sales=>status-credit_blocked ).
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky                   = order-%tky
                        %state_area            = 'REQUESTED_DATE'
                        %msg                   = message( number = '006' v1 = |{ order-RequestedDate DATE = ISO }| )
                        %element-RequestedDate = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateItems.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Item
        FIELDS ( ItemCategory ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky %state_area = 'ITEMS' ) TO reported-salesorder.

      DATA(has_product) = abap_false.
      LOOP AT items TRANSPORTING NO FIELDS USING KEY entity
           WHERE SalesOrderUUID = key-SalesOrderUUID AND ItemCategory = lif_sales=>item_category-product.
        has_product = abap_true.
      ENDLOOP.
      IF has_product = abap_false.
        APPEND VALUE #( %tky = key-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky        = key-%tky
                        %state_area = 'ITEMS'
                        %msg        = message( '007' ) ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_status.
    IF order_keys IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN order_keys ( %tky = key-%tky Status = status ) ).

    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( order_keys )
      RESULT result.
  ENDMETHOD.

  METHOD message.
    result = new_message( id       = lif_sales=>c_msgid
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


CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_sales_order.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.

    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setItemDefaults.

    METHODS determinePrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~determinePrice.

    METHODS calculateTotals FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculateTotals.

    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItem.

    METHODS checkAvailability FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~checkAvailability.
ENDCLASS.


CLASS lhc_item IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( ItemCategory ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      FAILED failed.

    " Deposit items follow their product item and cannot be changed by hand
    result = VALUE #(
      FOR i IN items
      LET deposit = xsdbool( i-ItemCategory = lif_sales=>item_category-deposit ) IN
      ( %tky            = i-%tky
        %update         = COND #( WHEN deposit = abap_true THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled )
        %delete         = COND #( WHEN deposit = abap_true THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled )
        %field-Material = COND #( WHEN deposit = abap_true THEN if_abap_behv=>fc-f-read_only
                                  ELSE if_abap_behv=>fc-f-mandatory )
        %field-Quantity = COND #( WHEN deposit = abap_true THEN if_abap_behv=>fc-f-read_only
                                  ELSE if_abap_behv=>fc-f-mandatory ) ) ).
  ENDMETHOD.

  METHOD setItemDefaults.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( Item ItemCategory ) WITH CORRESPONDING #( keys )
      RESULT DATA(new_items)
      ENTITY Item BY \_SalesOrder
        FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Item
        FIELDS ( Item ) WITH CORRESPONDING #( orders )
      RESULT DATA(all_items).

    LOOP AT new_items ASSIGNING FIELD-SYMBOL(<item>).
      DATA(order) = VALUE #( orders[ KEY id SalesOrderUUID = <item>-SalesOrderUUID %is_draft = <item>-%is_draft ] OPTIONAL ).
      IF <item>-Item IS INITIAL.
        " Items are numbered 00010, 00020 ... in the order they are added; deposit sub-items like 00011
        " do not move the next number
        DATA(highest) = REDUCE i( INIT h = 0
                                  FOR a IN all_items USING KEY id WHERE ( SalesOrderUUID = <item>-SalesOrderUUID
                                                                          AND %is_draft  = <item>-%is_draft )
                                  NEXT h = nmax( val1 = h val2 = CONV i( a-Item ) ) ).
        <item>-Item = ( highest DIV 10 + 1 ) * 10.
        APPEND VALUE #( %tky = <item>-%tky Item = <item>-Item ) TO all_items.
      ENDIF.
      IF <item>-ItemCategory IS INITIAL.
        <item>-ItemCategory = lif_sales=>item_category-product.
      ENDIF.
      <item>-Currency = order-Currency.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( Item ItemCategory Currency )
        WITH VALUE #( FOR i IN new_items ( %tky         = i-%tky
                                           Item         = i-Item
                                           ItemCategory = i-ItemCategory
                                           Currency     = i-Currency ) ).
  ENDMETHOD.

  METHOD determinePrice.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( ItemCategory ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " Deposit items are maintained together with their product item
    DELETE items WHERE ItemCategory = lif_sales=>item_category-deposit.
    IF items IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item BY \_SalesOrder
        ALL FIELDS WITH CORRESPONDING #( items )
      RESULT DATA(orders).

    lcl_pricing=>reprice( orders ).
  ENDMETHOD.

  METHOD calculateTotals.
    DATA order_keys TYPE TABLE FOR READ IMPORT zvhb_r_salesorder\\salesorder\_item.
    DATA updates TYPE TABLE FOR UPDATE zvhb_r_salesorder\\salesorder.
    DATA net TYPE zvhb_amount.
    DATA deposit TYPE zvhb_amount.

    " The keys of deleted items still name their order
    LOOP AT keys INTO DATA(key).
      DATA(known) = abap_false.
      LOOP AT order_keys TRANSPORTING NO FIELDS USING KEY id
           WHERE %is_draft = key-%is_draft AND SalesOrderUUID = key-SalesOrderUUID.
        known = abap_true.
      ENDLOOP.
      IF known = abap_false.
        APPEND VALUE #( %is_draft = key-%is_draft SalesOrderUUID = key-SalesOrderUUID ) TO order_keys.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Item
        FIELDS ( ItemCategory NetAmount ) WITH order_keys
      RESULT DATA(items).

    LOOP AT order_keys INTO DATA(order).
      CLEAR: net, deposit.
      LOOP AT items INTO DATA(item) USING KEY id
           WHERE %is_draft = order-%is_draft AND SalesOrderUUID = order-SalesOrderUUID.
        IF item-ItemCategory = lif_sales=>item_category-deposit.
          deposit += item-NetAmount.
        ELSE.
          net += item-NetAmount.
        ENDIF.
      ENDLOOP.
      APPEND VALUE #( %is_draft      = order-%is_draft
                      SalesOrderUUID = order-SalesOrderUUID
                      NetAmount      = net
                      DepositAmount  = deposit
                      TotalAmount    = net + deposit ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( NetAmount DepositAmount TotalAmount ) WITH updates.
  ENDMETHOD.

  METHOD validateItem.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( Item ItemCategory Material Quantity BasePrice ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      ENTITY Item BY \_SalesOrder
        FIELDS ( DistributionChannel ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT items INTO DATA(item) WHERE ItemCategory <> lif_sales=>item_category-deposit.
      APPEND VALUE #( %tky = item-%tky %state_area = 'ITEM' ) TO reported-item.

      SELECT SINGLE material_type, is_active FROM zvhb_mat
        WHERE material = @item-Material
        INTO @DATA(material).
      DATA(channel) = VALUE #( orders[ KEY entity SalesOrderUUID = item-SalesOrderUUID ]-DistributionChannel OPTIONAL ).

      DATA(problem) = COND symsgno( WHEN material-material_type <> lif_sales=>c_finished_product
                                      OR material-is_active = abap_false THEN '008'
                                    WHEN item-Quantity <= 0 THEN '009'
                                    WHEN item-BasePrice <= 0 THEN '010' ).
      IF problem IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = item-%tky ) TO failed-item.
      APPEND VALUE #( %tky        = item-%tky
                      %state_area = 'ITEM'
                      %msg        = new_message( id       = lif_sales=>c_msgid
                                                 number   = problem
                                                 severity = if_abap_behv_message=>severity-error
                                                 v1       = item-Item
                                                 v2       = item-Material
                                                 v3       = channel )
                      %path       = VALUE #( salesorder-%is_draft      = item-%is_draft
                                             salesorder-SalesOrderUUID = item-SalesOrderUUID ) ) TO reported-item.
    ENDLOOP.
  ENDMETHOD.

  METHOD checkAvailability.
    READ ENTITIES OF zvhb_r_salesorder IN LOCAL MODE
      ENTITY Item
        FIELDS ( Item ItemCategory Quantity ConfirmedQuantity Unit ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " FR-SD-02: a partial confirmation is allowed, the user is told about it
    LOOP AT items INTO DATA(item) WHERE ItemCategory <> lif_sales=>item_category-deposit.
      APPEND VALUE #( %tky = item-%tky %state_area = 'AVAILABILITY' ) TO reported-item.

      IF item-Quantity > 0 AND item-ConfirmedQuantity < item-Quantity.
        APPEND VALUE #( %tky        = item-%tky
                        %state_area = 'AVAILABILITY'
                        %msg        = new_message( id       = lif_sales=>c_msgid
                                                   number   = '011'
                                                   severity = if_abap_behv_message=>severity-warning
                                                   v1       = item-Item
                                                   v2       = |{ item-ConfirmedQuantity NUMBER = USER }|
                                                   v3       = |{ item-Quantity NUMBER = USER } { item-Unit }| )
                        %path       = VALUE #( salesorder-%is_draft      = item-%is_draft
                                               salesorder-SalesOrderUUID = item-SalesOrderUUID ) ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

