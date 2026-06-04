--统计周期230905-240201--可用表9月5号才有数
with work_day_list as(
select
date_key
,is_working_day
,is_holiday
,case when day_of_week in ('6','7') and holiday_type = '2' then '1' else is_working_day end as is_work_day
from default.dim_date_ya_v2
where date_key > '2023-08-01'
),

a_list as(
select
dt
,emplid
,leave_dt
,case when leave_dt is null then 0 else 1 end as add_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt > 20230801
),

b_list as(
select
dt
,emplid
,leave_dt
,sum(add_num) over(partition by emplid order by concat(dt,emplid) desc) as sum_num
from a_list
),

c_list as(
select
dt
,emplid
,leave_dt
,sum_num
,max(leave_dt) over(partition by concat(emplid,sum_num) order by concat(dt,emplid) desc) as final_leave_dt
from b_list
),

leave_list as(
select
dt
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,case when final_leave_dt is null then '2035-12-31' else final_leave_dt end as leave_dt
from c_list t1
),

staff_list as(
select
dt
,new_dt
,store_code
,employee_id
,name
,hps_d_hr_status
,hps_hire_type
,hps_d_jobcode
,manager_code
,post_name
,row_number() over(partition by concat(employee_id,
hps_d_hr_status
,hps_hire_type --用工形式
) order by dt) as rn --按照人*在职状态维度进行排序(用用工形式排序不严谨，后续可优化调整)
,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
from
(
select
t1.dt
,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,t1.hps_dept_code_lv5 as store_code
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,name
,case when t3.leave_dt = '2035-12-31' then '在职'
when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
else '离职' end as hps_d_hr_status --在离职状态
,t1.hps_hire_type --用工形式
,t1.hps_d_jobcode
,t2.manager_code
,case when t2.manager_code is not null then '架构负责人'
when t1.hps_d_jobcode = '店副经理' then '店副经理'
when t1.hps_dept_descr_lv5 like '%区X%' then '机动队'
when t1.hps_d_jobcode in ('店经理','门店伙伴','店员','社会PT','学生PT','见习店经理') then '店员'
else '其它' end as post_name
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join --判断是否是架构负责人
(select distinct
dt
,if(length(manager_code)=6,concat('10',manager_code),manager_code) as manager_code
from data_build.pdw_opc_shop_ehr_staff_dept_view
where dt > 20230801
) t2 on t1.dt = t2.dt and if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t2.manager_code
left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
join work_day_list t4 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t4.date_key
where t1.dt > 20230801
and is_work_day = '1'
--and if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) in ('11162439','11337198','11162150','11332787')
) a
),

attendance_hours_list as(
select 
lpad(employee_no,8,'10') as staff_code
,work_shift_date
,sum(attendance_work_hours) as attendance_work_hours
from data_build.pdw_opc_shop_attendance_report_work_shift_view
where dt = '${today-1}'
and work_shift_date between '2023-08-01' and '2024-03-05' --要计算9月5号前14天，从8月22号统计
and work_shift_type in (1, 9, 12)
group by
lpad(employee_no,8,'10')
,work_shift_date
),

attendance_days_list as(
select distinct
lpad(employee_no,8,'10') as staff_code
,work_shift_date
from data_build.pdw_opc_shop_attendance_report_work_shift_view
where dt = '${today-1}'
and work_shift_date between '2023-08-01' and '2024-03-05' --要计算9月5号前14天，从8月22号统计
and work_shift_type in (1, 9, 12)
and attendance_work_hours > 0
),

is_available_list as(
SELECT distinct
target_date
,lpad(staff_code,8,'10') as staff_code
,is_available_roster
from data_smartorder.dm_roster_staff_available_di
where dt = 20240305
and target_date BETWEEN '2023-08-01' and '2024-03-05'
),

raw_list as(
select
t1.dt
,t1.new_dt
,t1.store_code
,t1.employee_id
,t1.name
,t1.hps_d_hr_status
,t1.hps_hire_type
,t1.hps_d_jobcode
,t1.manager_code
,t1.post_name
,t1.rn
,t1.rn_1
,t2.attendance_work_hours
,case when t3.staff_code is not null then '1' else '0' end as attendance_day
,t4.is_available_roster
from staff_list t1
left join attendance_hours_list t2 on t1.employee_id = t2.staff_code and t1.new_dt = t2.work_shift_date
left join attendance_days_list t3 on t1.employee_id = t3.staff_code and t1.new_dt = t3.work_shift_date
left join is_available_list t4 on t1.employee_id = t4.staff_code and t1.new_dt = t4.target_date
),

raw_list_1 as(
select
a.new_dt
,a.store_code
,a.employee_id
,a.name
,a.hps_d_hr_status
,a.hps_hire_type
,a.hps_d_jobcode
,a.manager_code
,a.post_name
,a.rn
,a.rn_1
,a.attendance_work_hours
,a.attendance_day
,a.is_available_roster

,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 7 preceding and 1 preceding) as 7_attendance_work_hours
,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 8 preceding and 1 preceding) as 8_attendance_work_hours
,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 9 preceding and 1 preceding) as 9_attendance_work_hours
,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 10 preceding and 1 preceding) as 10_attendance_work_hours
,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 11 preceding and 1 preceding) as 11_attendance_work_hours
,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 12 preceding and 1 preceding) as 12_attendance_work_hours
,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 13 preceding and 1 preceding) as 13_attendance_work_hours
,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between 14 preceding and 1 preceding) as 14_attendance_work_hours

,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 7 preceding and 1 preceding) as 7_attendance_day
,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 8 preceding and 1 preceding) as 8_attendance_day
,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 9 preceding and 1 preceding) as 9_attendance_day
,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 10 preceding and 1 preceding) as 10_attendance_day
,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 11 preceding and 1 preceding) as 11_attendance_day
,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 12 preceding and 1 preceding) as 12_attendance_day
,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 13 preceding and 1 preceding) as 13_attendance_day
,sum(a.attendance_day) over(partition by a.employee_id order by a.new_dt rows between 14 preceding and 1 preceding) as 14_attendance_day

,sum(a.is_available_roster) over(partition by a.employee_id order by a.new_dt rows between current row and 13 following) as 14_is_available --未来14天可用

,sum(a.attendance_work_hours) over(partition by a.employee_id order by a.new_dt rows between current row and 29 following) as 30_attendance_work --未来30天出勤

,b.leave_dt as leave_date --离职日期

,case when datediff(b.leave_dt,a.new_dt) <= 29 then '离职' else '在职' end as 30_leave --30天内是否离职

,c.class --店经理标签

from raw_list a
left join leave_list b on a.employee_id = b.employee_id and a.dt = b.dt
left join data_build.ods_uploads_manager_tag_4 c on a.employee_id = c.employee_id and c.dt = 20240304
)

select
post_name

--7-14天0工时
,count(distinct case when 7_attendance_work_hours = '0' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' then employee_id else null end)

--7-14天0工时&未来14天可用<=1
,count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' then employee_id else null end)

--7-14天出勤1天
,count(distinct case when 7_attendance_day = '1' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' then employee_id else null end)

--7-14天出勤1天&未来14天可用<=1
,count(distinct case when 7_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 14_is_available <= '1' then employee_id else null end)

--7-14天0工时&30天离职
,count(distinct case when 7_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 30_leave = '离职' then employee_id else null end)

--7-14天0工时&未来14天可用<=1&30天离职
,count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)

--7-14天出勤1天&30天离职
,count(distinct case when 7_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 30_leave = '离职' then employee_id else null end)

--7-14天出勤1天&未来14天可用<=1&30天离职
,count(distinct case when 7_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' then employee_id else null end)

--7-14天0工时&30天无出勤
,count(distinct case when 7_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 30_attendance_work = '0' then employee_id else null end)

--7-14天0工时&未来14天可用<=1&30天无出勤
,count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)

--7-14天出勤1天&30天无出勤
,count(distinct case when 7_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 30_attendance_work = '0' then employee_id else null end)

--7-14天出勤1天&未来14天可用<=1&30天无出勤
,count(distinct case when 7_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)

--7-14天0工时&30天离职&30天无出勤
,count(distinct case when 7_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天0工时&未来14天可用<=1&30天离职&30天无出勤
,count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天出勤1天&30天离职&30天无出勤
,count(distinct case when 7_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天出勤1天&未来14天可用<=1&30天离职&30天无出勤
,count(distinct case when 7_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天0工时&30天在职&30天无出勤
,count(distinct case when 7_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 7_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 8_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 9_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 10_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 11_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 12_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 13_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0'  and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 14_attendance_work_hours = '0' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天0工时&未来14天可用<=1&30天在职&30天无出勤
,count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' and 30_attendance_work = '0' then employee_id else null end)
-count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' and 30_leave = '离职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天出勤1天&30天在职&30天无出勤
,count(distinct case when 7_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天出勤1天&未来14天可用<=1&30天在职&30天无出勤
,count(distinct case when 7_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 14_is_available <= '1' and 30_leave = '在职' and 30_attendance_work = '0' then employee_id else null end)

--7-14天0工时&当前是店经理
,count(distinct case when 7_attendance_work_hours = '0' and class is not null then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and class is not null then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and class is not null then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and class is not null then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and class is not null then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and class is not null then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and class is not null then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and class is not null then employee_id else null end)

--7-14天0工时&未来14天可用<=1&当前是店经理
,count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' and class is not null then employee_id else null end)

--7-14天出勤1天&当前是店经理
,count(distinct case when 7_attendance_day = '1' and class is not null then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and class is not null then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and class is not null then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and class is not null then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and class is not null then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and class is not null then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and class is not null then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and class is not null then employee_id else null end)

--7-14天出勤1天&未来14天可用<=1&当前是店经理
,count(distinct case when 7_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 14_is_available <= '1' and class is not null then employee_id else null end)

--7-14天0工时&当前店经理标签银牌及以上
,count(distinct case when 7_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and class in ('钻石','金牌','银牌') then employee_id else null end)

--7-14天0工时&未来14天可用<=1&当前店经理标签银牌及以上
,count(distinct case when 7_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 8_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 9_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 10_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 11_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 12_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 13_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 14_attendance_work_hours = '0' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)

--7-14天出勤1天&当前店经理标签银牌及以上
,count(distinct case when 7_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and class in ('钻石','金牌','银牌') then employee_id else null end)

--7-14天出勤1天&未来14天可用<=1&当前店经理标签银牌及以上
,count(distinct case when 7_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 8_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 9_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 10_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 11_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 12_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 13_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)
,count(distinct case when 14_attendance_day = '1' and 14_is_available <= '1' and class in ('钻石','金牌','银牌') then employee_id else null end)

from raw_list_1
where hps_d_hr_status = '在职'
and rn > 14
and new_dt between '2023-09-05' and '2024-02-01'
group by
post_name