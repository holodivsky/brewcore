# 5. UUID key with the partner number assigned on save

Status: accepted, 2026-11-05

## Context

Business partners get a number from the number range `ZVHB_PARTN`. The number should be assigned when the partner is saved, not when the user opens a draft, so discarded drafts do not use up numbers.

RAP offers late numbering for this. The key stays empty until the save sequence, the framework works with a preliminary ID (`%pid`), and `adjust_numbers` in the saver class maps it to the final key. With draft, this mapping also has to cover the draft instance and every child entity that holds the parent key.

## Decision

- The technical key is a UUID, `PartnerUUID`, with `numbering : managed`. Drafts and the child entity `Role` use it from the first moment.
- The business partner number `Partner` is a read-only field. The determination `setPartnerNumber` on save fills it from `ZVHB_PARTN` through `ZIF_VHB_NUMBER_RANGE`.
- `Partner` is the semantic key in the projection, so the Fiori app shows and searches the number, not the UUID.
- Price conditions follow the same pattern without a number: UUID key, readable fields for the user.

## Consequences

- No preliminary IDs and no `adjust_numbers` logic. Draft, child entities and unit tests need no special handling.
- A draft shows no partner number until it is saved for the first time.
- If the number range fails, the save stops with message `ZVHB_MD/019` and nothing is written.
- The number range is buffered (see [ADR 2](0002-number-ranges.md)), so partner numbers can have gaps, for example `1000000000` followed by `1000000010`.
- Document business objects in later stages will decide between this pattern and real late numbering once they are built.
