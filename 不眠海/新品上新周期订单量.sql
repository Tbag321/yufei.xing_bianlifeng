--新品上新周期订单量
with min_day as (
    select
    coalesce(b.finished_sku_code,a.sku_code) as sku_code,
    min(order_date) as min_order_date
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on a.sku_code=b.component_sku_code and b.finished_sku_type_code='9' and b.dt='${today-1}'
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_parse('20210101','%%Y%%m%%d')
    and order_date<=date_parse('20220611','%%Y%%m%%d')
    and sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(pay_id,'')<>'30112507801894'
    group by 1
),
one_week_user_list as(
    select
    sku_code,
    pay_id,
    case
        when new_type in ('饮品新用户','双新用户') then '新用户' else '老用户' 
    end as new_type
    from
    (select
        coalesce(d.finished_sku_code,a.sku_code) as sku_code,
        a.pay_id,
        c.new_type,
        row_number () over (partition by concat(coalesce(d.finished_sku_code,a.sku_code),a.pay_id)) as row_number
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on a.sku_code=d.component_sku_code and d.finished_sku_type_code = '9' and d.dt = '${today-1}'
    left join min_day b on coalesce(d.finished_sku_code,a.sku_code)=b.sku_code
    left join data_drink.dm_drink_user_new_user_info_da c on c.user_id=a.pay_id and c.order_date=a.order_date and c.dt='${today-1}'
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and a.order_date>=date_add('day', 0, b.min_order_date)
    and a.order_date<=date_add('day', 2, b.min_order_date)
    and sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3)
    where row_number=1
),
one_week_user as (
    select 
    '前3天' as one_week,
    a.sku_code,
    a.new_type,
    a.order_no,
    count(distinct a.pay_id) as user_cut
    from (
        select
        coalesce(d.finished_sku_code,a.sku_code) as sku_code,
        a.pay_id,
        c.new_type,
        count(distinct order_no) as order_no
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on a.sku_code=d.component_sku_code and d.finished_sku_type_code = '9' and d.dt = '${today-1}'
    left join min_day b on coalesce(d.finished_sku_code,a.sku_code)=b.sku_code
    left join one_week_user_list c on coalesce(d.finished_sku_code,a.sku_code)=c.sku_code and a.pay_id=c.pay_id
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_add('day', 0, b.min_order_date)
    and order_date<=date_add('day', 2, b.min_order_date)
    and sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3
    )a
    group by 1,2,3,4
),
two_week_user as (
    select
    '前7天' as two_week, 
    a.sku_code,
    a.new_type,
    a.order_no,
    count(distinct a.pay_id) as user_cut
    from (
        select
        coalesce(d.finished_sku_code,a.sku_code) as sku_code,
        a.pay_id,
        c.new_type,
        count(distinct order_no) as order_no
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on a.sku_code=d.component_sku_code and d.finished_sku_type_code = '9' and d.dt = '${today-1}'
    left join min_day b on coalesce(d.finished_sku_code,a.sku_code)=b.sku_code
    join one_week_user_list c on coalesce(d.finished_sku_code,a.sku_code)=c.sku_code and a.pay_id=c.pay_id
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_add('day', 0, b.min_order_date)
    and order_date<=date_add('day', 6, b.min_order_date)
    and sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3
    )a
    group by 1,2,3,4
),
three_week_user as (
    select
    '前14天' as three_week,  
    a.sku_code,
    a.new_type,
    a.order_no,
    count(distinct a.pay_id) as user_cut
    from (
        select
        coalesce(d.finished_sku_code,a.sku_code) as sku_code,
        a.pay_id,
        c.new_type,
        count(distinct order_no) as order_no
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on a.sku_code=d.component_sku_code and d.finished_sku_type_code = '9' and d.dt = '${today-1}'
    left join min_day b on coalesce(d.finished_sku_code,a.sku_code)=b.sku_code
    join one_week_user_list c on coalesce(d.finished_sku_code,a.sku_code)=c.sku_code and a.pay_id=c.pay_id
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_add('day', 0, b.min_order_date)
    and order_date<=date_add('day', 13, b.min_order_date)
    and sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3
    )a
    group by 1,2,3,4
),
four_week_user as (
    select
    '前28天' as four_week, 
    a.sku_code,
    a.new_type,
    a.order_no,
    count(distinct a.pay_id) as user_cut
    from (
        select
        coalesce(d.finished_sku_code,a.sku_code) as sku_code,
        a.pay_id,
        c.new_type,
        count(distinct order_no) as order_no
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on a.sku_code=d.component_sku_code and d.finished_sku_type_code = '9' and d.dt = '${today-1}'
    left join min_day b on coalesce(d.finished_sku_code,a.sku_code)=b.sku_code
    join one_week_user_list c on coalesce(d.finished_sku_code,a.sku_code)=c.sku_code and a.pay_id=c.pay_id
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_add('day', 0, b.min_order_date)
    and order_date<=date_add('day', 27, b.min_order_date)
    and sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3
    )a
    group by 1,2,3,4
),
five_week_user as (
    select
    '前56天' as five_week, 
    a.sku_code,
    a.new_type,
    a.order_no,
    count(distinct a.pay_id) as user_cut
    from (
        select
        coalesce(d.finished_sku_code,a.sku_code) as sku_code,
        a.pay_id,
        c.new_type,
        count(distinct order_no) as order_no
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 d on a.sku_code=d.component_sku_code and d.finished_sku_type_code = '9' and d.dt = '${today-1}'
    left join min_day b on coalesce(d.finished_sku_code,a.sku_code)=b.sku_code
    join one_week_user_list c on coalesce(d.finished_sku_code,a.sku_code)=c.sku_code and a.pay_id=c.pay_id
    WHERE a.dt='${today-1}'
    and order_status = 'FINISHED'
    and order_date>=date_add('day', 0, b.min_order_date)
    and order_date<=date_add('day', 55, b.min_order_date)
    and sku_quantity>0
    and (a.sku_division_code='0716' OR a.sku_class_code='50')
    and sku_division_code not in ('5001','5002')
    and coalesce(a.pay_id,'')<>'30112507801894'
    group by 1,2,3
    )a
    group by 1,2,3,4
)
select * from one_week_user
UNION
select * from two_week_user
UNION
select * from three_week_user
UNION
select * from four_week_user
UNION
select * from five_week_user