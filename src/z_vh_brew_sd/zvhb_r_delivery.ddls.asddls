@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Delivery'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_Delivery
  as select from zvhb_dlvhdr

  composition [0..*] of ZVHB_R_DeliveryItem as _Item

  association [0..1] to ZVHB_I_CustomerVH   as _Customer on $projection.Customer = _Customer.Customer
  association [0..1] to ZVHB_I_DeliveryStatusVH as _Status on $projection.Status = _Status.Status
{
  key dlv_uuid              as DeliveryUUID,

      delivery              as Delivery,

      so_uuid               as SalesOrderUUID,

      sales_order           as SalesOrder,

      @ObjectModel.foreignKey.association: '_Customer'
      customer              as Customer,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

      // Picked deliveries wait for the goods issue
      cast( case status when 'PICK' then 2
                        else 3 end as abap.int1 ) as StatusCriticality,

      @EndUserText.label: 'Goods Issue Date'
      goods_issue_date      as GoodsIssueDate,

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
      _Status
}
