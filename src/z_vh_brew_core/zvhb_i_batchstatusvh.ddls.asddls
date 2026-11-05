@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Batch Status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@Search.searchable: true
define view entity ZVHB_I_BatchStatusVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZVHB_BATCH_STATUS' )
{
      @ObjectModel.text.element: [ 'BatchStatusName' ]
      @Search.defaultSearchElement: true
  key cast( value_low as zvhb_batch_status ) as BatchStatus,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      text                                   as BatchStatusName
}
where
  language = $session.system_language
