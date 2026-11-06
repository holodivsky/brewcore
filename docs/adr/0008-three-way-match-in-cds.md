# 8. The 3-way match is calculated in CDS

Status: accepted, 2026-11-06

## Context

Before a supplier invoice is paid, it is compared with two other documents: the purchase order (what price was agreed) and the goods receipt (what really arrived). In S/4HANA this is the 3-way match of logistics invoice verification (MIRO). A price that deviates by more than a tolerance, or more quantity than was received, blocks the invoice for payment until a person decides.

The same figures are needed in three places:

- when the invoice is posted, to decide between Posted and Blocked;
- while the invoice is entered, as a hint per item;
- in the supplier score, which rates suppliers by their price deviation.

The received quantity must come from inventory. The purchase order item also has a received quantity, but it is updated asynchronously by the event handler of [ADR 7](0007-goods-receipt-event.md) and may lag behind.

## Decision

- `ZVHB_I_PurchaseOrderHistory` sums the goods receipts per order item from the material documents (101 adds, 102 takes back) and keeps the first receipt date.
- `ZVHB_I_InvoicedQuantity` sums what posted and blocked invoices have already charged per order item.
- `ZVHB_I_InvoiceItemFigures` puts order price, received quantity, quantity of other invoices and the invoice item side by side. `coalesce` turns a missing receipt into zero, `case` keeps the current invoice out of the other invoices, and `division` gives the price deviation in percent.
- `ZVHB_I_SupplierInvoiceMatch` turns the figures into a result per item: `PRIC` above 2 % price deviation, `QUAN` when all invoices together charge more than was received, otherwise `OK`.
- The action `post` of the supplier invoice reads only the items that do not match and sets the status to Posted or Blocked. Release for Payment and Reject are the manual decision on a blocked invoice.
- The hint while entering an invoice is a virtual element (`ZCL_VHB_INVOICE_ITEM_MATCH`). Drafts are not in the database tables that the views read, so the hint is calculated from the fields of the row: invoiced price and quantity, order price and the received quantity of the order item.
- The supplier score reads the same match view, so the price criterion uses exactly the deviations that blocked invoices.

## Consequences

- The rule is in one place for posting and for analytics, and it runs on the database.
- The tolerance exists twice: as the literal 2 in the view and as `ZCL_VHB_PURCHASING_CHECK=>c_price_tolerance` for the hint and the messages. Both carry a comment that points to the other.
- The hint is a preview. It compares with the received quantity of the order item and ignores other invoices; the binding result is the one of the view on posting.
- The views read the tables of inventory and purchasing directly. They only read, so the rule that modules never write into each other's tables still holds.
