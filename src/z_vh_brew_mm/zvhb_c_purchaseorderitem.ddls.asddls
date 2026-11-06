@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Item'
@Metadata.allowExtensions: true
define view entity ZVHB_C_PurchaseOrderItem
  as projection on ZVHB_R_PurchaseOrderItem
{
  key PurchaseOrderUUID,

  key ItemUUID,

      Item,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName as MaterialName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      Plant,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_StorageLocVH', element: 'StorageLocation' } }]
      StorageLocation,

      Unit,
      Quantity,
      ReceivedQuantity,
      Currency,
      NetPrice,
      NetAmount,
      DeliveryDate,
      IsDelivered,
      RequisitionUUID,
      LocalLastChangedAt,

      _PurchaseOrder : redirected to parent ZVHB_C_PurchaseOrder,
      _Material
}
