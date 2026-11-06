@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Supplier invoice item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_SupplierInvoiceItem
  as select from zvhb_sinvitm

  association        to parent ZVHB_R_SupplierInvoice as _Invoice   on $projection.InvoiceUUID = _Invoice.InvoiceUUID

  association [0..1] to ZVHB_R_PurchaseOrderItem       as _OrderItem on $projection.OrderItemUUID = _OrderItem.ItemUUID
  association [0..1] to ZVHB_I_MaterialVH              as _Material  on $projection.Material = _Material.Material
{
  key invoice_uuid          as InvoiceUUID,

  key item_uuid             as ItemUUID,

      item                  as Item,

      po_item_uuid          as OrderItemUUID,

      purchase_order        as PurchaseOrder,

      purchase_order_item   as PurchaseOrderItem,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Invoiced Quantity'
      quantity              as Quantity,

      @EndUserText.label: 'Currency'
      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Invoiced Price per Unit'
      net_price             as NetPrice,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Net Amount'
      net_amount            as NetAmount,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Invoice,
      _OrderItem,
      _Material
}
