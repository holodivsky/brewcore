"! Application log of BrewCore (log object ZVHB_LOG).
"! Collect messages during a job or mass action, then call save once.
INTERFACE zif_vhb_app_log
  PUBLIC .

  TYPES ty_severity  TYPE c LENGTH 1.
  TYPES ty_subobject TYPE c LENGTH 20.

  CONSTANTS:
    BEGIN OF severity,
      error   TYPE ty_severity VALUE 'E',
      warning TYPE ty_severity VALUE 'W',
      info    TYPE ty_severity VALUE 'I',
      success TYPE ty_severity VALUE 'S',
    END OF severity.

  CONSTANTS:
    "! Subobjects maintained in application log object ZVHB_LOG
    BEGIN OF subobject,
      setup        TYPE ty_subobject VALUE 'SETUP',
      demo_data    TYPE ty_subobject VALUE 'DEMO_DATA',
      reorder      TYPE ty_subobject VALUE 'REORDER',
      batch_expiry TYPE ty_subobject VALUE 'BATCH_EXPIRY',
      mass_action  TYPE ty_subobject VALUE 'MASS_ACTION',
    END OF subobject.

  "! Adds a message from a message class
  "! @parameter severity | Severity, see constants SEVERITY
  "! @parameter msgid    | Message class, e.g. ZVHB_MM
  "! @parameter msgno    | Message number
  "! @parameter result   | The log itself, for chaining
  METHODS add_message
    IMPORTING
      severity      TYPE ty_severity DEFAULT severity-info
      msgid         TYPE symsgid
      msgno         TYPE symsgno
      v1            TYPE simple OPTIONAL
      v2            TYPE simple OPTIONAL
      v3            TYPE simple OPTIONAL
      v4            TYPE simple OPTIONAL
    RETURNING
      VALUE(result) TYPE REF TO zif_vhb_app_log.

  "! Adds an exception with its text and the chain of previous exceptions
  METHODS add_exception
    IMPORTING
      severity      TYPE ty_severity DEFAULT severity-error
      exception     TYPE REF TO cx_root
    RETURNING
      VALUE(result) TYPE REF TO zif_vhb_app_log.

  "! Adds a free text; prefer ADD_MESSAGE for anything a user reads
  METHODS add_text
    IMPORTING
      severity      TYPE ty_severity DEFAULT severity-info
      text          TYPE csequence
    RETURNING
      VALUE(result) TYPE REF TO zif_vhb_app_log.

  "! True if at least one error or exception was added
  METHODS has_errors
    RETURNING
      VALUE(result) TYPE abap_bool.

  "! Number of items added so far
  METHODS get_item_count
    RETURNING
      VALUE(result) TYPE i.

  "! Writes the log to the database; assigns it to the current application job if there is one
  METHODS save.

ENDINTERFACE.
