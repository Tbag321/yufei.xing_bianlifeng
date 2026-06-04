--当周夜间不营业天数统计
--日期表
with work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

no_sale_night_num as(
select
date_add(a.record_date,7-case when dayofweek(a.record_date) = 1 then 7 else dayofweek(a.record_date) - 1 end) as order_week,
a.store_code,
b.is_working_day,
sum(case when a.all_day_type = '营业' then 1 else 0 end) as all_day_sale_num,
sum(case when a.all_day_type = '不营业' then 1 else 0 end) as all_day_no_sale_num,
sum(case when a.night_type = '营业' then 1 else 0 end) as sale_night_num,
sum(case when a.night_type = '不营业' then 1 else 0 end) as no_sale_night_num
from data_smartorder.dw_ordering_report_store_business_status_da a
left join work_day_list b on a.record_date = b.date_key
where a.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by date_add(a.record_date,7-case when dayofweek(a.record_date) = 1 then 7 else dayofweek(a.record_date) - 1 end),
a.store_code,
b.is_working_day
),

--全周状态
all_week_type as(
select
a.order_week,
a.store_code,
case 
when sum(all_day_sale_num) = 0 then '休眠'
when sum(all_day_sale_num) = 1 and sum(sale_night_num) = 0 then '夜间闭店'
when sum(all_day_sale_num) = 2 and sum(sale_night_num) = 0 then '夜间闭店'
when sum(all_day_sale_num) = 3 and sum(sale_night_num) < 2 then '夜间闭店'
when sum(all_day_sale_num) = 4 and sum(sale_night_num) < 2 then '夜间闭店'
when sum(all_day_sale_num) = 5 and sum(sale_night_num) < 3 then '夜间闭店'
when sum(all_day_sale_num) = 6 and sum(sale_night_num) < 3 then '夜间闭店'
when sum(all_day_sale_num) = 7 and sum(sale_night_num) < 4 then '夜间闭店'
else '正常营业'
end as sale_type
from no_sale_night_num a
where order_week > '2021-01-04'
group by
a.order_week,
a.store_code),

--工作日状态
work_day_type as(
select
a.order_week,
a.store_code,
case 
when all_day_sale_num = 0 then '休眠'
when all_day_sale_num = 1 and sale_night_num = 0 then '夜间闭店'
when all_day_sale_num = 2 and sale_night_num = 0 then '夜间闭店'
when all_day_sale_num = 3 and sale_night_num < 2 then '夜间闭店'
when all_day_sale_num = 4 and sale_night_num < 2 then '夜间闭店'
when all_day_sale_num = 5 and sale_night_num < 3 then '夜间闭店'
when all_day_sale_num = 6 and sale_night_num < 3 then '夜间闭店'
when all_day_sale_num = 7 and sale_night_num < 4 then '夜间闭店'
else '正常营业'
end as sale_type
from no_sale_night_num a
where is_working_day = 1
and order_week > '2021-01-04'),

--非工作日周末状态
without_work_day_type as(
select
a.order_week,
a.store_code,
case 
when all_day_sale_num = 0 then '休眠'
when all_day_sale_num = 1 and sale_night_num = 0 then '夜间闭店'
when all_day_sale_num = 2 and sale_night_num = 0 then '夜间闭店'
when all_day_sale_num = 3 and sale_night_num < 2 then '夜间闭店'
when all_day_sale_num = 4 and sale_night_num < 2 then '夜间闭店'
when all_day_sale_num = 5 and sale_night_num < 3 then '夜间闭店'
when all_day_sale_num = 6 and sale_night_num < 3 then '夜间闭店'
when all_day_sale_num = 7 and sale_night_num < 4 then '夜间闭店'
else '正常营业'
end as sale_type
from no_sale_night_num a
where is_working_day = 0
and order_week > '2021-01-04')

--结果表
select
a.order_week
,a.store_code
,a.sale_type
,b.sale_type
,c.sale_type
from all_week_type a
left join work_day_type b on a.order_week = b.order_week and a.store_code = b.store_code
left join without_work_day_type c on a.order_week = c.order_week and a.store_code = c.store_code























---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--计算营业月份
with list as(
select
trunc(record_date, 'MM') as order_month,
store_code,
sum(case when all_day_type = '营业' then 1 else 0 end) as all_day_sale_num,
sum(case when all_day_type = '不营业' then 1 else 0 end) as all_day_no_sale_num,
sum(case when night_type = '营业' then 1 else 0 end) as sale_night_num,
sum(case when night_type = '不营业' then 1 else 0 end) as no_sale_night_num
from data_smartorder.dw_ordering_report_store_business_status_da
where dt = 20221005
and record_date between '2020-01-01' and '2022-07-30'
group by trunc(record_date, 'MM'),
store_code
)

select
b.store_cvs_code,
count(distinct order_month)
from list a
left join data_md.dm_md_dim_store_base_info_store_v1 b on a.store_code = b.store_code and b.dt = 20221005
group by b.store_cvs_code


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--周维度门店营业天数
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
date_add(order_date,7-case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as order_week
,b.store_cvs_code
,b.display_name
,SUM(payable_price) as payable_price
,count(distinct order_date) as date_num
from default.dw_order_sku_promotion_v1 a
left join desensitization b on a.store_code = b.store_code
WHERE dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
and pay_status = 'PAY_SUCCESS'
and store_type = '0'
group by
date_add(order_date,7-case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,b.store_cvs_code
,b.display_name