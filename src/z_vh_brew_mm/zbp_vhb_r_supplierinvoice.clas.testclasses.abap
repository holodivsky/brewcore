*"* use this source file for your ABAP unit test classes

"! Item proposal, checks, 3-way match result and the manual decision of the supplier invoice.
"! The transactional buffer, the purchase order data and the match view are replaced by test doubles.
CLASS ltc_supplier_invoice DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_supplierinvoice.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_supplierinvoice.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_supplierinvoice.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_supplierinvoice\\invoice.

    TYPES tt_orders          TYPE STANDARD TABLE OF zvhb_r_purchaseorder WITH EMPTY KEY.
    TYPES tt_order_items     TYPE STANDARD TABLE OF zvhb_r_purchaseorderitem WITH EMPTY KEY.
    TYPES tt_history         TYPE STANDARD TABLE OF zvhb_i_purchaseorderhistory WITH EMPTY KEY.
    TYPES tt_invoiced        TYPE STANDARD TABLE OF zvhb_i_invoicedquantity WITH EMPTY KEY.
    TYPES tt_order_headers   TYPE STANDARD TABLE OF zvhb_pohdr WITH EMPTY KEY.
    TYPES tt_invoice_headers TYPE STANDARD TABLE OF zvhb_sinvhdr WITH EMPTY KEY.
    TYPES tt_matches         TYPE STANDARD TABLE OF zvhb_i_supplierinvoicematch WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF orders,
        ordered     TYPE zvhb_purch_order VALUE '4500000001',
        not_ordered TYPE zvhb_purch_order VALUE '4500000002',
        unknown     TYPE zvhb_purch_order VALUE '4599999999',
      END OF orders.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA invoice_handler TYPE REF TO lhc_invoice.
    DATA item_handler    TYPE REF TO lhc_item.
    DATA failed          TYPE ty_failed.
    DATA reported        TYPE ty_reported.

    "! Responses of actions, which report in the interaction phase
    DATA mapped_early   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_supplierinvoice.
    DATA failed_early   TYPE RESPONSE FOR FAILED EARLY zvhb_r_supplierinvoice.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_supplierinvoice.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS new_invoice_gets_defaults FOR TESTING.
    METHODS open_quantity_is_proposed FOR TESTING.
    METHODS amount_is_calculated FOR TESTING.
    METHODS unknown_order_fails FOR TESTING.
    METHODS order_not_sent_fails FOR TESTING.
    METHODS duplicate_reference_fails FOR TESTING.
    METHODS future_invoice_date_fails FOR TESTING.
    METHODS zero_quantity_fails FOR TESTING.
    METHODS matching_invoice_is_posted FOR TESTING.
    METHODS price_deviation_blocks FOR TESTING.
    METHODS quantity_excess_blocks FOR TESTING.
    METHODS blocked_invoice_is_released FOR TESTING.
    METHODS posted_invoice_is_locked FOR TESTING.

    "! Invoice for the purchase order; determinations are run as in the app
    METHODS create_invoice
      IMPORTING
        purchase_order TYPE zvhb_purch_order DEFAULT orders-ordered
        reference      TYPE zvhb_inv_reference DEFAULT 'RE-4711'
      RETURNING
        VALUE(result)  TYPE ty_mapped.

    METHODS read_invoice
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE zvhb_r_supplierinvoice.

    "! Lets the match view report the given result for the first item of the invoice
    METHODS set_match_result
      IMPORTING
        mapped TYPE ty_mapped
        result TYPE zvhb_i_supplierinvoicematch-MatchResult.

    METHODS post
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.

    METHODS assert_message
      IMPORTING
        msgno TYPE symsgno.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_supplier_invoice IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_SUPPLIERINVOICE' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_R_PURCHASEORDER' )
                                                                                     ( 'ZVHB_R_PURCHASEORDERITEM' )
                                                                                     ( 'ZVHB_I_PURCHASEORDERHISTORY' )
                                                                                     ( 'ZVHB_I_INVOICEDQUANTITY' )
                                                                                     ( 'ZVHB_POHDR' )
                                                                                     ( 'ZVHB_SINVHDR' )
                                                                                     ( 'ZVHB_I_SUPPLIERINVOICEMATCH' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    sql_environment->insert_test_data( VALUE tt_orders(
      ( PurchaseOrderUUID = 'A0000000000000000000000000000001' PurchaseOrder = orders-ordered
        Supplier = '1000000020' Currency = 'EUR' Status = 'ORDR' )
      ( PurchaseOrderUUID = 'A0000000000000000000000000000002' PurchaseOrder = orders-not_ordered
        Supplier = '1000000020' Currency = 'EUR' Status = 'NEW' ) ) ).

    sql_environment->insert_test_data( VALUE tt_order_headers(
      ( po_uuid = 'A0000000000000000000000000000001' purchase_order = orders-ordered status = 'ORDR' )
      ( po_uuid = 'A0000000000000000000000000000002' purchase_order = orders-not_ordered status = 'NEW' ) ) ).

    " Malt was received, hops not yet
    sql_environment->insert_test_data( VALUE tt_order_items(
      ( PurchaseOrderUUID = 'A0000000000000000000000000000001' ItemUUID = 'B0000000000000000000000000000001'
        Item = '00010' Material = 'MALT-PILS' Unit = 'KG' Quantity = 25000 Currency = 'EUR' NetPrice = '0.48' )
      ( PurchaseOrderUUID = 'A0000000000000000000000000000001' ItemUUID = 'B0000000000000000000000000000002'
        Item = '00020' Material = 'HOPS-HALL' Unit = 'KG' Quantity = 50 Currency = 'EUR' NetPrice = '18.00' ) ) ).

    sql_environment->insert_test_data( VALUE tt_history(
      ( PurchaseOrder = orders-ordered PurchaseOrderItem = '00010' Unit = 'KG' ReceivedQuantity = 10000 ) ) ).

    " An earlier invoice already charged 4,000 kg of the 10,000 kg received
    sql_environment->insert_test_data( VALUE tt_invoiced(
      ( OrderItemUUID = 'B0000000000000000000000000000001' Unit = 'KG' InvoicedQuantity = 4000 ) ) ).

    sql_environment->insert_test_data( VALUE tt_invoice_headers(
      ( invoice_uuid = 'C0000000000000000000000000000001' supplier_invoice = '5100000009'
        supplier = '1000000020' invoice_reference = 'RE-0001' status = 'POST' ) ) ).

    CREATE OBJECT invoice_handler FOR TESTING.
    CREATE OBJECT item_handler FOR TESTING.
    CLEAR: failed, reported, mapped_early, failed_early, reported_early.
  ENDMETHOD.

  METHOD create_invoice.
    MODIFY ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Invoice
        CREATE FIELDS ( PurchaseOrder InvoiceReference )
        WITH VALUE #( ( %cid = 'INVOICE' PurchaseOrder = purchase_order InvoiceReference = reference ) )
      MAPPED result.

    invoice_handler->setdefaults( keys = CORRESPONDING #( result-invoice ) ).
    invoice_handler->proposeitems( keys = CORRESPONDING #( result-invoice ) ).

    READ ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Invoice BY \_Item
        FIELDS ( ItemUUID ) WITH CORRESPONDING #( result-invoice )
      RESULT DATA(items).
    IF items IS NOT INITIAL.
      item_handler->calculateamount( keys = CORRESPONDING #( items ) ).
    ENDIF.
    result-item = CORRESPONDING #( items ).
  ENDMETHOD.

  METHOD read_invoice.
    READ ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Invoice ALL FIELDS WITH CORRESPONDING #( mapped-invoice )
      RESULT DATA(invoices).
    result = CORRESPONDING #( invoices[ 1 ] ).
  ENDMETHOD.

  METHOD set_match_result.
    sql_environment->insert_test_data( VALUE tt_matches(
      ( InvoiceUUID          = mapped-invoice[ 1 ]-InvoiceUUID
        ItemUUID             = mapped-item[ 1 ]-ItemUUID
        Item                 = '0001'
        Unit                 = 'KG'
        MatchResult          = result
        PriceVariancePercent = COND #( WHEN result = 'PRIC' THEN '4.17' )
        QuantityExcess       = COND #( WHEN result = 'QUAN' THEN 500 ) ) ) ).
  ENDMETHOD.

  METHOD post.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_supplierinvoice\\invoice~post.

    invoice_handler->post( EXPORTING keys     = CORRESPONDING #( mapped-invoice )
                           CHANGING  result   = result
                                     mapped   = mapped_early
                                     failed   = failed_early
                                     reported = reported_early ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_supplierinvoice.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_supplierinvoice.

    invoice_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-invoice )
        requested_features = VALUE #( %update         = if_abap_behv=>mk-on
                                      %action-post    = if_abap_behv=>mk-on
                                      %action-release = if_abap_behv=>mk-on
                                      %action-reject  = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed_early
        reported           = reported_early ).
  ENDMETHOD.

  METHOD assert_message.
    DATA(messages) = VALUE string_table(
      FOR r IN reported-invoice WHERE ( %msg IS BOUND ) ( CONV string( r-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR i IN reported-item WHERE ( %msg IS BOUND ) ( CONV string( i-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR e IN reported_early-invoice WHERE ( %msg IS BOUND ) ( CONV string( e-%msg->if_t100_message~t100key-msgno ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MM { msgno } expected| ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_differs( act = lines( failed-invoice ) + lines( failed-item )
                                         exp = 0
                                         msg = 'Check should fail' ).
    assert_message( msgno ).
  ENDMETHOD.

  METHOD new_invoice_gets_defaults.
    DATA(invoice) = read_invoice( create_invoice( ) ).

    cl_abap_unit_assert=>assert_equals( act = invoice-Status exp = 'NEW' ).
    cl_abap_unit_assert=>assert_equals( act = invoice-InvoiceDate exp = cl_abap_context_info=>get_system_date( ) ).
    cl_abap_unit_assert=>assert_equals( act = invoice-Supplier exp = '1000000020' ).
    cl_abap_unit_assert=>assert_equals( act = invoice-Currency exp = 'EUR' ).
  ENDMETHOD.

  METHOD open_quantity_is_proposed.
    " 10,000 kg received minus 4,000 kg already invoiced; the hops were not received yet
    DATA(mapped) = create_invoice( ).

    READ ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Item ALL FIELDS WITH CORRESPONDING #( mapped-item )
      RESULT DATA(items).

    cl_abap_unit_assert=>assert_equals( act = lines( items ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-PurchaseOrderItem exp = '00010' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-Quantity exp = 6000 ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-NetPrice exp = '0.48' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-Item exp = '0001' ).
  ENDMETHOD.

  METHOD amount_is_calculated.
    " 6,000 kg x 0.48 EUR
    cl_abap_unit_assert=>assert_equals( act = read_invoice( create_invoice( ) )-TotalAmount exp = '2880.00' ).
  ENDMETHOD.

  METHOD unknown_order_fails.
    DATA(mapped) = create_invoice( purchase_order = orders-unknown ).

    invoice_handler->validateorder( EXPORTING keys     = CORRESPONDING #( mapped-invoice )
                                    CHANGING  failed   = failed
                                              reported = reported ).

    assert_error( '021' ).
  ENDMETHOD.

  METHOD order_not_sent_fails.
    DATA(mapped) = create_invoice( purchase_order = orders-not_ordered ).

    invoice_handler->validateorder( EXPORTING keys     = CORRESPONDING #( mapped-invoice )
                                    CHANGING  failed   = failed
                                              reported = reported ).

    assert_error( '022' ).
  ENDMETHOD.

  METHOD duplicate_reference_fails.
    DATA(mapped) = create_invoice( reference = 'RE-0001' ).

    invoice_handler->validatereference( EXPORTING keys     = CORRESPONDING #( mapped-invoice )
                                        CHANGING  failed   = failed
                                                  reported = reported ).

    assert_error( '025' ).
  ENDMETHOD.

  METHOD future_invoice_date_fails.
    DATA(mapped) = create_invoice( ).
    MODIFY ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Invoice
        UPDATE FIELDS ( InvoiceDate )
        WITH VALUE #( ( %tky = mapped-invoice[ 1 ]-%tky InvoiceDate = cl_abap_context_info=>get_system_date( ) + 1 ) ).

    invoice_handler->validatereference( EXPORTING keys     = CORRESPONDING #( mapped-invoice )
                                        CHANGING  failed   = failed
                                                  reported = reported ).

    assert_error( '026' ).
  ENDMETHOD.

  METHOD zero_quantity_fails.
    DATA(mapped) = create_invoice( ).
    MODIFY ENTITIES OF zvhb_r_supplierinvoice
      ENTITY Item
        UPDATE FIELDS ( Quantity )
        WITH VALUE #( ( %tky = mapped-item[ 1 ]-%tky Quantity = 0 ) ).

    item_handler->validateitem( EXPORTING keys     = CORRESPONDING #( mapped-item )
                                CHANGING  failed   = failed
                                          reported = reported ).

    assert_error( '027' ).
  ENDMETHOD.

  METHOD matching_invoice_is_posted.
    DATA(mapped) = create_invoice( ).

    post( mapped ).

    cl_abap_unit_assert=>assert_equals( act = read_invoice( mapped )-Status exp = 'POST' ).
    assert_message( '031' ).
  ENDMETHOD.

  METHOD price_deviation_blocks.
    DATA(mapped) = create_invoice( ).
    set_match_result( mapped = mapped result = 'PRIC' ).

    post( mapped ).

    cl_abap_unit_assert=>assert_equals( act = read_invoice( mapped )-Status exp = 'BLCK' ).
    assert_message( '032' ).
  ENDMETHOD.

  METHOD quantity_excess_blocks.
    DATA(mapped) = create_invoice( ).
    set_match_result( mapped = mapped result = 'QUAN' ).

    post( mapped ).

    cl_abap_unit_assert=>assert_equals( act = read_invoice( mapped )-Status exp = 'BLCK' ).
    assert_message( '033' ).
  ENDMETHOD.

  METHOD blocked_invoice_is_released.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_supplierinvoice\\invoice~release.
    DATA(mapped) = create_invoice( ).
    set_match_result( mapped = mapped result = 'PRIC' ).
    post( mapped ).

    DATA(features) = get_features( mapped ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-release exp = if_abap_behv=>fc-o-enabled ).

    invoice_handler->release( EXPORTING keys     = CORRESPONDING #( mapped-invoice )
                              CHANGING  result   = result
                                        mapped   = mapped_early
                                        failed   = failed_early
                                        reported = reported_early ).

    cl_abap_unit_assert=>assert_equals( act = read_invoice( mapped )-Status exp = 'POST' ).
    assert_message( '034' ).
  ENDMETHOD.

  METHOD posted_invoice_is_locked.
    DATA(mapped) = create_invoice( ).
    post( mapped ).

    DATA(features) = get_features( mapped ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%update exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-post exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-release exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

ENDCLASS.

