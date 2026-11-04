CLASS zcx_vhb_app_log DEFINITION
  PUBLIC
  INHERITING FROM cx_no_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_t100_message .
    INTERFACES if_t100_dyn_msg .

    CONSTANTS:
      "! Generic runtime failure of the Application Log API
      BEGIN OF runtime_error,
        msgid TYPE symsgid VALUE 'ZVHB_CORE',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'REASON',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF runtime_error,
      "! The log could not be written to the database
      BEGIN OF save_failed,
        msgid TYPE symsgid VALUE 'ZVHB_CORE',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE 'REASON',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF save_failed.

    "! Text of the underlying exception
    DATA reason TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid   LIKE if_t100_message=>t100key OPTIONAL
        !previous LIKE previous OPTIONAL
        !reason   TYPE string OPTIONAL.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_vhb_app_log IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->reason = reason.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = runtime_error.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
