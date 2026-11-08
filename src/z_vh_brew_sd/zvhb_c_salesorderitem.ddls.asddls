@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item'
@Metadata.allowExtensions: true
define view entity ZVHB_C_SalesOrderItem
  as projection on ZVHB_R_SalesOrderItem
{
  key SalesOrderUUID,

  key ItemUUID,

      Item,

      @ObjectModel.text.element: [ 'ItemCategoryName' ]
      ItemCategory,
      _ItemCategory.ItemCategoryName  as ItemCategoryName,

      ParentItemUUID,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName         as MaterialName,

      Unit,
      Quantity,
      ConfirmedQuantity,

      @EndUserText.label: 'Available to Promise'
      _Availability.AvailableQuantity as AvailableQuantity,

      Currency,
      BasePrice,
      DiscountPercent,
      NetAmount,
      LocalLastChangedAt,

      _SalesOrder : redirected to parent ZVHB_C_SalesOrder,
      _Material,
      _Availability,
      _ItemCategory
}
