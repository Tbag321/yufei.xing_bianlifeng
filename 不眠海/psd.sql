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
)

select
a.order_date,
--coalesce(b.finished_sku_code,a.sku_code) as sku_code,
case when
coalesce(b.finished_sku_code,a.sku_code) in  ('40e1d65c55bc6d23b71f6d84b2e58dd9')
then '消暑桃桃莓莓酪'
when coalesce(b.finished_sku_code,a.sku_code) in ('9e8e8b455eaec8988e97f0b2fce077b4')
then '消暑桃桃椰椰酪' 
when coalesce(b.finished_sku_code,a.sku_code) in ('a5851fbdab5bfbfffe33de9644536522')
then '消暑桃桃爆柠茶' 
when coalesce(b.finished_sku_code,a.sku_code) in ('209d1aba1f0dbc398a240f1741e656ec','5c878f9fc00841e670b26dcfc5136ce9')
then '生椰摩卡嗨乐冰' 
when coalesce(b.finished_sku_code,a.sku_code) in ('8711407b71582e50a919ecc7dff4c565','915348c1ed82c4bc501e0e1fd0bba871')
then '摩卡嗨乐冰' 
end as series_name,
count(distinct a.store_code) as store_cnt,
sum(sku_quantity) as sku_quantity,
count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as store_day,
sum(sku_quantity)*1.0000/count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as psd
from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d') and finished_sku_type_code='9' and b.component_sku_code=a.sku_code
join store_business_time d on d.store_code=a.store_code and d.business_date=a.order_date
where a.dt>='${start_dt}'
and a.dt<='${end_dt}'
and a.sku_division_code not in ('5001','5002','5019','5020')
and a.is_in_store=1 --有营业日
group by 1,2
