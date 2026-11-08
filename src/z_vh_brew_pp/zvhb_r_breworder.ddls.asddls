@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Brew order'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_BrewOrder
  as select from zvhb_brewhdr

  composition [0..*] of ZVHB_R_BrewOrderComponent as _Component

  association [0..1] to ZVHB_I_MaterialVH         as _Material      on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_TankVH             as _Tank          on $projection.Tank = _Tank.Tank
  association [0..1] to ZVHB_I_BrewOrderBatch     as _ProducedBatch on $projection.BrewOrder = _ProducedBatch.BrewOrder
  association [0..*] to ZVHB_C_BrewOrderMovement  as _Movement      on $projection.BrewOrder = _Movement.BrewOrder
  association [0..1] to ZVHB_I_BrewStatusVH       as _Status        on $projection.Status = _Status.Status
{
  key brew_uuid             as BrewOrderUUID,

      brew_order            as BrewOrder,

      @ObjectModel.foreignKey.association: '_Material'
      @EndUserText.label: 'Beer'
      material              as Material,

      plant                 as Plant,

      recipe_uuid           as RecipeUUID,

      version_uuid          as VersionUUID,

      @EndUserText.label: 'Recipe Version'
      recipe_version        as RecipeVersion,

      @ObjectModel.foreignKey.association: '_Tank'
      tank                  as Tank,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Planned Quantity'
      planned_quantity      as PlannedQuantity,

      @EndUserText.label: 'Planned Start'
      planned_start         as PlannedStart,

      @EndUserText.label: 'Tank Free From'
      planned_end           as PlannedEnd,

      @EndUserText.label: 'Fermentation Days'
      fermentation_days     as FermentationDays,

      @EndUserText.label: 'Maturation Days'
      maturation_days       as MaturationDays,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

      // Brews in progress are orange, filled brews green
      cast( case status when 'NEW'  then 0
                        when 'DONE' then 3
                        else 2 end as abap.int1 ) as StatusCriticality,

      @EndUserText.label: 'Mashing'
      mashing_start         as MashingStart,

      @EndUserText.label: 'Boiling'
      boiling_start         as BoilingStart,

      @EndUserText.label: 'Fermentation'
      fermentation_start    as FermentationStart,

      @EndUserText.label: 'Maturation'
      maturation_start      as MaturationStart,

      @EndUserText.label: 'Filling'
      filling_date          as FillingDate,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Filled Quantity'
      filled_quantity       as FilledQuantity,

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

      _Component,
      _Material,
      _Tank,
      _ProducedBatch,
      _Movement,
      _Status
}
