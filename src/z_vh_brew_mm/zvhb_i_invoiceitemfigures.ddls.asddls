@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Invoice item against order and receipt'
@Metadata.ignorePropagatedAnnotations: true
// The three documents of the 3-way match side by side for every invoice item:
// order price from the purchase order, received quantity from inventory, invoiced price and quantity
define view entity ZVHB_I_InvoiceItemFigures
  as select from         zvhb_sinvitm                as Item
    inner join           zvhb_sinvhdr                as Invoice   on Invoice.invoice_uuid = Item.invoice_uuid
    inner join           zvhb_poitm                  as OrderItem on OrderItem.item_uuid = Item.po_item_uuid
    left outer to one join ZVHB_I_PurchaseOrderHistory as History on  History.PurchaseOrder     = Item.purchase_order
                                                                   and History.PurchaseOrderItem = Item.purchase_order_item
    left outer to one join ZVHB_I_InvoicedQuantity   as Invoiced  on Invoiced.OrderItemUUID = Item.po_item_uuid
{
  key Item.invoice_uuid                                    as InvoiceUUID,
  key Item.item_uuid                                       as ItemUUID,
      Invoice.supplier_invoice                             as SupplierInvoice,
      Invoice.supplier                                     as Supplier,
      Invoice.status                                       as InvoiceStatus,
      Invoice.invoice_date                                 as InvoiceDate,
      Item.item                                            as Item,
      Item.purchase_order                                  as PurchaseOrder,
      Item.purchase_order_item                             as PurchaseOrderItem,
      Item.material                                        as Material,
      Item.unit                                            as Unit,
      Item.currency                                        as Currency,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      Item.quantity                                        as InvoicedQuantity,

      // No goods receipt yet means nothing was received
      @Semantics.quantity.unitOfMeasure: 'Unit'
      coalesce( History.ReceivedQuantity, Item.quantity - Item.quantity ) as ReceivedQuantity,

      // Other invoices for the same order item; this one is part of the sum once it is posted or blocked
      @Semantics.quantity.unitOfMeasure: 'Unit'
      coalesce( Invoiced.InvoicedQuantity, Item.quantity - Item.quantity )
        - case Invoice.status when 'POST' then Item.quantity
                              when 'BLCK' then Item.quantity
                              else Item.quantity - Item.quantity end      as OtherInvoicedQuantity,

      @Semantics.amount.currencyCode: 'Currency'
      Item.net_price                                       as InvoicePrice,

      @Semantics.amount.currencyCode: 'Currency'
      OrderItem.net_price                                  as OrderPrice,

      // Deviation of the invoiced price from the order price in percent
      case when OrderItem.net_price = 0
           then cast( 0 as abap.dec( 7, 2 ) )
           else cast( division( ( cast( Item.net_price as abap.dec( 15, 2 ) ) - cast( OrderItem.net_price as abap.dec( 15, 2 ) ) ) * 100,
                                cast( OrderItem.net_price as abap.dec( 15, 2 ) ), 2 ) as abap.dec( 7, 2 ) )
      end                                                  as PriceVariancePercent
}
