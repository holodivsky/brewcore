@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inspection Lot Origin'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@Search.searchable: true
define view entity ZVHB_I_LotOriginVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZVHB_LOT_ORIGIN' )
{
      @ObjectModel.text.element: [ 'OriginName' ]
      @Search.defaultSearchElement: true
  key cast( value_low as zvhb_lot_origin ) as Origin,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      text                                 as OriginName
}
where
  language = $session.system_language
