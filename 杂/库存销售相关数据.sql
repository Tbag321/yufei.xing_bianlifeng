select
t.order_date as `日期`
 --,t.order_time as `时间`
 ,t.store_code as `门店编码`
 ,t.store_name as `门店名称`
 
 --销售方式
 --,case when
 --t.order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then '外卖'
 --else '到店' end as `销售方式`
 

 --商品中分类
 ,case when t.sku_division_code in ('6101','6102') then '香烟'
 when t.sku_class_code in ('01','02','04','08','10','11','13') then '风幕日配短保'
 when t.sku_class_code in ('21') then '常温日配短保'
 when t.sku_class_code in ('12') then '风幕12乳饮'
 when t.sku_class_code in ('03','05','06') and t.sku_division_code in ('0301','0304') then '日配热餐米饭'
 when t.sku_class_code in ('03','05','06') and t.sku_division_code not in ('0301','0304') then '日配制作类'
 when t.sku_class_code in ('07') then '咖啡豆浆自助饮品'
 when t.sku_class_code in ('30','31','32','33','42') then '水饮(白酒洋酒饮料冰淇淋等)'
 when t.sku_class_code in ('34','35','36','37','38','40','41') then '非日配食品（薯片饼干香肠泡面糖巧等）' 
 else '其它' end as `商品中分类`

,t.sku_name as `商品名称`
,sum(t.sku_quantity) as `销售数量`
,sum(t.sell_price) as `折前金额`
,sum(t.payable_price) as `折后金额` 
 
from data_build.dw_order_sku_promotion_v1 t --订单明细表
left join data_build.dm_site_selection_project_feature_info_di a on t.store_code = a.store_code and a.dt = 20221114
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and t.order_date between '2023-10-16' and '2023-10-30'
 and t.store_type = '0'
 and t.pay_status = 'PAY_SUCCESS'
 and t.sku_quantity > '0'
 and t.sku_class_code not in ('86','50')
 and t.store_city = '北京市'
 and a.location_type in ('办公','办公+其他')
 group by
t.order_date
 --,t.order_time
 ,t.store_code
 ,t.store_name
 
 --销售方式
 --,case when
 --t.order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') then '外卖'
 --else '到店' end
 

 --商品中分类
 ,case when t.sku_division_code in ('6101','6102') then '香烟'
 when t.sku_class_code in ('01','02','04','08','10','11','13') then '风幕日配短保'
 when t.sku_class_code in ('21') then '常温日配短保'
 when t.sku_class_code in ('12') then '风幕12乳饮'
 when t.sku_class_code in ('03','05','06') and t.sku_division_code in ('0301','0304') then '日配热餐米饭'
 when t.sku_class_code in ('03','05','06') and t.sku_division_code not in ('0301','0304') then '日配制作类'
 when t.sku_class_code in ('07') then '咖啡豆浆自助饮品'
 when t.sku_class_code in ('30','31','32','33','42') then '水饮(白酒洋酒饮料冰淇淋等)'
 when t.sku_class_code in ('34','35','36','37','38','40','41') then '非日配食品（薯片饼干香肠泡面糖巧等）' 
 else '其它' end

,t.sku_name







with sku_info as
(select
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name
from default.dim_sku_info
where dt = 20231129
group by
sku_code
,sku_name
,sku_class_code
,sku_division_code
,sku_division_name),

store_info as(
select
store_code
,store_name
from default.dim_store_info
where dt = 20231129
group by
store_code
,store_name),

store_sku_list as(
select a.*
from(
select
from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,a.store_code
,c.store_name
,a.sku_code
,b.sku_division_name
,case when b.sku_division_code in ('6101','6102') then '香烟'
 when b.sku_class_code in ('01','02','04','08','10','11','13') then '风幕日配短保'
 when b.sku_class_code in ('21') then '常温日配短保'
 when b.sku_class_code in ('12') then '风幕12乳饮'
 when b.sku_class_code in ('03','05','06') and b.sku_division_code in ('0301','0304') then '日配热餐米饭'
 when b.sku_class_code in ('03','05','06') and b.sku_division_code not in ('0301','0304') then '日配制作类'
 when b.sku_class_code in ('07') then '咖啡豆浆自助饮品'
 when b.sku_class_code in ('30','31','32','33','42') then '水饮(白酒洋酒饮料冰淇淋等)'
 when b.sku_class_code in ('34','35','36','37','38','40','41') then '非日配食品（薯片饼干香肠泡面糖巧等）' 
 else '其它' end as sku_class
,b.sku_name
,a.quantity
,row_number() over (partition by concat(a.dt,a.store_code,a.sku_code) order by a.quantity desc) as rn
from default.dw_inventory_store_snapshot_ha_v1 a
left join sku_info b on a.sku_code = b.sku_code
left join store_info c on a.store_code = c.store_code
where from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') between '2023-11-27' and '2023-11-29'
--and a.store_code = '100078005'
and a.is_available = '1'
--and a.quantity <> '0'
and store_type = '0'
and substring(a.sku_code,1,1) <>'9'
and substring(a.sku_code,1,2) not in ('81','82','83','84','86','87','89')
) a
where rn = 1),

sale_list as
(select
t.order_date
,t.store_code
,t.store_name
,t.sku_code
,t.sku_name
,sum(t.sku_quantity) as sku_quantity
,sum(t.sell_price) as sell_price
,sum(t.payable_price) as payable_price
 
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and t.order_date between '2023-11-27' and '2023-11-29'
 and t.store_type = '0'
 and t.pay_status = 'PAY_SUCCESS'
 and t.sku_quantity > '0'
 and t.sku_class_code not in ('86','50')
 and t.store_city = '北京市'
 --and t.store_code = '100078005'
 group by
t.order_date
,t.store_code
,t.store_name
,t.sku_code
,t.sku_name),

sale_store_list as
(select
t.store_code
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and t.order_date between '2023-11-27' and '2023-11-29'
 and t.store_type = '0'
 and t.pay_status = 'PAY_SUCCESS'
 and t.sku_quantity > '0'
 and t.sku_class_code not in ('86','50')
 and t.store_city = '北京市'
 --and t.store_code = '100078005'
 group by
t.store_code
)

select
record_date as `周`
,store_code as `门店编码`
,store_name as `门店名称`
,sku_class as `商品中分类`
,sku_code as `商品编码`
,sku_division_name as `商品小分类`
,sku_name as `商品名称`
--,quantity as `库存`
,sku_quantity as `销量`
,sell_price as `折前金额`
,payable_price as `折后金额`
from(
select
date_add(t1.record_date,7 - case when dayofweek(t1.record_date) = 1 then 7 else dayofweek(t1.record_date) - 1 end) as record_date
,t1.store_code
,t1.store_name
,t1.sku_class
,t1.sku_code
,t1.sku_division_name
,t1.sku_name
,sum(t1.quantity) as quantity
,case when sum(t2.sku_quantity) is null then '0' else sum(t2.sku_quantity) end as sku_quantity
,sum(t2.sell_price) as sell_price
,sum(t2.payable_price) as payable_price
from store_sku_list t1
left join sale_list t2 on t1.record_date = t2.order_date and t1.store_code = t2.store_code and t1.sku_code = t2.sku_code
join data_build.dm_site_selection_project_feature_info_di t3 on t1.store_code = t3.store_code and t3.dt = 20221114
join sale_store_list t4 on t1.store_code = t4.store_code -- 只取有销售的门店
where t3.location_type in ('办公','办公+其他')
and t3.store_city = '北京市'
group by
date_add(t1.record_date,7 - case when dayofweek(t1.record_date) = 1 then 7 else dayofweek(t1.record_date) - 1 end)
,t1.store_code
,t1.store_name
,t1.sku_class
,t1.sku_code
,t1.sku_division_name
,t1.sku_name
) a
where quantity + sku_quantity <> '0'












select
store_code
,store_name
,sum(profit_rank)/count(store_code)
from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1
where dt > 20230101
group by
store_code
,store_name

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店地址信息
select
store_code
,store_name
,store_address
,store_city
,store_area_name
,store_longitude
,store_latitude
from default.dim_store_info
where dt = 20231108
and store_type = '0'

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店距离
select
a_store_code
,a_store_city
,b_store_code
,b_store_city
,distince
from data_smartorder.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all t1
left join data_build.ods_upload_store_list_1603 t2 on t1.a_store_code = t2.store_code and t2.dt = 2023118
left join data_build.ods_upload_store_list_1603 t3 on t1.b_store_code = t3.store_code and t3.dt = 2023118
where t1.dt = 20231108
and t2.store_type not in ('当前撤店pipeline中门店','已撤出','null')
and t3.store_type not in ('当前撤店pipeline中门店','已撤出','null')