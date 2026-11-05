@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'Partner' ]
@Search.searchable: true
define root view entity ZVHB_C_BusinessPartner
  provider contract transactional_query
  as projection on ZVHB_R_BusinessPartner
{
  key PartnerUUID,

      @Search.defaultSearchElement: true
      Partner,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      PartnerName,

      Street,
      PostalCode,

      @Search.defaultSearchElement: true
      City,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Country', element: 'Country' } }]
      @ObjectModel.text.element: [ 'CountryName' ]
      Country,
      @EndUserText.label: 'Country/Region Name'
      _Country._Text[1: Language = $session.system_language].CountryName as CountryName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      Currency,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PaymentTermsVH', element: 'PaymentTerms' } }]
      @ObjectModel.text.element: [ 'PaymentTermsName' ]
      @EndUserText.label: 'Payment Terms'
      PaymentTerms,
      _PaymentTerms.PaymentTermsName as PaymentTermsName,

      CreditLimit,
      IsBlocked,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Role : redirected to composition child ZVHB_C_BusinessPartnerRole,
      _Country,
      _Currency,
      _PaymentTerms
}
