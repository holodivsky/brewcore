@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Price condition quantity scale'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_PriceConditionScale
  as select from zvhb_prcscale

  association to parent ZVHB_R_PriceCondition as _Price on $projection.PriceUUID = _Price.PriceUUID
{
  key price_uuid            as PriceUUID,

  key scale_uuid            as ScaleUUID,

      @EndUserText.label: 'Unit'
      base_unit             as BaseUnit,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      @EndUserText.label: 'From Quantity'
      from_quantity         as FromQuantity,

      @EndUserText.label: 'Discount (%)'
      discount_percent      as DiscountPercent,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Price
}
