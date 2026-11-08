@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Beer with Active Recipe'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
// Beers that can be brewed: each has a recipe with exactly one active version
define view entity ZVHB_I_BeerRecipeVH
  as select from ZVHB_R_RecipeVersion as Version
    inner join   ZVHB_R_Recipe        as Recipe on Recipe.RecipeUUID = Version.RecipeUUID
    left outer join zvhb_mattxt       as Text   on  Text.material = Recipe.Material
                                                and Text.language = $session.system_language
{
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Beer'
  key Recipe.Material,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'Beer Description'
      Text.description              as MaterialName,

      @UI.hidden: true
      Version.RecipeUUID,

      @UI.hidden: true
      Version.VersionUUID,

      @EndUserText.label: 'Recipe Version'
      Version.Version,

      @EndUserText.label: 'Unit'
      Version.YieldUnit,

      @Semantics.quantity.unitOfMeasure: 'YieldUnit'
      @EndUserText.label: 'Yield per Brew'
      Version.YieldQuantity,

      @EndUserText.label: 'Fermentation Days'
      Version.FermentationDays,

      @EndUserText.label: 'Maturation Days'
      Version.MaturationDays
}
where
  Version.IsActive = 'X'
