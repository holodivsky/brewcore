@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Billing document item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_BillingDocumentItem
  as select from zvhb_billitm

  association        to parent ZVHB_R_BillingDocument as _BillingDocument on $projection.BillingDocumentUUID = _BillingDocument.BillingDocumentUUID

  association [0..1] to ZVHB_I_MaterialVH             as _Material        on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_ItemCategoryVH         as _ItemCategory    on $projection.ItemCategory = _ItemCategory.ItemCategory
{
  key bill_uuid             as BillingDocumentUUID,

  key item_uuid             as ItemUUID,

      item                  as Item,

      @ObjectModel.foreignKey.association: '_ItemCategory'
      item_category         as ItemCategory,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Billed Quantity'
      quantity              as Quantity,

      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Net Value'
      net_amount            as NetAmount,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _BillingDocument,
      _Material,
      _ItemCategory
}
