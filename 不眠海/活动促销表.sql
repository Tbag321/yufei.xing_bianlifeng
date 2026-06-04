with list_one as
(
with activity_mid_info as
(
select t.store_code
      ,t.store_name
      ,t.store_city
      ,t.openning_date
      ,t.start_date
      ,t.end_date
      ,if(t.store_status = '1','活动中','停止活动') as activity_status
  from data_promotion.dm_promotion_daily_detl_2023_daily_activity_store_list_di t
 where t.dt = '20230603'
   and t.reverse_no = '1'
),
activity_discount_info as
(
select distinct t.store_code
      ,t.discount_type
      ,t.start_date
  from data_promotion.ods_uploads_dm_promotion_2023_daily_activity_experiment_store_info t
 where t.start_date >= '2023-02-27'
   and t.activity_goods not in ('0101')
),
balance_price_info as
(
select t.store_code
      ,t.location_type
      ,t.breakeven_point as balance_price
  from dm_site_selection_store_info_lite t
 where t.dt = 20230603
),
replenish_loaction_type_info as
(
select distinct t.store_code
      ,t.store_location_info
  from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t
 where t.dt = 20230603
   and t.store_type = '0'
),
cigarette_tag_info as
(
select t.store_code
      ,sum(t.payable_price) as payable_price
  from dw_order_sku_promotion_v1 t
 where t.dt = 20230603
   and t.order_status = 'FINISHED'
   and t.store_type = '0'
   and t.order_date >= 20230504
   and t.sku_division_code in ('6101','6102')
group by t.store_code
)
select t1.store_code
      ,t1.store_name
      ,t1.store_city
      ,t1.openning_date
      ,t1.start_date
      ,date_sub(date_add(t1.start_date,1 - case when dayofweek(t1.start_date) = 1 then 7 else dayofweek(t1.start_date) - 1 end),7) as before_start_date
      ,t1.end_date
      ,t1.activity_status
      ,t2.discount_type
      ,t3.balance_price
      ,nvl(t3.location_type,t4.store_location_info) as location_type
      ,if(t5.payable_price > 0,'Y','N') as cigarette_tag
from activity_mid_info t1
left join activity_discount_info t2
  on t1.store_code = t2.store_code
 and t1.start_date = t2.start_date
left join balance_price_info t3
  on t1.store_code = t3.store_code
left join replenish_loaction_type_info t4
  on t1.store_code = t4.store_code
left join cigarette_tag_info t5
  on t1.store_code = t5.store_code
)
select * from list_one