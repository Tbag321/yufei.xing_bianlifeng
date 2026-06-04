--门店商品信息,落表data_build.app_store_main_sku_list_info_da
--订货表
with tmp_five as
(select
booking_date--订货日期
,store_code
,sku_main_code
,sum(final_qty) as final_qty--订货数量
from data_smartorder.dm_ordering_book_particulars_store_sku_v1_di
where dt > date_format(date_sub(current_date(),30),'yyyyMMdd')
--and store_code = '110000636'
and final_qty > 0
group by
booking_date--订货日期
,store_code
,sku_main_code
),

--订货商品采购单价
--每天每店每个SKU_main_code的最大采购单价并排序，判断是否空值
tmp_one as(
select
booking_date
,store_code
,sku_main_code
,purchasing_unit_price--采购单价
,row_number ()over(partition by concat(booking_date,store_code,sku_main_code) order by purchasing_unit_price desc) as rn
from data_smartorder.dm_ordering_book_particulars_store_sku_v1_di
where dt > 20230701
--and store_code = '110000636'
),

tmp_two as(
select
* 
from tmp_one
where rn = 1
--order by concat(store_code,sku_main_code,booking_date)
--limit 1234567891456789
),

tmp_three as(
select
row_number ()over(order by concat(store_code,sku_main_code,booking_date)) as serial_number
,*
from tmp_two
),

sku_main_code_price as(
select
serial_number
,booking_date
,store_code
,sku_main_code
,purchasing_unit_price
,case when purchasing_unit_price = '' or purchasing_unit_price is null then 0 else 1 end as y_n
from tmp_three
),

cnt_y_n_list as(
select
serial_number
,booking_date
,store_code
,sku_main_code
,purchasing_unit_price
,y_n
,sum(y_n) over(partition by concat(store_code,sku_main_code) order by serial_number) as cnt_y_n
from sku_main_code_price
),

day_store_sku_price as(--商品单价
select
serial_number
,booking_date
,store_code
,sku_main_code
,purchasing_unit_price
,y_n
,cnt_y_n
,max(purchasing_unit_price) over(partition by concat(store_code,sku_main_code,cnt_y_n) order by serial_number) as final_purchasing_unit_price
from cnt_y_n_list
),

--商品实际售卖金额和数量--订单表
sku_main_sale as(
select
order_date
,store_code
,case when sku_main_code = '03030895' then '03030893' --黑米粥（新）
when sku_main_code = '03030942' then '03030941'--瘦肉青菜粥
else sku_main_code end as sku_main_code --目前发现有两个商品sku_main_code和订货表不一致，手动处理
,sum(sku_quantity) as sku_quantity--销售数量
,sum(payable_price) as payable_price--销售金额
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '110000636'
and t.sku_class_code not in ('86','50')
and order_date between date_format(date_sub(current_date(),30),'yyyy-MM-dd') and current_date()
group by
order_date
,store_code
,case when sku_main_code = '03030895' then '03030893' --黑米粥（新）
when sku_main_code = '03030942' then '03030941'--瘦肉青菜粥
else sku_main_code end
),

tmp_four as(
select
t2.serial_number
,t.record_date
,t.store_code
,t.store_name
,t.sku_division_name
,t.sku_main_code
,t.sku_main_name
,t2.final_purchasing_unit_price--采购单价
,t3.sku_quantity --订单表销售数量
,t3.payable_price --订单表销售金额
,case when t1.final_qty is null then 0 else t1.final_qty end as final_qty--订货数量
,sum(t.sku_inventory_beginning) as sku_inventory_beginning --期初库存
,sum(t.sku_inventory_endding) as sku_inventory_endding --期末库存
,abs(sum(t.sku_online_sale_quantity)+sum(t.sku_online_wholesale_quantity)+sum(t.sku_offline_sale_quantity)) as quantity --销售数量
,abs(sum(t.sku_stock_shrink_quantity)) as sku_stock_shrink_quantity --废弃数量
,sum(t.sku_purchase_quantity) as sku_purchase_quantity --到货数量
from data_smartorder.app_inventory_store_sku_di t
left join tmp_five t1 on t.store_code = t1.store_code and t.record_date = t1.booking_date and t.sku_main_code = t1.sku_main_code
left join day_store_sku_price t2 on t.store_code = t2.store_code and t.record_date = t2.booking_date and t.sku_main_code = t2.sku_main_code
left join sku_main_sale t3 on t.store_code = t3.store_code and t.record_date = t3.order_date and t.sku_main_code = t3.sku_main_code
where from_unixtime(unix_timestamp(t.dt,'yyyyMMdd'),'yyyy-MM-dd') between date_format(date_sub(current_date(),30),'yyyy-MM-dd') and current_date()
--and t.store_code = '110000636'
and store_type = '0'
group by
t2.serial_number
,t.record_date
,t.store_code
,t.store_name
,t.sku_division_name
,t.sku_main_code
,t.sku_main_name
,t2.final_purchasing_unit_price
,t3.sku_quantity --订单表销售数量
,t3.payable_price --订单表销售金额
,case when t1.final_qty is null then 0 else t1.final_qty end
),

--取有数据的sku_main
sku_main_list as(
select
store_code
,sku_main_code
,sum(final_purchasing_unit_price)
,sum(sku_quantity)
,sum(payable_price)
,sum(final_qty)
,sum(sku_inventory_beginning)
,sum(sku_inventory_endding)
,sum(sku_stock_shrink_quantity)
,sum(sku_purchase_quantity)
from(
select
serial_number
,record_date
,case when d.is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
,tmp.store_code
,tmp.store_name
,c.location_type
,tmp.sku_division_name
,tmp.sku_main_code
,sku_main_name
,case when final_purchasing_unit_price is null then 0 else final_purchasing_unit_price end as final_purchasing_unit_price
,case when sku_quantity is null then 0 else sku_quantity end as sku_quantity--销售数量已订单表为准
,case when payable_price is null then 0 else payable_price end as payable_price
,final_qty
,sku_inventory_beginning
,sku_inventory_endding
,sku_stock_shrink_quantity
,sku_purchase_quantity
from tmp_four tmp
left join data_build.dm_site_selection_project_feature_info_di c on tmp.store_code = c.store_code and c.dt = 20221114 --立地
left join default.dim_date_ya_v3 d on tmp.record_date = d.date_key
--and tmp.store_code = '100078005'
) a
group by
store_code
,sku_main_code
having sum(final_purchasing_unit_price)
+sum(sku_quantity)
+sum(payable_price)
+sum(final_qty)
+sum(sku_inventory_beginning)
+sum(sku_inventory_endding)
+sum(sku_stock_shrink_quantity)
+sum(sku_purchase_quantity) > 0
)

select
serial_number
,record_date
,case when d.is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
,tmp.store_code
,tmp.store_name
,c.location_type
,tmp.sku_division_name
,tmp.sku_main_code
,sku_main_name
,case when final_purchasing_unit_price is null then 0 else final_purchasing_unit_price end as final_purchasing_unit_price
,case when sku_quantity is null then 0 else sku_quantity end as sku_quantity--销售数量已订单表为准
,case when payable_price is null then 0 else payable_price end as payable_price
,final_qty
,sku_inventory_beginning
,sku_inventory_endding
,sku_stock_shrink_quantity
,sku_purchase_quantity
from tmp_four tmp
left join data_build.dm_site_selection_project_feature_info_di c on tmp.store_code = c.store_code and c.dt = 20221114 --立地
left join default.dim_date_ya_v3 d on tmp.record_date = d.date_key
join sku_main_list e on tmp.store_code = e.store_code and tmp.sku_main_code = e.sku_main_code










--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--排面情况
select 
store_name,
store_code,
snap_create_time,
effective_date,
shelf_name,
shelf_type,
sku_code,
display_status,
logistics_state_code,
sku_state_code
from data_smartorder.dw_sku_display_next_week_store_sku_display_all_history_di
where dt='20230114'
and store_name='歌华大厦店'

--订货表
select * from data_smartorder.dm_ordering_book_particulars_store_sku_v1_di t
where dt >='20231208'
and store_code='100078005' 
and booking_date between '2023-12-08' and '2023-12-13'
and final_qty >0

--废弃表
select
target_date
,store_code 
,date_sub(next_day(target_date,'mon'),7) as roster_week
,sku_division_code
,sum(zonghe_manual_waste_qty) as zonghe_correction_waste_qty --财务口径 废弃数量
,sum(zonghe_manual_waste_amount) as zonghe_correction_waste_amount --财务口径 纯录入废弃金额
from data_smartorder.dm_production_os_waste_presum_di
where dt= '${today-1}'
and target_date >= '2023-09-01'
and target_date <= '${TODAY-1}'
and store_code ='100078005'
group by target_date,store_code 
,sku_division_code

--进货表
select
sku_purchase_quantity
from data_smartorder.app_inventory_store_sku_di