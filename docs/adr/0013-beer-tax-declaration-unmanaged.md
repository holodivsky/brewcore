# 13. Beer tax: rates per plant, base from goods issues, declaration as unmanaged business object

Status: accepted, 2026-11-23

## Context

German beer tax (Biersteuer) arises when beer leaves the tax warehouse of the brewery. Every month the brewery declares the quantity to the customs office (Hauptzollamt). Section 2 of the Beer Tax Act (BierStG) defines the tariff:

- The tax is hectoliters × tax class × rate per hectoliter and degree Plato. The tax class is the original extract in whole degrees; fractions are disregarded.
- The standard rate is 0.787 EUR per hectoliter and degree.
- Legally and economically independent breweries with an annual output below 200,000 hl pay a reduced share: 50 % up to 5,000 hl, 60 % at 10,000 hl, 70 % at 20,000 hl and 75 % at 40,000 hl, rising evenly in steps of 1,000 hl. For reduced rates the rate is determined to four and the tax per hectoliter to two decimal places.
- The text does not state the share between 40,000 and 200,000 hl.

Beer that is exported is not taxed in Germany. A submitted declaration may not be changed.

## Decision

- **Rate per plant and date.** The rate is configuration (`ZVHB_R_BeerTaxRate`, app Beer Tax Rates):
  - plant, valid-from date, standard rate and the share the plant pays (50 % to 100 %);
  - the rate per hectoliter and degree is derived, four decimal places.

  BrewCore does not derive the share from the annual output. The customs office confirms the share of a brewery, and the law leaves the band above 40,000 hl open. Nordhopf belongs to a brewery group, is not independent and pays the standard rate.
- **Original extract on the material.** The material master carries the original extract registered with customs (`OriginalExtract`, °P), as the excise duty data of a material in S/4HANA. Bottles are converted to hectoliters with the alternative unit HL (200 bottles of 0.5 l = 1 hl).
- **Base from the goods issues.** `ZVHB_I_BeerTaxBaseItem` reads the delivery items of finished beer whose goods issue (movement type 601) is posted, in the month of the goods issue. Crates and other deposit items are not beer. A customer outside Germany makes the line an export, free of tax. `ZVHB_I_BeerTaxBase` sums the lines per plant, month, material, tax class and treatment.
- **Calculation in one class.** `ZCL_VHB_BEER_TAX` holds the tariff: tax class, rate, tax per hectoliter and the lines and totals of a month. It reads no data and is tested on its own.
- **Declaration as unmanaged business object.** `ZVHB_R_BeerTaxDeclaration` with items is implemented by hand:
  - a transactional buffer keeps the headers and items changed in the transaction; read, read by association and the actions see it before anything is saved;
  - `generate` (static factory action) checks month, plant, rate and that the month has no declaration yet, then builds header and items from the base;
  - `recalculate` rebuilds the items of a draft, `submit` sets status Submitted with user and time, `delete` removes a draft;
  - instance features disable all three for a submitted declaration, and the actions check the status again;
  - locking uses the lock object `EZVHB_BTDECL`;
  - the saver draws the declaration number from `ZVHB_DECL` in `finalize` and writes the buffer in `save`.

## Consequences

- The declaration only changes through its actions. Numbers, rate and quantities cannot be typed in.
- The rate of a declaration is the one valid on the last day of its month. A later rate change does not touch submitted declarations; a draft picks it up with Recalculate.
- Goods issues are counted when they are posted. Deliveries that are picked but not issued, and reversals of goods issues, are not part of the base yet.
- The unmanaged business object has no draft and no side effects; the Fiori app shows it read-only with action buttons. In return every step of the save sequence is visible in the code.
- Small breweries are supported by entering their share; the step calculation by annual output is left to the customs notice.
