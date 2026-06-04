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
and a.store_code in ('00a33498bfb1ab8daca1343332f12455','eeb5135b2358e37c33e4b11697f8638b','ce6d27cc785228d3c5161d57edd53225','9482330020eef058fc6702cd721908e7','35286dbc966e0f09d7d4e1419f667d1b','55da76bb04a29bc2086e85e6cef69877','7e62c378f88c6cd40a4b57dbb1b7d668','f02f5d15be953fea430b488b285cc56e','ec626fd9af8f7a821d393e47a6d4a5e4','ad9bd7b8c94898c78493890abba8431a','977b71ee6396845039db4419e5b6cfb4','affe44aa36ac427bff43b464ad7c5cc1','558404cb2fcd60117a9c600ae8e83101','04f719fcc8333f6e5c48d4ff826a2f9e','f11624d18d0fb303819c8486e3550bc2','496b478fa161d8e2640ad027e4379da9','693e19da1a399a9cf732de05f09f8846','ec28a46e86170c31b377c15f361be727','07ee7d068135b3cb916ed69da98034f3','fb17452313ea1b9ab0a2c4d86ae5108b','4cdd3caaf45ac8c17a025f24169bd16a','0d5440bda12b3880dfc1bd6529f9763d','004ed4b720d19e12cac595ccc417b82d')
group by 1,2
)
select
a.order_week,
a.store_code,
count(distinct a.store_code) as store_cnt,
sum(sku_quantity) as sku_quantity,
count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as store_day,
sum(sku_quantity)*1.0000/count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as psd
from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a 
join store_business_time d on d.store_code=a.store_code and d.business_date=a.order_date
where a.dt>='${start_dt}'
and a.dt<='${end_dt}'
and a.sku_division_code not in ('5001','5002','5019','5020')
and sku_code not in ('0f57418933cfef1de375300180810bbe','405143d65229957d7d1f89677b2fe634','96c02e1e533b6040ad615803251a1b60','1bc7a7ff4e99ccfca9d235f0cca7b9cd','1f2d8c256b40ce167460076f6fea797e')
and a.is_in_store=1 --有营业日
group by 1,2