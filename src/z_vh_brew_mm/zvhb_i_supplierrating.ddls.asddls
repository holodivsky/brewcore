@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Supplier rating criteria'
@Metadata.ignorePropagatedAnnotations: true
// The four criteria of the supplier score, each from 0 to 100. A criterion without data
// counts as fulfilled, so a new supplier starts at 100 and loses points with every problem.
define view entity ZVHB_I_SupplierRating
  as select from         ZVHB_I_SupplierVH          as Supplier
    left outer to one join ZVHB_I_SupplierDeliveryKPI as Delivery on Delivery.Supplier = Supplier.Supplier
    left outer to one join ZVHB_I_SupplierPriceKPI    as Price    on Price.Supplier = Supplier.Supplier
{
  key Supplier.Supplier,
      Supplier.SupplierName,
      Supplier.City,
      Supplier.Country,
      Supplier.IsBlocked,

      coalesce( Delivery.DeliveryCount, 0 )    as DeliveryCount,
      coalesce( Delivery.OnTimeCount, 0 )      as OnTimeCount,
      coalesce( Price.InvoiceItemCount, 0 )    as InvoiceItemCount,

      case when Delivery.DueCount > 0
           then cast( division( Delivery.QuantityDeviationSum, Delivery.DueCount, 2 ) as abap.dec( 7, 2 ) )
           else cast( 0 as abap.dec( 7, 2 ) )
      end                                      as AvgQuantityDeviation,

      case when Price.InvoiceItemCount > 0
           then cast( division( Price.PriceDeviationSum, Price.InvoiceItemCount, 2 ) as abap.dec( 7, 2 ) )
           else cast( 0 as abap.dec( 7, 2 ) )
      end                                      as AvgPriceDeviation,

      // Share of deliveries that arrived on time
      case when Delivery.DeliveryCount > 0
           then cast( division( Delivery.OnTimeCount * 100, Delivery.DeliveryCount, 1 ) as zvhb_score )
           else cast( 100 as zvhb_score )
      end                                      as OnTimeScore,

      // Every percent of quantity deviation costs one point
      case when Delivery.DueCount > 0
           then case when division( Delivery.QuantityDeviationSum, Delivery.DueCount, 1 ) >= 100
                     then cast( 0 as zvhb_score )
                     else cast( 100 - division( Delivery.QuantityDeviationSum, Delivery.DueCount, 1 ) as zvhb_score )
                end
           else cast( 100 as zvhb_score )
      end                                      as QuantityScore,

      // Every percent of price deviation costs ten points
      case when Price.InvoiceItemCount > 0
           then case when division( Price.PriceDeviationSum, Price.InvoiceItemCount, 2 ) >= 10
                     then cast( 0 as zvhb_score )
                     else cast( 100 - division( Price.PriceDeviationSum, Price.InvoiceItemCount, 2 ) * 10 as zvhb_score )
                end
           else cast( 100 as zvhb_score )
      end                                      as PriceScore,

      // Inspection results follow with quality management in v0.8
      cast( 100 as zvhb_score )                as QualityScore
}
