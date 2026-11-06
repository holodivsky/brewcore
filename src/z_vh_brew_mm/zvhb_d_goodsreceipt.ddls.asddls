@EndUserText.label: 'Goods Receipt'
define abstract entity ZVHB_D_GoodsReceipt
{
  @EndUserText.label: 'Received Quantity'
  Quantity       : abap.dec(13,3);

  @EndUserText.label: 'Production Date of the Batch'
  ProductionDate : abap.dats;
}
