@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Open requirements of brew orders'
@Metadata.ignorePropagatedAnnotations: true
// Raw materials that released brew orders will take when mashing starts; until then they are
// still in stock but no longer available for another brew
define view entity ZVHB_I_OpenRequirement
  as select from zvhb_brewcmp as Component
    inner join   zvhb_brewhdr as BrewOrder on BrewOrder.brew_uuid = Component.brew_uuid
{
  key Component.material         as Material,
  key Component.plant            as Plant,
  key Component.storage_location as StorageLocation,
      Component.unit             as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( Component.quantity )  as RequiredQuantity
}
where
  BrewOrder.status = 'REL'
group by
  Component.material,
  Component.plant,
  Component.storage_location,
  Component.unit
