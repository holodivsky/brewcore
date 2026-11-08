@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Stock available for production'
@Metadata.ignorePropagatedAnnotations: true
// Free stock that production may use: blocked and expired batches do not count
define view entity ZVHB_I_AvailableStock
  as select from ZVHB_I_Stock
{
  key Material,
  key Plant,
  key StorageLocation,
      Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( FreeQuantity ) as FreeQuantity
}
where
  IsExpired = ' '
group by
  Material,
  Plant,
  StorageLocation,
  Unit
