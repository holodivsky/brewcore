# 10. Inspection lots are opened from the goods receipt event

Status: accepted, 2026-11-08

## Context

Quality management has to inspect two kinds of goods before they can be used:

- every new batch of beer, received from a brew order when the tank is filled;
- raw materials from a supplier whose quality is not proven yet.

Until the usage decision, nobody may use the stock of the batch. On rejection, the stock must leave the warehouse.

Inventory already raises the business event `GoodsReceiptPosted` for receipts against a purchase order, and purchasing listens to it ([ADR 7](0007-goods-receipt-event.md)). The brew order posts its receipt in the same transaction as the filling ([ADR 9](0009-brew-order-orchestrates-in-one-luw.md)). The question was how quality management learns about both kinds of receipts without inventory or production knowing quality management.

## Decision

- Inventory publishes `GoodsReceiptPosted` for every goods receipt (101) and its reversal (102) that refers to a purchase order or a brew order. The payload now also carries the brew order, plant, storage location and unit. Purchasing ignores items without a purchase order.
- `ZCL_VHB_QM_GOODS_RECEIPT` in `Z_VH_BREW_QM` is a second handler of the same event. It passes the receipts into a new batch to the static action `createFromGoodsReceipt` of the inspection lot, in its own transaction.
- The inspection lot decides whether a receipt needs a lot:
  - each batch gets at most one lot, even when the event arrives twice;
  - a beer batch from a brew order always gets one;
  - a raw material from a purchase order gets one until the supplier has an accepted lot of that material.
- When the lot is opened, the batch is set to Blocked through the batch action `block`. Blocked stock is not free for FEFO, brew order release or other issues.
- The characteristics are copied into the lot when it is opened, so a later change of the recipe does not change an open inspection:
  - beer: original extract and alcohol around the targets of the recipe version of the brew order (±0.3 °P, ±0.2 % vol), pH 4.2 to 4.6, microbiology (0 or 1) and a sensory score from 1 to 5, at least 3;
  - raw material: contamination and appearance.
- The usage decision is made with two actions:
  - Accept requires every characteristic to be recorded and within its limits, then releases the batch;
  - Reject keeps the batch blocked and scraps its stock in the storage location of the lot with movement type 551.

  The lot, the batch and the material document are saved in one transaction.
- The rules for a single result (number, 0 or 1, whole score, within limits) are in `ZCL_VHB_CHARACTERISTIC_CHECK`. The lot uses them on save and on Accept. The app uses them as virtual elements, so the valuation is visible while results are still in the draft.
- The supplier score reads the share of accepted raw material lots among all decided ones (`ZVHB_I_SupplierQualityKPI`).

## Consequences

- Inventory and production do not know quality management; the receipt is the only contract.
- The handler runs after the receipt is committed. For a short moment the new batch is free, before the handler blocks it. A failure in the handler leaves the batch free and without a lot. This is visible in the lot list, and the demo class shows how to open missing lots.
- Receipts posted before quality management existed got no event. `ZCL_VHB_DEMO_DATA` opens their lots through the same static action.
- Reversals (102) do not cancel an open lot yet. The lot is then decided by hand.
- The supplier score in purchasing reads a view of quality management. This is a read-only dependency from MM to QM, which is allowed by the rule that modules only write through business objects.
- The tolerances around the recipe targets are constants in the lot, not fields of the recipe. A tolerance per recipe would need new fields in master data and is left for later.
