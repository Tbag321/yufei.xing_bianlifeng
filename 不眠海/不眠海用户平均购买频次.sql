--不眠海用户平均购买频次--hive
--app_data_drink_average_order_num_da
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
left join store_info b on a.store_code=b.store_code
where a.dt='${today-1}'
and a.record_date>b.opening_date
and a.sale_time<>'全天不营业'
group by a.store_code,a.record_date
),

--不眠海基础订单信息
soberhi_order_info as(
    select
    order_date,
    pay_id,
    order_no
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join default.ods_uploads_soberhi_desensitization c on a.vice_store_code=c.store_code_ming
    join store_business_time b on c.store_code_mi=b.store_code and a.order_date=cast(b.record_date as date)
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and a.sku_division_code not in ('5001','5002','5019','5020')
    and coalesce(a.pay_id,'')<>'30112507801894'
    and pay_id is not null
    group by order_date,pay_id,order_no
)

select
trunc(order_date, 'MM') as order_month,
count(distinct pay_id) as pay_id_num,
count(distinct order_no) as order_no_num,
count(distinct order_no)*1.0000/count(distinct pay_id) as average_order_num
from soberhi_order_info
where trunc(order_date, 'MM')=add_months(trunc(date(current_date), 'MM'),-1)
group by trunc(order_date, 'MM')