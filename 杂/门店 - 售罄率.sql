# 售罄
1) 日配ff 基于高峰期/非高峰期权重计算售罄
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

 date_list as(
    select
    date_key,
    case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
    from default.dim_date_ya_v2
 )

select
date_add(target_date,7 - case when dayofweek(target_date) = 1 then 7 else dayofweek(target_date) - 1 end) as order_week,
b.store_cvs_code,
b.display_name,
c.date_type
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) as sold_out_rate_fenzi --售罄分子:非制作-售罄时段人流*因子 制作-售罄时段权重
,SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate_fenmu --售罄分母:非制作-时段总人流*因子 制作-时段总权重
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) / SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate
from data_smartorder.dm_ordering_report_sold_out_customangle_di a
left join desensitization b on a.store_code = b.store_code
left join date_list c on a.target_date = c.date_key
where dt between '20220501' and '20221130'
and sku_division_group_code in
(--只覆盖这些分类组
'0301','0302','0303','0304'
,'0501','0502'
,'0601','0602'
)
and b.store_cvs_code = '108000076'
group by
date_add(target_date,7 - case when dayofweek(target_date) = 1 then 7 else dayofweek(target_date) - 1 end),
b.store_cvs_code,
b.display_name,
c.date_type



2) 日配非制作类 基于经营性最小陈列
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name)
 
select
trunc(target_date,'MM') as order_month,
b.store_cvs_code,
b.display_name
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) as sold_out_rate_fenzi --售罄分子:非制作-售罄时段人流*因子 制作-售罄时段权重
,SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate_fenmu --售罄分母:非制作-时段总人流*因子 制作-时段总权重
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) / SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate
from data_smartorder.dm_ordering_report_noff_sold_out_operational_group_final_di a
left join desensitization b on a.store_code = b.store_code
where dt between '20220801' and '20220831'
and sku_division_group_code in
(--只覆盖这些分类组
'0101&0102'
,'0103&0401'
,'0201&0202'
,'0801&0805'
,'1101&1102&1104'
,'1301'
,'21'
)
group by
trunc(target_date,'MM'),
b.store_cvs_code,
b.display_name



--3) 非日配 在陈列品的库存为0记为售罄。售罄率 = sum(is_sold_out)/count(1)
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name)

select
trunc(t3.record_date,'MM') as order_month,
b.store_cvs_code,
b.display_name,
sum(is_sold_out),
count(is_sold_out),
sum(is_sold_out)/count(is_sold_out)
from
(select
t1.record_date
,t1.store_code
,t1.sku_main_code
,nvl(t2.quantity,0) as quantity
,case when nvl(t2.quantity,0) <= 0 then 1 else 0 end as is_sold_out
from data_smartorder.app_ordering_system_evaluation_ordering_store_division_main_sku_di_v2 t1
left join
(
select
dt
,store_code
,sku_code
,greatest(quantity,0) as quantity --巴赫系统库存,负数置为0
from default.dw_inventory_store_snapshot_ha_v1 --全量表
where dt between '20220801' and '20220831'
and store_type = '0' --便利店
and location_type = '1' --所有仓
and is_available = '1'
and is_owned = '1'
and hr = '20' --业务侧默认看20:00
) t2
on t1.store_code = t2.store_code
and t1.sku_main_code = t2.sku_code
and t1.dt = t2.dt
where t1.dt between '20220801' and '20220831'
and t1.store_type = '0'
and (t1.sku_class_code = '12' or t1.sku_class_code >= 30)
and t1.face_nums > 0 --在陈列
and t1.store_order_nums >= 20 --当天门店正常营业
) t3
left join desensitization b on t3.store_code = b.store_code
group by trunc(t3.record_date,'MM'),
b.store_cvs_code,
b.display_name






SELECT
date_add(record_date,1 - case when dayofweek(record_date) = 1 then 7 else dayofweek(record_date) - 1 end) as order_week,
store_code,
store_name,
sum(sku_opportunity_loss_payable_price)/count(distinct record_date)
from data_smartorder.dw_ordering_opportunity_loss_quantity_store_division
WHERE dt > '20210829'
and sku_opportunity_loss_payable_price <> 0
GROUP BY
date_add(record_date,1 - case when dayofweek(record_date) = 1 then 7 else dayofweek(record_date) - 1 end),
store_code,
store_name























# 机会损失金额
店中分类粒度（包含香烟、非日配） dw_ordering_opportunity_loss_quantity_store_division
机会损失数量 sku_opportunity_loss_quantity
机会损失金额 sku_opportunity_loss_payable_price




# 订货常用宽表
1) sku级别 关键字段：进/销/存/废/毛利
app_ordering_system_evaluation_ordering_store_division_main_sku_di_v2
废弃后毛利 = zonghe_sku_payable_profit - zonghe_sku_finance_sale_waste_amount
  
2) 中分类级别 关键字段：进/销/存/废/毛利
app_ordering_system_evaluation_ordering_store_division_main_sku_division_di_v2
废弃后毛利 = zonghe_sku_payable_profit - zonghe_sku_finance_sale_waste_amount



 select 
 create_date --销售日期
 ,store_code
 ,store_name
 ,sku_division_code
 ,sku_division_name
 ,sum(make_quantity) as make_quantity --鲜度pad录入制作数量
from data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and create_date >= '2022-01-01'
 and sku_division_code = '0301' --热餐分类
 and hour(make_time) between 9 and 13 --限制制作时间为午餐段 9:00~14:00
group by 
 create_date
 ,store_code
 ,store_name
 ,sku_division_code
 ,sku_division_name

 -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 --分时段热餐售罄次数
 with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

 date_list as(
    select
    date_key,
    case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
    from default.dim_date_ya_v2
 ),

sold_list as(
select
target_date,
b.store_cvs_code,
b.display_name,
c.date_type,
hr,
hr_helf
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) as sold_out_rate_fenzi --售罄分子:非制作-售罄时段人流*因子 制作-售罄时段权重
,SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate_fenmu --售罄分母:非制作-时段总人流*因子 制作-时段总权重
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) / SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate
from data_smartorder.dm_ordering_report_sold_out_customangle_di a
left join desensitization b on a.store_code = b.store_code
left join date_list c on a.target_date = c.date_key
where dt between '20170501' and '20221130'
and sku_division_group_code in
(--只覆盖这些分类组
'0301'
)
--and b.store_cvs_code in ('100000237','100002001')
group by
target_date,
b.store_cvs_code,
b.display_name,
c.date_type,
hr,
hr_helf
)

select
trunc(target_date,'MM')  as month
,store_cvs_code
,display_name
,date_type
,sum(case when hr_helf = '12:30' then sold_out_rate end) as 1230_sold_days
,sum(case when hr_helf = '13:00' then sold_out_rate end) as 1300_sold_days
from sold_list
where store_cvs_code in ('101001036')
group by
trunc(target_date,'MM')
,store_cvs_code
,display_name
,date_type




--鲜食制作数量
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name)

select 
 create_date --销售日期
 ,make_time
 ,b.store_cvs_code
 ,b.display_name
 ,sku_division_code
 ,sku_division_name
 ,sum(make_quantity) as make_quantity --鲜度pad录入制作数量
 ,count(distinct case when make_quantity>0 then sku_code else null end) --做了几个菜
from default.dw_promotion_store_sku_freshness_make_v1 t
left join desensitization b on t.store_code = b.store_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and create_date >= '2022-01-01'
 and sku_division_code = '0301' --热餐分类
 and hour(make_time) between 9 and 13 --限制制作时间为午餐段 9:00~14:00
 and b.store_cvs_code = '101001036'
group by 
 create_date
 ,make_time
 ,b.store_cvs_code
 ,b.display_name
 ,sku_division_code
 ,sku_division_name