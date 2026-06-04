--不眠海高频用户分析
with temp_third_part_order AS( 
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
 AND a.business_type IN('SelfPay',
 'SelfPos',
 'SelfPosBliPay',
 'SelfScan') THEN '门店自提'
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
 WHERE dt >='20220501'
 AND dt<='20220531' 
 and json_extract_scalar(orderstatus,'$.name')='FINISHED'
 group by 1,2,3,4
 ) a),

 history_user_order_num as (
     select
     pay_id,
     count(distinct order_no) as history_order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da
WHERE dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date<=timestamp'2022-04-30'
    and sku_quantity>0
    and sku_class_code='50'
    and sku_division_code not in ('5001','5002','5019')
    and coalesce(pay_id,'')<>'30112507801894'
    and pay_id is not null
    group by 1
),

history_user_min_order_day as (
    select
     pay_id,
     min(order_date) as min_order_date
from data_promotion.dm_promotion_store_detl_order_detail_info_da
WHERE dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date<=timestamp'2022-05-31'
    and sku_quantity>0
    and sku_class_code='50'
    and sku_division_code not in ('5001','5002','5019')
    and coalesce(pay_id,'')<>'30112507801894'
    and pay_id is not null
    group by 1
)

select
    a.pay_id,
    a.user_id,
    a.order_no,
    a.sku_code,
    a.order_date,
    a.sku_division_name,
    a.sell_price,
    a.origin_payable_price,
    a.payable_price,
    b.acquisition_type,
    c.history_order_no_num,
    d.min_order_date
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join temp_third_part_order b on a.order_no=b.order_no
    left join history_user_order_num c on a.pay_id=c.pay_id
    left join history_user_min_order_day d on a.pay_id=d.pay_id 
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and a.order_date>=timestamp'2022-05-01'
    and a.order_date<=timestamp'2022-05-31'
    and sku_quantity>0
    and sku_class_code='50'
    and sku_division_code not in ('5001','5002','5019')
    and coalesce(a.pay_id,'')<>'30112507801894'
    and a.pay_id is not null
