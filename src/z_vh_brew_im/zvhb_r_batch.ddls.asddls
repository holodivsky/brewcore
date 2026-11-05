@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Batch'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_Batch
  as select from zvhb_batches

  association [0..1] to ZVHB_I_MaterialVH    as _Material on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_BatchStatusVH as _Status   on $projection.Status = _Status.BatchStatus
{
      @ObjectModel.foreignKey.association: '_Material'
  key material              as Material,

  key batch                 as Batch,

      @EndUserText.label: 'Production Date'
      production_date       as ProductionDate,

      @EndUserText.label: 'Best Before'
      expiry_date           as ExpiryDate,

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

      _Material,
      _Status
}
