# 11. Order-to-cash: one business object per document, availability and credit in CDS

Status: accepted, 2026-11-08

## Context

Selling bottled beer runs through three documents: the sales order, the delivery and the billing document. On the way the brewery has to answer four questions:

- What does an item cost? The base price depends on the distribution channel, quantity scales give a discount, and returnable crates carry a deposit that is not part of the revenue.
- How much can be confirmed? Free stock minus what other open orders have already been promised (available to promise, ATP).
- May the customer order more? Open orders and unpaid invoices must stay within the credit limit.
- Which batches leave the warehouse? Beer goes out first expired, first out (FEFO), and the crates go to the customer and come back later.

The prices must be visible while the order is still a draft, and the numbers must be the same in the app, in the checks and in reports.

## Decision

- **Three business objects.** Sales order (with draft), delivery and billing document are separate business objects in `Z_VH_BREW_SD`.
  - The order action `createDelivery` creates the delivery.
  - The delivery actions `postGoodsIssue` and `createInvoice` post the goods issue and create the invoice.
  - The static action `returnEmpties` of the billing document creates a credit memo.
  - Each action calls the next business object through EML. Its changes are saved in the same transaction ([ADR 9](0009-brew-order-orchestrates-in-one-luw.md)).
- **Pricing.** A determination on material and quantity prices the item:
  - it takes the base price of the channel valid today;
  - it applies the highest quantity scale that is reached;
  - for a material sold in returnable packaging, it keeps one deposit item as a sub-item (product 00010, deposit 00011): crates = bottles / 20 rounded up, at the deposit rate of the crate.

  The material master says which packaging a material is sold in and how many units fit in (`ReturnablePackaging`, `UnitsPerPackage`). Side effects refresh price, confirmed quantity and totals while the user types.
- **Availability.** It is calculated in CDS:
  - `ZVHB_I_SalesFreeStock` sums the free, unexpired stock;
  - `ZVHB_I_OrderDemand` sums the confirmed quantities of open and credit-blocked orders;
  - `ZVHB_I_AvailableToPromise` subtracts the demand from the free stock.

  The item confirms what is available plus what the same order had already confirmed. A partial confirmation is allowed and reported as a warning.
- **Credit exposure.** `ZVHB_I_CreditExposureItem` is a union of open and delivered orders and of billing documents, where credit memos count negative. On save, the order compares the exposure of the customer plus its own total with the credit limit. If the limit is exceeded, the order is blocked. Release Credit Block lifts the block by hand.
- **Delivery.** The delivery is picked by FEFO from `ZVHB_I_FEFOBatch`, so one order item can be split over several batches. The crates are a delivery item of their own from the empties store. The goods issue posts movement type 601 for all items.
- **Invoice and empties.**
  - The invoice bills the delivered quantity at the net price per unit of the order item, and batch splits are billed as one line.
  - Returned crates are received with the new movement type 653 and credited at the deposit rate.
  - `ZVHB_C_EmptiesBalance` shows the crates at each customer: issued with goods issues minus returned with credit memos.

## Consequences

- The rules are where they belong: price and availability on the item, credit on the order, picking on the delivery. Every document can be opened on its own.
- ATP, exposure and empties balance are views. Reports and the business objects read the same numbers.
- Quantities are reserved only by confirmation, not by delivery. A delivery that is picked but not issued yet does not block the stock for other deliveries.
- The unconfirmed rest of a partially confirmed order is not delivered later. Back orders and rescheduling are outside the scope.
- Payments are not recorded, so every invoice counts as open in the credit exposure until accounting follows.
- The deposit is a separate amount on order and invoice and does not count as revenue.
