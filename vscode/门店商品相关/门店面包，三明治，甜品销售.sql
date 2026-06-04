with time_list as(
select
'00:00:00-00:30:00' as time_range,'time_1' as time_name,'1' as joinkey
union all
select
'00:30:01-01:00:00','time_2','1' as joinkey
union all
select
'01:00:01-01:30:00','time_3','1' as joinkey
union all
select
'01:30:01-02:00:00','time_4','1' as joinkey
union all
select
'02:00:01-02:30:00','time_5','1' as joinkey
union all
select
'02:30:01-03:00:00','time_6','1' as joinkey
union all
select
'03:00:01-03:30:00','time_7','1' as joinkey
union all
select
'03:30:01-04:00:00','time_8','1' as joinkey
union all
select
'04:00:01-04:30:00','time_9','1' as joinkey
union all
select
'04:30:01-05:00:00','time_10','1' as joinkey
union all
select
'05:00:01-05:30:00','time_11','1' as joinkey
union all
select
'05:30:01-06:00:00','time_12','1' as joinkey
union all
select
'06:00:01-06:30:00','time_13','1' as joinkey
union all
select
'06:30:01-07:00:00','time_14','1' as joinkey
union all
select
'07:00:01-07:30:00','time_15','1' as joinkey
union all
select
'07:30:01-08:00:00','time_16','1' as joinkey
union all
select
'08:00:01-08:30:00','time_17','1' as joinkey
union all
select
'08:30:01-09:00:00','time_18','1' as joinkey
union all
select
'09:00:01-09:30:00','time_19','1' as joinkey
union all
select
'09:30:01-10:00:00','time_20','1' as joinkey
union all
select
'10:00:01-10:30:00','time_21','1' as joinkey
union all
select
'10:30:01-11:00:00','time_22','1' as joinkey
union all
select
'11:00:01-11:30:00','time_23','1' as joinkey
union all
select
'11:30:01-12:00:00','time_24','1' as joinkey
union all
select
'12:00:01-12:30:00','time_25','1' as joinkey
union all
select
'12:30:01-13:00:00','time_26','1' as joinkey
union all
select
'13:00:01-13:30:00','time_27','1' as joinkey
union all
select
'13:30:01-14:00:00','time_28','1' as joinkey
union all
select
'14:00:01-14:30:00','time_29','1' as joinkey
union all
select
'14:30:01-15:00:00','time_30','1' as joinkey
union all
select
'15:00:01-15:30:00','time_31','1' as joinkey
union all
select
'15:30:01-16:00:00','time_32','1' as joinkey
union all
select
'16:00:01-16:30:00','time_33','1' as joinkey
union all
select
'16:30:01-17:00:00','time_34','1' as joinkey
union all
select
'17:00:01-17:30:00','time_35','1' as joinkey
union all
select
'17:30:01-18:00:00','time_36','1' as joinkey
union all
select
'18:00:01-18:30:00','time_37','1' as joinkey
union all
select
'18:30:01-19:00:00','time_38','1' as joinkey
union all
select
'19:00:01-19:30:00','time_39','1' as joinkey
union all
select
'19:30:01-20:00:00','time_40','1' as joinkey
union all
select
'20:00:01-20:30:00','time_41','1' as joinkey
union all
select
'20:30:01-21:00:00','time_42','1' as joinkey
union all
select
'21:00:01-21:30:00','time_43','1' as joinkey
union all
select
'21:30:01-22:00:00','time_44','1' as joinkey
union all
select
'22:00:01-22:30:00','time_45','1' as joinkey
union all
select
'22:30:01-23:00:00','time_46','1' as joinkey
union all
select
'23:00:01-23:30:00','time_47','1' as joinkey
union all
select
'23:30:01-23:59:59','time_48','1' as joinkey
),

store_list as(
select
order_date,
store_code,
'1' as joinkey
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-01-01' and '2023-12-31'
group by
order_date,
store_code,
'1'
),

store_time_list as(
select
a.order_date
,a.store_code
,b.time_range
,b.time_name
from store_list a
cross join time_list b on a.joinkey = b.joinkey
),

sale_list as(
select
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '00:30:00' then '00:00:00-00:30:00'
when substr(order_time,12,8) between '00:30:01' and '01:00:00' then '00:30:01-01:00:00'
when substr(order_time,12,8) between '01:00:01' and '01:30:00' then '01:00:01-01:30:00'
when substr(order_time,12,8) between '01:30:01' and '02:00:00' then '01:30:01-02:00:00'
when substr(order_time,12,8) between '02:00:01' and '02:30:00' then '02:00:01-02:30:00'
when substr(order_time,12,8) between '02:30:01' and '03:00:00' then '02:30:01-03:00:00'
when substr(order_time,12,8) between '03:00:01' and '03:30:00' then '03:00:01-03:30:00'
when substr(order_time,12,8) between '03:30:01' and '04:00:00' then '03:30:01-04:00:00'
when substr(order_time,12,8) between '04:00:01' and '04:30:00' then '04:00:01-04:30:00'
when substr(order_time,12,8) between '04:30:01' and '05:00:00' then '04:30:01-05:00:00'
when substr(order_time,12,8) between '05:00:01' and '05:30:00' then '05:00:01-05:30:00'
when substr(order_time,12,8) between '05:30:01' and '06:00:00' then '05:30:01-06:00:00'
when substr(order_time,12,8) between '06:00:01' and '06:30:00' then '06:00:01-06:30:00'
when substr(order_time,12,8) between '06:30:01' and '07:00:00' then '06:30:01-07:00:00'
when substr(order_time,12,8) between '07:00:01' and '07:30:00' then '07:00:01-07:30:00'
when substr(order_time,12,8) between '07:30:01' and '08:00:00' then '07:30:01-08:00:00'
when substr(order_time,12,8) between '08:00:01' and '08:30:00' then '08:00:01-08:30:00'
when substr(order_time,12,8) between '08:30:01' and '09:00:00' then '08:30:01-09:00:00'
when substr(order_time,12,8) between '09:00:01' and '09:30:00' then '09:00:01-09:30:00'
when substr(order_time,12,8) between '09:30:01' and '10:00:00' then '09:30:01-10:00:00'
when substr(order_time,12,8) between '10:00:01' and '10:30:00' then '10:00:01-10:30:00'
when substr(order_time,12,8) between '10:30:01' and '11:00:00' then '10:30:01-11:00:00'
when substr(order_time,12,8) between '11:00:01' and '11:30:00' then '11:00:01-11:30:00'
when substr(order_time,12,8) between '11:30:01' and '12:00:00' then '11:30:01-12:00:00'
when substr(order_time,12,8) between '12:00:01' and '12:30:00' then '12:00:01-12:30:00'
when substr(order_time,12,8) between '12:30:01' and '13:00:00' then '12:30:01-13:00:00'
when substr(order_time,12,8) between '13:00:01' and '13:30:00' then '13:00:01-13:30:00'
when substr(order_time,12,8) between '13:30:01' and '14:00:00' then '13:30:01-14:00:00'
when substr(order_time,12,8) between '14:00:01' and '14:30:00' then '14:00:01-14:30:00'
when substr(order_time,12,8) between '14:30:01' and '15:00:00' then '14:30:01-15:00:00'
when substr(order_time,12,8) between '15:00:01' and '15:30:00' then '15:00:01-15:30:00'
when substr(order_time,12,8) between '15:30:01' and '16:00:00' then '15:30:01-16:00:00'
when substr(order_time,12,8) between '16:00:01' and '16:30:00' then '16:00:01-16:30:00'
when substr(order_time,12,8) between '16:30:01' and '17:00:00' then '16:30:01-17:00:00'
when substr(order_time,12,8) between '17:00:01' and '17:30:00' then '17:00:01-17:30:00'
when substr(order_time,12,8) between '17:30:01' and '18:00:00' then '17:30:01-18:00:00'
when substr(order_time,12,8) between '18:00:01' and '18:30:00' then '18:00:01-18:30:00'
when substr(order_time,12,8) between '18:30:01' and '19:00:00' then '18:30:01-19:00:00'
when substr(order_time,12,8) between '19:00:01' and '19:30:00' then '19:00:01-19:30:00'
when substr(order_time,12,8) between '19:30:01' and '20:00:00' then '19:30:01-20:00:00'
when substr(order_time,12,8) between '20:00:01' and '20:30:00' then '20:00:01-20:30:00'
when substr(order_time,12,8) between '20:30:01' and '21:00:00' then '20:30:01-21:00:00'
when substr(order_time,12,8) between '21:00:01' and '21:30:00' then '21:00:01-21:30:00'
when substr(order_time,12,8) between '21:30:01' and '22:00:00' then '21:30:01-22:00:00'
when substr(order_time,12,8) between '22:00:01' and '22:30:00' then '22:00:01-22:30:00'
when substr(order_time,12,8) between '22:30:01' and '23:00:00' then '22:30:01-23:00:00'
when substr(order_time,12,8) between '23:00:01' and '23:30:00' then '23:00:01-23:30:00'
when substr(order_time,12,8) between '23:30:01' and '23:59:59' then '23:30:01-23:59:59'
end as time_range
,sum(payable_price) as payable_price
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread --面包
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-01-01' and '2023-12-31'
and sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109','0201','0202','1101','1102','1103','1104','1105','1210','0204')
group by
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '00:30:00' then '00:00:00-00:30:00'
when substr(order_time,12,8) between '00:30:01' and '01:00:00' then '00:30:01-01:00:00'
when substr(order_time,12,8) between '01:00:01' and '01:30:00' then '01:00:01-01:30:00'
when substr(order_time,12,8) between '01:30:01' and '02:00:00' then '01:30:01-02:00:00'
when substr(order_time,12,8) between '02:00:01' and '02:30:00' then '02:00:01-02:30:00'
when substr(order_time,12,8) between '02:30:01' and '03:00:00' then '02:30:01-03:00:00'
when substr(order_time,12,8) between '03:00:01' and '03:30:00' then '03:00:01-03:30:00'
when substr(order_time,12,8) between '03:30:01' and '04:00:00' then '03:30:01-04:00:00'
when substr(order_time,12,8) between '04:00:01' and '04:30:00' then '04:00:01-04:30:00'
when substr(order_time,12,8) between '04:30:01' and '05:00:00' then '04:30:01-05:00:00'
when substr(order_time,12,8) between '05:00:01' and '05:30:00' then '05:00:01-05:30:00'
when substr(order_time,12,8) between '05:30:01' and '06:00:00' then '05:30:01-06:00:00'
when substr(order_time,12,8) between '06:00:01' and '06:30:00' then '06:00:01-06:30:00'
when substr(order_time,12,8) between '06:30:01' and '07:00:00' then '06:30:01-07:00:00'
when substr(order_time,12,8) between '07:00:01' and '07:30:00' then '07:00:01-07:30:00'
when substr(order_time,12,8) between '07:30:01' and '08:00:00' then '07:30:01-08:00:00'
when substr(order_time,12,8) between '08:00:01' and '08:30:00' then '08:00:01-08:30:00'
when substr(order_time,12,8) between '08:30:01' and '09:00:00' then '08:30:01-09:00:00'
when substr(order_time,12,8) between '09:00:01' and '09:30:00' then '09:00:01-09:30:00'
when substr(order_time,12,8) between '09:30:01' and '10:00:00' then '09:30:01-10:00:00'
when substr(order_time,12,8) between '10:00:01' and '10:30:00' then '10:00:01-10:30:00'
when substr(order_time,12,8) between '10:30:01' and '11:00:00' then '10:30:01-11:00:00'
when substr(order_time,12,8) between '11:00:01' and '11:30:00' then '11:00:01-11:30:00'
when substr(order_time,12,8) between '11:30:01' and '12:00:00' then '11:30:01-12:00:00'
when substr(order_time,12,8) between '12:00:01' and '12:30:00' then '12:00:01-12:30:00'
when substr(order_time,12,8) between '12:30:01' and '13:00:00' then '12:30:01-13:00:00'
when substr(order_time,12,8) between '13:00:01' and '13:30:00' then '13:00:01-13:30:00'
when substr(order_time,12,8) between '13:30:01' and '14:00:00' then '13:30:01-14:00:00'
when substr(order_time,12,8) between '14:00:01' and '14:30:00' then '14:00:01-14:30:00'
when substr(order_time,12,8) between '14:30:01' and '15:00:00' then '14:30:01-15:00:00'
when substr(order_time,12,8) between '15:00:01' and '15:30:00' then '15:00:01-15:30:00'
when substr(order_time,12,8) between '15:30:01' and '16:00:00' then '15:30:01-16:00:00'
when substr(order_time,12,8) between '16:00:01' and '16:30:00' then '16:00:01-16:30:00'
when substr(order_time,12,8) between '16:30:01' and '17:00:00' then '16:30:01-17:00:00'
when substr(order_time,12,8) between '17:00:01' and '17:30:00' then '17:00:01-17:30:00'
when substr(order_time,12,8) between '17:30:01' and '18:00:00' then '17:30:01-18:00:00'
when substr(order_time,12,8) between '18:00:01' and '18:30:00' then '18:00:01-18:30:00'
when substr(order_time,12,8) between '18:30:01' and '19:00:00' then '18:30:01-19:00:00'
when substr(order_time,12,8) between '19:00:01' and '19:30:00' then '19:00:01-19:30:00'
when substr(order_time,12,8) between '19:30:01' and '20:00:00' then '19:30:01-20:00:00'
when substr(order_time,12,8) between '20:00:01' and '20:30:00' then '20:00:01-20:30:00'
when substr(order_time,12,8) between '20:30:01' and '21:00:00' then '20:30:01-21:00:00'
when substr(order_time,12,8) between '21:00:01' and '21:30:00' then '21:00:01-21:30:00'
when substr(order_time,12,8) between '21:30:01' and '22:00:00' then '21:30:01-22:00:00'
when substr(order_time,12,8) between '22:00:01' and '22:30:00' then '22:00:01-22:30:00'
when substr(order_time,12,8) between '22:30:01' and '23:00:00' then '22:30:01-23:00:00'
when substr(order_time,12,8) between '23:00:01' and '23:30:00' then '23:00:01-23:30:00'
when substr(order_time,12,8) between '23:30:01' and '23:59:59' then '23:30:01-23:59:59'
end
),

full_list as(
select
a.order_date
,a.store_code
,a.time_name
,a.time_range
,b.payable_price
,b.bread
,b.sandwich_burger
,b.dessert_fast_food_and_other
from store_time_list a
left join sale_list b on a.store_code = b.store_code and a.order_date = b.order_date and a.time_range = b.time_range
)

select
order_date
,time_range
,count(distinct store_code) as store_num
,sum(payable_price) as payable_price
,sum(bread) as bread
,sum(sandwich_burger) as sandwich_burger
,sum(dessert_fast_food_and_other) as dessert_fast_food_and_other
from full_list
group by
order_date
,time_range

================================================================================================================================================================================================================
--7个品类的分时段销售情况 --2024.05.23
with time_list as(
select
'00:00:00-00:30:00' as time_range,'time_1' as time_name,'1' as joinkey
union all
select
'00:30:01-01:00:00','time_2','1' as joinkey
union all
select
'01:00:01-01:30:00','time_3','1' as joinkey
union all
select
'01:30:01-02:00:00','time_4','1' as joinkey
union all
select
'02:00:01-02:30:00','time_5','1' as joinkey
union all
select
'02:30:01-03:00:00','time_6','1' as joinkey
union all
select
'03:00:01-03:30:00','time_7','1' as joinkey
union all
select
'03:30:01-04:00:00','time_8','1' as joinkey
union all
select
'04:00:01-04:30:00','time_9','1' as joinkey
union all
select
'04:30:01-05:00:00','time_10','1' as joinkey
union all
select
'05:00:01-05:30:00','time_11','1' as joinkey
union all
select
'05:30:01-06:00:00','time_12','1' as joinkey
union all
select
'06:00:01-06:30:00','time_13','1' as joinkey
union all
select
'06:30:01-07:00:00','time_14','1' as joinkey
union all
select
'07:00:01-07:30:00','time_15','1' as joinkey
union all
select
'07:30:01-08:00:00','time_16','1' as joinkey
union all
select
'08:00:01-08:30:00','time_17','1' as joinkey
union all
select
'08:30:01-09:00:00','time_18','1' as joinkey
union all
select
'09:00:01-09:30:00','time_19','1' as joinkey
union all
select
'09:30:01-10:00:00','time_20','1' as joinkey
union all
select
'10:00:01-10:30:00','time_21','1' as joinkey
union all
select
'10:30:01-11:00:00','time_22','1' as joinkey
union all
select
'11:00:01-11:30:00','time_23','1' as joinkey
union all
select
'11:30:01-12:00:00','time_24','1' as joinkey
union all
select
'12:00:01-12:30:00','time_25','1' as joinkey
union all
select
'12:30:01-13:00:00','time_26','1' as joinkey
union all
select
'13:00:01-13:30:00','time_27','1' as joinkey
union all
select
'13:30:01-14:00:00','time_28','1' as joinkey
union all
select
'14:00:01-14:30:00','time_29','1' as joinkey
union all
select
'14:30:01-15:00:00','time_30','1' as joinkey
union all
select
'15:00:01-15:30:00','time_31','1' as joinkey
union all
select
'15:30:01-16:00:00','time_32','1' as joinkey
union all
select
'16:00:01-16:30:00','time_33','1' as joinkey
union all
select
'16:30:01-17:00:00','time_34','1' as joinkey
union all
select
'17:00:01-17:30:00','time_35','1' as joinkey
union all
select
'17:30:01-18:00:00','time_36','1' as joinkey
union all
select
'18:00:01-18:30:00','time_37','1' as joinkey
union all
select
'18:30:01-19:00:00','time_38','1' as joinkey
union all
select
'19:00:01-19:30:00','time_39','1' as joinkey
union all
select
'19:30:01-20:00:00','time_40','1' as joinkey
union all
select
'20:00:01-20:30:00','time_41','1' as joinkey
union all
select
'20:30:01-21:00:00','time_42','1' as joinkey
union all
select
'21:00:01-21:30:00','time_43','1' as joinkey
union all
select
'21:30:01-22:00:00','time_44','1' as joinkey
union all
select
'22:00:01-22:30:00','time_45','1' as joinkey
union all
select
'22:30:01-23:00:00','time_46','1' as joinkey
union all
select
'23:00:01-23:30:00','time_47','1' as joinkey
union all
select
'23:30:01-23:59:59','time_48','1' as joinkey
),

store_list as(
select
order_date,
store_code,
'1' as joinkey
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-01-01' and '2024-05-22'
and store_city = '北京市'
group by
order_date,
store_code,
'1'
),

store_time_list as(
select
a.order_date
,a.store_code
,b.time_range
,b.time_name
from store_list a
cross join time_list b on a.joinkey = b.joinkey
),

sale_list as(
select
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '00:30:00' then '00:00:00-00:30:00'
when substr(order_time,12,8) between '00:30:01' and '01:00:00' then '00:30:01-01:00:00'
when substr(order_time,12,8) between '01:00:01' and '01:30:00' then '01:00:01-01:30:00'
when substr(order_time,12,8) between '01:30:01' and '02:00:00' then '01:30:01-02:00:00'
when substr(order_time,12,8) between '02:00:01' and '02:30:00' then '02:00:01-02:30:00'
when substr(order_time,12,8) between '02:30:01' and '03:00:00' then '02:30:01-03:00:00'
when substr(order_time,12,8) between '03:00:01' and '03:30:00' then '03:00:01-03:30:00'
when substr(order_time,12,8) between '03:30:01' and '04:00:00' then '03:30:01-04:00:00'
when substr(order_time,12,8) between '04:00:01' and '04:30:00' then '04:00:01-04:30:00'
when substr(order_time,12,8) between '04:30:01' and '05:00:00' then '04:30:01-05:00:00'
when substr(order_time,12,8) between '05:00:01' and '05:30:00' then '05:00:01-05:30:00'
when substr(order_time,12,8) between '05:30:01' and '06:00:00' then '05:30:01-06:00:00'
when substr(order_time,12,8) between '06:00:01' and '06:30:00' then '06:00:01-06:30:00'
when substr(order_time,12,8) between '06:30:01' and '07:00:00' then '06:30:01-07:00:00'
when substr(order_time,12,8) between '07:00:01' and '07:30:00' then '07:00:01-07:30:00'
when substr(order_time,12,8) between '07:30:01' and '08:00:00' then '07:30:01-08:00:00'
when substr(order_time,12,8) between '08:00:01' and '08:30:00' then '08:00:01-08:30:00'
when substr(order_time,12,8) between '08:30:01' and '09:00:00' then '08:30:01-09:00:00'
when substr(order_time,12,8) between '09:00:01' and '09:30:00' then '09:00:01-09:30:00'
when substr(order_time,12,8) between '09:30:01' and '10:00:00' then '09:30:01-10:00:00'
when substr(order_time,12,8) between '10:00:01' and '10:30:00' then '10:00:01-10:30:00'
when substr(order_time,12,8) between '10:30:01' and '11:00:00' then '10:30:01-11:00:00'
when substr(order_time,12,8) between '11:00:01' and '11:30:00' then '11:00:01-11:30:00'
when substr(order_time,12,8) between '11:30:01' and '12:00:00' then '11:30:01-12:00:00'
when substr(order_time,12,8) between '12:00:01' and '12:30:00' then '12:00:01-12:30:00'
when substr(order_time,12,8) between '12:30:01' and '13:00:00' then '12:30:01-13:00:00'
when substr(order_time,12,8) between '13:00:01' and '13:30:00' then '13:00:01-13:30:00'
when substr(order_time,12,8) between '13:30:01' and '14:00:00' then '13:30:01-14:00:00'
when substr(order_time,12,8) between '14:00:01' and '14:30:00' then '14:00:01-14:30:00'
when substr(order_time,12,8) between '14:30:01' and '15:00:00' then '14:30:01-15:00:00'
when substr(order_time,12,8) between '15:00:01' and '15:30:00' then '15:00:01-15:30:00'
when substr(order_time,12,8) between '15:30:01' and '16:00:00' then '15:30:01-16:00:00'
when substr(order_time,12,8) between '16:00:01' and '16:30:00' then '16:00:01-16:30:00'
when substr(order_time,12,8) between '16:30:01' and '17:00:00' then '16:30:01-17:00:00'
when substr(order_time,12,8) between '17:00:01' and '17:30:00' then '17:00:01-17:30:00'
when substr(order_time,12,8) between '17:30:01' and '18:00:00' then '17:30:01-18:00:00'
when substr(order_time,12,8) between '18:00:01' and '18:30:00' then '18:00:01-18:30:00'
when substr(order_time,12,8) between '18:30:01' and '19:00:00' then '18:30:01-19:00:00'
when substr(order_time,12,8) between '19:00:01' and '19:30:00' then '19:00:01-19:30:00'
when substr(order_time,12,8) between '19:30:01' and '20:00:00' then '19:30:01-20:00:00'
when substr(order_time,12,8) between '20:00:01' and '20:30:00' then '20:00:01-20:30:00'
when substr(order_time,12,8) between '20:30:01' and '21:00:00' then '20:30:01-21:00:00'
when substr(order_time,12,8) between '21:00:01' and '21:30:00' then '21:00:01-21:30:00'
when substr(order_time,12,8) between '21:30:01' and '22:00:00' then '21:30:01-22:00:00'
when substr(order_time,12,8) between '22:00:01' and '22:30:00' then '22:00:01-22:30:00'
when substr(order_time,12,8) between '22:30:01' and '23:00:00' then '22:30:01-23:00:00'
when substr(order_time,12,8) between '23:00:01' and '23:30:00' then '23:00:01-23:30:00'
when substr(order_time,12,8) between '23:30:01' and '23:59:59' then '23:30:01-23:59:59'
end as time_range
,sum(payable_price) as payable_price
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_and_roasted_products --FF料理炸烤制品
,sum(case when sku_division_code in ('0303') then payable_price else 0 end) as FF_Cuisine_Snacks --FF料理小吃
,sum(case when sku_division_code in ('0501') then payable_price else 0 end) as FF_Cute_Cooking --FF萌煮
,sum(case when sku_division_code in ('0502') then payable_price else 0 end) as eggs_boiled --茶鸡蛋
,sum(case when sku_division_code in ('0601') then payable_price else 0 end) as Steamed_bun --蒸包
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as Breakfast_pastry --早餐酥饼
,sum(case when sku_division_code in ('0604') then payable_price else 0 end) as corn --玉米
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-01-01' and '2024-05-22'
and sku_division_code in ('0302','0303','0501','0502','0601','0602','0604')
and store_city = '北京市'
group by
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '00:30:00' then '00:00:00-00:30:00'
when substr(order_time,12,8) between '00:30:01' and '01:00:00' then '00:30:01-01:00:00'
when substr(order_time,12,8) between '01:00:01' and '01:30:00' then '01:00:01-01:30:00'
when substr(order_time,12,8) between '01:30:01' and '02:00:00' then '01:30:01-02:00:00'
when substr(order_time,12,8) between '02:00:01' and '02:30:00' then '02:00:01-02:30:00'
when substr(order_time,12,8) between '02:30:01' and '03:00:00' then '02:30:01-03:00:00'
when substr(order_time,12,8) between '03:00:01' and '03:30:00' then '03:00:01-03:30:00'
when substr(order_time,12,8) between '03:30:01' and '04:00:00' then '03:30:01-04:00:00'
when substr(order_time,12,8) between '04:00:01' and '04:30:00' then '04:00:01-04:30:00'
when substr(order_time,12,8) between '04:30:01' and '05:00:00' then '04:30:01-05:00:00'
when substr(order_time,12,8) between '05:00:01' and '05:30:00' then '05:00:01-05:30:00'
when substr(order_time,12,8) between '05:30:01' and '06:00:00' then '05:30:01-06:00:00'
when substr(order_time,12,8) between '06:00:01' and '06:30:00' then '06:00:01-06:30:00'
when substr(order_time,12,8) between '06:30:01' and '07:00:00' then '06:30:01-07:00:00'
when substr(order_time,12,8) between '07:00:01' and '07:30:00' then '07:00:01-07:30:00'
when substr(order_time,12,8) between '07:30:01' and '08:00:00' then '07:30:01-08:00:00'
when substr(order_time,12,8) between '08:00:01' and '08:30:00' then '08:00:01-08:30:00'
when substr(order_time,12,8) between '08:30:01' and '09:00:00' then '08:30:01-09:00:00'
when substr(order_time,12,8) between '09:00:01' and '09:30:00' then '09:00:01-09:30:00'
when substr(order_time,12,8) between '09:30:01' and '10:00:00' then '09:30:01-10:00:00'
when substr(order_time,12,8) between '10:00:01' and '10:30:00' then '10:00:01-10:30:00'
when substr(order_time,12,8) between '10:30:01' and '11:00:00' then '10:30:01-11:00:00'
when substr(order_time,12,8) between '11:00:01' and '11:30:00' then '11:00:01-11:30:00'
when substr(order_time,12,8) between '11:30:01' and '12:00:00' then '11:30:01-12:00:00'
when substr(order_time,12,8) between '12:00:01' and '12:30:00' then '12:00:01-12:30:00'
when substr(order_time,12,8) between '12:30:01' and '13:00:00' then '12:30:01-13:00:00'
when substr(order_time,12,8) between '13:00:01' and '13:30:00' then '13:00:01-13:30:00'
when substr(order_time,12,8) between '13:30:01' and '14:00:00' then '13:30:01-14:00:00'
when substr(order_time,12,8) between '14:00:01' and '14:30:00' then '14:00:01-14:30:00'
when substr(order_time,12,8) between '14:30:01' and '15:00:00' then '14:30:01-15:00:00'
when substr(order_time,12,8) between '15:00:01' and '15:30:00' then '15:00:01-15:30:00'
when substr(order_time,12,8) between '15:30:01' and '16:00:00' then '15:30:01-16:00:00'
when substr(order_time,12,8) between '16:00:01' and '16:30:00' then '16:00:01-16:30:00'
when substr(order_time,12,8) between '16:30:01' and '17:00:00' then '16:30:01-17:00:00'
when substr(order_time,12,8) between '17:00:01' and '17:30:00' then '17:00:01-17:30:00'
when substr(order_time,12,8) between '17:30:01' and '18:00:00' then '17:30:01-18:00:00'
when substr(order_time,12,8) between '18:00:01' and '18:30:00' then '18:00:01-18:30:00'
when substr(order_time,12,8) between '18:30:01' and '19:00:00' then '18:30:01-19:00:00'
when substr(order_time,12,8) between '19:00:01' and '19:30:00' then '19:00:01-19:30:00'
when substr(order_time,12,8) between '19:30:01' and '20:00:00' then '19:30:01-20:00:00'
when substr(order_time,12,8) between '20:00:01' and '20:30:00' then '20:00:01-20:30:00'
when substr(order_time,12,8) between '20:30:01' and '21:00:00' then '20:30:01-21:00:00'
when substr(order_time,12,8) between '21:00:01' and '21:30:00' then '21:00:01-21:30:00'
when substr(order_time,12,8) between '21:30:01' and '22:00:00' then '21:30:01-22:00:00'
when substr(order_time,12,8) between '22:00:01' and '22:30:00' then '22:00:01-22:30:00'
when substr(order_time,12,8) between '22:30:01' and '23:00:00' then '22:30:01-23:00:00'
when substr(order_time,12,8) between '23:00:01' and '23:30:00' then '23:00:01-23:30:00'
when substr(order_time,12,8) between '23:30:01' and '23:59:59' then '23:30:01-23:59:59'
end
),

full_list as(
select
a.order_date
,a.store_code
,a.time_name
,a.time_range
,b.payable_price
,b.fried_and_roasted_products
,b.FF_Cuisine_Snacks
,b.FF_Cute_Cooking
,b.eggs_boiled
,b.Steamed_bun
,b.Breakfast_pastry
,b.corn
from store_time_list a
left join sale_list b on a.store_code = b.store_code and a.order_date = b.order_date and a.time_range = b.time_range
)

select
order_date
,time_range
,count(distinct store_code) as store_num
,sum(payable_price) as payable_price
,sum(fried_and_roasted_products) as fried_and_roasted_products
,sum(FF_Cuisine_Snacks) as FF_Cuisine_Snacks
,sum(FF_Cute_Cooking) as FF_Cute_Cooking
,sum(eggs_boiled) as eggs_boiled
,sum(Steamed_bun) as Steamed_bun
,sum(Breakfast_pastry) as Breakfast_pastry
,sum(corn) as corn
from full_list
group by
order_date
,time_range

=============================================================================================================================================
--分时段库存 --还没整明白
with sku_info as(
SELECT
finished_sku_code
,finished_sku_name
,component_sku_main_code
,sku_type
from data_smartorder.dw_order_sku_promotion_teardown_ratio_v1
where dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd')
--and component_sku_division_code = '0301'
--and sku_type in ('4','6') --车次商品
and finished_sku_code not in ('09060006','03014042','03012192')
GROUP BY
finished_sku_code
,finished_sku_name
,component_sku_main_code
,sku_type
),

inventory_list as(
select
t0.store_code
,record_date
,hr
,sku_code
,sku_name
,sku_division_code
,t3.sku_type
,sum(all_quantity) as all_quantity
from data_smartorder.app_inventory_store_sku_everyhour_ha t0
left join data_build.ods_uploads_ods_uploads_store_type_v1 t2 on t0.store_code = t2.store_code
left join sku_info t3 on t0.sku_code = t3.finished_sku_code
where from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') between '2024-05-20' and '2024-05-22'
and t0.store_code = '100078005'
and (t2.stroe_type = '试验组' or t0.store_code = '100078005')
and sku_division_code in ('0302','0303','0501','0502','0601','0602','0604')
group by
t0.store_code
,record_date
,hr
,sku_code
,sku_name
,sku_division_code
,t3.sku_type
),

sale_list as(
select
*
from(
select
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '05:00:00' then '00'

when substr(order_time,12,8) between '05:00:01' and '06:00:00' then '05'

when substr(order_time,12,8) between '06:00:01' and '07:00:00' then '06'

when substr(order_time,12,8) between '07:00:01' and '08:00:00' then '07'

when substr(order_time,12,8) between '08:00:01' and '09:00:00' then '08'

when substr(order_time,12,8) between '09:00:01' and '10:00:00' then '09'

when substr(order_time,12,8) between '10:00:01' and '11:00:00' then '10'

when substr(order_time,12,8) between '11:00:01' and '12:00:00' then '11'

when substr(order_time,12,8) between '12:00:01' and '13:00:00' then '12'

when substr(order_time,12,8) between '13:00:01' and '14:00:00' then '13'

when substr(order_time,12,8) between '14:00:01' and '15:00:00' then '14'

when substr(order_time,12,8) between '15:00:01' and '16:00:00' then '15'

when substr(order_time,12,8) between '16:00:01' and '17:00:00' then '16'

when substr(order_time,12,8) between '17:00:01' and '18:00:00' then '17'

when substr(order_time,12,8) between '18:00:01' and '19:00:00' then '18'

when substr(order_time,12,8) between '19:00:01' and '20:00:00' then '19'

when substr(order_time,12,8) between '20:00:01' and '21:00:00' then '20'

when substr(order_time,12,8) between '21:00:01' and '22:00:00' then '21'

when substr(order_time,12,8) between '22:00:01' and '23:00:00' then '22'

when substr(order_time,12,8) between '23:00:01' and '23:59:59' then '23'

end as time_range
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_and_roasted_products --FF料理炸烤制品
,sum(case when sku_division_code in ('0303') then payable_price else 0 end) as FF_Cuisine_Snacks --FF料理小吃
,sum(case when sku_division_code in ('0501') then payable_price else 0 end) as FF_Cute_Cooking --FF萌煮
,sum(case when sku_division_code in ('0502') then payable_price else 0 end) as eggs_boiled --茶鸡蛋
,sum(case when sku_division_code in ('0601') then payable_price else 0 end) as Steamed_bun --蒸包
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as Breakfast_pastry --早餐酥饼
,sum(case when sku_division_code in ('0604') then payable_price else 0 end) as corn --玉米
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-05-20' and '2024-05-22'
and sku_division_code in ('0302','0303','0501','0502','0601','0602','0604')
--and store_city = '北京市'
group by
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '05:00:00' then '00'

when substr(order_time,12,8) between '05:00:01' and '06:00:00' then '05'

when substr(order_time,12,8) between '06:00:01' and '07:00:00' then '06'

when substr(order_time,12,8) between '07:00:01' and '08:00:00' then '07'

when substr(order_time,12,8) between '08:00:01' and '09:00:00' then '08'

when substr(order_time,12,8) between '09:00:01' and '10:00:00' then '09'

when substr(order_time,12,8) between '10:00:01' and '11:00:00' then '10'

when substr(order_time,12,8) between '11:00:01' and '12:00:00' then '11'

when substr(order_time,12,8) between '12:00:01' and '13:00:00' then '12'

when substr(order_time,12,8) between '13:00:01' and '14:00:00' then '13'

when substr(order_time,12,8) between '14:00:01' and '15:00:00' then '14'

when substr(order_time,12,8) between '15:00:01' and '16:00:00' then '15'

when substr(order_time,12,8) between '16:00:01' and '17:00:00' then '16'

when substr(order_time,12,8) between '17:00:01' and '18:00:00' then '17'

when substr(order_time,12,8) between '18:00:01' and '19:00:00' then '18'

when substr(order_time,12,8) between '19:00:01' and '20:00:00' then '19'

when substr(order_time,12,8) between '20:00:01' and '21:00:00' then '20'

when substr(order_time,12,8) between '21:00:01' and '22:00:00' then '21'

when substr(order_time,12,8) between '22:00:01' and '23:00:00' then '22'

when substr(order_time,12,8) between '23:00:01' and '23:59:59' then '23'

end
) a
LATERAL VIEW explode(map('0302',fried_and_roasted_products,'0303',FF_Cuisine_Snacks,'0501',FF_Cute_Cooking,'0502',eggs_boiled,'0601',Steamed_bun
,'0602',Breakfast_pastry,'0604',corn)) b as commodity_tyoe , commodity_payable_price
)

select
t0.record_date
,t0.record_time as record_time
,t0.store_code
,t0.sku_division_code
,t0.quantity --库存
,t1.commodity_payable_price --销售额
from inventory_list t0
left join sale_list t1 on t0.record_date = t1.order_date and t0.store_code = t1.store_code and t0.record_time = t1.time_range and t0.sku_division_code = t1.commodity_tyoe

=============================================================================================================================================================================================
--7个品类的分时段订单情况 --2024.05.23
with time_list as(
select
'00:00:00-00:30:00' as time_range,'time_1' as time_name,'1' as joinkey
union all
select
'00:30:01-01:00:00','time_2','1' as joinkey
union all
select
'01:00:01-01:30:00','time_3','1' as joinkey
union all
select
'01:30:01-02:00:00','time_4','1' as joinkey
union all
select
'02:00:01-02:30:00','time_5','1' as joinkey
union all
select
'02:30:01-03:00:00','time_6','1' as joinkey
union all
select
'03:00:01-03:30:00','time_7','1' as joinkey
union all
select
'03:30:01-04:00:00','time_8','1' as joinkey
union all
select
'04:00:01-04:30:00','time_9','1' as joinkey
union all
select
'04:30:01-05:00:00','time_10','1' as joinkey
union all
select
'05:00:01-05:30:00','time_11','1' as joinkey
union all
select
'05:30:01-06:00:00','time_12','1' as joinkey
union all
select
'06:00:01-06:30:00','time_13','1' as joinkey
union all
select
'06:30:01-07:00:00','time_14','1' as joinkey
union all
select
'07:00:01-07:30:00','time_15','1' as joinkey
union all
select
'07:30:01-08:00:00','time_16','1' as joinkey
union all
select
'08:00:01-08:30:00','time_17','1' as joinkey
union all
select
'08:30:01-09:00:00','time_18','1' as joinkey
union all
select
'09:00:01-09:30:00','time_19','1' as joinkey
union all
select
'09:30:01-10:00:00','time_20','1' as joinkey
union all
select
'10:00:01-10:30:00','time_21','1' as joinkey
union all
select
'10:30:01-11:00:00','time_22','1' as joinkey
union all
select
'11:00:01-11:30:00','time_23','1' as joinkey
union all
select
'11:30:01-12:00:00','time_24','1' as joinkey
union all
select
'12:00:01-12:30:00','time_25','1' as joinkey
union all
select
'12:30:01-13:00:00','time_26','1' as joinkey
union all
select
'13:00:01-13:30:00','time_27','1' as joinkey
union all
select
'13:30:01-14:00:00','time_28','1' as joinkey
union all
select
'14:00:01-14:30:00','time_29','1' as joinkey
union all
select
'14:30:01-15:00:00','time_30','1' as joinkey
union all
select
'15:00:01-15:30:00','time_31','1' as joinkey
union all
select
'15:30:01-16:00:00','time_32','1' as joinkey
union all
select
'16:00:01-16:30:00','time_33','1' as joinkey
union all
select
'16:30:01-17:00:00','time_34','1' as joinkey
union all
select
'17:00:01-17:30:00','time_35','1' as joinkey
union all
select
'17:30:01-18:00:00','time_36','1' as joinkey
union all
select
'18:00:01-18:30:00','time_37','1' as joinkey
union all
select
'18:30:01-19:00:00','time_38','1' as joinkey
union all
select
'19:00:01-19:30:00','time_39','1' as joinkey
union all
select
'19:30:01-20:00:00','time_40','1' as joinkey
union all
select
'20:00:01-20:30:00','time_41','1' as joinkey
union all
select
'20:30:01-21:00:00','time_42','1' as joinkey
union all
select
'21:00:01-21:30:00','time_43','1' as joinkey
union all
select
'21:30:01-22:00:00','time_44','1' as joinkey
union all
select
'22:00:01-22:30:00','time_45','1' as joinkey
union all
select
'22:30:01-23:00:00','time_46','1' as joinkey
union all
select
'23:00:01-23:30:00','time_47','1' as joinkey
union all
select
'23:30:01-23:59:59','time_48','1' as joinkey
),

store_list as(
select
order_date,
store_code,
'1' as joinkey
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-01-01' and '2024-05-22'
and store_city = '北京市'
group by
order_date,
store_code,
'1'
),

store_time_list as(
select
a.order_date
,a.store_code
,b.time_range
,b.time_name
from store_list a
cross join time_list b on a.joinkey = b.joinkey
),

sale_list as(
select
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '00:30:00' then '00:00:00-00:30:00'
when substr(order_time,12,8) between '00:30:01' and '01:00:00' then '00:30:01-01:00:00'
when substr(order_time,12,8) between '01:00:01' and '01:30:00' then '01:00:01-01:30:00'
when substr(order_time,12,8) between '01:30:01' and '02:00:00' then '01:30:01-02:00:00'
when substr(order_time,12,8) between '02:00:01' and '02:30:00' then '02:00:01-02:30:00'
when substr(order_time,12,8) between '02:30:01' and '03:00:00' then '02:30:01-03:00:00'
when substr(order_time,12,8) between '03:00:01' and '03:30:00' then '03:00:01-03:30:00'
when substr(order_time,12,8) between '03:30:01' and '04:00:00' then '03:30:01-04:00:00'
when substr(order_time,12,8) between '04:00:01' and '04:30:00' then '04:00:01-04:30:00'
when substr(order_time,12,8) between '04:30:01' and '05:00:00' then '04:30:01-05:00:00'
when substr(order_time,12,8) between '05:00:01' and '05:30:00' then '05:00:01-05:30:00'
when substr(order_time,12,8) between '05:30:01' and '06:00:00' then '05:30:01-06:00:00'
when substr(order_time,12,8) between '06:00:01' and '06:30:00' then '06:00:01-06:30:00'
when substr(order_time,12,8) between '06:30:01' and '07:00:00' then '06:30:01-07:00:00'
when substr(order_time,12,8) between '07:00:01' and '07:30:00' then '07:00:01-07:30:00'
when substr(order_time,12,8) between '07:30:01' and '08:00:00' then '07:30:01-08:00:00'
when substr(order_time,12,8) between '08:00:01' and '08:30:00' then '08:00:01-08:30:00'
when substr(order_time,12,8) between '08:30:01' and '09:00:00' then '08:30:01-09:00:00'
when substr(order_time,12,8) between '09:00:01' and '09:30:00' then '09:00:01-09:30:00'
when substr(order_time,12,8) between '09:30:01' and '10:00:00' then '09:30:01-10:00:00'
when substr(order_time,12,8) between '10:00:01' and '10:30:00' then '10:00:01-10:30:00'
when substr(order_time,12,8) between '10:30:01' and '11:00:00' then '10:30:01-11:00:00'
when substr(order_time,12,8) between '11:00:01' and '11:30:00' then '11:00:01-11:30:00'
when substr(order_time,12,8) between '11:30:01' and '12:00:00' then '11:30:01-12:00:00'
when substr(order_time,12,8) between '12:00:01' and '12:30:00' then '12:00:01-12:30:00'
when substr(order_time,12,8) between '12:30:01' and '13:00:00' then '12:30:01-13:00:00'
when substr(order_time,12,8) between '13:00:01' and '13:30:00' then '13:00:01-13:30:00'
when substr(order_time,12,8) between '13:30:01' and '14:00:00' then '13:30:01-14:00:00'
when substr(order_time,12,8) between '14:00:01' and '14:30:00' then '14:00:01-14:30:00'
when substr(order_time,12,8) between '14:30:01' and '15:00:00' then '14:30:01-15:00:00'
when substr(order_time,12,8) between '15:00:01' and '15:30:00' then '15:00:01-15:30:00'
when substr(order_time,12,8) between '15:30:01' and '16:00:00' then '15:30:01-16:00:00'
when substr(order_time,12,8) between '16:00:01' and '16:30:00' then '16:00:01-16:30:00'
when substr(order_time,12,8) between '16:30:01' and '17:00:00' then '16:30:01-17:00:00'
when substr(order_time,12,8) between '17:00:01' and '17:30:00' then '17:00:01-17:30:00'
when substr(order_time,12,8) between '17:30:01' and '18:00:00' then '17:30:01-18:00:00'
when substr(order_time,12,8) between '18:00:01' and '18:30:00' then '18:00:01-18:30:00'
when substr(order_time,12,8) between '18:30:01' and '19:00:00' then '18:30:01-19:00:00'
when substr(order_time,12,8) between '19:00:01' and '19:30:00' then '19:00:01-19:30:00'
when substr(order_time,12,8) between '19:30:01' and '20:00:00' then '19:30:01-20:00:00'
when substr(order_time,12,8) between '20:00:01' and '20:30:00' then '20:00:01-20:30:00'
when substr(order_time,12,8) between '20:30:01' and '21:00:00' then '20:30:01-21:00:00'
when substr(order_time,12,8) between '21:00:01' and '21:30:00' then '21:00:01-21:30:00'
when substr(order_time,12,8) between '21:30:01' and '22:00:00' then '21:30:01-22:00:00'
when substr(order_time,12,8) between '22:00:01' and '22:30:00' then '22:00:01-22:30:00'
when substr(order_time,12,8) between '22:30:01' and '23:00:00' then '22:30:01-23:00:00'
when substr(order_time,12,8) between '23:00:01' and '23:30:00' then '23:00:01-23:30:00'
when substr(order_time,12,8) between '23:30:01' and '23:59:59' then '23:30:01-23:59:59'
end as time_range
,count(distinct order_no) as order_no_num
,count(distinct case when sku_division_code in ('0302') then order_no else null end) as fried_and_roasted_products --FF料理炸烤制品
,count(distinct case when sku_division_code in ('0303') then order_no else null end) as FF_Cuisine_Snacks --FF料理小吃
,count(distinct case when sku_division_code in ('0501') then order_no else null end) as FF_Cute_Cooking --FF萌煮
,count(distinct case when sku_division_code in ('0502') then order_no else null end) as eggs_boiled --茶鸡蛋
,count(distinct case when sku_division_code in ('0601') then order_no else null end) as Steamed_bun --蒸包
,count(distinct case when sku_division_code in ('0602') then order_no else null end) as Breakfast_pastry --早餐酥饼
,count(distinct case when sku_division_code in ('0604') then order_no else null end) as corn --玉米
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-01-01' and '2024-05-22'
and sku_division_code in ('0302','0303','0501','0502','0601','0602','0604')
and store_city = '北京市'
group by
store_code
,order_date
,case
when substr(order_time,12,8) between '00:00:00' and '00:30:00' then '00:00:00-00:30:00'
when substr(order_time,12,8) between '00:30:01' and '01:00:00' then '00:30:01-01:00:00'
when substr(order_time,12,8) between '01:00:01' and '01:30:00' then '01:00:01-01:30:00'
when substr(order_time,12,8) between '01:30:01' and '02:00:00' then '01:30:01-02:00:00'
when substr(order_time,12,8) between '02:00:01' and '02:30:00' then '02:00:01-02:30:00'
when substr(order_time,12,8) between '02:30:01' and '03:00:00' then '02:30:01-03:00:00'
when substr(order_time,12,8) between '03:00:01' and '03:30:00' then '03:00:01-03:30:00'
when substr(order_time,12,8) between '03:30:01' and '04:00:00' then '03:30:01-04:00:00'
when substr(order_time,12,8) between '04:00:01' and '04:30:00' then '04:00:01-04:30:00'
when substr(order_time,12,8) between '04:30:01' and '05:00:00' then '04:30:01-05:00:00'
when substr(order_time,12,8) between '05:00:01' and '05:30:00' then '05:00:01-05:30:00'
when substr(order_time,12,8) between '05:30:01' and '06:00:00' then '05:30:01-06:00:00'
when substr(order_time,12,8) between '06:00:01' and '06:30:00' then '06:00:01-06:30:00'
when substr(order_time,12,8) between '06:30:01' and '07:00:00' then '06:30:01-07:00:00'
when substr(order_time,12,8) between '07:00:01' and '07:30:00' then '07:00:01-07:30:00'
when substr(order_time,12,8) between '07:30:01' and '08:00:00' then '07:30:01-08:00:00'
when substr(order_time,12,8) between '08:00:01' and '08:30:00' then '08:00:01-08:30:00'
when substr(order_time,12,8) between '08:30:01' and '09:00:00' then '08:30:01-09:00:00'
when substr(order_time,12,8) between '09:00:01' and '09:30:00' then '09:00:01-09:30:00'
when substr(order_time,12,8) between '09:30:01' and '10:00:00' then '09:30:01-10:00:00'
when substr(order_time,12,8) between '10:00:01' and '10:30:00' then '10:00:01-10:30:00'
when substr(order_time,12,8) between '10:30:01' and '11:00:00' then '10:30:01-11:00:00'
when substr(order_time,12,8) between '11:00:01' and '11:30:00' then '11:00:01-11:30:00'
when substr(order_time,12,8) between '11:30:01' and '12:00:00' then '11:30:01-12:00:00'
when substr(order_time,12,8) between '12:00:01' and '12:30:00' then '12:00:01-12:30:00'
when substr(order_time,12,8) between '12:30:01' and '13:00:00' then '12:30:01-13:00:00'
when substr(order_time,12,8) between '13:00:01' and '13:30:00' then '13:00:01-13:30:00'
when substr(order_time,12,8) between '13:30:01' and '14:00:00' then '13:30:01-14:00:00'
when substr(order_time,12,8) between '14:00:01' and '14:30:00' then '14:00:01-14:30:00'
when substr(order_time,12,8) between '14:30:01' and '15:00:00' then '14:30:01-15:00:00'
when substr(order_time,12,8) between '15:00:01' and '15:30:00' then '15:00:01-15:30:00'
when substr(order_time,12,8) between '15:30:01' and '16:00:00' then '15:30:01-16:00:00'
when substr(order_time,12,8) between '16:00:01' and '16:30:00' then '16:00:01-16:30:00'
when substr(order_time,12,8) between '16:30:01' and '17:00:00' then '16:30:01-17:00:00'
when substr(order_time,12,8) between '17:00:01' and '17:30:00' then '17:00:01-17:30:00'
when substr(order_time,12,8) between '17:30:01' and '18:00:00' then '17:30:01-18:00:00'
when substr(order_time,12,8) between '18:00:01' and '18:30:00' then '18:00:01-18:30:00'
when substr(order_time,12,8) between '18:30:01' and '19:00:00' then '18:30:01-19:00:00'
when substr(order_time,12,8) between '19:00:01' and '19:30:00' then '19:00:01-19:30:00'
when substr(order_time,12,8) between '19:30:01' and '20:00:00' then '19:30:01-20:00:00'
when substr(order_time,12,8) between '20:00:01' and '20:30:00' then '20:00:01-20:30:00'
when substr(order_time,12,8) between '20:30:01' and '21:00:00' then '20:30:01-21:00:00'
when substr(order_time,12,8) between '21:00:01' and '21:30:00' then '21:00:01-21:30:00'
when substr(order_time,12,8) between '21:30:01' and '22:00:00' then '21:30:01-22:00:00'
when substr(order_time,12,8) between '22:00:01' and '22:30:00' then '22:00:01-22:30:00'
when substr(order_time,12,8) between '22:30:01' and '23:00:00' then '22:30:01-23:00:00'
when substr(order_time,12,8) between '23:00:01' and '23:30:00' then '23:00:01-23:30:00'
when substr(order_time,12,8) between '23:30:01' and '23:59:59' then '23:30:01-23:59:59'
end
),

full_list as(
select
a.order_date
,a.store_code
,a.time_name
,a.time_range
,b.order_no_num
,b.fried_and_roasted_products
,b.FF_Cuisine_Snacks
,b.FF_Cute_Cooking
,b.eggs_boiled
,b.Steamed_bun
,b.Breakfast_pastry
,b.corn
from store_time_list a
left join sale_list b on a.store_code = b.store_code and a.order_date = b.order_date and a.time_range = b.time_range
)

select
order_date
,time_range
,count(distinct store_code) as store_num
,sum(order_no_num) as order_no_num
,sum(fried_and_roasted_products) as fried_and_roasted_products
,sum(FF_Cuisine_Snacks) as FF_Cuisine_Snacks
,sum(FF_Cute_Cooking) as FF_Cute_Cooking
,sum(eggs_boiled) as eggs_boiled
,sum(Steamed_bun) as Steamed_bun
,sum(Breakfast_pastry) as Breakfast_pastry
,sum(corn) as corn
from full_list
group by
order_date
,time_range

=================================================================================================================================================================
34020004	金嗓子桑菊含片22.8g
34020002	金嗓子都乐含片22.8g
34020003	金嗓子香橙含片22.8g
79341150	金嗓子桑菊含片22.8g***
79341102	金嗓子香橙含片22.8g***
79341400	金嗓子都乐含片22.8g***

--北京门店
--19年1月至24年5月
--月维度
--每个月均有销售

select
*
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_code = '100078005'
and sku_code in ('34020004','34020002','34020003','79341150','79341102','79341400')




with store_list as(
select --周期内总共65个月，选取65个月均有日商的门店
store_code
,count(1) as sale_num
from(
select
trunc(order_date,'MM') as month
,store_code
,sum(payable_price)/count(distinct order_date) as payable_price
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_city = '北京市'
and order_date between '2019-01-01' and '2024-05-31'
and store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
group by
trunc(order_date,'MM')
,store_code
) a
group by
store_code
)

select
trunc(t.order_date,'MM') as month
,t.store_code
,count(distinct t.order_date) as date_num
,sum(case when t.sku_code in ('34020004','34020002','34020003','79341150','79341102','79341400') then t.payable_price else 0 end) as golden_baby_sale
,sum(case when t.sku_code in ('34020004','34020002','34020003','79341150','79341102','79341400') then t.sku_quantity else 0 end) as golden_baby_num 
,sum(t.payable_price) as payable_price
from data_build.dw_order_sku_v1 t
left join store_list t1 on t.store_code = t1.store_code
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_city = '北京市'
and t.order_date between '2019-01-01' and '2024-05-31'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t1.sale_num = '65' --65个月均有日商
group by
trunc(t.order_date,'MM')
,t.store_code