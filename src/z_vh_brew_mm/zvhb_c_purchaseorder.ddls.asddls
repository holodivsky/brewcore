@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'PurchaseOrder' ]
@Search.searchable: true
define root view entity ZVHB_C_PurchaseOrder
  provider contract transactional_query
  as projection on ZVHB_R_PurchaseOrder
{
  key PurchaseOrderUUID,

      @Search.defaultSearchElement: true
      PurchaseOrder,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_SupplierVH', element: 'Supplier' } }]
      @ObjectModel.text.element: [ 'SupplierName' ]
      @Search.defaultSearchElement: true
      Supplier,
      @EndUserText.label: 'Supplier Name'
      _Supplier.SupplierName            as SupplierName,

      OrderDate,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      Currency,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PaymentTermsVH', element: 'PaymentTerms' } }]
      @ObjectModel.text.element: [ 'PaymentTermsName' ]
      PaymentTerms,
      _PaymentTerms.PaymentTermsName    as PaymentTermsName,

      TotalAmount,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_POStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName                as StatusName,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZVHB_C_PurchaseOrderItem,
      _Supplier,
      _Currency,
      _PaymentTerms,
      _Status
}
