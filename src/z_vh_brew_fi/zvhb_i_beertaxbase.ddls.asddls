@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Beer tax base by month'
@Metadata.ignorePropagatedAnnotations: true
// Hectoliters per plant, month, material, tax class and treatment: the lines of the monthly declaration
define view entity ZVHB_I_BeerTaxBase
  as select from ZVHB_I_BeerTaxBaseItem
{
  key Plant,
  key PeriodYear,
  key PeriodMonth,
  key Material,
  key TaxClass,
  key Treatment,
      sum( QuantityHL ) as QuantityHL,
      count( * )        as DeliveryItems
}
group by
  Plant,
  PeriodYear,
  PeriodMonth,
  Material,
  TaxClass,
  Treatment
