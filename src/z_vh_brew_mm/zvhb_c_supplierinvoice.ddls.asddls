@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Supplier Invoice'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'SupplierInvoice' ]
@Search.searchable: true
define root view entity ZVHB_C_SupplierInvoice
  provider contract transactional_query
  as projection on ZVHB_R_SupplierInvoice
{
  key InvoiceUUID,

      @Search.defaultSearchElement: true
      SupplierInvoice,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_InvoiceableOrderVH', element: 'PurchaseOrder' } }]
      @Search.defaultSearchElement: true
      PurchaseOrder,

      @ObjectModel.text.element: [ 'SupplierName' ]
      @Search.defaultSearchElement: true
      Supplier,
      @EndUserText.label: 'Supplier Name'
      _Supplier.SupplierName       as SupplierName,

      @Search.defaultSearchElement: true
      InvoiceReference,

      InvoiceDate,
      Currency,
      TotalAmount,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_InvoiceStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName           as StatusName,

      StatusCriticality,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZVHB_C_SupplierInvoiceItem,
      _PurchaseOrder,
      _Supplier,
      _Status
}
