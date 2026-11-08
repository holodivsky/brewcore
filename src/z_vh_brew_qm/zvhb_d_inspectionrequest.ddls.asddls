@EndUserText.label: 'Inspection Request'
// Parameter of the static action createFromGoodsReceipt: one goods receipt into a new batch, with the
// purchase order or the brew order it came from
define abstract entity ZVHB_D_InspectionRequest
{
  MaterialDocument : zvhb_matdoc;
  DocumentItem     : zvhb_matdoc_item;
  PurchaseOrder    : zvhb_purch_order;
  BrewOrder        : zvhb_brew_order;
  Material         : zvhb_material;
  Batch            : zvhb_batch;
  Plant            : zvhb_plant;
  StorageLocation  : zvhb_storage_loc;
  Unit             : zvhb_unit;
  Quantity         : abap.dec(13,3);
}
