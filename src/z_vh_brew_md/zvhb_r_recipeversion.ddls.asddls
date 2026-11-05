@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Recipe version'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_RecipeVersion
  as select from zvhb_rcpver

  association to parent ZVHB_R_Recipe        as _Recipe    on $projection.RecipeUUID = _Recipe.RecipeUUID

  composition [0..*] of ZVHB_R_RecipeComponent as _Component
{
  key recipe_uuid           as RecipeUUID,

  key version_uuid          as VersionUUID,

      version               as Version,

      @EndUserText.label: 'Active'
      is_active             as IsActive,

      @EndUserText.label: 'Yield Unit'
      yield_unit            as YieldUnit,

      @Semantics.quantity.unitOfMeasure: 'YieldUnit'
      @EndUserText.label: 'Yield per Brew'
      yield_quantity        as YieldQuantity,

      @EndUserText.label: 'Target Gravity (°P)'
      target_gravity        as TargetGravity,

      @EndUserText.label: 'Target Alcohol (% vol)'
      target_alcohol        as TargetAlcohol,

      @EndUserText.label: 'Fermentation (Days)'
      fermentation_days     as FermentationDays,

      @EndUserText.label: 'Maturation (Days)'
      maturation_days       as MaturationDays,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Recipe,
      _Component
}
