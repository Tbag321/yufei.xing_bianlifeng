with sku_spu_mapping_base as(
SELECT finished_sku_code AS sku_code,
       component_sku_code
FROM data_md.dm_md_dim_sku_components_info_package_sku_v1
where dt=date_format(date_add('day', -1, CURRENT_DATE), '%%Y%%m%%d') and finished_sku_type_code='9'
GROUP BY 1,2
UNION
SELECT sku_code,
       component_sku_code
FROM default.mid_order_sku_component_detail_v3_di
WHERE dt<=date_format(date_add('day', -1, CURRENT_DATE), '%%Y%%m%%d')
GROUP BY 1,2
),

-- 取sku对应的第一个spu
sku_spu_mapping as (
SELECT b.component_sku_code,
       b.sku_code
FROM
  ( SELECT component_sku_code,
           sku_code,
           row_number() over(partition BY component_sku_code) AS rnk
   FROM sku_spu_mapping_base) b
WHERE b.rnk=1
),

sku_info as (
SELECT sku_code,
      sku_name,
      sku_division_code,
      sku_division_name
FROM default.dim_sku_info
WHERE dt=date_format(date_add('day', -1, CURRENT_DATE), '%%Y%%m%%d')
  AND sku_class_code='50'
  AND sku_division_code NOT IN ('5001','5002')
GROUP BY 1,2,3,4
),


order_base as(
select 
a.order_date,
a.order_no,
a.order_business_type,
a.activity_id,
a.coupon_id,
a.sku_code,
a.sku_name,
a.sku_quantity,
a.sell_price,
a.origin_price,
a.discount,
a.profit_price,
CASE
    WHEN b.sku_code is not null then a.sku_code 
    WHEN b.sku_code is null and c.component_sku_code is not null then c.sku_code
    ELSE a.sku_code
END AS spu_code
from 
(SELECT order_date,
       order_no,
       order_business_type,
       activity_id,
       coupon_id,
       sku_code,
       sku_name,
       SUM (cast(sku_quantity AS int)) AS sku_quantity,
       SUM (sell_price) AS sell_price,
       SUM (profit_price) AS profit_price,
       SUM (origin_payable_price) AS origin_price,
       round(SUM(origin_payable_price)*1.00/SUM(sell_price),2) as discount
FROM data_promotion.dm_promotion_supplement_order_detail
WHERE dt='${today-1}'
  AND order_status = 'FINISHED'
  AND order_date>=date_parse('20220521','%%Y%%m%%d')
  AND order_date<=date_add('day', -1, CURRENT_DATE)
  AND (sku_division_code='0716' OR sku_class_code='50')
  AND sku_division_code NOT IN ('5001','5002')
  AND pay_id<>'30112507801894'
  AND cast(sku_quantity as int) >0
  AND sku_class_code='50'
GROUP BY 1,2,3,4,5,6,7) a
LEFT JOIN sku_spu_mapping b ON a.sku_code=b.sku_code
LEFT JOIN sku_spu_mapping c ON a.sku_code=c.component_sku_code
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13
),
coupon_usage as(
SELECT json_extract_scalar(track_data, '$.consumeorderNoStr') AS order_no,
       amount ,
       coalesce(b.inout_type,'无') as inout_type,
       coalesce(b.channel_tag,'无') as channel_tag
FROM default.dw_promotion_coupon_usage a
JOIN data_promotion.ods_uploads_beetea_new_user_coupon_id b ON a.coupon_id=b.coupon_id
WHERE dt=date_format(date_add('day', -1, CURRENT_DATE), '%%Y%%m%%d')
  AND coupon_status = 'USED'
GROUP BY 1,2,3,4
UNION
SELECT json_extract_scalar(track_data, '$.consumeorderNoStr') AS order_no ,
       amount ,
       '店内' AS inout_type ,
       '券包' AS channel_tag
FROM default.dw_promotion_coupon_usage a
WHERE dt=date_format(date_add('day', -1, CURRENT_DATE), '%%Y%%m%%d')
  AND json_extract_scalar(track_data, '$.strategyCode') in ('coupon_drink_0406')
  AND coupon_status = 'USED'
GROUP BY 1,2
UNION
SELECT json_extract_scalar(track_data, '$.consumeorderNoStr') AS order_no ,
       amount ,
       '店内' AS inout_type ,
       '饮品站月卡' AS channel_tag
FROM default.dw_promotion_coupon_usage a
WHERE dt=date_format(date_add('day', -1, CURRENT_DATE), '%%Y%%m%%d')
  AND json_extract_scalar(track_data, '$.strategyCode') in ('soberHiOfflinePackage','coupon_drink_0328')
  AND coupon_status = 'USED'
GROUP BY 1,2
),


order_info as(
SELECT a.order_date,
       b.y_m,
       a.order_no,
       a.order_business_type,
       a.activity_id,
       a.coupon_id,
       a.sku_code,
       a.sku_quantity,
       a.sell_price,
       a.origin_price,
       a.profit_price,
       a.discount,
       a.spu_code,
       a.spu_name,
       a.sku_division_code,
       CASE
           WHEN sku_division_name IN('茶类茶饮','果类茶饮','乳类茶饮','2-奶茶类') THEN '茶类饮品'
           WHEN sku_division_name IN('1-咖啡类','咖啡') THEN '咖啡饮品'
           WHEN sku_division_name IN('3-鸡尾酒','酒类饮品') THEN '酒类饮品'
           ELSE '其他'
       END AS sku_division_name
FROM
  (SELECT a.order_date,
          a.order_no,
          a.order_business_type,
          a.activity_id,
          a.coupon_id,
          a.sku_code,
          a.sku_quantity,
          a.sell_price,
          a.origin_price,
          a.profit_price,
          a.discount,
          a.spu_code,
          regexp_replace(regexp_replace(regexp_replace(CASE WHEN b.sku_code IS NULL THEN a.sku_name ELSE b.sku_name END,'（','('),'）',')'),'\(.*\)|-外卖|\d+?(oz)+|；|^冰','') AS spu_name,
          b.sku_division_code,
          CASE
              WHEN c.sku_code IS NULL THEN b.sku_division_name
              ELSE c.type
          END AS sku_division_name
   FROM order_base a
   LEFT JOIN sku_info b ON a.spu_code=b.sku_code
   LEFT JOIN data_promotion.ods_uploads_dm_promotion_beetea_sku_list_info c ON a.spu_code=c.sku_code) a
   JOIN(
        SELECT cast(date_key AS date) AS date_key,
        substr(date_key,1,7) AS y_m
        FROM dim_date_ya_v2
        WHERE cast(date_key AS date)>=date_parse('20220421', '%%Y%%m%%d')
        AND cast(date_key AS date)<CURRENT_DATE
   ) b on a.order_date=b.date_key
   
),
channel_info as(
select 
a.y_m,
a.order_date,
a.sku_division_name,
a.sku_division_code,
a.spu_name,
a.spu_code,
case 
 when a.activity_id in ('1220097152088511','1220096002712500','1220098252152640','1220098282513420','1220098683782831','1220100863580561','1220102545379765','1220102585889578','1220103869278665','1220104176346466','1220104795356296','1220104977826805','1220104957952057','1220106926807724','1220106922110146'
) then '清库存'
 when activity_id in ('1220099923321398','1220099905803134') then '39/59大促'
 when a.activity_id = '1220108063033445' then '生日季'
 when a.activity_id = '1220110298379209' then '划线价促销活动'
 when a.activity_id in ('1220111257490795','1220111274441058') then '奥奥草莓&北海道dirty49折促销'
 when a.activity_id = '1220111400414779' then '第二件N折'
 when a.order_business_type IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and activity_id is not null then '加购-有活动'
 when a.order_business_type IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and activity_id is null then '加购-无活动'
 when a.order_business_type not in ('SELFPOS','SELFPOSBLIPAY','SELFPAY') and (inout_type = '店外' and b.channel_tag = '口令分享') then '惊喜红包'
 when a.order_business_type not in ('SELFPOS','SELFPOSBLIPAY','SELFPAY') and b.channel_tag is not null then b.channel_tag
 when a.order_business_type not in ('SELFPOS','SELFPOSBLIPAY','SELFPAY') and a.activity_id <> '-1' then '其他活动'
 when a.order_business_type not in ('SELFPOS','SELFPOSBLIPAY','SELFPAY') and (a.activity_id = '-1' or b.channel_tag is null) then '无活动未用券'
 when (a.coupon_id is null and a.activity_id = '-1')  or b.channel_tag is null then '无活动未用券'
 when b.channel_tag='无' then '无活动未用券'
 ELSE '其他活动' END AS activity_type,
sum(sku_quantity) as sku_quantity,
sum(a.sell_price) as sell_price,
sum(a.origin_price) as origin_price,
sum(a.profit_price) as profit_price
from order_info a
LEFT JOIN coupon_usage b
ON a.order_no=b.order_no
where a.order_date>=timestamp'2022-06-05'
and a.order_date<=timestamp'2022-06-05'
and spu_code='32cbfaccc1a5f4302d29cc7d0b74a77f'
group by 1,2,3,4,5,6,7
)
SELECT * from channel_info