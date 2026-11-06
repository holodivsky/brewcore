@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Supplier Score'
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.semanticKey: [ 'Supplier' ]
@Search.searchable: true
define view entity ZVHB_C_SupplierScore
  as select from ZVHB_I_SupplierScore
{
      @ObjectModel.text.element: [ 'SupplierName' ]
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Supplier'
  key Supplier,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'Supplier Name'
      SupplierName,

      @EndUserText.label: 'City'
      City,

      @EndUserText.label: 'Country'
      Country,

      @EndUserText.label: 'Blocked'
      IsBlocked,

      @EndUserText.label: 'Deliveries'
      @EndUserText.quickInfo: 'Order items with a goods receipt'
      DeliveryCount,

      @EndUserText.label: 'On Time Deliveries'
      OnTimeCount,

      @EndUserText.label: 'Invoice Items'
      @EndUserText.quickInfo: 'Items of posted and blocked invoices'
      InvoiceItemCount,

      @EndUserText.label: 'Quantity Deviation %'
      @EndUserText.quickInfo: 'Average deviation of the received from the ordered quantity'
      AvgQuantityDeviation,

      @EndUserText.label: 'Price Deviation %'
      @EndUserText.quickInfo: 'Average deviation of the invoiced from the ordered price'
      AvgPriceDeviation,

      @EndUserText.label: 'On Time'
      @EndUserText.quickInfo: 'On time score, weight 40 %'
      OnTimeScore,

      @EndUserText.label: 'Quantity'
      @EndUserText.quickInfo: 'Quantity score, weight 30 %'
      QuantityScore,

      @EndUserText.label: 'Price'
      @EndUserText.quickInfo: 'Price score, weight 20 %'
      PriceScore,

      @EndUserText.label: 'Quality'
      @EndUserText.quickInfo: 'Quality score, weight 10 %'
      QualityScore,

      @EndUserText.label: 'Score'
      Score,

      // A from 80, B from 60, C below
      @EndUserText.label: 'Rating'
      cast( case when Score >= 80 then 'A'
                 when Score >= 60 then 'B'
                 else 'C' end as abap.char( 1 ) ) as Rating,

      case when Score >= 80 then 3
           when Score >= 60 then 2
           else 1 end                             as ScoreCriticality
}
