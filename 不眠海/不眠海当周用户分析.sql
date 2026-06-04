--不眠海当周用户分析
--soberhi_week_user_21646
--老用户购买list——过去一个月（30天有购买），不含当周
with last_month_user_list as(
   select
    a.date_key,
    b.pay_id
    from default.dim_date_ya_v2 a
    left join data_promotion.dm_promotion_store_detl_order_detail_info_da b on b.order_date>=date_add('day',-30,cast(a.date_key as date)) and b.order_date<cast(a.date_key as date)
    where b.dt='${today-1}'
        and b.order_status = 'FINISHED'
        and b.sku_quantity > 0
        and (
            b.sku_division_code = '0716'
            OR b.sku_class_code = '50'
        )
        and b.sku_division_code not in ('5001','5002','5019')
        and coalesce(b.pay_id,'')<>'30112507801894'
        and a.day_of_week_name='星期一'
        GROUP BY 1,2
),
--老用户购买list过去30到60天，不含当周及过去一个月
last_two_month_user_list as(
    select
    a.date_key,
    b.pay_id
    from default.dim_date_ya_v2 a
    left join data_promotion.dm_promotion_store_detl_order_detail_info_da b on b.order_date>=date_add('day',-60,cast(a.date_key as date)) and b.order_date<date_add('day',-30,cast(a.date_key as date))
    where b.dt='${today-1}'
        and b.order_status = 'FINISHED'
        and b.sku_quantity > 0
        and (
            b.sku_division_code = '0716'
            OR b.sku_class_code = '50'
        )
        and b.sku_division_code not in ('5001','5002','5019')
        and coalesce(b.pay_id,'')<>'30112507801894'
        and a.day_of_week_name='星期一'
        GROUP BY 1,2
),
--沉睡用户，过去两个月有购买，一个月无购买
sleep_user_list as (
    select
        a.date_key,
        a.pay_id
    from
        (
            select
                a.date_key,
                a.pay_id,
                case
                    when b.pay_id is null then 0
                    else 1
                end as sleep_user
            from
                last_two_month_user_list a
                left join last_month_user_list b on a.pay_id = b.pay_id and a.date_key=b.date_key
        ) a
    where
        a.sleep_user = 0
    group by 1,2
),
--本周交易用户类型
user_type_week as(
select
    date_trunc('week',date(a.order_date)) as order_week,
    a.pay_id,
    case
        when b.new_type is not null then b.new_type
        when c.pay_id is not null then '老用户'
        when d.pay_id is not null then '沉睡用户'
        else '流失老用户'
    end as user_type
from
    data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_drink.dm_drink_user_new_user_info_da b on a.pay_id = b.user_id and date_trunc('week',date(a.order_date))=date_trunc('week',date(b.order_date)) and b.dt='${today-1}'
    left join last_month_user_list c on a.pay_id = c.pay_id and date_trunc('week',date(a.order_date))=cast(c.date_key as date)
    left join sleep_user_list d on a.pay_id = d.pay_id and date_trunc('week',date(a.order_date))=cast(d.date_key as date)
where
    a.dt = '${today-1}'
    and a.order_status = 'FINISHED'
    and a.sku_quantity > 0
    and (
        a.sku_division_code = '0716'
        OR a.sku_class_code = '50'
    )
    and a.sku_division_code not in ('5001','5002','5019')
    and coalesce(a.pay_id,'')<>'30112507801894'
group by
    1,
    2,
    3
),
--当周营业门店数（去重）
store_info as (
select store_city,store_code,store_name,original_openning_date as opening_date
from default.dim_store_info
where dt='${today-1}'
and store_type='20'
),
store_week_num as(
select
date_trunc('week',date(business_date)) as order_week,
count(distinct store_code) as store_week_num
from
(select a.store_code,
cast(a.record_date as date) as business_date
from data_drink.dm_drink_mid_beetea_business_time a
join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
where a.record_date>=b.opening_date
and sale_time<>'全天不营业'
and a.record_date<='${today-1}'
group by 1,2)
group by 1
)
select
    a.order_week as "周",
    b.store_week_num as "店数",
    count(distinct pay_id) as "用户总计",
    count(distinct case when user_type='饮品新用户' then pay_id end) as "饮品新用户数量",
    count(distinct case when user_type='双新用户' then pay_id end) as "双新用户数量",
    count(distinct case when user_type='老用户' then pay_id end) as "老用户数量",
    count(distinct case when user_type='沉睡用户' then pay_id end) as "沉睡用户数量",
    count(distinct case when user_type='流失老用户' then pay_id end) as "流失老用户数量",
    count(distinct case when user_type='饮品新用户' then pay_id end)*1.0000/count(distinct pay_id) as "饮品新用户占比",
    count(distinct case when user_type='双新用户' then pay_id end)*1.0000/count(distinct pay_id) as "双新用户占比",
    count(distinct case when user_type='老用户' then pay_id end)*1.0000/count(distinct pay_id) as "老用户占比",
    count(distinct case when user_type='沉睡用户' then pay_id end)*1.0000/count(distinct pay_id) as "沉睡用户占比",
    count(distinct case when user_type='流失老用户' then pay_id end)*1.0000/count(distinct pay_id) as "流失老用户占比",
    count(distinct case when user_type='饮品新用户' then pay_id end)/b.store_week_num as "店均饮品新用户数量",
    count(distinct case when user_type='双新用户' then pay_id end)/b.store_week_num as "店均双新用户数量",
    count(distinct case when user_type='老用户' then pay_id end)/b.store_week_num as "店均老用户数量",
    count(distinct case when user_type='沉睡用户' then pay_id end)/b.store_week_num as "店均沉睡用户数量",
    count(distinct case when user_type='流失老用户' then pay_id end)/b.store_week_num as "店均流失老用户数量"
from user_type_week a
left join store_week_num b on a.order_week=b.order_week
group by 1,2
having a.order_week>=timestamp'2021-03-29'