@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Billing Document Item'
@Metadata.allowExtensions: true
define view entity ZVHB_C_BillingDocumentItem
  as projection on ZVHB_R_BillingDocumentItem
{
  key BillingDocumentUUID,

  key ItemUUID,

      Item,

      @ObjectModel.text.element: [ 'ItemCategoryName' ]
      ItemCategory,
      _ItemCategory.ItemCategoryName as ItemCategoryName,

      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName as MaterialName,

      Unit,
      Quantity,
      Currency,
      NetAmount,
      LocalLastChangedAt,

      _BillingDocument : redirected to parent ZVHB_C_BillingDocument,
      _Material,
      _ItemCategory
}
