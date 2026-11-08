@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery Item'
@Metadata.allowExtensions: true
define view entity ZVHB_C_DeliveryItem
  as projection on ZVHB_R_DeliveryItem
{
  key DeliveryUUID,

  key ItemUUID,

      Item,
      OrderItem,
      ItemCategory,

      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName as MaterialName,

      Batch,

      @EndUserText.label: 'Best Before'
      _Batch.ExpiryDate      as ExpiryDate,

      Plant,
      StorageLocation,
      Unit,
      Quantity,
      LocalLastChangedAt,

      _Delivery : redirected to parent ZVHB_C_Delivery,
      _Material,
      _Batch
}
