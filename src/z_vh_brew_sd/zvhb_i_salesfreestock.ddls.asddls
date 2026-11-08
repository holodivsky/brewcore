@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Free stock for sales'
@Metadata.ignorePropagatedAnnotations: true
// Free, unexpired stock per material over all storage locations of the brewery
define view entity ZVHB_I_SalesFreeStock
  as select from ZVHB_I_Stock
{
  key Material,
      Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( FreeQuantity ) as FreeQuantity
}
where
      IsExpired = ' '
  and Plant     = 'BR01'
group by
  Material,
  Unit
