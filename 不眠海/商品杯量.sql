with store_info as (
select store_city,store_code,store_name,original_openning_date as opening_date
from default.dim_store_info
where dt='${today-1}'
and store_type='20'
and store_city='北京市'
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
--中分类销量
sku_division_quantity as(
select
a.order_date,
a.sku_division_name,
sum(a.sku_quantity)
from
(select
a.*
,b.sku_name
,b.sku_division_name
from (
select
a.order_date,
coalesce(b.finished_sku_code,a.sku_code) as sku_code,
sum(sku_quantity) as sku_quantity
from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d') and finished_sku_type_code='9' and b.component_sku_code=a.sku_code
join store_business_time d on d.store_code=a.store_code and d.business_date=a.order_date
where a.dt>='${start_dt}'
and a.dt<='${end_dt}'
and a.is_in_store=1 --有营业日
group by 1,2
) a
left join sku_info b on b.sku_code=a.sku_code) a
group by 1,2
)
--select
--a.*
--,b.sku_name
--,b.sku_division_name
--from (
select
a.order_date,
--coalesce(b.finished_sku_code,a.sku_code) as sku_code,
case when
coalesce(b.finished_sku_code,a.sku_code) in  ('d7a0ab5a09cf10a7a93905d2b6713cb2','8624d9545f2ce674d2e8f0274e31a214','f35ca5f2167d8557a07f1f93a52c9240','0001194770913aacd3a3d7917908a2e6','9eab095ca1ccb35f9d6dc8c155682b5e','4b1b40c58685dc91040c3b2bf1585f21')
then '柠檬茶系列'
when coalesce(b.finished_sku_code,a.sku_code) in ('d195b2ebe66567dd2a96f8455cc625a8','ca9699984c0bc493169059022f1eef59')
then '椰子水系列' end as series_name,
count(distinct a.store_code) as store_cnt,
sum(sku_quantity) as sku_quantity,
count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as store_day,
sum(sku_quantity)*1.0000/count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as psd
from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d') and finished_sku_type_code='9' and b.component_sku_code=a.sku_code
join store_business_time d on d.store_code=a.store_code and d.business_date=a.order_date
where a.dt>='${start_dt}'
and a.dt<='${end_dt}'
and a.is_in_store=1 --有营业日
group by 1,2
--) a
--left join sku_info b on b.sku_code=a.sku_code
--where b.sku_code in ('d7a0ab5a09cf10a7a93905d2b6713cb2','8624d9545f2ce674d2e8f0274e31a214','f35ca5f2167d8557a07f1f93a52c9240','0001194770913aacd3a3d7917908a2e6','9eab095ca1ccb35f9d6dc8c155682b5e','4b1b40c58685dc91040c3b2bf1585f21','d195b2ebe66567dd2a96f8455cc625a8','ca9699984c0bc493169059022f1eef59','9405fe8795123cb6b35cb71661d2951d')