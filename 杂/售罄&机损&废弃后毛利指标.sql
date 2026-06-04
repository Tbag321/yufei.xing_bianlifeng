# 售罄
1) 日配ff 基于高峰期/非高峰期权重计算售罄
select
a.target_date
,b.is_working_day
,a.store_code
,a.sku_division_group_code
,a.sku_division_group_name
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) as sold_out_rate_fenzi --售罄分子:非制作-售罄时段人流*因子 制作-售罄时段权重
,SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate_fenmu --售罄分母:非制作-时段总人流*因子 制作-时段总权重
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) / SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate
from data_smartorder.dm_ordering_report_sold_out_customangle_di a
inner join default.dim_date_ya_v2 b
on a.target_date = b.date_key
where dt >= date_format(date_sub('${dt}',120),'yyyyMMdd')
and sku_division_group_code in
(--只覆盖这些分类组
'0301','0302','0303','0304'
,'0501','0502'
,'0601','0602'
)
group by
a.target_date
,b.is_working_day
,a.store_code
,a.sku_division_group_code
,a.sku_division_group_name

2) 日配非制作类 基于经营性最小陈列
select
a.target_date
,b.is_working_day
,a.store_code
,a.sku_division_group_code
,a.sku_division_group_name
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) as sold_out_rate_fenzi --售罄分子:非制作-售罄时段人流*因子 制作-售罄时段权重
,SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate_fenmu --售罄分母:非制作-时段总人流*因子 制作-时段总权重
,SUM(nvl(a.sale_out_flag,0)*nvl(a.factor_1,0)*nvl(a.factor_3,0)) / SUM(nvl(a.factor_2,0) * nvl(a.factor_3,0)) as sold_out_rate
from data_smartorder.dm_ordering_report_noff_sold_out_operational_group_final_di a
inner join default.dim_date_ya_v2 b
on a.target_date = b.date_key
where dt >= date_format(date_sub('${dt}',120),'yyyyMMdd')
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
a.target_date
,b.is_working_day
,a.store_code
,a.sku_division_group_code
,a.sku_division_group_name
 
3) 非日配 在陈列品的库存为0记为售罄。售罄率 = sum(is_sold_out)/count(1)
select
t1.record_date
,t1.store_code
,t1.sku_main_code
,nvl(t2.quantity,0) as quantity
,case when nvl(t2.quantity,0) <= 0 then 1 else 0 end as is_sold_out
from data_smartorder.app_ordering_system_evaluation_ordering_store_division_main_sku_di_v2 t1
left join
(
select
store_code
,sku_code
,greatest(quantity,0) as quantity --巴赫系统库存,负数置为0
from data_smartorder.dm_copy_dw_inventory_store_snapshot_ha_v1_view --增量表
where dt = '20220717' --dt=销售日期
and store_type = '0' --便利店
and location_type = '1' --所有仓
and is_available = '1'
and is_owned = '1'
and hr = '20' --业务侧默认看20:00
) t2
on t1.store_code = t2.store_code
and t1.sku_main_code = t2.sku_code
where t1.dt = '20220717'
and t1.store_type = '0'
and (t1.sku_class_code = '12' or t1.sku_class_code >= 30)
and t1.face_nums > 0 --在陈列
and t1.store_order_nums >= 20 --当天门店正常营业


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