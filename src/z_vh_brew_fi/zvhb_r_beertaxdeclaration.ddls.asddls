@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Beer tax declaration'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_BeerTaxDeclaration
  as select from zvhb_btdecl

  composition [0..*] of ZVHB_R_BeerTaxDeclItem as _Item

  association [0..1] to ZVHB_I_PlantVH      as _Plant    on $projection.Plant = _Plant.Plant
  association [0..1] to ZVHB_I_DeclStatusVH as _Status   on $projection.Status = _Status.Status
  association [0..1] to I_Currency          as _Currency on $projection.Currency = _Currency.Currency
{
  key decl_uuid             as DeclarationUUID,
      declaration           as Declaration,

      @ObjectModel.foreignKey.association: '_Plant'
      plant                 as Plant,

      @EndUserText.label: 'Year'
      period_year           as PeriodYear,

      @EndUserText.label: 'Month'
      period_month          as PeriodMonth,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

      @EndUserText.label: 'Rate per hl and °P'
      rate_per_degree       as RatePerDegree,

      @EndUserText.label: 'Taxable (hl)'
      taxable_hl            as TaxableHL,

      @EndUserText.label: 'Export, Tax-Free (hl)'
      export_hl             as ExportHL,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Beer Tax'
      tax_amount            as TaxAmount,

      @ObjectModel.foreignKey.association: '_Currency'
      @EndUserText.label: 'Currency'
      currency              as Currency,

      @EndUserText.label: 'Submitted By'
      submitted_by          as SubmittedBy,

      @EndUserText.label: 'Submitted At'
      submitted_at          as SubmittedAt,

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

      _Item,
      _Plant,
      _Status,
      _Currency
}
