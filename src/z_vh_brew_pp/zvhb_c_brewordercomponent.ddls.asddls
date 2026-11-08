@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Brew Order Component'
@Metadata.allowExtensions: true
define view entity ZVHB_C_BrewOrderComponent
  as projection on ZVHB_R_BrewOrderComponent
{
  key BrewOrderUUID,

  key ComponentUUID,

      Item,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName as MaterialName,

      Plant,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_StorageLocVH', element: 'StorageLocation' } }]
      StorageLocation,

      Unit,
      Quantity,
      LocalLastChangedAt,

      _BrewOrder : redirected to parent ZVHB_C_BrewOrder,
      _Material
}
