--data_shop.dwa_shop_staff_abs_balcklist_di
--每日输出旷工黑名单的增量和作为应离职离职的人的增量

--今天和昨天跑出来的取diff
with base_abs_info_prep_today as ( 
    select distinct 
        t1.employee_no
        ,t1.employee_name
        ,t1.dt
        ,t1.blacklist_reason as releasce_reason
    from data_shop.dwd_shop_staff_abs_releasce_di_v2_di t1
    where t1.dt = '${today-1}'
)

,base_abs_info_prep_yesterday as ( 
    select distinct 
        t1.employee_no
        ,t1.employee_name
        ,t1.dt
    from data_shop.dwd_shop_staff_abs_releasce_di_v2_di t1
    where t1.dt = '${today-2}'
)

--在今天但是不在昨天的人需要新拉黑
,union_info as (
    select 
        t1.employee_no
        ,t1.employee_name
        ,0 as is_releasce
        ,t1.releasce_reason as releasce_reason
    from base_abs_info_prep_today t1
    left join base_abs_info_prep_yesterday t2
    on t1.employee_no = t2.employee_no
    where t2.employee_no is null
)

--旷工黑名单增量
select 
    t1.employee_no
    ,t1.employee_name
    ,current_date() as date_start
    ,date_add(current_date(),3650) as date_end
    ,t1.is_releasce
    ,t1.releasce_reason
from union_info t1

union all

--作为最差标签在t-1离职的人拉黑
select distinct
    t1.man_code as employee_no --工号
    ,t2.staff_name as employee_name
    ,current_date() as date_start
    ,date_add(current_date(),3650) as date_end
    ,0 as is_releasce
    ,'应离职离职拉黑' as releasce_reason
from data_shop.pdw_gis_workday_dimission_order_view t1
left join data_shop.dm_shop_staff_protect_tag_v2 t2
on t2.dt >= '${today-5}' 
    and date_format(date_sub(final_leave_date,2),'yyyyMMdd') = t2.dt 
    and lpad(t1.man_code,8,'10') = t2.staff_code
where t1.dt = '${today-1}' 
    and t1.job in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理')
    and t1.order_status <> 'SUSPEND'
    and (t1.leave_way <> 3 and date_format(date_add(final_leave_date,1),'yyyyMMdd') = t1.dt and final_leave = 'leave') --lastday是昨天
    and t2.protect_tag_detail = '5'


*****************************************************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------
*****************************************************************************************************************************************************


--data_shop.dwd_shop_staff_abs_releasce_di_v2_di
with attend_total as (
  --入职后累计出勤
  select
    t1.employee_no,
    sum(t1.attendance_work_hours) as cum_attend_hours
  from
    data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_no = t2.emplid
    and t2.dt = '${today-1}'
    and date_format(t2.hps_hire_dt, 'yyyyMMdd') <= date_format(t1.work_shift_date, 'yyyyMMdd')
    and t2.hps_dept_descr_lv1 in ('运营管理部A', '运营管理部B','运营管理部X')
    and t2.hps_d_jobcode in ('店经理', '店副经理','门店伙伴', '店员', '社会PT', '学生PT', '见习店经理')
    and t2.hps_d_hr_status = '在职'
  where
    t1.dt = '${today-1}'
    and t1.work_shift_type in (1, 9, 12)
  group by
    t1.employee_no
),
report_work_shift as (
  --考勤表订正：入职后的班次按天排序
  select distinct
    t1.work_shift_id,
    t1.employee_no,
    t1.employee_name,
    date_format(t1.work_shift_date, 'yyyy-MM-dd') as work_shift_date,
    t1.work_shift_hours,
    t1.attendance_work_hours,
    t1.punch_start_time,
    t1.absenteeism_hours,
    date_format(t2.hps_hire_dt, 'yyyy-MM-dd') as hire_date,
    case
      when t4.store_manager_no is not null then 1
      else 0
    end as is_manager,
    row_number() over(
      partition by t1.employee_no
      order by
        t1.work_shift_date asc
    ) as rn
  from
    data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_no = t2.emplid
    and t2.dt = '${today-1}'
    and date_format(t2.hps_hire_dt, 'yyyyMMdd') <= date_format(t1.work_shift_date, 'yyyyMMdd')
    and t2.hps_dept_descr_lv1 in ('运营管理部A', '运营管理部B','运营管理部X')
    and t2.hps_d_jobcode in ('店经理','店副经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理')
    and t2.hps_d_hr_status = '在职'
    left join data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t4 on t1.employee_no = t4.store_manager_no
    and t4.dt = '${today-1}'
  where
    t1.dt = '${today-1}'
    and t1.work_shift_type in (1, 9, 12)
),
--新增逻辑：如果打了上班卡就不算旷工
-- 每人每天上班卡的数据
punch_record as (
    select 
    staff_no
    ,punch_date
    ,punch_type
    ,real_sign
    ,case when punch_type = 1 and real_sign = 1 then 1 else 0 end as is_punch_start
    from data_shop.pdw_idss_ipes_daily_punch_punch_record_di_view 
    where dt = '${today-1}'
    and punch_type = 1
),
abs_info_rm_0 as (
  --剔除第一个班次的t30旷工表
  select distinct 
    t1.employee_no,
    t1.employee_name,
    t1.hire_date,
    t1.work_shift_date,
    t1.is_manager,
    coalesce(t3.cum_attend_hours, 0) as cum_attend_hours,
    lead(t1.work_shift_date, 1, t1.work_shift_date) over (
      partition by t1.employee_no
      order by
        t1.work_shift_date desc
    ) as last_abs_date,
    nvl(t5.is_punch_start,0) as is_punch_start
    
  from
    report_work_shift t1
    left join attend_total t3 on t1.employee_no = t3.employee_no
    left join data_shop.pdw_opc_shop_attendance_attendance_state_view t4 on t1.work_shift_id = t4.roster_id
    and t4.dt = '${today-1}' and t4.check_type = '1'
    left join punch_record t5 on t1.work_shift_date = t5.punch_date and lpad(t1.employee_no,8,'10') = lpad(t5.staff_no,8,'10')
  where
    t1.rn > 1
    and (
      (
        t1.absenteeism_hours >= 4
        -- and t1.punch_start_time is null
        -- and t4.state in (7)
        and t4.state in (7,22)
        
      )
      or (
        t4.state in (7,22)
        -- t4.state in (7)
        -- t1.punch_start_time is null
        and t1.work_shift_hours >= 4
       
        and date_format(t1.work_shift_date, 'yyyyMMdd') <= '${today-1}'
        and date_format(t1.work_shift_date, 'yyyyMMdd') >= '20230424'
      )
    )
),
abs_info_rm_1 as (
    select
    t1.employee_no,
    t1.employee_name,
    t1.hire_date,
    t1.work_shift_date,
    t1.is_manager,
    t1.cum_attend_hours,
    t1.last_abs_date,
    t1.is_punch_start,
    nvl(t5.is_punch_start,0) as is_punch_start_b
    from abs_info_rm_0 t1 
    left join punch_record t5 on t1.last_abs_date = t5.punch_date and lpad(t1.employee_no,8,'10') = lpad(t5.staff_no,8,'10')
),
prep_info as (
  select
    distinct t1.employee_no,
    t1.employee_name,
    '曾7天2次及以上旷工' as blacklist_reason
  from
    abs_info_rm_1 t1
  where
    datediff(work_shift_date, last_abs_date) <= 6
    and datediff(work_shift_date, last_abs_date) > 0
    and date_format(t1.last_abs_date, 'yyyyMMdd') >= '20230301'
    and is_punch_start = 0
    and is_punch_start_b = 0
  UNION ALL
  select
    distinct t1.employee_no,
    t1.employee_name,
    '新人旷工' as blacklist_reason
  from
    abs_info_rm_1 t1
  where
    cum_attend_hours < 60
    and is_manager = 0
    and datediff(work_shift_date, last_abs_date) <= 14
    and datediff(work_shift_date, last_abs_date) > 0
    and date_format(t1.work_shift_date, 'yyyyMMdd') >= '${today-15}'
    and is_punch_start = 0
  UNION ALL
  select
    distinct t1.employee_no,
    t1.employee_name,
    '曾30天2次及以上旷工' as blacklist_reason
  from
    abs_info_rm_1 t1
  where
    datediff(work_shift_date, last_abs_date) <= 29
    and datediff(work_shift_date, last_abs_date) > 0
    and is_manager = 0
    and date_format(t1.work_shift_date, 'yyyyMMdd') >= '20230301'
    and is_punch_start = 0
    and is_punch_start_b = 0
  UNION ALL
  select
    distinct t1.employee_no,
    t1.employee_name,
    '曾60天2次及以上旷工' as blacklist_reason
  from
    abs_info_rm_1 t1
  where
    datediff(work_shift_date, last_abs_date) <= 59
    and datediff(work_shift_date, last_abs_date) > 0
    and is_manager = 0
    and date_format(t1.last_abs_date, 'yyyyMMdd') >= '20230301'
    and is_punch_start = 0
    and is_punch_start_b = 0
  UNION ALL
  select
    distinct t1.employee_no,
    t1.employee_name,
    '曾90天2次及以上旷工' as blacklist_reason
  from
    abs_info_rm_1 t1
  where
    datediff(work_shift_date, last_abs_date) <= 89
    and datediff(work_shift_date, last_abs_date) > 0
    and is_manager = 0
    and date_format(t1.last_abs_date, 'yyyyMMdd') >= '20230301'
    and is_punch_start = 0
    and is_punch_start_b = 0
)
select
  distinct t1.employee_no,
  t1.employee_name,
  coalesce(
    t2.blacklist_reason,
    t3.blacklist_reason,
    t4.blacklist_reason,
    t5.blacklist_reason,
    t6.blacklist_reason
  ) as blacklist_reason
from
  prep_info t1
  left join prep_info t2 on t1.employee_no = t2.employee_no
  and t2.blacklist_reason = '曾7天2次及以上旷工'
  left join prep_info t3 on t1.employee_no = t3.employee_no
  and t3.blacklist_reason = '新人旷工'
  left join prep_info t4 on t1.employee_no = t4.employee_no
  and t4.blacklist_reason = '曾30天2次及以上旷工'
  left join prep_info t5 on t1.employee_no = t5.employee_no
  and t5.blacklist_reason = '曾60天2次及以上旷工'
  left join prep_info t6 on t1.employee_no = t6.employee_no
  and t6.blacklist_reason = '曾90天2次及以上旷工'
