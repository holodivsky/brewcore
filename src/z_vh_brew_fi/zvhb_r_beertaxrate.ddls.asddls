@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Beer tax rate'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_BeerTaxRate
  as select from zvhb_btrate

  association [0..1] to ZVHB_I_PlantVH as _Plant    on $projection.Plant = _Plant.Plant
  association [0..1] to I_Currency     as _Currency on $projection.Currency = _Currency.Currency
{
  key rate_uuid             as RateUUID,

      @ObjectModel.foreignKey.association: '_Plant'
      plant                 as Plant,

      @EndUserText.label: 'Valid From'
      valid_from            as ValidFrom,

      @EndUserText: { label: 'Standard Rate', quickInfo: 'EUR per hectoliter and degree Plato, section 2 (1) BierStG' }
      standard_rate         as StandardRate,

      @EndUserText: { label: 'Share of Standard Rate (%)', quickInfo: '100 % or the reduced share of a small brewery, section 2 (2) BierStG' }
      rate_percent          as RatePercent,

      @EndUserText: { label: 'Rate per hl and °P', quickInfo: 'Rate that applies to the plant, four decimal places' }
      rate_per_degree       as RatePerDegree,

      @ObjectModel.foreignKey.association: '_Currency'
      @EndUserText.label: 'Currency'
      currency              as Currency,

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
      _Currency
}
