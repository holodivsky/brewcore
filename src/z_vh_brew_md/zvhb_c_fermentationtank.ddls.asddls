@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Fermentation Tank'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'Tank' ]
@Search.searchable: true
define root view entity ZVHB_C_FermentationTank
  provider contract transactional_query
  as projection on ZVHB_R_FermentationTank
{
      @Search.defaultSearchElement: true
  key Tank,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      @ObjectModel.text.element: [ 'PlantName' ]
      Plant,
      _Plant.PlantName as PlantName,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Description,

      CapacityUnit,
      Capacity,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_TankStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName as StatusName,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Plant,
      _Status
}
