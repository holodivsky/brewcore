# BrewCore

End-to-end ERP for a fictional German brewery, built on SAP BTP ABAP Environment with ABAP Cloud, RAP and Fiori.

![abaplint](https://github.com/holodivsky/brewcore/actions/workflows/abaplint.yml/badge.svg)
![ABAP Cloud](https://img.shields.io/badge/ABAP-Cloud-0a6ed1)
![License](https://img.shields.io/badge/license-MIT-green)

<!-- End-to-end demo GIF goes here once the first business process is in place -->

BrewCore follows beer from the malt purchase to the customer invoice and the monthly beer tax declaration of Nordhopf Brauerei GmbH, a regional brewery with about 80,000 hl per year. Company, volumes and partners are invented.

## What it does

| Process | Modules | Stage |
|---|---|---|
| Procure-to-Pay with 3-way match | MM, IM | v0.5, v0.6 |
| Plan-to-Produce with batches and fermentation tanks | PP, IM | v0.7 |
| Inspect-to-Release | QM | v0.8 |
| Stock-to-Ship with FEFO and returnable empties | IM | v0.4 |
| Order-to-Cash with ATP and deposit (Pfand) | SD | v0.9 |
| German beer tax (Biersteuer) by degrees Plato | FI | v0.11 |
| Management KPIs | AN | v0.12 |

The BTP ABAP Environment has no standard MM, PP or SD. Every business object here is written from scratch, but follows S/4HANA logic and terms: movement types 101/261/601, batch status, 3-way match, document number ranges.

## Architecture

```
Z_VH_BREW            superpackage, overview class ZCL_VHB_README
├── Z_VH_BREW_CORE   domains, data elements, number ranges, application log
├── Z_VH_BREW_MD     master data: materials, partners, recipes, tanks
├── Z_VH_BREW_MM     procurement
├── Z_VH_BREW_IM     inventory: material documents, batches, empties
├── Z_VH_BREW_PP     production: brew orders, tank planning
├── Z_VH_BREW_QM     quality: inspection lots, usage decisions
├── Z_VH_BREW_SD     sales: orders, deliveries, billing
├── Z_VH_BREW_FI     beer tax declarations
└── Z_VH_BREW_AN     analytics
```

- Modules talk to each other only through EML and RAP business events and never write into another module's tables.
- Stock is never stored. It is a CDS aggregation over material documents, as in S/4HANA (MATDOC).
- Document numbers come from number ranges and are assigned on save, not when the draft is created.

Design decisions are recorded in [docs/adr](docs/adr).

## Tech stack

RAP (managed, unmanaged save, unmanaged), CDS view entities, Fiori Elements, SAPUI5, RAP business events, application jobs, application logs, number ranges, ABAP Unit, ATC, abaplint in GitHub Actions, abapGit.

## How to run it

1. Get an SAP BTP ABAP Environment (the trial works).
2. Create package `Z_VH_BREW` and pull this repository with abapGit.
3. Run `ZCL_VHB_SETUP_NUMBER_RANGES` with F9 in ADT to create the number range intervals.
4. Run `ZCL_VHB_DEMO_DATA` with F9 to create the demo master data.
5. Open the Fiori Elements preview from the service bindings.

## Stages

Every stage is a tagged release with a description and screenshots in `docs/screenshots/<tag>/`.

| Tag | Stage | Status |
|---|---|---|
| [v0.1](https://github.com/holodivsky/brewcore/releases/tag/v0.1) | Foundation: packages, DDIC basics, number ranges, application log, CI | released |
| [v0.2](https://github.com/holodivsky/brewcore/releases/tag/v0.2) | Master data: materials, business partners, price conditions | released |
| [v0.3](https://github.com/holodivsky/brewcore/releases/tag/v0.3) | Recipes and fermentation tanks | released |
| [v0.4](https://github.com/holodivsky/brewcore/releases/tag/v0.4) | Inventory and batches | released |
| [v0.5](https://github.com/holodivsky/brewcore/releases/tag/v0.5) | Procurement | released |
| [v0.6](https://github.com/holodivsky/brewcore/releases/tag/v0.6) | Invoice verification and supplier rating | released |
| [v0.7](https://github.com/holodivsky/brewcore/releases/tag/v0.7) | Production | released |
| v0.8 | Quality | planned |
| v0.9 | Sales | planned |
| v0.10 | Automation with application jobs | planned |
| v0.11 | Beer tax | planned |
| v0.12 | Analytics | planned |
| v0.13 | Tank board (freestyle UI5) | planned |
| v1.0 | Roles, end-to-end demo, case study | planned |
| v1.1 | Warehouse (EWM-lite) | planned |

## About

<!-- Add a short note about yourself, your LinkedIn profile and the SAP certification once available -->
