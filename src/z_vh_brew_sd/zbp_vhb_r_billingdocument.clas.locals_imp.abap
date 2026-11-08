*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_billing_document DEFINITION DEFERRED FOR TESTING.

INTERFACE lif_billing.
  CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_SD'.
  CONSTANTS c_credit_memo TYPE zvhb_bill_type VALUE 'CRM'.
  CONSTANTS c_deposit TYPE zvhb_item_cat VALUE 'DEPO'.
  CONSTANTS c_deposit_condition TYPE zvhb_cond_type VALUE 'DEPO'.
  CONSTANTS c_customer_return TYPE zvhb_movement_type VALUE '653'.
  CONSTANTS c_plant TYPE zvhb_plant VALUE 'BR01'.
  CONSTANTS c_empties_storage TYPE zvhb_storage_loc VALUE 'LE01'.
ENDINTERFACE.


CLASS lhc_billing_document DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_billing_document.
  PRIVATE SECTION.
    TYPES ty_return TYPE zvhb_d_emptiesreturn.

    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR BillingDocument RESULT result.

    METHODS returnEmpties FOR MODIFY
      IMPORTING keys FOR ACTION BillingDocument~returnEmpties.

    METHODS setNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR BillingDocument~setNumber.

    "! The quantity is above zero and not more than the customer has at the moment
    METHODS check_return
      IMPORTING
        return        TYPE ty_return
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.

    METHODS message
      IMPORTING
        number        TYPE symsgno
        severity      TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        v1            TYPE simple OPTIONAL
        v2            TYPE simple OPTIONAL
        v3            TYPE simple OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_abap_behv_message.
ENDCLASS.


CLASS lhc_billing_document IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-returnEmpties = if_abap_behv=>mk-on.
      result-%action-returnEmpties = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD returnEmpties.
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT keys INTO DATA(key).
      DATA(return) = key-%param.

      DATA(problem) = check_return( return ).

      SELECT SINGLE amount, currency FROM zvhb_price
        WHERE condition_type = @lif_billing=>c_deposit_condition
          AND material       = @return-Material
          AND valid_from    <= @today
          AND valid_to      >= @today
        INTO @DATA(rate).

      SELECT SINGLE base_unit FROM zvhb_mat
        WHERE material = @return-Material
        INTO @DATA(unit).

      " FR-SD-05: the crates go back into the empties store with movement type 653
      IF problem IS NOT BOUND.
        MODIFY ENTITIES OF zvhb_r_materialdocument
          ENTITY MaterialDocument
            EXECUTE postGoodsMovement
            FROM VALUE #( ( %cid   = 'RETURN'
                            %param = VALUE #( MovementType    = lif_billing=>c_customer_return
                                              Material        = return-Material
                                              Plant           = lif_billing=>c_plant
                                              StorageLocation = lif_billing=>c_empties_storage
                                              Quantity        = return-Quantity
                                              HeaderText      = |Empties return { return-Customer }| ) ) )
          FAILED DATA(return_failed)
          REPORTED DATA(return_reported).
        IF return_failed IS NOT INITIAL.
          problem = VALUE #( return_reported-materialdocument[ 1 ]-%msg OPTIONAL ).
          CLEAR return_failed.
        ENDIF.
      ENDIF.

      IF problem IS BOUND.
        APPEND VALUE #( %cid = key-%cid ) TO failed-billingdocument.
        APPEND VALUE #( %cid = key-%cid %msg = problem ) TO reported-billingdocument.
        CONTINUE.
      ENDIF.

      DATA(credit) = CONV zvhb_amount( return-Quantity * rate-amount ).

      " The credit memo carries the deposit as a positive amount; its type makes it a credit
      MODIFY ENTITIES OF zvhb_r_billingdocument IN LOCAL MODE
        ENTITY BillingDocument
          CREATE FIELDS ( BillingType Customer BillingDate Currency NetAmount DepositAmount TotalAmount )
          WITH VALUE #( ( %cid          = key-%cid
                          BillingType   = lif_billing=>c_credit_memo
                          Customer      = return-Customer
                          BillingDate   = today
                          Currency      = rate-currency
                          DepositAmount = credit
                          TotalAmount   = credit ) )
          CREATE BY \_Item
          FIELDS ( Item ItemCategory Material Unit Quantity Currency NetAmount )
          WITH VALUE #( ( %cid_ref = key-%cid
                          %target  = VALUE #( ( %cid         = |{ key-%cid }_10|
                                                Item         = '00010'
                                                ItemCategory = lif_billing=>c_deposit
                                                Material     = return-Material
                                                Unit         = unit
                                                Quantity     = return-Quantity
                                                Currency     = rate-currency
                                                NetAmount    = credit ) ) ) )
        MAPPED DATA(created).

      INSERT LINES OF created-billingdocument INTO TABLE mapped-billingdocument.
      APPEND VALUE #( %cid = key-%cid
                      %msg = message( number   = '021'
                                      severity = if_abap_behv_message=>severity-success
                                      v1       = |{ return-Quantity NUMBER = USER } { unit } { return-Material }|
                                      v2       = return-Customer ) ) TO reported-billingdocument.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_return.
    IF return-Quantity <= 0.
      result = message( '019' ).
      RETURN.
    ENDIF.

    SELECT SINGLE BalanceQuantity FROM zvhb_i_emptiesbalance
      WHERE Customer = @return-Customer
        AND Material = @return-Material
      INTO @DATA(balance).

    IF return-Quantity > balance.
      result = message( number = '020'
                        v1     = return-Customer
                        v2     = |{ balance NUMBER = USER }|
                        v3     = return-Material ).
    ENDIF.
  ENDMETHOD.

  METHOD setNumber.
    READ ENTITIES OF zvhb_r_billingdocument IN LOCAL MODE
      ENTITY BillingDocument
        FIELDS ( BillingDocument ) WITH CORRESPONDING #( keys )
      RESULT DATA(documents).

    DELETE documents WHERE BillingDocument IS NOT INITIAL.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.

    LOOP AT documents ASSIGNING FIELD-SYMBOL(<document>).
      TRY.
          <document>-BillingDocument = number_range->get_next( zif_vhb_number_range=>objects-billing_document ).
        CATCH zcx_vhb_number_range INTO DATA(exception).
          APPEND VALUE #( %tky = <document>-%tky %msg = message( number = '001' v1 = exception->get_text( ) ) )
                 TO reported-billingdocument.
      ENDTRY.
    ENDLOOP.

    MODIFY ENTITIES OF zvhb_r_billingdocument IN LOCAL MODE
      ENTITY BillingDocument
        UPDATE FIELDS ( BillingDocument )
        WITH VALUE #( FOR d IN documents WHERE ( BillingDocument IS NOT INITIAL )
                      ( %tky = d-%tky BillingDocument = d-BillingDocument ) ).
  ENDMETHOD.

  METHOD message.
    result = new_message( id       = lif_billing=>c_msgid
                          number   = number
                          severity = severity
                          v1       = v1
                          v2       = v2
                          v3       = v3 ).
  ENDMETHOD.

ENDCLASS.

