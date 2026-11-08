*"* use this source file for your ABAP unit test classes

"! Pricing, deposit items, availability, credit check, validations and FEFO picking of the sales order.
"! The transactional buffers of sales order and delivery and the tables and views of materials, prices,
"! partners, stock and open documents are replaced by test doubles. The goods issue is checked in the app.
CLASS ltc_sales_order DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_mapped TYPE RESPONSE FOR MAPPED EARLY zvhb_r_salesorder.
    TYPES ty_failed TYPE RESPONSE FOR FAILED EARLY zvhb_r_salesorder.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY zvhb_r_salesorder.
    TYPES ty_failed_late TYPE RESPONSE FOR FAILED LATE zvhb_r_salesorder.
    TYPES ty_reported_late TYPE RESPONSE FOR REPORTED LATE zvhb_r_salesorder.
    TYPES tt_items TYPE TABLE FOR READ RESULT zvhb_r_salesorder\\item.

    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_mat WITH EMPTY KEY.
    TYPES tt_prices TYPE STANDARD TABLE OF zvhb_price WITH EMPTY KEY.
    TYPES tt_scales TYPE STANDARD TABLE OF zvhb_prcscale WITH EMPTY KEY.
    TYPES tt_promises TYPE STANDARD TABLE OF zvhb_i_availabletopromise WITH EMPTY KEY.
    TYPES tt_customers TYPE STANDARD TABLE OF zvhb_i_customervh WITH EMPTY KEY.
    TYPES tt_exposure TYPE STANDARD TABLE OF zvhb_i_creditexposureitem WITH EMPTY KEY.
    TYPES tt_partners TYPE STANDARD TABLE OF zvhb_bp WITH EMPTY KEY.
    TYPES tt_roles TYPE STANDARD TABLE OF zvhb_bprole WITH EMPTY KEY.
    TYPES tt_batches TYPE STANDARD TABLE OF zvhb_i_fefobatch WITH EMPTY KEY.

    CLASS-DATA environment TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA order_handler TYPE REF TO lhc_sales_order.
    DATA item_handler TYPE REF TO lhc_item.
    DATA failed TYPE ty_failed_late.
    DATA reported TYPE ty_reported_late.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS gastronomy_gets_scale_discount FOR TESTING.
    METHODS wholesale_pays_base_price FOR TESTING.
    METHODS deposit_item_follows_bottles FOR TESTING.
    METHODS totals_include_deposit FOR TESTING.
    METHODS stock_confirms_partially FOR TESTING.
    METHODS credit_limit_blocks_order FOR TESTING.
    METHODS order_within_limit_is_open FOR TESTING.
    METHODS credit_block_is_released FOR TESTING.
    METHODS unknown_customer_fails FOR TESTING.
    METHODS blocked_customer_fails FOR TESTING.
    METHODS missing_price_fails FOR TESTING.
    METHODS order_needs_product FOR TESTING.
    METHODS picking_follows_fefo FOR TESTING.
    METHODS missing_stock_stops_picking FOR TESTING.

    "! Order of bottled Pils, priced and confirmed as in the app
    METHODS create_order
      IMPORTING
        customer      TYPE zvhb_partner DEFAULT '1000000003'
        channel       TYPE zvhb_distr_channel DEFAULT 'GA'
        quantity      TYPE zvhb_quantity DEFAULT 6000
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS read_order
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE zvhb_r_salesorder.

    METHODS read_items
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE tt_items.

    METHODS assert_message
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_sales_order IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_SALESORDER' )
                                                                                    ( 'ZVHB_R_DELIVERY' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_MAT' )
                                                                                     ( 'ZVHB_PRICE' )
                                                                                     ( 'ZVHB_PRCSCALE' )
                                                                                     ( 'ZVHB_I_AVAILABLETOPROMISE' )
                                                                                     ( 'ZVHB_I_ORDERDEMAND' )
                                                                                     ( 'ZVHB_I_CUSTOMERVH' )
                                                                                     ( 'ZVHB_I_CREDITEXPOSUREITEM' )
                                                                                     ( 'ZVHB_BP' )
                                                                                     ( 'ZVHB_BPROLE' )
                                                                                     ( 'ZVHB_I_FEFOBATCH' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    " Pils in 0.5 l bottles, 20 to a crate with 3.10 EUR deposit
    sql_environment->insert_test_data( VALUE tt_materials(
      ( material = 'PILS-BTL05' material_type = 'FERT' base_unit = 'ST' is_active = abap_true
        returnable_packaging = 'CRATE-20' units_per_package = 20 )
      ( material = 'CRATE-20' material_type = 'LEER' base_unit = 'ST' is_active = abap_true ) ) ).

    " Gastronomy pays 0.89 EUR with 5 % from 1,000 and 8 % from 5,000 bottles, wholesale 0.79 EUR
    sql_environment->insert_test_data( VALUE tt_prices(
      ( price_uuid = 'A0000000000000000000000000000001' condition_type = 'BASE' material = 'PILS-BTL05'
        distr_channel = 'GA' valid_from = '20260101' valid_to = '99991231' amount = '0.89' currency = 'EUR' )
      ( price_uuid = 'A0000000000000000000000000000002' condition_type = 'BASE' material = 'PILS-BTL05'
        distr_channel = 'GF' valid_from = '20260101' valid_to = '99991231' amount = '0.79' currency = 'EUR' )
      ( price_uuid = 'A0000000000000000000000000000003' condition_type = 'DEPO' material = 'CRATE-20'
        valid_from = '20260101' valid_to = '99991231' amount = '3.10' currency = 'EUR' ) ) ).
    sql_environment->insert_test_data( VALUE tt_scales(
      ( price_uuid = 'A0000000000000000000000000000001' scale_uuid = 'B0000000000000000000000000000001'
        from_quantity = 1000 discount_percent = 5 )
      ( price_uuid = 'A0000000000000000000000000000001' scale_uuid = 'B0000000000000000000000000000002'
        from_quantity = 5000 discount_percent = 8 ) ) ).

    sql_environment->insert_test_data( VALUE tt_promises(
      ( Material = 'PILS-BTL05' Unit = 'ST' FreeQuantity = 14400 ConfirmedQuantity = 6000 AvailableQuantity = 8400 ) ) ).

    " The inn has 15,000 EUR credit and already 11,685.60 EUR open
    sql_environment->insert_test_data( VALUE tt_customers(
      ( Customer = '1000000003' CustomerName = 'Gasthaus Zum Kupferkessel' Currency = 'EUR' CreditLimit = 15000 )
      ( Customer = '1000000004' CustomerName = 'Getraenke Huber GmbH' Currency = 'EUR' CreditLimit = 50000 ) ) ).
    sql_environment->insert_test_data( VALUE tt_exposure(
      ( DocumentUUID = 'C0000000000000000000000000000001' Customer = '1000000003' Currency = 'EUR'
        Amount = '11685.60' ) ) ).
    sql_environment->insert_test_data( VALUE tt_partners(
      ( partner_uuid = 'D0000000000000000000000000000003' partner = '1000000003' )
      ( partner_uuid = 'D0000000000000000000000000000004' partner = '1000000004' )
      ( partner_uuid = 'D0000000000000000000000000000005' partner = '1000000005' is_blocked = abap_true ) ) ).
    sql_environment->insert_test_data( VALUE tt_roles(
      ( partner_uuid = 'D0000000000000000000000000000003' partner_role = 'CU' )
      ( partner_uuid = 'D0000000000000000000000000000004' partner_role = 'CU' )
      ( partner_uuid = 'D0000000000000000000000000000005' partner_role = 'CU' ) ) ).

    " Two bottle batches: the older one runs out first
    sql_environment->insert_test_data( VALUE tt_batches(
      ( Material = 'PILS-BTL05' Plant = 'BR01' StorageLocation = 'FG01' Batch = '2000000001' Unit = 'ST'
        ExpiryDate = '20261128' FreeQuantity = 4800 )
      ( Material = 'PILS-BTL05' Plant = 'BR01' StorageLocation = 'FG01' Batch = '2000000002' Unit = 'ST'
        ExpiryDate = '20270314' FreeQuantity = 9600 ) ) ).

    CREATE OBJECT order_handler FOR TESTING.
    CREATE OBJECT item_handler FOR TESTING.
    CLEAR: failed, reported.
  ENDMETHOD.

  METHOD gastronomy_gets_scale_discount.
    DATA(items) = read_items( create_order( ) ).
    DATA(product) = items[ ItemCategory = 'PROD' ].

    cl_abap_unit_assert=>assert_equals( exp = '0.89' act = product-BasePrice ).
    cl_abap_unit_assert=>assert_equals( exp = 8 act = product-DiscountPercent ).
    cl_abap_unit_assert=>assert_equals( exp = '4912.80' act = product-NetAmount ).
  ENDMETHOD.

  METHOD wholesale_pays_base_price.
    DATA(items) = read_items( create_order( customer = '1000000004' channel = 'GF' quantity = 1000 ) ).
    DATA(product) = items[ ItemCategory = 'PROD' ].

    cl_abap_unit_assert=>assert_equals( exp = 0 act = product-DiscountPercent ).
    cl_abap_unit_assert=>assert_equals( exp = '790.00' act = product-NetAmount ).
  ENDMETHOD.

  METHOD deposit_item_follows_bottles.
    DATA(items) = read_items( create_order( quantity = 6010 ) ).

    DATA(deposit) = items[ ItemCategory = 'DEPO' ].
    cl_abap_unit_assert=>assert_equals( exp = 'CRATE-20' act = deposit-Material ).
    cl_abap_unit_assert=>assert_equals( exp = 301 act = deposit-Quantity ).
    cl_abap_unit_assert=>assert_equals( exp = '933.10' act = deposit-NetAmount ).
    cl_abap_unit_assert=>assert_equals( exp = items[ ItemCategory = 'PROD' ]-ItemUUID act = deposit-ParentItemUUID ).
  ENDMETHOD.

  METHOD totals_include_deposit.
    DATA(order) = read_order( create_order( ) ).

    cl_abap_unit_assert=>assert_equals( exp = '4912.80' act = order-NetAmount ).
    cl_abap_unit_assert=>assert_equals( exp = '930.00' act = order-DepositAmount ).
    cl_abap_unit_assert=>assert_equals( exp = '5842.80' act = order-TotalAmount ).
  ENDMETHOD.

  METHOD stock_confirms_partially.
    DATA(mapped) = create_order( customer = '1000000004' quantity = 12000 ).
    DATA(items) = read_items( mapped ).

    cl_abap_unit_assert=>assert_equals( exp = 8400 act = items[ ItemCategory = 'PROD' ]-ConfirmedQuantity ).
    cl_abap_unit_assert=>assert_equals( exp = 420 act = items[ ItemCategory = 'DEPO' ]-ConfirmedQuantity ).

    item_handler->checkavailability( EXPORTING keys     = CORRESPONDING #( items )
                                     CHANGING  failed   = failed
                                               reported = reported ).
    cl_abap_unit_assert=>assert_initial( failed-item ).
    DATA(numbers) = VALUE string_table( FOR r IN reported-item WHERE ( %msg IS BOUND )
                                        ( CONV string( r-%msg->if_t100_message~t100key-msgno ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `011` ) ) act = numbers ).
  ENDMETHOD.

  METHOD credit_limit_blocks_order.
    " 4,000 bottles with 5 % and 200 crates come to 4,002.00 EUR on top of 11,685.60 EUR
    DATA(mapped) = create_order( quantity = 4000 ).

    order_handler->checkcredit( EXPORTING keys = CORRESPONDING #( mapped-salesorder ) CHANGING reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 'CRBL' act = read_order( mapped )-Status ).
    assert_message( '012' ).
  ENDMETHOD.

  METHOD order_within_limit_is_open.
    DATA(mapped) = create_order( customer = '1000000004' channel = 'GF' ).

    order_handler->checkcredit( EXPORTING keys = CORRESPONDING #( mapped-salesorder ) CHANGING reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 'OPEN' act = read_order( mapped )-Status ).
  ENDMETHOD.

  METHOD credit_block_is_released.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_salesorder\\salesorder~releasecredit.
    DATA mapped_early TYPE ty_mapped.
    DATA failed_early TYPE ty_failed.
    DATA reported_early TYPE ty_reported.
    DATA(mapped) = create_order( quantity = 4000 ).
    order_handler->checkcredit( EXPORTING keys = CORRESPONDING #( mapped-salesorder ) CHANGING reported = reported ).

    order_handler->releasecredit( EXPORTING keys     = CORRESPONDING #( mapped-salesorder )
                                  CHANGING  result   = result
                                            mapped   = mapped_early
                                            failed   = failed_early
                                            reported = reported_early ).

    cl_abap_unit_assert=>assert_equals( exp = 'OPEN' act = read_order( mapped )-Status ).
  ENDMETHOD.

  METHOD unknown_customer_fails.
    DATA(mapped) = create_order( customer = '1000000099' ).

    order_handler->validatecustomer( EXPORTING keys = CORRESPONDING #( mapped-salesorder )
                                     CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_not_initial( failed-salesorder ).
    assert_message( '003' ).
  ENDMETHOD.

  METHOD blocked_customer_fails.
    DATA(mapped) = create_order( customer = '1000000005' ).

    order_handler->validatecustomer( EXPORTING keys = CORRESPONDING #( mapped-salesorder )
                                     CHANGING failed = failed reported = reported ).

    assert_message( '004' ).
  ENDMETHOD.

  METHOD missing_price_fails.
    DATA(mapped) = create_order( channel = 'EX' ).

    item_handler->validateitem( EXPORTING keys = CORRESPONDING #( mapped-item )
                                CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_not_initial( failed-item ).
    DATA(numbers) = VALUE string_table( FOR r IN reported-item WHERE ( %msg IS BOUND )
                                        ( CONV string( r-%msg->if_t100_message~t100key-msgno ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `010` ) ) act = numbers ).
  ENDMETHOD.

  METHOD order_needs_product.
    MODIFY ENTITIES OF zvhb_r_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( Customer DistributionChannel RequestedDate )
        WITH VALUE #( ( %cid = 'ORDER' Customer = '1000000003' DistributionChannel = 'GA'
                        RequestedDate = cl_abap_context_info=>get_system_date( ) + 2 ) )
      MAPPED DATA(mapped).

    order_handler->validateitems( EXPORTING keys = CORRESPONDING #( mapped-salesorder )
                                  CHANGING failed = failed reported = reported ).

    assert_message( '007' ).
  ENDMETHOD.

  METHOD picking_follows_fefo.
    DATA problem TYPE REF TO if_abap_behv_message.
    DATA(items) = read_items( create_order( customer = '1000000004' channel = 'GF' ) ).

    DATA(picked) = order_handler->pick( EXPORTING items = items IMPORTING problem = problem ).

    cl_abap_unit_assert=>assert_not_bound( problem ).
    DATA(targets) = picked[ 1 ]-%target.
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( targets ) ).
    cl_abap_unit_assert=>assert_equals( exp = '2000000001' act = targets[ 1 ]-Batch ).
    cl_abap_unit_assert=>assert_equals( exp = 4800 act = targets[ 1 ]-Quantity ).
    cl_abap_unit_assert=>assert_equals( exp = '2000000002' act = targets[ 2 ]-Batch ).
    cl_abap_unit_assert=>assert_equals( exp = 1200 act = targets[ 2 ]-Quantity ).
    cl_abap_unit_assert=>assert_equals( exp = 'CRATE-20' act = targets[ 3 ]-Material ).
    cl_abap_unit_assert=>assert_equals( exp = 'LE01' act = targets[ 3 ]-StorageLocation ).
  ENDMETHOD.

  METHOD missing_stock_stops_picking.
    DATA problem TYPE REF TO if_abap_behv_message.
    DATA(items) = read_items( create_order( customer = '1000000004' channel = 'GF' ) ).
    sql_environment->clear_doubles( ).

    DATA(picked) = order_handler->pick( EXPORTING items = items IMPORTING problem = problem ).

    cl_abap_unit_assert=>assert_bound( problem ).
    cl_abap_unit_assert=>assert_initial( picked ).
    cl_abap_unit_assert=>assert_equals( exp = '016' act = problem->if_t100_message~t100key-msgno ).
  ENDMETHOD.

  METHOD create_order.
    MODIFY ENTITIES OF zvhb_r_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( Customer DistributionChannel RequestedDate )
        WITH VALUE #( ( %cid = 'ORDER' Customer = customer DistributionChannel = channel
                        RequestedDate = cl_abap_context_info=>get_system_date( ) + 2 ) )
        CREATE BY \_Item
        FIELDS ( Material Quantity )
        WITH VALUE #( ( %cid_ref = 'ORDER'
                        %target  = VALUE #( ( %cid = 'ITEM' Material = 'PILS-BTL05' Quantity = quantity ) ) ) )
      MAPPED result.

    order_handler->setdefaults( keys = CORRESPONDING #( result-salesorder ) ).
    item_handler->setitemdefaults( keys = CORRESPONDING #( result-item ) ).
    item_handler->determineprice( keys = CORRESPONDING #( result-item ) ).

    READ ENTITIES OF zvhb_r_salesorder
      ENTITY SalesOrder BY \_Item
        FIELDS ( ItemUUID ) WITH CORRESPONDING #( result-salesorder )
      RESULT DATA(items).
    item_handler->calculatetotals( keys = CORRESPONDING #( items ) ).
  ENDMETHOD.

  METHOD read_order.
    READ ENTITIES OF zvhb_r_salesorder
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( mapped-salesorder )
      RESULT DATA(orders).
    result = CORRESPONDING #( orders[ 1 ] ).
  ENDMETHOD.

  METHOD read_items.
    READ ENTITIES OF zvhb_r_salesorder
      ENTITY SalesOrder BY \_Item ALL FIELDS WITH CORRESPONDING #( mapped-salesorder )
      RESULT result.
  ENDMETHOD.

  METHOD assert_message.
    LOOP AT reported-salesorder INTO DATA(line) WHERE %msg IS BOUND.
      IF line-%msg->if_t100_message~t100key-msgno = msgno.
        RETURN.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>fail( |Message { msgno } expected| ).
  ENDMETHOD.

ENDCLASS.

