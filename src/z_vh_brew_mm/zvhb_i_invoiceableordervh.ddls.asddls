@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order to Invoice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
// Purchase orders a supplier can invoice: sent to the supplier or completely delivered
define view entity ZVHB_I_InvoiceableOrderVH
  as select from zvhb_pohdr

  association [0..1] to ZVHB_I_SupplierVH as _Supplier on $projection.Supplier = _Supplier.Supplier
  association [0..1] to ZVHB_I_POStatusVH as _Status   on $projection.Status = _Status.Status
{
      @Search.defaultSearchElement: true
  key purchase_order          as PurchaseOrder,

      @ObjectModel.text.element: [ 'SupplierName' ]
      @EndUserText.label: 'Supplier'
      supplier                as Supplier,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'Supplier Name'
      _Supplier.SupplierName  as SupplierName,

      @EndUserText.label: 'Order Date'
      order_date              as OrderDate,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Total Net Amount'
      total_amount            as TotalAmount,

      currency                as Currency,

      @ObjectModel.text.element: [ 'StatusName' ]
      status                  as Status,

      @EndUserText.label: 'Status'
      _Status.StatusName      as StatusName,

      _Supplier,
      _Status
}
where
     status = 'ORDR'
  or status = 'DONE'
