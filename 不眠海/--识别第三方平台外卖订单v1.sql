--识别第三方平台外卖订单v1
with temp_third_part_order as (
SELECT a.order_no,
 CASE
 WHEN a.sub_business_type='EleMe' THEN '饿了么'
 WHEN a.sub_business_type='MeiTuan' THEN '美团'
 WHEN a.sub_business_type='PickUp'
 AND a.business_type='TakeawayV5' THEN '外卖自提'
 WHEN a.sub_business_type IS NULL
 AND a.business_type='TakeawayV5' THEN '其他外卖'
 WHEN a.sub_business_type='delivery'
 AND a.business_type='BeeTea' THEN '自有外卖'
 WHEN a.sub_business_type IS NULL
 AND a.business_type='BeeTea' THEN '门店自提'
 WHEN a.sub_business_type='performance' THEN '加购'
 WHEN a.sub_business_type IS NULL
 AND a.business_type in('SelfPay','SelfPos','SelfPosBliPay','SelfScan') THEN '门店自提'
 ELSE '其他'
 END AS acquisition_type,
 business_type,
 sub_business_type
FROM
 (SELECT order_no,
 json_extract_scalar(bizinfo, '$.businessType') AS business_type,
 json_extract_scalar(bizinfo, '$.subBusinessType') AS sub_business_type,
 json_extract_scalar(orderstatus,'$.name') AS order_status
 FROM default.pdw_order_detail_order_main_di
 WHERE dt >='20220522'
 AND dt<='${today-1}' ) a
),


order_info AS(
SELECT DISTINCT t1.pay_id AS user_id,
 t1.order_no,
 t2.acquisition_type,
 t1.order_date,
 t1.order_time,
 t2.business_type,
 t2.sub_business_type,
 t1.order_business_type,
 t1.delivery_type
FROM
 (SELECT 
 pay_id,
 user_id,
 order_no,
 order_date,
 order_time,
 order_business_type,
 delivery_type
 FROM data_promotion.dm_promotion_store_detl_order_detail_info_da
 WHERE dt='${today-1}'
 AND order_status = 'FINISHED'
 AND order_date>=date_parse('20220520','%%Y%%m%%d')
 AND order_date<=date_parse('${today-1}','%%Y%%m%%d')
-- AND sku_quantity>0
 AND (sku_division_code='0716' OR sku_class_code='50')
 AND sku_division_code NOT IN ('5001','5002')
 GROUP BY 1,2,3,4,5,6,7 ) t1
LEFT JOIN temp_third_part_order t2 ON t1.order_no=t2.order_no
)




select 
order_date,
acquisition_type,
business_type,
sub_business_type,
order_business_type,
delivery_type,
count(order_no) as order_cnt
from order_info
group by 1,2,3,4,5,6