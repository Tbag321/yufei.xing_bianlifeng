#
# --------------------------------------
# DATE: 2022-12-21
# TABLE: data_shop.dwd_shop_staff_transfer_wage_match_di
# DEV:  hanzhi.cao
# DESC: 门店-架构调拨薪资测算
# --------------------------------------


###参数设置：日期参数，表名，唯一键
source ${ETC}/format_date.cnf
TABLE_NAME="data_shop.dwd_shop_staff_transfer_wage_match_di"
UNIQ_KEY="staff_code,suggest_dt,from_store_code,to_store_code"

###JOB入口函数：计算，校验
function dwd_shop_staff_transfer_wage_match_di_run {
     calculate
}


##计算模块
function calculate {
$HIVE << EOF

${HIVE_SETTINGS};

with L4_base_info as (
    select 
        t1.*
        ,row_number() over(partition by t1.store_code order by t1.dt desc) rn
    from data_shop.app_shop_structure_lack_details_di t1
    where dt >= '${today-2}'
)

,finished_info as (
    select
        t1.*
        ,case 
            when t0.current_manager_code is not null and t0.current_manager_code <> t1.store_mgr_code then '退出缺编-换架构' 
            when t0.store_status = 3 then '退出缺编-退出监控' else '退出缺编-同架构' end as change_tag
    from L4_base_info t1
    left join data_shop.dwa_shop_store_structure_condition_di t0
    on t0.dt = '${today-1}' and t1.store_code = t0.store_code
    where t1.rn = 1 and t1.dt = '${today-2}'
)

,structure_lack_detail_1 as 
(
select 
    t1.valid_date --as `缺编日期`
    ,t1.store_code --as `门店编号`
    ,t1.store_name --as `门店名称`
    ,t1.city_name --as `城市`
    ,t1.store_level-- as `重点门店`
    ,t1.store_mgr_code --as `架构店长工号`
    ,t1.store_mgr_name --as `架构店长姓名`
    ,t1.bz_mgr_code --as `战区工号`
    ,t1.bz_mgr_name --as `战区姓名`
    ,t1.city_mgr_code-- as `城市总工号`
    ,t1.city_mgr_name --as `城市总姓名`
    ,t1.structure_status_desc --as `缺编类型`
    ,t1.is_active_leaving --as `是否主动提离职`
    ,t1.leaving_order_status --as `离职流程状态`
    ,t1.leaving_apply_date --as `主动发起离职日期`
    ,t1.leaving_last_date --as `lastday日期`
    ,t1.t60_active_apply_times --as `近60天内主动提交离职次数`
    ,t1.store_mgr_level --as `店长评价等级`
    ,t1.protect_tag as protect_tag --as `金银牌`
    ,t3.protect_tag as staff_protect_tag--as `店员开工表现`
    ,t1.punish_rate_per_100_hour --as `百工时违规`
    ,t1.store_priority_level --as `门店Q等级`
    ,t1.f14_available_days --as `未来14天可用天数`
    ,t1.f14_give_hours --as `未来14天给班小时`
    ,t1.f14_valid_give_days --as `未来14天有效给班天数`
    ,t1.f14_black_list_days --as `未来14天黑名单天数`
    ,t1.f14_health_cer_invalid_days --as `未来14天健康证到期天数`
    ,t1.f14_dimision_affect_hours --as `未来14天离职流程影响小时数`
    ,t1.f14_vac_hours --as `未来14天请假小时数`
    ,t1.t30_lack_days --as `近30天连续缺编天数`
    ,case when t1.store_code = '110000059' and t1.store_mgr_code = '11134704' then if(t1.t30_lack_days = 1,'新增-三期员工','保持-三期员工')
        when t1.t30_lack_days = 1 then '新增' else '保持' end as dangqianzhuangtai
    ,t1.difficulty_level --as `门店难度等级`
    ,t1.is_sal_tough_store --as `是否薪资困难店`
    ,t1.store_reserve --as `本店储备店长情况`
    ,t1.store_reserve_5km --as `5km储备店长情况`
    ,t1.has_social_insur --as `是否有社保`
    ,t1.store_difficulty_desc --as `门店难度`
    ,t1.store_capacity_desc --as `门店人力情况`
    ,t1.store_op_quality --as `门店质量`
    ,t1.store_status_level-- as `门店综合等级`
    ,t1.special_mark --as `特殊备注`
    ,t0.store_status_desc --as `门店营业状态`
from data_shop.app_shop_structure_lack_details_di t1
left join data_shop.dwa_shop_store_structure_condition_di t0 on t0.dt = '${today-1}' and t1.store_code = t0.store_code
left join data_shop.dm_shop_staff_protect_tag_v2 t3 on t1.store_mgr_code = t3.staff_code  and t3.dt = '${today-1}'

where t1.dt = '${today-1}'
and  t1.store_code <> '100000238'


UNION ALL

select 
    t1.valid_date --as `缺编日期`
    ,t1.store_code --as `门店编号`
    ,t1.store_name --as `门店名称`
    ,t1.city_name --as `城市`
    ,t1.store_level --as `重点门店`
    ,t1.store_mgr_code --as `架构店长工号`
    ,t1.store_mgr_name --as `架构店长姓名`
    ,t1.bz_mgr_code --as `战区工号`
    ,t1.bz_mgr_name --as `战区姓名`
    ,t1.city_mgr_code --as `城市总工号`
    ,t1.city_mgr_name --as `城市总姓名`
    ,t1.structure_status_desc --as `缺编类型`
    ,t1.is_active_leaving --as `是否主动提离职`
    ,t1.leaving_order_status --as `离职流程状态`
    ,t1.leaving_apply_date -- as `主动发起离职日期`
    ,t1.leaving_last_date --as `lastday日期`
    ,t1.t60_active_apply_times --as `近60天内主动提交离职次数`
    ,t1.store_mgr_level --as `店长评价等级`
    ,t1.protect_tag as protect_tag --as `金银牌`
    ,t3.protect_tag as staff_protect_tag--as `店员开工表现`
    ,t1.punish_rate_per_100_hour --as `百工时违规`
    ,t1.store_priority_level --as `门店Q等级`
    ,t1.f14_available_days --as `未来14天可用天数`
    ,t1.f14_give_hours --as `未来14天给班小时`
    ,t1.f14_valid_give_days --as `未来14天有效给班天数`
    ,t1.f14_black_list_days --as `未来14天黑名单天数`
    ,t1.f14_health_cer_invalid_days --as `未来14天健康证到期天数`
    ,t1.f14_dimision_affect_hours --as `未来14天离职流程影响小时数`
    ,t1.f14_vac_hours --as `未来14天请假小时数`
    ,t1.t30_lack_days --as `近30天连续缺编天数`
    ,change_tag  as dangqianzhuangtai--as `当前状态`
    ,t1.difficulty_level --as `门店难度等级`
    ,t1.is_sal_tough_store --as `是否薪资困难店`
    ,t1.store_reserve --as `本店储备店长情况`
    ,t1.store_reserve_5km --as `5km储备店长情况`
    ,t1.has_social_insur --as `是否有社保`
    ,t1.store_difficulty_desc --as `门店难度`
    ,t1.store_capacity_desc --as `门店人力情况`
    ,t1.store_op_quality --as `门店质量`
    ,t1.store_status_level --as `门店综合等级`
    ,t1.special_mark --as `特殊备注`
    ,t0.store_status_desc --as `门店营业状态`
from finished_info t1
left join data_shop.dwa_shop_store_structure_condition_di t0
on t0.dt = '${today-1}' and t1.store_code = t0.store_code
left join data_shop.dm_shop_staff_protect_tag_v2 t3 on t1.store_mgr_code = t3.staff_code  and t3.dt = '${today-1}'
where  t1.store_code<> '100000238'
)



,base_info_1 as (
    select distinct
        date_add(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),1) as valid_date
        ,store_code
        ,current_manager_code
        ,t1.structure_status
    from data_shop.dwa_shop_store_structure_condition_di t1
    where dt = '${today-1}'
        AND t1.structure_status = '0.1'
)

,t30_info as (
    select distinct
        date_add(concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)),1) as valid_date
        ,store_code
        ,current_manager_code
        ,t1.structure_status
    from data_shop.dwa_shop_store_structure_condition_di t1
    where dt >= '${today-30}' and dt < '${today-1}'
        AND t1.structure_status = '0.1'
)

,cum_prep as (
        SELECT 
            t1.store_code
            ,t1.current_manager_code
            ,t1.valid_date
            ,t2.valid_date as valid_date_t30
            ,datediff(t1.valid_date,t2.valid_date) as diff_days
            ,row_number()over(partition by t1.store_code order by t2.valid_date desc) as rn
        FROM base_info_1 t1
        left join t30_info t2
        on t1.store_code = t2.store_code 
            and t1.structure_status = t2.structure_status 
            and t1.current_manager_code = t2.current_manager_code
)

,cum_days as (
    SELECT 
        store_code
        ,current_manager_code
        ,count(distinct valid_date_t30) + 1 as cum_days
    FROM cum_prep
    where diff_days = rn
    group by store_code
        ,current_manager_code
)

,replace_detail as 
(select 
t4.store_code as store_code 
,'汰换' as structure_status_desc

from data_shop.dm_shop_staff_protect_tag_v2 t1
left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
on t2.dt = '${today-1}' and t1.staff_code = IF(LENGTH(t2.emplid)<8,concat('10',t2.emplid),t2.emplid)
    and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
    and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员','店副经理', '社会PT', '学生PT', '见习店经理')
left join data_shop.dwd_shop_store_jiagou_di t3
on t3.dt = '${today-1}' and t1.store_code = t3.store_code
inner join data_shop.dwa_shop_store_structure_condition_di t4
on t2.emplid = t4.current_manager_code
    and t4.dt = '${today-1}' 
left join cum_days t5
on t2.emplid = t5.current_manager_code and t4.store_code = t5.store_code
where t1.dt = '${today-1}' 
    and t4.structure_status = '0.1'
)

-- ,upload_lack_stores as (
--     select 
--     t1.store_code 
--     ,'盈利待改善' as structure_status_desc 
    
--     from data_shop.ods_uploads_improved_stores_v1 t1 
--   left join structure_lack_detail_1 t2 on t1.store_code = t2.store_code
--   left join replace_detail t3 on t1.store_code = t3.store_code
--   where t2.store_code is null and  t3.store_code is null
-- )

,structure_lack_detail as 
(
    select t1.store_code 
,t1.structure_status_desc 
from structure_lack_detail_1 t1

union all 
select t2.store_code 
,t2.structure_status_desc 
from replace_detail t2

-- union all 
-- select t3.store_code 
-- ,t3.structure_status_desc 
-- from upload_lack_stores t3
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
,case when protect_tag in ('待观察','末位普通','应离职') then 1
--when student_suspect = 1 then 1
 when position_cn = '学生PT' then 1
else 0 end as is_di
,nvl(is_quality,1) as is_quality -- 如果没有则算优质
,date_add(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
from data_shop.dm_shop_staff_protect_tag_v2
where dt ='${today-1}'
)
-- 离职前保护标签
,leave_tag as (
 select
        IF(LENGTH(t1.emplid)<8,CONCAT('10',t1.emplid),t1.emplid) as emplid
        ,t1.hps_d_jobcode as position_cn
        ,t1.hps_d_hr_status
        ,t1.leave_dt
        ,t2.protect_tag
        ,t2.dt 
        ,row_number() over(partition by t1.emplid order by t2.dt desc) rn
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
 )
 -- 离职前是否末位普通+应离职
 ,leave_tag_final as (
 select 
 emplid
 ,leave_dt
 ,protect_tag
 ,case when protect_tag in ('末位普通','应离职') then 1 else 0 end as is_di_leave 
 from leave_tag
 where rn = 1
 )
 
,manager_list as
 (
 select
 if(length(store_manager_no)=6,concat('10',store_manager_no),store_manager_no) as store_manager_no
,date_add(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
,store_code
 from data_shop.dw_ordering_store_tag_location_ranking_info_v1_view
where dt ='${today-1}'
and store_status_desc = '营业'
)

,staff_detail as 
(
select 
distinct
t1.employee_id as staff_code 
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
,t2.is_quality
,t1.geiban_label
,case when t1.is_manager = 1 then 1 
when t6.store_manager_no is not null then 1 
else 0 end as is_manager
,t1.available_days
,t1.is_leave_21
,date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
,case when t1.is_manager = 1 then 0 
when t2.position_cn = '店副经理' then 1 
--when t1.chuqin_label = '长夜型员工' and t2.protect_tag_detail <=2 and datediff(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),t2.entry_date) >=30 and t2.is_di = 0 and t1.available_days >=3 then 1 
else 0 end as is_sec_manager 
,t1.chuqin_label
,t1.dt as dt 
,nvl(t7.is_di_leave,0) as is_di_leave
from data_build.dwd_store_construction_roster_staff_supply_v1_di t1
left join protect_detail t2 on t1.employee_id = t2.staff_code and date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1) = t2.record_date
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on t1.employee_id = IF(LENGTH(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt = '${today-1}' 
left join manager_list t6 on t1.employee_id = t6.store_manager_no and date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1) = t6.record_date and t1.store_code = t6.store_code 
left join leave_tag_final t7 on t1.employee_id = t7.emplid
where t1.dt = '${today-1}'
)

,L4_output_base as 
(
    select 
distinct 
t2.staff_code as staff_code
,if(substr(t2.staff_code,1,2) = '10' , substr(t2.staff_code,3,6) , t2.staff_code) as emplid 
,t2.cn_name as staff_name 
,t2.position_cn as hps_d_jobcode
,split(t6.hps_hrbp_idnames,'-')[0] as hrbp_code
,split(t6.hps_hrbp_idnames,'-')[1] as hrbp_name
,t5.store_city as city_name
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
,'L4' as transfer_plan
,nvl(t7.type,'正常') as eliminate_type -- 汰换类型
,concat(substr(t2.record_date,1,4),substr(t2.record_date,6,2),substr(t2.record_date,9,2))   as suggest_dt
,t2.dt as dt 
from structure_lack_detail t1  
left join data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t3 on t1.store_code = t3.a_store_code and t3.distince <= 10000  
--and t3.distince >1 
and t3.dt= '${today-1}'
left join staff_detail t2 on t3.b_store_code = t2.store_code and t2.protect_tag_detail <= 2 and t2.is_manager = 0 and t2.is_sec_manager =0 and t2.on_job_days >=30  and t2.available_days>=5 and t2.is_di = 0
and t2.is_leave_21 = 0 and t2.hours >=250 and t2.is_di_leave = 0
-- and t2.is_quality = 1 -- 只选优质店员
left join data_shop.dwd_shop_store_jiagou_di t4 on t1.store_code = t4.store_code and t4.dt = '${today-1}'
left join data_shop.dwd_shop_store_jiagou_di t5 on t2.store_code = t5.store_code and t5.dt = '${today-1}'
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t6 on t2.staff_code = IF(LENGTH(t6.emplid)<8,concat('10',t6.emplid),t6.emplid) and t6.dt = '${today-1}'
left join data_shop.ods_uploads_eliminate_manager t7 on t2.staff_code = t7.staff_code 
where t3.a_store_city = t3.b_store_city 
and t2.staff_code is not null 
)
,L4_output as 
(
select 
t0.staff_code
,t0.emplid 
,t0.staff_name 
,t0.hps_d_jobcode
,t0.hrbp_code
,t0.hrbp_name 
,t0.city_name
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
,t0.suggest_dt
,t0.dt
from L4_output_base t0 
left join data_smartorder.ai_roster_store_app_manager_staff_transfer t1 on t1.dt = '${today-1}'
and t0.staff_code = if(length(t1.staff_id)<8,concat('10',t1.staff_id),t1.staff_id) and t0.to_store_code = t1.to_store_code
left join data_shop.dwd_manager_transfer_blacklist_v1_di t3 
on t3.dt = '${today-1}' and t0.staff_code = t3.staff_code 
where if(length(t1.staff_id)<8,concat('10',t1.staff_id),t1.staff_id) is null and t1.to_store_code is null 
and t0.eliminate_type not in ('普通汰换','末尾店汰换') -- 汰换过的人不能进入候选池
and t3.staff_code is null
)

,base_info as 
(
    select 
        if(length(t1.staff_id)<8,concat('10',t1.staff_id),t1.staff_id) as staff_code
        ,t1.staff_id as emplid
        ,t1.user_namecn as staff_name
        ,t2.hps_d_jobcode
        ,split(t2.hps_hrbp_idnames,'-')[0] as hrbp_code
        ,split(t2.hps_hrbp_idnames,'-')[1] as hrbp_name
        ,t1.city_name
        ,t1.from_store_code
        ,t1.from_store_name
        ,t1.from_store_mgr_name as from_store_mgr_code
        ,t1.from_bz_mgr_name
        ,t1.from_city_zone_mgr_name
        ,t1.to_store_code
        ,t1.to_store_name
        ,t1.to_store_mgr_name
        ,t1.to_bz_mgr_name
        ,t1.to_city_zone_mgr_name
        ,case when t1.package = 'L3.2S' then 'L3.2' 
        when t1.package = 'L3.1S' then 'L3.1' else t1.package end as transfer_plan
        ,case when t1.special_mark = 'bz_mgr_recommend' then t1.suggest_dt when t1.suggest_dt = '20230206' then if(t1.special_mark = '0206new','20230206','20230206old') when t1.staff_id = '11190079' and t1.suggest_dt = '20230215' then if(t1.from_store_code = '11190079','20000101',if(t1.package <> 'L3.2ST','20000101',t1.suggest_dt)) else t1.suggest_dt end as suggest_dt 
        ,t1.dt 
    from data_smartorder.ai_roster_store_app_manager_staff_transfer t1
    left join data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw_view t2
    on t1.staff_id = t2.emplid and t2.dt = '${today-1}'
    left join data_shop.dwd_manager_transfer_blacklist_v1_di t3 
    on if(length(t1.staff_id)<8,concat('10',t1.staff_id),t1.staff_id) = t3.staff_code and t3.dt = '${today-1}'
    where t1.dt = '${today-1}'
    and t1.to_store_code not in ('100002507','100076002')
    and t3.staff_code is null 

   union all
    select 
    t3.* 
    from  L4_output t3
  
where t3.to_store_code not in ('100002507','100076002')

)
,distance_info as (
    select distinct 
        a_store_code
        ,b_store_code
        ,distince as store_distance
    from data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view a 
    where dt = '${today-1}'
)

,attend_info as (
    select 
        IF(LENGTH(t1.employee_no)<8,concat('10',t1.employee_no),t1.employee_no) as staff_code
        ,sum(coalesce(attendance_work_hours,0)) as t30_attendance_work_hours
    from default.pdw_opc_shop_attendance_report_work_shift t1
    where t1.dt = '${today-1}'
        and t1.work_shift_type in (1,9,12)
        and date_format(t1.work_shift_date,'yyyyMMdd') >= '${today-30}'
    group by 
        t1.employee_no
)

-- ,give_info as ( --给班信息
--     select
--         t1.staff_code
--         ,sum(case when 
--             date_format(t1.target_date, 'yyyyMMdd') <= '${DATE_SUB1DAY}'
--             and date_format(t1.target_date, 'yyyyMMdd') >= '${DATE_SUB30DAY}' 
--         then coalesce(if(t1.is_give_roster>12,12,t1.is_give_roster),0) end) as t30_effective_give_hours
--     from data_shop.dm_roster_staff_available_di_view t1
--     where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd') 
--         and is_available_roster = '1'
--     group by t1.staff_code
-- )

,main_list as( --历史流程统计
SELECT * 
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '031412' --晋升/接店意愿沟通
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
,row_number() over(partition by concat(substr(t1.create_time,1,10),regexp_extract(t1.flow_ame,'\\(([^)]+)\\)',1)) order by t1.create_time desc) as rn
from main_list t1
left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t2
on t1.order_id = t2.order_id
and t2.dt = '${today-1}'
and t2.form_name = 'accept'
)

,refuse_num as( --拒绝晋升次数统计
select
staff_code
,count(case when compute_period >= '${FDATE_SUB30DAY}' then staff_code else null end) as refuse_num_30 --t30拒绝次数
,count(case when compute_period >= '${FDATE_SUB180DAY}' then staff_code else null end) as refuse_num_180 --t180拒绝次数
from result_list
where result <> '愿意接受'
group by
staff_code
)

insert overwrite table ${TABLE_NAME} partition(dt='$DATE')

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
    ,t1.from_store_mgr_code
    ,t1.from_bz_mgr_name
    ,t1.from_city_zone_mgr_name
    ,t1.to_store_code
    ,t1.to_store_mgr_name
    ,t1.to_bz_mgr_name
    ,t1.transfer_plan
    ,t3.manager_sal1
    ,t3.manager_sal2
    ,case when t1.hps_d_jobcode = '学生pt' then t3.student_pt_sal
        when t1.hps_d_jobcode in  ('社会pt','门店伙伴','店副经理','店经理') then t3.else_sal
    end                                                                                 as cur_index_sal        --岗位时薪
    ,coalesce(t4.sep_hours,0)                                                                       as actual_hours         --实际工时
    ,coalesce(t4.sep_base,0)                                                                        as actual_base          --实际底薪
    ,greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))                                      as max_hour             --工时取高
    ,167*t3.manager_sal1 
        + (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2           as base_pred            --底薪预测
    ,167*t3.manager_sal1 
        + (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2 
        - coalesce(t4.sep_base,0)                                                                   as base_upraised        --时薪上涨
    ,coalesce(t4.sep_bonus,0)                                                           as actual_bonus         --实际奖金
    ,case 
        when t1.transfer_plan in ('L1','L4') then coalesce(t3.min_bonus,0)
        when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
            then greatest(coalesce(t4.sep_bonus,0),coalesce(t3.min_bonus,0),0)
        else coalesce(t3.min_bonus,0) end                                                           as base_bonus           --店奖金取低
    ,case 
        when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
            then greatest(coalesce(t4.sep_bonus,0)
                ,coalesce(t5.sep_avg_bonus,0),3500,0)
        when t1.transfer_plan = 'L2.1' 
            then greatest(1500
                ,coalesce(t5.sep_avg_bonus,0),0)
        else greatest(coalesce(t5.sep_avg_bonus,0),(case when t1.city_name = '北京' then 3200
                                                         when t1.city_name = '天津' then 2400
                                                         when t1.city_name = '上海' then 3200
                                                         when t1.city_name = '南京' then 3100
                                                         else 2975 end),0) end                               as ceil_bonus           --店奖金取高--20250916调整不同城市奖金值
    -- ,t5.sep_avg_bonus
    -- ,greatest(coalesce(t5.sep_avg_bonus,0),coalesce(t4.sep_bonus,0),coalesce(t3.min_bonus,0)) as testest
    ,0                                                                                  as base_extra_bonus     --额外激励取低
    ,case 
        when t1.transfer_plan = 'L3.1' then 1000 
        when substr(t1.transfer_plan,1,4) = 'L3.2' then 700 else 0 end                             as ceil_extra_bonus     --额外激励取高
    ,167*t3.manager_sal1 + 
        (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2 + 
        (case 
            when t1.transfer_plan in ('L1','L4') then coalesce(t3.min_bonus,0)
            when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
                then greatest(coalesce(t4.sep_bonus,0),coalesce(t3.min_bonus,0),0)
            else coalesce(t3.min_bonus,0) end) - 
        coalesce(t4.actual_sep_sal,0)                                                               as base_sal_upraised    --取低合计收入增长
    ,(167*t3.manager_sal1 + 
        (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2 + 
        (case 
            when t1.transfer_plan in ('L1','L4') then coalesce(t3.min_bonus,0)
            when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
                then greatest(coalesce(t4.sep_bonus,0),coalesce(t3.min_bonus,0),0)
            else coalesce(t3.min_bonus,0) end) - 
        coalesce(t4.actual_sep_sal,0))/coalesce(t4.actual_sep_sal,0)                                            as base_sal_upraised_percent    --取低合计增长比例
    ,167*t3.manager_sal1 + 
        (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2 +
        (case 
            when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
                then greatest(coalesce(t4.sep_bonus,0)
                    ,coalesce(t5.sep_avg_bonus,0),3500,0)
            when t1.transfer_plan = 'L2.1' 
                then greatest(1500
                    ,coalesce(t5.sep_avg_bonus,0),0)
            else greatest(coalesce(t5.sep_avg_bonus,0),(case when t1.city_name = '北京' then 3200
                                                         when t1.city_name = '天津' then 2400
                                                         when t1.city_name = '上海' then 3200
                                                         when t1.city_name = '南京' then 3100
                                                         else 2975 end),0) end) +
        (case 
            when t1.transfer_plan = 'L3.1' then 1000 
            when substr(t1.transfer_plan,1,4) = 'L3.2' then 700 else 0 end) - 
        coalesce(t4.actual_sep_sal,0)                                                               as ceil_sal_upraised    --取高合计收入增长
    ,(167*t3.manager_sal1 +
        (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2 +
        (case 
            when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
                then greatest(coalesce(t4.sep_bonus,0)
                    ,coalesce(t5.sep_avg_bonus,0),3500,0)
            when t1.transfer_plan = 'L2.1' 
                then greatest(1500
                    ,coalesce(t5.sep_avg_bonus,0),0)
            else greatest(coalesce(t5.sep_avg_bonus,0),(case when t1.city_name = '北京' then 3200
                                                         when t1.city_name = '天津' then 2400
                                                         when t1.city_name = '上海' then 3200
                                                         when t1.city_name = '南京' then 3100
                                                         else 2975 end),0) end) +
        (case 
            when t1.transfer_plan = 'L3.1' then 1000 
            when substr(t1.transfer_plan,1,4) = 'L3.2' then 700 else 0 end) - 
        coalesce(t4.actual_sep_sal,0))/coalesce(t4.actual_sep_sal,0)                                            as ceil_sal_upraised_percent    --取高合计增长比例
    ,coalesce(t4.actual_sep_sal,0)                                                                  as actual_sal           --实际实发
    ,167*t3.manager_sal1 + 
        (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2 + 
        (case 
            when t1.transfer_plan in ('L1','L4') then coalesce(t3.min_bonus,0)
            when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
                then greatest(coalesce(t4.sep_bonus,0),coalesce(t3.min_bonus,0),0)
            else coalesce(t3.min_bonus,0) end)                                                      as base_sal_pred        --晋升后实发取低
    ,167*t3.manager_sal1 + 
        (greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-167)*t3.manager_sal2 +
        (case 
            when substr(t1.transfer_plan,1,4) in ('L3.1','L3.2') 
                then greatest(coalesce(t4.sep_bonus,0)
                    ,coalesce(t5.sep_avg_bonus,0),3500,0)
            when t1.transfer_plan = 'L2.1' 
                then greatest(1500
                    ,coalesce(t5.sep_avg_bonus,0),0)
            else greatest(coalesce(t5.sep_avg_bonus,0),(case when t1.city_name = '北京' then 3200
                                                         when t1.city_name = '天津' then 2400
                                                         when t1.city_name = '上海' then 3200
                                                         when t1.city_name = '南京' then 3100
                                                         else 2975 end),0) end) +
        (case 
            when t1.transfer_plan = 'L3.1' then 1000 
            when substr(t1.transfer_plan,1,4) = 'L3.2' then 700 else 0 end)                        as ceil_sal_pred        --晋升后实发取高
    ,t1.to_city_zone_mgr_name
    ,greatest(coalesce(t4.sep_hours,0),287,coalesce(t6.actual_hour_avg,0))-coalesce(t4.sep_hours,0)                        as hours_diff           --接店后工时上涨
    ,t1.from_store_name
    ,t1.to_store_name
    ,t8.store_distance
    ,t9.t30_attendance_work_hours

    ,t10.bonus_w_cut as staff_bonus_w_cut
    ,t10.bonus as staff_bonus
    ,t10.cut as staff_cut

    ,t11.bonus_w_cut as from_bonus_w_cut
    ,t11.bonus as from_bonus
    ,t11.cut as from_cut

    ,t12.bonus_w_cut as to_bonus_w_cut
    ,t12.bonus as to_bonus_nov
    ,t12.cut as to_cut_nov

    ,null as t30_effective_give_hours

    ,null as to_store_priority_level --`门店Q等级`
    ,null as to_store_reward_level
    ,null as to_store_reward_level_night

    ,t15.bonus_w_cut as to_bonus_w_cut_t1
    ,t15.bonus as to_bonus_t1
    ,t15.cut as to_cut_t1

    ,t16.bonus_w_cut as to_bonus_w_cut_t2
    ,t16.bonus as to_bonus_t2
    ,t16.cut as to_cut_t2

    ,null as gap_new
from base_info t1
left join data_shop.ods_uploads_sal_index t3
on t1.city_name = t3.city_name
left join data_shop.ods_uploads_sep_sal t4
on t1.staff_code = t4.staff_code
left join data_shop.ods_uploads_sep_store_man_bonus t5
on t1.to_store_code = t5.store_code
left join data_shop.ods_uploads_nov_hour t6
on t1.to_store_code = t6.store_code
-- left join data_shop.ods_uploads_sep_store_man_bonus t7
-- on t1.city_name = t7.store_code
left join distance_info t8
on t1.from_store_code = t8.a_store_code and t1.to_store_code = t8.b_store_code
left join attend_info t9
on t1.staff_code = t9.staff_code
left join data_shop.ods_uploads_bonus_cut_nov t10
on t1.staff_code = t10.code

left join data_shop.ods_uploads_bonus_w_cut_dec t11
on t1.from_store_code = t11.code

left join data_shop.ods_uploads_bonus_w_cut_dec t12
on t1.to_store_code = t12.code
left join data_shop.ods_uploads_bonus_w_cut_nov t15
on t1.to_store_code = t15.code
left join data_shop.ods_uploads_bonus_w_cut_oct t16
on t1.to_store_code = t16.code
-- left join give_info t13
-- on t1.staff_code = t13.staff_code
-- LEFT JOIN data_build.dwd_store_construction_store_groups_recruit_gap t14
-- ON t1.to_store_code = t14.store_code and t14.dt = '${DATE_SUB1DAY}'
left join refuse_num t17 on t1.emplid = t17.staff_code
where t17.refuse_num_30 < 3 --30天内小于3次
or t17.staff_code is null --从没发过

;

EOF
}