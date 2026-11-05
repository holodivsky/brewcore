@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Batch'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'Material', 'Batch' ]
@Search.searchable: true
define root view entity ZVHB_C_Batch
  provider contract transactional_query
  as projection on ZVHB_R_Batch
{
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
  key Material,

      @Search.defaultSearchElement: true
  key Batch,

      @EndUserText.label: 'Material Description'
      _Material.MaterialName as MaterialName,

      ProductionDate,
      ExpiryDate,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_BatchStatusVH', element: 'BatchStatus' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.BatchStatusName as StatusName,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Material,
      _Status
}
