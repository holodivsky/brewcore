*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

"! Transactional buffer of the unmanaged declaration: headers and items changed in this transaction.
"! Handlers read through it, so they see their own changes before the saver writes them.
CLASS lcl_buffer DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_header.
        INCLUDE TYPE zvhb_btdecl.
    TYPES:
        change TYPE c LENGTH 1,
      END OF ty_header,
      tt_headers TYPE STANDARD TABLE OF ty_header WITH EMPTY KEY,
      BEGIN OF ty_item.
        INCLUDE TYPE zvhb_btdeclitm.
    TYPES:
        change TYPE c LENGTH 1,
      END OF ty_item,
      tt_items     TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY,
      tt_db_items  TYPE STANDARD TABLE OF zvhb_btdeclitm WITH EMPTY KEY,
      ty_header_entity TYPE STRUCTURE FOR READ RESULT zvhb_r_beertaxdeclaration\\Declaration,
      ty_item_entity   TYPE STRUCTURE FOR READ RESULT zvhb_r_beertaxdeclaration\\Item.

    CONSTANTS:
      BEGIN OF changes,
        created TYPE c LENGTH 1 VALUE 'C',
        updated TYPE c LENGTH 1 VALUE 'U',
        deleted TYPE c LENGTH 1 VALUE 'D',
      END OF changes.

    CLASS-DATA headers TYPE tt_headers.
    CLASS-DATA items TYPE tt_items.

    "! The header as this transaction sees it; initial if it does not exist or is deleted
    CLASS-METHODS get_header
      IMPORTING
        uuid          TYPE sysuuid_x16
      RETURNING
        VALUE(result) TYPE zvhb_btdecl.

    "! The items of a declaration as this transaction sees them
    CLASS-METHODS get_items
      IMPORTING
        decl_uuid     TYPE sysuuid_x16
      RETURNING
        VALUE(result) TYPE tt_db_items.

    CLASS-METHODS get_item
      IMPORTING
        uuid          TYPE sysuuid_x16
      RETURNING
        VALUE(result) TYPE zvhb_btdeclitm.

    CLASS-METHODS set_header
      IMPORTING
        header TYPE zvhb_btdecl
        change TYPE c.

    CLASS-METHODS set_item
      IMPORTING
        item   TYPE zvhb_btdeclitm
        change TYPE c.

    CLASS-METHODS to_entity
      IMPORTING
        header        TYPE zvhb_btdecl
      RETURNING
        VALUE(result) TYPE ty_header_entity.

    CLASS-METHODS item_to_entity
      IMPORTING
        item          TYPE zvhb_btdeclitm
      RETURNING
        VALUE(result) TYPE ty_item_entity.

    CLASS-METHODS clear.
ENDCLASS.


CLASS lcl_buffer IMPLEMENTATION.

  METHOD get_header.
    READ TABLE headers INTO DATA(buffered) WITH KEY decl_uuid = uuid.
    IF sy-subrc = 0.
      IF buffered-change <> changes-deleted.
        result = CORRESPONDING #( buffered ).
      ENDIF.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zvhb_btdecl WHERE decl_uuid = @uuid INTO @result.
  ENDMETHOD.

  METHOD get_items.
    SELECT * FROM zvhb_btdeclitm WHERE decl_uuid = @decl_uuid INTO TABLE @result.

    LOOP AT items INTO DATA(buffered) WHERE decl_uuid = decl_uuid.
      DELETE result WHERE item_uuid = buffered-item_uuid.
      IF buffered-change <> changes-deleted.
        APPEND CORRESPONDING #( buffered ) TO result.
      ENDIF.
    ENDLOOP.

    SORT result BY item.
  ENDMETHOD.

  METHOD get_item.
    READ TABLE items INTO DATA(buffered) WITH KEY item_uuid = uuid.
    IF sy-subrc = 0.
      IF buffered-change <> changes-deleted.
        result = CORRESPONDING #( buffered ).
      ENDIF.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zvhb_btdeclitm WHERE item_uuid = @uuid INTO @result.
  ENDMETHOD.

  METHOD set_header.
    READ TABLE headers ASSIGNING FIELD-SYMBOL(<buffered>) WITH KEY decl_uuid = header-decl_uuid.
    IF sy-subrc <> 0.
      APPEND VALUE #( BASE CORRESPONDING #( header ) change = change ) TO headers.
      RETURN.
    ENDIF.

    " Created and deleted in the same transaction: nothing to write
    IF <buffered>-change = changes-created AND change = changes-deleted.
      DELETE headers WHERE decl_uuid = header-decl_uuid.
      RETURN.
    ENDIF.

    DATA(previous) = <buffered>-change.
    <buffered> = VALUE #( BASE CORRESPONDING #( header )
                          change = COND #( WHEN previous = changes-created THEN changes-created ELSE change ) ).
  ENDMETHOD.

  METHOD set_item.
    READ TABLE items ASSIGNING FIELD-SYMBOL(<buffered>) WITH KEY item_uuid = item-item_uuid.
    IF sy-subrc <> 0.
      APPEND VALUE #( BASE CORRESPONDING #( item ) change = change ) TO items.
      RETURN.
    ENDIF.

    IF <buffered>-change = changes-created AND change = changes-deleted.
      DELETE items WHERE item_uuid = item-item_uuid.
      RETURN.
    ENDIF.

    DATA(previous) = <buffered>-change.
    <buffered> = VALUE #( BASE CORRESPONDING #( item )
                          change = COND #( WHEN previous = changes-created THEN changes-created ELSE change ) ).
  ENDMETHOD.

  METHOD to_entity.
    result = CORRESPONDING #( header MAPPING DeclarationUUID    = decl_uuid
                                             PeriodYear         = period_year
                                             PeriodMonth        = period_month
                                             RatePerDegree      = rate_per_degree
                                             TaxableHL          = taxable_hl
                                             ExportHL           = export_hl
                                             TaxAmount          = tax_amount
                                             SubmittedBy        = submitted_by
                                             SubmittedAt        = submitted_at
                                             CreatedBy          = created_by
                                             CreatedAt          = created_at
                                             LastChangedBy      = last_changed_by
                                             LastChangedAt      = last_changed_at
                                             LocalLastChangedAt = local_last_changed_at ).
  ENDMETHOD.

  METHOD item_to_entity.
    result = CORRESPONDING #( item MAPPING ItemUUID           = item_uuid
                                           DeclarationUUID    = decl_uuid
                                           TaxClass           = tax_class
                                           QuantityHL         = quantity_hl
                                           TaxAmount          = tax_amount
                                           LocalLastChangedAt = local_last_changed_at ).
  ENDMETHOD.

  METHOD clear.
    CLEAR: headers, items.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_declaration DEFINITION DEFERRED FOR TESTING.

CLASS lhc_declaration DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_declaration.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_FI'.
    CONSTANTS c_lock_object TYPE if_abap_lock_object=>tv_name VALUE 'EZVHB_BTDECL'.

    CONSTANTS:
      BEGIN OF statuses,
        draft     TYPE zvhb_decl_status VALUE 'DRFT',
        submitted TYPE zvhb_decl_status VALUE 'SUBM',
      END OF statuses.

    TYPES ty_request TYPE zvhb_d_declarationrequest.
    TYPES tt_db_items TYPE lcl_buffer=>tt_db_items.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Declaration RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Declaration RESULT result.

    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE Declaration.

    METHODS read FOR READ
      IMPORTING keys FOR READ Declaration RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Declaration.

    METHODS rba_Item FOR READ
      IMPORTING keys_rba FOR READ Declaration\_Item FULL result_requested RESULT result LINK association_links.

    METHODS generate FOR MODIFY
      IMPORTING keys FOR ACTION Declaration~generate.

    METHODS recalculate FOR MODIFY
      IMPORTING keys FOR ACTION Declaration~recalculate RESULT result.

    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION Declaration~submit RESULT result.

    "! Message number of the first reason why a declaration cannot be generated, or initial
    METHODS check_request
      IMPORTING
        request       TYPE ty_request
        today         TYPE d
      RETURNING
        VALUE(result) TYPE symsgno.

    "! Last day of the month of the request
    METHODS last_day
      IMPORTING
        year          TYPE ty_request-periodyear
        month         TYPE ty_request-periodmonth
      RETURNING
        VALUE(result) TYPE d.

    "! Rate of the plant valid on the last day of the month
    METHODS find_rate
      IMPORTING
        plant         TYPE zvhb_plant
        on_date       TYPE d
      RETURNING
        VALUE(result) TYPE zvhb_btrate.

    "! Fills rate and totals of the header from the tax base and returns the new items
    METHODS calculate
      IMPORTING
        rate          TYPE zvhb_btrate
      CHANGING
        header        TYPE zvhb_btdecl
      RETURNING
        VALUE(result) TYPE tt_db_items.

    METHODS stamp
      CHANGING
        header TYPE zvhb_btdecl.
ENDCLASS.


CLASS lhc_declaration IMPLEMENTATION.

  METHOD get_instance_features.
    LOOP AT keys INTO DATA(key).
      DATA(is_draft) = xsdbool( lcl_buffer=>get_header( key-DeclarationUUID )-status = statuses-draft ).
      DATA(feature) = COND #( WHEN is_draft = abap_true THEN if_abap_behv=>fc-o-enabled
                                                         ELSE if_abap_behv=>fc-o-disabled ).
      APPEND VALUE #( %tky                = key-%tky
                      %delete             = feature
                      %action-recalculate = feature
                      %action-submit      = feature ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by role follows in stage v1.0
    IF requested_authorizations-%action-generate = if_abap_behv=>mk-on.
      result-%action-generate = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(key).
      DATA(header) = lcl_buffer=>get_header( key-DeclarationUUID ).
      IF header IS INITIAL.
        APPEND VALUE #( %tky = key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-declaration.
      ELSE.
        APPEND lcl_buffer=>to_entity( header ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Item.
    LOOP AT keys_rba INTO DATA(key).
      IF lcl_buffer=>get_header( key-DeclarationUUID ) IS INITIAL.
        APPEND VALUE #( %tky = key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-declaration.
        CONTINUE.
      ENDIF.

      LOOP AT lcl_buffer=>get_items( key-DeclarationUUID ) INTO DATA(item).
        APPEND VALUE #( source-%tky = key-%tky target-ItemUUID = item-item_uuid ) TO association_links.
        IF result_requested = abap_true.
          APPEND lcl_buffer=>item_to_entity( item ) TO result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
    TRY.
        DATA(lock) = cl_abap_lock_object_factory=>get_instance( iv_name = c_lock_object ).
      CATCH cx_abap_lock_failure INTO DATA(failure).
        RAISE SHORTDUMP failure.
    ENDTRY.

    LOOP AT keys INTO DATA(key).
      TRY.
          lock->enqueue( it_parameter = VALUE #( ( name = 'DECL_UUID' value = REF #( key-DeclarationUUID ) ) ) ).
        CATCH cx_abap_foreign_lock INTO DATA(foreign_lock).
          APPEND VALUE #( DeclarationUUID = key-DeclarationUUID ) TO failed-declaration.
          APPEND VALUE #( DeclarationUUID = key-DeclarationUUID
                          %msg            = new_message_with_text( text = foreign_lock->get_text( ) ) )
                 TO reported-declaration.
        CATCH cx_abap_lock_failure INTO failure.
          RAISE SHORTDUMP failure.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    LOOP AT keys INTO DATA(key).
      DATA(header) = lcl_buffer=>get_header( key-DeclarationUUID ).
      IF header-status <> statuses-draft.
        APPEND VALUE #( %tky = key-%tky ) TO failed-declaration.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message( id = c_msgid number = '014' v1 = header-declaration
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-declaration.
        CONTINUE.
      ENDIF.

      LOOP AT lcl_buffer=>get_items( header-decl_uuid ) INTO DATA(item).
        lcl_buffer=>set_item( item = item change = lcl_buffer=>changes-deleted ).
      ENDLOOP.
      lcl_buffer=>set_header( header = header change = lcl_buffer=>changes-deleted ).
    ENDLOOP.
  ENDMETHOD.

  METHOD generate.
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT keys INTO DATA(key).
      DATA(request) = CORRESPONDING ty_request( key-%param ).
      DATA(rate) = VALUE zvhb_btrate( ).
      DATA(problem) = check_request( request = request today = today ).
      IF problem IS INITIAL.
        rate = find_rate( plant = request-plant on_date = last_day( year = request-periodyear month = request-periodmonth ) ).
        problem = COND #( WHEN rate IS INITIAL THEN '011' ).
      ENDIF.

      IF problem IS NOT INITIAL.
        APPEND VALUE #( %cid = key-%cid ) TO failed-declaration.
        APPEND VALUE #( %cid = key-%cid
                        %msg = new_message( id       = c_msgid
                                            number   = problem
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = COND #( WHEN problem = '010' THEN request-periodmonth
                                                               WHEN problem = '013' THEN request-periodmonth
                                                               ELSE request-plant )
                                            v2       = COND #( WHEN problem = '011'
                                                               THEN |{ last_day( year = request-periodyear month = request-periodmonth ) DATE = USER }|
                                                               WHEN problem = '013' THEN request-periodyear
                                                               ELSE request-periodmonth )
                                            v3       = request-periodyear ) ) TO reported-declaration.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(header) = VALUE zvhb_btdecl( decl_uuid    = cl_system_uuid=>create_uuid_x16_static( )
                                            plant        = request-plant
                                            period_year  = request-periodyear
                                            period_month = request-periodmonth
                                            status       = statuses-draft
                                            created_by   = cl_abap_context_info=>get_user_technical_name( ) ).
        CATCH cx_uuid_error INTO DATA(uuid_error).
          RAISE SHORTDUMP uuid_error.
      ENDTRY.
      GET TIME STAMP FIELD header-created_at.
      stamp( CHANGING header = header ).

      LOOP AT calculate( EXPORTING rate = rate CHANGING header = header ) INTO DATA(item).
        lcl_buffer=>set_item( item = item change = lcl_buffer=>changes-created ).
      ENDLOOP.
      lcl_buffer=>set_header( header = header change = lcl_buffer=>changes-created ).

      APPEND VALUE #( %cid = key-%cid DeclarationUUID = header-decl_uuid ) TO mapped-declaration.
      APPEND VALUE #( %cid = key-%cid
                      %msg = new_message( id       = c_msgid
                                          number   = '017'
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = header-period_month
                                          v2       = header-period_year
                                          v3       = |{ header-tax_amount NUMBER = USER }| ) ) TO reported-declaration.
    ENDLOOP.
  ENDMETHOD.

  METHOD recalculate.
    LOOP AT keys INTO DATA(key).
      DATA(header) = lcl_buffer=>get_header( key-DeclarationUUID ).
      IF header-status <> statuses-draft.
        APPEND VALUE #( %tky = key-%tky ) TO failed-declaration.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message( id = c_msgid number = '014' v1 = header-declaration
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-declaration.
        CONTINUE.
      ENDIF.

      " The rate and the goods issues of the month may have changed since the declaration was generated
      DATA(rate) = find_rate( plant = header-plant on_date = last_day( year = header-period_year month = header-period_month ) ).
      LOOP AT lcl_buffer=>get_items( header-decl_uuid ) INTO DATA(old_item).
        lcl_buffer=>set_item( item = old_item change = lcl_buffer=>changes-deleted ).
      ENDLOOP.
      LOOP AT calculate( EXPORTING rate = rate CHANGING header = header ) INTO DATA(new_item).
        lcl_buffer=>set_item( item = new_item change = lcl_buffer=>changes-created ).
      ENDLOOP.
      stamp( CHANGING header = header ).
      lcl_buffer=>set_header( header = header change = lcl_buffer=>changes-updated ).

      APPEND VALUE #( %tky = key-%tky %param = lcl_buffer=>to_entity( header ) ) TO result.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message( id       = c_msgid
                                          number   = '016'
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = header-declaration
                                          v2       = |{ header-tax_amount NUMBER = USER }| ) ) TO reported-declaration.
    ENDLOOP.
  ENDMETHOD.

  METHOD submit.
    LOOP AT keys INTO DATA(key).
      DATA(header) = lcl_buffer=>get_header( key-DeclarationUUID ).
      IF header-status <> statuses-draft.
        APPEND VALUE #( %tky = key-%tky ) TO failed-declaration.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message( id = c_msgid number = '014' v1 = header-declaration
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-declaration.
        CONTINUE.
      ENDIF.

      " A submitted declaration is a document of the customs office: from now on it is only read
      header-status       = statuses-submitted.
      header-submitted_by = cl_abap_context_info=>get_user_technical_name( ).
      GET TIME STAMP FIELD header-submitted_at.
      stamp( CHANGING header = header ).
      lcl_buffer=>set_header( header = header change = lcl_buffer=>changes-updated ).

      APPEND VALUE #( %tky = key-%tky %param = lcl_buffer=>to_entity( header ) ) TO result.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message( id       = c_msgid
                                          number   = '015'
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = header-declaration ) ) TO reported-declaration.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_request.
    IF request-periodmonth < 1 OR request-periodmonth > 12.
      result = '010'.
      RETURN.
    ENDIF.

    IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-plant value = request-plant ).
      result = '001'.
      RETURN.
    ENDIF.

    IF |{ request-periodyear }{ request-periodmonth }01| > today.
      result = '013'.
      RETURN.
    ENDIF.

    SELECT SINGLE declaration FROM zvhb_btdecl
      WHERE plant        = @request-plant
        AND period_year  = @request-periodyear
        AND period_month = @request-periodmonth
      INTO @DATA(existing).
    IF sy-subrc = 0 OR line_exists( lcl_buffer=>headers[ plant        = request-plant
                                                         period_year  = request-periodyear
                                                         period_month = request-periodmonth ] ).
      result = '012'.
    ENDIF.
  ENDMETHOD.

  METHOD last_day.
    DATA first_day TYPE d.
    first_day = |{ year }{ month }01|.
    " Day 28 plus 4 days is always in the next month; its first day minus one is the last day of this month
    DATA(next_month) = CONV d( first_day + 31 ).
    next_month+6(2) = '01'.
    result = next_month - 1.
  ENDMETHOD.

  METHOD find_rate.
    SELECT * FROM zvhb_btrate
      WHERE plant      = @plant
        AND valid_from <= @on_date
      ORDER BY valid_from DESCENDING
      INTO @result
      UP TO 1 ROWS.
    ENDSELECT.
  ENDMETHOD.

  METHOD calculate.
    SELECT Material, TaxClass, Treatment, QuantityHL FROM zvhb_i_beertaxbase
      WHERE Plant       = @header-plant
        AND PeriodYear  = @header-period_year
        AND PeriodMonth = @header-period_month
      INTO TABLE @DATA(base).

    DATA(figures) = zcl_vhb_beer_tax=>declare(
      base    = VALUE #( FOR b IN base ( material    = b-Material
                                         tax_class   = b-TaxClass
                                         treatment   = b-Treatment
                                         quantity_hl = b-QuantityHL ) )
      rate    = rate-rate_per_degree
      percent = rate-rate_percent ).

    header-rate_per_degree = rate-rate_per_degree.
    header-currency        = rate-currency.
    header-taxable_hl      = figures-taxable_hl.
    header-export_hl       = figures-export_hl.
    header-tax_amount      = figures-tax_amount.

    LOOP AT figures-lines INTO DATA(line).
      TRY.
          APPEND VALUE #( item_uuid   = cl_system_uuid=>create_uuid_x16_static( )
                          decl_uuid   = header-decl_uuid
                          item        = sy-tabix * 10
                          material    = line-material
                          tax_class   = line-tax_class
                          treatment   = line-treatment
                          quantity_hl = line-quantity_hl
                          tax_amount  = line-tax_amount
                          currency    = rate-currency ) TO result.
        CATCH cx_uuid_error INTO DATA(uuid_error).
          RAISE SHORTDUMP uuid_error.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD stamp.
    header-last_changed_by = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD header-last_changed_at.
    header-local_last_changed_at = header-last_changed_at.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS read FOR READ
      IMPORTING keys FOR READ Item RESULT result.

    METHODS rba_Declaration FOR READ
      IMPORTING keys_rba FOR READ Item\_Declaration FULL result_requested RESULT result LINK association_links.
ENDCLASS.


CLASS lhc_item IMPLEMENTATION.

  METHOD read.
    LOOP AT keys INTO DATA(key).
      DATA(item) = lcl_buffer=>get_item( key-ItemUUID ).
      IF item IS INITIAL.
        APPEND VALUE #( %tky = key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-item.
      ELSE.
        APPEND lcl_buffer=>item_to_entity( item ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Declaration.
    LOOP AT keys_rba INTO DATA(key).
      DATA(item) = lcl_buffer=>get_item( key-ItemUUID ).
      DATA(header) = lcl_buffer=>get_header( item-decl_uuid ).
      IF header IS INITIAL.
        APPEND VALUE #( %tky = key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-item.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( source-%tky = key-%tky target-DeclarationUUID = header-decl_uuid ) TO association_links.
      IF result_requested = abap_true AND NOT line_exists( result[ KEY id DeclarationUUID = header-decl_uuid ] ).
        APPEND lcl_buffer=>to_entity( header ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


"! Save sequence of the unmanaged declaration: number on save, then the buffer is written to the tables
CLASS lsc_declaration DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save REDEFINITION.
    METHODS cleanup REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.


CLASS lsc_declaration IMPLEMENTATION.

  METHOD finalize.
    DATA number_range TYPE REF TO zif_vhb_number_range.

    LOOP AT lcl_buffer=>headers ASSIGNING FIELD-SYMBOL(<header>)
         WHERE change = lcl_buffer=>changes-created AND declaration IS INITIAL.
      IF number_range IS NOT BOUND.
        number_range = NEW zcl_vhb_number_range( ).
      ENDIF.
      TRY.
          <header>-declaration = number_range->get_next( zif_vhb_number_range=>objects-tax_declaration ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( DeclarationUUID = <header>-decl_uuid ) TO failed-declaration.
          APPEND VALUE #( DeclarationUUID = <header>-decl_uuid
                          %msg            = new_message( id       = 'ZVHB_FI'
                                                         number   = '018'
                                                         severity = if_abap_behv_message=>severity-error
                                                         v1       = exception->get_text( ) ) ) TO reported-declaration.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_before_save.
    " Every check runs in the actions; a declaration is consistent when it leaves the buffer
    RETURN.
  ENDMETHOD.

  METHOD save.
    DATA headers TYPE STANDARD TABLE OF zvhb_btdecl WITH EMPTY KEY.
    DATA items TYPE STANDARD TABLE OF zvhb_btdeclitm WITH EMPTY KEY.

    LOOP AT lcl_buffer=>headers INTO DATA(header).
      CASE header-change.
        WHEN lcl_buffer=>changes-created.
          APPEND CORRESPONDING #( header ) TO headers.
        WHEN lcl_buffer=>changes-updated.
          UPDATE zvhb_btdecl FROM @( CORRESPONDING zvhb_btdecl( header ) ).
        WHEN lcl_buffer=>changes-deleted.
          DELETE FROM zvhb_btdecl WHERE decl_uuid = @header-decl_uuid.
          DELETE FROM zvhb_btdeclitm WHERE decl_uuid = @header-decl_uuid.
      ENDCASE.
    ENDLOOP.
    INSERT zvhb_btdecl FROM TABLE @headers.

    LOOP AT lcl_buffer=>items INTO DATA(item).
      CASE item-change.
        WHEN lcl_buffer=>changes-created.
          APPEND CORRESPONDING #( item ) TO items.
        WHEN lcl_buffer=>changes-deleted.
          DELETE FROM zvhb_btdeclitm WHERE item_uuid = @item-item_uuid.
      ENDCASE.
    ENDLOOP.
    INSERT zvhb_btdeclitm FROM TABLE @items.
  ENDMETHOD.

  METHOD cleanup.
    lcl_buffer=>clear( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
    lcl_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.

