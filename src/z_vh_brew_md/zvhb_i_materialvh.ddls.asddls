@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #MASTER }
@Search.searchable: true
define view entity ZVHB_I_MaterialVH
  as select from ZVHB_R_Material
{
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
  key Material,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      _Text[1: Language = $session.system_language].Description as MaterialName,

      MaterialType,
      BaseUnit,
      IsActive
}
