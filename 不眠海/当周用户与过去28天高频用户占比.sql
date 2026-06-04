--当周用户与过去28天高频用户占比
--soberhi_week_high_frequency_user_21647
with sku_info as(
    select
    sku_code,
    sku_name,
    case
        WHEN sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
        WHEN sku_division_name='咖啡' THEN '咖啡'
        ELSE '其他'
END AS sku_division_name
from default.dim_sku_info
where dt='${today-1}'
and sku_class_code='50' and sku_division_code not in ('5001','5002')
and sku_type='动态组合商品'
group by 1,2,3 
),
--过去4周购买频次(单量)的用户list
last_four_week_user_list as(
    select
    a.date_key,
    b.pay_id,
    '总单量' as type,
    count(distinct order_no) as order_num
from default.dim_date_ya_v2 a
left join data_promotion.dm_promotion_store_detl_order_detail_info_da b on b.order_date>=date_add('day',-28,cast(a.date_key as date)) and b.order_date<cast(a.date_key as date) and b.dt='${today-1}'
where 
        b.order_status = 'FINISHED'
        and b.sku_quantity > 0
        and (
            b.sku_division_code = '0716'
            OR b.sku_class_code = '50'
        )
        and b.sku_division_code not in ('5001','5002','5019')
        and coalesce(b.pay_id,'')<>'30112507801894'
        and a.day_of_week_name='星期一'
        and b.order_date>=timestamp'2022-01-01'
        GROUP BY 1,2,3
union
select
    a.date_key,
    b.pay_id,
    '咖啡单量' as type,
    count(distinct order_no) as order_num
from default.dim_date_ya_v2 a
left join data_promotion.dm_promotion_store_detl_order_detail_info_da b on b.order_date>=date_add('day',-28,cast(a.date_key as date)) and b.order_date<cast(a.date_key as date) and b.dt='${today-1}'
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on d.finished_sku_type_code='9' and d.component_sku_code=b.sku_code and d.dt='${today-1}'
join sku_info c on coalesce(d.finished_sku_code,b.sku_code)=c.sku_code and c.sku_division_name='咖啡'
where   b.order_status = 'FINISHED'
        and b.sku_quantity > 0
        and (
            b.sku_division_code = '0716'
            OR b.sku_class_code = '50'
        )
        and b.sku_division_code not in ('5001','5002','5019')
        and coalesce(b.pay_id,'')<>'30112507801894'
        and a.day_of_week_name='星期一'
        and b.order_date>=timestamp'2022-01-01'
        GROUP BY 1,2,3
union
select
    a.date_key,
    b.pay_id,
    '茶饮单量' as type,
    count(distinct order_no) as order_num
from default.dim_date_ya_v2 a
left join data_promotion.dm_promotion_store_detl_order_detail_info_da b on b.order_date>=date_add('day',-28,cast(a.date_key as date)) and b.order_date<cast(a.date_key as date) and b.dt='${today-1}'
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on d.finished_sku_type_code='9' and d.component_sku_code=b.sku_code and d.dt='${today-1}'
join sku_info c on coalesce(d.finished_sku_code,b.sku_code)=c.sku_code and c.sku_division_name='茶饮'
where
        b.order_status = 'FINISHED'
        and b.sku_quantity > 0
        and (
            b.sku_division_code = '0716'
            OR b.sku_class_code = '50'
        )
        and b.sku_division_code not in ('5001','5002','5019')
        and coalesce(b.pay_id,'')<>'30112507801894'
        and a.day_of_week_name='星期一'
        and b.order_date>=timestamp'2022-01-01'
        GROUP BY 1,2,3
),
--当周用户单量及杯量
week_user_order_num as(
    select 
    date_trunc('week',date(a.order_date)) as order_week,
    a.pay_id,
    count(distinct a.order_no) as order_num,
    sum(a.sku_quantity) as sku_quantity_num
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
where a.dt='${today-1}'
        and a.order_status = 'FINISHED'
        and a.sku_quantity > 0
        and (
            a.sku_division_code = '0716'
            OR a.sku_class_code = '50'
        )
        and a.sku_division_code not in ('5001','5002','5019')
        and coalesce(a.pay_id,'')<>'30112507801894'
        and a.order_date>=timestamp'2022-01-01'
        GROUP BY 1,2
),
--本周用户中，过去28天总单量情况
week_user_list_order_num as(
    select 
    a.order_week,
    a.pay_id,
    a.order_num as week_order_num,
    b.order_num as last_28_order_num,
    c.order_num as last_28_tea_order_num,
    d.order_num as last_28_coffe_order_num,
    a.sku_quantity_num as week_sku_quantity
    from week_user_order_num a
    left join last_four_week_user_list b on a.pay_id=b.pay_id and a.order_week=cast(b.date_key as date) and b.type='总单量'
    left join last_four_week_user_list c on a.pay_id=c.pay_id and a.order_week=cast(c.date_key as date) and c.type='茶饮单量'
    left join last_four_week_user_list d on a.pay_id=d.pay_id and a.order_week=cast(d.date_key as date) and d.type='咖啡单量'
)
select
a.order_week,
count(distinct a.pay_id) as "本周用户数量",
sum(a.week_sku_quantity) as "本周杯量",
count(distinct b.pay_id) as "过去28天高频用户数量",
count(distinct c.pay_id) as "过去28天茶饮高频用户数量",
count(distinct d.pay_id) as "过去28天咖啡高频用户数量",
count(distinct e.pay_id) as "过去28天双高频用户数量",
sum(b.week_sku_quantity) as "过去28天高频用户杯量"
from week_user_list_order_num a
left join week_user_list_order_num b on a.order_week=b.order_week and a.pay_id=b.pay_id and b.last_28_order_num>=4
left join week_user_list_order_num c on a.order_week=c.order_week and a.pay_id=c.pay_id and c.last_28_tea_order_num>=4
left join week_user_list_order_num d on a.order_week=d.order_week and a.pay_id=d.pay_id and d.last_28_coffe_order_num>=4
left join week_user_list_order_num e on a.order_week=e.order_week and a.pay_id=e.pay_id and e.last_28_coffe_order_num>=4 and e.last_28_tea_order_num>=4
group by 1