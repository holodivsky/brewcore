@EndUserText.label: 'Goods Movement'
define abstract entity ZVHB_D_GoodsMovement
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MovementTypeVH', element: 'MovementType' } }]
  @EndUserText.label: 'Movement Type'
  MovementType      : zvhb_movement_type;

  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
  @EndUserText.label: 'Material'
  Material          : zvhb_material;

  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
  @EndUserText.label: 'Plant'
  Plant             : zvhb_plant;

  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_StorageLocVH', element: 'StorageLocation' } }]
  @EndUserText.label: 'Storage Location'
  StorageLocation   : zvhb_storage_loc;

  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_StorageLocVH', element: 'StorageLocation' } }]
  @EndUserText.label: 'Receiving Storage Location'
  ReceivingLocation : zvhb_storage_loc;

  @EndUserText.label: 'Batch (empty: new batch or FEFO)'
  Batch             : zvhb_batch;

  @EndUserText.label: 'Quantity in Base Unit'
  Quantity          : abap.dec(13,3);

  @EndUserText.label: 'Posting Date'
  PostingDate       : abap.dats;

  @EndUserText.label: 'Production Date of New Batch'
  ProductionDate    : abap.dats;

  @EndUserText.label: 'Text'
  HeaderText        : zvhb_description;

  @UI.hidden: true
  PurchaseOrder     : zvhb_purch_order;

  @UI.hidden: true
  PurchaseOrderItem : zvhb_po_item;

  @UI.hidden: true
  BrewOrder         : zvhb_brew_order;
}
