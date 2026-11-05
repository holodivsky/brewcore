# 4. Authorization by plant comes with the roles in v1.0

Status: accepted, 2026-11-04

## Context

The requirements ask for access control by plant on master data. In ABAP Cloud this needs an authorization object (`ZVHB_PLANT` with plant and activity), access controls on the consumption views that check it, and business roles that grant it.

The business roles are designed only in stage v1.0, when all modules exist. Until then there is nobody to grant the authorization to, and every user of the trial system would be locked out of the apps.

## Decision

- Stages v0.2 to v0.13 use `@AccessControl.authorizationCheck: #NOT_REQUIRED` and global authorization that allows every operation.
- The behavior pools already implement `get_global_authorizations`, so v1.0 only fills in the check and adds instance authorization by plant.
- Stage v1.0 creates the authorization object, the access controls for all consumption views and the five roles from the requirements in one step.

## Consequences

- The apps are usable in every stage without role setup.
- Plant-level security is tested once, end to end, across all modules instead of piece by piece.
- Until v1.0 the trial system does not separate data by plant. The demo data contains nothing confidential.
