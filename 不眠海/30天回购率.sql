--30天回购率
--门店基础信息
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

--营业店日(营业日期大于2022年3月1号)
store_business_time as(
    select
    a.store_code,
    a.record_date,
    date_add('day',30,cast(a.record_date as date)) as last_30_day
    from data_drink.dm_drink_mid_beetea_business_time a
    left join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
    where a.record_date>b.opening_date
    and a.record_date>='2022-03-01'
    and a.record_date<='2022-06-22'
    and a.sale_time<>'全天不营业'
    group by 1,2,3
),

--范围门店店日（取3月1日-5月22日，从计算日起往后31天，至少有22天营业）
store_range_business_time as(
    select
    a.store_code,
    a.record_date,
    count(distinct b.record_date) as store_num
    from store_business_time a
    left join store_business_time b on a.store_code=b.store_code and cast(b.record_date as date) between cast(a.record_date as date) and cast(a.last_30_day as date)
    where a.record_date>='2022-03-01'
    and a.record_date<='2022-05-22'
    group by 1,2
    having count(distinct b.record_date)>=22
),

--获取用户列表（该用户在范围门店店日下单且是新用户）
pay_list as(
    select
    a.pay_id,
    a.order_date,
    date_add('day',30,cast(a.order_date as date)) as last_30_day,
    d.new_type
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join default.ods_uploads_soberhi_desensitization b on a.vice_store_code=b.store_code_ming
    join store_range_business_time c on a.order_date=cast(c.record_date as date) and b.store_code_mi=c.store_code
    left join data_drink.dm_drink_user_new_user_info_da d on a.pay_id=d.user_id and a.order_no=d.order_no and d.dt='${today-1}'
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and a.sku_division_code not in ('5001','5002','5019')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3,4
    having d.new_type in ('饮品新用户','双新用户') 
),

--获取用户首单起，31天之内的订单数（含首单）
pay_list_order_num as(
    select
    b.pay_id,
    count(distinct a.order_no) as order_no_num
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join pay_list b on a.pay_id=b.pay_id and a.order_date between b.order_date and b.last_30_day
    where a.dt='${today-1}'
    and a.order_status='FINISHED'
    and a.sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and a.sku_division_code not in ('5001','5002','5019')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1
)

select
    order_no_num,
    count(distinct pay_id) as pay_id_num
    from pay_list_order_num
group by 1
