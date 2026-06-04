************************************************************************************************************************************
--钻石机动队标签--data_build.dwd_dwd_district_staff_protect_tag_v2_da_di
with base_tag as 
(
    select
    emplid
    ,staff_code
    ,staff_name
    ,city_name
    ,position_cn
    ,store_code
    ,store_name
    ,entry_date
    ,protect_tag_raw
    ,protect_tag_detail
    from data_build.dwd_district_staff_protect_tag_v1_da
    where dt = '${today-1}'
)
-- 带过店的机动队店长得分
,manager_score as (
    select 
    t1.employee_id
    ,t1.store_code
    ,t1.performance_score 
    ,t1.store_score
    ,t1.dt
    ,(0.5*t1.performance_score + 0.5*t1.store_score) as score_new

    from (
    select 
    t1.employee_id
    ,t1.name
    ,t1.store_code
    ,t1.will_score
    ,t1.performance_score 
    ,t1.store_score
    ,t1.manage_score
    ,t1.total_score_base
    ,t1.total_score
    ,t1.dt
    ,row_number() over(partition by t1.employee_id,t1.store_code order by dt desc) as rn
    from data_build.dwd_district_manager_tag_v1_di t1
    where dt <= '${today-1}'
    ) t1
    where rn = 1
)
,manager_result as (
    select 
    -- 带店数量及平均得分
    employee_id
    ,count(distinct store_code) as store_num_total 
    ,avg(score_new) as score_avg
    from manager_score  
    group by employee_id
)
-- 全量陪跑效果
,peipao_info as (
    select distinct 
    staff_code
    ,manager_code
    ,hps_d_hr_status
    ,class
    ,class_new
    ,tag_date
    ,start_date_new
    ,end_date_new
    ,type0
    ,total_work_shift_hours
    from data_build.dwd_district_staff_peipao_v1_di
    where is_chuqin_over_120= 1
    and is_over_7days = 1
    and dt <= '${today-1}'
)
-- 陪跑店长数及好店长占比
,peipao_result as (
    select 
    staff_code
    ,count(distinct manager_code) as manager_num_total
    ,count(distinct case when class_new in ('金牌','优质银牌','钻石') then manager_code else null end) as manager_num_good
    ,count(distinct case when class_new in ('金牌','优质银牌','钻石') then manager_code else null end)/count(distinct manager_code) as good_manager_per
    from peipao_info
    group by staff_code
)
-- 晋升黑名单
,transfer_blacklist as(
    select distinct
    staff_code
    from data_shop.dwd_manager_transfer_blacklist_v1_di
    where dt = '${today-1}'
)
select 
tt.emplid
    ,tt.staff_code
    ,tt.staff_name
    ,tt.city_name
    ,tt.position_cn
    ,tt.store_code
    ,tt.store_name
    ,tt.entry_date
    ,tt.protect_tag_raw
    ,tt.protect_tag_detail
    ,tt.store_num_total
    ,tt.score_avg
    ,tt.manager_num_total
    ,tt.manager_num_good
    ,tt.good_manager_per
    ,tt.store_quality
    ,tt.peipao_quality
    -- 本来是金银牌，带店质量好则钻石
    ,case when tt.protect_tag_detail <= 2 and tt.store_quality >0 and tt.store_quality < 4
    and ttt.staff_code is null --0617新增规则，晋升黑名单里的人禁止成为钻石机动队
     then 0
    --0522改：只是陪跑质量好的应该是金牌 
        -- when tt.protect_tag_detail <= 2 and tt.peipao_quality >0 then 0
        when tt.protect_tag_detail <= 2 and tt.peipao_quality >0 then 1
        -- 本来是金银牌，带店质量差则掉到铜牌须努力
        -- when tt.protect_tag_detail <= 2 and tt.store_quality >=4 then tt.store_quality
        -- else tt.protect_tag_detail end as protect_tag_detail_new
        -- 带店质量差调整为减分项
        when (case when tt.protect_tag_detail <= 2 and tt.store_quality = 4 then protect_tag_raw + 1.0
            when tt.protect_tag_detail <= 2 and tt.store_quality = 5 then protect_tag_raw + 1.5 else null end) < 1.5 then 1

        when (case when tt.protect_tag_detail <= 2 and tt.store_quality = 4 then protect_tag_raw + 1.0
            when tt.protect_tag_detail <= 2 and tt.store_quality = 5 then protect_tag_raw + 1.5 else null end) < 2.5 and protect_tag_raw < 2.2 then 1.5 --0617增加机动队优质银牌逻辑

        when (case when tt.protect_tag_detail <= 2 and tt.store_quality = 4 then protect_tag_raw + 1.0
            when tt.protect_tag_detail <= 2 and tt.store_quality = 5 then protect_tag_raw + 1.5 else null end) < 2.5 then 2
             
        when (case when tt.protect_tag_detail <= 2 and tt.store_quality = 4 then protect_tag_raw + 1.0
            when tt.protect_tag_detail <= 2 and tt.store_quality = 5 then protect_tag_raw + 1.5 else null end) < 4.5 then 4
        
        else tt.protect_tag_detail end as protect_tag_detail_new
from (
select 
t0.emplid
    ,t0.staff_code
    ,t0.staff_name
    ,t0.city_name
    ,t0.position_cn
    ,t0.store_code
    ,t0.store_name
    ,t0.entry_date
    ,t0.protect_tag_raw
    ,case when t0.protect_tag_detail = 2 and t0.protect_tag_raw < 2.2 then 1.5 else t0.protect_tag_detail end as protect_tag_detail --0617新增机动队优质银牌逻辑
    ,coalesce(t1.store_num_total,0) as store_num_total
    ,coalesce(t1.score_avg,0) as score_avg
    ,coalesce(t2.manager_num_total,0) as manager_num_total
    ,coalesce(t2.manager_num_good,0) as manager_num_good
    ,coalesce(t2.good_manager_per,0) as good_manager_per
    ,case when coalesce(t1.score_avg,0) > 3.4 then 1 -- 带店质量超过3.4则质量好
        when coalesce(t1.store_num_total,0) >0 and coalesce(t1.score_avg,0) < 2 then 5 -- 带店质量<2则带店质量须努力
        when coalesce(t1.store_num_total,0) >0 and coalesce(t1.score_avg,0) < 3 then 4 -- 带店质量<3则带店质量铜牌
        else 0 end as store_quality 
    -- 陪跑好店长占比超过50%，则陪跑质量好
    ,case when coalesce(t2.good_manager_per,0) >0.5 then 1 else 0 end as peipao_quality 
    
from base_tag t0 
left join manager_result t1 on t0.staff_code = t1.employee_id
left join peipao_result t2 on t0.staff_code = t2.staff_code
) tt
left join transfer_blacklist ttt on tt.emplid = ttt.staff_code

**********************************************************************************************************************************************************************************
**********************************************************************************************************************************************************************************
**********************************************************************************************************************************************************************************

--机动队店长标签--data_build.dwd_district_manager_tag_v1_di
with 
-- 门店类型
location_type_list as (
select 
t2.store_code
,max(case when location_type in ('办公+其他','写字楼','办公+居民','居民+办公') then '办公' 
when location_type in ('居民+其他','居民+其它','住宅') then '居民' 
when location_type = '混合' then '其他'
else location_type end) as location_type
from data_build.dm_site_selection_project_feature_info_di t2 

where t2.dt <= '20221114'
group by t2.store_code
),
-- 是否工作日、是否节假日
work_day_list as(
select
date_key
,is_working_day
,is_holiday
from data_build.dim_date_ya_v2
where date_key >= '${TODAY-30}'
and date_key <= '${TODAY-1}'
group by
date_key
,is_working_day
,is_holiday
),

-- t30员工名单
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

-- 计算周期
base_manager_info as (
    select store_code,
employee_id,
name,
store_name,
city_name,
difficulty_level_new,
entry_date,
entry_days,
change_date0,
cal_days_0,
change_date,
cal_days,
start_cdate,
cal_days_14,
change_date_14,
b_manager_date,
b_manager_days,
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as work_dt
from data_build.dwd_store_construction_district_manager_base_info0_di
where dt ='${today-1}' 
),


attend_shift_info0 as 
( --排班工时底表
 select
 if(length(employee_no)<8,concat('10',employee_no),employee_no) as staff_code
 ,employee_no as emplid
 ,month(work_shift_date) as mon_of_attend_date
 ,date_sub(next_day(work_shift_date,'mon'),7) as roster_week
 ,date_format(work_shift_date, 'yyyy-MM-dd') as attend_date
 ,sum(work_shift_hours) as work_shift_hours
 ,sum(attendance_work_hours) as attendance_work_hours
 ,sum(arrive_late_count)/2 as arrive_late_hour
 ,sum(leave_early_count)/2 as leave_early_hour
 ,sum(absenteeism_hours) as absenteeism_hour
 ,floor(sum((unix_timestamp(work_shift_start_time) - unix_timestamp(punch_start_time))) / 3600 / 0.5)/2 as early_arrive_hour
 ,floor(sum((unix_timestamp(punch_end_time) - unix_timestamp(work_shift_end_time))) / 3600 / 0.5)/2 as late_leave_hour
 from data_build.pdw_opc_shop_attendance_report_work_shift_view
 where dt = '${today-1}'
 and work_shift_date >= '${TODAY-30}'
 and work_shift_date <= '${TODAY-1}'
 and work_shift_type in (1,9,12)
 group by 
 if(length(employee_no)<8,concat('10',employee_no),employee_no) 
 ,employee_no 
 ,month(work_shift_date)
 ,date_sub(next_day(work_shift_date,'mon'),7)
 ,date_format(work_shift_date, 'yyyy-MM-dd')
),
attend_shift_detail as ( 
    --出勤工时底表
 select distinct
 emplid
 ,staff_code
 ,attend_date
 ,work_shift_hours
 ,case when work_shift_hours >= 4 then 1 else 0 end as is_over_10 -- 改为4小时20231128
 ,case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.change_date,'yyyyMMdd') then 1 else 0 end as is_start
 ,case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.change_date,'yyyyMMdd') then t1.work_shift_hours end work_shift_hours_after_change
 ,roster_week
 ,mon_of_attend_date
 ,attendance_work_hours
 ,change_date0
 ,change_date
 ,cal_days_0
 ,cal_days
 ,coalesce(arrive_late_hour,0) as arrive_late_hour
 ,coalesce(leave_early_hour,0) as leave_early_hour
 ,coalesce(absenteeism_hour,0) as absenteeism_hour
 ,coalesce(arrive_late_hour,0) + coalesce(leave_early_hour,0) + coalesce(absenteeism_hour,0) as ab_attend_hour
 ----延长打卡时间不超过4小时
 ,case when early_arrive_hour >= 0 and early_arrive_hour <= 4 then early_arrive_hour else 0 end as early_arrive_hour
 ,case when late_leave_hour >= 0 and late_leave_hour <= 4 then late_leave_hour else 0 end as late_leave_hour
 ,t3.is_working_day
 ,t3.is_holiday -- 是否法定节假日，周末不是法定节假日
 from attend_shift_info0 t1
 left join base_manager_info t2 on t1.staff_code = t2.employee_id
 left join work_day_list t3
    on t1.attend_date = t3.date_key
 ),

 t30_attend_info as ( --part2.实际出勤
 select 
 t1.staff_code
 ,t1.emplid
-- ,t1.mon_of_attend_date
 ,change_date
 ,change_date0
 ,cal_days_0
 ,cal_days
 ,count(distinct case when is_over_10 = 1 then t1.attend_date end) as work_day_attend_cnts -- 总超过4小时的出勤天数
 ,sum(t1.is_working_day) as work_day_cnts -- 工作日天数
 ,count(distinct case when t1.is_working_day = '0' and is_over_10 = 1 then t1.attend_date end) as holiday_attend_cnts -- 节假日出勤天数
 ,sum(case when t1.is_working_day = '0' then 1 else 0 end) as holiday_day_cnts -- 节假日天数
 ,count(distinct case when t1.is_holiday = '1' and is_over_10 = 1 then t1.attend_date end) as holiday_2_attend_cnts -- 法定节假日出勤天数
 ,sum(t1.work_shift_hours) as work_shift_hours
 ,sum(t1.attendance_work_hours) as attendance_work_hours
 ,sum(work_shift_hours_after_change) as work_shift_hours_after_change --t30出勤工时
 --,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_dt,'yyyyMMdd') then t1.attendance_work_hours end) as attendance_work_hours_after_entry
 ,sum(t1.arrive_late_hour) as arrive_late_hour
 ,sum(t1.leave_early_hour) as leave_early_hour
 ,sum(t1.absenteeism_hour) as absenteeism_hour
 ,sum(t1.ab_attend_hour) as ab_attend_hour
 ,sum(t1.early_arrive_hour) as early_arrive_hour
 ,sum(t1.late_leave_hour) as late_leave_hour
 ,count(distinct case when t1.arrive_late_hour>0 or t1.leave_early_hour >0 then t1.attend_date end) as t30_leave_arrive_cnts
 from attend_shift_detail t1

 group by t1.staff_code
 ,t1.emplid
 -- ,t1.mon_of_attend_date
 ,change_date
 ,change_date0
 ,cal_days_0
 ,cal_days
),
-- 蜂利器超时任务 by 人 豁免一周
user_task_tmp0 as (
 SELECT
 order_id,
 taskorder_id,
 taskorder_node_id,
 taskorder_create_time as create_time,
 taskorder_update_time as update_time,
 taskorder_status,
 task_orders,
 taskorder_handler,
 date_format(taskorder_create_time, 'yyyy-MM-dd') AS create_day,
 taskorder_deadline_time as deadline_time,
 IF(taskorder_status = 'NEW_ORDER',taskorder_assignee,taskorder_handler) AS assignee
 --,IF(taskorder_status = 'FINISHED',date_format(taskorder_update_time, 'yyyy-MM-dd'),'yyyy-mm-dd') AS finish_day
 FROM
 data_build.pdw_order_store_211_order_detail_flow_task_taskorders
 WHERE dt ='${today-1}'
 and taskorder_create_time >= '${TODAY-30}'
 and taskorder_create_time <= '${TODAY-1}'
),
user_task_tmp as (
select order_id,
 taskorder_id,
 taskorder_node_id,
create_time,
create_day,
 update_time,
 taskorder_status,
 task_orders,
 taskorder_handler,
 deadline_time,
 assignee[0] as assignee
from user_task_tmp0),

taskorder_list as (
   select 
    dt
    ,new_dt
    ,t1.store_code
    ,t1.employee_id
    ,assignee
    ,if(length(assignee)<8,concat('10',assignee),assignee) as assignee2
    ,order_id
    ,taskorder_status
    ,taskorder_handler
    ,create_time
    ,update_time
    ,t2.deadline_time
    ,case when taskorder_status = 'FINISHED' and unix_timestamp(deadline_time) < unix_timestamp(update_time) and unix_timestamp(deadline_time) > unix_timestamp(create_time)
     and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then 1
   when taskorder_status != 'FINISHED' and day(deadline_time) < day(new_dt) and unix_timestamp(deadline_time) > unix_timestamp(create_time) 
   and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then 1 
   else 0 end as is_delay
   ,case when taskorder_status = 'FINISHED' and unix_timestamp(deadline_time) < unix_timestamp(update_time) and unix_timestamp(deadline_time) > unix_timestamp(create_time) and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then (unix_timestamp(update_time) - unix_timestamp(deadline_time)) / 3600 
   when taskorder_status != 'FINISHED' and unix_timestamp(deadline_time) < unix_timestamp(new_dt) and unix_timestamp(deadline_time) > unix_timestamp(create_time) 
   and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then (unix_timestamp(new_dt) - unix_timestamp(deadline_time)) / 3600 
   else 0 end as delay_hours
   ,case when create_day >= start_cdate then 1 else 0 end as is_start
    from staff_list t1 
    left join user_task_tmp t2 on t1.employee_id = if(length(t2.assignee)<8,concat('10',t2.assignee),t2.assignee)
    left join base_manager_info t3 on t1.employee_id = t3.employee_id
    ),

delay_task_list0 as 
(-- 每天的超时任务数
    select 
    roster_week 
    ,employee_id
    ,new_dt
    ,count(distinct order_id) as delay_task_count 
    ,count(distinct case when is_over24 = 1 then order_id else null end) as delay_task_count_24
    from (
    select 
    dt
    ,new_dt
    ,date_sub(next_day(new_dt,'mon'),7) as roster_week
    ,employee_id
    ,order_id
    ,create_time
    ,update_time
    ,deadline_time
    ,is_delay
    ,taskorder_status
    ,case when delay_hours > 24 then 1 else 0 end as is_over24
    from taskorder_list 
    where is_delay = 1
    and is_start = 1
    ) tt 
    group by roster_week 
    ,employee_id
    ,new_dt
),
delay_task_list as ( --平均每天超时任务数
    select 
    employee_id
    ,avg(delay_task_count) as delay_task_count
    ,avg(delay_task_count_24) as delay_task_count_24
    from delay_task_list0
    group by 
    employee_id)
,ab_attend_info as (
 select 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date) as mon_of_ab_attend
 ,roster_week
 -- ,case when ab_attend_date >= change_date then 1 else 0 end as is_start
 ,sum(arrive_late_cost+leave_early_cost+absenteeism_cost) as attend_ab_cost
 ,sum(if(arrive_late_cost>0,1,0)
 +if(leave_early_cost>0,1,0)
 +if(absenteeism_cost>0,1,0)) as attend_ab_cnts
 ,sum(ab_attend_hours) as ab_attend_hours

 from (
 select
 if(length(t1.employee_no)=6,concat('10',t1.employee_no),t1.employee_no) as employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7) as roster_week
 ,date_format(t1.work_shift_date, 'yyyy-MM-dd') as ab_attend_date
 ,sum(arrive_late_count)*11*4 as arrive_late_cost
 ,sum(leave_early_count)*11*4 as leave_early_cost 
 ,sum(absenteeism_hours)*22*4 as absenteeism_cost
 ,sum(arrive_late_minutes) as arrive_late_minutes
 ,sum(leave_early_minutes) as leave_early_minutes
 ,sum(absenteeism_hours) as absenteeism_hours
 ,sum(case when arrive_late_minutes < 30 then 0 else arrive_late_minutes end/60+leave_early_minutes/60+absenteeism_hours) as ab_attend_hours -- 改为实际小时数 --0808改标准，大于等于30分钟才算迟到
 from data_build.pdw_opc_shop_attendance_report_work_shift_view t1
 where t1.dt = '${today-1}'
 and t1.work_shift_date >= '${TODAY-30}'
 and t1.work_shift_date <= '${TODAY-1}'
 and t1.work_shift_type in (1,9,12)
 and (arrive_late_count > 0 or leave_early_count > 0 or absenteeism_hours >=4)
 group by employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7)
 ,t1.work_shift_date
 ) t0
-- left join base_manager_info t1 on t0.employee_no = t1.employee_id

 group by 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date)
 ,roster_week
 -- ,case when ab_attend_date >= change_date then 1 else 0 end
)
-- 违规情况低于10分钟 by人
,ab_attend_info_less10 as (
 select 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date) as mon_of_ab_attend
 ,roster_week
 -- ,case when ab_attend_date >= change_date then 1 else 0 end as is_start
 ,sum(arrive_late_cost+leave_early_cost) as attend_ab_cost
 ,sum(if(arrive_late_cost>0,1,0)
 +if(leave_early_cost>0,1,0)) as attend_ab_cnts
 ,sum(arrive_late_minutes/60+leave_early_minutes/60) as ab_attend_hours

 from (
    -- 迟到/早退10分钟以下的次数，不算旷工
 select
 if(length(t1.employee_no)=6,concat('10',t1.employee_no),t1.employee_no) as employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7) as roster_week
 ,date_format(t1.work_shift_date, 'yyyy-MM-dd') as ab_attend_date
 ,sum(case when arrive_late_minutes <30 then arrive_late_count else 0 end)*11*4 as arrive_late_cost --0808改：迟到小于30分钟不计入
 ,sum(case when leave_early_minutes <10 then leave_early_count else 0 end)*11*4 as leave_early_cost 
 ,sum(case when arrive_late_minutes <30 then arrive_late_minutes else 0 end) as arrive_late_minutes --0808改：迟到小于30分钟不计入
 ,sum(case when leave_early_minutes <10 then leave_early_minutes else 0 end) as leave_early_minutes
 from data_build.pdw_opc_shop_attendance_report_work_shift_view t1
 where t1.dt = '${today-1}'
 and t1.work_shift_date >= '${TODAY-30}'
 and t1.work_shift_date <= '${TODAY-1}'
 and t1.work_shift_type in (1,9,12)
 and (arrive_late_count > 0 or leave_early_count > 0)
 
 group by employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7)
 ,t1.work_shift_date

) t0

group by 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date)
 ,roster_week
)
,ab_attend_info2 as (
    select 
    t1.employee_no
   -- ,mon_of_ab_attend
    ,sum(t1.attend_ab_cost) as attend_ab_cost_0
    ,sum(t1.attend_ab_cnts) as ab_attend_count
    ,sum(t1.ab_attend_hours) as ab_attend_hours
    -- ,count(distinct case when t1.ab_attend_hours > 0.5 then t1.ab_attend_date else null end) as ab_attend_count
    ,sum(t2.attend_ab_cost) as attend_ab_cost_less10
    ,sum(t2.attend_ab_cnts) as attend_ab_cnts_less10
    ,sum(t2.ab_attend_hours) as ab_attend_hours_less10
    -- 5次10分钟的迟到或早退不算
    ,sum(t1.attend_ab_cnts)-if(sum(t2.attend_ab_cnts)>=5,5,sum(t2.attend_ab_cnts)) as attend_ab_cnts
    from ab_attend_info t1 
    left join ab_attend_info_less10 t2 on t1.employee_no = t2.employee_no and t1.ab_attend_date = t2.ab_attend_date
    group by t1.employee_no
   -- ,mon_of_ab_attend
),
--员工工序工时合格率 豁免一周
task_hour_info0 as ( 
 select 
 employee_id
 ,avg(qualified_task_time_exclude_free_rate) as t30_avg_task_time_rate --工时合格率
 from (
 select 
 t1.work_date
 ,if(length(t1.employee_id)=6,concat('10',t1.employee_id),t1.employee_id)  as employee_id
 ,qualified_task_time_exclude_free_rate
 ,t1.store_code
 ,case when t1.work_date >= start_cdate then 1 else 0 end as is_start
 from data_shop.app_mmc_store_employee_qualified_task_time_rate_di_v3_view t1
 left join base_manager_info t2 on if(length(t1.employee_id)=6,concat('10',t1.employee_id),t1.employee_id) = t2.employee_id 
 where t1.dt >= '${today-30}'
 -- and t1.dt <= '20230331' 
 and date_format(t1.work_date, 'yyyyMMdd') >= '${today-30}'
 and date_format(t1.work_date, 'yyyyMMdd') <= '${today-1}'
 -- and date_format(t1.work_date, 'yyyyMMdd') <= '20230331'
 ) tmp
 where is_start = 1
 group by employee_id
),
-- 废弃数量及金额 by store 豁免一周
promotion_list as (
select 
store_code	
,start_date
,end_date
,date_add(end_date,7) as end_date_week1
from data_promotion.dm_promotion_daily_app_2023_activity_store_list_di 
where dt= '${today-1}'
-- and start_date >= '2023-05-04'
),
sku_list as (
    select distinct
sku_division_code
,sku_class_code
from data_build.dim_sku_info 
where dt = '${today-1}'
),
waste_list0 as (
select
  target_date
 ,store_code 
 ,date_sub(next_day(target_date,'mon'),7) as roster_week
 ,t1.sku_division_code
 ,sku_class_code
 ,sum(zonghe_manual_waste_qty) as zonghe_correction_waste_qty --财务口径 废弃数量
 ,sum(zonghe_manual_waste_amount) as zonghe_correction_waste_amount --财务口径 纯录入废弃金额
from data_smartorder.dm_production_os_waste_presum_di t1
left join sku_list t2 on t1.sku_division_code = t2.sku_division_code
where dt >= '${today-30}'
and dt <= '${today-1}'
 and target_date >= '${TODAY-30}'
and target_date <= '${TODAY-1}'
  --and store_code = '100000696'
group by target_date,store_code 
,t1.sku_division_code
,sku_class_code
),
waset_list as (
    select 
    
    store_code
    ,sum(zonghe_correction_waste_qty) as zonghe_correction_waste_qty
    ,sum(zonghe_correction_waste_amount) as zonghe_correction_waste_amount
    from(
    select
    target_date 
    ,t1.store_code 
    ,t1.roster_week
    ,case when t1.target_date >= t2.start_cdate then 1 else 0 end as is_start_7
    ,case when t1.roster_week >= date_sub(next_day(t3.start_date,'mon'),7) and t1.roster_week <= date_add(next_day(t3.end_date,'mon'),0) then 1 else 0 end as is_promotion
    ,zonghe_correction_waste_qty
    ,zonghe_correction_waste_amount
    from waste_list0 t1 
    left join base_manager_info t2 on t1.store_code = t2.store_code 
    left join promotion_list t3 on t1.store_code =t3.store_code 
    where sku_class_code not in ('30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '61', '64', '65',
 '66', '67', '68', '70', '71', '72', '73', '78', '85', '88', '89')
    ) tt 
    where is_start_7 = 1
    and is_promotion = 0
    group by store_code
),
-- 计算工作日天数
workdays_t30 as (
select
max(date_key) as max_date_key
,count(distinct date_key) as total_days
,count(distinct date_key)-count(distinct case when is_holiday = 1 then date_key else null end) as workdays
from data_build.dim_date_ya_v2
where date_key >= '${TODAY-30}'
and date_key <= '${TODAY-1}'
),

-- 日商无豁免
sell_price_list as (
select 
-- trunc(order_date,'MM') as record_month
t.store_code 
--,t.store_name
--周中日订单量折前销售额折后销售额
,count(distinct case when b.is_working_day = 1 then t.order_no end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_order_cnt --订单量
,sum(case when b.is_working_day = 1 then t.sell_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_sell_price --折前销售额
,sum(case when b.is_working_day = 1 then t.payable_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_payable_price --折后销售额
,count(distinct t.order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
left join work_day_list b on t.order_date = b.date_key 
where t.dt = '${today-1}'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '${TODAY-30}' and '${TODAY-1}'
group by 
t.store_code 
--,t.store_name
),
sell_price_list_ripei as (
select 
t.store_code 
 --,t.store_name
--,t.store_name
--周中日订单量折前销售额折后销售额
,count(distinct case when b.is_working_day = 1 then t.order_no end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_order_cnt --订单量
,sum(case when b.is_working_day = 1 then t.sell_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_sell_price --折前销售额
,sum(case when b.is_working_day = 1 then t.payable_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_payable_price --折后销售额
,count(distinct t.order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.sell_price) as total_quanzhou_sell_price
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
left join work_day_list b on t.order_date = b.date_key 
where t.dt = '${today-1}'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.sku_class_code not in ('30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '61', '64', '65',
 '66', '67', '68', '70', '71', '72', '73', '78', '85', '88', '89')
and t.order_date between '${TODAY-30}' and '${TODAY-1}'
group by t.store_code 
--,t.store_name
),

-- 折前日商 bystore豁免一周
sales_pdps_list0 as (
    select
 store_city 
 ,t1.store_code 
 ,t1.store_name 
 ,sale_date
 ,substr(sale_date,1,7) as month_of_sale
 ,date_sub(next_day(sale_date,'mon'),7) as roster_week
 ,case when t1.sale_date >= t2.start_cdate then 1 else 0 end as is_start_7
 ,payable_price_for_roster as sales_pdps
 ,sell_price_for_roster as sales_pdps_b
 -- ,round(avg_t,0) as `T值`
from data_smartorder.dm_ordering_suggestion_reference_data_store_amt_for_roster_da t1
left join base_manager_info t2 on t1.store_code = t2.store_code 
where dt = '${today-1}'
 and sale_date >= '${TODAY-30}'
 and sale_date <=  '${TODAY-1}'
 and store_type = '0'
 and order_cnt_store >= 20 --正常营业店日
 and holiday_type in (1,2) --剔除节假日
),

sales_pdps_list as 
(
    select
 store_city 
 ,store_code 
 ,store_name 
-- ,month_of_sale
 ,round(avg(sales_pdps_b),0) as sales_pdps_b
 ,round(sum(sales_pdps_b),0) as total_sales_pdps_b
 -- ,round(avg_t,0) as `T值`
from sales_pdps_list0
where is_start_7 = 1
group by store_city 
 ,store_code 
 ,store_name 
-- ,month_of_sale
),
-- 废弃对应商圈及日商
waset_location_list as (
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
   ,case when sell_price_rounddown >= 0 and sell_price_rounddown < 1000 then '[0,1000)'
    when sell_price_rounddown >= 1000 and sell_price_rounddown < 2000 then '[1000,2000)'
    when sell_price_rounddown >= 2000 and sell_price_rounddown < 3000 then '[2000,3000)'
    when sell_price_rounddown >= 3000 and sell_price_rounddown < 4000 then '[3000,4000)'
    when sell_price_rounddown >= 4000 and sell_price_rounddown < 5000 then '[4000,5000)'
    when sell_price_rounddown >= 5000 and sell_price_rounddown < 6000 then '[5000,6000)'
    when sell_price_rounddown >= 6000 and sell_price_rounddown < 7000 then '[6000,7000)'
    when sell_price_rounddown >= 7000 and sell_price_rounddown < 8000 then '[7000,8000)'
    when sell_price_rounddown >= 8000 and sell_price_rounddown < 9000 then '[8000,9000)'
    when sell_price_rounddown >= 9000 and sell_price_rounddown < 10000 then '[9000,10000)'
    when sell_price_rounddown >= 10000 and sell_price_rounddown < 11000 then '[10000,11000)'
    when sell_price_rounddown >= 11000 and sell_price_rounddown < 12000 then '[11000,12000)'
    when sell_price_rounddown >= 12000 and sell_price_rounddown < 13000 then '[12000,13000)'
    when sell_price_rounddown >= 13000 and sell_price_rounddown < 14000 then '[13000,14000)'
    when sell_price_rounddown >= 14000 and sell_price_rounddown < 15000 then '[14000,15000)'
    when sell_price_rounddown >= 15000 then '[15000,+)'
    else null end as sell_price_type 
    from (
    select 
    t0.store_code
    ,(t7.zonghe_correction_waste_amount/t2.total_quanzhou_sell_price) as waste_rate --t30废弃率（豁免第1周）
    ,location_type --商圈类型
    ,case when (round(floor(quanzhou_sell_price/1000),0)*1000) > 15000 then 15000
else (round(floor(quanzhou_sell_price/1000),0)*1000) end as sell_price_rounddown -- 日商档位
    from base_manager_info t0 
    left join waset_list t7 on t0.store_code = t7.store_code
    left join sales_pdps_list t6 on t0.store_code = t6.store_code
    left join location_type_list t1 on t0.store_code = t1.store_code
    left join sell_price_list_ripei t2 on t0.store_code = t2.store_code
    ) tt
),
-- 废弃对应商圈日商不同分位值
waset_location_rank as (
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
    ,sell_price_type
    ,round(percent_rank() over (partition by sell_price_type order by waste_rate asc)*100,2) as percent_rank_waste
    ,rank() over (partition by sell_price_type order by waste_rate asc)-1 as rank_waste
    ,count(1) over (partition by sell_price_type) as total_stores
    ,rank() over (partition by sell_price_type order by waste_rate asc)/count(1) over (partition by sell_price_type) as percent_rank_waste2
    from waset_location_list
    where waste_rate is not null 

    union 
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
    ,sell_price_type
    ,null as percent_rank_waste
    ,null as rank_waste
    ,null as total_stores
    ,null as percent_rank_waste2
    from waset_location_list
    where waste_rate is null 
),
-- 废弃得分
waset_location_score as (
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
    ,sell_price_type
    ,percent_rank_waste
    ,rank_waste
    ,total_stores
    ,percent_rank_waste2
    ,case when percent_rank_waste <= 20 then 5 
    when percent_rank_waste <= 50 then 4
    when percent_rank_waste <= 70 then 3
    when percent_rank_waste <= 90 then 2
    when percent_rank_waste > 90 then 1
    when percent_rank_waste is null then 3
    else null end as waste_score
    from waset_location_rank
),

check_order_info as ( --员工盘点执行率 t7改为t30
 select 
executor
 ,avg(check_order_rate) as t30_avg_check_order_rate
 from (
 select 
 if(length(t1.executor)=6,concat('10',t1.executor),t1.executor) as executor
 ,t1.work_date
 ,case when t1.work_date >= start_cdate then 1 else 0 end as is_start
 ,t1.biz_order_id
 ,sum(t1.task_finish_work_num)/sum(task_work_num) as check_order_rate

 from data_shop.dwa_shop_horae_task_operation_checkorder_da t1
 left join base_manager_info t2 on if(length(t1.executor)=6,concat('10',t1.executor),t1.executor) = t2.employee_id
 where t1.dt = '${today-1}' 
 and date_format(t1.work_date,'yyyyMMdd') >= '${today-30}' --最新dt 
 and date_format(t1.work_date,'yyyyMMdd') <= '${today-1}' --最新dt 
 -- and date_format(t1.work_date,'yyyyMMdd') <= '20230331'
 group by t1.executor
 ,t1.work_date
 ,case when t1.work_date >= start_cdate then 1 else 0 end 
 ,t1.biz_order_id
 ) tmp
 where is_start = 1
 group by executor
),
-- 盘点差异率 t7改为t30
check_diff_info as 
( select 
sale_date
,t1.store_code
,cal_days
,case when date_format(t1.sale_date,'yyyyMMdd') >= date_format(t2.start_cdate,'yyyyMMdd') then 1 else 0 end as is_start
,sum(case when t1.document_status = 'FINISHED'  and t1.sku_domain_name = '商品' and sku_class_code not in (84,44) and sku_division_code not in (0503) then abs(quantity) else 0 end ) as stocktaking_inventory_true_numerator--盘点库存准确率-分子
,sum(case when t1.document_status = 'FINISHED'  and t1.sku_domain_name = '商品' and sku_class_code not in (84,44) and sku_division_code not in (0503) then abs(inventory_quantity) else 0 end ) as stocktaking_inventory_true_denominator--盘点库存准确率-分母
from data_smartorder.app_stocktaking_store_day_os_di t1
left join base_manager_info t2 on t1.store_code = t2.store_code
where t1.dt >= '${today-30}' --最新dt
and  t1.dt <= '${today-1}' --最新dt
and sale_date >= '${TODAY-30}'
and sale_date <= '${TODAY-1}'
group by sale_date
,t1.store_code
,cal_days
,case when date_format(t1.sale_date,'yyyyMMdd') >= date_format(t2.start_cdate,'yyyyMMdd') then 1 else 0 end
)
,check_diff_info2 as ( 
    select 
    store_code
    ,sum(stocktaking_inventory_true_numerator) as stocktaking_inventory_true_numerator
    ,sum(stocktaking_inventory_true_denominator) as stocktaking_inventory_true_denominator
    ,sum(stocktaking_inventory_true_numerator)/sum(stocktaking_inventory_true_denominator) as check_diff_per
    from check_diff_info
    where is_start = 1
    group by store_code
),
-- 库存出店执行率
kucun_list0 as(
select 
t1.store_code
,effective_time 
,date_sub(next_day(effective_time,'mon'),7) as roster_week
,case when effective_time >= start_cdate then 1 else 0 end as is_start
,sum(coalesce(real_treatment_quantity,0)) as real_treatment_qty, 
sum(coalesce(inventory_quantity,0)) as should_treatment_qty, 
coalesce(sum(coalesce(real_treatment_quantity,0) )/sum(coalesce(inventory_quantity,0)) ,0 ) as execute_rate, --调拨返仓执行率（库存出店执行率）
sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(inventory_quantity,0) else 0 end ) as dec_allocation_qty, 
sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(real_treatment_quantity,0) else 0 end ) as act_allocation_in_doc_qty, 
coalesce(sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(real_treatment_quantity,0) else 0 end )/sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(inventory_quantity,0) else 0 end ),0) as allocation_rate --调拨执行率
FROM data_smartorder.dm_copy_dm_inv_mgt_store_down_inv_out_treatment_detail_store_sku_v1_view t1 
left join base_manager_info t3 on t1.store_code = t3.store_code
WHERE dt = '${today-1}'
AND effective_time >= '${TODAY-30}'
AND effective_time <= '${TODAY-1}'

GROUP BY t1.store_code
,effective_time 
,date_sub(next_day(effective_time,'mon'),7) 
,case when effective_time >= start_cdate then 1 else 0 end
),
kucun_list1 as (
    select 
    store_code
    ,coalesce(sum(coalesce(real_treatment_qty,0) )/sum(coalesce(should_treatment_qty,0)) ,0 ) as execute_rate --调拨返仓执行率（库存出店执行率）
    from kucun_list0
    where is_start = 1
    group by store_code
    
),
-- 现金存缴完成率
cash_finish0 as (
   select 
    task_day
,from_unixtime(unix_timestamp(task_day,'yyyyMMdd'),'yyyy-MM-dd') as task_date
,shop_code
,deposit
,bill_amount
,case when deposit = 0 then 0 when deposit = 1 and to_date(deposit_time) <= '${TODAY-1}' then (bill_amount+deposit_diff_amount) else null end as real_amount
    from data_build.dwd_pdw_inf_pay_bill_report_bank_cash_day_summary_view 
    where dt = '${today-1}' 
and task_day >= '${today-37}'
and task_day <= '${today-7}'
and remark in ('现金已存款','现金未存款')
),

cash_finish as (
select 
task_day
,task_date
,shop_code
,sum(bill_amount) as bill_amount -- 应缴
,sum(real_amount) as real_amount-- 实缴
from cash_finish0
group by task_day
,task_date
,shop_code
),
cash_finish1 as (
    SELECT
    task_date
    ,shop_code
    ,date_sub(next_day(task_date,'mon'),7) as roster_week
    ,bill_amount
    ,real_amount
    ,real_amount/bill_amount as cash_rate
    ,case when task_date >= change_date0 then 1 else 0 end as is_start
    from cash_finish t1
    left join base_manager_info t2 on t1.shop_code = t2.store_code
),
cash_finish2 as (
    select 
    shop_code
    ,sum(bill_amount) as bill_amount
    ,sum(real_amount) as real_amount
    ,avg(cash_rate) as cash_rate
    from cash_finish1
    where is_start = 1
    group by shop_code
),
-- 发票回收
invoice_list as (
    select 
cost_bearing_department_code as store_code
,id
,should_pay_amount
,verification_amount
,verification_status
,to_date(real_pay_time) as pay_date
,case when to_date(real_pay_time) >= change_date0 then 1 else 0 end as is_start_7

from data_build.dwd_pdw_finance_tax_match_request_info_view t1
left join base_manager_info t2 on t1.cost_bearing_department_code = t2.store_code 
where t1.dt  = '${today-1}' --
and match_system in ('shop_rent','bach_electric_after','bach_electric_pre','bach_water_pre','bach_water_after') 
and source in ('后付电费','预付电费','后付水费','预付水费','取暖费','商业服务费','物业费','杂项费用','杂项费用公摊水费','制冷/空调费','咨询服务费','资源占用费')
and to_date(real_pay_time) >= '${TODAY-60}'
and to_date(real_pay_time) < '${TODAY-30}'
),
invoice_final_list1 as (
    select 
    store_code
   
    ,sum(should_pay_amount) as should_pay_amount
    ,sum(verification_amount) as verification_amount
    ,count(distinct id) as should_num
    ,count(distinct case when verification_status in ('1','2') then id else null end) as verification_num
    ,sum(verification_amount)/sum(should_pay_amount) as t30_verification_per
    ,count(distinct case when verification_status in ('1','2') then id else null end)/count(distinct id) as t30_verification_num_per
    from invoice_list
    where is_start_7 = 1
    group by store_code
  
),
-- t30门店t值
opening_days_base as
(select
 sale_date as c_date
 ,case when sale_date >= change_date then 1 else 0 end as is_start
 ,case when sale_date >= start_cdate then 1 else 0 end as is_start_7
 ,weekofyear(sale_date) as week_of_year
 ,date_sub(next_day(sale_date,'mon'),7) as roster_week
 ,shop_code as store_code
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt

 from data_build.pdw_idss_mmc_cooperate_shop_open_info_view t1
 left join base_manager_info t2 on t1.shop_code = t2.store_code
 -- left join data_build.dim_date_ya_v2 t2
   -- on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.date_key
 where t1.dt= '${today-1}'
 and shop_type=0
 and shop_state=1
 and bach_business_time not in ('全天不营业','20:00:00-23:59:59','19:00:00-23:59:59')
 and sale_date >= '${TODAY-30}'
 and sale_date <= '${TODAY-1}'
 ),
opening_days2 as 
(
select distinct
store_code
,c_date
from opening_days_base 
 where is_start_7 = 1
),
opening_days3 as 
(
select 
store_code
,count(distinct c_date) as opening_days
from opening_days_base 
group by store_code
),
t_byday as 
(
select 
 shop_id
 ,alarm_start_date
 ,case when alarm_start_date >= start_cdate then 1 else 0 end as is_start_7
 ,final_level_modify
 ,substr(final_level_modify,2,1) as final_t_level
from data_shop.dwd_ic_new_import_store_level_da_view t1 
left join base_manager_info t2 on t1.shop_id = t2.store_code
where dt = '${today-1}'
-- and final_level_modify in ('T5','T6') 
 and alarm_start_date >= '${TODAY-30}'
and alarm_start_date <= '${TODAY-1}'
),
t_final as 
(
select 
t1.store_code
,avg(final_t_level) as final_t_level

from opening_days2 t1 
left join t_byday t2 on t1.store_code = t2.shop_id
and t1.c_date = t2.alarm_start_date
where t2.is_start_7 = 1
group by t1.store_code
),
-- 品控
audit_base as (
select 
shop_code
,audit_begin_time
,score
,result
,to_date(audit_begin_time) as audit_begin_date
,t3.change_date0
,t3.entry_date
,case when to_date(audit_begin_time) >date_add(change_date0,7) then 1 else 0 end as is_change_7
,case when to_date(audit_begin_time) >t3.entry_date then 1 else 0 end as is_entry
from data_smartorder.dm_copy_pdw_qcs_data_audit_shop_task_view t1 
left join base_manager_info t3 on t1.shop_code = t3.store_code
where t1.dt = '${today-1}'
),
audit_begin_date_maxlist as (
select 
shop_code 
,max(audit_begin_date) as audit_begin_date_max 
from audit_base
where is_change_7 = 1
and is_entry = 1
and audit_begin_date <= '${TODAY-1}'
and audit_begin_date >= '${TODAY-30}'
group by shop_code
),
audit_final_list as (
select 
t1.shop_code 
,score
,result
,audit_begin_date
from audit_begin_date_maxlist t1
left join audit_base t2 on t1.shop_code = t2.shop_code and t1.audit_begin_date_max  = t2.audit_begin_date 
),
punish_detail as ( --惩处明细
 select
 t1.previous_order_id as order_id
 ,to_date(t1.1st_create_date) as order_create_date
 ,t4.start_cdate
 ,case when to_date(t1.1st_create_date) >= t4.start_cdate then 1 else 0 end as is_start

 ,t4.cal_days
 -- ,t2.occur_time as ab_create_time
 ,t1.chain_status as order_status
 ,case when locate('#', regexp_replace(t1.1st_item_id,'[0-9]','#')) > 0
 then t1.1st_flow_name else t1.1st_item_id end as punish_item
 ,coalesce(t1.3rd_operate_results,t1.2nd_operate_results,t1.1st_operate_results) as operate_results
 ,t1.1st_shop_code as shop_code
 -- ,t3.hps_dept_code_lv5 as dept_code
 ,coalesce(t1.3rd_final_user_name,t1.2nd_final_user_name,t1.1st_final_user_name) as staff_name
 ,coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) as emplid
 ,lpad(coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code),8,'10') as staff_code
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type
 ,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then '工时数量扣减' else '工时工资扣减' end as punish_type
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
 ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then 20*round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) 
 else round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) end as punish_value
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
 ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then 20*round(coalesce(3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) 
 else round(coalesce(3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) end as punish_value_origin
 from data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 t1
 -- left join ab_time_detail t2
 -- on coalesce(t1.next_order_id_2,t1.next_order_id,t1.previous_order_id) = t2.order_id 
 -- left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t3
 -- on t3.dt <= '${today-1}' and date_format(date_sub(to_date(t2.occur_time),1),'yyyyMMdd') = t3.dt
 -- and coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) = t3.emplid
 left join base_manager_info t4 on t1.1st_shop_code = t4.store_code
 where t1.dt = '${today-1}'
 and date_format(t1.1st_create_date,'yyyyMMdd') >=  '${today-30}'
 and date_format(t1.1st_create_date,'yyyyMMdd') <=  '${today-1}'
 and (case when locate('#', regexp_replace(1st_item_id,'[0-9]','#')) > 0
 then 1st_flow_name else 1st_item_id end) not in ('请假/拒绝班次惩处','超成本工时费用')
)

,appeal_text_detail as ( --客诉详细说明
 select distinct
 order_id
 ,abnormal_explain
 ,exemption
 ,split(inspection_order_id,' ')[1] as inspection_order_id
 from data_build.dwd_store_construction_operation_punish_flow_details_long_middle_v1 t1
 where t1.dt = '${today-1}' and rm = 1
)
,appeal_punish_detail as ( --客诉分类调整0524
 select distinct
 t1.emplid
 ,t1.order_create_date
 -- ,t1.ab_create_time
 ,t1.shop_code
 ,t1.cal_days
 -- ,t1.dept_code
 ,t1.order_id
 ,t1.punish_item
 ,t1.punish_type
 ,t1.punish_value
 ,t1.punish_value_origin
 ,t2.abnormal_explain
 ,t2.exemption
 ,case when t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物','客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/卫生/环境','客诉-投诉分类: 一级/CT/服务冲突','客诉-投诉分类: 一级/RS/人伤','客诉-投诉分类: 一级/WS/物损') 
 then 1 when t2.abnormal_explain in ('客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质','客诉-投诉分类: 三级/量少/量少','客诉-投诉分类: 三级/配套产品缺失/配套产品缺失','客诉-投诉分类: 三级/商品或包装破损/商品或包装破损','客诉-投诉分类: 三级/失温/失温'
                                    ,'客诉-投诉分类: 四级/服务问题/技能/专业不熟练','客诉-投诉分类: 四级/服务问题/沟通困难','客诉-投诉分类: 四级/购物体验/豆浆稀','客诉-投诉分类: 四级/购物体验/身体不适'
                                    -- ,'客诉-投诉分类: 四级/拣货问题/已下单商品部分缺货（在库）','客诉-投诉分类: 四级/拣货问题/已下单商品全部缺货（在库）'
                ,'客诉-投诉分类: 四级/设备故障问题/豆浆机故障','客诉-投诉分类: 四级/设备故障问题/点餐屏故障','客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 四级/退换货问题/门店结错账','客诉-投诉分类: 四级/支付问题/支付金额与宣传不符')
                then 2 else 0 end as appeal_punish_type
                -- 1 为严重客诉 2为普通客诉
 ,case when lpad(t1.emplid,8,'10') = t3.employee_id then 1 else 0 end as is_manager_appeal

 from punish_detail t1
 left join appeal_text_detail t2
 on t1.order_id = t2.order_id
 left join base_manager_info t3 on t1.shop_code = t3.store_code
 where t1.punish_item = '客诉惩处' 
 and t1.operate_results = '运营问题'
 and t1.order_status = 'FINISHED'
 and t1.is_start = 1 
 and t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物','客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/卫生/环境','客诉-投诉分类: 一级/CT/服务冲突'
 ,'客诉-投诉分类: 一级/RS/人伤','客诉-投诉分类: 一级/WS/物损',
 '客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质','客诉-投诉分类: 三级/量少/量少','客诉-投诉分类: 三级/配套产品缺失/配套产品缺失','客诉-投诉分类: 三级/商品或包装破损/商品或包装破损','客诉-投诉分类: 三级/失温/失温'
                                    ,'客诉-投诉分类: 四级/服务问题/技能/专业不熟练','客诉-投诉分类: 四级/服务问题/沟通困难','客诉-投诉分类: 四级/购物体验/豆浆稀','客诉-投诉分类: 四级/购物体验/身体不适'
                                    -- ,'客诉-投诉分类: 四级/拣货问题/已下单商品部分缺货（在库）','客诉-投诉分类: 四级/拣货问题/已下单商品全部缺货（在库）' -- 剔除普通客诉2项0601
                ,'客诉-投诉分类: 四级/设备故障问题/豆浆机故障','客诉-投诉分类: 四级/设备故障问题/点餐屏故障','客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 四级/退换货问题/门店结错账','客诉-投诉分类: 四级/支付问题/支付金额与宣传不符')
                )
           
,appeal_punish_info1 as ( --客诉final
 select
 shop_code
 ,appeal_punish_type
 ,is_manager_appeal
 ,count(distinct order_id) as appeal_punish_cnts
 ,sum(punish_value) as appeal_punish_value
 ,sum(punish_value_origin) as appeal_punish_value_origin
 from appeal_punish_detail
 -- where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
 group by shop_code
 ,appeal_punish_type
 ,is_manager_appeal
),
-- 增加店长严重客诉、店长普通客诉、店员严重客诉、店员普通客诉类别0524
appeal_punish_info as ( 
    select 
    shop_code 
    ,max(case when appeal_punish_type = 1 and is_manager_appeal = 1 then appeal_punish_cnts else null end) as appeal_punish_cnts_serious_manager
    ,max(case when appeal_punish_type = 1 and is_manager_appeal = 0 then appeal_punish_cnts else null end) as appeal_punish_cnts_serious_manager0
    ,max(case when appeal_punish_type = 2 and is_manager_appeal = 1 then appeal_punish_cnts else null end) as appeal_punish_cnts_common_manager
    ,max(case when appeal_punish_type = 2 and is_manager_appeal = 0 then appeal_punish_cnts else null end) as appeal_punish_cnts_common_manager0
    from appeal_punish_info1
    group by shop_code
),

-- 本店好店员工时占比
paiban_base0 as 
(
 select 
IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) as employee_id
,t1.store_id -- 排班门店
,roster_id
,work_date
,date_sub(next_day(work_date,'mon'),7) roster_week  --周
,start_time
,end_time
,(end_time-start_time) as paiban_hours
,roster_source
,case when t3.employee_id is not null then 1 else 0 end as is_manager
,max(case when work_date = t2.new_dt then t2.store_code else null end) as hps_dept_code_lv5 -- 当天员工所属门店
-- ,case when t2.protect_tag = '待观察' then 1 else 0 end as is_new_staff
from data_build.dw_roster_effect_roster_detail_info_da_view t1 
left join staff_list t2 on IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) = t2.employee_id
 left join base_manager_info t3 on IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) = t3.employee_id
where t1.dt = '${today-1}'
and work_date >=  '${TODAY-30}'
and work_date <=  '${TODAY-1}'
and t1.store_type_desc = '门店'
and t1.class_id in ('0')
and t1.store_type = '0'
and t1.sale_type <> '全天不营业'
group by 
IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id)
,t1.store_id -- 排班门店
,roster_id
,work_date
,date_sub(next_day(work_date,'mon'),7) 
,start_time
,end_time
,roster_source
,case when t3.employee_id is not null then 1 else 0 end
),
paiban_base as (
select 
t1.employee_id
,t1.store_id -- 排班门店
,t1.hps_dept_code_lv5
,case when t1.store_id = t1.hps_dept_code_lv5 then 0 else 1 end as is_shift -- 是否由外店员工上班
,roster_id
,t1.work_date
,roster_week  --周
,start_time
,end_time
,paiban_hours
,roster_source
 ,is_manager
-- ,case when t2.protect_tag = '待观察' then 1 else 0 end as is_new_staff
from paiban_base0 t1 
),
cross_attend_info1 as (
    select
    t1.store_id
    ,work_date 
    ,roster_week
    ,case when t1.work_date >= t2.change_date_14 then 1 else 0 end as is_start_14
    ,sum(case when is_shift = 1 then paiban_hours else 0 end ) as work_shift_hours_cross -- 被跨店小时数 -- 除开店长排班
    ,sum(paiban_hours) as work_shift_hours -- 门店总排班小时数 -- 除开店长排班
    from paiban_base t1
    left join base_manager_info t2 on t1.store_id = t2.store_code
     where t1.is_manager = 0 --除开店长
    group by t1.store_id
    ,work_date 
    ,roster_week
    ,case when t1.work_date >= t2.change_date_14 then 1 else 0 end
),
cross_attend_info2 as (
    select 
    store_id as store_code
    
    ,sum(work_shift_hours_cross) as work_shift_hours_cross -- 被跨店小时数
    ,sum(work_shift_hours) as work_shift_hours -- 门店总排班小时数 -- 除开店长排班
    from cross_attend_info1
    where is_start_14 = 1
    group by store_id
    
),
local_attend_info1 as ( --每个人在本店的排班小时和总排班小时
select
    t1.employee_id
    ,work_date 
    ,roster_week
    ,t1.hps_dept_code_lv5 -- 所属门店
     ,is_manager
    ,sum(case when is_shift = 0 then paiban_hours else 0 end ) as work_shift_hours_local -- 在本店排班小时数
    ,sum(paiban_hours) as work_shift_hours -- 总排班小时数
    from paiban_base t1
    group by 
    t1.employee_id
    ,work_date 
    ,roster_week
    ,t1.hps_dept_code_lv5
     ,is_manager
),
-- 是否好员工
staff_protect_base as (
select
t1.dt
    ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
    ,t1.staff_code
    ,t1.protect_tag
    ,t1.store_code -- 所属门店
    ,case when protect_tag in ('应保护','普通','待观察') then 1 -- 新增待观察新人为好员工占比0524
   else 0 end as is_good
   ,case when protect_tag in ('待观察') then 1 -- 新增待观察新人工时打折为50%
   else 0 end as is_new
    from data_shop.dm_shop_staff_protect_tag_v2 t1 
    where dt <=  '${today-1}'
    and dt >=  '${today-30}'),

staff_protect_list0 as ( --所有员工在本店的排班
    select 
    t1.store_code
    ,t1.staff_code
    ,t1.new_dt
    ,t1.is_good
    ,t1.is_new
    ,t2.work_date 
    ,t2.is_manager
    ,work_shift_hours_local
  ,case when t1.new_dt >= change_date_14 then 1 else 0 end as is_start_14
    from staff_protect_base t1 
    left join local_attend_info1 t2 on t1.staff_code = t2.employee_id and t1.store_code = t2.hps_dept_code_lv5 and t1.new_dt= t2.work_date
    left join base_manager_info t3 on t1.store_code = t3.store_code
),
staff_protect_2 as ( -- 店员的排班总数 除开店长
    select 
    t1.store_code
    ,sum(case when is_good = 1 then work_shift_hours_local else 0 end) as good_staff_work_shift_hours
    ,sum(case when is_new = 1 then work_shift_hours_local else 0 end) as new_staff_work_shift_hours
    ,count(distinct staff_code) as total_staff 
    ,count(distinct case when is_good = 1 then staff_code else null end) as good_staff
    from staff_protect_list0 t1 
    left join cross_attend_info2 t2 on t1.store_code = t2.store_code
    where t1.is_start_14 = 1
    and is_manager = 0 
    group by t1.store_code
),
final_goodlist as(
    select 
    t1.store_code
    ,t2.work_shift_hours -- 门店总排班小时 -- 除开店长
    ,good_staff_work_shift_hours
    ,new_staff_work_shift_hours
    ,(good_staff_work_shift_hours+new_staff_work_shift_hours*0.5)/t2.work_shift_hours as good_er2 -- 新人工时占比*50% + 好员工工时占比 0601 -- 除开店长
    from staff_protect_2 t1 
    left join cross_attend_info2 t2 on t1.store_code = t2.store_code
    ),
-- 门店失败小时数 by store
fail_shift as (
select 
t1.roster_id
,t1.store_id
,t1.work_date
,case when t1.work_date >= t2.change_date_14 then 1 else 0 end as is_start_14
,(end_time-start_time) as paiban_hours
,date_sub(next_day(work_date,'mon'),7) as roster_week
,case when t1.employee_id is null then 1 else 0 end as is_fail
from data_build.dw_roster_effect_roster_detail_info_da_view t1 
left join base_manager_info t2 on t1.store_id = t2.store_code
where dt = '${today-1}'
 and work_date >=  '${TODAY-30}'
 and work_date <=  '${TODAY-1}'
 and t1.store_type_desc = '门店'
and t1.class_id in ('0','-5')
and t1.store_type = '0'
and t1.sale_type <> '全天不营业'
),

fail_list2 as (
    select 
    store_id
    ,sum(case when is_fail = 1 then paiban_hours else 0 end) as fail_hours
    ,count(distinct case when is_fail = 1 then roster_id else null end) as fail_counts
    ,count(distinct roster_id) as total_counts
    ,sum(paiban_hours) as work_shift_hours2
    from fail_shift 
    where is_start_14 = 1
    group by store_id
),
sop_learn_detail as ( --蜂窝学习明细-任务维度聚合
 select 
 title
 ,from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd') as create_date
 ,case when from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd') >= start_cdate then 1 else 0 end as is_start
 ,if(length(emplid)=6,concat('10',emplid),emplid) as emplid
 ,t0.store_code 
 ,count(1) as mission_cnts
 ,sum(finis_percent)/100 as finish_cnts
 from (
 select 
 title
 ,source_name
 ,usercode as emplid
 ,mission_type
 ,sub_mission_type
 ,createtime
 ,date_format(createtime,'yyyyMMdd') as create_dt
 ,class_hour
 ,finis_percent
 ,max(case when date_format(createtime,'yyyyMMdd') = t2.dt then t2.store_code else null end) as store_code
 
 from data_shop.dwa_shop_sop_learn_exam_result_v1 t1
 left join staff_list_v3 t2 on if(length(t1.usercode)=6,concat('10',t1.usercode),t1.usercode)  = t2.employee_id
 where t1.dt = '${today-1}'
 and subplantype = 'clerkSop'
 and date_format(createtime,'yyyyMMdd') >= '${today-30}'
  and date_format(createtime,'yyyyMMdd') <= '${today-1}'
 group by title
 ,source_name
 ,usercode 
 ,mission_type
 ,sub_mission_type
 ,createtime
 ,date_format(createtime,'yyyyMMdd') 
 ,class_hour
 ,finis_percent

 ) t0
 left join base_manager_info t2 on t0.store_code = t2.store_code
 group by 
 title
 ,from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd')
 ,case when from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd') >= start_cdate then 1 else 0 end
 ,emplid
 ,t0.store_code 
),
sop_learn1 as (
    select 
    t1.store_code 
    
    ,count(distinct title) as sop_issue_cnts
    ,count(distinct case when finish_cnts/mission_cnts=1 then title end) as sop_finish_cnts
    ,count(distinct case when finish_cnts/mission_cnts=1 then title end)/count(distinct title) as sop_finish_per
    from sop_learn_detail t1 
    where is_start = 1
    group by t1.store_code 
    
),
blacklist as (
    select distinct 
    employee_no
    ,lpad(employee_no,8,'10') as staff_code
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
where dt = '${today-1}' 
    and valid_status=1 
    and start_date <= '${TODAY}'
    and end_date >= '${TODAY}'
),
key_task_qualified_info as ( -- 员工重点工序执行率
select 
lpad(t1.staff_code,8,'10') as staff_code

,sum(qualified_key_task_hours) as qualified_key_task_hours
,sum(key_task_hours) as key_task_hours
,sum(qualified_key_task_hours)/sum(key_task_hours) as key_task_qualified_hours_rate
from data_smartorder.app_mmc_key_task_qualified_rate_di t1 
where t1.dt = '${today-1}'
and t1.work_date <= '${TODAY-1}' 
and t1.work_date >= '${TODAY-30}' 
group by lpad(t1.staff_code,8,'10')),

final_list as (
select 
t0.employee_id
,t1.emplid
,t0.name
,t0.store_code
,t0.store_name
,t0.city_name
,t0.difficulty_level_new -- 招聘等级指标
,t19.opening_days
,case when t19.opening_days >= 28 then 1 when t19.opening_days >= 20 then 2 else 0 end as opening_type -- 营业类型 1为7天营业 2为五天营业 0为其他
,t0.entry_date
,if(datediff('${TODAY-1}',t0.entry_date) >=30,30,datediff('${TODAY-1}',t0.entry_date)) as entry_days
,t0.cal_days_0
,t0.change_date0
,datediff('${TODAY-1}',t0.change_date0) as change_days
,t0.start_cdate
,t0.cal_days
,t1.work_shift_hours/(t23.workdays+t1.holiday_2_attend_cnts/t23.total_days) as work_shift_hours --增加节假日系数，无入职时间影响 t30累计出勤工时
,t1.work_shift_hours_after_change/(t0.cal_days_0/30)/(t23.workdays+t1.holiday_2_attend_cnts/t23.total_days) as work_shift_hours_2 -- 增加入职本店时间影响
,delay_task_count_24 -- t30日均24h以上超时任务数（豁免第1周）
,coalesce(t4.ab_attend_hours,0) as ab_attend_hours -- t30出勤违规总时长
,coalesce(t4.ab_attend_count,0) as ab_attend_count-- t30出勤违规次数（超半小时）
,coalesce(t4.attend_ab_cnts,0) as attend_ab_cnts-- t30出勤违规次数
,t0.b_manager_date
,t0.b_manager_days -- 成为架构负责人天数
,t1.early_arrive_hour+t1.late_leave_hour as vo_attendhours -- 需要除以entry_days乘以30 t30超时打卡工时数
,(t1.early_arrive_hour+t1.late_leave_hour)/t0.entry_days * 30 as vo_attendhours_2
,t5.t30_avg_task_time_rate --t30工序工时合格率（豁免第1周）
-- ,t6.sales_pdps_b -- t30折前日商 豁免7天
,round(t7.zonghe_correction_waste_amount/t6.total_sales_pdps_b,2) as waste_rate --t30废弃率（豁免第1周）
-- ,t21.waste_rate as waste_rate2
,t21.location_type -- 商圈类型
,t21.sell_price_rounddown
,t21.sell_price_type -- 日商类型
,t21.percent_rank_waste 
,t21.waste_score -- 废弃得分
,t8.t30_avg_check_order_rate -- t30盘点执行率豁免一周,0524 t7改为t30
,t9.check_diff_per -- t30盘点差异率豁免一周 0524 t7改为t30
,t10.execute_rate -- t30库存出店执行率（豁免第1周）
,t12.t30_verification_num_per -- t30发票回收完成率（最近1月付款发票不纳入考核）
,t11.cash_rate -- t30现金存缴完成率（最近1周现金不纳入考核）
,t13.final_t_level -- t30门店t值（豁免1周
,t14.result -- t30品控结果（豁免第1周）
,nvl(t15.appeal_punish_cnts_serious_manager,0) as appeal_punish_cnts_serious_manager-- t30运营类客诉数量（豁免第1周） -- 店长严重客诉
,nvl(t15.appeal_punish_cnts_serious_manager0,0) as appeal_punish_cnts_serious_manager0 -- 店员严重客诉
,nvl(t15.appeal_punish_cnts_common_manager,0) as appeal_punish_cnts_common_manager -- 店长普通客诉
,nvl(t15.appeal_punish_cnts_common_manager0,0) as appeal_punish_cnts_common_manager0 -- 店员普通客诉
,(nvl(t15.appeal_punish_cnts_serious_manager,0) *3*3 + nvl(t15.appeal_punish_cnts_serious_manager0,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager0,0) *1*1) as appeal_punish_base_score -- 客诉分数
,t16.good_er2 -- t30好店员工时占比（豁免第1-2周）
,round(t17.fail_hours/t17.work_shift_hours2,2) as fail_hours_per -- t30失败小时占比（豁免第1-2周）
,round(t17.fail_counts/t17.total_counts,2) as fail_counts_per -- t30失败班次占比（豁免第1-2周）
,t18.sop_finish_per -- t30团队蜂窝SOP学习率（豁免第1周）
,t20.quanzhou_sell_price -- t30折前日商无豁免
,t20.quanzhou_order_cnt -- t30订单量 0601新增
,(nvl(t15.appeal_punish_cnts_serious_manager,0) *3*3 + nvl(t15.appeal_punish_cnts_serious_manager0,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager0,0) *1*1)/t20.quanzhou_order_cnt * 1000 as appeal_punish_orderbase_score
,t22.work_level
,t23.workdays
,t23.total_days
,coalesce(t1.work_day_attend_cnts,0) as work_day_attend_cnts
,coalesce(t1.work_day_attend_cnts,0)/t19.opening_days as work_day_per
,coalesce(t1.holiday_day_cnts,0) as holiday_day_cnts
,coalesce(t1.holiday_attend_cnts,0) as holiday_attend_cnts
,t24.key_task_qualified_hours_rate as key_task_qualified_hours_rate
from base_manager_info t0 
left join t30_attend_info t1 on t0.employee_id = t1.staff_code
-- left join min_manager t3 on t0.employee_id = t3.employee_id
left join delay_task_list t2 on t0.employee_id = t2.employee_id
left join ab_attend_info2 t4 on t0.employee_id = t4.employee_no
left join task_hour_info0 t5 on t0.employee_id = t5.employee_id
left join sales_pdps_list t6 on t0.store_code = t6.store_code
left join waset_list t7 on  t0.store_code = t7.store_code
left join check_order_info t8 on t0.employee_id = t8.executor
left join check_diff_info2 t9 on t0.store_code = t9.store_code
left join kucun_list1 t10 on t0.store_code = t10.store_code
left join cash_finish2 t11 on t0.store_code = t11.shop_code
left join invoice_final_list1 t12 on t0.store_code = t12.store_code
left join t_final t13 on t0.store_code = t13.store_code
left join audit_final_list t14 on t0.store_code = t14.shop_code
left join appeal_punish_info t15 on t0.store_code = t15.shop_code
left join final_goodlist t16 on t0.store_code = t16.store_code
left join fail_list2 t17 on t0.store_code = t17.store_id
left join sop_learn1 t18 on t0.store_code = t18.store_code
left join opening_days3 t19 on t0.store_code = t19.store_code
left join sell_price_list t20 on t0.store_code = t20.store_code
left join waset_location_score t21 on t0.store_code = t21.store_code
left join data_build.dwd_store_construction_roster_store_demand_v1_di t22 on t0.store_code = t22.store_id and t22.dt = '${today-1}' --最新dt 0531才有数
left join workdays_t30 t23 on t0.work_dt = t23.max_date_key
 left join key_task_qualified_info t24 on t0.employee_id = t24.staff_code
),
final_list2 as (
select 
employee_id,
emplid,
name,
store_code,
store_name,
city_name,
difficulty_level_new,
opening_type,
entry_date,
entry_days,
cal_days_0,
change_date0,
change_days,
start_cdate,
cal_days,
work_shift_hours,
coalesce(work_shift_hours_2,work_shift_hours) as work_shift_hours_2,
delay_task_count_24,
ab_attend_hours,
ab_attend_count,
attend_ab_cnts,
b_manager_date,
b_manager_days,
vo_attendhours,
vo_attendhours_2,
t30_avg_task_time_rate,
waste_rate,
location_type,
sell_price_rounddown,
sell_price_type,
percent_rank_waste,
waste_score,
t30_avg_check_order_rate,
check_diff_per,
execute_rate,
t30_verification_num_per,
cash_rate,
final_t_level,
result,
appeal_punish_cnts_serious_manager,
appeal_punish_cnts_serious_manager0,
appeal_punish_cnts_common_manager,
appeal_punish_cnts_common_manager0,
appeal_punish_base_score,
good_er2,
fail_hours_per,
fail_counts_per,
sop_finish_per,
quanzhou_sell_price,
quanzhou_order_cnt,
appeal_punish_orderbase_score,
work_level,
key_task_qualified_hours_rate

-- 意愿度得分
,case when coalesce(work_shift_hours_2,work_shift_hours) >= 300 then 5 
when work_day_per >= 0.9 then 5

when coalesce(work_shift_hours_2,work_shift_hours) >= 280 then 4
when work_day_per >= 0.87 then 4

when coalesce(work_shift_hours_2,work_shift_hours) >= 260 then 3
when work_day_per >= 0.8 then 3
when coalesce(work_shift_hours_2,work_shift_hours) >= 220 then 2
when work_day_per >= 0.63 then 2
when coalesce(work_shift_hours_2,work_shift_hours) < 220 then 1
when work_day_per < 0.63 then 1
else null end as work_shift_score 
-- 出勤工时分 基础指标1
,case when delay_task_count_24 =0 then 5
when delay_task_count_24 <= 1 then 4
when delay_task_count_24 <= 3 then 3
when delay_task_count_24 <= 10 then 2
when delay_task_count_24 > 10 then 1
else 5 end as delay_task_score -- 超时任务分 基础指标2
,case when ab_attend_hours =0 then 0
when attend_ab_cnts <= 1 and ab_attend_hours <=1 then -1
when attend_ab_cnts <= 2 and ab_attend_hours <=2 then -2
when attend_ab_cnts <= 3 and ab_attend_hours <=3 then -3
when attend_ab_cnts <= 5 and ab_attend_hours <=5 then -4
when attend_ab_cnts > 5 or ab_attend_hours > 5 then -5
else 0 end as ab_attend_score -- 出勤违规扣分
-- 0704改出勤违规扣分标准
,case when b_manager_days >= 730 then 1
when b_manager_days >= 365 then 0.5
when b_manager_days < 365 then 0
else 0 end as manager_days_score -- 工龄分 加分
,case when vo_attendhours >= 3 then 0.25
when vo_attendhours < 3 then 0
else 0 end as vo_scores -- 义务工时 加分
-- 个人能力
,case when t30_avg_task_time_rate >= 0.98 then 5
when t30_avg_task_time_rate >= 0.95 then 4
when t30_avg_task_time_rate >= 0.9 then 3
when t30_avg_task_time_rate >= 0.85 then 2
when t30_avg_task_time_rate < 0.85 then 1
else 3 end as task_time_score -- 工序合格分 基础分 -- 改为扣分

,case when t30_avg_check_order_rate = 1 and check_diff_per <= 0.05 then 5
when t30_avg_check_order_rate >= 0.95 and check_diff_per <= 0.065 then 4
when t30_avg_check_order_rate >= 0.85 and check_diff_per <= 0.075 then 3
when t30_avg_check_order_rate >= 0.85 then 2
when t30_avg_check_order_rate < 0.85 then 1
else 3 end as check_score -- 盘点得分 基础分
,case when cash_rate >= 1 then 0 
when cash_rate >= 0.9 then -0.25
when cash_rate < 0.9 then -0.5
else 0 end as cash_score -- 现金存缴 扣分
,case when t30_verification_num_per = 1 then 0
when t30_verification_num_per >= 0.5 then -0.25
when t30_verification_num_per < 0.5 then -0.5
else 0 end as verification_score -- 发票回收 扣分
,case when execute_rate >= 0.9 then 0
when execute_rate >= 0.7 then -0.25
when execute_rate < 0.7 then -0.5
else 0 end as execute_score -- 库存出店 扣分
-- 重点工序执行率扣分
 ,case when key_task_qualified_hours_rate < 0.9 then -1 
 else 0 end as key_task_qualified_hours_rate_score
-- 门店质量
,case when final_t_level  <= 1.6 then 5 --20241108改标准
when final_t_level  <= 2 then 4 --20241108改标准
when final_t_level  <= 2.5 then 3 --20241108改标准
when final_t_level  <= 4 then 2
when final_t_level  > 4 then 1
else 3 end as t_score -- t档分数 基础分
-- 客诉分数 扣分
,case when appeal_punish_orderbase_score >= 15 then -2
when appeal_punish_orderbase_score >= 6 then -1
when appeal_punish_orderbase_score >= 3 then -0.5
when appeal_punish_orderbase_score < 3 then 0
else 0 end as punish_score
-- 品控得分 加分
,case when result = '00' then 1
when result = '01' then 0.5
when result = '02' then 0
else 0 end as result_score

-- 团队管理
-- 好店员工时占比 基础分
,case when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.82 then 5*1.3
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.92 then 5*1.3
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.75 then 4*1.3
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.85 then 4*1.3
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.65 then 3*1.3
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.75 then 3*1.3
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.5 then 2*1.3
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.6 then 2*1.3
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 < 0.5 then 1*1.3
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 < 0.6 then 1*1.3
else 3*1.3 end as good_score

-- 失败小时占比
,case when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.095 then -1
WHEN difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.075 then -0.5
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per < 0.095 then 0
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.06 then -1
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.045 then -0.5
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per < 0.06 then 0
else 0 end as fail_score
-- sop学习率 加分
,case when sop_finish_per >= 0.9 then 1
when sop_finish_per >= 0.8 then 0.5
when sop_finish_per < 0.8 then 0
else 0 end as sop_score 
-- 运营难度得分 
-- 0704改为最高加0.5
,case when work_level >= 6  then 0.5
when work_level <= 2 then -0.5
else 0 end as work_level_score
from final_list
),
score_list as (
select 
t4.*
,(will_score*0.3 + performance_score*0.2 +store_score*0.3 +manage_score*0.2) as total_score_base
,((will_score*0.3 + performance_score*0.2 +store_score*0.3 +manage_score*0.2)+work_level_score) as total_score

from (
select 
t2.*
-- 意愿度总分
,case when (work_shift_score *0.7 + delay_task_score*0.3 + ab_attend_score + manager_days_score + vo_scores) >=5 then 5 
when (work_shift_score *0.7 + delay_task_score*0.3 + ab_attend_score + manager_days_score + vo_scores) <=1 then 1
else (work_shift_score *0.7 + delay_task_score*0.3 + ab_attend_score + manager_days_score + vo_scores) end as will_score
-- 个人能力总分
,case when (task_time_score *0.4 + waste_score *0.3 + check_score*0.3 +cash_score +verification_score +execute_score+key_task_qualified_hours_rate_score) >=5 then 5 -- 盘点占比0.6，废弃占比0.4 
when (task_time_score *0.4 + waste_score *0.3 + check_score*0.3 +cash_score +verification_score +execute_score+key_task_qualified_hours_rate_score) <= 1 then 1
else (task_time_score *0.4 + waste_score *0.3 + check_score*0.3 +cash_score +verification_score +execute_score+key_task_qualified_hours_rate_score) end as performance_score
-- 门店质量总分
,case when (t_score +punish_score +result_score) >= 5 then 5 
when (t_score +punish_score +result_score) <= 1 then 1 
else (t_score +punish_score +result_score) end  as store_score 
-- 团队管理总分
,case when (good_score + fail_score 
--+ sop_score
) >= 5 then 5 
when (good_score + fail_score
-- + sop_score
) <= 1 then 1
else (good_score + fail_score
-- + sop_score
) end as manage_score --0719更新，取消SOP学习率得分

from final_list2 t2
) t4
)

select t5.employee_id,
t5.emplid,
t5.name,
t5.store_code,
t5.store_name,
t5.city_name,
t5.difficulty_level_new,
t5.opening_type,
t5.entry_date,
t5.entry_days,
t5.cal_days_0,
t5.change_date0,
t5.change_days,
t5.start_cdate,
t5.cal_days,
t5.work_shift_hours,
t5.work_shift_hours_2,
t5.delay_task_count_24,
t5.ab_attend_hours,
t5.ab_attend_count,
t5.attend_ab_cnts,
t5.b_manager_date,
t5.b_manager_days,
t5.vo_attendhours,
t5.vo_attendhours_2,
t5.t30_avg_task_time_rate,
t5.waste_rate,
t5.location_type,
t5.sell_price_rounddown,
t5.sell_price_type,
t5.percent_rank_waste,
t5.waste_score,
t5.t30_avg_check_order_rate,
t5.check_diff_per,
t5.execute_rate,
t5.t30_verification_num_per,
t5.cash_rate,
t5.final_t_level,
t5.result,
t5.appeal_punish_cnts_serious_manager,
t5.appeal_punish_cnts_serious_manager0,
t5.appeal_punish_cnts_common_manager,
t5.appeal_punish_cnts_common_manager0,
t5.appeal_punish_base_score,
t5.good_er2,
t5.fail_hours_per,
t5.fail_counts_per,
t5.sop_finish_per,
t5.quanzhou_sell_price,
t5.quanzhou_order_cnt,
t5.appeal_punish_orderbase_score,
t5.work_level,
t5.work_shift_score,
t5.delay_task_score,
t5.ab_attend_score,
t5.manager_days_score,
t5.vo_scores,
t5.task_time_score,
t5.check_score,
t5.cash_score,
t5.verification_score,
t5.execute_score,
t5.t_score,
t5.punish_score,
t5.result_score,
t5.good_score,
t5.fail_score,
t5.sop_score,
t5.work_level_score,
t5.will_score,
t5.performance_score,
t5.store_score,
t5.manage_score,
t5.total_score_base,
t5.total_score

,case when t23.staff_code is not null then 1 else 0 end as is_blacklist
,case when start_cdate >= '${TODAY-1}' then 'F'
when change_days <= 14 then 'F'
when t23.staff_code is not null then 'D'
when total_score is null then 'na' 
when total_score >= 4.5 then 'S' 
when total_score >= 3.8 then 'A' 
when total_score >= 3 then 'B'
when total_score >= 2 then 'C'
when total_score < 2 then 'D'
else null end as final_rank
,t5.key_task_qualified_hours_rate
,t5.key_task_qualified_hours_rate_score
from score_list t5
left join blacklist t23 on t5.employee_id = t23.staff_code

**************************************************************************************************************************************************************************
-- 机动队店员标签(data_build.dwd_district_staff_protect_tag_v1_da)
with work_reference as (
    select distinct
        date_key
        ,day_of_week
        ,case when day_of_week in ('6','7') 
            and holiday_type = '2' then '1' 
            else is_working_day end as is_work_day
    from data_shop.dim_date_ya_v2_view
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

,cum_attend_info as ( --part1.工龄
    select
        t1.employee_no
        ,sum(coalesce(attendance_work_hours,0)) as cum_attend_hours
        ,count(distinct work_shift_date) as total_attend_days
        ,sum(case when date_format(t1.work_shift_date,'yyyyMMdd') >= 
            date_format(t2.hps_hire_date,'yyyyMMdd') then t1.attendance_work_hours end) as cum_attendance_work_hours_after_entry
    from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    inner join --更新入职日期，避免换签后入职日期变更的情况
    raw_list t2
    on t1.employee_no = t2.emplid and t2.new_dt = '${TODAY-1}'
    where t1.dt = '${today-1}'
        and t1.work_shift_type in (1,9,12)
        and t1.work_shift_second_type_code <> 355
       -- and t2.hps_d_hr_status in ('在职')
        and t2.hps_dept_descr_lv1 in ('运营管理部X')
        and t2.hps_d_jobcode in ( '门店伙伴', '店员', '社会PT', '学生PT','店经理','店副经理')
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
            and work_shift_second_type_code <> 355
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
    inner join raw_list t2
    on t1.emplid = t2.emplid and t2.dt = '${today-1}'
        and t2.hps_d_hr_status in ('在职')
        and t2.hps_dept_descr_lv1 in ('运营管理部X')
        and t2.hps_d_jobcode in ( '门店伙伴', '店员', '社会PT', '学生PT','店经理','店副经理')
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
        and date_key --本周和未来三周--本周和未来四周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7) 
            --and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),20)
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
        and t1.roster_date --本周和未来三周--本周和未来四周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7) 
            --and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),20)
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
        and t1.target_date --本周和未来三周--本周和未来四周
            between date_sub(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),7)
            --and date_add(next_day(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),'mon'),20)
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
        and t1.target_date --过去四周+本周--过去四周+本周+未来四周
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
            and t2.hps_dept_descr_lv1 in ('运营管理部X')
            and t2.hps_d_jobcode in ( '门店伙伴', '店员', '社会PT', '学生PT','店经理','店副经理')
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
will_part0 as (
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
where t1.dt = '${today-1}'
    and t1.hps_dept_descr_lv1 in ('运营管理部X')
    and t1.hps_d_jobcode in ( '门店伙伴', '店员', '社会PT', '学生PT','店经理','店副经理')
    and t1.hps_d_hr_status = '在职'
)
--data_shop.dwa_shop_staff_performance_v2_da



,cum_attend_info2 as ( --part1.熟练度类型
    select
        employee_no
        ,sum(attendance_work_hours) as cum_attend_hours
        -- ,sum(is_night_shift) as night_shift_cnts
        -- ,sum(is_weekend_shift) as weekend_shift_cnts
        -- ,sum(is_long_shift) as long_shift_cnts
        ,sum(case when date_format(attend_date,'yyyyMMdd') >= '${today-30}' then work_shift_hours end) as t30_work_shift_hours
    from (
        select distinct
            t1.employee_no
            ,t1.work_shift_id
            ,date_format(t1.work_shift_date, 'yyyy-MM-dd') as attend_date
            -- ,case when date_format(t1.work_shift_date,'yyyyMMdd') >= date_format(t2.hps_hire_dt,'yyyyMMdd') then '1' else '0' end as is_latest_entry
            ,t1.attendance_work_hours
            ,t1.work_shift_hours
            -- ,case
            --     when to_date(nvl(attendance_start_time,punch_start_time))<>to_date(nvl(attendance_end_time,punch_end_time)) then '1'
            --     when to_date(nvl(attendance_start_time,punch_start_time))<>work_shift_date then '1'
            --     else '0'
            -- end as is_night_shift
            -- ,case when t3.day_of_week in ('6','7') then '1' else '0' end as is_weekend_shift
            -- ,case when t1.attendance_work_hours >= 8 then '1' else '0' end as is_long_shift
        from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
        inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
        on t1.employee_no = t2.emplid and t2.dt = '${today-1}'
        left join work_reference t3
        on date_format(t1.work_shift_date, 'yyyy-MM-dd') = t3.date_key
        where t1.dt = '${today-1}'
            and t1.work_shift_type in (1,9,12)
            and work_shift_second_type_code <> 355
            and t2.hps_d_hr_status in ('在职')
            and t2.hps_dept_descr_lv1 in ('运营管理部X')
            and t2.hps_d_jobcode in  ( '门店伙伴', '店员', '社会PT', '学生PT','店经理','店副经理')
    ) tmp
    group by employee_no
)

,task_hour_info as ( --员工工序工时合格率
    select
        employee_id
        ,avg(case when dt >= '${today-7}' then qualified_task_time_exclude_free_rate end) as t7_avg_task_time_rate --工时合格率t7
        ,avg(qualified_task_time_exclude_free_rate) as t30_avg_task_time_rate --工时合格率t30
    from (
        select
            t1.work_date
            ,t1.dt
            ,t1.employee_id
            ,qualified_task_time_exclude_free_rate
        from data_shop.app_mmc_store_employee_qualified_task_time_rate_di_v3_view t1 --日级别增量表，过去数据需要修改dt
        where t1.dt >= '${today-30}'
            and t1.dt <= '${today-1}'
            -- and t1.dt = date_format(t1.work_date, 'yyyyMMdd')
    ) tmp
    group by employee_id
)

,task_execute_detail as ( --员工工序未按sop执行天维度明细
    select
        lpad(a1.staff_code,8,'10') as staff_code
        ,a3.store_code
        ,a3.roster_date
        ,count(*) as task_cnts
        ,sum(if(check_result_status = 1,1,0))/count(*) as mismatch_ratio --工序未按sop执行率
    from
    (
        select get_json_object(item_detail_result,'$.contentInfo.baseInfo.formVariables[0].value') as staff_code
            ,check_result_status
            ,shop_task_id
        from data_shop.pdw_idss_ice_ddp_remote_inspect_shop_item_result_view
        where dt = '${today-1}'
            and business_type = 4
            and date_format(create_time,'yyyyMMdd') >= '${today-30}' -- 最近30天
    ) a1
    left outer join
    (
        select id
            ,business_code
        from data_shop.pdw_idss_ice_ddp_remote_inspect_shop_task_view
        where dt = '${today-1}'
    ) a2
    on a1.shop_task_id = a2.id
    left outer join
    (
        select task_id
            ,shop_code as store_code
            ,work_date as roster_date
        from data_shop.dm_mmc_task_di_view
        where dt >= '${today-30}'
    ) a3
    on a2.business_code = a3.task_id
    group by
        lpad(a1.staff_code,8,'10')
        ,a3.store_code
        ,a3.roster_date
)

,task_execute_info as ( --员工工序未按sop执行率(指标越小越好)
    select
        staff_code
        ,avg(mismatch_ratio) as t30_avg_mismatch_ratio --未按sop执行率
        ,sum(task_cnts) as t30_sum_task_cnts --点击执行数
    from task_execute_detail
    group by staff_code
)

,check_order_info as ( --员工盘点执行率
    select
        executor
        ,avg(check_order_rate) as t30_avg_check_order_rate
    from (
        select
            t1.executor
            ,t1.work_date
            ,t1.biz_order_id
            ,t1.task_finish_work_num/task_work_num as check_order_rate
        from data_shop.dwa_shop_horae_task_operation_checkorder_da t1
        where t1.dt ='${today-1}' 
        and date_format(t1.work_date,'yyyyMMdd') >= '${today-30}'
    ) tmp
    group by executor
)

-- ,ab_time_detail as ( --违规发生时间表
--     select
--         flow_name
--         ,order_id
--         ,max(case when form_name='createTime' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) as occur_time
--         ,max(case when form_name='createTime' then form_values end) as occur_time_raw
--     from (
--         select
--             t1.flow_ame    as flow_name
--             ,t1.order_id
--             ,t2.form_name
--             ,t2.form_values
--             ,t2.index
--             ,t2.seq
--             ,row_number() over (partition by t1.order_id,t2.form_name,t2.index,t2.seq order by t2.dt desc)  as rm
--         from data_build.pdw_order_store_211_order_detail_flow_main t1
--         left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_di t2
--             on t1.order_id = t2.order_id
--             and t2.dt >= '20220101'
--         where t1.dt = '${today-1}'
--             and t1.flow_code = '023898'
--     )t1
--     where rm = 1
--     group by
--         flow_name
--         ,order_id
-- )

,punish_detail as ( --惩处明细
    select
        t1.previous_order_id                                                                                            as order_id
        ,to_date(t1.1st_create_date)                                                                                    as order_create_date
        -- ,t2.occur_time                                                                                                  as ab_create_time
        ,t1.chain_status                                                                                                as order_status
        ,case when locate('#', regexp_replace(t1.1st_item_id,'[0-9]','#')) > 0
            then t1.1st_flow_name else t1.1st_item_id end                                                               as punish_item
        ,coalesce(t1.3rd_operate_results,t1.2nd_operate_results,t1.1st_operate_results)                                 as operate_results
        ,t1.1st_shop_code                                                                                               as shop_code
        -- ,t3.hps_dept_code_lv5                                                                                           as dept_code
        ,coalesce(t1.3rd_final_user_name,t1.2nd_final_user_name,t1.1st_final_user_name)                                 as staff_name
        ,coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code)                                 as emplid
        ,lpad(coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code),8,'10')                    as staff_code
        ,case
            when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type
                ,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
            then '工时数量扣减' else '工时工资扣减' end                                                                     as punish_type
        ,case
            when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
                ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
                then 20*round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
                        ,2nd_final_feedback_result_value,2nd_feedback_result_value
                        ,1st_final_feedback_result_value,1st_feedback_result_value),2)
            else round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
                        ,2nd_final_feedback_result_value,2nd_feedback_result_value
                        ,1st_final_feedback_result_value,1st_feedback_result_value),2) end                              as punish_value
        ,case
            when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
                ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
                then 20*round(coalesce(3rd_feedback_result_value
                        ,2nd_feedback_result_value
                        ,1st_feedback_result_value),2)
            else round(coalesce(3rd_feedback_result_value
                        ,2nd_feedback_result_value
                        ,1st_feedback_result_value),2) end                                                              as punish_value_origin
    from data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 t1
    -- left join ab_time_detail t2
    -- on coalesce(t1.next_order_id_2,t1.next_order_id,t1.previous_order_id) = t2.order_id
    -- left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t3
    -- on t3.dt <= '${today-1}' and date_format(date_sub(to_date(t2.occur_time),1),'yyyyMMdd') = t3.dt
    --     and coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) = t3.emplid
    where t1.dt = '${today-1}'
        and date_format(t1.1st_create_date,'yyyyMMdd') >= '${today-30}'
        and (case when locate('#', regexp_replace(1st_item_id,'[0-9]','#')) > 0
            then 1st_flow_name else 1st_item_id end) not in ('请假/拒绝班次惩处','超成本工时费用')
)

,sample_punch_detail as ( --随机打卡
    select distinct
        emplid
        ,order_create_date
        -- ,ab_create_time
        ,shop_code
        -- ,dept_code
        ,order_id
        ,punish_item
        ,punish_type
        ,punish_value
        ,punish_value_origin
    from punish_detail
    where punish_item = '随机打卡任务超时'
        and operate_results = '运营问题'
        and order_status = 'FINISHED'
)

,sample_punch_info as ( --随机打卡final
    select
        emplid
        ,count(distinct order_id) as  sample_punch_cnts
        ,sum(punish_value) as sample_punch_punish_value
        ,sum(punish_value_origin) as sample_punch_punish_value_origin
    from sample_punch_detail
    where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
    group by emplid
)

,appeal_text_detail as ( --客诉详细说明
    select distinct
        order_id
        ,abnormal_explain
        ,exemption
        ,split(inspection_order_id,' ')[1] as inspection_order_id
    from data_build.dwd_store_construction_operation_punish_flow_details_long_middle_v1 t1
    where t1.dt = '${today-1}' and rm = 1
)

,appeal_punish_detail as ( --客诉
    select distinct
        t1.emplid
        ,t1.order_create_date
        -- ,t1.ab_create_time
        ,t1.shop_code
        -- ,t1.dept_code
        ,t1.order_id
        ,t1.punish_item
        ,t1.punish_type
        ,t1.punish_value
        ,t1.punish_value_origin
        ,t2.abnormal_explain
        ,t2.exemption
    from punish_detail t1
    left join appeal_text_detail t2
    on t1.order_id = t2.order_id
    where t1.punish_item = '客诉惩处'
        and t1.operate_results = '运营问题'
        and t1.order_status = 'FINISHED'
        and (
            (t2.exemption = '客诉-业务来源: 日配客诉'
                and t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物'
                ,'客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质'))
            or
            (t2.abnormal_explain in ('客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/技能/专业不熟练'
                ,'客诉-投诉分类: 四级/配送问题/配送超时','客诉-投诉分类: 四级/配送问题/商品漏送','客诉-投诉分类: 四级/配送问题/商品送错'
                ,'客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 一级/CT/服务冲突'))
        )
)

,appeal_punish_info as ( --客诉final
    select
        emplid
        ,count(distinct order_id) as  appeal_punish_cnts
        ,sum(punish_value) as appeal_punish_value
        ,sum(punish_value_origin) as appeal_punish_value_origin
    from appeal_punish_detail
    where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
    group by emplid
)

,else_punish_detail as ( --其他惩处
    select distinct
        emplid
        ,order_create_date
        -- ,ab_create_time
        ,shop_code
        -- ,dept_code
        ,order_id
        ,punish_item
        ,punish_type
        ,punish_value
        ,punish_value_origin
    from punish_detail
    where punish_item not in ('工序任务未按sop执行（原工序任务真实执行率）','工序任务工时合格率不达标','客诉惩处','随机打卡任务超时')
        and operate_results = '运营问题'
        and order_status = 'FINISHED'
)

,else_punish_info as ( --客诉final
    select
        emplid
        ,count(distinct order_id) as  else_punish_cnts
        ,sum(punish_value) as else_punish_value
        ,sum(punish_value_origin) as else_punish_value_origin
    from else_punish_detail
    where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
    group by emplid
)

,cross_eval_detail as ( --跨店评价明细
    select
        t1.dynamic_shift_id
        ,t2.id
        ,t3.work_shift_id
        ,t1.cross_employee_id
        ,t1.cross_store_code
        ,t1.evaluator
        ,t1.roster_store_code
        ,t1.roster_date
        ,t3.work_shift_type
        ,t3.work_shift_second_desc
        ,t1.roster_arrange
        ,t1.skill_level
        ,t1.need_improve_skill
        ,t1.work_state
        ,t1.welcome
    from data_shop.pdw_opc_roster_cross_store_staff_evaluation_view t1
    left join data_shop.pdw_opc_shop_attendance_shop_roster_detail_view t2
    on t2.dt = '${today-1}'
        and t1.dynamic_shift_id = t2.dynamic_shift_id
    left join data_shop.pdw_opc_shop_attendance_report_work_shift_view t3
    on t3.dt = '${today-1}'
        and t2.id = t3.work_shift_id
    where t1.dt = '${today-1}'
        and t1.evaluator is not null
        and date_format(t1.roster_date,'yyyyMMdd') >= '${today-60}'
        and t3.work_shift_second_desc <> '新人班次'
)

,cross_eval_info as ( --跨店指标汇总
    select
        cross_employee_id
        ,count(distinct work_shift_id) as evaluate_cnts
        ,count(distinct case when skill_level = '高' then work_shift_id end) as high_skill_cnts
        ,count(distinct case when work_state = '一直努力' then work_shift_id end) as work_hard_cnts
        ,count(distinct case when welcome = '十分希望' then work_shift_id end) as welcome_cnts
        ,count(distinct case when work_state = '一直偷懒' then work_shift_id end) as lazy_cnts
        ,count(distinct case when welcome = '拒绝' then work_shift_id end) as reject_cnts
    from cross_eval_detail
    group by cross_employee_id
),
performance_part0 as (
select
    distinct
    t1.emplid
    ,lpad(t1.emplid,8,'10') as staff_code
    ,t1.name as staff_name
    ,t1.hps_d_city as city_name
    ,t1.hps_d_jobcode as position_cn
    ,case when t0.store_manager_no is not null then '1' else '0' end as is_store_manager
    ,t1.hps_dept_code_lv5 as store_code
    ,t1.hps_dept_descr_lv5 as store_name

    -- ,coalesce(t2.cum_attend_hours,0) as cum_attend_hours
    ,coalesce(t2.t30_work_shift_hours,0) as t30_work_shift_hours
    -- ,case when t2.night_shift_cnts>0 then 1 else 0 end as has_night_shift
    -- ,case when t2.weekend_shift_cnts>0 then 1 else 0 end as has_weekend_shift
    -- ,case when t2.long_shift_cnts>0 then 1 else 0 end as has_long_shift
    ,coalesce(round(t3.t7_avg_task_time_rate,4),null) as t7_avg_task_time_rate --员工工序工时合格率t7
    ,coalesce(round(t3.t30_avg_task_time_rate,4),null) as t30_avg_task_time_rate --员工工序工时合格率t30
    ,coalesce(round(t4.t30_avg_mismatch_ratio,4),null) as t30_avg_mismatch_ratio --员工工序未按sop执行率
    -- ,coalesce(round(t4.t30_sum_task_cnts,4),0) as t30_sum_task_cnts --员工工序执行数量
    ,coalesce(round(t5.t30_avg_check_order_rate,4),null) as t30_avg_check_order_rate --员工盘点执行率

    --其他惩处
    ,coalesce(t6.else_punish_cnts,0) as t30_else_punish_cnts
    -- ,case when coalesce(t2.t30_work_shift_hours,0) = 0 then null
    --     else coalesce(t6.else_punish_cnts,0) / coalesce(t2.t30_work_shift_hours,0) end as else_punish_rate_100per
    -- ,coalesce(t6.else_punish_value,0) as t30_else_punish_value
    -- ,coalesce(t6.else_punish_value_origin,0) as t30_else_punish_value_origin

    --客诉惩处
    ,coalesce(t7.appeal_punish_cnts,0) as t30_appeal_punish_cnts
    -- ,case when coalesce(t2.t30_work_shift_hours,0) = 0 then null
    --     else coalesce(t7.appeal_punish_cnts,0) / coalesce(t2.t30_work_shift_hours,0) end as appeal_punish_rate_100per
    -- ,coalesce(t7.appeal_punish_value,0) as t30_appeal_punish_value
    -- ,coalesce(t7.appeal_punish_value_origin,0) as t30_appeal_punish_value_origin

    --随机打卡惩处
    ,coalesce(t8.sample_punch_cnts,0) as t30_sample_punch_cnts
    -- ,case when coalesce(t2.t30_work_shift_hours,0) = 0 then null
    --     else coalesce(t8.sample_punch_cnts,0) / coalesce(t2.t30_work_shift_hours,0) end as sample_punch_punish_rate_100per
    -- ,coalesce(t8.sample_punch_punish_value,0) as t30_sample_punch_punish_value
    -- ,coalesce(t8.sample_punch_punish_value_origin,0) as t30_sample_punch_punish_value_origin

    --跨店评价
    ,coalesce(evaluate_cnts,0) as t60_cross_evaluate_cnts
    ,coalesce(high_skill_cnts,0) as t60_cross_high_skill_cnts
    ,coalesce(work_hard_cnts,0) as t60_cross_work_hard_cnts
    ,coalesce(welcome_cnts,0) as t60_cross_welcome_cnts
    ,coalesce(lazy_cnts,0) as t60_cross_lazy_cnts
    ,coalesce(reject_cnts,0) as t60_cross_reject_cnts

from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join cum_attend_info2 t2
on lpad(t1.emplid,8,'10') = lpad(t2.employee_no,8,'10')
left join task_hour_info t3
on lpad(t1.emplid,8,'10') = lpad(t3.employee_id,8,'10')
left join task_execute_info t4
on lpad(t1.emplid,8,'10') = lpad(t4.staff_code,8,'10')
left join check_order_info t5
on lpad(t1.emplid,8,'10') = lpad(t5.executor,8,'10')
left join else_punish_info t6
on lpad(t1.emplid,8,'10') = lpad(t6.emplid,8,'10')
left join appeal_punish_info t7
on lpad(t1.emplid,8,'10') = lpad(t7.emplid,8,'10')
left join sample_punch_info t8
on lpad(t1.emplid,8,'10') = lpad(t8.emplid,8,'10')
left join cross_eval_info t9
on lpad(t1.emplid,8,'10') = lpad(t9.cross_employee_id,8,'10')

left join data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t0
on t0.dt = '${today-1}' and lpad(t1.emplid,8,'10') = lpad(t0.store_manager_no,8,'10')
where t1.dt = '${today-1}'
    and t1.hps_dept_descr_lv1 in('运营管理部X')
    and t1.hps_d_jobcode in  ( '门店伙伴', '店员', '社会PT', '学生PT','店经理','店副经理')
    and t1.hps_d_hr_status = '在职'
),
will_part as (
--汇总意愿度数据
    select distinct
        t1.emplid
        ,t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.is_store_manager
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.t30_attend_hours_after_entry
        ,t1.t30_work_day_cnts_after_entry
        --入职后工作日模拟30天的出勤
        ,t30_workday_attend_hours_after_entry/t30_work_day_cnts_after_entry*30 as mock_workday_t30_attend_hours

        --入职后自然日模拟30天的出勤
        ,case when total_entry_days >= 30 then t30_attend_hours_after_entry
            else t30_attend_hours_after_entry/total_entry_days*30 end as mock_t30_attend_hours

        --除了极特殊情况（入职后60小时全部是非工作日的出勤）用自然日模拟的出勤，其他时候都用工作日模拟的
        ,case when t1.t30_attend_hours_after_entry >= 60
            and (t30_workday_attend_hours_after_entry/t30_work_day_cnts_after_entry*30) = 0
            then (case when total_entry_days >= 30 then t30_attend_hours_after_entry
                else t30_attend_hours_after_entry/total_entry_days*30 end)
            else (t30_workday_attend_hours_after_entry/t30_work_day_cnts_after_entry*30) end as mock_combined_t30_attend_hours
        ,work_day_avail_days/work_day_cnts as workday_avail_rate
        ,cum_attend_hours
        ,case when t1.t30_sop_issue_cnts = 0 or t1.t30_sop_issue_cnts is null then null --如果没有下发sop学习任务则为空
            else round(coalesce(coalesce(t1.t30_sop_finish_cnts,0)/coalesce(t1.t30_sop_issue_cnts,0),0),4) end as sop_learn_rate
        ,case when coalesce(total_day_cnts,0)-coalesce(work_day_cnts,0) = 0 then null --如果没有节假日的可给班则为空
            else (total_avail_days-work_day_avail_days)/(total_day_cnts-work_day_cnts) end as holiday_avail_rate
        ,case when work_day_cnts = 0 or work_day_cnts is null then null --如果没有工作日的可给班则为空
            when work_day_avail_days = 0 or work_day_avail_days is null then 0 --如果工作日可给没给则为0
            else work_day_full_avail_days/work_day_avail_days end as workday_full_avail_rate
        ,case when coalesce(t30_work_shift_hours,0)+coalesce(t30_sum_penalty_roster_hours,0) = 0 then null
            else coalesce((t30_arrive_late_hour+t30_leave_early_hour+t30_absenteeism_hour+t30_sum_penalty_roster_hours)/
                (t30_work_shift_hours+t30_sum_penalty_roster_hours),0) end as ab_hour_rate
        ,t30_ab_leave_arrive_cnts
        ,std_avail_days_rate
        ,cum_attend_hours_after_entry
    from will_part0 t1
    
)

,performance_part as (
--汇总能力数据
    select distinct
        t1.emplid
        ,t7_avg_task_time_rate
        ,round(t30_else_punish_cnts/t30_work_shift_hours*100,3) as t30_else_punish_per_100_hours
        ,round(t30_appeal_punish_cnts/t30_work_shift_hours*100,3) as t30_appeal_punish_per_100_hours
        ,case when t30_avg_task_time_rate>=0.8 then t30_avg_mismatch_ratio else null end as t30_avg_mismatch_ratio
        ,t30_sample_punch_cnts -- 随机打卡次数
        ,round(t30_sample_punch_cnts/t30_work_shift_hours*100,3) as t30_sample_punch_per_100_hours
        ,t30_avg_check_order_rate
        --跨店评价
        ,t60_cross_evaluate_cnts
        ,t60_cross_high_skill_cnts / t60_cross_evaluate_cnts as t60_cross_high_skill_rate
        ,t60_cross_work_hard_cnts / t60_cross_evaluate_cnts as t60_cross_work_hard_rate
        ,t60_cross_welcome_cnts / t60_cross_evaluate_cnts as t60_cross_welcome_rate
        ,t60_cross_lazy_cnts / t60_cross_evaluate_cnts as t60_cross_lazy_rate
        ,t60_cross_reject_cnts / t60_cross_evaluate_cnts as t60_cross_reject_rate
    from performance_part0 t1
    
)

,manager_transfer_blacklist as(
select distinct
lpad(staff_code,8,10) as staff_code
from data_shop.dwd_manager_transfer_blacklist_v1_di
where dt = '${today-1}'
)

,prep_info as (
--计算标签前准备：
--所有_score后缀的均为该指标的得分
--所有_check后缀的均为该指标是否有效的判断
    select distinct
        --基础信息
        t1.emplid
        ,t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.is_store_manager
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.t30_attend_hours_after_entry
        ,t1.cum_attend_hours_after_entry

        --意愿
        ,t1.mock_workday_t30_attend_hours
        ,t1.mock_t30_attend_hours
        ,t1.mock_combined_t30_attend_hours
        ,t1.workday_avail_rate
        ,t1.cum_attend_hours
        ,t1.sop_learn_rate
        ,t1.holiday_avail_rate
        ,t1.workday_full_avail_rate
        ,t1.ab_hour_rate
        ,t1.t30_ab_leave_arrive_cnts
        ,t1.std_avail_days_rate

        --能力
        ,t2.t7_avg_task_time_rate
        ,coalesce(t2.t30_else_punish_per_100_hours,0) as t30_else_punish_per_100_hours
        ,coalesce(t2.t30_appeal_punish_per_100_hours,0) as t30_appeal_punish_per_100_hours
        ,t2.t30_avg_mismatch_ratio
        ,coalesce(t2.t30_sample_punch_per_100_hours,0) as t30_sample_punch_per_100_hours
        ,round(t2.t30_sample_punch_cnts,0) as t30_sample_punch_cnts
        ,t2.t30_avg_check_order_rate
        ,t2.t60_cross_evaluate_cnts
        ,t2.t60_cross_high_skill_rate
        ,t2.t60_cross_work_hard_rate
        ,t2.t60_cross_welcome_rate
        ,t2.t60_cross_lazy_rate
        ,t2.t60_cross_reject_rate

        --意愿得分
        --基础分
        ,case
            when round(t1.mock_combined_t30_attend_hours,0) >= 300 then 1
            when round(t1.mock_combined_t30_attend_hours,0) >= 250 then 2
            when round(t1.mock_combined_t30_attend_hours,0) >= 150 then 3
        else 4 end as t30_attend_hours_score
        ,case
            when t1.workday_avail_rate >= 0.93 then 1
            when t1.workday_avail_rate >= 0.78 then 2
            when t1.workday_avail_rate >= 0.38 then 3
        else 4 end as workday_avail_score --0813改标准，因为改为未来四周给班，标准下调2%
        --加分
        ,case
            when t1.cum_attend_hours >= 1500 then 4
            when t1.cum_attend_hours >= 600 then 3
            when t1.cum_attend_hours >= 200 then 2
        else 1 end as cum_attend_score
        ,case
            when t1.sop_learn_rate >= 0.95 then 4
            when t1.sop_learn_rate >= 0.75 then 3
            when t1.sop_learn_rate >= 0.6 then 2
            when t1.sop_learn_rate >= 0.5 then 1
        else 0 end as sop_learn_score
        ,case when t1.sop_learn_rate is not null then 4 else 0 end as sop_check
        ,case
            when t1.holiday_avail_rate >= 1 then 4
            when t1.holiday_avail_rate >= 0.9 then 3
            when t1.holiday_avail_rate >= 0.85 then 2
            when t1.holiday_avail_rate >= 0.8 then 1
        else 0 end as holiday_avail_score
        ,case when t1.holiday_avail_rate is not null then 4 else 0 end as holiday_check
        ,case
            when t1.workday_full_avail_rate >= 1 then 4
            when t1.workday_full_avail_rate >= 0.95 then 3
            when t1.workday_full_avail_rate >= 0.9 then 2
            when t1.workday_full_avail_rate >= 0.7 then 1
        else 0 end as workday_full_avail_score
        ,case when t1.workday_full_avail_rate is not null then 4 else 0 end as workday_check
        --减分
        ,case
            when t1.ab_hour_rate >= 0.03 then 4
            when t1.ab_hour_rate >= 0.01 then 3
            when t1.ab_hour_rate >= 0.005 then 2
            when t1.ab_hour_rate > 0 then 1
        else 0 end as ab_hour_score
        ,case when t1.ab_hour_rate is not null then 4 else 0 end as ab_hour_check
        ,case
            when t1.t30_ab_leave_arrive_cnts >= 4 then 4
            when t1.t30_ab_leave_arrive_cnts >= 3 then 3
            when t1.t30_ab_leave_arrive_cnts >= 2 then 2
            when t1.t30_ab_leave_arrive_cnts > 0 then 1
        else 0 end as ab_attend_score
        ,case when t1.t30_ab_leave_arrive_cnts >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as t30_ab_attend_check
        ,case
            when t1.std_avail_days_rate >= 0.45 then 4
            when t1.std_avail_days_rate >= 0.4 then 3
            when t1.std_avail_days_rate >= 0.35 then 2
            when t1.std_avail_days_rate >= 0.25 then 1
        else 0 end as std_avail_days_score --0813改标准，因为改为未来四周给班，标准上调5%
        ,case when t1.std_avail_days_rate >= 0 then 4 else 0 end as std_avail_check

        --能力得分
        --基础分
        ,case
            when t2.t7_avg_task_time_rate >= 0.95 then 1
            when t2.t7_avg_task_time_rate >= 0.9 then 2
            when t2.t7_avg_task_time_rate >= 0.8 then 3
            when t2.t7_avg_task_time_rate >= 0 then 4
        end as t7_avg_task_time_score
        ,case
            when t2.t30_else_punish_per_100_hours > 2.4 then 4
            when t2.t30_else_punish_per_100_hours > 1.6 then 3
            when t2.t30_else_punish_per_100_hours > 0.8 then 2
            when t2.t30_else_punish_per_100_hours >= 0 then 1
        end as t30_else_punish_score
        --减分
        ,case
            when t2.t30_sample_punch_per_100_hours >0 then 4
        end as t30_sample_punch_score
        ,case when t2.t30_sample_punch_cnts = 1 then 1
        when t2.t30_sample_punch_cnts in (2,3) then 2
        when t2.t30_sample_punch_cnts > 3 then 3
        end as t30_sample_punch_cnts_score
        ,case
            when t2.t30_avg_mismatch_ratio >= 0.25 then 4
            when t2.t30_avg_mismatch_ratio >= 0.1 then 3
            when t2.t30_avg_mismatch_ratio >= 0.05 then 2
            when t2.t30_avg_mismatch_ratio > 0 then 1
        else 0 end as t30_avg_mismatch_ratio_score
        ,case when t2.t30_avg_mismatch_ratio >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as mismatch_ratio_check
        ,case
            when t2.t30_appeal_punish_per_100_hours >= 1 then 4
            when t2.t30_appeal_punish_per_100_hours >= 0.5 then 3
            when t2.t30_appeal_punish_per_100_hours >= 0.3 then 2
            when t2.t30_appeal_punish_per_100_hours > 0 then 1
        else 0 end as t30_appeal_punish_score
        ,case when t2.t30_appeal_punish_per_100_hours >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as appeal_check
        ,case
            when t2.t30_avg_check_order_rate >= 0.95 then 0
            when t2.t30_avg_check_order_rate >= 0.9 then 1
            when t2.t30_avg_check_order_rate >= 0.75 then 2
            when t2.t30_avg_check_order_rate >= 0.7 then 3
            when t2.t30_avg_check_order_rate >= 0 then 4
        end as t30_avg_check_order_score
        ,case when t2.t30_avg_check_order_rate >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as check_order_check
        
        ,case when t60_cross_evaluate_cnts >=3 
            and t60_cross_high_skill_rate >=0.75 
            and t60_cross_work_hard_rate >=0.75 
            and t60_cross_welcome_rate >=0.75 then 4 end as cross_eval_good_score
        ,case when t60_cross_evaluate_cnts >=3 then 4 else 0 end as cross_eval_check
        --加分
        ,case when t60_cross_evaluate_cnts >=3 
            and (t60_cross_lazy_rate >= 0.5 or t60_cross_reject_rate >= 0.5) then 4 end as cross_eval_bad_score
         --1219新增晋升黑名单员工减分
        ,case when t3.staff_code is not null then 0.75 else 0 end as manager_transfer_blacklist_score

    from will_part t1
    left join performance_part t2
    on t1.emplid = t2.emplid
    left join manager_transfer_blacklist t3
    on lpad(t1.emplid,8,10) = t3.staff_code
)

--通过基础分/加分/减分，按照阈值规则计算保护标签
select
    tmp.emplid
    ,tmp.staff_code
    ,tmp.staff_name
    ,tmp.city_name
    ,tmp.position_cn
    ,tmp.is_store_manager
    ,tmp.store_code
    ,tmp.store_name
    ,tmp.entry_date
    ,tmp.t30_attend_hours_after_entry
    ,tmp.cum_attend_hours_after_entry

    ,tmp.mock_workday_t30_attend_hours
    ,tmp.mock_t30_attend_hours
    ,tmp.mock_combined_t30_attend_hours
    ,tmp.workday_avail_rate
    ,tmp.cum_attend_hours
    ,tmp.sop_learn_rate
    ,tmp.holiday_avail_rate
    ,tmp.workday_full_avail_rate
    ,tmp.ab_hour_rate
    ,tmp.t30_ab_leave_arrive_cnts
    ,tmp.std_avail_days_rate

    ,tmp.t7_avg_task_time_rate
    ,tmp.t30_else_punish_per_100_hours
    ,tmp.t30_appeal_punish_per_100_hours
    ,tmp.t30_avg_mismatch_ratio
    ,tmp.t30_sample_punch_per_100_hours
    ,tmp.t30_avg_check_order_rate

    ,tmp.t30_attend_hours_score
    ,tmp.workday_avail_score
    ,tmp.cum_attend_score
    ,tmp.sop_learn_score
    ,tmp.holiday_avail_score
    ,tmp.workday_full_avail_score
    ,tmp.ab_hour_score
    ,tmp.ab_attend_score
    ,tmp.std_avail_days_score
    ,tmp.sop_check
    ,tmp.holiday_check
    ,tmp.workday_check
    ,tmp.ab_hour_check
    ,tmp.t30_ab_attend_check
    ,tmp.std_avail_check

    ,tmp.t7_avg_task_time_score
    ,tmp.t30_else_punish_score
    ,tmp.t30_sample_punch_score
    ,tmp.t30_avg_mismatch_ratio_score
    ,tmp.t30_appeal_punish_score
    ,tmp.t30_avg_check_order_score
    ,tmp.mismatch_ratio_check
    ,tmp.appeal_check
    ,tmp.check_order_check

    ,tmp.will_base
    ,tmp.will_up
    ,tmp.will_down
    ,tmp.perfm_base
    ,tmp.perfm_down

            
    ,round(coalesce(will_down,0),1) +
        --如果能力的基础分和加减分都是null，则default给3分
        --如果加减分任意一个不为null但基础分为null，则default给2.4分
        round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
            coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + manager_transfer_blacklist_score as protect_tag_raw
    ,case when cum_attend_hours_after_entry < 60 then 3
        else (case when round(coalesce(will_down,0),1) +
        round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
            coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + manager_transfer_blacklist_score < 1.5 then 1
            when round(coalesce(will_down,0),1) +
        round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
            coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + manager_transfer_blacklist_score < 2.5 then 2
            when round(coalesce(will_down,0),1) +
        round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
            coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + manager_transfer_blacklist_score < 4 then 4 else 5 end)
    end as protect_tag_detail

    ,tmp.perfm_up
    ,tmp.cross_eval_good_score
    ,tmp.cross_eval_bad_score
    ,tmp.cross_eval_check
from (
--汇总出意愿度和能力的基础分/加分/减分
    select
        t1.emplid
        ,t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.is_store_manager
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.t30_attend_hours_after_entry
        ,t1.cum_attend_hours_after_entry

        ,t1.mock_workday_t30_attend_hours
        ,t1.mock_t30_attend_hours
        ,t1.mock_combined_t30_attend_hours
        ,t1.workday_avail_rate
        ,t1.cum_attend_hours
        ,t1.sop_learn_rate
        ,t1.holiday_avail_rate
        ,t1.workday_full_avail_rate
        ,t1.ab_hour_rate
        ,t1.t30_ab_leave_arrive_cnts
        ,t1.std_avail_days_rate

        ,t1.t7_avg_task_time_rate
        ,t1.t30_else_punish_per_100_hours
        ,t1.t30_appeal_punish_per_100_hours
        ,t1.t30_avg_mismatch_ratio
        ,t1.t30_sample_punch_per_100_hours
        ,t1.t30_avg_check_order_rate

        ,t1.t30_attend_hours_score
        ,t1.workday_avail_score
        ,t1.cum_attend_score
        ,t1.sop_learn_score
        ,t1.holiday_avail_score
        ,t1.workday_full_avail_score
        ,t1.ab_hour_score
        ,t1.ab_attend_score
        ,t1.std_avail_days_score
        ,t1.sop_check
        ,t1.holiday_check
        ,t1.workday_check
        ,t1.ab_hour_check
        ,t1.t30_ab_attend_check
        ,t1.std_avail_check

        ,t1.t7_avg_task_time_score
        ,t1.t30_else_punish_score
        ,t1.t30_sample_punch_score
        ,t1.t30_avg_mismatch_ratio_score
        ,t1.t30_appeal_punish_score
        ,t1.t30_avg_check_order_score
        ,t1.mismatch_ratio_check
        ,t1.appeal_check
        ,t1.check_order_check
        ,t1.manager_transfer_blacklist_score

        ,0.5 * coalesce(t1.t30_attend_hours_score,0) + 0.5 * coalesce(t1.workday_avail_score,0) as will_base --基础分
        ,coalesce(t1.cum_attend_score,0)/3.2 + --0723调整，取消SOP学习率得分，增加累计出勤工时得分
            (--coalesce(t1.sop_learn_score,0) + 
            coalesce(t1.holiday_avail_score,0) + coalesce(t1.workday_full_avail_score,0))/
                (--coalesce(t1.sop_check,0) + 
                coalesce(t1.holiday_check,0) + coalesce(t1.workday_check,0)) as will_up --加分
        ,(coalesce(t1.ab_hour_score,0) + coalesce(t1.ab_attend_score,0) + coalesce(t1.std_avail_days_score,0))/
            (coalesce(ab_hour_check,0) + coalesce(t30_ab_attend_check,0) + coalesce(std_avail_check,0)) as will_down --减分

        ,case when t1.t30_else_punish_score is null and t1.t7_avg_task_time_score is null then null
            when t1.t7_avg_task_time_score is null then t1.t30_else_punish_score
            when t1.t30_else_punish_score is null then t1.t7_avg_task_time_score
            else 0.7 * t1.t30_else_punish_score + 0.3 * t1.t7_avg_task_time_score end as perfm_base
        ,case when t30_sample_punch_score is null and t30_avg_mismatch_ratio_score is null
            and t30_appeal_punish_score is null and t30_avg_check_order_score is null 
            and cross_eval_bad_score is null then null
        else (coalesce(t30_sample_punch_cnts_score,0) +
            (coalesce(t30_avg_mismatch_ratio_score,0) + coalesce(t30_appeal_punish_score,0) + coalesce(t30_avg_check_order_score,0) + coalesce(t1.cross_eval_bad_score,0))/
                (coalesce(mismatch_ratio_check,0) + coalesce(appeal_check,0) + coalesce(check_order_check,0) + coalesce(t1.cross_eval_check,0))) end as perfm_down
        ,case when t1.cross_eval_good_score = 4 then 1 end as perfm_up

        ,t1.cross_eval_good_score
        ,t1.cross_eval_bad_score
        ,t1.cross_eval_check
    from prep_info t1
) tmp