# 1. Subpackages without package encapsulation

Status: accepted, 2026-10-25

## Context

Each module (MD, MM, IM, PP, QM, SD, FI, AN) lives in its own subpackage of `Z_VH_BREW`. All modules reuse data elements and domains from `Z_VH_BREW_CORE`, for example quantity, unit, plant and batch.

With encapsulated packages, every object used by another package has to be listed in a package interface. Otherwise the package check reports violations, and the definition of done asks for an ATC run without findings of priority 1 and 2.

## Decision

- `Z_VH_BREW` stays encapsulated, so nothing outside BrewCore depends on its internals.
- The subpackages are not encapsulated.
- Module boundaries are enforced by the architecture instead: modules call each other only through EML and RAP business events and never access another module's tables.

## Consequences

- No package interfaces to maintain for every new data element in CORE.
- The system does not stop a module from reading another module's tables. Code review and the EML-only rule have to cover that.
- If BrewCore grows into separately deployed components, package interfaces can be added later per subpackage.
