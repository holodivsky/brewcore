@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Delivery item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_DeliveryItem
  as select from zvhb_dlvitm

  association        to parent ZVHB_R_Delivery as _Delivery on $projection.DeliveryUUID = _Delivery.DeliveryUUID

  association [0..1] to ZVHB_I_MaterialVH      as _Material on $projection.Material = _Material.Material
  association [0..1] to ZVHB_R_Batch           as _Batch    on  $projection.Material = _Batch.Material
                                                            and $projection.Batch    = _Batch.Batch
{
  key dlv_uuid              as DeliveryUUID,

  key item_uuid             as ItemUUID,

      item                  as Item,

      @EndUserText.label: 'Order Item'
      order_item            as OrderItem,

      item_category         as ItemCategory,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      batch                 as Batch,

      plant                 as Plant,

      storage_location      as StorageLocation,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Delivery Quantity'
      quantity              as Quantity,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Delivery,
      _Material,
      _Batch
}
