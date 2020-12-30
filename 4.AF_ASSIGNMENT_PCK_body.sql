create or replace PACKAGE BODY AF_ASSIGNMENT_PCK AS

    PROCEDURE oro(P_ADDBY varchar2, P_ADDDTTM date, P_MODBY varchar2, P_MODDTTM date, P_ORO_NAME varchar2, P_EFFECTIVE_DATE date) IS
        i NUMBER :=0;
        j NUMBER :=0;
        v_max_adddttm date;
        v_sysdate date;
        v_app_user varchar2(10) := v('CURRENT_USERNAME');
        v_pass_effective_time_old date;
        v_pass_effective_time_new date;
        v_cnt NUMBER;


        CURSOR c_cur is 
            SELECT *
            FROM contract_IMSV7_ONCALL_LOCAL
            ORDER BY EFFECTIVE_DATE ASC
            FOR UPDATE;

        PROCEDURE update_duration(p_effective_date date) IS
            v_pass_effective_date_old date;
            v_effective_duration varchar2(20); 
            v_max_timestamp timestamp := null;
            v_adddttm date :=null;
        BEGIN
            --As the effective date precision is on Minute. There may have more than 1 record for the same effective date . Get the latest one according to the transaction timestamp. 
            select max(MODIFIED_ON) into v_max_timestamp from AF_ONCALL_SCHEDULE_AUDIT where unit_code=6 and trunc(new_effective_datetime)=P_EFFECTIVE_DATE;
            select old_effective_datetime, to_char(round(p_effective_date-trunc(old_effective_datetime),0))
            into v_pass_effective_date_old, v_effective_duration
            from AF_ONCALL_SCHEDULE_AUDIT 
            where unit_code=6 and trunc(old_effective_datetime)=P_EFFECTIVE_DATE and modified_on=v_max_timestamp;
            update imsv7.oncall@contract set effective_duration=v_effective_duration, effective_end_date=p_effective_date where effective_date=v_pass_effective_date_old;
            select adddttm into v_adddttm from imsv7.oncall@contract where effective_date=v_pass_effective_date_old;
            --select to_date(pass_effective_time_new, 'DD-MON-YYYY HH24:MI') into v_pass_effective_date_new from AF_ONCALL_HIST where pass_effective_time_old=to_char(v_pass_effective_date_old, 'DD-MON-YYYY HH24:MI');
            if v_adddttm is null then  -- not IM
                update imsv7.oncall@contract set effective_duration=0, effective_end_date=p_effective_date where effective_date>v_pass_effective_date_old and effective_date<p_effective_date and effective_duration is null;
            else
                update imsv7.oncall@contract set effective_duration=to_char(round(v_pass_effective_date_old-effective_date,0)), effective_end_date=v_pass_effective_date_old where effective_date<v_pass_effective_date_old and adddttm>v_adddttm and effective_duration is null;
            end if;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
        END;

    BEGIN
        --This block is to process the records in table contract_IMSV7_ONCALL_LOCAL
        BEGIN
            FOR c IN c_cur LOOP
                BEGIN
                    SAVEPOINT start_transaction; --1 by 1 to process the records
                    update_duration(c.effective_date);
                    insert into imsv7.oncall@contract(ADDBY,ADDDTTM,MODBY,MODDTTM,ORO_NAME,EFFECTIVE_DATE) values (c.ADDBY, c.ADDDTTM, c.MODBY, c.MODDTTM, c.ORO_NAME, c.EFFECTIVE_DATE);
                    --update_duration(c.effective_date);
                    delete from contract_IMSV7_ONCALL_LOCAL where current of c_cur;
                    EXCEPTION
                        WHEN DUP_VAL_ON_INDEX THEN  --
                            BEGIN
                                select adddttm into v_max_adddttm from imsv7.oncall@contract where effective_date=c.EFFECTIVE_DATE; 
                                IF v_max_adddttm<c.adddttm THEN
                                    UPDATE imsv7.oncall@contract SET MODBY=c.MODBY, MODDTTM=c.MODDTTM, ORO_NAME=c.ORO_NAME WHERE EFFECTIVE_DATE=c.EFFECTIVE_DATE;
                                    update_duration(c.effective_date);
                                END IF;                                
                                delete from contract_IMSV7_ONCALL_LOCAL where current of c_cur;
                                EXCEPTION
                                    WHEN others THEN
                                        ROLLBACK TO start_transaction;
                            END;
                        WHEN others THEN
                            ROLLBACK TO start_transaction;
                END;
            END LOOP; 
        END;

        --This block is to process the current assignment
        BEGIN

            update_duration(p_effective_date); 
            --This block is to see whether there is a hanging future assignment on the imsv7.oncall@contract
            select old_effective_datetime, new_effective_datetime
            into v_pass_effective_time_old, v_pass_effective_time_new
            from 
            ( select * 
              from AF_ONCALL_SCHEDULE_AUDIT 
              where unit_code=6 and trunc(old_effective_datetime)=P_EFFECTIVE_DATE
              order by modified_on asc
            )
            where rownum=1;

            select count(1) into v_cnt from imsv7.oncall@contract where effective_date between v_pass_effective_time_old and v_pass_effective_time_new and effective_duration is null and effective_end_date is null;
            if v_cnt>0 then
                update imsv7.oncall@contract set modby=P_MODBY, moddttm=P_MODDTTM, oro_name=P_ORO_NAME, effective_date=P_EFFECTIVE_DATE where effective_date between v_pass_effective_time_old and v_pass_effective_time_new and effective_duration is null and effective_end_date is null;
            else
                insert into imsv7.oncall@contract(ADDBY,ADDDTTM,MODBY,MODDTTM,ORO_NAME,EFFECTIVE_DATE) values (P_ADDBY, P_ADDDTTM, P_MODBY, P_MODDTTM, P_ORO_NAME, P_EFFECTIVE_DATE);
            end if;
            --update_duration(p_effective_date);            
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN --The effective date precision is on Minute 
                    BEGIN
                        UPDATE imsv7.oncall@contract SET MODBY=P_MODBY, MODDTTM=P_MODDTTM, ORO_NAME=P_ORO_NAME WHERE EFFECTIVE_DATE=P_EFFECTIVE_DATE;
                        update_duration(p_effective_date);            
                        EXCEPTION
                            WHEN others THEN 
                                insert into contract_IMSV7_ONCALL_LOCAL(ADDBY,ADDDTTM,MODBY,MODDTTM,ORO_NAME,EFFECTIVE_DATE) values (P_ADDBY, P_ADDDTTM, P_MODBY, P_MODDTTM, P_ORO_NAME, P_EFFECTIVE_DATE);
                    END;    
                WHEN others THEN 
                    insert into contract_IMSV7_ONCALL_LOCAL(ADDBY,ADDDTTM,MODBY,MODDTTM,ORO_NAME,EFFECTIVE_DATE) values (P_ADDBY, P_ADDDTTM, P_MODBY, P_MODDTTM, P_ORO_NAME, P_EFFECTIVE_DATE);
        END;

        EXCEPTION
            WHEN others THEN
                raise_application_error(-20001,'DATA ERROR!!!');

    END ORO;



------------------------------------------
-- update_assignment_tbl
------------------------------------------
  procedure update_assignment_tbl (
        p_unit_code          varchar2,
        p_pass_onto          varchar2,
        p_mode               varchar2,
        p_specific_datetime  varchar2 default null
    ) AS

    v_af_oncall_sche_id      number;
    v_new_effective_datetime varchar2(45);

    v_af_schjob_tctr_var     varchar2(45);

--    v_passon_datetime           varchar2(40);
    v_pass_onto_to_be_replaced  varchar2(100);
    v_region_to_be_reassigned   varchar2(400);
    v_old_pass_onto_name        varchar2(100);

    v_old_pass_onto_email       varchar2(100);

    v_new_pass_onto_name        varchar2(100);
    v_new_pass_onto_email       varchar2(100);

    v_job_num                   number;

    v_default_sender           varchar2(100);
    v_default_sender_name      varchar2(100);
    v_receivers                varchar2(400)  := null;
    v_emailsubject             varchar2(1000) := null;
    v_emailbody                varchar2(4000) := null;
    
    -- added on Dec 21, 2020
    v_af_sche_job_pack_var     varchar2(4000) := null;


  BEGIN
  
    -- Added on Dec 21, 2020
     -- get predefined variable from app control table
            v_af_sche_job_pack_var := AF_APP_CONFIG_PCK.getControlParamValue(
                                            p_param_name => 'af_schedule_job_package_selection'
                                       );

    select 
        ret_oncall_pass_onto_info( p_unit_code, 'pass_onto' ),        
        name,      
        ret_oncall_pass_onto_info( p_unit_code, 'fullname' ),       
        ret_oncall_pass_onto_info( p_unit_code, 'email' )

    into 
        v_pass_onto_to_be_replaced, 
        v_region_to_be_reassigned,
        v_old_pass_onto_name,
        v_old_pass_onto_email
    from af_unit
    where code = p_unit_code;

   -- because this is a new assignment, if it is not IM, we need to 
   -- clean up all jobs for this unit, and then, if this is a future assignment, and scheduled job is 
   -- allowed by configuration table, will submit a new job

    if p_mode <> 'IM' then

       for rec in (

            select id, sche_job_num
            from af_oncall_schedule
            where unit_code = p_unit_code 
            and instr( sche_job_status, 'scheduled' ) > 0
            and instr( sche_job_status, 'complete' ) = 0
        ) loop


            begin

                if v_af_sche_job_pack_var = '1' then
                
                    dbms_job.remove(
                            job  => rec.sche_job_num                   
                        ); 
               
                else
                
                    -- added on Dec 21, 2020
                    begin   
                        DBMS_SCHEDULER.DROP_JOB (
                           job_name => 'af_job_unit_code_' || p_unit_code,
                           force    => true
                        );
                    
                    exception
                        when others then
                           null;
                    
                    end;
                
                end if;

                update af_oncall_schedule
                    set sche_job_status = case when sche_job_status is null 
                                                    then 'job ' || rec.sche_job_num || ' removed'
                                                    else case when instr( sche_job_status, 'removed' ) = 0 then sche_job_status || ';job ' || rec.sche_job_num  || ' removed'
                                                              else sche_job_status
                                                         end

                                              end

                where id = rec.id;

            exception
                when others then

                    begin

                        update af_oncall_schedule
                            set sche_job_status = case when sche_job_status is null 
                                                        then 'job ' || rec.sche_job_num || ' failed removed'
                                                        else case when instr( sche_job_status, 'failed removed' ) = 0 then sche_job_status || ';job ' || rec.sche_job_num  || ' failed removed'
                                                                  else sche_job_status
                                                            end

                                                  end

                        where id = rec.id;

                    exception
                        when others then
                            null;

                    end;


            end;

        end loop;


    end if;


    if p_mode = 'IM' then

        v_af_oncall_sche_id :=
            find_unit_current_assig_id (
                p_unit_code => p_unit_code
            );

        v_new_effective_datetime := systimestamp;

    else

        v_af_oncall_sche_id :=
            find_unit_future_assig_id (
                p_unit_code => p_unit_code
            );

         v_new_effective_datetime := p_specific_datetime;

    end if;

    if v_af_oncall_sche_id <> -1 then

        update af_oncall_schedule
            set assignee_username = p_pass_onto,
                effective_datetime = v_new_effective_datetime,
                assigned_datetime  = systimestamp,
                assigned_by        = v('CURRENT_USERNAME'),
                assign_mode        = p_mode,
                sche_job_num = null,
                sche_job_status = null
        where id = v_af_oncall_sche_id;

   else 

        insert into af_oncall_schedule ( unit_code, assignee_username, effective_datetime, assigned_datetime, assigned_by, assign_mode )
           values( p_unit_code, p_pass_onto, v_new_effective_datetime, systimestamp, v('CURRENT_USERNAME'), p_mode );

        select max(id) into v_af_oncall_sche_id from af_oncall_schedule;

   end if;




   ------------------------------------------------
   -- Send notification
   ------------------------------------------------
   select email, first_name || ' ' || last_name 
   into v_default_sender, v_default_sender_name 
   from users where upper(username) = upper( v('CURRENT_USERNAME') );

   select a.first_name || ' ' || a.last_name, email 
   into v_new_pass_onto_name, v_new_pass_onto_email 
   from users a where username = p_pass_onto;


    --    if p_mode <> 'IM' then
    --        v_receivers := v_default_sender || ',' || v_old_pass_onto_email  || ',' || v_new_pass_onto_email;
   --     else
            v_receivers := GET_curr_ONCALL_EMAILS() || ',' || v_new_pass_onto_email|| ',' ||'cms@toronto.ca,lsitu@toronto.ca';
   --     end if;

        v_emailsubject  := 'Do Not Reply - Next [ ' || v_region_to_be_reassigned || ' ] has been assigned';

        v_emailbody     := 'Hi All,' || CRLF || CRLF
                        || 'Please note next [ ' || v_region_to_be_reassigned || ' ] has been assigned by ' || v_default_sender_name || '. ' || CRLF || CRLF
                        || upper( v_new_pass_onto_name ) || ' will be replacing ' || v_old_pass_onto_name || ' as [ ' || v_region_to_be_reassigned || ' ], starting at: ' || v_new_effective_datetime
                        || '.' || CRLF || CRLF
                        || 'This is an automated email.  Please do not reply to this message. ' || CRLF || CRLF
                        || 'Thanks.' || CRLF || CRLF
                    --    || 'CMS Afterhours'
                        || 'CMS Afterhours@' || getDBServerName()
                        ;


        v_default_sender  := 'cms@toronto.ca';
        send_useremail(
            p_sender       => v_default_sender,
            p_recipients   => v_receivers,
            p_cc           => null,
            p_replyto      => v_default_sender,
            p_subject      => v_emailsubject,
            p_message      => v_emailbody,
            P_is_body_html => false
        );

        /*if  p_unit_code=6 and p_mode='IM' then
            oro(v('CURRENT_USERNAME'), sysdate, v('CURRENT_USERNAME'), sysdate, P_PASS_ONTO, P_SPECIFIC_DATETIME);
        end if;*/

        -- Finally, schedule a job for next auto-notification
        -- usage of adding time interval: http://www.dba-oracle.com/t_date_math_manipulation.htm

        -- This is only for future on-duty assignment
        if p_mode <> 'IM' then

            -- get predefined variable from app control table
            v_af_schjob_tctr_var := AF_APP_CONFIG_PCK.getControlParamValue(
                                            p_param_name => 'af_schedulejob_timecontrol_var'
                                       );


            -- if the variable is defined as "prohibit", then stop doing the whole email thing and schedule job
            if v_af_schjob_tctr_var is not null and upper( v_af_schjob_tctr_var ) <> upper( 'prohibit' ) then 

                v_af_schjob_tctr_var := v_af_schjob_tctr_var / 24 / 60;

                if to_date( to_date( v_new_effective_datetime, 'dd-MON-yyyy HH24:MI' ) - to_number( v_af_schjob_tctr_var ) ) - sysdate < 0.0 then

                    EMAIL_FOR_NEXT_AVAI_ASSIGNMENT( p_unit_code, COALESCE(v('CURRENT_USERNAME'), user) );

                else

                    if v_af_sche_job_pack_var = '1' then
                    
                        dbms_job.submit(
                                job         => v_job_num,
                                what        => 'begin AF_ASSIGNMENT_PCK.EMAIL_FOR_NEXT_AVAI_ASSIGNMENT(' || p_unit_code || ', COALESCE(v(''CURRENT_USERNAME''), user) ); end;', 
                                next_date   => to_date( v_new_effective_datetime, 'dd-MON-yyyy HH24:MI' ) - to_number( v_af_schjob_tctr_var ), 
                             --   next_date   => sysdate+2/24/60, 
                                interval    => 'null'
                           --     no_parse    => false,
                           --     instance    => ANY_INSTANCE,
                           --     force       => true
                            );  

                    else
                    
                        -- added on DEc 21, 2020
                        
                        v_job_num := p_unit_code;
                        
                        DBMS_SCHEDULER.CREATE_JOB(
                           job_name          =>  'af_job_unit_code_' || p_unit_code,
                           job_type          =>  'PLSQL_BLOCK',
                           job_action        =>  'begin AF_ASSIGNMENT_PCK.EMAIL_FOR_NEXT_AVAI_ASSIGNMENT(' || p_unit_code || ', COALESCE(v(''CURRENT_USERNAME''), user) ); end;',
                           start_date        =>  to_date( v_new_effective_datetime, 'dd-MON-yyyy HH24:MI' ) - to_number( v_af_schjob_tctr_var ), 
                           repeat_interval   =>  null,
                           enabled           =>  TRUE
                    
                           
                        );
                    
                    
                    end if;
    
                    -- Need to save the job number into table for future reference
                    update AF_ONCALL_SCHEDULE
                        set sche_job_num = v_job_num,
                            sche_job_status = case when sche_job_status is null 
                                                        then 'scheduled'
                                                        else sche_job_status || ';scheduled'
                                                  end
                    where id = v_af_oncall_sche_id;



                end if;



            end if;

        end if;


       cleanupScheduleTable(
            p_unit_code => p_unit_code
        );

  END update_assignment_tbl;


  ------------------------------------------
-- find_unit_current_assig_id
------------------------------------------
  function find_unit_current_assig_id (
        p_unit_code varchar2
    )
    return number
    as
        v_af_oncall_sche_id number;
    begin

        ---------------------------------------------------------
        -- need to find one which satisfies b=ht of followings:
        -- (1) effective datetime < sysdate
        -- (2) latest effective datetime whcih satifies (1)
        ---------------------------------------------------------

        select b.id into v_af_oncall_sche_id
        from 
        (
            select unit_code, max( effective_datetime ) max_datetime from af_oncall_schedule 
            where unit_code = p_unit_code and effective_datetime <= sysdate
            group by unit_code
        ) sche
        inner join af_oncall_schedule b
        on sche.unit_code = b.unit_code and sche.max_datetime = b.effective_datetime
        where b.unit_code = p_unit_code;

        return v_af_oncall_sche_id;

    exception
        when no_data_found then
            return -1;

    end find_unit_current_assig_id;

------------------------------------------
-- find_unit_future_assig_id
------------------------------------------    
    function find_unit_future_assig_id (
        p_unit_code varchar2
    )
    return number
    as
    v_af_oncall_sche_id number;
    begin

        ---------------------------------------------------------
        -- need to find one which satisfies b=ht of followings:
        -- (1) effective datetime > sysdate
        -- (2) latest assigned
        ---------------------------------------------------------

        select b.id into v_af_oncall_sche_id
        from 
        (
            select unit_code, max( assigned_datetime ) latest_assign_datetime 
            from af_oncall_schedule 
            where unit_code = p_unit_code and effective_datetime > sysdate
            group by unit_code
        ) sche
        inner join af_oncall_schedule b
        on sche.unit_code = b.unit_code 
        and sche.latest_assign_datetime = b.assigned_datetime
        where b.unit_code = p_unit_code
       and rownum < 2
        ;

        return v_af_oncall_sche_id;

    exception
        when no_data_found then

            return -1;

    end find_unit_future_assig_id;


-------------------------------
-- get_call_menu_table
-------------------------------
    function get_call_menu_table (
        p_unit_code varchar2
    )
    return list_obj_table PIPELINED
    is

        row_rec list_obj;

    begin

        for rec in (

            select 1, 
                   case 
                      when business_cell is not null then 'Mobile'
                      else null --'No Mobile Number'
                   end label, 
                   case 
                      when business_cell is not null then 'Tel:1' || business_cell
                      else null              
                   end target
            from users          
            where users.username = AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( p_unit_code, 'pass_onto' )

            union

            select 2, 
                   case 
                      when telephone is not null then 'Desk'
                      else null --'No Desk Number'
                   end label, 
                   case 
                      when telephone is not null then 'Tel:1' || telephone

                      else null            
                   end target
            from users
            where users.username = AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( p_unit_code, 'pass_onto' )

        ) loop

                IF rec.target is not null THEN
                    SELECT rec.label, rec.target
                        INTO row_rec.label, row_rec.target FROM DUAL;

                    PIPE ROW (row_rec);
                END IF;
        end loop;

        return;

    end get_call_menu_table;


------------------------------------------------
-- get_email_menu_table
------------------------------------------------      
    function get_email_menu_table (
        p_unit_code varchar2
    )
    return list_obj_table PIPELINED
    is

        row_rec         list_obj;
        v_delimiter     varchar2(10) := ';';      
        v_browser_type  varchar2(10);

        v_section_str   varchar2(10) := 'section';
        v_division_str  varchar2(10) := 'division';
        v_favorite_str  varchar2(10) := 'favorite';
        
        v_current_user_favorite_str  varchar2(10) := 'myfavorite';

    begin

        v_browser_type := v('APP_IS_MOBILE');

        if v_browser_type is null or v_browser_type = 'N' then

            v_delimiter := ';';

        else

            v_delimiter := ',';

        end if;

        for rec in (

            select 1, 
                   'Email '||users.first_name || ' ' || users.last_name label, 
                   'javascript:var mailTab=window.open(''mailto:'||users.email||''',''_blank''); mailTab.focus();  
                   setTimeout(function(){if(!mailTab.document.hasFocus()) { mailTab.close();}}, 300);' target,
                   1 seq

            from users
            where users.username = AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( p_unit_code, 'pass_onto' )

            union

            select 1, 
                   'Email all favorite units' label, 
                   'javascript:var mailTab=window.open(''mailto:' || AF_ASSIGNMENT_PCK.get_curr_oncall_emails( p_unit_code, v_favorite_str, v_delimiter ) ||''',''_blank''); mailTab.focus();  
                   setTimeout(function(){if(!mailTab.document.hasFocus()) { mailTab.close();}}, 300);' target,
                   2 seq

            from users
            where users.username = AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( p_unit_code, 'pass_onto' )

            union

            select 1, 
                   'Email all in section' label, 
                   'javascript:var mailTab=window.open(''mailto:' || AF_ASSIGNMENT_PCK.get_curr_oncall_emails( p_unit_code, v_section_str, v_delimiter ) ||''',''_blank''); mailTab.focus();  
                   setTimeout(function(){if(!mailTab.document.hasFocus()) { mailTab.close();}}, 300);' target,
                   3 seq

            from dual

            union

            select 1, 
                   'Email all in division' label, 
                   'javascript:var mailTab=window.open(''mailto:'|| AF_ASSIGNMENT_PCK.get_curr_oncall_emails( p_unit_code, v_division_str, v_delimiter ) ||''',''_blank''); mailTab.focus();  
                   setTimeout(function(){if(!mailTab.document.hasFocus()) { mailTab.close();}}, 300);' target,
                   4 seq

            from dual
            
            
            -- Added on Dec 03, 2020
            union

            select 1, 
                   'Email all in my favorites' label, 
                   'javascript:var mailTab=window.open(''mailto:'|| AF_ASSIGNMENT_PCK.get_curr_oncall_emails( p_unit_code, v_current_user_favorite_str, v_delimiter ) ||''',''_blank''); mailTab.focus();  
                   setTimeout(function(){if(!mailTab.document.hasFocus()) { mailTab.close();}}, 300);' target,
                   5 seq

            from dual


        ) loop

                    SELECT rec.label, rec.target, rec.seq
                        INTO row_rec.label, row_rec.target, row_rec.seq FROM DUAL;

                    PIPE ROW (row_rec);

        end loop;

        return;

    end get_email_menu_table;

-------------------------------
-- ret_oncall_pass_onto_info
-------------------------------
  function ret_oncall_pass_onto_info(
        p_unit_code    varchar2,
        p_ret_type     varchar2,
        p_curr_or_future varchar2 default 'C'
    )
    return varchar2 AS

        v_fullname              varchar2(200);
        v_pass_onto             varchar2(200);
        v_title                 varchar2(200);
        v_business_cell         varchar2(200);
        v_email                 varchar2(200);
        v_effective_timestamp   timestamp;

        v_ret           varchar2(200) := 'unknown type';

  BEGIN

    select 
        case when first_name is not null then
            first_name || ' ' || last_name || ' ( ' || username || ' )'
            else username
        end,
        assignee_username,
        title,
        business_cell,
        email,
        effective_datetime
    into
        v_fullname,
        v_pass_onto,
        v_title,
        v_business_cell,
        v_email,
        v_effective_timestamp
    from users
    inner join  af_oncall_schedule sche 
    on upper( users.username ) = upper( sche.assignee_username )
    where 
    ( p_curr_or_future is null
      and sche.id = find_unit_current_assig_id (
                        p_unit_code => p_unit_code
                    )
    )
    or
    ( p_curr_or_future is not null and p_curr_or_future = 'C'
      and sche.id = find_unit_current_assig_id (
                        p_unit_code => p_unit_code
                    )
    )
    or
    ( p_curr_or_future is not null and p_curr_or_future = 'F'
      and sche.id = find_unit_future_assig_id (
                        p_unit_code => p_unit_code
                    )
    )
    ;

    if lower(p_ret_type) = 'fullname' then
            v_ret := v_fullname;
        elsif lower(p_ret_type) = 'pass_onto' then
            v_ret := v_pass_onto; 
        elsif lower(p_ret_type) = 'title' then
            v_ret := v_title; 
        elsif lower(p_ret_type) = 'business_cell' then
            v_ret := v_business_cell; 
        elsif lower(p_ret_type) = 'email' then
            v_ret := v_email;
        elsif lower(p_ret_type) = 'pass_effective_time' then
            v_ret := to_char( v_effective_timestamp, 'dd-MON-yyyy HH24:MI:SS' ); 
        end if;

        return v_ret;

  exception
    when no_data_found 
     then 
        if lower(p_ret_type) = 'fullname' then 
            return 'Not Assigned';
        else 
            return null;
        end if;

  END ret_oncall_pass_onto_info;

-------------------------------
-- ret_future_oncall_info
-------------------------------
  function ret_future_oncall_info(
        p_unit_code    varchar2
    )
    return varchar2 AS

    v_ret                 varchar2(200) := NO_NEXT_SCHEDULE_TEXT;

    v_fullname              varchar2(200);
    v_pass_onto             varchar2(200);
    v_title                 varchar2(200);
    v_business_cell         varchar2(200);
    v_email                 varchar2(200);
    v_effective_timestamp   timestamp;


  BEGIN

    select 
        case when first_name is not null then
            first_name || ' ' || last_name || ' ( ' || username || ' )'
            else username
        end,
        assignee_username,
        title,
        business_cell,
        email,
        effective_datetime
    into
        v_fullname,
        v_pass_onto,
        v_title,
        v_business_cell,
        v_email,
        v_effective_timestamp
    from users
    inner join  af_oncall_schedule sche 
    on upper( users.username ) = upper( sche.assignee_username )
    where sche.id = find_unit_future_assig_id (
                        p_unit_code => p_unit_code
                    );    

    v_ret := '[ Next: '
                    || v_fullname
                    || ' - '
                    || TO_CHAR ( v_effective_timestamp, 'dd-MON-yyyy HH24:MI:SS' ) 
              --      || v_effective_timestamp
                    || ' ]';

    RETURN v_ret;

  exception
    when no_data_found 
    then return NO_NEXT_SCHEDULE_TEXT;

  END ret_future_oncall_info;


------------------------------------------------
-- get_all_curr_fu_oncall_table
------------------------------------------------      
    function get_all_curr_fu_oncall_table
        return oncall_obj_table PIPELINED
    as
        row_rec                   oncall_obj;
        v_new_pass_effective_time varchar2(200);
        v_new_pass_onto           varchar2(200);
        v_diff                    number;
    begin

        for rec in (

            select distinct unit.code
            from af_unit unit
            inner join af_oncall_schedule sche
            on unit.code = sche.unit_code
            where active = 'Y' and on_call = 'Y'

        ) loop



                v_new_pass_effective_time := AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info(
                                                p_unit_code => rec.code,
                                                p_ret_type  => 'pass_effective_time'  
                                            );        


                v_new_pass_onto := AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info(
                                            p_unit_code => rec.code,
                                            p_ret_type  => 'pass_onto'
                                        );

                SELECT rec.code, v_new_pass_onto, v_new_pass_effective_time
                INTO row_rec.unit_code, row_rec.pass_onto, row_rec.pass_effective_time FROM DUAL;

                PIPE ROW (row_rec);

                v_new_pass_effective_time := AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info(
                                                p_unit_code => rec.code,
                                                p_ret_type  => 'pass_effective_time',
                                                p_curr_or_future => 'F'  
                                            );        


                v_new_pass_onto := AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info(
                                            p_unit_code => rec.code,
                                            p_ret_type  => 'pass_onto',
                                            p_curr_or_future => 'F'
                                        );

                SELECT rec.code, v_new_pass_onto, v_new_pass_effective_time
                INTO row_rec.unit_code, row_rec.pass_onto, row_rec.pass_effective_time FROM DUAL;

                PIPE ROW (row_rec);


        end loop;

    end get_all_curr_fu_oncall_table;

------------------------------------------------
-- get_all_current_oncalls
------------------------------------------------   
    procedure get_all_current_oncalls (
        p_output_format     varchar2 default 'json',
        p_all_found   out   varchar2 
    )
    is    
    begin

        get_pair_values_output (
            p_output_format => p_output_format,
            p_qry_str        => QRYSTR_GET_ALL_CURRENT_ONCALLS,
            p_output_allstr  => p_all_found
        );

    end get_all_current_oncalls;

------------------------------------------------
-- get_pair_values_output_as_json
------------------------------------------------       
    procedure get_pair_values_output (
        p_output_format      varchar2 default 'json',
        p_qry_str            varchar2,
        p_output_allstr out  varchar2  
    )
    is

        v_retval       clob;
        json_all       clob;

        TYPE cur_type IS REF CURSOR;
        c              cur_type;

        v_option_val   varchar2(2000);
        v_option_dis   varchar2(2000);
        v_email        varchar2(2000);

        v_temp_val     varchar2(2000) := null;

        json_comp      varchar2(4000);

        cnt            int := 0;
        is_found       boolean;
        l_vc_arr1      APEX_APPLICATION_GLOBAL.VC_ARR2;

    begin

        json_all := '';

        json_comp := 
                    '{'
                  || '"option_dis":"' || 'None' || '",'
                  || '"option_val":"' || 'None' || '"'
                  || '}';

        OPEN c FOR p_qry_str;
        loop

            cnt := cnt + 1;

            FETCH c INTO v_option_dis, v_option_val, v_email;
            EXIT WHEN c%NOTFOUND;

            v_option_dis := REPLACE(REPLACE(REGEXP_REPLACE(v_option_dis, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\n') ;
            v_option_val := REPLACE(REPLACE(REGEXP_REPLACE(v_option_val, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\u') ;


            if p_output_format = 'email' then

                is_found := false;

                l_vc_arr1  := APEX_UTIL.STRING_TO_TABLE( v_temp_val );

                FOR z IN 1..l_vc_arr1.count LOOP

                    if l_vc_arr1(z) is not null and trim( l_vc_arr1(z) ) = trim( v_option_val ) then
                        is_found := true;

                    end if;            

                END LOOP;

                if is_found = false then

                    if cnt = 1 then

                        v_temp_val := v_option_val;
                        p_output_allstr := v_email;

                    else

                        v_temp_val := v_temp_val || ':' || v_option_val;
                        p_output_allstr := p_output_allstr || ',' || v_email;


                    end if;


                end if;

            else /* id_only */
                p_output_allstr := p_output_allstr || ':' || v_option_val;
            end if;


            if p_output_format = 'json' then

                json_comp := 
                        '{'
                      || '"option_dis":"' || v_option_dis || '",'
                      || '"option_val":"' || v_option_val || '"'
                      || '}';

                if  cnt = 1 then

                    json_all := json_comp;

                else

                    json_all := json_all || ',' || json_comp;

                end if;


            end if;

        end loop;
        close c;

        if p_output_format = 'json' then

           v_retval := '[' || json_all || ']';

            ----------------------------------------
            -- This is for test when debugging
            ----------------------------------------
       --     v_retval := '[{"option_dis":"value1","option_val":"value2"},{"option_dis":"value3","option_val":"value4"}]';

            htp.p(v_retval);


        end if;

        return;

    end get_pair_values_output;


  ------------------------------------------------
-- send_useremail
------------------------------------------------ 
    procedure send_useremail(
        p_sender      varchar2,
        p_recipients  varchar2,
        p_cc          varchar2 DEFAULT null,
        p_bcc         varchar2 DEFAULT 'cms@toronto.ca,lsitu@toronto.ca',      
        p_replyto     varchar2,
        p_subject     varchar2,
        p_message     varchar2,
        P_is_body_html boolean DEFAULT false
      )
      as
        real_sender  varchar2(1000);
        real_to      varchar2(2000);
        real_subject varchar2(2000);
        real_message varchar2(10000);
        real_cc      varchar2(1000);
        real_bcc     varchar2(1000);
        real_replyto varchar2(1000);

        v_test_mode          varchar2(100);
        v_test_user_email    varchar2(100);
        v_test_user_email_1  varchar2(100);
        v_app_enable_email varchar2(100);

      begin

        real_sender  := p_sender;
        real_to      := p_recipients;
        real_subject := p_subject;
        real_message := p_message;
        real_cc      := p_cc;
        real_bcc     := p_bcc;
        real_replyto := p_replyto;

        real_to := remove_duplic_in_delimited_str(
                    p_in_str         => real_to,
                    p_delimited_char => ','
                );

        real_cc := remove_duplic_in_delimited_str(
                    p_in_str         => real_cc,
                    p_delimited_char => ','
                )
                ||
                ',' || AF_APP_CONFIG_PCK.getControlParamValue( p_param_name => 'notif_email_added_cc' ) ;

        real_bcc := remove_duplic_in_delimited_str(
                    p_in_str         => real_bcc,
                    p_delimited_char => ','
                );

        real_replyto := remove_duplic_in_delimited_str(
                    p_in_str         => real_replyto,
                    p_delimited_char => ','
                );

        begin


            v_test_mode           := AF_APP_CONFIG_PCK.getControlParamValue(
                                            p_param_name => 'app_in_test_mode'
                                        );

            v_test_user_email     := AF_APP_CONFIG_PCK.getControlParamValue(
                                            p_param_name => 'app_tester_mail'
                                        );

            v_app_enable_email := AF_APP_CONFIG_PCK.getControlParamValue(
                                            p_param_name => 'app_enable_email'
                                       );



        exception
            when others then
                v_test_mode          := PCK_TEST_MODE;
                v_test_user_email    := PCK_TEST_USER_EMAIL;
                v_app_enable_email   := PCK_APP_ENABLE_EMAIL;

        end;

        if upper( v_test_mode ) = 'Y' then

            v_test_user_email_1 := v_test_user_email;

            if instr( v_test_user_email, ',' ) > 0 then
                v_test_user_email_1:= substr( v_test_user_email, 1, instr( v_test_user_email, ',' ) - 1 );
            end if;


             -- Modified on Jun 02, 2020 Shawn
         --    real_sender  := upper( v_test_user_email_1 );
            real_sender  := v('APP_USER') || '@toronto.ca';

            real_subject := 'CMF AF is now configured as Test Mode in CMS Admin app ! - ' || p_subject;
            real_message := 'CMF AF is now configured as Test Mode in CMS Admin app ! - ' || CRLF || CRLF 
                            || 'Original recipients [ ' || real_to || ' ]' || CRLF || CRLF 
                            || 'Original cc [ ' || real_cc || ' ]' || CRLF || CRLF 
                            || 'Original bcc [ ' || real_bcc || ' ]' || CRLF || CRLF 
                            || 'Original replyto [ ' || real_replyto || ' ]' || CRLF || CRLF 
                            || 'Original sender [ ' || real_sender || ' ]' || CRLF || CRLF
                            || 'original message: ' || CRLF || CRLF
                            || p_message;

            real_to      := upper( v_test_user_email );
            real_cc      := null;
            real_bcc     := null;

            -- Modified on Jun 02, 2020 Shawn
          --   real_replyto := v_test_user_email;
            real_replyto := v('APP_USER') || '@toronto.ca';

        end if;

        if upper( v_app_enable_email ) = 'Y' then

            if P_is_body_html = true then

                APEX_MAIL.SEND(

                    p_to                        => real_to,
                    p_from                      => real_sender,
                    p_body                      => null,
                    p_body_html                 => real_message,
                    p_subj                      => real_subject,
                    p_cc                        => real_cc,
                    p_bcc                       => real_bcc,
                    p_replyto                   => real_replyto

                    );
                APEX_MAIL.PUSH_QUEUE;
            else

                APEX_MAIL.SEND(

                    p_to                        => real_to,
                    p_from                      => real_sender,
                    p_body                      => real_message,
                    p_body_html                 => null,
                    p_subj                      => real_subject,
                    p_cc                        => real_cc,
                    p_bcc                       => real_bcc,
                    p_replyto                   => real_replyto

                    );

            APEX_MAIL.PUSH_QUEUE;
            end if;

        end if;


  --      raise_application_error( -20000, real_message );

      end send_useremail;


------------------------------------------------
-- get_all_curr_only_oncall_table
-- This is to make sure email list triggered
-- by email button on page 11 only for current on-calls
------------------------------------------------      
    function get_all_curr_only_oncall_table (
        p_unit_code varchar2 default null,
        p_scope     varchar2 default null 
    )
    return oncall_obj_table PIPELINED
    as
        row_rec                   oncall_obj;
        v_new_pass_effective_time varchar2(200);
        v_new_pass_onto           varchar2(200);
        v_af_oncall_sche_id       number;
    begin

        for rec in (

            select distinct unit.code
            from af_unit unit

            inner join af_oncall_schedule sche
            on unit.code = sche.unit_code

            left join af_section_unit_mapping map1
            on map1.unit_code = p_unit_code

            left join af_section_unit_mapping map1_1
            on map1_1.section_code = map1.section_code

            left join af_division_section_mapping map2
            on map1_1.section_code = map2.section_code

            left join af_division_section_mapping map2_1
            on map2_1.division_code = map2.division_code

            left join af_section_unit_mapping map2_2
            on map2_1.section_code = map2_2.section_code

            left join af_user_favorites fav
            on fav.unit_code = unit.code
           
            where unit.active = 'Y' and unit.on_call = 'Y'
            and 
            (                   
                p_unit_code is null and p_scope is null
                or
                (
                    p_unit_code is not null 
                    and 
                    p_scope is null
                    and 
                    sche.unit_code = p_unit_code
                )             
                or
                (
                    p_unit_code is not null 
                    and 
                    p_scope is not null 
                    and 
                    p_scope = 'section'
                    and 
                    unit.code = map1_1.unit_code
                )
                or
                (
                    p_unit_code is not null 
                    and 
                    p_scope is not null 
                    and 
                    p_scope = 'division'      
                    and 
                    unit.code = map2_2.unit_code 

                )
                or
                (
                    p_unit_code is not null 
                    and 
                    p_scope is not null 
                    and 
                    p_scope = 'favorite'      
                    and 
                    upper( fav.username ) = upper( ret_oncall_pass_onto_info(
                                                        p_unit_code    => p_unit_code,
                                                        p_ret_type     => 'pass_onto'
                                                    ) 
                                                )

                )
               
            )
            
            union 
                
            select unit_code from af_user_favorites where upper( username ) = upper( v('APP_USER') )
              and p_scope = 'myfavorite'   

        ) loop

                v_new_pass_effective_time := AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info(
                                                p_unit_code => rec.code,
                                                p_ret_type  => 'pass_effective_time'  
                                            );        


                v_new_pass_onto := AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info(
                                            p_unit_code => rec.code,
                                            p_ret_type  => 'pass_onto'
                                        );

              --  SELECT rec.code, v_new_pass_onto, v_new_pass_effective_time
                SELECT rec.code, v_new_pass_onto, to_date( v_new_pass_effective_time, 'dd-MON-yyyy HH24:MI:SS' )
                
                INTO row_rec.unit_code, row_rec.pass_onto, row_rec.pass_effective_time FROM DUAL;

                PIPE ROW (row_rec);

        end loop;

    end get_all_curr_only_oncall_table;

------------------------------------------------
-- get_curr_oncall_emails
-- This is called by following two procedures to get Cc for emails.
--  (1) procedure email_for_next_avai_assignment()
--  (2) procedure update_assignment_tbl()
------------------------------------------------   
  function get_curr_oncall_emails (
        p_unit_code          varchar2 default null,
        p_scope              varchar2 default null,
        p_specific_delimiter varchar2 default null
    ) return varchar2 AS

        ret_val      varchar2(2000) := null;
        v_email      varchar2(100);

        TYPE cur_type IS REF CURSOR;
        c              cur_type;

        CURSOR c_oncall_emails IS 
         select a.email 
            from USERS a 
            inner join table( AF_ASSIGNMENT_PCK.get_all_curr_only_oncall_table( p_unit_code, p_scope ) ) b 
            on a.username = b.pass_onto 
            -- added on Dec 03, 2020
            where a.email is not null
            order by 1;

    begin

        OPEN c_oncall_emails;
        loop

            FETCH c_oncall_emails INTO v_email;
            EXIT WHEN c_oncall_emails%NOTFOUND;

            -- added on Dec 20, 2018   
            if p_specific_delimiter is null then
                ret_val := ret_val || ',' || v_email;
            else
                ret_val := ret_val || p_specific_delimiter || v_email;
            end if;

        end loop;
        close c_oncall_emails;

        -- added on Dec 20, 2018
        if p_specific_delimiter is null then

            ret_val := remove_duplic_in_delimited_str(
                    p_in_str         => ret_val,
                    p_delimited_char => ','
                );

        else

            ret_val := remove_duplic_in_delimited_str(
                    p_in_str         => ret_val,
                    p_delimited_char => p_specific_delimiter
                );

        end if;

        return ret_val;

  END get_curr_oncall_emails;

------------------------------------------------
-- email_for_next_avai_assignment
-- This is the scheduled job
------------------------------------------------      
    procedure email_for_next_avai_assignment(
        p_specific_unit_code       varchar2 default null,
        p_specific_trans_username  varchar2 default null
    )
    is
        v_sche_id_return        VARCHAR2(200);
        v_sche_unit_code_return VARCHAR2(200);

        v_next_assignee        VARCHAR2(200);
        v_next_assignee_email  VARCHAR2(200);
        v_next_schedule        VARCHAR2(200);
        v_next_transaction_by  VARCHAR2(200);

        v_default_sender           varchar2(100);
        v_receivers                varchar2(1000)  := null;
        v_cc                       varchar2(1000) := null;
        v_emailsubject             varchar2(1000) := null;
        v_emailbody                varchar2(4000) := null;

        v_pass_onto_to_be_replaced  varchar2(100);
        v_region_to_be_reassigned   varchar2(400);
        v_old_pass_onto_name        varchar2(100);

        v_old_pass_onto_email       varchar2(100);

        c                           utl_smtp.connection;

    begin

         -- This is for debugging
        /* 
        c := utl_smtp.open_connection('mail.toronto.ca', 25); -- SMTP on port 25 
        utl_smtp.helo(c, 'mail.toronto.ca');
        utl_smtp.mail(c, 'cms@toronto.ca');
        utl_smtp.rcpt(c, 'xli5@toronto.ca');

        utl_smtp.data(
            c,
            'From: cms@toronto.ca' || utl_tcp.crlf ||
            'To: xli5@toronto.ca' || utl_tcp.crlf ||
            'Subject: debug info from scheduled job'  

        );
        utl_smtp.quit(c);
       */

        ---------------------------------------------
        -- if there is no spcific unit code, then 
        -- chosse latest future schedule
        ---------------------------------------------

        begin

            select sche.id, unit_code, unit.name 
            into v_sche_id_return, v_sche_unit_code_return, v_region_to_be_reassigned
            from af_oncall_schedule sche
            inner join af_unit unit
            on unit.code = sche.unit_code
            where assign_mode <> 'IM'
            and
            (
                (
                    p_specific_unit_code is not null
                    and 
                    unit_code = p_specific_unit_code
                    and 
                    assign_mode <> 'IM'
                    and 
                    effective_datetime =
                    (
                        select max(effective_datetime) from af_oncall_schedule where assign_mode <> 'IM' and unit_code = p_specific_unit_code
                    )
                )
                or
                (
                    p_specific_unit_code is null
                    and effective_datetime =
                    (
                        select max(effective_datetime) from af_oncall_schedule where assign_mode <> 'IM'
                    )
                )
            );

         exception
            when no_data_found then
                return;

         end;    

        v_next_assignee_email       := ret_oncall_pass_onto_info( v_sche_unit_code_return, 'email', 'F' );
        v_next_assignee             := ret_oncall_pass_onto_info( v_sche_unit_code_return, 'fullname', 'F' );
        v_next_schedule             := ret_oncall_pass_onto_info( v_sche_unit_code_return, 'pass_effective_time', 'F' );

        v_pass_onto_to_be_replaced  := ret_oncall_pass_onto_info( v_sche_unit_code_return, 'fullname' );

        v_default_sender := 'cms@toronto.ca';

        v_receivers     := v_next_assignee_email;

        ----------------------------
        -- Only current on-duty people will get email
        -- no future on-duty will get email
        ----------------------------
            v_cc            := GET_curr_ONCALL_EMAILS( v_sche_id_return ) || ',' || v_old_pass_onto_email;

            v_emailsubject  := 'Do Not Reply - ' || v_next_assignee || ' on-call duty as [ ' || v_region_to_be_reassigned || ' ] starting at [ ' || v_next_schedule || ' ]';

            v_emailbody     := 'Hi ' || v_next_assignee || ', ' || CRLF || CRLF
                            || 'This is a friendly reminder that your on-call duty as [ ' || v_region_to_be_reassigned || ' ] will start at  ' || v_next_schedule || '.   ' || CRLF || CRLF
                            || 'You will be replacing current on-call [ ' || v_pass_onto_to_be_replaced || ' ]' || CRLF || CRLF
                            || 'This is an automated email.  Please do not reply to this message.' || CRLF || CRLF
                            || 'Thank you.' || CRLF || CRLF
                         --   || 'CMS Afterhours' || CRLF || CRLF
                            || 'CMS Afterhours@' || getDBServerName() || CRLF || CRLF
                            -- Can comment this out if necessary
                            || output_all_assgn_in_text_tbl
                            ;

            -- This check added on Jan 11, 2019 by Shawn
            -- Previously, if new future assignment is created, adn there is no enough time
            -- to submit job, this function will be called directly from APEX session
            -- and then APEX app will get JSON.PArser error !!!!
            if v('APP_USER') is null then

                tmp_create_apex_session(
                    p_app_id      => 166,
                    p_app_user    => 'cmsaf',
                    p_app_page_id => 1
                );

            end if;

           /*if p_specific_unit_code=6 then
                oro(
                        p_specific_trans_username, 
                        to_date( ret_oncall_pass_onto_info( p_specific_unit_code, 'pass_effective_time', 'F'), 'dd-MON-yyyy HH24:MI:SS'), 
                        p_specific_trans_username,
                        to_date( ret_oncall_pass_onto_info( p_specific_unit_code, 'pass_effective_time', 'F' ), 'dd-MON-yyyy HH24:MI:SS'), 
                        ret_oncall_pass_onto_info( p_specific_unit_code, 'pass_onto', 'F' ), 
                        v_next_schedule
                    );
            end if;*/

           if v_next_assignee <> 'Not Assigned' then

                send_useremail(
                    p_sender       => v_default_sender,
                    p_recipients   => v_receivers,
                    p_cc           => v_cc,
                    p_replyto      => v_default_sender,
                    p_subject      => v_emailsubject,
                    p_message      => v_emailbody,
                    P_is_body_html => false
                );


            -- Update schedule job status
                        update AF_ONCALL_SCHEDULE
                            set sche_job_status = case when sche_job_status is null 
                                                        then 'completed'
                                                        else case when instr( sche_job_status, 'completed' ) = 0 then sche_job_status || ';completed'
                                                                  else sche_job_status
                                                             end
                                                  end
                        where id = v_sche_id_return;

            else

                -- Update schedule job status
                        update AF_ONCALL_SCHEDULE
                            set sche_job_status = case when sche_job_status is null 
                                                        then 'not killed job and email cancelled'
                                                        else case when instr( sche_job_status, 'not killed job and email cancelled' ) = 0 then sche_job_status || ';not killed job and email cancelled'
                                                                  else sche_job_status
                                                             end

                                                  end

                        where id = v_sche_id_return;

            end if;

    end email_for_next_avai_assignment;

  ------------------------------------------------
-- tmp_create_apex_session
-- This is for oracle scheduled job outside the APEX
------------------------------------------------     
    PROCEDURE tmp_create_apex_session(
          p_app_id IN apex_applications.application_id%TYPE,
          p_app_user IN apex_workspace_activity_log.apex_user%TYPE,
          p_app_page_id IN apex_application_pages.page_id%TYPE DEFAULT 1
    ) 
    AS
      l_workspace_id apex_applications.workspace_id%TYPE;
      l_cgivar_name  owa.vc_arr;
      l_cgivar_val   owa.vc_arr;
    BEGIN



      htp.init; 

      l_cgivar_name(1) := 'REQUEST_PROTOCOL';
      l_cgivar_val(1) := 'HTTP';

      owa.init_cgi_env( 
        num_params => 1, 
        param_name => l_cgivar_name, 
        param_val => l_cgivar_val ); 

      SELECT workspace_id
      INTO l_workspace_id
      FROM apex_applications
      WHERE application_id = p_app_id;

      wwv_flow_api.set_security_group_id(l_workspace_id); 

      apex_application.g_instance := 1; 
      apex_application.g_flow_id := p_app_id; 
      apex_application.g_flow_step_id := p_app_page_id; 


      -- Notes on Jan. 11, 2019 by Shawn Li
      -- This sometimes may popup JSON.Parser error
      apex_custom_auth.post_login( 
        p_uname => p_app_user, 
     --   p_session_id => null, -- could use APEX_CUSTOM_AUTH.GET_NEXT_SESSION_ID
        p_session_id => APEX_CUSTOM_AUTH.GET_NEXT_SESSION_ID,
    --    p_session_id => V('APP_SESSION'),
        p_app_page => apex_application.g_flow_id||':'||p_app_page_id); 


    END tmp_create_apex_session;

------------------------------------------------
-- remove_duplic_in_delimited_str
------------------------------------------------ 
    function remove_duplic_in_delimited_str(
        p_in_str            varchar2,
        p_delimited_char    varchar2 DEFAULT ':'
    ) return varchar2
    as
        v_ret varchar2(2000) := null;

        is_found       boolean;
        l_vc_arr1      APEX_APPLICATION_GLOBAL.VC_ARR2;
        l_vc_arr2      APEX_APPLICATION_GLOBAL.VC_ARR2;

        v_cnt          int := 0;

    begin

        if trim( p_in_str ) is null then        
            return null;       
        end if;

        l_vc_arr1  := APEX_UTIL.STRING_TO_TABLE( 
                        p_string    => p_in_str,
                        p_separator => p_delimited_char
                    );

        FOR z IN 1..l_vc_arr1.count LOOP

            is_found := false;

                if trim( l_vc_arr1(z) ) is not null then

                    FOR z1 IN 1..l_vc_arr2.count LOOP

                        if trim( l_vc_arr1(z) ) = l_vc_arr2(z1) then
                            is_found := true;               
                        end if;            

                    END LOOP;

                else
                    is_found := true; 
                end if;


            if is_found = false then

                v_cnt := v_cnt + 1;
                l_vc_arr2(v_cnt) := trim( l_vc_arr1(z) );                

            end if;

        END LOOP;


        v_ret := APEX_UTIL.TABLE_TO_STRING (
                    p_table     => l_vc_arr2,
                    p_string    => p_delimited_char
                    ); 


        return v_ret;

    END remove_duplic_in_delimited_str;


------------------------------------------------
-- output_all_assgn_in_text_tbl
------------------------------------------------        
    function output_all_assgn_in_text_tbl 
    return clob
    is
        v_ret clob := null;

        v_pad_num_1 int := 10;
        v_pad_num_2 int := 110;
        v_pad_num_3 int := 50;
        v_pad_num_4 int := 300;
        v_pad_num_5 int := 50;

        v_col_title_1 varchar2(200) := 'ID';
        v_col_title_2 varchar2(200) := 'Unit';
        v_col_title_3 varchar2(200) := 'Current on-duty';
        v_col_title_4 varchar2(200) := 'Future on-duty';
        v_col_title_5 varchar2(200) := 'Effective Time';

        v_tmp_str     varchar2(300);
        v_tmp_str_1   varchar2(300);
        v_tmp_str_2   varchar2(300);

    begin


        v_ret := '***********************************************' || CRLF 
                || 'This table shows all current / future on-duty assignments for all units'
                || CRLF || CRLF
              --  || rpad( v_col_title_1, v_pad_num_1 - length(v_col_title_1), ' ' )
             --   || rpad( v_col_title_2, v_pad_num_2 - length(v_col_title_2), ' ' )
             --   || rpad( v_col_title_3, v_pad_num_3 - length(v_col_title_3), ' ' )
             --   || rpad( v_col_title_4, v_pad_num_4 - length(v_col_title_4), ' ' )

            --    || rpad( v_col_title_5, v_pad_num_5 - length(v_col_title_5) )
             --   || CRLF
                ;

        for rec in (

            select 
                distinct
                sche.unit_code,
                unit.name unit_name

            from af_oncall_schedule sche
            inner join af_unit unit
            on sche.unit_code = unit.code
            where unit.active = 'Y' and unit.on_call = 'Y'
            order by unit.name

        ) loop

            v_tmp_str := trim( 
                            ret_oncall_pass_onto_info (
                                P_unit_code   =>  rec.unit_code,
                                p_ret_type    => 'fullname'
                            ) 
                        );

            v_tmp_str_1 := trim( 
                              RET_FUTURE_ONCALL_INFO(
                                P_unit_code =>  rec.unit_code
                              )
                            );

            if  v_tmp_str_1 = NO_NEXT_SCHEDULE_TEXT then
                v_tmp_str_1 := null;
            end if;

            v_ret :=  v_ret || CRLF 
                 --     || rpad( rec.on_call_id,    v_pad_num_1 - length(rec.on_call_id),         ' ' )
                --      || rpad( rec.category_cd,   v_pad_num_2 - length(rec.category_cd),        ' ' )
                --      || rpad( v_tmp_str_1,         v_pad_num_3 - length(v_tmp_str_1), ' ' ) 
                --      || rpad( v_tmp_str_1,       v_pad_num_4 - length(v_tmp_str_1), ' ' ) 
                      || rpad( rec.unit_code, v_pad_num_1 - length(rec.unit_code), ' ' )
                      || rec.unit_name || CRLF
                      || chr(09) || v_tmp_str || ' '
                      || v_tmp_str_1 || CRLF
                    --   || rpad( v_tmp_str_2,       v_pad_num_5 - length(v_tmp_str_2) ) 
                      ;

        end loop;


        return v_ret;

    end output_all_assgn_in_text_tbl;

------------------------------------------------
-- getDBServerName
------------------------------------------------     
    function getDBServerName return varchar2
    is
        v_nm varchar2(100) := null;

    begin

        v_nm := sys_context('USERENV','SERVER_HOST');

     /*   
        if v_nm = 'ytfvdor06' then
            return '@dev';
        elsif v_nm = 'wtor11hovm' then
            return '@test';
        -- return null if it is production
        elsif instr( v_nm, 'wpor13' ) > 0 then
            return null;
        else
            return v_nm;
        end if;
     */

      return v_nm;

    end getDBServerName;

------------------------------------------------
-- get_all_oncall_cadidates_table
------------------------------------------------    
    function get_all_oncall_cadidates_table
    return list_obj_table PIPELINED
    is
        row_rec list_obj;

        v_option_val   varchar2(2000);
        v_option_dis   varchar2(2000);

        TYPE cur_type IS REF CURSOR;
        c              cur_type;
        cnt            int;
    begin

        OPEN c FOR QRYSTR_GET_ALL_QUALIFY_ONCALLS;
        loop

            cnt := cnt + 1;

            FETCH c INTO v_option_dis, v_option_val;
            EXIT WHEN c%NOTFOUND;

            v_option_dis := REPLACE(REPLACE(REGEXP_REPLACE(v_option_dis, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\n') ;
            v_option_val := REPLACE(REPLACE(REGEXP_REPLACE(v_option_val, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\u') ;

            SELECT v_option_dis, v_option_val
            INTO row_rec.label, row_rec.target FROM DUAL;

            PIPE ROW (row_rec);

        end loop;
        close c;

        return;

    end get_all_oncall_cadidates_table;

 -------------------------------------------
 -- procedure cleanupScheduleTable
 -------------------------------------------
    procedure cleanupScheduleTable(
        p_unit_code varchar2
    )
    is
        v_curr_sche_id   number;
        v_future_sche_id number;
    begin

        v_future_sche_id := find_unit_future_assig_id (
                                p_unit_code => p_unit_code
                            );

        v_curr_sche_id := find_unit_current_assig_id (
                                p_unit_code => p_unit_code
                            );  

        delete from af_oncall_schedule
            where unit_code = p_unit_code
            and
            (
                v_curr_sche_id is not null and id <> v_curr_sche_id
            )
            and
            (
                v_future_sche_id is not null and id <> v_future_sche_id
            )
            ;



    end cleanupScheduleTable;

-------------------------------------------
 -- function is_user_in_current_unit
 -------------------------------------------  
    function is_user_in_current_unit (
        p_username       varchar2 default null,
        p_curr_unit_code varchar2 default null
    ) return boolean
    is 
        v_cnt       int;
        v_ret_bool  boolean := false;
        v_username  varchar2(100);
        v_unit_code varchar2(100);
    begin

        if p_username is not null then
            v_username := p_username;
        else
            v_username := v('CURRENT_USERNAME');
        end if;

        if p_curr_unit_code is not null then
            v_unit_code := p_curr_unit_code;
        else
            v_unit_code := v('APP_CURRENT_UNIT_CODE');
        end if;

        select count(*) into v_cnt 
        from AF_ONCALL_USER_UNIT_MAPPING
        where upper( username ) = upper( v_username ) and unit_code = v_unit_code;

        if v_cnt > 0 then
            v_ret_bool := true;
        end if; 

        return v_ret_bool;

    exception
        when others then
            return false;

    end is_user_in_current_unit;


------------------------------------------------
-- outputDivSecUnitHireJSON
------------------------------------------------     
    procedure outputDivSecUnitHireJSON(
        p_username varchar2 default null
    )
    is

        v_retval       clob;
        json_all       clob;

        v_parent_name   varchar2(2000);
        v_child_name    varchar2(2000);
        v_child_disp_name varchar2(2000);
        v_child_font_color varchar2(20);
        v_child_bg_color varchar2(20);
        v_child_code    varchar2(2000);
        v_child_url     varchar2(2000);
        v_parent_code    varchar2(2000);
        v_parent_url     varchar2(2000);
        v_tooltip        varchar2(2000);

        v_dup_child_bg_color varchar2(20) := '#DDA0DD';

        v_level         varchar2(2000);

        json_comp      varchar2(4000);

        cnt            int := 0;

        v_qry_str      varchar2(9000);

        TYPE cur_type IS REF CURSOR;
        c              cur_type;

        v_section_url   varchar2(400) := '<a style="color: inherit;" href="f?p=' || v('APP_ID') || ':200:' || v('SESSION') || '::NO:RP:P200_MODE,P200_MODE_PARAM,P200_PREV_PAGE:specific_section,';
        v_division_url  varchar2(400) := '<a style="color: inherit;" href="f?p=' || v('APP_ID') || ':500:' || v('SESSION') || '::NO:RP:P500_MODE,P500_MODE_PARAM,P500_PREV_PAGE:specific_division,';
        v_unit_url      varchar2(400) := '<a style="color: inherit;" href="f?p=' || v('APP_ID') || ':300:' || v('SESSION') || '::NO:RP:P300_UNIT_CODE,P300_PREV_PAGE:';
        v_return_pg_num varchar2(20)  := '6003';

        v_orphan_node         varchar2(100) := 'Not assigned';
        v_all_assigned_node   varchar2(100) := 'All assigned';

        TYPE dup_name IS TABLE OF NUMBER  -- Associative array type
        INDEX BY VARCHAR2(600);            --  indexed by string

        dup_child_name  dup_name;        -- Associative array variable
        i  VARCHAR2(600);                    -- Scalar variable
        k  VARCHAR2(600);                    -- Scalar variable

        v_found boolean;

    begin

        v_qry_str := 'select ' ||

                        ' distinct ' || 
                        ' ''div_sec'' cur_level, ' ||
                        ' sec.name child_name, ' ||
                        ' sec.name child_disp_name, ' ||
                        ' AF_APP_CONFIG_PCK.getFlexibleSeetingValue( ''af_section'', sec.code, ''SETTING_1'' ) child_font_color, ' ||
                        ' sec.code child_code, ' ||
                        ' ''' || v_section_url || ''' child_url, ' ||
                        ' div.code parent_code, ' ||
                        ' ''' || v_division_url || ''' parent_url, ' ||
                        ' sec.description tooltip, ' ||
                        ' div.name parent_name ' ||

                        'from af_division div ' ||
                        'inner join af_division_section_mapping map1 ' ||
                        'on div.code = map1.division_code ' || 
                        'inner join af_section sec ' || 
                        'on map1.section_code = sec.code ' ||

                        'union all ' ||

                        'select  ' ||

                        ' distinct ' || 
                            ' ''sec_unit'' cur_level, ' ||
                        '    unit.name child_name, ' ||
                        '    unit.name child_disp_name, ' ||
                        ' '''' child_font_color, ' ||
                        '    unit.code child_code, ' ||
                        ' ''' || v_unit_url || ''' child_url, ' ||
                        ' sec.code parent_code, ' ||
                        ' ''' || v_section_url || ''' parent_url, ' ||
                        ' unit.description tooltip, ' ||
                        '    sec.name parent_name ' ||
                        'from af_unit unit ' ||
                        'inner join af_section_unit_mapping map1 ' ||
                        'on unit.code = map1.unit_code ' ||
                        'inner join af_section sec ' ||
                        'on map1.section_code = sec.code ' ||

                        'union all ' ||

                        'select  ' ||

                        ' distinct ' || 
                            ' ''orphan_unit'' cur_level, ' ||
                        '    ''[Unit] '' || unit.name child_name, ' ||
                        '    ''[Unit] '' || unit.name child_disp_name, ' ||
                        '    '''' child_font_color, ' ||
                        '    unit.code child_code, ' ||
                        ' ''' || v_unit_url || ''' child_url, ' ||
                        ' '''' parent_code, ' ||
                        ' '''' parent_url, ' ||
                        ' unit.description tooltip, ' ||
                        ' ''' || v_orphan_node || ''' parent_name ' ||
                        'from af_unit unit ' ||
                        'left join af_section_unit_mapping map1 ' ||
                        'on unit.code = map1.unit_code ' ||
                        'where map1.unit_code is null ' ||

                        'union all ' ||

                        'select  ' ||

                        ' distinct ' || 
                        ' ''orphan_sec'' cur_level, ' ||
                        '    ''[Section] '' || sec.name child_name, ' ||
                        '    ''[Section] '' || sec.name child_disp_name, ' ||
                        '    AF_APP_CONFIG_PCK.getFlexibleSeetingValue( ''af_section'', sec.code, ''SETTING_1'' ) child_font_color, ' ||
                        '    sec.code child_code, ' ||
                        ' ''' || v_section_url || ''' child_url, ' ||     
                        ' '''' parent_code, ' ||
                        ' '''' parent_url, ' ||
                        ' sec.description tooltip, ' ||
                        ' ''' || v_orphan_node || ''' parent_name ' ||
                        'from af_section sec ' ||
                        'left join af_division_section_mapping map1 ' ||
                        'on sec.code = map1.section_code ' ||
                        'where map1.division_code is null ' ||

                        'union all ' ||

                        'select  ' ||

                        ' distinct ' || 
                        ' ''orphan_div'' cur_level, ' ||
                        '    ''[Division] '' || div.name child_name, ' ||
                        '    ''[Division] '' || div.name child_disp_name, ' ||
                        ' AF_APP_CONFIG_PCK.getFlexibleSeetingValue( ''af_division'', div.code, ''SETTING_1'' ) child_font_color, ' ||
                        '    div.code child_code, ' ||
                        ' ''' || v_division_url || ''' child_url, ' ||     
                        ' '''' parent_code, ' ||
                        ' '''' parent_url, ' ||
                        ' div.description tooltip, ' ||
                        ' ''' || v_orphan_node || ''' parent_name ' ||
                        'from af_division div ' ||
                        'left join af_division_section_mapping map1 ' ||
                        'on div.code = map1.division_code ' ||
                        'where map1.division_code is null ' ||

                        'union all ' ||

                        'select  ' ||

                        ' distinct ' || 
                        ' ''unit_oncall'' cur_level, ' ||
                        '    ''Oncall: '' || AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( sche.unit_code, ''fullname'' ) child_name, ' ||
                        '    ''Oncall: '' || AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( sche.unit_code, ''fullname'' ) child_disp_name, ' ||
                        '    '''' child_font_color, ' ||
                        '    unit.code child_code, ' ||
                        ' ''' || v_unit_url || ''' child_url, ' ||
                        ' unit.code parent_code, ' ||
                        ' ''' || v_unit_url || ''' parent_url, ' ||
                        ' '''' tooltip, ' ||
                        '    unit.name parent_name ' ||
                        'from af_oncall_schedule sche ' ||
                        'inner join af_unit unit ' ||
                        'on unit.code = sche.unit_code ' ||
                        'and AF_ASSIGNMENT_PCK.find_unit_current_assig_id( sche.unit_code ) <> -1 ' ||

                        'union all ' ||

                        'select  ' ||

                        ' distinct ' || 
                        ' ''unit_future'' cur_level, ' ||
                        '    ''Future: '' || AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( sche.unit_code, ''fullname'', ''F'' ) child_name, ' ||
                        '    ''Future: '' || AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( sche.unit_code, ''fullname'', ''F'' ) child_disp_name, ' ||
                        ' '''' child_font_color, ' ||
                        '    unit.code child_code, ' ||
                        ' ''' || v_unit_url || ''' child_url, ' ||
                        ' unit.code parent_code, ' ||
                        ' ''' || v_unit_url || ''' parent_url, ' ||
                        ' '''' tooltip, ' ||
                        '    unit.name parent_name ' ||
                        'from af_oncall_schedule sche ' ||
                        'inner join af_unit unit ' ||
                        'on unit.code = sche.unit_code ' ||
                        'and AF_ASSIGNMENT_PCK.find_unit_future_assig_id( sche.unit_code ) <> -1 ' ||

                        'union all ' ||

                        'select  ' ||

                        ' distinct ' || 
                        ' ''all_div'' cur_level, ' ||               
                        '    div.name child_name, ' ||
                        '    div.name child_disp_name, ' ||
                        '    AF_APP_CONFIG_PCK.getFlexibleSeetingValue( ''af_division'', div.code, ''SETTING_1'' ) child_font_color, ' ||
                        '    div.code child_code, ' ||
                        ' ''' || v_division_url || ''' child_url, ' ||     
                        ' '''' parent_code, ' ||
                        ' '''' parent_url, ' ||
                        ' div.description tooltip, ' ||
                        ' ''' || v_all_assigned_node || ''' parent_name ' ||
                        'from af_division div ' ||
                        'inner join af_division_section_mapping map1 ' ||
                        'on div.code = map1.division_code ' 

                        ;


        json_comp := 
                    '{'
                  || '"child_name":"' || 'None' || '",'
                  || '"child_disp_name":"' || 'None' || '",'
                  || '"child_font_color":"' || 'None' || '",'
                  || '"child_bg_color":"' || 'None' || '",'
                  || '"parent_name":"' || 'None' || '",'
                  || '"tooltip":"' || 'None' || '"'
                  || '}';

        OPEN c FOR v_qry_str;
        loop

            cnt := cnt + 1;

            FETCH c INTO v_level, v_child_name, v_child_disp_name, v_child_font_color, v_child_code, v_child_url, v_parent_code, v_parent_url, v_tooltip, v_parent_name;
            EXIT WHEN c%NOTFOUND;


            v_found := false;

            k := replace(v_level || '-' || v_child_name,' ', '');
            i := dup_child_name.FIRST;

            WHILE i IS NOT NULL LOOP

                if i = k then
                    v_found := true;
                end if;

                i := dup_child_name.NEXT(i);  -- Get next element of array
            END LOOP;

            if v_found = false then
                dup_child_name( k ) :=  0;
            end if;

            dup_child_name( k ) := dup_child_name( k ) + 1;       

            v_child_bg_color := null;

            if dup_child_name( k ) > 1 then

                v_child_name := v_child_name || '(' || dup_child_name( k ) || ')';  
                v_child_disp_name := v_child_disp_name || '(' || dup_child_name( k ) || ')';   

                v_child_bg_color := v_dup_child_bg_color;

            end if;


            v_child_name := v_child_url || v_child_code || ',' || v_return_pg_num || '">' || v_child_name || '</a>';
            v_child_disp_name := v_child_url || v_child_code || ',' || v_return_pg_num || '">' || v_child_disp_name || '</a>';


            if v_parent_name <> v_orphan_node and v_parent_name <> v_all_assigned_node then
                v_parent_name := v_parent_url || v_parent_code || ',' || v_return_pg_num || '">' || v_parent_name || '</a>';
            end if;

            v_child_name  := REPLACE(REPLACE(REGEXP_REPLACE(v_child_name, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\n') ;
            v_child_disp_name  := REPLACE(REPLACE(REGEXP_REPLACE(v_child_disp_name, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\n') ;
            v_parent_name := REPLACE(REPLACE(REGEXP_REPLACE(v_parent_name, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\n') ;


             json_comp := 
                        '{'                
                      || '"child_name":"' || v_child_name || '",'
                      || '"child_disp_name":"' || v_child_disp_name || '",'
                      || '"child_font_color":"' || v_child_font_color || '",'
                      || '"child_bg_color":"' || v_child_bg_color || '",'
                      || '"parent_name":"' || v_parent_name || '",'
                      || '"tooltip":"' || v_tooltip || '"'
                      || '}';

                if  cnt = 1 then

                    json_all := json_comp;

                else

                    json_all := json_all || ',' || json_comp;

                end if;

        end loop;
        close c;


           v_retval := '[' || json_all || ']';

            htp.p(v_retval);


        return;


    end outputDivSecUnitHireJSON;

------------------------------------------------
-- get_gantt_sche_table
------------------------------------------------       
    function get_gantt_sche_table (
        p_unit_code     varchar2,
        p_check_enddate varchar2               
    )
    return list_gantt_obj_table PIPELINED
    is

        v_cnt                 int := 0;
        v_prev_id             int;
        v_dedenpency_id       int;
        v_prev_username       varchar2(100);
        v_prev_effective_date timestamp;

        row_rec list_gantt_ibj;


    begin

        for rec in (

            select 
                id,
                case when b.first_name is null then ASSIGNEE_USERNAME
                     else b.first_name || ' ' || b.last_name || ' ( ' || ASSIGNEE_USERNAME || ' )'
                end ASSIGNEE_USERNAME,
                EFFECTIVE_DATETIME
            from af_oncall_schedule_hist a
            inner join users b
            on a.assignee_username = b.username
            where unit_code = p_unit_code
            -- order by id\
            order by effective_datetime

        ) loop

            v_cnt := v_cnt + 1;

            if v_cnt <> 1 then  

                if  to_char( v_prev_effective_date, 'YYYY-MM-DD' ) = to_char( rec.EFFECTIVE_DATETIME, 'YYYY-MM-DD' ) 
                    and
                    p_check_enddate = 'Y'
                then 

                    SELECT 
                        v_prev_id, 
                        v_prev_username, 
                       extract( year from v_prev_effective_date ),
                       extract( month from v_prev_effective_date ) - 1,
                       extract( day from v_prev_effective_date ),
                       extract( year from rec.EFFECTIVE_DATETIME + 1 ),
                       extract( month from rec.EFFECTIVE_DATETIME + 1 ) - 1,
                       extract( day from rec.EFFECTIVE_DATETIME + 1 ),
                       to_char( v_prev_effective_date, 'dd-MON-yyyy HH24:MI' ),
                       to_char( rec.EFFECTIVE_DATETIME, 'dd-MON-yyyy HH24:MI' ),
                       100,
                       v_dedenpency_id
                    INTO row_rec.id, row_rec.username, 
                    row_rec.start_date_y, row_rec.start_date_m, row_rec.start_date_d, 
                    row_rec.end_date_y, row_rec.end_date_m, row_rec.end_date_d,
                    row_rec.start_date, row_rec.end_date, row_rec.complete_percentage,
                    row_rec.dependency
                    FROM DUAL;

                else

                    SELECT 
                        v_prev_id, 
                        v_prev_username, 
                       extract( year from v_prev_effective_date ),
                       extract( month from v_prev_effective_date ) - 1,
                       extract( day from v_prev_effective_date ),
                       extract( year from rec.EFFECTIVE_DATETIME ),
                       extract( month from rec.EFFECTIVE_DATETIME ) - 1,
                       extract( day from rec.EFFECTIVE_DATETIME ),
                       to_char( v_prev_effective_date, 'dd-MON-yyyy HH24:MI' ),
                       to_char( rec.EFFECTIVE_DATETIME, 'dd-MON-yyyy HH24:MI' ),
                       100,
                       v_dedenpency_id
                    INTO row_rec.id, row_rec.username, 
                    row_rec.start_date_y, row_rec.start_date_m, row_rec.start_date_d, 
                    row_rec.end_date_y, row_rec.end_date_m, row_rec.end_date_d,
                    row_rec.start_date, row_rec.end_date, row_rec.complete_percentage,
                    row_rec.dependency
                    FROM DUAL;


                end if;


                PIPE ROW (row_rec);

            end if;

            if v_cnt = 1 then  
                v_dedenpency_id := null;
            else
                v_dedenpency_id := v_prev_id;
            end if;

            v_prev_id             := rec.id;
            v_prev_username       := rec.ASSIGNEE_USERNAME;
            v_prev_effective_date := rec.EFFECTIVE_DATETIME;


        end loop;

        SELECT 
            v_prev_id, 
            v_prev_username, 
           extract( year from v_prev_effective_date ),
           extract( month from v_prev_effective_date ) - 1,
           extract( day from v_prev_effective_date ),
           extract( year from v_prev_effective_date + 1 ),
           extract( month from v_prev_effective_date + 1 ) - 1,
           extract( day from v_prev_effective_date + 1 ),
           to_char( v_prev_effective_date, 'dd-MON-yyyy HH24:MI' ),
           to_char( v_prev_effective_date, 'dd-MON-yyyy HH24:MI' ),
           0,
           v_dedenpency_id
        INTO row_rec.id, row_rec.username, 
        row_rec.start_date_y, row_rec.start_date_m, row_rec.start_date_d, 
        row_rec.end_date_y, row_rec.end_date_m, row_rec.end_date_d,
        row_rec.start_date, row_rec.end_date, row_rec.complete_percentage,
        row_rec.dependency
        FROM DUAL;

        PIPE ROW (row_rec);

        return;

    end get_gantt_sche_table;

------------------------------------------------
-- outputGanttJSON
------------------------------------------------        
    procedure outputGanttJSON(
        p_unit_code varchar2,
        p_num_of_rec_ret int default -1
    )
    is

        v_retval       clob;
        json_all       clob;

        json_comp      varchar2(4000);

        cnt            int := 0;

        v_qry_str      varchar2(9000);

        TYPE cur_type IS REF CURSOR;
        c              cur_type;

        v_id                    varchar2(10);
        v_username              varchar2(100);
        v_start_date_y          varchar2(4);
        v_start_date_m          varchar2(2);
        v_start_date_d          varchar2(2);
        v_end_date_y            varchar2(4);
        v_end_date_m            varchar2(2);
        v_end_date_d            varchar2(2);
        v_complete_percentage   varchar2(4);
        v_dependency            varchar2(4);

    begin

        if p_num_of_rec_ret = -1 then

            v_qry_str := 'select id, username, start_date_y, start_date_m, start_date_d, end_date_y, end_date_m, end_date_d, '
                         || 'complete_percentage, case when dependency is null then ''null'' else dependency end dependency '
                         || 'from TABLE(AF_ASSIGNMENT_PCK.GET_GANTT_SCHE_TABLE( '
                         || ''''
                         || p_unit_code
                         || ''', '
                         || '''Y'''
                         || ') )';

        else

            v_qry_str := 'select id, username, start_date_y, start_date_m, start_date_d, end_date_y, end_date_m, end_date_d, '
                         || 'complete_percentage, case when dependency is null then ''null'' else dependency end dependency from '
                         || '( '
                         || 'select * from '
                         || '( '
                         || 'select * from '
                         || '( '
                         || 'select id, username, start_date_y, start_date_m, start_date_d, end_date_y, end_date_m, end_date_d, start_date, complete_percentage, dependency from TABLE(AF_ASSIGNMENT_PCK.GET_GANTT_SCHE_TABLE( '
                         || ''''
                         || p_unit_code
                         || ''', '
                         || '''Y'''
                         || ') ) order by to_date( start_date, ''dd-MON-yyyy HH24:Mi:SS'' ) desc  '
                         || ' ) a where rownum <= '
                         || p_num_of_rec_ret
                         || ' ) a order by to_date( start_date, ''dd-MON-yyyy HH24:Mi:SS'' ) ) a';

        end if;

    --    DBMS_OUTPUT.PUT_LINE(v_qry_str);

        json_comp := 
                    '{'
                  || '"id":"' || 'None' || '",'
                  || '"username":"' || 'None' || '",'
                  || '"start_date_y":"' || 'None' || '",'
                  || '"start_date_m":"' || 'None' || '",'
                  || '"start_date_d":"' || 'None' || '",'
                  || '"end_date_y":"' || 'None' || '",'
                  || '"end_date_m":"' || 'None' || '",'
                  || '"end_date_d":"' || 'None' || '",'
                  || '"complete_percentage":"' || 'None' || '",'
                  || '"dependency":"' || 'null' || '"'
                  || '}';

        OPEN c FOR v_qry_str;
        loop

            cnt := cnt + 1;

            FETCH c INTO v_id, v_username, v_start_date_y, v_start_date_m, v_start_date_d, v_end_date_y, v_end_date_m, v_end_date_d, v_complete_percentage, v_dependency;
            EXIT WHEN c%NOTFOUND;


            v_username  := REPLACE(REPLACE(REGEXP_REPLACE(v_username, '([/\|"])', '\\\1', 1, 0), chr(9), '\t'), chr(10), '\n') ;

            if v_id is null then

                json_comp := 
                            '{'                
                          || '"id":"1",'
                          || '"username":"No Assignment",'
                          || '"start_date_y":"2020",'
                          || '"start_date_m":"0",'
                          || '"start_date_d":"1",'
                          || '"end_date_y":"2020",'
                          || '"end_date_m":"0",'
                          || '"end_date_d":"2",'
                          || '"complete_percentage":"0",'
                          || '"dependency":"null"'
                          || '}';


            else

                if cnt = 1 then
                    v_dependency := 'null';
                end if;

                 json_comp := 
                            '{'                
                          || '"id":"' || v_id || '",'
                      --    || '"id":"' || v_username || '",'
                          || '"username":"' || v_username || '",'
                          || '"start_date_y":"' || v_start_date_y || '",'
                          || '"start_date_m":"' || v_start_date_m || '",'
                          || '"start_date_d":"' || v_start_date_d || '",'
                          || '"end_date_y":"' || v_end_date_y || '",'
                          || '"end_date_m":"' || v_end_date_m || '",'
                          || '"end_date_d":"' || v_end_date_d || '",'
                          || '"complete_percentage":"' || v_complete_percentage || '",'
                          || '"dependency":"' || v_dependency || '"'
                          || '}';

                end if;

                if  cnt = 1 then

                    json_all := json_comp;

                else

                    json_all := json_all || ',' || json_comp;

                end if;

        end loop;
        close c;

        v_retval := '[' || json_all || ']';


            DBMS_OUTPUT.PUT_LINE(v_retval);

        htp.p(v_retval);


        return;


    end outputGanttJSON;


-----------------------------------------------
-- preset_user_favorites
------------------------------------------------           
    procedure preset_user_favorites
    is
        cnt int;
    begin

        null;

        select count(*) into cnt from AF_USER_FAVORITES where upper( username ) = upper( v('CURRENT_USERNAME') );

        if cnt = 0 then

            insert into AF_USER_FAVORITES
                select v('CURRENT_USERNAME') username, unit_code, "SEQ_AF_USER_FAVORITES_ID".nextval
                    from 
                    (
                        select unit_code from af_section_unit_mapping
                        inner join af_unit
                        on af_section_unit_mapping.unit_code = af_unit.code
                        where section_code in
                            (
                                select a.section_code 
                                  from af_section_unit_mapping a
                                  inner join AF_unit b
                                  on a.unit_code = b.code
                                  inner join ( select * from users where upper( username ) = upper( v( 'CURRENT_USERNAME' ) ) ) users
                                  on upper( users.unit ) = upper( b.business_name ) 
                            )
                        and af_unit.active = 'Y'
                        
                        union 
                            
                        select code
                        from AF_unit b
                        inner join ( select * from users where upper( username ) = upper( v('CURRENT_USERNAME') ) ) users
                        on upper( users.unit ) = upper( b.business_name )
                    )    
                    ;


        end if;

    exception
        when others then
           null;

    end preset_user_favorites;


-----------------------------------------------
-- build_unit_code
------------------------------------------------         
    function build_unit_code return varchar2
    is
        newcode varchar2(1000);
    begin

        select "SEQ_AF_UNIT_ID".nextval into newcode from sys.dual; 
        return newcode;

    end build_unit_code;



END AF_ASSIGNMENT_PCK;