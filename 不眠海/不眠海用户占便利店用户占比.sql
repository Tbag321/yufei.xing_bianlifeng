--过去28天不眠海用户及门店用户数
--过去4周(28天)不眠海营业门店列表
with store_info as(
select
store_city, 
store_code,
store_name,
original_openning_date as opening_date
from default.dim_store_info
where dt='${today-1}'
and store_type='20'
),
--营业店日
store_business_time as(
select
a.store_code,
a.record_date
from data_drink.dm_drink_mid_beetea_business_time a
left join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
where a.record_date>b.opening_date
and a.sale_time<>'全天不营业'
and a.store_code in ('00a33498bfb1ab8daca1343332f12455','eeb5135b2358e37c33e4b11697f8638b','ce6d27cc785228d3c5161d57edd53225','9482330020eef058fc6702cd721908e7','35286dbc966e0f09d7d4e1419f667d1b','55da76bb04a29bc2086e85e6cef69877','7e62c378f88c6cd40a4b57dbb1b7d668','f02f5d15be953fea430b488b285cc56e','ec626fd9af8f7a821d393e47a6d4a5e4','ad9bd7b8c94898c78493890abba8431a','977b71ee6396845039db4419e5b6cfb4','affe44aa36ac427bff43b464ad7c5cc1','558404cb2fcd60117a9c600ae8e83101','04f719fcc8333f6e5c48d4ff826a2f9e','f11624d18d0fb303819c8486e3550bc2','496b478fa161d8e2640ad027e4379da9','693e19da1a399a9cf732de05f09f8846','ec28a46e86170c31b377c15f361be727','07ee7d068135b3cb916ed69da98034f3','fb17452313ea1b9ab0a2c4d86ae5108b','4cdd3caaf45ac8c17a025f24169bd16a','0d5440bda12b3880dfc1bd6529f9763d','004ed4b720d19e12cac595ccc417b82d')
--and a.record_date>=date_format(date_add('day',-28,current_date),'%%Y-%%m-%%d')
--and a.record_date<=date_format(date_add('day',-1,current_date),'%%Y-%%m-%%d')
group by 1,2
),
--过去4周（28天）不眠海营业门店对应的BLF门店列表(会剔除不关联便利蜂门店的不眠海门店)
blf_store_business_time as(
select
soberhi_store_code,
blf_store_code,
blf_store_name,
cast(record_date as date) as record_date
from(
    select
    c.store_code as soberhi_store_code,
    a.store_code as blf_store_code,
    a.store_name as blf_store_name,
    c.record_date
    from data_promotion.dm_promotion_beetea_store_code_mapping_di a
    left join default.ods_uploads_soberhi_desensitization b on a.beetea_store_code=b.store_code_ming
    left join store_business_time c on b.store_code_mi=c.store_code
    where a.dt='${today-1}')
where record_date is not null
),
--门店订单基础信息(含不眠海)
blf_order_info as(
    select
    a.store_code as blf_store_code,
    b.soberhi_store_code as soberhi_store_code,
    a.order_date,
    pay_id
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    join blf_store_business_time b on a.store_code=b.blf_store_code and a.order_date=b.record_date
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3,4
),
--不眠海基础订单信息
soberhi_order_info as(
    select
    a.store_code as blf_store_code,
    b.soberhi_store_code as soberhi_store_code,
    a.order_date,
    pay_id
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    join blf_store_business_time b on a.store_code=b.blf_store_code and a.order_date=b.record_date
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and a.sku_division_code not in ('5001','5002','5019','5020')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3,4
)
select
date_trunc('week',date(a.order_date)) as week,
a.blf_store_code,
a.soberhi_store_code,
--a.order_date,
count(distinct a.pay_id),
count(distinct b.pay_id)
from blf_order_info a left join soberhi_order_info b on a.blf_store_code=b.blf_store_code and a.order_date=b.order_date
group by 1,2,3