--3月-5月新客购买单sku占新客购买总sku占比
with order_info as(
select
    a.pay_id,
    a.order_date,
    coalesce(b.finished_sku_code, a.sku_code) as sku_code,
    case
        when c.new_type in ('饮品新用户', '双新用户') then '新客'
        else '老客'
    end as user_type
FROM
    data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on a.sku_code = b.component_sku_code
    and b.finished_sku_type_code = '9'
    and b.dt = '${today-1}'
    left join data_drink.dm_drink_user_new_user_info_da c on c.user_id = a.pay_id
    and c.order_date = a.order_date
    and a.order_no = c.order_no
    and c.dt = '${today-1}'
WHERE
    a.dt = '${today-1}'
    and order_status = 'FINISHED'
    and a.order_date >= date_parse('20210301', '%%Y%%m%%d')
    and a.order_date <= date_parse('20220530', '%%Y%%m%%d')
    and sku_quantity > 0
    AND (
        a.sku_division_code = '0716'
        OR a.sku_class_code = '50'
    )
    and sku_division_code not in ('5001', '5002')
    and coalesce(pay_id, '') <> '30112507801894'
),

sku_user_num as
(select
order_date,
sku_code,
count(distinct (case when user_type='新客' then pay_id end)) as pay_id
from order_info
group by 1,2),

new_user_num as
(select
order_date,
count(distinct (case when user_type='新客' then pay_id end)) as new_pay_id
from order_info
group by 1)

SELECT 
A.sku_code,
A.pay_id*1.000/A.new_pay_id
FROM 
(
select
a.sku_code AS sku_code,
sum(a.pay_id) AS pay_id,
sum(b.new_pay_id) AS new_pay_id
from sku_user_num a
left join new_user_num b on a.order_date=b.order_date
group by 1
) A
WHERE A.new_pay_id>0