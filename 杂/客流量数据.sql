--进店客流数据可用状态。计算交易转化率，只考虑 状态2和3
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

select 
 from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
 ,store_code
 ,store_status
 from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view t
 where dt >= date_format(date_sub(current_date(),1365),'yyyyMMdd')
 and store_status in ('0','1','2','3') --3可用, 2低置信可用, 1不可用, 0初始状态

--店外客流 进店客流
select 
 store_code as shop_id
 ,event_date
 --,time_hour as event_hour --小时
 --,come_customer_num
 --,go_customer_num --进店客流
 --,outside_flow_cnt_in
 ,sum(outside_flow_cnt_out) --店外客流
from data_smartorder.dm_ordering_report_store_change_info_di t
left join desensitization b on t.store_code = b.store_code
where dt >= date_format(date_sub(current_date(),1365),'yyyyMMdd')
and b.store_cvs_code = '100000696'
group by
 store_code
 ,event_date




--交易转换率-日-大盘-周维度
with valid_store as(
    select
    from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date,
    store_code
    from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view
    where dt >= 20160101
    and store_status in ('3','2')
    group by from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),store_code
)

select
date_add(x.event_date,1 - case when dayofweek(x.event_date) = 1 then 7 else dayofweek(x.event_date) - 1 end) as order_week,
sum(x.go_customer_num) as go_customer_num,
sum(x.order_num_all) as order_num_all,
sum(x.order_num_all)*1.0000/sum(x.go_customer_num) as rate
from(
select
a.store_code,
a.event_date,
sum(go_customer_num) as go_customer_num,
sum(order_num_all) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate
from data_smartorder.dm_ordering_report_store_change_info_di a
join valid_store b
on a.store_code=b.store_code
and a.event_date=b.record_date
where a.dt between 20160101 and 20220826
group by
a.store_code,
a.event_date) x
group by date_add(x.event_date,1 - case when dayofweek(x.event_date) = 1 then 7 else dayofweek(x.event_date) - 1 end)



--交易转换率-日-门店维度-周维度
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

valid_store as(
    select
    from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date,
    store_code,
    store_status
    from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view
    where dt >= 20160101
    and store_status in ('3','2')
    group by from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),store_code,store_status
)

select
date_add(a.event_date,1 - case when dayofweek(a.event_date) = 1 then 1 else dayofweek(a.event_date) - 7 end) as week,
c.store_cvs_code,
c.display_name,
count(distinct a.event_date) as valid_num,
sum(go_customer_num) as go_customer_num,
sum(order_num_all) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate
from data_smartorder.dm_ordering_report_store_change_info_di a
left join valid_store b
on a.store_code=b.store_code
and a.event_date=b.record_date
left join desensitization c on a.store_code = c.store_code
where a.dt between 20210101 and 20221031
and b.store_status is not null
group by
date_add(a.event_date,1 - case when dayofweek(a.event_date) = 1 then 1 else dayofweek(a.event_date) - 7 end),
c.store_cvs_code,
c.display_name




--交易转换率-日-门店维度-月维度
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

valid_store as(
    select
    from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date,
    store_code,
    store_status
    from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view
    where dt >= 20160101
    and store_status in ('3','2')
    group by from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),store_code,store_status
)

select
trunc(a.event_date,'MM') as month,
c.store_cvs_code,
c.display_name,
count(distinct a.event_date) as valid_num,
sum(go_customer_num) as customer_no,
sum(order_num_all) as order_no,
sum(go_customer_num)*1.0000/count(distinct a.event_date) as go_customer_num,
sum(order_num_all)*1.0000/count(distinct a.event_date) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate,
sum(payable_price)*1.0000/count(distinct a.event_date) as sale
from data_smartorder.dm_ordering_report_store_change_info_di a
left join valid_store b
on a.store_code=b.store_code
and a.event_date=b.record_date
left join desensitization c on a.store_code = c.store_code
where a.dt between 20210801 and 20210831
and b.store_status is not null
group by
trunc(a.event_date,'MM'),
c.store_cvs_code,
c.display_name

----交易转换率-日-门店维度-小时
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

valid_store as(
    select
    from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date,
    store_code,
    store_status
    from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view
    where dt >= 20160101
    and store_status in ('3','2')
    group by from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),store_code,store_status
),

date_list as(
    select
    date_key,
    case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
    from default.dim_date_ya_v2
 )

select
trunc(event_date,'MM') as month,
d.date_type,
time_hour,
c.store_cvs_code,
c.display_name,
count(distinct a.event_date) as valid_num,
sum(go_customer_num) as go_customer_num,
sum(order_num_all) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate
from data_smartorder.dm_ordering_report_store_change_info_di a
left join valid_store b
on a.store_code=b.store_code
and a.event_date=b.record_date
left join desensitization c on a.store_code = c.store_code
left join date_list d on a.event_date = d.date_key 
where a.dt between 20220801 and 20220831
and b.store_status is not null
group by
trunc(event_date,'MM'),
d.date_type,
time_hour,
c.store_cvs_code,
c.display_name

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店店外客流
--工作日列表
with work_day_list as(
select
date_key
,case when is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
)
 
--店外客流 进店客流
select 
t.store_code as shop_id
,date_add(t.event_date,7 - case when dayofweek(t.event_date) = 1 then 7 else dayofweek(t.event_date) - 1 end) as record_week
--,c.is_working_day
--,time_hour as event_hour --小时
--,come_customer_num
--,go_customer_num --进店客流
--,outside_flow_cnt_in
,sum(outside_flow_cnt_out)/count(distinct concat(t.store_code,t.event_date)) --店外客流
from data_smartorder.dm_ordering_report_store_change_info_di t
left join work_day_list c on t.event_date = c.date_key
where dt >= date_format(date_sub(current_date(),2365),'yyyyMMdd')
--and b.store_cvs_code = '123000367'
group by
t.store_code
,date_add(t.event_date,7 - case when dayofweek(t.event_date) = 1 then 7 else dayofweek(t.event_date) - 1 end)
--,c.is_working_day

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店进店转化率&交易转化率
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

--工作日列表
work_day_list as(
select
date_key
,case when is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--置信度表
Confidence_list as(
select 
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,store_code
,store_status
from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view t
where dt >= date_format(date_sub(current_date(),2365),'yyyyMMdd')
and store_status in ('0','1','2','3') --3可用, 2低置信可用, 1不可用, 0初始状态
)

select
--a.event_date,
c.store_cvs_code,
--c.display_name,
--d.is_working_day,
count(distinct a.event_date) as valid_num,
sum(outside_flow_cnt_out) as outside_flow_cnt_out,
sum(go_customer_num) as go_customer_num,
sum(order_num_all) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate
from data_smartorder.dm_ordering_report_store_change_info_di a
left join Confidence_list b on a.store_code=b.store_code and a.event_date=b.record_date
left join desensitization c on a.store_code = c.store_code
left join work_day_list d on a.event_date = d.date_key
where a.dt between 20230327 and 20230618
and b.store_status in ('2','3')
--and c.store_cvs_code = '233000005'
group by
--a.event_date,
c.store_cvs_code,
--c.display_name
--,d.is_working_day
----------------------------------------------------------------------------------------------------------------------------------
--工作日列表
with work_day_list as(
select
date_key
,case when is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
)
 
--店外客流 进店客流
select
date_add(t.event_date,7 - case when dayofweek(t.event_date) = 1 then 7 else dayofweek(t.event_date) - 1 end) as record_week
,t.store_code as shop_id
--,t.event_date
,c.is_working_day
--,time_hour as event_hour --小时
--,come_customer_num
--,go_customer_num --进店客流
--,outside_flow_cnt_in
,sum(outside_flow_cnt_out)/count(distinct concat(t.store_code,t.event_date)) --店外客流
from data_smartorder.dm_ordering_report_store_change_info_di t
left join work_day_list c on t.event_date = c.date_key
where dt between '20211201' and '20231231'
and t.store_code in ('100000630',
'100000311',
'123000622',
'123000088',
'123001001',
'123001009',
'123000081',
'123000355',
'123000317',
'123001016',
'123000363',
'100000268',
'123000070',
'123000385',
'100076007',
'123000393')
group by
date_add(t.event_date,7 - case when dayofweek(t.event_date) = 1 then 7 else dayofweek(t.event_date) - 1 end)
,t.store_code
--,event_date
,c.is_working_day

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--周维度进店客流&交易转化率
--工作日列表
with work_day_list as(
select
date_key
,case when is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--置信度表
Confidence_list as(
select 
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,store_code
,store_status
from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view t
where dt >= date_format(date_sub(current_date(),2365),'yyyyMMdd')
and store_status in ('0','1','2','3') --3可用, 2低置信可用, 1不可用, 0初始状态
)

select
date_add(a.event_date,7 - case when dayofweek(a.event_date) = 1 then 7 else dayofweek(a.event_date) - 1 end) as record_week,
a.store_code,
--d.is_working_day,
count(distinct a.event_date) as valid_num,
sum(outside_flow_cnt_out)/count(distinct a.event_date) as outside_flow_cnt_out,
sum(go_customer_num)/count(distinct a.event_date) as go_customer_num,
sum(order_num_all)/count(distinct a.event_date) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate
from data_smartorder.dm_ordering_report_store_change_info_di a
left join Confidence_list b on a.store_code=b.store_code and a.event_date=b.record_date
left join work_day_list d on a.event_date = d.date_key
where a.dt >= date_format(date_sub(current_date(),2365),'yyyyMMdd')
and b.store_status in ('2','3')
group by
date_add(a.event_date,7 - case when dayofweek(a.event_date) = 1 then 7 else dayofweek(a.event_date) - 1 end),
a.store_code
--,d.is_working_day