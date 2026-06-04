with date_list as
(select
date_key
,is_working_day
from default.dim_date_ya_v3
)

select
 t.order_date
 ,t.store_code
 --,t.store_name
 ,t.store_city
 ,b.is_working_day
 
 --订单量
 ,count(distinct order_no) as order_cnt --全部订单量
 ,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
 ,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
 
 ,count(distinct case when hour(order_time) between 0 and 5 then order_no else null end) as order_cnt_0_5 --0:00~6:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 6 and 10 then order_no else null end) as order_cnt_6_10 --6:00~11:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 11 and 14 then order_no else null end) as order_cnt_11_14 --11:00~15:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 15 and 21 then order_no else null end) as order_cnt_15_22 --15:00~22:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 22 and 23 then order_no else null end) as order_cnt_22_00 --22:00~00:00订单量 含外卖

 --热餐订单量
 ,count(distinct case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then order_no else null end) as hotmeal_order_cnt --热餐订单量
 
 --折后销售额 按照到店/外卖拆分
 ,sum(payable_price) as payable_price --全部销售额
 ,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
 ,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

 --折后销售额 按照时段拆分
 ,sum(case when hour(order_time) between 0 and 5 then payable_price else 0 end) as payable_price_0_5 --0:00~6:00销售额
 ,sum(case when hour(order_time) between 6 and 10 then payable_price else 0 end) as payable_price_6_10 --6:00~11:00销售额
 ,sum(case when hour(order_time) between 11 and 14 then payable_price else 0 end) as payable_price_11_14 --11:00~15:00销售额
 ,sum(case when hour(order_time) between 15 and 21 then payable_price else 0 end) as payable_price_15_22 --15:00~22:00销售额
 ,sum(case when hour(order_time) between 22 and 23 then payable_price else 0 end) as payable_price_22_00 --22:00~00:00销售额

 --当天销售了几个菜
 ,count(distinct case when sku_class_code in ('03','05','06') and sku_division_code in ('0301') then sku_code else null end) as dishes_quantity --菜品种类数量

 --折前销售额 按照商品拆分
 ,sum(case when sku_division_code in ('6101','6102') then sell_price else 0 end) as sell_price_cigarette --香烟销售额
 ,sum(case when sku_class_code in ('01','02','04','08','10','11','13') then sell_price else 0 end) as sell_price_fresh --风幕日配短保 销售额
 ,sum(case when sku_class_code in ('21') then sell_price else 0 end) as sell_price_bread --常温日配短保 销售额（面包）
 ,sum(case when sku_class_code in ('12') then sell_price else 0 end) as sell_price_milk --风幕12乳饮 销售额
 ,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then sell_price else 0 end) as sell_price_hotmeal --日配热餐米饭 销售额
 ,sum(case when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') then sell_price else 0 end ) as sell_price_ff --日配制作类销售额
 ,sum(case when sku_class_code in ('07') then sell_price else 0 end ) as sell_price_coffee --咖啡豆浆自助饮品销售额
 ,sum(case when sku_class_code in ('30','31','32','33','42') then sell_price else 0 end) as sell_price_drinks --水饮销售额（白酒洋酒饮料冰淇淋等)
 ,sum(case when sku_class_code in ('34','35','36','37','38','40','41') then sell_price else 0 end) as sell_price_snack --非日配食品销售额（薯片饼干香肠泡面糖巧等）

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
 
from default.dw_order_sku_promotion_v1 t --订单明细表
left join date_list b on t.order_date = b.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and order_date between '2023-07-03' and '2023-07-09'
 and t.store_code in ('100000002',
'100000276') --门店编码
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
group by 
 t.order_date
 ,t.store_code
 --,t.store_name
 ,t.store_city
 ,b.is_working_day




select
 date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as order_week
 ,t.store_code
 ,t.store_name
 ,t.store_city
 
 --订单量
 ,count(distinct order_no) as order_cnt --全部订单量
 ,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
 ,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
 
 ,count(distinct case when hour(order_time) between 0 and 5 then order_no else null end) as order_cnt_0_5 --0:00~6:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 6 and 10 then order_no else null end) as order_cnt_6_10 --6:00~11:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 11 and 14 then order_no else null end) as order_cnt_11_14 --11:00~15:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 15 and 23 then order_no else null end) as order_cnt_15_23 --15:00~00:00订单量 含外卖
 
 
 --折后销售额 按照到店/外卖拆分
 ,sum(payable_price) as payable_price --全部销售额
 ,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
 ,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

 --折后销售额 按照时段拆分
 ,sum(case when hour(order_time) between 0 and 5 then payable_price else 0 end) as payable_price_0_5 --0:00~6:00销售额
 ,sum(case when hour(order_time) between 6 and 10 then payable_price else 0 end) as payable_price_6_10 --6:00~11:00销售额
 ,sum(case when hour(order_time) between 11 and 14 then payable_price else 0 end) as payable_price_11_14 --11:00~15:00销售额
 ,sum(case when hour(order_time) between 15 and 23 then payable_price else 0 end) as payable_price_15_23 --15:00~00:00销售额
 
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
 
from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
group by 
 date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
 ,t.store_code
 ,t.store_name
 ,t.store_city

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--夜间（22-7）销售占比
with desensitization as(
select
 store_code,
 --store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 --store_name,
 store_cvs_code,
 display_name)

select
 t.order_date
 ,t.store_code
 --,t.store_name
 ,t.store_city
 ,a.store_code
 
 --订单量
 ,count(distinct order_no) as order_cnt --全部订单量
 ,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
 ,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
 
  ,count(distinct case when hour(order_time) between 0 and 6 then order_no else null end) as order_cnt_0_7 --00:00~7:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 7 and 21 then order_no else null end) as order_cnt_7_22 --7:00~22:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 22 and 23 then order_no else null end) as order_cnt_22_0 --22:00~00:00订单量 含外卖

 
 --折后销售额 按照到店/外卖拆分
 ,sum(payable_price) as payable_price --全部销售额
 ,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
 ,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

 --折后销售额 按照时段拆分
 ,sum(case when hour(order_time) between 0 and 6 then payable_price else 0 end) as payable_price_0_7 --00:00~7:00销售额
 ,sum(case when hour(order_time) between 7 and 21 then payable_price else 0 end) as payable_price_7_22 --7:00~22:00销售额
 ,sum(case when hour(order_time) between 22 and 23 then payable_price else 0 end) as payable_price_22_0 --22:00~00:00销售额
 
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
 
from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and order_date between '2017-08-01' and '2023-06-26'
 and a.store_cvs_code = '123001322' --门店编码
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
group by 
 t.order_date
 ,t.store_code
 --,t.store_name
 ,t.store_city
 ,a.store_code
 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--夜间（22-7）销售占比（月维度）
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

order_list as(
select
 t.order_date
 ,a.store_cvs_code
 ,a.display_name
 ,t.store_city
 ,t.store_code
 
 --订单量
 ,count(distinct order_no) as order_cnt --全部订单量
 ,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
 ,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
 
  ,count(distinct case when hour(order_time) between 0 and 6 then order_no else null end) as order_cnt_0_7 --00:00~7:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 7 and 21 then order_no else null end) as order_cnt_7_22 --7:00~22:00订单量 含外卖
 ,count(distinct case when hour(order_time) between 22 and 23 then order_no else null end) as order_cnt_22_0 --22:00~00:00订单量 含外卖

 
 --折后销售额 按照到店/外卖拆分
 ,sum(payable_price) as payable_price --全部销售额
 ,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
 ,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

 --折后销售额 按照时段拆分
  ,sum(case when hour(order_time) between 0 and 6 then payable_price else 0 end) as payable_price_0_7 --00:00~7:00销售额
 ,sum(case when hour(order_time) between 7 and 21 then payable_price else 0 end) as payable_price_7_22 --7:00~22:00销售额
 ,sum(case when hour(order_time) between 22 and 23 then payable_price else 0 end) as payable_price_22_0 --22:00~00:00销售额
 
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
 
from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 and order_date between '2016-08-01' and '2022-10-31'
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
group by 
 t.order_date
 ,a.store_cvs_code
 ,a.display_name
 ,t.store_city
 ,t.store_code),

 store_business_type as(
    select
record_date,
store_code,
sum(case when all_day_type = '营业' then 1 else 0 end) as all_day_sale_num,
sum(case when all_day_type = '不营业' then 1 else 0 end) as all_day_no_sale_num,
sum(case when night_type = '营业' then 1 else 0 end) as sale_night_num,
sum(case when night_type = '不营业' then 1 else 0 end) as no_sale_night_num
from data_smartorder.dw_ordering_report_store_business_status_da
where dt = '${today-1}'
and all_day_type = night_type
and all_day_type = '营业'
group by record_date,
store_code
 )

 select
 date_add(xx.order_date,1 - case when dayofweek(xx.order_date) = 1 then 1 else dayofweek(xx.order_date) - 7 end) as week,
 xx.store_cvs_code,
 xx.display_name,
 xx.store_city,
 sum(tt.all_day_sale_num) as all_day_sale_num,
 sum(tt.sale_night_num) as sale_night_num,
 sum(xx.payable_price_0_7) as payable_price_0_7,
 sum(xx.payable_price_7_22) as payable_price_7_22,
 sum(xx.payable_price_22_0) as payable_price_22_0
 from order_list xx
 join store_business_type tt on xx.order_date = tt.record_date and xx.store_code = tt.store_code
 group by
 date_add(xx.order_date,1 - case when dayofweek(xx.order_date) = 1 then 1 else dayofweek(xx.order_date) - 7 end),
 xx.store_cvs_code,
 xx.display_name,
 xx.store_city

 -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--分小时明细
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

 date_list as(
    select
    date_key,
    case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
    from default.dim_date_ya_v2
 ),

 --当月营业天数
 open_days_cnt as (
   select
   trunc(t.order_date,'MM') as month
   ,tt.date_type
   ,store_code
   ,count(distinct order_date) as open_days
   from default.dw_order_sku_promotion_v1 t --订单明细表
   left join date_list tt on t.order_date = tt.date_key
   where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
   and store_type = '0'
   and pay_status = 'PAY_SUCCESS'
   and order_date between '2021-08-01' and '2021-08-31'
   group by
   trunc(t.order_date,'MM')
   ,tt.date_type
   ,store_code  
 )

select
 trunc(t.order_date,'MM') as month
 ,b.date_type
 ,sku_class_code
 ,hour(order_time) as hour
 ,a.store_cvs_code
 ,a.display_name
 ,t.store_city
 ,c.open_days

 --营业日
 ,count(distinct order_date) as days

 --订单量
 ,count(distinct order_no) as order_cnt --全部订单量
 ,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
 ,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
  
 --折后销售额 按照到店/外卖拆分
 ,sum(payable_price) as payable_price --全部销售额
 ,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
 ,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额
 
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
 
from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
left join date_list b on t.order_date = b.date_key
left join open_days_cnt c on t.store_code = c.store_code and trunc(t.order_date,'MM') = c.month and b.date_type = c.date_type
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 and order_date between '2021-08-01' and '2021-08-31'
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
group by 
 trunc(t.order_date,'MM')
 ,b.date_type
 ,sku_class_code
 ,hour(order_time)
 ,a.store_cvs_code
 ,a.display_name
 ,t.store_city
 ,c.open_days

 ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 --分品类销售
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

 date_list as(
    select
    date_key,
    case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
    from default.dim_date_ya_v2
 ),

 --当周营业天数
 open_days_cnt as (
   select
   date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as week
   ,tt.date_type
   ,store_code
   ,count(distinct order_date) as open_days
   from default.dw_order_sku_promotion_v1 t --订单明细表
   left join date_list tt on t.order_date = tt.date_key
   where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
   and store_type = '0'
   and pay_status = 'PAY_SUCCESS'
   and order_date between '2021-08-01' and '2021-08-31'
   group by
   date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
   ,tt.date_type
   ,store_code  
 )

select
 date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as week
 ,b.date_type
 ,a.store_cvs_code
 ,a.display_name
 ,t.store_city
 ,c.open_days

 --营业日
 ,count(distinct order_date) as days

 --订单量
 ,count(distinct order_no) as order_cnt --全部订单量
 ,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
 ,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
  
 --折后销售额 按照到店/外卖拆分
 ,sum(payable_price) as payable_price --全部销售额
 ,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
 ,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额
 
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
 
from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
left join date_list b on t.order_date = b.date_key
left join open_days_cnt c on t.store_code = c.store_code and date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) = c.week and b.date_type = c.date_type
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 and order_date between '2021-08-01' and '2021-08-31'
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
group by 
 date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
 ,b.date_type
 ,a.store_cvs_code
 ,a.display_name
 ,t.store_city
 ,c.open_days

 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 --热餐售卖情况
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

 date_list as(
select
date_key,
case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
from default.dim_date_ya_v2
),

 --热餐售卖日
 ff_days as(
   select
   order_date
   ,store_code
   from default.dw_order_sku_promotion_v1
   where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and order_date between '2016-08-01' and '2022-12-31'
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
 and  sku_class_code in ('03','05','06')
 and sku_division_code in ('0301','0304')
 group by
 order_date
,store_code
 )

select
 date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as week
 ,t.store_city
 ,a.store_cvs_code
 ,a.display_name
 ,c.date_type
 
 --营业日
 ,count(distinct t.order_date) as order_date --营业日
 ,sum(payable_price) as payable_price --全部销售额
 
 --折后销售额 按照商品拆分
 ,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then payable_price else 0 end ) as payable_price_ff --热餐销售额

from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
join ff_days b on t.store_code = b.store_code and t.order_date = b.order_date
left join date_list c on t.order_date = c.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and t.order_date between '2016-08-01' and '2022-12-31'
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
 --and a.store_cvs_code = '100001153'
group by 
  date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
 ,t.store_city
 ,a.store_cvs_code
 ,a.display_name
 ,date_type
 -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 --热餐售卖情况(订单量)
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

 date_list as(
select
date_key,
case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
from default.dim_date_ya_v2
),

 --热餐售卖日
 ff_days as(
   select
   order_date
   ,store_code
   from default.dw_order_sku_promotion_v1
   where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and order_date between '2016-08-01' and '2022-12-31'
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
 and  sku_class_code in ('03','05','06')
 and sku_division_code in ('0301','0304')
 group by
 order_date
,store_code
 )

select
 order_date
 ,t.store_city
 ,a.store_cvs_code
 ,a.display_name
 ,c.date_type
 
 --营业日
 ,count(distinct t.order_date) as order_date --营业日
 ,count(distinct order_no) as order_no --全部销售额
 
 --折后销售额 按照商品拆分
 ,count(distinct case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then order_no else 0 end ) as order_no_ff --热餐销售额

from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
join ff_days b on t.store_code = b.store_code and t.order_date = b.order_date
left join date_list c on t.order_date = c.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and t.order_date between '2016-08-01' and '2022-12-31'
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
 and a.store_cvs_code in ('100001153','101000112')
group by 
  t.order_date
 ,t.store_city
 ,a.store_cvs_code
 ,a.display_name
 ,date_type

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店香烟销售数据
select
trunc(order_date,'MM') as month
,store_code
,store_name
 
--订单量
,count(distinct order_no) as order_cnt --全部订单量

--折后销售额 按照到店/外卖拆分
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
from data_build.dw_order_sku_promotion_v1
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2024-01-01' and '2025-11-30'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '101000220'
group by
trunc(order_date,'MM')
,store_code
,store_name

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--过去一年热餐销售高/中/低档位（区分周中周末）

--工作日列表
with work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--店*日午餐段热餐&全时段销售额
day_payable_price_hot_meal as(
select
order_date
,store_code
,store_name
,is_working_day
,sum(case when sku_division_code in ('0301') and substr(order_time,12,8) between '11:00:00' and '14:00:00' then payable_price end)/count(distinct a.store_code) as payable_price_hot_meal
,sum(payable_price)/count(distinct a.store_code) as payable_price
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
where dt = 20230211
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by
order_date
,store_code
,store_name
,is_working_day)

--高中低档位热餐销售天数
select
store_code
,store_name
,is_working_day
,count(case when payable_price_hot_meal > 700 then order_date end) as hight_sale_days
,count(case when payable_price_hot_meal < 700 and payable_price_hot_meal >= 300 then order_date end) as normal_sale_days
,count(case when payable_price_hot_meal < 300 and payable_price_hot_meal > 0 then order_date end) as low_sale_days
from day_payable_price_hot_meal
where order_date between '2022-02-10' and '2023-02-09'
group by
store_code
,store_name
,is_working_day

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店销售额，剔烟销售额，热餐销售额TOP1&TOP10%

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
display_name
),

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

--每日销售额
order_list as(
select
order_date
,store_code
,store_name
,is_working_day
,sum(case when sku_division_code in ('0301') then payable_price end) as payable_price_hot_meal
,sum(payable_price)/count(distinct a.store_code) as payable_price
,sum(case when sku_division_code not in ('6101','6102') then payable_price end) as payable_price_no_cigarette
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
where dt = 20230315
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and order_date between '2021-06-01' and '2023-02-09'
group by
order_date
,store_code
,store_name
,is_working_day
),

total_num as(
select
store_code
,is_working_day
,count(*) as total_num
from order_list
group by
store_code
,is_working_day
),

--窗口函数
window_function as(
select
a.order_date
,a.store_code
,a.store_name
,a.is_working_day
,a.payable_price
,a.payable_price_no_cigarette
,b.total_num
,row_number() over (partition by concat(a.store_code,a.is_working_day) order by payable_price_hot_meal desc) as row_number_payable_price_hot_meal
,row_number() over (partition by concat(a.store_code,a.is_working_day) order by payable_price desc) as row_number_payable_price
,row_number() over (partition by concat(a.store_code,a.is_working_day) order by payable_price_no_cigarette desc) as row_number_payable_price_no_cigarette
from order_list a
left join total_num b on a.store_code = b.store_code and a.is_working_day = b.is_working_day
)

select
order_date
,store_code
,store_name
,is_working_day
,payable_price
,payable_price_no_cigarette
,total_num
,row_number_payable_price
,row_number_payable_price
,row_number_payable_price_no_cigarette
,abs(row_number_payable_price_hot_meal/total_num-0.1) as payable_price_hot_meal_ten
,abs(row_number_payable_price/total_num-0.1) as payable_price_ten
,abs(row_number_payable_price_no_cigarette/total_num-0.1) as payable_price_no_cigarette_ten
,row_number() over (partition by concat(store_code,is_working_day) order by abs(row_number_payable_price_hot_meal/total_num-0.1)) as row_number_payable_price_hot_meal_ten
,row_number() over (partition by concat(store_code,is_working_day) order by abs(row_number_payable_price/total_num-0.1)) as row_number_payable_price_ten
,row_number() over (partition by concat(store_code,is_working_day) order by abs(row_number_payable_price_no_cigarette/total_num-0.1)) as row_number_payable_price_no_cigarette_ten
from window_function
where is_working_day = '非工作日'

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
display_name
),

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

--店外客流清单
outside_flow_cnt_out_list as(
select 
b.store_code
,a.event_date
,c.is_working_day
--,time_hour as event_hour --小时
--,come_customer_num
--,go_customer_num --进店客流
--,outside_flow_cnt_in
,sum(outside_flow_cnt_out) as outside_flow_cnt_out--店外客流
from data_smartorder.dm_ordering_report_store_change_info_di a
left join desensitization b on a.store_code = b.store_code
left join work_day_list c on a.event_date = c.date_key
where dt >= date_format(date_sub(current_date(),11365),'yyyyMMdd')
--and b.store_cvs_code = '123001001'
and outside_flow_cnt_out > 0
group by
b.store_code
,a.event_date
,c.is_working_day
),

total_num as(
select
store_code
,is_working_day
,count(*) as total_num
from outside_flow_cnt_out_list
group by
store_code
,is_working_day
)

select
a.store_code
,a.event_date
,a.is_working_day
,a.outside_flow_cnt_out
,b.total_num
,row_number() over (partition by concat(a.store_code,a.is_working_day) order by a.outside_flow_cnt_out desc) as row_number_outside_flow_cnt_out
,abs(row_number() over (partition by concat(a.store_code,a.is_working_day) order by a.outside_flow_cnt_out desc)/b.total_num-0.1) as outside_flow_cnt_out_ten
,row_number() over (partition by concat(a.store_code,a.is_working_day) order by abs(row_number() over (partition by concat(a.store_code,a.is_working_day) order by a.outside_flow_cnt_out desc)/b.total_num-0.1)) as row_number_outside_flow_cnt_out_ten
from outside_flow_cnt_out_list a
left join total_num b on a.store_code = b.store_code and a.is_working_day = b.is_working_day
where a.is_working_day = '非工作日'

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--2月销售天数
with sale_list as(
select
order_date
,store_code
,store_name
,count(*) as sale_num
,sum(payable_price)/count(distinct a.store_code) as payable_price
from default.dw_order_sku_promotion_v1 a
where dt = 20230309
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and order_date between '2023-02-01' and '2023-02-28'
group by
order_date
,store_code
,store_name
)

select
store_code
,store_name
,sale_num
,sum(payable_price)/sale_num as sale_day
from sale_list
group by
store_code
,store_name
,sale_num

select
*
from default.dw_order_sku_promotion_v1
where dt = 20230309
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100000529'
and sku_division_code in ('0301')

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
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
)

select
 t.order_date
 ,t.store_code
 ,t.store_name
 ,t.store_city
 ,a.store_code
 
 --订单量
 ,count(distinct order_no) as order_cnt --全部订单量
 ,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
 ,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
 
 --折后销售额 按照到店/外卖拆分
 ,sum(payable_price) as payable_price --全部销售额
 ,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
 ,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
left join work_day_list b on t.order_date = b.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and order_date between '2023-03-06' and '2023-03-10'
 and b.is_working_day = '工作日'
 and a.store_cvs_code in ('612000071',
'110000131',
'100000625',
'100000338',
'109000257',
'109000133',
'110000373',
'110000026',
'107000011',
'101000159',
'100023002',
'101000101',
'100000165',
'100000517',
'100001179',
'123000033',
'100000189',
'123000186',
'100000657',
'100033001',
'188001006',
'109000080',
'100001003',
'109000051',
'100075007',
'123000389',
'109000036',
'123000293',
'123000171',
'110000002',
'100000073',
'110000051',
'123000133',
'100001057',
'110001027',
'107000009',
'100000199',
'100006003',
'109000077',
'123000076',
'123000195',
'100000169',
'109000079',
'100071001',
'100022001',
'110000015',
'110000106',
'123001077',
'100000108',
'100000150',
'110000073',
'100000237',
'123000225',
'107000006',
'123000008') --门店编码
 and store_type = '0'
 and pay_status = 'PAY_SUCCESS'
group by 
 t.order_date
 ,t.store_code
 ,t.store_name
 ,t.store_city
 ,a.store_code

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
with work_day_list as(
select
date_key
,case when is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
)

select
trunc(order_date,'MM') as month
,store_code
,store_name
,b.is_working_day

--售卖日
,count(distinct order_date) as sale_num --全部售卖日
 
--订单量
,count(distinct order_no) as order_cnt --全部订单量

--折后销售额 按照到店/外卖拆分
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
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2021-09-01' and '2023-03-13'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and a.store_code = '100000696'
group by
trunc(order_date,'MM')
,store_code
,store_name
,b.is_working_day

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--外卖占比
select
--t.order_date
t.store_code
,t.store_name
,t.store_city

--订单量
,count(distinct order_no) as order_cnt --全部订单量
,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量

--折后销售额 按照到店/外卖拆分
,sum(payable_price) as payable_price --全部销售额
,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2021-08-01' and '2021-09-30'
--and a.store_cvs_code in ('100010002') --门店编码
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
--t.order_date
t.store_code
,t.store_name
,t.store_city
















--每日销售额
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,store_code
,store_name
,sum(payable_price)/count(distinct concat(a.store_code,order_date)) as payable_price_day
from default.dw_order_sku_promotion_v1 a
where dt = 20230322
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and order_date between '2022-08-01' and '2022-08-30'
and store_code = '100001678'
group by
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,store_code
,store_name





--过去一年热餐销售高/中/低档位（区分周中周末）

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

--店*日午餐段热餐&全时段销售额
select
order_date
,store_code
,store_name
,is_working_day
,count(distinct case when sku_division_code in ('0301') and substr(order_time,12,8) between '11:00:00' and '14:00:00' then order_no end)/count(distinct a.store_code) as order_num_hot_meal
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
where dt = 20230328
and store_code = '100000587'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by
order_date
,store_code
,store_name
,is_working_day




select
*
from default.dw_order_sku_promotion_v1 a
where dt = 20230328
and store_code = '100000587'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and order_date in ('2023-03-09','2023-03-15')
and sku_division_code in ('0301')
--and substr(order_time,12,8) between '11:00:00' and '14:00:00'
--------------------------------------------------------------------------------------------------------------------------
--佳宇促销表日商
--周日商
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
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,t.store_code 
--,t.store_name

--周中日订单量折前销售额折后销售额

,count(distinct case when b.is_working_day = 1 then t.order_no end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_order_cnt --订单量
,sum(case when b.is_working_day = 1 then t.sell_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_sell_price --折前销售额
,sum(case when b.is_working_day = 1 then t.payable_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_payable_price --折后销售额

,count(distinct t.order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1 t
left join work_day_list b on t.order_date = b.date_key 
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date >= '2023-07-10'
and store_code = '100001115'
group by date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,t.store_code 
--,t.store_name

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as order_week
,t.store_code
,t.store_name
,t.store_city

--折后销售额 按照到店/外卖拆分
,sum(payable_price) as payable_price --全部销售额

 --折后销售额 按照商品拆分
,sum(case when sku_division_code in ('6101','6102') then payable_price else 0 end) as payable_price_cigarette --香烟销售额

from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '123000352'
group by 
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
,t.store_name
,t.store_city

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
store_code,
store_name,
store_cvs_code,
display_name)

select
*
from default.dw_order_sku_promotion_v1 t --订单明细表
left join desensitization a on t.store_code = a.store_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2023-04-12' and '2023-04-15'
and a.store_cvs_code in ('100000023') --门店编码
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and sku_class_code in ('03','05','06')
and sku_division_code in ('0301','0304')

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


select
trunc(t.order_date,'MM') as month
,t.store_code
,t.store_name
,t.store_city

--营业天数
,count(distinct order_date) as order_date_num
 
--订单量
,count(distinct order_no) as order_cnt --全部订单量
,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量

--折后销售额 按照到店/外卖拆分
,sum(payable_price) as payable_price --全部销售额
,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

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
 
from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2023-09-01' and '2023-09-30'
and store_code in ('123001002') --门店编码
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
trunc(t.order_date,'MM')
,t.store_code
,t.store_name
,t.store_city

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--21年4月经营门店
with twenty_one_year_four as(
select
store_code
from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2021-04-01' and '2021-04-30'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by
store_code),

--21年4月和23年4.17-4.23同时有经营数据门店列表
same_store_list as(
select
t.store_code
from default.dw_order_sku_promotion_v1 t --订单明细表
join twenty_one_year_four b on t.store_code = b.store_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2023-04-17' and '2023-04-23'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by
t.store_code)

select
t.store_code
,t.store_city

--营业天数
,count(distinct case when order_date between '2021-04-01' and '2021-04-30' then order_date else null end) as twenty_one_year_four_order_date_num
,count(distinct case when order_date between '2023-04-17' and '2023-04-23' then order_date else null end) as twenty_three_year_four_order_date_num

--折前销售额 按照到店/外卖拆分
,sum(case when order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price --全部销售额
,sum(case when order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price --全部销售额

--折前销售额 按照商品拆分
,sum(case when sku_division_code in ('6101','6102') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price_cigarette --香烟销售额
,sum(case when sku_class_code in ('01','02','04','08','10','11','13') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price_fresh --风幕日配短保 销售额
,sum(case when sku_class_code in ('21') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price_bread --常温日配短保 销售额（面包）
,sum(case when sku_class_code in ('12') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price_milk --风幕12乳饮 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price_hotmeal --日配热餐米饭 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end ) as twenty_one_year_four_payable_price_ff --日配制作类销售额
,sum(case when sku_class_code in ('07') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end ) as twenty_one_year_four_payable_price_coffee --咖啡豆浆自助饮品销售额
,sum(case when sku_class_code in ('30','31','32','33','42') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price_drinks --水饮销售额（白酒洋酒饮料冰淇淋等)
,sum(case when sku_class_code in ('34','35','36','37','38','40','41') and order_date between '2021-04-01' and '2021-04-30' then sell_price else 0 end) as twenty_one_year_four_payable_price_snack --非日配食品销售额（薯片饼干香肠泡面糖巧等）

--折前销售额 按照商品拆分
,sum(case when sku_division_code in ('6101','6102') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price_cigarette --香烟销售额
,sum(case when sku_class_code in ('01','02','04','08','10','11','13') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price_fresh --风幕日配短保 销售额
,sum(case when sku_class_code in ('21') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price_bread --常温日配短保 销售额（面包）
,sum(case when sku_class_code in ('12') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price_milk --风幕12乳饮 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price_hotmeal --日配热餐米饭 销售额
,sum(case when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end ) as twenty_three_year_four_payable_price_ff --日配制作类销售额
,sum(case when sku_class_code in ('07') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end ) as twenty_three_year_four_payable_price_coffee --咖啡豆浆自助饮品销售额
,sum(case when sku_class_code in ('30','31','32','33','42') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price_drinks --水饮销售额（白酒洋酒饮料冰淇淋等)
,sum(case when sku_class_code in ('34','35','36','37','38','40','41') and order_date between '2023-04-17' and '2023-04-23' then sell_price else 0 end) as twenty_three_year_four_payable_price_snack --非日配食品销售额（薯片饼干香肠泡面糖巧等）
 
from default.dw_order_sku_promotion_v1 t --订单明细表
join same_store_list b on t.store_code = b.store_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2016-10-01' and '2023-04-23'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
t.store_code
,t.store_city











--佳宇促销表日商
--周日商
--工作日列表
with work_day_list as(
select
date_key
,day_of_week_name
from default.dim_date_ya_v2
group by
date_key
,day_of_week_name
)

select 
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,t.store_code 
--,t.store_name

--周中日订单量折前销售额折后销售额

,count(distinct case when b.day_of_week_name in ('星期四','星期五') then t.order_no else null end)/count(distinct case when b.day_of_week_name in ('星期四','星期五') then order_date else null end) as zhouzhong_order_cnt --订单量
,sum(case when b.day_of_week_name in ('星期四','星期五') then t.sell_price else 0 end)/count(distinct case when b.day_of_week_name in ('星期四','星期五') then order_date else null end) as zhouzhong_sell_price --折前销售额
,sum(case when b.day_of_week_name in ('星期四','星期五') then t.payable_price else 0 end)/count(distinct case when b.day_of_week_name in ('星期四','星期五') then order_date else null end) as zhouzhong_payable_price --折后销售额

,count(distinct t.order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1 t
left join work_day_list b on t.order_date = b.date_key 
where t.dt = '20230710'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date >= '2023-02-20'
group by date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,t.store_code 
--,t.store_name





--佳宇促销表日商
--月日商
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
trunc(order_date,'MM') as record_month
,t.store_code 
,t.store_name

--周中日订单量折前销售额折后销售额

,count(distinct case when b.is_working_day = 1 then t.order_no end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_order_cnt --订单量
,sum(case when b.is_working_day = 1 then t.sell_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_sell_price --折前销售额
,sum(case when b.is_working_day = 1 then t.payable_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_payable_price --折后销售额

,count(distinct t.order_no)/count(distinct order_date) as quanyue_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanyue_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanyue_payable_price --折后销售额
from dw_order_sku_v1 t
left join work_day_list b on t.order_date = b.date_key 
where t.dt = '20230523'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2016-04-01' and '2023-05-23'
and t.store_code = '123001037'
group by trunc(order_date,'MM')
,t.store_code 
,t.store_name

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--佳宇促销表日商
--任一时间范围日商
select 
t.store_code 
,t.store_name
,count(distinct t.order_no)/count(distinct order_date) as quanyue_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanyue_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanyue_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2025-11-20' and '2025-12-09'
and store_code = '100001565'
group by t.store_code 
,t.store_name

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--月维度日商（同cohort）
--当月营业天数
with payable_price_list as(
select
trunc(order_date,'MM') as month
,store_code
,store_city

--折后销售额 按照到店/外卖拆分
,sum(payable_price) as payable_price --全部销售额
,sum(payable_price)/count(distinct order_date) as avg_payable_price --月度日商

from default.dw_order_sku_promotion_v1 --订单明细表
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
and order_date between '2021-05-01' and '2023-04-30'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
trunc(order_date,'MM')
,store_code
,store_city)

select
a.month
,b.month
,a.store_city
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 1) then a.avg_payable_price else 0 end) as a_avg_payable_price_1
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 1) then b.avg_payable_price else 0 end) as b_avg_payable_price_1

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 2) then a.avg_payable_price else 0 end) as a_avg_payable_price_2
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 2) then b.avg_payable_price else 0 end) as b_avg_payable_price_2

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 3) then a.avg_payable_price else 0 end) as a_avg_payable_price_3
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 3) then b.avg_payable_price else 0 end) as b_avg_payable_price_3

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 4) then a.avg_payable_price else 0 end) as a_avg_payable_price_4
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 4) then b.avg_payable_price else 0 end) as b_avg_payable_price_4

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 5) then a.avg_payable_price else 0 end) as a_avg_payable_price_5
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 5) then b.avg_payable_price else 0 end) as b_avg_payable_price_5

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 6) then a.avg_payable_price else 0 end) as a_avg_payable_price_6
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 6) then b.avg_payable_price else 0 end) as b_avg_payable_price_6

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 7) then a.avg_payable_price else 0 end) as a_avg_payable_price_7
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 7) then b.avg_payable_price else 0 end) as b_avg_payable_price_7

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 8) then a.avg_payable_price else 0 end) as a_avg_payable_price_8
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 8) then b.avg_payable_price else 0 end) as b_avg_payable_price_8

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 9) then a.avg_payable_price else 0 end) as a_avg_payable_price_9
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 9) then b.avg_payable_price else 0 end) as b_avg_payable_price_9

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 10) then a.avg_payable_price else 0 end) as a_avg_payable_price_10
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 10) then b.avg_payable_price else 0 end) as b_avg_payable_price_10

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 11) then a.avg_payable_price else 0 end) as a_avg_payable_price_11
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 11) then b.avg_payable_price else 0 end) as b_avg_payable_price_11

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 12) then a.avg_payable_price else 0 end) as a_avg_payable_price_12
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 12) then b.avg_payable_price else 0 end) as b_avg_payable_price_12

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 13) then a.avg_payable_price else 0 end) as a_avg_payable_price_13
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 13) then b.avg_payable_price else 0 end) as b_avg_payable_price_13

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 14) then a.avg_payable_price else 0 end) as a_avg_payable_price_14
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 14) then b.avg_payable_price else 0 end) as b_avg_payable_price_14

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 15) then a.avg_payable_price else 0 end) as a_avg_payable_price_15
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 15) then b.avg_payable_price else 0 end) as b_avg_payable_price_15

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 16) then a.avg_payable_price else 0 end) as a_avg_payable_price_16
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 16) then b.avg_payable_price else 0 end) as b_avg_payable_price_16

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 17) then a.avg_payable_price else 0 end) as a_avg_payable_price_17
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 17) then b.avg_payable_price else 0 end) as b_avg_payable_price_17

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 18) then a.avg_payable_price else 0 end) as a_avg_payable_price_18
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 18) then b.avg_payable_price else 0 end) as b_avg_payable_price_18

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 19) then a.avg_payable_price else 0 end) as a_avg_payable_price_19
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 19) then b.avg_payable_price else 0 end) as b_avg_payable_price_19

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 20) then a.avg_payable_price else 0 end) as a_avg_payable_price_20
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 20) then b.avg_payable_price else 0 end) as b_avg_payable_price_20

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 21) then a.avg_payable_price else 0 end) as a_avg_payable_price_21
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 21) then b.avg_payable_price else 0 end) as b_avg_payable_price_21

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 22) then a.avg_payable_price else 0 end) as a_avg_payable_price_22
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 22) then b.avg_payable_price else 0 end) as b_avg_payable_price_22

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 23) then a.avg_payable_price else 0 end) as a_avg_payable_price_23
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 23) then b.avg_payable_price else 0 end) as b_avg_payable_price_23

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 24) then a.avg_payable_price else 0 end) as a_avg_payable_price_24
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 24) then b.avg_payable_price else 0 end) as b_avg_payable_price_24

,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 25) then a.avg_payable_price else 0 end) as a_avg_payable_price_25
,avg(case when a.store_code = b.store_code and a.month = add_months(b.month,- 25) then b.avg_payable_price else 0 end) as b_avg_payable_price_25


from payable_price_list a
left join payable_price_list b
on a.store_code = b.store_code
group by
a.month
,b.month
,a.store_city

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as week
,store_code

--营业日
,count(distinct order_date) as days

--订单量
,count(distinct order_no) as order_cnt --全部订单量
,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
  
--折后销售额 按照到店/外卖拆分
,sum(payable_price) as payable_price --全部销售额
,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额
 
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
 
from default.dw_order_sku_promotion_v1 --订单明细表
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
and order_date between '2023-04-17' and '2023-05-14'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
group by 
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,store_code


select t.store_code
      ,nvl(t.user_id,'-1') as user_id
      ,t.order_date
      ,t.order_no
      ,t.order_time
      ,t.order_business_type
      ,t.is_fresh_food
      ,t.sku_division_code
      ,t.sku_code
      ,sum(t.sku_quantity) as sku_quantity
      ,sum(t.sell_price) as sell_price
      ,sum(t.payable_price) as payable_price
     -- ,sum(t.profit_price) as profit_price
      ,sum(nvl(t.payable_price,0)-nvl(t.cost_price,0)-nvl(t.cost_tax,0)+nvl(t.vendor_allocated_cost_price,0)) as profit_price
      ,sum(if(nvl(t.activity_name,'aa') not like 'DY_动态促销活动%',t.sku_quantity,0)) as nody_sku_quantity
      ,sum(if(nvl(t.activity_name,'aa') not like 'DY_动态促销活动%',t.payable_price,0)) as nody_payable_price
 --from data_promotion.dm_promotion_store_detl_order_detail_info_da t
  from dw_order_sku_promotion_v1 t
 where t.dt = '20230612'
   and t.order_status = 'FINISHED'
   and t.store_type = '0'
   and t.sku_class_code not in ('50','86')
 --and nvl(t.activity_name,'aa') not like 'DY_动态促销活动%'
   and t.order_date between '2023-05-29' and '2023-06-11'
   and t.store_code in ('107000232','100005019','103000009','108000006','110000102')
group by t.store_code
        ,nvl(t.user_id,'-1')
        ,t.order_date
        ,t.order_no
        ,t.order_time
        ,t.order_business_type
        ,t.is_fresh_food
        ,t.sku_division_code
        ,t.sku_code

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--佳宇促销表日商
--天维度日商
select 
order_date
,t.store_code
,count(distinct t.order_no) as quanzhou_order_cnt --订单量
,sum(t.sell_price) as quanzhou_sell_price --折前销售额
,sum(t.payable_price) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1 t 
where t.dt = '20230619'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date >= '2023-06-11'
group by order_date
,t.store_code
        




















select
t.order_date
,order_time
,t.store_code
,sku_name
,sku_quantity
,payable_price --全部销售额
from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and (order_date between '2023-06-07' and '2023-06-07' or order_date between '2023-06-07' and '2023-06-07')
and t.store_code in ('107000055') --门店编码
--and sku_division_code in ('6101','6102')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--夜间销售占比（周维度）
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

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店周维度日商明细
with store_payable_price_list as(
select 
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,t.store_code
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1 t
where t.dt = '20230629'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
--and t.order_date >= '2023-02-20'
--and store_code = '123000113'
group by date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,t.store_code 
--,t.store_name
),

--促销时间明细表
time_line as(
select
store_code
,store_city
,start_date
,end_date
from data_promotion.dm_promotion_daily_detl_2023_daily_activity_store_list_di
where dt = 20230629
)

--促销时段内日商明细
select
t0.store_code
,t0.store_city
,t0.start_date
,t0.end_date
,t1.quanzhou_sell_price
,t1.quanzhou_payable_price
,t2.quanzhou_sell_price
,t2.quanzhou_payable_price
,t3.quanzhou_sell_price
,t3.quanzhou_payable_price
from time_line t0
left join store_payable_price_list t1 on t0.store_code = t1.store_code and t0.start_date = date_add(t1.record_week,1)
left join store_payable_price_list t2 on t0.store_code = t2.store_code and t0.end_date = t2.record_week
left join store_payable_price_list t3 on t0.store_code = t3.store_code and date_add(t0.end_date,7) = t3.record_week

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--周维度门店促销折后
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
),

--周日商(21年起)
source_list as(
select
date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end) as record_week
,t0.store_code
,case when t1.activity_type is null then '100' else t1.activity_type end as activity_type
,t2.breakeven_point as breakeven_point

--周中日订单量折前销售额折后销售额
,count(distinct t0.order_no)/count(distinct t0.order_date) as order_cnt --订单量
,sum(t0.sell_price)/count(distinct t0.order_date) as sell_price --折前销售额
,sum(t0.payable_price)/count(distinct t0.order_date) as payable_price --折后销售额
from dw_order_sku_v1 t0
left join promotion_list t1 on date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end) = t1.record_week and t0.store_code = t1.store_code
left join be_list t2 on t0.store_code = t2.store_code
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_type = '0'
and t0.order_status = 'FINISHED'
and t0.sku_class_code not in ('86','50')
and t0.sku_quantity > 0
and t0.order_date between '2021-01-04' and '2023-07-02'
group by 
date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end)
,t0.store_code
,case when t1.activity_type is null then '100' else t1.activity_type end
,t2.breakeven_point
)

select
store_code
,breakeven_point
,count(record_week) as sell_num
,count(case when activity_type <= 79 then store_code end) as promotion_sell_num
,count(case when activity_type > 79 and payable_price > breakeven_point*0.9 then store_code end) as ashore_num_without_promotion--可以调整达标率系数
,percentile_approx(case when activity_type > 79 then payable_price else null end,0.75) as top_25_position
,sum(case when record_week between '2023-06-01' and '2023-07-02' and activity_type > 79 then payable_price else null end)
/count(case when record_week between '2023-06-01' and '2023-07-02' and activity_type > 79 then store_code else null end) as six_payable_price
from source_list
group by
store_code
,breakeven_point

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--分品类销售占比（任一时间段）
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
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-09-01' and '2023-11-26'
group by
t.order_date
,t.store_code
)

select
record_week
,store_code
--分品类销售额--日
,payable_price/sale_days as `销售额`
,payable_price_cigarette/sale_days as `香烟销售额`
,payable_price_fresh/sale_days as `风幕日配短保销售额`
,payable_price_bread/sale_days as `常温日配短保销售额(面包)`
,payable_price_milk/sale_days as `风幕12乳饮销售额`
,payable_price_hotmeal/sale_days as `日配热餐米饭销售额`
,payable_price_ff/sale_days as `日配制作类销售额`
,payable_price_coffee/sale_days as `咖啡豆浆自助饮品销售额`
,payable_price_drinks/sale_days as `水饮销售额`
,payable_price_snack/sale_days as `非日配食品销售额（薯片饼干香肠泡面糖巧等）销售额`
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/sale_days as `其它销售额`
--分品类销占比
,payable_price_cigarette/payable_price as `香烟销售占比`
,payable_price_fresh/payable_price as `风幕日配短保销售占比`
,payable_price_bread/payable_price as `常温日配短保销售占比(面包)`
,payable_price_milk/payable_price as `风幕12乳饮销售占比`
,payable_price_hotmeal/payable_price as `日配热餐米饭销售占比`
,payable_price_ff/payable_price as `日配制作类销售占比`
,payable_price_coffee/payable_price as `咖啡豆浆自助饮品销售占比`
,payable_price_drinks/payable_price as `水饮销售占比`
,payable_price_snack/payable_price as `非日配食品销售额（薯片饼干香肠泡面糖巧等）销售占比`
,(payable_price-payable_price_cigarette-payable_price_fresh-payable_price_bread-payable_price_milk-payable_price_hotmeal-payable_price_ff-payable_price_coffee-payable_price_drinks-payable_price_snack)/payable_price as `其它销售占比`
from sale_list

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--佳宇促销表日商
--21m7 vs 23.7.17-23.7.23日商恢复情况
--21m7各城市门店日商
with 21_m7 as(
select 
store_city
,store_code
,count(distinct order_date) as order_date_num
,sum(payable_price) as payable_price
,sum(payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2021-07-01' and '2021-07-31'
group by
store_city
,store_code),

--23.7.17-23.7.23日商
last_week as(
select 
store_city
,store_code
,count(distinct order_date) as order_date_num
,sum(payable_price) as payable_price
,sum(payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-07-17' and '2023-07-23'
group by
store_city
,store_code)

select
t.store_city
--21m7
,count(a.store_code) as 21_m7_store_num
,sum(a.order_date_num) as 21_m7_order_date_num
,sum(a.payable_price) as 21_m7_payable_price
,sum(a.payable_price)/sum(a.order_date_num) as 21_m7_payable_price
--last_week
,count(t.store_code) as last_week_store_num
,sum(t.order_date_num) as last_week_order_date_num
,sum(t.payable_price) as last_week_payable_price
,sum(t.payable_price)/sum(t.order_date_num) as last_week_payable_price
from last_week t
left join 21_m7 a on t.store_code = a.store_code
group by
t.store_city

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--店天日商
select 
order_date
,store_code 

--订单量折前销售额折后销售额

,count(distinct t.order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-08-01' and '2023-09-30'
and store_code in ('100000159')
group by order_date
,t.store_code 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--分天分小时明细
select
order_date
,hour(order_time) as hour
,store_code

--订单量
,count(distinct order_no) as order_cnt --全部订单量
,count(distinct case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_takeaway --外卖订单量
,count(distinct case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then order_no else null end ) as order_cnt_instore --到店订单量
 
--折后销售额 按照到店/外卖拆分
,sum(payable_price) as payable_price --全部销售额
,sum(case when order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_takeaway --外卖销售额
,sum(case when order_business_type not in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then payable_price else 0 end) as payable_price_instore --到店销售额

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
,sum(case when sku_class_code in ('14') or sku_division_code in ('6103') then payable_price else 0 end) as fresh_electronic_cigarettes --生鲜&电子烟
 
from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2019-08-01' and '2024-01-04'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
group by 
order_date
,hour(order_time)
,store_code

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店达标率
--门店be
with be_list as(
select * from default.dm_site_selection_store_info_lite
where dt = 20230930
)

--任一时间范围日商
select 
t.store_code 
,a.breakeven_point
,count(distinct t.order_no)/count(distinct order_date) as quanyue_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanyue_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanyue_payable_price --折后销售额
from dw_order_sku_v1 t
left join be_list a on t.store_code = a.store_code
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-09-01' and '2023-09-30'
group by t.store_code
,a.breakeven_point

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--分天分小时明细
select
*,
case when sku_division_code in ('6101','6102') then 'cigarette'
when sku_class_code in ('01','02','04','08','10','11','13') then 'fresh'
when sku_class_code in ('21') then 'bread'
when sku_class_code in ('12') then 'milk'
when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then 'hotmeal'
when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') then 'ff'
when sku_class_code in ('07') then 'coffee'
when sku_class_code in ('30','31','32','33','42') then 'drinks'
when sku_class_code in ('34','35','36','37','38','40','41') then 'snack' else 'other' end as type_pay
 
from default.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2021-08-01' and '2021-08-31'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--热餐客单价
select
trunc(order_date,'MM') as order_month
,store_code
,count(distinct case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then order_date else null end) as hotmeal_order_sall_num--0301是菜，0304是米饭
,count(distinct case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then order_no else null end) as hotmeal_order_num
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then payable_price else 0 end) as payable_price_hotmeal
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
--and order_date between '2021-08-01' and '2021-08-31'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
group by
trunc(order_date,'MM')
,store_code

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--热餐售卖情况
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
trunc(order_date,'MM') as order_month
,store_code
,count(distinct case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then order_date else null end) as hotmeal_order_sall_num--0301是菜，0304是米饭
,count(distinct case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then order_no else null end) as hotmeal_order_no_num--0301是菜，0304是米饭
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301') then sku_quantity else null end) as dish_num
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0304') then sku_quantity else 0 end) as rice_num
from data_build.dw_order_sku_promotion_v1 t --订单明细表
left join work_day_list b on t.order_date = b.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2023-07-01' and '2023-08-31'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and b.is_working_day = 1--只看工作日
--and store_code = '100078005'
group by
trunc(order_date,'MM')
,store_code

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店周维度达标率
--门店be
with be_list as(
select * from default.dm_site_selection_store_info_lite
where dt > 20230828
)

--任一时间范围日商
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code 
,a.breakeven_point
,count(distinct t.order_no)/count(distinct order_date) as quanyue_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanyue_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanyue_payable_price --折后销售额
from dw_order_sku_v1 t
left join be_list a on t.store_code = a.store_code and date_add(from_unixtime(unix_timestamp(a.dt,'yyyymmdd'),'yyyy-mm-dd'),0) = date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-10-09' and '2023-10-15'
group by
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
,a.breakeven_point

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--北京门店日商恢复情况
--门店达标率
--门店be
with work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
)

--任一时间范围日商
select
a.is_working_day
,count(distinct t.order_no)/count(distinct concat(order_date,store_code)) as quanyue_order_cnt --订单量
,sum(t.sell_price)/count(distinct concat(order_date,store_code)) as quanyue_sell_price --折前销售额
,sum(t.payable_price)/count(distinct concat(order_date,store_code)) as quanyue_payable_price --折后销售额
from dw_order_sku_v1 t
left join work_day_list a on t.order_date = a.date_key
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-09-18' and '2023-09-24'
and store_city = '北京市'
and store_code = '100078005'
group by
a.is_working_day

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店月维度日商
select
trunc(t.order_date,'MM') as record_month
,t.store_code 
,count(distinct t.order_no)/count(distinct order_date) as quanyue_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanyue_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanyue_payable_price --折后销售额
from dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-09-18' and '2023-10-19'
group by
trunc(t.order_date,'MM')
,t.store_code

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--佳宇促销表日商
--21m9 vs 23m9日商恢复情况
--门店list
with store_list as(
SELECT
a.store_code
,a.store_city
,a.open_date
,a.location_type
,b.store_type
from data_build.dm_site_selection_project_feature_info_di a
LEFT JOIN data_build.ods_upload_profit_list b on a.store_code = b.store_code and b.dt = 20231026
where a.dt = 20221114
and b.store_type is NOT NULL
and open_date < '2021-06-01'
),

--21m9各城市门店日商
21_m9 as(
select 
store_city
,store_code
,count(distinct order_date) as order_date_num
,sum(payable_price) as payable_price
,sum(payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2021-09-01' and '2021-09-30'
group by
store_city
,store_code),

--23m9各城市门店日商
23_m9 as(
select 
store_city
,store_code
,count(distinct order_date) as order_date_num
,sum(payable_price) as payable_price
,sum(payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-09-01' and '2023-09-30'
group by
store_city
,store_code)

select
t0.store_code
,t0.store_city
,t0.location_type
,t0.store_type
--21m9
,count(a.store_code) as 21_m9_store_num
,sum(a.order_date_num) as 21_m9_order_date_num
,sum(a.payable_price) as 21_m9_payable_price
,sum(a.payable_price)/sum(a.order_date_num) as 21_m9_payable_price
--23m9
,count(t.store_code) as 23_m9_store_num
,sum(t.order_date_num) as 23_m9_order_date_num
,sum(t.payable_price) as 23_m9_payable_price
,sum(t.payable_price)/sum(t.order_date_num) as 23_m9_payable_price
from store_list t0
join 21_m9 a on t0.store_code = a.store_code
join 23_m9 t on t0.store_code = t.store_code
group by
t0.store_code
,t0.store_city
,t0.location_type
,t0.store_type 

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--香烟渗透率
--香烟订单号
with order_no_cigarette_list as(
  select
  order_no
  from data_build.dw_order_sku_v1 t
  where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-11-01' and '2023-11-19'
--and store_code = '100078005'
and sku_division_code in ('6101','6102')
and t.store_city = '北京市'
group by
order_no
)

select
t0.order_date --日期
,count(distinct t0.order_no)/count(distinct concat(t0.order_date,t0.store_code)) --全部订单量
,sum(t0.payable_price)/count(distinct concat(t0.order_date,t0.store_code))  --折后销售额
,count(distinct case when t0.sku_division_code in ('6101','6102') then t0.order_no else null end)/count(distinct case when t0.sku_division_code in ('6101','6102') then concat(t0.order_date,t0.store_code) else null end)--香烟订单量
,sum(case when t0.sku_division_code in ('6101','6102') then t0.payable_price else 0 end)/count(distinct case when t0.sku_division_code in ('6101','6102') then concat(t0.order_date,t0.store_code) else null end)--香烟销售额
,sum(case when t1.order_no is not null then t0.payable_price else 0 end)/count(distinct case when t1.order_no is not null then concat(t0.order_date,t0.store_code) else null end) --含香烟订单销售额
from data_build.dw_order_sku_v1 t0
left join order_no_cigarette_list t1 on t0.order_no = t1.order_no
join data_build.dm_site_selection_project_feature_info_di t2 on t0.store_code = t2.store_code and t2.dt = 20221114
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_type = '0'
and t0.order_status = 'FINISHED'
and t0.sku_class_code not in ('86','50')
and t0.sku_quantity > 0
and t0.order_date between '2023-11-01' and '2023-11-19'
--and t0.store_code = '100078005'
and t2.location_type in ('办公','办公+其他')
and t0.store_city = '北京市'
group by
t0.order_date

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
with work_day_list as(
select
date_key
,case when is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
from data_build.dim_date_ya_v2
group by
date_key
,is_working_day
)

select
date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end) as record_week
,t0.store_code
,t0.store_name
,t1.is_working_day

--折后销售额 按照到店/外卖拆分
,sum(payable_price)/count(distinct concat(order_date,store_code)) as payable_price --全部销售额

from data_build.dw_order_sku_v1 t0
left join work_day_list t1 on t0.order_date = t1.date_key
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_type = '0'
and t0.order_status = 'FINISHED'
and t0.sku_class_code not in ('86','50')
and t0.sku_quantity > 0
and t0.order_date between '2023-10-02' and '2023-11-19'
and t0.store_code = '100078005'
and t0.store_city = '北京市'
group by
date_add(t0.order_date,7 - case when dayofweek(t0.order_date) = 1 then 7 else dayofweek(t0.order_date) - 1 end)
,t0.store_code
,t0.store_name
,t1.is_working_day

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店香烟销售量
select
t0.sku_code
,t0.sku_name
,count(distinct t0.store_code)
,sum(t0.sku_quantity) as sku_quantity
from data_build.dw_order_sku_v1 t0
join data_build.dm_site_selection_project_feature_info_di t1 on t0.store_code = t1.store_code and t1.dt = 20221114
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_type = '0'
and t0.order_status = 'FINISHED'
and t0.sku_class_code not in ('86','50')
and t0.sku_quantity > 0
and t0.order_date between '2023-09-01' and '2023-09-30'
and t0.sku_division_code in ('6101','6102')
and t1.location_type in ('办公','办公+其他')
group BY
t0.sku_code
,t0.sku_name

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店9:00香烟库存信息
with sku_info as
(select
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name
from default.dim_sku_info
where dt = 20231207
group by
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name)

select
from_unixtime(unix_timestamp(t0.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,t0.hr
,t0.store_code
,t0.sku_code
,t0.quantity
from default.dw_inventory_store_snapshot_ha_v1 t0
left join sku_info t1 on t0.sku_code = t1.sku_code
where from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') between '2023-12-04' and '2023-12-08'
and hr between '0' and '24'
and store_code = '100078005'
and is_available = '1'
and t1.sku_division_code in ('6101','6102')

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--每一笔含香烟订单中香烟的销售额
select
order_no
,order_date
,order_time
,store_code
,store_name
,payable_price
,payable_price_cigarette
from (
select
t0.order_no
,t0.order_date
,t0.order_time
,t0.store_code	
,t0.store_name
,sum(t0.payable_price) as payable_price	 -- 订单金额
,sum(case when t0.sku_division_code in ('6101','6102') then t0.payable_price else 0 end) as payable_price_cigarette
from data_build.dw_order_sku_v1 t0
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_type = '0'
and t0.order_status = 'FINISHED'
and t0.sku_class_code not in ('86','50')
and t0.sku_quantity > 0
and t0.order_date between '2023-09-01' and '2023-09-30'
and t0.store_city = '北京市'
group BY
t0.order_no
,t0.order_date
,t0.order_time
,t0.store_code	
,t0.store_name
) a
where payable_price_cigarette > '1500'

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店每日最大的香烟库存及销售数据
with sku_info as
(select
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name
from default.dim_sku_info
where dt = 20231121
group by
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name),

store_info as(
select
store_code
,store_name
,store_city
from default.dim_store_info
where dt = 20231121
group by
store_code
,store_name
,store_city),

--门店香烟销售明细
store_sale_cigarette_list as(
  select
  order_date
  ,store_code
  ,store_name
  ,sku_code
  ,sku_name
  ,sum(sku_quantity) as sku_quantity
  from data_build.dw_order_sku_v1 t0
  --join data_build.dm_site_selection_project_feature_info_di t1 on t0.store_code = t1.store_code and t1.dt = 20221114
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_type = '0'
and t0.order_status = 'FINISHED'
and t0.sku_class_code not in ('86','50')
and t0.sku_quantity > 0
and t0.order_date between '2023-09-01' and '2023-09-30'
and t0.sku_division_code in ('6101','6102')
--and t1.location_type in ('办公','办公+其他')
group BY
order_date
  ,store_code
  ,store_name
  ,sku_code
  ,sku_name
),

--库存与销量清单
inventory_sale_list as(
select a.*
,b.sku_quantity--实际销售量
,case when b.sku_quantity > 0 and a.quantity <= 0 then b.sku_quantity else a.quantity end as real_quantity--修正库存
from(
select
from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date--日期
,a.hr--小时
,a.store_code--门店编码
,c.store_name--门店名称
,a.sku_code--商品编码
,b.sku_division_name--商品中分类名称
,b.sku_name--商品名称
,a.quantity--库存
,row_number() over (partition by concat(a.dt,a.store_code,a.sku_code) order by a.quantity desc) as rn--序列
from default.dw_inventory_store_snapshot_ha_v1 a
left join sku_info b on a.sku_code = b.sku_code
left join store_info c on a.store_code = c.store_code
join data_build.dm_site_selection_project_feature_info_di t1 on a.store_code = t1.store_code and t1.dt = 20221114
where from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') between '2023-09-01' and '2023-09-30'
--and a.store_code = '100078005'
and a.is_available = '1'
--and a.quantity <> '0'
and store_type = '0'
and substring(a.sku_code,1,1) <>'9'
and substring(a.sku_code,1,2) not in ('81','82','83','84','86','87','89')
and b.sku_division_code in ('6101','6102')
and c.store_city = '北京市'
and t1.location_type in ('办公','办公+其他')
) a
left join store_sale_cigarette_list b on a.record_date = b.order_date and a.store_code = b.store_code and a.sku_code = b.sku_code
where rn = 1
and case when b.sku_quantity > 0 and a.quantity <= 0 then b.sku_quantity else a.quantity end > '0'
)

--单sku周转率
select
sku_code
,sku_name
,count(distinct concat(record_date,store_code))
,sum(sku_quantity)/count(distinct concat(record_date,store_code))
,sum(real_quantity)/count(distinct concat(record_date,store_code))
from inventory_sale_list
group by
sku_code
,sku_name

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--tableau表分品类销售（data_build.app_app_sale_by_category_v1_da）
with database_table as(
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4202','4204','4203','4201') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('3602','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4002','3702','4001','4007','3813','3703','4005','3805','3804','4003','3808','3802','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('0706','0721','0702','0717','0716','0720') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('7932','7931','3101','3103','3202','3201','3105') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2102','2107','2101','2106','2103','3809','2104') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('1209','1210','8802','7302','7934','6404','3806','7104','6408','3811','3910','4006','6407','3801','4004','7985','8502','3812','9701','9702','9703','8215','5001','1501','9706','1504','1507','5002','0902','1414','1304','2406','1415','1402','2603','8701','4408','3807','6201','7107','8606','7938') then payable_price else 0 end) as other
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0201','0101','0103','0102','1101','1302','0202','0401','0801','1301','1407','1102','1104','3803') then payable_price else 0 end) as daily_Fresh_Food
,sum(case when sku_division_code in ('0502','0604','0301','0304','0501','0302','0601','0602','0303','0603','0313','0503','0505') then payable_price else 0 end) as daily_production_category
,sum(case when sku_division_code in ('3701','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('7970','6806','7968','6503','7004','6501','7303','7301','7101','6703','7003','6403','6803','7964','7967','6502','7106','6802','7973','7965','7006','6701','7103','7002','6702','7001','6402','6804','7971','6401','7005','8801','7105','6805','7007','6801','7988') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4103','4104','4105','4102','4106','4101','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('1401','1404','2205','2202','2204','2203','2207','2201','2208','2206','2307') then payable_price else 0 end) as Vegetables_and_Fruits_Fresh
,sum(case when sku_division_code in ('3305','1201','3301','1205','1203','3307','3002','3306','1202','1206','3302','3308','3309','3001','7933','3003','1207','1204','3104','3102','7930','7912') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3403','3402') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3601','3503','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('6601','6602','7966') then payable_price else 0 end) as paper_physiological_products
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code not in ('3604','4202','4204','4203','4201','3408','3407','3405','3406','3602','7936','3603','4002','3702','4001','4007','3813','3703','4005','3805','3804','4003','3808','3802','7940'
,'0706','0721','0702','0717','0716','0720','7932','7931','3101','3103','3202','3201','3105','2102','2107','2101','2106','2103','3809','2104','1209','1210','8802','7302','7934','6404','3806','7104','6408','3811','3910',
'4006','6407','3801','4004','7985','8502','3812','9701','9702','9703','8215','5001','1501','9706','1504','1507','5002','0902','1414','1304','2406','1415','1402','2603','8701','4408','3807','6201','7107','8606','7938'
,'3404','0201','0101','0103','0102','1101','1302','0202','0401','0801','1301','1407','1102','1104','3803','0502','0604','0301','0304','0501','0302','0601','0602','0303','0603','0313','0503','0505','3701','7937',
'7970','6806','7968','6503','7004','6501','7303','7301','7101','6703','7003','6403','6803','7964','7967','6502','7106','6802','7973','7965','7006','6701','7103','7002','6702','7001','6402','6804','7971','6401',
'7005','8801','7105','6805','7007','6801','7988','4103','4104','4105','4102','4106','4101','7941','1401','1404','2205','2202','2204','2203','2207','2201','2208','2206','2307','3305','1201','3301','1205','1203','3307',
'3002','3306','1202','1206','3302','3308','3309','3001','7933','3003','1207','1204','3104','3102','7930','7912','3401','3403','3402','6101','6102','6103','3501','3502','3601','3503','7935','6601','6602','7966','3310')
then payable_price else 0 end) as no_attribution
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-08-28' and date_format(date_sub(current_date(),1),'yyyy-MM-dd')
group by
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
,store_city
),

nine_month_large_market as(
select
record_month
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.record_month
,x.store_code
,x.store_city
,x.sale_days
,MAP('日商',x.payable_price,'槟榔', x.betel_nut, '冰淇淋', x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'咖啡豆浆自助饮品',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'其他',x.other,'巧克力',x.chocolate,'日配鲜食',x.daily_Fresh_Food,'日配制作类',x.daily_production_category,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'蔬果&生鲜',x.Vegetables_and_Fruits_Fresh,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'纸生理用品',x.paper_physiological_products,'热饮料',x.hot_drinks
,'无归属',no_attribution) AS tmp_column
FROM(
select
trunc(t.order_date,'MM') as record_month
,t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4202','4204','4203','4201') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('3602','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4002','3702','4001','4007','3813','3703','4005','3805','3804','4003','3808','3802','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('0706','0721','0702','0717','0716','0720') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('7932','7931','3101','3103','3202','3201','3105') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2102','2107','2101','2106','2103','3809','2104') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('1209','1210','8802','7302','7934','6404','3806','7104','6408','3811','3910','4006','6407','3801','4004','7985','8502','3812','9701','9702','9703','8215','5001','1501','9706','1504','1507','5002','0902','1414','1304','2406','1415','1402','2603','8701','4408','3807','6201','7107','8606','7938') then payable_price else 0 end) as other
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0201','0101','0103','0102','1101','1302','0202','0401','0801','1301','1407','1102','1104','3803') then payable_price else 0 end) as daily_Fresh_Food
,sum(case when sku_division_code in ('0502','0604','0301','0304','0501','0302','0601','0602','0303','0603','0313','0503','0505') then payable_price else 0 end) as daily_production_category
,sum(case when sku_division_code in ('3701','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('7970','6806','7968','6503','7004','6501','7303','7301','7101','6703','7003','6403','6803','7964','7967','6502','7106','6802','7973','7965','7006','6701','7103','7002','6702','7001','6402','6804','7971','6401','7005','8801','7105','6805','7007','6801','7988') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4103','4104','4105','4102','4106','4101','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('1401','1404','2205','2202','2204','2203','2207','2201','2208','2206','2307') then payable_price else 0 end) as Vegetables_and_Fruits_Fresh
,sum(case when sku_division_code in ('3305','1201','3301','1205','1203','3307','3002','3306','1202','1206','3302','3308','3309','3001','7933','3003','1207','1204','3104','3102','7930','7912') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3403','3402') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3601','3503','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('6601','6602','7966') then payable_price else 0 end) as paper_physiological_products
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code not in ('3604','4202','4204','4203','4201','3408','3407','3405','3406','3602','7936','3603','4002','3702','4001','4007','3813','3703','4005','3805','3804','4003','3808','3802','7940'
,'0706','0721','0702','0717','0716','0720','7932','7931','3101','3103','3202','3201','3105','2102','2107','2101','2106','2103','3809','2104','1209','1210','8802','7302','7934','6404','3806','7104','6408','3811','3910',
'4006','6407','3801','4004','7985','8502','3812','9701','9702','9703','8215','5001','1501','9706','1504','1507','5002','0902','1414','1304','2406','1415','1402','2603','8701','4408','3807','6201','7107','8606','7938'
,'3404','0201','0101','0103','0102','1101','1302','0202','0401','0801','1301','1407','1102','1104','3803','0502','0604','0301','0304','0501','0302','0601','0602','0303','0603','0313','0503','0505','3701','7937',
'7970','6806','7968','6503','7004','6501','7303','7301','7101','6703','7003','6403','6803','7964','7967','6502','7106','6802','7973','7965','7006','6701','7103','7002','6702','7001','6402','6804','7971','6401',
'7005','8801','7105','6805','7007','6801','7988','4103','4104','4105','4102','4106','4101','7941','1401','1404','2205','2202','2204','2203','2207','2201','2208','2206','2307','3305','1201','3301','1205','1203','3307',
'3002','3306','1202','1206','3302','3308','3309','3001','7933','3003','1207','1204','3104','3102','7930','7912','3401','3403','3402','6101','6102','6103','3501','3502','3601','3503','7935','6601','6602','7966','3310')
then payable_price else 0 end) as no_attribution
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-09-01' and '2023-09-30'
group by
trunc(t.order_date,'MM')
,t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val
)


select
x.*
,t.val_day as nine_val_day
,case when t.val_day = '0' and x.val_day <> '0' then '100%' else x.val_day/t.val_day end as val_recovery
,t1.location_type
from(
select
record_week
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
SELECT record_week
      ,store_code
      ,store_city
      ,sale_days
           ,MAP('日商',payable_price,'槟榔', betel_nut, '冰淇淋', ice_cream,'饼干',cookie,'干果',dried_fruit,'果脯',preserved_fruit,'加工食品',processed_food,'咖啡豆浆自助饮品',coffee_soybean_milk_self_service_drink,
           '烈酒',spirits,'面包',bread,'其他',other,'巧克力',chocolate,'日配鲜食',daily_Fresh_Food,'日配制作类',daily_production_category,'肉脯',portly_or_obese_person,'生活杂货',daily_necessities,
           '嗜好品',asaddictive_things,'蔬果&生鲜',Vegetables_and_Fruits_Fresh,'水饮',retained_fluid,'糖果',candy,'香烟',cigarette,'休闲食品',snack_food,'纸生理用品',paper_physiological_products,'热饮料',hot_drinks
           ,'无归属',no_attribution) AS tmp_column
   FROM database_table) x
   LATERAL VIEW EXPLODE(tmp_column) exptbl as bool,val) x
   left join nine_month_large_market t on x.store_code = t.store_code and x.bool = t.bool
   left join data_build.dm_site_selection_project_feature_info_di t1 on x.store_code = t1.store_code and t1.dt = 20221114

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--歌华大厦库存情况
with sku_info as
(select
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name
from default.dim_sku_info
where dt = 20231218
group by
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name),

store_info as(
select
store_code
,store_name
,store_city
from default.dim_store_info
where dt = 20231218
group by
store_code
,store_name
,store_city)

--库存情况

select
from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date--日期
,a.hr--小时
,a.store_code--门店编码
,c.store_name--门店名称
,a.sku_code--商品编码
,b.sku_division_name--商品中分类名称
,b.sku_name--商品名称
,sum(a.quantity) as quantity--库存
--,row_number() over (partition by concat(a.dt,a.store_code,a.sku_code) order by a.quantity desc) as rn--序列
from default.dw_inventory_store_snapshot_ha_v1 a
left join sku_info b on a.sku_code = b.sku_code
left join store_info c on a.store_code = c.store_code
where from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') between '2023-12-19' and '2023-12-19'
and a.store_code in ('100078005','100000687')
and a.is_available = '1'
--and a.quantity <> '0'
and store_type = '0'
and substring(a.sku_code,1,1) <>'9'
and substring(a.sku_code,1,2) not in ('81','82','83','84','86','87','89')
and a.hr = '17'
and b.sku_code in ('01020500',
'02010525',
'02010540',
'02020079',
'05010013',
'05020004',
'05020005',
'08010132',
'08010142',
'11010198',
'11010482',
'11010514',
'11010523',
'11010526',
'11010527',
'12010003',
'12010004',
'12010008',
'12010096',
'12010104',
'12010105',
'12010138',
'12010165',
'12010167',
'12010174',
'12010189',
'12010195',
'12010210',
'12010219',
'12010238',
'12010246',
'12010250',
'12010251',
'12010255',
'12010260',
'12020005',
'12020011',
'12020012',
'12020013',
'12020023',
'12020045',
'12020194',
'12030006',
'12030017',
'12030026',
'12030030',
'12030053',
'12030071',
'12030077',
'12030078',
'12030090',
'12030091',
'12030092',
'12030093',
'12030097',
'12030155',
'12030433',
'12030434',
'12030475',
'12030476',
'12030477',
'12030508',
'12030604',
'12030781',
'12030783',
'12030816',
'12030963',
'12031119',
'12031151',
'12031152',
'12031242',
'12031290',
'12031308',
'12031309',
'12031312',
'12031313',
'12031323',
'12040303',
'12040315',
'12050003',
'12050004',
'12050005',
'12050006',
'12050115',
'12050240',
'12050253',
'12050264',
'12050269',
'12050272',
'12050319',
'12050381',
'12050404',
'12060012',
'12060015',
'12060036',
'12060063',
'12060089',
'12060091',
'12070084',
'12090026',
'12090033',
'13010427',
'13010533',
'13010613',
'13010614')--酸奶、鲜奶、果汁
--and b.sku_division_code in ('6101','6102','6103')--香烟
--and c.store_city = '北京市'
group by
from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd')
,a.hr--小时
,a.store_code--门店编码
,c.store_name--门店名称
,a.sku_code--商品编码
,b.sku_division_name--商品中分类名称
,b.sku_name--商品名称

-------------------------------------------------------------------------------------------------
--sku维度周销售数据
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,sku_code
,sku_name
,sum(sku_quantity) as sku_quantity--销售数量
,sum(payable_price)--销售金额
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-10-09' and '2023-12-07'
group by
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,sku_code
,sku_name

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--分时段热餐单量
select
t.order_date
,t.store_code
,t.store_name

--销售单量 按照时段拆分
,count(distinct case when substr(order_time,12,8) between '09:00:00' and '10:59:59' then order_no else null end) as order_num_1
,count(distinct case when substr(order_time,12,8) between '11:00:00' and '11:14:59' then order_no else null end) as order_num_2
,count(distinct case when substr(order_time,12,8) between '11:15:00' and '11:29:59' then order_no else null end) as order_num_3
,count(distinct case when substr(order_time,12,8) between '11:30:00' and '11:44:59' then order_no else null end) as order_num_4
,count(distinct case when substr(order_time,12,8) between '11:45:00' and '11:59:59' then order_no else null end) as order_num_5
,count(distinct case when substr(order_time,12,8) between '12:00:00' and '12:14:59' then order_no else null end) as order_num_6
,count(distinct case when substr(order_time,12,8) between '12:15:00' and '12:29:59' then order_no else null end) as order_num_7
,count(distinct case when substr(order_time,12,8) between '12:30:00' and '12:44:59' then order_no else null end) as order_num_8
,count(distinct case when substr(order_time,12,8) between '12:45:00' and '12:59:59' then order_no else null end) as order_num_9
,count(distinct case when substr(order_time,12,8) between '13:00:00' and '13:14:59' then order_no else null end) as order_num_10
,count(distinct case when substr(order_time,12,8) between '13:15:00' and '13:29:59' then order_no else null end) as order_num_11
,count(distinct case when substr(order_time,12,8) between '13:30:00' and '13:44:59' then order_no else null end) as order_num_12
,count(distinct case when substr(order_time,12,8) between '13:45:00' and '13:59:59' then order_no else null end) as order_num_13
,count(distinct case when substr(order_time,12,8) between '14:00:00' and '14:59:59' then order_no else null end) as order_num_14

from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and sku_division_name = '热餐'
and order_date between '2023-09-01' and '2024-01-25'
group by 
t.order_date
,t.store_code
,t.store_name

--开始制作时间分布
select
create_date
,store_code
,store_name

--制作数量 按照时段拆分
,sum(case when substr(make_time,12,8) between '09:00:00' and '10:59:59' then make_quantity else null end) as make_quantity_num_1
,sum(case when substr(make_time,12,8) between '11:00:00' and '11:14:59' then make_quantity else null end) as make_quantity_num_2
,sum(case when substr(make_time,12,8) between '11:15:00' and '11:29:59' then make_quantity else null end) as make_quantity_num_3
,sum(case when substr(make_time,12,8) between '11:30:00' and '11:44:59' then make_quantity else null end) as make_quantity_num_4
,sum(case when substr(make_time,12,8) between '11:45:00' and '11:59:59' then make_quantity else null end) as make_quantity_num_5
,sum(case when substr(make_time,12,8) between '12:00:00' and '12:14:59' then make_quantity else null end) as make_quantity_num_6
,sum(case when substr(make_time,12,8) between '12:15:00' and '12:29:59' then make_quantity else null end) as make_quantity_num_7
,sum(case when substr(make_time,12,8) between '12:30:00' and '12:44:59' then make_quantity else null end) as make_quantity_num_8
,sum(case when substr(make_time,12,8) between '12:45:00' and '12:59:59' then make_quantity else null end) as make_quantity_num_9
,sum(case when substr(make_time,12,8) between '13:00:00' and '13:14:59' then make_quantity else null end) as make_quantity_num_10
,sum(case when substr(make_time,12,8) between '13:15:00' and '13:29:59' then make_quantity else null end) as make_quantity_num_11
,sum(case when substr(make_time,12,8) between '13:30:00' and '13:44:59' then make_quantity else null end) as make_quantity_num_12
,sum(case when substr(make_time,12,8) between '13:45:00' and '13:59:59' then make_quantity else null end) as make_quantity_num_13
,sum(case when substr(make_time,12,8) between '14:00:00' and '14:59:59' then make_quantity else null end) as make_quantity_num_14

from data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and sku_division_name	= '热餐'
and store_code = '100078005'
and create_date between '2023-09-01' and '2024-01-25'
group by
create_date
,store_code
,store_name

--基础数据
select
t.order_date
,t.store_code
,t.store_name

--销售单量 按照时段拆分
,sum(payable_price) as payable_price
,count(distinct order_no) as order_num
,count(distinct case when sku_division_name = '热餐' and substr(order_time,12,8) between '09:00:00' and '14:59:59' then order_no else null end) as noon_hot_num
,sum(case when sku_division_name = '热餐' and substr(order_time,12,8) between '09:00:00' and '14:59:59' then sku_quantity else 0 end) as noon_hot_quantity
,sum(case when sku_division_name = '热餐' and substr(order_time,12,8) between '09:00:00' and '14:59:59' then payable_price else 0 end) as noon_hot_payable_price
,sum(case when sku_division_name = '热餐' and substr(order_time,12,8) between '09:00:00' and '14:59:59' then sell_price else 0 end) as noon_hot_sell_price

from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-25'
and sku_class_code not in ('86','50')
group by 
t.order_date
,t.store_code
,t.store_name

--制作量统计
select
create_date
,store_code
,store_name
,sku_code
,sku_name

,sum(make_quantity) as make_quantity

from data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and sku_division_name	= '热餐'
and store_code = '100078005'
and create_date between '2023-09-01' and '2024-01-25'
and substr(make_time,12,8) between '09:00:00' and '14:59:59'
group by
create_date
,store_code
,store_name
,sku_code
,sku_name

--实际销售
select
t.order_date
,t.store_code
,t.store_name
,t.sku_code
,t.sku_name

--销售单量 按照时段拆分
,sum(sku_quantity) as noon_hot_quantity

from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-25'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by 
t.order_date
,t.store_code
,t.store_name
,t.sku_code
,t.sku_name

--实际单价
select
t.order_date
,t.store_code
,t.store_name
,sku_code
,sku_name

--销售单量 按照时段拆分
,sum(payable_price)/sum(sku_quantity) as sku_payable_price

from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-25'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by 
t.order_date
,t.store_code
,t.store_name
,sku_code
,sku_name

--制作完成时间分布
select
create_date
,store_code
,store_name

--制作数量 按照时段拆分
,sum(case when substr(start_selling_time,12,8) between '09:00:00' and '10:59:59' then make_quantity else null end) as make_quantity_num_1
,sum(case when substr(start_selling_time,12,8) between '11:00:00' and '11:14:59' then make_quantity else null end) as make_quantity_num_2
,sum(case when substr(start_selling_time,12,8) between '11:15:00' and '11:29:59' then make_quantity else null end) as make_quantity_num_3
,sum(case when substr(start_selling_time,12,8) between '11:30:00' and '11:44:59' then make_quantity else null end) as make_quantity_num_4
,sum(case when substr(start_selling_time,12,8) between '11:45:00' and '11:59:59' then make_quantity else null end) as make_quantity_num_5
,sum(case when substr(start_selling_time,12,8) between '12:00:00' and '12:14:59' then make_quantity else null end) as make_quantity_num_6
,sum(case when substr(start_selling_time,12,8) between '12:15:00' and '12:29:59' then make_quantity else null end) as make_quantity_num_7
,sum(case when substr(start_selling_time,12,8) between '12:30:00' and '12:44:59' then make_quantity else null end) as make_quantity_num_8
,sum(case when substr(start_selling_time,12,8) between '12:45:00' and '12:59:59' then make_quantity else null end) as make_quantity_num_9
,sum(case when substr(start_selling_time,12,8) between '13:00:00' and '13:14:59' then make_quantity else null end) as make_quantity_num_10
,sum(case when substr(start_selling_time,12,8) between '13:15:00' and '13:29:59' then make_quantity else null end) as make_quantity_num_11
,sum(case when substr(start_selling_time,12,8) between '13:30:00' and '13:44:59' then make_quantity else null end) as make_quantity_num_12
,sum(case when substr(start_selling_time,12,8) between '13:45:00' and '13:59:59' then make_quantity else null end) as make_quantity_num_13
,sum(case when substr(start_selling_time,12,8) between '14:00:00' and '14:59:59' then make_quantity else null end) as make_quantity_num_14

from data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and sku_division_name	= '热餐'
and store_code = '100078005'
and create_date between '2023-09-01' and '2024-01-30'
group by
create_date
,store_code
,store_name

--平均售价&平均折扣率
select
trunc(t.order_date,'MM') as month
,t1.type --日期类型
,t.store_code
,t.store_name
,t.sku_code
,t.sku_name

,sum(payable_price) as payable_price
,sum(sell_price) as sell_price
,sum(sku_quantity) as sku_quantity
,sum(payable_price)/sum(sku_quantity) as avg_price
,sum(payable_price)/sum(sell_price) as avg_discount

from data_build.dw_order_sku_promotion_v1 t --订单明细表
left join data_build.ods_uploads_day_list t1 --珊瑚海表
on t.order_date = t1.record_day and t1.dt = 20240131
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-28'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by 
trunc(t.order_date,'MM')
,t1.type --日期类型
,t.store_code
,t.store_name
,t.sku_code
,t.sku_name

--分时段热餐sku量
select
t.order_date
,t.store_code
,t.store_name

--销售单量 按照时段拆分
,sum(case when substr(order_time,12,8) between '09:00:00' and '10:59:59' then sku_quantity else null end) as order_num_1
,sum(case when substr(order_time,12,8) between '11:00:00' and '11:14:59' then sku_quantity else null end) as order_num_2
,sum(case when substr(order_time,12,8) between '11:15:00' and '11:29:59' then sku_quantity else null end) as order_num_3
,sum(case when substr(order_time,12,8) between '11:30:00' and '11:44:59' then sku_quantity else null end) as order_num_4
,sum(case when substr(order_time,12,8) between '11:45:00' and '11:59:59' then sku_quantity else null end) as order_num_5
,sum(case when substr(order_time,12,8) between '12:00:00' and '12:14:59' then sku_quantity else null end) as order_num_6
,sum(case when substr(order_time,12,8) between '12:15:00' and '12:29:59' then sku_quantity else null end) as order_num_7
,sum(case when substr(order_time,12,8) between '12:30:00' and '12:44:59' then sku_quantity else null end) as order_num_8
,sum(case when substr(order_time,12,8) between '12:45:00' and '12:59:59' then sku_quantity else null end) as order_num_9
,sum(case when substr(order_time,12,8) between '13:00:00' and '13:14:59' then sku_quantity else null end) as order_num_10
,sum(case when substr(order_time,12,8) between '13:15:00' and '13:29:59' then sku_quantity else null end) as order_num_11
,sum(case when substr(order_time,12,8) between '13:30:00' and '13:44:59' then sku_quantity else null end) as order_num_12
,sum(case when substr(order_time,12,8) between '13:45:00' and '13:59:59' then sku_quantity else null end) as order_num_13
,sum(case when substr(order_time,12,8) between '14:00:00' and '14:59:59' then sku_quantity else null end) as order_num_14

from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and sku_division_name = '热餐'
and order_date between '2023-09-01' and '2024-01-31'
group by 
t.order_date
,t.store_code
,t.store_name
----------------------------------------------------------------------------------------------------------------------------------------------------------------
--人均购买金额
--促销信息
with promotion_list as(
select
order_date
,sum(payable_price) as toatal_payable_price 
,sum(sell_price) as toatal_sell_price
,sum(payable_price)/sum(sell_price)
,case when sum(payable_price)/sum(sell_price) < 0.86 then '促销' else '非促销' end as promotion_type
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-28'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by
order_date
),

avg_order_list as(
select
a.*
,count(order_no) over (partition by concat(user_id,promotion_type)) as order_num --总单量
,avg (payable_price) over (partition by concat(user_id,promotion_type)) as avg_payable_price --平均消费金额
,max(payable_price) over (partition by concat(user_id,promotion_type)) as max_payable_price --最大消费金额
,min(payable_price) over (partition by concat(user_id,promotion_type)) as min_payable_price --最小消费金额
,sum(payable_price) over (partition by concat(user_id,promotion_type)) as total_price --总消费金额
from(
select
t.user_id --用户编号
,t.order_no --订单编号
,t.order_date --订单日期
,t1.promotion_type --是否促销
,sum(t.payable_price) as payable_price --订单金额
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join promotion_list t1 on t.order_date = t1.order_date
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
t.user_id
,t.order_no
,t.order_date
,t1.promotion_type
) a
),

--用户周均购买次数
user_week_num as(
select
user_id
,count(distinct record_week) as week_num --购买周数
,avg(order_no_num) as order_no_num --平均每周购买次数
from ( 
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,user_id
,count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,user_id
) a
group by
user_id
),

--用户购买情况统计
user_consumption_list as(
select
user_id
,promotion_type
,order_num --总单量
,avg_payable_price --平均消费金额
,max_payable_price --最大消费金额
,min_payable_price --最小消费金额
,total_price --总消费金额
from avg_order_list
group by
user_id
,promotion_type
,order_num --总单量
,avg_payable_price --平均消费金额
,max_payable_price --最大消费金额
,min_payable_price --最小消费金额
,total_price --总消费金额
)

select
a.user_id --用户编码
,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_payable_price --平均消费金额
,c.max_payable_price --最大消费金额
,c.min_payable_price --最小消费金额
,c.total_price --总消费金额
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数
,percentile_approx(payable_price,0.5) as percentile --中位数
,stddev(payable_price) as variance --标准差
from avg_order_list a
left join user_week_num b on a.user_id = b.user_id
left join user_consumption_list c on a.user_id = c.user_id
and a.promotion_type = c.promotion_type
group by
a.user_id --用户编码
,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_payable_price --平均消费金额
,c.max_payable_price --最大消费金额
,c.min_payable_price --最小消费金额
,c.total_price --总消费金额
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--人均购买菜品数量
--促销信息
with promotion_list as(
select
order_date
,sum(payable_price) as toatal_payable_price 
,sum(sell_price) as toatal_sell_price
,sum(payable_price)/sum(sell_price)
,case when sum(payable_price)/sum(sell_price) < 0.86 then '促销' else '非促销' end as promotion_type
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-28'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by
order_date
),

avg_order_list as(
select
a.*
,count(order_no) over (partition by user_id) as order_num --总单量
,avg (sku_quantity) over (partition by user_id) as avg_sku_quantity --平均菜品数量
,max(sku_quantity) over (partition by user_id) as max_sku_quantity --最大菜品数量
,min(sku_quantity) over (partition by user_id) as min_sku_quantity --最小菜品数量
,sum(sku_quantity) over (partition by user_id) as total_sku_quantity --总菜品数量
from(
select
t.user_id --用户编号
,t.order_no --订单编号
,t.order_date --订单日期
--,t1.promotion_type --是否促销
,sum(t.sku_quantity) as sku_quantity --菜品数量
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
--left join promotion_list t1 on t.order_date = t1.order_date
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
t.user_id
,t.order_no
,t.order_date
--,t1.promotion_type
) a
),

--用户周均购买次数
user_week_num as(
select
user_id
,count(distinct record_week) as week_num --购买周数
,avg(order_no_num) as order_no_num --平均每周购买次数
from ( 
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,user_id
,count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,user_id
) a
group by
user_id
),

--用户购买情况统计
user_consumption_list as(
select
user_id
--,promotion_type
,order_num --总单量
,avg_sku_quantity --平均菜品数量
,max_sku_quantity --最大菜品数量
,min_sku_quantity --最小菜品数量
,total_sku_quantity --总菜品数量
from avg_order_list
group by
user_id
--,promotion_type
,order_num --总单量
,avg_sku_quantity --平均菜品数量
,max_sku_quantity --最大菜品数量
,min_sku_quantity --最小菜品数量
,total_sku_quantity --总菜品数量
)

select
a.user_id --用户编码
--,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_sku_quantity --平均菜品数量
,c.max_sku_quantity --最大菜品数量
,c.min_sku_quantity --最小菜品数量
,c.total_sku_quantity --总菜品数量
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数
,percentile_approx(sku_quantity,0.5) as percentile --中位数
,stddev(sku_quantity) as variance --标准差
from avg_order_list a
left join user_week_num b on a.user_id = b.user_id
left join user_consumption_list c on a.user_id = c.user_id
--and a.promotion_type = c.promotion_type
group by
a.user_id --用户编码
--,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_sku_quantity --平均菜品数量
,c.max_sku_quantity --最大菜品数量
,c.min_sku_quantity --最小菜品数量
,c.total_sku_quantity --总菜品数量
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--人均荤素比例
--促销信息
with promotion_list as(
select
order_date
,sum(payable_price) as toatal_payable_price 
,sum(sell_price) as toatal_sell_price
,sum(payable_price)/sum(sell_price)
,case when sum(payable_price)/sum(sell_price) < 0.86 then '促销' else '非促销' end as promotion_type
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-28'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by
order_date
),

avg_order_list as(
select
a.*
,count(order_no) over (partition by concat(user_id,promotion_type)) as order_num --总单量
,avg (vegetable_sku_quantity) over (partition by concat(user_id,promotion_type)) as avg_vegetable_sku_quantity --平均素菜数量
,max(vegetable_sku_quantity) over (partition by concat(user_id,promotion_type)) as max_vegetable_sku_quantity --最大素菜数量
,min(vegetable_sku_quantity) over (partition by concat(user_id,promotion_type)) as min_vegetable_sku_quantity --最小素菜数量
,avg (meat_sku_quantity) over (partition by concat(user_id,promotion_type)) as avg_meat_sku_quantity --平均荤菜数量
,max(meat_sku_quantity) over (partition by concat(user_id,promotion_type)) as max_meat_sku_quantity --最大荤菜数量
,min(meat_sku_quantity) over (partition by concat(user_id,promotion_type)) as min_meat_sku_quantity --最小荤菜数量
,avg(meat_rat) over (partition by concat(user_id,promotion_type)) as avg_meat_rat --平均荤菜比
,max(meat_rat) over (partition by concat(user_id,promotion_type)) as max_meat_rat --最大荤菜比
,min(meat_rat) over (partition by concat(user_id,promotion_type)) as min_meat_rat --最小荤菜比
from(
select
t.user_id --用户编号
,t.order_no --订单编号
,t.order_date --订单日期
,t1.promotion_type --是否促销
,sum(case when meat_and_vegetable in ('纯素菜') then t.sku_quantity else 0 end) as vegetable_sku_quantity --素菜数量
,sum(case when meat_and_vegetable in ('荤菜') then t.sku_quantity else 0 end) as meat_sku_quantity --荤菜菜数量
,sum(case when meat_and_vegetable in ('荤菜') then t.sku_quantity else 0 end)/sum(t.sku_quantity) as meat_rat --荤菜占比
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join promotion_list t1 on t.order_date = t1.order_date
left join data_build.ods_uploads_meat_and_vegetable t2 on t.sku_name = t2.sku_name and t2.dt = 20240202
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
t.user_id
,t.order_no
,t.order_date
,t1.promotion_type
) a
),

--用户周均购买次数
user_week_num as(
select
user_id
,count(distinct record_week) as week_num --购买周数
,avg(order_no_num) as order_no_num --平均每周购买次数
from ( 
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,user_id
,count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,user_id
) a
group by
user_id
),

--用户购买情况统计
user_consumption_list as(
select
user_id
,promotion_type
,order_num --总单量
,avg_vegetable_sku_quantity --平均素菜数量
,max_vegetable_sku_quantity --最大素菜数量
,min_vegetable_sku_quantity --最小素菜数量
,avg_meat_sku_quantity --平均荤菜数量
,max_meat_sku_quantity --最大荤菜数量
,min_meat_sku_quantity --最小荤菜数量
,avg_meat_rat --平均荤菜比
,max_meat_rat --最大荤菜比
,min_meat_rat --最小荤菜比
from avg_order_list
group by
user_id
,promotion_type
,order_num --总单量
,avg_vegetable_sku_quantity --平均素菜数量
,max_vegetable_sku_quantity --最大素菜数量
,min_vegetable_sku_quantity --最小素菜数量
,avg_meat_sku_quantity --平均荤菜数量
,max_meat_sku_quantity --最大荤菜数量
,min_meat_sku_quantity --最小荤菜数量
,avg_meat_rat --平均荤菜比
,max_meat_rat --最大荤菜比
,min_meat_rat --最小荤菜比
)

select
a.user_id --用户编码
,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_vegetable_sku_quantity --平均素菜数量
,c.max_vegetable_sku_quantity --最大素菜数量
,c.min_vegetable_sku_quantity --最小素菜数量
,c.avg_meat_sku_quantity --平均荤菜数量
,c.max_meat_sku_quantity --最大荤菜数量
,c.min_meat_sku_quantity --最小荤菜数量
,c.avg_meat_rat --平均荤菜比
,c.max_meat_rat --最大荤菜比
,c.min_meat_rat --最小荤菜比
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数
,percentile_approx(meat_rat,0.5) as percentile --中位数
,stddev(meat_rat) as variance --标准差
from avg_order_list a
left join user_week_num b on a.user_id = b.user_id
left join user_consumption_list c on a.user_id = c.user_id
and a.promotion_type = c.promotion_type
group by
a.user_id --用户编码
,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_vegetable_sku_quantity --平均素菜数量
,c.max_vegetable_sku_quantity --最大素菜数量
,c.min_vegetable_sku_quantity --最小素菜数量
,c.avg_meat_sku_quantity --平均荤菜数量
,c.max_meat_sku_quantity --最大荤菜数量
,c.min_meat_sku_quantity --最小荤菜数量
,c.avg_meat_rat --平均荤菜比
,c.max_meat_rat --最大荤菜比
,c.min_meat_rat --最小荤菜比
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--人均购买时间
--促销信息
with promotion_list as(
select
order_date
,sum(payable_price) as toatal_payable_price 
,sum(sell_price) as toatal_sell_price
,sum(payable_price)/sum(sell_price)
,case when sum(payable_price)/sum(sell_price) < 0.86 then '促销' else '非促销' end as promotion_type
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-28'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by
order_date
),

avg_order_list as(
select
a.*
,count(order_no) over (partition by user_id) as order_num --总单量
,avg (order_time) over (partition by user_id) as avg_order_time --平均购买时间
,max(order_time) over (partition by user_id) as max_order_time --最大购买时间
,min(order_time) over (partition by user_id) as min_order_time --最小购买时间
--,sum(order_time) over (partition by user_id) as total_sku_quantity --总菜品数量
from(
select
t.user_id --用户编号
,t.order_no --订单编号
,t.order_date --订单日期
,hour(substr(t.order_time,12,8))*3600 + minute(substr(t.order_time,12,8))*60 + second(substr(t.order_time,12,8)) as order_time
--,t1.promotion_type --是否促销
--,sum(t.sku_quantity) as sku_quantity --菜品数量
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
--left join promotion_list t1 on t.order_date = t1.order_date
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
t.user_id
,t.order_no
,t.order_date
,substr(t.order_time,12,8)
--,t1.promotion_type
) a
),

--用户周均购买次数
user_week_num as(
select
user_id
,count(distinct record_week) as week_num --购买周数
,avg(order_no_num) as order_no_num --平均每周购买次数
from ( 
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,user_id
,count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,user_id
) a
group by
user_id
),

--用户购买情况统计
user_consumption_list as(
select
user_id
--,promotion_type
,order_num --总单量
,avg_order_time --平均购买时间
,max_order_time --最大购买时间
,min_order_time --最小购买时间
--,total_sku_quantity --总菜品数量
from avg_order_list
group by
user_id
--,promotion_type
,order_num --总单量
,avg_order_time --平均购买时间
,max_order_time --最大购买时间
,min_order_time --最小购买时间
--,total_sku_quantity --总菜品数量
)

select
a.user_id --用户编码
--,a.promotion_type --是否促销
,c.order_num --总单量
,concat_ws(':',
if(length(cast(floor(c.avg_order_time/3600) as string)) = 1,concat('0',cast(floor(c.avg_order_time/3600) as string)),cast(floor(c.avg_order_time/3600) as string))
,if(length(cast(floor(c.avg_order_time%3600/60) as string)) = 1,concat('0',cast(floor(c.avg_order_time%3600/60) as string)),cast(floor(c.avg_order_time%3600/60) as string)) 
,if(length(cast(c.avg_order_time%3600%60 as string)) = 1,concat('0',cast(c.avg_order_time%3600%60 as string)),cast(c.avg_order_time%3600%60 as string))) as avg_order_time --平均购买时间
,concat_ws(':',
if(length(cast(floor(c.max_order_time/3600) as string)) = 1,concat('0',cast(floor(c.max_order_time/3600) as string)),cast(floor(c.max_order_time/3600) as string))
,if(length(cast(floor(c.max_order_time%3600/60) as string)) = 1,concat('0',cast(floor(c.max_order_time%3600/60) as string)),cast(floor(c.max_order_time%3600/60) as string)) 
,if(length(cast(c.max_order_time%3600%60 as string)) = 1,concat('0',cast(c.max_order_time%3600%60 as string)),cast(c.max_order_time%3600%60 as string))) as max_order_time --最大购买时间
,concat_ws(':',
if(length(cast(floor(c.min_order_time/3600) as string)) = 1,concat('0',cast(floor(c.min_order_time/3600) as string)),cast(floor(c.min_order_time/3600) as string))
,if(length(cast(floor(c.min_order_time%3600/60) as string)) = 1,concat('0',cast(floor(c.min_order_time%3600/60) as string)),cast(floor(c.min_order_time%3600/60) as string)) 
,if(length(cast(c.min_order_time%3600%60 as string)) = 1,concat('0',cast(c.min_order_time%3600%60 as string)),cast(c.min_order_time%3600%60 as string))) as min_order_time --最小购买时间
--,c.total_sku_quantity --总菜品数量
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数
,concat_ws(':',
if(length(cast(floor(percentile_approx(order_time,0.5)/3600) as string)) = 1,concat('0',cast(floor(percentile_approx(order_time,0.5)/3600) as string)),cast(floor(percentile_approx(order_time,0.5)/3600) as string))
,if(length(cast(floor(percentile_approx(order_time,0.5)%3600/60) as string)) = 1,concat('0',cast(floor(percentile_approx(order_time,0.5)%3600/60) as string)),cast(floor(percentile_approx(order_time,0.5)%3600/60) as string)) 
,if(length(cast(percentile_approx(order_time,0.5)%3600%60 as string)) = 1,concat('0',cast(percentile_approx(order_time,0.5)%3600%60 as string)),cast(percentile_approx(order_time,0.5)%3600%60 as string))) as percentile --中位数
,stddev(order_time)/60 as variance --标准差(minute)
from avg_order_list a
left join user_week_num b on a.user_id = b.user_id
left join user_consumption_list c on a.user_id = c.user_id
--and a.promotion_type = c.promotion_type
group by
a.user_id --用户编码
--,a.promotion_type --是否促销
,c.order_num --总单量
,concat_ws(':',
if(length(cast(floor(c.avg_order_time/3600) as string)) = 1,concat('0',cast(floor(c.avg_order_time/3600) as string)),cast(floor(c.avg_order_time/3600) as string))
,if(length(cast(floor(c.avg_order_time%3600/60) as string)) = 1,concat('0',cast(floor(c.avg_order_time%3600/60) as string)),cast(floor(c.avg_order_time%3600/60) as string)) 
,if(length(cast(c.avg_order_time%3600%60 as string)) = 1,concat('0',cast(c.avg_order_time%3600%60 as string)),cast(c.avg_order_time%3600%60 as string)))
,concat_ws(':',
if(length(cast(floor(c.max_order_time/3600) as string)) = 1,concat('0',cast(floor(c.max_order_time/3600) as string)),cast(floor(c.max_order_time/3600) as string))
,if(length(cast(floor(c.max_order_time%3600/60) as string)) = 1,concat('0',cast(floor(c.max_order_time%3600/60) as string)),cast(floor(c.max_order_time%3600/60) as string)) 
,if(length(cast(c.max_order_time%3600%60 as string)) = 1,concat('0',cast(c.max_order_time%3600%60 as string)),cast(c.max_order_time%3600%60 as string)))
,concat_ws(':',
if(length(cast(floor(c.min_order_time/3600) as string)) = 1,concat('0',cast(floor(c.min_order_time/3600) as string)),cast(floor(c.min_order_time/3600) as string))
,if(length(cast(floor(c.min_order_time%3600/60) as string)) = 1,concat('0',cast(floor(c.min_order_time%3600/60) as string)),cast(floor(c.min_order_time%3600/60) as string)) 
,if(length(cast(c.min_order_time%3600%60 as string)) = 1,concat('0',cast(c.min_order_time%3600%60 as string)),cast(c.min_order_time%3600%60 as string)))
--,c.total_sku_quantity --总菜品数量
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数

-------------------------------------------------------------------------------------------------------------------------------------------------------------
with user_id_list as
(--过去三个月任一14天内购买大于等于2次
SELECT
user_id
from(
SELECT
user_id
,order_date
,rank1
,time2
,datediff(order_date,time2) as diffdate
from(
SELECT
user_id
,order_date
,ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY order_date) AS rank1
,lag(order_date,1) OVER(PARTITION BY user_id ORDER BY order_date) AS time2
from(
SELECT
user_id
,order_date
from data_promotion.dm_promotion_store_detl_order_detail_info_da t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-11-01' and '2024-01-31'
and user_id is not null --非现金用户
GROUP BY
user_id
,order_date
ORDER BY user_id,order_date
LIMIT 50000) a
) b
) c
where diffdate <= 14
GROUP BY
user_id)

select
t.store_code
,t.store_name
,sku_class_code
,sku_class_name
,sku_division_code	
,sku_division_name
,sku_section_code
,sku_section_name
,sku_code
,sku_name
,sum(sku_quantity) as sku_quantity
,sum(case when t1.user_id is not null then sku_quantity else 0 end) as sku_quantity_core
from data_promotion.dm_promotion_store_detl_order_detail_info_da t --订单明细表
left join user_id_list t1 on t.user_id = t1.user_id
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-11-01' and '2024-01-31'
and t.user_id is not null --非现金用户
group by 
t.store_code
,t.store_name
,sku_class_code
,sku_class_name
,sku_division_code	
,sku_division_name
,sku_section_code
,sku_section_name
,sku_code
,sku_name

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
with user_id_list as
(--过去三个月任一14天内购买大于等于2次
SELECT
user_id
from(
SELECT
user_id
,order_date
,rank1
,time2
,datediff(order_date,time2) as diffdate
from(
SELECT
user_id
,order_date
,ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY order_date) AS rank1
,lag(order_date,1) OVER(PARTITION BY user_id ORDER BY order_date) AS time2
from(
SELECT
user_id
,order_date
from data_promotion.dm_promotion_store_detl_order_detail_info_da t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-11-01' and '2024-01-31'
and user_id is not null --非现金用户
GROUP BY
user_id
,order_date
ORDER BY user_id,order_date
LIMIT 50000) a
) b
) c
where diffdate <= 14
GROUP BY
user_id)

select
t.user_id
,case when t1.user_id is not null then '核心用户' else '非核心用户' end as user_type
,sku_class_name
,count(distinct sku_code) as sku_kind
,sum(sku_quantity) as sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da t --订单明细表
left join user_id_list t1 on t.user_id = t1.user_id
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-11-01' and '2024-01-31'
and t.user_id is not null --非现金用户
group by 
t.user_id
,case when t1.user_id is not null then '核心用户' else '非核心用户' end
,sku_class_name

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--北京办公店9-1月中午售卖热餐sku
select
t.sku_name
,min(order_date) as min_order_date
,max(order_date) as max_order_date
,count(distinct t.store_code) as store_num
,count(distinct concat(t.store_code,t.order_date)) as store_sell_num
,sum(sku_quantity) as sku_quantity
,sum(sell_price) as sell_price
,sum(payable_price) as payable_price
from data_build.dw_order_sku_promotion_v1 t --订单明细表
left join data_build.dm_site_selection_project_feature_info_di t1 on t.store_code = t1.store_code and t1.dt = 20221114
left join data_build.dim_date_ya_v2 t2 on t.order_date = t2.date_key
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and order_date between '2023-09-01' and '2024-01-31'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
and t1.location_type in ('办公','办公+其他')
and t.store_city = '北京市'
and t2.is_working_day	 = '1'
--and sku_name = '虎皮蛋琵琶腿'
and t.store_code = '100078005'
group by
t.sku_name


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--人均购买菜品数量
--促销信息
with promotion_list as(
select
order_date
,sum(payable_price) as toatal_payable_price 
,sum(sell_price) as toatal_sell_price
,sum(payable_price)/sum(sell_price)
,case when sum(payable_price)/sum(sell_price) < 0.86 then '促销' else '非促销' end as promotion_type
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and order_date between '2023-09-01' and '2024-01-28'
and sku_class_code not in ('86','50')
and sku_division_name = '热餐'
and substr(order_time,12,8) between '09:00:00' and '14:59:59'
group by
order_date
),

avg_order_list as(
select
a.*
,count(order_no) over (partition by user_id) as order_num --总单量
,avg (sku_quantity) over (partition by user_id) as avg_sku_quantity --平均菜品数量
,max(sku_quantity) over (partition by user_id) as max_sku_quantity --最大菜品数量
,min(sku_quantity) over (partition by user_id) as min_sku_quantity --最小菜品数量
,sum(sku_quantity) over (partition by user_id) as total_sku_quantity --总菜品数量
from(
select
t.user_id --用户编号
,t.order_no --订单编号
,t.order_date --订单日期
--,t1.promotion_type --是否促销
,sum(t.sku_quantity) as sku_quantity --菜品数量
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
--left join promotion_list t1 on t.order_date = t1.order_date
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
t.user_id
,t.order_no
,t.order_date
--,t1.promotion_type
) a
),

--用户周均购买次数
user_week_num as(
select
user_id
,count(distinct record_week) as week_num --购买周数
,avg(order_no_num) as order_no_num --平均每周购买次数
from ( 
select
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end) as record_week
,user_id
,count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240131
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.order_date between '2023-09-01' and '2024-01-28'
and t.store_code in ('100078005')
and t.sku_division_name = '热餐'
and substr(t.order_time,12,8) between '09:00:00' and '14:59:59'
and t.user_id is not null
group by
date_add(order_date,7 - case when dayofweek(order_date) = 1 then 7 else dayofweek(order_date) - 1 end)
,user_id
) a
group by
user_id
),

--用户购买情况统计
user_consumption_list as(
select
user_id
--,promotion_type
,order_num --总单量
,avg_sku_quantity --平均菜品数量
,max_sku_quantity --最大菜品数量
,min_sku_quantity --最小菜品数量
,total_sku_quantity --总菜品数量
from avg_order_list
group by
user_id
--,promotion_type
,order_num --总单量
,avg_sku_quantity --平均菜品数量
,max_sku_quantity --最大菜品数量
,min_sku_quantity --最小菜品数量
,total_sku_quantity --总菜品数量
)

select
a.user_id --用户编码
--,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_sku_quantity --平均菜品数量
,c.max_sku_quantity --最大菜品数量
,c.min_sku_quantity --最小菜品数量
,c.total_sku_quantity --总菜品数量
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数
,percentile_approx(sku_quantity,0.5) as percentile --中位数
,stddev(sku_quantity) as variance --标准差
from avg_order_list a
left join user_week_num b on a.user_id = b.user_id
left join user_consumption_list c on a.user_id = c.user_id
--and a.promotion_type = c.promotion_type
group by
a.user_id --用户编码
--,a.promotion_type --是否促销
,c.order_num --总单量
,c.avg_sku_quantity --平均菜品数量
,c.max_sku_quantity --最大菜品数量
,c.min_sku_quantity --最小菜品数量
,c.total_sku_quantity --总菜品数量
,b.week_num --购买周数
,b.order_no_num --平均每周购买次数

#################################################################################################################################################################################################################################################
#################################################################################################################################################################################################################################################
#################################################################################################################################################################################################################################################

--门店月维度日商
select
trunc(t.order_date,'MM') as record_month
,t.store_code
,count(distinct order_date) as order_date_num 
,count(distinct t.order_no)/count(distinct order_date) as quanyue_order_cnt --订单量
,sum(case when sku_division_code in ('6101','6102') then payable_price else 0 end)/count(distinct order_date) as payable_price_cigarette --香烟
,sum(case when sku_class_code in ('01','02','03','04','05','06','07','08','09','10','11','13','14','15','20','21','22','23','24','25','26') or sku_division_code in ('1209','1210') 
then payable_price else 0 end)/count(distinct order_date) as payable_price_daily --日配
,sum(t.payable_price)/count(distinct order_date) as quanyue_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
where t.dt = '20240825'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
group by
trunc(t.order_date,'MM')
,t.store_code


--含香烟的订单
with cigarette_order_no as(
select distinct
order_no
,t.order_date
,t.store_code
from data_build.dw_order_sku_v1 t
where t.dt = '20260506'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and sku_division_code in ('6101','6102')
)

select
trunc(t.order_date,'MM') as record_month
,t.store_code
,sum(case when t1.order_no is not null then payable_price else 0 end)/count(distinct t1.order_no) as payable_price_cigarette --含香烟订单客单价
,sum(case when t1.order_no is null then payable_price else 0 end)/count(distinct case when t1.order_no is not null then null else t.order_no end) as payable_price_np_cigarette --不含香烟订单客单价
from data_build.dw_order_sku_v1 t
left join cigarette_order_no t1 on t.store_code = t1.store_code and t.order_date = t1.order_date and t.order_no = t1.order_no
where t.dt = '20260506'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
group by
trunc(t.order_date,'MM')
,t.store_code











--香烟
sku_division_code in ('6101','6102')
--日配
sku_class_code in ('01','02','03','04','05','06','07','08','09','10','11','13','14','15','20','21','22','23','24','25','26')--FF&风幕日配 
or sku_division_code in ('1209','1210')
