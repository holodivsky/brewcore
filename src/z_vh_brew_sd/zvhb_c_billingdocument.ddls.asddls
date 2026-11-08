@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Billing Document'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'BillingDocument' ]
@Search.searchable: true
define root view entity ZVHB_C_BillingDocument
  provider contract transactional_query
  as projection on ZVHB_R_BillingDocument
{
  key BillingDocumentUUID,

      @Search.defaultSearchElement: true
      BillingDocument,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_BillingTypeVH', element: 'BillingType' } }]
      @ObjectModel.text.element: [ 'BillingTypeName' ]
      BillingType,
      _BillingType.BillingTypeName as BillingTypeName,

      @ObjectModel.text.element: [ 'CustomerName' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_CustomerVH', element: 'Customer' } }]
      @Search.defaultSearchElement: true
      Customer,
      _Customer.CustomerName as CustomerName,

      SalesOrder,
      Delivery,
      BillingDate,
      Currency,
      NetAmount,
      DepositAmount,
      TotalAmount,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZVHB_C_BillingDocumentItem,
      _Customer,
      _BillingType
}
