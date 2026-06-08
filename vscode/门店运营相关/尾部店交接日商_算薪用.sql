--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 修改code
-- 需要改的部分：
-- 1. 尾部店code "dept_code",来源于yuejia
-- 2. 日期 "b_manager_date" 
with base_info as (
select 
dt
,from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,dept_code
,dept_name
,if(length(manager_code)=6,concat('10',manager_code),manager_code) as manager_code
,manager_name
from data_build.pdw_opc_shop_ehr_staff_dept_view 
where dt >='20260501' -- 算薪月首日
and dept_code in ('100000232',
'100000367',
'100001053',
'100001099',
'100001387',
'100005019',
'100005117',
'101000050',
'101000199',
'101001039',
'107000032',
'107000128',
'111000007',
'100000609',
'100000626',
'100000682',
'100001502',
'100002578',
'100005060',
'100005075',
'100005126',
'100005325',
'100075001',
'100075003',
'101000107',
'101001031',
'107000037',
'107000071',
'107000090',
'109000072',
'110000069',
'110000083',
'110000085',
'110000116',
'110001057',
'123001077',
'123000118',
'123000137',
'123000165',
'123000363',
'123001022',
'123001133',
'100000096',
'100000189',
'100000526',
'100005232',
'101000261',
'109000105',
'110000066',
'100003681',
'100005179',
'101000130',
'101000212',
'101000227',
'101000598',
'110000080',
'100000381',
'100001003',
'100001069',
'100001535',
'100001565',
'100002375',
'101000135',
'109000068',
'109000085',
'100078005',
'100001028',
'100001057',
'100003053',
'100005357',
'101000091',
'101000113',
'107000012',
'110000005',
'188001009',
'100000208',
'100000638',
'100001036',
'100003216',
'100003620',
'100011006',
'100072006',
'101000206',
'101001013',
'101001056',
'109000051',
'123000359',
'123000555',
'100000561',
'100001013',
'110001061',
'101000178',
'101000538',
'107000073',
'107000107',
'109000025',
'109000031',
'110000031',
'110000131',
'110000217',
'100000023',
'123000033',
'100000112',
'123000336',
'100005360',
'110000009',
'110000097',
'110000165',
'118000010',
'101000171',
'100001018',
'100005105',
'110001005',
'123000017',
'100005509',
'123000353',
'101001011',
'123000057',
'101000232')
)
,b_manager_info as ( -- 门店，交接人，交接日期
    select 
    dept_code
    ,dept_name
,manager_code
,manager_name
,b_manager_date
,b_manager_dt 
from (
select 
dept_code
,dept_name
,manager_code
,manager_name
,min(new_dt) as b_manager_date
,min(dt) as b_manager_dt
from base_info 
group by dept_code
,dept_name
,manager_code
,manager_name
) tt 
where b_manager_date >'2026-05-01' -- 算薪月首日
)

,sell_price_list as (
select 
-- trunc(order_date,'MM') as record_month
t.store_code 
--,t.store_name
--周中日订单量折前销售额折后销售额
,t.order_date
,sum(t.sell_price)/count(distinct t2.manager_code) as quanzhou_sell_price --折前销售额
,sum(payable_price)/count(distinct t2.manager_code) as quanzhou_payable_price--折后销售额

from data_build.dw_order_sku_v1 t
left join b_manager_info t2 on t.store_code = t2.dept_code
where t.dt = '${today-1}'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date >= date_sub(b_manager_date,37) --交接日-37天
and t.order_date <= date_sub(current_date(),1) -- t-1日商
group by 
t.store_code 
,t.order_date
--,t.store_name
)

select
dept_code as `门店编码`
,dept_name as `门店名称`
,b_manager_date as `交接日期`
,manager_code as `交接人工号`
,manager_name as `交接人姓名`
,t2.order_date as `日商日期`
,t2.quanzhou_sell_price as `折前日商`
,t2.quanzhou_payable_price as `折后日商`
from b_manager_info t1
left join sell_price_list t2 on t1.dept_code = t2.store_code  
where t2.order_date >= date_sub(b_manager_date,37) --交接日-37天
and t2.order_date <= date_sub(b_manager_date,7) --交接日-7天

union all 
select
dept_code as `门店编码`
,dept_name as `门店名称`
,b_manager_date as `交接日期`
,manager_code as `交接人工号`
,manager_name as `交接人姓名`
,t2.order_date as `日商日期`
,t2.quanzhou_sell_price as `折前日商`
,t2.quanzhou_payable_price as `折后日商`
from b_manager_info t1
left join sell_price_list t2 on t1.dept_code = t2.store_code  
where t2.order_date >= date_add(b_manager_date,8) --交接日+8天
and t2.order_date <= date_sub(current_date(),1) -- t-1日商


--在营门店t-3-t-1天有日商门店
select
t.store_code 
,t.store_name
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between date_sub(from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd'),4) 
and date_sub(from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd'),1)
group by 
t.store_code 
,t.store_name


















1.流程图里的环节补充完整
2.第二阶段的判断标准文字描述清楚（当前预测的春节gap大于基线值，只触发店长店副干预，
淘汰不触发，当春节gap<极限值，则都触发；定为三个档，1不冗余，2轻度冗余，3特别冗余，分别对应的处理措施）
2.1执行标准细化，根据矩阵制定淘汰优先级（P1,P2,P3）
2.2机动队汰换：考虑城市利用率和区域利用率
2.3关于店长店副的汰换，分批处理的自动识别方法
3.写春节人力冗余判断标准表的具体逻辑
4.预警逻辑：单次连续两周or三周，orgap指标恶化，需要单独预警；关键岗位严重恶化，关键区域恶化后不达标
--5.下周班表出来以后，统计今年的出勤概率vs去年出勤概率；统计入离职和淘汰人数那张表
--5.1入职人数/gap模拟入职人数，离职率*现在人数模拟预计离职人数；
--5fte+入职（打折新人*0.5）-所有离职（剔除汰换）-hc=能折腾人数
