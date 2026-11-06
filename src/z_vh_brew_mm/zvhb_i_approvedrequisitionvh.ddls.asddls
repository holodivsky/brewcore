@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved Purchase Requisition'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@Search.searchable: true
// Requisitions that can be turned into a purchase order
define view entity ZVHB_I_ApprovedRequisitionVH
  as select from zvhb_preq

  association [0..1] to ZVHB_I_MaterialVH as _Material on $projection.Material = _Material.Material
{
      @Search.defaultSearchElement: true
  key purchase_requisition   as PurchaseRequisition,

      @Search.defaultSearchElement: true
      material               as Material,

      @EndUserText.label: 'Material Description'
      _Material.MaterialName as MaterialName,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      quantity               as Quantity,

      unit                   as Unit,

      @EndUserText.label: 'Delivery Date'
      delivery_date          as DeliveryDate,

      @EndUserText.label: 'Preferred Supplier'
      supplier               as Supplier,

      _Material
}
where
  status = 'APPR'
