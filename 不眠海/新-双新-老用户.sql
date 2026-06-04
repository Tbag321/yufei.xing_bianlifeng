SELECT
a.pay_id,
a.order_date,
case
when b.new_type is NULL then '老用户'
ELSE b.new_type end as new_type
--count(DISTINCT pay_id)
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
LEFT JOIN data_drink.dm_drink_user_new_user_info_da b on a.pay_id=b.user_id and a.order_date=b.order_date and b.dt='20220515'
where a.dt='20220515' and a.order_date>=timestamp'2022-04-21'
and a.order_status='FINISHED'
and sku_quantity>0
and a.order_date<=timestamp'2022-05-15'
and a.store_type='20'