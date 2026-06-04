--商品上新前30天psd
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
and a.record_date>=date_format(date_parse('${start_dt}','%%Y%%m%%d'),'%%Y-%%m-%%d')
and a.record_date<=date_format(date_parse('${end_dt}','%%Y%%m%%d'),'%%Y-%%m-%%d')
group by 1,2
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
--商品上新前30天日期
between_day as (
    select
    coalesce(b.finished_sku_code,a.sku_code) as spu,
    min(order_date) as min_order_date,
    min(date_add('day', 29, order_date)) as max_order_date
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on a.sku_code=b.component_sku_code and b.finished_sku_type_code='9' and b.dt='${today-1}'
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_parse('20220301','%%Y%%m%%d')
    and order_date<=date_parse('${today}','%%Y%%m%%d')
    and sku_quantity>0
    AND (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(pay_id,'')<>'30112507801894'
    --and coalesce(b.finished_sku_code,a.sku_code) in ('759849017b08fc47d93fa856ec80bb86')
    group by 1
)
select
a.*
,b.sku_name
,b.sku_division_name
from (
select
--a.order_date,
coalesce(b.finished_sku_code,a.sku_code) as sku_code,
count(distinct a.store_code) as store_cnt,
sum(sku_quantity) as sku_quantity,
count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as store_day,
sum(sku_quantity)*1.0000/count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as psd
from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d') and finished_sku_type_code='9' and b.component_sku_code=a.sku_code
join store_business_time d on d.store_code=a.store_code and date(d.business_date)=a.order_date
left join between_day e on coalesce(b.finished_sku_code,a.sku_code)=e.spu
where a.dt>='${start_dt}'
and a.dt<='${end_dt}'
and a.order_date>=e.min_order_date
and a.order_date<=e.max_order_date
and e.min_order_date>=timestamp'2022-03-01'
and a.is_in_store=1 --有营业日
and a.sku_division_code not in('5001','5002','5019','5020')
group by 1
) a
left join sku_info b on b.sku_code=a.sku_code