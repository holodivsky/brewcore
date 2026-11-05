@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Material alternative unit'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_MaterialUnit
  as select from zvhb_matuom

  association to parent ZVHB_R_Material as _Material on $projection.Material = _Material.Material
  association [0..1] to I_UnitOfMeasure as _AltUnit  on $projection.AltUnit = _AltUnit.UnitOfMeasure
{
  key material              as Material,

      @ObjectModel.foreignKey.association: '_AltUnit'
      @EndUserText.label: 'Alternative Unit'
  key alt_unit              as AltUnit,

      @EndUserText: { label: 'Base Units', quickInfo: 'Quantity in base units that equals the denominator in the alternative unit' }
      numerator             as Numerator,

      @EndUserText: { label: 'Alternative Units', quickInfo: 'Quantity in the alternative unit' }
      denominator           as Denominator,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Material,
      _AltUnit
}
