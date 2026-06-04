--饮品站单品销售日报-单品日停售率
with store_info as (
  select
    store_city,
    store_code,
    store_name,
    original_openning_date as opening_date
  from
    default.dim_store_info
  where
    dt = '${today-1}'
    and store_type = '20'
),
-- 门店售卖状态15分钟快照
store_sale_status as(
select
a.order_date,
a.order_time,
a.store_code,
a.main_sku,
a.sale_status,
a.batch,
a.create_time,
a.sku_code_mi--
from
(select
date(format_datetime(date_parse(substr(a.batch, 1, 8), '%Y%m%d'), 'yyyy-MM-dd')) as order_date,
date_parse(a.batch, '%Y%m%d%H%i') as order_time,
a.store_code,
a.main_sku,
a.sale_status,
a.batch,
a.create_time,
b.sku_code_mi--
from default.pdw_cvs_data_real_beetea_sale_status a
left join default.ods_uploads_soberhi_desensitization b on a.main_sku=b.sku_code_ming--
where dt='${today-1}'
) a join store_info b on a.store_code=b.store_code
where a.order_date>=timestamp'2021-01-20 00:00'
and a.order_date<=date_parse('${today-1}','%Y%m%d')
),
store_business_time as (
select
a.store_code,
cast(a.record_date as date) as business_date,
cast(a.sale_start_time as timestamp) as start_time,
cast(a.sale_end_time as timestamp) as end_time
from data_drink.dm_drink_mid_beetea_business_time a
join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
where a.record_date>=b.opening_date
and sale_time<>'全天不营业'
and a.record_date>='2021-01-20'
and a.record_date<='${today-1}'
group by 1,2,3,4
),
working_day as(
SELECT cast(date_key AS date) AS date_key
   FROM dim_date_ya_v2
   WHERE cast(date_key AS date)>=timestamp'2021-01-20 00:00'
   and cast(date_key AS date)<=date_parse('${today-1}','%Y%m%d')
   --and is_working_day=1
),
-- 动销spu
sale_spu as(
select
coalesce(b.finished_sku_code,a.sku_code) as spu_code
--c.sku_code_ming	as spu_code
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on a.sku_code=b.component_sku_code and b.dt='${today-1}' and finished_sku_type_code='9'
--left join default.ods_uploads_soberhi_desensitization c on coalesce(b.finished_sku_code,a.sku_code)=c.sku_code_ming
where a.dt='${today-1}'
and a.order_date>=timestamp'2021-01-20 00:00'
and a.order_date<=date_parse('${today-1}','%Y%m%d')
and (a.sku_division_code='0716' OR a.sku_class_code='50')
and a.sku_division_code not in('5001','5002')
and a.sku_quantity>0
and coalesce(a.pay_id,'')<>'30112507801894'
group by 1
--having count(distinct a.order_date)>=30
),
sku_offline_rate as (
  select
    a.main_sku,
    a.order_date,
    count(
      case
        when sale_status = 'OFFLINE' then batch
      end
    ) as offline_batch,
    count(1) as total_batch
  from
    store_sale_status a
    join store_business_time c on c.store_code = a.store_code
    and c.business_date = a.order_date
    and c.start_time <= a.order_time
    and c.end_time >= a.order_time
    join working_day b on a.order_date=b.date_key
    join sale_spu c on a.main_sku=c.spu_code
     
  group by
    1,2
),
store_offline_rate as (
    select 
    a.store_code,
    a.order_date,
    a.main_sku,
    count(
      case
        when sale_status = 'OFFLINE' then batch
      end
    ) as offline_batch,
    count(1) as total_batch
from 
    store_sale_status a
    join store_business_time c on c.store_code=a.store_code
    and c.business_date=a.order_date
    and c.start_time <= a.order_time
    and c.end_time >= a.order_time
    join working_day b on a.order_date=b.date_key
    join sale_spu c on a.main_sku=c.spu_code
group by 1,2,3
),
store_offline_rate_b as (
    select
    store_code,
    order_date,
    main_sku,
    offline_batch,
    total_batch,
    case when offline_batch=total_batch then 1 else 0 end as store_offline_rate_b
    from store_offline_rate
),
store_offline_rate_c as (
select
order_date,
main_sku,
sum(store_offline_rate_b)*1.0000/count(store_offline_rate_b) as rat
from store_offline_rate_b
group by 1,2)
select
  a.main_sku as sku_code,
  b.sku_name as sku_name,
  CASE
   WHEN sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
   WHEN sku_division_name='咖啡' THEN '咖啡'
   ELSE '其他'
  END AS sku_division_name,
  a.order_date as date_key,
  a.offline_batch,
  a.total_batch,
  a.offline_batch*1.0000/a.total_batch as stop_rate,
  c.rat
from
  sku_offline_rate a
  left join default.dim_sku_info b on a.main_sku=b.sku_code and b.dt='${today-1}'
  left join store_offline_rate_c c on c.order_date=a.order_date and c.main_sku=a.main_sku