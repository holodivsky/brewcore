@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Quality KPIs per supplier'
@Metadata.ignorePropagatedAnnotations: true
// FR-QM-04: usage decisions on raw material lots per supplier; lots still in inspection do not count
define view entity ZVHB_I_SupplierQualityKPI
  as select from zvhb_insplot
{
  key supplier                                        as Supplier,

      count( * )                                      as DecidedLotCount,

      sum( case status when 'REJ' then 1 else 0 end ) as RejectedLotCount
}
where
      origin = '01'
  and (
       status = 'ACC'
    or status = 'REJ'
  )
group by
  supplier
