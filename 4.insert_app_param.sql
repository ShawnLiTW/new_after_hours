--------------------------------------------------------
--  File created - Monday-December-21-2020   
--------------------------------------------------------
REM INSERTING into AF_APP_CONTROL_PARAMS
SET DEFINE OFF;
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (121,null,null,null);
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (122,'favorites','My favorites','Display on desktop mode');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (123,'section_mobile','S','Title on page 200 when press "My Sections" column link on page 100 to enter it');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (124,'division_mobile','D','Title on page 200 when press "My Divisions" column link on page 100 to enter it');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (22,'app_tester_mail','xli5@toronto.ca','If system in test mode, which is defined by variable: app_in_test_mode, then all emails will be auto-routed to these test emails, no email will be sent to real receiver');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (24,'page_100_anim_def','0%   {background-color:white; left:200px; top:0px;}
 100% {background-color:white; left:0px; top:0px;}',null);
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (29,'page_300_anim_def','0%   {background-color:white; left:200px; top:0px;}
 100% {background-color:white; left:0px; top:0px;}',null);
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (30,'page_300_anim_timer','1.0',null);
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (1,'favorites_mobile','F','Title on page 200 when press "My Favorites" column link on page 100 to enter it');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (2,'section','My section','Display on desktop mode');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (3,'division','My division','Display on desktop mode');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (4,'all','All on-call units','Title on page 200 when press "All units on call" menu link under admin on left side menu to enter it');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (61,'show_mysection','Y','Enable or disable "My Section" column on page 100');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (62,'show_mydivision','Y','Enable or disable "My Division" column on page 100');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (63,'notif_email_added_cc','wsun@toronto.ca,xli5@toronto.ca','Every notification email will auto-Cc these emails as well');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (81,'show_division_name_colomn','N','determine if division column displayed on page 200');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (23,'app_enable_email','Y','If "N", there will be no email sent');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (27,'page_200_anim_def','0%   {background-color:white; left:200px; top:0px;}
 100% {background-color:white; left:0px; top:0px;}',null);
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (28,'page_200_anim_timer','1.0',null);
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (41,'af_schedulejob_timecontrol_var','15','[ number of minutes ] This is used in package procedure [ AF_ASSIGNMENT_PCK.update_assignment_tbl ] to control how many minutes ahead of next assignment is active, the scheduled job will be fired and second email will be sent. The format of the value will be like [ 2/24/60 ],in this example it means 10 minutes ahead of the new assignment is activated. If the value is ''prohibit'', then disable the scheduled job.');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (82,'show_section_name_colomn','Y','determine if section column displayed on page 200');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (21,'app_in_test_mode','Y','If "Y", then system email will be sent to those defined in variable: app_tester_mail');
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (26,'page_100_anim_timer','1.0',null);
Insert into AF_APP_CONTROL_PARAMS (ID,PARAM_NAME,PARAM_VALUE,DESCRIPTION) values (141,'af_schedule_job_package_selection','2','1 - select [ dbms_job ], otherwise select [ DBMS_SCHEDULER ]');

commit;