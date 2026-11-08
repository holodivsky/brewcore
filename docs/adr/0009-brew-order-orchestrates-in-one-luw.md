# 9. The brew order drives inventory and the tank in one transaction

Status: accepted, 2026-11-08

## Context

A brew order runs through six phases: release, mashing, boiling, fermentation, maturation and filling. Three of them change other business objects:

- mashing takes the raw materials out of stock (movement type 261, goods issue to the order);
- fermentation occupies the fermentation tank;
- filling receives the beer into a new batch (movement type 101) and sends the tank to cleaning (CIP).

The phase of the order and the postings must not drift apart. An order in Mashing without the goods issue, or a beer batch without a filled order, would make stock and production disagree.

Purchasing solved a similar problem with a business event ([ADR 7](0007-goods-receipt-event.md)). There, inventory must not know purchasing, and the purchase order may lag a little behind the stock. Here the order itself starts the posting and the brewer expects the result at once. If the raw materials are missing, the phase must not start.

Release also has to plan two scarce resources:

- raw materials, which other released orders have already claimed;
- the tank, which is blocked for 28 days for a Pils (7 days fermentation, 21 days maturation).

## Decision

- The actions `startMashing`, `startFermentation` and `fill` of `ZVHB_R_BrewOrder` call the other business objects through EML: `postGoodsMovement` of the material document, and `occupy` or `empty` of the fermentation tank. RAP collects all changes in one transactional buffer and saves them together. If inventory or the tank rejects the request, the action fails and nothing is saved.
- Every material document item carries the brew order number (`brew_order` in `ZVHB_MDOCITM`). The order shows its goods movements and its beer batch through associations, so production keeps no copy of stock data.
- `occupy` and `empty` are internal actions of the tank. They are not exposed in the tank app, so a tank only becomes occupied through a brew order.
- Release checks the raw materials per material and storage location. The requirement of all components is compared with the free, unexpired stock minus the components of other released orders that are not mashed yet (`ZVHB_I_OpenRequirement`).
- Release checks the tank for overlapping brews. Two brews overlap when one starts before the other ends and ends after the other starts: `planned_start <= other end AND planned_end >= other start`. New and filled orders do not block the tank.

## Consequences

- A phase and its postings are saved together or not at all. The goods issue and the batch are visible on the order right after the action.
- Production depends on inventory and master data, which matches the package dependency. Inventory and the tank do not know production; the brew order number on the material document is only a reference.
- The checks on release run in the order's own validation and read the tables of the other modules. They only read; changes still go through the business objects.
- ABAP Unit covers the phases, the recipe copy and both checks. The calls into inventory and the tank are not doubled. They are checked with the demo data and in the app.
- Requirements are reserved only from release until mashing. A real MRP run with dates per requirement is outside the scope.
