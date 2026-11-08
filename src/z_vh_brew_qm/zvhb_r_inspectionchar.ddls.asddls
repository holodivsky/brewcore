@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Inspection characteristic'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_InspectionChar
  as select from zvhb_inspchar

  association to parent ZVHB_R_InspectionLot as _InspectionLot on $projection.LotUUID = _InspectionLot.LotUUID
{
  key lot_uuid              as LotUUID,

  key char_uuid             as CharacteristicUUID,

      @EndUserText.label: 'Sort Order'
      sort_order            as SortOrder,

      characteristic        as Characteristic,

      @EndUserText.label: 'Description'
      description           as Description,

      unit_text             as UnitText,

      @EndUserText.label: 'Target'
      target_value          as TargetValue,

      @EndUserText.label: 'Lower Limit'
      lower_limit           as LowerLimit,

      @EndUserText.label: 'Upper Limit'
      upper_limit           as UpperLimit,

      result_value          as ResultValue,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _InspectionLot
}
