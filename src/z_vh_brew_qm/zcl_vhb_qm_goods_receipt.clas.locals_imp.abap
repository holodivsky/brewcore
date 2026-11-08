*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS lhe_goods_receipt DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    CONSTANTS c_goods_receipt TYPE zvhb_movement_type VALUE '101'.

    METHODS on_goods_receipt_posted FOR ENTITY EVENT receipts FOR MaterialDocument~GoodsReceiptPosted.
ENDCLASS.


CLASS lhe_goods_receipt IMPLEMENTATION.

  METHOD on_goods_receipt_posted.
    DATA requests TYPE TABLE FOR ACTION IMPORT zvhb_r_inspectionlot\\inspectionlot~createfromgoodsreceipt.

    " Only receipts into a batch open a lot; the inspection lot decides whether the batch needs one
    requests = VALUE #( FOR r IN receipts INDEX INTO i
                        WHERE ( %param-MovementType = c_goods_receipt AND %param-Batch IS NOT INITIAL )
                        ( %cid   = |RECEIPT{ i }|
                          %param = VALUE #( MaterialDocument = r-MaterialDocument
                                            DocumentItem     = r-%param-Item
                                            PurchaseOrder    = r-%param-PurchaseOrder
                                            BrewOrder        = r-%param-BrewOrder
                                            Material         = r-%param-Material
                                            Batch            = r-%param-Batch
                                            Plant            = r-%param-Plant
                                            StorageLocation  = r-%param-StorageLocation
                                            Unit             = r-%param-Unit
                                            Quantity         = r-%param-Quantity ) ) ).
    IF requests IS INITIAL.
      RETURN.
    ENDIF.

    " The handler runs in its own transaction after the material document has been saved
    cl_abap_tx=>modify( ).
    MODIFY ENTITIES OF zvhb_r_inspectionlot
      ENTITY InspectionLot
        EXECUTE createFromGoodsReceipt FROM requests.
    cl_abap_tx=>save( ).
  ENDMETHOD.

ENDCLASS.

