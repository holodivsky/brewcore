@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inspection Characteristic'
@Metadata.allowExtensions: true
define view entity ZVHB_C_InspectionChar
  as projection on ZVHB_R_InspectionChar
{
  key LotUUID,

  key CharacteristicUUID,

      SortOrder,
      Characteristic,
      Description,
      UnitText,
      TargetValue,
      LowerLimit,
      UpperLimit,
      ResultValue,

      // Valuation against the limits, also for results that are only in the draft
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VHB_CHARACTERISTIC_CHECK'
      @EndUserText.label: 'Valuation'
      virtual ValuationText        : abap.char( 20 ),

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_VHB_CHARACTERISTIC_CHECK'
      virtual ValuationCriticality : abap.int1,

      LocalLastChangedAt,

      _InspectionLot : redirected to parent ZVHB_C_InspectionLot
}
