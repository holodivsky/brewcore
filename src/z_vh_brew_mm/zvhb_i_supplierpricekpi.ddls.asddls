@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Price KPIs per supplier'
@Metadata.ignorePropagatedAnnotations: true
// Price deviation of all posted and blocked invoice items per supplier
define view entity ZVHB_I_SupplierPriceKPI
  as select from ZVHB_I_SupplierInvoiceMatch
{
  key Supplier,

      count( * )                         as InvoiceItemCount,

      sum( abs( PriceVariancePercent ) ) as PriceDeviationSum
}
where
     InvoiceStatus = 'POST'
  or InvoiceStatus = 'BLCK'
group by
  Supplier
