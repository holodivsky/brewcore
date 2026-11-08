@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'SalesOrder' ]
@Search.searchable: true
define root view entity ZVHB_C_SalesOrder
  provider contract transactional_query
  as projection on ZVHB_R_SalesOrder
{
  key SalesOrderUUID,

      @Search.defaultSearchElement: true
      SalesOrder,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_CustomerVH', element: 'Customer' } }]
      @ObjectModel.text.element: [ 'CustomerName' ]
      @Search.defaultSearchElement: true
      Customer,
      _Customer.CustomerName                         as CustomerName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_DistrChannelVH', element: 'DistributionChannel' } }]
      @ObjectModel.text.element: [ 'DistributionChannelName' ]
      DistributionChannel,
      @EndUserText.label: 'Channel Name'
      _DistributionChannel.DistributionChannelName   as DistributionChannelName,

      OrderDate,
      RequestedDate,
      Currency,
      NetAmount,
      DepositAmount,
      TotalAmount,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_SalesOrderStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName                             as StatusName,

      StatusCriticality,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item     : redirected to composition child ZVHB_C_SalesOrderItem,
      _Delivery : redirected to ZVHB_C_Delivery,
      _Customer,
      _DistributionChannel,
      _Status
}
