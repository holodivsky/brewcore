"! Schedules the BrewCore application jobs from their job templates with the released API CL_APJ_RT_API,
"! which is the API behind the Fiori app Application Jobs. Run with F9: both jobs start at once in the
"! background, and the console shows their job number and status.
CLASS zcl_vhb_schedule_jobs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_job,
        template TYPE cl_apj_rt_api=>ty_template_name,
        text     TYPE cl_apj_rt_api=>ty_job_text,
        name     TYPE cl_apj_rt_api=>ty_jobname,
        count    TYPE cl_apj_rt_api=>ty_jobcount,
      END OF ty_job,
      tt_jobs TYPE STANDARD TABLE OF ty_job WITH EMPTY KEY.

    DATA out TYPE REF TO if_oo_adt_classrun_out.

    "! Starts a job from its template at once; the parameters are taken from the template
    METHODS schedule
      CHANGING
        job TYPE ty_job.

    "! Waits until the jobs are finished or a minute has passed and writes their status
    METHODS write_status
      IMPORTING
        jobs TYPE tt_jobs.
ENDCLASS.



CLASS zcl_vhb_schedule_jobs IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    me->out = out.

    DATA(jobs) = VALUE tt_jobs( ( template = 'ZVHB_REORDER_BR01'      text = 'BrewCore: Automatic reorder BR01' )
                                ( template = 'ZVHB_BATCH_EXPIRY_BR01' text = 'BrewCore: Expiring batches BR01' ) ).

    LOOP AT jobs ASSIGNING FIELD-SYMBOL(<job>).
      schedule( CHANGING job = <job> ).
    ENDLOOP.

    write_status( jobs ).
  ENDMETHOD.

  METHOD schedule.
    TRY.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name = job-template
            iv_job_text          = job-text
            is_start_info        = VALUE #( start_immediately = abap_true )
          IMPORTING
            ev_jobname           = job-name
            ev_jobcount          = job-count ).
        out->write( |{ job-text }: scheduled as job { job-name } { job-count }| ).
      CATCH cx_apj_rt INTO DATA(error).
        out->write( |{ job-text }: not scheduled, { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD write_status.
    DATA status TYPE cl_apj_rt_api=>ty_job_status.
    DATA status_text TYPE cl_apj_rt_api=>ty_job_status_text.

    LOOP AT jobs INTO DATA(job) WHERE name IS NOT INITIAL.
      " A background job usually finishes within seconds; finished (F) and aborted (A) are final
      DO 30 TIMES.
        TRY.
            cl_apj_rt_api=>get_job_status( EXPORTING iv_jobname         = job-name
                                                     iv_jobcount        = job-count
                                           IMPORTING ev_job_status      = status
                                                     ev_job_status_text = status_text ).
          CATCH cx_apj_rt INTO DATA(error).
            status_text = error->get_text( ).
            EXIT.
        ENDTRY.
        IF status = 'F' OR status = 'A'.
          EXIT.
        ENDIF.
        WAIT UP TO 2 SECONDS.
      ENDDO.
      out->write( |{ job-text }: { status_text }| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
