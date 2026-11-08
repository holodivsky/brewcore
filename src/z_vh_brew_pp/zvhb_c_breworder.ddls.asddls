@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Brew Order'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'BrewOrder' ]
@Search.searchable: true
define root view entity ZVHB_C_BrewOrder
  provider contract transactional_query
  as projection on ZVHB_R_BrewOrder
{
  key BrewOrderUUID,

      @Search.defaultSearchElement: true
      BrewOrder,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_BeerRecipeVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
      Material,
      @EndUserText.label: 'Beer Description'
      _Material.MaterialName      as MaterialName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      Plant,

      RecipeUUID,
      VersionUUID,
      RecipeVersion,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_TankVH', element: 'Tank' } }]
      @ObjectModel.text.element: [ 'TankDescription' ]
      @Search.defaultSearchElement: true
      Tank,
      @EndUserText.label: 'Tank Description'
      _Tank.Description           as TankDescription,

      Unit,
      PlannedQuantity,
      PlannedStart,
      PlannedEnd,
      FermentationDays,
      MaturationDays,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_BrewStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName          as StatusName,

      StatusCriticality,
      MashingStart,
      BoilingStart,
      FermentationStart,
      MaturationStart,
      FillingDate,
      FilledQuantity,

      @EndUserText.label: 'Beer Batch'
      _ProducedBatch.Batch        as Batch,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Component : redirected to composition child ZVHB_C_BrewOrderComponent,
      _Material,
      _Tank,
      _Movement,
      _Status
}
