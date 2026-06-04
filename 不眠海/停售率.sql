--succses
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
a.create_time
from
(select
date(format_datetime(date_parse(substr(batch, 1, 8), '%%Y%%m%%d'), 'yyyy-MM-dd')) as order_date,
date_parse(batch, '%%Y%%m%%d%%H%%i') as order_time,
store_code,
b.sku_code_mi as main_sku,
sale_status,
batch,
create_time
from default.pdw_cvs_data_real_beetea_sale_status a
left join default.ods_uploads_soberhi_desensitization b on a.main_sku=b.sku_code_ming
where dt='${today-1}'
) a join store_info b on a.store_code=b.store_code
where a.order_date>=timestamp'2021-01-20 00:00'
and a.order_date<=date_parse('${today-1}','%%Y%%m%%d')
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
   and cast(date_key AS date)<=date_parse('${today-1}','%%Y%%m%%d')
   --and is_working_day=1
),
-- 动销spu
sale_spu as(
select
--coalesce(b.finished_sku_code,a.sku_code) as spu_code
c.sku_code_mi	as spu_code
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on a.sku_code=b.component_sku_code and b.dt='${today-1}' and finished_sku_type_code='9'
left join default.ods_uploads_soberhi_desensitization c on coalesce(b.finished_sku_code,a.sku_code)=c.sku_code_mi
where a.dt='${today-1}'
and a.order_date>=timestamp'2021-01-20 00:00'
and a.order_date<=date_parse('${today-1}','%%Y%%m%%d')
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
)
select
  a.main_sku as spu_code,
  b.sku_name as spu_name,
  CASE
   WHEN sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
   WHEN sku_division_name='咖啡' THEN '咖啡'
   ELSE '其他'
  END AS sku_division_name,
  a.order_date as date_key,
  a.offline_batch,
  a.total_batch,
  a.offline_batch*1.0000/a.total_batch as stop_rate
from
  sku_offline_rate a
  left join default.dim_sku_info b on a.main_sku=b.sku_code and b.dt='${today-1}'
where b.sku_code in ('d7a0ab5a09cf10a7a93905d2b6713cb2','8624d9545f2ce674d2e8f0274e31a214','f35ca5f2167d8557a07f1f93a52c9240','0001194770913aacd3a3d7917908a2e6','9eab095ca1ccb35f9d6dc8c155682b5e','4b1b40c58685dc91040c3b2bf1585f21','d195b2ebe66567dd2a96f8455cc625a8','ca9699984c0bc493169059022f1eef59','9405fe8795123cb6b35cb71661d2951d')