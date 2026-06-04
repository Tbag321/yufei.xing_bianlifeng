--门店周维度订单类型
--订单类型
with store_info as (
select store_city,store_code,store_name,original_openning_date as opening_date
from default.dim_store_info
where dt='${today-1}'
and store_type='20'
),
 
-- 营业店日
store_business_time as(
select
a.store_code,
cast(a.record_date as date) as business_date
from data_drink.dm_drink_mid_beetea_business_time a
join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
where a.record_date>=b.opening_date
and sale_time<>'全天不营业'
group by 1,2
),

temp_third_part_order as (
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

--门店周维度订单明细
order_list_week as(
select
date_trunc('week',date(a.order_date)) as order_week,
a.vice_store_code,
a.vice_store_name,
a.order_no,
b.acquisition_type
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join temp_third_part_order b on a.order_no=b.order_no
left join default.ods_uploads_soberhi_desensitization c on a.vice_store_code=c.store_code_ming
join store_business_time d on c.store_code_mi=d.store_code and d.business_date=a.order_date
where a.dt='${today-1}'
and a.order_status='FINISHED'
and a.sku_quantity>0
and (    a.sku_division_code = '0716'
        OR a.sku_class_code = '50'
        )
and a.sku_division_code not in ('5001','5002','5019','5020')
and coalesce(a.pay_id,'')<>'30112507801894'
group by 1,2,3,4,5
)

--门店周维度订单类型
select
order_week,
vice_store_code,
vice_store_name,
count(distinct order_no) as "订单总量",
count(distinct case when acquisition_type in ('美团','饿了么') then order_no end) as "三方外卖订单量",
count(distinct case when acquisition_type in ('加购','门店自提') then order_no end) as "加购订单量",
count(distinct case when acquisition_type in ('自有外卖') then order_no end) as "自有外卖订单量"
from order_list_week
group by 1,2,3