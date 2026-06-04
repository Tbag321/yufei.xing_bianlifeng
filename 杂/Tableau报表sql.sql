--tableau表
--分品类销售额(周)
--销售明细
with sale_list as(
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('6101','6102') then payable_price else 0 end) as payable_price_cigarette --香烟销售额
,sum(case when sku_class_code in ('01','02','04','08','10','11','13') then payable_price else 0 end) as payable_price_fresh --风幕日配短保 销售额
,sum(case when sku_class_code in ('21') then payable_price else 0 end) as payable_price_bread --常温日配短保 销售额（面包）
,sum(case when sku_class_code in ('12') then payable_price else 0 end) as payable_price_milk --风幕12乳饮 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then payable_price else 0 end) as payable_price_hotmeal --日配热餐米饭 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') then payable_price else 0 end ) as payable_price_ff --日配制作类销售额
,sum(case when sku_class_code in ('07') then payable_price else 0 end ) as payable_price_coffee --咖啡豆浆自助饮品销售额
,sum(case when sku_class_code in ('30','31','32','33','42') then payable_price else 0 end) as payable_price_drinks --水饮销售额（白酒洋酒饮料冰淇淋等)
,sum(case when sku_class_code in ('34','35','36','37','38','40','41') then payable_price else 0 end) as payable_price_snack --非日配食品销售额（薯片饼干香肠泡面糖巧等）
 
from 
--default.dw_order_sku_promotion_v1 t --订单明细表
data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
)

select
record_week
,store_code
--分品类销售额--日
,payable_price/sale_days as payable_price
,payable_price_cigarette/sale_days as payable_price_cigarette
,payable_price_fresh/sale_days as payable_price_fresh
,payable_price_bread/sale_days as payable_price_bread
,payable_price_milk/sale_days as payable_price_milk
,payable_price_hotmeal/sale_days as payable_price_hotmeal
,payable_price_ff/sale_days as payable_price_ff
,payable_price_coffee/sale_days as payable_price_coffee
,payable_price_drinks/sale_days as payable_price_drinks
,payable_price_snack/sale_days as payable_price_snack
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/sale_days as payable_price_other
--分品类销占比
,payable_price_cigarette/payable_price as payable_price_cigarette_ratio
,payable_price_fresh/payable_price as payable_price_fresh_ratio
,payable_price_bread/payable_price as payable_price_bread_ratio
,payable_price_milk/payable_price as payable_price_milk_ratio
,payable_price_hotmeal/payable_price as payable_price_hotmeal_ratio
,payable_price_ff/payable_price as payable_price_ff_ratio
,payable_price_coffee/payable_price as payable_price_coffee_ratio
,payable_price_drinks/payable_price as payable_price_drinks_ratio
,payable_price_snack/payable_price as payable_price_snack_ratio
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/payable_price as payable_price_other_ratio
from sale_list

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--分品类销售额(月)
--销售明细
with sale_list as(
select
trunc(t.order_date,'MM') as month
,t.store_code

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('6101','6102') then payable_price else 0 end) as payable_price_cigarette --香烟销售额
,sum(case when sku_class_code in ('01','02','04','08','10','11','13') then payable_price else 0 end) as payable_price_fresh --风幕日配短保 销售额
,sum(case when sku_class_code in ('21') then payable_price else 0 end) as payable_price_bread --常温日配短保 销售额（面包）
,sum(case when sku_class_code in ('12') then payable_price else 0 end) as payable_price_milk --风幕12乳饮 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then payable_price else 0 end) as payable_price_hotmeal --日配热餐米饭 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') then payable_price else 0 end ) as payable_price_ff --日配制作类销售额
,sum(case when sku_class_code in ('07') then payable_price else 0 end ) as payable_price_coffee --咖啡豆浆自助饮品销售额
,sum(case when sku_class_code in ('30','31','32','33','42') then payable_price else 0 end) as payable_price_drinks --水饮销售额（白酒洋酒饮料冰淇淋等)
,sum(case when sku_class_code in ('34','35','36','37','38','40','41') then payable_price else 0 end) as payable_price_snack --非日配食品销售额（薯片饼干香肠泡面糖巧等）
 
from 
--default.dw_order_sku_promotion_v1 t --订单明细表
data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
trunc(t.order_date,'MM')
,t.store_code
)

select
month
,store_code
--分品类销售额
,payable_price/sale_days as payable_price
,payable_price_cigarette/sale_days as payable_price_cigarette
,payable_price_fresh/sale_days as payable_price_fresh
,payable_price_bread/sale_days as payable_price_bread
,payable_price_milk/sale_days as payable_price_milk
,payable_price_hotmeal/sale_days as payable_price_hotmeal
,payable_price_ff/sale_days as payable_price_ff
,payable_price_coffee/sale_days as payable_price_coffee
,payable_price_drinks/sale_days as payable_price_drinks
,payable_price_snack/sale_days as payable_price_snack
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/sale_days as payable_price_other
--分品类销占比
,payable_price_cigarette/payable_price as payable_price_cigarette_ratio
,payable_price_fresh/payable_price as payable_price_fresh_ratio
,payable_price_bread/payable_price as payable_price_bread_ratio
,payable_price_milk/payable_price as payable_price_milk_ratio
,payable_price_hotmeal/payable_price as payable_price_hotmeal_ratio
,payable_price_ff/payable_price as payable_price_ff_ratio
,payable_price_coffee/payable_price as payable_price_coffee_ratio
,payable_price_drinks/payable_price as payable_price_drinks_ratio
,payable_price_snack/payable_price as payable_price_snack_ratio
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/payable_price as payable_price_other_ratio
from sale_list

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店近30天日商--code--data_build.app_last_thirty_sales_da
--佳宇促销表日商
select 
t.order_date
,t.store_code
--订单量折前销售额折后销售额
,count(distinct t.order_no)/count(distinct t.order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct t.order_date) as quanzhou_sell_price --折前销售额
,sum(t.payable_price)/count(distinct t.order_date) as quanzhou_payable_price --折后销售额
from 
default.dw_order_sku_v1 t
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between date_sub(current_date(),30) and date_sub(current_date(),1)
group by t.order_date
,t.store_code

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--BE全量-数仓落表code--data_build.app_dm_site_selection_store_info_lite_da
select
store_code
, store_name
, opening_date
, store_strategy
, location_type
, is_listed
, breakeven_point
, profitability_tier
, is_tobacco_sale
, dt as record_day
from default.dm_site_selection_store_info_lite
where dt > '20170101'

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--夜间销售占比（周维度）-数仓落表code--data_build.app_store_payable_price_night_rat_da
--工作日列表
with work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
)

select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code
,cast(a.is_working_day as string) as is_working_day

--折后销售额
,sum(payable_price) as payable_price --折后销售额

--折后销售额 按照时段拆分
,sum(case when hour(order_time) between 7 and 21 then payable_price else 0 end) as payable_price_7_22 --7:00~22:00折后销售额

--当周夜间销售占比
,(sum(payable_price)-sum(case when hour(order_time) between 7 and 21 then payable_price else 0 end))/sum(payable_price) as payable_price_night_rat

from default.dw_order_sku_promotion_v1 t --订单明细表
--from data_or.dm_copy_dw_order_sku_promotion_v1_view
left join work_day_list a on t.order_date = a.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
--and order_date between '2017-08-01' and '2023-06-26'
--and a.store_cvs_code = '123001322' --门店编码
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
,a.is_working_day

union all

select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code
,'全周' as is_working_day

--折后销售额
,sum(payable_price) as payable_price --折后销售额

--折后销售额 按照时段拆分
,sum(case when hour(order_time) between 7 and 21 then payable_price else 0 end) as payable_price_7_22 --7:00~22:00折后销售额

,(sum(payable_price)-sum(case when hour(order_time) between 7 and 21 then payable_price else 0 end))/sum(payable_price) as payable_price_night_rat

from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
--and order_date between '2017-08-01' and '2023-06-26'
--and a.store_cvs_code = '123001322' --门店编码
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
,'全周'

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--上周分品类销售占比--code--data_build.app_last_week_payable_class_rat_da
--销售明细
with sale_list as(
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('6101','6102') then payable_price else 0 end) as payable_price_cigarette --香烟销售额
,sum(case when sku_class_code in ('01','02','04','08','10','11','13') then payable_price else 0 end) as payable_price_fresh --风幕日配短保 销售额
,sum(case when sku_class_code in ('21') then payable_price else 0 end) as payable_price_bread --常温日配短保 销售额（面包）
,sum(case when sku_class_code in ('12') then payable_price else 0 end) as payable_price_milk --风幕12乳饮 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then payable_price else 0 end) as payable_price_hotmeal --日配热餐米饭 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') then payable_price else 0 end ) as payable_price_ff --日配制作类销售额
,sum(case when sku_class_code in ('07') then payable_price else 0 end ) as payable_price_coffee --咖啡豆浆自助饮品销售额
,sum(case when sku_class_code in ('30','31','32','33','42') then payable_price else 0 end) as payable_price_drinks --水饮销售额（白酒洋酒饮料冰淇淋等)
,sum(case when sku_class_code in ('34','35','36','37','38','40','41') then payable_price else 0 end) as payable_price_snack --非日配食品销售额（薯片饼干香肠泡面糖巧等）
 
from 
default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
)

select
record_week
,store_code
--分品类销售额--日
,payable_price/sale_days as payable_price
,payable_price_cigarette/sale_days as payable_price_cigarette
,payable_price_fresh/sale_days as payable_price_fresh
,payable_price_bread/sale_days as payable_price_bread
,payable_price_milk/sale_days as payable_price_milk
,payable_price_hotmeal/sale_days as payable_price_hotmeal
,payable_price_ff/sale_days as payable_price_ff
,payable_price_coffee/sale_days as payable_price_coffee
,payable_price_drinks/sale_days as payable_price_drinks
,payable_price_snack/sale_days as payable_price_snack
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/sale_days as payable_price_other
--分品类销占比
,payable_price_cigarette/payable_price as payable_price_cigarette_ratio
,payable_price_fresh/payable_price as payable_price_fresh_ratio
,payable_price_bread/payable_price as payable_price_bread_ratio
,payable_price_milk/payable_price as payable_price_milk_ratio
,payable_price_hotmeal/payable_price as payable_price_hotmeal_ratio
,payable_price_ff/payable_price as payable_price_ff_ratio
,payable_price_coffee/payable_price as payable_price_coffee_ratio
,payable_price_drinks/payable_price as payable_price_drinks_ratio
,payable_price_snack/payable_price as payable_price_snack_ratio
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/payable_price as payable_price_other_ratio
from sale_list
where record_week = date_sub(current_date(),case when dayofweek(current_date()) = 1 then 7 else dayofweek(current_date()) - 1 end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--店外客流（周维度）--code--data_build.app_outside_flow_cnt_out_da
select 
store_code
,date_add(t.event_date,7 - case when dayofweek(t.event_date) = 1 then 7 else dayofweek(t.event_date) - 1 end) as record_week
,sum(outside_flow_cnt_out)/count(distinct concat(t.store_code,t.event_date)) as outside_flow_cnt_out --店外客流
from data_smartorder.dm_ordering_report_store_change_info_di t
where dt >= date_format(date_sub(current_date(),2365),'yyyyMMdd')
group by
store_code
,date_add(t.event_date,7 - case when dayofweek(t.event_date) = 1 then 7 else dayofweek(t.event_date) - 1 end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--交易转换率（周维度）--code--data_build.app_dm_ordering_report_store_change_info_da
--周维度进店客流&交易转化率
--置信度表
with Confidence_list as(
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
count(distinct a.event_date) as valid_num,
sum(outside_flow_cnt_out)/count(distinct a.event_date) as outside_flow_cnt_out,
sum(go_customer_num)/count(distinct a.event_date) as go_customer_num,
sum(order_num_all)/count(distinct a.event_date) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate
from data_smartorder.dm_ordering_report_store_change_info_di a
left join Confidence_list b on a.store_code=b.store_code and a.event_date=b.record_date
where a.dt >= date_format(date_sub(current_date(),2365),'yyyyMMdd')
and b.store_status in ('2','3')
group by
date_add(a.event_date,7 - case when dayofweek(a.event_date) = 1 then 7 else dayofweek(a.event_date) - 1 end),
a.store_code

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--T值（周维度）--code--data_build.app_dwd_ic_new_import_store_level_da
select
date_add(alarm_start_date,7 - case when dayofweek(alarm_start_date) = 1 then 7 else dayofweek(alarm_start_date) - 1 end) as record_week
,shop_id
,sum(substr(final_level_modify,2,1))/count(shop_id) as final_t_level_avg
from data_shop.dwd_ic_new_import_store_level_da_view t1
where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
date_add(alarm_start_date,7 - case when dayofweek(alarm_start_date) = 1 then 7 else dayofweek(alarm_start_date) - 1 end)
,shop_id

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--周维度门店促销折后--code--data_build.app_dm_promotion_daily_app_2023_activity_store_list_da
--21年1月2月促销数据
with 21_years_jan_feb as(
  select
  date_add(end_date,7 - case when dayofweek(end_date) = 1 then 7 else dayofweek(end_date) - 1 end) as record_week
  ,store_code
  ,discount_type as activity_type
  from data_promotion.ods_uploads_dm_promotion_all_59_store_info
  where end_date between '2021-01-01' and '2021-02-28'
  group by
  date_add(end_date,7 - case when dayofweek(end_date) = 1 then 7 else dayofweek(end_date) - 1 end)
  ,store_code
  ,discount_type
),

--21年3月-12月促销数据
21_year_mar_dec as(
  select
  date_add(end_date,7 - case when dayofweek(end_date) = 1 then 7 else dayofweek(end_date) - 1 end) as record_week
  ,store_code
  ,activity_type
  from data_promotion.ods_uploads_dm_promotion_2021_daily_activity_store_list_info
  where end_date between '2021-03-01' and '2021-12-31'
  group by
  date_add(end_date,7 - case when dayofweek(end_date) = 1 then 7 else dayofweek(end_date) - 1 end)
  ,store_code
  ,activity_type
),

--22年&23年促销数据(这个表里数据不用了，22年都是先涨价再打折)
--22_23_years_promotion as(
--  select
--  record_week
--  ,store_code
--  ,activity_type
--from(
--  select
--  date_add(end_date,7 - case when dayofweek(end_date) = 1 then 7 else dayofweek(end_date) - 1 end) as record_week
--  ,store_code
--  ,activity_type
--  ,rank() over(partition by concat(date_add(end_date,7 - case when dayofweek(end_date) = 1 then 7 else dayofweek(end_date) - 1 end),store_code) order by activity_type) as rn
--  from data_promotion.ods_uploads_dm_promotion_2022_daily_activity_store_list_info
--  where end_date >= '2022-01-01'
--  group by
--  date_add(end_date,7 - case when dayofweek(end_date) = 1 then 7 else dayofweek(end_date) - 1 end)
--  ,store_code
--  ,activity_type) a
--  where rn = 1
--),

--23年促销数据
23_years_promotion as(
  select
  date_add(record_date,7 - case when dayofweek(record_date) = 1 then 7 else dayofweek(record_date) - 1 end) as record_week
  ,store_code
  ,discount_type as action_type
  from(
  select
  date_add(start_date,mid_date) as record_date
  ,store_code
  ,discount_type
  from data_promotion.dm_promotion_daily_app_2023_activity_store_list_di t0
  lateral view posexplode(
    split(space(datediff(end_date,start_date)),'')
  ) t1 as mid_date,
  val
  where t0.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
)--将源数据日期转置成行 
   a
  group by
  date_add(record_date,7 - case when dayofweek(record_date) = 1 then 7 else dayofweek(record_date) - 1 end)
  ,store_code
  ,discount_type
  ),

--促销数据合并
promotion_list as(
  select * from 21_years_jan_feb
  union all
  select * from 21_year_mar_dec
  union all
  select * from 23_years_promotion
),

--静态BE(20230701)
be_list as(
  select
  store_code
  ,breakeven_point
from(
  select
  store_code
  ,breakeven_point
  ,rank() over(partition by store_code order by dt desc) as rn
  from default.dm_site_selection_store_info_lite
  where dt between 20170701 and date_format(date_sub(current_date(),2),'yyyyMMdd')
  and breakeven_point is not null) a
  where rn = 1
)

select
date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end) as record_week
,t0.store_code
,case when t1.activity_type is null then '100' else t1.activity_type end as activity_type
,t2.breakeven_point as breakeven_point

--周中日订单量折前销售额折后销售额
,count(distinct t0.order_no)/count(distinct t0.order_date) as order_cnt --订单量
,sum(t0.sell_price)/count(distinct t0.order_date) as sell_price --折前销售额
,sum(t0.payable_price)/count(distinct t0.order_date) as payable_price --折后销售额
from default.dw_order_sku_v1 t0
left join promotion_list t1 on date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end) = t1.record_week and t0.store_code = t1.store_code
left join be_list t2 on t0.store_code = t2.store_code
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_type = '0'
and t0.order_status = 'FINISHED'
and t0.sku_class_code not in ('86','50')
and t0.sku_quantity > 0
--and t0.order_date between '2021-01-04' and '2023-07-02'
group by 
date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end)
,t0.store_code
,case when t1.activity_type is null then '100' else t1.activity_type end
,t2.breakeven_point

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--事件上报及相关调整申请--code--data_build.app_dm_ordering_report_taskoutput_info_da
select * 
from(
select
task_name as task_name
,order_status
,create_time
,date_add(substring(create_time,1,10),7 - case when dayofweek(substring(create_time,1,10)) = 1 then 7 else dayofweek(substring(create_time,1,10)) - 1 end) as record_week
,taskorder_update_time
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') as store_code
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[3]'),'$.values[0]'),'$.label') as eventType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[4]'),'$.values[0]'),'$.label') as friendType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[5]'),'$.values[0]'),'$.label') as yiqingtype
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[6]'),'$.values[0]'),'$.label') as businessCentreType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[7]'),'$.values[0]'),'$.label') as school
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[8]'),'$.values[0]'),'$.label') as buxi
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[9]'),'$.values[0]'),'$.label') as around
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[10]'),'$.values[0]'),'$.label') as noDoType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[11]'),'$.values[0]'),'$.label') as waterStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[12]'),'$.values[0]'),'$.label') as powerStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[13]'),'$.values[0]'),'$.label') as detailStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[14]'),'$.values[0]'),'$.label') as equipment
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[19]'),'$.values[0]'),'$.value') as reason
,row_number()over(partition by (order_id) order by taskorder_update_time desc) as rn
from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110135208680930'
and flow_code = '017119') t1
where rn = 1
and reason is not null
--and substr(create_time,1,10) between '2023-01-01' and '2023-07-12'
--and store_code = '101000159'
and eventtype in ('商圈变化','竞对相关')

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--店长标签--这是源数据，不落表，直接在tableau里处理
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
where t0.dt > 20170101

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--店长月维度标签--tableau里sql
with source_list as(
select 
t0.store_code as store_code
,t0.total_score as total_score
,t0.final_rank as final_rank
,case when t0.final_rank = 'S' then '1'
when t0.final_rank = 'A' then '2'
when t0.final_rank = 'B' then '3'
when t0.final_rank = 'C' then '4'
when t0.final_rank = 'D' then '5'
when t0.final_rank = 'F' then '6'
else null end as protect_tag
,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
from data_build.dwd_manager_tag_v1_di t0
where t0.dt > 20170101
and date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) in ('2023-05-01','2023-05-29','2023-07-03','2023-07-31','2023-09-04',date_sub(current_date,0))
),

a_b_c_d_list as(
select
store_code
,max(case when record_date = '2023-05-01' then protect_tag else 0 end) as four_lable
,max(case when record_date = '2023-05-29' then protect_tag else 0 end) as five_lable
,max(case when record_date = '2023-07-03' then protect_tag else 0 end) as six_lable
,max(case when record_date = '2023-07-31' then protect_tag else 0 end) as seven_lable
,max(case when record_date = '2023-09-04' then protect_tag else 0 end) as eight_lable
,max(case when record_date = date_sub(current_date,0) then protect_tag else 0 end) as now_lable
from source_list
group by store_code
)

select
store_code
,case when four_lable = '1' then '钻石'
when four_lable = '2' then '金牌'
when four_lable = '3' then '银牌'
when four_lable = '4' then '铜牌'
when four_lable = '5' then '需努力'
when four_lable = '6' then '待观察'
else null end as four_lable
,case when five_lable = '1' then '钻石'
when five_lable = '2' then '金牌'
when five_lable = '3' then '银牌'
when five_lable = '4' then '铜牌'
when five_lable = '5' then '需努力'
when five_lable = '6' then '待观察'
else null end as five_lable
,case when six_lable = '1' then '钻石'
when six_lable = '2' then '金牌'
when six_lable = '3' then '银牌'
when six_lable = '4' then '铜牌'
when six_lable = '5' then '需努力'
when six_lable = '6' then '待观察'
else null end as six_lable
,case when seven_lable = '1' then '钻石'
when seven_lable = '2' then '金牌'
when seven_lable = '3' then '银牌'
when seven_lable = '4' then '铜牌'
when seven_lable = '5' then '需努力'
when seven_lable = '6' then '待观察'
else null end as seven_lable
,case when eight_lable = '1' then '钻石'
when eight_lable = '2' then '金牌'
when eight_lable = '3' then '银牌'
when eight_lable = '4' then '铜牌'
when eight_lable = '5' then '需努力'
when eight_lable = '6' then '待观察'
else null end as eight_lable
,case when now_lable = '1' then '钻石'
when now_lable = '2' then '金牌'
when now_lable = '3' then '银牌'
when now_lable = '4' then '铜牌'
when now_lable = '5' then '需努力'
when now_lable = '6' then '待观察'
else null end as now_lable
from a_b_c_d_list

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--店长得分（每周日）--tableau里sql
with work_day_list as(
select
date_key
,day_of_week_name
from data_build.dim_date_ya_v2
group by
date_key
,day_of_week_name
)

select 
t0.store_code as store_code
,t0.total_score as total_score
,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),0) as record_date--取当天dt，dt是星期日就是周日-30的时间段
from data_build.dwd_manager_tag_v1_di t0
left join work_day_list a on date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),0) = a.date_key
where t0.dt > 20170101
and a.day_of_week_name = '星期日'