--用户购买产品后，N天复购率
--3月-5月新客购买的list
with new_user_list as(
    select
        a.pay_id,
        coalesce(b.finished_sku_code, a.sku_code) as sku_code,
        a.order_date,
        a.order_no,
        case
            when c.new_type in ('饮品新用户', '双新用户') then '新用户'
            else '老用户'
        end as user_type
    from
        data_promotion.dm_promotion_store_detl_order_detail_info_da a
        left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on finished_sku_type_code = '9'
        and a.sku_code = b.component_sku_code
        and b.dt = '${today-1}'
        left join data_drink.dm_drink_user_new_user_info_da c on a.pay_id = c.user_id
        and a.order_date = c.order_date
        and a.order_no = c.order_no
        and c.dt = '${today-1}'
    where
        a.dt = '${today-1}'
        and a.order_status = 'FINISHED'
        and sku_quantity > 0
        and (
            a.sku_division_code = '0716'
            or a.sku_class_code = '50'
        )
        and sku_division_code not in ('5001', '5002')
        and coalesce(a.pay_id, '') <> '30112507801894'
        and a.order_date >= timestamp '2022-03-01'
        and a.order_date <= timestamp '2022-05-31'
        and c.new_type in ('饮品新用户', '双新用户')
    group by
        1,
        2,
        3,
        4,
        5
),

three_days_repurchase_list as(
    select
        a.pay_id,
        coalesce(b.finished_sku_code, a.sku_code) as sku_code,
        a.order_date,
        a.order_no
    from
        data_promotion.dm_promotion_store_detl_order_detail_info_da a
        left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on finished_sku_type_code = '9'
        and a.sku_code = b.component_sku_code
        and b.dt = '${today-1}'
        left join new_user_list c on a.pay_id = c.pay_id
        and coalesce(b.finished_sku_code, a.sku_code) = c.sku_code
        and a.order_no <> c.order_no
    where
        a.dt = '${today-1}'
        and date_diff('day', c.order_date, a.order_date) >= 0
        and date_diff('day', c.order_date, a.order_date) <= 2
        and a.order_status = 'FINISHED'
        and sku_quantity > 0
        and (
            a.sku_division_code = '0716'
            or a.sku_class_code = '50'
        )
        and sku_division_code not in ('5001', '5002')
        and coalesce(a.pay_id, '') <> '30112507801894'
) 

--three_days_repurchase_rate
select
    a.sku_code,
    count(distinct a.pay_id),
    count(distinct b.pay_id),
    count(distinct b.pay_id) * 1.0000 / count(distinct a.pay_id) * 1.0000
from
    new_user_list a
    left join three_days_repurchase_list b on b.sku_code = a.sku_code
group by
    1