@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Recipe component'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_RecipeComponent
  as select from zvhb_rcpcomp

  association        to parent ZVHB_R_RecipeVersion as _Version  on  $projection.RecipeUUID  = _Version.RecipeUUID
                                                                  and $projection.VersionUUID = _Version.VersionUUID

  association [1..1] to ZVHB_R_Recipe               as _Recipe   on  $projection.RecipeUUID = _Recipe.RecipeUUID
  association [0..1] to ZVHB_I_MaterialVH           as _Material on  $projection.Material = _Material.Material
{
  key recipe_uuid           as RecipeUUID,

  key version_uuid          as VersionUUID,

  key component_uuid        as ComponentUUID,

      @ObjectModel.foreignKey.association: '_Material'
      @EndUserText.label: 'Component'
      material              as Material,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Quantity per Brew'
      quantity              as Quantity,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Version,
      _Recipe,
      _Material
}
