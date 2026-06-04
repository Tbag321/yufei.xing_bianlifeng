-- 饮品站门店
with store_info as (
  select
    store_city,
    store_code,
    store_name,
    original_openning_date as opening_date
  from
    default.dim_store_info
  where
    dt = '${today-1}'
    and store_type = '20'
),

-- 饮品站商品
sku_info as (
  select 
  a.sku_code,
  a.old_spu_code,
  b.sku_name,
  a.sku_division_name,
  a.sku_type,
  a.sku_division_code,
  a.sku_state_code
  from
  (
  select
    a.sku_code,
    coalesce(b.old_spu_code,a.sku_code) as old_spu_code,
    case when  sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
         when  sku_division_name='咖啡' THEN '咖啡'
         else '其他' end as sku_division_name,
    sku_type,
    sku_division_code,
    sku_state_code
  from
    default.dim_sku_info a 
    left join data_drink.ods_uploads_soberhi_coffee_new_spu_mapping b on a.sku_code=b.new_spu_code
    where a.dt = '${today-1}'
    and a.sku_class_code = '50'
    and a.sku_division_code not in ('5001', '5002')
    and a.sku_type='动态组合商品'
  group by 1,2,3,4,5,6
  ) a join default.dim_sku_info b on a.old_spu_code=b.sku_code and b.dt='${today-1}' and b.sku_type='动态组合商品'
  
),

-- 门店每日营业状态
store_business_time as (
  select 
  a.store_code,
  cast(a.record_date as date) as business_date,
  cast(a.sale_start_time as TIMESTAMP) as start_time,
  cast(a.sale_end_time as TIMESTAMP) as end_time
  from data_drink.dm_drink_mid_beetea_business_time a
  join store_info b on a.store_code=b.store_code and a.dt='${today-1}'
  where a.record_date>=b.opening_date
  and sale_time<>'全天不营业'
  and a.record_date>='2021-03-01'
  group by 1,2,3,4
),

--用户双新订单号
user_double_first_order as (
SELECT
    user_id,
    order_date,
    order_time,
    order_no,
    new_type
from
    data_drink.dm_drink_user_new_user_info_da
where
    dt = '${today-1}'
    and new_type in('双新用户','饮品新用户')
),

-- 订单明细
order_info as (
select
    order_no,
    order_date,
    order_time,
    store_city,
    vice_store_code as store_code,
    pay_id as user_id,
    sku_code,
    delivery_type,
    order_business_type,
    payable_price-profit_price as cost,
    sku_quantity
  from
    data_promotion.dm_promotion_store_detl_order_detail_info_da
  where
    dt = '${today-1}'
    and order_status = 'FINISHED'
    and order_date >= date('2021-03-31')
    and store_type = '20'
    and sku_class_code = '50'
    and sku_division_code not in ('5001','5002')
    and coalesce(pay_id,'')<>'30112507801894'
),

order_detail as (
  select
    order_no,
    user_id,
    delivery_type,
    order_business_type,
    store_city,
    store_code,
    b.old_spu_code as sku_code,
    order_date,
    order_time,
    sku_division_code,
    sum(sku_quantity) as sku_quantity,
    sum(cost) as cost
  from
    (
      select
        a.order_no,
        a.user_id,
        a.delivery_type,
        a.order_business_type,
        a.store_city,
        a.store_code,
        coalesce(b.finished_sku_code, a.sku_code) as sku_code,
        a.order_date,
        a.order_time,
        a.sku_quantity,
        a.cost
      from order_info a 
        left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt = '${today-1}'
        and finished_sku_type_code = '9' and b.component_sku_code = a.sku_code
        join store_business_time c on c.store_code = a.store_code and date(c.business_date) = a.order_date
    ) a
    join sku_info b on a.sku_code=b.sku_code
    group by 1,2,3,4,5,6,7,8,9,10
),

-- 外卖率
waimai_rate as (
  select
    sku_code,
    date_trunc('week', date(order_date)) as order_week,
    count(distinct order_no) as finished_order_num,
    count(distinct case when delivery_type = 'DELIVERY' or order_business_type = 'TAKEAWAYV5' then order_no end) as waimai_order_num,
    sum(case when delivery_type = 'DELIVERY' or order_business_type = 'TAKEAWAYV5' then sku_quantity end) as waimai_quantity,
    sum(cost) as cost 
  from order_detail a
  where order_date >= date('2022-01-03')
  group by 1,2
),

--取消率
cancel_rate as (
  select
    a.sku_code,
    date_trunc('week', date(a.order_date)) as order_week,
    count(distinct order_no) as order_num,
    count(distinct case when order_status = 'CANCELLED' then order_no end) as cancel_order_num,
    count(distinct case when pay_status in ('PAY_SUCCESS','REFUND_SUCCESS') then order_no end) as pay_order_num,
    count(distinct case when order_status = 'CANCELLED' and pay_status in ('PAY_SUCCESS','REFUND_SUCCESS') then order_no end) as pay_cancel_order_num
    from data_promotion.dm_promotion_store_detl_order_detail_info_da a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt = '${today-1}'
    and b.finished_sku_type_code = '9' and b.component_sku_code = a.sku_code
    join sku_info c on coalesce(b.finished_sku_code, a.sku_code)=c.sku_code
    where a.dt = '${today-1}'
    and a.order_date >= date('2022-01-03')
    and a.store_type='20'
    and a.sku_class_code = '50'
    and a.sku_division_code not in ('5001', '5002')
    and coalesce(a.pay_id,'')<>'30112507801894'
  group by 1,2
),


--停售率
--打包商品和动态组合商品对应关系
sku_9_5 as (
  select
    c.old_spu_code as sku_code_9,
    b.finished_sku_code as sku_code_5
  from
    (
      select
        finished_sku_code,
        component_sku_code
      from
        data_md.dm_md_dim_sku_components_info_package_sku_v1
      where
        dt = '${today-1}'
        and finished_sku_type_code = '9'
        group by 1,2
    ) a
    join (
      select
        finished_sku_code,
        component_sku_code
      from
        data_md.dm_md_dim_sku_components_info_package_sku_v1
      where
        dt = '${today-1}'
        and finished_sku_type_code = '5'
    ) b on b.component_sku_code = a.component_sku_code
    join sku_info c on a.finished_sku_code=c.sku_code and c.sku_state_code = 1
  group by 1,2
    
),


store_status_info AS (
  SELECT
    substr(batch, 1, 8) AS order_date,
    substr(batch, 9, 4) AS order_time,
    b.store_city,
    t.store_code,
    main_sku,
    sale_status,
    batch
  FROM
    default.pdw_cvs_data_real_beetea_sale_status AS t
    join store_info b on b.store_code = t.store_code
  WHERE
    dt = '${today-1}'
    and substr(batch, 1, 8) >= '20220103'
  GROUP BY 1,2,3,4,5,6,7
),

sku_div_detail_info AS (
  select
    store_city,
    store_code,
    date(format_datetime(date_parse(order_date, '%%Y%%m%%d'), 'yyyy-MM-dd')) as order_date,
    date_parse(batch, '%%Y%%m%%d%%H%%i') as order_time,
    main_sku,
    sale_status,
    batch
  from
    store_status_info
),



-- 商品停售率
sku_offline_rate as (
  select
    coalesce(b.sku_code_9, a.main_sku) as main_sku,
    date_trunc('week', a.order_date) as order_week,
    count(case when sale_status = 'OFFLINE' then batch end) as offline_batch,
    count(1) as total_batch
  from
    sku_div_detail_info a
    left join sku_9_5 b on b.sku_code_5 = a.main_sku
    join store_business_time c on c.store_code = a.store_code
    and date(c.business_date) = a.order_date
    and c.start_time <= a.order_time
    and c.end_time >= a.order_time
  group by 1,2
),

--平均制作时长
store_make_time as (
  select
    a.sku_code,
    date_trunc('week', date(a.order_date)) as order_week,
    sum(a.avg_make_time * a.sku_quantity) as make_time,
    sum(a.sku_quantity) as make_quantity
    from (
      select
        a.order_no,
        a.store_city,
        a.store_code,
        a.order_date,
        a.sku_cnt,
        date_diff('second', start_time, end_time) / 60.0000 / sku_cnt as avg_make_time,
        c.old_spu_code as sku_code,
        b.sku_quantity
      from
        (
          select
            a.order_no,
            c.store_city,
            a.store_code,
            a.order_date,
            a.sku_cnt,
            min(case when status = 1 then create_time end) as start_time,
            max(case when status = 2 then create_time end) as end_time
          from
            data_md.dm_soberhi_store_order_product_process_node_di_v1 a
            join store_info c on c.store_code = a.store_code
          where
            a.dt >= '20220103'
            and a.order_status = 'FINISHED'
            and a.status > 0
            and a.sku_cnt > 0
          group by 1,2,3,4,5
        ) a
        left join order_detail b on b.order_no = a.order_no
        join sku_info c on b.sku_code=c.sku_code
        and b.sku_quantity > 0
        group by 1,2,3,4,5,6,7,8
    ) a
  group by 1,2
),


sku_complain as (
  select 
  a.complain_week,
  b.old_spu_code as sku_code,
  sum(a.complain_num) as complain_num
  from 
  (select
    date_trunc('week', complain_date) as complain_week,
    coalesce(b.finished_sku_code, a.sku_code) as sku_code,
    count(distinct complain_id) as complain_num
  from
    data_userresearch.dwa_customer_experience_drink_request_detail_v1 a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt = '${today-1}'
    and finished_sku_type_code = '9'
    and b.component_sku_code = a.sku_code
    where a.dt = '${today-1}'
    and type_level_2 = '口感'
    and complain_date >= date('2022-01-03')
  group by 1,2
  ) a join sku_info b on a.sku_code=b.sku_code
  group by 1,2
),


sku_first_date as (
  select
    sku_code,
    min(order_date) as first_date
  from
    order_detail
  group by 1
),

--双新用户
user_info as (
  select
    sku_code,
    date_trunc('week', date(a.order_date)) as order_week,
    count(distinct a.user_id) as user_num,
    count(distinct case when b.order_no is not null and b.new_type='饮品新用户' then a.user_id end) as new_user_num,
    count(distinct case when b.order_no is not null and b.new_type='双新用户' then a.user_id end) as double_new_user_num,
    count(distinct concat(a.user_id, '|', cast(a.order_date as varchar))) as user_date
    from order_detail a
    left join user_double_first_order b on b.user_id = a.user_id and b.order_no = a.order_no
    group by 1,2
),

-- 套打品
reuse_product as (
SELECT a.business_code AS sku_code
FROM pdw_bach_baseinfo_goblin_tag_value a
join pdw_bach_baseinfo_goblin_tag b on a.tag_code = b.code and a.dt='${today-1}' and b.dt='${today-1}'
WHERE a.tag_code = b.code
AND a.value = '是'
AND a.tag_code ='100275' 
group by 1
),

-- 每周总杯量
total_sku_quantity as(
SELECT date_trunc('week', order_date) AS order_week,
       sum(sku_quantity) AS total_quantity
FROM order_detail a 
left join reuse_product b on a.sku_code=b.sku_code
where sku_division_code not in('5019','5020')
group by 1
)





select a.*,
b.sku_name,
b.sku_division_name as sku_type
from 
(select
  a.sku_code,
  a.order_week,
  a.store_num,
  a.sale_store_num,
  a.quantity,
  a.sell_price,
  a.origin_payable_price,
  a.store_day,
  h.first_date,
  b.cost,
  b.finished_order_num,
  b.waimai_order_num,
  c.order_num as total_order_num,
  c.cancel_order_num,
  c.pay_order_num,
  c.pay_cancel_order_num,
  d.offline_batch,
  d.total_batch,
  e.make_time,
  e.make_quantity,
  f.user_num,
  f.new_user_num,
  f.user_date,
  f.double_new_user_num,
  i.complain_num,
  j.total_quantity
  from (
    select
      e.old_spu_code as sku_code,
      date_trunc('week', date(a.order_date)) as order_week,
      count(distinct a.store_code) as store_num,
      count(distinct case when a.sku_quantity > 0 then a.store_code end) sale_store_num,
      sum(a.sku_quantity) as quantity,
      sum(a.sell_price) as sell_price,
      sum(a.origin_payable_price) as origin_payable_price,
      count(distinct case when coalesce(a.store_day, '') <> '' then a.store_day end) as store_day
    from
      data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
      left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt = '${today-1}'
      and finished_sku_type_code = '9' and b.component_sku_code = a.sku_code
      join store_business_time d on d.store_code = a.store_code and date(d.business_date) = a.order_date
      join sku_info e on coalesce(b.finished_sku_code, a.sku_code)=e.sku_code
    where
      a.dt >= '20220103'
      and coalesce(a.store_day, '') <> ''
      and a.is_in_store=1
      and a.sku_division_code not in('5019','5020')
    group by 1,2
  ) a
  left join sku_first_date h on h.sku_code = a.sku_code
  left join waimai_rate b on b.sku_code = a.sku_code and b.order_week = a.order_week
  left join cancel_rate c on c.sku_code = a.sku_code and c.order_week = a.order_week
  left join sku_offline_rate d on d.main_sku = a.sku_code and d.order_week = a.order_week
  left join store_make_time e on e.sku_code = a.sku_code and e.order_week = a.order_week
  left join user_info f on f.sku_code = a.sku_code and f.order_week = a.order_week
  left join sku_complain i on i.sku_code = a.sku_code and i.complain_week = a.order_week
  left join total_sku_quantity j on j.order_week=a.order_week
  left join reuse_product k on k.sku_code=a.sku_code
  where a.order_week = date('2022-06-06') and k.sku_code is null
  ) a
  left join sku_info b on b.sku_code=a.sku_code
  where b.sku_division_code not in ('5019','5020')
  and b.sku_type = '动态组合商品'
  and a.sale_store_num>0
  
  
  
 
  
  