"! Query of the custom entity ZVHB_C_JobLog: the messages of application log object ZVHB_LOG of the last
"! 30 days, newest first, from the copy in ZVHB_LOGMSG (see ZCL_VHB_APP_LOG). Can be filtered by subobject.
CLASS zcl_vhb_job_log_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES tt_rows TYPE STANDARD TABLE OF zvhb_c_joblog WITH EMPTY KEY.

    "! Log messages of the subobject, or of all subobjects if it is empty
    METHODS read_log
      IMPORTING
        subobject     TYPE zif_vhb_app_log=>ty_subobject OPTIONAL
      RETURNING
        VALUE(result) TYPE tt_rows.

    "! Readable job name, severity text and criticality of one row
    METHODS describe
      CHANGING
        row TYPE zvhb_c_joblog.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_days_back TYPE i VALUE 30.
ENDCLASS.



CLASS zcl_vhb_job_log_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA subobject TYPE zif_vhb_app_log=>ty_subobject.

    TRY.
        DATA(ranges) = io_request->get_filter( )->get_as_ranges( ).
        subobject = VALUE #( ranges[ name = 'SUBOBJECT' ]-range[ 1 ]-low OPTIONAL ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR subobject.
    ENDTRY.

    DATA(rows) = read_log( subobject ).
    SORT rows BY LoggedAt DESCENDING ItemNumber ASCENDING.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( rows ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(offset) = io_request->get_paging( )->get_offset( ).
      DATA(page_size) = io_request->get_paging( )->get_page_size( ).
      DATA(last) = COND i( WHEN page_size = if_rap_query_paging=>page_size_unlimited THEN lines( rows )
                           ELSE nmin( val1 = offset + page_size val2 = lines( rows ) ) ).
      DATA(page) = VALUE tt_rows( FOR i = offset + 1 THEN i + 1 WHILE i <= last ( rows[ i ] ) ).
      io_response->set_data( page ).
    ENDIF.
  ENDMETHOD.

  METHOD read_log.
    DATA(since) = utclong_add( val = utclong_current( ) days = - c_days_back ).

    SELECT log_handle AS LogHandle, item_number AS ItemNumber, logged_at AS LoggedAt, subobject AS Subobject,
           external_id AS ExternalId, severity AS SeverityText, message_text AS MessageText
      FROM zvhb_logmsg
      WHERE logged_at >= @since
        AND ( @subobject = ' ' OR subobject = @subobject )
      INTO CORRESPONDING FIELDS OF TABLE @result.

    LOOP AT result REFERENCE INTO DATA(row).
      describe( CHANGING row = row->* ).
    ENDLOOP.
  ENDMETHOD.

  METHOD describe.
    row-JobName = SWITCH #( row-Subobject
                            WHEN zif_vhb_app_log=>subobject-reorder      THEN 'Automatic reorder'
                            WHEN zif_vhb_app_log=>subobject-batch_expiry THEN 'Expiring batches'
                            WHEN zif_vhb_app_log=>subobject-demo_data    THEN 'Demo data'
                            WHEN zif_vhb_app_log=>subobject-setup        THEN 'System setup'
                            ELSE row-Subobject ).

    " The severity arrives as its one-letter code and is turned into text and criticality here
    DATA(code) = row-SeverityText.
    row-Criticality = SWITCH #( code WHEN if_bali_constants=>c_severity_error   THEN 1
                                     WHEN if_bali_constants=>c_severity_warning THEN 2
                                     WHEN if_bali_constants=>c_severity_status  THEN 3
                                     ELSE 0 ).
    row-SeverityText = SWITCH #( code WHEN if_bali_constants=>c_severity_error   THEN 'Error'
                                      WHEN if_bali_constants=>c_severity_warning THEN 'Warning'
                                      WHEN if_bali_constants=>c_severity_status  THEN 'Success'
                                      ELSE 'Information' ).
  ENDMETHOD.

ENDCLASS.
