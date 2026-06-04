with a_list as(
select
*
,case when protect_tag_month_clerk is null then 0 else 1 end as add_num_clerk
,case when protect_tag_month_manager is null then 0 else 1 end as add_num_manager
,case when protect_tag_month_vice_manager is null then 0 else 1 end as add_num_vice_manager
from data_build.dwd_staff_raw_list_v1_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
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

vacation_situation as(  --员工请假情况统计
select
apply_date
,leavepeople
,count(distinct order_id)  as vacation_number  --请假次数
,count(distinct substr(diff_start_time,1,10)) as vacation_day --请假天数
,sum(vacation_time) as vacation_times  --请假总时长
from
(select
substr(t0.create_date,1,10) as apply_date --申请日期
,t0.order_id --流程编码
,t0.leavepeople --申请员工编码
,t0.diff_start_time --影响班次开始时间
,t0.diff_end_time --影响班次结束时间
,(unix_timestamp(t0.diff_end_time) - unix_timestamp(t0.diff_start_time))/3600 as vacation_time
from data_shop.app_internal_control_vacation_da_view t0
where t0.dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
and t0.vacationname = '事假' --请假类型
and reason = '临时身体不适'  --病假
group by
substr(t0.create_date,1,10)
,t0.order_id
,t0.leavepeople
,t0.diff_start_time
,t0.diff_end_time
) a
group by
apply_date
,leavepeople
),

raw_list_1 as(
select
t0.*
,t1.vacation_number --请假次数
,t1.vacation_day --请假天数
,t1.vacation_times --请假总时长
,row_number() over(partition by concat(t0.employee_id,t0.post_name,t0.rn_2) order by t0.dt_v1) as post_number --当次入职在某一个岗位上的工作天数
,case when datediff(t0.leave_dt,t0.new_dt) < 0 then '离职' else datediff(t0.leave_dt,t0.new_dt) end as leave_countdown --离职倒计时
from raw_list t0
left join vacation_situation t1 on t0.new_dt = t1.apply_date and t0.employee_id = t1.leavepeople
--where employee_id in ('11176717','11162439')
)

select
trunc(new_dt,'MM') as record_month --月份
,protect_tag_month_clerk_v1 --每月的店员保护标签

--全量店员
,count(distinct employee_id) as employee_num --人数
,count(distinct case when vacation_number > 0 then employee_id else null end) as employee_vacation_num --请假人数
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

--好店员
,count(distinct case when post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_num --人数
,count(distinct case when vacation_number > 0 and post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_vacation_num --请假人数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_number else 0 end) as toatal_vacation_number --请假总次数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_day else 0 end) as toatal_vacation_day --请假总天数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_times else 0 end) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '店员'
and hps_d_hr_status = '在职'
group by
trunc(new_dt,'MM')
,protect_tag_month_clerk_v1

union all

select
trunc(new_dt,'MM') as record_month --月份
,protect_tag_month_manager_v1 --每月的店员保护标签

--全量架构负责人
,count(distinct employee_id) as employee_num --人数
,count(distinct case when vacation_number > 0 then employee_id else null end) as employee_vacation_num --请假人数
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

--好架构负责人
,count(distinct case when post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_num --人数
,count(distinct case when vacation_number > 0 and post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_vacation_num --请假人数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_number else 0 end) as toatal_vacation_number --请假总次数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_day else 0 end) as toatal_vacation_day --请假总天数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_times else 0 end) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '架构负责人'
and hps_d_hr_status = '在职'
group by
trunc(new_dt,'MM')
,protect_tag_month_manager_v1

union all

select
trunc(new_dt,'MM') as record_month --月份
,protect_tag_month_vice_manager_v1 --每月的店员保护标签

--全量店副经理
,count(distinct employee_id) as employee_num --人数
,count(distinct case when vacation_number > 0 then employee_id else null end) as employee_vacation_num --请假人数
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

--好店副经理
,count(distinct case when post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_num --人数
,count(distinct case when vacation_number > 0 and post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_vacation_num --请假人数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_number else 0 end) as toatal_vacation_number --请假总次数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_day else 0 end) as toatal_vacation_day --请假总天数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_times else 0 end) as toatal_vacation_times --请假总时长


from raw_list_1
where post_name = '店副经理'
and hps_d_hr_status = '在职'
group by
trunc(new_dt,'MM')
,protect_tag_month_vice_manager_v1

-------------------------------------------------------------------------------------------------------------------------------------------------------
select
'全量店员' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
trunc(new_dt,'MM') as record_month --月份
,employee_id
,protect_tag_month_clerk_v1 --每月的店员保护标签

--全量店员
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长
from raw_list_1
where post_name = '店员'
and hps_d_hr_status = '在职'
and vacation_number > 0
and new_dt between '2023-01-01' and '2024-02-29'
group by
trunc(new_dt,'MM')
,employee_id
,protect_tag_month_clerk_v1
) a

union all

select
'好店员' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
trunc(new_dt,'MM') as record_month --月份
,employee_id
,protect_tag_month_clerk_v1 --每月的店员保护标签

--全量店员
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长
from raw_list_1
where post_name = '店员'
and hps_d_hr_status = '在职'
and vacation_number > 0
and post_number > 150
and leave_countdown > 15
and new_dt between '2023-01-01' and '2024-02-29'
and protect_tag_month_clerk_v1 in ('应保护','普通')
group by
trunc(new_dt,'MM')
,employee_id
,protect_tag_month_clerk_v1
) a

union all

select
'全量架构负责人' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
trunc(new_dt,'MM') as record_month --月份
,employee_id
,protect_tag_month_manager_v1 --每月的店员保护标签

--全量架构负责人
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '架构负责人'
and hps_d_hr_status = '在职'
and vacation_number > 0
and new_dt between '2023-03-01' and '2024-02-29'
group by
trunc(new_dt,'MM')
,employee_id
,protect_tag_month_manager_v1
) a

union all

select
'好架构负责人' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
trunc(new_dt,'MM') as record_month --月份
,employee_id
,protect_tag_month_manager_v1 --每月的店员保护标签

--好架构负责人
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '架构负责人'
and hps_d_hr_status = '在职'
and vacation_number > 0
and post_number > 150
and leave_countdown > 15
and new_dt between '2023-03-01' and '2024-02-29'
and protect_tag_month_manager_v1 in ('钻石','金牌','银牌')
group by
trunc(new_dt,'MM')
,employee_id
,protect_tag_month_manager_v1
) a

union all

select
'全量店副' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
trunc(new_dt,'MM') as record_month --月份
,employee_id
,protect_tag_month_vice_manager_v1 --每月的店员保护标签

--全量店副经理
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '店副经理'
and hps_d_hr_status = '在职'
and vacation_number > 0
and new_dt between '2023-10-01' and '2024-02-29'
group by
trunc(new_dt,'MM')
,employee_id
,protect_tag_month_vice_manager_v1
) a

union all

select
'好店副' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
trunc(new_dt,'MM') as record_month --月份
,employee_id
,protect_tag_month_vice_manager_v1 --每月的店员保护标签

--好店副经理
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '店副经理'
and hps_d_hr_status = '在职'
and vacation_number > 0
and post_number > 150
and leave_countdown > 15
and new_dt between '2023-10-01' and '2024-02-29'
and protect_tag_month_vice_manager_v1 in ('金牌','银牌')
group by
trunc(new_dt,'MM')
,employee_id
,protect_tag_month_vice_manager_v1
) a

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
select
case when new_dt between '2023-01-01' and '2023-06-30' then '23H1'
when new_dt between '2023-07-01' and '2023-12-31' then '23H2' else null end as record_year --月份
,protect_tag --全周期保护标签

--全量店员
,count(distinct employee_id) as employee_num --人数
,count(distinct case when vacation_number > 0 then employee_id else null end) as employee_vacation_num --请假人数
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

--好店员
,count(distinct case when post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_num --人数
,count(distinct case when vacation_number > 0 and post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_vacation_num --请假人数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_number else 0 end) as toatal_vacation_number --请假总次数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_day else 0 end) as toatal_vacation_day --请假总天数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_times else 0 end) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '店员'
and hps_d_hr_status = '在职'
group by
case when new_dt between '2023-01-01' and '2023-06-30' then '23H1'
when new_dt between '2023-07-01' and '2023-12-31' then '23H2' else null end
,protect_tag --全周期保护标签

union all

select
case when new_dt between '2023-03-01' and '2023-08-31' then '23H1'
when new_dt between '2023-09-01' and '2024-02-29' then '23H2' else null end as record_year --月份
,protect_tag --全周期保护标签

--全量架构负责人
,count(distinct employee_id) as employee_num --人数
,count(distinct case when vacation_number > 0 then employee_id else null end) as employee_vacation_num --请假人数
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

--好架构负责人
,count(distinct case when post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_num --人数
,count(distinct case when vacation_number > 0 and post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_vacation_num --请假人数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_number else 0 end) as toatal_vacation_number --请假总次数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_day else 0 end) as toatal_vacation_day --请假总天数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_times else 0 end) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '架构负责人'
and hps_d_hr_status = '在职'
group by
case when new_dt between '2023-03-01' and '2023-08-31' then '23H1'
when new_dt between '2023-09-01' and '2024-02-29' then '23H2' else null end
,protect_tag --全周期保护标签

union all

select
case when new_dt between '2023-10-01' and '2024-02-29' then '23H2'
else null end as record_year --月份
,protect_tag --全周期保护标签

--全量店副经理
,count(distinct employee_id) as employee_num --人数
,count(distinct case when vacation_number > 0 then employee_id else null end) as employee_vacation_num --请假人数
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

--好店副经理
,count(distinct case when post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_num --人数
,count(distinct case when vacation_number > 0 and post_number > 150 and leave_countdown > 15 then employee_id else null end) as employee_vacation_num --请假人数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_number else 0 end) as toatal_vacation_number --请假总次数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_day else 0 end) as toatal_vacation_day --请假总天数
,sum(case when post_number > 150 and leave_countdown > 15 then vacation_times else 0 end) as toatal_vacation_times --请假总时长


from raw_list_1
where post_name = '店副经理'
and hps_d_hr_status = '在职'
group by
case when new_dt between '2023-10-01' and '2024-02-29' then '23H2'
else null end
,protect_tag --全周期保护标签

---------------------------------------------------------------------------------------------------------------------------------------------------------------
select
'全量店员' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
case when new_dt between '2023-01-01' and '2023-06-30' then '23H1'
when new_dt between '2023-07-01' and '2023-12-31' then '23H2' else null end as record_year --月份
,employee_id
,protect_tag --全周期保护标签

--全量店员
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长
from raw_list_1
where post_name = '店员'
and hps_d_hr_status = '在职'
and vacation_number > 0
and new_dt between '2023-01-01' and '2024-02-29'
group by
case when new_dt between '2023-01-01' and '2023-06-30' then '23H1'
when new_dt between '2023-07-01' and '2023-12-31' then '23H2' else null end
,employee_id
,protect_tag --全周期保护标签
) a

union all

select
'好店员' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
case when new_dt between '2023-01-01' and '2023-06-30' then '23H1'
when new_dt between '2023-07-01' and '2023-12-31' then '23H2' else null end as record_year --月份
,employee_id
,protect_tag --全周期保护标签

--全量店员
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长
from raw_list_1
where post_name = '店员'
and hps_d_hr_status = '在职'
and vacation_number > 0
and post_number > 150
and leave_countdown > 15
and new_dt between '2023-01-01' and '2024-02-29'
and protect_tag_month_clerk_v1 in ('应保护','普通')
group by
case when new_dt between '2023-01-01' and '2023-06-30' then '23H1'
when new_dt between '2023-07-01' and '2023-12-31' then '23H2' else null end
,employee_id
,protect_tag --全周期保护标签
) a

union all

select
'全量架构负责人' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
case when new_dt between '2023-03-01' and '2023-08-31' then '23H1'
when new_dt between '2023-09-01' and '2024-02-29' then '23H2' else null end as record_year --月份
,employee_id
,protect_tag --全周期保护标签

--全量架构负责人
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '架构负责人'
and hps_d_hr_status = '在职'
and vacation_number > 0
and new_dt between '2023-03-01' and '2024-02-29'
group by
case when new_dt between '2023-03-01' and '2023-08-31' then '23H1'
when new_dt between '2023-09-01' and '2024-02-29' then '23H2' else null end
,employee_id
,protect_tag --全周期保护标签
) a

union all

select
'好架构负责人' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
case when new_dt between '2023-03-01' and '2023-08-31' then '23H1'
when new_dt between '2023-09-01' and '2024-02-29' then '23H2' else null end as record_year --月份
,employee_id
,protect_tag --全周期保护标签

--好架构负责人
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '架构负责人'
and hps_d_hr_status = '在职'
and vacation_number > 0
and post_number > 150
and leave_countdown > 15
and new_dt between '2023-03-01' and '2024-02-29'
and protect_tag_month_manager_v1 in ('钻石','金牌','银牌')
group by
case when new_dt between '2023-03-01' and '2023-08-31' then '23H1'
when new_dt between '2023-09-01' and '2024-02-29' then '23H2' else null end
,employee_id
,protect_tag --全周期保护标签
) a

union all

select
'全量店副' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
case when new_dt between '2023-10-01' and '2024-02-29' then '23H2'
else null end as record_year --月份
,employee_id
,protect_tag --全周期保护标签

--全量店副经理
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '店副经理'
and hps_d_hr_status = '在职'
and vacation_number > 0
and new_dt between '2023-10-01' and '2024-02-29'
group by
case when new_dt between '2023-10-01' and '2024-02-29' then '23H2'
else null end
,employee_id
,protect_tag --全周期保护标签
) a

union all

select
'好店副' as post_name
,percentile_approx(toatal_vacation_number,0.5)
,percentile_approx(toatal_vacation_day,0.5)
,percentile_approx(toatal_vacation_times,0.5)
from(
select
case when new_dt between '2023-10-01' and '2024-02-29' then '23H2'
else null end as record_year --月份
,employee_id
,protect_tag --全周期保护标签

--好店副经理
,sum(vacation_number) as toatal_vacation_number --请假总次数
,sum(vacation_day) as toatal_vacation_day --请假总天数
,sum(vacation_times) as toatal_vacation_times --请假总时长

from raw_list_1
where post_name = '店副经理'
and hps_d_hr_status = '在职'
and vacation_number > 0
and post_number > 150
and leave_countdown > 15
and new_dt between '2023-10-01' and '2024-02-29'
and protect_tag_month_vice_manager_v1 in ('金牌','银牌')
group by
case when new_dt between '2023-10-01' and '2024-02-29' then '23H2'
else null end
,employee_id
,protect_tag --全周期保护标签
) a