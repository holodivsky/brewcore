@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Empties balance per customer'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_I_EmptiesBalance
  as select from ZVHB_I_EmptiesMovement
{
  key Customer,
  key Material,
      Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( IssuedQuantity )                           as IssuedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( ReturnedQuantity )                         as ReturnedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( IssuedQuantity ) - sum( ReturnedQuantity ) as BalanceQuantity
}
group by
  Customer,
  Material,
  Unit
