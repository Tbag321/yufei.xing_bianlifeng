--分小时psd数据
with store_info as (
select store_city,store_code,store_name,original_openning_date as opening_date from default.dim_store_info
where dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d')
and store_type='20'
),
 
-- 营业店日
store_business_time as (
 select
 store_code,
 date(business_date) as business_date,
 work_type,
 cast(concat(business_date,' ',start_time) as timestamp) as start_time,
 cast(concat(business_date,' ',end_time) as timestamp) as end_time
 ,business_time
 from (
 select
 a.store_code
 ,a.business_date
 ,case when t.business_time='24小时营业' or t.business_time='全天不营业' then t.business_time
 else '正常营业' end as work_type
 ,case when t.business_time='24小时营业' then '00:00:00'
 when t.business_time='全天不营业' then NULL else concat(split(t.business_time,'-')[1],':00')
 end as start_time
 ,case when t.business_time='24小时营业' then '23:59:59'
 when t.business_time='全天不营业' then NULL
 else concat(split(t.business_time,'-')[2],':00') end as end_time
 ,t.business_time
 from (
 select
 a.store_code,
 b.opening_date,
 json_extract_scalar(a.information_info,'$.销售日期') as business_date,
 json_extract_scalar(a.information_info,'$.门店营业时间') as business_time
 from data_smartorder.dm_ordering_information_system_order_detail_parse a
 join store_info b on b.store_code=a.store_code
 where a.dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d')
 and l1_category_name='门店情报'
 and l2_category_name='门店营业状态'
 and a.status='1'
 ) a
 cross join unnest(split(business_time, ',')) as t (business_time)
 where a.business_date>=a.opening_date
 and a.business_date>='2021-03-31'
 ) a
 where work_type<>'全天不营业'
),
order_info as (
SELECT user_id,
 order_no,
 order_date,
 sku_code,
 sku_name,
 sku_division_code,
 sku_quantity,
 store_code,
 CASE
 WHEN hour>=7
 AND a.hour<8 THEN '7-8'
 WHEN a.hour>=8
 AND a.hour<9 THEN '8-9'
 WHEN a.hour>=9
 AND a.hour<10 THEN '9-10'
 WHEN a.hour>=10
 AND a.hour<11 THEN '10-11'
 WHEN a.hour>=11
 AND a.hour<12 THEN '11-12'
 WHEN a.hour>=12
 AND a.hour<13 THEN '12-13'
 WHEN a.hour>=13
 AND a.hour<14 THEN '13-14'
 WHEN a.hour>=14
 AND a.hour<15 THEN '14-15'
 WHEN a.hour>=15
 AND a.hour<16 THEN '15-16'
 WHEN a.hour>=16
 AND a.hour<17 THEN '16-17'
 WHEN a.hour>=17
 AND a.hour<18 THEN '17-18'
 WHEN a.hour>=18
 AND a.hour<19 THEN '18-19'
 WHEN a.hour>=19
 AND a.hour<20 THEN '19-20'
 WHEN a.hour>=20
 AND a.hour<21 THEN '20-21'
 ELSE '其他'
 END AS hour
 from
 (SELECT pay_id AS user_id,
 order_no,
 order_date,
 sku_code,
 sku_name,
 sku_division_code,
 sku_quantity,
 vice_store_code as store_code,
 hour(order_time) as hour
 FROM data_promotion.dm_promotion_store_detl_order_detail_info_da
 WHERE dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d')
 AND order_status = 'FINISHED'
 and order_date>=date_parse('20220517','%%Y%%m%%d')
 AND order_date<=date_add('day',-2,current_date)
 AND sku_quantity>0
 AND (sku_division_code='0716' or sku_class_code='50')
 AND sku_division_code NOT IN ('5001','5002')
 AND pay_id<>'30112507801894'
 AND order_no<>'10164007072786' --味全每日C葡萄汁
 AND pay_id IS NOT NULL
 group by 1,2,3,4,5,6,7,8,9) a
),
 
sku_spu_mapping_base as(
SELECT finished_sku_code AS sku_code,
 component_sku_code
FROM data_md.dm_md_dim_sku_components_info_package_sku_v1
where dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d') and finished_sku_type_code='9'
GROUP BY 1,
 2
),
-- 取sku对应的第一个spu
sku_spu_mapping as (
SELECT b.component_sku_code,
 b.sku_code
FROM (
 (SELECT component_sku_code,
 sku_code,
 row_number() over(partition BY component_sku_code) AS rnk
 FROM sku_spu_mapping_base) a) b
WHERE b.rnk=1
),
 
sku_info as (
SELECT sku_code,
 sku_name,
 sku_division_code,
 sku_division_name
FROM default.dim_sku_info
WHERE dt=date_format(CURRENT_DATE - interval '1' DAY,'%%Y%%m%%d')
 AND sku_class_code='50'
 AND sku_division_code NOT IN ('5001','5002')
GROUP BY 1,2,3,4
),
 
sku_order as(
SELECT
 a.sku_code,
 a.sku_name,
 CASE
 WHEN b.sku_code is not null then a.sku_code
 WHEN b.sku_code is null and c.component_sku_code is not null then c.sku_code
 ELSE a.sku_code
 END AS spu_code,
 a.sku_division_code
FROM order_info a
LEFT JOIN sku_spu_mapping b ON a.sku_code=b.sku_code
LEFT JOIN sku_spu_mapping c on a.sku_code=c.component_sku_code
group by 1,2,3,4
),
 
sku_division_mapping as(
SELECT sku_code,
 spu_code,
 spu_name,
 sku_division_code,
 CASE
 WHEN sku_division_name IN('茶类茶饮','果类茶饮','乳类茶饮','2-奶茶类') THEN '茶类饮品'
 WHEN sku_division_name IN('1-咖啡类','咖啡') THEN '咖啡饮品'
 WHEN sku_division_name IN('3-鸡尾酒','酒类饮品') THEN '酒类饮品'
 ELSE '其他'
 END AS sku_division_name
FROM
 (SELECT
 a.sku_code,
 a.spu_code,
 regexp_replace(regexp_replace(regexp_replace(CASE WHEN b.sku_code IS NULL THEN a.sku_name ELSE b.sku_name END,'（','('),'）',')'),'\(.*\)|-外卖|废弃|新|\d+?(oz)+?|；|^冰','') AS spu_name,
 b.sku_division_code,
 CASE
 WHEN c.sku_code IS NULL THEN b.sku_division_name
 ELSE c.type
 END AS sku_division_name
 FROM sku_order a
 LEFT JOIN sku_info b ON a.spu_code=b.sku_code
 LEFT JOIN data_promotion.ods_uploads_dm_promotion_beetea_sku_list_info c ON a.spu_code=c.sku_code) a
group by 1,2,3,4,5
)
select
a.sku_division_name
,a.spu_name
,a.hour
,a.quantity
,b.store_day
,a.quantity*1.0000/b.store_day as psd
from (
select
sku_division_name
,spu_name
,CASE
 WHEN hour(order_time)>=7
 AND hour(order_time)<8 THEN '7-8'
 WHEN hour(order_time)>=8
 AND hour(order_time)<9 THEN '8-9'
 WHEN hour(order_time)>=9
 AND hour(order_time)<10 THEN '9-10'
 WHEN hour(order_time)>=10
 AND hour(order_time)<11 THEN '10-11'
 WHEN hour(order_time)>=11
 AND hour(order_time)<12 THEN '11-12'
 WHEN hour(order_time)>=12
 AND hour(order_time)<13 THEN '12-13'
 WHEN hour(order_time)>=13
 AND hour(order_time)<14 THEN '13-14'
 WHEN hour(order_time)>=14
 AND hour(order_time)<15 THEN '14-15'
 WHEN hour(order_time)>=15
 AND hour(order_time)<16 THEN '15-16'
 WHEN hour(order_time)>=16
 AND hour(order_time)<17 THEN '16-17'
 WHEN hour(order_time)>=17
 AND hour(order_time)<18 THEN '17-18'
 WHEN hour(order_time)>=18
 AND hour(order_time)<19 THEN '18-19'
 WHEN hour(order_time)>=19
 AND hour(order_time)<20 THEN '19-20'
 WHEN hour(order_time)>=20
 AND hour(order_time)<21 THEN '20-21'
 ELSE '其他' END AS hour
,sum(a.sku_quantity) as quantity
from data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
left join sku_division_mapping b on a.sku_code=b.sku_code
join store_business_time d on d.store_code=a.store_code and date(d.business_date)=a.order_date
where a.dt>='20220228'
and a.dt<='20220313'
group by 1,2,3) a
left join (
select
sku_division_name
,spu_name
,count(distinct concat(d.store_code,'|',cast(d.business_date as varchar))) as store_day
from data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
left join sku_division_mapping b on a.sku_code=b.sku_code
join store_business_time d on d.store_code=a.store_code and date(d.business_date)=a.order_date
where a.dt>='20220517'
and a.dt<='2022524'
group by 1,2
) b on a.sku_division_name=b.sku_division_name and a.spu_name=b.spu_name
where a.sku_division_name is not null