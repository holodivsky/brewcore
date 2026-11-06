@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Supplier Invoice Item'
@Metadata.allowExtensions: true
define view entity ZVHB_C_SupplierInvoiceItem
  as projection on ZVHB_R_SupplierInvoiceItem
{
  key InvoiceUUID,

  key ItemUUID,

      Item,
      OrderItemUUID,

      @EndUserText.label: 'Purchase Order'
      PurchaseOrder,

      @EndUserText.label: 'PO Item'
      PurchaseOrderItem,

      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName       as MaterialName,

      Unit,
      Quantity,
      Currency,
      NetPrice,
      NetAmount,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Order Price per Unit'
      _OrderItem.NetPrice          as OrderNetPrice,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Received Quantity'
      _OrderItem.ReceivedQuantity  as ReceivedQuantity,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VHB_INVOICE_ITEM_MATCH'
      @EndUserText.label: 'Price Deviation (%)'
      virtual PriceVariance    : zvhb_percent,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VHB_INVOICE_ITEM_MATCH'
      @EndUserText.label: '3-Way Match'
      virtual MatchText        : abap.char( 80 ),

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VHB_INVOICE_ITEM_MATCH'
      virtual MatchCriticality : abap.int1,

      LocalLastChangedAt,

      _Invoice : redirected to parent ZVHB_C_SupplierInvoice,
      _Material
}
