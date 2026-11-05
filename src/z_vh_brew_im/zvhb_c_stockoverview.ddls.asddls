@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Overview'
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZVHB_C_StockOverview
  as select from ZVHB_I_Stock

  association [0..1] to ZVHB_I_PlantVH       as _Plant           on $projection.Plant = _Plant.Plant
  association [0..1] to ZVHB_I_StorageLocVH  as _StorageLocation on $projection.StorageLocation = _StorageLocation.StorageLocation
  association [0..1] to ZVHB_I_BatchStatusVH as _BatchStatus     on $projection.BatchStatus = _BatchStatus.BatchStatus
{
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Material'
  key Material,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      @ObjectModel.text.element: [ 'PlantName' ]
      @EndUserText.label: 'Plant'
  key Plant,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_StorageLocVH', element: 'StorageLocation' } }]
      @ObjectModel.text.element: [ 'StorageLocationName' ]
      @EndUserText.label: 'Storage Location'
  key StorageLocation,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Batch'
  key Batch,

      @EndUserText.label: 'Material Description'
      _Material.MaterialName              as MaterialName,

      @EndUserText.label: 'Plant Name'
      _Plant.PlantName                    as PlantName,

      @EndUserText.label: 'Storage Location Name'
      _StorageLocation.StorageLocationName as StorageLocationName,

      @EndUserText.label: 'Unit'
      Unit,

      @EndUserText.label: 'Batch Status'
      @ObjectModel.text.element: [ 'BatchStatusName' ]
      BatchStatus,

      @EndUserText.label: 'Batch Status Name'
      _BatchStatus.BatchStatusName         as BatchStatusName,

      @EndUserText.label: 'Best Before'
      ExpiryDate,

      @EndUserText.label: 'Remaining Shelf Life (Days)'
      RemainingShelfLife,

      @EndUserText.label: 'Expired'
      IsExpired,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Total Stock'
      TotalQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Free Stock'
      FreeQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Blocked Stock'
      BlockedQuantity,

      _Material,
      _Plant,
      _StorageLocation,
      _BatchStatus
}
