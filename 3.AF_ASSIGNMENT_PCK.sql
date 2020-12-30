create or replace package AF_ASSIGNMENT_PCK
is


    CRLF VARCHAR2( 2 ):= CHR( 13 ) || CHR( 10 );


    -- This controls if emails will be sent to tester, or to real people
    -- In procedure send_useremail(), if PCK_TEST_MODE = 'Y',
    -- the real email receiver will be PCK_TEST_USER_EMAIL

    PCK_TEST_MODE          varchar2(10)  := 'Y';
    PCK_TEST_USER_EMAIL    varchar2(200) := 'cms@toronto.ca';
    PCK_APP_ENABLE_EMAIL   varchar2(200) := 'Y';

    
    QRYSTR_GET_ALL_QUALIFY_ONCALLS varchar2(3000) :=
           
            'select trim(FIRST_NAME) || '' '' || trim(LAST_NAME) || '' [ '' || a.username || '' ]'' as d, '
            || 'trim(a.USERNAME) as r '
            || 'from USERS a '
            || 'inner join af_oncall_user_unit_mapping b '
            || 'on a.username = b.username '
            || 'inner join af_unit c '
            || 'on b.unit_code = c.code '
            || 'WHERE trim(a.USERNAME) is not null '
            || 'and upper( b.unit_code ) = v(''APP_CURRENT_UNIT_CODE'') '
            || 'order by 1'
           ;
            
    QRYSTR_GET_ALL_ACTIVE_USERS varchar2(2000) :=

            'select trim(FIRST_NAME) || '' '' || trim(LAST_NAME) || ''[ '' || users.username || ''] '' as d, '
            || 'trim(users.USERNAME) as r '
            || 'from USERS '
            || 'inner join af_oncall_info '
            || 'on users.unit = af_oncall_info.category_name '
            || 'WHERE trim(FIRST_NAME) is not null '
            || 'and trim(LAST_NAME) is not null '
            || 'and trim(users.USERNAME) is not null '           
            || 'and ' 
            || '( instr( upper(title), upper(''Director'') ) > 0 '
            || 'or instr( upper(title), upper(''Supervisor'') ) > 0 '
            || 'or instr( upper(title), upper(''Coordinator'') ) > 0 '
            || 'or instr( upper(title), upper(''Manager'') ) > 0 '
            || 'or instr( upper(title), upper(''Engineer'') ) > 0 '
            || 'or upper(title) is not null '
            || ') '
            || 'and af_oncall_info.active = ''A'' ' 
            || 'order by 1 ';


    QRYSTR_GET_ALL_CURRENT_ONCALLS varchar2(2000) :=

            'select FIRST_NAME || '' '' ||LAST_NAME as d, '
              || 'a.USERNAME as r, '
              || 'a.email '
              || 'from USERS a '
        --      || 'inner join af_oncall_info b '
              || 'inner join table( AF_ASSIGNMENT_PCK.get_all_curr_fu_oncall_table() ) b '
              || 'on a.username = b.pass_onto ' 
       --       || 'on a.username = AF_ASSIGNMENT_PCK.ret_oncall_pass_onto_info( v(''APP_CURRENT_ONCALL_ID''), ''pass_onto'' )  '               
              || 'order by 1 ';


    NO_NEXT_SCHEDULE_TEXT varchar2(100) := '[ Next on-call: not scheduled ]';

    type list_obj is RECORD (
      label  VARCHAR2(50),
      target VARCHAR2(500),
      seq   number
    );
    
    type list_gantt_ibj is RECORD (
      id                    int,
      username              VARCHAR2(100),
      start_date_y          VARCHAR2(4),
      start_date_m          VARCHAR2(2),
      start_date_d          VARCHAR2(2),
      end_date_y            VARCHAR2(4),
      end_date_m            VARCHAR2(2),
      end_date_d            VARCHAR2(2),
      start_date            VARCHAR2(45),
      end_date              VARCHAR2(45),
      complete_percentage   int,
      dependency            VARCHAR2(45)
    );

    type list_gantt_obj_table IS TABLE OF list_gantt_ibj;
    
    function get_gantt_sche_table (
        p_unit_code     varchar2,
        p_check_enddate varchar2
    )
    return list_gantt_obj_table PIPELINED;
    
    type list_obj_table IS TABLE OF list_obj;

    type oncall_obj is RECORD (
      unit_code             af_oncall_schedule.unit_code%TYPE,
      pass_onto             af_oncall_schedule.assignee_username%TYPE,
      pass_effective_time   af_oncall_schedule.effective_datetime%TYPE
    );


    type oncall_obj_table IS TABLE OF oncall_obj;
    
    function get_all_curr_only_oncall_table (
        p_unit_code varchar2 default null,
        p_scope     varchar2 default null              
    )
    return oncall_obj_table PIPELINED;

    function get_email_menu_table (
        p_unit_code varchar2
    )
    return list_obj_table PIPELINED;

    function get_call_menu_table (
        p_unit_code varchar2
    )
    return list_obj_table PIPELINED;

    function get_all_curr_fu_oncall_table
    return oncall_obj_table PIPELINED;
/*

    -- This is to make sure email list triggered
    -- by email button on page 11 only for current on-calls
    function get_all_curr_only_oncall_table (
        p_specific_oncall_id number default null
    )
    return oncall_obj_table PIPELINED;
*/

    function get_all_oncall_cadidates_table
    return list_obj_table PIPELINED;

/*
    -- thio is used in profile image upload page
    -- to get all users whose unit is defined in info
    -- with active status
    function get_all_unit_users_table
    return list_obj_table PIPELINED;

*/
    procedure update_assignment_tbl (
        p_unit_code          varchar2,
        p_pass_onto          varchar2,
        p_mode               varchar2,
        p_specific_datetime  varchar2 default null
    );

    function ret_oncall_pass_onto_info(
        p_unit_code    varchar2,
        p_ret_type     varchar2,
        p_curr_or_future varchar2 default 'C'
    )
    return varchar2;

    function ret_future_oncall_info(
        p_unit_code    varchar2
    )
    return varchar2;

    procedure get_all_current_oncalls (
        p_output_format     varchar2 default 'json',
        p_all_found   out   varchar2 
    );

    procedure get_pair_values_output (
        p_output_format      varchar2 default 'json',
        p_qry_str            varchar2,
        p_output_allstr out  varchar2  
    );

    procedure send_useremail(
        p_sender      varchar2,
        p_recipients  varchar2,
        p_cc          varchar2 DEFAULT null,
        p_bcc         varchar2 DEFAULT 'cms@toronto.ca,lsitu@toronto.ca',     
        p_replyto     varchar2,
        p_subject     varchar2,
        p_message     varchar2,
        P_is_body_html boolean DEFAULT false
      );

    function get_curr_oncall_emails (
        p_unit_code          varchar2 default null,
        p_scope              varchar2 default null,
        p_specific_delimiter varchar2 default null
    ) return varchar2;

    procedure email_for_next_avai_assignment(
        p_specific_unit_code       varchar2 default null,
        p_specific_trans_username  varchar2 default null
    );

    procedure tmp_create_apex_session(
      p_app_id IN apex_applications.application_id%TYPE,
      p_app_user IN apex_workspace_activity_log.apex_user%TYPE,
      p_app_page_id IN apex_application_pages.page_id%TYPE DEFAULT 1
      ); 

    function remove_duplic_in_delimited_str(
        p_in_str            varchar2,
        p_delimited_char    varchar2 DEFAULT ':'
    ) return varchar2;

    function output_all_assgn_in_text_tbl return clob;

    function getDBServerName return varchar2;
  
    function find_unit_current_assig_id (
        p_unit_code varchar2
    )
    return number;
    
    
    function find_unit_future_assig_id (
        p_unit_code varchar2
    )
    return number;
    
    procedure cleanupScheduleTable(
        p_unit_code varchar2
    );
    
    function is_user_in_current_unit (
        p_username       varchar2 default null,
        p_curr_unit_code varchar2 default null
    ) return boolean;
    
    
    procedure outputDivSecUnitHireJSON(
        p_username varchar2 default null
    );
    
    procedure outputGanttJSON(
        p_unit_code varchar2,
        p_num_of_rec_ret int default -1
    );
    
    
    procedure preset_user_favorites;
    
    function build_unit_code return varchar2;

end AF_ASSIGNMENT_PCK;