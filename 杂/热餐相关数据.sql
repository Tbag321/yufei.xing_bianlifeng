with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name)

first_buy_hotmeal_list as
(
select
a.*
from
(select
order_date
,pay_id
,a.store_code
,b.store_cvs_code
,b.display_name
,row_number() over (partition by pay_id order by order_date) as rn
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join desensitization b on a.store_code = b.store_code
where dt = '${today-1}'
and sku_division_code in ('0301')
and pay_status = 'PAY_SUCCESS'
--and store_cvs_code = '101000128'
and pay_id is not null) a
where rn = 1
)

new_old_num_month as
(
select
trunc(a.order_date,'MM') as month
,b.store_cvs_code
,b.display_name
,count(distinct a.pay_id) as hotmeal_num
,count(distinct case when trunc(a.order_date,'MM') = trunc(b.order_date,'MM') then a.pay_id end) as new_hotmeal_num
,count(distinct case when trunc(a.order_date,'MM') <> trunc(b.order_date,'MM') then a.pay_id end) as old_hotmeal_num
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join first_buy_hotmeal_list b on a.store_code = b.store_code and a.pay_id = b.pay_id
where a.dt = '${today-1}'
and sku_division_code in ('0301')
and pay_status = 'PAY_SUCCESS'
and b.store_cvs_code = '101000128'
and a.pay_id is not null
group by
trunc(a.order_date,'MM')
,b.store_cvs_code
,b.display_name
)

select
trunc(a.order_date,'MM') as month
,b.store_cvs_code
,b.display_name
,count(distinct pay_id)
from data_promotion.dm_promotion_store_detl_order_detail_info_da a
left join desensitization b on a.store_code = b.store_code
where a.dt = 20221222
and a.order_date between '2018-02-01' and '2018-02-28'
and pay_status = 'PAY_SUCCESS'
and store_cvs_code = '100025002'
group by
trunc(a.order_date,'MM')
,b.store_cvs_code
,b.display_name