--soberhi_coffee_bean_exp_store_week_statistics_v1
--咖啡psd，渗透率(动销店日）
with
store_info as(
select store_code
,store_name
,store_city
,store_county
,area_dept_name
,area_manager_namecn
,opening_date
,exp_group
,exp_plan
,own_store_code
,own_store_name
,array_join(array_agg(exp_interval),',') as exp_interval
from 
(
select 
  t1.store_code, 
  t1.store_name, 
  t1.store_city, 
  t1.store_county, 
  t1.area_dept_name, 
  t1.area_manager_namecn,
  substr(t1.original_openning_date, 1, 10) opening_date,
  case when b.store_code is null then '其他' else b.exp_group end as exp_group,
  case when b.store_code is null then '其他' else b.exp_plan end as exp_plan,
  case when b.store_code is null then '无' else b.price_exp end as exp_interval,
  t2.store_code as own_store_code, 
  t2.store_name as own_store_name
from 
  data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
  left join default.ods_uploads_soberhi_desensitization c on c.store_code_mi=t1.store_code 
  join data_promotion.dm_promotion_beetea_store_code_mapping_di t2 on t2.dt = '${today-1}' and c.store_code_ming = t2.beetea_store_code 
  left join data_drink.ods_uploads_ods_uploads_soberhi_coffee_bean_exp_store_v3 b on t1.store_code=b.store_code_mi and b.qualified='1'
 where t1.dt = '${today-1}'
 and t1.store_type = '20' 
  and ( 
    t1.store_status = '1' 
    or ( 
      t1.store_status = '0' 
      and ( 
        t1.original_openning_date >= date_format(date_parse('${today-1}','%%Y%%m%%d'), '%%Y-%%m-%%d') 
        and t1.original_openning_date < '2037-01-01' 
      ) 
    ) 
  )
  ) a group by 1,2,3,4,5,6,7,8,9,10,11
),


date_key as (
select date(date_key) as date_key,
case when date(date_key)>=date_parse('20220303','%%Y%%m%%d') and date(date_key)<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
when date(date_key)>=date_parse('20220505','%%Y%%m%%d') and date(date_key)<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
when date(date_key)>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week
from default.dim_date_ya_v2 
where date(date_key)>=date_parse('20220303','%%Y%%m%%d') and date(date_key)<=date_parse('${today-1}','%%Y%%m%%d')
group by 1,2
),


sku_info as (
select sku_code,
sku_name,
CASE
   WHEN sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
   WHEN sku_division_name='咖啡' THEN '咖啡'
   ELSE '其他'
END AS sku_division_name
from default.dim_sku_info
where dt='${today-1}'
and sku_class_code='50' and sku_division_code not in ('5001','5002')
group by 1,2,3
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
and a.record_date>=date_format(date_parse('20220303','%%Y%%m%%d'),'%%Y-%%m-%%d')
group by 1,2
),









store_sales as (
select a.date_week
,a.exp_group
,a.store_code
,a.sku_division_name
,case when e.sku_quantity is null then a.quantity else (a.quantity-e.sku_quantity) end as soberhi_quantity
,d.user_num as soberhi_user_num
,c.store_day
,case when e.sku_quantity is null then b.quantity else (b.quantity-e.sku_quantity) end as quantity
,b.user_num
,a.store_num
from (
    select case when date(a.order_date)>=date_parse('20220303','%%Y%%m%%d') and date(a.order_date)<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
    when date(a.order_date)>=date_parse('20220505','%%Y%%m%%d') and date(a.order_date)<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
    when date(a.order_date)>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week
    ,d.store_code
    ,d.exp_group
    ,b.sku_division_name
    ,count(distinct a.store_code) as store_num
    ,sum(a.sku_quantity) as quantity
    from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
    join sku_info b on b.sku_code=a.sku_code
    join store_business_time c on a.store_code=c.store_code and a.order_date=c.business_date
    join store_info d on a.store_code=d.store_code
    where a.dt>='20220505'
    and a.is_in_store=1
    and concat(a.store_code,cast(a.order_date as varchar)) not in ('6b324301dfa939ad352d60564f37fedd2022-05-15','6b324301dfa939ad352d60564f37fedd2022-05-16','6b324301dfa939ad352d60564f37fedd2022-05-17','6b324301dfa939ad352d60564f37fedd2022-05-18','6b324301dfa939ad352d60564f37fedd2022-05-19','6b324301dfa939ad352d60564f37fedd2022-05-22','6b324301dfa939ad352d60564f37fedd2022-05-23','baf172023681e92097d93a6c170cce4e2022-05-25','baf172023681e92097d93a6c170cce4e2022-06-03')
    group by 1,2,3,4
) a
left join (
    select case when date(a.order_date)>=date_parse('20220303','%%Y%%m%%d') and date(a.order_date)<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
    when date(a.order_date)>=date_parse('20220505','%%Y%%m%%d') and date(a.order_date)<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
    when date(a.order_date)>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week
    ,a.exp_group
    ,a.store_code
    ,sum(sku_quantity) as quantity
    ,count(distinct pay_id) as user_num
    from (
        select a.order_no,a.pay_id,date(a.order_date) as order_date,c.store_code,c.exp_group,a.sku_quantity from data_md.dm_order_summary_order_detail_user_store_sku_day_di_v1 a
        left join sku_info b on b.sku_code=a.sku_code
        join store_info c on a.store_code=c.own_store_code
        where a.dt>='20220505' and b.sku_code is null
        and concat(a.store_code,cast(a.order_date as varchar)) not in ('6b324301dfa939ad352d60564f37fedd2022-05-15','6b324301dfa939ad352d60564f37fedd2022-05-16','6b324301dfa939ad352d60564f37fedd2022-05-17','6b324301dfa939ad352d60564f37fedd2022-05-18','6b324301dfa939ad352d60564f37fedd2022-05-19','6b324301dfa939ad352d60564f37fedd2022-05-22','6b324301dfa939ad352d60564f37fedd2022-05-23','baf172023681e92097d93a6c170cce4e2022-05-25','baf172023681e92097d93a6c170cce4e2022-06-03')
        union
        select a.order_no,a.pay_id,date(a.order_date) as order_date,a.store_code,b.exp_group,a.sku_quantity from data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
        join store_info b on a.store_code=b.store_code
        where a.dt>='20220505'
        and concat(a.store_code,cast(a.order_date as varchar)) not in ('6b324301dfa939ad352d60564f37fedd2022-05-15','6b324301dfa939ad352d60564f37fedd2022-05-16','6b324301dfa939ad352d60564f37fedd2022-05-17','6b324301dfa939ad352d60564f37fedd2022-05-18','6b324301dfa939ad352d60564f37fedd2022-05-19','6b324301dfa939ad352d60564f37fedd2022-05-22','6b324301dfa939ad352d60564f37fedd2022-05-23','baf172023681e92097d93a6c170cce4e2022-05-25','baf172023681e92097d93a6c170cce4e2022-06-03')
    ) a
    group by 1,2,3
) b on b.date_week=a.date_week and b.exp_group=a.exp_group and b.store_code=a.store_code
left join
(
select case when date(a.order_date)>=date_parse('20220303','%%Y%%m%%d') and date(a.order_date)<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
    when date(a.order_date)>=date_parse('20220505','%%Y%%m%%d') and date(a.order_date)<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
    when date(a.order_date)>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week
    ,d.exp_group
    ,d.store_code
    ,count(distinct case when coalesce(a.store_day,'')<>'' then a.store_day end) as store_day
    from data_md.dm_md_store_sku_soberhi_daily_sales_monitor_di_v1 a
    join sku_info b on b.sku_code=a.sku_code
    join store_business_time c on a.store_code=c.store_code and a.order_date=c.business_date
    join store_info d on a.store_code=d.store_code
    where a.dt>='20220505'
    and a.is_in_store=1
    and concat(a.store_code,cast(a.order_date as varchar)) not in ('6b324301dfa939ad352d60564f37fedd2022-05-15','6b324301dfa939ad352d60564f37fedd2022-05-16','6b324301dfa939ad352d60564f37fedd2022-05-17','6b324301dfa939ad352d60564f37fedd2022-05-18','6b324301dfa939ad352d60564f37fedd2022-05-19','6b324301dfa939ad352d60564f37fedd2022-05-22','6b324301dfa939ad352d60564f37fedd2022-05-23','baf172023681e92097d93a6c170cce4e2022-05-25','baf172023681e92097d93a6c170cce4e2022-06-03')
    group by 1,2,3
) c on c.date_week=a.date_week and c.exp_group=a.exp_group and c.store_code=a.store_code
left join 
(
    select case when date(a.order_date)>=date_parse('20220303','%%Y%%m%%d') and date(a.order_date)<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
    when date(a.order_date)>=date_parse('20220505','%%Y%%m%%d') and date(a.order_date)<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
    when date(a.order_date)>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week
    ,b.sku_division_name
    ,c.exp_group
    ,c.store_code
    ,count(distinct a.pay_id) as user_num from data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
    join sku_info b on b.sku_code=a.sku_code
    join store_info c on a.store_code=c.store_code
    where a.dt>='20220505'
    and concat(a.store_code,cast(a.order_date as varchar)) not in ('6b324301dfa939ad352d60564f37fedd2022-05-15','6b324301dfa939ad352d60564f37fedd2022-05-16','6b324301dfa939ad352d60564f37fedd2022-05-17','6b324301dfa939ad352d60564f37fedd2022-05-18','6b324301dfa939ad352d60564f37fedd2022-05-19','6b324301dfa939ad352d60564f37fedd2022-05-22','6b324301dfa939ad352d60564f37fedd2022-05-23','baf172023681e92097d93a6c170cce4e2022-05-25','baf172023681e92097d93a6c170cce4e2022-06-03')
    group by 1,2,3,4
) d on d.date_week=a.date_week and d.exp_group=a.exp_group and d.sku_division_name=a.sku_division_name and d.store_code=a.store_code
left join
(WITH temp_third_part_order AS
 (SELECT a.order_no,
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
 AND a.business_type IN('SelfPay',
 'SelfPos',
 'SelfPosBliPay',
 'SelfScan') THEN '门店自提'
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
 WHERE dt >='20220521'
 AND dt<='20220523' ) a),
 
order_info AS
 (SELECT DISTINCT t1.pay_id AS user_id,
 t1.date_week,
 t1.order_no,
 t2.acquisition_type,
 t1.order_date,
 t1.order_time,
 t2.business_type,
 t2.sub_business_type,
 t1.order_business_type,
 t1.delivery_type,
 t1.store_code,
 t1.store_name,
 t1.sku_division_name,
 t1.sku_quantity
 FROM
 (SELECT pay_id,
 user_id,
 case when date(order_date)>=date_parse('20220303','%%Y%%m%%d') and date(order_date)<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
    when date(order_date)>=date_parse('20220505','%%Y%%m%%d') and date(order_date)<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
    when date(order_date)>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week,
 order_no,
 order_date,
 order_time,
 order_business_type,
 delivery_type,
 vice_store_code AS store_code,
 vice_store_name AS store_name,
 sku_division_name,
 sum(sku_quantity) as sku_quantity
 FROM data_promotion.dm_promotion_store_detl_order_detail_info_da
 WHERE dt='20220526'
 AND order_status = 'FINISHED'
 AND order_date>=date_parse('20220521','%%Y%%m%%d')
 AND order_date<=date_parse('20220523','%%Y%%m%%d') 
 -- AND sku_quantity>0
 AND (sku_division_code='0716'
 OR sku_class_code='50')
 AND sku_division_code='5003' --咖啡
 and concat(store_code,cast(order_date as varchar)) not in ('6b324301dfa939ad352d60564f37fedd2022-05-15','6b324301dfa939ad352d60564f37fedd2022-05-16','6b324301dfa939ad352d60564f37fedd2022-05-17','6b324301dfa939ad352d60564f37fedd2022-05-18','6b324301dfa939ad352d60564f37fedd2022-05-19','6b324301dfa939ad352d60564f37fedd2022-05-22','6b324301dfa939ad352d60564f37fedd2022-05-23','baf172023681e92097d93a6c170cce4e2022-05-25','baf172023681e92097d93a6c170cce4e2022-06-03')
 GROUP BY 1,2,3,4,5,6,7,8,9,10,11) t1
 LEFT JOIN temp_third_part_order t2 ON t1.order_no=t2.order_no)
 SELECT
 date_week,
 b.exp_group,
 sku_division_name,
 a.store_code,
 --store_name,
 --acquisition_type,
 --business_type,
 --sub_business_type,
 --order_business_type,
 sum(sku_quantity) as sku_quantity
 from order_info a
 left join data_drink.ods_uploads_soberhi_coffee_bean_exp_store_v2 b on a.store_code=b.store_code
 where acquisition_type in ('美团','饿了么')
 and exp_group in ('实验组','对照组')
 group by 1,2,3,4
 ) e on a.date_week=e.date_week and e.exp_group=a.exp_group and e.sku_division_name=a.sku_division_name and a.store_code=d.store_code
),

--新老用户
user_type as(
 select
 a.date_week,
 a.sku_division_name,
 a.exp_group,
 a.user_id,
 a.store_code,
 case when b.user_id is null then 0 else 1 end as is_new
 from
 (select case when date(a.order_date)>=date_parse('20220303','%%Y%%m%%d') and date(a.order_date)<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
    when date(a.order_date)>=date_parse('20220505','%%Y%%m%%d') and date(a.order_date)<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
    when date(a.order_date)>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week
    ,b.sku_division_name,c.exp_group,a.pay_id as user_id,a.store_code from data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
    join sku_info b on b.sku_code=a.sku_code
    join store_info c on a.store_code=c.store_code
    where a.dt>='20220303'
 group by 1,2,3,4,5
) a
 left join
( 
 select 
  case when order_date>=date_parse('20220303','%%Y%%m%%d') and order_date<date_add('day',28,date_parse('20220303','%%Y%%m%%d')) then '0303-0330'
     when order_date>=date_parse('20220505','%%Y%%m%%d') and order_date<date_parse('20220521','%%Y%%m%%d') then '0505-0520'
     when order_date>=date_parse('20220521','%%Y%%m%%d') then '0521至今' end  as date_week,
     user_id
   from data_drink.dm_drink_user_new_user_info_da 
   where dt='${today-1}'
   AND new_type in ('饮品新用户','双新用户')
   AND order_date>=date_parse('20220303','%%Y%%m%%d')
 ) b on a.date_week=b.date_week and a.user_id=b.user_id
 ),


sell_info as (
select a.order_no,a.pay_id as user_id,a.store_code,a.order_date,c.exp_group,b.sku_division_name
from data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
join sku_info b on b.sku_code=a.sku_code
join store_info c on a.store_code=c.store_code
where a.dt>='20220505'
and concat(a.store_code,cast(a.order_date as varchar)) not in ('6b324301dfa939ad352d60564f37fedd2022-05-15','6b324301dfa939ad352d60564f37fedd2022-05-16','6b324301dfa939ad352d60564f37fedd2022-05-17','6b324301dfa939ad352d60564f37fedd2022-05-18','6b324301dfa939ad352d60564f37fedd2022-05-19','6b324301dfa939ad352d60564f37fedd2022-05-22','6b324301dfa939ad352d60564f37fedd2022-05-23','baf172023681e92097d93a6c170cce4e2022-05-25','baf172023681e92097d93a6c170cce4e2022-06-03') 
),

user_uad as (
    select a.date_week
    ,b.exp_group
    ,b.store_code
    ,b.sku_division_name
    ,case when count(distinct b.user_id)=0 then 0 else count(distinct concat(b.user_id,cast(b.order_date as varchar)))*1.0/count(distinct b.user_id) end as uad_28
    ,case when count(distinct case when b.order_date>=date_add('day',-7,a.date_key) then b.user_id end)=0 then 0 else count(distinct concat(case when b.order_date>=date_add('day',-7,a.date_key) then b.user_id end,'|',case when b.order_date>=date_add('day',-7,a.date_key) then cast(b.order_date as varchar) end))*1.0/count(distinct case when b.order_date>=date_add('day',-7,a.date_key) then b.user_id end) end as uad_7
    from date_key a
    left join sell_info b on b.order_date>=date_add('day',-28,a.date_key) and b.order_date<=date_add('day',-1,a.date_key)
    group by 1,2,3,4
),


store_sales_uad as (
select 
a.date_week
,a.exp_group
,a.store_code
,a.sku_division_name
,a.soberhi_quantity7%%
,a.soberhi_user_num
,a.store_day
,a.quantity
,a.user_num
,b.uad_28
,b.uad_7
,a.store_num
from store_sales a 
left join user_uad b on b.exp_group=a.exp_group and b.date_week=a.date_week and a.sku_division_name=b.sku_division_name and a.store_code=b.store_code
)



select 
a.exp_group
,b.exp_plan
,a.sku_division_name
,a.store_code
,b.store_name
,concat(b.store_city,b.store_county) AS store_add
,b.exp_interval
,max(case when date_week='0303-0330' then soberhi_quantity else 0 end) as first_month_soberhi_quantity
,max(case when date_week='0303-0330' then soberhi_user_num else 0 end) as first_month_soberhi_user_num
,max(case when date_week='0303-0330' then store_num else 0 end) as first_month_store_num
,max(case when date_week='0303-0330' then user_num else 0 end) as first_month_user_num
,max(case when date_week='0303-0330' then uad_28 else 0 end) as first_month_uad_28
,max(case when date_week='0303-0330' then uad_7 else 0 end) as first_month_uad_7
,max(case when date_week='0303-0330' then store_day else 0 end) as first_month_store_day
,if(max(case when date_week='0303-0330' then store_day else 0 end)=0,0,max(case when date_week='0303-0330' then soberhi_quantity else 0 end)*1.00/max(case when date_week='0303-0330' then store_day else 0 end)) as first_month_psd
,if(max(case when date_week='0303-0330' then user_num else 0 end)=0,0,max(case when date_week='0303-0330' then soberhi_user_num else 0 end)*1.00/max(case when date_week='0303-0330' then user_num else 0 end)) as first_month_pr
,max(case when date_week='0505-0520' then soberhi_quantity else 0 end) as base_week_soberhi_quantity
,max(case when date_week='0505-0520' then soberhi_user_num else 0 end) as base_week_soberhi_user_num
,max(case when date_week='0505-0520' then store_num else 0 end) as base_week_store_num
,max(case when date_week='0505-0520' then user_num else 0 end) as base_week_user_num
,max(case when date_week='0505-0520' then uad_28 else 0 end) as base_week_uad_28
,max(case when date_week='0505-0520' then uad_7 else 0 end) as base_week_uad_7
,max(case when date_week='0505-0520' then store_day else 0 end) as base_week_store_day
,if(max(case when date_week='0505-0520' then store_day else 0 end)=0,0,max(case when date_week='0505-0520' then soberhi_quantity else 0 end)*1.00/max(case when date_week='0505-0520' then store_day else 0 end)) as base_week_psd
,if(max(case when date_week='0505-0520' then user_num else 0 end)=0,0,max(case when date_week='0505-0520' then soberhi_user_num else 0 end)*1.00/max(case when date_week='0505-0520' then user_num else 0 end)) as base_week_pr
,max(case when date_week='0521至今' then soberhi_quantity else 0 end) as exp_week_soberhi_quantity
,max(case when date_week='0521至今' then soberhi_user_num else 0 end) as exp_week_soberhi_user_num
,max(case when date_week='0521至今' then store_num else 0 end) as exp_week_store_num
,max(case when date_week='0521至今' then user_num else 0 end) as exp_week_user_num
,max(case when date_week='0521至今' then uad_28 else 0 end) as exp_week_uad_28
,max(case when date_week='0521至今' then uad_7 else 0 end) as exp_week_uad_7
,max(case when date_week='0521至今' then store_day else 0 end) as exp_week_store_day
,if(max(case when date_week='0521至今' then store_day else 0 end)=0,0,max(case when date_week='0521至今' then soberhi_quantity else 0 end)*1.00/max(case when date_week='0521至今' then store_day else 0 end)) as exp_week_psd
,if(max(case when date_week='0521至今' then user_num else 0 end)=0,0,max(case when date_week='0521至今' then soberhi_user_num else 0 end)*1.00/max(case when date_week='0521至今' then user_num else 0 end)) as exp_week_pr
from store_sales_uad a
join store_info b on a.store_code=b.store_code
group by 1,2,3,4,5,6,7