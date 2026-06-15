--查询当天生效的黑名单(最新一天)

select distinct 
    employee_no
    ,lpad(employee_no,8,'10') as staff_code
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view 
where dt = '${today-1}' 
    and valid_status=1 
    and start_date <= '${TODAY}'
    and end_date >= '${TODAY}'



--月均T等级changedates
select 
 shop_id  

 ,round(avg(substr(final_level_modify,2,1)),1) as avg_t
from data_shop.dwd_ic_new_import_store_level_da_view
where dt = '${today-1}' 
-- and final_level_modify in ('T5','T6') 
 and alarm_start_date between '2026-05-01' and '2026-05-31' --记得改这个
group by shop_id


----t30工时、夜班工时changedates
with attend_info as
(
select
  t1.roster_system_id,
  t1.store_code,
  t1.store_name,
  t1.work_shift_date,
 t1.employee_no,
 t2.is_night,
 sum((unix_timestamp(t1.end_time) - unix_timestamp( t1.start_time))/3600) attend_hours,
 (unix_timestamp(min(t1.start_time)) - unix_timestamp( t1.work_shift_date,'yyyy-MM-dd'))/3600 attend_start_time,
 (unix_timestamp(max(t1.end_time)) - unix_timestamp( t1.work_shift_date,'yyyy-MM-dd'))/3600 attend_end_time
from data_smartorder.dw_roster_attendance_shift_ha t1
left join data_build.dw_roster_effect_roster_detail_info_da_view  t2 on t2.roster_id = t1.roster_system_id and t2.dt = '${today}'
where  t1.dt = '${today}'
and  t1.work_shift_date between '2026-05-01' and '2026-05-31'
--and work_shift_date >= '2023-05-30'
and  t1.type = 1
and  t1.store_name not like '%饮品站%'
group by
  t1.roster_system_id,
 t1.store_code,
  t1.store_name,
  t1.work_shift_date,
  t1.employee_no
   ,t2.is_night)

select     employee_no
    ,lpad(employee_no,8,'10') as staff_code
    ,sum(attend_hours) as t30_attend_hours
    ,nvl(sum(case when is_night = 1 then attend_hours end),0) as t30_attend_night_hours
    from attend_info 
    group by employee_no


---在职情况
    select 
lpad(emplid,8,'10') as staff_code,
 hps_dept_code_lv5 as sec_store_code, -- 店
 hps_d_jobcode as job 
 from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view 
 where dt= '${today-1}'
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','店副经理','社会PT','学生PT','防疫伙伴')
    and hps_d_hr_status = '在职'


  --保护标签
  select 
  staff_code as staff_code
  ,protect_tag_detail as protect_tag_detail
  from 
data_shop.dm_shop_staff_protect_tag_v2
where dt= '${today-1}'


--店副天数
with dt_count as 
(select 
count(distinct dt) as store_days 
 ,lpad(emplid,8,'10') as staff_code,
 hps_dept_code_lv5 as sec_store_code-- 店
 from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view 
 where dt between 20260501 and 20260531
    and hps_d_jobcode in ('店副经理')
    and hps_d_hr_status = '在职'
    group by emplid
    ,hps_dept_code_lv5
)


select 
 lpad(t1.emplid,8,'10') as staff_code,
 t1.hps_dept_code_lv5 as sec_store_code
 ,t2.store_days 
 from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view  t1
 left join dt_count t2 on t1.emplid = t2.staff_code and t1.hps_dept_code_lv5 = t2.sec_store_code
 where t1.dt= '${today-1}'
    and t1.hps_d_jobcode in ('店副经理')
    and t1.hps_d_hr_status = '在职'

--总销售额，记得改日期--这个表应该不太能用了

select
store_code,
sum(amount_store)
from data_smartorder.dm_ordering_suggestion_reference_data_store_amt_for_roster_da t
where dt = '${today-1}'
and sale_date between '2023-06-01' and '2023-06-30'
group by store_code



--YUFEI算薪用的日商表仅供参考与核对
data_build.dw_order_sku_v1


--日商表现--这个是新的，可以换成这个

select
trunc(order_date,'MM') as month
,t.store_code 
,t.store_name
,count(distinct order_date) as date_num --营业日
,sum(t.payable_price) as total_sales --sales
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2026-05-01' and '2026-05-31' --记得改这个
group by 
trunc(order_date,'MM')
,t.store_code 
,t.store_name


  --每月给越佳的缺编情况

select 
  store_code
  ,district_code
  ,case when
    (reward_level in ('P3','P4','P5','P6','P7','P8') or reward_level_night in ('P3','P4','P5','P6','P7','P8') or gap_new >=1) and reward_level_district not in ('P1','P2') then '缺编'
    when reward_level in  ('P1','P2') and reward_level_district in ('P1','P2') and reward_level_night not in ('P3','P4','P5','P6','P7','P8') and reward_level_night_district not in ('P4','P5','P6','P7','P8') then '不缺编'
    else '正常' end as final_level

  from data_build.dwd_store_construction_store_groups_recruit_gap
  where dt = '${today-1}'






  --惩处-离职员工加重数据
  --(直接从http://schedule.corp.bianlifeng.com/job/push_excel_ods_idss_mmc_gownsman_leave_employee_withhold/3/console这个调度里下载表格就行)
  with
t_cal as (
select 

a.flow_order_id
,a.flow_code
,a.order_status
,a.shop_code
,a.shop_name
,a.item_id
,a.item_from
,a.final_feed_back_type
,a.final_back_result_value
,a.origin_feed_back_type
,a.origin_back_result_value
,a.important_item_name
,a.final_user_num
,a.final_user_name
,a.job_state
,a.flow_create_time
,a.item_start_time
,a.item_end_time
,a.item_date
,a.snap_date_time
,a.red_line_item
,a.level_job_exempt
,a.protect_tag_exempt
,a.remove_electron_tag_flow_order_id
,a.remove_electron_tag_exempt
,a.rollback_electron_tag_flow_order_id
,a.rollback_electron_tag_exempt
,a.exempt
,a.punish
,a.content
,a.punish_owner_code
,a.punish_owner_name
,a.punish_owner_type
,a.is_franchise
,a.manager_code
,a.dt
from data_smartorder.dm_copy_pdw_idss_mmc_gownsman_calc_salary_snap_view a
where dt = 20250501--每月第一天
and snap_date_time = '2025-05-01 23:59:59'
),
t_withhold as (
select 
id,
flow_order_id,
leave_flow_order_id,
staff_code,
staff_name,
city,
job,
shop_code,
original_withhold_amount,
original_exempt,
actual_withhold_amount,
supplement_withhold_amount,
supplement_withhold_reason,
is_withhold,
start_time,
end_time,
is_repay,
snap_date_time,
create_time,
update_time,
dt
from data_smartorder.dm_copy_ods_idss_mmc_gownsman_leave_employee_withhold_view a
where dt = 20250501--每月第一天
and snap_date_time = '2025-05-01 23:59:59'
)

select
a.id,
a.flow_order_id,
a.leave_flow_order_id,
a.staff_code,
a.staff_name,
a.city,
a.job,
a.shop_code,
b.final_feed_back_type,
a.original_withhold_amount,
a.original_exempt,
a.actual_withhold_amount,
a.supplement_withhold_amount,
a.supplement_withhold_reason,
a.is_withhold,
a.start_time,
a.end_time,
a.is_repay,
a.snap_date_time,
a.create_time,
a.update_time,
a.dt
from t_withhold a
left join t_cal b
on a.flow_order_id = b.flow_order_id



