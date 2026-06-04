with ref_qty as
(
select
    record_hour
   ,sale_date
   ,day_of_week_name
   ,is_working_day
   ,holiday_type
   ,is_holiday
   ,store_code
   ,store_name
   ,store_area_name
   ,store_city
   ,store_county
   ,store_location_info
   ,position_info
   ,store_opening_date
   ,weather_condition
   ,max_temperature
   ,discount --日配59 79促销

   ,is_close_store
   ,go_customer_num

   ,order_cnt_store
   ,order_cnt_instore
   ,order_cnt_takeaway
   ,order_cnt_cash
   ,order_cnt_new_user_coupon

   ,amount_store
   ,amount_instore
   ,amount_cash
   ,amount_takeaway
   ,amount_new_user_coupon
   ,amount_cigarette
   ,amount_24h
   ,amount_non24h
   ,amount_fruit
   ,amount_hotmeal
   ,amount_ff
   ,amount_drink_manual
   ,amount_snack
   ,amount_drinks
   ,amount_umbrella
   ,amount_theft_loss_retrieve --盗损追回
   ,amount_big_order

   ,amount_ripei
   ,amount_non_ripei

   ,close_shop_task_cnt
   ,water_purifier_repair_task_cnt
   ,coffee_machine_repair_task_cnt
   ,soybean_milk_machine_repair_task_cnt
   ,zhengbaoji_repair_task_cnt
   ,guandongzhu_repair_task_cnt
   ,zhapin_repair_task_cnt
   ,kaoxiang_repair_task_cnt
   ,wenshuigui_repair_task_cnt
   ,fengmugui_repair_task_cnt
   ,houbugui_repair_task_cnt

   ,water_failure_cnt
   ,competitor_event_cnt
   ,business_circle_event_cnt
   ,force_majeure_event_cnt

   ,make_quantity_meal
   ,make_quantity_ff

   ,lag(sale_date, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_date
   ,lag(max_temperature, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_max_temperature
   ,lag(discount,1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_discount
   ,lag(go_customer_num, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_go_customer_num
   ,lag(is_close_store, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_close_store

   ,lag(order_cnt_store, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_order_cnt_store
   ,lag(order_cnt_instore, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_order_cnt_instore
   ,lag(order_cnt_takeaway, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_order_cnt_takeaway
   ,lag(order_cnt_cash, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_order_cnt_cash
   ,lag(order_cnt_new_user_coupon, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_order_cnt_new_user_coupon

   ,lag(amount_store, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_store
   ,lag(amount_instore, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_instore
   ,lag(amount_takeaway, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_takeaway
   ,lag(amount_cash, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_cash
   ,lag(amount_new_user_coupon, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_new_user_coupon
   ,lag(amount_cigarette, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_cigarette
   ,lag(amount_24h, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_24h
   ,lag(amount_non24h, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_non24h
   ,lag(amount_fruit, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_fruit
   ,lag(amount_hotmeal, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_hotmeal
   ,lag(amount_ff, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_ff
   ,lag(amount_drink_manual, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_drink_manual
   ,lag(amount_snack, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_snack
   ,lag(amount_drinks, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_drinks
   ,lag(amount_umbrella, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_umbrella
   ,lag(amount_theft_loss_retrieve, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_theft_loss_retrieve
   ,lag(amount_big_order, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_big_order

   ,lag(amount_ripei, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_ripei
   ,lag(amount_non_ripei, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as ref_amount_non_ripei

   ,max_temperature - lag(max_temperature, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as max_temperature_diff
   ,discount - lag(discount,1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as discount_diff
   ,go_customer_num - lag(go_customer_num, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as go_customer_num_diff
   ,order_cnt_store - lag(order_cnt_store, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as order_cnt_store_diff
   ,order_cnt_instore - lag(order_cnt_instore, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as order_cnt_instore_diff

   ,amount_store - lag(amount_store, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_store_diff
   ,amount_instore - lag(amount_instore, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_instore_diff
   ,amount_takeaway - lag(amount_takeaway, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_takeaway_diff
   ,amount_cash - lag(amount_cash, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_cash_diff
   ,amount_new_user_coupon - lag(amount_new_user_coupon, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_new_user_coupon_diff

   ,amount_cigarette - lag(amount_cigarette, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as  amount_cigarette_diff
   ,amount_24h - lag(amount_24h, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_24h_diff
   ,amount_non24h - lag(amount_non24h, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_non24h_diff
   ,amount_fruit - lag(amount_fruit, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_fruit_diff
   ,amount_hotmeal - lag(amount_hotmeal, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_hotmeal_diff
   ,amount_ff - lag(amount_ff, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_ff_diff
   ,amount_drink_manual - lag(amount_drink_manual, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_drink_manual_diff
   ,amount_snack - lag(amount_snack, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_snack_diff
   ,amount_drinks - lag(amount_drinks, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_drinks_diff
   ,amount_umbrella - lag(amount_umbrella, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc)  as amount_umbrella_diff
   ,amount_theft_loss_retrieve - lag(amount_theft_loss_retrieve, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_theft_loss_retrieve_diff
   ,amount_big_order - lag(amount_big_order, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_big_order_diff

   ,amount_ripei - lag(amount_ripei, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_ripei_diff
   ,amount_non_ripei - lag(amount_non_ripei, 1) over(partition by store_code, holiday_type, day_of_week_name order by sale_date asc) as amount_non_ripei_diff
from data_smartorder.app_anomaly_detection_store_amount_root_cause_analysis_realtime_di
where dt = 20230413,17
)

,rule_list as
(--构造规则集合
select
    record_hour
   ,sale_date
   ,day_of_week_name
   ,is_working_day
   ,holiday_type
   ,is_holiday
   ,store_code
   ,store_name
   ,store_area_name
   ,store_city
   ,store_county
   ,store_location_info
   ,position_info
   ,store_opening_date
   ,weather_condition
   ,max_temperature
   ,discount --日配59 79促销

   ,is_close_store
   ,go_customer_num

   ,order_cnt_store
   ,order_cnt_instore
   ,order_cnt_takeaway
   ,order_cnt_cash
   ,order_cnt_new_user_coupon

   ,amount_store
   ,amount_instore
   ,amount_cash
   ,amount_takeaway
   ,amount_new_user_coupon
   ,amount_cigarette
   ,amount_24h
   ,amount_non24h
   ,amount_fruit
   ,amount_hotmeal
   ,amount_ff
   ,amount_drink_manual
   ,amount_snack
   ,amount_drinks
   ,amount_umbrella
   ,amount_theft_loss_retrieve --盗损追回
   ,amount_big_order

   ,amount_ripei
   ,amount_non_ripei

   ,close_shop_task_cnt
   ,water_purifier_repair_task_cnt
   ,coffee_machine_repair_task_cnt
   ,soybean_milk_machine_repair_task_cnt
   ,zhengbaoji_repair_task_cnt
   ,guandongzhu_repair_task_cnt
   ,zhapin_repair_task_cnt
   ,kaoxiang_repair_task_cnt
   ,wenshuigui_repair_task_cnt
   ,fengmugui_repair_task_cnt
   ,houbugui_repair_task_cnt

   ,water_failure_cnt
   ,competitor_event_cnt
   ,business_circle_event_cnt
   ,force_majeure_event_cnt

   ,make_quantity_meal
   ,make_quantity_ff

   ,ref_date
   ,ref_max_temperature
   ,ref_discount
   ,ref_go_customer_num
   ,ref_close_store
   ,ref_order_cnt_store
   ,ref_order_cnt_instore
   ,ref_order_cnt_takeaway
   ,ref_order_cnt_cash
   ,ref_order_cnt_new_user_coupon
   ,ref_amount_store
   ,ref_amount_instore
   ,ref_amount_takeaway
   ,ref_amount_cash
   ,ref_amount_new_user_coupon
   ,ref_amount_cigarette
   ,ref_amount_24h
   ,ref_amount_non24h
   ,ref_amount_fruit
   ,ref_amount_hotmeal
   ,ref_amount_ff
   ,ref_amount_drink_manual
   ,ref_amount_snack
   ,ref_amount_drinks
   ,ref_amount_umbrella
   ,ref_amount_theft_loss_retrieve
   ,ref_amount_big_order


   ,ref_amount_ripei
   ,ref_amount_non_ripei

   ,max_temperature_diff
   ,discount_diff
   ,go_customer_num_diff
   ,order_cnt_store_diff
   ,order_cnt_instore_diff
   ,amount_store_diff
   ,amount_instore_diff
   ,amount_takeaway_diff
   ,amount_cash_diff
   ,amount_new_user_coupon_diff
   ,amount_cigarette_diff
   ,amount_24h_diff
   ,amount_non24h_diff
   ,amount_fruit_diff
   ,amount_hotmeal_diff
   ,amount_ff_diff
   ,amount_drink_manual_diff
   ,amount_snack_diff
   ,amount_drinks_diff
   ,amount_umbrella_diff
   ,amount_theft_loss_retrieve_diff
   ,amount_big_order_diff

   ,amount_ripei_diff
   ,amount_non_ripei_diff


   ,case when ref_amount_ripei =0 then amount_ripei else (amount_ripei-ref_amount_ripei)/ref_amount_ripei end as amount_ripei_diff_ratio
   ,case when ref_amount_non_ripei=0 then amount_non_ripei else (amount_non_ripei-ref_amount_non_ripei)/ref_amount_non_ripei end as amount_non_ripei_diff_ratio

   ,case when ref_amount_store > 0 and amount_store_diff > 0 then '1'  --相对上周同期 销售上涨
         when ref_amount_store > 0 and amount_store_diff < 0 then '2'  --相对上周同期 销售下降
         else '0' --销售持平/新店/复业
         end as amount_change_type

   ,case when close_shop_task_cnt > 0 or is_close_store = 1 then 'y' else 'n' end as shop_close
   ,case when ref_close_store = 1 and is_close_store = 0 then 'y' else 'n' end as shop_reopen

   ,case when competitor_event_cnt>0 or business_circle_event_cnt > 0 then 'y' else 'n' end as business_circle_event
   ,case when force_majeure_event_cnt > 0  then 'y' else 'n' end as force_majeure_event

   ,case when water_failure_cnt > 0 or water_purifier_repair_task_cnt > 0 then 'y' else 'n' end as water_failure
   ,case when kaoxiang_repair_task_cnt > 0 or wenshuigui_repair_task_cnt > 0 then 'y' else 'n' end as machine_repair

   ,case when weather_condition like '%雨%' or weather_condition like '%雪%' or weather_condition like '%扬沙%' or weather_condition like '%沙尘暴%' then 'y' else 'n' end as bad_weather --恶劣天气
   ,case when max_temperature < 20  and max_temperature_diff <= -5  then '降温'
         when (max_temperature > 25 and max_temperature_diff >= 5) or (max_temperature > 30 and max_temperature_diff >= 3) then '升温'
         else '其他' end as temperature_change --温度变化

   ,case when go_customer_num_diff is not null and go_customer_num_diff <= -100 and abs(go_customer_num_diff)/ref_go_customer_num > 0.2
         then 'y' else 'n' end as passenger_decline_anomaly --门店客流异常下降
   ,case when (go_customer_num_diff is not null and go_customer_num_diff >=  100 and abs(go_customer_num_diff)/ref_go_customer_num > 0.2)
           or (go_customer_num_diff is null and order_cnt_instore_diff >=  100 and abs(order_cnt_instore_diff)/ref_order_cnt_instore > 0.2)
         then 'y' else 'n' end as passenger_increase_anomaly --门店客流异常下降

   ,case when amount_new_user_coupon_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as new_user_coupon_change
   ,case when amount_cash_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as amount_cash_change
   ,case when amount_takeaway_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as takeaway_change

   ,case when amount_big_order_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as big_order_change
   ,case when amount_theft_loss_retrieve_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as theft_loss_retrieve_change
   ,case when amount_cigarette_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as cigarette_change
   ,case when (amount_hotmeal_diff + amount_ff_diff)/amount_store_diff > 0.5
         then 'y' else 'n' end as ff_change
   ,case when amount_drinks_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as drinks_change
   ,case when amount_umbrella_diff/amount_store_diff > 0.5
         then 'y' else 'n' end as umbrella_change
from ref_qty
)

select
    record_hour
   ,sale_date
   ,day_of_week_name
   ,is_working_day
   ,holiday_type
   ,is_holiday
   ,store_code
   ,store_name
   ,store_area_name
   ,store_city
   ,store_county
   ,store_location_info
   ,position_info
   ,store_opening_date
   ,weather_condition
   ,max_temperature
   ,discount --日配59 79促销

   ,is_close_store
   ,go_customer_num

   ,order_cnt_store
   ,order_cnt_instore
   ,order_cnt_takeaway
   ,order_cnt_cash
   ,order_cnt_new_user_coupon

   ,amount_store
   ,amount_instore
   ,amount_cash
   ,amount_takeaway
   ,amount_new_user_coupon
   ,amount_cigarette
   ,amount_24h
   ,amount_non24h
   ,amount_fruit
   ,amount_hotmeal
   ,amount_ff
   ,amount_drink_manual
   ,amount_snack
   ,amount_drinks
   ,amount_umbrella
   ,amount_theft_loss_retrieve --盗损追回
   ,amount_big_order

   ,close_shop_task_cnt
   ,water_purifier_repair_task_cnt
   ,coffee_machine_repair_task_cnt
   ,soybean_milk_machine_repair_task_cnt
   ,zhengbaoji_repair_task_cnt
   ,guandongzhu_repair_task_cnt
   ,zhapin_repair_task_cnt
   ,kaoxiang_repair_task_cnt
   ,wenshuigui_repair_task_cnt
   ,fengmugui_repair_task_cnt
   ,houbugui_repair_task_cnt

   ,water_failure_cnt
   ,competitor_event_cnt
   ,business_circle_event_cnt
   ,force_majeure_event_cnt

   ,make_quantity_meal
   ,make_quantity_ff

   ,ref_date
   ,ref_max_temperature
   ,ref_discount
   ,ref_go_customer_num
   ,ref_close_store
   ,ref_order_cnt_store
   ,ref_order_cnt_instore
   ,ref_order_cnt_takeaway
   ,ref_order_cnt_cash
   ,ref_order_cnt_new_user_coupon
   ,ref_amount_store
   ,ref_amount_instore
   ,ref_amount_takeaway
   ,ref_amount_cash
   ,ref_amount_new_user_coupon
   ,ref_amount_cigarette
   ,ref_amount_24h
   ,ref_amount_non24h
   ,ref_amount_fruit
   ,ref_amount_hotmeal
   ,ref_amount_ff
   ,ref_amount_drink_manual
   ,ref_amount_snack
   ,ref_amount_drinks
   ,ref_amount_umbrella
   ,ref_amount_theft_loss_retrieve
   ,ref_amount_big_order

   ,max_temperature_diff
   ,discount_diff
   ,go_customer_num_diff
   ,order_cnt_store_diff
   ,order_cnt_instore_diff
   ,amount_store_diff
   ,amount_instore_diff
   ,amount_takeaway_diff
   ,amount_cash_diff
   ,amount_new_user_coupon_diff
   ,amount_cigarette_diff
   ,amount_24h_diff
   ,amount_non24h_diff
   ,amount_fruit_diff
   ,amount_hotmeal_diff
   ,amount_ff_diff
   ,amount_drink_manual_diff
   ,amount_snack_diff
   ,amount_drinks_diff
   ,amount_umbrella_diff
   ,amount_theft_loss_retrieve_diff
   ,amount_big_order_diff

   ,amount_change_type
   ,shop_close
   ,shop_reopen
   ,business_circle_event
   ,force_majeure_event
   ,bad_weather
   ,temperature_change
   ,passenger_decline_anomaly
   ,passenger_increase_anomaly
   ,new_user_coupon_change
   ,amount_cash_change
   ,takeaway_change
   ,big_order_change
   ,theft_loss_retrieve_change
   ,cigarette_change
   ,ff_change
   ,drinks_change
   ,umbrella_change

   ,case
         --强规则
         when amount_change_type in ('1','0') and shop_reopen = 'y' then '营业时间变化'
         when amount_store_diff < 2000 and shop_close = 'y'  then '计划闭店/紧急闭店'
         when amount_change_type = '2' and force_majeure_event = 'y' then '下降_不可抗因素'

         --相对强规则
         when business_circle_event = 'y' then '竞对变化/商圈变化'
         when cigarette_change = 'y' then '香烟销售变化'
         when big_order_change = 'y' then '大单销售变化'
         when theft_loss_retrieve_change = 'y' then '盗损追回金额变化'
         when takeaway_change = 'y' then '外卖销售变化'
         when new_user_coupon_change = 'y' then '地推活动变化'
         when amount_cash_change = 'y' then '现金用户变化' --大概率是外部原因 比如学生旅游团等

         when amount_change_type = '2' and ff_change = 'y' and (water_failure = 'y'  or machine_repair = 'y') then '下降_停水/设备故障影响FF区'
         when amount_change_type = '1' and umbrella_change = 'y' and weather_condition like '%雨%' then '上涨_雨天雨具销售增加'


         --弱规则
         when amount_change_type = '1' and drinks_change = 'y' and temperature_change = '升温' then '上涨_大幅升温水饮销售增加'
         when amount_change_type = '2' and drinks_change = 'y' and temperature_change = '降温' then '下降_大幅降温水饮销售减少'

         --弱规则 折扣活动变化
         --日商上涨不做限制,只要有折扣活动就归因为折扣. 日商下降需要限制各分类变化范围, 避免漏出
         when amount_change_type = '1' and discount in ('0.19','0.39','0.59')  then '上涨_19/39/59折活动'
         when amount_change_type = '2' and discount_diff = 0.81 and amount_ripei_diff_ratio <-0.3 and amount_non_ripei_diff_ratio <-0.3 then '下降_取消19折活动'
         else '其他' end as final_reason
from rule_list t