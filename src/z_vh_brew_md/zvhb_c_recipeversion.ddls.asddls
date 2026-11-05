@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Recipe Version'
@Metadata.allowExtensions: true
define view entity ZVHB_C_RecipeVersion
  as projection on ZVHB_R_RecipeVersion
{
  key RecipeUUID,

  key VersionUUID,

      Version,
      IsActive,
      YieldUnit,
      YieldQuantity,
      TargetGravity,
      TargetAlcohol,
      FermentationDays,
      MaturationDays,
      LocalLastChangedAt,

      _Recipe    : redirected to parent ZVHB_C_Recipe,
      _Component : redirected to composition child ZVHB_C_RecipeComponent
}
