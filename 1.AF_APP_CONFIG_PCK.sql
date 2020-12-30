create or replace PACKAGE AF_APP_CONFIG_PCK AS 

  function getControlParamValue( 
    p_param_name varchar2 
   ) return varchar2;
  
  function getFlexibleSeetingValue( 
    p_key_1          varchar2,
    p_key_2          varchar2,
    p_setting_option varchar2 
  ) return varchar2;

END AF_APP_CONFIG_PCK;