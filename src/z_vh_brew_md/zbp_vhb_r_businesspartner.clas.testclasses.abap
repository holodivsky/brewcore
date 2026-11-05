*"* use this source file for your ABAP unit test classes

"! Number range double: returns a fixed number or fails like an exhausted interval
CLASS ltd_number_range DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_vhb_number_range.
    DATA fails TYPE abap_boolean.
ENDCLASS.


CLASS ltd_number_range IMPLEMENTATION.

  METHOD zif_vhb_number_range~get_next.
    IF fails = abap_true.
      RAISE EXCEPTION NEW zcx_vhb_number_range( object = object interval = '01' ).
    ENDIF.
    result = '1000000001'.
  ENDMETHOD.

ENDCLASS.


"! Validations, determinations and feature control of the business partner BO,
"! run against a test double of its transactional buffer.
CLASS ltc_partner DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_failed   TYPE RESPONSE FOR FAILED LATE zvhb_r_businesspartner.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zvhb_r_businesspartner.
    TYPES ty_mapped   TYPE RESPONSE FOR MAPPED EARLY zvhb_r_businesspartner.
    TYPES ty_features TYPE TABLE FOR INSTANCE FEATURES RESULT zvhb_r_businesspartner\\partner.

    CLASS-DATA environment TYPE REF TO if_botd_txbufdbl_bo_test_env.

    DATA partner_handler TYPE REF TO lhc_partner.
    DATA role_handler    TYPE REF TO lhc_role.
    DATA number_range    TYPE REF TO ltd_number_range.
    DATA failed          TYPE ty_failed.
    DATA reported        TYPE ty_reported.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS valid_partner_passes FOR TESTING.
    METHODS missing_name_fails FOR TESTING.
    METHODS unknown_country_fails FOR TESTING.
    METHODS unknown_currency_fails FOR TESTING.
    METHODS negative_credit_limit_fails FOR TESTING.
    METHODS partner_without_role_fails FOR TESTING.
    METHODS unknown_payment_terms_fail FOR TESTING.
    METHODS known_payment_terms_pass FOR TESTING.
    METHODS unknown_role_fails FOR TESTING.
    METHODS known_role_passes FOR TESTING.
    METHODS new_partner_gets_defaults FOR TESTING.
    METHODS number_drawn_on_save FOR TESTING.
    METHODS number_range_error_reported FOR TESTING.
    METHODS saved_partner_can_be_blocked FOR TESTING.
    METHODS draft_cannot_be_blocked FOR TESTING.

    METHODS create_partner
      IMPORTING
        name          TYPE zvhb_r_businesspartner-PartnerName DEFAULT 'Hopfenhof Hallertau GmbH'
        country       TYPE land1 DEFAULT 'DE'
        currency      TYPE zvhb_currency DEFAULT 'EUR'
        payment_terms TYPE zvhb_pay_terms DEFAULT 'NT30'
        credit_limit  TYPE zvhb_amount DEFAULT 0
        role          TYPE zvhb_bp_role DEFAULT 'SU'
        draft         TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
      RETURNING
        VALUE(result) TYPE ty_mapped.

    METHODS validate_partner
      IMPORTING
        mapped TYPE ty_mapped.

    METHODS get_features
      IMPORTING
        mapped        TYPE ty_mapped
      RETURNING
        VALUE(result) TYPE ty_features.

    METHODS assert_error
      IMPORTING
        msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_partner IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_botd_txbufdbl_bo_test_env=>create(
      environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                             )->set_bdef_dependencies( bdef_dependencies = VALUE #( ( 'ZVHB_R_BUSINESSPARTNER' ) ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    CREATE OBJECT partner_handler FOR TESTING.
    CREATE OBJECT role_handler FOR TESTING.
    number_range = NEW #( ).
    partner_handler->number_range = number_range.
    CLEAR: failed, reported.
  ENDMETHOD.

  METHOD create_partner.
    MODIFY ENTITIES OF zvhb_r_businesspartner
      ENTITY Partner
        CREATE FIELDS ( PartnerName Country Currency PaymentTerms CreditLimit )
        WITH VALUE #( ( %cid         = 'PARTNER'
                        %is_draft    = draft
                        PartnerName  = name
                        Country      = country
                        Currency     = currency
                        PaymentTerms = payment_terms
                        CreditLimit  = credit_limit ) )
        CREATE BY \_Role
        FIELDS ( PartnerRole )
        WITH COND #( WHEN role IS NOT INITIAL
                     THEN VALUE #( ( %cid_ref  = 'PARTNER'
                                     %is_draft = draft
                                     %target   = VALUE #( ( %cid        = 'ROLE'
                                                            %is_draft   = draft
                                                            PartnerRole = role ) ) ) ) )
      MAPPED result.
  ENDMETHOD.

  METHOD validate_partner.
    DATA(keys) = mapped-partner.
    partner_handler->validatename( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    partner_handler->validatecountry( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    partner_handler->validatecurrency( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    partner_handler->validatecreditlimit( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
    partner_handler->validateroles( EXPORTING keys = CORRESPONDING #( keys ) CHANGING failed = failed reported = reported ).
  ENDMETHOD.

  METHOD get_features.
    DATA failed_early TYPE RESPONSE FOR FAILED EARLY zvhb_r_businesspartner.
    DATA reported_early TYPE RESPONSE FOR REPORTED EARLY zvhb_r_businesspartner.

    partner_handler->get_instance_features(
      EXPORTING
        keys               = CORRESPONDING #( mapped-partner )
        requested_features = VALUE #( %action-block   = if_abap_behv=>mk-on
                                      %action-unblock = if_abap_behv=>mk-on )
      CHANGING
        result             = result
        failed             = failed_early
        reported           = reported_early ).
  ENDMETHOD.

  METHOD assert_error.
    cl_abap_unit_assert=>assert_differs( act = lines( failed-partner ) + lines( failed-role )
                                         exp = 0
                                         msg = 'Validation should fail' ).

    DATA(messages) = VALUE string_table(
      FOR p IN reported-partner WHERE ( %msg IS BOUND ) ( CONV string( p-%msg->if_t100_message~t100key-msgno ) ) ).
    messages = VALUE #( BASE messages
      FOR r IN reported-role WHERE ( %msg IS BOUND ) ( CONV string( r-%msg->if_t100_message~t100key-msgno ) ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( messages[ table_line = CONV string( msgno ) ] ) )
                                      msg = |Message ZVHB_MD { msgno } expected| ).
  ENDMETHOD.

  METHOD valid_partner_passes.
    validate_partner( create_partner( ) ).

    cl_abap_unit_assert=>assert_initial( failed-partner ).
  ENDMETHOD.

  METHOD missing_name_fails.
    validate_partner( create_partner( name = '' ) ).

    assert_error( '012' ).
  ENDMETHOD.

  METHOD unknown_country_fails.
    validate_partner( create_partner( country = 'XX' ) ).

    assert_error( '013' ).
  ENDMETHOD.

  METHOD unknown_currency_fails.
    validate_partner( create_partner( currency = 'XYZ' ) ).

    assert_error( '014' ).
  ENDMETHOD.

  METHOD negative_credit_limit_fails.
    validate_partner( create_partner( credit_limit = '-1.00' ) ).

    assert_error( '016' ).
  ENDMETHOD.

  METHOD partner_without_role_fails.
    validate_partner( create_partner( role = '' ) ).

    assert_error( '018' ).
  ENDMETHOD.

  METHOD unknown_payment_terms_fail.
    DATA(mapped) = create_partner( payment_terms = 'XXXX' ).

    partner_handler->validatepaymentterms( EXPORTING keys = CORRESPONDING #( mapped-partner )
                                           CHANGING failed = failed reported = reported ).

    assert_error( '015' ).
  ENDMETHOD.

  METHOD known_payment_terms_pass.
    DATA(mapped) = create_partner( payment_terms = 'NT30' ).

    partner_handler->validatepaymentterms( EXPORTING keys = CORRESPONDING #( mapped-partner )
                                           CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-partner ).
  ENDMETHOD.

  METHOD unknown_role_fails.
    DATA(mapped) = create_partner( role = 'XX' ).

    role_handler->validaterole( EXPORTING keys = CORRESPONDING #( mapped-role ) CHANGING failed = failed reported = reported ).

    assert_error( '017' ).
  ENDMETHOD.

  METHOD known_role_passes.
    DATA(mapped) = create_partner( role = 'CU' ).

    role_handler->validaterole( EXPORTING keys = CORRESPONDING #( mapped-role ) CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-role ).
  ENDMETHOD.

  METHOD new_partner_gets_defaults.
    DATA(mapped) = create_partner( currency = '' payment_terms = '' ).

    partner_handler->setdefaults( keys = CORRESPONDING #( mapped-partner ) ).

    READ ENTITIES OF zvhb_r_businesspartner
      ENTITY Partner FIELDS ( Currency PaymentTerms ) WITH CORRESPONDING #( mapped-partner )
      RESULT DATA(partners).
    cl_abap_unit_assert=>assert_equals( act = partners[ 1 ]-Currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = partners[ 1 ]-PaymentTerms exp = 'NT30' ).
  ENDMETHOD.

  METHOD number_drawn_on_save.
    DATA(mapped) = create_partner( ).

    partner_handler->setpartnernumber( EXPORTING keys = CORRESPONDING #( mapped-partner ) CHANGING reported = reported ).

    READ ENTITIES OF zvhb_r_businesspartner
      ENTITY Partner FIELDS ( Partner ) WITH CORRESPONDING #( mapped-partner )
      RESULT DATA(partners).
    cl_abap_unit_assert=>assert_equals( act = partners[ 1 ]-Partner exp = '1000000001' ).
  ENDMETHOD.

  METHOD number_range_error_reported.
    DATA(mapped) = create_partner( ).
    number_range->fails = abap_true.

    partner_handler->setpartnernumber( EXPORTING keys = CORRESPONDING #( mapped-partner ) CHANGING reported = reported ).

    cl_abap_unit_assert=>assert_equals( act = reported-partner[ 1 ]-%msg->if_t100_message~t100key-msgno exp = '019' ).
  ENDMETHOD.

  METHOD saved_partner_can_be_blocked.
    DATA(features) = get_features( create_partner( ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-block exp = if_abap_behv=>fc-o-enabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-unblock exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

  METHOD draft_cannot_be_blocked.
    DATA(features) = get_features( create_partner( draft = if_abap_behv=>mk-on ) ).

    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-block exp = if_abap_behv=>fc-o-disabled ).
    cl_abap_unit_assert=>assert_equals( act = features[ 1 ]-%action-unblock exp = if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

ENDCLASS.

