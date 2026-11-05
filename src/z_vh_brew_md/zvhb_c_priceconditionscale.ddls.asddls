@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quantity Scale'
@Metadata.allowExtensions: true
define view entity ZVHB_C_PriceConditionScale
  as projection on ZVHB_R_PriceConditionScale
{
  key PriceUUID,

  key ScaleUUID,

      BaseUnit,
      FromQuantity,
      DiscountPercent,
      LocalLastChangedAt,

      _Price : redirected to parent ZVHB_C_PriceCondition
}
