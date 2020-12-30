create or replace PACKAGE BODY AF_APP_CONFIG_PCK AS

-----------------------------------
-- function getControlParamValue
-----------------------------------

    function getControlParamValue( p_param_name varchar2 ) 
    return varchar2
    is
        v_ret varchar2(1000);
    begin
    
        select param_value into v_ret from af_app_control_params where upper( param_name ) = upper( p_param_name );
        return v_ret;
        
    exception
        when no_data_found then
            return 'no_data_found';
            
    end getControlParamValue;
    
    
------------------------------------
-- function getFlexibleSeetingValue
------------------------------------

    function getFlexibleSeetingValue( 
    p_key_1          varchar2,
    p_key_2          varchar2,
    p_setting_option varchar2 
  ) return varchar2
  is
        v_ret varchar2(1000);
    begin
    
        select 
            case when upper( p_setting_option ) = 'SETTING_1'
                then SETTING_1
                 when upper( p_setting_option ) = 'SETTING_2'
                then SETTING_2
                else null
            end
        into v_ret 
          from af_flexible_settings 
          where upper( key_1 ) = upper( p_key_1 )
          and upper( key_2 ) = upper( p_key_2 );
          
        return v_ret;
        
    exception
        when no_data_found then
            return 'no_data_found';
            
    end getFlexibleSeetingValue;
    
END AF_APP_CONFIG_PCK;