# 3. Domains only where fixed values are needed

Status: accepted, 2026-10-25

## Context

Classic ABAP creates a domain for almost every data element. In ABAP Cloud a data element can use a built-in type directly, and the RAP generators do the same.

## Decision

- Domains exist only for closed value sets with fixed values: plant, storage location, distribution channel, material type.
- All other shared data elements in `Z_VH_BREW_CORE` use built-in types, for example `ZVHB_QUANTITY` (QUAN 13,3) and `ZVHB_PLATO` (DEC 4,1).
- Data elements and domains go into CORE only when more than one module needs them. Module-specific types such as document statuses live in the module package.
- Administrative fields reuse the released data elements `ABP_CREATION_USER`, `ABP_CREATION_TSTMPL`, `ABP_LASTCHANGE_USER`, `ABP_LASTCHANGE_TSTMPL` and `ABP_LOCINST_LASTCHANGE_TSTMPL`.

## Consequences

- Fewer repository objects, and each domain carries real meaning.
- Value helps for fixed-value domains come from the domain itself.
- Material numbers are entered as readable IDs such as `PILS-BTL05`. Without a domain there is no automatic upper-case conversion, so a validation in the material business object has to normalise the input.
