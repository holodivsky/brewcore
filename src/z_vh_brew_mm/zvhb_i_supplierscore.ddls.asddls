@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Supplier score'
@Metadata.ignorePropagatedAnnotations: true
// Weighted supplier score 0 to 100: on time 40 %, quantity 30 %, price 20 %, quality 10 %
define view entity ZVHB_I_SupplierScore
  as select from ZVHB_I_SupplierRating
{
  key Supplier,
      SupplierName,
      City,
      Country,
      IsBlocked,
      DeliveryCount,
      OnTimeCount,
      InvoiceItemCount,
      AvgQuantityDeviation,
      AvgPriceDeviation,
      OnTimeScore,
      QuantityScore,
      PriceScore,
      QualityScore,

      cast( division( OnTimeScore * 4 + QuantityScore * 3 + PriceScore * 2 + QualityScore, 10, 1 ) as zvhb_score ) as Score
}
