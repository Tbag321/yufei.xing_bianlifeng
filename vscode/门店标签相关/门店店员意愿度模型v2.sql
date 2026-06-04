--门店店员意愿度模型v2(data_shop.dwa_shop_staff_will_v2_da)
with work_reference as (
    select distinct
        date_key
        ,day_of_week
        ,case when day_of_week in ('6','7') 
            and holiday_type = '2' then '1' 
            else is_working_day end as is_work_day
    from data_shop.dim_date_ya_v2_view
)

,a_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,case when leave_dt is null then 0 else 1 end as add_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt >= 20210318
),

b_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,sum(add_num) over(partition by emplid order by concat(dt,emplid) desc) as sum_num
from a_list
),

c_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,sum_num
,max(leave_dt) over(partition by concat(emplid,sum_num) order by concat(dt,emplid) desc) as final_leave_dt
from b_list
),

leave_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,case when final_leave_dt is null then '2035-12-31' else final_leave_dt end as leave_dt
from c_list t1
),

staff_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,new_dt
,store_code
,emplid
,employee_id
,name
,hps_hire_dt
,leave_dt
,hps_d_hr_status
,hps_hire_type
,hps_d_jobcode
,hps_dept_descr_lv1
,hps_d_city
,hps_dept_code_lv5
,hps_dept_descr_lv5
,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
,dense_rank() over(partition by employee_id order by leave_dt) as rn_2 --第几次在职
,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt) as hps_hire_date
,case when hps_d_hr_status = '离职' then '离职' else 
datediff(new_dt,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt))
end as hire_date_num
from
(
select
t1.dt
,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,t1.hps_dept_code_lv5 as store_code
,t1.emplid
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,name
,t1.hps_hire_dt
,t3.leave_dt
,case when t3.leave_dt = '2035-12-31' then '在职'
when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
else '离职' end as hps_d_hr_status --在离职状态
,t1.hps_hire_type --用工形式
,t1.hps_d_jobcode
,t1.hps_dept_descr_lv1
,t1.hps_d_city
,t1.hps_dept_code_lv5
,t1.hps_dept_descr_lv5
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
where t1.dt >= 20210318
) a
),

raw_list as( --更新入职日期，防止换签导致的入职日期刷新
select
t.dt
,t.new_dt --日期
,t.store_code --门店编码
,t.emplid
,t.employee_id
,t.name
,t.hps_hire_dt --系统雇佣时间(没用)
,t.leave_dt --离职日期
,t.hps_d_hr_status --在离职状态
,t.hps_hire_type
,t.hps_d_jobcode
,t.hps_dept_descr_lv1
,t.hps_d_city
,t.hps_dept_code_lv5
,t.hps_dept_descr_lv5
,t.rn_1 --按照人*时间维度排序
,t.rn_2 --第几次入职
,t.hps_hire_date --本次雇佣周期开始日期(真实的入职日期)
,t.hire_date_num --本次雇佣周期时长
from staff_list t
)

,t30_work_reference as (
    select 
        date_key
        ,sum(is_work_day) over(order by date_key desc) as t30_work_day_cnts
    from (
        select distinct
            date_key
            ,is_work_day
        from work_reference
    ) t0
    where t0.date_key >= '${TODAY-30}' and t0.date_key <= '${TODAY-1}'
)

,cum_attend_info as ( --part1.工龄
    select
        t1.employee_no
        ,sum(coalesce(attendance_work_hours,0)) as cum_attend_hours
        ,count(distinct work_shift_date) as total_attend_days
        ,sum(case when date_format(t1.work_shift_date,'yyyyMMdd') >= 
            date_format(t2.hps_hire_date,'yyyyMMdd') then t1.attendance_work_hours end) as cum_attendance_work_hours_after_entry
    from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    --inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
    inner join raw_list t2
    on t1.employee_no = t2.emplid and t2.new_dt = '${TODAY-1}'
    where t1.dt = '${today-1}'
        and t1.work_shift_type in (1,9,12)
       -- and t2.hps_d_hr_status in ('在职')
        and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
        and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        -- and date_format(t1.work_shift_date,'yyyyMMdd') >= date_format(t2.hps_hire_dt,'yyyyMMdd')
    group by
        t1.employee_no
)

,attend_shift_detail as ( --出勤工时底表
    select 
        emplid
        ,work_shift_id
        ,attend_date
        ,work_shift_hours
        ,attendance_work_hours
        ,t1.is_work_day
        ,coalesce(arrive_late_hour,0) as arrive_late_hour
        ,coalesce(leave_early_hour,0) as leave_early_hour
        ,coalesce(absenteeism_hour,0) as absenteeism_hour
        ,coalesce(arrive_late_hour,0) + coalesce(leave_early_hour,0) + coalesce(absenteeism_hour,0) as ab_attend_hour

        ----延长打卡时间不超过4小时
        ,case when early_arrive_hour >= 0 and early_arrive_hour <= 4 then early_arrive_hour else 0 end as early_arrive_hour
        ,case when late_leave_hour >= 0 and late_leave_hour <= 4 then late_leave_hour else 0 end as late_leave_hour
    from (
        select
            employee_no as emplid
            ,work_shift_id
            ,date_format(work_shift_date, 'yyyy-MM-dd') as attend_date
            ,sum(work_shift_hours) as work_shift_hours
            ,sum(attendance_work_hours) as attendance_work_hours
            --,sum(arrive_late_count)/2 as arrive_late_hour
            ,sum(case when arrive_late_minutes < 30 then 0 else arrive_late_minutes end)/60 as arrive_late_hour --0808改：迟到30分钟不算迟到，直接按照分钟换算成小时
            ,sum(leave_early_count)/2 as leave_early_hour
            ,sum(absenteeism_hours) as absenteeism_hour
            ,floor(sum((unix_timestamp(work_shift_start_time) - unix_timestamp(punch_start_time))) / 3600 / 0.5)/2 as early_arrive_hour
            ,floor(sum((unix_timestamp(punch_end_time) - unix_timestamp(work_shift_end_time))) / 3600 / 0.5)/2 as late_leave_hour
        from data_shop.pdw_opc_shop_attendance_report_work_shift_view
        where dt = '${today-1}'
            and date_format(work_shift_date, 'yyyyMMdd') >= '${today-30}'
            and work_shift_type in (1,9,12)
        group by employee_no,work_shift_id,date_format(work_shift_date, 'yyyy-MM-dd')
    ) t0
    left join work_reference t1
    on t0.attend_date = t1.date_key
)

,t30_attend_info as ( --part2.实际出勤
    select 
        t1.emplid
        ,sum(t1.work_shift_hours) as work_shift_hours
        ,sum(t1.attendance_work_hours) as attendance_work_hours
        ,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_date,'yyyyMMdd') 
            then t1.work_shift_hours end) as work_shift_hours_after_entry
        ,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_date,'yyyyMMdd') 
            then t1.attendance_work_hours end) as attendance_work_hours_after_entry
        ,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_date,'yyyyMMdd') 
            and t1.is_work_day = '1' then t1.attendance_work_hours end) as workday_attend_hours_after_entry
        ,sum(t1.arrive_late_hour) as arrive_late_hour
        ,sum(t1.leave_early_hour) as leave_early_hour
        ,sum(t1.absenteeism_hour) as absenteeism_hour
        ,sum(t1.ab_attend_hour) as ab_attend_hour
        ,sum(t1.early_arrive_hour) as early_arrive_hour
        ,sum(t1.late_leave_hour) as late_leave_hour
        ,count(distinct case when t1.arrive_late_hour>0 or t1.leave_early_hour >0 then t1.attend_date end) as t30_leave_arrive_cnts
    from attend_shift_detail t1
    --inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
    inner join raw_list t2
    on t1.emplid = t2.emplid and t2.new_dt = '${TODAY-1}'
        and t2.hps_d_hr_status in ('在职')
        and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
        and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    group by t1.emplid
)

,ab_vac_detail as (
    select
        order_id
        ,if(length(leavepeople)<8,concat('10',leavepeople),leavepeople) as staff_code
        ,leavename as employee_name
        ,roster_shopcode as store_code
        ,roster_shopname as store_name
        ,shopcode as dept_code
        ,date_format(create_date,'yyyy-MM-dd') as vac_apply_date
        ,penalty_roster_hours --最终惩处工时
    from data_shop.app_internal_control_vacation_da_view
    where dt = '${today-1}'
        and date_format(create_date, 'yyyyMMdd') >= '${today-30}'
        and is_exemption_eliminate = 0
)

,ab_vac_info as ( --t30违规请假惩处工时
    select 
        staff_code
        ,sum(penalty_roster_hours) as t30_sum_penalty_roster_hours
    from ab_vac_detail
    group by staff_code
)

,avail_hours_info as ( --可用小时
    select 
        lpad(staff_code,8,'10') as staff_code
        ,date_format(date_key,'yyyy-MM-dd') as roster_date
        -- ,date_sub(next_day(date_key,'mon'),7) as roster_week --周
        ,count(distinct case when is_give_roster = 1 and is_vacation = 0 
            and is_dimission_apply_available = 1 and is_health_cer_right = 1 
            and is_in_black_list = 0 then rk_of_half_hour end)/2 as avail_hours --可用小时（给班&未请假&未离职&健康证可用&不在黑名单）
    from data_shop.dm_roster_staff_half_hour_roster_and_attendance_quantity_di_view t1
    where dt = '${today-1}'
        and hps_d_hr_status = '在职'
        and date_key --本周和未来一周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7) 
            and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),6) 
        -- and is_store_manager = 0 --非架构负责人
    group by 
        staff_code
        ,date_key
        -- ,date_sub(next_day(date_key,'mon'),7)
)

,give_standard_detail as (
    select
        date_format(roster_date,'yyyy-MM-dd') as roster_date
        ,employee_id
        ,IF(LENGTH(employee_id)<8,concat('10',employee_id),employee_id) as staff_code
        ,givetype
        ,case when givetype in ('全天可开工','夜晚可开工','白天可开工') then '1' else '0' end as is_give_standard
        ,case when givetype in ('全天可开工') then '1' else '0' end as is_give_full
    from data_shop.dw_roster_give_roster_detail_snapshot_da_view t1
    where t1.dt = '${today-1}'
        and t1.roster_date --本周和未来一周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7) 
            and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),6) 
)

,avial_days_info as (
    select distinct 
        t1.staff_code
        ,date_format(t1.target_date,'yyyy-MM-dd') as roster_date
        -- ,date_sub(next_day(t1.target_date,'mon'),7) as roster_week --周
        ,case when is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1'
            then '1' else '0' end as is_available_roster
        ,case when (is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1') 
            and is_give_standard = '1' then '1' else '0' end as is_standard
        ,case when (is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1') 
            and is_give_full = '1' then '1' else '0' end as is_full
        ,t2.givetype
    from data_shop.dm_roster_staff_available_di_view t1
    left join give_standard_detail t2
    on t1.staff_code = t2.staff_code 
        and date_format(t1.target_date,'yyyy-MM-dd') = date_format(t2.roster_date,'yyyy-MM-dd')
    where t1.dt = '${today-1}'
        and t1.target_date --本周和未来一周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7)
            and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),6)
)

,avail_detail as ( --天维度可用整理
    select distinct
        t1.staff_code
        ,t1.roster_date
        ,if(t1.avail_hours > 12, 12, t1.avail_hours) as avail_hours
        ,coalesce(t2.is_available_roster,0) as is_avail_day
        ,coalesce(t2.is_standard,0) as is_standard
        ,coalesce(t2.is_full,0) as is_full
        ,coalesce(t2.givetype,'未自主给班') as give_type
        ,t3.day_of_week
        ,t3.is_work_day
    from avail_hours_info t1
    left join avial_days_info t2
    on lpad(t1.staff_code,8,'10') = lpad(t2.staff_code,8,'10') and t1.roster_date = t2.roster_date
    left join work_reference t3
    on t1.roster_date = t3.date_key
)

-- ,is_give as ( --历史代码：做80%给班天数的筛选，弃用
--     select 
--         roster_date
--         ,count(distinct staff_code) as staff_cnts
--         ,count(distinct case when give_type = '未自主给班' then staff_code end) as ungive_cnts
--         ,count(distinct case when give_type = '未自主给班' then staff_code end)/count(distinct staff_code) as ungive_rate
--     from avail_detail
--     group by roster_date
-- )

,avail_info as ( --part3.未来可用
    select 
        t1.staff_code
        ,count(distinct t1.roster_date) as total_day_cnts
        ,count(distinct case when t1.is_work_day = '1' then t1.roster_date end) as work_day_cnts
        ,sum(t1.avail_hours) as total_avail_hours
        ,sum(case when t1.is_work_day = '1' then t1.avail_hours end) as work_day_avail_hours
        ,count(distinct case when t1.is_avail_day = '1' then t1.roster_date end) as total_avail_days
        ,count(distinct case when t1.is_work_day = '1' and t1.is_avail_day = '1' then t1.roster_date end) as work_day_avail_days
        ,count(distinct case when t1.is_avail_day = '1' and t1.is_standard = '1' then t1.roster_date end) as total_standard_avail_days
        ,count(distinct case when t1.is_work_day = '1' and t1.is_avail_day = '1' and t1.is_standard = '1' then t1.roster_date end) as work_day_standard_avail_days
        ,count(distinct case when t1.is_avail_day = '1' and t1.is_full = '1' then t1.roster_date end) as total_full_avail_days
        ,count(distinct case when t1.is_work_day = '1' and t1.is_avail_day = '1' and t1.is_full = '1' then t1.roster_date end) as work_day_full_avail_days
    from avail_detail t1
    -- inner join is_give t0
    -- on t1.roster_date = t0.roster_date and t0.ungive_rate < 0.8
    group by t1.staff_code
)

,avial_days_fluc_detail as ( --可用波动
    select distinct 
        t1.staff_code
        ,date_format(t1.target_date,'yyyy-MM-dd') as roster_date
        ,date_sub(next_day(t1.target_date,'mon'),7) as roster_week --周
        ,case when is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1'
            then '1' else '0' end as is_available_roster
    from data_shop.dm_roster_staff_available_di_view t1
    inner join work_reference t3
    on date_format(t1.target_date,'yyyy-MM-dd') = t3.date_key and t3.is_work_day = '1' --只看工作日
    where t1.dt = '${today-1}'
        and t1.target_date --过去四周+本周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),35)
            and date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),1) 
)

,avial_days_fluc_pivot as ( --周度可用pivot
    select 
        staff_code
        ,roster_week
        ,count(distinct case when is_available_roster = '1' then roster_date end) as avial_days
        ,count(distinct roster_date) as total_days
        ,count(distinct case when is_available_roster = '1' then roster_date end)/count(distinct roster_date) as avail_days_rate
    from avial_days_fluc_detail
    group by 
        staff_code
        ,roster_week
)

,avial_days_fluc_info as ( --part3.2可用波动
    -- select 
    --     t1.staff_code
    --     ,t1.roster_week
    --     ,t1.avial_days
    --     ,t1.total_days
    --     ,t1.avail_days_rate
    --     ,t2.std_avail_days_rate
    -- from avial_days_fluc_pivot t1
    -- left join (
        select 
            staff_code
            ,stddev_samp(avail_days_rate) as std_avail_days_rate
        from avial_days_fluc_pivot t1
        group by staff_code
    -- ) t2
    -- on t1.staff_code = t2.staff_code
)

,sop_learn_detail as ( --蜂窝学习明细-任务维度聚合
    select 
        title
        ,emplid
        ,count(1) as mission_cnts
        ,sum(finis_percent)/100 as finish_cnts
    from (
        select distinct
            title
            ,source_name
            ,usercode as emplid
            ,mission_type
            ,sub_mission_type
            ,createtime
            ,class_hour
            ,finis_percent
        from data_shop.dwa_shop_sop_learn_exam_result_v1 t1
        inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
        on t1.usercode = t2.emplid  and t2.dt = '${today-1}'
            and t2.hps_d_hr_status in ('在职')
            and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
            and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        where t1.dt = '${today-1}' --只有最新dt有数
            and subplantype = 'clerkSop'
            and date_format(createtime,'yyyyMMdd') >= '${today-30}'
    ) t0
    group by 
        title
        ,emplid
)

,sop_learn_info as ( --part4.1蜂窝学习完成率=sop_finish_cnts/sop_issue_cnts
    select 
        emplid
        ,count(distinct title) as sop_issue_cnts
        ,count(distinct case when finish_cnts/mission_cnts=1 then title end) as sop_finish_cnts
        ,count(distinct case when finish_cnts/mission_cnts=1 then title end)/count(distinct title) as sop_learn_rate
    from sop_learn_detail
    group by emplid
)

,course_info as ( --part4.2课程覆盖率
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
    where t1.dt = '${today-1}'
)


select
    distinct
    t1.emplid
    ,lpad(t1.emplid,8,'10') as staff_code
    ,t1.name as staff_name
    ,t1.hps_d_city as city_name
    ,t1.hps_d_jobcode as position_cn
    ,case when t7.store_manager_no is not null then '1' else '0' end as is_store_manager
    ,t1.hps_dept_code_lv5 as store_code
    ,t1.hps_dept_descr_lv5 as store_name
    ,date_format(t1.hps_hire_date,'yyyy-MM-dd') as entry_date
    -- ,case when t7.store_manager_no is null and coalesce(t2.cum_attendance_work_hours_after_entry,0) >= 60 then '店员标签' end as is_tag

    -- --常规项
    -- ,coalesce(t2.cum_attend_hours,0) as `累计出勤工时`
    -- ,round(case when datediff(to_date('${TODAY}'),t1.hps_hire_dt) < 30 then
    --     coalesce(attendance_work_hours_after_entry,0)/datediff(to_date('${TODAY}'),t1.hps_hire_dt) * 30
    --     else coalesce(attendance_work_hours_after_entry,0) end,4) as `0-模拟t30出勤小时`
    -- ,round(coalesce(work_day_avail_days,0)/coalesce(work_day_cnts,0),4) as `0-工作日可用天数占比`
    -- ,round(coalesce((coalesce(t3.ab_attend_hour,0) + coalesce(t9.t30_sum_penalty_roster_hours,0))/
    --     (coalesce(t3.work_shift_hours,0) + coalesce(t9.t30_sum_penalty_roster_hours,0)),0),4) as `0-迟早旷+违规请假工时占比`
    -- ,coalesce(t3.t30_leave_arrive_cnts,0) as `t30迟早次数`
    -- --加分项
    -- ,round(coalesce(coalesce(t5.sop_finish_cnts,0)/coalesce(t5.sop_issue_cnts,0),0),4) as `蜂窝学习完成率`
    -- ,round((coalesce(total_avail_days,0) - coalesce(work_day_avail_days,0))/
    --     (coalesce(total_day_cnts,0) - coalesce(work_day_cnts,0)),4) as `0-节假日给班`
    -- ,round(coalesce(coalesce(work_day_full_avail_days,0)/coalesce(work_day_avail_days,0),0),4) as `0-工作日全天占比`
    -- --减分项
    -- ,round(coalesce(coalesce(work_day_standard_avail_days,0)/coalesce(work_day_avail_days,0),0),4) as `0-工作日标准占比`
    -- ,round(coalesce(t8.std_avail_days_rate,'NA'),4) as `0-工作日可用占比std`

    --底数
    ,coalesce(t2.cum_attend_hours,0) as cum_attend_hours --累计出勤工时
    ,coalesce(total_attend_days,0) as total_attend_days --累计出勤天数
    ,coalesce(t2.cum_attendance_work_hours_after_entry,0) as cum_attend_hours_after_entry --入职后出勤工时(卡二次入职)
    ,datediff(to_date('${TODAY}'),t1.hps_hire_date) as total_entry_days --入职至今的天数
    ,coalesce(t3.work_shift_hours,0) as t30_work_shift_hours --t30排班工时
    ,coalesce(t3.attendance_work_hours,0) as t30_attendance_work_hours --t30出勤工时
    ,coalesce(t3.work_shift_hours_after_entry,0) as t30_work_shift_hours_after_entry --t30入职后排班工时(卡二次入职)
    ,coalesce(t3.attendance_work_hours_after_entry,0) as t30_attend_hours_after_entry --t30入职后出勤工时(卡二次入职)
    ,coalesce(t3.arrive_late_hour,0) as t30_arrive_late_hour
    ,coalesce(t3.leave_early_hour,0) as t30_leave_early_hour
    ,coalesce(t3.absenteeism_hour,0) as t30_absenteeism_hour
    ,coalesce(t9.t30_sum_penalty_roster_hours,0) as t30_sum_penalty_roster_hours --t30违规请假惩处小时数
    -- ,coalesce(t3.ab_attend_hour,0) as t30_ab_attend_hour --t30迟早旷小时数
    ,coalesce(t3.t30_leave_arrive_cnts,0) as t30_ab_leave_arrive_cnts --t30迟早次数
    -- ,coalesce(t3.ab_attend_hour,0) + coalesce(t9.t30_sum_penalty_roster_hours,0) as ab_roster_hour --t30考勤类违规小时数
    ,coalesce(t3.early_arrive_hour,0) as t30_early_arrive_hour
    ,coalesce(t3.late_leave_hour,0) as t30_late_leave_hour
    -- ,coalesce(t3.early_arrive_hour,0) + coalesce(t3.late_leave_hour,0) as over_punch_hour --t30义务打卡时间
    ,coalesce(total_day_cnts,0) as total_day_cnts --未来给班天数
    ,coalesce(work_day_cnts,0) as work_day_cnts --未来工作日给班天数
    -- ,coalesce(total_avail_hours,0) as total_avail_hours --未来可用小时数
    -- ,coalesce(work_day_avail_hours,0) as work_day_avail_hours --未来工作日可用小时数
    ,coalesce(total_avail_days,0) as total_avail_days --未来可用天数
    ,coalesce(work_day_avail_days,0) as work_day_avail_days --未来工作日可用天数
    -- ,coalesce(total_standard_avail_days,0) as total_standard_avail_days --未来标准可用天数
    -- ,coalesce(work_day_standard_avail_days,0) as work_day_standard_avail_days --未来工作日标准可用天数
    ,coalesce(total_full_avail_days,0) as total_full_avail_days --未来全天可用天数
    ,coalesce(work_day_full_avail_days,0) as work_day_full_avail_days --未来工作日全天可用天数
    ,coalesce(t5.sop_issue_cnts,0) as t30_sop_issue_cnts
    ,coalesce(t5.sop_finish_cnts,0) as t30_sop_finish_cnts
    ,round(coalesce(coalesce(t5.sop_finish_cnts,0)/coalesce(t5.sop_issue_cnts,0),0),4) as sop_learn_rate --蜂窝学习完成率
    -- ,coalesce(t6.learn_tag,'D') as learn_tag --课程覆盖率（新人训/初级/进阶/店长）
    ,coalesce(t8.std_avail_days_rate,null) as std_avail_days_rate --5周+可用波动

    ,coalesce(t3.workday_attend_hours_after_entry,0) as t30_workday_attend_hours_after_entry
    ,coalesce(t10.t30_work_day_cnts,0) as t30_work_day_cnts_after_entry
--from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1
from raw_list t1
left join cum_attend_info t2
on lpad(t1.emplid,8,'10') = lpad(t2.employee_no,8,'10')
left join t30_attend_info t3
on lpad(t1.emplid,8,'10') = lpad(t3.emplid,8,'10')
left join avail_info t4
on lpad(t1.emplid,8,'10') = lpad(t4.staff_code,8,'10')
left join sop_learn_info t5
on lpad(t1.emplid,8,'10') = lpad(t5.emplid,8,'10')
left join course_info t6
on lpad(t1.emplid,8,'10') = lpad(t6.staff_code,8,'10')
left join data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t7
on t7.dt = '${today-1}' and lpad(t1.emplid,8,'10') = lpad(t7.store_manager_no,8,'10')
left join avial_days_fluc_info t8
on lpad(t1.emplid,8,'10') = lpad(t8.staff_code,8,'10')
left join ab_vac_info t9
on lpad(t1.emplid,8,'10') = lpad(t9.staff_code,8,'10')
left join t30_work_reference t10
on (case when date_format(t1.hps_hire_date,'yyyyMMdd') < '${today-30}' then '${TODAY-30}' 
    else date_format(t1.hps_hire_date,'yyyy-MM-dd') end) = t10.date_key
where t1.new_dt = '${TODAY-1}'
    and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
    and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and t1.hps_d_hr_status = '在职'

############################################################################################################################################################################################
############################################################################################################################################################################################
############################################################################################################################################################################################

--门店店员意愿度模型v2(data_shop.dwa_shop_staff_will_v2_da) --调整给班逻辑为未来4周
with work_reference as (
    select distinct
        date_key
        ,day_of_week
        ,case when day_of_week in ('6','7') 
            and holiday_type = '2' then '1' 
            else is_working_day end as is_work_day
    from data_shop.dim_date_ya_v2_view
)

,a_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,case when leave_dt is null then 0 else 1 end as add_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt >= 20210318
),

b_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,sum(add_num) over(partition by emplid order by concat(dt,emplid) desc) as sum_num
from a_list
),

c_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,sum_num
,max(leave_dt) over(partition by concat(emplid,sum_num) order by concat(dt,emplid) desc) as final_leave_dt
from b_list
),

leave_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,case when final_leave_dt is null then '2035-12-31' else final_leave_dt end as leave_dt
from c_list t1
),

staff_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,new_dt
,store_code
,emplid
,employee_id
,name
,hps_hire_dt
,leave_dt
,hps_d_hr_status
,hps_hire_type
,hps_d_jobcode
,hps_dept_descr_lv1
,hps_d_city
,hps_dept_code_lv5
,hps_dept_descr_lv5
,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
,dense_rank() over(partition by employee_id order by leave_dt) as rn_2 --第几次在职
,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt) as hps_hire_date
,case when hps_d_hr_status = '离职' then '离职' else 
datediff(new_dt,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt))
end as hire_date_num
from
(
select
t1.dt
,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,t1.hps_dept_code_lv5 as store_code
,t1.emplid
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,name
,t1.hps_hire_dt
,t3.leave_dt
,case when t3.leave_dt = '2035-12-31' then '在职'
when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
else '离职' end as hps_d_hr_status --在离职状态
,t1.hps_hire_type --用工形式
,t1.hps_d_jobcode
,t1.hps_dept_descr_lv1
,t1.hps_d_city
,t1.hps_dept_code_lv5
,t1.hps_dept_descr_lv5
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
where t1.dt >= 20210318
) a
),

raw_list as( --更新入职日期，防止换签导致的入职日期刷新
select
t.dt
,t.new_dt --日期
,t.store_code --门店编码
,t.emplid
,t.employee_id
,t.name
,t.hps_hire_dt --系统雇佣时间(没用)
,t.leave_dt --离职日期
,t.hps_d_hr_status --在离职状态
,t.hps_hire_type
,t.hps_d_jobcode
,t.hps_dept_descr_lv1
,t.hps_d_city
,t.hps_dept_code_lv5
,t.hps_dept_descr_lv5
,t.rn_1 --按照人*时间维度排序
,t.rn_2 --第几次入职
,t.hps_hire_date --本次雇佣周期开始日期(真实的入职日期)
,t.hire_date_num --本次雇佣周期时长
from staff_list t
)

,t30_work_reference as (
    select 
        date_key
        ,sum(is_work_day) over(order by date_key desc) as t30_work_day_cnts
    from (
        select distinct
            date_key
            ,is_work_day
        from work_reference
    ) t0
    where t0.date_key >= '${TODAY-30}' and t0.date_key <= '${TODAY-1}'
)

,cum_attend_info as ( --part1.工龄
    select
        t1.employee_no
        ,sum(coalesce(attendance_work_hours,0)) as cum_attend_hours
        ,count(distinct work_shift_date) as total_attend_days
        ,sum(case when date_format(t1.work_shift_date,'yyyyMMdd') >= 
            date_format(t2.hps_hire_date,'yyyyMMdd') then t1.attendance_work_hours end) as cum_attendance_work_hours_after_entry
    from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    --inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
    inner join raw_list t2
    on t1.employee_no = t2.emplid and t2.new_dt = '${TODAY-1}'
    where t1.dt = '${today-1}'
        and t1.work_shift_type in (1,9,12)
       -- and t2.hps_d_hr_status in ('在职')
        and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
        and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        -- and date_format(t1.work_shift_date,'yyyyMMdd') >= date_format(t2.hps_hire_dt,'yyyyMMdd')
    group by
        t1.employee_no
)

,attend_shift_detail as ( --出勤工时底表
    select 
        emplid
        ,work_shift_id
        ,attend_date
        ,work_shift_hours
        ,attendance_work_hours
        ,t1.is_work_day
        ,coalesce(arrive_late_hour,0) as arrive_late_hour
        ,coalesce(leave_early_hour,0) as leave_early_hour
        ,coalesce(absenteeism_hour,0) as absenteeism_hour
        ,coalesce(arrive_late_hour,0) + coalesce(leave_early_hour,0) + coalesce(absenteeism_hour,0) as ab_attend_hour

        ----延长打卡时间不超过4小时
        ,case when early_arrive_hour >= 0 and early_arrive_hour <= 4 then early_arrive_hour else 0 end as early_arrive_hour
        ,case when late_leave_hour >= 0 and late_leave_hour <= 4 then late_leave_hour else 0 end as late_leave_hour
    from (
        select
            employee_no as emplid
            ,work_shift_id
            ,date_format(work_shift_date, 'yyyy-MM-dd') as attend_date
            ,sum(work_shift_hours) as work_shift_hours
            ,sum(attendance_work_hours) as attendance_work_hours
            --,sum(arrive_late_count)/2 as arrive_late_hour
            ,sum(case when arrive_late_minutes < 30 then 0 else arrive_late_minutes end)/60 as arrive_late_hour --0808改：迟到30分钟不算迟到，直接按照分钟换算成小时
            ,sum(leave_early_count)/2 as leave_early_hour
            ,sum(absenteeism_hours) as absenteeism_hour
            ,floor(sum((unix_timestamp(work_shift_start_time) - unix_timestamp(punch_start_time))) / 3600 / 0.5)/2 as early_arrive_hour
            ,floor(sum((unix_timestamp(punch_end_time) - unix_timestamp(work_shift_end_time))) / 3600 / 0.5)/2 as late_leave_hour
        from data_shop.pdw_opc_shop_attendance_report_work_shift_view
        where dt = '${today-1}'
            and date_format(work_shift_date, 'yyyyMMdd') >= '${today-30}'
            and work_shift_type in (1,9,12)
        group by employee_no,work_shift_id,date_format(work_shift_date, 'yyyy-MM-dd')
    ) t0
    left join work_reference t1
    on t0.attend_date = t1.date_key
)

,t30_attend_info as ( --part2.实际出勤
    select 
        t1.emplid
        ,sum(t1.work_shift_hours) as work_shift_hours
        ,sum(t1.attendance_work_hours) as attendance_work_hours
        ,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_date,'yyyyMMdd') 
            then t1.work_shift_hours end) as work_shift_hours_after_entry
        ,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_date,'yyyyMMdd') 
            then t1.attendance_work_hours end) as attendance_work_hours_after_entry
        ,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_date,'yyyyMMdd') 
            and t1.is_work_day = '1' then t1.attendance_work_hours end) as workday_attend_hours_after_entry
        ,sum(t1.arrive_late_hour) as arrive_late_hour
        ,sum(t1.leave_early_hour) as leave_early_hour
        ,sum(t1.absenteeism_hour) as absenteeism_hour
        ,sum(t1.ab_attend_hour) as ab_attend_hour
        ,sum(t1.early_arrive_hour) as early_arrive_hour
        ,sum(t1.late_leave_hour) as late_leave_hour
        ,count(distinct case when t1.arrive_late_hour>0 or t1.leave_early_hour >0 then t1.attend_date end) as t30_leave_arrive_cnts
    from attend_shift_detail t1
    --inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
    inner join raw_list t2
    on t1.emplid = t2.emplid and t2.new_dt = '${TODAY-1}'
        and t2.hps_d_hr_status in ('在职')
        and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
        and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    group by t1.emplid
)

,ab_vac_detail as (
    select
        order_id
        ,if(length(leavepeople)<8,concat('10',leavepeople),leavepeople) as staff_code
        ,leavename as employee_name
        ,roster_shopcode as store_code
        ,roster_shopname as store_name
        ,shopcode as dept_code
        ,date_format(create_date,'yyyy-MM-dd') as vac_apply_date
        ,penalty_roster_hours --最终惩处工时
    from data_shop.app_internal_control_vacation_da_view
    where dt = '${today-1}'
        and date_format(create_date, 'yyyyMMdd') >= '${today-30}'
        and is_exemption_eliminate = 0
)

,ab_vac_info as ( --t30违规请假惩处工时
    select 
        staff_code
        ,sum(penalty_roster_hours) as t30_sum_penalty_roster_hours
    from ab_vac_detail
    group by staff_code
)

,avail_hours_info as ( --可用小时
    select 
        lpad(staff_code,8,'10') as staff_code
        ,date_format(date_key,'yyyy-MM-dd') as roster_date
        -- ,date_sub(next_day(date_key,'mon'),7) as roster_week --周
        ,count(distinct case when is_give_roster = 1 and is_vacation = 0 
            and is_dimission_apply_available = 1 and is_health_cer_right = 1 
            and is_in_black_list = 0 then rk_of_half_hour end)/2 as avail_hours --可用小时（给班&未请假&未离职&健康证可用&不在黑名单）
    from data_shop.dm_roster_staff_half_hour_roster_and_attendance_quantity_di_view t1
    where dt = '${today-1}'
        and hps_d_hr_status = '在职'
        and date_key --本周和未来一周--本周和未来四周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7) 
            and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),27) 
        -- and is_store_manager = 0 --非架构负责人
    group by 
        staff_code
        ,date_key
        -- ,date_sub(next_day(date_key,'mon'),7)
)

,give_standard_detail as (
    select
        date_format(roster_date,'yyyy-MM-dd') as roster_date
        ,employee_id
        ,IF(LENGTH(employee_id)<8,concat('10',employee_id),employee_id) as staff_code
        ,givetype
        ,case when givetype in ('全天可开工','夜晚可开工','白天可开工') then '1' else '0' end as is_give_standard
        ,case when givetype in ('全天可开工') then '1' else '0' end as is_give_full
    from data_shop.dw_roster_give_roster_detail_snapshot_da_view t1
    where t1.dt = '${today-1}'
        and t1.roster_date --本周和未来一周--本周和未来四周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7) 
            and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),27) 
)

,avial_days_info as (
    select distinct 
        t1.staff_code
        ,date_format(t1.target_date,'yyyy-MM-dd') as roster_date
        -- ,date_sub(next_day(t1.target_date,'mon'),7) as roster_week --周
        ,case when is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1'
            then '1' else '0' end as is_available_roster
        ,case when (is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1') 
            and is_give_standard = '1' then '1' else '0' end as is_standard
        ,case when (is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1') 
            and is_give_full = '1' then '1' else '0' end as is_full
        ,t2.givetype
    from data_shop.dm_roster_staff_available_di_view t1
    left join give_standard_detail t2
    on t1.staff_code = t2.staff_code 
        and date_format(t1.target_date,'yyyy-MM-dd') = date_format(t2.roster_date,'yyyy-MM-dd')
    where t1.dt = '${today-1}'
        and t1.target_date --本周和未来一周--本周和未来4周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7)
            and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),27)
)

,avail_detail as ( --天维度可用整理
    select distinct
        t1.staff_code
        ,t1.roster_date
        ,if(t1.avail_hours > 12, 12, t1.avail_hours) as avail_hours
        ,coalesce(t2.is_available_roster,0) as is_avail_day
        ,coalesce(t2.is_standard,0) as is_standard
        ,coalesce(t2.is_full,0) as is_full
        ,coalesce(t2.givetype,'未自主给班') as give_type
        ,t3.day_of_week
        ,t3.is_work_day
    from avail_hours_info t1
    left join avial_days_info t2
    on lpad(t1.staff_code,8,'10') = lpad(t2.staff_code,8,'10') and t1.roster_date = t2.roster_date
    left join work_reference t3
    on t1.roster_date = t3.date_key
)

-- ,is_give as ( --历史代码：做80%给班天数的筛选，弃用
--     select 
--         roster_date
--         ,count(distinct staff_code) as staff_cnts
--         ,count(distinct case when give_type = '未自主给班' then staff_code end) as ungive_cnts
--         ,count(distinct case when give_type = '未自主给班' then staff_code end)/count(distinct staff_code) as ungive_rate
--     from avail_detail
--     group by roster_date
-- )

,avail_info as ( --part3.未来可用
    select 
        t1.staff_code
        ,count(distinct t1.roster_date) as total_day_cnts
        ,count(distinct case when t1.is_work_day = '1' then t1.roster_date end) as work_day_cnts
        ,sum(t1.avail_hours) as total_avail_hours
        ,sum(case when t1.is_work_day = '1' then t1.avail_hours end) as work_day_avail_hours
        ,count(distinct case when t1.is_avail_day = '1' then t1.roster_date end) as total_avail_days
        ,count(distinct case when t1.is_work_day = '1' and t1.is_avail_day = '1' then t1.roster_date end) as work_day_avail_days
        ,count(distinct case when t1.is_avail_day = '1' and t1.is_standard = '1' then t1.roster_date end) as total_standard_avail_days
        ,count(distinct case when t1.is_work_day = '1' and t1.is_avail_day = '1' and t1.is_standard = '1' then t1.roster_date end) as work_day_standard_avail_days
        ,count(distinct case when t1.is_avail_day = '1' and t1.is_full = '1' then t1.roster_date end) as total_full_avail_days
        ,count(distinct case when t1.is_work_day = '1' and t1.is_avail_day = '1' and t1.is_full = '1' then t1.roster_date end) as work_day_full_avail_days
    from avail_detail t1
    -- inner join is_give t0
    -- on t1.roster_date = t0.roster_date and t0.ungive_rate < 0.8
    group by t1.staff_code
)

,avial_days_fluc_detail as ( --可用波动
    select distinct 
        t1.staff_code
        ,date_format(t1.target_date,'yyyy-MM-dd') as roster_date
        ,date_sub(next_day(t1.target_date,'mon'),7) as roster_week --周
        ,case when is_available_roster_day = '1' or is_available_roster_night = '1' or is_available_roster = '1'
            then '1' else '0' end as is_available_roster
    from data_shop.dm_roster_staff_available_di_view t1
    inner join work_reference t3
    on date_format(t1.target_date,'yyyy-MM-dd') = t3.date_key and t3.is_work_day = '1' --只看工作日
    where t1.dt = '${today-1}'
        and t1.target_date --过去四周+本周+未来四周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),35)
            --and date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),1)
            and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),27) 
)

,avial_days_fluc_pivot as ( --周度可用pivot
    select 
        staff_code
        ,roster_week
        ,count(distinct case when is_available_roster = '1' then roster_date end) as avial_days
        ,count(distinct roster_date) as total_days
        ,count(distinct case when is_available_roster = '1' then roster_date end)/count(distinct roster_date) as avail_days_rate
    from avial_days_fluc_detail
    group by 
        staff_code
        ,roster_week
)

,avial_days_fluc_info as ( --part3.2可用波动
    -- select 
    --     t1.staff_code
    --     ,t1.roster_week
    --     ,t1.avial_days
    --     ,t1.total_days
    --     ,t1.avail_days_rate
    --     ,t2.std_avail_days_rate
    -- from avial_days_fluc_pivot t1
    -- left join (
        select 
            staff_code
            ,stddev_samp(avail_days_rate) as std_avail_days_rate
        from avial_days_fluc_pivot t1
        group by staff_code
    -- ) t2
    -- on t1.staff_code = t2.staff_code
)

,sop_learn_detail as ( --蜂窝学习明细-任务维度聚合
    select 
        title
        ,emplid
        ,count(1) as mission_cnts
        ,sum(finis_percent)/100 as finish_cnts
    from (
        select distinct
            title
            ,source_name
            ,usercode as emplid
            ,mission_type
            ,sub_mission_type
            ,createtime
            ,class_hour
            ,finis_percent
        from data_shop.dwa_shop_sop_learn_exam_result_v1 t1
        inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
        on t1.usercode = t2.emplid  and t2.dt = '${today-1}'
            and t2.hps_d_hr_status in ('在职')
            and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
            and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        where t1.dt = '${today-1}' --只有最新dt有数
            and subplantype = 'clerkSop'
            and date_format(createtime,'yyyyMMdd') >= '${today-30}'
    ) t0
    group by 
        title
        ,emplid
)

,sop_learn_info as ( --part4.1蜂窝学习完成率=sop_finish_cnts/sop_issue_cnts
    select 
        emplid
        ,count(distinct title) as sop_issue_cnts
        ,count(distinct case when finish_cnts/mission_cnts=1 then title end) as sop_finish_cnts
        ,count(distinct case when finish_cnts/mission_cnts=1 then title end)/count(distinct title) as sop_learn_rate
    from sop_learn_detail
    group by emplid
)

,course_info as ( --part4.2课程覆盖率
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
    where t1.dt = '${today-1}'
),

final_list as(
select
    distinct
    t1.emplid
    ,lpad(t1.emplid,8,'10') as staff_code
    ,t1.name as staff_name
    ,t1.hps_d_city as city_name
    ,t1.hps_d_jobcode as position_cn
    ,case when t7.store_manager_no is not null then '1' else '0' end as is_store_manager
    ,t1.hps_dept_code_lv5 as store_code
    ,t1.hps_dept_descr_lv5 as store_name
    ,date_format(t1.hps_hire_date,'yyyy-MM-dd') as entry_date
    -- ,case when t7.store_manager_no is null and coalesce(t2.cum_attendance_work_hours_after_entry,0) >= 60 then '店员标签' end as is_tag

    -- --常规项
    -- ,coalesce(t2.cum_attend_hours,0) as `累计出勤工时`
    -- ,round(case when datediff(to_date('${TODAY}'),t1.hps_hire_dt) < 30 then
    --     coalesce(attendance_work_hours_after_entry,0)/datediff(to_date('${TODAY}'),t1.hps_hire_dt) * 30
    --     else coalesce(attendance_work_hours_after_entry,0) end,4) as `0-模拟t30出勤小时`
    -- ,round(coalesce(work_day_avail_days,0)/coalesce(work_day_cnts,0),4) as `0-工作日可用天数占比`
    -- ,round(coalesce((coalesce(t3.ab_attend_hour,0) + coalesce(t9.t30_sum_penalty_roster_hours,0))/
    --     (coalesce(t3.work_shift_hours,0) + coalesce(t9.t30_sum_penalty_roster_hours,0)),0),4) as `0-迟早旷+违规请假工时占比`
    -- ,coalesce(t3.t30_leave_arrive_cnts,0) as `t30迟早次数`
    -- --加分项
    -- ,round(coalesce(coalesce(t5.sop_finish_cnts,0)/coalesce(t5.sop_issue_cnts,0),0),4) as `蜂窝学习完成率`
    -- ,round((coalesce(total_avail_days,0) - coalesce(work_day_avail_days,0))/
    --     (coalesce(total_day_cnts,0) - coalesce(work_day_cnts,0)),4) as `0-节假日给班`
    -- ,round(coalesce(coalesce(work_day_full_avail_days,0)/coalesce(work_day_avail_days,0),0),4) as `0-工作日全天占比`
    -- --减分项
    -- ,round(coalesce(coalesce(work_day_standard_avail_days,0)/coalesce(work_day_avail_days,0),0),4) as `0-工作日标准占比`
    -- ,round(coalesce(t8.std_avail_days_rate,'NA'),4) as `0-工作日可用占比std`

    --底数
    ,coalesce(t2.cum_attend_hours,0) as cum_attend_hours --累计出勤工时
    ,coalesce(total_attend_days,0) as total_attend_days --累计出勤天数
    ,coalesce(t2.cum_attendance_work_hours_after_entry,0) as cum_attend_hours_after_entry --入职后出勤工时(卡二次入职)
    ,datediff(to_date('${TODAY}'),t1.hps_hire_date) as total_entry_days --入职至今的天数
    ,coalesce(t3.work_shift_hours,0) as t30_work_shift_hours --t30排班工时
    ,coalesce(t3.attendance_work_hours,0) as t30_attendance_work_hours --t30出勤工时
    ,coalesce(t3.work_shift_hours_after_entry,0) as t30_work_shift_hours_after_entry --t30入职后排班工时(卡二次入职)
    ,coalesce(t3.attendance_work_hours_after_entry,0) as t30_attend_hours_after_entry --t30入职后出勤工时(卡二次入职)
    ,coalesce(t3.arrive_late_hour,0) as t30_arrive_late_hour
    ,coalesce(t3.leave_early_hour,0) as t30_leave_early_hour
    ,coalesce(t3.absenteeism_hour,0) as t30_absenteeism_hour
    ,coalesce(t9.t30_sum_penalty_roster_hours,0) as t30_sum_penalty_roster_hours --t30违规请假惩处小时数
    -- ,coalesce(t3.ab_attend_hour,0) as t30_ab_attend_hour --t30迟早旷小时数
    ,coalesce(t3.t30_leave_arrive_cnts,0) as t30_ab_leave_arrive_cnts --t30迟早次数
    -- ,coalesce(t3.ab_attend_hour,0) + coalesce(t9.t30_sum_penalty_roster_hours,0) as ab_roster_hour --t30考勤类违规小时数
    ,coalesce(t3.early_arrive_hour,0) as t30_early_arrive_hour
    ,coalesce(t3.late_leave_hour,0) as t30_late_leave_hour
    -- ,coalesce(t3.early_arrive_hour,0) + coalesce(t3.late_leave_hour,0) as over_punch_hour --t30义务打卡时间
    ,coalesce(total_day_cnts,0) as total_day_cnts --未来给班天数
    ,coalesce(work_day_cnts,0) as work_day_cnts --未来工作日给班天数
    -- ,coalesce(total_avail_hours,0) as total_avail_hours --未来可用小时数
    -- ,coalesce(work_day_avail_hours,0) as work_day_avail_hours --未来工作日可用小时数
    ,coalesce(total_avail_days,0) as total_avail_days --未来可用天数
    ,coalesce(work_day_avail_days,0) as work_day_avail_days --未来工作日可用天数
    -- ,coalesce(total_standard_avail_days,0) as total_standard_avail_days --未来标准可用天数
    -- ,coalesce(work_day_standard_avail_days,0) as work_day_standard_avail_days --未来工作日标准可用天数
    ,coalesce(total_full_avail_days,0) as total_full_avail_days --未来全天可用天数
    ,coalesce(work_day_full_avail_days,0) as work_day_full_avail_days --未来工作日全天可用天数
    ,coalesce(t5.sop_issue_cnts,0) as t30_sop_issue_cnts
    ,coalesce(t5.sop_finish_cnts,0) as t30_sop_finish_cnts
    ,round(coalesce(coalesce(t5.sop_finish_cnts,0)/coalesce(t5.sop_issue_cnts,0),0),4) as sop_learn_rate --蜂窝学习完成率
    -- ,coalesce(t6.learn_tag,'D') as learn_tag --课程覆盖率（新人训/初级/进阶/店长）
    ,coalesce(t8.std_avail_days_rate,null) as std_avail_days_rate --5周+可用波动

    ,coalesce(t3.workday_attend_hours_after_entry,0) as t30_workday_attend_hours_after_entry
    ,coalesce(t10.t30_work_day_cnts,0) as t30_work_day_cnts_after_entry
--from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1
from raw_list t1
left join cum_attend_info t2
on lpad(t1.emplid,8,'10') = lpad(t2.employee_no,8,'10')
left join t30_attend_info t3
on lpad(t1.emplid,8,'10') = lpad(t3.emplid,8,'10')
left join avail_info t4
on lpad(t1.emplid,8,'10') = lpad(t4.staff_code,8,'10')
left join sop_learn_info t5
on lpad(t1.emplid,8,'10') = lpad(t5.emplid,8,'10')
left join course_info t6
on lpad(t1.emplid,8,'10') = lpad(t6.staff_code,8,'10')
left join data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t7
on t7.dt = '${today-1}' and lpad(t1.emplid,8,'10') = lpad(t7.store_manager_no,8,'10')
left join avial_days_fluc_info t8
on lpad(t1.emplid,8,'10') = lpad(t8.staff_code,8,'10')
left join ab_vac_info t9
on lpad(t1.emplid,8,'10') = lpad(t9.staff_code,8,'10')
left join t30_work_reference t10
on (case when date_format(t1.hps_hire_date,'yyyyMMdd') < '${today-30}' then '${TODAY-30}' 
    else date_format(t1.hps_hire_date,'yyyy-MM-dd') end) = t10.date_key
where t1.new_dt = '${TODAY-1}'
    and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
    and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and t1.hps_d_hr_status = '在职'
)

select emplid,
staff_code,
staff_name,
city_name,
position_cn,
is_store_manager,
store_code,
store_name,
entry_date,
cum_attend_hours,
total_attend_days,
cum_attend_hours_after_entry,
total_entry_days,
t30_work_shift_hours,
t30_attendance_work_hours,
t30_work_shift_hours_after_entry,
t30_attend_hours_after_entry,
t30_arrive_late_hour,
t30_leave_early_hour,
t30_absenteeism_hour,
t30_sum_penalty_roster_hours,
t30_ab_leave_arrive_cnts,
t30_early_arrive_hour,
t30_late_leave_hour,
total_day_cnts,
work_day_cnts,
total_avail_days,
work_day_avail_days,
total_full_avail_days,
work_day_full_avail_days,
t30_sop_issue_cnts,
t30_sop_finish_cnts,
std_avail_days_rate,
t30_workday_attend_hours_after_entry,
t30_work_day_cnts_after_entry
from final_list