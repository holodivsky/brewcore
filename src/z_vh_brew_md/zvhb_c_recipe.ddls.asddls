@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Recipe'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'Material' ]
@Search.searchable: true
define root view entity ZVHB_C_Recipe
  provider contract transactional_query
  as projection on ZVHB_R_Recipe
{
  key RecipeUUID,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' },
                                           additionalBinding: [{ localConstant: 'FERT', element: 'MaterialType', usage: #FILTER }] }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
      Material,

      @EndUserText.label: 'Beer Description'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      _Material.MaterialName as MaterialName,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Version : redirected to composition child ZVHB_C_RecipeVersion,
      _Material
}
