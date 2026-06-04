with customer_complaint as(
select a.*
,b.user_id
,row_number() over(partition by phone order by happen_date) as rn
from(
SELECT DISTINCT --去重
id --主键ID
,shelf_id --门店编码
,phone --电话
,substr(call_time,1,10) as call_date --来电时间
,feedback_channel_desc --反馈渠道
,shelf_order_content --需求单内容
,context --问题描述
,type_level_1 --需求单级别1级类型
,type_level_2 --需求单级别2级类型
,type_level_3 --需求单级别3级类型
,demand_complain_type --需求投诉类型
,type_class --需求单类型分类 1--操作 ,2--咨询 ,3--投诉
,substr(order_time,1,10) as order_date --订单发生时间
,case
when substr(call_time,1,10) is null then substr(order_time,1,10)
when substr(order_time,1,10) is null then substr(call_time,1,10)
when substr(order_time,1,10) < substr(call_time,1,10) then substr(order_time,1,10)
else substr(call_time,1,10) end as happen_date --校验发生时间
,case
when business_type_desc in ('门店','外卖') and type_class in('投诉') and type_level_1 in('四级','三级','二级','一级','CS-外卖',) and type_level_2 in ('服务问题',
'优惠/活动问题','口感','退换货问题','YW','BZ','品质','支付问题','量少','价格','拣货问题','购物体验','GQ','商品或包装破损','标签','非食品类质量问题','失温','包装','配套产品缺失','CT',
'RS','设备故障问题','实物和图片不符','WS','撒漏','提货问题','WH','商品质量问题') and type_level_3 in ('服务态度问题','优惠活动无法享用','口感','店员给错商品','异物','优惠券无法使用',
'变质','品质','卫生/环境','订单重复支付','量少','价格','已下单商品部分缺货（在库）','等待/排队时间长','技能/专业不熟练','豆浆稀','过期',
'商品或包装破损','标签','门店结错账','非食品类质量问题','不认可优惠券推广方式','失温','身体不适','商品临期','支付金额与宣传不符','包装','支付异常','未生单无法支付',
'配套产品缺失','服务冲突','其它','信号问题','人伤','豆浆机故障','实物和图片不符','物损','撒漏','已下单商品全部缺货（在库）','退款后优惠券未到账',
'噪音/声音问题','三方优惠券无法使用','沟通困难','点餐屏故障','未佩戴口罩','闭店无法提货','人员健康问题','危害客户安全','仪表不整','已下单商品部分缺货') then '门店' 
when business_type_desc in ('外卖') and type_class in ('投诉') and type_level_1 in ('四级') and type_level_2 in ('拣货问题') and type_level_3 in 
('已下单商品部分缺货（在库）','缺货联系不上用户','已下单商品全部缺货（在库）','备货超时') then '门店-外卖' else null end
else null end as 
from data_smartorder.dw_punish_customer_complaint_order_da
where dt = date_format(date_sub(current_date(),1),'yyyymmdd')
and shelf_id = '100078005'
) a
left join data_promotion.dim_user_info b on a.phone = b.user_phone and b.dt = date_format(date_sub(current_date(),1),'yyyymmdd')
where a.type_class = '投诉'
and a.happen_date is not null
),

user_order_info as(
select
user_id
,min(order_date) as frist_order
,max(order_date) as last_order
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
where a.dt = 20240124
and a.store_code = '100078005'
and a.order_status = 'FINISHED'
and a.store_type = '0'
and a.sku_class_code not in ('86','50')
group by
user_id
)

select
a.*
,b.*
,c.frist_order
,c.last_order
,case when a.order_date <= b.happen_date then '投诉前' else '投诉后' end as complain_node
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join customer_complaint b on a.user_id = b.user_id and b.rn = 1
left join user_order_info c on a.user_id = c.user_id
where a.dt = 20240124
and b.rn is not null
and a.store_code = '100078005'
and a.order_status = 'FINISHED'
and a.store_type = '0'
and a.sku_class_code not in ('86','50')


--百日单量
with user_list as(
select
user_id
,count(distinct order_no) as order_num --用户单量
,min(order_date) as frist_order --首单日期
,max(order_date) as last_order --最近一单日期
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
where a.dt = 20240124
and a.store_code = '100078005'
and a.order_status = 'FINISHED'
and a.store_type = '0'
and a.sku_class_code not in ('86','50')
group by
user_id
)

select
user_id
,order_num
,datediff(last_order,frist_order) as day_num
from user_list
