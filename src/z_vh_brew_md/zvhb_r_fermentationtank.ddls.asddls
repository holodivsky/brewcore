@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Fermentation tank'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_FermentationTank
  as select from zvhb_ftank

  association [0..1] to ZVHB_I_PlantVH      as _Plant  on $projection.Plant = _Plant.Plant
  association [0..1] to ZVHB_I_TankStatusVH as _Status on $projection.Status = _Status.Status
{
  key tank                  as Tank,

      @ObjectModel.foreignKey.association: '_Plant'
      plant                 as Plant,

      @EndUserText.label: 'Description'
      description           as Description,

      @EndUserText.label: 'Capacity Unit'
      capacity_unit         as CapacityUnit,

      @Semantics.quantity.unitOfMeasure: 'CapacityUnit'
      @EndUserText.label: 'Capacity'
      capacity              as Capacity,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

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

      _Plant,
      _Status
}
