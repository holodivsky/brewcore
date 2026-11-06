@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: 3-way match of supplier invoices'
@Metadata.ignorePropagatedAnnotations: true
// 3-way match result per invoice item. The price may deviate by 2 % from the order;
// the quantity of all invoices together may not exceed the received quantity.
define view entity ZVHB_I_SupplierInvoiceMatch
  as select from ZVHB_I_InvoiceItemFigures
{
  key InvoiceUUID,
  key ItemUUID,
      SupplierInvoice,
      Supplier,
      InvoiceStatus,
      InvoiceDate,
      Item,
      PurchaseOrder,
      PurchaseOrderItem,
      Material,
      Unit,
      Currency,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      InvoicedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      ReceivedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      OtherInvoicedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      InvoicedQuantity + OtherInvoicedQuantity - ReceivedQuantity as QuantityExcess,

      @Semantics.amount.currencyCode: 'Currency'
      InvoicePrice,

      @Semantics.amount.currencyCode: 'Currency'
      OrderPrice,

      PriceVariancePercent,

      case when abs( PriceVariancePercent ) > 2
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean )
      end                                                         as IsPriceBlocked,

      case when InvoicedQuantity + OtherInvoicedQuantity > ReceivedQuantity
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean )
      end                                                         as IsQuantityBlocked,

      // PRIC: price outside the tolerance, QUAN: more invoiced than received, OK: payment can be released
      case when abs( PriceVariancePercent ) > 2                       then cast( 'PRIC' as abap.char( 4 ) )
           when InvoicedQuantity + OtherInvoicedQuantity > ReceivedQuantity then cast( 'QUAN' as abap.char( 4 ) )
           else cast( 'OK' as abap.char( 4 ) )
      end                                                         as MatchResult
}
