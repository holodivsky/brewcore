@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Price Condition'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZVHB_C_PriceCondition
  provider contract transactional_query
  as projection on ZVHB_R_PriceCondition
{
  key PriceUUID,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_ConditionTypeVH', element: 'ConditionType' } }]
      @ObjectModel.text.element: [ 'ConditionTypeName' ]
      ConditionType,
      _ConditionType.ConditionTypeName             as ConditionTypeName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      @Search.defaultSearchElement: true
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName                         as MaterialName,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_DistrChannelVH', element: 'DistributionChannel' } }]
      @ObjectModel.text.element: [ 'DistributionChannelName' ]
      DistributionChannel,
      _DistributionChannel.DistributionChannelName as DistributionChannelName,

      ValidFrom,
      ValidTo,
      Amount,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      Currency,

      BaseUnit,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Scale : redirected to composition child ZVHB_C_PriceConditionScale,
      _Material,
      _DistributionChannel,
      _Currency,
      _ConditionType
}
