# 7. Purchasing learns about goods receipts from a business event

Status: accepted, 2026-11-06

## Context

A goods receipt for a purchase order touches two modules. Inventory has to post a material document with movement type 101 and create the batch; purchasing has to raise the received quantity of the order item and close the order once everything has arrived.

The README sets the rule that modules never write into each other's tables. Inventory already has a single entry point for every stock change, the action `postGoodsMovement` (see [ADR 6](0006-material-document-journal.md)). The open question was how purchasing finds out that a receipt has been posted, including receipts and reversals that are not started from the purchase order app.

Three options were considered:

1. Purchasing posts the receipt and updates its own item in the same request.
2. Inventory calls purchasing through EML after posting.
3. Inventory raises a RAP business event, and purchasing reacts to it.

Option 1 misses receipts that are reversed later in the inventory app. Option 2 makes inventory depend on purchasing, which turns the package dependency upside down, because every later module (production, sales) would have to be known to inventory.

## Decision

- The material document BO declares `event GoodsReceiptPosted parameter ZVHB_D_GoodsReceiptPosted`. The saver raises it in `save_modified` for every item that refers to a purchase order, with document item, movement type, order, order item, material, batch and quantity.
- The purchase order item action `receiveGoods` only checks the order (ordered, quantity above zero, not above the open quantity) and calls `postGoodsMovement` with movement type 101 and the order reference. It does not change the order item.
- `ZCL_VHB_PO_GOODS_RECEIPT` in `Z_VH_BREW_MM` is the event handler (`FOR EVENTS OF zvhb_r_materialdocument`). It finds the order item by number, turns a 102 reversal into a negative quantity and calls the internal action `applyGoodsReceipt`, which updates the received quantity, the delivered flag and the order status.
- The handler opens its own transaction with `cl_abap_tx=>modify( )` and `cl_abap_tx=>save( )`; `COMMIT ENTITIES` is not allowed there.
- `applyGoodsReceipt` is not exposed in the projection, so a user cannot set the received quantity by hand.

## Consequences

- Inventory does not know purchasing. Production and sales can subscribe to the same pattern later without changes in inventory.
- Reversals of a receipt in the inventory app also lower the received quantity of the order.
- The handler runs asynchronously after the commit. The purchase order shows the new received quantity only after a refresh, and a failure in the handler does not roll back the material document. A failed update is visible as an open quantity that does not match the stock.
- The event handler itself is not covered by ABAP Unit. The action `applyGoodsReceipt` that it calls is.
