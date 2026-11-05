@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Recipe'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_Recipe
  as select from zvhb_recipe

  composition [0..*] of ZVHB_R_RecipeVersion as _Version

  association [0..1] to ZVHB_I_MaterialVH    as _Material on $projection.Material = _Material.Material
{
  key recipe_uuid           as RecipeUUID,

      @ObjectModel.foreignKey.association: '_Material'
      @EndUserText.label: 'Beer'
      material              as Material,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Version,
      _Material
}
