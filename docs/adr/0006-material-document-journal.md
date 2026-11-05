# 6. The material document is an append-only journal

Status: accepted, 2026-11-05

## Context

Every stock change in BrewCore, from goods receipts to production issues, deliveries and scrapping, is a material document, as in S/4HANA (table MATDOC). Inventory figures and the beer tax depend on these documents, so a posted document must never change. A mistake is corrected with a reversal document that cancels the original one.

Material and partner master data use managed RAP with draft (see [ADR 5](0005-partner-number-on-save.md)). That model fits data that people edit; it does not fit a journal that is only written once.

## Decision

- `ZVHB_R_MaterialDocument` with its items is a managed BO **with unmanaged save** and **late numbering**, without draft.
- Create is `internal`, the BO has no update and no delete. Documents come into being only through two factory actions:
  - the static action `postGoodsMovement` with the parameter entity `ZVHB_D_GoodsMovement`, which checks the movement and creates a one-item document;
  - the instance action `reverse`, which creates the mirror document (101 becomes 102, 261 becomes 262 and so on) and points to the original one.
- The saver assigns the document number from `ZVHB_MDOC` in `adjust_numbers` and numbers the items per document. `save_modified` only inserts rows.
- Stock is never stored. `ZVHB_I_StockMovement` turns every item into signed quantities, a transfer posting into two lines; `ZVHB_I_Stock` sums them per material, plant, storage location and batch and splits free and blocked stock by batch status.
- Batches are a separate BO `ZVHB_R_Batch`. A receipt of a batch-managed material without a batch creates a new batch with a number from `ZVHB_BATCH`; the best-before date follows from the shelf life of the material.
- An issue without a batch takes the batch proposed by `ZVHB_I_FefoBatch`: free stock, not expired, earliest best-before date first.

## Consequences

- A document number exists only after the save. Callers get a preliminary ID in `mapped` and read the number after the commit.
- Corrections are visible: the original document and its reversal both stay in the journal.
- Stock figures always match the documents, because there is nothing else to keep in sync. The cost is an aggregation on every read, which the CDS views push to the database.
- Later stages (purchasing, production, sales) post through the same action, so every rule on stock is checked in one place.
