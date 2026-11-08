@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Confirmed demand per material'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_I_MaterialDemand
  as select from ZVHB_I_OrderDemand
{
  key Material,
      Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( ConfirmedQuantity ) as ConfirmedQuantity
}
group by
  Material,
  Unit
