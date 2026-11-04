"! <p><strong>BrewCore</strong> - end-to-end ERP for the fictional brewery Nordhopf Brauerei GmbH,
"! built on SAP BTP ABAP Environment with ABAP Cloud, RAP and Fiori.</p>
"!
"! <p>Each module is a subpackage with its own RAP business objects. Modules talk to each other
"! only through EML and RAP business events and never write into another module's tables.</p>
"!
"! <ul>
"! <li>Z_VH_BREW_CORE - domains, data elements, number ranges, application log</li>
"! <li>Z_VH_BREW_MD - master data: materials, business partners, recipes, tanks</li>
"! <li>Z_VH_BREW_MM - procurement: requisitions, purchase orders, invoice verification</li>
"! <li>Z_VH_BREW_IM - inventory: material documents, batches, returnable empties</li>
"! <li>Z_VH_BREW_PP - production: brew orders, tank planning</li>
"! <li>Z_VH_BREW_QM - quality: inspection lots, usage decisions</li>
"! <li>Z_VH_BREW_SD - sales: sales orders, deliveries, billing</li>
"! <li>Z_VH_BREW_FI - German beer tax (Biersteuer) declarations</li>
"! <li>Z_VH_BREW_AN - analytics: cubes, queries, KPIs</li>
"! </ul>
"!
"! <p>Set up a fresh system: pull the repository with abapGit, run ZCL_VHB_SETUP_NUMBER_RANGES,
"! then the demo data generator. Run this class with F9 for the same overview in the console.</p>
CLASS zcl_vhb_readme DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    TYPES:
      BEGIN OF ty_module,
        package     TYPE c LENGTH 30,
        description TYPE string,
      END OF ty_module,
      tt_modules TYPE STANDARD TABLE OF ty_module WITH KEY package.

    "! Subpackages of Z_VH_BREW with their purpose
    METHODS get_modules
      RETURNING
        VALUE(result) TYPE tt_modules.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_vhb_readme IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    out->write( name = `BrewCore modules` data = get_modules( ) ) ##NO_TEXT.
  ENDMETHOD.

  METHOD get_modules.
    result = VALUE #(
      ( package = 'Z_VH_BREW_CORE' description = `Domains, data elements, number ranges, application log` )
      ( package = 'Z_VH_BREW_MD'   description = `Master data: materials, business partners, recipes, tanks` )
      ( package = 'Z_VH_BREW_MM'   description = `Procurement: requisitions, purchase orders, invoice verification` )
      ( package = 'Z_VH_BREW_IM'   description = `Inventory: material documents, batches, returnable empties` )
      ( package = 'Z_VH_BREW_PP'   description = `Production: brew orders, tank planning` )
      ( package = 'Z_VH_BREW_QM'   description = `Quality: inspection lots, usage decisions` )
      ( package = 'Z_VH_BREW_SD'   description = `Sales: sales orders, deliveries, billing` )
      ( package = 'Z_VH_BREW_FI'   description = `German beer tax (Biersteuer) declarations` )
      ( package = 'Z_VH_BREW_AN'   description = `Analytics: cubes, queries, KPIs` ) ) ##NO_TEXT.
  ENDMETHOD.

ENDCLASS.
