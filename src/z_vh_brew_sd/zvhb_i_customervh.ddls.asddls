@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Customer'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #MASTER }
@Search.searchable: true
// Business partners with the customer role
define view entity ZVHB_I_CustomerVH
  as select from zvhb_bp     as Partner
    inner join   zvhb_bprole as Role on  Role.partner_uuid = Partner.partner_uuid
                                     and Role.partner_role = 'CU'
{
      @ObjectModel.text.element: [ 'CustomerName' ]
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Customer'
  key Partner.partner        as Customer,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'Customer Name'
      Partner.partner_name   as CustomerName,

      @EndUserText.label: 'City'
      Partner.city           as City,

      @EndUserText.label: 'Country'
      Partner.country        as Country,

      @EndUserText.label: 'Currency'
      Partner.currency       as Currency,

      @EndUserText.label: 'Payment Terms'
      Partner.payment_terms  as PaymentTerms,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Credit Limit'
      Partner.credit_limit   as CreditLimit,

      @EndUserText.label: 'Blocked'
      Partner.is_blocked     as IsBlocked
}
