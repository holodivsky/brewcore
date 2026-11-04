CLASS zcx_vhb_number_range DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_t100_message .
    INTERFACES if_t100_dyn_msg .

    CONSTANTS:
      "! No number could be drawn from the interval
      BEGIN OF no_number_available,
        msgid TYPE symsgid VALUE 'ZVHB_CORE',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE 'OBJECT',
        attr2 TYPE scx_attrname VALUE 'INTERVAL',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_number_available.

    DATA object   TYPE cl_numberrange_runtime=>nr_object READ-ONLY.
    DATA interval TYPE cl_numberrange_runtime=>nr_interval READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid   LIKE if_t100_message=>t100key OPTIONAL
        !previous LIKE previous OPTIONAL
        !object   TYPE cl_numberrange_runtime=>nr_object OPTIONAL
        !interval TYPE cl_numberrange_runtime=>nr_interval OPTIONAL.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_vhb_number_range IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->object   = object.
    me->interval = interval.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = no_number_available.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
