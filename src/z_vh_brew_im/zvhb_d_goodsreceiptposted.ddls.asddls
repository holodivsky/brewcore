@EndUserText.label: 'Goods Receipt Posted'
// Payload of the event GoodsReceiptPosted: one material document item of a goods receipt (101) or its
// reversal (102) that refers to a purchase order or a brew order. Reversals carry the same reference,
// so consumers can take the quantity back.
define abstract entity ZVHB_D_GoodsReceiptPosted
{
  Item              : zvhb_matdoc_item;
  MovementType      : zvhb_movement_type;
  PurchaseOrder     : zvhb_purch_order;
  PurchaseOrderItem : zvhb_po_item;
  BrewOrder         : zvhb_brew_order;
  Material          : zvhb_material;
  Batch             : zvhb_batch;
  Plant             : zvhb_plant;
  StorageLocation   : zvhb_storage_loc;
  Unit              : zvhb_unit;
  Quantity          : abap.dec(13,3);
}
