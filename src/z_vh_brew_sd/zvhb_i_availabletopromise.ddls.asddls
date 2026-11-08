@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Available to promise'
@Metadata.ignorePropagatedAnnotations: true
// FR-SD-02: what sales can still promise, free stock minus the quantities that open orders have confirmed
define view entity ZVHB_I_AvailableToPromise
  as select from         ZVHB_I_SalesFreeStock as Stock
    left outer to one join ZVHB_I_MaterialDemand as Demand on Demand.Material = Stock.Material
{
  key Stock.Material,
      Stock.Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Free Stock'
      Stock.FreeQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Confirmed for Orders'
      coalesce( Demand.ConfirmedQuantity, Stock.FreeQuantity - Stock.FreeQuantity )                      as ConfirmedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Available to Promise'
      Stock.FreeQuantity - coalesce( Demand.ConfirmedQuantity, Stock.FreeQuantity - Stock.FreeQuantity ) as AvailableQuantity
}
