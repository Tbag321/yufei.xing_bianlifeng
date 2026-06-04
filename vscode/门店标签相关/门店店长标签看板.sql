--自定义表(store_mgr_protect_tag_24812)
with latest_ehr_infra as ( --每人最新的花名册记录
    select
        distinct
        IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid) AS staff_code
        ,t1.emplid
        ,t1.name as staff_name
        ,t1.hps_d_city as city_name
        ,t1.hps_d_jobcode as position_cn
        ,case when date_format(t1.hps_hire_dt, 'yyyyMMdd') < date_format(date_sub(current_date,31),'yyyyMMdd')
            then if(t1.hps_d_jobcode in ('店经理'),'老店长','老员工')
            else if(t1.hps_d_jobcode in ('店经理'),'新店长','新员工')
        end as position_class
        ,t1.hps_dept_code_lv5 as store_code
        ,t1.hps_dept_descr_lv5 as store_name
        ,date_format(t1.hps_hire_dt,'yyyyMMdd') as entry_date
        ,date_format(t1.leave_dt,'yyyyMMdd') as leave_date
        ,case t1.hps_d_hr_status
            when '在职' then 1 else 0
        end   as job_status
        ,case when t1.hps_dept_descr_lv1 in ('运营管理部X') then 1 else 0 end as is_district
        ,null as hours
        ,null as total_attend_days
        ,null as punish_scl
        ,null as will_score_scl
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    where t1.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
        and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B','运营管理部X')
        and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        and t1.hps_d_hr_status = '在职'
)

,no_punch as ( --下班未打卡记录
    select
        employee_no
        ,work_shift_date
        ,'下班未打卡' as mark
    from default.pdw_opc_shop_attendance_report_work_shift a
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
        and date_format(work_shift_date, 'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
        and date_format(work_shift_date, 'yyyyMMdd') >= date_format(date_sub(current_date,28),'yyyyMMdd')
        and work_shift_type in (1,9,12)
        and punch_start_time is not null --上班打卡
        and punch_end_time is null --下班未打卡
)

,attendance_report_work_shift_revision_t30 as ( --考勤表订正
    select
        a.work_shift_id
        ,a.employee_no
        ,a.employee_name
        ,a.store_code
        ,a.store_name
        ,a.dept_code
        ,a.work_shift_date
        ,work_shift_hours
        ,attendance_work_hours
        ,case when b.mark = '下班未打卡'
            and a.work_shift_hours = 0.5 and punch_start_time is null and punch_end_time is null --切班
            then 0 else a.absenteeism_hours end as absenteeism_hours
        ,a.arrive_late_count
        ,a.leave_early_count
        ,a.arrive_late_minutes
        ,a.leave_early_minutes
    from default.pdw_opc_shop_attendance_report_work_shift a
    left join no_punch b
    on a.employee_no = b.employee_no and a.work_shift_date = b.work_shift_date
    where a.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
        and date_format(a.work_shift_date, 'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
        and date_format(a.work_shift_date, 'yyyyMMdd') >= date_format(date_sub(current_date,28),'yyyyMMdd')
        and a.work_shift_type in (1,9,12)
)

---------旷工修正结束------------

,attendance_info as(
    select
        work_shift_id                           -- as `考勤班次ID`
        ,if(length(employee_no) = 6,concat('10',employee_no),employee_no) as staff_code --as `员工工号`
        ,employee_name                          -- as `员工姓名`
        ,store_code                             -- as `门店编码`
        ,store_name                             -- as `门店名称`
        ,dept_code                              -- as `归属部门编码`
        ,date_format(work_shift_date,'yyyy-MM-dd') as work_shift_date           -- as `考勤班次日期`
        ,if(arrive_late_count=0,null,if(arrive_late_minutes<30,null,arrive_late_count)) as arrive_late_count 		-- as `迟到次数`
		,if(leave_early_count=0,null,if(leave_early_minutes<30,null,leave_early_count))	as leave_early_count		-- as `早退次数`
		,if(absenteeism_hours=0,null,if(absenteeism_hours<0.5,null,absenteeism_hours))	as absenteeism_hours		-- as `旷工工时数`
		,null as vac_punish_count  -- as `违规请假工时数`
    from attendance_report_work_shift_revision_t30 a
    where (arrive_late_count > 0 or leave_early_count > 0 or absenteeism_hours >=4)

    UNION ALL

    select
        order_id
        ,if(length(leavepeople)<8,concat('10',leavepeople),leavepeople) as staff_code
        ,leavename as employee_name
        ,roster_shopcode as store_code
        ,roster_shopname as store_name
        ,shopcode as dept_code
        ,date_format(create_date,'yyyy-MM-dd') as vac_apply_date
        ,null as arrive_late_count
        ,null as leave_early_count
        ,null as absenteeism_hours
        ,penalty_roster_hours --最终惩处工时
    from data_smartorder.app_internal_control_vacation_da
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
        and date_format(create_date, 'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
        and date_format(create_date, 'yyyyMMdd') >= date_format(date_sub(current_date,28),'yyyyMMdd')
        and is_exemption_eliminate = 0
        and penalty_roster_hours >= 0.5
)

,att_ab_info as (
    select
        staff_code
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,7),'yyyyMMdd')
                and date_format(work_shift_date,'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t7_abs
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,28),'yyyyMMdd')
                and date_format(work_shift_date,'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t28_abs
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,7),'yyyyMMdd')
                and date_format(work_shift_date,'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
                and arrive_late_count >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t7_late
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,7),'yyyyMMdd')
                and date_format(work_shift_date,'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t7_all_att
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,14),'yyyyMMdd')
                and date_format(work_shift_date,'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t14_all_att
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,21),'yyyyMMdd')
                and date_format(work_shift_date,'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t21_all_att
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,28),'yyyyMMdd')
                and date_format(work_shift_date,'yyyyMMdd') <= date_format(date_sub(current_date,1),'yyyyMMdd')
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t28_all_att
    from (
        select
            staff_code
            ,date_format(work_shift_date,'yyyy-MM-dd') as work_shift_date
            ,sum(coalesce(arrive_late_count,0)) as arrive_late_count
            ,sum(coalesce(leave_early_count,0)) as leave_early_count
            ,sum(coalesce(absenteeism_hours,0)) as absenteeism_hours
            ,sum(coalesce(vac_punish_count,0)) as vac_punish_count
        from attendance_info
        group by staff_code,date_format(work_shift_date,'yyyy-MM-dd')
    ) tmp
    group by staff_code
)

,should_leave_info AS (
    select
        tmp.staff_code
        ,"应离职" as protect_tag
        ,5 as protect_tag_detail
    from (
        select
            staff_code
            ,case
                when t7_abs>=2 then 1
                when t7_late>=3 then 1
                when (case when t7_abs>0 and (t7_all_att-1)>0 then t7_all_att-1 else 0 end)>=1 then 1
                when t7_all_att>=3 then 1
                when t14_all_att>=5 then 1
                when t21_all_att>=5 then 1
                when t28_all_att>=9 then 1
                when t28_abs >= 2 then 1
            else 0 end as should_leave
        from att_ab_info
    ) tmp
    left join latest_ehr_infra t1
    on tmp.staff_code = t1.staff_code
    where should_leave = 1
)

,name_bd_match as (
    select
        distinct
        IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid) AS staff_code --8位
        ,case
            when floor(datediff(date_format(date_sub(current_date,0),'yyyy-MM-dd'),t2.resume_birth_date)/365) is null then '无年龄信息'
            when floor(datediff(date_format(date_sub(current_date,0),'yyyy-MM-dd'),t2.resume_birth_date)/365) <= 22 then '疑似学生'
            else '非学生' end as position_tag
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    left join data_shop.dw_gis_hire_recruit_detail_v1_di_view t2
    on t2.dt = date_format(date_sub(current_date,1),'yyyyMMdd') and length(t2.entry_user_id) >2 and t1.hps_sys_name = t2.entry_user_id
    where t1.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
        and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B','运营管理部X')
        and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '店副经理','社会PT', '学生PT', '见习店经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        and t1.hps_d_hr_status = '在职'
)

,protect_tag_hist as (
    select
        staff_code
        ,protect_tag
        ,protect_tag_detail
    from (
        select
            staff_code
            ,protect_tag
            ,protect_tag_detail
            ,row_number() over(partition by staff_code order by dt desc) as rn
        from data_shop.dm_shop_staff_protect_tag_v2
        where dt <= date_format(date_sub(current_date,1),'yyyyMMdd')
    ) tmp
    where tmp.rn = 1
)

,shift_attend_info as (
    select
        t1.employee_no
        ,lpad(t1.employee_no,8,'10') as staff_code
        ,sum(coalesce(attendance_work_hours,0)) as attendance_work_hours
        ,count(distinct work_shift_date) as total_attend_days
    from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    where t1.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
        and t1.work_shift_type in (1,9,12)
    group by
        t1.employee_no
),

protect_tag_raw_mon as (
select 
staff_code
,protect_tag_raw
from data_shop.app_shop_staff_protect_tag_v2_da
where dt = date_format(date_sub(next_day(date_format(date_sub(current_date,1),'yyyy-MM-dd'),'mon'),7), 'yyyyMMdd')
),

--员工标签异常反馈流程(032225)
order_flow_main as(
select
order_id --流程编码(流程信息)
,substr(create_time,1,10) as create_date
,order_status --流程状态(流程信息)
,initiator_code --发起人编码(流程信息)
,create_time --流程发起时间(流程信息)
,flow_ame --流程名称(流程信息)
,org_code --门店编码(流程信息)
,org_name --门店名称(流程信息)
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and flow_code = '032225' --流程code
--and order_status in ('PROCESSING','FINISHED')
),

order_flow_groups as(
select
order_id
,max(employ_no) as employ_no --被申请人
,max(apply_type) as apply_type --申请类型
from(
select
order_id
,case when form_name = 'employ_no' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as employ_no --被申请人
,case when form_name = 'leibie' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as apply_type --申请类型
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and form_name in ('employ_no','leibie')
--and order_id = '2110159997876589'
) a
group by
order_id
),

order_flow_taskorders as(
select
order_id
,taskorder_node_id
,task_orders
,get_json_object(get_json_object(get_json_object(task_orders,'$.opLogs[1]'),'$.variableGroups[0]'),'$.formVariables.values[0].value') as handling_opinions --处理意见
,row_number() over(partition by concat(order_id,taskorder_node_id) order by taskorder_create_time desc) as rn
from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110159997876589'
and taskorder_result = 'AGREE'
and taskorder_status = 'FINISHED'
and taskorder_node_id = 'UserTask_1pg3a9a'
),

raw_list as(
select
t0.order_id --流程编码(流程信息)
,t0.create_date
,t0.order_status --流程状态(流程信息)
,t0.initiator_code --发起人编码(流程信息)
,t0.create_time --流程发起时间(流程信息)
,t0.flow_ame --流程名称(流程信息)
,t0.org_code --门店编码(流程信息)
,t0.org_name --门店名称(流程信息)
,t1.employ_no --被申请人
,t1.apply_type --申请类型
,t2.handling_opinions --处理意见
,row_number() over(partition by t1.employ_no order by t0.create_time desc) as rn --同一个人取最新申请时间
from order_flow_main t0
left join order_flow_groups t1 on t0.order_id = t1.order_id
left join order_flow_taskorders t2 on t0.order_id = t2.order_id
),

abnormal_label_list as(
select
create_date --相当于生效时间
,employ_no --被申请人
,case when apply_type = '1、本店店员是铜牌，但店长认为标签不合理' and handling_opinions = '可以豁免' then '2'
when apply_type = '3、本店或跨店店员标签很好，但实际表现很差，应该被淘汰' and handling_opinions = '可以豁免' then '4'
else null end as protect_tag_detail
,date_add(create_date,30) as cut_off_date --标签生效截止时间
from raw_list
where case when apply_type = '1、本店店员是铜牌，但店长认为标签不合理' and handling_opinions = '可以豁免' then '2'
when apply_type = '3、本店或跨店店员标签很好，但实际表现很差，应该被淘汰' and handling_opinions = '可以豁免' then '4'
else null end is not null
and rn = '1'
)

,final_list as (
    select
    distinct
        t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.position_class
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.leave_date
        ,t1.job_status
        ,t8.attendance_work_hours as hours
        ,t8.total_attend_days
        ,t1.punish_scl
        ,t1.will_score_scl
        ,case
        (case when t12.employ_no is not null and t12.protect_tag_detail = 2 then '银牌' --员工标签异常反馈流程(032225)
        when t12.employ_no is not null and t12.protect_tag_detail = 4 then '铜牌' --员工标签异常反馈流程(032225)
        when t10.staff_code is not null and t10.protect_tag_detail = 2 then '银牌'
        when t10.staff_code is not null and t10.protect_tag_detail = 1 then '金牌'
        when t7.staff_code is not null then '应离职' --政委输出的应离职list
            else coalesce(t3.protect_tag --出勤违规应离职
                ,if(t11.employee_id is not null --如果是店长，按照店长标签输出
                  ,(case t11.code 
                  when '0' then '钻石'
                  when '1' then '金牌'
                  when '2' then '银牌'
                  when '3' then '待观察'
                  when '4' then '铜牌'
                  when '5' then '应离职'
                  when '6' then '优质银牌'
                  end )
                  ,(case t0.protect_tag_detail_auto
                    when '1' then '金牌'
                    when '2' then '银牌'
                    when '4' then '铜牌'
                    when '5' then '应离职' end)) --待观察日更结果
                ,if((t2.protect_tag='待观察' or t2.protect_tag is null)
                    ,if(t5.protect_tag in ('应保护','普通','金牌','银牌'),t5.protect_tag,t2.protect_tag) --当前是待观察但是历史曾作为1/2的人离职
                    ,case t2.protect_tag_detail
                    when '0' then '钻石'
                  when '1' then '金牌'
                  when '2' then '银牌'
                  when '3' then '待观察'
                  when '4' then '铜牌'
                  when '5' then '应离职'
                  end ) --每周二上传结果
                ,'待观察')
        end)
            when '钻石' then '钻石'
            when '应保护' then '金牌'
            when '金牌' then '金牌'
            when '普通' then '银牌'
            when '银牌' then '银牌'
            when '待观察' then '待观察'
            when '末位普通' then '铜牌'
            when '铜牌' then '铜牌'
            when '应离职' then '应离职'
            when '须努力' then '应离职'
            when '优质银牌' then '优质银牌'
        end as protect_tag
        ,case
        (case when t12.employ_no is not null and t12.protect_tag_detail = 2 then '银牌' --员工标签异常反馈流程(032225)
        when t12.employ_no is not null and t12.protect_tag_detail = 4 then '铜牌' --员工标签异常反馈流程(032225)
        when t10.staff_code is not null and t10.protect_tag_detail = 2 then '银牌'
        when t10.staff_code is not null and t10.protect_tag_detail = 1 then '金牌'
        when t7.staff_code is not null then '应离职' --政委输出的应离职list
            else coalesce(t3.protect_tag --出勤违规应离职
                ,if(t11.employee_id is not null --如果是店长，按照店长标签输出
                  ,(case t11.code 
                  when '0' then '钻石'
                  when '1' then '金牌'
                  when '2' then '银牌'
                  when '3' then '待观察'
                  when '4' then '铜牌'
                  when '5' then '应离职'
                  when '6' then '优质银牌'
                  end )
                  ,(case t0.protect_tag_detail_auto
                    when '1' then '金牌'
                    when '2' then '银牌'
                    when '4' then '铜牌'
                    when '5' then '应离职' end)) --待观察日更结果
                ,if((t2.protect_tag='待观察' or t2.protect_tag is null)
                    ,if(t5.protect_tag in ('应保护','普通','金牌','银牌'),t5.protect_tag,t2.protect_tag) --当前是待观察但是历史曾作为1/2的人离职
                    ,case t2.protect_tag_detail
                    when '0' then '钻石'
                  when '1' then '金牌'
                  when '2' then '银牌'
                  when '3' then '待观察'
                  when '4' then '铜牌'
                  when '5' then '应离职'
                  end ) --每周二上传结果
                ,'待观察')
        end)
            when '钻石' then '0'
            when '应保护' then '1'
            when '金牌' then '1'
            when '优质银牌' then '1.5'
            when '普通' then '2'
            when '银牌' then '2'
            when '待观察' then '3'
            when '末位普通' then '4'
            when '铜牌' then '4'
            when '应离职' then '5'
            when '须努力' then '5'
        end as protect_tag_detail
        ,date_format(date_sub(current_date,0),'yyyyMMdd') as valid_dt
        ,case when t1.position_cn <> '店经理' and t1.position_cn <> '学生PT'
            and t4.position_tag = '疑似学生' and t6.staff_code is null then 1 else 0 end as student_suspect
        ,case when t9.store_manager_no is not null then '1' else '0'
        end as is_manager
        ,case when t8.attendance_work_hours < 60 then '1-[0,60)'
            when t8.attendance_work_hours < 200 then '2-[60,200)'
            when t8.attendance_work_hours < 600 then '3-[200,600)'
            else '4-[600,+)'
        end as mature_level
        ,t1.emplid
        ,t1.is_district
    from latest_ehr_infra t1
    left join data_shop.ods_uploads_protect_tag_0419 t2
    ON t1.staff_code = t2.staff_code
    left join should_leave_info t3
    on t1.staff_code = t3.staff_code
    left join name_bd_match t4
    on t1.staff_code = t4.staff_code and t4.position_tag = '疑似学生'
    left join protect_tag_hist t5
    on t1.staff_code = t5.staff_code
    left join data_shop.ods_uploads_student_suspect_remove t6
    on t1.staff_code = t6.staff_code
    left join data_shop.ods_uploads_should_leave t7
    on t1.staff_code = t7.staff_code
    left join shift_attend_info t8
    on t1.staff_code = t8.staff_code
    left join data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t9
    on t9.dt = date_format(date_sub(current_date,1),'yyyyMMdd') and t1.emplid = t9.store_manager_no
    left join data_shop.app_shop_staff_new_tag_di t0
    on t1.staff_code = lpad(t0.emplid,8,'10')
        and t0.dt <= date_format(date_sub(current_date,1),'yyyyMMdd')
        and t0.dt >=
            date_format(case
                when (pmod(datediff(date_format(date_sub(current_date,0),'yyyy-MM-dd'),'1900-01-08'),7)+1) in (2,3,4,5,6,7)
                    then date_sub(date_format(date_sub(current_date,0),'yyyy-MM-dd'),pmod(datediff(date_format(date_sub(current_date,0),'yyyy-MM-dd'),'1900-01-08'),7))
                when (pmod(datediff(date_format(date_sub(current_date,0),'yyyy-MM-dd'),'1900-01-08'),7)+1) in (1)
                    then date_sub(date_format(date_sub(current_date,0),'yyyy-MM-dd'),pmod(datediff(date_format(date_sub(current_date,0),'yyyy-MM-dd'),'1900-01-08'),7)+7)
            end,'yyyyMMdd')
    left join data_shop.ods_uploads_staff_tag_uploadv2 t10
            on t1.staff_code = t10.staff_code
    left join(
select * from(
select 
t0.employee_id
,case when t0.code = '2' and t1.total_score > 3.4 then '6' else t0.code end as code
,rank() over(order by t0.dt desc) as rn
from
data_build.ods_uploads_manager_tag_4 t0
left join data_build.dwd_manager_tag_v1_di t1 on t0.employee_id = t1.employee_id 
and t1.dt = case when dayofweek(current_date()) in ('2','3') then date_format(date_sub(next_day(current_date(), 'MO'), 14),'yyyyMMdd') else date_format(date_sub(next_day(current_date(), 'MO'), 7),'yyyyMMdd') end
where t0.dt < date_format(current_date,'yyyyMMdd')
) a
where rn = 1
) t11
    on t1.staff_code = t11.employee_id
    left join abnormal_label_list t12 on t1.staff_code = t12.employ_no 
    and t12.cut_off_date >= date_format(date_sub(current_date,0),'yyyy-MM-dd') --保护标签生效30天
            ),

    protect_raw as(
    select
    staff_code
    ,protect_tag
    from final_list
    ),

    protect_raw_1 as(
    select
    t0.*
    ,t1.protect_tag
    ,case when t2.employee_id is not null then '店长' else '机动队' end as postition_name
    from data_build.dwd_store_construction_manager_base_info_vi_v1_di t0
    left join protect_raw t1 on t0.employee_id = t1.staff_code
    left join data_build.dwd_store_construction_manager_base_info_vi_di t2 on t0.employee_id = t2.employee_id and t2.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    where t0.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    )

    select
    postition_name
    ,protect_tag
    ,count(store_code) as num
    ,count(*) * 100/sum(count(*)) over() as per
    from protect_raw_1
    group by
    postition_name
    ,protect_tag