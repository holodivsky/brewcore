*"* use this source file for your ABAP unit test classes

"! FR-IM-05: which materials are below their reorder point and how much is ordered. Materials, plant data,
"! stock, requisitions and purchase orders are replaced by SQL test doubles. Creating the requisition goes
"! through the requisition business object and is checked with the job run.
CLASS ltc_reorder_job DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES tt_materials TYPE STANDARD TABLE OF zvhb_mat WITH EMPTY KEY.
    TYPES tt_plant_data TYPE STANDARD TABLE OF zvhb_matplnt WITH EMPTY KEY.
    TYPES tt_stock TYPE STANDARD TABLE OF zvhb_i_stock WITH EMPTY KEY.
    TYPES tt_requisitions TYPE STANDARD TABLE OF zvhb_preq WITH EMPTY KEY.
    TYPES tt_order_items TYPE STANDARD TABLE OF zvhb_poitm WITH EMPTY KEY.
    TYPES tt_orders TYPE STANDARD TABLE OF zvhb_pohdr WITH EMPTY KEY.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.
    DATA cut TYPE REF TO zcl_vhb_reorder_job.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS low_stock_is_proposed FOR TESTING.
    METHODS enough_stock_is_skipped FOR TESTING.
    METHODS expired_stock_does_not_count FOR TESTING.
    METHODS open_requisition_is_named FOR TESTING.
    METHODS open_order_is_named FOR TESTING.
    METHODS products_are_not_bought FOR TESTING.
ENDCLASS.


CLASS ltc_reorder_job IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZVHB_MAT' )
                                                                                     ( 'ZVHB_MATPLNT' )
                                                                                     ( 'ZVHB_I_STOCK' )
                                                                                     ( 'ZVHB_PREQ' )
                                                                                     ( 'ZVHB_POITM' )
                                                                                     ( 'ZVHB_POHDR' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_environment->clear_doubles( ).
    cut = NEW #( ).

    " Yeast: reorder point 60 kg; malt: reorder point 5,000 kg
    sql_environment->insert_test_data( VALUE tt_materials(
      ( material = 'YEAST-W34' material_type = 'ROH' base_unit = 'KG' is_active = abap_true )
      ( material = 'MALT-PILS' material_type = 'ROH' base_unit = 'KG' is_active = abap_true )
      ( material = 'PILS-BTL05' material_type = 'FERT' base_unit = 'ST' is_active = abap_true ) ) ).
    sql_environment->insert_test_data( VALUE tt_plant_data(
      ( material = 'YEAST-W34' plant = 'BR01' base_unit = 'KG' min_stock = 20 reorder_point = 60 )
      ( material = 'MALT-PILS' plant = 'BR01' base_unit = 'KG' min_stock = 2000 reorder_point = 5000 )
      ( material = 'PILS-BTL05' plant = 'BR01' base_unit = 'ST' reorder_point = 1000 ) ) ).
    sql_environment->insert_test_data( VALUE tt_stock(
      ( Material = 'YEAST-W34' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000001' Unit = 'KG'
        FreeQuantity = 20 TotalQuantity = 20 IsExpired = ' ' )
      ( Material = 'MALT-PILS' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000002' Unit = 'KG'
        FreeQuantity = 12000 TotalQuantity = 12000 IsExpired = ' ' ) ) ).
  ENDMETHOD.

  METHOD low_stock_is_proposed.
    DATA(proposals) = cut->plan( 'BR01' ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( proposals ) ).
    DATA(yeast) = proposals[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = 'YEAST-W34' act = yeast-material ).
    cl_abap_unit_assert=>assert_equals( exp = 20 act = yeast-free_quantity ).
    " Topped up to twice the reorder point: 2 x 60 - 20
    cl_abap_unit_assert=>assert_equals( exp = 100 act = yeast-quantity ).
    cl_abap_unit_assert=>assert_equals( exp = 'RM01' act = yeast-storage_location ).
    cl_abap_unit_assert=>assert_initial( yeast-open_document ).
  ENDMETHOD.

  METHOD enough_stock_is_skipped.
    DATA(proposals) = cut->plan( 'BR01' ).

    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( proposals[ material = 'MALT-PILS' ] ) ) ).
  ENDMETHOD.

  METHOD expired_stock_does_not_count.
    sql_environment->insert_test_data( VALUE tt_stock(
      ( Material = 'YEAST-W34' Plant = 'BR01' StorageLocation = 'RM01' Batch = '2000000003' Unit = 'KG'
        FreeQuantity = 100 TotalQuantity = 100 IsExpired = 'X' ) ) ).

    DATA(proposals) = cut->plan( 'BR01' ).

    cl_abap_unit_assert=>assert_equals( exp = 20 act = proposals[ material = 'YEAST-W34' ]-free_quantity ).
  ENDMETHOD.

  METHOD open_requisition_is_named.
    sql_environment->insert_test_data( VALUE tt_requisitions(
      ( preq_uuid = 'A0000000000000000000000000000001' purchase_requisition = '1100000005' material = 'YEAST-W34'
        plant = 'BR01' status = 'NEW' ) ) ).

    DATA(proposals) = cut->plan( 'BR01' ).

    cl_abap_unit_assert=>assert_equals( exp = '1100000005' act = proposals[ material = 'YEAST-W34' ]-open_document ).
  ENDMETHOD.

  METHOD open_order_is_named.
    sql_environment->insert_test_data( VALUE tt_orders(
      ( po_uuid = 'B0000000000000000000000000000001' purchase_order = '4500000009' status = 'ORDR' ) ) ).
    sql_environment->insert_test_data( VALUE tt_order_items(
      ( po_uuid = 'B0000000000000000000000000000001' item_uuid = 'C0000000000000000000000000000001'
        material = 'YEAST-W34' plant = 'BR01' quantity = 100 ) ) ).

    DATA(proposals) = cut->plan( 'BR01' ).

    cl_abap_unit_assert=>assert_equals( exp = '4500000009' act = proposals[ material = 'YEAST-W34' ]-open_document ).
  ENDMETHOD.

  METHOD products_are_not_bought.
    DATA(proposals) = cut->plan( 'BR01' ).

    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( proposals[ material = 'PILS-BTL05' ] ) ) ).
  ENDMETHOD.

ENDCLASS.

