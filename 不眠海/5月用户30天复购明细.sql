-- 饮品站商品
with
sku_info as (
  select
    a.sku_code,
    a.sku_name,
    case when  sku_division_name IN('茶类茶饮','乳类茶饮','果类茶饮','其他茶饮') THEN '茶饮'
         when  sku_division_name IN('咖啡') THEN '咖啡'
         else '其它' end as sku_division_name,
    sku_type,
    sku_division_code,
    sku_state_code
  from
    default.dim_sku_info a 
    where a.dt = '${today-1}'
    and a.sku_class_code = '50'
    and a.sku_division_code not in ('5001', '5002','5019','5020')
    and a.sku_code not in ('62be949f20ef0c86d73202c145d0f14b','2a179e702434a126dfb31f909e86092c','15d00c356e4d1343809c033a07611343','8d6d52c046f5d0c407555d28a295ba6c','4f904185f913e55856d969d538568158','ec45243f1e4c7b91e058b7c316ced9ca','f9db5aefc73db015523721e8d2fd99c6','bf65d1821cd79dc71cccbddd3f8a968a','7f2eebfa989c67a89825c9c195e932a8','d167fe010de973cdc87c430a732f3f90','2a84b1891346dafff9a8717ad2637f9b','9ed91aed72b124348ef5d4922325a8db','f6b1794e2e8c24b2f884ff48475845f9','b091d93bfaf541b60882b9a3f5897145','f84fefc1ca5bc6adda3c76f264bc7431','0ee3cbcb152aa2581f07a91d43ae5d71','1f436ea0b68fc116b8b20559dd579a54','dbe78b0d14d75af4b643473672ed3687','424f72b194ba0a7cf9f0111e8edcd406','07ff01e130dc07c80f07d6af0ef8e112','8628e3f0c12dd3dfedd9d3ab48b84d38','819c656339a5efee412d39de033af59b','ce9b558a9c26ffbc80072a3acaf5670f','1c5506969a51577bdef03ab5c2832477','185769ddc0c014a76310f545505d2a89','5eb4221b00e64ec0119e2f3b0f376792')
    and a.sku_type='动态组合商品'
  group by 1,2,3,4,5,6
),

store_info as(
select
  t1.store_code,
  t1.store_name,
  t1.store_city
from
  data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
  where t1.dt = '${today-1}'
  and t1.store_type = '20'
  and t1.store_status = '1'
  and t1.store_code not in(
    '1ef7d2720f79858ee50b3e7b9d43e198',
    '35600187690e83585abfb96c6731a3bf',
    '4eb01d68cd59da9ea78b794a127ac222',
    '96d51bca1b712ac335a77823302150c1',
    '9a324a3a3ad36275233bdd69fa1b05ef',
    '0040da5d0cf8c2a74686d83f97100b8c',
    '35f9841d320daaf2877d333fa51535d5',
    '60be5ec19dad8223e4ceca5f64b30fc7',
    '073aefd4bd7d608aecdbde3352e49e89'
  )
  and store_city in('北京市','天津市')
 ),

--5月高频用户（大于等于4次） 
order_info as (
  select coalesce(b.finished_sku_code, a.sku_code) as sku_code
    ,a.pay_id as user_id
    ,a.order_no
    ,a.order_date
    ,sku_quantity
    ,a.store_code
    ,c.sku_division_name
  from
    data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt = '${today-1}'
    and finished_sku_type_code = '9' and b.component_sku_code = a.sku_code
    left join sku_info c on coalesce(b.finished_sku_code, a.sku_code)=c.sku_code
  where a.dt >= '20220501'
    and a.dt<='20220630'
    and a.sku_quantity > 0
    and coalesce(a.pay_id,'') not in('','30112507801894')
  group by 1,2,3,4,5,6,7
),

high_freq_user as(
select a.user_id
,a.order_cnt as order_cnt_m5
,sum(coalesce(b.order_cnt,0)) as order_cnt
from
(select user_id
,count(distinct order_no) as order_cnt
,max(order_date) as max_date
from order_info a
join sku_info b on a.sku_code=b.sku_code
join store_info c on a.store_code=c.store_code
where a.order_date>=date('2022-05-01') 
and a.order_date<=date('2022-05-31')
group by 1
) a 
left join
(
select user_id
,order_date
,count(distinct order_no) as order_cnt
from order_info a
join sku_info b on a.sku_code=b.sku_code
join store_info c on a.store_code=c.store_code
group by 1,2
) b on a.user_id=b.user_id and b.order_date>a.max_date and b.order_date<=date_add('day',30,max_date)
group by 1,2
),

t as(
select order_cnt_m5
,count(distinct user_id) as total_user_cnt
,count(distinct case when order_cnt>0 then user_id end) as rebuy_user_cnt
from high_freq_user
group by 1
)

select a.*,c.sku_division_name,d.order_cnt_m5,f.secret_phone
from data_md.dm_order_summary_soberhi_order_detail_user_store_sku_day_di_v1 a
    left join data_md.dm_md_dim_sku_components_info_package_sku_v1 b on b.dt = '${today-1}'
    and finished_sku_type_code = '9' and b.component_sku_code = a.sku_code
    join sku_info c on coalesce(b.finished_sku_code, a.sku_code)=c.sku_code
    join store_info e on a.store_code=e.store_code
    join high_freq_user d on a.user_id=d.user_id and order_cnt=0
    left join default.dim_user_info f on a.user_id=f.user_id and f.dt='${today-1}'
  where a.dt >= '20220501'
    and a.dt<='20220630'
    and a.sku_quantity > 0
    and coalesce(a.pay_id,'') not in('','30112507801894')
