--店*周维度用户分析
--每周用户总订单量（截止当周之前）
with total_order_week as (
SELECT
a.date_key,
b.pay_id,
count(DISTINCT b.order_no) as order_no_num
from default.dim_date_ya_v2 a
left join data_promotion.dm_promotion_store_detl_order_detail_info_da b
on b.order_date<cast(a.date_key as date)
WHERE a.day_of_week_name='星期一'
and b.dt='${today-1}'
and b.order_status = 'FINISHED'
        and b.sku_quantity > 0
        and (
            b.sku_division_code = '0716'
            OR b.sku_class_code = '50'
        )
        and b.sku_division_code not in ('5001','5002')
        and b.order_date>=timestamp'2021-03-31'
        and coalesce(b.pay_id,'')<>'30112507801894'
        GROUP BY 1,2
),

--每周用户订单量
day_user_order as(
select
date_trunc('week',date(order_date)) as order_week,
pay_id,
count(distinct order_no) as order_no_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da
where dt='${today-1}'
and order_status = 'FINISHED'
        and sku_quantity > 0
        and (
            sku_division_code = '0716'
            OR sku_class_code = '50'
        )
        and sku_division_code not in ('5001','5002')
        and order_date>=timestamp'2021-03-31'
        and coalesce(pay_id,'')<>'30112507801894'
        group by 1,2),

--当周和上周和上周之前订单量
week_lastweek_order as(
select
date_trunc('week',date(a.order_date)) as order_week,
a.store_code,
a.vice_store_code,
a.vice_store_name,
a.pay_id,
d.new_type as week_new_type,--当周新客类型
e.new_type as last_week_new_type,--上周新客类型
b.order_no_num as last_week_order_num,--上周订单量
c.order_no_num-coalesce(b.order_no_num,0) as histore_order_num,--上周以前订单量
count(distinct a.order_no) as week_order_no_num--当周订单量
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join day_user_order b on b.order_week=date_add('day',-7,date_trunc('week',date(a.order_date))) and b.pay_id=a.pay_id--上周
left join total_order_week c on cast(c.date_key as date)=date_add('day',0,date_trunc('week',date(a.order_date))) and c.pay_id=a.pay_id--上周之前
left join data_drink.dm_drink_user_new_user_info_da d on a.pay_id=d.user_id and date_trunc('week',date(a.order_date))=date_trunc('week',date(d.order_date))
left join data_drink.dm_drink_user_new_user_info_da e on a.pay_id=e.user_id and date_trunc('week',date(e.order_date))=date_add('day',-7,date_trunc('week',date(a.order_date)))
where a.dt='${today-1}'
and a.order_status = 'FINISHED'
        and a.sku_quantity > 0
        and (
            a.sku_division_code = '0716'
            OR a.sku_class_code = '50'
        )
        and sku_division_code not in ('5001','5002')
        and a.order_date>=timestamp'2021-03-31'
        and coalesce(a.pay_id,'')<>'30112507801894'
group by 1,2,3,4,5,6,7,8,9),

user_type as(
select
a.*,
case 
when week_new_type is not null and week_order_no_num=1 then a.week_new_type
when week_new_type is not null and week_order_no_num>1 then '当周新转老'
when last_week_new_type is not null and last_week_order_num=1 and week_order_no_num>=1 then '上周新转老'
when histore_order_num=1 and  week_order_no_num>=1 then '历史新转老'
else '老用户' end as user_type
from week_lastweek_order a
),

week_user_type as(
select
a.store_code,
b.beetea_store_code,
b.beetea_store_name,
order_week,
user_type,
count(distinct pay_id) as user_type_num
from user_type a
left join data_promotion.dm_promotion_beetea_store_code_mapping_di b on a.store_code=b.store_code and b.dt='${today-1}'
group by 1,2,3,4,5
)

select
beetea_store_code,
beetea_store_name,
order_week,
sum(case when user_type='饮品新用户'then user_type_num else 0 end) as "饮品新用户数量",
sum(case when user_type='双新用户'then user_type_num else 0 end) as "双新用户数量",
sum(case when user_type='当周新转老'then user_type_num else 0 end) as "当周新转老用户数量",
sum(case when user_type='上周新转老'then user_type_num else 0 end) as "上周新转老用户数量",
sum(case when user_type='历史新转老'then user_type_num else 0 end) as "历史新转老用户数量",
sum(case when user_type='老用户'then user_type_num else 0 end) as "老用户数量"
from week_user_type
group by 1,2,3