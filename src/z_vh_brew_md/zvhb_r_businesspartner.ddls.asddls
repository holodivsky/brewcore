@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Business partner'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_BusinessPartner
  as select from zvhb_bp

  composition [0..*] of ZVHB_R_BusinessPartnerRole as _Role

  association [0..1] to I_Country                  as _Country  on $projection.Country = _Country.Country
  association [0..1] to I_Currency                 as _Currency     on $projection.Currency = _Currency.Currency
  association [0..1] to ZVHB_I_PaymentTermsVH      as _PaymentTerms on $projection.PaymentTerms = _PaymentTerms.PaymentTerms
{
  key partner_uuid          as PartnerUUID,

      @EndUserText.label: 'Business Partner'
      partner               as Partner,

      @EndUserText.label: 'Name'
      partner_name          as PartnerName,

      @EndUserText.label: 'Street'
      street                as Street,

      @EndUserText.label: 'Postal Code'
      postal_code           as PostalCode,

      @EndUserText.label: 'City'
      city                  as City,

      @ObjectModel.foreignKey.association: '_Country'
      @EndUserText.label: 'Country/Region'
      country               as Country,

      @ObjectModel.foreignKey.association: '_Currency'
      @EndUserText.label: 'Currency'
      currency              as Currency,

      @ObjectModel.foreignKey.association: '_PaymentTerms'
      payment_terms         as PaymentTerms,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Credit Limit'
      credit_limit          as CreditLimit,

      @EndUserText.label: 'Blocked'
      is_blocked            as IsBlocked,

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

      _Role,
      _Country,
      _Currency,
      _PaymentTerms
}
