@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Invoiced quantity per order item'
@Metadata.ignorePropagatedAnnotations: true
// Quantity per purchase order item that suppliers have already invoiced.
// Posted and blocked invoices count, new and rejected ones do not.
define view entity ZVHB_I_InvoicedQuantity
  as select from zvhb_sinvitm as Item
    inner join   zvhb_sinvhdr as Invoice on Invoice.invoice_uuid = Item.invoice_uuid
{
  key Item.po_item_uuid  as OrderItemUUID,
      Item.unit          as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( Item.quantity ) as InvoicedQuantity
}
where
     Invoice.status = 'POST'
  or Invoice.status = 'BLCK'
group by
  Item.po_item_uuid,
  Item.unit
