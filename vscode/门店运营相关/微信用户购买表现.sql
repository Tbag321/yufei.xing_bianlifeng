with gehua_user_list as(--歌华用户清单
select
t.pay_id
,t.order_date
,t1.wx_nickname
from data_promotion.dm_promotion_store_detl_order_detail_info_da t
left join data_promotion.dim_user_info t1 on t.pay_id = t1.user_id and t1.dt = 20240229
where t.dt = 20240229
and t.order_status = 'FINISHED'
and t.store_type = '0'
and t.store_code in ('100078005')
and t.sku_quantity > 0
and t1.wx_nickname is not null
and order_date between '2023-12-18' and '2024-02-05' --微信进群时间
group by
t.pay_id
,t.order_date
,t1.wx_nickname
),

--歌华微信群里用户
vx_list as(
SELECT
a.vx_name
,a.nick_name --微信昵称
,a.join_time --进群时间
,b.pay_id --用户编码
,b.order_date
,b.wx_nickname
from data_build.ods_uploads_vx_user_list_v1 a
left join gehua_user_list b on a.nick_name = b.wx_nickname and a.join_time = b.order_date
where b.pay_id is not null
)

select
a.pay_id
,a.nick_name
,a.join_time
,date_add(join_time,-29) as last_30_date
,date_add(join_time,30) as future_30_date
,count(distinct case when b.order_date between date_add(join_time,-29) and join_time then b.order_no else null end) as last_30_order_num
,sum(case when b.order_date between date_add(join_time,-29) and join_time then b.payable_price else 0 end) as last_30_sale
,count(distinct case when b.order_date between date_add(join_time,1) and date_add(join_time,30) then b.order_no else null end) as future_30_order_num
,sum(case when b.order_date between date_add(join_time,1) and date_add(join_time,30) then b.payable_price else 0 end) as future_30_sale
,count(distinct case when b.order_date between '2022-07-01' and '2022-09-30' then b.order_no else null end) as 22Q3_order_num
,sum(case when b.order_date between '2022-07-01' and '2022-09-30' then b.payable_price else 0 end) as 22Q3_sale
,count(distinct case when b.order_date between '2022-10-01' and '2022-12-31' then b.order_no else null end) as 22Q4_order_num
,sum(case when b.order_date between '2022-10-01' and '2022-12-31' then b.payable_price else 0 end) as 22Q4_sale
,count(distinct case when b.order_date between '2023-07-01' and '2023-09-30' then b.order_no else null end) as 23Q3_order_num
,sum(case when b.order_date between '2023-07-01' and '2023-09-30' then b.payable_price else 0 end) as 23Q3_sale
,count(distinct case when b.order_date between '2023-10-01' and '2023-12-31' then b.order_no else null end) as 23Q4_order_num
,sum(case when b.order_date between '2023-10-01' and '2023-12-31' then b.payable_price else 0 end) as 23Q4_sale
,count(distinct case when b.order_date between '2024-01-08' and '2024-02-04' then b.order_no else null end) as 24m1_order_num
,sum(case when b.order_date between '2024-01-08' and '2024-02-04' then b.payable_price else 0 end) as 24m1_sale
from vx_list a
left join data_promotion.dm_promotion_store_detl_order_detail_info_da b on a.pay_id = b.pay_id and b.dt = 20240229
where b.order_status = 'FINISHED'
and b.store_type = '0'
and b.store_code in ('100078005')
and b.sku_quantity > 0
and b.order_date > '2022-01-01'
group by
a.pay_id
,a.nick_name
,a.join_time
,date_add(join_time,-29)
,date_add(join_time,30)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--歌华用户1月8号-2月4号销售情况
select
a.pay_id
,count(distinct a.order_no) as order_no
,sum(a.payable_price) as payable_price
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
where a.dt = 20240305
and a.order_status = 'FINISHED'
and a.store_type = '0'
and a.store_code in ('100078005')
and a.sku_quantity > 0
and a.order_date between '2024-01-08' and '2024-02-04'
group by
a.pay_id