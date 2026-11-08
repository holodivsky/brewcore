@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'Material' ]
@Search.searchable: true
define root view entity ZVHB_C_Material
  provider contract transactional_query
  as projection on ZVHB_R_Material
{
      @Search.defaultSearchElement: true
      @ObjectModel.text.association: null
      @ObjectModel.text.element: [ 'MaterialName' ]
  key Material,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'Description'
      _Text.Description              as MaterialName : localized,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialTypeVH', element: 'MaterialType' } }]
      @ObjectModel.text.element: [ 'MaterialTypeName' ]
      MaterialType,
      _MaterialType.MaterialTypeName as MaterialTypeName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' } }]
      @EndUserText.label: 'Base Unit'
      BaseUnit,

      ShelfLifeDays,
      IsBatchManaged,
      IsActive,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      ReturnablePackaging,
      UnitsPerPackage,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Text  : redirected to composition child ZVHB_C_MaterialText,
      _Unit  : redirected to composition child ZVHB_C_MaterialUnit,
      _Plant : redirected to composition child ZVHB_C_MaterialPlant,
      _MaterialType,
      _BaseUnit
}
