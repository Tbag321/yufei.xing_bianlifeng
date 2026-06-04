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
group by
order_no
,order_date
,store_code
) a
where sku_quantity >= 11 or payable_price >= 500
)

select
trunc(t.order_date,'MM') as record_month
,t.store_code

--营业日
,count(distinct t.order_date) as days

--折后销售额
,sum(case when t.sku_division_code not in ('6101','6102','6103') then t.payable_price else 0 end)/count(distinct t.order_date) as cigarette_order_payable_price --非香烟全部日商

,sum(case when t.sku_division_code in ('6101','6102','6103') and t1.order_no is null then t.payable_price else 0 end)/count(distinct t.order_date) as cigarette_order_payable_price --剔大单香烟全部日商

from data_build.dw_order_sku_promotion_v1 t --订单明细表
left join big_cigarette_order_list t1 on t.order_date = t1.order_date and t.store_code = t1.store_code and t.order_no = t1.order_no
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.pay_status = 'PAY_SUCCESS'
and t.sku_class_code not in ('86','50')
group by 
trunc(t.order_date,'MM')
,t.store_code