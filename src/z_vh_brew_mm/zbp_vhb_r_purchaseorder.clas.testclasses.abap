*"* use this source file for your ABAP unit test classes

"! Defaults, amounts, approval, goods receipt and the requisition reference of the purchase order.
"! The transactional buffers and the master data views are replaced by test doubles.
CLASS ltc_purchase_order DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_purchaseorder.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_purchaseorder.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_purchaseorder.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_purchaseorder\\purchaseorder.
    TYPES tt_materials    TYPE STANDARD TABLE OF zvhb_r_material WITH EMPTY KEY.
    TYPES tt_suppliers    TYPE STANDARD TABLE OF zvhb_i_suppliervh WITH EMPTY KEY.
    TYPES tt_requisitions TYPE STANDARD TABLE OF zvhb_preq WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_line,
        material TYPE zvhb_material,
        quantity TYPE zvhb_quantity,
        price    TYPE zvhb_amount,
      END OF ty_line,
      tt_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    CLASS-DATA environment     TYPE REF TO if_botd_txbufdbl_bo_test_env.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA order_handler TYPE REF TO lhc_purchase_order.
    DATA item_handler  TYPE REF TO lhc_item.
    DATA failed        TYPE ty_failed.
    DATA reported      TYPE ty_reported.

    "! Responses of actions, which report in the interaction phase
    DATA mapped_early   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_purchaseorder.
    DATA failed_early   TYPE RESPONSE FOR FAILED EARLY zvhb_r_purchaseorder.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_purchaseorder.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS new_order_gets_defaults FOR TESTING.
    METHODS supplier_terms_are_copied FOR TESTING.
    METHODS missing_supplier_fails FOR TESTING.
    METHODS order_without_items_fails FOR TESTING.
    METHODS items_numbered_in_tens FOR TESTING.
    METHODS amounts_are_calculated FOR TESTING.
    METHODS zero_price_fails FOR TESTING.
    METHODS small_order_is_ordered FOR TESTING.
    METHODS large_order_waits_approval FOR TESTING.
    METHODS waiting_order_can_be_approved FOR TESTING.
    METHODS rejected_order_is_final FOR TESTING.
    METHODS ordered_order_is_locked FOR TESTING.
    METHODS receipt_needs_ordered_po FOR TESTING.
    METHODS over_delivery_fails FOR TESTING.
    METHODS full_receipt_completes_order FOR TESTING.
    METHODS partial_receipt_stays_open FOR TESTING.
    METHODS unapproved_requisition_fails FOR TESTING.
    METHODS ordered_requisition_fails FOR TESTING.

    "! Order for supplier 1000000020 with the given items; determinations are run as in the app
    METHODS create_order
      IMPORTING
        supplier      TYPE zvhb_partner DEFAULT '1000000020'
        lines         TYPE tt_lines OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_mapped.

    "! 1,000 kg malt at 0.50 EUR = 500 EUR, below the approval limit
    METHODS small_order
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS read_order
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE zvhb_r_purchaseorder.

    METHODS execute_order
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.

    METHODS apply_receipt
      IMPORTING
        mapped   TYPE ty_mapped
        quantity TYPE zvhb_quantity.

    METHODS receive
      IMPORTING
        mapped   TYPE ty_mapped
        quantity TYPE zvhb_quantity.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_purchase_order IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_PURCHASEORDER' )
                                                                                    ( 'ZVHB_R_PURCHASEREQUISITION' ) ) ) ).
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_R_MATERIAL' )
                                                                                     ( 'ZVHB_I_SUPPLIERVH' )
                                                                                     ( 'ZVHB_R_BUSINESSPARTNER' )
                                                                                     ( 'ZVHB_PREQ' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).

    DATA(materials) = VALUE tt_materials(
      ( Material = 'MALT-PILS' MaterialType = 'ROH' BaseUnit = 'KG' IsActive = abap_true )
      ( Material = 'HOPS-HALL' MaterialType = 'ROH' BaseUnit = 'KG' IsActive = abap_true ) ).
    sql_environment->insert_test_data( materials ).

    DATA(suppliers) = VALUE tt_suppliers(
      ( Supplier = '1000000020' SupplierName = 'Maltings' Currency = 'EUR' PaymentTerms = 'NT14' ) ).
    sql_environment->insert_test_data( suppliers ).

    DATA(requisitions) = VALUE tt_requisitions(
      ( preq_uuid = '0A0B0C0D0E0F10111213141516171819' purchase_requisition = '0010000001' status = 'NEW' )
      ( preq_uuid = '1A1B1C1D1E1F20212223242526272829' purchase_requisition = '0010000002' status = 'ORDR' ) ).
    sql_environment->insert_test_data( requisitions ).

    CREATE OBJECT order_handler FOR TESTING.
    CREATE OBJECT item_handler FOR TESTING.
    CLEAR: failed, reported, mapped_early, failed_early, reported_early.
  ENDMETHOD.

  METHOD create_order.
    MODIFY ENTITIES OF zvhb_r_purchaseorder
      ENTITY PurchaseOrder
        CREATE FIELDS ( Supplier )
        WITH VALUE #( ( %cid = 'PO' Supplier = supplier ) )
        CREATE BY \_Item
        FIELDS ( Material Quantity NetPrice )
        WITH VALUE #( ( %cid_ref = 'PO'
                        %target  = VALUE #( FOR line IN lines INDEX INTO i
                                            ( %cid     = |ITEM{ i }|
                                              Material = line-material
                                              Quantity = line-quantity
                                              NetPrice = line-price ) ) ) )
      MAPPED result.

    order_handler->setdefaults( keys = CORRESPONDING #( result-purchaseorder ) ).
    order_handler->copysupplierterms( keys = CORRESPONDING #( result-purchaseorder ) ).
    IF result-item IS NOT INITIAL.
      item_handler->setitemdefaults( keys = CORRESPONDING #( result-item ) ).
      item_handler->setunit( keys = CORRESPONDING #( result-item ) ).
      item_handler->calculateamount( keys = CORRESPONDING #( result-item ) ).
    ENDIF.
  ENDMETHOD.

  METHOD small_order.
    result = create_order( lines = VALUE #( ( material = 'MALT-PILS' quantity = 1000 price = '0.50' ) ) ).
  ENDMETHOD.

  METHOD read_order.
    READ ENTITIES OF zvhb_r_purchaseorder
      ENTITY PurchaseOrder ALL FIELDS WITH CORRESPONDING #( mapped-purchaseorder )
      RESULT DATA(orders).
    result = CORRESPONDING #( orders[ 1 ] ).
  ENDMETHOD.

  METHOD execute_order.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_purchaseorder\\purchaseorder~order.

    order_handler->order( EXPORTING keys     = CORRESPONDING #( mapped-purchaseorder )
                          CHANGING  result   = result
                                    mapped   = mapped_early
                                    failed   = failed_early
                                    reported = reported_early ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_purchaseorder.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_purchaseorder.

    order_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-purchaseorder )
        requested_features = VALUE #( %update         = if_abap_behv=>mk-on
                                      %action-order   = if_abap_behv=>mk-on
                                      %action-approve = if_abap_behv=>mk-on
                                      %action-reject  = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed_early
        reported           = reported_early ).
  ENDMETHOD.

  METHOD apply_receipt.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_purchaseorder\\item~applygoodsreceipt.

    item_handler->applygoodsreceipt(
      EXPORTING keys     = VALUE #( FOR i IN mapped-item ( %tky = i-%tky %param-Quantity = quantity ) )
      CHANGING  result   = result
                mapped   = mapped_early
                failed   = failed_early
                reported = reported_early ).
  ENDMETHOD.

  METHOD receive.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_purchaseorder\\item~receivegoods.

    item_handler->receivegoods(
      EXPORTING keys     = VALUE #( FOR i IN mapped-item ( %tky = i-%tky %param-Quantity = quantity ) )
      CHANGING  result   = result
                mapped   = mapped_early
                failed   = failed_early
                reported = reported_early ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_differs( act = lines( failed-purchaseorder ) + lines( failed-item )
                                             + lines( failed_early-purchaseorder ) + lines( failed_early-item )
                                         exp = 0
                                         msg = 'Check should fail' ).

    DATA(messages) = VALUE string_table(
      FOR o IN reported-purchaseorder WHERE ( %msg IS BOUND ) ( CONV string( o-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR i IN reported-item WHERE ( %msg IS BOUND ) ( CONV string( i-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR eo IN reported_early-purchaseorder WHERE ( %msg IS BOUND )
      ( CONV string( eo-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR ei IN reported_early-item WHERE ( %msg IS BOUND ) ( CONV string( ei-%msg->if_t100_message~t100key-msgno ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MM { msgno } expected| ).
  ENDMETHOD.

  METHOD new_order_gets_defaults.
    DATA(order) = read_order( small_order( ) ).

    cl_abap_unit_assert=>assert_equals( act = order-Status exp = 'NEW' ).
    cl_abap_unit_assert=>assert_equals( act = order-Currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = order-OrderDate exp = cl_abap_context_info=>get_system_date( ) ).
  ENDMETHOD.

  METHOD supplier_terms_are_copied.
    cl_abap_unit_assert=>assert_equals( act = read_order( small_order( ) )-PaymentTerms exp = 'NT14' ).
  ENDMETHOD.

  METHOD missing_supplier_fails.
    DATA(mapped) = create_order( supplier = '' ).

    order_handler->validatesupplier( EXPORTING keys = CORRESPONDING #( mapped-purchaseorder ) CHANGING failed = failed reported = reported ).

    assert_error( '008' ).
  ENDMETHOD.

  METHOD order_without_items_fails.
    DATA(mapped) = create_order( ).

    order_handler->validateitems( EXPORTING keys = CORRESPONDING #( mapped-purchaseorder ) CHANGING failed = failed reported = reported ).

    assert_error( '013' ).
  ENDMETHOD.

  METHOD items_numbered_in_tens.
    DATA(mapped) = create_order( lines = VALUE #( ( material = 'MALT-PILS' quantity = 1000 price = '0.50' )
                                                  ( material = 'HOPS-HALL' quantity = 20 price = '18.00' ) ) ).

    READ ENTITIES OF zvhb_r_purchaseorder
      ENTITY Item FIELDS ( Item Unit ) WITH CORRESPONDING #( mapped-item )
      RESULT DATA(items).
    SORT items BY Item.
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-Item exp = '00010' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 2 ]-Item exp = '00020' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-Unit exp = 'KG' ).
  ENDMETHOD.

  METHOD amounts_are_calculated.
    " 1,000 x 0.50 + 20 x 18.00 = 860.00
    DATA(mapped) = create_order( lines = VALUE #( ( material = 'MALT-PILS' quantity = 1000 price = '0.50' )
                                                  ( material = 'HOPS-HALL' quantity = 20 price = '18.00' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = read_order( mapped )-TotalAmount exp = '860.00' ).
  ENDMETHOD.

  METHOD zero_price_fails.
    DATA(mapped) = create_order( lines = VALUE #( ( material = 'MALT-PILS' quantity = 1000 price = 0 ) ) ).

    item_handler->validateitem( EXPORTING keys = CORRESPONDING #( mapped-item ) CHANGING failed = failed reported = reported ).

    assert_error( '011' ).
  ENDMETHOD.

  METHOD small_order_is_ordered.
    DATA(mapped) = small_order( ).

    execute_order( mapped ).

    cl_abap_unit_assert=>assert_equals( act = read_order( mapped )-Status exp = 'ORDR' ).
  ENDMETHOD.

  METHOD large_order_waits_approval.
    " 25,000 kg malt at 0.48 EUR = 12,000 EUR, above the approval limit of 10,000 EUR
    DATA(mapped) = create_order( lines = VALUE #( ( material = 'MALT-PILS' quantity = 25000 price = '0.48' ) ) ).

    execute_order( mapped ).

    cl_abap_unit_assert=>assert_equals( act = read_order( mapped )-Status exp = 'WAIT' ).
    cl_abap_unit_assert=>assert_equals( act = reported_early-purchaseorder[ 1 ]-%msg->if_t100_message~t100key-msgno
                                        exp = '020' ).
  ENDMETHOD.

  METHOD waiting_order_can_be_approved.
    DATA(mapped) = create_order( lines = VALUE #( ( material = 'MALT-PILS' quantity = 25000 price = '0.48' ) ) ).
    execute_order( mapped ).

    DATA(features) = get_features( mapped ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-approve exp = if_abap_behv=>fc-o-enabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-reject exp = if_abap_behv=>fc-o-enabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-order exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

  METHOD rejected_order_is_final.
    DATA result TYPE TABLE FOR ACTION RESULT zvhb_r_purchaseorder\\purchaseorder~reject.
    DATA(mapped) = create_order( lines = VALUE #( ( material = 'MALT-PILS' quantity = 25000 price = '0.48' ) ) ).
    execute_order( mapped ).

    order_handler->reject( EXPORTING keys     = CORRESPONDING #( mapped-purchaseorder )
                           CHANGING  result   = result
                                     mapped   = mapped_early
                                     failed   = failed_early
                                     reported = reported_early ).

    cl_abap_unit_assert=>assert_equals( act = result[ 1 ]-%param-Status exp = 'REJ' ).
    DATA(features) = get_features( mapped ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-approve exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%update exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

  METHOD ordered_order_is_locked.
    DATA(mapped) = small_order( ).
    execute_order( mapped ).

    DATA(features) = get_features( mapped ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%update exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-order exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

  METHOD receipt_needs_ordered_po.
    receive( mapped = small_order( ) quantity = 100 ).

    assert_error( '019' ).
  ENDMETHOD.

  METHOD over_delivery_fails.
    DATA(mapped) = small_order( ).
    execute_order( mapped ).

    receive( mapped = mapped quantity = 1500 ).

    assert_error( '018' ).
  ENDMETHOD.

  METHOD full_receipt_completes_order.
    DATA(mapped) = small_order( ).
    execute_order( mapped ).

    apply_receipt( mapped = mapped quantity = 1000 ).

    READ ENTITIES OF zvhb_r_purchaseorder
      ENTITY Item FIELDS ( ReceivedQuantity IsDelivered ) WITH CORRESPONDING #( mapped-item )
      RESULT DATA(items).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-ReceivedQuantity exp = 1000 ).
    cl_abap_unit_assert=>assert_true( items[ 1 ]-IsDelivered ).
    cl_abap_unit_assert=>assert_equals( act = read_order( mapped )-Status exp = 'DONE' ).
  ENDMETHOD.

  METHOD partial_receipt_stays_open.
    DATA(mapped) = small_order( ).
    execute_order( mapped ).

    apply_receipt( mapped = mapped quantity = 400 ).

    cl_abap_unit_assert=>assert_equals( act = read_order( mapped )-Status exp = 'ORDR' ).
  ENDMETHOD.

  METHOD unapproved_requisition_fails.
    order_handler->createfromrequisition(
      EXPORTING keys     = VALUE #( ( %cid = 'NEW' %param-PurchaseRequisition = '0010000001' %param-NetPrice = '0.50' ) )
      CHANGING  mapped   = mapped_early
                failed   = failed_early
                reported = reported_early ).

    assert_error( '015' ).
  ENDMETHOD.

  METHOD ordered_requisition_fails.
    order_handler->createfromrequisition(
      EXPORTING keys     = VALUE #( ( %cid = 'NEW' %param-PurchaseRequisition = '0010000002' %param-NetPrice = '0.50' ) )
      CHANGING  mapped   = mapped_early
                failed   = failed_early
                reported = reported_early ).

    assert_error( '016' ).
  ENDMETHOD.

ENDCLASS.

