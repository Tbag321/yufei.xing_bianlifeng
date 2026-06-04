--商品温度销售分布
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
c.store_code_ming,
cast(a.record_date as date) as business_date
from data_drink.dm_drink_mid_beetea_business_time a
join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
left join default.ods_uploads_soberhi_desensitization c on a.store_code=c.store_code_mi
where a.record_date>=b.opening_date
and sale_time<>'全天不营业'
and a.record_date>=date_format(date_parse('${start_dt}','%%Y%%m%%d'),'%%Y-%%m-%%d')
and a.record_date<=date_format(date_parse('${end_dt}','%%Y%%m%%d'),'%%Y-%%m-%%d')
group by 1,2,3
),

-- 商品信息
sku_info as (
select
sku_code,
sku_name,
CASE
   WHEN sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
   WHEN sku_division_name='咖啡' THEN '咖啡'
   ELSE '其他'
END AS sku_division_name
from default.dim_sku_info
where dt='${today-1}'
and sku_class_code='50' and sku_division_code not in ('5001','5002')
and sku_type='动态组合商品'
group by 1,2,3
),

--sku对应温度信息
sku_temperature as(
    select finished_sku_code,sku_code
,case when sku_label_type='temperature' then '温度'
when sku_label_type='cup' then '杯子'
when sku_label_type='alcohol' then '酒精含量'
when sku_label_type='sugar' then '甜度'
when sku_label_type='sugar_type' then '糖种类'
when sku_label_type='weight' then '份量'
end as sku_label_type
,case when sku_label='temperature_06' then '正常冰（推荐）'
when sku_label='temperature_01' then '正常冰'
when sku_label='temperature_02' then '少冰'
when sku_label='temperature_03' then '去冰'
when sku_label='temperature_04' then '热'
when sku_label='temperature_05' then '冷'
when sku_label='alcohol_01' then '微醺'
when sku_label='alcohol_02' then '微微醺'
when sku_label='cup_01' then '正常外带杯'
when sku_label='cup_02' then '自带杯立减2元'
when sku_label='sugar_01' then '正常甜（推荐）'
when sku_label='sugar_02' then '半甜'
when sku_label='sugar_03' then '正常甜'
when sku_label='sugar_04' then '少少甜'
when sku_label='sugar_05' then '少少少甜'
when sku_label='sugar_06' then '不另外加甜'
when sku_label='sugar_07' then '多甜'
when sku_label='sugar_08' then '少甜'
when sku_label='sugar_type_01' then '砂糖'
when sku_label='sugar_type_02' then '+1元换低卡甜菊糖'
when sku_label='sugar_type_03' then '甜菊糖（限时免费）'
when sku_label='sugar_type_04' then '标准糖'
when sku_label='sugar_type_05' then '0卡糖'
when sku_label='weight_01' then '8oz（推荐）'
when sku_label='weight_02' then '12oz'
when sku_label='weight_03' then '8oz'
end as sku_label
from (
select finished_sku_code,component_sku_code as sku_code,substr(sku_label,1,length(sku_label)-3) as sku_label_type,sku_label from (
select a.finished_sku_code,a.component_sku_code,replace(sku_label,'"','') as sku_label from default.pdw_bach_baseinfo_product_product_sku_gen_rule a
left join default.dim_sku_info b on b.dt='${today-1}' and b.sku_code=a.finished_sku_code
cross join unnest(split(replace(replace(related_dynamic_sku_label,'[',''),']'),',')) as t (sku_label)
where a.dt='${today-1}'
and b.sku_class_code='50'
and b.sku_type='动态组合商品'
group by a.finished_sku_code,a.component_sku_code,sku_label
) a
) a
),

--订单明细
order_info as(
select
a.order_date,
a.order_no,
coalesce(b.finished_sku_code,a.sku_code) as sku_code,
c.component_sku_code,
e.sku_label_type,
e.sku_label,
sum(sku_quantity) as sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d') and finished_sku_type_code='9' and b.component_sku_code=a.sku_code
left join default.mid_order_sku_component_detail_v3_di c on a.order_no=c.order_no and coalesce(b.finished_sku_code,a.sku_code)=c.sku_code
left join sku_temperature e on e.sku_code=c.component_sku_code
join store_business_time d on d.store_code_ming=a.vice_store_code and d.business_date=a.order_date
where a.dt='${today-1}'
and sku_division_code not in ('5001','5002','5019','5020')
AND a.order_status = 'FINISHED'
AND a.sku_quantity>0
AND (a.sku_division_code='0716' OR a.sku_class_code='50')
AND coalesce(a.pay_id,'')<>'30112507801894'
group by 1,2,3,4,5,6
)

select
date_trunc('month',date(order_date)) as month,
sku_code,
sku_label,
sum(sku_quantity)
from order_info
where sku_label_type='温度'
group by 1,2,3