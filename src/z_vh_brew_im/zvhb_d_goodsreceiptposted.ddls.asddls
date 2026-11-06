@EndUserText.label: 'Goods Receipt Posted'
// Payload of the event GoodsReceiptPosted: one material document item with a purchase order reference.
// Reversals (102) carry the same reference, so consumers can take the quantity back.
define abstract entity ZVHB_D_GoodsReceiptPosted
{
  Item              : zvhb_matdoc_item;
  MovementType      : zvhb_movement_type;
  PurchaseOrder     : zvhb_purch_order;
  PurchaseOrderItem : zvhb_po_item;
  Material          : zvhb_material;
  Batch             : zvhb_batch;
  Quantity          : abap.dec(13,3);
}
