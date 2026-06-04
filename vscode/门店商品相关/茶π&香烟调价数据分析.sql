--季度茶π价格
--门店季度总订单&用户数量
with order_num_store as(
select
concat(year(order_date),"-",quarter(order_date)) as record_time
,store_code
--,store_name
,store_city
,count(distinct order_no) as all_order_num
,count(distinct if(length(nvl(pay_id,'-1')) > 3,pay_id,null)) as all_pay_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240401
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.sku_quantity > 0
group by
concat(year(order_date),"-",quarter(order_date))
,store_code
--,store_name
,store_city
)

select
concat(year(t.order_date),"-",quarter(t.order_date)) as record_time
,t.store_code
--,t.store_name
,t.store_city
,t1.all_order_num
,t1.all_pay_num

,count(distinct t.order_no) as sku_order_num
,count(distinct if(length(nvl(t.pay_id,'-1')) > 3,t.pay_id,null))
,count(distinct t.sku_code) as sku_code_num
,sum(t.sku_quantity) as sku_quantity
,sum(t.sell_price)/sum(t.sku_quantity) as sell_price
,sum(t.payable_price)/sum(t.sku_quantity) as payable_price
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join order_num_store t1 on concat(year(t.order_date),"-",quarter(t.order_date)) = t1.record_time and t.store_code = t1.store_code
where t.dt = 20240401
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and sku_code in (
--'03000620'
--,'03000648'
--,'03000657'
--,'33030107' --农夫山泉茶π柠檬红茶250ml
'33030272' --农夫山泉茶π青提乌龙茶500ml***
,'33030273' --农夫山泉茶π柑普柠檬茶500ml***
--,'33030315' --农夫山泉茶π西柚茉莉花茶果味茶饮料900ml
,'33050005' --农夫茶π蜜桃乌龙茶500ml***
,'33050008' --农夫山泉茶π柠檬红茶500ml***
,'33050012' --农夫山泉茶π柚子绿茶500ml
,'33050018' --农夫茶π西柚茉莉花茶500ml
,'33050034' --农夫茶π柚子绿茶500ml***
,'33050048' --茶π果味茶玫瑰荔枝红茶500ml
--,'33050163' --茶π柠檬红茶750ml
--,'33050164' --茶π蜜桃乌龙茶750ml
--,'33080018' --农夫山泉茶π柠檬红茶900ml
--,'33080019' --农夫山泉茶π蜜桃乌龙茶900ml
--,'79330560'
,'79330568' --农夫山泉茶π柑普柠檬茶500ml*** 
,'79330602' --农夫茶π柚子绿茶500ml***
,'79330615' --农夫茶π蜜桃乌龙茶500ml***
,'79330618' --农夫山泉茶π柠檬红茶500ml***
,'79330621' --农夫山泉茶π青提乌龙茶500ml***
--,'79330687'
--,'79330702'
--,'79330734'
--,'79330974'
)
and t.sku_quantity > 0
group by
concat(year(t.order_date),"-",quarter(t.order_date))
,t.store_code
--,t.store_name
,t.store_city
,t1.all_order_num
,t1.all_pay_num

************************************************************************************************************************************

--用户维度
--base信息
with base_pay_id as(
select
pay_id
,store_code
--水饮
,count(distinct order_no) as retained_fluid_order_no
,sum(sku_quantity) as retained_fluid_sku_quantity
--茶π
,count(distinct case when sku_code in ('33030272','33030273','33050005','33050008','33050012','33050018','33050034','33050048','79330568','79330602','79330615','79330618','79330621') then order_no else null end) as tea_order_no
,sum(case when sku_code in ('33030272','33030273','33050005','33050008','33050012','33050018','33050034','33050048','79330568','79330602','79330615','79330618','79330621') then sku_quantity else 0 end) as tea_sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240407
and t.pay_id is not null
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.sku_quantity > 0
and order_date between '2020-01-01' and '2020-06-30'
and sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933')
and store_code in ('100001005','100001007','100005002','100009001','100016002','100019002','100033002','100057002','100002006','100008001','100017005','100051001','100001016','100001023','100001030','100003006',
'100071001','100001018','100001036','100001037','100001038','100001061','100001063','100001077','100001095','100001110','100022002','100072001','100072007','100073009','100075001','100075002','100077005',
'100000002','100000009','100000013','100000023','100000030','100000057','100000060','100000066','100000075','100000078','100000080','100000082','100000085',
'100000086','100000088','100000092','100000105','100000107','100000111','100001076','100001115','100076003','100078005','100079001','100079012','100079019','100079021','100079023','100000073',
'100000091','100000099','100000112','100000129','100000132','100000139','100000155','100000159','100000179','100000181','100000182','100000183')
group by
pay_id
,store_code
),

quarter_list as(
select
concat(year(t.order_date),"-",quarter(t.order_date)) as record_time
,pay_id
,store_code
--全部单量
,count(distinct order_no) as order_no_num
--水饮
,count(distinct case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then order_no else null end) as retained_fluid_order_no
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then sku_quantity else 0 end) as retained_fluid_sku_quantity
--茶π
,count(distinct case when sku_code in ('33030272','33030273','33050005','33050008','33050012','33050018','33050034','33050048','79330568','79330602','79330615','79330618','79330621') then order_no else null end) as tea_order_no
,sum(case when sku_code in ('33030272','33030273','33050005','33050008','33050012','33050018','33050034','33050048','79330568','79330602','79330615','79330618','79330621') then sku_quantity else 0 end) as tea_sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = 20240407
and t.pay_id is not null
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.sku_quantity > 0
and order_date between '2020-07-01' and '2024-03-31'
and store_code in ('100001005','100001007','100005002','100009001','100016002','100019002','100033002','100057002','100002006','100008001','100017005','100051001','100001016','100001023','100001030','100003006',
'100071001','100001018','100001036','100001037','100001038','100001061','100001063','100001077','100001095','100001110','100022002','100072001','100072007','100073009','100075001','100075002','100077005',
'100000002','100000009','100000013','100000023','100000030','100000057','100000060','100000066','100000075','100000078','100000080','100000082','100000085',
'100000086','100000088','100000092','100000105','100000107','100000111','100001076','100001115','100076003','100078005','100079001','100079012','100079019','100079021','100079023','100000073',
'100000091','100000099','100000112','100000129','100000132','100000139','100000155','100000159','100000179','100000181','100000182','100000183')
group by
concat(year(t.order_date),"-",quarter(t.order_date))
,pay_id
,store_code
),

raw_1 as(
select
t0.pay_id as 0_pay_id
,t0.store_code as 0_store_code

,t0.retained_fluid_order_no as 0_retained_fluid_order_no
,t0.retained_fluid_sku_quantity as 0_retained_fluid_sku_quantity
,t0.tea_order_no as 0_tea_order_no
,t0.tea_sku_quantity as 0_tea_sku_quantity

,t1.order_no_num as 1_order_no_num
,t1.retained_fluid_order_no as 1_retained_fluid_order_no
,t1.retained_fluid_sku_quantity as 1_retained_fluid_sku_quantity
,t1.tea_order_no as 1_tea_order_no
,t1.tea_sku_quantity as 1_tea_sku_quantity

,t2.order_no_num as 2_order_no_num
,t2.retained_fluid_order_no as 2_retained_fluid_order_no
,t2.retained_fluid_sku_quantity as 2_retained_fluid_sku_quantity
,t2.tea_order_no as 2_tea_order_no
,t2.tea_sku_quantity as 2_tea_sku_quantity

,t3.order_no_num as 3_order_no_num
,t3.retained_fluid_order_no as 3_retained_fluid_order_no
,t3.retained_fluid_sku_quantity as 3_retained_fluid_sku_quantity
,t3.tea_order_no as 3_tea_order_no
,t3.tea_sku_quantity as 3_tea_sku_quantity

,t4.order_no_num as 4_order_no_num
,t4.retained_fluid_order_no as 4_retained_fluid_order_no
,t4.retained_fluid_sku_quantity as 4_retained_fluid_sku_quantity
,t4.tea_order_no as 4_tea_order_no
,t4.tea_sku_quantity as 4_tea_sku_quantity

,t5.order_no_num as 5_order_no_num
,t5.retained_fluid_order_no as 5_retained_fluid_order_no
,t5.retained_fluid_sku_quantity as 5_retained_fluid_sku_quantity
,t5.tea_order_no as 5_tea_order_no
,t5.tea_sku_quantity as 5_tea_sku_quantity

,t6.order_no_num as 6_order_no_num
,t6.retained_fluid_order_no as 6_retained_fluid_order_no
,t6.retained_fluid_sku_quantity as 6_retained_fluid_sku_quantity
,t6.tea_order_no as 6_tea_order_no
,t6.tea_sku_quantity as 6_tea_sku_quantity

,t7.order_no_num as 7_order_no_num
,t7.retained_fluid_order_no as 7_retained_fluid_order_no
,t7.retained_fluid_sku_quantity as 7_retained_fluid_sku_quantity
,t7.tea_order_no as 7_tea_order_no
,t7.tea_sku_quantity as 7_tea_sku_quantity

,t8.order_no_num as 8_order_no_num
,t8.retained_fluid_order_no as 8_retained_fluid_order_no
,t8.retained_fluid_sku_quantity as 8_retained_fluid_sku_quantity
,t8.tea_order_no as 8_tea_order_no
,t8.tea_sku_quantity as 8_tea_sku_quantity

,t9.order_no_num as 9_order_no_num
,t9.retained_fluid_order_no as 9_retained_fluid_order_no
,t9.retained_fluid_sku_quantity as 9_retained_fluid_sku_quantity
,t9.tea_order_no as 9_tea_order_no
,t9.tea_sku_quantity as 9_tea_sku_quantity

,t10.order_no_num as 10_order_no_num
,t10.retained_fluid_order_no as 10_retained_fluid_order_no
,t10.retained_fluid_sku_quantity as 10_retained_fluid_sku_quantity
,t10.tea_order_no as 10_tea_order_no
,t10.tea_sku_quantity as 10_tea_sku_quantity

,t11.order_no_num as 11_order_no_num
,t11.retained_fluid_order_no as 11_retained_fluid_order_no
,t11.retained_fluid_sku_quantity as 11_retained_fluid_sku_quantity
,t11.tea_order_no as 11_tea_order_no
,t11.tea_sku_quantity as 11_tea_sku_quantity

,t12.order_no_num as 12_order_no_num
,t12.retained_fluid_order_no as 12_retained_fluid_order_no
,t12.retained_fluid_sku_quantity as 12_retained_fluid_sku_quantity
,t12.tea_order_no as 12_tea_order_no
,t12.tea_sku_quantity as 12_tea_sku_quantity

,t13.order_no_num as 13_order_no_num
,t13.retained_fluid_order_no as 13_retained_fluid_order_no
,t13.retained_fluid_sku_quantity as 13_retained_fluid_sku_quantity
,t13.tea_order_no as 13_tea_order_no
,t13.tea_sku_quantity as 13_tea_sku_quantity

,t14.order_no_num as 14_order_no_num
,t14.retained_fluid_order_no as 14_retained_fluid_order_no
,t14.retained_fluid_sku_quantity as 14_retained_fluid_sku_quantity
,t14.tea_order_no as 14_tea_order_no
,t14.tea_sku_quantity as 14_tea_sku_quantity

,t15.order_no_num as 15_order_no_num
,t15.retained_fluid_order_no as 15_retained_fluid_order_no
,t15.retained_fluid_sku_quantity as 15_retained_fluid_sku_quantity
,t15.tea_order_no as 15_tea_order_no
,t15.tea_sku_quantity as 15_tea_sku_quantity

from base_pay_id t0
left join quarter_list t1 on t0.store_code = t1.store_code and t0.pay_id = t1.pay_id and t1.record_time = '2020-3'
left join quarter_list t2 on t0.store_code = t2.store_code and t0.pay_id = t2.pay_id and t2.record_time = '2020-4'
left join quarter_list t3 on t0.store_code = t3.store_code and t0.pay_id = t3.pay_id and t3.record_time = '2021-1'
left join quarter_list t4 on t0.store_code = t4.store_code and t0.pay_id = t4.pay_id and t4.record_time = '2021-2'
left join quarter_list t5 on t0.store_code = t5.store_code and t0.pay_id = t5.pay_id and t5.record_time = '2021-3'
left join quarter_list t6 on t0.store_code = t6.store_code and t0.pay_id = t6.pay_id and t6.record_time = '2021-4'
left join quarter_list t7 on t0.store_code = t7.store_code and t0.pay_id = t7.pay_id and t7.record_time = '2022-1'
left join quarter_list t8 on t0.store_code = t8.store_code and t0.pay_id = t8.pay_id and t8.record_time = '2022-2'
left join quarter_list t9 on t0.store_code = t9.store_code and t0.pay_id = t9.pay_id and t9.record_time = '2022-3'
left join quarter_list t10 on t0.store_code = t10.store_code and t0.pay_id = t10.pay_id and t10.record_time = '2022-4'
left join quarter_list t11 on t0.store_code = t11.store_code and t0.pay_id = t11.pay_id and t11.record_time = '2023-1'
left join quarter_list t12 on t0.store_code = t12.store_code and t0.pay_id = t12.pay_id and t12.record_time = '2023-2'
left join quarter_list t13 on t0.store_code = t13.store_code and t0.pay_id = t13.pay_id and t13.record_time = '2023-3'
left join quarter_list t14 on t0.store_code = t14.store_code and t0.pay_id = t14.pay_id and t14.record_time = '2023-4'
left join quarter_list t15 on t0.store_code = t15.store_code and t0.pay_id = t15.pay_id and t15.record_time = '2024-1'
)

select
0_store_code

,count(0_pay_id)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(0_retained_fluid_order_no)-- as `购买饮料单量`
,sum(0_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(0_tea_order_no)--  as `购买茶π单量`
,sum(0_tea_sku_quantity)-- as `购买茶π数量`

,count(case when nvl(1_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(1_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(1_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(1_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(1_retained_fluid_order_no)-- as `购买饮料单量`
,sum(1_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 1_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 1_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(2_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(2_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(2_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(2_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(2_retained_fluid_order_no)-- as `购买饮料单量`
,sum(2_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 2_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 2_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(3_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(3_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(3_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(3_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(3_retained_fluid_order_no)-- as `购买饮料单量`
,sum(3_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 3_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 3_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(4_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(4_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(4_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(4_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(4_retained_fluid_order_no)-- as `购买饮料单量`
,sum(4_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 4_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 4_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(5_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(5_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(5_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(5_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(5_retained_fluid_order_no)-- as `购买饮料单量`
,sum(5_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 5_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 5_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(6_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(6_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(6_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(6_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(6_retained_fluid_order_no)-- as `购买饮料单量`
,sum(6_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 6_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 6_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(7_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(7_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(7_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(7_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(7_retained_fluid_order_no)-- as `购买饮料单量`
,sum(7_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 7_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 7_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(8_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(8_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(8_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(8_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(8_retained_fluid_order_no)-- as `购买饮料单量`
,sum(8_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 8_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 8_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(9_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(9_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(9_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(9_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(9_retained_fluid_order_no)-- as `购买饮料单量`
,sum(9_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 9_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 9_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(10_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(10_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(10_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(10_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(10_retained_fluid_order_no)-- as `购买饮料单量`
,sum(10_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 10_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 10_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(11_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(11_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(11_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(11_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(11_retained_fluid_order_no)-- as `购买饮料单量`
,sum(11_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 11_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 11_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(12_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(12_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(12_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(12_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(12_retained_fluid_order_no)-- as `购买饮料单量`
,sum(12_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 12_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 12_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(13_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(13_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(13_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(13_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(13_retained_fluid_order_no)-- as `购买饮料单量`
,sum(13_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 13_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 13_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(14_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(14_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(14_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(14_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(14_retained_fluid_order_no)-- as `购买饮料单量`
,sum(14_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 14_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 14_tea_sku_quantity else 0 end)-- as `购买茶π数量`

,count(case when nvl(15_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(15_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(15_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(15_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(15_retained_fluid_order_no)-- as `购买饮料单量`
,sum(15_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 15_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 15_tea_sku_quantity else 0 end)-- as `购买茶π数量`

from raw_1
group by
0_store_code

***************************************************************************************************************************************************************

--高销香烟
--香烟大单明细
with big_cigarette_order_list as(
select
order_no
,order_date
,store_code
from(
select
order_no
,order_date
,store_code
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and sku_division_code in ('6101','6102','6103')
and store_code = '100078005'
group by
order_no
,order_date
,store_code
) a
where sku_quantity >= 11 or payable_price >= 500
)

select
t.order_date
,t.store_code
,t.sku_code
,t.sku_name
,sum(t.sku_quantity) as sku_quantity
from data_build.dw_order_sku_promotion_v1 t
left join big_cigarette_order_list t1 on t.order_date = t1.order_date and t.store_code = t1.store_code and t.order_no = t1.order_no
where dt = 20240410
and t.sku_division_code in ('6101','6102','6103')
and t.store_type = '0'
and t.pay_status = 'PAY_SUCCESS'
and t.store_code = '100078005'
and t.sku_class_code not in ('86','50')
and t.order_date between '2023-06-01' and '2023-08-31'
and t1.order_no is null --剔除大单
group by
t.order_date
,t.store_code
,t.sku_code
,t.sku_name

*******************************************************************************************************************************************************************************

--高销单价
--香烟大单明细
with big_cigarette_order_list as(
select
order_no
,order_date
,store_code
from(
select
order_no
,order_date
,store_code
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
from data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and sku_division_code in ('6101','6102','6103')
and store_code = '100078005'
and t.order_date >= '2023-06-01'
group by
order_no
,order_date
,store_code
) a
where sku_quantity >= 11 or payable_price >= 500
),

--top3香烟价格
--门店周度总订单&用户数量
order_num_store as(
select
t.order_date
,t.store_code
,t.store_city
,count(distinct t.order_no) as all_order_num
,count(distinct if(length(nvl(t.pay_id,'-1')) > 3,t.pay_id,null)) as all_pay_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join big_cigarette_order_list t1 on t.store_code = t1.store_code and t.order_date = t1.order_date and t.order_no = t1.order_no
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.sku_quantity > 0
--and t.store_code = '100078005'
and t1.order_no is null --剔香烟大单
and t.order_date >= '2023-06-01'
and pay_id is not null
group by
t.order_date
,t.store_code
,t.store_city
)

select
t.order_date
,t.store_code
,t.store_city
,t1.all_order_num
,t1.all_pay_num
,t.sku_name

,count(distinct t.order_no) as sku_order_num
,count(distinct if(length(nvl(t.pay_id,'-1')) > 3,t.pay_id,null)) as pay_num
,count(distinct t.sku_code) as sku_code_num
,sum(t.sku_quantity) as sku_quantity
,sum(t.sell_price)/sum(t.sku_quantity) as sell_price
,sum(t.payable_price)/sum(t.sku_quantity) as payable_price

from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join order_num_store t1 on t.order_date = t1.order_date and t.store_code = t1.store_code
left join big_cigarette_order_list t2 on t.store_code = t2.store_code and t.order_date = t2.order_date and t.order_no = t2.order_no
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
--and t.store_code = '100078005'
and t.sku_code in (
--'61010065' --红塔山（软经典）
'61010007' --云烟（紫）
--,'61010101' --长白山(777)
)
and t.sku_quantity > 0
and t.order_date >= '2023-06-01'
and t2.order_no is null
group by
t.order_date
,t.store_code
,t.store_city
,t1.all_order_num
,t1.all_pay_num
,t.sku_name

*******************************************************************************************************************************************************************************************

--用户维度
--base信息
with base_pay_id as(
select
pay_id
,store_code
--水饮
,count(distinct order_no) as retained_fluid_order_no
,sum(sku_quantity) as retained_fluid_sku_quantity
--茶π
,count(distinct case when sku_code in ('61010007') then order_no else null end) as tea_order_no
,sum(case when sku_code in ('61010007') then sku_quantity else 0 end) as tea_sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.pay_id is not null
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.sku_quantity > 0
and order_date between '2023-09-18' and '2023-11-19'
and sku_division_code in ('6101','6102','6103')
and store_code in ('100002502',
'100000517',
'100001572',
'123000520',
'123000099',
'100000198',
'123000193',
'100000618',
'100001608',
'100000322',
'100001183',
'100000208',
'123000335',
'123000273',
'100000085')
group by
pay_id
,store_code
),

quarter_list as(
select
pay_id
,store_code
--全部单量
,count(distinct order_no) as order_no_num
--水饮
,count(distinct case when sku_division_code in ('6101','6102','6103') then order_no else null end) as retained_fluid_order_no
,sum(case when sku_division_code in ('6101','6102','6103') then sku_quantity else 0 end) as retained_fluid_sku_quantity
--茶π
,count(distinct case when sku_code in ('61010007') then order_no else null end) as tea_order_no
,sum(case when sku_code in ('61010007') then sku_quantity else 0 end) as tea_sku_quantity
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.pay_id is not null
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.sku_class_code not in ('50','86')
and t.sku_quantity > 0
and order_date between '2024-02-26' and '2024-04-28'
and store_code in ('100002502',
'100000517',
'100001572',
'123000520',
'123000099',
'100000198',
'123000193',
'100000618',
'100001608',
'100000322',
'100001183',
'100000208',
'123000335',
'123000273',
'100000085')
group by
pay_id
,store_code
),

raw_1 as(
select
t0.pay_id as 0_pay_id
,t0.store_code as 0_store_code

,t0.retained_fluid_order_no as 0_retained_fluid_order_no
,t0.retained_fluid_sku_quantity as 0_retained_fluid_sku_quantity
,t0.tea_order_no as 0_tea_order_no
,t0.tea_sku_quantity as 0_tea_sku_quantity

,t1.order_no_num as 1_order_no_num
,t1.retained_fluid_order_no as 1_retained_fluid_order_no
,t1.retained_fluid_sku_quantity as 1_retained_fluid_sku_quantity
,t1.tea_order_no as 1_tea_order_no
,t1.tea_sku_quantity as 1_tea_sku_quantity

from base_pay_id t0
left join quarter_list t1 on t0.store_code = t1.store_code and t0.pay_id = t1.pay_id
)

select
0_store_code

,count(0_pay_id)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(0_retained_fluid_order_no)-- as `购买饮料单量`
,sum(0_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(0_tea_order_no)--  as `购买茶π单量`
,sum(0_tea_sku_quantity)-- as `购买茶π数量`

,count(case when nvl(1_order_no_num,0) > 0 then 0_pay_id else null end)-- as `购买饮料又继续购物用户数`
,sum(1_order_no_num)-- as `购买饮料又继续购物用户的单量`
,count(case when nvl(1_retained_fluid_order_no,0) > 0 then 0_pay_id else null end)-- as `购买饮料用户数`
,count(case when nvl(0_tea_order_no,0) > 0 and nvl(1_tea_order_no,0) > 0 then 0_pay_id else null end)-- as `购买茶π用户数`
,sum(1_retained_fluid_order_no)-- as `购买饮料单量`
,sum(1_retained_fluid_sku_quantity)--  as `购买饮料数量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 1_tea_order_no else 0 end)--  as `购买茶π单量`
,sum(case when nvl(0_tea_order_no,0) > 0 then 1_tea_sku_quantity else 0 end)-- as `购买茶π数量`
from raw_1
group by
0_store_code