"! Application log of BrewCore on top of the released Application Log API (CL_BALI_*).
"! Logs show up in the Fiori app Application Logs under object ZVHB_LOG.
CLASS zcl_vhb_app_log DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.
    INTERFACES zif_vhb_app_log.

    CONSTANTS c_log_object TYPE c LENGTH 20 VALUE 'ZVHB_LOG'.

    "! Creates a new, empty log
    "! @parameter subobject   | Subobject, see ZIF_VHB_APP_LOG=>SUBOBJECT
    "! @parameter external_id | Identifier shown in the Application Logs app, e.g. a document number
    "! @parameter result      | The new log
    CLASS-METHODS create
      IMPORTING
        subobject     TYPE zif_vhb_app_log=>ty_subobject
        external_id   TYPE csequence OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO zif_vhb_app_log.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA log         TYPE REF TO if_bali_log.
    DATA item_count  TYPE i.
    DATA error_count TYPE i.

    METHODS constructor
      IMPORTING
        log TYPE REF TO if_bali_log.

    METHODS add_item
      IMPORTING
        item TYPE REF TO if_bali_item_setter.

    METHODS to_bali_severity
      IMPORTING
        severity      TYPE zif_vhb_app_log=>ty_severity
      RETURNING
        VALUE(result) TYPE if_bali_constants=>ty_severity.

    METHODS count_if_error
      IMPORTING
        severity TYPE zif_vhb_app_log=>ty_severity.
ENDCLASS.



CLASS zcl_vhb_app_log IMPLEMENTATION.

  METHOD create.
    TRY.
        DATA(header) = cl_bali_header_setter=>create( object      = c_log_object
                                                      subobject   = subobject
                                                      external_id = CONV #( external_id ) ).
        result = NEW zcl_vhb_app_log( cl_bali_log=>create_with_header( header ) ).
      CATCH cx_bali_runtime INTO DATA(error).
        RAISE EXCEPTION NEW zcx_vhb_app_log( previous = error
                                             reason   = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD constructor.
    me->log = log.
  ENDMETHOD.

  METHOD zif_vhb_app_log~add_message.
    add_item( cl_bali_message_setter=>create( severity   = to_bali_severity( severity )
                                              id         = msgid
                                              number     = msgno
                                              variable_1 = CONV #( |{ v1 }| )
                                              variable_2 = CONV #( |{ v2 }| )
                                              variable_3 = CONV #( |{ v3 }| )
                                              variable_4 = CONV #( |{ v4 }| ) ) ).
    count_if_error( severity ).
    result = me.
  ENDMETHOD.

  METHOD zif_vhb_app_log~add_exception.
    add_item( cl_bali_exception_setter=>create( severity  = to_bali_severity( severity )
                                                exception = exception ) ).
    count_if_error( severity ).
    result = me.
  ENDMETHOD.

  METHOD zif_vhb_app_log~add_text.
    add_item( cl_bali_free_text_setter=>create( severity = to_bali_severity( severity )
                                                text     = CONV #( text ) ) ).
    count_if_error( severity ).
    result = me.
  ENDMETHOD.

  METHOD zif_vhb_app_log~has_errors.
    result = xsdbool( error_count > 0 ).
  ENDMETHOD.

  METHOD zif_vhb_app_log~get_item_count.
    " Counted here because IF_BALI_LOG->GET_ALL_ITEMS raises an exception for an empty log
    result = item_count.
  ENDMETHOD.

  METHOD zif_vhb_app_log~save.
    TRY.
        cl_bali_log_db=>get_instance( )->save_log( log                        = log
                                                   assign_to_current_appl_job = abap_true ).
      CATCH cx_bali_runtime INTO DATA(error).
        RAISE EXCEPTION NEW zcx_vhb_app_log( textid   = zcx_vhb_app_log=>save_failed
                                             previous = error
                                             reason   = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD add_item.
    TRY.
        log->add_item( item ).
        item_count += 1.
      CATCH cx_bali_runtime INTO DATA(error).
        RAISE EXCEPTION NEW zcx_vhb_app_log( previous = error
                                             reason   = error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD to_bali_severity.
    result = SWITCH #( severity
                       WHEN zif_vhb_app_log=>severity-error   THEN if_bali_constants=>c_severity_error
                       WHEN zif_vhb_app_log=>severity-warning THEN if_bali_constants=>c_severity_warning
                       WHEN zif_vhb_app_log=>severity-success THEN if_bali_constants=>c_severity_status
                       ELSE if_bali_constants=>c_severity_information ).
  ENDMETHOD.

  METHOD count_if_error.
    IF severity = zif_vhb_app_log=>severity-error.
      error_count += 1.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
