--dwd_shop_sec_manager_transfer_wage_match_di
--门店-架构调拨薪资测算
with staff_list as 
(
select 
    *
    ,dt as suggest_dt
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view 
where dt >= '20230801'
and hps_d_hr_status = '在职'
and hps_d_jobcode = '店副经理'
)


,structure_lack_detail_0 as 
(
    select t1.store_code 
    ,t1.city_name
    ,t1.store_name
    ,t1.dt as suggest_dt 
,case when t2.emplid is not null then 1 else 0 end as is_sec_manager
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join staff_list t2 on t1.store_code = t2.hps_dept_code_lv5 and t1.dt = t2.suggest_dt  and t2.hps_d_jobcode = '店副经理'
where t1.dt >= '20230801'
)
,structure_lack_detail as 
(
    select *,
    '店副缺编' as structure_status_desc
from structure_lack_detail_0 
where is_sec_manager = 0
)


,protect_detail as 
(
select
 staff_code
,position_class
,position_cn
,protect_tag_detail
,protect_tag
,hours
,from_unixtime(unix_timestamp(entry_date,'yyyymmdd'),'yyyy-mm-dd') as entry_date 
,case when protect_tag in ('应离职','末位普通') then 1
--when student_suspect = 1 then 1
 when position_cn = '学生PT' then 1
else 0 end as is_di
,dt as record_date
from data_shop.dm_shop_staff_protect_tag_v2
where dt >= '20230801'
  )

,manager_list as
 (
 select
 if(length(store_manager_no)=6,concat('10',store_manager_no),store_manager_no) as store_manager_no
,dt as record_date
,store_code
 from data_build.dw_ordering_store_tag_location_ranking_info_v1_view
where dt >= '20230801'
and store_status_desc = '营业'
)

,staff_detail as 
(
select 
distinct
t1.employee_id_original as staff_code 
,t1.employee_id as emplid
,t1.store_code 
,t1.cn_name
,t2.position_cn 
,t2.position_class
,t2.protect_tag_detail
,t2.protect_tag 
,t2.entry_date 
,t2.hours as hours
,datediff(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),t2.entry_date) as on_job_days 
,t2.is_di 
,t1.geiban_label
,case when t1.is_manager = 1 then 1 
when t6.store_manager_no is not null then 1 
else 0 end as is_manager
,t1.available_days
,t1.is_leave_21
,t1.dt as record_date
,case when t1.is_manager = 1 then 0 
when t2.position_cn = '店副经理' then 1 
--when t1.chuqin_label = '长夜型员工' and t2.protect_tag_detail <=2 and datediff(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),t2.entry_date) >=30 and t2.is_di = 0 and t1.available_days >=3 then 1 
else 0 end as is_sec_manager 
,t1.chuqin_label
,split(t3.hps_hrbp_idnames,'-')[0] as hrbp_code
,split(t3.hps_hrbp_idnames,'-')[1] as hrbp_name
from data_build.dwd_store_construction_roster_staff_supply_v1_di t1
left join protect_detail t2 on t1.employee_id = t2.staff_code and t1.dt = t2.record_date
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on t1.employee_id = IF(LENGTH(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt = ${today-1}
left join manager_list t6 on t1.employee_id = t6.store_manager_no and t1.dt = t6.record_date and t1.store_code = t6.store_code 
where t1.dt >= '20230801'
)

,base_info as (
select 
distinct 
t2.staff_code as staff_code 
,t2.emplid as emplid 
,t2.cn_name as staff_name 
,t2.position_cn as hps_d_jobcode 
,t2.hrbp_code
,t2.hrbp_name
,t1.city_name
,t2.store_code as from_store_code 
,t5.store_name as from_store_name
 ,t5.store_mgr_code as from_store_mgr_code
 ,t5.bz_mgr_name as from_bz_mgr_name
 ,t5.city_zone_mgr_name as from_city_zone_mgr_name
,t1.store_code  as to_store_code 
,t4.store_name as to_store_name
 ,t4.store_mgr_code as to_store_mgr_code
 ,t4.bz_mgr_name as to_bz_mgr_name
 ,t4.city_zone_mgr_name as to_city_zone_mgr_name
,'N1' as transfer_plan
,t1.suggest_dt as suggest_dt
,t1.structure_status_desc as lack_type
,t2.position_class as position_class
,t2.protect_tag_detail as protect_tag_detail
,t2.protect_tag as protect_tag
,t2.entry_date as entry_date
,t2.available_days as available_days
,t2.geiban_label as geiban_lebel 
,t2.chuqin_label as chuqin_label
,t2.hours  as all_hours 
,t3.distince as store_distance
,t6.store_address as to_store_address
from structure_lack_detail t1  
left join data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t3 on t1.store_code = t3.a_store_code and t3.distince <= 10000
--and t3.distince >1 --0306调整，允许本店符合条件的店员晋升店副
and t3.dt=${today-1}
left join staff_detail t2 on t3.b_store_code = t2.store_code and t2.protect_tag_detail in (0,1,2) and t2.is_manager = 0 and t2.is_sec_manager = 0 and t2.on_job_days >=10
and t2.available_days>= 4 and t2.is_di = 0
and t2.geiban_label in ('长夜型员工','全天型员工')
and t2.is_leave_21 = 0 and t2.hours >=100 and t1.suggest_dt = t2.record_date
left join data_shop.dwd_shop_store_jiagou_di t4 on t1.store_code = t4.store_code and t4.dt = ${today-1}
left join data_shop.dwd_shop_store_jiagou_di t5 on t2.store_code = t5.store_code and t5.dt = ${today-1}
left join  data_build.dim_store_info t6 on t1.store_code = t6.store_code and t6.dt =  ${today-1}

where t3.a_store_city = t3.b_store_city 
and t2.staff_code is not null 
)


,attend_info as (
    select 
        IF(LENGTH(t1.employee_no)<8,concat('10',t1.employee_no),t1.employee_no) as staff_code
        ,sum(coalesce(attendance_work_hours,0)) as t30_attendance_work_hours
    from data_build.pdw_opc_shop_attendance_report_work_shift_view t1
    where t1.dt = ${today-1}
        and t1.work_shift_type in (1,9,12)
        and date_format(t1.work_shift_date,'yyyyMMdd') >=${today-30}
    group by 
        t1.employee_no
)

,30days_sales as
 ( 
select
store_code
 --计算日均销售额，剔除450以上大单，剔除2000以下店日 结果可能为null
,avg(case when payable_price_lessthan_450_for_roster >= 1000 then payable_price_lessthan_450_for_roster else null end) as avg_amount_30days
from data_smartorder.dm_ordering_suggestion_reference_data_store_amt_for_roster_da t
 where dt = ${today-1}
 and sale_date >= date_sub(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),30)
and store_type = 0
and order_cnt_store >= 20 --正常营业店日
and holiday_type in (1,2) --剔除节假日
group by store_code
 )


,sec_maneger_result as 
(
    select 
    t1.staff_code
    ,t1.emplid
    ,t1.staff_name
    ,t1.city_name
    ,t1.suggest_dt
    ,t1.hps_d_jobcode
    ,t1.hrbp_code
    ,t1.hrbp_name
    ,t1.from_store_code 
    ,t1.from_store_name 
    ,t1.from_store_mgr_code
    ,t1.from_bz_mgr_name
    ,t1.from_city_zone_mgr_name
    ,t1.to_store_code
    ,t1.to_store_name
    ,t1.to_store_mgr_code
    ,t1.to_bz_mgr_name
    ,t1.to_city_zone_mgr_name
    ,t1.transfer_plan
    ,t1.store_distance 
    ,coalesce(t4.sep_hours,0)       as actual_hours         --实际工时
    ,coalesce(t4.sep_base,0)        as actual_base          --实际底薪
    ,299 as after_hours --预计工时
    ,case when coalesce(t4.sep_hours,0) >=299 then 0 else 299-coalesce(t4.sep_hours,0) end  as hours_diff           --接店后工时上涨
    ,t2.sale_level*0.0003*26*11.5   as sec_manager_bonus  --店副奖金
    ,312 as night_allowance --夜班补贴
    ,t9.t30_attendance_work_hours as t30_attendance_work_hours --t30工时
    ,t10.avg_amount_30days --过去30天日商
    ,row_number()over(partition by concat(t1.staff_code,t1.suggest_dt) order by t10.avg_amount_30days desc) as rn --0306调整，需要合并推荐日期后再排序，避免历史推荐门店日商高，现在门店无法排进前五
    ,t1.to_store_address as to_store_address

    from base_info t1
left join data_build.dwd_store_construction_roster_store_demand_v1_di t2 on t1.to_store_code = t2.store_id and t2.dt = ${today-1}
left join data_shop.ods_uploads_sal_index t3
on t1.city_name = t3.city_name
left join data_shop.ods_uploads_sep_sal t4
on t1.staff_code = t4.staff_code
left join data_shop.ods_uploads_sep_store_man_bonus t5
on t1.to_store_code = t5.store_code
left join data_shop.ods_uploads_nov_hour t6
on t1.to_store_code = t6.store_code
left join attend_info t9
on t1.staff_code = t9.staff_code 
left join 30days_sales t10 on t1.to_store_code = t10.store_code 
--left join data_shop.dwd_manager_transfer_blacklist_v1_di t11 on t1.staff_code = t11.staff_code 
--and t11.dt = '${today-2}'
--where t11.staff_code is null --0306调整，容许晋升黑名单的人晋升店副
)

,sec_manager_suggest_list as(
select 
if(length(t1.staff_code) = 8 and substr(t1.staff_code,0,2) = '10',substr(t1.staff_code,3,8),t1.staff_code) as staff_code
    ,t1.emplid
    ,t1.staff_name
    ,t1.city_name
    ,t1.suggest_dt
    ,t1.hps_d_jobcode
    ,t1.hrbp_code
    ,t1.hrbp_name
    ,t1.from_store_code 
    ,t1.from_store_name 
    ,t1.from_store_mgr_code
    ,t1.from_bz_mgr_name
    ,t1.from_city_zone_mgr_name
    ,t1.to_store_code
    ,t1.to_store_name
    ,t1.to_store_mgr_code
    ,t1.to_bz_mgr_name
    ,t1.to_city_zone_mgr_name
    ,t1.transfer_plan
    ,t1.store_distance 
    ,t1.actual_hours         --实际工时
    ,t1.actual_base          --实际底薪
    ,t1.after_hours --预计工时
    ,t1.hours_diff           --接店后工时上涨
    ,t1.sec_manager_bonus  --店副奖金
    ,t1.night_allowance --夜班补贴
    ,t1.t30_attendance_work_hours --t30工时
    ,t1.avg_amount_30days --过去30天日商
    ,t1.to_store_address
    ,t1.rn
    from sec_maneger_result t1
    --where t1.rn <= 5 --0320调整，先选出所有符合要求的门店，再判断哪些门店
)

,raw_list as(
select
t0.staff_code
,t0.emplid	
,t0.staff_name	
,t0.city_name	
,t0.suggest_dt	
,t0.hps_d_jobcode	
,t0.hrbp_code	
,t0.from_store_code	
,t0.from_store_name	
,t0.from_store_mgr_code	
,t0.from_bz_mgr_name	
,t0.from_city_zone_mgr_name	
,t0.to_store_code	
,t0.to_store_name	
,t0.to_store_mgr_code	
,t0.to_bz_mgr_name	
,t0.to_city_zone_mgr_name	
,t0.transfer_plan	
,t0.store_distance	
,t0.actual_hours	
,t0.actual_base	
,t0.after_hours	
,t0.hours_diff	
,t0.sec_manager_bonus	
,t0.night_allowance	
,t0.t30_attendance_work_hours
,t0.avg_amount_30days	
,t0.to_store_address
,t0.rn
,case when from_store_code = to_store_code then '1' else '0' end as is_self_store
from sec_manager_suggest_list t0
)

,main_list as( --历史流程统计
SELECT * 
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '032042' --晋升店副意愿沟通
)

,result_list as(
select
substr(t1.create_time,1,10) as compute_period --流程发起日期
,t1.order_id --流程编码
,t1.order_status --流程状态
,t1.flow_ame --流程名称
,SUBSTRING(
    t1.flow_ame, 
    LOCATE('(', t1.flow_ame) + 1, 
    LOCATE(')', t1.flow_ame) - LOCATE('(', t1.flow_ame) - 1
  ) AS staff_code --员工编码
,t1.create_time --创建时间
,t2.form_values
,nvl(get_json_object(t2.form_values,'$[0].label'),'未处理') as result --意愿
from main_list t1
left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t2
on t1.order_id = t2.order_id
and t2.dt = '${today-1}'
and t2.form_name = 'accept'
)

,refuse_num as( --拒绝晋升次数统计
select
staff_code
,count(case when compute_period >= date_sub(current_date(),30) then staff_code else null end) as refuse_num_30 --t30拒绝次数
,count(case when compute_period >= date_sub(current_date(),180) then staff_code else null end) as refuse_num_180 --t180拒绝次数
from result_list
where result <> '愿意接受'
group by
staff_code
)

,ranked_data as(
select
t1.*
,case when t1.is_self_store = '1' then '0' else row_number()over(partition by concat(t1.staff_code,t1.suggest_dt) order by t1.avg_amount_30days desc) end as rn_1 --本店优先排在0号
from raw_list t1
left join refuse_num t2 on t1.staff_code = lpad(t2.staff_code,8,10)
where (t2.refuse_num_30 < 3 and t2.refuse_num_30 < 5)
or t2.staff_code is null
)

select
staff_code
,if(substr(staff_code,1,2) = '10' , substr(staff_code,3,6) , staff_code) as emplid
,staff_name
,city_name
,suggest_dt
,hps_d_jobcode
,hrbp_code
,from_store_code
,from_store_name
,from_store_mgr_code
,from_bz_mgr_name
,from_city_zone_mgr_name
,to_store_code
,to_store_name
,to_store_mgr_code
,to_bz_mgr_name
,to_city_zone_mgr_name
,transfer_plan
,store_distance
,actual_hours
,actual_base
,after_hours
,hours_diff
,sec_manager_bonus
,night_allowance
,t30_attendance_work_hours
,to_store_address
from ranked_data
where rn_1 <= 5 --取日商前五的门店

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
******************************************************************************************************************************************************************************************
******************************************************************************************************************************************************************************************
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--店副晋升黑名单
--data_shop.dwd_vice_manager_transfer_blacklist_v1_da
begin
    with leave_tag as (
    select
    IF(LENGTH(t1.emplid)<8,CONCAT('10',t1.emplid),t1.emplid) as emplid
    ,t1.hps_d_jobcode as position_cn
    ,t1.hps_d_hr_status
    ,t1.leave_dt
    ,t2.protect_tag
    ,t2.dt 
    ,row_number() over(partition by t1.emplid order by t2.dt desc) rn
    ,t1.emplid as original_emplid --0314updated
    from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    left join data_shop.dm_shop_staff_protect_tag_v2 t2
    on IF(LENGTH(t1.emplid)<8,CONCAT('10',t1.emplid),t1.emplid) = t2.staff_code 
    and t2.dt <= date_format(date_sub(leave_dt,1) ,'yyyyMMdd') 
    and t2.dt >= date_format(date_sub(leave_dt,7) ,'yyyyMMdd') 
    and t2.dt <= '${today-1}'

    where t1.dt <='${today-1}'
    and t1.hps_d_hr_status = '离职'
    -- and t1.store_type = 0
    -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
    ),

    id_list as(
    select
    IF(LENGTH(emplid)<8,CONCAT('10',emplid),emplid) as emplid_ten
    ,emplid as emplid_eight
    from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt <= '${today-1}'
    group by
    IF(LENGTH(emplid)<8,CONCAT('10',emplid),emplid)
    ,emplid
    )

    ,leave_tag_final as (
    select 
    emplid
    ,leave_dt
    ,protect_tag
    ,case when protect_tag in ('末位普通','应离职') then 1 else 0 end as is_di_leave 
    from leave_tag
    where rn = 1
    )

    ,should_leave_list as (
    select 
    staff_code
    ,protect_tag
    ,protect_tag_detail
    from data_shop.ods_uploads_protect_tag_0419
    where protect_tag_detail = '5'
    )

    ,order_flow_main as( --店副晋升意愿统计
    select
    order_id
    ,lpad(SUBSTRING_INDEX(SUBSTRING_INDEX(flow_ame, '(', -1), ')', 1),8,'10') as staff_code
    ,SUBSTRING(flow_ame, LENGTH(flow_ame) - 7, 8) as record_date
    ,create_time
    ,order_status
    from data_build.pdw_order_store_211_order_detail_flow_main
    where dt = '${today-1}'
    and flow_code = '032042' --流程code
    and TO_DATE(create_time) >= '2025-03-21' --从3月21号起开始统计拒绝次数
    )

    ,promotion_wish_result as(
    SELECT
    t0.order_id
    ,t0.staff_code
    ,t0.record_date
    ,t0.create_time
    ,t0.order_status
    ,case when t1.form_name = 'toStoreCode' then get_json_object(get_json_object(t1.form_values,'$.[0]'),'$.value') else null end as toStoreCode
    ,case when t2.accept = '1' then '接受' when t2.accept = '0' then '拒绝' else t2.accept end as accept
    ,t2.reason
    ,t2.shopCode
    ,row_number() over(partition by concat(t0.staff_code,case when t1.form_name = 'toStoreCode' then get_json_object(get_json_object(t1.form_values,'$.[0]'),'$.value') else null end) order by t0.create_time desc) as rm
    --人*店维度按照接收晋升意愿时间降序排序
    from order_flow_main t0
    left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t1 on t0.order_id = t1.order_id
    and t1.dt = '${today-1}'
    and t1.form_name in ('toStoreCode') 
    left join(
    select
    order_id
    ,max(case when form_name = 'accept' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as accept
    ,max(case when form_name = 'refuseReasonType' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as reason
    ,max(case when form_name = 'shopCode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as shopCode
    from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
    where dt = '${today-1}'
    and form_name in ('accept','refuseReasonType','shopCode')
    group by
    order_id
    ) t2 on t1.order_id = t2.order_id
    )

    ,refuse_list as(
    select
    distinct
    staff_code
    ,TO_DATE(create_time) as refuse_date
    from promotion_wish_result
    where accept = '拒绝'
    and order_status = 'FINISHED'
    )

    ,refuse_raw as(
    select
    staff_code
    ,refuse_date
    ,LAG(refuse_date, 2) OVER (PARTITION BY staff_code ORDER BY refuse_date ASC) AS prev_prev_date
    ,LAG(refuse_date, 4) OVER (PARTITION BY staff_code ORDER BY refuse_date ASC) AS prev_prev_prev_prevdate
    from refuse_list
    order by 
    staff_code
    ,refuse_date
    limit 10000000
    )

    ,refuse_data as(
    select
    staff_code
    ,refuse_date
    ,prev_prev_date
    ,prev_prev_prev_prevdate
    ,datediff(refuse_date,prev_prev_date) as three_refuse_date --三次拒绝间隔
    ,datediff(refuse_date,prev_prev_prev_prevdate) as five_refuse_date --五次拒绝间隔
    from refuse_raw
    )

    select 
    lpad(t1.emplid,8,'10') as staff_code --0314updated
    ,hps_dept_code_lv5 as store_code
    ,'离职前低意愿' as reason
    from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1 
    left join leave_tag_final t2 on IF(LENGTH(t1.emplid)<8,CONCAT('10',t1.emplid),t1.emplid) = t2.emplid 
    where t1.dt = '${today-1}' and t1.hps_d_hr_status = '在职' and t2.is_di_leave = 1

    union 

    select 
    t2.emplid_ten as staff_code --0314updated
    ,null as store_code 
    ,'应离职标签' as reason 
    from should_leave_list t4
    inner join id_list t2 on t4.staff_code = t2.emplid_ten --0314updated

    union

    select
    distinct
    staff_code
    ,null as store_code
    ,'半年内三次拒绝' as reason
    from refuse_data
    where three_refuse_date <= '180'

    union

    select
    distinct
    staff_code
    ,null as store_code
    ,'一年内五次拒绝' as reason
    from refuse_data
    where five_refuse_date <= '365'
end