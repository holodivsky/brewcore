@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'Delivery' ]
@Search.searchable: true
define root view entity ZVHB_C_Delivery
  provider contract transactional_query
  as projection on ZVHB_R_Delivery
{
  key DeliveryUUID,

      @Search.defaultSearchElement: true
      Delivery,

      SalesOrderUUID,

      @Search.defaultSearchElement: true
      SalesOrder,

      @ObjectModel.text.element: [ 'CustomerName' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_CustomerVH', element: 'Customer' } }]
      Customer,
      _Customer.CustomerName as CustomerName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_DeliveryStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName     as StatusName,

      StatusCriticality,
      GoodsIssueDate,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZVHB_C_DeliveryItem,
      _Customer,
      _Status
}
