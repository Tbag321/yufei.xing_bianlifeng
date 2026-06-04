with user_info as (
 select t.store_code as store_code
 ,concat(year(t.order_date), 'Q', quarter(t.order_date)) as quarter_label
 ,date_format(last_day(t.order_date), 'yyyy-MM') as month_label
 ,t.store_name as store_name
 ,t.store_city as store_city
 ,t.pay_id as pay_id
 ,t.order_no as order_no
 ,t.order_date as order_date
 ,t.order_time as order_time
 ,case when t.order_business_type in ('FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then 'take_away_v5' else 'in_store' end as order_type
 ,sum(t.sku_quantity) as sku_quantity
 ,sum(t.sell_price) as sell_price
 ,sum(t.payable_price) as payable_price
 ,sum(t.profit_price) as profit_price
 from data_promotion.dm_promotion_supplement_order_detail t
 where t.dt = from_unixtime(
 unix_timestamp(date_sub(current_date, 2)),
 'yyyyMMdd')
 and t.order_status = 'FINISHED' --订单完成
 and t.store_type = '0' --门店类型:门店
 and t.sku_section_code <> '071603' --加购饮品
 and t.sku_class_code <> '50' --加购饮品
 and t.sku_quantity > 0
 -- and t.order_business_type not in ('FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') --剔外卖
 and store_code in ('100001001', '100001002') AND ((order_date between '2021-08-01' and '2021-08-31'))
 group by t.store_code
 ,t.order_business_type
 ,t.store_name
 ,t.pay_id
 ,t.order_no
 ,t.order_date
 ,t.store_city
 ,t.order_time
 ),
 user_phone_mapping as (
 select user_id, user_phone from default.dim_user_info where dt= from_unixtime(
 unix_timestamp(date_sub(current_date, 2)),
 'yyyyMMdd')
 )

 
 select
 a.store_code as store_code,
 a.store_name as store_name,
 a.store_city as store_city,
 date_format(last_day(a.order_date), 'yyyy-MM') as date_label,
 a.pay_id as pay_id,
 a.order_no as order_no,
 a.order_date as order_date,
 a.order_time as order_time,
 a.order_type as order_type,
 a.sku_quantity as sku_quantity,
 a.sell_price as sell_price,
 a.payable_price as payable_price,
 a.profit_price as profit_price,
 b.user_id as user_id,
 b.user_phone as user_phone
 from user_info a
 left join user_phone_mapping b
 on
 a.pay_id = b.user_id