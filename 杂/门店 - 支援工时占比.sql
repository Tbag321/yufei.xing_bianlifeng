with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

chuqin_staff_list as
(
select 
t1.employee_no
,t3.store_cvs_code
,t3.display_name
,t2.hps_dept_code_lv5
,case when t3.store_cvs_code = t2.hps_dept_code_lv5 then 0 else 1 end as is_shift
,work_shift_id
,work_shift_date
,attendance_start_time
,attendance_end_time
,(unix_timestamp(attendance_end_time)-unix_timestamp(attendance_start_time))/3600 as attendance_hours
from data_build.dw_roster_attendance_detail_da_view t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 
on t1.employee_no = t2.emplid and t1.dt = t2.dt
left join desensitization t3 on t1.store_code = t3.store_code
where t1.dt = '20221118' 
and work_shift_date>='2022-10-31'
and work_shift_date<='2022-11-06'
and t2.hps_d_hr_status = '在职'
)

select 
employee_no
,hps_dept_code_lv5 as store_code 
,group_level
,reward_level
,priority_level
,sum(case when is_shift = 0 then attendance_hours else 0 end ) as attendance_hours_local
,count(distinct case when is_shift = 0 then work_shift_id else null end) as work_shifts_local
,sum(case when is_shift = 1 then attendance_hours else 0 end ) as attendance_hours_cross
,count(distinct case when is_shift = 1 then work_shift_id else null end) as work_shifts_cross
,sum(attendance_hours) as attendance_hours
,count(distinct work_shift_id ) as work_shifts

from chuqin_staff_list t1 
left join data_build.dwd_store_construction_store_groups_recruit_gap t2
on t1.hps_dept_code_lv5 = t2.store_code 
and t2.dt = '20221108'
group by 
employee_no
,hps_dept_code_lv5
,group_level
,reward_level
,priority_level

--------------------------------------------------------------------------------------------------------------------

--店维度
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

chuqin_staff_list as
(
select 
t1.employee_no
,t3.store_cvs_code
,t3.display_name
,t2.hps_dept_code_lv5
,case when t3.store_cvs_code = t2.hps_dept_code_lv5 then 0 else 1 end as is_shift
,work_shift_id
,work_shift_date
,attendance_start_time
,attendance_end_time
,(unix_timestamp(attendance_end_time)-unix_timestamp(attendance_start_time))/3600 as attendance_hours
from data_build.dw_roster_attendance_detail_da_view t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 
on t1.employee_no = t2.emplid and t1.dt = t2.dt
left join desensitization t3 on t1.store_code = t3.store_code
where t1.dt = '20221118' 
and work_shift_date>='2021-01-01'
and work_shift_date<='2022-11-18'
--and t2.hps_d_hr_status = '在职'
)

select 
date_add(work_shift_date,1 - case when dayofweek(work_shift_date) = 1 then 1 else dayofweek(work_shift_date) - 7 end) as week
,store_cvs_code 
,display_name
,sum(case when is_shift = 0 then attendance_hours else 0 end ) as attendance_hours_local
,count(distinct case when is_shift = 0 then work_shift_id else null end) as work_shifts_local
,sum(case when is_shift = 1 then attendance_hours else 0 end ) as attendance_hours_cross
,count(distinct case when is_shift = 1 then work_shift_id else null end) as work_shifts_cross
,sum(attendance_hours) as attendance_hours
,count(distinct work_shift_id ) as work_shifts
from chuqin_staff_list
group by 
date_add(work_shift_date,1 - case when dayofweek(work_shift_date) = 1 then 1 else dayofweek(work_shift_date) - 7 end)
,store_cvs_code 
,display_name