@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Purchase order item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_PurchaseOrderItem
  as select from zvhb_poitm

  association        to parent ZVHB_R_PurchaseOrder as _PurchaseOrder on $projection.PurchaseOrderUUID = _PurchaseOrder.PurchaseOrderUUID

  association [0..1] to ZVHB_I_MaterialVH           as _Material      on $projection.Material = _Material.Material
{
  key po_uuid               as PurchaseOrderUUID,

  key item_uuid             as ItemUUID,

      item                  as Item,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      plant                 as Plant,

      storage_location      as StorageLocation,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Ordered Quantity'
      quantity              as Quantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Received Quantity'
      received_quantity     as ReceivedQuantity,

      @EndUserText.label: 'Currency'
      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Net Price per Unit'
      net_price             as NetPrice,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Net Amount'
      net_amount            as NetAmount,

      @EndUserText.label: 'Delivery Date'
      delivery_date         as DeliveryDate,

      @EndUserText.label: 'Delivered'
      is_delivered          as IsDelivered,

      @EndUserText.label: 'Requisition'
      preq_uuid             as RequisitionUUID,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _PurchaseOrder,
      _Material
}
