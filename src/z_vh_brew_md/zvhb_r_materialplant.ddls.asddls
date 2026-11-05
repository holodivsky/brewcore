@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Material plant data'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_MaterialPlant
  as select from zvhb_matplnt

  association to parent ZVHB_R_Material as _Material on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_PlantVH  as _PlantVH  on $projection.Plant = _PlantVH.Plant
{
  key material              as Material,

      @ObjectModel.foreignKey.association: '_PlantVH'
  key plant                 as Plant,

      base_unit             as BaseUnit,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      @EndUserText.label: 'Minimum Stock'
      min_stock             as MinStock,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      @EndUserText.label: 'Reorder Point'
      reorder_point         as ReorderPoint,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Material,
      _PlantVH
}
