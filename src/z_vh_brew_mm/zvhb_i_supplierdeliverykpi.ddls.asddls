@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Delivery KPIs per supplier'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_I_SupplierDeliveryKPI
  as select from ZVHB_I_SupplierDelivery
{
  key Supplier,

      count( * )                                                         as DeliveryCount,

      sum( IsOnTime )                                                    as OnTimeCount,

      sum( IsDue )                                                       as DueCount,

      sum( case IsDue when 1 then QuantityDeviationPercent
                      else cast( 0 as abap.dec( 7, 2 ) ) end )           as QuantityDeviationSum
}
group by
  Supplier
