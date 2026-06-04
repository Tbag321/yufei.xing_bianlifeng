--店日均咖啡品类PSD
--app_drink_coffe_store_day_psd_da
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
group by a.store_code,cast(a.record_date as date)
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
group by sku_code,sku_name,sku_division_name
)

select
trunc(order_date,'MM') as order_month,
c.sku_division_name,
count(distinct a.store_code) as store_cnt,
sum(sku_quantity) as sku_quantity,
count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as store_day,
sum(sku_quantity)*1.0000/count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as psd
from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d') and finished_sku_type_code='9' and b.component_sku_code=a.sku_code
left join sku_info c on coalesce(b.finished_sku_code,a.sku_code)=c.sku_code
join store_business_time d on d.store_code=a.store_code and d.business_date=cast(a.order_date as date)
where a.dt>='20220101'
and a.sku_division_code not in ('5001','5002','5019','5020')
and a.is_in_store=1 --有营业日
group by trunc(order_date,'MM'),c.sku_division_name