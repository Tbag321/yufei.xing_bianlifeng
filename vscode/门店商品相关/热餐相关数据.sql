--用户周均购买次数
select
pay_id
,count(distinct order_no) as order_no_num --订单数量
,count(distinct sku_code) as sku_num --菜品数量
,sum(case when sku_code = '03014038' then sku_quantity else 0 end) as `03014038`
,sum(case when sku_code = '03013809' then sku_quantity else 0 end) as `03013809`
,sum(case when sku_code = '03014793' then sku_quantity else 0 end) as `03014793`
,sum(case when sku_code = '03012359' then sku_quantity else 0 end) as `03012359`
,sum(case when sku_code = '03014656' then sku_quantity else 0 end) as `03014656`
,sum(case when sku_code = '03014691' then sku_quantity else 0 end) as `03014691`
,sum(case when sku_code = '03012189' then sku_quantity else 0 end) as `03012189`
,sum(case when sku_code = '03014302' then sku_quantity else 0 end) as `03014302`
,sum(case when sku_code = '03012053' then sku_quantity else 0 end) as `03012053`
,sum(case when sku_code = '03014662' then sku_quantity else 0 end) as `03014662`
,sum(case when sku_code = '03012604' then sku_quantity else 0 end) as `03012604`
,sum(case when sku_code = '03014672' then sku_quantity else 0 end) as `03014672`
,sum(case when sku_code = '03014679' then sku_quantity else 0 end) as `03014679`
,sum(case when sku_code = '03014709' then sku_quantity else 0 end) as `03014709`
,sum(case when sku_code = '03014807' then sku_quantity else 0 end) as `03014807`
,sum(case when sku_code = '03014365' then sku_quantity else 0 end) as `03014365`
,sum(case when sku_code = '03014378' then sku_quantity else 0 end) as `03014378`
,sum(case when sku_code = '03014747' then sku_quantity else 0 end) as `03014747`
,sum(case when sku_code = '03013125' then sku_quantity else 0 end) as `03013125`
,sum(case when sku_code = '03014708' then sku_quantity else 0 end) as `03014708`
,sum(case when sku_code = '03014786' then sku_quantity else 0 end) as `03014786`
,sum(case when sku_code = '03014739' then sku_quantity else 0 end) as `03014739`
,sum(case when sku_code = '03014110' then sku_quantity else 0 end) as `03014110`
,sum(case when sku_code = '03014680' then sku_quantity else 0 end) as `03014680`
,sum(case when sku_code = '03014820' then sku_quantity else 0 end) as `03014820`
,sum(case when sku_code = '03014161' then sku_quantity else 0 end) as `03014161`
,sum(case when sku_code = '03014759' then sku_quantity else 0 end) as `03014759`
,sum(case when sku_code = '03013368' then sku_quantity else 0 end) as `03013368`
,sum(case when sku_code = '03014766' then sku_quantity else 0 end) as `03014766`
,sum(case when sku_code = '03014714' then sku_quantity else 0 end) as `03014714`
,sum(case when sku_code = '03012361' then sku_quantity else 0 end) as `03012361`
,sum(case when sku_code = '03014671' then sku_quantity else 0 end) as `03014671`
,sum(case when sku_code = '03014798' then sku_quantity else 0 end) as `03014798`
,sum(case when sku_code = '03014774' then sku_quantity else 0 end) as `03014774`
,sum(case when sku_code = '03014817' then sku_quantity else 0 end) as `03014817`
,sum(case when sku_code = '03013582' then sku_quantity else 0 end) as `03013582`
,sum(case when sku_code = '03014808' then sku_quantity else 0 end) as `03014808`
,sum(case when sku_code = '03014692' then sku_quantity else 0 end) as `03014692`
,sum(case when sku_code = '03014816' then sku_quantity else 0 end) as `03014816`
,sum(case when sku_code = '03014663' then sku_quantity else 0 end) as `03014663`
,sum(case when sku_code = '03014600' then sku_quantity else 0 end) as `03014600`
,sum(case when sku_code = '03014647' then sku_quantity else 0 end) as `03014647`
,sum(case when sku_code = '03014648' then sku_quantity else 0 end) as `03014648`
,sum(case when sku_code = '03014822' then sku_quantity else 0 end) as `03014822`
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240228
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-10-30' and '2024-02-04' --14周
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.pay_id is not null
and t.sku_quantity > 0
group by
pay_id

-----------------------------------------------------------------------------------------------------------------------------------------
with date_list as(
select
date_key
,is_working_day
,'1' as joinkey
from default.dim_date_ya_v2
where date_key between '2022-01-01' and '2024-03-21'
),

sku_list as(
select
sku_name
,'1' as joinkey
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
group by
sku_name
,'1'
),

pay_list as(
select
pay_id
,'1' as joinkey
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.pay_id is not null
and t.sku_quantity > 0
group by
pay_id
),

sku_day_list as(  --日期*sku
select
date_key
,is_working_day
,sku_name
from date_list a
left join sku_list b
on a.joinkey = b.joinkey
),

pay_day_list as(  --日期*人
select
date_key
,is_working_day
,pay_id
from date_list a
left join pay_list b
on a.joinkey = b.joinkey
),

22_list as(
select
sku_name
,min(order_date) as first_order_date
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2022-12-31'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
group by
sku_name
),

new_sku_list as(
select
t.sku_name
,t1.first_order_date as 22_first_order_date
,min(t.order_date) as first_order_date
,date_add(min(t.order_date),6) as 7_order_date
,date_add(min(t.order_date),13) as 14_order_date
,date_add(min(t.order_date),20) as 21_order_date
,date_add(min(t.order_date),27) as 28_order_date
,date_sub(min(t.order_date),90) as before_90_order_date
,date_add(min(t.order_date),90) as last_90_order_date
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join 22_list t1 on t.sku_name = t1.sku_name
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-01-01' and '2023-12-31'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
and t1.first_order_date is null  --22年没有卖过
group by
t.sku_name
,t1.first_order_date
),

--每日SKU销量
sku_sell as(
select
order_date
,sku_name
,sum(sku_quantity) as sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
group by
order_date
,sku_name
),

--每日热餐销量
hotmeal_sell as(
select
order_date
,sum(sku_quantity) as sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
group by
order_date
),

--每日热餐制作量
make_list as(
select
create_date
,store_code
,store_name
,sku_name
--制作数量
,sum(make_quantity) as make_quantity
from data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and sku_division_name	= '热餐'
and store_code = '100078005'
group by
create_date
,store_code
,store_name
,sku_name
),

--日期*SKU*当日SKU销量*当日热餐销量*当日制作量
raw_list as(
select
t0.date_key
,t0.is_working_day
,t0.sku_name
,t1.sku_quantity as sku_quantity
,t2.sku_quantity as hotmeal_quantity
,t3.make_quantity
from sku_day_list t0
left join sku_sell t1 on t0.date_key = t1.order_date and t0.sku_name = t1.sku_name
left join hotmeal_sell t2 on t0.date_key = t2.order_date
left join make_list t3 on t0.sku_name = t3.sku_name and t0.date_key = t3.create_date
),

--每日用户单量
pay_sell as(
select
pay_id
,order_date
,count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.pay_id is not null
and t.sku_quantity > 0
group by
pay_id
,order_date
)

--------------------------------------------------------------------------------------------------------------------------------
select
t0.date_key
,t0.is_working_day
,t0.sku_name
,t0.sku_quantity
,t0.hotmeal_quantity
,t0.make_quantity
,t1.first_order_date
,sum(t0.sku_quantity) over(partition by t0.sku_name order by t0.date_key rows between current row and 6 following)
,sum(t0.sku_quantity) over(partition by t0.sku_name order by t0.date_key rows between 7 following and 13 following)
,sum(t0.sku_quantity) over(partition by t0.sku_name order by t0.date_key rows between 14 following and 20 following)
,sum(t0.sku_quantity) over(partition by t0.sku_name order by t0.date_key rows between 21 following and 27 following)
,sum(t0.sku_quantity) over(partition by t0.sku_name order by t0.date_key rows between current row and 27 following)

,sum(t0.hotmeal_quantity) over(partition by t0.sku_name order by t0.date_key rows between current row and 6 following)
,sum(t0.hotmeal_quantity) over(partition by t0.sku_name order by t0.date_key rows between 7 following and 13 following)
,sum(t0.hotmeal_quantity) over(partition by t0.sku_name order by t0.date_key rows between 14 following and 20 following)
,sum(t0.hotmeal_quantity) over(partition by t0.sku_name order by t0.date_key rows between 21 following and 27 following)
,sum(t0.hotmeal_quantity) over(partition by t0.sku_name order by t0.date_key rows between current row and 27 following)

,sum(t0.make_quantity) over(partition by t0.sku_name order by t0.date_key rows between current row and 6 following)
,sum(t0.make_quantity) over(partition by t0.sku_name order by t0.date_key rows between 7 following and 13 following)
,sum(t0.make_quantity) over(partition by t0.sku_name order by t0.date_key rows between 14 following and 20 following)
,sum(t0.make_quantity) over(partition by t0.sku_name order by t0.date_key rows between 21 following and 27 following)
,sum(t0.make_quantity) over(partition by t0.sku_name order by t0.date_key rows between current row and 27 following)
from raw_list t0
left join new_sku_list t1 on t0.sku_name = t1.sku_name and t0.date_key = t1.first_order_date
------------------------------------------------------------------------------------------------------------------------------------

sku_90 as(
select
t0.date_key
,t0.is_working_day
,t0.sku_name
from sku_day_list t0
left join new_sku_list t1 on t0.sku_name = t1.sku_name
where t0.date_key between date_sub(t1.first_order_date,90) and date_add(t1.first_order_date,89)
),

sku_pay_90 as(
select
t0.date_key
,t0.is_working_day
,t0.sku_name
,t1.pay_id
,t1.order_no_num
,sum(t1.order_no_num) over(partition by concat(sku_name,t1.pay_id)) as total_order_no_num
from sku_90 t0
left join pay_sell t1 on t0.date_key = t1.order_date
)

-------------------------------------------------------------------------------------------------------------------------------
select
t0.sku_name
,count(distinct t0.pay_id) as pay_id_num
from sku_pay_90 t0
where t0.total_order_no_num >= '2'
group by
t0.sku_name
----------------------------------------------------------------------------------------------------------------------------------

--每个用户每天买了什么菜
pay_sell_sku as(
select
pay_id
,order_date
,sku_name
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.pay_id is not null
and t.sku_quantity > 0
group by
pay_id
,order_date
,sku_name
),

sku_week_pay as(
select
t0.pay_id
,t0.order_date
,t0.sku_name
,case when t0.order_date between t1.first_order_date and t1.7_order_date then '第一周购买' else null end as w1_sell
,case when t0.order_date between t1.7_order_date and t1.14_order_date then '第二周购买' else null end as w2_sell
,case when t0.order_date between t1.14_order_date and t1.21_order_date then '第三周购买' else null end as w3_sell
,case when t0.order_date between t1.21_order_date and t1.28_order_date then '第四周购买' else null end as w4_sell
,case when t0.order_date between t1.first_order_date and t1.28_order_date then '前四周购买' else null end as w1_w4_sell
from pay_sell_sku t0
left join new_sku_list t1 on t0.sku_name = t1.sku_name
),

--第N周购买的用户清单
n_list as(
select
pay_id
,sku_name
from sku_week_pay
where w1_sell is not null
)

select
t0.sku_name
,count(distinct t0.pay_id) as pay_id_num
from sku_pay_90 t0
join n_list t1 on t0.pay_id = t1.pay_id and t0.sku_name = t1.sku_name
--where t0.total_order_no_num >= '2'
group by
t0.sku_name

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--新需求
with 22_list as(
select
sku_name
,min(order_date) as first_order_date
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2022-12-31'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
group by
sku_name
),

new_sku_list as(
select
t.sku_name
,t1.first_order_date as 22_first_order_date
,min(t.order_date) as first_order_date
,date_add(min(t.order_date),6) as 7_order_date
,date_add(min(t.order_date),13) as 14_order_date
,date_add(min(t.order_date),20) as 21_order_date
,date_add(min(t.order_date),27) as 28_order_date
,date_sub(min(t.order_date),90) as before_90_order_date
,date_add(min(t.order_date),90) as last_90_order_date
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join 22_list t1 on t.sku_name = t1.sku_name
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-01-01' and '2023-12-31'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
and t1.first_order_date is null  --22年没有卖过
group by
t.sku_name
,t1.first_order_date
),

--每个用户每天买了什么菜
pay_sell_sku as(
select
pay_id
,order_date
,sku_name
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.pay_id is not null
and t.sku_quantity > 0
group by
pay_id
,order_date
,sku_name
),

sku_week_pay as(
select
t0.pay_id
,t0.order_date
,t0.sku_name
,case when t0.order_date between t1.first_order_date and t1.28_order_date then '四周之内购买' else null end as w1_w4_sell
from pay_sell_sku t0
left join new_sku_list t1 on t0.sku_name = t1.sku_name
)
----------------------------------------------------------------------------------------------------------------------------------------
select
sku_name
,count(distinct pay_id) as pay_id_num
from sku_week_pay
where w1_w4_sell = '四周之内购买'
group by
sku_name
---------------------------------------------------------------------------------------------------------------------------------------
date_list as(
select
date_key
,is_working_day
,'1' as joinkey
from default.dim_date_ya_v2
where date_key between '2022-01-01' and '2024-03-21'
),

sku_list as(
select
sku_name
,'1' as joinkey
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
--and t.pay_id is not null
and t.sku_quantity > 0
group by
sku_name
,'1'
),

pay_list as(
select
pay_id
,'1' as joinkey
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.pay_id is not null
and t.sku_quantity > 0
group by
pay_id
),

sku_day_list as(  --日期*sku
select
date_key
,is_working_day
,sku_name
from date_list a
left join sku_list b
on a.joinkey = b.joinkey
),

sku_28 as(
select
t0.date_key
,t0.is_working_day
,t0.sku_name
from sku_day_list t0
left join new_sku_list t1 on t0.sku_name = t1.sku_name
where t0.date_key between t1.first_order_date and t1.28_order_date
),

--每日用户单量
pay_sell as(
select
pay_id
,order_date
,count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240320
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2022-01-01' and '2024-03-21'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
--and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.pay_id is not null
and t.sku_quantity > 0
group by
pay_id
,order_date
),

sku_pay_28 as(
select
t0.date_key
,t0.is_working_day
,t0.sku_name
,t1.pay_id
,t1.order_no_num
,sum(t1.order_no_num) over(partition by concat(sku_name,t1.pay_id)) as total_order_no_num
from sku_28 t0
left join pay_sell t1 on t0.date_key = t1.order_date
)

select
a.sku_name
,count(distinct a.pay_id)
from sku_pay_28 a
left join pay_sell_sku b on a.pay_id = b.pay_id and a.date_key = b.order_date and a.sku_name = b.sku_name
where total_order_no_num >= 2
and b.pay_id is not null
group by
sku_name