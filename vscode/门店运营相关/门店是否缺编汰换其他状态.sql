--data_shop.dwa_shop_store_structure_condition_di
with base_info as(
    select distinct
        t1.store_code
        ,t1.store_status_blf
    from data_build.dwd_store_construction_project_status_v2_di t1
         inner join (
 select max(dt) as max_dt
 from data_build.dwd_store_construction_project_status_v2_di
 where dt >='${today-4}'
 and dt <= '${today-1}'
 ) tmp on t1.dt = tmp.max_dt
 where t1.dt >= '${today-4}'
 and t1.dt <= '${today-1}'
        and t1.store_status_blf in ('1正常保留-已开业门店','2正常保留-未开业门店')
)
,jiameng_list as (
select distinct 
store_code
from default.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
select t1.flag_code 
,t1.project_name 
,t1.city_name 
,t1.store_code 
,t1.store_name 
,t1.project_id 
,t1.project_status_updated_time 
from data_build.app_store_construction_project_pipeline_indicators_ha_v1 t1 
where t1.project_status_updated_time > '1990-01-01 00:00:00.0' 
and t1.project_status_group = '状态' 
and t1.dt = '${today-1}'
and t1.hr >=20 
and t1.is_delete = 0 
and t1.business_type = '便利店' 
and substring_index(t1.project_status_name,' ',1) = '10' 
)
,chedian_list as (
select 

store_code

from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)
,base_open_info as (
    SELECT 
        DISTINCT 
        record_date
        ,store_code
        ,CASE WHEN change_reason in ('紧急闭店','门店延期营业') OR urgent_close_reason IS NOT NULL THEN ideal_shop_business_time
            ELSE bach_business_time END AS business_time
    FROM data_shop.dw_ordering_report_store_business_status_da_view
    WHERE dt = '${today-1}' AND store_type = '0'
        AND date_format(record_date,'yyyyMMdd') >= '${today}'
        AND date_format(record_date,'yyyyMMdd') <= '${today+29}'
        and store_code <> '100000319' --科创五街38号店这家僵尸店先暂时单独加到这里处理，直接改逻辑担心影响其它门店
)

,open_info as (
    SELECT
        store_code
        ,SUM(is_current_open) AS is_current_open
        ,SUM(is_future_open) AS is_future_open
    FROM (
        SELECT 
            DISTINCT 
            store_code
            ,1 AS is_current_open
            ,0 AS is_future_open
        FROM base_open_info
        WHERE date_format(record_date,'yyyyMMdd') = '${today}'
            AND business_time <> '全天不营业'
            AND business_time <> ''
        
        UNION ALL

        SELECT 
            DISTINCT 
            store_code
            ,0 AS is_current_open
            ,1 AS is_future_open
        FROM base_open_info
        WHERE date_format(record_date,'yyyyMMdd') > '${today}'
            AND business_time <> '全天不营业'
            AND business_time <> ''
    ) tmp
    group by store_code
)

,structure_info as (
select
        t1.store_code
        ,t1.store_name
        ,t1.store_city
        ,t1.store_manager_no
        ,t3.protect_tag
        ,t2.hps_d_jobcode as position_cn
        ,t2.hps_d_hr_status
        ,case when t2.hps_d_jobcode in ('店经理','门店伙伴','学生PT','店副经理') and t2.hps_dept_descr_lv5 like '%区X%' then 1 else 0 end as is_district_staff
        ,t4.class as manager_class
        ,t4.code as manager_code
    from data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t1
    left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
    on t1.store_manager_no = t2.emplid 
        and t2.dt = '${today-1}' 
        and t1.dt = t2.dt
    left join data_shop.dm_shop_staff_protect_tag_v2 t3
    on IF(LENGTH(store_manager_no)<8,CONCAT('10',store_manager_no),store_manager_no) = t3.staff_code 
        and t3.dt = '${today-1}' 
        and t1.dt = t3.dt
    left join 
    (select
    t1.employee_id
    ,t1.class
    ,t1.code
    ,t1.dt
    from data_build.ods_uploads_manager_tag_4 t1
    inner join 
    (select
    max(dt) as dt
    from data_build.ods_uploads_manager_tag_4
    where dt > 20170101
    ) tmp
    on t1.dt = tmp.dt
    ) t4 
      on IF(LENGTH(store_manager_no)<8,CONCAT('10',store_manager_no),store_manager_no) = t4.employee_id
    where t1.dt='${today-1}'
        -- and t1.store_type = 0
        -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
)

,status_info as (
    select 
        distinct 
        emplid
        ,1 as is_leave
    from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt = '${today-1}' and hps_d_hr_status = '离职'

)

,handover_info as (
    select 
        t1.order_id
        ,t1.order_status
        ,t1.create_time
        ,t1.city_name
        ,t1.hand_over_store_code
        ,t1.hand_over_staff_code
        ,t1.hand_over_staff_name
        -- ,t1.final_take_over_store_code  as take_over_dept_code
        -- ,t1.final_take_over_staff_code  as take_over_staff_code
        -- ,t1.final_take_over_staff_name  as take_over_staff_name
        -- ,t1.final_take_over_position    as take_over_position
        ,case when t1.tmp_take_over_staff_code <> t1.hand_over_staff_code and t1.final_take_over_staff_code <> t1.hand_over_staff_code
            then coalesce(t1.final_take_over_store_code,t1.tmp_take_over_dept_code)    
        end as take_over_dept_code
        ,case when t1.tmp_take_over_staff_code <> t1.hand_over_staff_code and t1.final_take_over_staff_code <> t1.hand_over_staff_code
            then coalesce(t1.final_take_over_staff_code,t1.tmp_take_over_staff_code)   
        end as take_over_staff_code
        ,case when t1.tmp_take_over_staff_code <> t1.hand_over_staff_code and t1.final_take_over_staff_code <> t1.hand_over_staff_code
            then coalesce(t1.final_take_over_staff_name,t1.tmp_take_over_staff_name)   
        end as take_over_staff_name
        ,case when t1.tmp_take_over_staff_code <> t1.hand_over_staff_code and t1.final_take_over_staff_code <> t1.hand_over_staff_code
            then coalesce(t1.final_take_over_position,t1.tmp_take_over_position)   
        end as take_over_position
    from data_shop.dwd_shop_manager_handover_flow_di t1
    where t1.dt = '${today-1}'
        and t1.order_status in ('handling','waitHandle')
)

,leave_info as ( --离职流程中
    select distinct
        t1.man_code as user_job_number
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = '${today-1}'
        and (t1.order_status = 'PROCESSING')
            or (date_format(final_leave_date,'yyyyMMdd') > '${today}' and final_leave = 'leave' and t1.order_status = 'FINISHED')
)

,course_info as (
    select 
        staff_code
        ,case 
            when (manager_practice_result='通过' or manager_theory_result='通过' or manager_learn_result='通过')
                and (date_format(manager_practice_check_time,'yyyyMMdd') <= '${today-1}' 
                    or date_format(manager_theory_check_time,'yyyyMMdd') <= '${today-1}' 
                    or date_format(manager_learn_check_time,'yyyyMMdd') <= '${today-1}')
                then 'A'
            when date_format(task_10_9_past_date,'yyyyMMdd') <= '${today-1}' then 'A'
            when (advanced_practice_result='通过' or advanced_learn_result='通过') 
                and (date_format(advanced_practice_check_time,'yyyyMMdd') <= '${today-1}'
                    or date_format(advanced_theory_check_time,'yyyyMMdd') <= '${today-1}' 
                    or date_format(advanced_learn_check_time,'yyyyMMdd') <= '${today-1}' )
                then 'B'
            when date_format(task_10_8_past_date,'yyyyMMdd') <= '${today-1}' then 'B'
            when (primary_theory_result='通过' or primary_learn_result='通过') 
                and (date_format(primary_theory_result_check_time,'yyyyMMdd') <= '${today-1}'
                    or date_format(primary_learn_check_time,'yyyyMMdd') <= '${today-1}')
                then 'C'
            when date_format(task_10_3_past_date,'yyyyMMdd') <= '${today-1}' then 'C'
        else 'D' end as learn_tag
    from data_shop.dwa_shop_train_stage_state_v1 t1
    inner join (
      select max(dt) as dt 
      from data_shop.dwa_shop_train_stage_state_v1 
      where dt >='${today-2}' and dt <= '${today-1}') t0 --数据降级
    on t1.dt = t0.dt
    where t1.dt >= '${today-2}'
)

,give_behave_info_p7 as (
    select 
        tmp.staff_code
        ,7-sum(tmp.is_available_roster) as p7_unavailable_days
    from (
        select 
            distinct
            t1.staff_code
            ,t1.target_date
            ,case when staff_code = '10611242' then t1.is_valid_give else t1.is_available_roster end as is_available_roster --于广友工号10611242，因为离职后修正了在职状态(2110166594920927)导致一直识别离职，给班不可用
            --，在此改为使用他的实际给班状态
        from data_shop.dm_roster_staff_available_di_view t1
        where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
            and date_format(t1.target_date,'yyyyMMdd') >= '${today-6}'
            and date_format(t1.target_date,'yyyyMMdd') <= '${today}'
    ) tmp
    group by tmp.staff_code
)

,give_behave_info_f14 as (
    select 
        tmp.staff_code
        ,14-sum(tmp.is_available_roster) as f14_unavailable_days
    from (
        select 
            distinct
            t1.staff_code
            ,t1.target_date
            ,case when staff_code = '10611242' then t1.is_valid_give else t1.is_available_roster end as is_available_roster --于广友工号10611242，因为离职后修正了在职状态(2110166594920927)导致一直识别离职，给班不可用
            --，在此改为使用他的实际给班状态
        from data_shop.dm_roster_staff_available_di_view t1
        where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
            and date_format(t1.target_date,'yyyyMMdd') >= '${today+1}'
            and date_format(t1.target_date,'yyyyMMdd') <= '${today+14}'
    ) tmp
    group by tmp.staff_code
)

,give_behave_info_f14_a_after_spring as (
    select 
        tmp.staff_code
        ,sum(tmp.is_available_roster) as f14_available_days_after_spring
    from (
        select 
            distinct
            t1.staff_code
            ,t1.target_date
            ,case when staff_code = '10611242' then t1.is_valid_give else t1.is_available_roster end as is_available_roster --于广友工号10611242，因为离职后修正了在职状态(2110166594920927)导致一直识别离职，给班不可用
            --，在此改为使用他的实际给班状态
        from data_shop.dm_roster_staff_available_di_view t1
        where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
            and date_format(t1.target_date,'yyyyMMdd') >= '20230130'
            and date_format(t1.target_date,'yyyyMMdd') <= '20230212'
    ) tmp
    group by tmp.staff_code
)

,give_behave_info_f14_a as (
    select 
        tmp.staff_code
        ,sum(tmp.is_available_roster) as f14_available_days
    from (
        select 
            distinct
            t1.staff_code
            ,t1.target_date
            ,case when staff_code = '10611242' then t1.is_valid_give else t1.is_available_roster end as is_available_roster --于广友工号10611242，因为离职后修正了在职状态(2110166594920927)导致一直识别离职，给班不可用
            --，在此改为使用他的实际给班状态
        from data_shop.dm_roster_staff_available_di_view t1
        where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
            and date_format(t1.target_date,'yyyyMMdd') >= '${today+1}'
            and date_format(t1.target_date,'yyyyMMdd') <= '${today+14}'
    ) tmp
    group by tmp.staff_code
)

,give_behave_info_f7_a as (
    select 
        tmp.staff_code
        ,sum(tmp.is_available_roster) as f7_available_days
    from (
        select 
            distinct
            t1.staff_code
            ,t1.target_date
            ,case when staff_code = '10611242' then t1.is_valid_give else t1.is_available_roster end as is_available_roster --于广友工号10611242，因为离职后修正了在职状态(2110166594920927)导致一直识别离职，给班不可用
            --，在此改为使用他的实际给班状态
        from data_shop.dm_roster_staff_available_di_view t1
        where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
            and date_format(t1.target_date,'yyyyMMdd') >= '${today+1}'
            and date_format(t1.target_date,'yyyyMMdd') <= '${today+7}'
    ) tmp
    group by tmp.staff_code
)

,actual_attend as (
    select 
        t1.employee_no
        ,sum(coalesce(work_shift_hours,0)) as work_shift_hours_t7
        ,sum(coalesce(attendance_work_hours,0)) as attendance_work_hours_t7
    from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
        and date_format(t1.work_shift_date,'yyyyMMdd') >= '${today-7}'
        and date_format(t1.work_shift_date,'yyyyMMdd') <= '${today-1}'
    group by t1.employee_no
)

,store_mgr_level_info as (
    select
        distinct 
        t1.employee_id as staff_code
        ,t1.name as staff_name
        ,case t1.code
            when '0' then 'A1'
            when '1' then 'A2'
            when '2' then 'A3'
            when '3' then 'A4'
            when '4' then 'A5'
            when '5' then 'A6'
        end as store_mgr_level
        --,date_format(t1.create_time,'yyyy-MM-dd') as valid_date
    from data_build.ods_uploads_manager_tag_4 t1
    
    where t1.dt = 20230515 
      
)

--店经理降职对应保护标签
--每周店长标签，周维度
,manager_tag_week as(
select 
employee_id
,class as protect_tag
,code
,dt
from data_build.ods_uploads_manager_tag_4 
where dt >= date_format(date_sub(next_day(current_date(),'mon'),70),'yyyyMMdd') --最近10周
)

--店长降职明细
--门店降职流程
,order_flow_main as(
select
order_id --流程编码(流程信息)
,order_status --流程状态(流程信息)
,initiator_code --发起人编码(流程信息)
,create_time --流程发起时间(流程信息)
,flow_ame --流程名称(流程信息)
,org_code --门店编码(流程信息)
,org_name --门店名称(流程信息)
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '032134' --流程code
),

order_flow_groups as(
select
order_id
,max(typeofdemote) as typeofdemote --申请降职类型
,max(shopCode) as shopCode --value门店编码
,max(shopName) as shopName --label门店名称
,max(whentoendstart) as whentoendstart --降职的开始时间
,max(whentoend) as whentoend --降职的结束时间
,max(agent) as agent --降职期间是否已找好代理店经理
,max(agentwho) as agentwho --降职期间代理店经理
,max(des) as des --降职原因
from(
select --主表单信息
order_id --流程编码
,case when form_name = 'typeofdemote' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as typeofdemote --申请降职类型
,case when form_name = 'shopCode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as shopCode --value门店编码
,case when form_name = 'shopCode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as shopName --label门店名称
,case when form_name = 'whentoendstart' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as whentoendstart --降职的开始时间
,case when form_name = 'whentoend' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as whentoend --降职的结束时间
,case when form_name = 'agent' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as agent --降职期间是否已找好代理店经理
,case when form_name = 'agentwho' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as agentwho --降职期间代理店经理
,case when form_name = 'des' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as des --降职原因
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = '${today-1}'
--and order_id = '2110156450344230'
) a
group by
order_id
),

order_flow_taskorders as(
select
order_id
,max(middleground_manage_label) as middleground_manage_label
,max(middleground_mobile) as middleground_mobile
,max(middleground_temporary_manage_label) as middleground_temporary_manage_label
,max(middleground_protect) as middleground_protect
,max(middleground_shifouquebian) as middleground_shifouquebian
,max(middleground_ontinme) as middleground_ontinme
,max(middleground_give) as middleground_give
,max(middleground_return_protect) as middleground_return_protect
,max(commissar_blocked) as commissar_blocked
from(
select
order_id
,taskorder_node_id
,element
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'Storeownertag' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_manage_label--中台审核条件(店经理降职前标签)
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'protect9' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_mobile--中台审核条件(是否需要机动队挂店)
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'agenttag' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_temporary_manage_label--中台审核条件(代理店经理当前标签)
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'protect' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_protect--中台审核条件(是否符合降职保护条件)
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'shifouquebian' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_shifouquebian--中台审核条件(是否需要加入店长缺编清单)

,case when taskorder_node_id = 'UserTask_0xiz2zo' and get_json_object(element,'$.name') = 'backtostore' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_ontinme--中台确认返岗(原店经理是否在降职结束时间如期返岗)
,case when taskorder_node_id = 'UserTask_0xiz2zo' and get_json_object(element,'$.name') = 'backtostore2' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_give--中台确认返岗(原店经理是否在降职结束时间次周给班5天及以上)
,case when taskorder_node_id = 'UserTask_0xiz2zo' and get_json_object(element,'$.name') = 'result' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_return_protect--中台确认返岗(标签保护是否生效)

,case when taskorder_node_id = 'UserTask_12fej7c' and get_json_object(element,'$.name') = 'blocked' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as commissar_blocked --政委确认加入晋升黑名单
from(
select
order_id
,taskorder_node_id
,task_orders
,row_number() over(partition by concat(order_id,taskorder_node_id) order by taskorder_create_time desc) as rn
from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
where dt = '${today-1}'
--and order_id = '2110156450344230'
and taskorder_result = 'AGREE'
and taskorder_status = 'FINISHED'
and (taskorder_node_id = 'UserTask_1tbwabs' or taskorder_node_id = 'UserTask_0xiz2zo' or taskorder_node_id = 'UserTask_12fej7c')
) a
lateral view
explode(split(regexp_replace(regexp_replace(task_orders, '\\\\[|\\\\]' , ''), '\\\\}\\\\,\\\\{' , '\\\\}\\\\&\\\\{'), '&')) x1 as element
where rn = 1
) b
group by
order_id
)

,demotion_final_list as(
select distinct
IF(LENGTH(a.initiator_code)<8,concat('10',a.initiator_code),a.initiator_code) as staff_code
,b.shopCode
from order_flow_main a
left join order_flow_groups b on a.order_id = b.order_id
left join order_flow_taskorders c on a.order_id = c.order_id
--where c.middleground_shifouquebian = '需要加入缺编清单'
where c.middleground_mobile = '是' --0808调整加入缺编的字段
and a.order_status not in ('SUSPEND')
)

select distinct
    t0.store_code
    ,t1.is_current_open
    ,t1.is_future_open
    ,t2.store_name
    ,t2.store_city
    ,t2.store_manager_no as current_manager_code
    ,t2.position_cn as current_manager_position
    ,t2.hps_d_hr_status as current_manager_status
    ,t2.protect_tag as current_manager_protect_tag
    ,t3.hand_over_staff_code as out_staff_code_1
    ,t3.take_over_staff_code as in_staff_code
    ,t3.take_over_position as in_staff_position
    ,t4.take_over_staff_code as out_staff_code_2
    ,t5.is_leaving as current_manager_is_leaving
    ,coalesce(t9.is_leave,t6.is_leaving) as in_staff_is_leaving
    ,case when t7.learn_tag in ('A','B') then 1 else 0 end as current_manager_is_ab
    ,case when t8.learn_tag in ('A','B') then 1 else 0 end as in_staff_is_ab
    ,t10.p7_unavailable_days
    ,t11.f14_unavailable_days
    ,t12.reward_level
    ,case when (t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1) and t18.staff_code is not null and t18.store_name = '汰换' then '3.1' --0904待汰换的机动队优先出现在缺编表
        when t18.staff_code is not null and t18.store_name = '汰换' and datediff(nvl(t5.leave_date,'2145-01-01'),'${TODAY-1}') > '7' then '0.1' --命中汰换和离职，离职日期7天内优先按照离职标签计算
        when t2.manager_class = '须努力' and datediff(nvl(t5.leave_date,'2145-01-01'),'${TODAY-1}') > '7' then '0.1'
        when t2.manager_class = '须努力' then '3.03' --命中标签差和离职，离职日期7天内优先按照离职标签计算
        --when t18.staff_code is not null and t18.store_name = '汰换' then '0.2'
        when t21.shopcode is not null then '3.01'
        when t2.protect_tag = '应离职' then '3.02'
        when t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1 then '3.1'
        when t5.is_leaving = '1' or t2.hps_d_hr_status = '离职' then '3.2'
        when t14.f14_available_days <= '1' then '3.3'
        when t17.store_mgr_level = 'A6' then '3.4'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then '1.1'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '1.2' 
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then '2.1'
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '2.2' 
    end as structure_status
    ,t13.work_shift_hours_t7
    ,t13.attendance_work_hours_t7
    ,t0.store_status_blf
    ,t14.f14_available_days
    ,case when (t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1) and t18.staff_code is not null and t18.store_name = '汰换' then '战区经理/机动队员' --0904待汰换的机动队优先出现在缺编表
        when t18.staff_code is not null and t18.store_name = '汰换' and datediff(nvl(t5.leave_date,'2145-01-01'),'${TODAY-1}') > '7' then '汰换店长' --命中汰换和离职，离职日期7天内优先按照离职标签计算
        when t5.is_leaving = '1' or t2.hps_d_hr_status = '离职' then '离职流程中' --命中须努力和离职的时候，优先展示为离职流程中
        when t2.manager_class = '须努力' then '须努力店长'
        when t2.protect_tag = '应离职' then '应离职店长'
        --when t18.staff_code is not null and t18.store_name = '汰换' then '待汰换店长'
        when t21.shopcode is not null then '降职流程中'
        when t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1 then '战区经理/机动队员'
        when t14.f14_available_days <= '1' then '未来14天可用天数<=1天'
        when t17.store_mgr_level = 'A6' then 'A6店长'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then 'AB店经理'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '非AB店经理' 
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then 'AB非店经理'
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '非AB非店经理' 
    end as structure_status_desc
    ,case when t1.is_current_open = '1' then '1'
        when t1.is_future_open = '1' then '2'
    else '3' end as store_status
    ,case when t1.is_current_open = '1' then '保留且营业'
        when t1.is_future_open = '1' then '保留但未来营业'
    else '保留但未营业' end as store_status_desc

    ,case
        when t3.take_over_position in ('战区经理','高级战区经理','城市总经理','机动组长') then '3.3'
        when coalesce(t9.is_leave,t6.is_leaving) = '1' then '3.2'        
        when t3.take_over_position = '店经理' 
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '1' then '1.1'
        when t3.take_over_position = '店经理'
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '0' then '1.2' 
        when t3.take_over_position <> '店经理'
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '1' then '2.1'
        when t3.take_over_position <> '店经理'
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '0' then '2.2' 
    end as future_structure_status
    ,case 
        when t3.take_over_position in ('战区经理','高级战区经理','城市总经理','机动组长') then '战区经理'
        when coalesce(t9.is_leave,t6.is_leaving) = '1' then '离职流程中'
        when t3.take_over_position = '店经理' 
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '1' then 'AB店经理'
        when t3.take_over_position = '店经理'
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '0' then '非AB店经理' 
        when t3.take_over_position <> '店经理'
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '1' then 'AB非店经理'
        when t3.take_over_position <> '店经理'
            and (case when t8.learn_tag in ('A','B') then 1 else 0 end) = '0' then '非AB非店经理' 
    end as future_structure_status_desc
    ,t15.f7_available_days
    ,case when (t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1) and t18.staff_code is not null and t18.store_name = '汰换' then '3.1' --0904待汰换的机动队优先出现在缺编表
        when t18.staff_code is not null and t18.store_name = '汰换' and datediff(nvl(t5.leave_date,'2145-01-01'),'${TODAY-1}') > '7' then '0.1' --命中汰换和离职，离职日期7天内优先按照离职标签计算
        when t2.manager_class = '须努力' or t2.protect_tag = '应离职' and datediff(nvl(t5.leave_date,'2145-01-01'),'${TODAY-1}') > '7' then '0.1'
        when t2.manager_class = '须努力' or t2.protect_tag = '应离职' then '3.03'
        --when t18.staff_code is not null and t18.store_name = '汰换' then '0.2'
        when t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1 then '3.1'
        when t5.is_leaving = '1' or t2.hps_d_hr_status = '离职' then '3.2'
        when t15.f7_available_days = '0' then '3.3'
        when t17.store_mgr_level = 'A6' then '3.4'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then '1.1'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '1.2' 
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then '2.1'
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '2.2' 
    end as structure_status_pre_warn
    ,case when (t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1) and t18.staff_code is not null and t18.store_name = '汰换' then '战区经理/机动队员' --0904待汰换的机动队优先出现在缺编表
        when t18.staff_code is not null and t18.store_name = '汰换' and datediff(nvl(t5.leave_date,'2145-01-01'),'${TODAY-1}') > '7' then '汰换店长' --命中汰换和离职，离职日期7天内优先按照离职标签计算
        when t2.manager_class = '须努力' then '须努力店长'
        when t2.protect_tag = '应离职' then '应离职店长'
        --when t18.staff_code is not null and t18.store_name = '汰换' then '待汰换店长'
        when t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1 then '战区经理/机动队员'
        when t5.is_leaving = '1' or t2.hps_d_hr_status = '离职' then '离职流程中'
        when t15.f7_available_days = '0' then '未来7天可用天数0天'
        when t17.store_mgr_level = 'A6' then 'A6店长'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then 'AB店经理'
        when t2.position_cn = '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '非AB店经理' 
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '1' then 'AB非店经理'
        when t2.position_cn <> '店经理' and t2.hps_d_hr_status = '在职' 
            and (case when t7.learn_tag in ('A','B') then 1 else 0 end) = '0' then '非AB非店经理' 
    end as structure_status_pre_warn_desc
    ,case when t1.is_current_open = '1' and (t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1 or t2.hps_d_hr_status = '离职') then '1.1'
        when t1.is_current_open = '1' and t5.is_leaving = '1' then '1.1'
        when t1.is_current_open = '1' and t14.f14_available_days <= '1' then '1.2'
        when t1.is_future_open = '1' and (t2.position_cn in ('战区经理','高级战区经理','城市总经理','机动组长') or t2.is_district_staff =1 or t2.hps_d_hr_status = '离职') then '2.1'
        when t1.is_future_open = '1' and t5.is_leaving = '1' then '2.1'
        when t1.is_future_open = '1' and t14.f14_available_days <= '1' then '2.2'
    else null end as solve_priority
    ,case when t16.f14_available_days_after_spring <= 1 or t16.f14_available_days_after_spring is null then '春节后两周可用<=1' 
        else '春节后两周可用>1' end as special_mark
from base_info t0
left join open_info t1
on t0.store_code = t1.store_code
left join structure_info t2
on t0.store_code = t2.store_code
left join handover_info t3
on t0.store_code = t3.hand_over_store_code
left join handover_info t4
on t0.store_code = t4.take_over_dept_code
left join leave_info t5
on t2.store_manager_no = t5.user_job_number
left join leave_info t6
on t3.take_over_staff_code = t6.user_job_number
left join course_info t7
on t2.store_manager_no = t7.staff_code
left join course_info t8
on t3.take_over_staff_code = t8.staff_code
left join status_info t9
on t3.take_over_staff_code = t9.emplid
left join give_behave_info_p7 t10
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t10.staff_code
left join give_behave_info_f14 t11
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t11.staff_code
left join data_build.dwd_store_construction_store_groups_recruit_gap t12
on t12.dt = '${today-1}' and t1.store_code = t12.store_code
left join actual_attend t13
on t2.store_manager_no = t13.employee_no
left join give_behave_info_f14_a t14
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t14.staff_code
left join give_behave_info_f7_a t15
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t15.staff_code
left join give_behave_info_f14_a_after_spring t16
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t16.staff_code
-- where t1.is_future_open = 1
left join store_mgr_level_info t17
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t17.staff_code
left join data_shop.ods_uploads_eliminate_manager t18
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t18.staff_code and t0.store_code = t18.store_code
left join jiameng_list t19 on t0.store_code = t19.store_code
left join chedian_list t20 on t0.store_code=t20.store_code
left join demotion_final_list t21 on t0.store_code = t21.shopcode and if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t21.staff_code
  where t19.store_code is null -- 剔除加盟店
      and t20.store_code is null -- 剔除撤店

***********************************************************************************************************************************************************************
--缺编看板
--report_excel_quebian_dianzhang_to_chat
--把current_date换成'${today-1}'格式
with base_info as (
 select 
 t1.*
 ,row_number() over(partition by t1.store_code order by t1.dt desc) rn
 from data_smartorder.dm_copy_app_shop_structure_lack_details_di_view t1
 where dt >= '${today-3}'
)

,finished_info as (
 select
 t1.*
 ,case 
 when t0.current_manager_code is not null and t0.current_manager_code <> t1.store_mgr_code then '退出缺编-换架构' 
 when t0.store_status = 3 then '退出缺编-退出监控' else '退出缺编-同架构' end as change_tag
 from base_info t1
 left join data_smartorder.dm_copy_dwa_shop_store_structure_condition_di_view
 t0
 on t0.dt = '${today-1}' and t1.store_code = t0.store_code
 where t1.rn = 1 and t1.dt = '${today-2}'
)

,lack_list as (
select 
 t1.valid_date as `缺编日期`
 ,t1.store_code as `门店编号`
 ,t1.store_name as `门店名称`
 ,t1.city_name as `城市`
 ,t1.store_level as `重点门店`
 ,t1.store_mgr_code as `架构店长工号`
 ,t1.store_mgr_name as `架构店长姓名`
 ,t1.city_mgr_code as `城市总工号`
 ,t1.city_mgr_name as `城市总姓名`
 ,t1.structure_status_desc as `缺编类型`
 ,t1.is_active_leaving as `是否主动提离职`
 ,t1.leaving_order_status as `离职流程状态`
 ,t1.leaving_apply_date as `主动发起离职日期`
 ,t1.leaving_last_date as `lastday日期`
 ,coalesce(t4.class,t3.protect_tag) as `店长开工表现`
 ,t1.f14_valid_give_days as `未来14天有效给班天数`
 ,t1.f14_black_list_days as `未来14天黑名单天数`
 ,t1.t30_lack_days as `近30天连续缺编天数`
 ,case when t1.store_code = '110000059' and t1.store_mgr_code = '11134704' then if(t1.t30_lack_days = 1,'新增-三期员工','保持-三期员工')
 when t1.t30_lack_days = 1 then '新增' else '保持' end as `当前状态`
 ,t1.difficulty_level as `门店难度等级`
 ,t1.is_sal_tough_store as `是否薪资困难店`
 ,t1.has_social_insur as `是否有社保`
 ,t1.store_difficulty_desc as `门店难度`
 ,t1.store_capacity_desc as `门店人力情况`
 ,t1.store_op_quality as `门店质量`
 ,t1.store_status_level as `门店综合等级`
 ,t1.special_mark as `特殊备注`
 ,t0.store_status_desc as `门店营业状态`
from data_smartorder.dm_copy_app_shop_structure_lack_details_di_view t1
left join data_smartorder.dm_copy_dwa_shop_store_structure_condition_di_view t0 on t0.dt = '${today-1}' and t1.store_code = t0.store_code
left join data_smartorder.dm_copy_dm_shop_staff_protect_tag_v2_view t3 on t1.store_mgr_code = t3.staff_code and t3.dt = '${today-1}'
left join data_smartorder.dm_copy_ods_uploads_manager_tag_4_view t4 on t1.store_mgr_code = t4.employee_id and from_unixtime(unix_timestamp(t4.dt,'yyyyMMdd'),'yyyy-MM-dd') = CASE 
 WHEN dayofweek('${TODAY}') IN (2, 3) THEN -- 如果今天是周一或周二
 date_sub('${TODAY}', dayofweek('${TODAY}') + 5) -- 输出上周一的日期
 ELSE 
 CASE 
 WHEN dayofweek('${TODAY}') = 1 THEN date_sub('${TODAY}', 6) -- 如果今天是周日
 ELSE date_sub('${TODAY}', dayofweek('${TODAY}') - 2) -- 其他情况（周三到周六）
 END
 end

where t1.dt = '${today-1}'
and t1.store_code <> '100000238'
)
,finish_list as (
select 
 t1.valid_date as `缺编日期`
 ,t1.store_code as `门店编号`
 ,t1.store_name as `门店名称`
 ,t1.city_name as `城市`
 ,t1.store_level as `重点门店`
 ,t1.store_mgr_code as `架构店长工号`
 ,t1.store_mgr_name as `架构店长姓名`
 ,t1.city_mgr_code as `城市总工号`
 ,t1.city_mgr_name as `城市总姓名`
 ,t1.structure_status_desc as `缺编类型`
 ,t1.is_active_leaving as `是否主动提离职`
 ,t1.leaving_order_status as `离职流程状态`
 ,t1.leaving_apply_date as `主动发起离职日期`
 ,t1.leaving_last_date as `lastday日期`
 ,coalesce(t4.class,t3.protect_tag) as `店长开工表现`
 ,t1.f14_valid_give_days as `未来14天有效给班天数`
 ,t1.f14_black_list_days as `未来14天黑名单天数`
 ,t1.t30_lack_days as `近30天连续缺编天数`
 ,change_tag as `当前状态`
 ,t1.difficulty_level as `门店难度等级`
 ,t1.is_sal_tough_store as `是否薪资困难店`
 ,t1.has_social_insur as `是否有社保`
 ,t1.store_difficulty_desc as `门店难度`
 ,t1.store_capacity_desc as `门店人力情况`
 ,t1.store_op_quality as `门店质量`
 ,t1.store_status_level as `门店综合等级`
 ,t1.special_mark as `特殊备注`
 ,t0.store_status_desc as `门店营业状态`
from finished_info t1
left join data_smartorder.dm_copy_dwa_shop_store_structure_condition_di_view t0
on t0.dt = '${today-1}' and t1.store_code = t0.store_code
left join data_smartorder.dm_copy_dm_shop_staff_protect_tag_v2_view t3 on t1.store_mgr_code = t3.staff_code and t3.dt = '${today-1}'
left join data_smartorder.dm_copy_ods_uploads_manager_tag_4_view t4 on t1.store_mgr_code = t4.employee_id and from_unixtime(unix_timestamp(t4.dt,'yyyyMMdd'),'yyyy-MM-dd') = CASE 
 WHEN dayofweek('${TODAY}') IN (2, 3) THEN -- 如果今天是周一或周二
 date_sub('${TODAY}', dayofweek('${TODAY}') + 5) -- 输出上周一的日期
 ELSE 
 CASE 
 WHEN dayofweek('${TODAY}') = 1 THEN date_sub('${TODAY}', 6) -- 如果今天是周日
 ELSE date_sub('${TODAY}', dayofweek('${TODAY}') - 2) -- 其他情况（周三到周六）
 END
 end
where t1.store_code<> '100000238'
)


select * from finish_list
union all
select * from lack_list

********************************************************************************************************************************************************************************************
--汰换看板
with base_info as (
    select distinct
        date_add(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),1) as valid_date
        ,store_code
        ,current_manager_code
        ,t1.structure_status
    from data_shop.dwa_shop_store_structure_condition_di t1
    where dt = '${today-1}'
        AND t1.structure_status = '0.1'
)

,t30_info as (
    select distinct
        date_add(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),1) as valid_date
        ,store_code
        ,current_manager_code
        ,t1.structure_status
    from data_shop.dwa_shop_store_structure_condition_di t1
    where dt >= '${today-30}' and dt < '${today-1}'
        AND t1.structure_status = '0.1' 
)

,cum_prep as (
        SELECT 
            t1.store_code
            ,t1.current_manager_code
            ,t1.valid_date
            ,t2.valid_date as valid_date_t30
            ,datediff(t1.valid_date,t2.valid_date) as diff_days
            ,row_number()over(partition by t1.store_code order by t2.valid_date desc) as rn
        FROM base_info t1
        left join t30_info t2
        on t1.store_code = t2.store_code 
            and t1.structure_status = t2.structure_status 
            and t1.current_manager_code = t2.current_manager_code
)

,cum_days as (
    SELECT 
        store_code
        ,current_manager_code
        ,count(distinct valid_date_t30) + 1 as cum_days
    FROM cum_prep
    where diff_days = rn
    group by store_code
        ,current_manager_code
)


select 
    t2.emplid
    ,t2.name
    ,t4.store_code
    ,t4.store_name
    ,t3.bz_mgr_code
    ,t3.bz_mgr_name
    ,t3.zone_mgr_code
    ,t3.zone_mgr_name
    ,t3.city_zone_mgr_code
    ,t3.city_zone_mgr_name
    ,split(t2.hps_hrbp_idnames,'-')[0] as hr_code
    ,split(t2.hps_hrbp_idnames,'-')[1] as hr_name
    ,t5.cum_days
from data_shop.dm_shop_staff_protect_tag_v2 t1
left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
on t2.dt = '${today-1}' and t1.staff_code = IF(LENGTH(t2.emplid)<8,concat('10',t2.emplid),t2.emplid)
    and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
    and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员','店副经理', '社会PT', '学生PT', '见习店经理')
left join data_shop.dwd_shop_store_jiagou_di t3
on t3.dt = '${today-1}' and t1.store_code = t3.store_code
inner join data_shop.dwa_shop_store_structure_condition_di t4
on t2.emplid = t4.current_manager_code
    and t4.dt = '${today-1}' 
left join cum_days t5
on t2.emplid = t5.current_manager_code and t4.store_code = t5.store_code
where t1.dt = '${today-1}' 
    and t4.structure_status = '0.1'

================================================================================================================================================================================
--app_shop_structure_lack_details_di
#
# --------------------------------------
# DATE: 2022-12-15
# TABLE: data_shop.app_shop_structure_lack_details_di
# DEV:  hanzhi.cao
# DESC: 门店-人周维度给排出和惩处聚合数据
# --------------------------------------


###参数设置：日期参数，表名，唯一键
source ${ETC}/format_date.cnf
TABLE_NAME="data_shop.app_shop_structure_lack_details_di"
UNIQ_KEY="valid_date,store_code"

###JOB入口函数：计算，校验
function app_shop_structure_lack_details_di_run {
     calculate
}


##计算模块
function calculate {
$HIVE << EOF

${HIVE_SETTINGS};


with apply_leave as (
    select distinct
        t1.man_code as user_job_number
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
        ,leave_way
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = '${DATE}'
        -- and leave_way = 1
        and (t1.order_status = 'PROCESSING'
            or (date_format(final_leave_date,'yyyyMMdd') >= '${DATE_SUB13DAY}' and final_leave = 'leave' and t1.order_status = 'FINISHED'))
)

,apply_leave_times as (
    select
        t1.man_code as user_job_number
        ,COUNT(DISTINCT order_num) as active_leave_times
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = '${DATE}'
        and leave_way = 1
        and date_format(create_time,'yyyyMMdd') > '${DATE_SUB60DAY}'
    group by t1.man_code
)

,behave_info_f14 as (
    select 
        tmp.staff_code
        ,sum(tmp.is_available_roster)               as f14_available_days
        ,sum(tmp.is_give_roster)                    as give_roster
        ,sum(tmp.is_valid_give)                     as valid_give
        ,sum(tmp.is_in_black_list)                  as in_black_list
        ,sum(tmp.is_health_cer_right)               as health_cer_right
        ,sum(tmp.is_dimission_apply_available)      as dimission_apply_available
        ,sum(tmp.is_vacation)                       as vacation
    from (
        select 
            distinct
            t1.staff_code
            ,t1.target_date
            ,t1.is_available_roster
            ,is_give_roster
            ,is_valid_give
            ,is_in_black_list
            ,is_health_cer_right
            ,is_dimission_apply_available
            ,is_vacation
        from data_shop.dm_roster_staff_available_di_view t1
        where t1.dt = '${DATE}'
            and date_format(t1.target_date,'yyyyMMdd') >= '${DATE_ADD2DAY}'
            and date_format(t1.target_date,'yyyyMMdd') <= '${DATE_ADD15DAY}'
    ) tmp
    group by tmp.staff_code
)

,base_info as (
    select distinct
        date_add(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),1) as valid_date
        ,store_code
        ,'3' as structure_status
    from data_shop.dwa_shop_store_structure_condition_di t1
    where dt = '${DATE}'
        AND t1.store_status < 3
        AND t1.structure_status >= 3
)

,t30_info as (
    select distinct
        date_add(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),1) as valid_date
        ,store_code
        ,'3' as structure_status
    from data_shop.dwa_shop_store_structure_condition_di t1
    where dt > '${DATE_SUB30DAY}' and dt < '${DATE}'
        AND t1.store_status < 3
        AND t1.structure_status >= 3
)

,cum_prep as (
        SELECT 
            t1.store_code
            ,t1.valid_date
            ,t2.valid_date as valid_date_t30
            ,datediff(t1.valid_date,t2.valid_date) as diff_days
            ,row_number()over(partition by t1.store_code order by t2.valid_date desc) as rn
        FROM base_info t1
        left join t30_info t2
        on t1.store_code = t2.store_code and t1.structure_status = t2.structure_status
)

,cum_days as (
    SELECT 
        store_code
        ,count(distinct valid_date_t30) + 1 as cum_days
    FROM cum_prep
    where diff_days = rn
    group by store_code
)

,reserve_info as (
    select 
        store_code
        ,count(distinct staff_code) as reserve_cnts
    from data_shop.app_shop_staff_reserve_manager_da
    where dt = '${DATE_SUB1DAY}'
        and reserve_manager_level in ('第1梯队','第2梯队','第3梯队')
    group by store_code
)

,base_distance_info as (
    select
        a_store_code,
        b_store_code
    from data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view a 
    where dt = '${DATE}' and distince <= 5000
)

,reserve_info_5km as (
    select 
        a_store_code as store_code
        ,sum(reserve_cnts) as reserve_cnts_5km
    from (
        select 
            a_store_code
            ,b_store_code
            ,coalesce(t2.reserve_cnts,0) as reserve_cnts
        from base_distance_info t1
        left join reserve_info t2
        on t1.b_store_code = t2.store_code
    ) tmp
    group by a_store_code
)

,store_mgr_level_info as (
    select
        distinct 
        t2.staff_code
        ,t2.staff_name
        ,case t2.final_judge
            when '一级' then 'A1'
            when '二级' then 'A2'
            when '三级' then 'A3'
            when '四级' then 'A4'
            when '五级' then 'A5'
            when '六级' then 'A6'
        end as store_mgr_level
        ,date_format(t1.create_time,'yyyy-MM-dd') as valid_date
    from data_shop.pdw_shop_carplay_datax_shop_data_snapshot_view t1
    lateral view json_tuple(data,'store_mgr_name','staff_code','final_judge') t2 as 
        staff_name
        ,staff_code
        ,final_judge
    where t1.dt = '${DATE}' 
        and t1.business_key = 'carplay_snapshot_shop_manager_judge_final_di'
        and date_format(t1.create_time,'yyyyMMdd') = '${DATE}'
)

insert overwrite table ${TABLE_NAME} partition(dt='$DATE')

SELECT DISTINCT
    date_add(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),1) as valid_date --`缺编日期`
    ,t1.store_code as store_code  -- `门店编号`
    ,t1.store_name as store_name  --`门店名称`
    ,t1.store_city as city_name  --`城市`
    ,t1.current_manager_code as store_mgr_code  --`架构店长工号`
    ,t2.store_mgr_name as store_mgr_name  --`架构店长姓名`
    ,t2.bz_mgr_code as bz_mgr_code --`战区工号`
    ,t2.bz_mgr_name as bz_mgr_name --`战区姓名`
    ,t2.city_zone_mgr_code as city_mgr_code --`城市总工号`
    ,t2.city_zone_mgr_name as city_mgr_name --`城市总姓名`
    ,t9.store_level --as `重点门店`
    ,t10.store_mgr_level --as `店长评价等级`
    ,t1.structure_status_desc as structure_status_desc --`缺编类型`
    -- ,t1.solve_priority as `解决优先级`
    ,case when leave_way = 1 then t3.is_leaving else 0 end as is_active_leaving --`是否主动提离职`
    ,t3.order_status as leaving_order_status --`离职流程状态`
    ,t3.create_date as leaving_apply_date --`主动发起离职日期`
    ,t3.leave_date as leaving_last_date --`lastday日期`
    ,t4.active_leave_times as t60_active_apply_times --`近60天内主动提交离职次数`
    ,case when t1.current_manager_protect_tag in ('应保护','金牌') then '金牌'
        when t1.current_manager_protect_tag in ('普通','银牌') then '银牌'
        when t1.current_manager_protect_tag='待观察' then '新人'
        when t1.current_manager_protect_tag in ('末位普通','须努力') then '普通'
        when t1.current_manager_protect_tag in ('应离职','不合格') then '观察期' end as protect_tag --`金银牌`
    ,round(t5.punish_rate_per_100_hour,2) as punish_rate_per_100_hour --`百工时违规`
    ,substr(t6.priority_level,1,3) as store_priority_level --`门店Q等级`
    ,t7.f14_available_days as f14_available_days --`未来14天可用天数`
    ,t7.give_roster as f14_give_hours --`未来14天给班小时`
    ,t7.valid_give as f14_valid_give_days --`未来14天有效给班天数`
    ,t7.in_black_list as f14_black_list_days --`未来14天黑名单天数`
    ,t7.health_cer_right as f14_health_cer_invalid_days --`未来14天健康证到期天数`
    ,t7.dimission_apply_available as f14_dimision_affect_hours --`未来14天离职流程影响小时数`
    ,t7.vacation as f14_vac_hours --`未来14天请假小时数`
    ,coalesce(t8.cum_days,1) as t30_lack_days --`近30天连续缺编天数`
    -- *未来14天的请假类型
    ,t13.difficulty_level   --门店难度等级
    ,case when t14.store_code is not null then '薪资困难店' else '非困难店' end as is_sal_tou_store   --是否薪资困难店
    ,coalesce(t11.reserve_cnts,0) as store_reserve_cnts   --本店储备数量
    ,coalesce(t12.reserve_cnts_5km,0) as store_reserve_cnts_5km   --5km储备数量
    ,case when coalesce(t11.reserve_cnts,0)=0 then '本店缺少储备' else '本店不缺储备' end as store_reserve   --本店储备情况
    ,case when coalesce(t12.reserve_cnts_5km,0)<=5 then '店群缺少储备' else '店群不缺储备' end as store_reserve_5km   --5km储备情况
    ,case when t15.staff_code is not null then '有社保' else '无社保' end as has_social_ins  --11月是否有社保
    
    ,t16.w1_c                                                    as store_difficulty_desc --`门店难度`
    ,t16.w2_c                                                    as store_capacity_desc --`门店人力情况`
    ,t16.w3_c                                                    as store_op_quality --`门店质量`
    ,t16.shop_cat                                                as store_status_level --`门店综合等级`
    ,t1.special_mark --`备注`
FROM data_shop.dwa_shop_store_structure_condition_di t1
LEFT JOIN data_shop.dwd_shop_store_jiagou_di t2
ON t2.dt = '${DATE}' AND t1.store_code = t2.store_code
LEFT JOIN apply_leave t3
ON t1.current_manager_code = t3.user_job_number
LEFT JOIN apply_leave_times t4
ON t1.current_manager_code = t4.user_job_number
LEFT JOIN data_shop.dm_shop_punish_pivot_v1_di t5
ON if(length(t1.current_manager_code)<8,concat('10',t1.current_manager_code),t1.current_manager_code) = t5.staff_code and t5.dt = '${DATE}'
LEFT JOIN data_build.dwd_store_construction_store_groups_recruit_gap t6
ON t1.store_code = t6.store_code and t6.dt = '${DATE_SUB1DAY}'
LEFT JOIN behave_info_f14 t7
ON if(length(t1.current_manager_code)<8,concat('10',t1.current_manager_code),t1.current_manager_code) = t7.staff_code
left join cum_days t8
on t1.store_code = t8.store_code
left join( 
select
*
from(
select
store_code
,store_level
,row_number() over(partition by store_code order by store_level) as rn
from data_shop.ods_uploads_store_level
where dt = '20221214'
) a
where a.rn = 1
) t9 --20240905调整，store_code有重复，取去重后结果
on t1.store_code = t9.store_code
left join store_mgr_level_info t10
on if(length(t1.current_manager_code)<8,concat('10',t1.current_manager_code),t1.current_manager_code) = t10.staff_code
left join reserve_info t11
on t1.store_code = t11.store_code
left join reserve_info_5km t12
on t1.store_code = t12.store_code
left join data_shop.ods_uploads_store_difficulty_level t13
on t1.store_code = t13.store_code
left join data_shop.ods_uploads_sal_tough_store t14
on t1.store_code = t14.store_code
left join data_shop.ods_uploads_has_ssn t15
on if(length(t1.current_manager_code)<8,concat('10',t1.current_manager_code),t1.current_manager_code) = t15.staff_code
left join data_shop.dwd_shop_comprehensive_category_di t16
on t1.store_code = t16.store_code and t16.dt = '${DATE_SUB1DAY}'
WHERE t1.dt = '${DATE}'
    --AND t1.store_status < 3
    AND t1.structure_status >= 3

;

EOF
}

************************************************************************************************************************************************************
------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------
************************************************************************************************************************************************************


--全量保留门店
with base_info as(
 select distinct
 t1.store_code
 ,t1.dt
 from data_build.dwd_store_construction_store_groups_recruit_gap t1
 where t1.dt = '${today-2}'
 -- and t1.store_status_blf in ('1正常保留-已开业门店','2正常保留-未开业门店')
)

--架构关系：门店对应架构负责人
,structure_info as (
 select
 t1.store_code
 ,t1.store_name
 ,t1.store_city
 ,nvl(t2.emplid,0) as store_manager_no
 ,t2.name as store_manager_name -- 店副
 ,t3.protect_tag
 ,t2.hps_d_jobcode as position_cn
 ,t2.hps_d_hr_status
 from data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t1
 left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
 on t1.store_code = t2.hps_dept_code_lv5 
 and t2.dt = '${today-1}' 
 and t1.dt = t2.dt
 and t2.jobcode= 'NB0129'
 and t2.hps_d_hr_status = '在职'
 left join data_shop.dm_shop_staff_protect_tag_v2 t3
 on IF(LENGTH(t2.emplid)<8,CONCAT('10',t2.emplid),t2.emplid) = t3.staff_code
 and t3.dt = '${today-1}' 
 and t1.dt = t3.dt
 where t1.dt='${today-1}'
 -- and t1.store_type = 0
 -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
)

--当前已离职人list
,status_info as (
 select 
 distinct 
 emplid
 ,1 as is_leave
 from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view
 where dt = '${today-1}' and hps_d_hr_status = '离职'
)

--进行中or已确定未来会离职的人
,leave_info as ( --离职流程中
 select distinct
 t1.man_code as user_job_number
 ,t1.order_status
 ,date_format(create_time,'yyyy-MM-dd') as create_date
 ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
 ,'1' as is_leaving
 from data_shop.pdw_gis_workday_dimission_order_view t1
 where t1.dt = '${today-1}'
 and (t1.order_status = 'PROCESSING')
 or (date_format(final_leave_date,'yyyyMMdd') > '${today}' and final_leave = 'leave' and t1.order_status = 'FINISHED')
)
--未来14天可用的天数
,give_behave_info_f14_a as (
 select 
 tmp.staff_code
 ,sum(tmp.is_available_roster) as f14_available_days
 from (
 select 
 distinct
 t1.staff_code
 ,t1.target_date
 ,t1.is_available_roster
 from data_shop.dm_roster_staff_available_di_view t1
 where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and date_format(t1.target_date,'yyyyMMdd') >= '${today+1}'
 and date_format(t1.target_date,'yyyyMMdd') <= '${today+14}'
 ) tmp
 group by tmp.staff_code
)

,fail_night_list as 
(
select 
store_id
,count(distinct work_date) as fail_days 
from (
 select 
 from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,store_id
,work_date
,start_time
,end_time
from data_smartorder.dw_roster_roster_detail_info_ha a 
where dt = '${today-1}'
and hr = '22'
and work_date >= '${Today-14}'
and work_date <= '${Today-1}'
and sale_type <> '全天不营业'
and class_id = 0
and (a.roster_source='失败班表' and a.arrange_class_type IN (1,2))
and end_time -start_time >4
and start_time >= 19
) tt 
group by store_id
)
,staff_list_v2 as
(
select
 t1.dt
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 ,t2.store_code
 ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
 ,hps_d_hr_status
 ,hps_d_jobcode
 from base_info t2
 left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1 on t2.store_code = t1.hps_dept_code_lv5 
 and t1.dt >= '${today-14}' 
 and t1.dt <= '${today-1}' 
 and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理')
 and hps_d_hr_status = '在职'
)
,paiban_base0 as 
(
 select 
 IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) as employee_id
,t0.store_code -- 排班门店
,t1.roster_id
,t1.work_date
,date_sub(next_day(t1.work_date,'mon'),7) roster_week --周
,t1.start_time
,t1.end_time
,(t1.end_time-t1.start_time) as paiban_hours
,t1.roster_source
,max(case when work_date = t2.new_dt then t2.store_code else null end) as hps_dept_code_lv5 -- 当天员工所属门店
-- ,case when t2.protect_tag = '待观察' then 1 else 0 end as is_new_staff
from base_info t0
left join data_build.dw_roster_effect_roster_detail_info_da_view t1 on t0.store_code = t1.store_id 

and t1.dt = '${today-1}' 
and t1.work_date >= '${TODAY-14}'
and t1.work_date <= '${TODAY-1}'
and t1.store_type_desc = '门店'
and t1.class_id in ('0')
and t1.store_type = '0'
and t1.sale_type <> '全天不营业'
and t1.start_time >= 19
left join staff_list_v2 t2 on IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) = t2.employee_id
group by 
IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id)
,t0.store_code -- 排班门店
,t1.roster_id
,t1.work_date
,date_sub(next_day(t1.work_date,'mon'),7) 
,t1.start_time
,t1.end_time
,(t1.end_time-t1.start_time) 
,t1.roster_source
) 
,paiban_base as (
select 
t1.employee_id
,t1.store_code -- 排班门店
,t1.hps_dept_code_lv5
,case when t1.store_code = t1.hps_dept_code_lv5 then 0 else 1 end as is_shift -- 是否由外店员工上班
,roster_id
,t1.work_date
,roster_week --周
,start_time
,end_time
,paiban_hours
,roster_source
from paiban_base0 t1 
)
,night_shift_store as (
select 
 store_code 
 ,count(distinct roster_id) as total_night_shift 
 ,count(distinct case when is_shift = 0 then roster_id else null end) as local_night_shift 
 ,count(distinct case when is_shift = 0 then roster_id else null end)/count(distinct roster_id) as local_night_shift_per
 from paiban_base 
 where roster_source = '成功班表'
 group by store_code
 )
,night_shift_staff_base as (
select 
 employee_id
 ,hps_dept_code_lv5 
 ,count(distinct roster_id) as total_night_shift_staff 
 ,count(distinct case when is_shift = 0 then roster_id else null end) as local_night_shift_staff 
 from paiban_base 
 where roster_source = '成功班表'
 group by employee_id
 ,hps_dept_code_lv5 
 )
,night_shift_staff as (
 select 
 hps_dept_code_lv5 as store_code 
 ,count(distinct case when local_night_shift_staff >= 8 then employee_id else null end) as local_night_staff_cnts
 from night_shift_staff_base
 group by hps_dept_code_lv5
)
,vice_manager_list as( --机动队代店副清单
select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt ='${today-1}'
and delete_ts = 0
and end_date >= '${TODAY-1}'
and relation_type = 'VICE_MANAGER'
and shop_code NOT RLIKE '[\\u4e00-\\u9fff]'
) a
where rn = 1
)

select distinct

 t0.store_code as `门店编号`
 ,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as `缺编日期`
 ,t2.store_name as `门店名称`
 ,t2.store_city as `城市`
 ,t2.store_manager_no as `店副工号`
 ,t2.store_manager_name as `店副姓名`
 ,t2.hps_d_hr_status as current_manager_status
 ,t2.protect_tag as `店副标签`
 ,t5.is_leaving as current_manager_is_leaving
 ,t12.reward_level as `P等级`
 ,t6.bz_mgr_code as `战区工号`
 ,t6.bz_mgr_name as `战区姓名`
 ,t6.city_zone_mgr_code as `城市总工号`
 ,t6.city_zone_mgr_name as `城市总姓名`
 
 --架构是否缺编
 --顺序为汰换,战区,离职,不可用(14天),店员带店，店长带店
 ,case when t2.store_manager_no = '0' then '店副缺编'
 when t5.is_leaving = '1' then '离职流程中'
 when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
 else '店副正常'
 end as `缺编类型`
 ,case when t2.store_manager_no = '0' then '0'
 when t5.is_leaving = '1' then '3.2'
 when t14.f14_available_days <= '1' then '3.3'
 else '1'
 end as `缺编编号`

 ,t14.f14_available_days
 ,t7.fail_days
 ,case when t7.fail_days >0 then 1 else 0 end as is_night_fail
 -- 1. 缺店副，但有稳定夜班人员 （过去2周夜班无失败班次，>80%本店人员上的，有至少1个人出勤本店夜班>=4天/周）
 -- 2. 缺店副，无稳定夜班人员（过去2周夜班无失败班次，>80%本店人员上的，但没有人出勤每周稳定>=4天夜班）
 -- 3. 缺店副，缺夜班人员（过去2周夜班有失败班次/夜班班次有跨店人来上）
 -- 本店夜班是否由本店员工上
,t8.total_night_shift as total_night_shift_2week
,coalesce(t8.local_night_shift_per,0) as `本店夜班比例`
-- 本店是否有稳定夜班
,case when t9.local_night_staff_cnts >= 1 then 1 else 0 end as `是否有稳定夜班`
,case when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) = 0 and t8.local_night_shift_per >= 0.7 and t9.local_night_staff_cnts >= 1 then '缺店副，有稳定夜班人员'
when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) = 0 and t8.local_night_shift_per >= 0.7 and coalesce(t9.local_night_staff_cnts,0) < 1 then '缺店副，无稳定夜班人员'
when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) > 0 then '缺店副，缺夜班人员'
when t2.store_manager_no = '0' and t8.local_night_shift_per < 1 then '缺店副，缺夜班人员'
else null end as `店副缺编类型`
,case when t10.shop_code is not null then '是' else '否' end as `是否机动队代店副`

from base_info t0
left join structure_info t2
on t0.store_code = t2.store_code
left join status_info t3 
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t3.emplid
left join leave_info t5
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t5.user_job_number
left join data_build.dwd_store_construction_store_groups_recruit_gap t12
on t12.dt = '${today-1}' and t0.store_code = t12.store_code
left join give_behave_info_f14_a t14
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t14.staff_code
left join data_shop.dwd_shop_store_jiagou_di t6 
on t6.dt = '${today-1}' and t0.store_code = t6.store_code
left join fail_night_list t7 on t0.store_code = t7.store_id
left join night_shift_store t8 on t0.store_code = t8.store_code
left join night_shift_staff t9 on t0.store_code = t9.store_code
left join vice_manager_list t10 on t0.store_code = t10.shop_code

--------------------------------------------------------------------------------------------------------------------------------------------------------------
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
--------------------------------------------------------------------------------------------------------------------------------------------------------------
--店副缺编报表，蜂利器报表
--全量保留门店
--落结果表
--data_smartorder.dwd_store_vice_manager_condition_da
--data_smartorder.dm_roster_staff_vice_manager_not_available_di
with base_info as(
 select distinct
 t1.store_code
 ,t1.dt
 from data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t1
 where t1.dt = '${today-2}'
 -- and t1.store_status_blf in ('1正常保留-已开业门店','2正常保留-未开业门店')
)

--架构关系：门店对应架构负责人
,structure_info as (
 select
 t1.store_code
 ,t1.store_name
 ,t1.store_city
 ,nvl(t2.emplid,0) as store_manager_no
 ,t2.name as store_manager_name -- 店副
 ,t3.protect_tag
 ,t2.hps_d_jobcode as position_cn
 ,t2.hps_d_hr_status
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 left join data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view t2
 on t1.store_code = t2.hps_dept_code_lv5 
 and t2.dt = '${today-1}' 
 and t1.dt = t2.dt
 and t2.jobcode= 'NB0129'
 and t2.hps_d_hr_status = '在职'
 left join data_smartorder.dm_copy_dm_shop_staff_protect_tag_v2_view t3
 on IF(LENGTH(t2.emplid)<8,CONCAT('10',t2.emplid),t2.emplid) = t3.staff_code
 and t3.dt = '${today-1}' 
 and t1.dt = t3.dt
 where t1.dt='${today-1}'
 -- and t1.store_type = 0
 -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
)

--当前已离职人list
,status_info as (
 select 
 distinct 
 emplid
 ,1 as is_leave
 from data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view
 where dt = '${today-1}' and hps_d_hr_status = '离职'
)

--进行中or已确定未来会离职的人
,leave_info as ( --离职流程中
 select distinct
 t1.man_code as user_job_number
 ,t1.order_status
 ,date_format(create_time,'yyyy-MM-dd') as create_date
 ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
 ,'1' as is_leaving
 from data_smartorder.dm_copy_pdw_gis_workday_dimission_order_view t1
 where t1.dt = '${today-1}'
 and (t1.order_status = 'PROCESSING')
 or (date_format(final_leave_date,'yyyyMMdd') > '${today}' and final_leave = 'leave' and t1.order_status = 'FINISHED')
)
--未来14天可用的天数
,give_behave_info_f14_a as (
 select 
 tmp.staff_code
 ,sum(tmp.is_available_roster) as f14_available_days
 from (
 select 
 distinct
 t1.staff_code
 ,t1.target_date
 ,t1.is_available_roster
 from data_smartorder.dm_roster_staff_available_di t1
 where t1.dt = '${today-1}'
 and date_format(t1.target_date,'yyyyMMdd') >= '${today+1}'
 and date_format(t1.target_date,'yyyyMMdd') <= '${today+14}'
 ) tmp
 group by tmp.staff_code
)

,fail_night_list as 
(
select 
store_id
,count(distinct work_date) as fail_days 
from (
 select 
 from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,store_id
,work_date
,start_time
,end_time
from data_smartorder.dw_roster_roster_detail_info_ha a 
where dt = '${today-1}'
and hr = '22'
and work_date >= date_sub(current_Date,14)
and work_date <= date_sub(current_Date,1)
and sale_type <> '全天不营业'
and class_id = 0
and (a.roster_source='失败班表' and a.arrange_class_type IN (1,2))
and end_time -start_time >4
and start_time >= 19
) tt 
group by store_id
)
,staff_list_v2 as
(
select
 t1.dt
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 ,t2.store_code
 ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
 ,hps_d_hr_status
 ,hps_d_jobcode
 from base_info t2
 left join data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view t1 on t2.store_code = t1.hps_dept_code_lv5 
 and t1.dt >= '${today-14}' 
 and t1.dt <= '${today-1}' 
 and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理')
 and hps_d_hr_status = '在职'
)
,paiban_base0 as 
(
 select 
 IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) as employee_id
,t0.store_code -- 排班门店
,t1.roster_id
,t1.work_date
,date_sub(next_day(t1.work_date,'mon'),7) roster_week --周
,t1.start_time
,t1.end_time
,(t1.end_time-t1.start_time) as paiban_hours
,t1.roster_source
,t1.job --岗位
,max(case when work_date = t2.new_dt then t2.store_code else null end) as hps_dept_code_lv5 -- 当天员工所属门店
-- ,case when t2.protect_tag = '待观察' then 1 else 0 end as is_new_staff
from base_info t0
left join data_smartorder.dw_roster_effect_roster_detail_info_da_view t1 on t0.store_code = t1.store_id 

and t1.dt = '${today-1}' 
and t1.work_date >= '${Today-14}'
and t1.work_date <= '${Today-1}'
and t1.store_type_desc = '门店'
and t1.class_id in ('0')
and t1.store_type = '0'
and t1.sale_type <> '全天不营业'
and t1.start_time >= 19
left join staff_list_v2 t2 on IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) = t2.employee_id
group by 
IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id)
,t0.store_code -- 排班门店
,t1.roster_id
,t1.work_date
,date_sub(next_day(t1.work_date,'mon'),7) 
,t1.start_time
,t1.end_time
,(t1.end_time-t1.start_time) 
,t1.roster_source
,t1.job
) 
,paiban_base as (
select 
t1.employee_id
,t1.store_code -- 排班门店
,t1.hps_dept_code_lv5
,case when t1.store_code = t1.hps_dept_code_lv5 then 0 else 1 end as is_shift -- 是否由外店员工上班
,roster_id
,t1.work_date
,roster_week --周
,start_time
,end_time
,paiban_hours
,roster_source
,job
from paiban_base0 t1 
)
,night_shift_store as (
select 
 store_code 
 ,count(distinct roster_id) as total_night_shift 
 ,count(distinct case when is_shift = 0 then roster_id else null end) as local_night_shift 
 ,count(distinct case when is_shift = 0 then roster_id else null end)/count(distinct roster_id) as local_night_shift_per --本店夜班班次占比
 ,count(distinct case when job not in ('店副经理') and is_shift = 0 then roster_id else null end)/count(distinct case when job not in ('店副经理') then roster_id else null end) as local_without_vice_night_shift_per --非店副经理本店夜班班次占比
 from paiban_base 
 where roster_source = '成功班表'
 group by store_code
 )
,night_shift_staff_base as (
select 
 employee_id
 ,hps_dept_code_lv5 
 ,count(distinct roster_id) as total_night_shift_staff 
 ,count(distinct case when is_shift = 0 then roster_id else null end) as local_night_shift_staff 
 from paiban_base 
 where roster_source = '成功班表'
 group by employee_id
 ,hps_dept_code_lv5 
 )
,night_shift_staff as (
 select 
 hps_dept_code_lv5 as store_code 
 ,count(distinct case when local_night_shift_staff >= 8 then employee_id else null end) as local_night_staff_cnts
 from night_shift_staff_base
 group by hps_dept_code_lv5
)
,vice_manager_list as( --机动队代店副清单
select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt ='${today-1}'
and delete_ts = 0
and end_date >= date_sub(current_Date,1)
and relation_type = 'VICE_MANAGER'
and shop_code NOT RLIKE '[\\u4e00-\\u9fff]'
) a
where rn = 1
)

select distinct

 date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
 ,t0.store_code as store_code
 ,t2.store_name as store_name
 ,t2.store_city as city
 ,t6.bz_mgr_code as bz_mgr_code
 ,t6.bz_mgr_name as bz_mgr_name
 ,t6.city_zone_mgr_code as city_zone_mgr_code
 ,t6.city_zone_mgr_name as city_zone_mgr_name
 
 --架构是否缺编
 --顺序为汰换,战区,离职,不可用(14天),店员带店，店长带店
 ,case when t2.store_manager_no = '0' then '店副缺编'
 when t5.is_leaving = '1' then '离职流程中'
 when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
 else '店副正常'
 end as type
,t12.reward_level as reward_level
,case when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) = 0 and t8.local_night_shift_per >= 0.7 and t9.local_night_staff_cnts >= 1 then '缺店副，有稳定夜班人员'
when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) = 0 and t8.local_night_shift_per >= 0.7 and coalesce(t9.local_night_staff_cnts,0) < 1 then '缺店副，无稳定夜班人员'
when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) > 0 then '缺店副，缺夜班人员'
when t2.store_manager_no = '0' and t8.local_night_shift_per < 1 then '缺店副，缺夜班人员'
when t5.is_leaving = '1' and coalesce(local_without_vice_night_shift_per,0) >= 0.7 then '缺店副，有稳定夜班人员'
when t5.is_leaving = '1' and coalesce(local_without_vice_night_shift_per,0) < 0.7 then '缺店副，无稳定夜班人员'
else null end as vice_manager_type
,case when t10.shop_code is not null then '是' else '否' end as is_district_vice_manager
,case t11.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district

from base_info t0
left join structure_info t2
on t0.store_code = t2.store_code
left join status_info t3 
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t3.emplid
left join leave_info t5
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t5.user_job_number
left join data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t12
on t12.dt = '${today-1}' and t0.store_code = t12.store_code
left join give_behave_info_f14_a t14
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t14.staff_code
left join data_smartorder.dm_copy_dwd_shop_store_jiagou_di_view t6 
on t6.dt = '${today-1}' and t0.store_code = t6.store_code
left join fail_night_list t7 on t0.store_code = t7.store_id
left join night_shift_store t8 on t0.store_code = t8.store_code
left join night_shift_staff t9 on t0.store_code = t9.store_code
left join vice_manager_list t10 on t0.store_code = t10.shop_code
left join data_smartorder.ods_uploads_business_district_qiyang t11 on t0.store_code = t11.store_code
where t12.reward_level <> '' and case when t2.store_manager_no = '0' then '店副缺编'
 when t5.is_leaving = '1' then '离职流程中'
 when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
 else '店副正常'
 end <> '店副正常'











--店副缺编报表，蜂利器报表
--全量保留门店
--落结果表
--data_smartorder.dwd_store_vice_manager_condition_da
with base_info as(
 select distinct
 t1.store_code
 ,t1.dt
 from data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t1
 where t1.dt >= 20251101
 -- and t1.store_status_blf in ('1正常保留-已开业门店','2正常保留-未开业门店')
)

--架构关系：门店对应架构负责人
,structure_info as (
 select
 t1.dt
 ,t1.store_code
 ,t1.store_name
 ,t1.store_city
 ,nvl(t2.emplid,0) as store_manager_no
 ,t2.name as store_manager_name -- 店副
 ,t3.protect_tag
 ,t2.hps_d_jobcode as position_cn
 ,t2.hps_d_hr_status
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 left join data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view t2
 on t1.store_code = t2.hps_dept_code_lv5 
 and t2.dt >= '20251101' 
 and t1.dt = t2.dt
 and t2.jobcode= 'NB0129'
 and t2.hps_d_hr_status = '在职'
 left join data_smartorder.dm_copy_dm_shop_staff_protect_tag_v2_view t3
 on IF(LENGTH(t2.emplid)<8,CONCAT('10',t2.emplid),t2.emplid) = t3.staff_code
 and t3.dt >= '20251101' 
 and t1.dt = t3.dt
 where t1.dt>='20251101'
 -- and t1.store_type = 0
 -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
)

--进行中or已确定未来会离职的人
,leave_info as ( --离职流程中
 select distinct
 t1.dt
 ,t1.man_code as user_job_number
 ,t1.order_status
 ,date_format(create_time,'yyyy-MM-dd') as create_date
 ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
 ,'1' as is_leaving
 from data_smartorder.dm_copy_pdw_gis_workday_dimission_order_view t1
 where t1.dt >= '20251101'
 and (t1.order_status = 'PROCESSING')
 or (final_leave_date > date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) and final_leave = 'leave' and t1.order_status = 'FINISHED')
)
--未来14天可用的天数
,give_behave_info_f14_a as (
 select 
 dt
 ,tmp.staff_code
 ,sum(tmp.is_available_roster) as f14_available_days
 from (
 select 
 distinct
 t1.dt
 ,t1.staff_code
 ,t1.target_date
 ,t1.is_available_roster
 from data_smartorder.dm_roster_staff_available_di t1
 where t1.dt >= '20251101'
 and t1.target_date >= date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),2)
 and t1.target_date <= date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),15)
 ) tmp
 group by dt,tmp.staff_code
)

,vice_manager_list as( --机动队代店副清单
select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by concat(dt,employee_no) order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt >='20251101'
and delete_ts = 0
and end_date >= from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd')
and relation_type = 'VICE_MANAGER'
and shop_code NOT RLIKE '[\\u4e00-\\u9fff]'
) a
where rn = 1
)

,dwd_store_vice_manager_condition_da as(
select distinct

  t0.dt
 ,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
 ,t0.store_code as store_code
 ,t2.store_name as store_name
 ,t2.store_city as city
 
 --架构是否缺编
 --顺序为汰换,战区,离职,不可用(14天),店员带店，店长带店
 ,case when t2.store_manager_no = '0' then '店副缺编'
 when t5.is_leaving = '1' then '离职流程中'
 when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
 else '店副正常'
 end as type
,t12.reward_level as reward_level
,case when t10.shop_code is not null then '是' else '否' end as is_district_vice_manager

from base_info t0
left join structure_info t2
on t0.store_code = t2.store_code and t0.dt = t2.dt
left join leave_info t5
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t5.user_job_number and t0.dt = t5.dt
left join data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t12
on t12.dt = t0.dt and t0.store_code = t12.store_code and t12.dt >= 20251101
left join give_behave_info_f14_a t14
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t14.staff_code and t0.dt = t14.dt
left join vice_manager_list t10 on t0.store_code = t10.shop_code and t0.dt = t10.dt
where t12.reward_level <> '' and case when t2.store_manager_no = '0' then '店副缺编'
when t5.is_leaving = '1' then '离职流程中'
when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
else '店副正常'
end <> '店副正常')
 
 SELECT
from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')
,case when t1.city_name is null then '天津' else t1.city_name end as city_name
,t1.store_code
,t1.store_name
,case when t2.is_district_vice_manager = '是' then '机动队挂店副'
when t2.is_district_vice_manager = '否' then '缺店副'
else '有店副' end as vice_manager_type
,case when t3.store_code is not null then '店长缺编' else '有店长' end as manager_type
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join dwd_store_vice_manager_condition_da t2 on t1.store_code = t2.store_code and t1.dt = t2.dt
LEFT JOIN data_shop.app_shop_structure_lack_details_di t3 on t1.store_code = t3.store_code and t1.dt = t3.dt
where t1.dt >= 20251101







 SELECT
from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')
,case when t1.city_name is null then '天津' else t1.city_name end as city_name
,t1.store_code
,t1.store_name
,case when t2.is_district_vice_manager = '是' then '机动队挂店副'
when t2.is_district_vice_manager = '否' then '缺店副'
else '有店副' end as vice_manager_type
,case when t3.store_code is not null then '店长缺编' else '有店长' end as manager_type
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join data_smartorder.dwd_store_vice_manager_condition_da t2 on t1.store_code = t2.store_code and t1.dt = t2.dt
LEFT JOIN data_shop.app_shop_structure_lack_details_di t3 on t1.store_code = t3.store_code and t1.dt = t3.dt
where t1.dt >= 20251101





--hr=`echo $time_hour| awk '{split($0, a, "/"); print a[4]}'`
--editdt=`echo $time_hour| awk '{split($0, a, "/"); print a[1]"-"a[2]"-"a[3]}'`
--emdt=$(date -d "-30 day ${editdt}" "+%Y-%m-%d")

--dt=$(date -d "-0 day ${editdt}" "+%Y%m%d")
--dt_add1day=$(date -d "1 day ${editdt}" "+%Y%m%d")
--sdt=$(date -d "-180 day ${editdt}" "+%Y%m%d")


--/usr/apache/hive/bin/hive -e"

set mapred.reduce.tasks = 250;
set hive.merge.mapfiles = false;
set mapred.max.split.size = 10000000;

--drop table data_smartorder.dm_ordering_warehouse_base_sku_data_di


-- CREATE EXTERNAL TABLE `data_smartorder.dm_roster_staff_vice_manager_not_available_di`(
--   `store_code` string, 
--   `record_date` date, 
--   `store_name` string, 
--   `store_city` string, 
--   `store_manager_no` string, 
--   `store_manager_name` string, 
--   `hps_d_hr_status` string, 
--   `protect_tag` string, 
--   `is_leaving` string, 
--   `reward_level` string, 
--   `bz_mgr_code` string, 
--   `bz_mgr_name` string, 
--   `city_zone_mgr_code` string, 
--   `city_zone_mgr_name` string, 
--   `empty_org_type` string, 
--   `empty_org_no` string, 
--   `f14_available_days` double, 
--   `fail_days` bigint, 
--   `is_night_fail` int, 
--   `total_night_shift_2week` bigint, 
--   `local_night_ratio` double, 
--   `local_night_staff_cnts` bigint, 
--   `is_stable_night` int, 
--   `empty_vice_org_type` string)
--  COMMENT '店副待汰换机动队接店'
--  PARTITIONED BY (
--    `dt` string)
--  ROW FORMAT SERDE
--    'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
--  WITH SERDEPROPERTIES (
--    'field.delim'=',',
--    'serialization.format'=',')
--  STORED AS INPUTFORMAT
--    'org.apache.hadoop.mapred.TextInputFormat'
--  OUTPUTFORMAT
--    'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
--  LOCATION
--    'hdfs://wormpexdata/user/data_smartorder/dm/dm_roster_staff_vice_manager_not_available_di'




DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_base_info_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_base_info_${dt} as 

 select distinct
 t1.store_code
 ,t1.dt
 from data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t1
 where t1.dt = date_format(date_sub(current_date(),2),'yyyyMMdd') 
 ;

;

DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_structure_info_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_structure_info_${dt} as 

 select
 t1.store_code
 ,t1.store_name
 ,t1.store_city
 ,nvl(t2.emplid,0) as store_manager_no
 ,t2.name as store_manager_name -- 店副
 ,t3.protect_tag
 ,t2.hps_d_jobcode as position_cn
 ,t2.hps_d_hr_status
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 left join data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view t2
 on t1.store_code = t2.hps_dept_code_lv5 
 and t2.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')  
 and t1.dt = t2.dt
 and t2.jobcode= 'NB0129'
 and t2.hps_d_hr_status = '在职'
 left join data_smartorder.dm_copy_dm_shop_staff_protect_tag_v2_view t3
 on IF(LENGTH(t2.emplid)<8,CONCAT('10',t2.emplid),t2.emplid) = t3.staff_code
 and t3.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')  
 and t1.dt = t3.dt
 where t1.dt=date_format(date_sub(current_date(),1),'yyyyMMdd') 
 -- and t1.store_type = 0
 -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
--)
;;

--当前已离职人list
--,status_info as (

DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_status_info_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_status_info_${dt} as 

 select 
 distinct 
 emplid
 ,1 as is_leave
 from data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view
 where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')  and hps_d_hr_status = '离职'
--)
;



--进行中or已确定未来会离职的人
--,leave_info as ( --离职流程中


DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_leave_info_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_leave_info_${dt} as 

 select distinct
 t1.man_code as user_job_number
 ,t1.order_status
 ,date_format(create_time,'yyyy-MM-dd') as create_date
 ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
 ,'1' as is_leaving
 from data_smartorder.dm_copy_pdw_gis_workday_dimission_order_view t1
 where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd') 
 and (t1.order_status = 'PROCESSING')
 or (date_format(final_leave_date,'yyyyMMdd') > date_format(date_sub(current_date(),0),'yyyyMMdd')  and final_leave = 'leave' and t1.order_status = 'FINISHED')
-- )
;;


--未来14天可用的天数
--,give_behave_info_f14_a as (

DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_give_behave_info_f14_a_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_give_behave_info_f14_a_${dt} as 

 select 
 tmp.staff_code
 ,sum(tmp.is_available_roster) as f14_available_days
 from (
 select 
 distinct
 t1.staff_code
 ,t1.target_date
 ,t1.is_available_roster
 from data_smartorder.dm_roster_staff_available_di t1
 where t1.dt in (select max(dt) from  data_smartorder.dm_roster_staff_available_di t1

 where dt >=date_format(date_sub(current_date(),2),'yyyyMMdd'))
 and date_format(t1.target_date,'yyyyMMdd') >= date_format(date_sub(current_date(),-1),'yyyyMMdd') 
 and date_format(t1.target_date,'yyyyMMdd') <= date_format(date_sub(current_date(),-14),'yyyyMMdd') 
 ) tmp
 group by tmp.staff_code
;



DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_fail_night_list_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_fail_night_list_${dt} as 
-- as 

select 
store_id
,count(distinct work_date) as fail_days 
from (
 select 
 from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,store_id
,work_date
,start_time
,end_time
from data_smartorder.dw_roster_roster_detail_info_ha a 
where concat(dt,hr) in (
select max(concat(dt,hr)) from data_smartorder.dw_roster_roster_detail_info_ha
where dt = date_format(date_sub(current_date(),0),'yyyyMMdd') 
)
and work_date >= date_sub(current_date(),-1)
and work_date <= date_sub(current_date(),7)
and sale_type <> '全天不营业'
and class_id = 0
and (a.roster_source='失败班表' and a.arrange_class_type IN (1,2))
and end_time -start_time >4
and start_time >= 19
) tt 
group by store_id



;;
DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_staff_list_v2_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_staff_list_v2_${dt} as 
-- as 

select
 t1.dt
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 ,t2.store_code
 ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
 ,hps_d_hr_status
 ,hps_d_jobcode
 from data_smartorder_dev.tmp_roster_vice_manager_not_available_info_base_info_${dt} t2
 left join data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view t1 on t2.store_code = t1.hps_dept_code_lv5 
 and t1.dt >= date_format(date_sub(current_date(),14),'yyyyMMdd')  
 and t1.dt <= date_format(date_sub(current_date(),1),'yyyyMMdd')  
 and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理')
 and hps_d_hr_status = '在职'
;;

DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_paiban_base0_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_paiban_base0_${dt} as 

 select 
 IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) as employee_id
,t0.store_code -- 排班门店
,t1.roster_id
,t1.work_date
,date_sub(next_day(t1.work_date,'mon'),7) roster_week --周
,t1.start_time
,t1.end_time
,(t1.end_time-t1.start_time) as paiban_hours
,t1.roster_source
,max(case when least(work_date,date_sub(current_date(),1)) = t2.new_dt then t2.store_code else null end) as hps_dept_code_lv5 -- 当天员工所属门店
-- ,case when t2.protect_tag = '待观察' then 1 else 0 end as is_new_staff
from data_smartorder_dev.tmp_roster_vice_manager_not_available_info_base_info_${dt}  t0
left join (select * from data_smartorder.dw_roster_roster_detail_info_ha a 
where concat(dt,hr) in (
select max(concat(dt,hr)) from data_smartorder.dw_roster_roster_detail_info_ha
where dt = date_format(date_sub(current_date(),0),'yyyyMMdd') 
)
and (arrange_class_type is null or arrange_class_type in(1,2))
)t1 on t0.store_code = t1.store_id 

and  t1.work_date >= date_sub(current_date(),1)
and t1.work_date <= date_sub(current_date(),-8)
and t1.store_type_desc = '门店'
and t1.class_id in ('0')
and t1.store_type = '0'
and t1.sale_type <> '全天不营业'
and t1.start_time >= 19
left join data_smartorder_dev.tmp_roster_vice_manager_staff_list_v2_${dt} t2 on IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) = t2.employee_id

group by 
IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id)
,t0.store_code -- 排班门店
,t1.roster_id
,t1.work_date
,date_sub(next_day(t1.work_date,'mon'),7) 
,t1.start_time
,t1.end_time
,(t1.end_time-t1.start_time) 
,t1.roster_source
;


DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_paiban_base_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_paiban_base_${dt} as 

select 
t1.employee_id
,t1.store_code -- 排班门店
,t1.hps_dept_code_lv5
,case when t1.store_code = t1.hps_dept_code_lv5 then 0 else 1 end as is_shift -- 是否由外店员工上班
,roster_id
,t1.work_date
,roster_week --周
,start_time
,end_time
,paiban_hours
,roster_source
from data_smartorder_dev.tmp_roster_vice_manager_paiban_base0_${dt} t1 
;;

DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_night_shift_store_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_night_shift_store_${dt} as 


select 
 store_code ,count(distinct work_date) as work_date_cnt
 ,count(distinct roster_id) as total_night_shift 
 ,count(distinct case when is_shift = 0 then roster_id else null end) as local_night_shift 
 ,count(distinct case when is_shift = 0 then roster_id else null end)/count(distinct roster_id) as local_night_shift_per

 from data_smartorder_dev.tmp_roster_vice_manager_paiban_base_${dt} 
 where roster_source = '成功班表'
 group by store_code
;



DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_night_shift_staff_base_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_night_shift_staff_base_${dt} as 

select 
 employee_id
 ,hps_dept_code_lv5 
 ,count(distinct roster_id) as total_night_shift_staff 
 ,count(distinct case when is_shift = 0 then roster_id else null end) as local_night_shift_staff 
 from data_smartorder_dev.tmp_roster_vice_manager_paiban_base_${dt}  
 where roster_source = '成功班表'
 group by employee_id
 ,hps_dept_code_lv5 
 --

 ;

 DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_night_shift_staff_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_night_shift_staff_${dt} as 

 select 
 hps_dept_code_lv5 as store_code 
 ,count(distinct case when local_night_shift_staff >= 4 or local_night_shift_staff/work_date_cnt >0.56  then employee_id else null end) as local_night_staff_cnts
 from data_smartorder_dev.tmp_roster_vice_manager_night_shift_staff_base_${dt} a left join data_smartorder_dev.tmp_roster_vice_manager_night_shift_store_${dt} b 
 on a.hps_dept_code_lv5 = b.store_code
 group by hps_dept_code_lv5
;;




DROP table if EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_${dt};
CREATE table if NOT EXISTS data_smartorder_dev.tmp_roster_vice_manager_not_available_info_${dt} as 



select distinct

 t0.store_code  -- as `门店编号`
 ,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date -- `缺编日期`
 ,t2.store_name -- as `门店名称`
 ,t2.store_city -- as `城市`
 ,t2.store_manager_no -- as `店副工号`
 ,t2.store_manager_name -- as `店副姓名`
 ,t2.hps_d_hr_status -- as current_manager_status
 ,t2.protect_tag -- as `店副标签`
 ,t5.is_leaving -- as current_manager_is_leaving
 ,t12.reward_level--  as `P等级`
 ,t6.bz_mgr_code -- as `战区工号`
 ,t6.bz_mgr_name -- as `战区姓名`
 ,t6.city_zone_mgr_code -- as `城市总工号`
 ,t6.city_zone_mgr_name -- as `城市总姓名`
 
 --架构是否缺编
 --顺序为汰换,战区,离职,不可用(14天),店员带店，店长带店
 ,case when t2.store_manager_no = '0' then '店副缺编'
 when t5.is_leaving = '1' then '离职流程中'
 when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
 else '店副正常'
 end empty_org_type -- as `缺编类型`
 ,case when t2.store_manager_no = '0' then '0'
 when t5.is_leaving = '1' then '3.2'
 when t14.f14_available_days <= '1' then '3.3'
 else '1'
 end empty_org_no -- as `缺编编号`

 ,t14.f14_available_days
 ,t7.fail_days
 ,case when t7.fail_days >0 then 1 else 0 end as is_night_fail
 -- 1. 缺店副，但有稳定夜班人员 （过去2周夜班无失败班次，>80%本店人员上的，有至少1个人出勤本店夜班>=4天/周）
 -- 2. 缺店副，无稳定夜班人员（过去2周夜班无失败班次，>80%本店人员上的，但没有人出勤每周稳定>=4天夜班）
 -- 3. 缺店副，缺夜班人员（过去2周夜班有失败班次/夜班班次有跨店人来上）
 -- 本店夜班是否由本店员工上
,t8.total_night_shift as total_night_shift_2week
,coalesce(t8.local_night_shift_per,0)  as local_night_ratio -- as `本店夜班比例`
,t9.local_night_staff_cnts
-- 本店是否有稳定夜班
,case when t9.local_night_staff_cnts >= 1 then 1 else 0 end as is_stable_night --  `是否有稳定夜班`
,case when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) <= 1  and t8.local_night_shift_per >= 0.7 and t9.local_night_staff_cnts >= 1 then '缺店副，有稳定夜班人员'
when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) <= 1 and t8.local_night_shift_per >= 0.7 and coalesce(t9.local_night_staff_cnts,0) < 1 then '缺店副，无稳定夜班人员'
when t2.store_manager_no = '0' and coalesce(t7.fail_days,0) > 1 then '缺店副，缺夜班人员'
when t2.store_manager_no = '0' and t8.local_night_shift_per < 1 then '缺店副，缺夜班人员'
when t5.is_leaving = '1' then '缺店副，无稳定夜班人员'
else null end as  empty_vice_org_type -- `店副缺编类型`

from data_smartorder_dev.tmp_roster_vice_manager_not_available_info_base_info_${dt} t0
left join  data_smartorder_dev.tmp_roster_vice_manager_not_available_info_structure_info_${dt} t2
on t0.store_code = t2.store_code
left join data_smartorder_dev.tmp_roster_vice_manager_not_available_info_status_info_${dt} t3 
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t3.emplid
left join data_smartorder_dev.tmp_roster_vice_manager_not_available_info_leave_info_${dt} t5
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t5.user_job_number
left join data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t12
on t12.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')  and t0.store_code = t12.store_code
left join data_smartorder_dev.tmp_roster_vice_manager_not_available_info_give_behave_info_f14_a_${dt} t14
on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t14.staff_code
left join data_smartorder.dm_copy_dwd_shop_store_jiagou_di_view t6 
on t6.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')  and t0.store_code = t6.store_code
left join  data_smartorder_dev.tmp_roster_vice_manager_not_available_info_fail_night_list_${dt} t7 on t0.store_code = t7.store_id
left join data_smartorder_dev.tmp_roster_vice_manager_night_shift_store_${dt} t8 on t0.store_code = t8.store_code
left join data_smartorder_dev.tmp_roster_vice_manager_night_shift_staff_${dt} t9 on t0.store_code = t9.store_code


;


insert overwrite table data_smartorder.dm_roster_staff_vice_manager_not_available_di PARTITION(dt='$dt')

select * from data_smartorder_dev.tmp_roster_vice_manager_not_available_info_${dt}



;

;
;
"
