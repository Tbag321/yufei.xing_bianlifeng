--商品前三天周期对应不眠海用户数
--商品上新前三天对应日期
with between_day as (
    select
    coalesce(b.finished_sku_code,a.sku_code) as spu,
    min(order_date) as min_order_date,
    min(date_add('day', 2, order_date)) as max_order_date
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on a.sku_code=b.component_sku_code and b.finished_sku_type_code='9' and b.dt='${today-1}'
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_parse('20210101','%%Y%%m%%d')
    and order_date<=date_parse('20220611','%%Y%%m%%d')
    and sku_quantity>0
    AND (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(pay_id,'')<>'30112507801894'
    group by 1
),
--不眠海每天用户数
day_user as(
select
coalesce(b.finished_sku_code,a.sku_code) as spu,
a.order_date,
a.pay_id,
c.new_type
FROM data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on a.sku_code=b.component_sku_code and b.finished_sku_type_code = '9' and b.dt='${today-1}'
left join data_drink.dm_drink_user_new_user_info_da c on c.user_id=a.pay_id and c.order_date=a.order_date and c.dt='${today-1}' 
WHERE a.dt='${today-1}'
AND a.order_status = 'FINISHED'
AND a.sku_quantity>0
AND (a.sku_division_code='0716' OR a.sku_class_code='50')
AND a.sku_division_code NOT IN ('5001','5002')
AND coalesce(a.pay_id,'')<>'30112507801894'
)
select
a.spu,
b.new_type,
count(distinct b.pay_id) as pay_id_num
FROM between_day a
left join day_user b on 1=1
where b.order_date>=a.min_order_date
and b.order_date<=a.max_order_date
group by 1,2