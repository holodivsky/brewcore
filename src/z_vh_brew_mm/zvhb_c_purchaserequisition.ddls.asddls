@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Requisition'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'PurchaseRequisition' ]
@Search.searchable: true
define root view entity ZVHB_C_PurchaseRequisition
  provider contract transactional_query
  as projection on ZVHB_R_PurchaseRequisition
{
  key RequisitionUUID,

      @Search.defaultSearchElement: true
      PurchaseRequisition,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName            as MaterialName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      Plant,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_StorageLocVH', element: 'StorageLocation' } }]
      StorageLocation,

      Unit,
      Quantity,
      DeliveryDate,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_SupplierVH', element: 'Supplier' } }]
      @ObjectModel.text.element: [ 'SupplierName' ]
      Supplier,
      @EndUserText.label: 'Supplier Name'
      _Supplier.SupplierName            as SupplierName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PRStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName                as StatusName,

      @EndUserText.label: 'Purchase Order'
      _OrderItem._PurchaseOrder.PurchaseOrder as PurchaseOrder,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Material,
      _Supplier,
      _Status
}
