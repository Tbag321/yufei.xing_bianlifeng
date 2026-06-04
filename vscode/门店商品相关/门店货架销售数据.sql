--## 1.1 货架改造门店(剔除节假日)
--##SQL-实验店
--sql_shelf_reshape_store="""
with store_month_sale as (
select a.store_code
,b.store_name
,a.order_week
,a.level_1
,a.level_2
,a.`日均金额`
,a.`进店人流`
,a.`购买转化`
,a.`交易人数`
,a.`人均金额`
,a.`渗透率`
,a.`日均销量`
,a.`日均废弃前毛利`
,a.`日均废弃后毛利`
from (
select store_code
,order_week
,level_1
,level_2
,avg(`日均金额`)    as `日均金额`
,avg(`进店人流`)    as `进店人流`
,avg(`购买转化`)    as `购买转化`
,avg(`交易人数`)    as `交易人数`
,avg(`人均金额`)    as `人均金额`
,avg(`渗透率`)      as `渗透率`
,avg(`日均销量`)    as `日均销量`
,avg(`日均废弃前毛利`) as `日均废弃前毛利`
,avg(`日均废弃后毛利`) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店' as level_1
,'0-门店' as level_2
,avg(store_origin_payable_price)                            as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(store_transaction_user_num/in_store_user_num)          as `购买转化`
,avg(store_transaction_user_num)                            as `交易人数`
,avg(store_origin_payable_price/store_transaction_user_num) as `人均金额`
,avg(store_transaction_user_num/store_transaction_user_num) as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and is_weekend = 0
and is_holiday = 0
and store_code in ${store_list}
group by store_code
,order_week
,order_date
,'0-门店'      
,'0-门店'
) a
group by store_code
,order_week
,level_1
,level_2

union all

select store_code
,order_week
,'0-门店'   as level_1
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end as level_2
,avg(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(transaction_user_num/in_store_user_num)                as `购买转化`
,avg(transaction_user_num)                                  as `交易人数`
,avg(origin_payable_price/transaction_user_num)             as `人均金额`
,avg(transaction_user_num/store_transaction_user_num)       as `渗透率`
,avg(sell_qty)                                              as `日均销量`
,avg(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,avg(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and is_weekend = 0
and is_holiday = 0
and store_code in ${store_list}
group by store_code
,order_week
,'0-门店'
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end

union all

select store_code
,order_week
,level_1
,level_2
,avg(`日均金额`)    as `日均金额`
,avg(`进店人流`)    as `进店人流`
,avg(`购买转化`)    as `购买转化`
,avg(`交易人数`)    as `交易人数`
,avg(`人均金额`)    as `人均金额`
,avg(`渗透率`)      as `渗透率`
,avg(`日均销量`)    as `日均销量`
,avg(`日均废弃前毛利`) as `日均废弃前毛利`
,avg(`日均废弃后毛利`) as `日均废弃后毛利`
from (

select store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end as level_1
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)           as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)        as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)  as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and is_weekend = 0
and is_holiday = 0
and store_code in ${store_list}
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
) a
group by store_code
,order_week
,level_1
,level_2
      
union all

select store_code
,order_week
,level_1
,level_2
,avg(`日均金额`)    as `日均金额`
,avg(`进店人流`)    as `进店人流`
,avg(`购买转化`)    as `购买转化`
,avg(`交易人数`)    as `交易人数`
,avg(`人均金额`)    as `人均金额`
,avg(`渗透率`)      as `渗透率`
,avg(`日均销量`)    as `日均销量`
,avg(`日均废弃前毛利`) as `日均废弃前毛利`
,avg(`日均废弃后毛利`) as `日均废弃后毛利`
from(
select store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_1
,sku_matrix_name as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)            as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)         as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)   as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and is_weekend = 0
and is_holiday = 0
and store_code in ${store_list}
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
,sku_matrix_name
) a 
group by store_code
,order_week
,level_1
,level_2

) a
join default.dim_store_info b on a.store_code=b.store_code
where b.dt='${today-1}'
)

select *
from store_month_sale

--"""

--## 1.2.北京整体(剔除节假日)
--##SQL-北京整体-剔除改造店
--sql_beijing="""
with store_month_sale as (
select a.order_week
,'北京大盘-剔除改造店' as store_code
,'北京大盘-剔除改造店' as store_name
,a.level_1
,a.level_2
,a.`日均金额`
,a.`进店人流`
,a.`购买转化`
,a.`交易人数`
,a.`人均金额`
,a.`渗透率`
,a.`日均销量`
,a.`日均废弃前毛利`
,a.`日均废弃后毛利`
from (
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店' as level_1
,'0-门店' as level_2
,avg(store_origin_payable_price)                            as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(store_transaction_user_num/in_store_user_num)          as `购买转化`
,avg(store_transaction_user_num)                            as `交易人数`
,avg(store_origin_payable_price/store_transaction_user_num) as `人均金额`
,avg(store_transaction_user_num/store_transaction_user_num) as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,'0-门店'      
,'0-门店'
) a
group by order_week
,level_1
,level_2

union all
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店'   as level_1
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end as level_2
,avg(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(transaction_user_num/in_store_user_num)                as `购买转化`
,avg(transaction_user_num)                                  as `交易人数`
,avg(origin_payable_price/transaction_user_num)             as `人均金额`
,avg(transaction_user_num/store_transaction_user_num)       as `渗透率`
,avg(sell_qty)                                              as `日均销量`
,avg(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,avg(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501'  
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,'0-门店'
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end
) a
group by order_week
,level_1
,level_2

union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (

select store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end as level_1
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)           as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)        as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)  as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
and sku_type_1 in ('日配','非日配')
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
) a
group by order_week
,level_1
,level_2
      
union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from(
select store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_1
,sku_matrix_name as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)            as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)         as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)   as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
and sku_type_1 in ('日配','非日配')
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
,sku_matrix_name
) a 
group by order_week
,level_1
,level_2

) a
)

select *
from store_month_sale

--"""


--##SQL-北京整体-包含改造店
--sql_beijing_1="""
with store_month_sale as (
select a.order_week
,'北京大盘-包含改造店' as store_code
,'北京大盘-包含改造店' as store_name
,a.level_1
,a.level_2
,a.`日均金额`
,a.`进店人流`
,a.`购买转化`
,a.`交易人数`
,a.`人均金额`
,a.`渗透率`
,a.`日均销量`
,a.`日均废弃前毛利`
,a.`日均废弃后毛利`
from (
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店' as level_1
,'0-门店' as level_2
,avg(store_origin_payable_price)                            as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(store_transaction_user_num/in_store_user_num)          as `购买转化`
,avg(store_transaction_user_num)                            as `交易人数`
,avg(store_origin_payable_price/store_transaction_user_num) as `人均金额`
,avg(store_transaction_user_num/store_transaction_user_num) as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
group by store_code
,order_week
,order_date
,'0-门店'      
,'0-门店'
) a
group by order_week
,level_1
,level_2

union all
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店'   as level_1
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end as level_2
,avg(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(transaction_user_num/in_store_user_num)                as `购买转化`
,avg(transaction_user_num)                                  as `交易人数`
,avg(origin_payable_price/transaction_user_num)             as `人均金额`
,avg(transaction_user_num/store_transaction_user_num)       as `渗透率`
,avg(sell_qty)                                              as `日均销量`
,avg(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,avg(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501'  
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
group by store_code
,order_week
,order_date
,'0-门店'
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end
) a
group by order_week
,level_1
,level_2

union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (

select store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end as level_1
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)           as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)        as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)  as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
) a
group by order_week
,level_1
,level_2
      
union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from(
select store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_1
,sku_matrix_name as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)            as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)         as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)   as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and is_weekend = 0
and is_holiday = 0
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
,sku_matrix_name
) a 
group by order_week
,level_1
,level_2

) a
)

select *
from store_month_sale

--"""



--## 2.1货架改造门店(不剔节假日)
--##SQL-实验店
--sql_shelf_reshape_store_all="""
with store_month_sale as (
select a.store_code
,b.store_name
,a.order_week
,a.level_1
,a.level_2
,a.`日均金额`
,a.`进店人流`
,a.`购买转化`
,a.`交易人数`
,a.`人均金额`
,a.`渗透率`
,a.`日均销量`
,a.`日均废弃前毛利`
,a.`日均废弃后毛利`
from (
select store_code
,order_week
,level_1
,level_2
,avg(`日均金额`)    as `日均金额`
,avg(`进店人流`)    as `进店人流`
,avg(`购买转化`)    as `购买转化`
,avg(`交易人数`)    as `交易人数`
,avg(`人均金额`)    as `人均金额`
,avg(`渗透率`)      as `渗透率`
,avg(`日均销量`)    as `日均销量`
,avg(`日均废弃前毛利`) as `日均废弃前毛利`
,avg(`日均废弃后毛利`) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店' as level_1
,'0-门店' as level_2
,avg(store_origin_payable_price)                            as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(store_transaction_user_num/in_store_user_num)          as `购买转化`
,avg(store_transaction_user_num)                            as `交易人数`
,avg(store_origin_payable_price/store_transaction_user_num) as `人均金额`
,avg(store_transaction_user_num/store_transaction_user_num) as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_code in ${store_list}
group by store_code
,order_week
,order_date
,'0-门店'      
,'0-门店'
) a
group by store_code
,order_week
,level_1
,level_2

union all

select store_code
,order_week
,'0-门店'   as level_1
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end as level_2
,avg(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(transaction_user_num/in_store_user_num)                as `购买转化`
,avg(transaction_user_num)                                  as `交易人数`
,avg(origin_payable_price/transaction_user_num)             as `人均金额`
,avg(transaction_user_num/store_transaction_user_num)       as `渗透率`
,avg(sell_qty)                                              as `日均销量`
,avg(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,avg(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_code in ${store_list}
group by store_code
,order_week
,'0-门店'
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end

union all

select store_code
,order_week
,level_1
,level_2
,avg(`日均金额`)    as `日均金额`
,avg(`进店人流`)    as `进店人流`
,avg(`购买转化`)    as `购买转化`
,avg(`交易人数`)    as `交易人数`
,avg(`人均金额`)    as `人均金额`
,avg(`渗透率`)      as `渗透率`
,avg(`日均销量`)    as `日均销量`
,avg(`日均废弃前毛利`) as `日均废弃前毛利`
,avg(`日均废弃后毛利`) as `日均废弃后毛利`
from (

select store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end as level_1
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)           as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)        as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)  as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_code in ${store_list}
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
) a
group by store_code
,order_week
,level_1
,level_2
      
union all

select store_code
,order_week
,level_1
,level_2
,avg(`日均金额`)    as `日均金额`
,avg(`进店人流`)    as `进店人流`
,avg(`购买转化`)    as `购买转化`
,avg(`交易人数`)    as `交易人数`
,avg(`人均金额`)    as `人均金额`
,avg(`渗透率`)      as `渗透率`
,avg(`日均销量`)    as `日均销量`
,avg(`日均废弃前毛利`) as `日均废弃前毛利`
,avg(`日均废弃后毛利`) as `日均废弃后毛利`
from(
select store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_1
,sku_matrix_name as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)            as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)         as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)   as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_code in ${store_list}
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
,sku_matrix_name
) a 
group by store_code
,order_week
,level_1
,level_2

) a
join default.dim_store_info b on a.store_code=b.store_code
where b.dt='${today-1}'
)

select *
from store_month_sale

--"""


--## 2.2.北京整体(不剔除节假日)
--##SQL-北京整体-剔除改造店
--sql_beijing_all="""
with store_month_sale as (
select a.order_week
,'北京大盘-剔除改造店' as store_code
,'北京大盘-剔除改造店' as store_name
,a.level_1
,a.level_2
,a.`日均金额`
,a.`进店人流`
,a.`购买转化`
,a.`交易人数`
,a.`人均金额`
,a.`渗透率`
,a.`日均销量`
,a.`日均废弃前毛利`
,a.`日均废弃后毛利`
from (
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店' as level_1
,'0-门店' as level_2
,avg(store_origin_payable_price)                            as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(store_transaction_user_num/in_store_user_num)          as `购买转化`
,avg(store_transaction_user_num)                            as `交易人数`
,avg(store_origin_payable_price/store_transaction_user_num) as `人均金额`
,avg(store_transaction_user_num/store_transaction_user_num) as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,'0-门店'      
,'0-门店'
) a
group by order_week
,level_1
,level_2

union all
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店'   as level_1
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end as level_2
,avg(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(transaction_user_num/in_store_user_num)                as `购买转化`
,avg(transaction_user_num)                                  as `交易人数`
,avg(origin_payable_price/transaction_user_num)             as `人均金额`
,avg(transaction_user_num/store_transaction_user_num)       as `渗透率`
,avg(sell_qty)                                              as `日均销量`
,avg(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,avg(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,'0-门店'
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end
) a
group by order_week
,level_1
,level_2

union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (

select store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end as level_1
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)           as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)        as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)  as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and sku_type_1 in ('日配','非日配')
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
) a
group by order_week
,level_1
,level_2
      
union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from(
select store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_1
,sku_matrix_name as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)            as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)         as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)   as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and sku_type_1 in ('日配','非日配')
and store_code not in (
'100076009',
'100075003',
'100036001',
'100005511',
'100005325',
'100005228',
'100005226',
'100005217',
'100005208',
'100005167',
'100005117',
'100005063',
'100005053',
'100005019',
'100005016',
'100005006',
'100005002',
'100003659',
'100003120',
'100003119',
'100003051',
'100003006',
'100002593',
'100002581',
'100001598',
'100001580',
'100001572',
'100001510',
'100001502',
'100001388',
'100001386',
'100001379',
'100001099',
'100001093',
'100001091',
'100001061',
'100001036',
'100001033',
'100000653',
'100000597',
'100000589',
'100000587',
'100000572',
'100000526',
'100000381',
'100000376',
'100000332',
'100000309',
'100000299',
'100000298',
'100000277',
'100000268',
'100000232',
'100000196',
'100000179',
'100000159',
'100000101',
'100000063',
'100000023'
)
group by store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
,sku_matrix_name
) a 
group by order_week
,level_1
,level_2


) a
)

select *
from store_month_sale


"""


##SQL-北京整体-包含改造店
sql_beijing_all_1="""
with store_month_sale as (
select a.order_week
,'北京大盘-包含改造店' as store_code
,'北京大盘-包含改造店' as store_name
,a.level_1
,a.level_2
,a.`日均金额`
,a.`进店人流`
,a.`购买转化`
,a.`交易人数`
,a.`人均金额`
,a.`渗透率`
,a.`日均销量`
,a.`日均废弃前毛利`
,a.`日均废弃后毛利`
from (
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店' as level_1
,'0-门店' as level_2
,avg(store_origin_payable_price)                            as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(store_transaction_user_num/in_store_user_num)          as `购买转化`
,avg(store_transaction_user_num)                            as `交易人数`
,avg(store_origin_payable_price/store_transaction_user_num) as `人均金额`
,avg(store_transaction_user_num/store_transaction_user_num) as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
group by store_code
,order_week
,order_date
,'0-门店'      
,'0-门店'
) a
group by order_week
,level_1
,level_2

union all
select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (
select store_code
,order_week
,order_date
,'0-门店'   as level_1
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end as level_2
,avg(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,avg(transaction_user_num/in_store_user_num)                as `购买转化`
,avg(transaction_user_num)                                  as `交易人数`
,avg(origin_payable_price/transaction_user_num)             as `人均金额`
,avg(transaction_user_num/store_transaction_user_num)       as `渗透率`
,avg(sell_qty)                                              as `日均销量`
,avg(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,avg(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
group by store_code
,order_week
,order_date
,'0-门店'
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      when sku_type_1='香烟' then '3-香烟'
      when sku_type_1='自助饮品' then '4-自助饮品'
      when sku_type_1='生鲜' then '5-生鲜'
      end
) a
group by order_week
,level_1
,level_2

union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from (

select store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end as level_1
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)           as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)        as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)  as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='日配' then '1-日配'
      when sku_type_1='非日配' then '2-非日配'
      end
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
) a
group by order_week
,level_1
,level_2
      
union all

select order_week
,level_1
,level_2
,sum(`日均金额`)/count(distinct concat(store_code,order_date))    as `日均金额`
,sum(`进店人流`)/count(distinct concat(store_code,order_date))    as `进店人流`
,sum(`购买转化`)/count(distinct concat(store_code,order_date))    as `购买转化`
,sum(`交易人数`)/count(distinct concat(store_code,order_date))    as `交易人数`
,sum(`人均金额`)/count(distinct concat(store_code,order_date))    as `人均金额`
,sum(`渗透率`)/count(distinct concat(store_code,order_date))      as `渗透率`
,sum(`日均销量`)/count(distinct concat(store_code,order_date))    as `日均销量`
,sum(`日均废弃前毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃前毛利`
,sum(`日均废弃后毛利`)/count(distinct concat(store_code,order_date)) as `日均废弃后毛利`
from(
select store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end as level_1
,sku_matrix_name as level_2
,sum(origin_payable_price)                                  as `日均金额`
,avg(in_store_user_num)                                     as `进店人流`
,sum(transaction_user_num)/avg(in_store_user_num)            as `购买转化`
,sum(transaction_user_num)                                  as `交易人数`
,sum(origin_payable_price)/sum(transaction_user_num)         as `人均金额`
,sum(transaction_user_num)/avg(store_transaction_user_num)   as `渗透率`
,sum(sell_qty)                                              as `日均销量`
,sum(origin_payable_price-cost_price_plus_tax)              as `日均废弃前毛利`
,sum(profit_after_waste)                                    as `日均废弃后毛利`
from data_md.dm_md_report_store_class_user_sales_info_v1_di a
where dt>='20230501' 
and store_city='北京市'
and sku_type_1 in ('日配','非日配')
group by store_code
,order_week
,order_date
,case when sku_type_1='非日配' and sku_matrix_code='12' then '1-风幕柜'
      when sku_type_1='日配' and sku_matrix_code in('0014','0015','0016','0019','0020','0022','0023','0024') then '1-风幕柜'
      when sku_type_1='非日配' and sku_matrix_code in ('30','33') then '2-冷藏柜'
      when sku_type_1='非日配' and sku_matrix_code in ('31','32','34','35','36','37','38','39','40','41','44','61','64','65','66','67','68','70','71','72','73','78','85','88','89') then '3-常温货架'
      when sku_type_1='日配' and sku_matrix_code in ('0021') then '4-面包货架'
      when sku_type_1='非日配' and sku_matrix_code in ('42','43') then '5-冰淇淋柜'
      when sku_type_1='日配' and sku_matrix_code in('0010','0011','0017','0030','0147','0302','0303','0314','0316','0501','0503','0505','0603','0604') then '6-FF区'
      else '7-其他' end
,sku_matrix_name
) a 
group by order_week
,level_1
,level_2


) a
)

select *
from store_month_sale


"""


## 3.货架主题销量

##SQL-主题销量
sql_topic_sale="""
with order_info as (
select order_date
,order_week
,store_city
,store_code
,store_name
,case when store_code in ${store_list} then '1-实验组' else '对照组' end as store_type
,shelf_class_name
,shelf_topic
,is_working_day
,main_shelf_num
,sum(sku_quantity_repartition) as sku_quantity
,sum(origin_payable_price_repartition) as payable_price
,sum(gross_profit_after_waste_repartition) as profit_after
from data_md.dm_md_report_store_shelf_effectiveness_info_v1_di
where dt>='20230501' 
and store_city='北京市'
group by order_date
,order_week
,store_city
,store_code
,store_name
,case when store_code in ${store_list} then '1-实验组' else '对照组' end
,shelf_class_name
,shelf_topic
,is_working_day
,main_shelf_num
),

store_day as (
select order_week
,store_name
,'1-工作日' as period_type
,count(distinct concat(store_code,order_date)) as store_day
from order_info
where is_working_day=1
and store_type='1-实验组'
group by order_week
,store_name
,'1-工作日'
union all
select order_week
,'北京大盘-包含改造店' as store_name 
,'1-工作日' as period_type
,count(distinct concat(store_code,order_date)) as store_day
from order_info
where is_working_day=1
group by order_week
,'北京大盘-包含改造店' 
,'1-工作日'
union all
select order_week
,'北京大盘-剔除改造店' as store_name 
,'1-工作日' as period_type
,count(distinct concat(store_code,order_date)) as store_day
from order_info
where is_working_day=1
and store_type='对照组'
group by order_week
,'北京大盘-剔除改造店' 
,'1-工作日'

union all
select order_week
,store_name
,'2-全周' as period_type
,count(distinct concat(store_code,order_date)) as store_day
from order_info
where store_type='1-实验组'
group by order_week
,store_name
,'2-全周'
union all
select order_week
,'北京大盘-包含改造店' as store_name 
,'2-全周' as period_type
,count(distinct concat(store_code,order_date)) as store_day
from order_info
group by order_week
,'北京大盘-包含改造店' 
,'2-全周'
union all
select order_week
,'北京大盘-剔除改造店' as store_name 
,'2-全周' as period_type
,count(distinct concat(store_code,order_date)) as store_day
from order_info
where store_type='对照组'
group by order_week
,'北京大盘-剔除改造店' 
,'2-全周'

),


topic_sale as (
select order_week
,store_name
,'1-工作日' as period_type
,shelf_class_name
,shelf_topic
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
,sum(profit_after) as profit_after
from order_info
where is_working_day=1
and store_type='1-实验组'
group by order_week
,store_name
,'1-工作日'
,shelf_class_name
,shelf_topic
union all
select order_week
,'北京大盘-包含改造店' as store_name
,'1-工作日' as period_type
,shelf_class_name
,shelf_topic
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
,sum(profit_after) as profit_after
from order_info
where is_working_day=1
group by order_week
,'北京大盘-包含改造店'
,'1-工作日'
,shelf_class_name
,shelf_topic

union all
select order_week
,'北京大盘-剔除改造店' as store_name
,'1-工作日' as period_type
,shelf_class_name
,shelf_topic
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
,sum(profit_after) as profit_after
from order_info
where is_working_day=1
and store_type='对照组'
group by order_week
,'北京大盘-剔除改造店'
,'1-工作日'
,shelf_class_name
,shelf_topic

union all
select order_week
,store_name
,'2-全周' as period_type
,shelf_class_name
,shelf_topic
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
,sum(profit_after) as profit_after
from order_info
where store_type='1-实验组'
group by order_week
,store_name
,'2-全周'
,shelf_class_name
,shelf_topic
union all
select order_week
,'北京大盘-包含改造店' as store_name
,'2-全周' as period_type
,shelf_class_name
,shelf_topic
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
,sum(profit_after) as profit_after
from order_info
group by order_week
,'北京大盘-包含改造店'
,'2-全周'
,shelf_class_name
,shelf_topic

union all
select order_week
,'北京大盘-剔除改造店' as store_name
,'2-全周' as period_type
,shelf_class_name
,shelf_topic
,sum(sku_quantity) as sku_quantity
,sum(payable_price) as payable_price
,sum(profit_after) as profit_after
from order_info
where store_type='对照组'
group by order_week
,'北京大盘-剔除改造店'
,'2-全周'
,shelf_class_name
,shelf_topic
)

select a.order_week
,a.period_type
,a.store_name
,a.shelf_class_name
,a.shelf_topic
,a.sku_quantity
,a.payable_price
,a.profit_after
,a.sku_quantity*1.0000/b.store_day as `日均销量`
,a.payable_price*1.0000/b.store_day as `日均金额`
,a.profit_after*1.0000/b.store_day as `日均废后毛利`
from topic_sale a
left join store_day b on a.order_week=b.order_week and a.period_type=b.period_type and a.store_name=b.store_name



--"""

--货架主体销售
select 
trunc(order_date,'MM') as order_month
,store_city
,store_code
,store_name
,shelf_class_name
,shelf_topic
,is_working_day
,count(distinct order_date) as order_date_num
,sum(sku_quantity_repartition)/count(distinct order_date) as sku_quantity
,sum(origin_payable_price_repartition)/count(distinct order_date) as payable_price
,sum(gross_profit_after_waste_repartition)/count(distinct order_date) as profit_after
from data_md.dm_md_report_store_shelf_effectiveness_info_v1_di
where dt between '20250601' and '20250630'
and is_working_day = '1'
group by trunc(order_date,'MM')
,store_city
,store_code
,store_name
,shelf_class_name
,shelf_topic
,is_working_day

--月维度日商(剔除节假日)
--门店月维度日商
select
trunc(t.order_date,'MM') as record_month
,t.store_code
,count(distinct order_date) as order_date_num 
,count(distinct t.order_no)/count(distinct order_date) as quanyue_order_cnt --订单量
,sum(case when sku_division_code in ('6101','6102') then payable_price else 0 end)/count(distinct order_date) as payable_price_cigarette --香烟
,sum(case when sku_class_code in ('01','02','03','04','05','06','07','08','09','10','11','13','14','15','20','21','22','23','24','25','26') or sku_division_code in ('1209','1210') 
then payable_price else 0 end)/count(distinct order_date) as payable_price_daily --日配
,sum(t.payable_price)/count(distinct order_date) as quanyue_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
join data_build.dim_date_ya_v2 t1 on t.order_date = t1.date_key and t1.is_working_day = 1
where t.dt = '20250703'
and order_date between '2025-06-01' and '2025-06-30'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
group by
trunc(t.order_date,'MM')
,t.store_code


--三个非食品货架主题(化妆品及洗护，纸生理用品，生活杂货及文玩具)上面的所有商品的psd，pad分三档：0,0-1,1+，包括架上架
SELECT
store_code
,store_name
,shelf_topic
,count(distinct sku_code) as sku_num
,count(distinct case when nvl(psd,0) = 0 then sku_code else null end) as zero
,count(distinct case when nvl(psd,0) > 0 and nvl(psd,0) < 1 then sku_code else null end) zero_to_one
,count(distinct case when nvl(psd,0) >= 1 then sku_code else null end) one_more
from data_smartorder.dw_sku_display_next_week_store_sku_display_all_history_di
where dt = 20250818
and shelf_topic in ('化妆品及洗护','纸生理用品','生活杂货及文玩具','粮油调味')
group by
store_code
,store_name
,shelf_topic















#
# --------------------------------------
# DATE: 2017-12-13
# OUT:  dw_sku_store_psd_di_v3
# DEV:  yueqiang.yu  8周PSD 对接陈列 格子门店
# --------------------------------------

source "${ETC}"/format_date.cnf
TABLE_NAME="dw_sku_store_psd_di_v3"
#HDFS_DIR="/user/wstats/dw/${TABLE_NAME}/dt=${DATE}"
UNIQUE_KEY="sku_code,store_code"
CHECK_DATA_SQL="
    select
        if(count(1)>0, cast(count(1) as string), cast(hivemall.raise_error('数据为空') as string)),
        if(count(1)=sum(m), cast(count(1) as string), cast(hivemall.raise_error('数据重复') as string))
    from (
        select ${UNIQUE_KEY},count(1)m
        from ${TABLE_NAME}
        where dt = '${DATE}'
        group by ${UNIQUE_KEY}
    ) t
"

function dw_sku_store_psd_di_v3_run {
#    rebuild_hdfs_dir $HDFS_DIR && calculate && drop_partition && do_check && add_partition && analyze_table && merge_smallfiles
    calculate
}

function calculate {
--     $HIVE  -e << EOF "
    set hive.cli.errors.ignore=false;

    with store_sku_info as(
    select
        aa.store_code
        ,aa.store_name
        ,cc.store_style
        --,aa.sku_division_code
        --,aa.sku_division_name
        ,aa.sku_code
        --,aa.sku_name
        ,cc.city_code
        ,cc.city_name
        ,nvl(aa.sale_amount/bb.day_num,0) as psd_amount
        ,nvl(aa.quantity/bb.day_num,0) as psd
        ,nvl(aa.profit/bb.day_num,0) as psd_profit
    from
    (
        select
            store_code
            ,store_name
            --,sku_division_code
            --,sku_division_name
            ,sku_code
            --,max(sku_name) as sku_name
            ,sum(origin_payable_price) as sale_amount
            ,sum(sku_quantity) as quantity
            ,sum(origin_payable_price - cost_price - cost_tax + vendor_allocated_cost_price) as profit
        from dw_order_sku_v1
        where dt='$DATE'
        and store_type in ('0','3')
        and order_status='FINISHED'
        and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
        and sku_code <> '34100087'   --不含称重零食
        group by store_code,store_name
        --,sku_division_code,sku_division_name
        ,sku_code--,sku_name

        union all
        select store_code
            ,store_name
            ,finished_sku_code  as sku_code
            ,sum(sku_origin_payable_amount) as sale_amount
            ,sum(sku_sell_quntity)*500 as quantity  --500g 计算PSD
            ,sum(gross_profit) as profit
        from data_md.app_rpt_sku_store_44_weighing
         where dt='$DATE'
         and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
         group by  store_code,store_name,finished_sku_code

    ) aa
    join
    (
        select
            store_code
            ,sku_code
            ,count(1) as day_num
        from
        (
            select
                sku_code,store_code,order_date
            from dim_sku_store_date_info_di
            where order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
            group by sku_code,store_code,order_date
        )b
        group by store_code,sku_code
     ) bb
     on aa.sku_code=bb.sku_code and aa.store_code=bb.store_code
     left join
     (
        -- select store_code,concat(store_location,'-',store_size) as store_style,city_code,city_name
        -- from ods_uploads_store_tag_details_city
        -- where store_code is not null

        SELECT t.shop_code as  store_code,concat(stand_name,'-',size_name) as store_style,city_code,city_name
             ,rank()over(partition by shop_code order by update_time desc ) rank_num
        FROM ods_cvs_product_display_shop_gezi t
        WHERE   dt='$DATE'
     ) cc
     on aa.store_code = cc.store_code
     and cc.rank_num=1
    ),
    old_new_store_sku_info as(
    select
        aa.sku_code
        ,nvl(aa.old_store_sale_amount/bb.old_store_day_num,0) as old_store_psd_amount
        ,nvl(aa.old_store_quantity/bb.old_store_day_num,0) as old_store_psd
        ,nvl(aa.old_store_profit/bb.old_store_day_num,0) as old_store_psd_profit
        ,nvl(aa.new_store_sale_amount/bb.new_store_day_num,0) as new_store_psd_amount
        ,nvl(aa.new_store_quantity/bb.new_store_day_num,0) as new_store_psd
        ,nvl(aa.new_store_profit/bb.new_store_day_num,0) as new_store_psd_profit
        ,nvl(aa.all_store_sale_amount/bb.all_store_day_num,0) as all_store_psd_amount
        ,nvl(aa.all_store_quantity/bb.all_store_day_num,0) as all_store_psd
        ,nvl(aa.all_store_profit/bb.all_store_day_num,0) as all_store_psd_profit
    from
    (
        select
            sku_code
            ,sum(case when old_store_start_date < '$FDATE_SUB2MONTH' then origin_payable_price else 0 end) as old_store_sale_amount
            ,sum(case when old_store_start_date < '$FDATE_SUB2MONTH' then sku_quantity else 0 end) as old_store_quantity
            ,sum(case when old_store_start_date < '$FDATE_SUB2MONTH' then origin_payable_price - cost_price - cost_tax + vendor_allocated_cost_price else 0 end) as old_store_profit
            ,sum(case when old_store_start_date >= '$FDATE_SUB2MONTH' then origin_payable_price else 0 end) as new_store_sale_amount
            ,sum(case when old_store_start_date >= '$FDATE_SUB2MONTH' then sku_quantity else 0 end) as new_store_quantity
            ,sum(case when old_store_start_date >= '$FDATE_SUB2MONTH' then origin_payable_price - cost_price - cost_tax + vendor_allocated_cost_price else 0 end) as new_store_profit
            ,sum(origin_payable_price) as all_store_sale_amount
            ,sum(sku_quantity) as all_store_quantity
            ,sum(origin_payable_price - cost_price - cost_tax + vendor_allocated_cost_price) as all_store_profit
        from dw_order_sku_v1 t1 left join dim_store_store_opening_date t2
        on t1.dt = t2.dt and t1.store_code = t2.store_code
        where t1.dt='$DATE'
        and t1.store_type in ('0','3')
        and order_status='FINISHED'
        and sku_code <> '34100087'   --不含称重零食
        and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
        group by sku_code


        union all
        select
            finished_sku_code as sku_code
            ,sum(case when old_store_start_date < '$FDATE_SUB2MONTH' then sku_origin_payable_amount else 0 end) as old_store_sale_amount
            ,sum(case when old_store_start_date < '$FDATE_SUB2MONTH' then sku_sell_quntity*500  else 0 end) as old_store_quantity
            ,sum(case when old_store_start_date < '$FDATE_SUB2MONTH' then gross_profit else 0 end) as old_store_profit
            ,sum(case when old_store_start_date >= '$FDATE_SUB2MONTH' then sku_origin_payable_amount else 0 end) as new_store_sale_amount
            ,sum(case when old_store_start_date >= '$FDATE_SUB2MONTH' then sku_sell_quntity*500  else 0 end) as new_store_quantity
            ,sum(case when old_store_start_date >= '$FDATE_SUB2MONTH' then gross_profit else 0 end) as new_store_profit
            ,sum(sku_origin_payable_amount) as all_store_sale_amount
            ,sum(sku_quantity)*500 as all_store_quantity
            ,sum(gross_profit) as all_store_profit
        from data_md.app_rpt_sku_store_44_weighing t1 left join dim_store_store_opening_date t2
        on t1.dt = t2.dt and t1.store_code = t2.store_code
        where t1.dt='$DATE'
        and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
        group by finished_sku_code


    )aa
    join
    (
        select
            sku_code
            ,count(case when old_store_start_date < '$FDATE_SUB2MONTH' then 1 else null end) as old_store_day_num
            ,count(case when old_store_start_date >= '$FDATE_SUB2MONTH' then 1 else null end) as new_store_day_num
            ,count(1) as all_store_day_num
        from
        (
            select
                sku_code,store_code,order_date,old_store_start_date
            from dim_sku_store_date_info_di
            where store_type  in ('0','3')
            and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
            group by sku_code,store_code,order_date,old_store_start_date
        ) b
        group by sku_code
     ) bb
     on aa.sku_code=bb.sku_code
    ),
    style_store_sku_info as(
    select
        aa.sku_code
        ,aa.store_style
        ,aa.city_code
        ,aa.city_name
        ,nvl(aa.sale_amount/bb.day_num,0) as style_store_psd_amount
        ,nvl(aa.quantity/bb.day_num,0) as style_store_psd
        ,nvl(aa.profit/bb.day_num,0) as style_store_psd_profit
    from
    (
        select
            sku_code
            ,store_style
            ,city_code,city_name
            ,sum(sale_amount) as sale_amount
            ,sum(quantity) as quantity
            ,sum(profit) as profit
        from
        (
            select
                store_code
                ,sku_code
                ,sum(origin_payable_price) as sale_amount
                ,sum(sku_quantity) as quantity
                ,sum(origin_payable_price - cost_price - cost_tax + vendor_allocated_cost_price) as profit
            from dw_order_sku_v1
            where dt='$DATE'
            and store_type in ('0','3')
            and order_status='FINISHED'
            and sku_code <> '34100087'   --不含称重零食
            and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
            group by store_code,sku_code


            union all
        select store_code
            ,finished_sku_code  as sku_code
            ,sum(sku_origin_payable_amount) as sale_amount
            ,sum(sku_sell_quntity)*500 as quantity  --500g 计算PSD
            ,sum(gross_profit) as profit
        from data_md.app_rpt_sku_store_44_weighing
         where dt='$DATE'
         and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
         group by  store_code,finished_sku_code



        ) t1
        left join
        (
            -- select store_code,concat(store_location,'-',store_size) as store_style,city_code,city_name
            -- from ods_uploads_store_tag_details_city
            -- where store_code is not null

            SELECT t.shop_code as  store_code,concat(stand_name,'-',size_name) as store_style,city_code,city_name
                   ,rank()over(partition by shop_code order by update_time desc ) rank_num
            FROM ods_cvs_product_display_shop_gezi t
            WHERE   dt='$DATE'
        ) t2
        on t1.store_code = t2.store_code
        and t2.rank_num=1
        group by store_style,sku_code,city_code,city_name

    ) aa
    join
    (
        select
            store_style
            ,sku_code
            ,city_code
            ,count(1) as day_num
        from
        (
            select
                sku_code,store_code,order_date
            from dim_sku_store_date_info_di
            where  order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
            group by sku_code,store_code,order_date
        ) t3
        left join
        (
            -- select store_code,concat(store_location,'-',store_size) as store_style,city_code,city_name
            -- from ods_uploads_store_tag_details_city
            -- where store_code is not null

            SELECT t.shop_code as  store_code,concat(stand_name,'-',size_name) as store_style,city_code,city_name
                 ,rank()over(partition by shop_code order by update_time desc ) rank_num
            FROM ods_cvs_product_display_shop_gezi t
            WHERE   dt='$DATE'
        ) t4
        on t3.store_code = t4.store_code
        and t4.rank_num=1
        group by store_style,sku_code,city_code,city_name
     ) bb
     on aa.sku_code=bb.sku_code and aa.store_style=bb.store_style and aa.city_code=bb.city_code

    ),
    city_sku_info as(
    select
        aa.sku_code
        ,aa.city_code
        ,nvl(aa.sale_amount/bb.day_num,0) as city_store_psd_amount
        ,nvl(aa.quantity/bb.day_num,0) as city_store_psd
        ,nvl(aa.profit/bb.day_num,0) as city_store_psd_profit
    from
    (
        select
            sku_code
            ,city_code
            ,sum(sale_amount) as sale_amount
            ,sum(quantity) as quantity
            ,sum(profit) as profit
        from
        (
            select
                t1.store_code
                ,sku_code
                ,t2.city_code
                ,sum(origin_payable_price) as sale_amount
                ,sum(sku_quantity) as quantity
                ,sum(origin_payable_price - cost_price - cost_tax + vendor_allocated_cost_price) as profit
            from dw_order_sku_v1 t1
            join dim_store_info t2
              on t1.store_code=t2.store_code
              and t2.dt='$DATE'
              and t2.store_type in ('0','3')
            where t1.dt='$DATE'
            and t1.store_type in ('0','3')
            and order_status='FINISHED'
            and sku_code <> '34100087'   --不含称重零食
            and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
            group by t1.store_code,sku_code,t2.city_code

            union all
        select t1.store_code
            ,finished_sku_code  as sku_code
            ,t2.city_code
            ,sum(sku_origin_payable_amount) as sale_amount
            ,sum(sku_sell_quntity)*500 as quantity  --500g 计算PSD
            ,sum(gross_profit) as profit
        from data_md.app_rpt_sku_store_44_weighing t1
        join dim_store_info t2
              on t1.store_code=t2.store_code
              and t2.dt='$DATE'
              and t2.store_type in ('0','3')
         where t1.dt='$DATE'
         and order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
         group by  t1.store_code,finished_sku_code,t2.city_code
        ) t1
        --left join
        --(
        --    -- select store_code,city_code
        --    -- from ods_uploads_store_tag_details_city
        --    -- where store_code is not null
--
        --    SELECT t.shop_code as  store_code,concat(stand_name,'-',size_name) as store_style,city_code,city_name
        --    FROM ods_cvs_product_display_shop_gezi t
        --    WHERE   dt='$DATE'
        --) t2
        --on t1.store_code = t2.store_code
        group by sku_code,city_code

    ) aa
    join
    (
        select
            sku_code
            ,city_code
            ,count(1) as day_num
        from
        (
            select
                sku_code,store_code,order_date,city_code
            from dim_sku_store_date_info_di
            where order_date between '$FDATE_SUB2MONTH' and '$FORMAT_DATE'
            group by sku_code,store_code,order_date,city_code
        ) t3
        --left join
        --(
        --    select store_code,city_code
        --    from ods_uploads_store_tag_details_city
        --    where store_code is not null
        --) t4
        --on t3.store_code = t4.store_code
        group by sku_code,city_code
     ) bb
     on aa.sku_code=bb.sku_code and aa.city_code=bb.city_code

    )

    insert overwrite table ${TABLE_NAME} partition (dt=$DATE)
    select
        report_date
        ,city_code
        ,city_name
        ,sku_code
        ,sku_name
        ,sku_division_code
        ,sku_division_name
        ,store_code
        ,store_name
        ,store_style
        ,psd_profit -- 门店
        ,psd_amount
        ,psd
        ,old_store_psd_profit --既存店
        ,old_store_psd_amount
        ,old_store_psd
        ,new_store_psd_profit --新店
        ,new_store_psd_amount
        ,new_store_psd
        ,all_store_psd_profit -- 全店
        ,all_store_psd_amount
        ,all_store_psd
        ,style_store_psd_profit --类型门店-城市
        ,style_store_psd_amount
        ,style_store_psd
        ,city_store_psd_profit -- 全店-城市
        ,city_store_psd_amount
        ,city_store_psd
    from (
    select
        '$FORMAT_DATE' as report_date
        ,t1.city_code
        ,t1.city_name
        ,t1.sku_code
        ,t4.sku_name
        ,t4.sku_division_code
        ,t4.sku_division_name
        ,t1.store_code
        ,t1.store_name
        ,t1.store_style
        ,t1.psd_profit -- 门店
        ,t1.psd_amount
        ,t1.psd
        ,t2.old_store_psd_profit --既存店
        ,t2.old_store_psd_amount
        ,t2.old_store_psd
        ,t2.new_store_psd_profit --新店
        ,t2.new_store_psd_amount
        ,t2.new_store_psd
        ,t2.all_store_psd_profit -- 全店
        ,t2.all_store_psd_amount
        ,t2.all_store_psd
        ,t3.style_store_psd_profit --类型门店-城市
        ,t3.style_store_psd_amount
        ,t3.style_store_psd
        ,t5.city_store_psd_profit -- 全店-城市
        ,t5.city_store_psd_amount
        ,t5.city_store_psd
        ,row_number()over(partition by t1.sku_code,t1.store_code ) as rn
    from store_sku_info t1
    left join old_new_store_sku_info t2
    on t1.sku_code = t2.sku_code
    left join style_store_sku_info t3
    on t1.sku_code = t3.sku_code and t1.store_style = t3.store_style and t1.city_code = t3.city_code
    left join city_sku_info t5
    on t1.sku_code = t5.sku_code and t1.city_code = t5.city_code
    join dim_sku_info t4
    on t4.dt='$DATE'
    and t4.sku_code= t1.sku_code
    ) a
    where a.rn = 1;
    -- 验证数据
    ${CHECK_DATA_SQL};
"
EOF
}

