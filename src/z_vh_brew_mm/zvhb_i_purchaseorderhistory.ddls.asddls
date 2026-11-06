@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Purchase order history'
@Metadata.ignorePropagatedAnnotations: true
// Goods receipts per purchase order item, read from the material documents of inventory.
// A reversal (102) takes its quantity back, so the sum is what is really in stock.
define view entity ZVHB_I_PurchaseOrderHistory
  as select from ZVHB_R_MaterialDocumentItem as Item
    inner join   ZVHB_R_MaterialDocument     as Document on Document.MaterialDocument = Item.MaterialDocument
{
  key Item.PurchaseOrder,
  key Item.PurchaseOrderItem,
      Item.Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( case Item.MovementType when '102' then Item.Quantity * -1 else Item.Quantity end ) as ReceivedQuantity,

      min( case Item.MovementType when '101' then Document.PostingDate end )                as FirstReceiptDate,

      max( case Item.MovementType when '101' then Document.PostingDate end )                as LastReceiptDate
}
where
  Item.PurchaseOrder <> ''
group by
  Item.PurchaseOrder,
  Item.PurchaseOrderItem,
  Item.Unit
