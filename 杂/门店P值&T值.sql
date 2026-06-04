with reward_level_list as 
(
select 
*
,date_add(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),1)  as record_date
from 
data_build.dwd_store_construction_store_groups_recruit_gap
where dt >= date_format(date_sub(current_date(),9),'yyyyMMdd')
)


select 
t1.*
,t2.group_level as group_level_yesterday
,t2.priority_level as priority_level_yesterday
,t2.difficulty_level as difficulty_level_yesterday
,t2.reward_level as reward_level_yesterday
,t2.reward_level_night as reward_level_night_yesterday
,date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
,case when t1.reward_level in ('P2','P3','P4','P5') and t2.reward_level in ('P1','P0') then 1 else 0 end as inflow_day
,case when t1.reward_level_night in ('P2','P3','P4','P5') and t2.reward_level_night in ('P1','P0') then 1 else 0 end as inflow_night
,case when t1.reward_level in ('P1','P0') and t2.reward_level in ('P2','P3','P4','P5') then 1 else 0 end as outflow_day
,case when t1.reward_level_night in ('P1','P0') and t2.reward_level_night in ('P2','P3','P4','P5') then 1 else 0 end as outflow_night
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join reward_level_list t2 on t1.store_code = t2.store_code and t2.record_date = from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd')
where t1.dt >= date_format(date_sub(current_date(),8),'yyyyMMdd')

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--门店周均P值
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
display_name)

select
date_add(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),7 - case when dayofweek(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)) = 1 then 7 else dayofweek(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)) - 1 end) as record_week
,t2.store_cvs_code
,t2.display_name
,sum(substr(t1.reward_level,2,1))/count(t2.store_cvs_code) as reward_level_avg
,sum(substr(t1.reward_level_night,2,1))/count(t2.store_cvs_code) as reward_level_night_avg
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join desensitization t2 on t1.store_code = t2.store_code
where t1.dt >= date_format(date_sub(current_date(),1888),'yyyyMMdd')
and t2.store_cvs_code = '100000288'
group by
date_add(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),7 - case when dayofweek(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)) = 1 then 7 else dayofweek(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)) - 1 end)
,t2.store_cvs_code
,t2.display_name

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店日P值
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

--P值日list
P_list as(
select
from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
,t2.store_cvs_code
,t2.display_name
,sum(substr(t1.reward_level,2,1))/count(t2.store_cvs_code) as reward_level_avg
,sum(substr(t1.reward_level_night,2,1))/count(t2.store_cvs_code) as reward_level_night_avg
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join desensitization t2 on t1.store_code = t2.store_code
where t1.dt >= date_format(date_sub(current_date(),1888),'yyyyMMdd')
and t2.store_cvs_code = '100000288'
group by
from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd')
,t2.store_cvs_code
,t2.display_name
)

--均值
select
store_cvs_code
,display_name
,count(case when reward_level_avg is not null then store_cvs_code end)
,count(case when reward_level_night_avg is not null then store_cvs_code end)
,sum(reward_level_avg)/count(case when reward_level_avg is not null then store_cvs_code end)
,sum(reward_level_night_avg)/count(case when reward_level_night_avg is not null then store_cvs_code end)
from P_list
where record_date between '2022-12-01' and '2022-03-05'
group by
store_cvs_code
,display_name

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--门店周均T值
with desensitization as(
select
store_code,
--store_name,
store_cvs_code,
--display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
group by
store_code,
--store_name,
store_cvs_code,
--display_name
)

select
date_add(alarm_start_date,7 - case when dayofweek(alarm_start_date) = 1 then 7 else dayofweek(alarm_start_date) - 1 end) as record_week
,t2.store_cvs_code
--,t2.display_name
,sum(substr(final_level_modify,2,1))/count(t2.store_cvs_code) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
left join desensitization t2 on t1.shop_id = t2.store_code
where t1.dt = '20230521'
--and t2.store_cvs_code = '100000015'
group by
date_add(alarm_start_date,7 - case when dayofweek(alarm_start_date) = 1 then 7 else dayofweek(alarm_start_date) - 1 end)
,t2.store_cvs_code
--,t2.display_name

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店T值
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
display_name)

select
t1.alarm_start_date
,t2.store_cvs_code
,t2.display_name
,sum(substr(final_level_modify,2,1))/count(t2.store_cvs_code) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
left join desensitization t2 on t1.shop_id = t2.store_code
where t1.dt = '20230611'
and t2.store_cvs_code in ('100000215','100000302','101000211','100002598','101000208','108000013','108000020')
group by
t1.alarm_start_date
,t2.store_cvs_code
,t2.display_name

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
display_name)

--P值日list
select
from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
,t2.store_cvs_code
,t2.display_name
,sum(substr(t1.reward_level,2,1))/count(t2.store_cvs_code) as reward_level_avg
,sum(substr(t1.reward_level_night,2,1))/count(t2.store_cvs_code) as reward_level_night_avg
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join desensitization t2 on t1.store_code = t2.store_code
where t1.dt >= date_format(date_sub(current_date(),1888),'yyyyMMdd')
and t2.store_cvs_code = '100000696'
group by
from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd')
,t2.store_cvs_code
,t2.display_name

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店周均T值
select
date_add(alarm_start_date,7 - case when dayofweek(alarm_start_date) = 1 then 7 else dayofweek(alarm_start_date) - 1 end) as record_week
,shop_id
,sum(substr(final_level_modify,2,1))/count(shop_id) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
where t1.dt = '20230712'
--and alarm_start_date between '2023-05-15' and '2023-06-11'
group by
date_add(alarm_start_date,7 - case when dayofweek(alarm_start_date) = 1 then 7 else dayofweek(alarm_start_date) - 1 end)
,shop_id

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店过去六个月T值80%分位（0109-0709）
--T值明细
with T_list as(
select
dt
,shop_id
,sum(substr(final_level_modify,2,1))/count(alarm_start_date) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and alarm_start_date between '2023-01-09' and '2023-07-09'
group by
dt
,shop_id),

eighty_percentile as(
select
dt
,percentile_approx(final_t_level_avg,0.8) as eighty_percentile
from T_list
group by dt
)

select
shop_id
,final_t_level_avg
,eighty_percentile
from T_list a left join eighty_percentile b on a.dt = b.dt

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

select
'22H2' as record_time
,shop_id
,sum(substr(final_level_modify,2,1))/count(alarm_start_date) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and alarm_start_date between '2022-07-01' and '2022-12-31'
group by
shop_id
,'22H2'
union all
select
'23Q1' as record_time
,shop_id
,sum(substr(final_level_modify,2,1))/count(alarm_start_date) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and alarm_start_date between '2023-01-01' and '2023-03-31'
group by
shop_id
,'22Q1'
union all
select
'23Q2' as record_time
,shop_id
,sum(substr(final_level_modify,2,1))/count(alarm_start_date) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and alarm_start_date between '2023-04-01' and '2023-06-30'
group by
shop_id
,'23Q2'
union all
select
'最近七天' as record_time
,shop_id
,sum(substr(final_level_modify,2,1))/count(alarm_start_date) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and alarm_start_date between '2023-07-04' and '2023-07-10'
group by
shop_id
,'最近七天'

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--4月T值
with four_T as
(select
trunc(alarm_start_date,'MM') as four_T_month
,shop_id
,sum(substr(final_level_modify,2,1))/count(shop_id) as four_final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
where t1.dt = '20230623'
and alarm_start_date between '2023-04-01' and '2023-04-30'
group by
trunc(alarm_start_date,'MM')
,shop_id
),

--6月T值
six_T as
(select
trunc(alarm_start_date,'MM') as six_T_month
,shop_id
,sum(substr(final_level_modify,2,1))/count(shop_id) as six_final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
where t1.dt = '20230623'
and alarm_start_date between '2023-06-01' and '2023-06-18'
group by
trunc(alarm_start_date,'MM')
,shop_id
),

--4月日商
four_sell as
(select
trunc(order_date,'MM') as four_sell_month
,store_code 
,sum(t.payable_price)/count(distinct order_date) as four_payable_price --折后销售额
from dw_order_sku_v1 t
where t.dt = '20230623'
and order_date between '20230401' and '20230618'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
group BY
trunc(order_date,'MM')
,store_code 
)

select
trunc(t.order_date,'MM') as month
,t.store_code as store_code
,a.four_final_t_level_avg as four_final_t_level_avg
,b.six_final_t_level_avg as six_final_t_level_avg
,c.four_payable_price as four_payable_price
,sum(t.payable_price)/count(distinct t.order_date) as six_payable_price --折后销售额
from dw_order_sku_v1 t
left join four_T a on t.store_code = a.shop_id
left join six_T b on t.store_code = b.shop_id
left join four_sell c on t.store_code = c.store_code
where t.dt = '20230623'
and order_date between '20230401' and '20230618'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
group BY
trunc(t.order_date,'MM')
,t.store_code
,a.four_final_t_level_avg
,b.six_final_t_level_avg
,c.four_payable_price

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--T30店长得分
select 
t0.store_code as store_code
,t0.total_score as total_score
,t0.final_rank as final_rank
,case when t0.final_rank = 'S' then '钻石'
when t0.final_rank = 'A' then '金牌'
when t0.final_rank = 'B' then '银牌'
when t0.final_rank = 'C' then '铜牌'
when t0.final_rank = 'D' then '须努力'
when t0.final_rank = 'F' then '待观察'
else null end as protect_tag
,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
from data_build.dwd_manager_tag_v1_di t0
where t0.dt >=20230101

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店过去7天T值平均分
select
shop_id
,sum(substr(final_level_modify,2,1))/count(shop_id) as seven_final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view
--from data_smartorder.dwd_ic_new_import_store_level_da_view
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and alarm_start_date between date_sub(current_date(),7) and date_sub(current_date(),1)
group by
shop_id


--T-1天门店T30店长得分
select 
t0.store_code as store_code
,t0.total_score as total_score
,t0.final_rank as final_rank
,case when t0.final_rank = 'S' then '钻石'
when t0.final_rank = 'A' then '金牌'
when t0.final_rank = 'B' then '银牌'
when t0.final_rank = 'C' then '铜牌'
when t0.final_rank = 'D' then '须努力'
when t0.final_rank = 'F' then '待观察'
else null end as protect_tag
,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
from data_build.dwd_manager_tag_v1_di t0
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')

---------------------------------------------------------------------------------------------------------------------
--6.18过去30天T值平均值（5.20-6.18）
select
shop_id
,sum(substr(final_level_modify,2,1))/count(shop_id) as seven_final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view
--from data_smartorder.dwd_ic_new_import_store_level_da_view
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and alarm_start_date between '2023-05-20' and '2023-06-18'
group by
shop_id

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--月度T值
select
trunc(alarm_start_date,'MM') as record_month
,store_city
,shop_id
,sum(substr(final_level_modify,2,1))/count(shop_id) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
where t1.dt = '20230921'
group by
trunc(alarm_start_date,'MM')
,store_city
,shop_id