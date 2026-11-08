@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Sales order'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_SalesOrder
  as select from zvhb_sohdr

  composition [0..*] of ZVHB_R_SalesOrderItem as _Item

  association [0..1] to ZVHB_I_CustomerVH     as _Customer            on $projection.Customer = _Customer.Customer
  association [0..1] to ZVHB_I_DistrChannelVH as _DistributionChannel on $projection.DistributionChannel = _DistributionChannel.DistributionChannel
  association [0..*] to ZVHB_R_Delivery       as _Delivery            on $projection.SalesOrderUUID = _Delivery.SalesOrderUUID
  association [0..1] to ZVHB_I_SalesOrderStatusVH as _Status          on $projection.Status = _Status.Status
{
  key so_uuid               as SalesOrderUUID,

      sales_order           as SalesOrder,

      @ObjectModel.foreignKey.association: '_Customer'
      customer              as Customer,

      @ObjectModel.foreignKey.association: '_DistributionChannel'
      distr_channel         as DistributionChannel,

      @EndUserText.label: 'Order Date'
      order_date            as OrderDate,

      @EndUserText.label: 'Requested Delivery'
      requested_date        as RequestedDate,

      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Net Value'
      net_amount            as NetAmount,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Deposit'
      deposit_amount        as DepositAmount,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Total'
      total_amount          as TotalAmount,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

      // Credit blocked orders are red, open orders orange, delivered and billed orders green
      cast( case status when 'CRBL' then 1
                        when 'OPEN' then 2
                        else 3 end as abap.int1 ) as StatusCriticality,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Item,
      _Customer,
      _DistributionChannel,
      _Delivery,
      _Status
}
