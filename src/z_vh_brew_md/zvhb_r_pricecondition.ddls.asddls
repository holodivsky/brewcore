@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Price condition'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_PriceCondition
  as select from zvhb_price

  composition [0..*] of ZVHB_R_PriceConditionScale as _Scale

  association [0..1] to ZVHB_I_MaterialVH          as _Material            on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_DistrChannelVH      as _DistributionChannel on $projection.DistributionChannel = _DistributionChannel.DistributionChannel
  association [0..1] to I_Currency                 as _Currency            on $projection.Currency = _Currency.Currency
  association [0..1] to ZVHB_I_ConditionTypeVH     as _ConditionType       on $projection.ConditionType = _ConditionType.ConditionType
{
  key price_uuid            as PriceUUID,

      @ObjectModel.foreignKey.association: '_ConditionType'
      condition_type        as ConditionType,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      @ObjectModel.foreignKey.association: '_DistributionChannel'
      distr_channel         as DistributionChannel,

      @EndUserText.label: 'Valid From'
      valid_from            as ValidFrom,

      @EndUserText.label: 'Valid To'
      valid_to              as ValidTo,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Amount'
      amount                as Amount,

      @ObjectModel.foreignKey.association: '_Currency'
      @EndUserText.label: 'Currency'
      currency              as Currency,

      @EndUserText.label: 'Per Unit'
      base_unit             as BaseUnit,

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

      _Scale,
      _Material,
      _DistributionChannel,
      _Currency,
      _ConditionType
}
