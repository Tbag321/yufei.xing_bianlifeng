#
# --------------------------------------
# DATE: 2022-11-30
# DEV:
# DESC:
# PRODUCT_WIKI:
# --------------------------------------
source ${ETC}/format_date.cnf


TABLE_NAME="data_build.dwd_store_construction_roster_store_demand_v1_di"
UNIQ_KEY='store_id,max_week_of_year,total_label_ld,total_label_md,total_label_sd1,total_label_sd2,total_label_ln,total_label_mn,total_label_sn1,total_label_sn2'
HDFS_DIR="/user/data_build/dwd/${TABLE_NAME}/dt=${DATE}"
CHECK_DATA_SQL="
    select
        '数据条数必须大于0', assert_true(count(1)>0), count(1),
        '唯一键唯一', assert_true(count(1)=sum(m)), sum(m)
    from (
        select ${UNIQ_KEY},count(1)m
        from ${TABLE_NAME}
        where dt='${DATE}'
        group by ${UNIQ_KEY}
    ) t;
"

##JOB入口函数
function dwd_store_construction_roster_store_demand_v1_di_run {
    #主体计算函数
    calculate
}

#清理hdfs文件
function rebuild_hdfs {
    rebuild_hdfs_dir "${HDFS_DIR}"
}

#JOB业务计算函数
function calculate {
--   ${HIVE} -e << EOF "
        set hive.cli.errors.ignore=false;
with
base_0 as
(
select
t1.roster_id
,t1.store_id
,t1.employee_id
,t1.work_date
,t1.start_time
,t1.end_time
,t1.is_night
,weekofyear(t1.work_date) as week_of_year
,year(t1.work_date) as year_of_work
,t2.holidays
,t1.dt
,date_sub(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) as new_dt
from data_build.dw_roster_effect_roster_detail_info_da_view t1
left join (
select
weekofyear(date_key) as week_of_year
,year(date_key) as year_of_week
,sum(is_holiday) as holidays --当周节假日天数
from data_build.dim_date_ya_v2
group by
weekofyear(date_key)
,year(date_key)
) t2 on weekofyear(t1.work_date) = t2.week_of_year and year(t1.work_date) = t2.year_of_week
where t1.dt = '${DATE_ADD1DAY}'
and t1.store_type_desc = '门店'
and (t1.class_id in ('0') or t1.attr_id = '344') --20250702新增attr_id = '344'远程支援班次类型
and t1.store_type = '0'
--and (sale_type <> '全天不营业' or sale_type is null)
and t1.work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
and t1.work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),20) --下周+未来三周

union all

select
t1.roster_id
,t1.store_id
,t1.employee_id
,t1.work_date
,t1.start_time
,t1.end_time
,t1.is_night
,weekofyear(t1.work_date) as week_of_year
,year(t1.work_date) as year_of_work
,t2.holidays
,t1.dt
,date_sub(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) as new_dt
from data_build.dw_roster_effect_roster_detail_info_da_view t1
left join (
select
weekofyear(date_key) as week_of_year
,year(date_key) as year_of_week
,sum(is_holiday) as holidays --当周节假日天数
from data_build.dim_date_ya_v2
group by
weekofyear(date_key)
,year(date_key)
) t2 on weekofyear(t1.work_date) = t2.week_of_year and year(t1.work_date) = t2.year_of_week
where t1.dt = '${DATE_ADD1DAY}'
and t1.store_type_desc = '门店'
and store_id = '110000583'
and t1.attr_id = '358' --20251127新增，门店需要一个专门收银岗，如果班表出现358机动队支援班次，则增加1个hc
and t1.store_type = '0'
--and (sale_type <> '全天不营业' or sale_type is null)
and t1.work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
and t1.work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),20) --下周+未来三周
),
base_1 as
(
    select
roster_id
,store_id
,employee_id
,work_date
,start_time
,end_time
,is_night
,t1.week_of_year
,year_of_work
,holidays
,dt
,new_dt
,day_of_week_name
    from base_0 t1
    left join data_build.dim_date_ya_v2 t2
    on new_dt = t2.date_key

),
base_2 as
(
    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name in ('星期一','星期二')
        and work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
        and work_date <= date_sub(next_day('${FDATE_SUB0DAY}','mon'),1) --本周

        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name in ('星期一','星期二')
        and work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),0)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),6) --下周

            union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name in ('星期一','星期二')
        and work_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),7)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),13) --下下周

        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name not in ('星期一','星期二')
        and work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),0)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),6) --下周

        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name not in ('星期一','星期二')
        and work_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),7)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),13) --下下周
        
        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name not in ('星期一','星期二')
        and work_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),14)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),20) --下下下周
),

week_lsit as( --取假期最少的那周且离当前最远的那周
select
store_id
,week_of_year
,year_of_work
,holidays
,dense_rank() over(partition by store_id order by concat(year_of_work,week_of_year) desc) as rn--按照未来时间排序，时间越远排序越靠前
from(
select
store_id
,week_of_year
,year_of_work
,holidays
,dense_rank() over(partition by store_id order by holidays) as rn --按照当周的假期排序,假期少的排序靠前
from(
select distinct
store_id
,week_of_year
,year_of_work
,holidays
from base_2
) a
) b
where b.rn = 1
),

base as
(
    select
t.roster_id
,t.store_id
,t.employee_id
,t.work_date
,t.start_time
,t.end_time
,t.is_night
,(t.end_time - t.start_time) as work_hours
,t.week_of_year
,t.year_of_work
from base_2 t
join week_lsit t1 on t.store_id = t1.store_id and t.week_of_year = t1.week_of_year and t.year_of_work = t1.year_of_work and t1.rn = 1
),
base_list as
(
    select
    roster_id
    ,week_of_year
    ,work_date
    ,store_id
    ,employee_id
    ,work_hours
    ,start_time
    ,end_time
    ,case when start_time is null then ''
            when is_night=1 then '夜班'
            when is_night=0 then '白班'
        end as work_shift_label_1
    ,case when work_hours>=10 then '长班_10h'
    -- when work_hours>=10 then '长班_10_12h'
    when work_hours>=8 then '长班_8_10h'
            when work_hours<8 and work_hours>=4 then '短班_4-8H'
            when work_hours<4 then '短班_<4H'
        end as work_shift_label_2
    from base
),
info_0 as
(select
 sale_date as c_date
 ,weekofyear(sale_date) as week_of_year
 ,shop_code as store_code
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 ,day_of_week_name
 from data_build.pdw_idss_mmc_cooperate_shop_open_info_view t1
 left join data_build.dim_date_ya_v2 t2
    on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.date_key
 where t1.dt= '${DATE}'
 and shop_type=0
 and shop_state=1
 and bach_business_time<>'全天不营业'
 ),

 info as
 (
    select
    store_code
    ,c_date
    ,week_of_year

    from info_0
    where day_of_week_name in ('星期一','星期二')
    and c_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
    and c_date <= date_sub(next_day('${FDATE_SUB0DAY}','mon'),1) --本周

    union

    select
    store_code
    ,c_date
    ,week_of_year

    from info_0
    where day_of_week_name in ('星期一','星期二')
    and c_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),0)
    and c_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),6) --下周

    union
    
    select
    store_code
    ,c_date
    ,week_of_year

    from info_0
    where day_of_week_name in ('星期一','星期二')
    and c_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),7)
    and c_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),13) --下下周

    union

    select
    store_code
    ,c_date
    ,week_of_year
    from info_0

    where day_of_week_name not in ('星期一','星期二')
    and c_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),0)
    and c_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),6) --下周

   union

    select
    store_code
    ,c_date
    ,week_of_year
    from info_0

    where day_of_week_name not in ('星期一','星期二')
    and c_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),7)
    and c_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),13) --下下周

   union

    select
    store_code
    ,c_date
    ,week_of_year
    from info_0

    where day_of_week_name not in ('星期一','星期二')
    and c_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),14)
    and c_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),28) --下下下周

 ),
 store_info as
 (
 select
    store_code
    ,week_of_year
    ,min(c_date) as opening_date_min
    ,max(c_date) as opening_date_max
    ,count(distinct c_date ) as opening_days
    from info
    group by store_code
    ,week_of_year),

-- 单店by天班型明细
base_final as
(
    select
    store_id
    ,work_date
    ,employee_id
    ,work_shift_label_1
    ,work_shift_label_2
    ,week_of_year
    ,case when work_shift_label_1='白班' and work_shift_label_2='长班_10h' then '长白班'
    when work_shift_label_1='白班' and work_shift_label_2='长班_8_10h' then '中白班'
            when work_shift_label_1='白班' and work_shift_label_2='短班_4-8H' then '短白班1'
            when work_shift_label_1='白班' and work_shift_label_2='短班_<4H' then '短白班2'

    when work_shift_label_1='夜班' and work_shift_label_2='长班_10h' then '长夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='长班_8_10h' then '中夜班'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_4-8H' then '短夜班1'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_<4H' then '短夜班2'
        else null end as label
    ,count(work_date) as workdays
    from base_list
    group by store_id
    ,work_date
    ,employee_id
    ,work_shift_label_1
    ,work_shift_label_2
    ,week_of_year
    ,case when work_shift_label_1='白班' and work_shift_label_2='长班_10h' then '长白班'
    when work_shift_label_1='白班' and work_shift_label_2='长班_8_10h' then '中白班'
            when work_shift_label_1='白班' and work_shift_label_2='短班_4-8H' then '短白班1'
            when work_shift_label_1='白班' and work_shift_label_2='短班_<4H' then '短白班2'

    when work_shift_label_1='夜班' and work_shift_label_2='长班_10h' then '长夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='长班_8_10h' then '中夜班'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_4-8H' then '短夜班1'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_<4H' then '短夜班2'
        else null end
),
final as
(

-- 单店by天班型分布

    select
    store_id
    ,week_of_year
    ,work_date
    ,label
    ,count(label) as label_no
    from base_final
    group by store_id
    ,week_of_year
    ,work_date
    ,label
),
final_week_list as
(
select
    store_id
    ,week_of_year
    ,label
    ,sum(label_no) as total_label_no

from final
group by
store_id
    ,week_of_year
    ,label
),
max_week as
(
    select
    store_id
    ,max(week_of_year) as max_week_of_year
    from final
    group by store_id
),
final_label_no1 as
(
select
store_id
,t1.week_of_year
,opening_days
,max(case when label = '长白班' then total_label_no else 0 end) as total_label_ld
,max(case when label = '中白班' then total_label_no else 0 end) as total_label_md
,max(case when label = '短白班1' then total_label_no else 0 end) as total_label_sd1
,max(case when label = '短白班2' then total_label_no else 0 end) as total_label_sd2
,max(case when label = '长夜班' then total_label_no else 0 end) as total_label_ln
,max(case when label = '中夜班' then total_label_no else 0 end) as total_label_mn
,max(case when label = '短夜班1' then total_label_no else 0 end) as total_label_sn1
,max(case when label = '短夜班2' then total_label_no else 0 end) as total_label_sn2

from final_week_list t1
left join store_info t2
on t1.store_id = t2.store_code
and t1.week_of_year = t2.week_of_year
group by store_id
,t1.week_of_year
,opening_days
),
final_label_no2 as
(
select
t1.store_id
,week_of_year
,max(case when week_of_year = max_week_of_year then opening_days
else 0 end) as opening_days
,max(case when week_of_year = max_week_of_year then total_label_ld
else 0 end) as total_label_ld
,max(case when week_of_year = max_week_of_year then total_label_md
else 0 end) as total_label_md
,max(case when week_of_year = max_week_of_year then total_label_sd1
else 0 end) as total_label_sd1
,max(case when week_of_year = max_week_of_year then total_label_sd2
else 0 end) as total_label_sd2
,max(case when week_of_year = max_week_of_year then total_label_ln
else 0 end) as total_label_ln
,max(case when week_of_year = max_week_of_year then total_label_mn
else 0 end) as total_label_mn
,max(case when week_of_year = max_week_of_year then total_label_sn1
else 0 end) as total_label_sn1
,max(case when week_of_year = max_week_of_year then total_label_sn2
else 0 end) as total_label_sn2
from final_label_no1 t1
left join max_week t2
on t1.store_id = t2.store_id
group by t1.store_id
,week_of_year
),
final_label_no3 as
(
    select
    t1.store_id
    ,max_week_of_year
    ,sum(opening_days) as opening_days
    ,sum(total_label_ld) as total_label_ld
    ,sum(total_label_md) as total_label_md
    ,sum(total_label_sd1) as total_label_sd1
    ,sum(total_label_sd2) as total_label_sd2
    ,sum(total_label_ln) as total_label_ln
    ,sum(total_label_mn) as total_label_mn
    ,sum(total_label_sn1) as total_label_sn1
    ,sum(total_label_sn2) as total_label_sn2
    from final_label_no2 t1
    left join max_week t2 on t1.store_id = t2.store_id
    group by t1.store_id
    ,max_week_of_year
)


,sku_quantity_raw as  
(
select
   record_date
  ,store_code
  ,sum(greatest(sku_purchase_quantity,0)) as sku_purchase_quantity_all --到货数量 全部商品
  ,sum(if(t2.sku_type not in ('耗材商品'),greatest(sku_purchase_quantity,0),0)) as sku_purchase_quantity_goods --到货数量 不含耗材
  ,sum(if(t2.sku_class_code in ('30','33'),greatest(sku_purchase_quantity,0),0)) as sku_purchase_quantity_cold --到货数量 冷饮

from data_smartorder.app_inventory_store_sku_di t1
inner join data_build.dim_sku_info t2
        on t2.dt = '${DATE_SUB1DAY}'
       and t1.sku_code = t2.sku_code 
where t1.dt >='${DATE_SUB31DAY}'
  and t1.store_type = '0'
 -- and t1.store_code = '100000696'
group by 
t1.record_date
,t1.store_code
),

sku_quantity_30days as 
(
select 
t1.store_code
,count(distinct case when t1.sku_purchase_quantity_all > 0 then  t1.record_date end)as sale_date_count
,sum(case when t1.sku_purchase_quantity_all > 0 then t1.sku_purchase_quantity_all end) as sku_purchase_quantity_all
,sum(case when t1.sku_purchase_quantity_goods > 0 then t1.sku_purchase_quantity_goods end) as sku_purchase_quantity_goods
,sum(case when t1.sku_purchase_quantity_cold > 0 then t1.sku_purchase_quantity_cold end) as sku_purchase_quantity_cold

,round(sum(case when t1.sku_purchase_quantity_all > 0 then t1.sku_purchase_quantity_all end)/count(distinct case when t1.sku_purchase_quantity_all > 0 then t1.record_date end),0) as sku_purchase_quantity_all_perdays
,round(sum(case when t1.sku_purchase_quantity_goods > 0 then t1.sku_purchase_quantity_goods end)/count(distinct case when t1.sku_purchase_quantity_all > 0 then t1.record_date end),0) as sku_purchase_quantity_goods_perdays
,round(sum(case when t1.sku_purchase_quantity_cold > 0 then t1.sku_purchase_quantity_cold end)/count(distinct case when t1.sku_purchase_quantity_all > 0 then t1.record_date end),0) as sku_purchase_quantity_cold_perdays

from sku_quantity_raw t1
group by t1.store_code

),


30days_sales as
( 
select
   store_code
   --计算日均销售额，剔除450以上大单，剔除2000以下店日 结果可能为null
   ,avg(case when payable_price_lessthan_450_for_roster >= 1000 then payable_price_lessthan_450_for_roster else null end) as avg_amount_30days
  from data_smartorder.dm_ordering_suggestion_reference_data_store_amt_for_roster_da t
  where dt = '${DATE_SUB1DAY}'
   and sale_date >= '${FDATE_SUB31DAY}'
   and store_type = '0'
   and order_cnt_store >= 20 --正常营业店日
   and holiday_type in (1,2) --剔除节假日
  group by store_code
  ),


ff_create_raw as 
(
--FF 录入制作数量
select
  create_date
 ,store_code
 ,sum(make_quantity) as make_quantity
from data_smartorder.dm_copy_dw_promotion_store_sku_freshness_make_v1_view
where dt ='${DATE_SUB1DAY}' --最新dt
  and create_date >= '${FDATE_SUB31DAY}'
  --and store_code = '100000696'
group by create_date,store_code
),


ff_create_30days as 
(
select 
store_code 
,count(distinct case when make_quantity>=1 then create_date end) as ff_create_date_count
,sum(make_quantity) as ffmake_quantity_all
,round(sum(make_quantity)/count(distinct case when make_quantity>=1 then create_date end),0) as ffmake_quantity_perdays
from ff_create_raw 
group by store_code 
),

ff_sale_raw as 
(
--FF 实际销售数量
select 
   order_date
  ,store_code
  ,sum(sku_quantity) as sale_quantity
from  data_build.dw_order_sku_v1 t
where dt = '${DATE_SUB1DAY}' --最新dt
  and store_type = '0'
  and order_date >='${FDATE_SUB31DAY}'
  and sku_division_code in ('0301','0302','0303','0304','0501','0502','0601','0602','0603','0706')
  and pay_status = 'PAY_SUCCESS'
  --and store_code = '100000696'
group by order_date,store_code
),


ff_sale_30days as 
(
select 
store_code 
,count(distinct case when sale_quantity>=1 then order_date end) as ff_order_date_count
,sum(sale_quantity) as ffsale_quantity_all
,round(sum(sale_quantity)/count(distinct case when sale_quantity>=1 then order_date end),0) as ffsale_quantity_perdays
from ff_sale_raw 
group by store_code 
),



roster_hours_raw as 
(
select 
work_date work_date
,store_id store_code
,sum(work_hours) as work_hours
,is_night is_night

from 
data_build.dw_roster_effect_roster_detail_info_da_view
where dt = '${DATE_SUB1DAY}'
and roster_source = '成功班表'
and work_date    between '${FDATE_SUB31DAY}' and '${FDATE_SUB1DAY}'
and class_id = '0'
and store_type = '0'
and sale_type <> '全天不营业'
group by work_date,store_id,is_night
),

roster_hours_30days as 
(select 
store_code 
,count(distinct case when work_hours >= 4 then work_date end )as open_days
,sum(case when is_night = 1 then work_hours end ) as night_hours
,sum(case when is_night = 0 then work_hours end ) as day_hours
,sum(work_hours) as all_work_hours
,round(sum(work_hours)/count(distinct case when work_hours>=4 then work_date end),0) as work_hours_perdays 
from roster_hours_raw
group by store_code 
)


,workload_level_process as 
(select 
t1.store_code as store_code 
,t6.work_hours_perdays as work_hours_perdays
,t2.sale_date_count as sale_days
,t1.avg_amount_30days as sale_amount
,case when t1.avg_amount_30days >=18000 then 18000 else round(t1.avg_amount_30days/1000,0)*1000 end as sale_level
,nvl(round(t2.sku_purchase_quantity_cold_perdays/t6.work_hours_perdays,2),'-') as cold_count_perhours
,nvl(round(t2.sku_purchase_quantity_goods_perdays/t6.work_hours_perdays,2),'-') as sku_count_perhours
,nvl(round(t4.ffmake_quantity_perdays/t6.work_hours_perdays,2),'-') as ff_make_perhours
,nvl(round(t3.ffsale_quantity_perdays/t6.work_hours_perdays,2),'-') as ff_sale_perhours
,case when nvl(round(t2.sku_purchase_quantity_cold_perdays/t6.work_hours_perdays,2),'-') >=8.3 then 3 
when nvl(round(t2.sku_purchase_quantity_cold_perdays/t6.work_hours_perdays,2),'-') <=4.4 then 1 
else 2 end as cold_count_level
,case when nvl(round(t2.sku_purchase_quantity_goods_perdays/t6.work_hours_perdays,2),'-') >=54 then 3 
when nvl(round(t2.sku_purchase_quantity_goods_perdays/t6.work_hours_perdays,2),'-') <=40 then 1 
else 2 end as sku_count_level
,case when nvl(round(t4.ffmake_quantity_perdays/t6.work_hours_perdays,2),'-') >=28.7 then 3 
when nvl(round(t4.ffmake_quantity_perdays/t6.work_hours_perdays,2),'-') <=16.8 then 1 
else 2 end as ff_make_level
,case when nvl(round(t3.ffsale_quantity_perdays/t6.work_hours_perdays,2),'-')  >=23.5 then 3 
when nvl(round(t3.ffsale_quantity_perdays/t6.work_hours_perdays,2),'-')  <=10.9 then 1 
else 2 end as ff_sale_level

from 30days_sales t1 
left join sku_quantity_30days t2 on t1.store_code = t2.store_code 
left join ff_create_30days t4 on t1.store_code = t4.store_code 
left join ff_sale_30days t3 on t1.store_code = t3.store_code 
left join roster_hours_30days t6 on t1.store_code = t6.store_code
)




insert overwrite table ${TABLE_NAME} partition (dt='$DATE')

select distinct
t1.store_id
,t1.max_week_of_year
,t1.total_label_ld/t1.opening_days as total_label_ld
,t1.total_label_md/t1.opening_days as total_label_md
,t1.total_label_sd1/t1.opening_days as total_label_sd1
,t1.total_label_sd2/t1.opening_days as total_label_sd2
,t1.total_label_ln/t1.opening_days as total_label_ln
,t1.total_label_mn/t1.opening_days as total_label_mn
,t1.total_label_sn1/t1.opening_days as total_label_sn1
,t1.total_label_sn2/t1.opening_days as total_label_sn2
,t1.opening_days as opening_days
,t2.sale_level as sale_level 
,round(case when t3.difficulty_level_new = 'D4' then 2 when t3.difficulty_level_new = 'D3' then 1 else 0 end +(t2.cold_count_level+t2.sku_count_level)/2 +(t2.ff_make_level+t2.ff_sale_level)/2,0)
as work_level 
from final_label_no3 t1
left join workload_level_process t2 on t1.store_id = t2.store_code 
left join data_build.dwd_store_construction_store_groups_recruit_gap t3 on t1.store_id = t3.store_code and t3.dt = '${DATE_SUB1DAY}'
        ;

        -- 验证数据
        ${CHECK_DATA_SQL};

        "
EOF
}