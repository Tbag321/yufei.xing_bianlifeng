select 
t1.store_code
,t1.store_name
,t3.city_name
,t1.shelf_type
,t2.shelf_type_name
,t1.shelf_name
,count(distinct t1.shelf_name) as shelf_num
,count(distinct t1.level_id) as level_num
from data_smartorder.dw_sku_display_next_week_store_sku_display_all_history_di t1
left join data_smartorder.dm_copy_pdw_cvs_product_display_base_shelf_type_view t2 on t1.shelf_type = t2.shelf_type_code and t1.dt = t2.dt
left join data_build.dwd_store_construction_project_status_v2_di t3 on t1.store_code = t3.store_code and t1.dt = t3.dt
where t1.dt = 20250710
and t3.store_status_blf = '1正常保留-已开业门店'
group by
t1.store_code
,t1.store_name
,t3.city_name
,t1.shelf_type
,t2.shelf_type_name
,t1.shelf_name

------------------------------------------------------------------------------------------------------------------------------------------
******************************************************************************************************************************************
******************************************************************************************************************************************
------------------------------------------------------------------------------------------------------------------------------------------
--每个主题分别贡献的日商
select 
order_date
,store_city
,store_code
,store_name
,shelf_class_name --一级货架名称
,shelf_topic --货架主题
,is_working_day
,count(distinct order_date) as order_date_num --营业日
,sum(sku_quantity_repartition)/count(distinct order_date) as sku_quantity --日均商品数量
,sum(origin_payable_price_repartition)/count(distinct order_date) as payable_price --销售额
,sum(gross_profit_after_waste_repartition)/count(distinct order_date) as profit_after
from data_md.dm_md_report_store_shelf_effectiveness_info_v1_di
where dt between '20250721' and '20250727'
--and is_working_day = '1'
group by
order_date
,store_city
,store_code
,store_name
,shelf_class_name
,shelf_topic
,is_working_day
------------------------------------------------------------------------------------------------------------------------------------------
******************************************************************************************************************************************
******************************************************************************************************************************************
------------------------------------------------------------------------------------------------------------------------------------------
--每个货架分别贡献的日商
with raw_list as(
select
t1.effective_date --陈列生效日期 
,t1.store_code
,t1.store_name
,t3.city_name
,t1.shelf_type --货架类型
,t2.shelf_type_name --货架类型名称
,t1.shelf_name --货架名称
,count(distinct t1.shelf_name) as shelf_num
,count(distinct t1.level_id) as level_num --货架层数
from data_smartorder.dw_sku_display_next_week_store_sku_display_all_history_di t1
left join data_smartorder.dm_copy_pdw_cvs_product_display_base_shelf_type_view t2 on t1.shelf_type = t2.shelf_type_code and t2.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
left join data_build.dwd_store_construction_project_status_v2_di t3 on t1.store_code = t3.store_code and t1.dt = t3.dt
where t1.dt = 20250720 --商品-门店-货架-下周陈列
and t3.store_status_blf = '1正常保留-已开业门店'
group by
t1.effective_date
,t1.store_code
,t1.store_name
,t3.city_name
,t1.shelf_type
,t2.shelf_type_name
,t1.shelf_name
)

select
effective_date --陈列生效日期 
,store_code
,store_name
,city_name
,shelf_type --货架类型
,shelf_type_name --货架类型名称
,shelf_name --货架名称
,shelf_num --货架名称计数
,shelf_array
,regexp_replace(single_shelf,'[0-9]+$','') as single_shelf
,round(shelf_num * (1.0 / SIZE(shelf_array)), 2) as shelf_num_1 --拆分后计数
from(
select
effective_date --陈列生效日期 
,store_code
,store_name
,city_name
,shelf_type --货架类型
,shelf_type_name --货架类型名称
,shelf_name --货架名称
,shelf_num --货架名称计数
,SPLIT(shelf_name, "\\+") AS shelf_array --分割组合类目
from raw_list
where shelf_name NOT RLIKE '^[a-zA-Z0-9]'  -- 筛选掉以数字开头的值
) t
lateral view explode(shelf_array) t1 as single_shelf