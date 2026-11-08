@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Brew order component'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_BrewOrderComponent
  as select from zvhb_brewcmp

  association        to parent ZVHB_R_BrewOrder as _BrewOrder on $projection.BrewOrderUUID = _BrewOrder.BrewOrderUUID

  association [0..1] to ZVHB_I_MaterialVH        as _Material  on $projection.Material = _Material.Material
{
  key brew_uuid             as BrewOrderUUID,

  key component_uuid        as ComponentUUID,

      item                  as Item,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      plant                 as Plant,

      storage_location      as StorageLocation,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Quantity'
      quantity              as Quantity,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _BrewOrder,
      _Material
}
