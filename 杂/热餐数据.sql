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
 target_date
 ,b.store_cvs_code
 ,b.display_name,
 sum(sale_gross_price - zonghe_correction_waste_price) / count(distinct(a.store_code)) as `废弃后毛利（系统）`,
 sum(sale_gross_out_waste_price) / count(distinct(a.store_code)) as `废弃后毛利（录入）`,
 sum(sale_payable_price) / count(distinct(a.store_code)) as `折后销售金额`,
 sum(sale_origin_payable_price) / count(distinct(a.store_code)) as `折前销售金额`,
 sum(sale_qty) / count(distinct(a.store_code)) as `销量`,
 sum(store_div_order_cntd) / count(distinct(a.store_code)) as `订单量`,
 sum(zonghe_correction_waste_price) / count(distinct(a.store_code)) as `财务废弃金额`,
 sum(zonghe_correction_waste_qty) / count(distinct(a.store_code)) as `财务废弃数量`,
 sum(waste_cost_add_tax) / count(distinct(a.store_code)) as `录入废弃金额`, 
 sum(waste_qty) / count(distinct(a.store_code)) as `录入废弃数量`,
 sum(oploss_qty) / count(distinct(a.store_code)) as `机损数量`,
 sum(forecast_qty_t_2) / count(distinct(a.store_code)) as `销量预测`,
 sum(sale_plan_sum_qty_2) / count(distinct(a.store_code)) as `销售计划量`,
 sum(product_target_count) / count(distinct(a.store_code)) as `生产计划目标量`,
 sum(instruction_target_count) / count(distinct(a.store_code)) as `工序目标量`,
 sum(make_qty) / count(distinct(a.store_code)) as `制作量`,
 sum(final_book_qty) / count(distinct(a.store_code)) as `订货量`,
 sum(arrive_book_qty) / count(distinct(a.store_code)) as `到货量`,
 sum(sale_out_rate_fenzi) / sum(sale_out_rate_fenmu) as `售罄率`,
 count(distinct(a.store_code)) as `门店数`
 from 
 data_smartorder.app_production_os_ff_store_div_section_di a
 left join desensitization b on a.store_code = b.store_code
 where
 dt >= '20171001'
 and sku_division_code = '0301'
 and store_order_cntd >= 20
 and store_type = 0
 and b.store_cvs_code in ('100001565')
 --and target_date = '2022-10-18'
 group by
 target_date
 ,b.store_cvs_code
 ,b.display_name

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = '20221225'
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

 waste_price as(
    select
target_date
,store_code
,sale_qty
,make_qty
,waste_qty
from data_smartorder.dm_production_os_store_div_section_sum_di
where dt > '20010101'
and sku_division_code in ('0301')
and meal_section_name in ('午餐')
)

SELECT
a.target_date
,b.store_cvs_code
,b.display_name
,is_working_day
,c.sale_qty
,c.make_qty
,c.waste_qty
,sum(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end) as fenzi_10
,count(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end) as fenmu_10
,sum(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end) as fenzi_1240
,count(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end) as fenmu_1240
,sum(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end)*1.0000/count(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end) as time_1000_1230
,sum(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end)*1.0000/count(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end) as time_1240_1400
from data_smartorder.dm_ordering_report_ff_sold_out_cuspeak_di a
left join desensitization b on a.store_code = b.store_code
left join waste_price c on a.store_code = c.store_code and a.target_date = c.target_date
WHERE dt >= '20210510'
and sku_division_code in ('0301')
and hr_mi BETWEEN '10:00' and '14:00'
group by
a.target_date
,b.store_cvs_code
,b.display_name
,is_working_day
,c.sale_qty
,c.make_qty
,c.waste_qty

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = '20221225'
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

 --工作日列表
work_day_list as(
select
target_date
from data_smartorder.dm_ordering_report_ff_sold_out_cuspeak_di
where dt between '20210915' and '20221216'
and is_working_day = 1
group by
target_date
 ),

--单店工作日平均sum(售罄)/sum(制作)
waste_price as(
select
store_code
,sum(sale_qty) as sale_qty
,sum(make_qty) as make_qty
,sum(waste_qty) as waste_qty
,sum(waste_qty)*1.0000/sum(make_qty) as waste_qty_rat
from data_smartorder.dm_production_os_store_div_section_sum_di a
join work_day_list b on a.target_date = b.target_date
where dt between '20210915' and '20221216'
and sku_division_code in ('0301')
and meal_section_name in ('午餐')
group by store_code
),

--每日sum(售罄)/sum(制作)明细
waste_price_days as(
select
a.target_date
,a.store_code
,sum(case when a.hr_mi between '11:00' and '12:30' then a.final_saleout_flag end) as fenzi_11
,sum(b.sale_qty) as sale_qty_days
,sum(b.make_qty) as make_qty_days
,sum(b.waste_qty) as waste_qty_days
,sum(b.waste_qty)*1.0000/sum(make_qty) as waste_qty_rat_days
from data_smartorder.dm_ordering_report_ff_sold_out_cuspeak_di a
left join data_smartorder.dm_production_os_store_div_section_sum_di b on a.store_code = b.store_code and a.target_date = b.target_date and b.dt between '20210915' and '20221216'
where a.dt between '20210915' and '20221216'
and a.sku_division_code in ('0301')
and a.is_working_day = 1
and b.sku_division_code in ('0301')
and b.meal_section_name in ('午餐')
group by
a.target_date
,a.store_code
)

--废弃多早售罄发生率
select
date_add(a.target_date,7 - case when dayofweek(a.target_date) = 1 then 7 else dayofweek(a.target_date) - 1 end) as order_week
,b.store_cvs_code
,b.display_name
,count(case when a.waste_qty_rat_days > c.waste_qty_rat and a.fenzi_11 > 0 then a.target_date end) as fenzi_bad
,count(a.target_date) as fenmu_days
from waste_price_days a
left join desensitization b on a.store_code = b.store_code
left join waste_price c on a.store_code = c.store_code
group by
date_add(a.target_date,7 - case when dayofweek(a.target_date) = 1 then 7 else dayofweek(a.target_date) - 1 end)
,b.store_cvs_code
,b.display_name

------------------------------------------------------------------------------------------------------------------------------
--当天最早出现售罄的时间
select
*
,row_number() over (partition by concat(target_date,store_code) order by hr_mi) as rn
from data_smartorder.dm_ordering_report_ff_sold_out_cuspeak_di
where dt >= 20210510
and is_working_day = '1'
and sku_division_code = '0301'
and hr_mi between '11:00' and '14:00'
and final_saleout_flag = '1'




select
* from data_smartorder.dm_production_os_store_div_section_sum_di
where dt >= 20210510
and store_code = 'c7955f102dc8d62589f80aefa35c9831'
and sku_division_code = '0301'

-----------------------------------------------------------------------------------------------------------------------------
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20230101'
group by
store_code,
store_name,
store_cvs_code,
display_name),

--工作日列表
work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--热餐当日中午（11:00-14:00）销售额
slae_hotmeal_day as(
select
order_date
,store_code
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301') then payable_price else 0 end) as payable_price_hot_meal
from default.dw_order_sku_promotion_v1
where dt = 20230101
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and substr(order_time,12,8) between '11:00:00' and '14:00:00'
group by
order_date
,store_code
)

select
create_date
,b.store_cvs_code
,b.display_name
,payable_price_hot_meal
,is_working_day
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then waste_quantity end) as waste_quantity
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity end) as make_quantity_1100
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then make_quantity end) as make_quantity_0900
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity end)*1.0000/sum(case when make_time between '09:00:00' and '14:00:00' then make_quantity end) as rat_1100
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join slae_hotmeal_day c on a.store_code = c.store_code and a.create_date = c.order_date
left join work_day_list d on a.create_date = d.date_key
where dt = '20230101'
and sku_division_code in ('0301')
and b.store_cvs_code in ('110000158','110000183','123000098','123000166','123000190','123000381')
group by
create_date
,b.store_cvs_code
,b.display_name
,payable_price_hot_meal
,is_working_day

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--热餐客单价&订单量
with date_list as(
select
date_key,
is_working_day,
case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
from default.dim_date_ya_v2
),

desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20230507'
group by
store_code,
store_name,
store_cvs_code,
display_name)

select
order_date
,c.store_cvs_code
,b.date_type
,b.is_working_day
,store_city
,count(distinct order_no) as order_num
,sum(payable_price) as hot_meal_payable_price
,sum(payable_price)/count(distinct order_no)--客单价
from default.dw_order_sku_promotion_v1 t
left join date_list b on t.order_date = b.date_key
left join desensitization c on t.store_code = c.store_code
where t.dt = 20230507
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and order_date between '2022-02-10' and '2023-02-09'
and sku_division_code in ('0301','0304')
--and c.store_cvs_code in ('100010002')
group by
order_date
,c.store_cvs_code
,b.date_type
,b.is_working_day
,store_city

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20221231'
group by
store_code,
store_name,
store_cvs_code,
display_name),

--工作日列表
work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--热餐周中当日中午（11:00-14:00）销售额
slae_hotmeal_day as(
select
order_date
,store_cvs_code
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301') then payable_price else 0 end) as payable_price_hot_meal
from default.dw_order_sku_promotion_v1 a
left join desensitization b on a.store_code = b.store_code
left join work_day_list c on a.order_date = c.date_key
where dt = 20221231
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and substr(order_time,12,8) between '11:00:00' and '14:00:00'
and c.is_working_day = '1'
group by
order_date
,store_cvs_code
),

--单店工作日当日制作,废弃数量及销售额（销售额>300）
late_make_list as(
select
create_date
,b.store_cvs_code
,b.display_name
,d.payable_price_hot_meal
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then waste_quantity end) as waste_quantity
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity end) as make_quantity_1100
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then make_quantity end) as make_quantity_0900
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join work_day_list c on a.create_date = c.date_key
left join slae_hotmeal_day d on a.create_date = d.order_date and b.store_cvs_code = d.store_cvs_code
where dt = '20221231'
and sku_division_code in ('0301')
--and b.store_cvs_code in ('123000226')
and is_working_day = '1'
and d.payable_price_hot_meal > 300
group by
create_date
,b.store_cvs_code
,b.display_name
,d.payable_price_hot_meal),

--门店工作日清单（当日热餐销售>300）
work_day_store_list as(
select
create_date
,b.store_cvs_code
,b.display_name
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join work_day_list c on a.create_date = c.date_key
left join slae_hotmeal_day d on b.store_cvs_code = d.store_cvs_code and d.order_date = a.create_date
where dt = '20221231'
and sku_division_code in ('0301')
--and b.store_cvs_code in ('123000226')
and is_working_day = '1'
and d.payable_price_hot_meal > 300
group by
create_date
,b.store_cvs_code
,b.display_name),

--历史热餐销售额均值
historey_hotmeal_avg as(
select
a.create_date
,a.store_cvs_code
,avg(b.payable_price_hot_meal) as histort_payable_price_hot_meal
from work_day_store_list a
left join slae_hotmeal_day b on a.create_date > b.order_date and a.store_cvs_code = b.store_cvs_code and b.payable_price_hot_meal > 300
--and a.store_cvs_code in ('123000226')
group by
a.create_date
,a.store_cvs_code
),

--工作日历史晚制作,总制作，废弃数量（当日热餐销售>300）
history_late_make_list as(
select
a.create_date
,a.store_cvs_code
,a.display_name
,sum(d.waste_quantity) as histort_waste_quantity
,sum(d.make_quantity_1100) as historey_make_quantity_1100
,sum(d.make_quantity_0900) as historey_make_quantity_0900
,sum(case when d.make_quantity_1100 is not null then d.make_quantity_0900 end) as historey_make_quantity_0900_1100_not_null
from work_day_store_list a
join late_make_list d on a.create_date > d.create_date and a.store_cvs_code = d.store_cvs_code
--and a.store_cvs_code in ('123000226')
group by
a.create_date
,a.store_cvs_code
,a.display_name
),

--热餐当日销售额，废弃量，晚制作，总制作，历史销售额，废弃量，晚制作，总制作（销售额>300）
hotmeal_pool_list as(
select
a.create_date
,b.store_cvs_code
,b.display_name
,d.payable_price_hot_meal
,f.histort_payable_price_hot_meal
,e.histort_waste_quantity
,e.historey_make_quantity_1100
,e.historey_make_quantity_0900
,e.historey_make_quantity_0900_1100_not_null
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then waste_quantity end) as today_waste_quantity
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity end) as today_make_quantity_1100
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then make_quantity end) as today_make_quantity_0900
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join work_day_list c on a.create_date = c.date_key
left join slae_hotmeal_day d on a.create_date = d.order_date and b.store_cvs_code = d.store_cvs_code
left join history_late_make_list e on a.create_date = e.create_date and b.store_cvs_code = e.store_cvs_code
left join historey_hotmeal_avg f on a.create_date = f.create_date and b.store_cvs_code = f.store_cvs_code
where dt = '20221231'
and sku_division_code in ('0301')
--and b.store_cvs_code in ('123000226')
and is_working_day = '1'
and d.payable_price_hot_meal > 300
group by
a.create_date
,b.store_cvs_code
,b.display_name
,d.payable_price_hot_meal
,f.histort_payable_price_hot_meal
,e.histort_waste_quantity
,e.historey_make_quantity_1100
,e.historey_make_quantity_0900
,e.historey_make_quantity_0900_1100_not_null
),

--最终列表
final_list as(
select
create_date
,store_cvs_code
,display_name
,payable_price_hot_meal
,histort_payable_price_hot_meal
,histort_waste_quantity
,historey_make_quantity_1100
,historey_make_quantity_0900
,historey_make_quantity_0900_1100_not_null
,today_waste_quantity
,today_make_quantity_1100
,today_make_quantity_0900
,case when histort_payable_price_hot_meal > payable_price_hot_meal then 1 else 0 end as payable_price_hot_meal_trend
,case when today_waste_quantity/today_make_quantity_0900 > histort_waste_quantity/historey_make_quantity_0900 then 1 else 0 end as waste_targe
,case when today_make_quantity_1100/today_make_quantity_0900 > historey_make_quantity_1100/historey_make_quantity_0900_1100_not_null then 1 else 0 end as late_make_target
from hotmeal_pool_list
)

--废弃多早售罄发生率
select
trunc(create_date,'MM') as month
,store_cvs_code
,display_name
,count(create_date) as days
,sum(payable_price_hot_meal_trend)/count(create_date) as payable_price_hot_meal_rat
,sum(waste_targe)/count(create_date) as waste_targe_rat
,sum(late_make_target)/count(create_date) as late_make_target_rat
from final_list
group by
trunc(create_date,'MM')
,store_cvs_code
,display_name



















SELECT
a.target_date
,b.store_cvs_code
,b.display_name
,is_working_day
,c.sale_qty
,c.make_qty
,c.waste_qty
,sum(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end) as fenzi_10
,count(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end) as fenmu_10
,sum(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end) as fenzi_1240
,count(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end) as fenmu_1240
,sum(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end)*1.0000/count(case when hr_mi between '10:00' and '12:30' then final_saleout_flag end) as time_1000_1230
,sum(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end)*1.0000/count(case when hr_mi between '12:40' and '14:00' then final_saleout_flag end) as time_1240_1400
from data_smartorder.dm_ordering_report_ff_sold_out_cuspeak_di a
left join desensitization b on a.store_code = b.store_code
left join waste_price c on a.store_code = c.store_code and a.target_date = c.target_date
WHERE dt >= '20210510'
and sku_division_code in ('0301')
and hr_mi BETWEEN '10:00' and '14:00'
group by
a.target_date
,b.store_cvs_code
,b.display_name
,is_working_day
,c.sale_qty
,c.make_qty
,c.waste_qty

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20230101'
group by
store_code,
store_name,
store_cvs_code,
display_name),

--工作日列表
work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--热餐当日中午（11:00-14:00）销售额
slae_hotmeal_day as(
select
order_date
,store_code
,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301') then payable_price else 0 end) as payable_price_hot_meal
from default.dw_order_sku_promotion_v1
where dt = 20230101
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and substr(order_time,12,8) between '11:00:00' and '14:00:00'
group by
order_date
,store_code
),

--制作明细
make_list as(
select
create_date
,b.store_cvs_code
,b.display_name
,payable_price_hot_meal
,is_working_day
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then waste_quantity else 0 end) as waste_quantity
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity else 0 end) as make_quantity_1100
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then make_quantity end) as make_quantity_0900
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join slae_hotmeal_day c on a.store_code = c.store_code and a.create_date = c.order_date
left join work_day_list d on a.create_date = d.date_key
where dt = '20230101'
and sku_division_code in ('0301')
--and b.store_cvs_code in ('110000158')
and create_date between '2022-12-01' and '2022-12-31'
group by
create_date
,b.store_cvs_code
,b.display_name
,payable_price_hot_meal
,is_working_day
)

select
is_working_day
,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900=0 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900=0 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900=0 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900=0 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900=0 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900=0 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0 and make_quantity_1100/make_quantity_0900<=0.05 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0 and make_quantity_1100/make_quantity_0900<=0.05 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0 and make_quantity_1100/make_quantity_0900<=0.05 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0 and make_quantity_1100/make_quantity_0900<=0.05 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0 and make_quantity_1100/make_quantity_0900<=0.05 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0 and make_quantity_1100/make_quantity_0900<=0.05 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.05 and make_quantity_1100/make_quantity_0900<=0.1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.05 and make_quantity_1100/make_quantity_0900<=0.1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.05 and make_quantity_1100/make_quantity_0900<=0.1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.05 and make_quantity_1100/make_quantity_0900<=0.1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.05 and make_quantity_1100/make_quantity_0900<=0.1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.05 and make_quantity_1100/make_quantity_0900<=0.1 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.1 and make_quantity_1100/make_quantity_0900<=0.15 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.1 and make_quantity_1100/make_quantity_0900<=0.15 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.1 and make_quantity_1100/make_quantity_0900<=0.15 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.1 and make_quantity_1100/make_quantity_0900<=0.15 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.1 and make_quantity_1100/make_quantity_0900<=0.15 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.1 and make_quantity_1100/make_quantity_0900<=0.15 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.15 and make_quantity_1100/make_quantity_0900<=0.2 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.15 and make_quantity_1100/make_quantity_0900<=0.2 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.15 and make_quantity_1100/make_quantity_0900<=0.2 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.15 and make_quantity_1100/make_quantity_0900<=0.2 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.15 and make_quantity_1100/make_quantity_0900<=0.2 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.15 and make_quantity_1100/make_quantity_0900<=0.2 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.2 and make_quantity_1100/make_quantity_0900<=0.25 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.2 and make_quantity_1100/make_quantity_0900<=0.25 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.2 and make_quantity_1100/make_quantity_0900<=0.25 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.2 and make_quantity_1100/make_quantity_0900<=0.25 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.2 and make_quantity_1100/make_quantity_0900<=0.25 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.2 and make_quantity_1100/make_quantity_0900<=0.25 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.25 and make_quantity_1100/make_quantity_0900<=0.3 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.25 and make_quantity_1100/make_quantity_0900<=0.3 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.25 and make_quantity_1100/make_quantity_0900<=0.3 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.25 and make_quantity_1100/make_quantity_0900<=0.3 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.25 and make_quantity_1100/make_quantity_0900<=0.3 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.25 and make_quantity_1100/make_quantity_0900<=0.3 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.3 and make_quantity_1100/make_quantity_0900<=0.35 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.3 and make_quantity_1100/make_quantity_0900<=0.35 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.3 and make_quantity_1100/make_quantity_0900<=0.35 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.3 and make_quantity_1100/make_quantity_0900<=0.35 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.3 and make_quantity_1100/make_quantity_0900<=0.35 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.3 and make_quantity_1100/make_quantity_0900<=0.35 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.35 and make_quantity_1100/make_quantity_0900<=0.4 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.35 and make_quantity_1100/make_quantity_0900<=0.4 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.35 and make_quantity_1100/make_quantity_0900<=0.4 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.35 and make_quantity_1100/make_quantity_0900<=0.4 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.35 and make_quantity_1100/make_quantity_0900<=0.4 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.35 and make_quantity_1100/make_quantity_0900<=0.4 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.4 and make_quantity_1100/make_quantity_0900<=0.45 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.4 and make_quantity_1100/make_quantity_0900<=0.45 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.4 and make_quantity_1100/make_quantity_0900<=0.45 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.4 and make_quantity_1100/make_quantity_0900<=0.45 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.4 and make_quantity_1100/make_quantity_0900<=0.45 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.4 and make_quantity_1100/make_quantity_0900<=0.45 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.45 and make_quantity_1100/make_quantity_0900<=0.5 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.45 and make_quantity_1100/make_quantity_0900<=0.5 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.45 and make_quantity_1100/make_quantity_0900<=0.5 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.45 and make_quantity_1100/make_quantity_0900<=0.5 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.45 and make_quantity_1100/make_quantity_0900<=0.5 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.45 and make_quantity_1100/make_quantity_0900<=0.5 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.5 and make_quantity_1100/make_quantity_0900<=0.55 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.5 and make_quantity_1100/make_quantity_0900<=0.55 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.5 and make_quantity_1100/make_quantity_0900<=0.55 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.5 and make_quantity_1100/make_quantity_0900<=0.55 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.5 and make_quantity_1100/make_quantity_0900<=0.55 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.5 and make_quantity_1100/make_quantity_0900<=0.55 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.55 and make_quantity_1100/make_quantity_0900<=0.6 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.55 and make_quantity_1100/make_quantity_0900<=0.6 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.55 and make_quantity_1100/make_quantity_0900<=0.6 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.55 and make_quantity_1100/make_quantity_0900<=0.6 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.55 and make_quantity_1100/make_quantity_0900<=0.6 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.55 and make_quantity_1100/make_quantity_0900<=0.6 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.6 and make_quantity_1100/make_quantity_0900<=0.65 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.6 and make_quantity_1100/make_quantity_0900<=0.65 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.6 and make_quantity_1100/make_quantity_0900<=0.65 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.6 and make_quantity_1100/make_quantity_0900<=0.65 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.6 and make_quantity_1100/make_quantity_0900<=0.65 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.6 and make_quantity_1100/make_quantity_0900<=0.65 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.65 and make_quantity_1100/make_quantity_0900<=0.7 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.65 and make_quantity_1100/make_quantity_0900<=0.7 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.65 and make_quantity_1100/make_quantity_0900<=0.7 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.65 and make_quantity_1100/make_quantity_0900<=0.7 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.65 and make_quantity_1100/make_quantity_0900<=0.7 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.65 and make_quantity_1100/make_quantity_0900<=0.7 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.7 and make_quantity_1100/make_quantity_0900<=0.75 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.7 and make_quantity_1100/make_quantity_0900<=0.75 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.7 and make_quantity_1100/make_quantity_0900<=0.75 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.7 and make_quantity_1100/make_quantity_0900<=0.75 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.7 and make_quantity_1100/make_quantity_0900<=0.75 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.7 and make_quantity_1100/make_quantity_0900<=0.75 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.75 and make_quantity_1100/make_quantity_0900<=0.8 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.75 and make_quantity_1100/make_quantity_0900<=0.8 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.75 and make_quantity_1100/make_quantity_0900<=0.8 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.75 and make_quantity_1100/make_quantity_0900<=0.8 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.75 and make_quantity_1100/make_quantity_0900<=0.8 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.75 and make_quantity_1100/make_quantity_0900<=0.8 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.8 and make_quantity_1100/make_quantity_0900<=0.85 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.8 and make_quantity_1100/make_quantity_0900<=0.85 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.8 and make_quantity_1100/make_quantity_0900<=0.85 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.8 and make_quantity_1100/make_quantity_0900<=0.85 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.8 and make_quantity_1100/make_quantity_0900<=0.85 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.8 and make_quantity_1100/make_quantity_0900<=0.85 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.85 and make_quantity_1100/make_quantity_0900<=0.9 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.85 and make_quantity_1100/make_quantity_0900<=0.9 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.85 and make_quantity_1100/make_quantity_0900<=0.9 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.85 and make_quantity_1100/make_quantity_0900<=0.9 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.85 and make_quantity_1100/make_quantity_0900<=0.9 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.85 and make_quantity_1100/make_quantity_0900<=0.9 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.9 and make_quantity_1100/make_quantity_0900<=0.95 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.9 and make_quantity_1100/make_quantity_0900<=0.95 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.9 and make_quantity_1100/make_quantity_0900<=0.95 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.9 and make_quantity_1100/make_quantity_0900<=0.95 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.9 and make_quantity_1100/make_quantity_0900<=0.95 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.9 and make_quantity_1100/make_quantity_0900<=0.95 then payable_price_hot_meal end)

,avg(case when make_quantity_0900>0 and make_quantity_0900<=50 and make_quantity_1100/make_quantity_0900>0.95 and make_quantity_1100/make_quantity_0900<=1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>50 and make_quantity_0900<=150 and make_quantity_1100/make_quantity_0900>0.95 and make_quantity_1100/make_quantity_0900<=1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>150 and make_quantity_0900<=250 and make_quantity_1100/make_quantity_0900>0.95 and make_quantity_1100/make_quantity_0900<=1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>250 and make_quantity_0900<=350 and make_quantity_1100/make_quantity_0900>0.95 and make_quantity_1100/make_quantity_0900<=1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>350 and make_quantity_0900<=450 and make_quantity_1100/make_quantity_0900>0.95 and make_quantity_1100/make_quantity_0900<=1 then payable_price_hot_meal end)
,avg(case when make_quantity_0900>450 and make_quantity_0900<=500000 and make_quantity_1100/make_quantity_0900>0.95 and make_quantity_1100/make_quantity_0900<=1 then payable_price_hot_meal end)
from make_list
group BY
is_working_day

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--大盘热餐（11:00-14:00）店均销售额
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20230101'
group by
store_code,
store_name,
store_cvs_code,
display_name),

--工作日列表
work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

day_payable_price_hot_meal as(
select
order_date
,is_working_day
,row_number () over(order by order_date asc) as rn
,sum(payable_price)/count(distinct a.store_code) as payable_price_hot_meal
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
left join desensitization c on a.store_code = c.store_code
where dt = 20230101
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and substr(order_time,12,8) between '11:00:00' and '14:00:00'
and is_working_day = 1
and sku_division_code in ('0301')
and c.store_cvs_code in ('100010002',
'100051001',
'100011003',
'123001003',
'110001010',
'123001002',
'110001025',
'110001033',
'123001032',
'123001031',
'100071007',
'123001037',
'123001055',
'123001033',
'123001050',
'100001107',
'100000002',
'110000003',
'110000002',
'110001058',
'123001076',
'110000006',
'123001063',
'123001062',
'123001071',
'123000001',
'110001062',
'123000018',
'110000011',
'100000069',
'100000059',
'123001059',
'100000153',
'100000170',
'100000060',
'123000067',
'123000076',
'123000008',
'123000017',
'123000062',
'110000021',
'123000061',
'100000139',
'123000077',
'123000012',
'123000030',
'123000083',
'123000082',
'123000087',
'110000056',
'123000098',
'100000238',
'110000069',
'123001066',
'123000131',
'123000101',
'123000166',
'100000310',
'100000318',
'123000179',
'123000165',
'123000190',
'110000102',
'123000227',
'123000267',
'123000288',
'100000579',
'110000136',
'100000569',
'100000535',
'100000607',
'101000173',
'123000283',
'110000138',
'100000589',
'110000135',
'123000319',
'110000155',
'100000375',
'101000220',
'110000158',
'110000161',
'123000365',
'110000165',
'100000681',
'100000687',
'123000369',
'123000371',
'100001183',
'123000377',
'110000176',
'110000052',
'100001185',
'123000381',
'110000177',
'110000186',
'110000183',
'100001576',
'110000208',
'100001562',
'110000321',
'101000599',
'101000530')
group by
order_date
,is_working_day),

T_1_list as(
select
a.order_date
,a.payable_price_hot_meal as day_payable_price_hot_meal
,b.payable_price_hot_meal as day_1_payable_price_hot_meal
from day_payable_price_hot_meal a
left join day_payable_price_hot_meal b on a.rn = b.rn+1
)

select
order_date
,(day_payable_price_hot_meal-day_1_payable_price_hot_meal)/day_1_payable_price_hot_meal
from T_1_list

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--103门店热餐△（分高中低销）
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20230101'
group by
store_code,
store_name,
store_cvs_code,
display_name),

--工作日列表
work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--店*日午餐段热餐销售额
day_payable_price_hot_meal as(
select
order_date
,c.store_cvs_code
,c.display_name
,is_working_day
,row_number () over(partition by c.store_cvs_code order by order_date asc) as rn
,sum(payable_price)/count(distinct a.store_code) as payable_price_hot_meal
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
left join desensitization c on a.store_code = c.store_code
where dt = 20230101
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and substr(order_time,12,8) between '11:00:00' and '14:00:00'
and is_working_day = 1
and sku_division_code in ('0301')
and c.store_cvs_code in ('100010002',
'100051001','100011003','123001003','110001010','123001002','110001025','110001033','123001032','123001031','100071007','123001037','123001055','123001033','123001050','100001107','100000002','110000003','110000002','110001058','123001076','110000006','123001063','123001062','123001071','123000001','110001062','123000018','110000011','100000069','100000059','123001059','100000153',
'100000170','100000060','123000067','123000076','123000008','123000017','123000062','110000021','123000061','100000139','123000077','123000012','123000030','123000083','123000082','123000087','110000056','123000098','100000238','110000069','123001066','123000131','123000101','123000166','100000310','100000318','123000179','123000165','123000190','110000102','123000227','123000267',
'123000288','100000579','110000136','100000569','100000535','100000607','101000173','123000283','110000138','100000589','110000135','123000319','110000155','100000375','101000220','110000158','110000161','123000365','110000165','100000681','100000687','123000369','123000371','100001183','123000377','110000176','110000052','100001185','123000381','110000177','110000186','110000183',
'100001576','110000208','100001562','110000321','101000599','101000530')
group by
order_date
,c.store_cvs_code
,c.display_name
,is_working_day),

--店*日制作明细
make_list as(
select
create_date
,b.store_cvs_code
,b.display_name
,c.payable_price_hot_meal
,d.is_working_day
,case
when c.payable_price_hot_meal > 0 and c.payable_price_hot_meal < 300 then 'low_sale'
when c.payable_price_hot_meal >= 300 and c.payable_price_hot_meal < 700 then 'normal_sale'
when c.payable_price_hot_meal >= 700 then 'hight_sale' end as gear
,row_number () over(partition by b.store_cvs_code order by create_date asc) as rn
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then waste_quantity else 0 end) as waste_quantity
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity else 0 end) as make_quantity_1100
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then make_quantity end) as make_quantity_0900
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join day_payable_price_hot_meal c on b.store_cvs_code = c.store_cvs_code and a.create_date = c.order_date
left join work_day_list d on a.create_date = d.date_key
where dt = '20230101'
and sku_division_code in ('0301')
and b.store_cvs_code in ('100010002',
'100051001','100011003','123001003','110001010','123001002','110001025','110001033','123001032','123001031','100071007','123001037','123001055','123001033','123001050','100001107','100000002','110000003','110000002','110001058','123001076','110000006','123001063','123001062','123001071','123000001','110001062','123000018','110000011','100000069','100000059','123001059','100000153',
'100000170','100000060','123000067','123000076','123000008','123000017','123000062','110000021','123000061','100000139','123000077','123000012','123000030','123000083','123000082','123000087','110000056','123000098','100000238','110000069','123001066','123000131','123000101','123000166','100000310','100000318','123000179','123000165','123000190','110000102','123000227','123000267',
'123000288','100000579','110000136','100000569','100000535','100000607','101000173','123000283','110000138','100000589','110000135','123000319','110000155','100000375','101000220','110000158','110000161','123000365','110000165','100000681','100000687','123000369','123000371','100001183','123000377','110000176','110000052','100001185','123000381','110000177','110000186','110000183',
'100001576','110000208','100001562','110000321','101000599','101000530')
and d.is_working_day = 1
and c.payable_price_hot_meal is not null
group by
create_date
,b.store_cvs_code
,b.display_name
,c.payable_price_hot_meal
,d.is_working_day
,case
when c.payable_price_hot_meal > 0 and c.payable_price_hot_meal < 300 then 'low_sale'
when c.payable_price_hot_meal >= 300 and c.payable_price_hot_meal < 700 then 'normal_sale'
when c.payable_price_hot_meal >= 700 then 'hight_sale' end
),

--高废弃晚制作标签
bad_type as(
select
a.create_date
,a.store_cvs_code
,a.display_name
,a.payable_price_hot_meal as T_pay
,b.payable_price_hot_meal as T_1_pay
,a.is_working_day
,a.gear
,a.rn
,a.waste_quantity
,a.make_quantity_1100
,a.make_quantity_0900
,case
when a.gear = 'hight_sale' and a.waste_quantity/a.make_quantity_0900 > 0.2 and a.make_quantity_1100/a.make_quantity_0900 > 0.3 then 1
when a.gear = 'normal_sale' and a.waste_quantity/a.make_quantity_0900 > 0.4 and a.make_quantity_1100/a.make_quantity_0900 > 0.3 then 1
when a.gear = 'low_sale' and a.waste_quantity/a.make_quantity_0900 > 0.7 and a.make_quantity_1100/a.make_quantity_0900 > 0.3 then 1 else 0 end as bad_type
from make_list a
left join make_list b on a.rn = b.rn+1 and a.store_cvs_code = b.store_cvs_code
)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--103门店热餐△（分高中低销）同档位比较
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20230101'
group by
store_code,
store_name,
store_cvs_code,
display_name),

--工作日列表
work_day_list as(
select
date_key
,is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

--店*日午餐段热餐销售额
day_payable_price_hot_meal as(
select
order_date
,c.store_cvs_code
,c.display_name
,is_working_day
,row_number () over(partition by c.store_cvs_code order by order_date asc) as rn
,sum(payable_price)/count(distinct a.store_code) as payable_price_hot_meal
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
left join desensitization c on a.store_code = c.store_code
where dt = 20230101
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and substr(order_time,12,8) between '11:00:00' and '14:00:00'
and is_working_day = 1
and sku_division_code in ('0301')
and c.store_cvs_code in ('100010002',
'100051001','100011003','123001003','110001010','123001002','110001025','110001033','123001032','123001031','100071007','123001037','123001055','123001033','123001050','100001107','100000002','110000003','110000002','110001058','123001076','110000006','123001063','123001062','123001071','123000001','110001062','123000018','110000011','100000069','100000059','123001059','100000153',
'100000170','100000060','123000067','123000076','123000008','123000017','123000062','110000021','123000061','100000139','123000077','123000012','123000030','123000083','123000082','123000087','110000056','123000098','100000238','110000069','123001066','123000131','123000101','123000166','100000310','100000318','123000179','123000165','123000190','110000102','123000227','123000267',
'123000288','100000579','110000136','100000569','100000535','100000607','101000173','123000283','110000138','100000589','110000135','123000319','110000155','100000375','101000220','110000158','110000161','123000365','110000165','100000681','100000687','123000369','123000371','100001183','123000377','110000176','110000052','100001185','123000381','110000177','110000186','110000183',
'100001576','110000208','100001562','110000321','101000599','101000530')
group by
order_date
,c.store_cvs_code
,c.display_name
,is_working_day),

--店*日制作明细
make_list as(
select
create_date
,b.store_cvs_code
,b.display_name
,c.payable_price_hot_meal
,d.is_working_day
,case
when c.payable_price_hot_meal > 0 and c.payable_price_hot_meal < 300 then 'low_sale'
when c.payable_price_hot_meal >= 300 and c.payable_price_hot_meal < 700 then 'normal_sale'
when c.payable_price_hot_meal >= 700 then 'hight_sale' end as gear
,row_number () over(partition by concat(b.store_cvs_code,gear) order by create_date asc) as rn
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then waste_quantity else 0 end) as waste_quantity
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity else 0 end) as make_quantity_1100
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then make_quantity end) as make_quantity_0900
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join day_payable_price_hot_meal c on b.store_cvs_code = c.store_cvs_code and a.create_date = c.order_date
left join work_day_list d on a.create_date = d.date_key
where dt = '20230101'
and sku_division_code in ('0301')
and b.store_cvs_code in ('100010002',
'100051001','100011003','123001003','110001010','123001002','110001025','110001033','123001032','123001031','100071007','123001037','123001055','123001033','123001050','100001107','100000002','110000003','110000002','110001058','123001076','110000006','123001063','123001062','123001071','123000001','110001062','123000018','110000011','100000069','100000059','123001059','100000153',
'100000170','100000060','123000067','123000076','123000008','123000017','123000062','110000021','123000061','100000139','123000077','123000012','123000030','123000083','123000082','123000087','110000056','123000098','100000238','110000069','123001066','123000131','123000101','123000166','100000310','100000318','123000179','123000165','123000190','110000102','123000227','123000267',
'123000288','100000579','110000136','100000569','100000535','100000607','101000173','123000283','110000138','100000589','110000135','123000319','110000155','100000375','101000220','110000158','110000161','123000365','110000165','100000681','100000687','123000369','123000371','100001183','123000377','110000176','110000052','100001185','123000381','110000177','110000186','110000183',
'100001576','110000208','100001562','110000321','101000599','101000530')
and d.is_working_day = 1
and c.payable_price_hot_meal is not null
group by
create_date
,b.store_cvs_code
,b.display_name
,c.payable_price_hot_meal
,d.is_working_day
,case
when c.payable_price_hot_meal > 0 and c.payable_price_hot_meal < 300 then 'low_sale'
when c.payable_price_hot_meal >= 300 and c.payable_price_hot_meal < 700 then 'normal_sale'
when c.payable_price_hot_meal >= 700 then 'hight_sale' end
),

--高废弃晚制作标签
bad_type as(
select
a.create_date
,a.store_cvs_code
,a.display_name
,a.payable_price_hot_meal as T_pay
,b.payable_price_hot_meal as T_1_pay
,a.is_working_day
,a.gear
,a.rn
,a.waste_quantity
,a.make_quantity_1100
,a.make_quantity_0900
,case
when a.gear = 'hight_sale' and a.waste_quantity/a.make_quantity_0900 > 0.2 and a.make_quantity_1100/a.make_quantity_0900 > 0.3 then 1
when a.gear = 'normal_sale' and a.waste_quantity/a.make_quantity_0900 > 0.4 and a.make_quantity_1100/a.make_quantity_0900 > 0.3 then 1
when a.gear = 'low_sale' and a.waste_quantity/a.make_quantity_0900 > 0.7 and a.make_quantity_1100/a.make_quantity_0900 > 0.3 then 1 else 0 end as bad_type
from make_list a
left join make_list b on a.rn = b.rn+1 and a.store_cvs_code = b.store_cvs_code and a.gear = b.gear
)

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--全量门店热餐△（分高中低销）
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '20230101'
group by
store_code,
store_name,
store_cvs_code,
display_name),

--工作日列表
work_day_list as(
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
,c.store_cvs_code
,c.display_name
,is_working_day
,row_number () over(partition by c.store_cvs_code order by order_date asc) as rn
,sum(case when sku_division_code in ('0301') and substr(order_time,12,8) between '11:00:00' and '14:00:00' then payable_price end)/count(distinct a.store_code) as payable_price_hot_meal
,sum(payable_price)/count(distinct a.store_code) as payable_price
from default.dw_order_sku_promotion_v1 a
left join work_day_list b on a.order_date = b.date_key
left join desensitization c on a.store_code = c.store_code
where dt = 20230101
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and is_working_day = 1
--and c.store_cvs_code in ('100010002',
--'100051001','100011003','123001003','110001010','123001002','110001025','110001033','123001032','123001031','100071007','123001037','123001055','123001033','123001050','100001107','100000002','110000003','110000002','110001058','123001076','110000006','123001063','123001062','123001071','123000001','110001062','123000018','110000011','100000069','100000059','123001059','100000153',
--'100000170','100000060','123000067','123000076','123000008','123000017','123000062','110000021','123000061','100000139','123000077','123000012','123000030','123000083','123000082','123000087','110000056','123000098','100000238','110000069','123001066','123000131','123000101','123000166','100000310','100000318','123000179','123000165','123000190','110000102','123000227','123000267',
--'123000288','100000579','110000136','100000569','100000535','100000607','101000173','123000283','110000138','100000589','110000135','123000319','110000155','100000375','101000220','110000158','110000161','123000365','110000165','100000681','100000687','123000369','123000371','100001183','123000377','110000176','110000052','100001185','123000381','110000177','110000186','110000183',
--'100001576','110000208','100001562','110000321','101000599','101000530')
group by
order_date
,c.store_cvs_code
,c.display_name
,is_working_day),

--店*日制作明细
make_list as(
select
create_date
,b.store_cvs_code
,b.display_name
,c.payable_price_hot_meal
,c.payable_price
,d.is_working_day
,case
when c.payable_price_hot_meal > 0 and c.payable_price_hot_meal < 300 then 'low_sale'
when c.payable_price_hot_meal >= 300 and c.payable_price_hot_meal < 700 then 'normal_sale'
when c.payable_price_hot_meal >= 700 then 'hight_sale' end as gear
,row_number () over(partition by b.store_cvs_code order by create_date asc) as rn
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then waste_quantity else 0 end) as waste_quantity
,sum(case when substr(make_time,12,8) between '11:00:00' and '14:00:00' then make_quantity else 0 end) as make_quantity_1100
,sum(case when substr(make_time,12,8) between '09:00:00' and '14:00:00' then make_quantity end) as make_quantity_0900
from default.dw_promotion_store_sku_freshness_make_v1 a
left join desensitization b on a.store_code = b.store_code
left join day_payable_price_hot_meal c on b.store_cvs_code = c.store_cvs_code and a.create_date = c.order_date
left join work_day_list d on a.create_date = d.date_key
where dt = '20230101'
and sku_division_code in ('0301')
--and b.store_cvs_code in ('100010002',
--'100051001','100011003','123001003','110001010','123001002','110001025','110001033','123001032','123001031','100071007','123001037','123001055','123001033','123001050','100001107','100000002','110000003','110000002','110001058','123001076','110000006','123001063','123001062','123001071','123000001','110001062','123000018','110000011','100000069','100000059','123001059','100000153',
--'100000170','100000060','123000067','123000076','123000008','123000017','123000062','110000021','123000061','100000139','123000077','123000012','123000030','123000083','123000082','123000087','110000056','123000098','100000238','110000069','123001066','123000131','123000101','123000166','100000310','100000318','123000179','123000165','123000190','110000102','123000227','123000267',
--'123000288','100000579','110000136','100000569','100000535','100000607','101000173','123000283','110000138','100000589','110000135','123000319','110000155','100000375','101000220','110000158','110000161','123000365','110000165','100000681','100000687','123000369','123000371','100001183','123000377','110000176','110000052','100001185','123000381','110000177','110000186','110000183',
--'100001576','110000208','100001562','110000321','101000599','101000530')
and d.is_working_day = 1
and c.payable_price_hot_meal is not null
group by
create_date
,b.store_cvs_code
,b.display_name
,c.payable_price_hot_meal
,payable_price
,d.is_working_day
,case
when c.payable_price_hot_meal > 0 and c.payable_price_hot_meal < 300 then 'low_sale'
when c.payable_price_hot_meal >= 300 and c.payable_price_hot_meal < 700 then 'normal_sale'
when c.payable_price_hot_meal >= 700 then 'hight_sale' end
),

--高废弃晚制作标签
bad_type as(
select
a.create_date
,a.store_cvs_code
,a.display_name
,a.payable_price_hot_meal as T_pay_hot_meal
,b.payable_price_hot_meal as T_1_pay_hot_meal
,a.payable_price as T_pay
,b.payable_price as T_1_pay
,a.is_working_day
,a.gear
,a.rn
,a.waste_quantity
,a.make_quantity_1100
,a.make_quantity_0900
,case
when a.gear = 'hight_sale' and a.waste_quantity/a.make_quantity_0900 > 0.09 and a.make_quantity_1100/a.make_quantity_0900 > 0.15 then 1
when a.gear = 'normal_sale' and a.waste_quantity/a.make_quantity_0900 > 0.16 and a.make_quantity_1100/a.make_quantity_0900 > 0.15 then 1
when a.gear = 'low_sale' and a.waste_quantity/a.make_quantity_0900 > 0.33 and a.make_quantity_1100/a.make_quantity_0900 > 0.15 then 1 else 0 end as bad_type
from make_list a
left join make_list b on a.rn = b.rn+1 and a.store_cvs_code = b.store_cvs_code
where a.create_date between '2021-01-01' and '2022-12-31'
)
