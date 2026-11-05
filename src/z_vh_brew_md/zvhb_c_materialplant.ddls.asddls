@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Plant Data'
@Metadata.allowExtensions: true
define view entity ZVHB_C_MaterialPlant
  as projection on ZVHB_R_MaterialPlant
{
  key Material,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      @ObjectModel.text.element: [ 'PlantName' ]
  key Plant,
      _PlantVH.PlantName as PlantName,

      BaseUnit,
      MinStock,
      ReorderPoint,
      LocalLastChangedAt,

      _Material : redirected to parent ZVHB_C_Material,
      _PlantVH
}
