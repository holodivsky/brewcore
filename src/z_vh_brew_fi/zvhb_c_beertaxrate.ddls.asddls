@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Beer Tax Rate'
@Metadata.allowExtensions: true
define root view entity ZVHB_C_BeerTaxRate
  provider contract transactional_query
  as projection on ZVHB_R_BeerTaxRate
{
  key RateUUID,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      @ObjectModel.text.element: [ 'PlantName' ]
      Plant,
      _Plant.PlantName as PlantName,

      ValidFrom,
      StandardRate,
      RatePercent,
      RatePerDegree,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      Currency,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Plant,
      _Currency
}
