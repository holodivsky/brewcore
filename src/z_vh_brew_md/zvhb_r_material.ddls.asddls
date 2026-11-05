@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Material'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_Material
  as select from zvhb_mat

  composition [0..*] of ZVHB_R_MaterialText   as _Text
  composition [0..*] of ZVHB_R_MaterialUnit   as _Unit
  composition [0..*] of ZVHB_R_MaterialPlant  as _Plant

  association [0..1] to ZVHB_I_MaterialTypeVH as _MaterialType on $projection.MaterialType = _MaterialType.MaterialType
  association [0..1] to I_UnitOfMeasure       as _BaseUnit     on $projection.BaseUnit = _BaseUnit.UnitOfMeasure
{
      @ObjectModel.text.association: '_Text'
  key material              as Material,

      @ObjectModel.foreignKey.association: '_MaterialType'
      material_type         as MaterialType,

      @ObjectModel.foreignKey.association: '_BaseUnit'
      @EndUserText.label: 'Base Unit'
      base_unit             as BaseUnit,

      @EndUserText: { label: 'Shelf Life (Days)', quickInfo: 'Shelf life in days, used for the best-before date of batches' }
      shelf_life_days       as ShelfLifeDays,

      @EndUserText.label: 'Batch-Managed'
      is_batch_managed      as IsBatchManaged,

      @EndUserText.label: 'Active'
      is_active             as IsActive,

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

      _Text,
      _Unit,
      _Plant,
      _MaterialType,
      _BaseUnit
}
