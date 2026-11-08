@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inspection Lot'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'InspectionLot' ]
@Search.searchable: true
define root view entity ZVHB_C_InspectionLot
  provider contract transactional_query
  as projection on ZVHB_R_InspectionLot
{
  key LotUUID,

      @Search.defaultSearchElement: true
      InspectionLot,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_LotOriginVH', element: 'Origin' } }]
      @ObjectModel.text.element: [ 'OriginName' ]
      Origin,
      _Origin.OriginName           as OriginName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName       as MaterialName,

      @Search.defaultSearchElement: true
      Batch,

      @ObjectModel.text.element: [ 'BatchStatusName' ]
      @EndUserText.label: 'Batch Status'
      _Batch.Status                as BatchStatus,
      @EndUserText.label: 'Batch Status Name'
      _Batch._Status.BatchStatusName as BatchStatusName,

      @EndUserText.label: 'Best Before'
      _Batch.ExpiryDate            as ExpiryDate,

      Plant,
      StorageLocation,
      Unit,
      Quantity,
      MaterialDocument,
      DocumentItem,
      PurchaseOrder,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_SupplierVH', element: 'Supplier' } }]
      @ObjectModel.text.element: [ 'SupplierName' ]
      Supplier,
      @EndUserText.label: 'Supplier Name'
      _Supplier.SupplierName       as SupplierName,

      @Search.defaultSearchElement: true
      BrewOrder,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_LotStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName           as StatusName,

      StatusCriticality,
      DecisionDate,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Characteristic : redirected to composition child ZVHB_C_InspectionChar,
      _Material,
      _Supplier,
      _Batch,
      _Status,
      _Origin
}
