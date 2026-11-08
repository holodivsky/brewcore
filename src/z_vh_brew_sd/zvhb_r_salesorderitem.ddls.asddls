@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Sales order item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_SalesOrderItem
  as select from zvhb_soitm

  association        to parent ZVHB_R_SalesOrder     as _SalesOrder   on $projection.SalesOrderUUID = _SalesOrder.SalesOrderUUID

  association [0..1] to ZVHB_I_MaterialVH            as _Material     on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_AvailableToPromise    as _Availability on $projection.Material = _Availability.Material
  association [0..1] to ZVHB_I_ItemCategoryVH        as _ItemCategory on $projection.ItemCategory = _ItemCategory.ItemCategory
{
  key so_uuid               as SalesOrderUUID,

  key item_uuid             as ItemUUID,

      item                  as Item,

      @ObjectModel.foreignKey.association: '_ItemCategory'
      item_category         as ItemCategory,

      parent_item_uuid      as ParentItemUUID,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Order Quantity'
      quantity              as Quantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Confirmed Quantity'
      confirmed_quantity    as ConfirmedQuantity,

      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Price per Unit'
      base_price            as BasePrice,

      @EndUserText.label: 'Discount (%)'
      discount_percent      as DiscountPercent,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Net Value'
      net_amount            as NetAmount,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _SalesOrder,
      _Material,
      _Availability,
      _ItemCategory
}
