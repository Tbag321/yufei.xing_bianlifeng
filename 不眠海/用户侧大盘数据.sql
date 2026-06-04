--过去28天不眠海用户及门店用户数
--soberhi_user_sku_quantity_28_21682
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
group by 1,2
),
--不眠海营业门店对应的BLF门店列表(会剔除不关联便利蜂门店的不眠海门店)
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
    pay_id,
    order_no
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    join blf_store_business_time b on a.store_code=b.blf_store_code and a.order_date=b.record_date
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and coalesce(a.pay_id,'')<>'30112507801894'
    and pay_id is not null
    group by 1,2,3,4,5
),
--不眠海基础订单信息
soberhi_order_info as(
    select
    a.store_code as blf_store_code,
    b.soberhi_store_code as soberhi_store_code,
    a.order_date,
    pay_id,
    order_no,
    sum(sku_quantity) as sku_quantity
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    join blf_store_business_time b on a.store_code=b.blf_store_code and a.order_date=b.record_date
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and a.sku_division_code not in ('5001','5002','5019','5020')
    and coalesce(a.pay_id,'')<>'30112507801894'
    and pay_id is not null
    group by 1,2,3,4,5
),
--不眠海咖啡基础订单信息
soberhi_coffe_order_info as(
    select
    a.store_code as blf_store_code,
    b.soberhi_store_code as soberhi_store_code,
    a.order_date,
    pay_id,
    order_no,
    sum(sku_quantity) as coffe_sku_quantity
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    join blf_store_business_time b on a.store_code=b.blf_store_code and a.order_date=b.record_date
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and a.sku_division_code in ('5003')
    and coalesce(a.pay_id,'')<>'30112507801894'
    and pay_id is not null
    group by 1,2,3,4,5
),
--不眠海茶饮基础订单信息
soberhi_tea_order_info as(
    select
    a.store_code as blf_store_code,
    b.soberhi_store_code as soberhi_store_code,
    a.order_date,
    pay_id,
    order_no,
    sum(sku_quantity) as tea_sku_quantity
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    join blf_store_business_time b on a.store_code=b.blf_store_code and a.order_date=b.record_date
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and a.sku_division_code in ('5004','5005','5006','5007')
    and coalesce(a.pay_id,'')<>'30112507801894'
    and pay_id is not null
    group by 1,2,3,4,5
)
--过去28天用户占比
select
a.date_key,
--b.blf_store_code,
--b.soberhi_store_code,
count(distinct b.pay_id) as blf_user_num,
count(distinct c.pay_id) as soberhi_user_num,
count(distinct c.order_no) as soberhi_order_num,
sum(c.sku_quantity) as soberhi_sku_quantity_num,
count(distinct d.pay_id) as soberhi_coffe_user_num,
count(distinct d.order_no) as soberhi_coffe_order_num,
sum(d.coffe_sku_quantity) as soberhi_coffe_sku_quantity_mun,
count(distinct e.pay_id) as soberhi_tea_user_num,
count(distinct e.order_no) as soberhi_tea_order_num,
sum(e.tea_sku_quantity) soberhi_tea_sku_quantity_mun
from default.dim_date_ya_v2 a
left join blf_order_info b on b.order_date<cast(a.date_key as date) and b.order_date>=date_add('day',-28,cast(a.date_key as date))
left join soberhi_order_info c on b.blf_store_code=c.blf_store_code and b.order_date=c.order_date and b.order_no=c.order_no
left join soberhi_coffe_order_info d on b.blf_store_code=d.blf_store_code and b.order_date=d.order_date and b.order_no=d.order_no
left join soberhi_tea_order_info e on b.blf_store_code=e.blf_store_code and b.order_date=e.order_date and b.order_no=e.order_no
where a.day_of_week_name='星期一'
group by 1