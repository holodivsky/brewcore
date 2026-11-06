@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Delivery performance'
@Metadata.ignorePropagatedAnnotations: true
// One line per purchase order item with goods receipts: was it on time, and how far
// does the received quantity differ from the ordered one
define view entity ZVHB_I_SupplierDelivery
  as select from zvhb_poitm                  as Item
    inner join   zvhb_pohdr                  as Header  on Header.po_uuid = Item.po_uuid
    inner join   ZVHB_I_PurchaseOrderHistory as History on  History.PurchaseOrder     = Header.purchase_order
                                                        and History.PurchaseOrderItem = Item.item
{
  key Item.item_uuid             as OrderItemUUID,
      Header.supplier            as Supplier,
      Header.purchase_order      as PurchaseOrder,
      Item.item                  as PurchaseOrderItem,
      Item.delivery_date         as DeliveryDate,
      History.FirstReceiptDate,
      Item.unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      Item.quantity              as OrderedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      History.ReceivedQuantity,

      // The first goods receipt came on or before the agreed delivery date
      case when History.FirstReceiptDate <= Item.delivery_date then 1 else 0 end as IsOnTime,

      // The quantity is only judged once the item is complete or overdue
      case when Item.is_delivered = 'X' or Item.delivery_date < $session.system_date
           then 1 else 0 end                                                     as IsDue,

      case when Item.quantity = 0
           then cast( 0 as abap.dec( 7, 2 ) )
           else cast( division( abs( cast( History.ReceivedQuantity as abap.dec( 15, 3 ) )
                                   - cast( Item.quantity as abap.dec( 15, 3 ) ) ) * 100,
                                cast( Item.quantity as abap.dec( 15, 3 ) ), 2 ) as abap.dec( 7, 2 ) )
      end                                                                        as QuantityDeviationPercent
}
where
  Header.status <> 'REJ'
