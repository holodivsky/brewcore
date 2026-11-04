# 2. One number range object per document type, one interval each

Status: accepted, 2026-10-25

## Context

BrewCore needs document numbers for business partners, batches, material documents, purchase requisitions and orders, supplier invoices, brew orders, inspection lots, sales orders, deliveries, billing documents and beer tax declarations.

ABAP Cloud offers number range objects with the released APIs `CL_NUMBERRANGE_RUNTIME` and `CL_NUMBERRANGE_INTERVALS`. Intervals are runtime data and are not part of the repository, so a fresh system has none after an abapGit pull.

## Decision

- One number range object per document type, 12 in total, all in `Z_VH_BREW_CORE`, number length 10.
- Each object has exactly one internal interval `01`.
- The first two digits identify the document type, as in S/4HANA: `45...` purchase order, `49...` material document, `51...` supplier invoice, `80...` delivery, `90...` billing document.
- Main memory buffering, no rolling. Gaps in numbers are acceptable for all document types.
- `ZCL_VHB_SETUP_NUMBER_RANGES` creates missing intervals and can be run any number of times.
- Business objects use `ZIF_VHB_NUMBER_RANGE`, so unit tests can replace number assignment with a test double.

## Consequences

- A document number alone tells which document it is, which helps when reading logs and screenshots.
- After setting up a new system, one class has to be run once before any document can be saved.
- Gapless numbering, if ever required for tax declarations, would need buffering switched off for that object.
