--门店招聘等级
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

 select
 a.dt,
 b.store_cvs_code,
 b.display_name,
 new_level,
 a.group_level,
 a.priority_level
 from data_build.dwd_store_construction_store_groups_recruit_gap a
 left join desensitization b on a.store_code = b.store_code
 where a.dt >= 20170101
and b.store_cvs_code = '100011007'

-------------------------------------------------------------------------

 --门店负责人岗位
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
 display_name),

 list as(
 select
 t1.dt --生效日
 ,t1.store_code
 ,t1.store_name
 ,t4.store_cvs_code
 ,t4.display_name
 ,t1.store_city
 ,IF(LENGTH(store_manager_no)<8,CONCAT('10',store_manager_no),store_manager_no) AS manager_code
 ,t3.protect_tag
 ,t2.hps_d_jobcode as position_cn
 ,t2.hps_d_hr_status
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 left join data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw_view t2
 on t1.store_manager_no = t2.emplid and t2.dt >= '${today-1}' and t1.dt = t2.dt
 left join data_shop.dm_shop_staff_protect_tag_v2 t3
 on IF(LENGTH(store_manager_no)<8,CONCAT('10',store_manager_no),store_manager_no) = t3.staff_code 
 and t3.dt >= '${today-1}' and t1.dt = t3.dt
 left join desensitization t4 on t1.store_code = t4.store_code
 where t1.dt >= '${today-1}'
 and t1.store_type = 0 --门店默认0
 --and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
 --and t4.store_cvs_code = '110000096'
 )

 select
 *
  ,row_number() over (partition by concat(store_cvs_code,manager_code,protect_tag,position_cn,hps_d_hr_status) order by dt desc) as rn
  from list
  where store_cvs_code = '100011007'
  
-------------------------------------------------------------------------

--经营状态
--当周夜间不营业天数统计
with no_sale_night_num as(
select
date_add(record_date,7-case when dayofweek(record_date) = 1 then 7 else dayofweek(record_date) - 1 end) as order_week,
store_code,
sum(case when all_day_type = '营业' then 1 else 0 end) as all_day_sale_num,
sum(case when all_day_type = '不营业' then 1 else 0 end) as all_day_no_sale_num,
sum(case when night_type = '营业' then 1 else 0 end) as sale_night_num,
sum(case when night_type = '不营业' then 1 else 0 end) as no_sale_night_num
from data_smartorder.dw_ordering_report_store_business_status_da
where dt = '${today-1}'
group by date_add(record_date,7-case when dayofweek(record_date) = 1 then 7 else dayofweek(record_date) - 1 end),
store_code
),

store_info as(
select
store_code,
store_cvs_code,
store_city,
store_type,
store_type_desc,
display_name,
store_location_type
from data_md.dm_md_dim_store_base_info_store_v1
where dt = '${today-1}'
group by
store_code,
store_cvs_code,
store_city,
store_type,
store_type_desc,
display_name,
store_location_type
),

sale_info as(
select
store_code,
1-sum(sale_night_num)*1.0000/sum(all_day_sale_num) as no_sale_night_rat
from no_sale_night_num
where order_week between '2022-06-05' and '2022-10-25'
group by store_code
)

select
a.order_week,
a.store_code,
b.store_cvs_code,
b.store_city,
b.store_type,
b.store_type_desc,
b.display_name,
b.store_location_type,
a.all_day_sale_num,
a.all_day_no_sale_num,
a.sale_night_num,
a.no_sale_night_num,
c.no_sale_night_rat,
case 
when all_day_sale_num = 0 then '休眠'
when all_day_sale_num = 1 and sale_night_num = 0 then '夜间闭店'
when all_day_sale_num = 2 and sale_night_num = 0 then '夜间闭店'
when all_day_sale_num = 3 and sale_night_num < 2 then '夜间闭店'
when all_day_sale_num = 4 and sale_night_num < 2 then '夜间闭店'
when all_day_sale_num = 5 and sale_night_num < 3 then '夜间闭店'
when all_day_sale_num = 6 and sale_night_num < 3 then '夜间闭店'
when all_day_sale_num = 7 and sale_night_num < 4 then '夜间闭店'
else '正常营业'
end as sale_type
from no_sale_night_num a
left join store_info b on a.store_code = b.store_code
left join sale_info c on a.store_code = c.store_code
where order_week > '2021-08-02'
and a.store_code = 'cd75350318248c6d309dd8fb78167e22'
  
-------------------------------------------------------------------------

--交易转换率
--交易转换率-日-门店维度-周维度
with valid_store as(
    select
    from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date,
    store_code
    from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view
    where dt >= 20160101
    and store_status in ('3','2')
    group by from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),store_code
)

select
date_add(a.event_date,1 - case when dayofweek(a.event_date) = 1 then 7 else dayofweek(a.event_date) - 1 end),
a.store_code,
--time_hour,
sum(go_customer_num) as go_customer_num,
sum(order_num_all) as order_num_all,
sum(order_num_all)*1.0000/sum(go_customer_num) as rate
from data_smartorder.dm_ordering_report_store_change_info_di a
join valid_store b
on a.store_code=b.store_code
and a.event_date=b.record_date
where a.dt between 20200501 and 20220826
and a.store_code in ('003fd3c8db4c87b80297f805e9d21cbc')
--and a.event_date = '20220704'
group by
date_add(a.event_date,1 - case when dayofweek(a.event_date) = 1 then 7 else dayofweek(a.event_date) - 1 end),
a.store_code
--time_hour
 
-------------------------------------------------------------------------

--门店人员质量
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

select 
 substr(dt,1,6) as dt_month
 ,ttt.store_code
 ,b.store_cvs_code
 ,b.display_name
 ,sum(total_cnts) as total_cnts
 ,sum(protect_cnts) as protect_cnts
 ,sum(normal_cnts) as normal_cnts
 ,sum(Resignation_cnts) as Resignation_cnts
 ,sum(last_cnts) as last_cnts
 ,sum(observation_cnts) as observation_cnts
 ,sum(Resigned_cnts) as Resigned_cnts
from (
 select 
 dt
 ,store_code
 ,coalesce(sum(cnts),0) as total_cnts
 ,coalesce(sum(case when protect_tag = '应保护' then cnts end),0) as protect_cnts
 ,coalesce(sum(case when protect_tag = '普通' then cnts end),0) as normal_cnts
 ,coalesce(sum(case when protect_tag = '应离职' then cnts end),0) as Resignation_cnts
 ,coalesce(sum(case when protect_tag = '末位普通' then cnts end),0) as last_cnts
 ,coalesce(sum(case when protect_tag = '待观察' then cnts end),0) as observation_cnts
 ,coalesce(sum(case when protect_tag = '已离职' then cnts end),0) as Resigned_cnts
 from (
 select 
 dt
 ,store_code
 ,protect_tag
 ,count(distinct staff_code) as cnts
 from data_shop.dm_shop_staff_protect_tag_v2
 where dt >= '20220601' and store_code is not null
 group by dt
 ,store_code
 ,protect_tag
 ) tmp
 group by 
 dt
 ,store_code
) ttt
left join desensitization b on ttt.store_code = b.store_code
group by substr(dt,1,6),ttt.store_code,store_cvs_code,display_name

-------------------------------------------------------------------------

--店月维度的架构店经理天数占比
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

select 
 dt_month
 ,b.store_cvs_code
 ,b.display_name
 ,count(distinct dt) as open_days_cnt
 ,sum(has_manager) as has_manager_days_cnts
from (
 select
 distinct
 t1.store_code
 ,IF(LENGTH(store_manager_no)<8,CONCAT('10',store_manager_no),store_manager_no) AS manager_code
 ,case when t2.hps_d_jobcode = '店经理' and t2.hps_d_hr_status = '在职' then 1 else 0 end as has_manager
 ,t1.dt
 ,substr(t1.dt,1,6) as dt_month
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 left join data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw_view t2
 on t1.store_manager_no = t2.emplid 
 and t2.dt >= '20110101' 
 and t1.dt = t2.dt
 where t1.dt >= '20110101'
 and t1.store_type = 0
 and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
) tmp
left join desensitization b on tmp.store_code = b.store_code
group by dt_month,b.store_cvs_code,b.display_name

-------------------------------------------------------------------------

--店月维度的架构更换次数
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

select 
 dt_month
 ,b.store_cvs_code
 ,b.display_name
 ,sum(if_diff_manager) as change_cnts
from (
 select distinct 
 substr(t1.dt,1,6) as dt_month
 ,dt
 ,store_code
 ,case when store_manager_no = t1_store_manager_no or (t1_store_manager_no is null and store_manager_no is null) then 0 else 1 end as if_diff_manager
 from (
 select
 distinct
 t1.store_code
 ,t1.store_manager_no
 ,lag(t1.store_manager_no,1,null) over(partition by store_code order by t1.dt asc) as t1_store_manager_no
 ,t1.dt
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 where t1.dt >= '20220531'
 and t1.store_type = 0
 and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
 ) t1
) tmp
left join desensitization b on tmp.store_code = b.store_code
group by dt_month,b.store_cvs_code,b.display_name



--店三个月维度的架构更换次数
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

 month_list as
 (select
 trunc(date(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')),'MM') as month
 ,store_code
 from dw_ordering_store_tag_location_ranking_info_v1
 where dt >= '20170101'
 and store_type = 0
 and store_status = 1
 group by trunc(date(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')),'MM'),store_code),

 month_change_cnts as(
select 
 dt_month
 ,tmp.store_code
 ,b.store_cvs_code
 ,b.display_name
 ,sum(if_diff_manager) as change_cnts
from (
 select distinct 
 trunc(date(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')),'MM') as dt_month
 ,dt
 ,store_code
 ,case when store_manager_no = t1_store_manager_no or (t1_store_manager_no is null and store_manager_no is null) then 0 else 1 end as if_diff_manager
 from (
 select
 distinct
 t1.store_code
 ,t1.store_manager_no
 ,lag(t1.store_manager_no,1,null) over(partition by store_code order by t1.dt asc) as t1_store_manager_no
 ,t1.dt
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 where t1.dt >= '20170101'
 and t1.store_type = 0
 and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
 ) t1
) tmp
left join desensitization b on tmp.store_code = b.store_code
group by dt_month,tmp.store_code,b.store_cvs_code,b.display_name)

select
a.month
,b.store_cvs_code
,b.display_name
,sum(change_cnts)
from month_list a left join month_change_cnts b on a.store_code = b.store_code
and b.dt_month <= a.month and b.dt_month >= add_months(a.month,-2)
group by
a.month
,b.store_cvs_code
,b.display_name

--店六个月维度的架构更换次数
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

 month_list as
 (select
 trunc(date(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')),'MM') as month
 ,store_code
 from dw_ordering_store_tag_location_ranking_info_v1
 where dt >= '20170101'
 and store_type = 0
 and store_status = 1
 group by trunc(date(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')),'MM'),store_code),

 month_change_cnts as(
select 
 dt_month
 ,tmp.store_code
 ,b.store_cvs_code
 ,b.display_name
 ,sum(if_diff_manager) as change_cnts
from (
 select distinct 
 trunc(date(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')),'MM') as dt_month
 ,dt
 ,store_code
 ,case when store_manager_no = t1_store_manager_no or (t1_store_manager_no is null and store_manager_no is null) then 0 else 1 end as if_diff_manager
 from (
 select
 distinct
 t1.store_code
 ,t1.store_manager_no
 ,lag(t1.store_manager_no,1,null) over(partition by store_code order by t1.dt asc) as t1_store_manager_no
 ,t1.dt
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 where t1.dt >= '20170101'
 and t1.store_type = 0
 and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
 ) t1
) tmp
left join desensitization b on tmp.store_code = b.store_code
group by dt_month,tmp.store_code,b.store_cvs_code,b.display_name)

select
a.month
,b.store_cvs_code
,b.display_name
,sum(change_cnts)
from month_list a left join month_change_cnts b on a.store_code = b.store_code
and b.dt_month <= a.month and b.dt_month >= add_months(a.month,-5)
group by
a.month
,b.store_cvs_code
,b.display_name

-------------------------------------------------------------------------

SELECT root_code,
 count(1) as total_cnt,/*总面数-展示*/ 

 count(if(correct_0=1,1,null)) as qual_cnt_0, 
 count(if(chenlie_miss_higconfi_0=1,1,null)) as miss_higconfid_cnt_0, 
 count(if(chenlie_miss_lowconfi_0=1,1,null)) as miss_lowconfid_cnt_0, 
 count(if(stock_miss_0=1,1,null)) as stock_miss_cnt_0, 
 qual_cnt_0+miss_higconfid_cnt_0+miss_lowconfid_cnt_0+stock_miss_cnt_0 AS operation_cnt_0, 
 if(operation_cnt_0=0,NULL,qual_cnt_0/operation_cnt_0) AS qual_rate_0,

 count(if(correct_1=1,1,null)) as qual_cnt_1, 
 count(if(chenlie_miss_higconfi_1=1,1,null)) as miss_higconfid_cnt_1, 
 count(if(chenlie_miss_lowconfi_1=1,1,null)) as miss_lowconfid_cnt_1, 
 count(if(stock_miss_1=1,1,null)) as stock_miss_cnt_1, 
 qual_cnt_1+miss_higconfid_cnt_1+miss_lowconfid_cnt_1+stock_miss_cnt_1 AS operation_cnt_1, 
 if(operation_cnt_1=0,NULL,qual_cnt_1/operation_cnt_1) AS qual_rate_1,

 count(if(correct_2=1,1,null)) as qual_cnt_2, 
 count(if(chenlie_miss_higconfi_2=1,1,null)) as miss_higconfid_cnt_2, 
 count(if(chenlie_miss_lowconfi_2=1,1,null)) as miss_lowconfid_cnt_2,
 count(if(stock_miss_2=1,1,null)) as stock_miss_cnt_2, 
 qual_cnt_2+miss_higconfid_cnt_2+miss_lowconfid_cnt_2+stock_miss_cnt_2 AS operation_cnt_2, 
 if(operation_cnt_2=0,NULL,qual_cnt_2/operation_cnt_2) AS qual_rate_2,

 count(if(correct_3=1,1,null)) as qual_cnt_3, 
 count(if(chenlie_miss_higconfi_3=1,1,null)) as miss_higconfid_cnt_3, 
 count(if(chenlie_miss_lowconfi_3=1,1,null)) as miss_lowconfid_cnt_3, 
 count(if(stock_miss_3=1,1,null)) as stock_miss_cnt_3, 
 qual_cnt_3+miss_higconfid_cnt_3+miss_lowconfid_cnt_3 AS operation_cnt_3, 
 if(operation_cnt_3=0,NULL,qual_cnt_3/operation_cnt_3) AS qual_rate_3


 FROM dt_materialized_chenlie_sku_detail_all 
 WHERE 1=1 
 AND statistic_date = toDate(yesterday()) 
 and statistic_date>=toDate(yesterday()) 
 AND toInt64(shelfid)>0 
 group by root_code

-------------------------------------------------------------------------

--惩处数据
--惩处这一块，有一段代码我发出来。
--用到的表 data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 是过去90天惩处下发的表，一行一条惩处，惩处项punish_item，对应门店 shop_code，下发日期1st_create_time
select distinct
 previous_order_id as order_id
 ,date_format(1st_create_date,'yyyy-MM-dd') as 1st_create_time
 ,chain_status as order_status
 ,case
 when locate('#', regexp_replace(1st_item_id,'[0-9]','#')) > 0
 then 1st_flow_name else 1st_item_id end as punish_item
 ,case when length(1st_shop_code)>9 then regexp_extract(1st_shop_code,'(.*)(: )(.*)',3)
 else 1st_shop_code end as shop_code
 ,1st_shop_name as shop_name
 ,null as event_date
 ,coalesce(3rd_final_user_name,2nd_final_user_name,1st_final_user_name) as staff_name
 ,if(length(coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code))<8
 ,concat('10',coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code))
 ,coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code)) as final_code
 ,coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code) as emplid
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type
 ,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then '工时数量扣减' else '工时费用扣减' end as punish_type
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type,1st_final_feedback_type
 ,1st_feedback_type)= '工时数量扣减'
 then 20*cast(coalesce(1st_final_feedback_result_value,1st_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,3rd_final_feedback_result_value,0) as double)
 else cast(coalesce(
 1st_final_feedback_result_value,1st_feedback_result_value,2nd_final_feedback_result_value
 ,2nd_feedback_result_value,3rd_final_feedback_result_value,0) as double) end as punish_money_value
 ,cast(coalesce(
 1st_final_feedback_result_value,1st_feedback_result_value,2nd_final_feedback_result_value
 ,2nd_feedback_result_value,3rd_final_feedback_result_value,0) as double) as punish_value
 from data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 t1
 where dt = '${DATE}'
 
-------------------------------------------------------------------------

SELECT root_code,
 count(1) as total_cnt,/*总面数-展示*/ 

 count(if(correct_0=1,1,null)) as qual_cnt_0, 
 count(if(chenlie_miss_higconfi_0=1,1,null)) as miss_higconfid_cnt_0, 
 count(if(chenlie_miss_lowconfi_0=1,1,null)) as miss_lowconfid_cnt_0, 
 count(if(stock_miss_0=1,1,null)) as stock_miss_cnt_0, 
 qual_cnt_0+miss_higconfid_cnt_0+miss_lowconfid_cnt_0+stock_miss_cnt_0 AS operation_cnt_0, 
 if(operation_cnt_0=0,NULL,qual_cnt_0/operation_cnt_0) AS qual_rate_0,

 count(if(correct_1=1,1,null)) as qual_cnt_1, 
 count(if(chenlie_miss_higconfi_1=1,1,null)) as miss_higconfid_cnt_1, 
 count(if(chenlie_miss_lowconfi_1=1,1,null)) as miss_lowconfid_cnt_1, 
 count(if(stock_miss_1=1,1,null)) as stock_miss_cnt_1, 
 qual_cnt_1+miss_higconfid_cnt_1+miss_lowconfid_cnt_1+stock_miss_cnt_1 AS operation_cnt_1, 
 if(operation_cnt_1=0,NULL,qual_cnt_1/operation_cnt_1) AS qual_rate_1,

 count(if(correct_2=1,1,null)) as qual_cnt_2, 
 count(if(chenlie_miss_higconfi_2=1,1,null)) as miss_higconfid_cnt_2, 
 count(if(chenlie_miss_lowconfi_2=1,1,null)) as miss_lowconfid_cnt_2,
 count(if(stock_miss_2=1,1,null)) as stock_miss_cnt_2, 
 qual_cnt_2+miss_higconfid_cnt_2+miss_lowconfid_cnt_2+stock_miss_cnt_2 AS operation_cnt_2, 
 if(operation_cnt_2=0,NULL,qual_cnt_2/operation_cnt_2) AS qual_rate_2,

 count(if(correct_3=1,1,null)) as qual_cnt_3, 
 count(if(chenlie_miss_higconfi_3=1,1,null)) as miss_higconfid_cnt_3, 
 count(if(chenlie_miss_lowconfi_3=1,1,null)) as miss_lowconfid_cnt_3, 
 count(if(stock_miss_3=1,1,null)) as stock_miss_cnt_3, 
 qual_cnt_3+miss_higconfid_cnt_3+miss_lowconfid_cnt_3 AS operation_cnt_3, 
 if(operation_cnt_3=0,NULL,qual_cnt_3/operation_cnt_3) AS qual_rate_3


 FROM dt_materialized_chenlie_sku_detail_all 
 WHERE 1=1 
 AND statistic_date = toDate(yesterday()) 
 and statistic_date>=toDate(yesterday()) 
 AND toInt64(shelfid)>0 
 group by root_code
 
-------------------------------------------------------------------------

--6~8月by店满编率
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name)

select
b.store_cvs_code
,b.display_name
,sum(fte_all) as fte_all
,sum(hc_all) as hc_all
,sum(fte_all)/sum(hc_all)*1.0000
from data_build.dwd_store_construction_store_groups_recruit_gap a
left join desensitization b on a.store_code = b.store_code
where dt between '20220601' and '20220831'
group by
b.store_cvs_code
,b.display_name

-------------------------------------------------------------------------

--进店客流数据可用状态。计算交易转化率，只考虑 状态2和3
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
group by
store_code,
store_name,
store_cvs_code,
display_name),

confidence as(
select 
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,store_code
,store_status
from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view t
where dt >= date_format(date_sub(current_date(),365),'yyyyMMdd')
and store_status in ('0','1','2','3') --3可用, 2低置信可用, 1不可用, 0初始状态
)

--店外客流 进店客流
select 
c.store_cvs_code as shop_id
,c.display_name
,trunc(event_date,'MM') as month
,time_hour
,count(distinct event_date) as event_date_num
,sum(come_customer_num)/count(distinct event_date) as come_customer_num
,sum(go_customer_num)/count(distinct event_date) as  go_customer_num--进店客流
,sum(outside_flow_cnt_in)/count(distinct event_date) as outside_flow_cnt_in
,sum(outside_flow_cnt_out)/count(distinct event_date) as outside_flow_cnt_out --店外客流
from data_smartorder.dm_ordering_report_store_change_info_di a
left join confidence b on a.store_code = b.store_code and a.event_date = b.record_date
left join desensitization c on a.store_code = c.store_code
where dt >= date_format(date_sub(current_date(),365),'yyyyMMdd')
and b.store_status in (2,3)
and store_cvs_code in ('100001153','101000112')
and cast(go_customer_num as int) > 0
and cast(outside_flow_cnt_out as int) > 0
and cast(outside_flow_cnt_out as int) > cast(go_customer_num as int)
and event_date between '2017-08-01' and '2022-12-31'
group by c.store_cvs_code
,c.display_name
,trunc(event_date,'MM')
,time_hour
-------------------------------------------------------------------------

--门店空窗/断档
--10/22空窗时长
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name)

SELECT
trunc(a.record_date,'MM') as month,
b.store_cvs_code,
b.display_name,
sum(nobody_duration)
from data_smartorder.app_roster_report_last_30days_empty_store_list_di a
left join desensitization b on a.store_code = b.store_code
where dt = '20221031'
and a.type = '空窗'
group by
trunc(a.record_date,'MM'),
b.store_cvs_code,
b.display_name

----------------------------------------------------------------------------------------------------------------------------------------------------------

--进店客流数据可用状态。计算交易转化率，只考虑 状态2和3，区分周中/周末
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
group by
store_code,
store_name,
store_cvs_code,
display_name),

confidence as(
select 
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,store_code
,store_status
from data_smartorder.dm_copy_dm_promotion_store_detl_passenger_flow_store_status_di_view t
where dt >= date_format(date_sub(current_date(),365),'yyyyMMdd')
and store_status in ('0','1','2','3') --3可用, 2低置信可用, 1不可用, 0初始状态
),

date_list as(
select
date_key,
case when day_of_week_name in ('星期一','星期二','星期三','星期四','星期五') then '周中' else '周末' end as date_type
from default.dim_date_ya_v2
)

--店外客流 进店客流
select 
c.store_cvs_code as shop_id
,c.display_name
,date_add(a.event_date,7 - case when dayofweek(a.event_date) = 1 then 7 else dayofweek(a.event_date) - 1 end) as week
,date_type
,count(distinct event_date) as event_date_num
,sum(come_customer_num)/count(distinct event_date) as come_customer_num
,sum(go_customer_num)/count(distinct event_date) as  go_customer_num--进店客流
,sum(outside_flow_cnt_in)/count(distinct event_date) as outside_flow_cnt_in
,sum(outside_flow_cnt_out)/count(distinct event_date) as outside_flow_cnt_out --店外客流
from data_smartorder.dm_ordering_report_store_change_info_di a
left join confidence b on a.store_code = b.store_code and a.event_date = b.record_date
left join desensitization c on a.store_code = c.store_code
left join date_list d on a.event_date = d.date_key
where dt >= date_format(date_sub(current_date(),365),'yyyyMMdd')
and b.store_status in (2,3)
--and store_cvs_code = '110000210'
--and cast(go_customer_num as int) > 0
--and cast(outside_flow_cnt_out as int) > 0
--and cast(outside_flow_cnt_out as int) > cast(go_customer_num as int)
and event_date between '2021-08-01' and '2021-08-31'
group by c.store_cvs_code
,c.display_name
,trunc(event_date,'MM')
,date_type