*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS ltc_partner DEFINITION DEFERRED FOR TESTING.

CLASS lhc_partner DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_partner.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    CONSTANTS:
      "! Values proposed for a new partner
      BEGIN OF defaults,
        currency      TYPE zvhb_currency VALUE 'EUR',
        payment_terms TYPE zvhb_pay_terms VALUE 'NT30',
      END OF defaults.

    TYPES tt_partner_keys TYPE TABLE FOR READ IMPORT zvhb_r_businesspartner\\partner.
    TYPES tt_partners     TYPE TABLE FOR READ RESULT zvhb_r_businesspartner\\partner.

    "! Replaced by a test double in unit tests
    DATA number_range TYPE REF TO zif_vhb_number_range.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Partner RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Partner RESULT result.

    METHODS block FOR MODIFY
      IMPORTING keys FOR ACTION Partner~block RESULT result.

    METHODS unblock FOR MODIFY
      IMPORTING keys FOR ACTION Partner~unblock RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Partner~setDefaults.

    METHODS setPartnerNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Partner~setPartnerNumber.

    METHODS validateName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateName.

    METHODS validateCountry FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateCountry.

    METHODS validateCurrency FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateCurrency.

    METHODS validatePaymentTerms FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validatePaymentTerms.

    METHODS validateCreditLimit FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateCreditLimit.

    METHODS validateRoles FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateRoles.

    "! Sets the blocked flag and returns the changed partners
    METHODS set_blocked
      IMPORTING
        partner_keys  TYPE tt_partner_keys
        is_blocked    TYPE abap_boolean
      RETURNING
        VALUE(result) TYPE tt_partners.

    METHODS get_number_range
      RETURNING
        VALUE(result) TYPE REF TO zif_vhb_number_range.
ENDCLASS.


CLASS lhc_partner IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( IsBlocked ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners)
      FAILED failed.

    " Blocking works on saved partners only, never on a draft
    result = VALUE #(
      FOR partner IN partners
      LET saved = xsdbool( partner-%is_draft = if_abap_behv=>mk-off ) IN
      ( %tky            = partner-%tky
        %action-block   = COND #( WHEN saved = abap_true AND partner-IsBlocked = abap_false
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled )
        %action-unblock = COND #( WHEN saved = abap_true AND partner-IsBlocked = abap_true
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Authorization by role follows in stage v1.0
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD block.
    DATA(partners) = set_blocked( partner_keys = CORRESPONDING #( keys )
                                  is_blocked   = abap_true ).
    result = VALUE #( FOR partner IN partners ( %tky = partner-%tky %param = partner ) ).
  ENDMETHOD.

  METHOD unblock.
    DATA(partners) = set_blocked( partner_keys = CORRESPONDING #( keys )
                                  is_blocked   = abap_false ).
    result = VALUE #( FOR partner IN partners ( %tky = partner-%tky %param = partner ) ).
  ENDMETHOD.

  METHOD set_blocked.
    MODIFY ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        UPDATE FIELDS ( IsBlocked )
        WITH VALUE #( FOR key IN partner_keys ( %tky = key-%tky IsBlocked = is_blocked ) ).

    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        ALL FIELDS WITH CORRESPONDING #( partner_keys )
      RESULT result.
  ENDMETHOD.

  METHOD get_number_range.
    IF number_range IS NOT BOUND.
      number_range = NEW zcl_vhb_number_range( ).
    ENDIF.
    result = number_range.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( Currency PaymentTerms ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    DELETE partners WHERE Currency IS NOT INITIAL AND PaymentTerms IS NOT INITIAL.
    IF partners IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        UPDATE FIELDS ( Currency PaymentTerms )
        WITH VALUE #( FOR partner IN partners
                      ( %tky         = partner-%tky
                        Currency     = COND #( WHEN partner-Currency IS INITIAL
                                               THEN defaults-currency
                                               ELSE partner-Currency )
                        PaymentTerms = COND #( WHEN partner-PaymentTerms IS INITIAL
                                               THEN defaults-payment_terms
                                               ELSE partner-PaymentTerms ) ) ).
  ENDMETHOD.

  METHOD setPartnerNumber.
    DATA numbered TYPE TABLE FOR UPDATE zvhb_r_businesspartner\\partner.

    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( Partner ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    DELETE partners WHERE Partner IS NOT INITIAL.

    LOOP AT partners INTO DATA(partner).
      TRY.
          APPEND VALUE #( %tky    = partner-%tky
                          Partner = get_number_range( )->get_next( zif_vhb_number_range=>objects-business_partner ) )
                 TO numbered.
        CATCH zcx_vhb_number_range INTO DATA(error).
          APPEND VALUE #( %tky = partner-%tky
                          %msg = new_message( id       = c_msgid
                                              number   = '019'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = error->get_text( ) ) ) TO reported-partner.
      ENDTRY.
    ENDLOOP.

    IF numbered IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        UPDATE FIELDS ( Partner ) WITH numbered.
  ENDMETHOD.

  METHOD validateName.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( PartnerName ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).
      APPEND VALUE #( %tky = partner-%tky %state_area = 'NAME' ) TO reported-partner.

      IF partner-PartnerName IS INITIAL.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky                 = partner-%tky
                        %state_area          = 'NAME'
                        %msg                 = new_message( id       = c_msgid
                                                            number   = '012'
                                                            severity = if_abap_behv_message=>severity-error )
                        %element-PartnerName = if_abap_behv=>mk-on ) TO reported-partner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCountry.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( Country ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    IF partners IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Country FROM I_Country WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @partners
      WHERE Country = @partners-Country
      INTO TABLE @DATA(known_countries).

    LOOP AT partners INTO DATA(partner).
      APPEND VALUE #( %tky = partner-%tky %state_area = 'COUNTRY' ) TO reported-partner.

      IF partner-Country IS INITIAL OR NOT line_exists( known_countries[ Country = partner-Country ] ).
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky             = partner-%tky
                        %state_area      = 'COUNTRY'
                        %msg             = new_message( id       = c_msgid
                                                        number   = '013'
                                                        severity = if_abap_behv_message=>severity-error
                                                        v1       = partner-Country )
                        %element-Country = if_abap_behv=>mk-on ) TO reported-partner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCurrency.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( Currency ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    IF partners IS INITIAL.
      RETURN.
    ENDIF.

    SELECT Currency FROM I_Currency WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @partners
      WHERE Currency = @partners-Currency
      INTO TABLE @DATA(known_currencies).

    LOOP AT partners INTO DATA(partner).
      APPEND VALUE #( %tky = partner-%tky %state_area = 'CURRENCY' ) TO reported-partner.

      IF partner-Currency IS NOT INITIAL AND line_exists( known_currencies[ Currency = partner-Currency ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
      APPEND VALUE #( %tky              = partner-%tky
                      %state_area       = 'CURRENCY'
                      %msg              = COND #( WHEN partner-Currency IS INITIAL
                                                  THEN new_message( id       = c_msgid
                                                                    number   = '031'
                                                                    severity = if_abap_behv_message=>severity-error )
                                                  ELSE new_message( id       = c_msgid
                                                                    number   = '014'
                                                                    severity = if_abap_behv_message=>severity-error
                                                                    v1       = partner-Currency ) )
                      %element-Currency = if_abap_behv=>mk-on ) TO reported-partner.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatePaymentTerms.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( PaymentTerms ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).
      APPEND VALUE #( %tky = partner-%tky %state_area = 'PAYMENT_TERMS' ) TO reported-partner.

      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-payment_terms
                                             value  = partner-PaymentTerms ).
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky                  = partner-%tky
                        %state_area           = 'PAYMENT_TERMS'
                        %msg                  = new_message( id       = c_msgid
                                                             number   = '015'
                                                             severity = if_abap_behv_message=>severity-error
                                                             v1       = partner-PaymentTerms )
                        %element-PaymentTerms = if_abap_behv=>mk-on ) TO reported-partner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCreditLimit.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( CreditLimit ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).
      APPEND VALUE #( %tky = partner-%tky %state_area = 'CREDIT_LIMIT' ) TO reported-partner.

      IF partner-CreditLimit < 0.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky                 = partner-%tky
                        %state_area          = 'CREDIT_LIMIT'
                        %msg                 = new_message( id       = c_msgid
                                                            number   = '016'
                                                            severity = if_abap_behv_message=>severity-error )
                        %element-CreditLimit = if_abap_behv=>mk-on ) TO reported-partner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateRoles.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( PartnerName ) WITH CORRESPONDING #( keys )
      RESULT DATA(partners)
      ENTITY Partner BY \_Role
        FIELDS ( PartnerRole ) WITH CORRESPONDING #( keys )
      LINK DATA(role_links).

    LOOP AT partners INTO DATA(partner).
      APPEND VALUE #( %tky = partner-%tky %state_area = 'ROLES' ) TO reported-partner.

      IF NOT line_exists( role_links[ KEY id COMPONENTS source-%tky = partner-%tky ] ).
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky        = partner-%tky
                        %state_area = 'ROLES'
                        %msg        = new_message( id       = c_msgid
                                                   number   = '018'
                                                   severity = if_abap_behv_message=>severity-error
                                                   v1       = partner-PartnerName ) ) TO reported-partner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_role DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_partner.
  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZVHB_MD'.

    METHODS validateRole FOR VALIDATE ON SAVE
      IMPORTING keys FOR Role~validateRole.
ENDCLASS.


CLASS lhc_role IMPLEMENTATION.

  METHOD validateRole.
    READ ENTITIES OF zvhb_r_businesspartner IN LOCAL MODE
      ENTITY Role
        FIELDS ( PartnerRole ) WITH CORRESPONDING #( keys )
      RESULT DATA(roles).

    LOOP AT roles INTO DATA(role).
      APPEND VALUE #( %tky                       = role-%tky
                      %state_area                = 'ROLE'
                      %path-partner-%is_draft    = role-%is_draft
                      %path-partner-PartnerUUID  = role-PartnerUUID ) TO reported-role.

      IF NOT zcl_vhb_fixed_values=>is_valid( domain = zcl_vhb_fixed_values=>domains-partner_role
                                             value  = role-PartnerRole ).
        APPEND VALUE #( %tky = role-%tky ) TO failed-role.
        APPEND VALUE #( %tky                      = role-%tky
                        %state_area               = 'ROLE'
                        %msg                      = new_message( id       = c_msgid
                                                                 number   = '017'
                                                                 severity = if_abap_behv_message=>severity-error
                                                                 v1       = role-PartnerRole )
                        %path-partner-%is_draft   = role-%is_draft
                        %path-partner-PartnerUUID = role-PartnerUUID
                        %element-PartnerRole      = if_abap_behv=>mk-on ) TO reported-role.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

