@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Recipe Component'
@Metadata.allowExtensions: true
define view entity ZVHB_C_RecipeComponent
  as projection on ZVHB_R_RecipeComponent
{
  key RecipeUUID,

  key VersionUUID,

  key ComponentUUID,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' },
                                           additionalBinding: [{ localConstant: 'ROH', element: 'MaterialType', usage: #FILTER }] }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,

      @EndUserText.label: 'Component Description'
      _Material.MaterialName as MaterialName,

      Unit,
      Quantity,
      LocalLastChangedAt,

      _Version : redirected to parent ZVHB_C_RecipeVersion,
      _Recipe  : redirected to ZVHB_C_Recipe,
      _Material
}
