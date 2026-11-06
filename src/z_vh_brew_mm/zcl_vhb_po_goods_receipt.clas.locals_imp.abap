*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS lhe_goods_receipt DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    CONSTANTS c_receipt_reversal TYPE zvhb_movement_type VALUE '102'.

    METHODS on_goods_receipt_posted FOR ENTITY EVENT receipts FOR MaterialDocument~GoodsReceiptPosted.
ENDCLASS.


CLASS lhe_goods_receipt IMPLEMENTATION.

  METHOD on_goods_receipt_posted.
    TYPES:
      BEGIN OF ty_reference,
        purchase_order TYPE zvhb_purch_order,
        item           TYPE zvhb_po_item,
      END OF ty_reference.
    DATA references TYPE STANDARD TABLE OF ty_reference WITH EMPTY KEY.
    DATA changes TYPE TABLE FOR ACTION IMPORT zvhb_r_purchaseorder\\item~applygoodsreceipt.

    references = VALUE #( FOR r IN receipts ( purchase_order = r-%param-PurchaseOrder item = r-%param-PurchaseOrderItem ) ).

    SELECT header~po_uuid, item~item_uuid, header~purchase_order, item~item
      FROM zvhb_pohdr AS header
        INNER JOIN zvhb_poitm AS item ON item~po_uuid = header~po_uuid
      FOR ALL ENTRIES IN @references
      WHERE header~purchase_order = @references-purchase_order
        AND item~item             = @references-item
      INTO TABLE @DATA(order_items).

    LOOP AT receipts INTO DATA(receipt).
      READ TABLE order_items INTO DATA(order_item) WITH KEY purchase_order = receipt-%param-PurchaseOrder
                                                            item           = receipt-%param-PurchaseOrderItem.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " A reversal of the goods receipt takes the quantity back
      APPEND VALUE #( PurchaseOrderUUID = order_item-po_uuid
                      ItemUUID          = order_item-item_uuid
                      %is_draft         = if_abap_behv=>mk-off
                      %param-Quantity   = COND #( WHEN receipt-%param-MovementType = c_receipt_reversal
                                                  THEN receipt-%param-Quantity * -1
                                                  ELSE receipt-%param-Quantity ) ) TO changes.
    ENDLOOP.

    IF changes IS INITIAL.
      RETURN.
    ENDIF.

    " The handler runs in its own transaction after the material document has been saved;
    " the framework commits it when the handler returns
    cl_abap_tx=>modify( ).
    MODIFY ENTITIES OF zvhb_r_purchaseorder
      ENTITY Item
        EXECUTE applyGoodsReceipt FROM changes.
    cl_abap_tx=>save( ).
  ENDMETHOD.

ENDCLASS.

