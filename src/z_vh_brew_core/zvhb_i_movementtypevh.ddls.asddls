@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Movement Type'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@Search.searchable: true
define view entity ZVHB_I_MovementTypeVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZVHB_MOVEMENT_TYPE' )
{
      @ObjectModel.text.element: [ 'MovementTypeName' ]
      @Search.defaultSearchElement: true
  key cast( value_low as zvhb_movement_type ) as MovementType,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      text                                    as MovementTypeName
}
where
  language = $session.system_language
