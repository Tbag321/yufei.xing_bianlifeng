--data_build.app_store_hotmeal_monitor_da
with sku_info as(
SELECT
finished_sku_code
,finished_sku_name
,component_sku_main_code
from data_smartorder.dw_order_sku_promotion_teardown_ratio_v1
where dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
and component_sku_division_code = '0301'
and sku_type in ('4','6') --车次商品
and finished_sku_code not in ('09060006','03014042','03012192')
and substr(finished_sku_code,1,2) <> '09' --0627修bug，因为尖椒土豆丝原料编码对应两个成品编码，导致数据重复，需把预制品的成品编码去掉
GROUP BY
finished_sku_code
,finished_sku_name
,component_sku_main_code
),

store_sku_list as(
select distinct
order_date
,store_code
,store_name
,sku_main_code
from(
select  
t0.order_date
,t0.store_code
,t0.store_name
,coalesce(t1.component_sku_main_code,t0.sku_main_code) as sku_main_code
from
data_build.dw_order_sku_promotion_v1 t0 --订单明细表
left join sku_info t1 on t0.sku_main_code = t1.finished_sku_code
where
t0.dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
and t0.store_type = '0'
and t0.pay_status = 'PAY_SUCCESS'
--and t0.store_code = '101000262'
and t0.sku_class_code not in ('86', '50')
and t0.order_date >= '2024-02-26'
and t0.sku_division_name = '热餐'
group by
t0.order_date
,t0.store_code
,t0.store_name
,coalesce(t1.component_sku_main_code,t0.sku_main_code)

union all

select
cast(sale_date as date) as order_date--策略系统-销售日
,store_code
,store_name
,sku_main_code
from
data_smartorder.dm_ordering_book_particulars_store_sku_v1_di
where
dt > 20240223
--and store_code = '101000262'
and final_qty > 0
and sku_division_code = '0301'
and sale_date >= '2024-02-26'
group by
cast(sale_date as date) --策略系统-销售日
,store_code
,store_name
,sku_main_code

union all

select
cast(booking_date as date) as order_date --订货日期
,store_code
,store_name
,sku_main_code
    from
        data_smartorder.dm_ordering_book_particulars_store_sku_v1_di
    where
        dt > 20240223 --and store_code = '100078005'
        and final_qty > 0
        and sku_division_code = '0301'
        and booking_date >= '2024-02-26'
    group by
        cast(booking_date as date) --订货日期
,
        store_code,
        store_name,
        sku_main_code

union all

select
t0.create_date as order_date,
t0.store_code,
store_name,
coalesce(t2.component_sku_main_code,t1.sku_main_code) as sku_main_code
from
data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view t0
left join(
select
sku_code
,sku_main_code
from data_build.dim_sku_info
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
sku_code
,sku_main_code
) t1 on t0.sku_code = t1.sku_code
left join sku_info t2 on t1.sku_main_code = t2.finished_sku_code
where
dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
and sku_division_name = '热餐'
--and store_code = '101000262'
and create_date >= '2024-02-26'

union all

select
cast(order_date as date) as order_date,
store_code,
store_name,
sku_main_code
from
data_smartorder.dm_ordering_waste_correction_store_main_sku_di
where
dt >= 20240226
--and store_code ='101000262'
and sku_division_name = '热餐'
and waste_quantity <> '0'
) a
)

,hotmeal_sale as(
    select
        t0.order_date,
        t0.store_code,
        t0.store_name,
        coalesce(t1.component_sku_main_code,t0.sku_main_code) as sku_main_code,
        t0.sku_code,
        t0.sku_name,
        sum(t0.sku_quantity) as sku_quantity,
        sum(t0.payable_price) as hotmeal_payable_price
    from
        data_build.dw_order_sku_promotion_v1 t0 --订单明细表
        left join sku_info t1 on t0.sku_main_code = t1.finished_sku_code
    where
        t0.dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
        and t0.store_type = '0'
        and t0.pay_status = 'PAY_SUCCESS' --and store_code = '100078005'
        and t0.sku_class_code not in ('86', '50')
        and t0.order_date >= '2024-02-26'
        and t0.sku_division_name = '热餐'
    group by
        t0.order_date,
        t0.store_code,
        t0.store_name,
        coalesce(t1.component_sku_main_code,t0.sku_main_code),
        t0.sku_code,
        t0.sku_name
),

--非烟/全店/早餐/关东煮&炸品销售额
no_cigarette_sale as(
    select
        t.order_date,
        t.store_code,
        sum(case when t.sku_division_code not in ('6101', '6102', '6103') then t.payable_price else 0 end) / count(distinct t.order_date) as no_cigarette_order_payable_price --非香烟全部日商
        ,sum(t.payable_price) / count(distinct t.order_date) as store_sale --全店日商
        ,sum(case when t.sku_division_code in ('0303', '0502', '0601','0602','0604') then t.payable_price else 0 end) / count(distinct t.order_date) as breakfast_sale --早餐销售
        ,sum(case when t.sku_division_code in ('0302', '0501') then t.payable_price else 0 end) / count(distinct t.order_date) as oden_sale --关东煮&炸品销售
    from
        data_build.dw_order_sku_promotion_v1 t --订单明细表
    where
        dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
        and t.store_type = '0'
        and t.pay_status = 'PAY_SUCCESS'
        and t.sku_class_code not in ('86', '50')
        and t.order_date >= '2024-02-26'
        and sku_quantity > 0
    group by
        t.order_date,
        t.store_code
),
--热餐到货量
hotmeal_book as(
    select
       sale_date --策略系统-销售日(到货日)
,
        store_code,
        sku_main_code,
        sum(final_qty) as final_qty --订货数量
    from
        data_smartorder.dm_ordering_book_particulars_store_sku_v1_di
    where
        dt > 20240223 --and store_code = '100078005'
        and final_qty > 0
    group by
        sale_date --策略系统-销售日
,
        store_code,
        sku_main_code
),

--热餐定货量
hotmeal_booking as(
    select
        booking_date --订货日期
,
        store_code,
        sku_main_code,
        sum(final_qty) as final_qty --订货数量
    from
        data_smartorder.dm_ordering_book_particulars_store_sku_v1_di
    where
        dt > 20240223 --and store_code = '100078005'
        and final_qty > 0
    group by
    booking_date
,
        store_code,
        sku_main_code
),

--热餐制作量
hotmeal_make as(
    select
        t0.create_date,
        t0.store_code,
        coalesce(t2.component_sku_main_code,t1.sku_main_code) as sku_main_code,

        sum(t0.make_quantity) as make_quantity --制作数量
    from
        data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view t0
    left join(
select
sku_code
,sku_main_code
from data_build.dim_sku_info
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
sku_code
,sku_main_code
) t1 on t0.sku_code = t1.sku_code
left join sku_info t2 on t1.sku_main_code = t2.finished_sku_code
    where
        dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
        and sku_division_name = '热餐' --and store_code = '100078005'
    group by
        t0.create_date,
        t0.store_code,
        coalesce(t2.component_sku_main_code,t1.sku_main_code)
),
--废弃数量
hotmeal_waste as(
    select
        store_code,
        order_date,
        sku_main_code,
        sku_main_name,
        sku_division_name,
        waste_quantity,
        --废弃数量
        correction_waste_quantity,
        --冲正数量
        waste_amount,
        dt
    from
        data_smartorder.dm_ordering_waste_correction_store_main_sku_di
    where
        dt >= 20240226 --and store_code ='100078005'
),
--全店废弃
store_waste as(
    select
        order_date
        ,store_code
        ,abs(sum(waste_amount)) as waste_amount
    from
        data_smartorder.dm_ordering_waste_correction_store_main_sku_di
    where
        dt >= 20240226
    group by
     order_date
     ,store_code
),

--全店废弃后毛利
store_profit_after_waste as(
    with 
profit as
(select 
store_code
,order_date
,sum(payable_price) as sum_payable_price
,sum(cost_price) as sum_cost_price
,sum(cost_tax) as sum_cost_tax 
from data_build.dw_order_sku_v1
where order_date >= '2024-02-26'
and dt=date_format(date_sub(current_date(), 1), 'yyyyMMdd')
--and sku_division_code in('0301','0304','0302','0303','0313','0501','0502','0601','0602','0604')
and store_type = '0'
and order_status = 'FINISHED'
and sku_class_code not in ('86','50')
and sku_quantity > 0
group by
store_code
,order_date),


waste as
(select
store_code
,operating_date
,sum_waste_amount
,sum_waste_tax
,sum_waste_amount + sum_waste_tax as waste_amount --总废弃金额
from
(
select
 store_code
 ,operating_date
 ,sum(cost_price) as sum_waste_amount
 ,sum(cost_tax) as sum_waste_tax
from
 data_smartorder.dm_copy_dm_finance_daily_store_wastecost_di_v1_view_test
where
 dt >= '2024-02-26'
 --and sku_division_code in('0301','0304','0302','0303','0313','0501','0502','0601','0602','0604')
 and operating_date >= '2024-02-26'
group by
 store_code
 ,operating_date
 ) a
 )
 

select
t1.store_code
,t1.sum_payable_price
,t1.sum_cost_price
,t1.sum_cost_tax
,t2.sum_waste_amount
,t2.sum_waste_tax
,t1.sum_payable_price - t1.sum_cost_price - t1.sum_cost_tax - abs(t2.sum_waste_amount) - abs(t2.sum_waste_tax) as profit_after_waste --毛利
,t1.order_date
from profit t1
left join waste t2
on t1.store_code=t2.store_code and t1.order_date=t2.operating_date
),

--早餐类&关东煮&炸品到货量
breakfast_oden_book as(
    select
       sale_date --策略系统-销售日(到货日)
,
        store_code,
        sum(case when sku_division_code in ('0303','0502','0601','0602','0604') then final_qty else 0 end) as breakfast_final_qty --早餐类到货数量
        ,sum(case when sku_division_code in ('0302','0501') then final_qty else 0 end) as oden_final_qty --关东煮&炸品到货数量
    from
        data_smartorder.dm_ordering_book_particulars_store_sku_v1_di
    where
        dt > 20240223 --and store_code = '100078005'
        and final_qty > 0
    group by
        sale_date --策略系统-销售日
,
        store_code
),

--早餐类&关东煮&炸品制作量
breakfast_oden_make as(
    select
        t0.create_date,
        t0.store_code,

        sum(case when sku_division_code in ('0303','0502','0601','0602','0604') then make_quantity else 0 end) as breakfast_make_quantity --早餐类制作数量
        ,sum(case when sku_division_code in ('0302','0501') then make_quantity else 0 end) as oden_make_quantity --关东煮&炸品制作数量
    from
        data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view t0
    where
        dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
    group by
        t0.create_date,
        t0.store_code
)

--早餐类&关东煮&炸品销量
,breakfast_oden_sale as(
    select
        t0.order_date,
        t0.store_code,
        sum(case when sku_division_code in ('0303','0502','0601','0602','0604') then t0.sku_quantity else 0 end) as breakfast_quantity, --早餐类销量
        sum(case when sku_division_code in ('0302','0501') then t0.sku_quantity else 0 end) as oden_quantity --关东煮&炸品销量
    from
        data_build.dw_order_sku_promotion_v1 t0 --订单明细表
    where
        t0.dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
        and t0.store_type = '0'
        and t0.pay_status = 'PAY_SUCCESS' --and store_code = '100078005'
        and t0.sku_class_code not in ('86', '50')
        and t0.order_date >= '2024-02-26'
    group by
        t0.order_date,
        t0.store_code
),

--热餐&早餐类&关东煮&炸品废弃金额
breakfast_oden_waste as(
    select
        order_date
        ,store_code
        ,abs(sum(case when sku_division_code in ('0303','0502','0601','0602','0604') then waste_amount else 0 end)) as breakfast_waste_amount
        ,abs(sum(case when sku_division_code in ('0302','0501') then waste_amount else 0 end)) as oden_waste_amount
        ,abs(sum(case when sku_division_code in ('0301') then waste_amount else 0 end)) as hot_meal_amount
    from
        data_smartorder.dm_ordering_waste_correction_store_main_sku_di
    where
        dt >= 20240226
    group by
     order_date
     ,store_code
)


select
    t0.order_date,
    t0.store_code,
    t0.store_name,
    t6.stroe_type,
    t6.sale_type,
    t0.sku_main_code,
    t8.finished_sku_code as sku_code,
    t8.finished_sku_name as sku_name,
    t5.sku_type,
    t7.sku_quantity --热餐销售数量
,
    t1.no_cigarette_order_payable_price --非香烟全部日商
,
    t2.final_qty --到货数量
,
    t3.make_quantity --制作数量
,
    abs(t4.waste_quantity) as waste_quantity --废弃数量
,
    abs(t4.waste_quantity) /(abs(t4.waste_quantity) + t7.sku_quantity) as waste_per --废弃率

,   t7.hotmeal_payable_price --热餐销售金额

,   t10.final_qty as booking_final_qty --订货数量

,   t11.waste_amount --全店废弃金额

,   t1.store_sale --全店销售

,   t1.breakfast_sale --早餐销售

,   t1.oden_sale --关东煮&炸品销售

,   t12.breakfast_final_qty --早餐类到货数量

,   t12.oden_final_qty --关东煮&炸品到货数量

,   t13.breakfast_make_quantity --早餐类制作数量

,   t13.oden_make_quantity --关东煮&炸品制作数量

,   t14.breakfast_quantity --早餐类销量

,   t14.oden_quantity --关东煮&炸品销量

,   t15.breakfast_waste_amount --早餐类废弃金额

,   t15.oden_waste_amount --关东煮&炸品废弃金额

,   t15.hot_meal_amount --热餐废弃金额

,   t16.profit_after_waste --废弃后毛利
from
    store_sku_list t0
    left join no_cigarette_sale t1 on t0.order_date = t1.order_date
    and t0.store_code = t1.store_code
    left join hotmeal_book t2 on t0.order_date = t2.sale_date
    and t0.store_code = t2.store_code
    and t0.sku_main_code = t2.sku_main_code
    left join hotmeal_make t3 on t0.order_date = t3.create_date
    and t0.store_code = t3.store_code
    and t0.sku_main_code = t3.sku_main_code
    left join hotmeal_waste t4 on t0.order_date = t4.order_date
    and t0.store_code = t4.store_code
    and t0.sku_main_code = t4.sku_main_code
    left join data_build.ods_uploads_ods_uploads_store_type_v1 t6 on t0.store_code = t6.store_code
    left join hotmeal_sale t7 on t0.store_code = t7.store_code and t0.order_date = t7.order_date and t0.sku_main_code = t7.sku_main_code
    left join sku_info t8 on t0.sku_main_code = t8.component_sku_main_code
    left join data_build.ods_uploads_ods_uploads_meat_and_vegetable_v1 t5 on t8.finished_sku_code = t5.sku_code
    left join hotmeal_booking t10 on t0.order_date = t10.booking_date
    and t0.store_code = t10.store_code
    and t0.sku_main_code = t10.sku_main_code
    left join store_waste t11 on t0.order_date = t11.order_date
    and t0.store_code = t11.store_code
    left join breakfast_oden_book t12 on t0.order_date = t12.sale_date
    and t0.store_code = t12.store_code
    left join breakfast_oden_make t13 on t0.order_date = t13.create_date
    and t0.store_code = t13.store_code
    left join breakfast_oden_sale t14 on t0.order_date = t14.order_date
    and t0.store_code = t14.store_code
    left join breakfast_oden_waste t15 on t0.order_date = t15.order_date
    and t0.store_code = t15.store_code
    left join store_profit_after_waste t16 --废弃后毛利
    on t0.store_code = t16.store_code and t0.order_date = t16.order_date
where t0.store_code <> '100001625'

===============================================================================================================================================================================


--宇菲，等你有空的时候能不能帮忙在实验店的看板上再加一个废弃后毛利的页面
--废弃后毛利：实付金额（payable_price）-商品成本（cost_price）-商品成本税额（cost_tax）-废弃金额
--实付金额（payable_price）-商品成本（cost_price）-商品成本税额（cost_tax） ：这3个都是订单表里的字段，直接对全店求sum就行；然后废弃金额，就用我们用的废弃金额就可以
with 
profit as
(select 
store_city
,store_code
,store_name
,order_date
,sum(payable_price) as sum_payable_price
,sum(cost_price) as sum_cost_price
,sum(cost_tax) as sum_cost_tax 
from data_build.dw_order_sku_v1
where order_date >= '2024-02-26'
and dt=date_format(date_sub(current_date(), 1), 'yyyyMMdd')
--and sku_division_code in('0301','0304','0302','0303','0313','0501','0502','0601','0602','0604')
and store_type = '0'
and order_status = 'FINISHED'
and sku_class_code not in ('86','50')
and sku_quantity > 0
group by
store_city
,store_code
,store_name
,order_date),


waste as
(select
store_code
,operating_date
,sum_waste_amount
,sum_waste_tax
,sum_waste_amount + sum_waste_tax as waste_amount --总废弃金额
from
(
select
 store_code
 ,operating_date
 ,sum(cost_price) as sum_waste_amount
 ,sum(cost_tax) as sum_waste_tax
from
 data_smartorder.dm_copy_dm_finance_daily_store_wastecost_di_v1_view_test
where
 dt >= '2024-02-26'
 --and sku_division_code in('0301','0304','0302','0303','0313','0501','0502','0601','0602','0604')
 and operating_date >= '2024-02-26'
group by
 store_code
 ,operating_date
 ) a
 )
 

select
t1.store_city
,t1.store_code
,t1.sum_payable_price
,t1.sum_cost_price
,t1.sum_cost_tax
,t2.sum_waste_amount
,t2.sum_waste_tax
,t1.sum_payable_price - t1.sum_cost_price - t1.sum_cost_tax - abs(t2.sum_waste_amount) - abs(t2.sum_waste_tax) as profit_after_waste --毛利
,t1.order_date
from profit t1
left join waste t2
on t1.store_code=t2.store_code and t1.order_date=t2.operating_date