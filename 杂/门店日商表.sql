--门店日商表
select
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_week
,substring('store_code_name',1,9) as store_code
,substring('store_code_name',10) as store_name
,final_price_all/day_cnt_storecode as sale_day
from default.dwa_store_construction_store_encrypt_sale_weekly_v1


------------------------------------------------------------------------------------------------------------------
--周维度达标率
--工作日列表
with work_day_list as(
select
date_key
,day_of_week_name
from default.dim_date_ya_v2
group by
date_key
,day_of_week_name
),

--每周日BE
be_list as(
select
from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_week
,a.store_code
,a.breakeven_point
,is_tobacco_sale
from default.dm_site_selection_store_info_lite a
left join work_day_list b on from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') = b.date_key
where a.dt > '20160220'
and b.day_of_week_name = "星期日"
),

--佳宇促销表日商
--周日商
day_sale_list as(
select 
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,store_code
--订单量折前销售额折后销售额
,count(distinct order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and order_status = 'FINISHED'
and sku_class_code not in ('86','50')
and sku_quantity > 0
and order_date >= '2016-02-20'
group by date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,store_code 
)

--每周达标率
select
a.record_week
,a.store_code
,a.quanzhou_payable_price
,b.breakeven_point
,a.quanzhou_payable_price/b.breakeven_point
from day_sale_list a
left join be_list b on a.record_week = b.record_week
and a.store_code = b.store_code
where a.record_date = '2023-07-09'