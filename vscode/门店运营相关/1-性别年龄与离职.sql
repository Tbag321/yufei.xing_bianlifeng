--性别年龄与离职 --data_build.dwd_staff_raw_list_v1_da
with a_list as(
select
dt
,emplid
,leave_dt
,case when leave_dt is null then 0 else 1 end as add_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt >= 20210318
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
,hps_hire_dt
,leave_dt
,hps_d_hr_status
,hps_hire_type
,hps_d_jobcode
,manager_code
,post_name
,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
,dense_rank() over(partition by employee_id order by leave_dt) as rn_2 --第几次在职
,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt) as hps_hire_date
,case when hps_d_hr_status = '离职' then '离职' else 
datediff(new_dt,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt))
end as hire_date_num
,sex
,birthday
,floor(datediff(trunc(date_sub(new_dt, (dayofmonth(new_dt) - 1)), 'MM'),trunc(date_sub(birthday, (dayofmonth(birthday) - 1)), 'MM'))/365) as age
from
(
select
t1.dt
,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,t1.hps_dept_code_lv5 as store_code
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,name
,t1.hps_hire_dt
,t3.leave_dt
,case when t3.leave_dt = '2035-12-31' then '在职'
when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
else '离职' end as hps_d_hr_status --在离职状态
,t1.hps_hire_type --用工形式
,t1.hps_d_jobcode
,t2.manager_code
,case when t1.hps_dept_descr_lv5 like '%区X%' or t1.hps_dept_descr_lv1 in ('运营管理部X') then '机动队' --0507调整机动队标签命中逻辑
when t2.manager_code is not null then '架构负责人'
when t1.hps_d_jobcode = '店副经理' then '店副经理'
when t1.hps_d_jobcode in ('店经理','门店伙伴','店员','社会PT','学生PT','见习店经理') then '店员'
else '其它' end as post_name
,t5.sex
,t5.birthday
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join --判断是否是架构负责人
(select distinct
dt
,if(length(manager_code)=6,concat('10',manager_code),manager_code) as manager_code
from data_build.pdw_opc_shop_ehr_staff_dept_view
where dt >= 20210318
) t2 on t1.dt = t2.dt and if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t2.manager_code
left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
left join data_build.ods_uploads_staff_info t5 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t5.staff_code and t5.dt = 20240310
where t1.dt >= 20210318
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
and work_shift_date >= '2021-01-01'
and work_shift_type in (1, 9, 12)
group by
lpad(employee_no,8,'10')
,work_shift_date
),

raw_list as(
select
t.dt
,t.new_dt --日期
,t.store_code --门店编码
,t.employee_id
,t.name
,t.hps_hire_dt --系统雇佣时间(没用)
,t.leave_dt --离职日期
,t.hps_d_hr_status --在离职状态
,t.hps_hire_type
,t.hps_d_jobcode
,t.manager_code
,t.post_name --岗位
,t.rn_1 --按照人*时间维度排序
,t.rn_2 --第几次入职
,t.hps_hire_date --本次雇佣周期开始日期
,t.hire_date_num --本次雇佣周期时长
,t.sex --性别
,t.birthday --生日
,t.age --年龄
,t1.attendance_work_hours --30工时
,sum(t1.attendance_work_hours) over(partition by t.employee_id order by t.new_dt rows between 30 preceding and 1 preceding) as t30_attendance_work_hours
from staff_list t
left join attendance_hours_list t1 on t.new_dt = t1.work_shift_date and t.employee_id = t1.staff_code
),

--计算当月是否一直在职
month_hire_state as(
select
month
,employee_id
,case when month_day_num = cast(hire_days as int) then '当月始终在职' else '当月没有始终在职' end as hire_state
from( 
select
trunc(new_dt,'MM') as month --月
,employee_id --员工编号
,count(new_dt) as month_day_num --当月有多少天
,sum(case when hps_d_hr_status = '在职' then '1' else '0' end) as hire_days --当月在职天数
from raw_list
group by
trunc(new_dt,'MM')
,employee_id
) a
),

--截止20240229在职天数
total_hire_date_num as(
select
employee_id
,sum(hire_date_num) as total_hire_date_num --员工雇佣的总天数(截止20240229)
from(
select distinct
employee_id
,rn_2
,hire_date_num
,row_number() over(partition by concat(employee_id,rn_2) order by dt desc) as rn
from raw_list
where hps_d_hr_status <> '离职'
) a
where rn = 1
group by
employee_id
),

protect_tag_list as(
--店员标签
SELECT
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,staff_code
,case when protect_tag_detail = 3 then null else protect_tag_detail end as protect_tag_detail --12345
,'店员' as post_name
from data_shop.dm_shop_staff_protect_tag_v2
where dt >= 20220312 --最早标签时间
--1--应保护
--2--普通
--3--待观察
--4--末位普通
--5--应离职

union all

--店副标签
select
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,staff_code
,case when protect_tag_detail = 3 then null else total_score end as protect_tag_detail --12345
,'店副经理' as post_name
from data_shop.dwd_assi_manager_protect_tag_v1_di
where dt >= 20230828  --最早标签时间
--1--金牌
--2--银牌
--3--待观察
--4--铜牌
--5--须努力

union all

--店长标签(得分)
select
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,employee_id as staff_code
,case when final_rank = 'F' then null else total_score
end as protect_tag_detail
,'架构负责人' as post_name
from data_build.dwd_manager_tag_v1_di
where dt >= 20230305  --最早标签时间
--A--金牌 --1
--B--银牌 --2
--C--铜牌 --4
--D--须努力 --5
--F--待观察 --3
--S--钻石 --0
),

--每人每月最后一天的累计在职天数
last_month_day_num as(
select
new_dt
,employee_id
,total_hire_date
from(
select
new_dt
,employee_id
,sum(auxiliary) over(partition by employee_id order by new_dt) as total_hire_date --累计在职天数
,row_number() over(partition by concat(employee_id,trunc(new_dt,'MM')) order by new_dt desc) as rn --每人每月为一组进行降序排序
from(
select 
new_dt
,employee_id
,case when rn_1 = 1 then hire_date_num
when hps_d_hr_status = '在职' then 1
when hps_d_hr_status = '离职' then 0
else null end as auxiliary
from raw_list
) a
) b
where rn = 1
),

raw_list_1 as
(
select
t.dt as dt_v1
,t.new_dt --日期
,t.store_code
,t.employee_id
,t.name
,t.hps_hire_dt --系统雇佣时间(没用)
,t.leave_dt --离职日期
,t.hps_d_hr_status --在离职状态
,t.hps_hire_type
,t.hps_d_jobcode
,t.manager_code
,t.post_name --岗位
,t.rn_1 --按照人*时间维度排序
,t.rn_2 --第几次入职
,t.hps_hire_date --本次雇佣周期开始日期
,t.hire_date_num --本次雇佣周期时长
,t.sex --性别
,t.birthday --生日
,t.age --年龄
,t.attendance_work_hours
,t.t30_attendance_work_hours --t30工时
,t1.hire_state --当月是否始终在职
,t2.total_hire_date_num --员工雇佣的总天数(截止20240229)
,t3.protect_tag_detail --保护标签
,t4.total_hire_date --每月最后一天的累计在职天数
from raw_list t
left join month_hire_state t1 on trunc(t.new_dt,'MM') = t1.month and t.employee_id = t1.employee_id
left join total_hire_date_num t2 on t.employee_id = t2.employee_id
left join protect_tag_list t3 on t.new_dt = t3.new_dt and t.employee_id = t3.staff_code and t.post_name = t3.post_name
left join last_month_day_num t4 on t.employee_id = t4.employee_id and date_sub(date_add(add_months(t.new_dt, 1), -1), day(add_months(t.new_dt, 1))-1) = t4.new_dt
),

protect_tag_list_avg as(
--不同岗位员工保护标签
select
employee_id
,post_name
,case when post_name = '店员' and protect_tag_detail is null then '待观察' 
when post_name = '店员' and protect_tag_detail < 1.94 then '应保护' 
when post_name = '店员' and protect_tag_detail < 3.06 then '普通' 
when post_name = '店员' and protect_tag_detail < 4.17 then '末位普通'
when post_name = '店员' and protect_tag_detail <= 5.00 then  '应离职'

when post_name = '店副经理' and protect_tag_detail is null then '待观察'
when post_name = '店副经理' and protect_tag_detail > 3 then '金牌' 
when post_name = '店副经理' and protect_tag_detail > 2 then '银牌'  
when post_name = '店副经理' and protect_tag_detail > 1.5 then '铜牌'
when post_name = '店副经理' and protect_tag_detail > 0 then  '须努力'

when post_name = '架构负责人' and protect_tag_detail is null then '待观察' 
when post_name = '架构负责人' and protect_tag_detail >= 4.5 then '钻石' 
when post_name = '架构负责人' and protect_tag_detail >= 3.8 then '金牌' 
when post_name = '架构负责人' and protect_tag_detail >= 3 then '银牌'
when post_name = '架构负责人' and protect_tag_detail >= 2 then  '铜牌'
when post_name = '架构负责人' and protect_tag_detail < 2 then  '须努力'
else null end as protect_tag
from(
select
employee_id
,post_name
,avg(protect_tag_detail) as protect_tag_detail  
from raw_list_1
group by
employee_id
,post_name
) a   
),

protect_tag_list_avg_month_clerk as(
--不同岗位员工保护标签(每天)  --店员
select
new_dt
,employee_id
,post_name
,case when post_name = '店员' and protect_tag_detail is null then '待观察' 
when post_name = '店员' and protect_tag_detail < 1.94 then '应保护' 
when post_name = '店员' and protect_tag_detail < 3.06 then '普通' 
when post_name = '店员' and protect_tag_detail < 4.17 then '末位普通'
when post_name = '店员' and protect_tag_detail <= 5.00 then  '应离职'
else null end as protect_tag
from(
select
new_dt
,employee_id
,post_name
,avg(protect_tag_detail) over(partition by concat(employee_id,post_name) order by new_dt rows between unbounded preceding and current row) as protect_tag_detail
from raw_list_1
) a
where post_name = '店员'
)
,

protect_tag_list_avg_month_manager as(
--不同岗位员工保护标签(每天)  --架构负责人
select
new_dt
,employee_id
,post_name
,case when post_name = '架构负责人' and protect_tag_detail is null then '待观察' 
when post_name = '架构负责人' and protect_tag_detail >= 4.5 then '钻石' 
when post_name = '架构负责人' and protect_tag_detail >= 3.8 then '金牌' 
when post_name = '架构负责人' and protect_tag_detail >= 3 then '银牌'
when post_name = '架构负责人' and protect_tag_detail >= 2 then  '铜牌'
when post_name = '架构负责人' and protect_tag_detail < 2 then  '须努力'
else null end as protect_tag
from(
select
new_dt
,employee_id
,post_name
,avg(protect_tag_detail) over(partition by concat(employee_id,post_name) order by new_dt rows between unbounded preceding and current row) as protect_tag_detail
from raw_list_1
) a
where post_name = '架构负责人'
),

protect_tag_list_avg_month_vice_manager as(
--不同岗位员工保护标签(每天)  --店副经理
select
new_dt
,employee_id
,post_name
,case when post_name = '店副经理' and protect_tag_detail is null then '待观察'
when post_name = '店副经理' and protect_tag_detail > 3 then '金牌' 
when post_name = '店副经理' and protect_tag_detail > 2 then '银牌'  
when post_name = '店副经理' and protect_tag_detail > 1.5 then '铜牌'
when post_name = '店副经理' and protect_tag_detail > 0 then  '须努力'
else null end as protect_tag
from(
select
new_dt
,employee_id
,post_name
,avg(protect_tag_detail) over(partition by concat(employee_id,post_name) order by new_dt rows between unbounded preceding and current row) as protect_tag_detail
from raw_list_1
) a
where post_name = '店副经理'
)

SELECT
t1.*
,t2.protect_tag
,t3.protect_tag as protect_tag_month_clerk
,t4.protect_tag as protect_tag_month_manager
,t5.protect_tag as protect_tag_month_vice_manager
from raw_list_1 t1
left join protect_tag_list_avg t2 on t1.employee_id = t2.employee_id and t1.post_name = t2.post_name
left join protect_tag_list_avg_month_clerk t3 on t1.employee_id = t3.employee_id and t1.new_dt = t3.new_dt
left join protect_tag_list_avg_month_manager t4 on t1.employee_id = t4.employee_id and t1.new_dt = t4.new_dt
left join protect_tag_list_avg_month_vice_manager t5 on t1.employee_id = t5.employee_id and t1.new_dt = t5.new_dt


===================================================================================================================================================================================================

--计算人均在职天数--截止到20240229当天
select
post_name
,sex
,case when age between 1 and 21 then '22以下'
when age between 22 and 25 then '22-25'
when age between 26 and 30 then '26-30'
when age between 31 and 35 then '31-35'
when age between 36 and 40 then '36-40'
when age between 41 and 45 then '41-45'
when age between 46 and 100 then '46+'
else null end as age
,count(distinct employee_id) as employee_id_num
,sum(total_hire_date_num) as sum_total_hire_date
from(
select distinct
employee_id
,post_name
,sex
,age
,total_hire_date_num
from data_build.dwd_staff_raw_list_v1_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
) a
group by
post_name
,sex
,case when age between 1 and 21 then '22以下'
when age between 22 and 25 then '22-25'
when age between 26 and 30 then '26-30'
when age between 31 and 35 then '31-35'
when age between 36 and 40 then '36-40'
when age between 41 and 45 then '41-45'
when age between 46 and 100 then '46+'
else null end

--计算离职率
select
trunc(new_dt,'MM') as month
,post_name
,case when age between 1 and 21 then '22以下'
when age between 22 and 25 then '22-25'
when age between 26 and 30 then '26-30'
when age between 31 and 35 then '31-35'
when age between 36 and 40 then '36-40'
when age between 41 and 45 then '41-45'
when age between 46 and 100 then '46+'
else null end as age
,sex

,count(distinct case when new_dt = substr(leave_dt,1,10) then employee_id else null end) as leave_usernum --离职人数

,count(distinct case when hire_state = '当月始终在职' then employee_id else null end) as do_job_usernum --当月在职没离职人数

,avg(case when new_dt = substr(leave_dt,1,10) then hire_date_num else null end) --离职人的平均在职天数

,avg(case when new_dt = substr(leave_dt,1,10) then t30_attendance_work_hours else null end) --离职人离职当天的平均t30工时

from data_build.dwd_staff_raw_list_v1_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--where rn_1 > 30 --从有记录开始要大于30天
--and hire_date_num > 30 --本次入职要大于30天
group by
trunc(new_dt,'MM')
,post_name
,case when age between 1 and 21 then '22以下'
when age between 22 and 25 then '22-25'
when age between 26 and 30 then '26-30'
when age between 31 and 35 then '31-35'
when age between 36 and 40 then '36-40'
when age between 41 and 45 then '41-45'
when age between 46 and 100 then '46+'
else null end
,sex

--计算人均在职天数*年龄的月维度离职率
select
trunc(new_dt,'MM') as month
,post_name
,case when age between 1 and 21 then '22以下'
when age between 22 and 25 then '22-25'
when age between 26 and 30 then '26-30'
when age between 31 and 35 then '31-35'
when age between 36 and 40 then '36-40'
when age between 41 and 45 then '41-45'
when age between 46 and 100 then '46+'
else null end as age
,sex

,case when total_hire_date between 0 and 30 then '1-30'
when total_hire_date between 31 and 60 then '31-60'
when total_hire_date between 61 and 90 then '61-90'
when total_hire_date between 91 and 150 then '91-150'
when total_hire_date between 151 and 300 then '151-300'
when total_hire_date between 301 and 500 then '301-500'
when total_hire_date between 501 and 12345 then '501+'
else null end as total_hire_date

,count(distinct case when new_dt = substr(leave_dt,1,10) then employee_id else null end) as leave_usernum --离职人数

,count(distinct case when hire_state = '当月始终在职' then employee_id else null end) as do_job_usernum --当月在职没离职人数

from data_build.dwd_staff_raw_list_v1_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--where rn_1 > 30 --从有记录开始要大于30天
--and hire_date_num > 30 --本次入职要大于30天
group by
trunc(new_dt,'MM')
,post_name
,case when age between 1 and 21 then '22以下'
when age between 22 and 25 then '22-25'
when age between 26 and 30 then '26-30'
when age between 31 and 35 then '31-35'
when age between 36 and 40 then '36-40'
when age between 41 and 45 then '41-45'
when age between 46 and 100 then '46+'
else null end
,sex
,case when total_hire_date between 0 and 30 then '1-30'
when total_hire_date between 31 and 60 then '31-60'
when total_hire_date between 61 and 90 then '61-90'
when total_hire_date between 91 and 150 then '91-150'
when total_hire_date between 151 and 300 then '151-300'
when total_hire_date between 301 and 500 then '301-500'
when total_hire_date between 501 and 12345 then '501+'
else null end

--计算不同年龄下的保护标签(店员)
--在有标签得分后在过职的员工
with emplid_list as(
select
employee_id
,sum(case when new_dt between '2022-03-12' and '2024-02-29' and hps_d_hr_status = '在职' then 1 else 0 end) as status_num  --在职天数
from data_build.dwd_staff_raw_list_v1_da
where dt = 20240317
and post_name = '店员'
group by
employee_id
)
select
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end as age
,count(distinct t.employee_id) as employee_num
from data_build.dwd_staff_raw_list_v1_da t
join emplid_list t1 on t.employee_id = t1.employee_id and t1.status_num > 0
where t.dt = 20240319
group by
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end

--计算不同年龄下的保护标签(架构负责人)
--在有标签得分后在过职的员工
with emplid_list as(
select
employee_id
,sum(case when new_dt between '2023-03-05' and '2024-02-29' and hps_d_hr_status = '在职' then 1 else 0 end) as status_num  --在职天数
from data_build.dwd_staff_raw_list_v1_da
where dt = 20240317
and post_name = '架构负责人'
group by
employee_id
)
select
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end as age
,count(distinct t.employee_id) as employee_num
from data_build.dwd_staff_raw_list_v1_da t
join emplid_list t1 on t.employee_id = t1.employee_id and t1.status_num > 0
where t.dt = 20240317
group by
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end

--计算不同年龄下的保护标签(店副经理)
--在有标签得分后在过职的员工
with emplid_list as(
select
employee_id
,sum(case when new_dt between '2023-08-28' and '2024-02-29' and hps_d_hr_status = '在职' then 1 else 0 end) as status_num  --在职天数
from data_build.dwd_staff_raw_list_v1_da
where dt = 20240317
and post_name = '店副经理'
group by
employee_id
)
select
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end as age
,count(distinct t.employee_id) as employee_num
from data_build.dwd_staff_raw_list_v1_da t
join emplid_list t1 on t.employee_id = t1.employee_id and t1.status_num > 0
where t.dt = 20240317
group by
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end

--年龄*人均在职天数好店员占比(店员)
with emplid_list as(
select
employee_id
,sum(case when new_dt between '2022-03-12' and '2024-02-29' and hps_d_hr_status = '在职' then 1 else 0 end) as status_num  --在职天数
from data_build.dwd_staff_raw_list_v1_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and post_name = '店员'
group by
employee_id
)
select
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end as age
,case when total_hire_date_num between 0 and 30 then '1-30'
when total_hire_date_num between 31 and 60 then '31-60'
when total_hire_date_num between 61 and 90 then '61-90'
when total_hire_date_num between 91 and 150 then '91-150'
when total_hire_date_num between 151 and 300 then '151-300'
when total_hire_date_num between 301 and 500 then '301-500'
when total_hire_date_num between 501 and 12345 then '501+'
else null end as total_hire_date_num
,count(distinct t.employee_id) as employee_num
from data_build.dwd_staff_raw_list_v1_da t
join emplid_list t1 on t.employee_id = t1.employee_id and t1.status_num > 0
where t.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and t.post_name = '店员'
group by
t.post_name
,t.sex
,t.protect_tag
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end
,case when total_hire_date_num between 0 and 30 then '1-30'
when total_hire_date_num between 31 and 60 then '31-60'
when total_hire_date_num between 61 and 90 then '61-90'
when total_hire_date_num between 91 and 150 then '91-150'
when total_hire_date_num between 151 and 300 then '151-300'
when total_hire_date_num between 301 and 500 then '301-500'
when total_hire_date_num between 501 and 12345 then '501+'
else null end

------------------------------------------------------------------------------------------------------------------------------------------------------------
with a_list as(
select
*
,case when protect_tag_month_clerk is null then 0 else 1 end as add_num_clerk
,case when protect_tag_month_manager is null then 0 else 1 end as add_num_manager
,case when protect_tag_month_vice_manager is null then 0 else 1 end as add_num_vice_manager
from data_build.dwd_staff_raw_list_v1_da
where dt = 20240320
),

b_list as(
select
*
,sum(add_num_clerk) over(partition by employee_id order by concat(new_dt,employee_id)) as sum_num_clerk
,sum(add_num_manager) over(partition by employee_id order by concat(new_dt,employee_id)) as sum_num_manager
,sum(add_num_vice_manager) over(partition by employee_id order by concat(new_dt,employee_id)) as sum_num_vice_manager
from a_list
),

c_list as(
select
*
,max(protect_tag_month_clerk) over(partition by concat(employee_id,sum_num_clerk) order by concat(new_dt,employee_id)) as protect_tag_month_clerk_v1
,max(protect_tag_month_manager) over(partition by concat(employee_id,sum_num_manager) order by concat(new_dt,employee_id)) as protect_tag_month_manager_v1
,max(protect_tag_month_vice_manager) over(partition by concat(employee_id,sum_num_vice_manager) order by concat(new_dt,employee_id)) as protect_tag_month_vice_manager_v1
from b_list
),

d_list as(  --每月最后一天不同岗位下的保护标签
select
new_dt
,employee_id
,protect_tag_month_clerk_v1
,protect_tag_month_manager_v1
,protect_tag_month_vice_manager_v1
from c_list
where new_dt = last_day(new_dt)
),

raw_list as(
select
t0.*
,protect_tag_month_clerk_v1
,protect_tag_month_manager_v1
,protect_tag_month_vice_manager_v1
from data_build.dwd_staff_raw_list_v1_da t0
left join d_list t1 on t0.employee_id = t1.employee_id and last_day(t0.new_dt) = t1.new_dt
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
),

--年龄*人均在职天数好店员占比(店员) --截止到每月最后一天
emplid_list as(
select
employee_id
,sum(case when new_dt between '2022-03-12' and '2024-02-29' and hps_d_hr_status = '在职' then 1 else 0 end) as status_num  --在职天数
from data_build.dwd_staff_raw_list_v1_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and post_name = '店员'
group by
employee_id
)

select
trunc(t.new_dt,'MM') as record_month
,t.post_name
,t.sex
,t.protect_tag_month_clerk_v1
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end as age
,case when total_hire_date between 0 and 30 then '1-30'
when total_hire_date between 31 and 60 then '31-60'
when total_hire_date between 61 and 90 then '61-90'
when total_hire_date between 91 and 150 then '91-150'
when total_hire_date between 151 and 300 then '151-300'
when total_hire_date between 301 and 500 then '301-500'
when total_hire_date between 501 and 12345 then '501+'
else null end as total_hire_date_num
,count(distinct t.employee_id) as employee_num
from raw_list t
join emplid_list t1 on t.employee_id = t1.employee_id and t1.status_num > 0
where t.post_name = '店员'
group by
trunc(t.new_dt,'MM')
,t.post_name
,t.sex
,t.protect_tag_month_clerk_v1
,case when t.age between 1 and 21 then '22以下'
when t.age between 22 and 25 then '22-25'
when t.age between 26 and 30 then '26-30'
when t.age between 31 and 35 then '31-35'
when t.age between 36 and 40 then '36-40'
when t.age between 41 and 45 then '41-45'
when t.age between 46 and 100 then '46+'
else null end
,case when total_hire_date between 0 and 30 then '1-30'
when total_hire_date between 31 and 60 then '31-60'
when total_hire_date between 61 and 90 then '61-90'
when total_hire_date between 91 and 150 then '91-150'
when total_hire_date between 151 and 300 then '151-300'
when total_hire_date between 301 and 500 then '301-500'
when total_hire_date between 501 and 12345 then '501+'
else null end