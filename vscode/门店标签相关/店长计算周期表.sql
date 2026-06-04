--data_build.dwd_store_construction_manager_base_info_vi_di
with staff_manager as
(
select
 t1.hps_dept_code_lv5 as store_code
        ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
        ,t1.name
        ,t1.hps_d_hr_status
        ,t1.hps_d_jobcode
        ,if(if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = if(length(t7.manager_code)=6,concat('10',t7.manager_code),t7.manager_code),1,0) as is_store_manager
        ,t3.protect_tag
        ,t4.store_name
        ,t4.city_name
        ,coalesce(t4.difficulty_level_new,t5.difficulty_level_new,t6.difficulty_level_new) as difficulty_level_new
        
        from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
        left join data_shop.dwa_shop_store_structure_condition_di t2 on t1.hps_dept_code_lv5 = t2.store_code and t2.dt = '${today-1}'  --最新dt 营业中门店，不包含撤店及加盟门店
        left join data_shop.dm_shop_staff_protect_tag_v2 t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.staff_code and t3.dt = '${today-1}'  --最新dt
        left join data_build.dwd_store_construction_store_groups_recruit_gap t4 on t1.hps_dept_code_lv5 = t4.store_code and t4.dt = '${today-1}'  --最新dt
        left join data_build.dwd_store_construction_store_groups_recruit_gap t5 on t1.hps_dept_code_lv5 = t5.store_code and t5.dt ='${today-2}'  --最新dt
        left join data_build.dwd_store_construction_store_groups_recruit_gap t6 on t1.hps_dept_code_lv5 = t6.store_code and t6.dt ='${today-3}'  --最新dt
        left join data_build.pdw_opc_shop_ehr_staff_dept_view t7 on t2.store_code = t7.dept_code 
         -- and if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = if(length(t7.manager_code)=6,concat('10',t7.manager_code),t7.manager_code) 
          and t7.dt ='${today-1}'  --最新dt，更准确的店长code
   
    where t1.dt=  '${today-1}' --最新dt
    and t1.hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and t1.hps_d_hr_status = '在职'
),
location_type_list as (
select 
t2.store_code
,max(case when location_type in ('办公+其他','写字楼','办公+居民','居民+办公') then '办公' 
when location_type in ('居民+其他','居民+其它','住宅') then '居民' 
when location_type = '混合' then '其他'
else location_type end) as location_type
from default.dm_site_selection_project_feature_info_di t2 

where t2.dt <= '20221114'
group by t2.store_code
),
staff_list as
(
select
     t1.dt
     ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
     ,hps_dept_code_lv5 as store_code
     ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
     ,hps_d_hr_status
     ,hps_d_jobcode
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    where t1.dt >= '${today-30}' 
    and t1.dt <= '${today-1}' 
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and hps_d_hr_status = '在职'
),
staff_list_v2 as -- 用于计算周期
(
select
     t1.dt
     ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
     ,hps_dept_code_lv5 as store_code
     ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
     ,hps_d_hr_status
     ,hps_d_jobcode
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    where t1.dt <= '${today-1}' 
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and hps_d_hr_status = '在职'
),
staff_list_v3 as -- 用于计算sop
(
select
     t1.dt
     ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
     ,hps_dept_code_lv5 as store_code
     ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
     ,hps_d_hr_status
     ,hps_d_jobcode
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    where t1.dt >= '${today-30}' 
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and hps_d_hr_status = '在职'
),

-- 入职日期
entry_date_list as (
    select 
    staff_code
    ,max(entry_date) as entry_date
    from data_shop.dm_shop_staff_protect_tag_v2
    where dt <= '${today-1}' 
    group by staff_code
),
-- 成为店长时间
b_manager0 as (
    select 
    dt 
    ,from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
    ,dept_code as store_code
    ,if(length(t1.manager_code)=6,concat('10',t1.manager_code),t1.manager_code) as current_manager_code
    from data_build.pdw_opc_shop_ehr_staff_dept_view t1
    where dt <= '${today-1}' 
),
b_manager1 as (
    select 
    t1.employee_id
    ,min(t2.new_dt) as b_manager_date
    from staff_manager t1 
    left join b_manager0 t2 on t1.employee_id = t2.current_manager_code
 --   left join entry_date_list t3 on t1.employee_id = t3.staff_code
   -- left join base_manager_info t4 on t1.employee_id = t4.employee_id
    where t1.is_store_manager = 1
    group by  t1.employee_id
),
min_manager as (
    select 
    t1.employee_id
    ,b_manager_date
    ,datediff('${TODAY-1}',b_manager_date) as b_manager_days 
    from b_manager1 t1 
),
-- 成为本店架构负责人日期

store_change_base_211 as (
    select 
 flow_name 
 ,order_id 
 ,order_status 
 ,create_time 
 ,update_time
 ,taskorder_handler 
 -- ,taskorder_fromhandler
 ,max(case when form_name='shopCode' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) as store_code 
 ,max(case when form_name='shopName' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) as store_name 
 ,max(case when form_name='toUser' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) as user_info
 -- ,max(case when form_name='fromUser' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) as user_info0
-- ,max(case when taskorder_node_id = 'toUserHandleTask' then taskorder_handler else 0 end) as user_code
 from ( 
 select 
 t1.flow_ame as flow_name 
 ,t1.order_id
 ,t1.order_status 
 ,t1.parent_order_id 
 ,t1.driver_flow_id 
 ,t1.create_time 
 ,t1.update_time
 ,t1.org_name 
 ,t1.initiator_code 
 ,t2.form_name 
 ,t2.form_values 
 ,t2.index 
 ,t2.seq 
 ,t3.taskorder_node_id
 ,t3.taskorder_handler[0] as taskorder_handler
--  ,t4.taskorder_node_id as taskorder_node_id_fromuser
--  ,t4.taskorder_handler[0] as taskorder_fromhandler
 -- ,case when t3.taskorder_node_id = 'toUserHandleTask' then t3.taskorder_handler[0] else null end as handler --接店人
 ,row_number() over (partition by t1.order_id,t2.form_name,t2.index,t2.seq order by t2.dt desc) as rm 
 from default.pdw_order_store_211_order_detail_flow_main t1 
 left join default.pdw_order_store_211_order_detail_flow_form_variable_groups_di t2 
 on t1.order_id = t2.order_id and t2.dt >= '20220901' --di表取流程起始时间 
left join default.pdw_order_store_211_order_detail_flow_task_taskorders t3
on t1.order_id = t3.order_id and t3.dt = '${today-1}' and t3.taskorder_node_id = 'toUserHandleTask'
-- left join default.pdw_order_store_211_order_detail_flow_task_taskorders t4
-- on t1.order_id = t4.order_id and t4.dt = '${today-1}' and t4.taskorder_node_id = 'fromUserHandleTask'
 where t1.dt = '${today-1}' --最近分区 
 and t1.flow_code = '017269' 
 and t1.order_status  ='FINISHED'
 and to_date(t1.update_time) <= '${TODAY-1}'
 and to_date(t1.update_time) >= '${TODAY-90}'
)  t1 
 where rm = 1 
-- and taskorder_node_id = 'toUserHandleTask'
 group by flow_name 
 ,order_id 
 ,order_status 
 ,create_time
 ,update_time
 ,taskorder_handler 
 -- ,taskorder_fromhandler
 ),
store_change_date_211 as (
    select 
    lpad(taskorder_handler,8,'10') as employee_id
    ,t0.store_code 
    ,max(date_format(update_time,'yyyyMMdd')) as change_dt
    ,max(to_date(update_time)) as change_date
    from staff_manager t0
    left join store_change_base_211 t1 on t0.store_code = t1.store_code and t0.employee_id = lpad(t1.taskorder_handler,8,'10')
    group by lpad(taskorder_handler,8,'10') 
    ,t0.store_code 
),
store_change_date_sheet as (
    select 
    t1.employee_id
    ,t1.store_code
    ,min(t3.dt) as change_dt
    ,min(t3.new_dt) as change_date
    from staff_manager t1
    left join b_manager0 t3 on t1.employee_id = t3.current_manager_code and t1.store_code = t3.store_code
    group by t1.employee_id
    ,t1.store_code
),
store_change_date_union as (
    select 
    employee_id
    ,store_code 
    ,change_dt
    ,from_unixtime(unix_timestamp(change_date,'yyyyMMdd'),'yyyy-MM-dd') as change_date
    from store_change_date_211

    union 

    select 
    employee_id
    ,store_code 
    ,change_dt
    ,change_date
    from store_change_date_sheet
   
),
store_change_date as (
    select 
    employee_id
    ,store_code 
    ,max(change_dt) as change_dt
    ,max(change_date) as change_date
    ,case when max(change_date) <= date_sub('${TODAY-30}',14) then 1 else 0 end as is_14
    ,case when max(change_date) <= date_sub('${TODAY-30}',7) and max(change_date) > date_sub('${TODAY-30}',14) then 1 else 0 end as is_7
    ,case when max(change_date) <= '${TODAY-30}' and max(change_date) >= date_sub('${TODAY-30}',7) then 1 else 0 end as is_30
    from store_change_date_union
    group by employee_id
    ,store_code 
)

    select distinct
    t0.store_code
    ,t0.employee_id
    ,t0.name
    ,t0.store_name
    ,t0.city_name
    ,t0.difficulty_level_new
    ,t2.entry_date as entry_dt
    ,from_unixtime(unix_timestamp(t2.entry_date,'yyyyMMdd'),'yyyy-MM-dd') as entry_date
    ,if(datediff('${TODAY-1}',from_unixtime(unix_timestamp(t2.entry_date,'yyyyMMdd'),'yyyy-MM-dd')) >=30,30,datediff('${TODAY-1}',from_unixtime(unix_timestamp(t2.entry_date,'yyyyMMdd'),'yyyy-MM-dd'))) as entry_days
    ,t1.change_date as change_date0
    ,case when is_14 = 1 or is_7 = 1 or is_30 = 1 then '30' 
    when is_14 = 0 and is_7 = 0 and is_30 = 0 then if(datediff('${TODAY-1}',t1.change_date) <0,0,datediff('${TODAY-1}',t1.change_date)) 
    else 0 end as cal_days_0 -- t30无豁免
    ,case when is_14 = 1 or is_7 = 1 or is_30 = 1 then '${TODAY-30}'
    when is_14 = 0 and is_7 = 0 and is_30 = 0 then t1.change_date end as change_date
    
    ,case when is_14 = 1 or is_7 = 1  then '30' 
    when is_30 = 1 then if(datediff('${TODAY-1}',date_add(t1.change_date,7)) <0,0,datediff('${TODAY-1}',date_add(t1.change_date,7))) 
    when is_14 = 0 and is_7 = 0 and is_30 = 0 then if(datediff('${TODAY-1}',date_add(t1.change_date,7)) <0,0,datediff('${TODAY-1}',date_add(t1.change_date,7))) 
    else 0 end as cal_days --t30豁免7天
    ,case when is_14 = 1 or is_7 = 1  then '${TODAY-30}'
    when is_30 = 1 then date_add(t1.change_date,7)
    when is_14 = 0 and is_7 = 0 and is_30 = 0 then date_add(t1.change_date,7) end as start_cdate --t30豁免7天

    ,case when is_14 = 1 then '30'
    when is_14 = 0 then if(datediff('${TODAY-1}',date_add(t1.change_date,14)) <0,0,datediff('${TODAY-1}',date_add(t1.change_date,14))) 
    else 0 end as cal_dyas_14 -- t30豁免14天
    ,case when is_14 = 1 then '${TODAY-30}'
    when is_14 = 0 then date_add(t1.change_date,14) end as change_date_14 -- t30豁免14天
    ,t3.b_manager_date
    ,t3.b_manager_days

    from staff_manager t0
    left join store_change_date t1 on t0.employee_id = t1.employee_id
    left join entry_date_list t2 on t0.employee_id = t2.staff_code
    left join min_manager t3 on t0.employee_id = t3.employee_id
    where is_store_manager = 1