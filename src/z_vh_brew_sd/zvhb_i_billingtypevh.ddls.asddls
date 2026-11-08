@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Billing Document Type'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@Search.searchable: true
define view entity ZVHB_I_BillingTypeVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZVHB_BILL_TYPE' )
{
      @ObjectModel.text.element: [ 'BillingTypeName' ]
      @Search.defaultSearchElement: true
  key cast( value_low as zvhb_bill_type ) as BillingType,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      text                                as BillingTypeName
}
where
  language = $session.system_language
