--门店维度用户数(周维度)
with store_info as (
select store_city,store_code,store_name,original_openning_date as opening_date
from default.dim_store_info
where dt='${today-1}'
and store_type='20'
),
 
-- 营业店日
store_business_time as(
select
a.store_code,
cast(a.record_date as date) as business_date
from data_drink.dm_drink_mid_beetea_business_time a
join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
where a.record_date>=b.opening_date
and sale_time<>'全天不营业'
group by 1,2
),

-- 商品信息
sku_info as (
select
sku_code,
sku_name,
CASE
   WHEN sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
   WHEN sku_division_name='咖啡' THEN '咖啡'
   ELSE '其他'
END AS sku_division_name
from default.dim_sku_info
where dt='${today-1}'
and sku_class_code='50' and sku_division_code not in ('5001','5002','5019','5020')
and sku_type='动态组合商品'
group by 1,2,3
),

temp_third_part_order as (
SELECT a.order_no,
 CASE
 WHEN a.sub_business_type='EleMe' THEN '饿了么'
 WHEN a.sub_business_type='MeiTuan' THEN '美团'
 WHEN a.sub_business_type='PickUp'
 AND a.business_type='TakeawayV5' THEN '外卖自提'
 WHEN a.sub_business_type IS NULL
 AND a.business_type='TakeawayV5' THEN '其他外卖'
 WHEN a.sub_business_type='delivery'
 AND a.business_type='BeeTea' THEN '自有外卖'
 WHEN a.sub_business_type IS NULL
 AND a.business_type='BeeTea' THEN '门店自提'
 WHEN a.sub_business_type='performance' THEN '加购'
 WHEN a.sub_business_type IS NULL
 AND a.business_type in('SelfPay','SelfPos','SelfPosBliPay','SelfScan') THEN '门店自提'
 ELSE '其他'
 END AS acquisition_type,
 business_type,
 sub_business_type
FROM
 (SELECT order_no,
 json_extract_scalar(bizinfo, '$.businessType') AS business_type,
 json_extract_scalar(bizinfo, '$.subBusinessType') AS sub_business_type,
 json_extract_scalar(orderstatus,'$.name') AS order_status
 FROM default.pdw_order_detail_order_main_di
 WHERE dt >='20220101'
 AND dt<='${today-1}' ) a
),

--近期老客列表
T_30_order_list as(
    select
    a.date_key,
    b.pay_id
    from default.dim_date_ya_v2 a
    left join data_promotion.dm_promotion_store_detl_order_detail_info_da b on b.order_date>=date_add('day',-30,cast(a.date_key as date)) and b.order_date<cast(a.date_key as date) and b.dt='${today-1}'
    where 
        b.order_status = 'FINISHED'
        and b.sku_quantity > 0
        and (
            b.sku_division_code = '0716'
            OR b.sku_class_code = '50'
        )
        and b.sku_division_code not in ('5001','5002','5019','5020')
        and coalesce(b.pay_id,'')<>'30112507801894'
        and b.pay_id is not null
        and a.day_of_week_name='星期一'
        and b.order_date>=timestamp'2022-01-01'
        GROUP BY 1,2
),

--当周用户列表（门店订单维度）
order_list_week as(
select
date_trunc('week',date(a.order_date)) as order_week,
a.vice_store_code,
pay_id,
count(distinct a.order_no) as order_no_num,
sum(sku_quantity) as sku_quantity_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join default.ods_uploads_soberhi_desensitization c on a.vice_store_code=c.store_code_ming
join store_business_time d on c.store_code_mi=d.store_code and d.business_date=a.order_date
where a.dt='${today-1}'
and a.order_status='FINISHED'
and a.sku_quantity>0
and (    a.sku_division_code = '0716'
        OR a.sku_class_code = '50'
        )
and a.sku_division_code not in ('5001','5002','5019','5020')
and coalesce(a.pay_id,'')<>'30112507801894'
and a.pay_id is not null
group by 1,2,3
),

--当周门店用户维度类型
week_sku_user_type as(
    select
    a.order_week,
    a.vice_store_code,
    a.pay_id,
    order_no_num,
    sku_quantity_num,
    case
    when c.new_type is not null then c.new_type
    when d.pay_id is not null then '近期老客'
    ELSE '沉睡激活' end as user_type,
    case
    when order_no_num=1 then '购买一次'
    when order_no_num=2 then '购买二次'
    when order_no_num=3 then '购买三次'
    else '购买四次及以上' end as order_no_num_type
    from order_list_week a
    left join data_drink.dm_drink_user_new_user_info_da c on a.pay_id=c.user_id and a.order_week=date_trunc('week',date(c.order_date)) and c.dt='${today-1}'
    left join T_30_order_list d on a.pay_id=d.pay_id and a.order_week=cast(d.date_key as date)
    group by 1,2,3,4,5,6,7
)

select
order_week,
vice_store_code,
count(distinct pay_id) as "总用户数",
sum(order_no_num) as "总单量",
sum(sku_quantity_num) as "总杯量",
count(distinct case when user_type='饮品新用户' then pay_id end) as "饮品新用户数量",
count(distinct case when user_type='双新用户' then pay_id end) as "双新用户数量",
count(distinct case when user_type='近期老客' then pay_id end) as "近期老客用户数量",
count(distinct case when user_type='沉睡激活' then pay_id end) as "沉睡激活用户数量",
count(distinct case when order_no_num_type='购买一次' then pay_id end) as "购买一次用户数量",
count(distinct case when order_no_num_type='购买二次' then pay_id end) as "购买二次用户数量",
count(distinct case when order_no_num_type='购买三次' then pay_id end) as "购买三次用户数量",
count(distinct case when order_no_num_type='购买四次及以上' then pay_id end) as "购买四次及以上用户数量"
from week_sku_user_type
group by 1,2