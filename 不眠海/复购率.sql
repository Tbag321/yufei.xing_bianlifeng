--UAD7
with date_key as (
select date(date_key) as date_key
from default.dim_date_ya_v2
where date(date_key)>=date_parse('20210601','%%Y%%m%%d') and date(date_key)<=date_add('day', -1, CURRENT_DATE)
group by 1
),
order_base as(
SELECT a.pay_id AS user_id
       ,a.order_no
       ,a.order_date
   FROM data_promotion.dm_promotion_store_detl_order_detail_info_da a
   left join data_md.ods_uploads_sku_spu_division_mapping b on a.sku_code=b.sku_code
   WHERE dt=date_format(date_add('day', -1, CURRENT_DATE), '%%Y%%m%%d')
     AND order_status = 'FINISHED'
     and order_date>=date_parse('20210601','%%Y%%m%%d')
     AND order_date<=date_add('day', -1, CURRENT_DATE)
     AND sku_quantity>0
     AND (a.sku_division_code='0716' or a.sku_class_code='50')
     AND a.sku_division_code NOT IN ('5001','5002')
     AND order_no<>'10164007072786' --味全每日C葡萄汁
     AND pay_id<>'30112507801894'
     AND pay_id IS NOT NULL
group by 1,2,3
),
  
user_uad as (
    select
    a.date_key
    ,count(distinct concat(b.user_id,cast(b.order_date as varchar))) as user_day
    ,count(distinct b.user_id) as user_cnt
    ,case when count(distinct b.user_id)=0 then 0 else count(distinct concat(b.user_id,cast(b.order_date as varchar)))*1.0000/count(distinct b.user_id) end as uad_7
    from date_key a
    left join order_base b on b.order_date>=date_add('day', -7, a.date_key) and b.order_date<=date_add('day', -1, a.date_key)
    group by 1
)
  
select
date_trunc('week',date_key) as date_week
,avg(user_day) as user_day
,avg(user_cnt) as user_cnt
,round(avg(uad_7)*1.00,4) as uad_7
from user_uad
group by 1
order by 1 desc