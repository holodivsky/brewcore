@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Material description'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
define view entity ZVHB_R_MaterialText
  as select from zvhb_mattxt

  association to parent ZVHB_R_Material as _Material on $projection.Material = _Material.Material
  association [0..1] to I_Language      as _Language on $projection.Language = _Language.Language
{
  key material              as Material,

      @Semantics.language: true
      @ObjectModel.foreignKey.association: '_Language'
  key language              as Language,

      @Semantics.text: true
      description           as Description,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Material,
      _Language
}
