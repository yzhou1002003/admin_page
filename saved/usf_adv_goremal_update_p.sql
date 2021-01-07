CREATE OR REPLACE procedure ADPROD.USF_ADV_GOREMAL_update_p
/******************************************************************************
PURPOSE:
inactive the eamil that matches those from the file (match on both cwid and email).
-- set goremal_status_ind not active If goremal_perferred_ind is active.
-- Put "Inactive per Advancement Convio hard bounce" in goremal_comment.
-- Update activity date with sysdate and Put "Advancement" as the update user
--If the inactived one is preferred then update another email as preferred in the
  order PERS; BUS, USF
-- Do not change any information if the constituent is a current employee or current student.
-- report those are student and current employee
-- Do not make any changes to any @usfca.edu emails and put these emails in a report.
-- If the CWID in the file does not match any constituent in banner
   then put these people in a report.
REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        5/6.2009   Yong Zhou      1. Created this procedure.
               02/28, 2011                       added custom table azremil

******************************************************************************/
is
    v_PIDM spriden.spriden_pidm%type;
    v_ID   spriden.spriden_id%type;
    fHandler UTL_FILE.FILE_TYPE;
    v_dateStamp  varchar2(10 char);
    report_row                    VARCHAR2(800);


cursor c_adv_email_rec is
      select distinct t.AZREMIL_PIDM, t.AZREMIL_EMAIL_ADDRESS  from AZREMIL t, goremal e
      where  t.AZREMIL_PIDM = e.goremal_pidm
        and upper(t.AZREMIL_EMAIL_ADDRESS) = upper(e.GOREMAL_EMAIL_ADDRESS)
        and e.GOREMAL_STATUS_IND  in ('A')
        and upper(t.AZREMIL_EMAIL_ADDRESS) not like upper( '%@usfca.edu')
        and exists (select 'Y' from apbcons a
                         where   t.AZREMIL_PIDM =a.APBCONS_PIDM)
        and not exists(select 'Y' from pebempl p
                         where  t.AZREMIL_PIDM = p.pebempl_pidm
                           and p.pebempl_empl_status not in('T'))
        and not   exists(select 'Y' from sgbstdn d
                          where  t.AZREMIL_PIDM = d.sgbstdn_pidm
                            and d.SGBSTDN_TERM_CODE_EFF = (select max(w.SGBSTDN_TERM_CODE_EFF)
                                                          from sgbstdn w
                                                          where w.sgbstdn_pidm = d.sgbstdn_pidm
                            and d.SGBSTDN_STST_CODE in ( 'AS')))
          and not exists(select 'Y' from gorirol g
                             where t.AZREMIL_PIDM = G.GORIROL_PIDM
                              and g.gorirol_role in ('INTACCEPT', 'STUDENT','FACULTY','EMPLOYEE'))
          order by AZREMIL_PIDM;

   cursor c_goremal_rec(p_pidm spriden.spriden_pidm%type, p_email goremal.goremal_email_address%type) is
       select * from goremal e
         where e.goremal_pidm = p_pidm
         and upper(e.GOREMAL_EMAIL_ADDRESS) = upper(p_email)
         and e.GOREMAL_STATUS_IND  in ('A')
       --  and e.GOREMAL_PREFERRED_IND <> 'Y'
         for update;

   v_goremal_rec c_goremal_rec%ROWTYPE;

   cursor c_pers_email(p_pidm spriden.spriden_pidm%type, p_email goremal.goremal_email_address%type) is
        select * from goremal e
           where e.goremal_pidm = p_pidm
             and upper(e.GOREMAL_EMAIL_ADDRESS) <> upper(p_email)
             and e.GOREMAL_EMAL_CODE = 'PERS'
             and e.GOREMAL_STATUS_IND = 'A'
             and rownum = 1
             for update of GOREMAL_PREFERRED_IND;

   cursor c_bus_email(p_pidm spriden.spriden_pidm%type, p_email goremal.goremal_email_address%type) is
        select * from goremal e
           where e.goremal_pidm = p_pidm
             and upper(e.GOREMAL_EMAIL_ADDRESS) <> upper(p_email)
             and e.GOREMAL_EMAL_CODE = 'BUS'
             and e.GOREMAL_STATUS_IND = 'A'
             and rownum = 1
             for update of GOREMAL_PREFERRED_IND;

   cursor c_usf_email(p_pidm spriden.spriden_pidm%type, p_email goremal.goremal_email_address%type) is
        select * from goremal e
           where e.goremal_pidm = p_pidm
             and upper(e.GOREMAL_EMAIL_ADDRESS) <> upper(p_email)
             and e.GOREMAL_EMAL_CODE = 'USF'
             and e.GOREMAL_STATUS_IND = 'A'
             and rownum = 1
             for update of GOREMAL_PREFERRED_IND;

   v_pers_email c_pers_email%ROWTYPE;
   v_bus_email c_bus_email%ROWTYPE;
   v_usf_email c_usf_email%ROWTYPE;
BEGIN
       DBMS_OUTPUT.PUT_LINE('start process ' ||chr(13));
       SELECT To_char(trunc(SYSDATE), 'YYYYMMDD') into v_dateStamp from dual;
        fHandler := UTL_FILE.FOPEN('ADV_MAIL_DIR', 'Invalid Email Report'||v_dateStamp||'.txt', 'W');
        for v_adv_email_rec in c_adv_email_rec Loop
                open c_goremal_rec(v_adv_email_rec.AZREMIL_PIDM, v_adv_email_rec.AZREMIL_EMAIL_ADDRESS);
                Loop
                    Fetch c_goremal_rec into v_goremal_rec;

                    exit when c_goremal_rec%notfound;
                       --DBMS_OUTPUT.PUT_LINE('The next pidm is ' || v_adv_email_rec.spriden_pidm|| chr(13));
                        if v_goremal_rec.GOREMAL_PREFERRED_IND = 'Y' Then

                                  update GOREMAL set GOREMAL_STATUS_IND = 'I',
                                           GOREMAL_COMMENT = 'Inactivated per Imods bounceback',
                                           GOREMAL_PREFERRED_IND = 'N',
                                           GOREMAL_ACTIVITY_DATE = sysdate,
                                           GOREMAL_USER_ID = user
                                           where current of c_goremal_rec;
                                  if SQL%found Then
                                      report_row := 'Invalid Preferred Email for person ' || gb_common.f_get_id(v_adv_email_rec.AZREMIL_PIDM);
                                      UTL_FILE.PUT_LINE(fHandler, report_row || CHR(13));
                                  End if;
                                  open c_pers_email(v_adv_email_rec.AZREMIL_PIDM, v_adv_email_rec.AZREMIL_EMAIL_ADDRESS);
                                  Fetch c_pers_email into v_pers_email;

                                  open c_bus_email(v_adv_email_rec.AZREMIL_PIDM, v_adv_email_rec.AZREMIL_EMAIL_ADDRESS);
                                  Fetch c_bus_email into v_pers_email;

                                  open c_usf_email(v_adv_email_rec.AZREMIL_PIDM, v_adv_email_rec.AZREMIL_EMAIL_ADDRESS);
                                  Fetch c_usf_email into v_pers_email;

                                  If c_pers_email%found Then
                                       update GOREMAL set GOREMAL_PREFERRED_IND = 'Y',
                                              GOREMAL_COMMENT = 'update preferred ind per Imods bounceback',
                                              GOREMAL_ACTIVITY_DATE = sysdate,
                                              GOREMAL_USER_ID = user
                                           where current of c_pers_email;

                                  elsif c_bus_email%found Then
                                          update GOREMAL set GOREMAL_PREFERRED_IND = 'Y',
                                                 GOREMAL_COMMENT = 'update preferred ind per Imods bounceback',
                                                 GOREMAL_ACTIVITY_DATE = sysdate,
                                                 GOREMAL_USER_ID = user
                                            where current of c_bus_email;

                                  elsif c_usf_email%found Then
                                          update GOREMAL set GOREMAL_PREFERRED_IND = 'Y',
                                                 GOREMAL_COMMENT = 'update preferred ind per Imods bounceback',
                                                 GOREMAL_ACTIVITY_DATE = sysdate,
                                                 GOREMAL_USER_ID = user
                                            where current of c_usf_email;
                                  ENd if;
                                  close c_pers_email;
                                  close c_bus_email;
                                  close c_usf_email;

                                   report_row := 'Reset Preferred Email Id for person ' || gb_common.f_get_id(v_adv_email_rec.AZREMIL_PIDM);
                                   UTL_FILE.PUT_LINE(fHandler, report_row || CHR(13));
                        else
                                  update GOREMAL set GOREMAL_STATUS_IND = 'I',
                                           GOREMAL_COMMENT = 'Inactivated per Imods bounceback',
                                           GOREMAL_ACTIVITY_DATE = sysdate,
                                           GOREMAL_USER_ID = user
                                           where current of c_goremal_rec;
                                  if SQL%found Then
                                     report_row := 'Invalid Email for person ' || gb_common.f_get_id(v_adv_email_rec.AZREMIL_PIDM);
                                     UTL_FILE.PUT_LINE(fHandler, report_row || CHR(13));
                                  End if;

                        End if;

                End loop;
                close c_goremal_rec;
        End Loop;

         UTL_FILE.PUT_LINE(fHandler,  CHR(13));
         UTL_FILE.PUT_LINE(fHandler, 'End Advancement Inactive Email Report' || CHR(13));
         utl_file.fclose(fHandler);


    COMMIT;
EXCEPTION
   WHEN UTL_FILE.INVALID_PATH THEN
      DBMS_OUTPUT.PUT_LINE('invalid path utl error');

   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
      DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

END USF_ADV_GOREMAL_update_p ;
/