@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Purchase requisition'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_PurchaseRequisition
  as select from zvhb_preq

  association [0..1] to ZVHB_I_MaterialVH as _Material on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_SupplierVH        as _Supplier  on $projection.Supplier = _Supplier.Supplier
  association [0..1] to ZVHB_R_PurchaseOrderItem as _OrderItem on $projection.RequisitionUUID = _OrderItem.RequisitionUUID
  association [0..1] to ZVHB_I_PRStatusVH        as _Status    on $projection.Status = _Status.Status
{
  key preq_uuid             as RequisitionUUID,

      purchase_requisition  as PurchaseRequisition,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      plant                 as Plant,

      storage_location      as StorageLocation,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Quantity'
      quantity              as Quantity,

      @EndUserText.label: 'Delivery Date'
      delivery_date         as DeliveryDate,

      @ObjectModel.foreignKey.association: '_Supplier'
      @EndUserText.label: 'Preferred Supplier'
      supplier              as Supplier,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

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

      _Material,
      _Supplier,
      _OrderItem,
      _Status
}
